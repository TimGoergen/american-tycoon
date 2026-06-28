extends SceneTree

# Headless balance simulator entry point (Mechanics Spec §13).
#
# Usage: godot --headless --path . --script res://sim/Sim.gd
#
# Runs the M1 verification protocol end to end, headlessly:
#   Phase 1 — 10 minutes of active play (wage taps, greedy buys, frenzy pops).
#   Phase 2 — hire staffers wherever affordable (the offline income source).
#   Phase 3 — save, reload into a fresh GameState, and return from a
#             simulated 3-hour absence (closed-form, never cycle-simulated).
#   Phase 4 — the return spike: spend the pile, report the income/sec jump.
#             This is the moment M1 exists to verify (GDD §3.1).
#
# The simulated player is ACTIVE during Phase 1: unstaffed cycles stop after
# each payout (Spec §4), so the player re-taps every idle property to restart
# it. Every tap (wage, start, rush) feeds the frenzy meter, which is popped
# greedily the moment it crosses the pop floor.

const ACTIVE_SECONDS := 600.0          # Phase 1 duration: 10 minutes
const TICK_SIZE := 0.1                 # matches LOGIC_HZ = 10
const REPORT_INTERVAL := 60.0          # print a status line every sim minute
const OFFLINE_GAP_SECONDS := 10800.0   # 3 hours — the GDD §3.2 tuning anchor
const WAGE_TAP_PERIOD := 0.3           # an active thumb: ~3 wage taps per second
const SIM_SAVE_PATH := "user://sim_save.json"

# --- Dynasty protocol (M2 prestige verification) ---
const DYNASTY_GENERATIONS := 6         # ≥5 generations (GDD §13 exit criterion)
const GEN_PLAY_SECONDS := 180.0        # fixed active play per generation, so estates grow
const DYNASTY_SAVE_PATH := "user://sim_dynasty_save.json"

var _property_configs: Array = []
var _tuning: TuningConfig


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return

	print("=== American Tycoon — Balance Simulator ===")
	print("")

	_print_ladder_magnitude()

	var game := GameState.new(_property_configs, _tuning)
	game.economy.award_cash(_tuning.m1_starting_cash)
	print("Starting cash: %s" % Money.of(game.economy.cash).display())

	_run_active_phase(game)
	_run_hiring_phase(game)
	var resumed := _run_offline_phase(game)
	if resumed == null:
		quit(1)
		return
	_run_return_spike_phase(resumed)

	# M2 prestige spine: prove the dynasty "speeds up every time" (GDD §13).
	_run_dynasty_protocol()

	# Epoch transition study: does each alien epoch take longer or shorter than
	# the last? (The "second epoch stalls out" investigation, 2026-06-27.)
	_run_epoch_timing_study()

	quit()


# ---------------------------------------------------------------------------
# Config loading — everything comes from /config, nothing from code
# ---------------------------------------------------------------------------

## Load every config Resource the sim needs (via the same ConfigLoader the
## game uses, so the two can never drift). Returns false on any failure.
func _load_configs() -> bool:
	# The sim always measures the baked defaults — never a device's local dev-panel
	# overrides — so balance results stay reproducible (apply_user_overrides=false).
	_tuning = ConfigLoader.load_tuning(false)
	_property_configs = ConfigLoader.load_property_configs()
	return _tuning != null and not _property_configs.is_empty()


# ---------------------------------------------------------------------------
# Phase 1 — active play
# ---------------------------------------------------------------------------

func _run_active_phase(game: GameState) -> void:
	print("")
	print("--- Phase 1: %d minutes of active play ---" % int(ACTIVE_SECONDS / 60.0))

	var sim_time := 0.0
	var next_report := REPORT_INTERVAL
	var next_wage_tap := 0.0
	var frenzy_pops := 0

	while sim_time < ACTIVE_SECONDS:
		# Wage taps (Layer 1) — also the early frenzy filler.
		if sim_time >= next_wage_tap:
			game.tap_wage()  # the clock-in level rises on its own as clicks accrue
			next_wage_tap += WAGE_TAP_PERIOD

		# Pop frenzy greedily. (A real player would charge higher first; the
		# greedy policy just proves the state machine cycles correctly.)
		if game.pop_frenzy():
			frenzy_pops += 1

		_greedy_buy_spree(game)

		# Restart idle cycles — the Layer-2 start verb, tapped by the player.
		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			if prop.units_owned > 0 and not prop.is_cycle_running:
				game.tap_property(i)

		game.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		if sim_time >= next_report:
			print("t=%02dm | income/sec: %s/s | cash: %s | wage taps: %d | frenzy x%.2f" % [
				int(sim_time / 60.0),
				Money.of(game.economy.get_total_income_per_sec()).display(),
				Money.of(game.economy.cash).display(),
				game.wage.lifetime_taps,
				game.frenzy.get_multiplier(),
			])
			next_report += REPORT_INTERVAL

	print("Frenzy pops this session: %d | final clock-in level: %d" % [
		frenzy_pops, game.wage.level
	])


# ---------------------------------------------------------------------------
# Phase 2 — staff hires before stepping away
# ---------------------------------------------------------------------------

func _run_hiring_phase(game: GameState) -> void:
	print("")
	print("--- Phase 2: hiring staff before stepping away ---")

	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned == 0 or prop.is_staffed:
			continue
		var cost := prop.get_staff_cost()
		if game.try_hire(i):
			print("  Hired %s for %s" % [
				(prop.config as PropertyConfig).staffer_name,
				Money.of(cost).display(),
			])

	var staffed_ips := 0.0
	for prop in game.economy.properties:
		var p := prop as PropertyState
		if p.is_staffed:
			staffed_ips += p.get_income_per_sec()

	print("  Staffed income/sec: %s/s | cash remaining: %s" % [
		Money.of(staffed_ips).display(),
		Money.of(game.economy.cash).display(),
	])


# ---------------------------------------------------------------------------
# Phase 3 — save round-trip + the 3-hour absence
# ---------------------------------------------------------------------------

## Save, then load into a fresh GameState as if the app relaunched 3 hours
## later. Returns the resumed game, or null if the save round-trip failed.
func _run_offline_phase(game: GameState) -> GameState:
	print("")
	print("--- Phase 3: away for %.1f hours ---" % (OFFLINE_GAP_SECONDS / 3600.0))

	if not SaveManager.save_to_file(game, SIM_SAVE_PATH):
		push_error("Sim: save failed")
		return null

	var save_dict := SaveManager.load_from_file(SIM_SAVE_PATH)
	if save_dict.is_empty():
		push_error("Sim: load failed")
		return null

	var resumed := GameState.new(_property_configs, _tuning)
	resumed.load_save_dict(save_dict)

	# Sanity-check the round trip before trusting the rest of the run.
	# (Cash is always integer-valued — everything floors at award/charge —
	# so exact float comparison is safe here.)
	if resumed.economy.cash != game.economy.cash:
		push_error("Sim: cash mismatch after save round-trip")
		return null

	var offline := resumed.apply_offline(OFFLINE_GAP_SECONDS)
	print("  Welcome back. Hours worked: 0")
	print("  Offline pile: %s (%.1f of %.1f hours paid, at %.0f%% efficiency)" % [
		Money.of(offline.pile).display(),
		offline.paid_seconds / 3600.0,
		offline.elapsed_seconds / 3600.0,
		_tuning.offline_efficiency * 100.0,
	])
	return resumed


# ---------------------------------------------------------------------------
# Phase 4 — the return spike
# ---------------------------------------------------------------------------

func _run_return_spike_phase(game: GameState) -> void:
	print("")
	print("--- Phase 4: the return spike ---")

	var ips_before := game.economy.get_total_income_per_sec()
	var units_bought := _greedy_buy_spree(game)

	# Restart anything idle the spree left behind (staffed ones auto-run).
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0 and not prop.is_cycle_running:
			game.tap_property(i)

	var ips_after := game.economy.get_total_income_per_sec()
	var delta_pct := 0.0
	if ips_before > 0.0:
		delta_pct = (ips_after / ips_before - 1.0) * 100.0

	print("  Units bought with the pile: %d" % units_bought)
	print("  Income/sec: %s/s -> %s/s  (+%.0f%%)" % [
		Money.of(ips_before).display(),
		Money.of(ips_after).display(),
		delta_pct,
	])

	print("")
	print("=== Final property breakdown ===")
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0:
			print("  %-26s owned: %4d | %s | ips: %s/s" % [
				(prop.config as PropertyConfig).display_name,
				prop.units_owned,
				"staffed" if prop.is_staffed else "manual",
				Money.of(prop.get_income_per_sec()).display(),
			])


# ---------------------------------------------------------------------------
# Shared player policy
# ---------------------------------------------------------------------------

## Spend cash on whichever single unit adds the best income/sec per dollar,
## repeating until nothing is affordable. Returns the number of units bought.
## (Capped to avoid a pathological loop on a degenerate config.)
func _greedy_buy_spree(game: GameState) -> int:
	var units_bought := 0
	while units_bought < 1000:
		var best_index := -1
		var best_value := 0.0  # marginal income/sec per dollar

		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			var cost := prop.get_next_cost()
			if cost <= 0.0 or game.economy.cash < cost:
				continue
			var current_ips := prop.get_income_per_sec()
			prop.units_owned += 1  # peek at the post-purchase rate
			var new_ips := prop.get_income_per_sec()
			prop.units_owned -= 1
			var value := (new_ips - current_ips) / cost
			if value > best_value:
				best_value = value
				best_index = i

		if best_index == -1:
			break  # nothing affordable

		game.try_buy(best_index, 1)
		units_bought += 1

	return units_bought


# ---------------------------------------------------------------------------
# Dynasty protocol — the M2 prestige spine, verified across generations
# ---------------------------------------------------------------------------

## Run several generations back to back and show that each heir reaches the
## previous generation's peak position in LESS time than the one before — the
## GDD §13 "speeds up every time" exit criterion for the prestige loop. Each
## generation plays a fixed span of active time (so estates keep growing and
## Legacy compounds); we measure how quickly it overtakes the predecessor.
func _run_dynasty_protocol() -> void:
	print("")
	print("=== Dynasty protocol: %d generations (GDD §13 'speeds up every time') ===" % DYNASTY_GENERATIONS)
	print("Each generation plays %d s of active time; we report how fast each heir reaches the founder's peak." % int(GEN_PLAY_SECONDS))

	if not _verify_waterfall_math():
		push_error("Sim: estate waterfall math spot-check failed")
		return

	var dynasty := DynastyState.new(_property_configs, _tuning)

	# The fixed yardstick for "speeds up every time": the founder's (gen 1) peak
	# net worth. Every later heir should reach THIS SAME position faster than the
	# last (GDD §5.1: "run 1's first hour is run 5's first ninety seconds").
	# Set after generation 1 plays; 0 until then.
	var founder_peak := 0.0
	var previous_time_to_founder := -1.0

	for _g in range(DYNASTY_GENERATIONS):
		var generation := dynasty.generation
		var legacy_at_birth := dynasty.upgrades.available

		# The new acceleration source: spend the banked Legacy on upgrades before
		# this heir starts working. Each generation thus inherits a stronger perk
		# sheet (more starting cash, higher income, faster cycles, …), which is
		# what should make it reach the founder's peak faster than the last.
		var upgrades_bought := _buy_upgrades_greedily(dynasty)
		var income_mult := dynasty.get_legacy_income_multiplier()

		var time_to_founder := _play_generation(dynasty, GEN_PLAY_SECONDS, founder_peak)
		var will := dynasty.get_draft_will()

		print("")
		print("--- Generation %d ---" % generation)
		print("  Born with Legacy: %d  (bought %d upgrade levels -> property income x%.2f)" % [
			legacy_at_birth, upgrades_bought, income_mult,
		])
		if founder_peak > 0.0:
			print("  Time to reach the founder's peak (%s): %s" % [
				Money.of(founder_peak).display(),
				_format_time_to_reference(time_to_founder, previous_time_to_founder),
			])
		print("  Peak net worth this life: %s" % Money.of(dynasty.current.peak_net_worth).display())
		# Gross estate is now LIFETIME CASH EARNED this generation (Spec §9.1), not
		# net worth at death — so it reads higher than the peak-net-worth line above.
		print("  Lifetime cash earned this life: %s" % Money.of(dynasty.current.economy.cash_earned_this_gen).display())
		print("  Estate at death: gross %s -> tax %s -> net %s  ==>  +%d Legacy" % [
			Money.of(will["estate_gross"]).display(),
			Money.of(will["tax"]).display(),
			Money.of(will["estate_net"]).display(),
			int(will["legacy_gain"]),
		])

		# Freeze the founder's peak after generation 1; track the trend thereafter.
		if founder_peak <= 0.0:
			founder_peak = dynasty.current.peak_net_worth
		elif time_to_founder >= 0.0:
			previous_time_to_founder = time_to_founder

		dynasty.perform_succession()

	print("")
	print("Dynasty Legacy after %d generations: %d to spend, %d earned over the bloodline" % [
		DYNASTY_GENERATIONS, dynasty.upgrades.available, dynasty.upgrades.earned_lifetime,
	])
	print("Dynasty lifetime cash earned across the bloodline: %s" % Money.of(dynasty.lifetime_cash_earned).display())
	_verify_dynasty_save_roundtrip(dynasty)


## Greedy upgrade buyer for the sim: repeatedly buy the cheapest affordable
## upgrade level until nothing is affordable, then re-apply the effects to the
## living generation. Returns how many levels were bought. (A real player would
## specialize; the cheapest-first policy just proves the spend/effect loop works
## and that buying upgrades accelerates each heir.)
func _buy_upgrades_greedily(dynasty: DynastyState) -> int:
	var bought := 0
	while bought < 1000:
		var best_id := ""
		var best_cost := -1
		for definition in LegacyUpgradeCatalog.all():
			var id := String(definition["id"])
			if not dynasty.upgrades.can_buy(id):
				continue
			var cost := dynasty.upgrades.get_next_cost(id)
			if best_cost < 0 or cost < best_cost:
				best_cost = cost
				best_id = id
		if best_id == "":
			break  # nothing affordable
		dynasty.upgrades.buy(best_id)
		bought += 1
	dynasty.refresh_current_generation_effects()
	return bought


## Play one generation for `seconds` of active time using the same greedy policy
## as the M1 phases, but ticking through the dynasty so the Legacy multiplier
## applies. Returns the sim-time (seconds) at which this generation first reached
## `reference_target` net worth, or -1.0 if it never did (or if the target is 0,
## i.e. the founder generation that defines the yardstick).
func _play_generation(dynasty: DynastyState, seconds: float, reference_target: float) -> float:
	var sim_time := 0.0
	var next_wage_tap := 0.0
	var time_to_reference := -1.0

	while sim_time < seconds:
		var game := dynasty.current

		if sim_time >= next_wage_tap:
			game.tap_wage()  # the clock-in level rises on its own as clicks accrue
			next_wage_tap += WAGE_TAP_PERIOD

		game.pop_frenzy()
		_greedy_buy_spree(game)

		# Restart idle cycles — the Layer-2 start verb, tapped by the player.
		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			if prop.units_owned > 0 and not prop.is_cycle_running:
				game.tap_property(i)

		dynasty.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		# Record the moment we reach the fixed reference (net worth is monotonic).
		if time_to_reference < 0.0 and reference_target > 0.0 \
				and game.peak_net_worth >= reference_target:
			time_to_reference = sim_time

	return time_to_reference


## Format the "time to reach the founder's peak" line, flagging whether it shrank
## vs. the prior generation (the actual thing we want to see — acceleration).
func _format_time_to_reference(time_to_reference: float, previous_time: float) -> String:
	if time_to_reference < 0.0:
		return "NOT REACHED within %d s" % int(GEN_PLAY_SECONDS)
	if previous_time < 0.0:
		return "%.1f s" % time_to_reference
	var faster := previous_time - time_to_reference
	var trend := "FASTER" if faster > 0.0 else "slower"
	return "%.1f s  (%.1f s %s than previous)" % [time_to_reference, absf(faster), trend]


## One hand-computable case through the waterfall, so a future formula change
## that breaks the math fails loudly here (Spec §9.2–9.3). Uses a $2B gross so the
## log-compressed Legacy curve (reworked 2026-06-17) returns a meaningful non-zero:
##   gross $2.0B, no debt, exemption $1.0M, rate 60%
##     -> after-credit $2.0B -> taxable $1.999B -> tax $1.1994B -> net $800.6M
##     -> legacy = floor(K_LEGACY × log10(net / $1M) ^ ALPHA)
func _verify_waterfall_math() -> bool:
	var will := EstateWaterfall.compute(2_000_000_000.0, 0.0, 1_000_000.0, 0.6)
	# Typed bool: Dictionary lookups are Variants, so := would infer Variant here.
	var ok: bool = will["taxable"] == 1_999_000_000.0 \
			and will["tax"] == 1_199_400_000.0 \
			and will["estate_net"] == 800_600_000.0
	# Independently recompute the log-curve Legacy and compare to the function's output.
	var net: float = will["estate_net"]
	var expected_legacy := 0
	if net > EstateWaterfall.LEGACY_BASE:
		var decades := log(net / EstateWaterfall.LEGACY_BASE) / log(10.0)
		expected_legacy = int(floor(_tuning.k_legacy * pow(decades, _tuning.alpha_legacy)))
	var legacy := EstateWaterfall.legacy_gain(net, _tuning.k_legacy, _tuning.alpha_legacy)
	ok = ok and legacy == expected_legacy
	print("  Waterfall spot-check: net %s, +%d Legacy ... %s" % [
		Money.of(net).display(), legacy, "PASS" if ok else "FAIL",
	])
	return ok


## Save the dynasty, reload it into a fresh DynastyState, and confirm the
## cross-generation facts survive the round trip (Spec §12 + the M2 save bump).
func _verify_dynasty_save_roundtrip(dynasty: DynastyState) -> void:
	if not SaveManager.save_dict_to_file(dynasty.to_save_dict(), DYNASTY_SAVE_PATH):
		push_error("Sim: dynasty save failed")
		return
	var data := SaveManager.load_from_file(DYNASTY_SAVE_PATH)
	if data.is_empty():
		push_error("Sim: dynasty load failed")
		return

	var reloaded := DynastyState.new(_property_configs, _tuning)
	reloaded.load_save_dict(data)

	var ok := reloaded.upgrades.available == dynasty.upgrades.available \
			and reloaded.upgrades.earned_lifetime == dynasty.upgrades.earned_lifetime \
			and reloaded.generation == dynasty.generation \
			and reloaded.ancestors.size() == dynasty.ancestors.size() \
			and reloaded.lifetime_cash_earned == dynasty.lifetime_cash_earned
	print("Dynasty save round-trip (Legacy to spend %d, generation %d, %d ancestors): %s" % [
		reloaded.upgrades.available, reloaded.generation, reloaded.ancestors.size(),
		"PASS" if ok else "FAIL",
	])


# ---------------------------------------------------------------------------
# Property ladder magnitude check (the "new magnitude per tier" feel)
# ---------------------------------------------------------------------------

## Print the base economics of each property tier and the step from the previous
## tier. The design goal is that each new property unlocks a clear ~5× magnitude
## of income/sec while staying worth buying (cost rises a touch faster, a gentle
## efficiency taper). This table is how that intent is verified at a glance.
func _print_ladder_magnitude() -> void:
	print("--- Property ladder (base values, before milestones) ---")
	print("  tier  property                    base cost     cycle    income/sec   ×inc  ×cost")
	var prev_ips := 0.0
	var prev_cost := 0.0
	for cfg in _property_configs:
		var c := cfg as PropertyConfig
		var ips := c.base_income_per_unit / c.base_cycle_length if c.base_cycle_length > 0.0 else 0.0
		var inc_ratio := ips / prev_ips if prev_ips > 0.0 else 0.0
		var cost_ratio := c.base_cost / prev_cost if prev_cost > 0.0 else 0.0
		print("  %2d    %-26s %12s  %5.1fs  %11s   %4s  %4s" % [
			c.property_id,
			c.display_name,
			Money.of(c.base_cost).display(),
			c.base_cycle_length,
			Money.of(ips).display() + "/s",
			("—" if inc_ratio == 0.0 else "%.1f" % inc_ratio),
			("—" if cost_ratio == 0.0 else "%.1f" % cost_ratio),
		])
		prev_ips = ips
		prev_cost = c.base_cost
	print("")


# ---------------------------------------------------------------------------
# Epoch transition study — "does the second epoch stall out?"
# ---------------------------------------------------------------------------
#
# THE QUESTION (Tim, 2026-06-27): reaching epoch 2 feels like it stalls — the only
# change is that new staff become available, and at billions/sec a flat property
# purchase no longer moves the needle. Is that a feel problem or a math problem?
#
# THE MODEL. Time to clear an epoch ~= (dollars you must earn) / (your income/sec).
#   - Dollars to clear epoch T = earth_target * economy_scale(T) (EpochCatalog.consume_threshold).
#   - Income/sec while IN epoch T ~= (your built-up Earth income) * staff_income_multiplier(T),
#     because the staffer-tier multiplier is a flat linear factor on property income
#     (EconomyState.get_passive_income_per_sec / PropertyState.get_income_per_cycle).
#
# So once we MEASURE one number — the income/sec a fully-built, fully-staffed
# generation reaches on Earth (tier 1) — every epoch's duration follows by
# multiplying that base by the tier's staff multiplier. We measure that base by
# actually playing a juiced heir (high-fidelity 0.1 s ticks), then PROJECT the
# whole 6-epoch ladder. The projection is exact for the RELATIVE timing (the thing
# we care about) precisely because the staff multiplier is linear; only the
# absolute clock depends on how juiced the heir is, and the divergence ratio does
# not depend on it at all.
#
# A brute-force play-to-a-quadrillion sim is deliberately NOT used: epoch 3 alone
# requires earning $103.6 quadrillion, which is hundreds of millions of ticks and
# would only re-derive what the linear staff factor already tells us exactly.

## Legacy granted to the measured heir so it buys a realistic deep-dynasty perk
## sheet (maxes the compounding accelerators). Only affects the ABSOLUTE clock, not
## the per-epoch divergence ratio — chosen generous so the absolute hours read realistically.
const STUDY_HEIR_LEGACY := 50_000
const STUDY_BUILDUP_SECONDS := 600.0   # active play before we read the income plateau


func _run_epoch_timing_study() -> void:
	print("")
	print("=== Epoch transition study (does the 2nd epoch stall?) ===")

	var base_ips := _measure_tier1_plateau_income()
	print("  Measured Earth (tier 1) income plateau, fully staffed: %s/s" % Money.of(base_ips).display())
	if base_ips <= 0.0:
		push_error("Sim: epoch study could not measure a base income")
		return

	# 1) The CURRENT constants, straight from the live catalog.
	var current_econ: Array = []
	var current_staff: Array = []
	for tier in range(1, EpochCatalog.tier_count() + 1):
		current_econ.append(EpochCatalog.economy_scale(tier))
		current_staff.append(EpochCatalog.staff_income_multiplier(tier))
	print("")
	print("  --- CURRENT constants (live EpochCatalog) ---")
	_print_epoch_projection(current_econ, current_staff, base_ips)

	# 2) Candidate matched/under-matched pairs. The per-epoch duration ratio is
	#    asymptotically economy_step / staff_step, so:
	#      step ratio  < 1  -> each epoch is FASTER than the last (accelerates)
	#      step ratio == 1  -> every epoch takes the same wall-clock (flat)
	#      step ratio  > 1  -> each epoch is slower (the current stall)
	#    Each candidate is a geometric ladder over 6 tiers from (1, 1).
	var candidates := [
		{"name": "Match high (econ x1000, staff x1000)", "econ": 1000.0, "staff": 1000.0},
		{"name": "Match moderate (econ x30, staff x30)", "econ": 30.0, "staff": 30.0},
		{"name": "Accelerating (econ x30, staff x40)", "econ": 30.0, "staff": 40.0},
		{"name": "Accelerating (econ x50, staff x60)", "econ": 50.0, "staff": 60.0},
	]
	for candidate in candidates:
		print("")
		print("  --- Candidate: %s ---" % candidate["name"])
		var econ := _geometric_ladder(float(candidate["econ"]), EpochCatalog.tier_count())
		var staff := _geometric_ladder(float(candidate["staff"]), EpochCatalog.tier_count())
		_print_epoch_projection(econ, staff, base_ips)

	# NOTE: the projection above uses the LEVEL-0 staff multiplier (the tier entry jump only),
	# which is the purest demonstration of the pacing law. The within-epoch staff levels add a
	# compounding bonus on top, so REAL epoch durations are shorter than projected (an epoch
	# becomes an income ramp). The staff-economics readout below shows what those levels cost.
	_print_staff_economics()

	print("")
	print("  TAKEAWAY: per-epoch duration ratio = economy_step / staff_step.")
	# Read the live epoch-2 step straight from the catalog so this line never goes
	# stale when the constants are retuned (it cited the old 1000/17 stall before).
	var econ_step: float = float(current_econ[1]) / float(current_econ[0]) if current_econ.size() > 1 else 0.0
	var staff_step: float = float(current_staff[1]) / float(current_staff[0]) if current_staff.size() > 1 else 0.0
	var verdict := "ACCELERATES" if staff_step > econ_step \
			else ("FLAT" if is_equal_approx(staff_step, econ_step) else "STALLS (slower each epoch)")
	print("  Live epoch-2 step: economy x%.0f / staff x%.0f  ->  %s." % [econ_step, staff_step, verdict])
	print("  Rule of thumb: keep staff step >= economy step to stay flat-or-accelerating.")


## Print, per alien epoch, what the new staffer costs vs. the epoch's whole economy — so the
## staff_cost_fraction retune (2026-06-27) is visible and tunable. Shows the cheapest (ATM,
## index 0) and priciest (Executive Assets, index 11) entry-hire prices, the entry price as a
## fraction of the epoch economy (the "is it too cheap at contact?" number Tim flagged), and the
## first within-epoch level cost. Uses a fresh economy at base prices (no Legacy discount).
func _print_staff_economics() -> void:
	print("")
	print("  --- Staff economics (entry-hire cost vs epoch economy; staff_cost_fraction=%.4f) ---" % _tuning.staff_cost_fraction)
	print("    epoch   epoch economy     hire ATM    %of econ   hire Exec    1st level (ATM)")
	var economy := EconomyState.new(_property_configs, _tuning)
	for tier in range(2, EpochCatalog.tier_count() + 1):
		var epoch_econ := _tuning.earth_economy_target * EpochCatalog.economy_scale(tier)
		var hire_cheap := economy.get_staff_cost(0, tier)
		var hire_dear := economy.get_staff_cost(11, tier)
		var pct := (hire_cheap / epoch_econ * 100.0) if epoch_econ > 0.0 else 0.0
		# First level (staff_level 0) costs the entry hire × staff_level_cost_base.
		var first_level := CostCurve.round_nice(hire_cheap * _tuning.staff_level_cost_base)
		print("    %4d   %13s   %10s   %6.2f%%   %10s   %14s" % [
			tier,
			Money.of(epoch_econ).display(),
			Money.of(hire_cheap).display(),
			pct,
			Money.of(hire_dear).display(),
			Money.of(first_level).display(),
		])


## Play one juiced generation to a build-out plateau and return its passive
## income/sec on Earth (every property staffed at tier 1). This is the single
## measured number the whole projection rests on.
func _measure_tier1_plateau_income() -> float:
	var dynasty := DynastyState.new(_property_configs, _tuning)
	dynasty.upgrades.award(STUDY_HEIR_LEGACY)
	var levels := _buy_upgrades_greedily(dynasty)
	print("  Juiced heir: spent %d Legacy on %d upgrade levels (property income x%.1f)" % [
		STUDY_HEIR_LEGACY, levels, dynasty.get_legacy_income_multiplier(),
	])

	var game := dynasty.current
	var sim_time := 0.0
	var next_wage_tap := 0.0
	while sim_time < STUDY_BUILDUP_SECONDS:
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()
		_greedy_buy_spree(game)
		# Keep every owned property staffed at tier 1 (the Earth automation tier)
		# and restart anything idle — we want the dependable passive plateau.
		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			if prop.units_owned > 0:
				if prop.staff_tier < 1:
					game.try_hire(i)
				if not prop.is_cycle_running:
					game.tap_property(i)
		dynasty.tick(TICK_SIZE)
		sim_time += TICK_SIZE

	# The passive (staffed) rate excludes the temporary frenzy multiplier, so it is
	# the steady income the epoch climb actually runs on.
	return game.economy.get_passive_income_per_sec()


## Build a geometric ladder [1, step, step^2, ...] of `count` tiers (tier 1 = 1.0).
func _geometric_ladder(step: float, count: int) -> Array:
	var ladder: Array = []
	var value := 1.0
	for _i in range(count):
		ladder.append(value)
		value *= step
	return ladder


## Print, for one set of (economy_scale, staff_multiplier) ladders, how long each
## epoch takes given the measured base income, and the ratio vs. the previous epoch.
func _print_epoch_projection(economy_scale: Array, staff_mult: Array, base_ips: float) -> void:
	print("    epoch  econ_scale   staff_x    income/sec       must earn      duration     vs prev")
	var earth_target := _tuning.earth_economy_target
	var prev_threshold := 0.0
	var prev_duration := 0.0
	var total := 0.0
	for index in range(economy_scale.size()):
		var tier := index + 1
		var threshold := earth_target * float(economy_scale[index])
		var to_earn := threshold - prev_threshold
		var income := base_ips * float(staff_mult[index])
		var duration := to_earn / income if income > 0.0 else INF
		total += duration
		var ratio_text := "—"
		if prev_duration > 0.0 and is_finite(duration):
			ratio_text = "x%.1f" % (duration / prev_duration)
		print("    %4d   %10s   %7s   %12s   %12s   %10s   %7s" % [
			tier,
			_format_scale(float(economy_scale[index])),
			_format_scale(float(staff_mult[index])),
			Money.of(income).display() + "/s",
			Money.of(to_earn).display(),
			_format_duration(duration),
			ratio_text,
		])
		prev_threshold = threshold
		prev_duration = duration
	print("    total time across all %d epochs: %s" % [economy_scale.size(), _format_duration(total)])


## Compact magnitude label for the projection table (e.g. 1000 -> "1e3", 15 -> "15").
func _format_scale(value: float) -> String:
	if value >= 1000.0:
		return "1e%d" % int(round(log(value) / log(10.0)))
	return "%.0f" % value


## Human-readable duration: seconds / minutes / hours / days / years, whichever fits.
func _format_duration(seconds: float) -> String:
	if not is_finite(seconds):
		return "never"
	if seconds < 60.0:
		return "%.0f s" % seconds
	if seconds < 3600.0:
		return "%.1f m" % (seconds / 60.0)
	if seconds < 86400.0:
		return "%.1f h" % (seconds / 3600.0)
	if seconds < 31_536_000.0:
		return "%.1f d" % (seconds / 86400.0)
	return "%.1f y" % (seconds / 31_536_000.0)
