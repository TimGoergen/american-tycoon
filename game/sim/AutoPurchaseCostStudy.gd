extends "res://sim/Sim.gd"

# Auto-Purchase Cost Study — the fit instrument for the restructure's two upgrade tracks
# (Plans/Auto_Purchase_Restructure.md §3.1).
#
# Usage: Godot_console.exe --headless --path game --script res://sim/AutoPurchaseCostStudy.gd
#
# THE QUESTION IT ANSWERS. Tim asked for "very high caps with more and more expensive upgrade
# costs", and for the runaway to be governed by cost curves alone. On this economy's shared
# steepening curve that makes the nominal cap almost irrelevant:
#
#     cost(n) = base x growth^(n-1) x s^((n-1)(n-2)/2) x multiplier      (s = 1.10, mult = 3.0)
#
# The steepening term is what dominates. By level 30 it alone is 1.10^406, about 1e17, so a
# 30-level track is never a 30-level climb — it is an asymptote whose real ceiling is wherever
# the player's gems run out. That is the same "uncapped on a steepening curve" shape the seven
# compounders already use, and it is why the cap is not the thing to tune.
#
# So the fit is NOT "make 30 levels affordable". It is: pick base and growth so the DEPTH A
# PLAYER ACTUALLY REACHES by the summit is a satisfying climb — not 3 levels (the track is a
# formality) and not 25 (the curve stopped mattering).
#
# HOW IT WORKS. Phase 1 plays a real dynasty with the shipped economy and records how many gems
# exist at the end of each generation — the same arc DynastyArcStudy prints, reused here as the
# budget curve. That pass is slow (minutes) because it is a genuine playout. Phase 2 is instant:
# it sweeps candidate (base, growth) pairs against that recorded curve and reports the depth
# reached per generation, so many candidates can be judged from one playout.
#
# THE BUDGET SHARE. A track never gets all the gems — it competes with the compounders, which
# are what make the next run deeper. Rather than model that rivalry (greedy shopping would need
# the new tracks in the live catalog, which is §3.3 work), the study sweeps an explicit share of
# lifetime gems. Read the 25% column as "a player who mostly buys compounders" and 50% as "a
# player who prioritises automation".

## Generations to play. Matches DynastyArcStudy so the two are directly comparable.
const GENERATIONS := 14
const GEN_CAP := 7200.0

## Skip the slow playout and fit against the RECORDED arc below.
##
## Phase 1 takes about a quarter of an hour and is fully deterministic — two separate runs on
## 2026-08-07 (this study and DynastyArcStudy) produced identical figures. Iterating candidate
## curves is a phase-2-only activity, so re-playing the dynasty for each sweep is pure waiting.
##
## SET THIS BACK TO false AND RE-RECORD whenever the economy is retuned. The numbers below are a
## measurement, not a constant: if mints or the summit generation move and this stays true, every
## fit silently becomes wrong. The printed header always says which mode produced the numbers.
const USE_RECORDED_ARC := true

## Lifetime gems at the end of each generation, measured 2026-08-07 against the shipped economy
## (summit at generation 11 — matching Plans/Endgame_Economy.md's confirmed arc).
const RECORDED_LIFETIME_GEMS := [
	1.3e6, 275.6e6, 4.5e9, 14.7e9, 33.4e9, 55.7e9, 84.3e9, 114.1e9, 150.5e9, 191.4e9, 235.1e9,
]

## The shared curve constants, read from the live config rather than copied, so a retune of
## either one invalidates this study's numbers instead of silently drifting from them.
var _steepening := 1.10
var _multiplier := 3.0

## Fractions of lifetime gems assumed to go into ONE track. See "THE BUDGET SHARE" above.
const BUDGET_SHARES := [0.25, 0.5]

## The candidates to fit. `levels` is the NOMINAL cap; the study reports reachable depth, which
## is the number that matters. Cadence is capped at 11 by physics, not by cost: 3.0s down to a
## 0.25s floor in 0.25s steps.
const CANDIDATES := [
	{"track": "quantity", "name": "A  base 1667 growth 1.6", "base": 1666.6667, "growth": 1.6, "levels": 30},
	{"track": "quantity", "name": "B  base 1667 growth 2.0", "base": 1666.6667, "growth": 2.0, "levels": 30},
	{"track": "quantity", "name": "C  base 1667 growth 2.2", "base": 1666.6667, "growth": 2.2, "levels": 30},
	{"track": "quantity", "name": "D  base  833 growth 1.6", "base": 833.3333, "growth": 1.6, "levels": 30},
	{"track": "quantity", "name": "E  base 3333 growth 1.6", "base": 3333.3333, "growth": 1.6, "levels": 30},
	# Cadence needs a wholly different scale. It is capped at 11 levels by PHYSICS (3.0s down to a
	# 0.25s floor in 0.25s steps), and 11 levels is far too few for the steepening term to bite —
	# at quantity's numbers the whole ladder totals well under a billion and maxes by generation 3.
	# So its climb has to come from growth, not from the curve. These candidates push growth hard.
	{"track": "cadence", "name": "F  base 1667 growth 3.0", "base": 1666.6667, "growth": 3.0, "levels": 11},
	{"track": "cadence", "name": "G  base 1667 growth 3.5", "base": 1666.6667, "growth": 3.5, "levels": 11},
	{"track": "cadence", "name": "H  base 1667 growth 4.0", "base": 1666.6667, "growth": 4.0, "levels": 11},
	{"track": "cadence", "name": "I  base 5000 growth 3.5", "base": 5000.0, "growth": 3.5, "levels": 11},
	{"track": "cadence", "name": "J  base  833 growth 4.0", "base": 833.3333, "growth": 4.0, "levels": 11},
]


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Auto-Purchase Cost Study ===")
	print("Fitting base/growth for the restructure's two tracks (Plans/Auto_Purchase_Restructure.md).")
	print("")

	# NOTE: the curve constants are NOT read here. LegacyUpgradeCatalog.cost_multiplier and
	# .cost_steepening are static vars that default to 1.0 and are pushed from tuning only when a
	# DynastyState is constructed. Reading them before phase 1 would silently fit every candidate
	# against a flat curve — the fit would look fine and be meaningless. They are captured inside
	# _play_dynasty_arc, immediately after the dynasty exists.
	var gems_by_generation := _play_dynasty_arc()
	if gems_by_generation.is_empty():
		print("The arc produced no generations — nothing to fit against.")
		quit(1)
		return

	_print_ladders()
	_print_reachable_depth(gems_by_generation)
	_print_verdict(gems_by_generation)
	quit()


# ---------------------------------------------------------------------------
# Phase 1 — the budget curve
# ---------------------------------------------------------------------------

## Play a real dynasty and return lifetime gems minted as of the END of each generation.
## Deliberately the same playout DynastyArcStudy uses (active rushing, greedy build-out), so
## the budget this study fits against is the one the game actually produces.
func _play_dynasty_arc() -> Array[float]:
	if USE_RECORDED_ARC:
		# Still construct a dynasty: it is what pushes the curve constants onto the catalog, and
		# without it every candidate would be fitted against a flat curve (see _initialize).
		var _warm := DynastyState.new(_property_configs, _tuning)
		_steepening = LegacyUpgradeCatalog.cost_steepening
		_multiplier = LegacyUpgradeCatalog.cost_multiplier
		print("Phase 1 — SKIPPED, using the arc recorded 2026-08-07 (summit at generation 11).")
		print("  (live curve: cost(n) = base x growth^(n-1) x %.2f^((n-1)(n-2)/2) x %.1f)" % [
			_steepening, _multiplier])
		print("  Re-record by setting USE_RECORDED_ARC = false after any economy retune.")
		print("")
		var recorded: Array[float] = []
		for value in RECORDED_LIFETIME_GEMS:
			recorded.append(float(value))
		return recorded

	print("Phase 1 — playing %d generations for the gem budget (this is the slow part)..."
		% GENERATIONS)
	print("  gen   reached        minted this gen        lifetime gems")

	var lifetime_by_gen: Array[float] = []
	var dynasty := DynastyState.new(_property_configs, _tuning)
	# Capture the live curve constants now that construction has pushed them off tuning.
	_steepening = LegacyUpgradeCatalog.cost_steepening
	_multiplier = LegacyUpgradeCatalog.cost_multiplier
	print("  (live curve: cost(n) = base x growth^(n-1) x %.2f^((n-1)(n-2)/2) x %.1f)" % [
		_steepening, _multiplier])
	for gen in range(1, GENERATIONS + 1):
		var game := dynasty.current
		game.economy.award_cash(_tuning.m1_starting_cash)
		for prop_variant in game.economy.properties:
			(prop_variant as PropertyState).rush_power_multiplier = 6.0

		var sim_time := 0.0
		var next_wage_tap := 0.0
		var rush_accumulator := 0.0
		var rush_pulse_interval := 1.0 / _tuning.hold_rush_per_second
		while game.epoch.current_tier < EpochCatalog.tier_count() and sim_time < GEN_CAP:
			if sim_time >= next_wage_tap:
				game.tap_wage()
				next_wage_tap += WAGE_TAP_PERIOD
			game.pop_frenzy()
			_greedy_build_out(game)
			var targets := _top_running_property_indices(game, 3)
			rush_accumulator += TICK_SIZE
			while rush_accumulator >= rush_pulse_interval:
				rush_accumulator -= rush_pulse_interval
				for idx in targets:
					game.hold_rush_property(idx)
			dynasty.tick(TICK_SIZE)
			sim_time += TICK_SIZE

		var reached := game.epoch.current_tier
		var lifetime_before := dynasty.upgrades.earned_lifetime
		dynasty.perform_succession()
		var minted := dynasty.upgrades.earned_lifetime - lifetime_before
		# The compounders still get bought, because the NEXT generation's mint depends on them.
		# Only the budget curve is recorded here; the tracks themselves are modelled in phase 2.
		_buy_upgrades_greedily(dynasty)
		lifetime_by_gen.append(float(dynasty.upgrades.earned_lifetime))
		print("  %3d   %5d/%d   %20s   %18s" % [
			gen, reached, EpochCatalog.tier_count(),
			Money.abbrev(float(minted)), Money.abbrev(float(dynasty.upgrades.earned_lifetime)),
		])
		if reached >= EpochCatalog.tier_count():
			print("  (summit reached at generation %d)" % gen)
			break
	print("")
	return lifetime_by_gen


# ---------------------------------------------------------------------------
# Phase 2 — the sweep
# ---------------------------------------------------------------------------

## One level's cost under the shared curve. Mirrors LegacyUpgradeCatalog.cost_for_level exactly,
## including its floor(), so the study can never quote a price the game would not charge.
func _cost_for(base: float, growth: float, level: int) -> float:
	var steps := float(level - 1)
	var steepen := pow(_steepening, steps * (steps - 1.0) / 2.0)
	return floor(base * pow(growth, steps) * steepen * _multiplier)


## Total gems to own every level up to and including `level`.
func _cumulative_cost(base: float, growth: float, level: int) -> float:
	var total := 0.0
	for n in range(1, level + 1):
		total += _cost_for(base, growth, n)
	return total


## The deepest level affordable with `budget` gems, buying from level 1 upward.
func _depth_for_budget(candidate: Dictionary, budget: float) -> int:
	var levels := int(candidate["levels"])
	var spent := 0.0
	for n in range(1, levels + 1):
		spent += _cost_for(float(candidate["base"]), float(candidate["growth"]), n)
		if spent > budget:
			return n - 1
	return levels


func _print_ladders() -> void:
	print("Phase 2a — what each candidate charges (level 1 / 5 / 10 / 15 / 20 / cap)")
	print("  track      candidate                 lv1        lv5       lv10       lv15       lv20        cap")
	for candidate in CANDIDATES:
		var base := float(candidate["base"])
		var growth := float(candidate["growth"])
		var levels := int(candidate["levels"])
		var cells: Array[String] = []
		for n in [1, 5, 10, 15, 20]:
			cells.append(Money.abbrev(_cost_for(base, growth, n)) if n <= levels else "  —")
		cells.append(Money.abbrev(_cost_for(base, growth, levels)))
		print("  %-9s  %-22s %9s %10s %10s %10s %10s %10s" % [
			candidate["track"], candidate["name"],
			cells[0], cells[1], cells[2], cells[3], cells[4], cells[5]])
	print("")


func _print_reachable_depth(lifetime_by_gen: Array[float]) -> void:
	print("Phase 2b — depth reached per generation, by share of lifetime gems spent on the track")
	for share in BUDGET_SHARES:
		print("")
		print("  --- %d%% of lifetime gems ---" % int(share * 100.0))
		var header := "  track      candidate               "
		for gen in range(1, lifetime_by_gen.size() + 1):
			header += "%4d" % gen
		print(header)
		for candidate in CANDIDATES:
			var row := "  %-9s  %-22s" % [candidate["track"], candidate["name"]]
			for lifetime in lifetime_by_gen:
				row += "%4d" % _depth_for_budget(candidate, lifetime * share)
			print(row)
	print("")


## The judgement call, stated in the study rather than left to the reader: a good quantity curve
## climbs steadily and is still climbing at the summit; a good cadence curve reaches its 11-level
## floor late rather than early, or the mode's speed stops being something to work toward.
func _print_verdict(lifetime_by_gen: Array[float]) -> void:
	var summit := lifetime_by_gen.size()
	var final_lifetime := lifetime_by_gen[summit - 1]
	print("Phase 2c — the summit read (depth at generation %d, and when the cap falls)" % summit)
	print("  track      candidate                 25%%   50%%   maxed@50%%   verdict")
	for candidate in CANDIDATES:
		var low := _depth_for_budget(candidate, final_lifetime * 0.25)
		var high := _depth_for_budget(candidate, final_lifetime * 0.5)
		var levels := int(candidate["levels"])

		# WHEN the cap falls matters more than whether it does. Reaching the top level on the
		# generation that cracks tier 27 is the reward landing with the summit; reaching it at
		# generation 3 means the track was priced as a formality. The first draft of this verdict
		# judged final depth alone and called the good case a failure.
		var maxed_at := 0
		for gen in range(1, summit + 1):
			if _depth_for_budget(candidate, lifetime_by_gen[gen - 1] * 0.5) >= levels:
				maxed_at = gen
				break

		var note := ""
		if high <= 3:
			note = "STALLED — the track is a formality"
		elif maxed_at > 0 and maxed_at <= summit / 2:
			note = "MAXED EARLY at gen %d — stops being a goal" % maxed_at
		elif maxed_at > 0:
			note = "maxes at the summit — the climb lasts the dynasty"
		else:
			note = "climbing — never maxes, the curve is the ceiling"
		print("  %-9s  %-22s %5d %5d   %9s   %s" % [
			candidate["track"], candidate["name"], low, high,
			("gen %d" % maxed_at) if maxed_at > 0 else "never", note])
	print("")
	print("Target shape: still climbing at the summit, or reaching the cap exactly there.")
	print("Then bake the chosen base/growth into LegacyUpgradeCatalog (plan §3.3).")
