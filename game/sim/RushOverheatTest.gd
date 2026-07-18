extends SceneTree

# Headless verification for Rush Overheat — the push-your-luck heat model that replaced the
# hold-forever momentum ratchet (Tim 2026-07-15; design of record: Plans/Rush_Overheat.md),
# extended for VENT WINDOWS (Tim 2026-07-17; design of record: Plans/Overdrive_Vent_Windows.md).
#
# Usage: godot --headless --path . --script res://sim/RushOverheatTest.gd
#
# Proves, without any rendering:
#   1. Building 0 → Hot takes ~6 s of sustained rushing (the old build feel is preserved).
#   2. band_entered fires on the upward crossings, HOT then CRITICAL, in order.
#   3. Ignoring the vent telegraph is a MISS: the excursion overheats below the hard ceiling,
#      with vent_missed announcing the blown window first.
#   4. The lockout: rush disabled, bonus 0, heat drains at the locked rate, and rush_ready
#      fires only rearm_seconds AFTER the bar empties — then rushing re-enables.
#   5. A frenzy burn FREEZES everything: build, bleed, lockout drain, re-arm countdown, the
#      vent-window scheduler, and an open window's gesture clock.
#   6. reset() from mid-lockout restores a clean, rushable state (the First Contact wipe).
#   7. The piecewise bonus mapping hits the knob values exactly at each band edge.
#
# Cruise Control amendment (Plans/Rush_Cruise_Control.md) adds:
#   8. The cruise clamp holds indefinitely — a long hold without overdrive never overheats
#      and the bonus pins at the cruise knob (+25%).
#   9. engage_overdrive() releases the clamp and the climb resumes to a real overheat.
#  10. Overdrive disengages on release; re-holding starts back in safe cruise mode.
#  11. Legacy cruise points (Cooling Systems) raise the clamp, hard-capped at bonus_at_hot;
#      parked at heat 1.0 exactly, cruising never starts an excursion (the boundary rule).
#  12. The lockout time scale (Rapid Restart) halves the whole lockout at level 5.
#  13. DUTY CYCLE (legacy strategy): the cruise baseline vs the pre-vent-window "ride and
#      release" rhythm — kept as the historical comparison point for the new numbers.
#
# Vent Windows (Plans/Overdrive_Vent_Windows.md, ENDLESS ESCALATION rework 2026-07-18) add:
#  14. The scheduler is deterministic under a seeded rng (reproducible window times).
#  15. The gesture judge: clean single, double, AND triple; gap-too-long; an intermediate tap
#      held too long (on both the ×2 and ×3 gestures); expiry; and lifts on a closed window
#      being ignored.
#  16. The ladder math: peak bonuses follow bonus_peak + tier × vent_bonus_step with NO cap.
#  17. Venting clamps at critical_start (never OUT of Critical); the escalation curves follow
#      the knobs exactly — delay and duration decay geometrically to their floors, lifts step
#      1 → 2 → 3 and never exceed 3, and the windows NEVER stop arriving.
#  18. The miss penalty: the re-arm gains vent_fail_rearm_per_tier seconds per achieved tier,
#      CAPPED at vent_fail_rearm_cap, and Rapid Restart still scales the WHOLE lockout,
#      sting included.
#  19. The telegraph guarantee: across panel-plausible knob combos, EVERY window (deep tiers
#      included) opens with its full duration still ahead of the projected ceiling arrival.
#  20. AUTOPILOT SURVIVAL + DUTY CYCLE (measure, don't guess): modeled SKILLED (95% per-LIFT
#      success) and SLOPPY (70%) venters ride each excursion until they MISS — no bail —
#      reporting the survival curve (median / p90 tier reached) and the long-session average
#      bonus vs the cruise baseline.
#
# Exits with code 0 only if every check passes (1 otherwise), so CI/headless runs fail loudly.

## One logic tick, matching the game's 10 Hz timestep.
const TICK_SECONDS := 0.1

var _failures := 0


func _initialize() -> void:
	print("=== Rush Overheat + Vent Windows — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	if tuning == null:
		print("FAILED to load tuning config")
		quit(1)
		return

	_test_build_time_to_hot(tuning)
	_test_band_signals_and_missed_window(tuning)
	_test_overheat_lockout(tuning)
	_test_frenzy_freeze(tuning)
	_test_reset_mid_lockout(tuning)
	_test_bonus_mapping(tuning)
	_test_cruise_clamp(tuning)
	_test_overdrive_engage(tuning)
	_test_overdrive_disengages_on_release(tuning)
	_test_legacy_cruise_and_boundary(tuning)
	_test_legacy_lockout_scale(tuning)
	_measure_duty_cycle(tuning)
	_test_scheduler_determinism(tuning)
	_test_gesture_judge(tuning)
	_test_ladder_math(tuning)
	_test_vent_clamp_and_escalation(tuning)
	_test_miss_penalty(tuning)
	_test_telegraph_guarantee(tuning)
	_measure_vent_autopilot_survival(tuning)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Assert helper: prints a pass/fail line and counts failures.
func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


## A fresh heat state with a deterministic rng seed, so every run reproduces exactly.
## (The rng now rolls vent-window ARRIVAL times — the old random ceiling is retired.)
func _fresh_state(tuning: TuningConfig, seed_value: int) -> RushMomentumState:
	var state := RushMomentumState.new(tuning)
	state.rng.seed = seed_value
	return state


## Start a realistic overdrive ride: the finger goes down (so the gesture judge sees a held
## button when a window opens) and overdrive is engaged.
func _press_and_engage(state: RushMomentumState) -> void:
	state.notify_rush_pressed()
	state.engage_overdrive()


## Rush a pressed, engaged state until a vent window OPENS. Returns the seconds it took,
## or -1.0 if the state overheated (or the cap tripped) before a window arrived.
func _ride_to_window_open(state: RushMomentumState, cap_seconds := 30.0) -> float:
	var elapsed := 0.0
	while not state.is_vent_window_open() and not state.is_locked_out() and elapsed < cap_seconds:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	return elapsed if state.is_vent_window_open() else -1.0


## Perform a clean vent gesture of `lifts` lifts on brisk 0.1 s beats, well inside every
## tolerance: release → gap → re-press, with (lifts − 1) intermediate taps in between.
## Ticks keep rushing=true through the lifts, exactly as GameState does while a window is open.
func _perform_clean_gesture(state: RushMomentumState, lifts: int) -> void:
	state.notify_rush_released()
	state.tick(TICK_SECONDS, true, false)
	state.notify_rush_pressed()
	for _extra_lift in range(lifts - 1):
		state.tick(TICK_SECONDS, true, false)
		state.notify_rush_released()
		state.tick(TICK_SECONDS, true, false)
		state.notify_rush_pressed()


## Ride to the next `count` windows and vent each one cleanly (however many lifts each
## demands). Returns true only if every vent succeeded.
func _vent_cleanly(state: RushMomentumState, count: int) -> bool:
	for _i in range(count):
		var tier_before := state.vent_tier()
		if _ride_to_window_open(state) < 0.0:
			return false
		_perform_clean_gesture(state, state.vent_required_lifts())
		if state.vent_tier() != tier_before + 1:
			return false
	return true


## Rush a state upward until it overheats (or the safety cap trips). Returns the seconds spent.
## Engages overdrive first — since Cruise Control, a plain hold clamps safely at the cruise
## point, so reaching an overheat requires the opt-in (exactly like the OVERDRIVE button).
## The hold never performs the vent gesture, so the FIRST vent window expires and misses —
## since Vent Windows, that is what an ignored overdrive ride's overheat IS.
func _rush_until_overheat(state: RushMomentumState) -> float:
	_press_and_engage(state)
	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 60.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	return elapsed


func _test_build_time_to_hot(tuning: TuningConfig) -> void:
	print("1. Building 0 -> Hot takes ~6 s of sustained rushing")
	var state := _fresh_state(tuning, 1)
	# Overdrive so the climb runs past the cruise clamp — this section times the raw build rate.
	_press_and_engage(state)
	var elapsed := 0.0
	while state.heat < 1.0 and elapsed < 30.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	print("     (reached Hot at %.1f s)" % elapsed)
	_check("Hot edge reached between 5.5 and 6.5 s", elapsed >= 5.5 and elapsed <= 6.5)
	_check("bonus at the Hot edge ~= bonus_at_hot",
		absf(state.bonus - tuning.rush_momentum_bonus_at_hot) < 0.02)


func _test_band_signals_and_missed_window(tuning: TuningConfig) -> void:
	print("\n2 & 3. Band signals fire upward in order; an ignored vent window misses and overheats")
	var state := _fresh_state(tuning, 12345)
	var bands_entered: Array = []
	var overheat_count := [0]  # single-element array so the lambda can mutate it
	var windows_opened := [0]
	var misses: Array = []
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))
	state.overheated.connect(func() -> void: overheat_count[0] += 1)
	state.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: windows_opened[0] += 1)
	state.vent_missed.connect(func(done: int, required: int) -> void: misses.append([done, required]))

	_rush_until_overheat(state)
	_check("band_entered fired exactly twice on the way up", bands_entered.size() == 2)
	_check("first crossing was HOT",
		bands_entered.size() >= 1 and bands_entered[0] == RushMomentumState.Band.HOT)
	_check("second crossing was CRITICAL",
		bands_entered.size() >= 2 and bands_entered[1] == RushMomentumState.Band.CRITICAL)
	_check("exactly one vent window telegraphed before the shutdown", windows_opened[0] == 1)
	_check("the ignored window was judged a MISS with zero lifts done",
		misses.size() == 1 and misses[0][0] == 0)
	_check("overheated fired exactly once", overheat_count[0] == 1)
	print("     (missed the window and overheated at heat %.3f)" % state.heat)
	_check("the missed-window overheat lands inside Critical, below the hard ceiling",
		state.heat > tuning.rush_momentum_critical_start
			and state.heat < tuning.rush_momentum_hard_ceiling)

	# A second excursion rolls a fresh window ARRIVAL: the shutdown height differs because the
	# schedule (not the outcome) is the random part now — the anti-memorization property.
	var first_overheat_heat := state.heat
	state.reset()
	_rush_until_overheat(state)
	_check("second excursion also misses inside Critical",
		state.heat > tuning.rush_momentum_critical_start
			and state.heat < tuning.rush_momentum_hard_ceiling)
	_check("second excursion's window arrived at a different time (fresh schedule roll)",
		not is_equal_approx(state.heat, first_overheat_heat))


func _test_overheat_lockout(tuning: TuningConfig) -> void:
	print("\n4. The overheat lockout: dead rush, locked drain, then the re-arm delay")
	var state := _fresh_state(tuning, 777)
	var ready_fired := [false]
	state.rush_ready.connect(func() -> void: ready_fired[0] = true)
	_rush_until_overheat(state)

	_check("can_rush() is false immediately on overheat", not state.can_rush())
	_check("is_locked_out() is true", state.is_locked_out())
	_check("bonus is forced to 0", is_zero_approx(state.bonus))
	_check("factor() is 1.0 (no income bonus) during lockout", is_equal_approx(state.factor(), 1.0))

	# Drain rate: one second of lockout ticks sheds exactly locked_drain_per_second of heat.
	# rushing=true on purpose — taps during a lockout must not slow the drain.
	var heat_before := state.heat
	for _i in range(10):
		state.tick(TICK_SECONDS, true, false)
	var drained := heat_before - state.heat
	print("     (drained %.3f heat in 1 s; knob says %.3f)" % [drained, tuning.rush_momentum_locked_drain_per_second])
	_check("lockout drains at the locked rate (rush taps ignored)",
		absf(drained - tuning.rush_momentum_locked_drain_per_second) < 0.005)

	# Run the drain out, then time the re-arm: rush_ready fires only rearm_seconds AFTER empty.
	# (This excursion achieved no vent tiers, so there is no per-tier sting — section 18 covers it.)
	var elapsed := 0.0
	while state.heat > 0.0 and elapsed < 60.0:
		state.tick(TICK_SECONDS, false, false)
		elapsed += TICK_SECONDS
	_check("rush_ready has NOT fired when the bar first empties", not ready_fired[0])
	_check("is_rearming() is true once the bar is empty", state.is_rearming())
	_check("still locked out during the re-arm", state.is_locked_out() and not state.can_rush())
	var rearm_elapsed := 0.0
	while not ready_fired[0] and rearm_elapsed < 10.0:
		state.tick(TICK_SECONDS, false, false)
		rearm_elapsed += TICK_SECONDS
	print("     (rush_ready fired %.1f s after empty; knob says %.1f)" % [rearm_elapsed, tuning.rush_momentum_rearm_seconds])
	_check("rush_ready fired ~rearm_seconds after the bar emptied (tier-0 excursion: no sting)",
		absf(rearm_elapsed - tuning.rush_momentum_rearm_seconds) <= TICK_SECONDS + 0.001)
	_check("can_rush() is true again after rush_ready", state.can_rush())
	_check("no longer locked out or re-arming", not state.is_locked_out() and not state.is_rearming())
	_check("heat is 0 for the fresh climb", is_zero_approx(state.heat))


func _test_frenzy_freeze(tuning: TuningConfig) -> void:
	print("\n5. A frenzy burn freezes heat exactly (build, bleed, lockout, and vent clocks all halt)")

	# Mid-build freeze: rushing during a burn adds no heat, and the bonus holds.
	var state := _fresh_state(tuning, 42)
	for _i in range(30):  # 3 s of rushing -> ~0.5 heat
		state.tick(TICK_SECONDS, true, false)
	var heat_before := state.heat
	var bonus_before := state.bonus
	for _i in range(50):  # 5 s of frenzy, still holding rush
		state.tick(TICK_SECONDS, true, true)
	_check("no heat GAIN during a burn (rush held)", is_equal_approx(state.heat, heat_before))
	_check("bonus holds during a burn", is_equal_approx(state.bonus, bonus_before))

	# Bleed freeze: released during a burn, heat still does not drain.
	for _i in range(50):
		state.tick(TICK_SECONDS, false, true)
	_check("no heat BLEED during a burn (rush released)", is_equal_approx(state.heat, heat_before))

	# Lockout freeze: the locked drain halts too...
	var locked := _fresh_state(tuning, 43)
	_rush_until_overheat(locked)
	var locked_heat := locked.heat
	for _i in range(50):
		locked.tick(TICK_SECONDS, false, true)
	_check("lockout DRAIN halts during a burn", is_equal_approx(locked.heat, locked_heat))

	# ...and so does the re-arm countdown.
	var rearming := _fresh_state(tuning, 44)
	var ready_fired := [false]
	rearming.rush_ready.connect(func() -> void: ready_fired[0] = true)
	_rush_until_overheat(rearming)
	while rearming.heat > 0.0:
		rearming.tick(TICK_SECONDS, false, false)
	_check("(setup) re-arm delay is running", rearming.is_rearming())
	for _i in range(100):  # 10 s of frenzy — far beyond the 1.5 s re-arm
		rearming.tick(TICK_SECONDS, false, true)
	_check("re-arm COUNTDOWN halts during a burn (rush_ready never fired)",
		not ready_fired[0] and rearming.is_rearming())

	# Vent SCHEDULER freeze: with a window rolled but not yet open, a long burn never opens it
	# (the arrival countdown advances on tick delta only — no wall-clock leaks).
	var pending := _fresh_state(tuning, 45)
	var windows_opened := [0]
	pending.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: windows_opened[0] += 1)
	_press_and_engage(pending)
	while pending.current_band() != RushMomentumState.Band.CRITICAL:
		pending.tick(TICK_SECONDS, true, false)
	pending.tick(TICK_SECONDS, true, false)  # one Critical tick so the schedule is rolled
	for _i in range(200):  # 20 s of frenzy — far beyond delay_max
		pending.tick(TICK_SECONDS, true, true)
	_check("a PENDING window never opens during a burn (scheduler frozen)",
		windows_opened[0] == 0 and not pending.is_locked_out())

	# Open-window freeze: an OPEN window's countdown halts, so a burn can never expire it.
	var open_state := _fresh_state(tuning, 46)
	var open_missed := [0]
	open_state.vent_missed.connect(func(_done: int, _required: int) -> void: open_missed[0] += 1)
	_press_and_engage(open_state)
	_check("(setup) a window opened for the freeze probe", _ride_to_window_open(open_state) >= 0.0)
	var remaining_before := open_state.vent_window_remaining()
	for _i in range(50):  # 5 s of frenzy — far beyond the ~1 s window
		open_state.tick(TICK_SECONDS, true, true)
	_check("an OPEN window's countdown halts during a burn (no miss, time held)",
		open_state.is_vent_window_open() and open_missed[0] == 0
			and is_equal_approx(open_state.vent_window_remaining(), remaining_before))


func _test_reset_mid_lockout(tuning: TuningConfig) -> void:
	print("\n6. reset() from mid-lockout restores a clean rushable state (First Contact wipe)")
	var state := _fresh_state(tuning, 5)
	_rush_until_overheat(state)
	_check("(setup) state is locked out", state.is_locked_out())
	state.reset()
	_check("heat is 0 after reset", is_zero_approx(state.heat))
	_check("bonus is 0 after reset", is_zero_approx(state.bonus))
	_check("can_rush() is true after reset", state.can_rush())
	_check("not locked out or re-arming after reset",
		not state.is_locked_out() and not state.is_rearming())
	_check("band is BUILDING after reset", state.current_band() == RushMomentumState.Band.BUILDING)
	_check("vent ladder and window are wiped after reset",
		state.vent_tier() == 0 and not state.is_vent_window_open())
	# And the wiped state actually climbs again.
	state.tick(1.0, true, false)
	_check("a reset state builds heat again", state.heat > 0.0)


func _test_bonus_mapping(tuning: TuningConfig) -> void:
	print("\n7. The piecewise bonus mapping hits the formula at each probe point")
	var state := _fresh_state(tuning, 6)
	# Expected values from the knobs, so the test tracks any retune automatically:
	#   heat 0.5  -> halfway up Building         = bonus_at_hot / 2
	#   heat 1.0  -> the Hot edge                = bonus_at_hot
	#   heat 1.25 -> the Critical edge           = bonus_at_critical
	#   heat 1.5  -> partway through Critical    = lerp toward the tier-0 peak at hard_ceiling
	var critical_fraction := (1.5 - tuning.rush_momentum_critical_start) \
			/ (tuning.rush_momentum_hard_ceiling - tuning.rush_momentum_critical_start)
	var probes := [
		[0.5, tuning.rush_momentum_bonus_at_hot * 0.5],
		[1.0, tuning.rush_momentum_bonus_at_hot],
		[tuning.rush_momentum_critical_start, tuning.rush_momentum_bonus_at_critical],
		[1.5, lerpf(tuning.rush_momentum_bonus_at_critical, tuning.rush_momentum_bonus_peak,
				critical_fraction)],
	]
	for probe in probes:
		var probe_heat: float = probe[0]
		var expected: float = probe[1]
		var actual: float = state._bonus_for_heat(probe_heat)
		_check("bonus at heat %.2f is %.4f (got %.4f)" % [probe_heat, expected, actual],
			absf(actual - expected) < 0.0001)


func _test_cruise_clamp(tuning: TuningConfig) -> void:
	print("\n8. The cruise clamp: a plain hold is safe FOREVER, pinned at the cruise bonus")
	var state := _fresh_state(tuning, 99)
	var overheat_count := [0]
	var bands_entered: Array = []
	state.overheated.connect(func() -> void: overheat_count[0] += 1)
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))

	# 120 s of holding — twenty times the old time-to-Hot — without ever touching overdrive.
	for _i in range(1200):
		state.tick(TICK_SECONDS, true, false)

	print("     (heat settled at %.4f; cruise point is %.4f)" % [state.heat, state.cruise_heat()])
	_check("a long hold never overheats", overheat_count[0] == 0 and not state.is_locked_out())
	_check("heat is pinned at the cruise point", is_equal_approx(state.heat, state.cruise_heat()))
	_check("bonus is pinned at the cruise bonus (+%d%%)" % int(round(tuning.rush_momentum_cruise_bonus * 100.0)),
		is_equal_approx(state.bonus, tuning.rush_momentum_cruise_bonus))
	_check("effective_cruise_bonus() matches the knob (no Legacy points bought)",
		is_equal_approx(state.effective_cruise_bonus(), tuning.rush_momentum_cruise_bonus))
	_check("is_cruising() is true during the hold", state.is_cruising())
	_check("is_overdrive_engaged() is false", not state.is_overdrive_engaged())
	_check("no band signal fired (cruise sits inside Building)", bands_entered.is_empty())
	_check("band is BUILDING at the clamp", state.current_band() == RushMomentumState.Band.BUILDING)


func _test_overdrive_engage(tuning: TuningConfig) -> void:
	print("\n9. engage_overdrive() releases the clamp: the climb resumes to a real overheat")
	var state := _fresh_state(tuning, 100)
	var bands_entered: Array = []
	var missed := [0]
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))
	state.vent_missed.connect(func(_done: int, _required: int) -> void: missed[0] += 1)

	# Settle into the cruise clamp first, then opt in.
	state.notify_rush_pressed()
	for _i in range(100):  # 10 s — well past the ~5 s climb to the clamp
		state.tick(TICK_SECONDS, true, false)
	_check("(setup) parked at the cruise clamp", is_equal_approx(state.heat, state.cruise_heat()))
	state.engage_overdrive()
	_check("is_overdrive_engaged() is true after the tap", state.is_overdrive_engaged())
	_check("is_cruising() is false once overdrive is engaged", not state.is_cruising())

	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 60.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	print("     (overheated %.1f s after engaging, at heat %.3f)" % [elapsed, state.heat])
	_check("the resumed climb reaches a real overheat", state.is_locked_out())
	_check("the overheat was the ignored window's MISS, below the hard ceiling",
		missed[0] == 1 and state.heat < tuning.rush_momentum_hard_ceiling)
	_check("HOT and CRITICAL both announced on the way up",
		bands_entered == [RushMomentumState.Band.HOT, RushMomentumState.Band.CRITICAL])
	_check("overdrive disengaged by the overheat", not state.is_overdrive_engaged())


func _test_overdrive_disengages_on_release(tuning: TuningConfig) -> void:
	print("\n10. Overdrive is per-excursion: releasing the hold disengages it")
	var state := _fresh_state(tuning, 101)
	_press_and_engage(state)
	# Ride ~2 s past the cruise point — above the clamp but still safely inside Hot, below
	# Critical, so no vent window can be scheduled during the ride.
	for _i in range(70):  # 7 s: ~6 s to the Hot edge plus ~1 s into Hot
		state.tick(TICK_SECONDS, true, false)
	_check("(setup) rode above the cruise point without overheating",
		state.heat > state.cruise_heat() and not state.is_locked_out())
	_check("(setup) overdrive engaged mid-ride", state.is_overdrive_engaged())

	# One released tick = the hold ended. That alone must disengage overdrive.
	state.notify_rush_released()
	state.tick(TICK_SECONDS, false, false)
	_check("one non-rushing tick disengages overdrive", not state.is_overdrive_engaged())

	# Re-holding WITHOUT tapping overdrive again is back in cruise mode: heat left over from
	# the ride bleeds DOWN to the cruise point (never sustained for free) and pins there.
	var overheat_count := [0]
	state.overheated.connect(func() -> void: overheat_count[0] += 1)
	state.notify_rush_pressed()
	for _i in range(300):  # 30 s of plain holding
		state.tick(TICK_SECONDS, true, false)
	_check("the re-hold is cruising again", state.is_cruising())
	_check("leftover ride heat bled back down to the cruise point",
		is_equal_approx(state.heat, state.cruise_heat()))
	_check("the re-hold never overheats", overheat_count[0] == 0)


func _test_legacy_cruise_and_boundary(tuning: TuningConfig) -> void:
	print("\n11. Legacy cruise points raise the clamp (capped at bonus_at_hot); heat 1.0 is safe")

	# The LegacyUpgrades getters map catalog levels to the values the state consumes.
	var upgrades := LegacyUpgrades.new()
	upgrades.levels = {
		LegacyUpgradeCatalog.COOLING_SYSTEMS: 5,
		LegacyUpgradeCatalog.RAPID_RESTART: 5,
	}
	_check("Cooling Systems level 5 grants +0.05 cruise points",
		absf(upgrades.cruise_bonus_points() - 0.05) < 0.0001)
	_check("Rapid Restart level 5 halves the lockout scale",
		absf(upgrades.overheat_lockout_scale() - 0.5) < 0.0001)

	# Max Cooling Systems: cruise = bonus_at_hot, so the clamp sits at heat 1.0 EXACTLY.
	var state := _fresh_state(tuning, 102)
	state.legacy_cruise_bonus = upgrades.cruise_bonus_points()
	_check("max-Legacy effective cruise bonus equals bonus_at_hot",
		is_equal_approx(state.effective_cruise_bonus(), tuning.rush_momentum_bonus_at_hot))
	_check("max-Legacy cruise point is heat 1.0 exactly", is_equal_approx(state.cruise_heat(), 1.0))

	# The min() is the hard guarantee: even absurd Legacy points can never push cruise past
	# the old +30% cap (Hot/Critical bonuses stay exclusive to overdrive).
	var over_capped := _fresh_state(tuning, 103)
	over_capped.legacy_cruise_bonus = 0.50
	_check("cruise bonus hard-caps at bonus_at_hot no matter the Legacy points",
		is_equal_approx(over_capped.effective_cruise_bonus(), tuning.rush_momentum_bonus_at_hot))

	# THE BOUNDARY RULE: parked at heat 1.0 while cruising must not start an excursion or read
	# as Hot — Building is inclusive of 1.0; only overdrive pushing PAST the tick opens the ride.
	var overheat_count := [0]
	var bands_entered: Array = []
	state.overheated.connect(func() -> void: overheat_count[0] += 1)
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))
	state.notify_rush_pressed()
	for _i in range(600):  # 60 s parked at the tick
		state.tick(TICK_SECONDS, true, false)
	_check("heat parks at 1.0 exactly", is_equal_approx(state.heat, 1.0))
	_check("bonus pins at bonus_at_hot (the re-earned old cap)",
		is_equal_approx(state.bonus, tuning.rush_momentum_bonus_at_hot))
	_check("heat AT 1.0 while cruising still reads as BUILDING (never Hot)",
		state.current_band() == RushMomentumState.Band.BUILDING)
	_check("no excursion started at the boundary (no band signal, no overheat)",
		bands_entered.is_empty() and overheat_count[0] == 0)

	# And engaging overdrive from that exact boundary starts a normal excursion PAST the tick.
	state.engage_overdrive()
	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 60.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	_check("overdrive from the 1.0 boundary rides to a normal overheat",
		state.is_locked_out() and bands_entered.size() == 2)


func _test_legacy_lockout_scale(tuning: TuningConfig) -> void:
	print("\n12. Rapid Restart at level 5 halves the whole lockout (drain AND re-arm together)")
	# Same seed = the same window schedule, so the two lockouts start from identical heat and
	# the only difference is the scale.
	var baseline := _fresh_state(tuning, 104)
	var halved := _fresh_state(tuning, 104)
	halved.lockout_time_scale = 0.5

	var baseline_time := _measure_lockout_seconds(baseline)
	var halved_time := _measure_lockout_seconds(halved)
	print("     (lockout: %.1f s at scale 1.0, %.1f s at scale 0.5)" % [baseline_time, halved_time])
	_check("the halved lockout is ~half the baseline (within tick rounding)",
		absf(halved_time - baseline_time / 2.0) <= 3.0 * TICK_SECONDS + 0.001)


## Overheat a state, then time the full lockout: from the overheat moment until rush_ready.
func _measure_lockout_seconds(state: RushMomentumState) -> float:
	var ready_fired := [false]
	state.rush_ready.connect(func() -> void: ready_fired[0] = true)
	_rush_until_overheat(state)
	var elapsed := 0.0
	while not ready_fired[0] and elapsed < 60.0:
		state.tick(TICK_SECONDS, false, false)
		elapsed += TICK_SECONDS
	return elapsed


## The LEGACY balance measurement (kept as the historical comparison point): the pre-vent-window
## "skilled" strategy rode heat up to 1.30 and released back to 1.00, never venting a window
## (the ride's ~0.7 s of Critical per lap is far shorter than the earliest window arrival, so
## no window ever opens). Its average vs cruise is the +10.3% edge Tim judged too small — the
## number the vent-window autopilot (section 20) exists to beat.
func _measure_duty_cycle(tuning: TuningConfig) -> void:
	print("\n13. LEGACY DUTY CYCLE — cruise baseline vs the old ride/release rhythm, 120 s")
	const RIDE_TOP := 1.30   # release point: barely into Critical, gone before a window arrives
	const VENT_BOTTOM := 1.0  # re-engage point, the Hot edge
	var total_seconds := 120.0

	# Baseline: the zone-out player just holds forever in cruise (no overdrive, no venting).
	var cruise_state := _fresh_state(tuning, 2025)
	var cruise_overheated := [false]
	cruise_state.overheated.connect(func() -> void: cruise_overheated[0] = true)
	var cruise_bonus_seconds := 0.0
	var cruise_elapsed := 0.0
	while cruise_elapsed < total_seconds:
		cruise_state.tick(TICK_SECONDS, true, false)
		cruise_elapsed += TICK_SECONDS
		cruise_bonus_seconds += cruise_state.bonus * TICK_SECONDS
	var cruise_average := cruise_bonus_seconds / total_seconds
	_check("the cruise hold never overheats", not cruise_overheated[0])

	# The old gamble: ride to the top of the safe zone and release, over and over.
	var state := _fresh_state(tuning, 2026)
	state.engage_overdrive()
	var overheated_during_run := [false]
	state.overheated.connect(func() -> void: overheated_during_run[0] = true)

	var rushing := true
	var total_bonus_seconds := 0.0
	var elapsed := 0.0
	while elapsed < total_seconds:
		state.tick(TICK_SECONDS, rushing, false)
		elapsed += TICK_SECONDS
		total_bonus_seconds += state.bonus * TICK_SECONDS
		# The old rhythm: release at the ride top, re-engage at the Hot edge.
		# Each re-engage taps OVERDRIVE again — the release tick disengaged it (per-excursion).
		if rushing and state.heat >= RIDE_TOP:
			rushing = false
		elif not rushing and state.heat <= VENT_BOTTOM:
			rushing = true
			state.engage_overdrive()

	var average_bonus := total_bonus_seconds / total_seconds
	_check("the old ride/release rhythm never overheats (windows never get time to open)",
		not overheated_during_run[0])
	print("  >>> CRUISE BASELINE AVERAGE BONUS: +%.1f%% (holds at +%.0f%% forever, zero risk) <<<"
			% [cruise_average * 100.0, cruise_state.effective_cruise_bonus() * 100.0])
	print("  >>> OLD RIDE/RELEASE AVERAGE BONUS: +%.1f%% — the pre-vent-window comparison <<<"
			% [average_bonus * 100.0])


func _test_scheduler_determinism(tuning: TuningConfig) -> void:
	print("\n14. The window scheduler is deterministic under a seeded rng")
	# Two identically seeded states must produce identical window times AND identical
	# missed-window overheat heights; a different seed must diverge.
	var first := _fresh_state(tuning, 555)
	var second := _fresh_state(tuning, 555)
	_press_and_engage(first)
	_press_and_engage(second)
	var first_open := _ride_to_window_open(first)
	var second_open := _ride_to_window_open(second)
	print("     (seed 555 opened its first window at %.1f s in both runs)" % first_open)
	_check("same seed opens the first window at the same time",
		first_open >= 0.0 and is_equal_approx(first_open, second_open))

	# Ride the same-seed pair to their (missed) overheat: identical shutdown heights.
	var first_elapsed := 0.0
	while not first.is_locked_out() and first_elapsed < 30.0:
		first.tick(TICK_SECONDS, true, false)
		first_elapsed += TICK_SECONDS
	var second_elapsed := 0.0
	while not second.is_locked_out() and second_elapsed < 30.0:
		second.tick(TICK_SECONDS, true, false)
		second_elapsed += TICK_SECONDS
	_check("same seed reproduces the same missed-window overheat height",
		first.is_locked_out() and is_equal_approx(first.heat, second.heat))

	# Different seeds must actually vary. One pair of seeds CAN legitimately collide — open
	# times are quantized to the 0.1 s tick across a ~1 s delay range — so probe a handful of
	# seeds and require the first-window time to vary somewhere in the batch.
	var open_times_varied := false
	for probe_seed in range(556, 562):
		var probe := _fresh_state(tuning, probe_seed)
		_press_and_engage(probe)
		if not is_equal_approx(_ride_to_window_open(probe), first_open):
			open_times_varied = true
			break
	_check("different seeds roll different window arrivals (across a seed batch)",
		open_times_varied)


func _test_gesture_judge(tuning: TuningConfig) -> void:
	print("\n15. The gesture judge: clean gestures succeed, blown beats miss, closed windows ignore")

	# --- Clean single, double, and triple, on one continuous ride up the endless ladder ---
	# With lifts_step_tiers = 3 the demanded lifts are 1 at tiers 0-2, 2 at tiers 3-5, and 3
	# from tier 6 (capped there). Ride through all three gesture classes cleanly.
	var lifts_step := maxi(tuning.rush_momentum_vent_lifts_step_tiers, 1)
	var state := _fresh_state(tuning, 700)
	var lifts: Array = []
	var successes: Array = []
	var misses: Array = []
	state.vent_lift_registered.connect(func(done: int, required: int) -> void: lifts.append([done, required]))
	state.vent_succeeded.connect(func(tier: int, peak: float) -> void: successes.append([tier, peak]))
	state.vent_missed.connect(func(done: int, required: int) -> void: misses.append([done, required]))
	_press_and_engage(state)
	_check("(setup) first window opened", _ride_to_window_open(state) >= 0.0)
	_check("the first window (tier 0) demands the SINGLE feather", state.vent_required_lifts() == 1)
	var heat_before_vent := state.heat
	_perform_clean_gesture(state, 1)
	_check("clean single lift succeeds the vent", successes.size() == 1 and state.vent_tier() == 1)
	_check("the single's lift beat was registered as 1 of 1",
		lifts.size() == 1 and lifts[0][0] == 1 and lifts[0][1] == 1)
	_check("success vented heat downward", state.heat < heat_before_vent)
	_check("the window closed on success",
		not state.is_vent_window_open() and is_zero_approx(state.vent_window_remaining()))

	# Vent up to the first DOUBLE window (tiers 1 and 2 still demand singles on the way).
	_check("(setup) vented through the remaining single tiers",
		_vent_cleanly(state, lifts_step - 1) and state.vent_tier() == lifts_step)
	_check("(setup) tier-%d window opened" % lifts_step, _ride_to_window_open(state) >= 0.0)
	_check("the tier-%d window demands the DOUBLE release (lifts_step_tiers)" % lifts_step,
		state.vent_required_lifts() == 2)
	lifts.clear()
	_perform_clean_gesture(state, 2)
	_check("clean double release succeeds the vent",
		successes.size() == lifts_step + 1 and state.vent_tier() == lifts_step + 1)
	_check("both lift beats were registered in order (1 of 2, then 2 of 2)",
		lifts.size() == 2 and lifts[0][0] == 1 and lifts[1][0] == 2)

	# Vent up to the first TRIPLE window (the rest of the double tiers on the way).
	_check("(setup) vented through the remaining double tiers",
		_vent_cleanly(state, lifts_step - 1) and state.vent_tier() == 2 * lifts_step)
	_check("(setup) tier-%d window opened" % (2 * lifts_step), _ride_to_window_open(state) >= 0.0)
	_check("the tier-%d window demands the TRIPLE pump" % (2 * lifts_step),
		state.vent_required_lifts() == 3)
	lifts.clear()
	_perform_clean_gesture(state, 3)
	_check("clean triple pump succeeds the vent",
		successes.size() == 2 * lifts_step + 1 and state.vent_tier() == 2 * lifts_step + 1)
	_check("all three lift beats were registered in order (1, 2, 3 of 3)",
		lifts.size() == 3 and lifts[0][0] == 1 and lifts[1][0] == 2 and lifts[2][0] == 3)
	_check("no miss fired during the clean gestures", misses.is_empty())

	# --- Gap too long: lift, then hover past vent_gap_max without re-pressing ---
	var gap_state := _fresh_state(tuning, 701)
	var gap_misses: Array = []
	var gap_overheated := [0]
	gap_state.vent_missed.connect(func(done: int, required: int) -> void: gap_misses.append([done, required]))
	gap_state.overheated.connect(func() -> void: gap_overheated[0] += 1)
	_press_and_engage(gap_state)
	_check("(setup) window opened for the gap-too-long case", _ride_to_window_open(gap_state) >= 0.0)
	gap_state.notify_rush_released()
	var gap_ticks := int(ceil((tuning.rush_momentum_vent_gap_max + 0.2) / TICK_SECONDS))
	for _i in range(gap_ticks):
		gap_state.tick(TICK_SECONDS, true, false)
	_check("a gap past vent_gap_max is a MISS (0 lifts done) and overheats",
		gap_misses.size() == 1 and gap_misses[0][0] == 0 and gap_overheated[0] == 1)

	# --- Tap too long: on a double window, hold the middle tap past vent_tap_max ---
	var tap_ticks := int(ceil((tuning.rush_momentum_vent_tap_max + 0.2) / TICK_SECONDS))
	var tap_state := _fresh_state(tuning, 702)
	var tap_misses: Array = []
	tap_state.vent_missed.connect(func(done: int, required: int) -> void: tap_misses.append([done, required]))
	_press_and_engage(tap_state)
	_check("(setup) vented to the first double window", _vent_cleanly(tap_state, lifts_step))
	_check("(setup) double window opened", _ride_to_window_open(tap_state) >= 0.0
			and tap_state.vent_required_lifts() == 2)
	tap_state.notify_rush_released()
	tap_state.tick(TICK_SECONDS, true, false)
	tap_state.notify_rush_pressed()  # the middle tap goes down (lift 1 registers)...
	for _i in range(tap_ticks):  # ...and never comes back up in time
		tap_state.tick(TICK_SECONDS, true, false)
	_check("a middle tap held past vent_tap_max is a MISS showing 1 of 2 lifts done",
		tap_misses.size() == 1 and tap_misses[0][0] == 1 and tap_misses[0][1] == 2
			and tap_state.is_locked_out())

	# --- SECOND tap too long: on a triple window, land the first tap cleanly but hold the
	# second one — the miss feedback must show the gesture died at 2 of 3 lifts ---
	var second_tap_state := _fresh_state(tuning, 705)
	var second_tap_misses: Array = []
	second_tap_state.vent_missed.connect(func(done: int, required: int) -> void:
		second_tap_misses.append([done, required]))
	_press_and_engage(second_tap_state)
	_check("(setup) vented to the first triple window", _vent_cleanly(second_tap_state, 2 * lifts_step))
	_check("(setup) triple window opened", _ride_to_window_open(second_tap_state) >= 0.0
			and second_tap_state.vent_required_lifts() == 3)
	second_tap_state.notify_rush_released()
	second_tap_state.tick(TICK_SECONDS, true, false)
	second_tap_state.notify_rush_pressed()   # first tap down (lift 1)
	second_tap_state.tick(TICK_SECONDS, true, false)
	second_tap_state.notify_rush_released()  # first tap up, in time
	second_tap_state.tick(TICK_SECONDS, true, false)
	second_tap_state.notify_rush_pressed()   # second tap down (lift 2)...
	for _i in range(tap_ticks):  # ...held like a re-hold — but a third lift was still owed
		second_tap_state.tick(TICK_SECONDS, true, false)
	_check("a SECOND tap held past vent_tap_max is a MISS showing 2 of 3 lifts done",
		second_tap_misses.size() == 1 and second_tap_misses[0][0] == 2
			and second_tap_misses[0][1] == 3 and second_tap_state.is_locked_out())

	# --- Expiry: hold straight through the window without ever lifting ---
	var expiry_state := _fresh_state(tuning, 703)
	var expiry_misses: Array = []
	expiry_state.vent_missed.connect(func(done: int, required: int) -> void: expiry_misses.append([done, required]))
	_press_and_engage(expiry_state)
	_check("(setup) window opened for the expiry case", _ride_to_window_open(expiry_state) >= 0.0)
	var expiry_ticks := int(ceil((tuning.rush_momentum_vent_window_duration + 0.2) / TICK_SECONDS))
	for _i in range(expiry_ticks):
		expiry_state.tick(TICK_SECONDS, true, false)
	_check("holding through the whole window is a MISS (0 lifts done) and overheats",
		expiry_misses.size() == 1 and expiry_misses[0][0] == 0 and expiry_state.is_locked_out())

	# --- Lifts on a CLOSED window are ordinary taps: no signals, no state damage ---
	var closed_state := _fresh_state(tuning, 704)
	var closed_signals := [0]
	closed_state.vent_lift_registered.connect(func(_done: int, _required: int) -> void: closed_signals[0] += 1)
	closed_state.vent_succeeded.connect(func(_tier: int, _peak: float) -> void: closed_signals[0] += 1)
	closed_state.vent_missed.connect(func(_done: int, _required: int) -> void: closed_signals[0] += 1)
	_press_and_engage(closed_state)
	for _i in range(30):  # 3 s: still climbing Building — far from any window
		closed_state.tick(TICK_SECONDS, true, false)
	for _i in range(3):  # rapid lift/re-press flurry with no window open
		closed_state.notify_rush_released()
		closed_state.tick(TICK_SECONDS, true, false)
		closed_state.notify_rush_pressed()
		closed_state.tick(TICK_SECONDS, true, false)
	_check("lifts with no window open emit no vent signals and change no vent state",
		closed_signals[0] == 0 and closed_state.vent_tier() == 0
			and not closed_state.is_locked_out())


func _test_ladder_math(tuning: TuningConfig) -> void:
	print("\n16. The reward ladder: peak bonus climbs by vent_bonus_step per tier, UNBOUNDED")
	# 8 rungs — twice the old tier cap — proves the formula keeps climbing where the cap
	# used to sit, without dragging the section into a marathon.
	const LADDER_PROBE_TIERS := 8
	var state := _fresh_state(tuning, 800)
	_press_and_engage(state)
	var expected_peaks: Array = []
	for tier in range(LADDER_PROBE_TIERS + 1):
		expected_peaks.append(tuning.rush_momentum_bonus_peak
				+ tier * tuning.rush_momentum_vent_bonus_step)
	print("     (expected peaks by tier: %s)" % [expected_peaks])

	_check("tier 0 peak is %.2f" % expected_peaks[0],
		absf(state.current_peak_bonus() - expected_peaks[0]) < 0.0001)
	_check("tier 0 bonus AT the hard ceiling equals the tier-0 peak",
		absf(state._bonus_for_heat(tuning.rush_momentum_hard_ceiling) - expected_peaks[0]) < 0.0001)
	for tier in range(1, LADDER_PROBE_TIERS + 1):
		if not _vent_cleanly(state, 1):
			_check("(setup) vent to tier %d succeeded" % tier, false)
			return
		_check("tier %d peak is %.2f" % [tier, expected_peaks[tier]],
			absf(state.current_peak_bonus() - expected_peaks[tier]) < 0.0001)
		_check("tier %d bonus AT the hard ceiling equals its peak" % tier,
			absf(state._bonus_for_heat(tuning.rush_momentum_hard_ceiling) - expected_peaks[tier]) < 0.0001)


func _test_vent_clamp_and_escalation(tuning: TuningConfig) -> void:
	print("\n17. Venting clamps INSIDE Critical; the escalation curves follow the knobs")

	# Clamp: with an absurdly large vent drop, a success still lands exactly at critical_start —
	# venting keeps you IN Critical, never back to safety (the ratchet is the reward, not an exit).
	var deep_drop: TuningConfig = tuning.duplicate()
	deep_drop.rush_momentum_vent_heat_drop = 5.0
	var clamp_state := _fresh_state(deep_drop, 900)
	_press_and_engage(clamp_state)
	_check("(setup) clamp-case vent succeeded", _vent_cleanly(clamp_state, 1))
	_check("an oversized vent clamps heat at critical_start exactly",
		is_equal_approx(clamp_state.heat, deep_drop.rush_momentum_critical_start))
	_check("the vented state still reads as CRITICAL",
		clamp_state.current_band() == RushMomentumState.Band.CRITICAL)

	# The escalation curves: ride 10 clean vents — past the retired 4-tier cap — capturing
	# every window's demanded lifts and duration, and check each against the knob formulas.
	const ESCALATION_PROBE_VENTS := 10
	var lifts_step := maxi(tuning.rush_momentum_vent_lifts_step_tiers, 1)
	var esc := _fresh_state(tuning, 901)
	var opens: Array = []  # [tier the window opened at, demanded lifts, duration]
	esc.vent_window_opened.connect(func(lifts: int, duration: float) -> void:
		opens.append([esc.vent_tier(), lifts, duration]))
	_press_and_engage(esc)
	_check("(setup) windows NEVER stop: %d clean vents on the endless ladder" % ESCALATION_PROBE_VENTS,
		_vent_cleanly(esc, ESCALATION_PROBE_VENTS)
			and esc.vent_tier() == ESCALATION_PROBE_VENTS)
	var durations_match := true
	var lifts_match := true
	var lifts_capped := true
	for open_variant in opens:
		var entry: Array = open_variant
		var tier: int = entry[0]
		var expected_duration: float = maxf(tuning.rush_momentum_vent_window_duration
				* pow(tuning.rush_momentum_vent_duration_decay, tier),
				tuning.rush_momentum_vent_duration_floor)
		var expected_lifts: int = mini(1 + tier / lifts_step, 3)
		if absf(float(entry[2]) - expected_duration) > 0.0001:
			durations_match = false
		if int(entry[1]) != expected_lifts:
			lifts_match = false
		if int(entry[1]) > 3:
			lifts_capped = false
	print("     (windows seen, by tier: %s)" % [opens])
	_check("every window's duration follows base x duration_decay^tier (floored)", durations_match)
	_check("every window's demanded lifts follow 1 + tier / lifts_step_tiers", lifts_match)
	_check("no window ever demanded more than 3 lifts", lifts_capped)

	# The floors, white-box at an absurd depth (tier 40): both decays have long bottomed out.
	# Poking _vent_tier directly is fair game here — riding 40 real vents would test nothing new.
	var deep := _fresh_state(tuning, 902)
	deep._vent_tier = 40
	_check("duration bottoms out at duration_floor",
		is_equal_approx(deep._next_window_duration(), tuning.rush_momentum_vent_duration_floor))
	_check("demanded lifts bottom out at the 3-lift cap",
		deep._next_window_required_lifts() == 3)
	# Delay floor: schedule from the bottom of Critical (nowhere near the ceiling, so the
	# telegraph clamp stays out of the way) and read the rolled arrival back.
	deep.heat = tuning.rush_momentum_critical_start
	deep._schedule_next_window()
	_check("arrival delay bottoms out at delay_floor",
		is_equal_approx(deep._window_arrival_remaining, tuning.rush_momentum_vent_delay_floor))


func _test_miss_penalty(tuning: TuningConfig) -> void:
	print("\n18. The miss penalty: per-tier re-arm sting (capped), still scaled whole by Rapid Restart")
	# Same seed and same script twice, so both runs overheat from identical heat at tier 2;
	# the only difference in the second run is the Rapid Restart scale.
	var baseline := _fresh_state(tuning, 950)
	var discounted := _fresh_state(tuning, 950)
	discounted.lockout_time_scale = 0.5

	var baseline_result := _overheat_at_tier(baseline, 2)
	var discounted_result := _overheat_at_tier(discounted, 2)

	var expected_drain: float = baseline_result["overheat_heat"] / tuning.rush_momentum_locked_drain_per_second
	var expected_rearm: float = tuning.rush_momentum_rearm_seconds \
			+ minf(2.0 * tuning.rush_momentum_vent_fail_rearm_per_tier,
					tuning.rush_momentum_vent_fail_rearm_cap)
	var expected_total := expected_drain + expected_rearm
	print("     (tier-2 lockout: measured %.1f s, expected %.1f s = %.1f drain + %.1f re-arm)"
			% [baseline_result["lockout_seconds"], expected_total, expected_drain, expected_rearm])
	_check("both runs overheated after exactly two clean vents, from the same heat",
		baseline_result["clean_vents"] == 2 and discounted_result["clean_vents"] == 2
			and is_equal_approx(baseline_result["overheat_heat"], discounted_result["overheat_heat"]))
	_check("the lockout includes the per-tier re-arm sting",
		absf(baseline_result["lockout_seconds"] - expected_total) <= 4.0 * TICK_SECONDS + 0.001)
	print("     (Rapid Restart 0.5: measured %.1f s vs %.1f s baseline)"
			% [discounted_result["lockout_seconds"], baseline_result["lockout_seconds"]])
	_check("Rapid Restart halves the WHOLE lockout, sting included",
		absf(discounted_result["lockout_seconds"] - baseline_result["lockout_seconds"] / 2.0)
			<= 3.0 * TICK_SECONDS + 0.001)

	# THE CAP (Tim 2026-07-18): a deep fall must not earn an ever-longer timeout. Pick a tier
	# whose uncapped sting would exceed the cap and verify the lockout uses the cap instead.
	var deep_tier := int(ceil(tuning.rush_momentum_vent_fail_rearm_cap
			/ maxf(tuning.rush_momentum_vent_fail_rearm_per_tier, 0.001))) + 1
	var capped := _fresh_state(tuning, 951)
	var capped_result := _overheat_at_tier(capped, deep_tier)
	var capped_expected: float = capped_result["overheat_heat"] / tuning.rush_momentum_locked_drain_per_second \
			+ tuning.rush_momentum_rearm_seconds + tuning.rush_momentum_vent_fail_rearm_cap
	print("     (tier-%d lockout: measured %.1f s, cap-expected %.1f s — uncapped would add +%.1f s)"
			% [deep_tier, capped_result["lockout_seconds"], capped_expected,
			deep_tier * tuning.rush_momentum_vent_fail_rearm_per_tier
					- tuning.rush_momentum_vent_fail_rearm_cap])
	_check("(setup) the deep run reached tier %d before its scripted miss" % deep_tier,
		capped_result["clean_vents"] == deep_tier)
	_check("the per-tier sting is CAPPED at vent_fail_rearm_cap",
		absf(capped_result["lockout_seconds"] - capped_expected) <= 4.0 * TICK_SECONDS + 0.001)


## Vent `tier` times cleanly, then keep holding without venting so the excursion overheats at
## that tier (via the next ignored window or the hard ceiling — whichever the schedule reaches
## first; the per-tier sting applies to both overheat causes identically). Returns the clean
## vents performed, the heat the overheat fell from, and the full lockout length.
func _overheat_at_tier(state: RushMomentumState, tier: int) -> Dictionary:
	var ready_fired := [false]
	var clean_vents := [0]
	state.rush_ready.connect(func() -> void: ready_fired[0] = true)
	state.vent_succeeded.connect(func(_tier: int, _peak: float) -> void: clean_vents[0] += 1)
	_press_and_engage(state)
	_vent_cleanly(state, tier)
	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 30.0:  # ride on, ignoring the next window
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	var overheat_heat := state.heat
	var lockout_seconds := 0.0
	while not ready_fired[0] and lockout_seconds < 120.0:
		state.tick(TICK_SECONDS, false, false)
		lockout_seconds += TICK_SECONDS
	return {
		"clean_vents": clean_vents[0],
		"overheat_heat": overheat_heat,
		"lockout_seconds": lockout_seconds,
	}


func _test_telegraph_guarantee(tuning: TuningConfig) -> void:
	print("\n19. The telegraph guarantee holds across panel-plausible knob combos, at EVERY tier")
	# For each combo, EVERY window — the first AND the escalated deep-tier ones, where the
	# cadence is fastest and heat rides closest to the ceiling — must open with its full
	# duration still ahead of the projected hard-ceiling arrival: heat_at_open + duration ×
	# build_hot <= hard_ceiling (plus one tick of slack, since the open is quantized to the
	# tick that notices the delay elapsed). Each seed rides a clean multi-vent excursion so the
	# checks sample the whole escalation curve, and each combo runs several seeds so the roll
	# can't get lucky.
	var combos := [
		{"label": "defaults", "delay_max": tuning.rush_momentum_vent_window_delay_max,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration},
		{"label": "delay_max 8", "delay_max": 8.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration},
		{"label": "build_hot x2", "delay_max": tuning.rush_momentum_vent_window_delay_max,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second * 2.0,
			"duration": tuning.rush_momentum_vent_window_duration},
		{"label": "delay_max 8 + build_hot x2", "delay_max": 8.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second * 2.0,
			"duration": tuning.rush_momentum_vent_window_duration},
		{"label": "delay_max 8 + duration 1.5", "delay_max": 8.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": 1.5},
	]
	for combo_variant in combos:
		var combo: Dictionary = combo_variant
		var combo_tuning: TuningConfig = tuning.duplicate()
		combo_tuning.rush_momentum_vent_window_delay_max = combo["delay_max"]
		combo_tuning.rush_momentum_heat_build_hot_per_second = combo["build_hot"]
		combo_tuning.rush_momentum_vent_window_duration = combo["duration"]
		var all_seeds_ok := true
		for seed_value in range(1, 6):
			var state := _fresh_state(combo_tuning, 3000 + seed_value)
			var open_info: Array = []  # [heat_at_open, duration] captured at each open moment
			state.vent_window_opened.connect(func(_lifts: int, duration: float) -> void:
				open_info.append([state.heat, duration]))
			_press_and_engage(state)
			# 8 clean vents = 9 window opens sampled per seed, from tier 0 into the deep curve.
			if not _vent_cleanly(state, 8) or _ride_to_window_open(state, 60.0) < 0.0:
				all_seeds_ok = false
				continue
			# One tick of build-rate slack: the open is noticed on a tick boundary.
			var slack: float = combo["build_hot"] * TICK_SECONDS + 0.0001
			for info_variant in open_info:
				var info: Array = info_variant
				var heat_at_open: float = info[0]
				var open_duration: float = info[1]
				if heat_at_open + open_duration * combo["build_hot"] \
						> combo_tuning.rush_momentum_hard_ceiling + slack:
					all_seeds_ok = false
		_check("[%s] every window (all tiers) fully fits before the ceiling" % combo["label"],
			all_seeds_ok)


func _measure_vent_autopilot_survival(tuning: TuningConfig) -> void:
	print("\n20. AUTOPILOT SURVIVAL + DUTY CYCLE — ride-until-you-miss venters vs cruise, %d s x %d seeds"
			% [int(AUTOPILOT_SECONDS), AUTOPILOT_SEED_RUNS])

	# Cruise baseline: the zone-out player holds forever, zero risk.
	var cruise_state := _fresh_state(tuning, 4000)
	var cruise_bonus_seconds := 0.0
	var cruise_ticks := int(round(AUTOPILOT_SECONDS / TICK_SECONDS))
	for _i in range(cruise_ticks):
		cruise_state.tick(TICK_SECONDS, true, false)
		cruise_bonus_seconds += cruise_state.bonus * TICK_SECONDS
	var cruise_average := cruise_bonus_seconds / AUTOPILOT_SECONDS

	# The modeled venters: identical policy — hold with overdrive on, gesture on every window
	# after a 0.3 s reaction, RIDE UNTIL THE MISS (the endless ladder has no cap to bail at;
	# every excursion ends in flames by design), remount when re-armed. Only the gesture
	# reliability differs. Averaged over several seeds — one 600 s session's fumble luck
	# swings the average by a couple of points, enough to mislead a retune.
	var skilled := _run_vent_autopilot_seeds(tuning, 4001, 0.95)
	var sloppy := _run_vent_autopilot_seeds(tuning, 4002, 0.70)

	var skilled_median := _tier_percentile(skilled["excursion_tiers"], 0.5)
	var skilled_p90 := _tier_percentile(skilled["excursion_tiers"], 0.9)
	var sloppy_median := _tier_percentile(sloppy["excursion_tiers"], 0.5)
	var sloppy_p90 := _tier_percentile(sloppy["excursion_tiers"], 0.9)

	print("")
	print("  >>> CRUISE BASELINE AVERAGE BONUS:  +%.1f%% (zero risk, zero skill) <<<"
			% [cruise_average * 100.0])
	print("  >>> SKILLED VENTER (95%% per lift):  +%.1f%% avg | survival median tier %d, p90 tier %d (%d runs) <<<"
			% [skilled["average_bonus"] * 100.0, skilled_median, skilled_p90,
			(skilled["excursion_tiers"] as Array).size()])
	print("  >>> SLOPPY VENTER  (70%% per lift):  +%.1f%% avg | survival median tier %d, p90 tier %d (%d runs) <<<"
			% [sloppy["average_bonus"] * 100.0, sloppy_median, sloppy_p90,
			(sloppy["excursion_tiers"] as Array).size()])
	print("      (skilled: %d vents, %d overheats — %d fumbled, %d outpaced by the deep-tier windows;"
			% [skilled["vents"], skilled["overheats"],
			skilled["missed_windows"] - skilled["outpaced_windows"], skilled["outpaced_windows"]])
	print("       sloppy:  %d vents, %d overheats — %d fumbled, %d outpaced)"
			% [sloppy["vents"], sloppy["overheats"],
			sloppy["missed_windows"] - sloppy["outpaced_windows"], sloppy["outpaced_windows"]])
	print("      (per-seed time split, skilled: %.0f s Critical / %.0f s climbing / %.0f s locked out;"
			% [skilled["critical_seconds"], skilled["climbing_seconds"], skilled["locked_seconds"]])
	print("       per-seed time split, sloppy:  %.0f s Critical / %.0f s climbing / %.0f s locked out)"
			% [sloppy["critical_seconds"], sloppy["climbing_seconds"], sloppy["locked_seconds"]])
	print("      (targets: skilled median run tier ~6-10 with average >= the v1 +62%;")
	print("       sloppy at or below cruise, so the risk stays real)")
	_check("the skilled venter's median run reaches tier 6-10 (the survival target)",
		skilled_median >= 6 and skilled_median <= 10)
	_check("the skilled venter averages at least the v1 +62% (worth the risk)",
		skilled["average_bonus"] >= 0.62)
	_check("the sloppy venter lands at or below cruise (the risk is real)",
		sloppy["average_bonus"] <= cruise_average + 0.005)
	_check("every skilled run eventually ends in an overheat (the endless ladder's designed ending)",
		skilled["overheats"] >= 1)
	_check("no CLEAN, in-time gesture was ever judged a miss (autopilot and judge agree on the rules)",
		skilled["clean_missed"] == 0 and sloppy["clean_missed"] == 0)


## Average _run_vent_autopilot over AUTOPILOT_SEED_RUNS seeds. average_bonus and the time
## splits come back as per-seed means; vents/overheats/misses as totals across all seeds;
## excursion_tiers as one pooled array (the survival curve's samples).
func _run_vent_autopilot_seeds(tuning: TuningConfig, base_seed: int, gesture_success: float) -> Dictionary:
	var totals := {
		"average_bonus": 0.0, "vents": 0, "overheats": 0, "missed_windows": 0,
		"clean_missed": 0, "outpaced_windows": 0, "excursion_tiers": [],
		"locked_seconds": 0.0, "critical_seconds": 0.0, "climbing_seconds": 0.0,
	}
	for s in range(AUTOPILOT_SEED_RUNS):
		var run := _run_vent_autopilot(tuning, base_seed + s * 100, gesture_success)
		totals["average_bonus"] += run["average_bonus"] / AUTOPILOT_SEED_RUNS
		totals["vents"] += run["vents"]
		totals["overheats"] += run["overheats"]
		totals["missed_windows"] += run["missed_windows"]
		totals["clean_missed"] += run["clean_missed"]
		totals["outpaced_windows"] += run["outpaced_windows"]
		(totals["excursion_tiers"] as Array).append_array(run["excursion_tiers"])
		totals["locked_seconds"] += run["locked_seconds"] / AUTOPILOT_SEED_RUNS
		totals["critical_seconds"] += run["critical_seconds"] / AUTOPILOT_SEED_RUNS
		totals["climbing_seconds"] += run["climbing_seconds"] / AUTOPILOT_SEED_RUNS
	return totals


## The survival curve's percentile read: the tier at `fraction` of the way up the sorted
## excursion-end tiers (0.5 = median, 0.9 = p90). Returns -1 when no excursion ever ended.
func _tier_percentile(tiers_variant: Variant, fraction: float) -> int:
	var tiers: Array = (tiers_variant as Array).duplicate()
	if tiers.is_empty():
		return -1
	tiers.sort()
	return tiers[int(round(fraction * (tiers.size() - 1)))]


## How long the autopilot rides for. Long enough that the skilled venter's ~5% miss rate is
## actually sampled (a miss only comes up once every ~15-20 windows).
const AUTOPILOT_SECONDS := 600.0

## Independent 600 s sessions averaged per profile — a single seed's fumble luck swings the
## average by a couple of points, enough to mislead a retune.
const AUTOPILOT_SEED_RUNS := 5

## Ticks the autopilot waits after a window telegraphs before starting the gesture — a human
## reaction beat (0.3 s), per the plan's modeled-venter spec.
const AUTOPILOT_REACTION_TICKS := 3


## The modeled venter (the CarbAutopilot lesson: measure the economy, don't guess it).
## Policy: hold with overdrive engaged; on every window, react after 0.3 s and perform the
## demanded gesture on brisk 0.1 s beats (a PER-LIFT skill roll decides whether each beat
## lands cleanly); RIDE UNTIL THE MISS — the endless ladder has no cap to bail at, so the excursion
## ends when a gesture is fumbled or a deep-tier window shrinks below what even a clean plan
## can finish in time (the designed difficulty wall); after any overheat, remount when re-armed.
func _run_vent_autopilot(tuning: TuningConfig, seed_value: int, gesture_success: float) -> Dictionary:
	var state := _fresh_state(tuning, seed_value)
	# The skill dice are a SEPARATE seeded rng, so the venter's fumbles can't perturb the
	# window-schedule rolls (both stay reproducible run to run).
	var skill_rng := RandomNumberGenerator.new()
	skill_rng.seed = seed_value * 7919 + 13

	var tick_index := [0]        # arrays so the signal lambdas can read/mutate them
	var pressed := [true]
	var vents := [0]
	var overheats := [0]
	var missed_windows := [0]
	var clean_missed := [0]     # misses despite a clean IN-TIME plan — 0 or the judge has a bug
	var outpaced_windows := [0]  # clean plans the window was too short to fit — the difficulty wall
	var planned_clean := [false]
	var planned_fits := [false]
	var excursion_tier := [0]    # vents THIS excursion — the survival stat, read at each overheat
	var excursion_tiers: Array = []
	# Scheduled gesture edges, keyed by absolute tick index -> "press" or "release". Edges are
	# executed just before that tick, like real input events arriving between logic ticks.
	var planned: Dictionary = {}

	state.vent_succeeded.connect(func(_tier: int, _peak: float) -> void:
		vents[0] += 1
		excursion_tier[0] += 1)
	state.vent_missed.connect(func(_done: int, _required: int) -> void:
		missed_windows[0] += 1
		if planned_clean[0] and planned_fits[0]:
			clean_missed[0] += 1
		elif planned_clean[0]:
			outpaced_windows[0] += 1)
	state.overheated.connect(func() -> void:
		overheats[0] += 1
		excursion_tiers.append(excursion_tier[0])
		excursion_tier[0] = 0
		planned.clear())
	state.vent_window_opened.connect(func(required_lifts: int, duration: float) -> void:
		var base: int = tick_index[0] + AUTOPILOT_REACTION_TICKS
		# The skill dice roll PER LIFT, not per window — a triple pump is three chances to blow
		# a beat, so the complexity axis (escalation axis 3) is a real difficulty in the model,
		# exactly as it is under a thumb. (With one roll per window, demanding more lifts would
		# change nothing for the modeled venters and the axis would test nothing.)
		var fumble_at_lift := -1
		for lift in range(1, required_lifts + 1):
			if skill_rng.randf() >= gesture_success:
				fumble_at_lift = lift
				break
		planned_clean[0] = fumble_at_lift < 0
		# Whether even a clean plan can finish inside the window: the last press must land
		# before the expiry tick. Reaction + (2 x lifts - 1) edges on 0.1 s beats needs the
		# window to outlast (reaction + 2 x lifts - 2) ticks. When it can't, the miss is the
		# DESIGNED difficulty wall, not a judge bug — counted apart from the canary.
		planned_fits[0] = duration \
				> float(AUTOPILOT_REACTION_TICKS + 2 * required_lifts - 2) * TICK_SECONDS + 0.0001
		# Plan the gesture on brisk 0.1 s beats — release then press per lift, comfortably
		# inside every tolerance. A fumble at lift k truncates the plan after k's release:
		# the finger lifts but the re-press never comes, the gap times out, MISS.
		var edge_count := 2 * required_lifts if fumble_at_lift < 0 else 2 * fumble_at_lift - 1
		for edge in range(edge_count):
			planned[base + edge] = "release" if edge % 2 == 0 else "press")

	state.notify_rush_pressed()
	state.engage_overdrive()

	var total_bonus_seconds := 0.0
	# Where the run's time actually went — the breakdown that tells a retune WHICH phase to
	# attack (riding pay vs recovery drag), instead of guessing from the average alone.
	var locked_seconds := 0.0
	var critical_seconds := 0.0
	var climbing_seconds := 0.0
	var total_ticks := int(round(AUTOPILOT_SECONDS / TICK_SECONDS))
	for _t in range(total_ticks):
		if state.is_locked_out():
			state.tick(TICK_SECONDS, false, false)
			tick_index[0] += 1
			locked_seconds += TICK_SECONDS
			if not state.is_locked_out():
				# Re-armed: straight back on the ride (the modeled venter never sulks).
				pressed[0] = true
				state.notify_rush_pressed()
				state.engage_overdrive()
			continue
		if planned.has(tick_index[0]):
			if planned[tick_index[0]] == "press":
				pressed[0] = true
				state.notify_rush_pressed()
			else:
				pressed[0] = false
				state.notify_rush_released()
			planned.erase(tick_index[0])
		# Mirror GameState's hold rule: an open window counts as rushing through the lifts.
		var rushing: bool = pressed[0] or state.is_vent_window_open()
		state.tick(TICK_SECONDS, rushing, false)
		tick_index[0] += 1
		total_bonus_seconds += state.bonus * TICK_SECONDS
		if state.current_band() == RushMomentumState.Band.CRITICAL:
			critical_seconds += TICK_SECONDS
		else:
			climbing_seconds += TICK_SECONDS
	return {
		"average_bonus": total_bonus_seconds / AUTOPILOT_SECONDS,
		"vents": vents[0],
		"overheats": overheats[0],
		"missed_windows": missed_windows[0],
		"clean_missed": clean_missed[0],
		"outpaced_windows": outpaced_windows[0],
		"excursion_tiers": excursion_tiers,
		"locked_seconds": locked_seconds,
		"critical_seconds": critical_seconds,
		"climbing_seconds": climbing_seconds,
	}
