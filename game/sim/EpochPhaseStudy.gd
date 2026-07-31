extends "res://sim/Sim.gd"

# Epoch Phase Study — inside one epoch, how much time is UNLOCKING vs STACKING?
# (Tim, 2026-07-30, from device testing: "each epoch seems to speed up with each new
# property you buy, and the time between your first purchase of the last property to
# completing the economy is pretty short.")
#
# Usage: Godot_console.exe --headless --path game --script res://sim/EpochPhaseStudy.gd
#
# THE SHAPE BEING MEASURED. Each epoch has two phases:
#   UNLOCK — from entering the epoch until you own >=1 of every property in it. This is
#            also the ownership half of the advance gate (GameState._owns_all_in_epoch),
#            so it is a real, player-visible milestone: the roster is complete.
#   STACK  — from that moment until the epoch's earn threshold clears and you advance.
#            Nothing new appears here; you are buying more units and more staff levels.
#
# WHY THE SPLIT IS LOPSIDED BY CONSTRUCTION. Cohort rungs are spaced exactly 2.00x and
# income is income-neutral (income/sec per dollar of cost is identical across the whole
# cohort). So each new rung is worth as much as everything below it combined: every
# purchase roughly doubles income, and the LAST rung alone is 8192/16383 = 50% of the
# epoch's capital. Buying one unit of it doubles the economy AND completes the roster.
# Meanwhile the gate grows x16807/epoch (7^5) against a ladder of 2^14 = 16384 — the two
# are the same number within 3%, so the ladder is sized to be climbed exactly once per
# epoch, which forces the last rung to land near the epoch's end every time.
#
# THE KNOB SWEPT HERE. `earth_economy_target` (tuning.tres) multiplies EVERY epoch's
# threshold (EpochCatalog.consume_threshold = earth_target x economy_scale).
#
# RESULT (2026-07-30, 66M-gem active heir, epochs 3-16). The money gate CANNOT create a
# tail. Mean STACK share:
#     gate x1  -> 0.3%      gate x3  -> 0.8%      gate x10 -> 2.3%
# A closed-form estimate said 24% / 35% / 47%; it was wrong by two orders of magnitude
# because it assumed growth at a CONSTANT exponential rate. Real end-of-epoch growth is
# SUPER-exponential — staff levels, upgrades and unit stacking all compound at once — so
# by the time the roster is complete, income is climbing fast enough that a 10x larger
# threshold is crossed in seconds. Reaching a ~25% stack share this way would need a
# multiplier in the thousands, which is absurd (and x10 already makes Earth's economy
# read as $1Qa, breaking the GDD figure).
#
# The `binding` column says which half of the gate was satisfied LAST, and `money waited`
# how long the threshold sat already-met. At x1, epochs 13+ are ROSTER-bound with the
# money slack growing (14 s at 13, 2.3 m at 16): the epoch ends the instant the last
# property is bought, and the money threshold has been irrelevant for minutes. Raising
# the gate mostly just buys back that slack.
#
# SECOND RESULT (2026-07-31): the within-cohort COST SPREAD is not the lever either.
# Holding each cohort's total capital fixed and only redistributing it across the rungs:
#     spread 2.00x (live, last rung 50.1% of cohort) -> 0.3%
#     spread 1.80x (44.5%)                           -> 0.4%
#     spread 1.60x (37.6%)                           -> 0.4%
# Moving a third of the epoch's capital out of the final rung changed the stack share by
# one tenth of one percent. (1.70x was skipped once 1.80x and 1.60x came back identical.)
# It also made the epoch's OPENING slower — holding the total fixed means a flatter ladder
# has a pricier cheapest rung, so epoch 3's unlock went 24 s -> 47 s -> 52 s. That fights
# the locked "fast pace is intentional" principle for no measured benefit.
#
# WHY BOTH LEVERS FAIL, and what it implies. By the end of an epoch the player's income is
# growing SUPER-exponentially (staff levels, upgrades and unit stacking compound at once).
# Anything denominated in dollars — a bigger threshold, a differently-shaped ladder — is
# therefore crossed in seconds. The epoch does not end when the player runs out of things
# to earn; it ends the moment the ownership gate is satisfied, and the ownership gate is
# satisfied by one purchase.
#
# So a tail cannot be bought with economy tuning. The options left are structural:
#   (a) flatten the end-of-epoch income explosion itself (staff/upgrade compounding) —
#       powerful, but it overlaps the banded-decay retune still under device validation;
#   (b) make advancement require something not denominated in dollars (the gate already
#       takes a predicate — e.g. N units of each property, or a staff-level requirement);
#   (c) accept the shape and treat buying the flagship AS the epoch's climax, investing in
#       the transition beat rather than in a tail that the income curve will always erase.
# Nothing here is implemented; this study exists to stop (a)-(c) being argued from guesses.
#
# Nothing here mutates live config: each candidate duplicates the loaded TuningConfig
# and overrides one field, the same pattern PaceStudy/PaybackStudy use for r0.

## Gate multipliers to sweep. 1.0 is live. Measured STACK shares: 0.3% / 0.8% / 2.3%
## (see the RESULT block above — the money gate is not the lever).
const GATE_MULTIPLIERS: Array[float] = [1.0, 3.0, 10.0]

## THE CANDIDATES. Each is one playout. `gate` multiplies earth_economy_target; `spread`
## rewrites the within-cohort cost ratio (0.0 = leave the live 2.00x alone).
##
## The spread rewrite holds each cohort's TOTAL capital constant and only redistributes it
## across the 14 rungs. That is deliberate: total capital is what sets income at a complete
## roster, so holding it fixed keeps epoch DURATION roughly unchanged and isolates the one
## variable in question — how much of the epoch's economy is concentrated in the final rung.
##   ratio 2.00 -> last rung is 50.0% of the cohort   (live)
##   ratio 1.80 -> 44.5%
##   ratio 1.70 -> 41.2%
##   ratio 1.60 -> 37.6%
const CANDIDATES: Array[Dictionary] = [
	{"label": "LIVE — gate x1, spread 2.00x", "gate": 1.0, "spread": 0.0},
	{"label": "spread 1.80x", "gate": 1.0, "spread": 1.8},
	{"label": "spread 1.70x", "gate": 1.0, "spread": 1.7},
	{"label": "spread 1.60x", "gate": 1.0, "spread": 1.6},
]

## Earth's two epochs are hand-tuned and device-validated; the spread rewrite touches only
## the alien cohorts (tier 3+), which are all generated from one recipe. That also leaves
## epochs 1-2 as an untouched control in every run.
const FIRST_ALIEN_TIER := 3

## Legacy stack to model. A mid-stack engaged heir — deep enough to reach the late epochs
## inside the time cap, not so deep that everything trivialises. Matches the stack
## EpochPaceStudy uses as its middle row.
const HEIR_LEGACY := 66_000_000

## Active-play model, identical to EpochPaceStudy so the two are comparable.
const RUSH_TOP_N := 3
const RUSH_POWER := 6.0

## Tiers worth printing in full. The early Earth epochs have their own hand-tuned shape;
## the question is about the alien cohorts, which are all generated from one recipe.
const REPORT_FROM_TIER := 3

## Stop the climb once this tier is cleared. The phase split is already flat well before
## here, and the deep tiers dominate wall-clock (epoch 23 alone is ~1.4 h of sim time
## against epoch 3's 24 s), so bounding the climb makes a full gate sweep practical.
## Raise it if a deep-tier question ever needs the tail.
const STOP_AFTER_TIER := 16







func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Epoch Phase Study ===")
	print("UNLOCK = entering the epoch until you own >=1 of every property in it (roster")
	print("complete, the ownership half of the advance gate).")
	print("STACK  = from there until the earn threshold clears and you advance.")
	print("A short STACK share is the compressed-ending feel: the flagship property is")
	print("bought and the epoch ends almost immediately after.")
	print("Heir: %s Legacy gems, active (rush top %d, Strong-Arm ~lv10)." % [
		_format_big(float(HEIR_LEGACY)), RUSH_TOP_N])

	print("Climb stops after epoch %d (deep tiers dominate runtime; the split is flat by then)." % STOP_AFTER_TIER)

	# An optional trailing integer selects ONE multiplier, so a sweep can be run as separate
	# short invocations instead of one long job.
	var selected := -1
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			selected = arg.to_int()
	for i in range(CANDIDATES.size()):
		if selected < 0 or selected == i:
			_print_phase_table(CANDIDATES[i])

	quit()


## Rebuild the property configs with a different within-cohort cost ratio, holding each
## cohort's TOTAL capital constant so only the concentration changes.
##
## Two things must move together. Cost is rewritten per rung, and base_income_per_unit is
## scaled by the SAME factor — that preserves income-neutrality (income/sec per dollar of
## cost is identical across a cohort), which is a load-bearing property of the live economy
## and not something this study is trying to vary.
##
## Rung order is taken by SORTING ON COST, never by config order: ConfigLoader's order is
## save/append order, which for some tiers is flagship-then-siblings rather than cheapest
## -first (see the civ pipeline notes in the project memory).
func _make_spread_variant_configs(ratio: float) -> Array:
	var indices_by_tier := {}
	for i in range(_property_configs.size()):
		var cfg := _property_configs[i] as PropertyConfig
		if cfg.unlock_tier < FIRST_ALIEN_TIER:
			continue
		if not indices_by_tier.has(cfg.unlock_tier):
			indices_by_tier[cfg.unlock_tier] = []
		(indices_by_tier[cfg.unlock_tier] as Array).append(i)

	# index -> multiplier to apply to both cost and income
	var rescale := {}
	for tier in indices_by_tier:
		var rungs: Array = indices_by_tier[tier]
		rungs.sort_custom(func(a, b):
			return (_property_configs[a] as PropertyConfig).base_cost \
				< (_property_configs[b] as PropertyConfig).base_cost)
		var cohort_total := 0.0
		for i in rungs:
			cohort_total += (_property_configs[i] as PropertyConfig).base_cost
		# Solve the cheapest rung from the geometric sum so the cohort total is preserved:
		#   total = base * (ratio^0 + ratio^1 + ... + ratio^(n-1))
		var geometric_sum := 0.0
		for k in range(rungs.size()):
			geometric_sum += pow(ratio, float(k))
		var base_rung := cohort_total / geometric_sum
		for k in range(rungs.size()):
			var idx: int = rungs[k]
			var live_cost := (_property_configs[idx] as PropertyConfig).base_cost
			rescale[idx] = (base_rung * pow(ratio, float(k))) / live_cost

	var variants: Array = []
	for i in range(_property_configs.size()):
		var live := _property_configs[i] as PropertyConfig
		var dup := live.duplicate() as PropertyConfig
		if rescale.has(i):
			var factor: float = rescale[i]
			dup.base_cost = live.base_cost * factor
			dup.base_income_per_unit = live.base_income_per_unit * factor
		variants.append(dup)
	return variants


## What fraction of a cohort's capital sits in its most expensive rung, for `ratio`.
## Printed per candidate so the table says what the knob actually did.
func _top_rung_share(ratio: float, rungs: int) -> float:
	var geometric_sum := 0.0
	for k in range(rungs):
		geometric_sum += pow(ratio, float(k))
	return pow(ratio, float(rungs - 1)) / geometric_sum


## Run one candidate's playout and print its per-epoch phase split.
func _print_phase_table(candidate: Dictionary) -> void:
	var gate_multiplier: float = candidate["gate"]
	var spread: float = candidate["spread"]
	# Reload a FRESH tuning + configs per candidate, then move the knobs on them. Reloading
	# (rather than duplicate()) keeps candidates provably free of shared state, which matters
	# here because a candidate can rewrite every property's cost.
	if not _load_configs():
		print("    (could not reload configs)")
		return
	var tuning := _tuning
	tuning.earth_economy_target = tuning.earth_economy_target * gate_multiplier

	var configs := _property_configs
	var spread_note := "spread 2.00x (live), last rung %.1f%% of cohort" % [
		_top_rung_share(2.0, 14) * 100.0]
	if spread > 0.0:
		configs = _make_spread_variant_configs(spread)
		spread_note = "spread %.2fx, last rung %.1f%% of cohort" % [
			spread, _top_rung_share(spread, 14) * 100.0]

	print("")
	print("  --- %s ---" % candidate["label"])
	print("      gate x%.1f (target %s) | %s" % [
		gate_multiplier, _format_big(tuning.earth_economy_target), spread_note])

	var result := _measure_epoch_phases(tuning, configs)
	var phases: Dictionary = result["phases"]
	print("    epoch      unlock       stack   stack share   binding   money waited")
	var unlock_total := 0.0
	var stack_total := 0.0
	var reported := 0
	for tier in range(REPORT_FROM_TIER, EpochCatalog.tier_count()):
		if not phases.has(tier):
			continue
		var row: Dictionary = phases[tier]
		var unlock: float = row["unlock"]
		var stack: float = row["stack"]
		var total := unlock + stack
		if total <= 0.0:
			continue
		unlock_total += unlock
		stack_total += stack
		reported += 1
		var share := stack / total * 100.0
		var roster_note := "" if row["roster_done"] else "  (roster probe missed)"
		print("    %4d  %10s  %10s       %5.1f%%   %7s   %10s%s" % [
			tier, _format_duration(unlock), _format_duration(stack), share,
			row["binding"], _format_duration(row["money_slack"]), roster_note])
	if reported == 0:
		print("    (no epochs cleared within the sim-time cap)")
		return
	var overall := unlock_total + stack_total
	print("    ----")
	print("    mean stack share across %d epochs: %.1f%%" % [
		reported, stack_total / overall * 100.0])
	if not result["completed"]:
		print("    (did not reach the final epoch within the %s cap)" % _format_duration(PLAYOUT_TIME_CAP))


## Play a heir from $0 under `tuning`, recording for each tier the sim-time it was entered,
## the sim-time its roster completed, and the sim-time it cleared. Mirrors
## Sim._measure_epoch_durations_via_playout's active-play model exactly, with the extra
## roster-completion probe — kept as its own function rather than threading a flag through
## the shared one, so the existing studies are untouched.
func _measure_epoch_phases(tuning: TuningConfig, configs: Array) -> Dictionary:
	var dynasty := DynastyState.new(configs, tuning)
	dynasty.upgrades.award(HEIR_LEGACY)
	_buy_upgrades_greedily(dynasty)
	var game := dynasty.current
	game.economy.award_cash(tuning.m1_starting_cash)
	for prop_variant in game.economy.properties:
		(prop_variant as PropertyState).rush_power_multiplier = RUSH_POWER

	var sim_time := 0.0
	var next_wage_tap := 0.0
	var rush_accumulator := 0.0
	var rush_pulse_interval := 1.0 / tuning.hold_rush_per_second
	var last_tier := game.epoch.current_tier
	var tier_entered := {last_tier: 0.0}
	var tier_roster_done := {}      # tier -> sim_time the roster completed
	var tier_money_done := {}       # tier -> sim_time the earn threshold was first met
	var phases := {}

	while game.epoch.current_tier <= STOP_AFTER_TIER \
			and game.epoch.current_tier < EpochCatalog.tier_count() \
			and sim_time < PLAYOUT_TIME_CAP:
		# The tier we are IN for this tick's purchases. Captured BEFORE the tick because the
		# tick itself can advance the epoch: buying the last property completes the roster and
		# clears the gate in the same tick, so probing the post-tick tier would check the NEXT
		# epoch's roster and lose the milestone entirely (it did, in the first run of this study).
		var tier_this_tick := game.epoch.current_tier
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()
		_greedy_build_out(game)
		if RUSH_TOP_N > 0:
			var targets := _top_running_property_indices(game, RUSH_TOP_N)
			rush_accumulator += TICK_SIZE
			while rush_accumulator >= rush_pulse_interval:
				rush_accumulator -= rush_pulse_interval
				for idx in targets:
					game.hold_rush_property(idx)
		dynasty.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		# Probe the roster gate for the tier this tick's buying belonged to, and latch the
		# first moment it is satisfied. Ownership only grows, so the first true is the
		# milestone. Probing AFTER the tick is right (the purchases have landed); using the
		# pre-tick tier index is what makes it correct on an advancing tick.
		if not tier_roster_done.has(tier_this_tick) and _owns_whole_epoch(game, tier_this_tick):
			tier_roster_done[tier_this_tick] = sim_time
		# Latch the other half of the gate too — the moment cumulative earnings first cover the
		# threshold. Comparing the two answers the question the gate knob turns on: if MONEY is
		# met long before the ROSTER, the money threshold is not what is holding the player, and
		# raising it is the only thing that can create a tail at all.
		if not tier_money_done.has(tier_this_tick):
			var threshold := EpochCatalog.consume_threshold(tier_this_tick, tuning.earth_economy_target)
			if game.economy.cash_earned_this_gen >= threshold:
				tier_money_done[tier_this_tick] = sim_time

		if game.epoch.current_tier > last_tier:
			# Close out every tier the tick crossed (a 0.1 s tick rarely crosses more than
			# one, but a huge income spike can).
			for crossed in range(last_tier, game.epoch.current_tier):
				var entered: float = tier_entered.get(crossed, 0.0)
				# If the roster gate was never observed true, the tier still advanced, so
				# treat the whole epoch as unlock and flag it.
				var roster_done: bool = tier_roster_done.has(crossed)
				var roster_at: float = tier_roster_done.get(crossed, sim_time)
				var money_at: float = tier_money_done.get(crossed, sim_time)
				phases[crossed] = {
					"unlock": roster_at - entered,
					"stack": sim_time - roster_at,
					"roster_done": roster_done,
					# Which half of the gate was satisfied LAST — that is the one actually
					# holding the epoch closed, and therefore the only one worth tuning.
					"binding": "roster" if roster_at >= money_at else "money",
					# How long the money threshold sat already-satisfied, waiting on the roster.
					"money_slack": maxf(0.0, roster_at - money_at),
				}
				tier_entered[crossed + 1] = sim_time
			last_tier = game.epoch.current_tier

	return {
		"phases": phases,
		"completed": game.epoch.current_tier >= EpochCatalog.tier_count(),
		"sim_time": sim_time,
	}


## Does this generation own at least one unit of every property in `tier`? Same predicate the
## live epoch gate uses (GameState._owns_all_in_epoch), reached through the public helpers.
func _owns_whole_epoch(game: GameState, tier: int) -> bool:
	var indices := game.economy.get_property_indices_for_unlock_tier(tier)
	if indices.is_empty():
		return true
	return game.economy.owns_at_least_one_of_each(indices)


## Compact magnitude for the header lines (the sim's own Money formatting is per-instance).
func _format_big(v: float) -> String:
	return Money.new(v).display(1)
