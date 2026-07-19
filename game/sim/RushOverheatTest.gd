extends SceneTree

# Headless verification for Rush Overheat — the push-your-luck heat model that replaced the
# hold-forever momentum ratchet (Tim 2026-07-15; design of record: Plans/Rush_Overheat.md),
# extended for VENT WINDOWS (Tim 2026-07-17; design of record: Plans/Overdrive_Vent_Windows.md).
#
# Usage: godot --headless --path . --script res://sim/RushOverheatTest.gd
#
# Proves, without any rendering (DEPTH-HAZARD model, Tim 2026-07-18 evening — the Critical
# band is retired; windows arrive from a per-tick hazard that rises with heat depth):
#   1. Building 0 → heat 1.0 takes ~6 s of sustained rushing (the old build feel is preserved).
#   2. band_entered fires exactly once, on the upward 1.0 crossing, emitting OVERDRIVE.
#   3. Ignoring the vent telegraph is a MISS: the excursion overheats below the hard ceiling,
#      with vent_missed announcing the blown window first.
#   4. The lockout: rush disabled, bonus 0, heat drains at the locked rate, and rush_ready
#      fires only rearm_seconds AFTER the bar empties — then rushing re-enables.
#   5. A frenzy burn FREEZES everything: build, bleed, lockout drain, re-arm countdown, the
#      hazard dice, an in-flight event's approach clock, and an open window's gesture clock.
#   6. reset() from mid-lockout restores a clean, rushable state (the First Contact wipe).
#   7. The bonus mapping: the Building segment hits its knob values, and the overdrive span
#      is ONE continuous lerp — sampled densely, monotone, with NO kink where the old band
#      edges used to sit.
#
# Cruise Control amendment (Plans/Rush_Cruise_Control.md) adds:
#   8. The cruise clamp holds indefinitely — a long hold without overdrive never overheats
#      and the bonus pins at the cruise knob (+25%).
#   9. engage_overdrive() releases the clamp and the climb resumes to a real overheat.
#  10. Overdrive disengages on release; re-holding starts back in safe cruise mode.
#  11. Legacy cruise points (Cooling Systems) raise the clamp, hard-capped at bonus_at_hot;
#      parked at heat 1.0 exactly, cruising never starts an excursion (the boundary rule).
#  12. The lockout time scale (Rapid Restart) halves the whole lockout at level 5.
#  13. DUTY CYCLE (legacy strategy): the cruise baseline, plus proof that the pre-vent-window
#      "ride and release" dodge is DEAD — the depth hazard reaches below the retired Critical
#      zone, so the old rhythm now eats the overheat it used to sidestep.
#
# Vent Windows (Plans/Overdrive_Vent_Windows.md; endless escalation + depth hazard) add:
#  14. The hazard is deterministic under a seeded rng (reproducible window times).
#  15. The gesture judge: clean single, double, AND triple; gap-too-long; an intermediate tap
#      held too long (on both the ×2 and ×3 gestures); expiry; and lifts on a closed window
#      being ignored.
#  16. The ladder math: peak bonuses follow bonus_peak + tier × vent_bonus_step with NO cap.
#  17. Venting floors at the cruise point (success never ends the ride); the escalation curves
#      follow the knobs exactly — duration decays geometrically to its floor, lifts step
#      1 → 2 → 3 and never exceed 3, and the windows NEVER stop arriving.
#  18. The miss penalty: the re-arm gains vent_fail_rearm_per_tier seconds per achieved tier,
#      CAPPED at vent_fail_rearm_cap, and Rapid Restart still scales the WHOLE lockout,
#      sting included.
#  19. The telegraph guarantee: across panel-plausible knob combos — now including a stretched
#      approach 4.0 — EVERY window (deep tiers included) opens with its full duration still
#      ahead of the projected ceiling arrival (the force-spawn reserves approach + window).
#  20. THE DEPTH HAZARD ITSELF (statistical): with heat pinned shallow vs deep, the measured
#      event SPAWN rates match the lerped knob rates — and their ratio matches the knobs'
#      ratio — within a loose seeded tolerance.
#  21. AUTOPILOT SURVIVAL + DUTY CYCLE (measure, don't guess): modeled SKILLED (95% per-LIFT
#      success) and SLOPPY (70%) venters ride each excursion until they MISS — no bail —
#      reporting the survival curve (median / p90 tier reached) and the long-session average
#      bonus vs the cruise baseline.
#
# The approach phase (Tim 2026-07-19 — the hazard roll SPAWNS an event that travels for
# vent_approach_seconds before its window opens) adds:
#  22. vent_incoming leads vent_window_opened by exactly approach_seconds of tick time, the
#      announced lifts always equal the opened window's demand (across the whole escalation),
#      and only one event is ever in flight or open at a time.
#  23. An in-flight approach cancels SILENTLY on release, overheat, and reset — no miss, no
#      lockout, and no phantom window later (an open only ever follows a fresh spawn's full
#      approach).
#
# The vent REFRACTORY (Tim 2026-07-18 night — a rolled quiet spell after every resolved vent
# and every fresh engage, so post-vent arrivals stop feeling metronomic) adds:
#  24. Post-vent gaps vary run to run, never undercut refractory_min, and once the deep
#      top-off clamp engages they are bounded by refractory_max plus tick slack (the
#      force-spawn tail); the engage-time roll is clamped so the telegraph guarantee still
#      holds even re-engaging hot near the force-spawn bound; the freeze checks in section 5
#      cover the refractory clock too.
#
# The lockout's visual re-arm timer (Tim 2026-07-18 night) adds, inside section 4:
#  25. rearm_remaining_fraction() is 0 while riding and while the drain runs, exactly 1.0 the
#      moment the re-arm delay starts, monotonically decreasing, and 0.0 at rush_ready.
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
	_test_depth_hazard_statistics(tuning)
	_measure_vent_autopilot_survival(tuning)
	_test_approach_phase(tuning)
	_test_approach_cancellation(tuning)
	_test_vent_refractory_spacing(tuning)

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
## (The rng now rolls the per-tick window hazard — the old random ceiling is retired.)
func _fresh_state(tuning: TuningConfig, seed_value: int) -> RushMomentumState:
	var state := RushMomentumState.new(tuning)
	state.rng.seed = seed_value
	return state


## Start a realistic overdrive ride: the finger goes down (so the gesture judge sees a held
## button when a window opens) and overdrive is engaged.
func _press_and_engage(state: RushMomentumState) -> void:
	state.notify_rush_pressed()
	state.engage_overdrive()


## Rush a pressed, engaged state until a vent window OPENS (riding through the approach phase
## in between). Returns the seconds it took, or -1.0 if the state overheated (or the cap
## tripped) before a window arrived.
func _ride_to_window_open(state: RushMomentumState, cap_seconds := 30.0) -> float:
	var elapsed := 0.0
	while not state.is_vent_window_open() and not state.is_locked_out() and elapsed < cap_seconds:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	return elapsed if state.is_vent_window_open() else -1.0


## Rush a pressed, engaged state until a vent event SPAWNS (vent_incoming fires — the approach
## flight begins). Returns the seconds it took, or -1.0 if the state overheated (or the cap
## tripped) before an event went in flight.
func _ride_to_approach(state: RushMomentumState, cap_seconds := 30.0) -> float:
	var elapsed := 0.0
	while not state.is_vent_approaching() and not state.is_locked_out() and elapsed < cap_seconds:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	return elapsed if state.is_vent_approaching() else -1.0


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
	print("1. Building 0 -> heat 1.0 takes ~6 s of sustained rushing")
	var state := _fresh_state(tuning, 1)
	# Overdrive so the climb runs past the cruise clamp — this section times the raw build rate.
	_press_and_engage(state)
	var elapsed := 0.0
	while state.heat < 1.0 and elapsed < 30.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	print("     (reached heat 1.0 at %.1f s)" % elapsed)
	_check("heat 1.0 reached between 5.5 and 6.5 s", elapsed >= 5.5 and elapsed <= 6.5)
	_check("bonus at heat 1.0 ~= bonus_at_hot",
		absf(state.bonus - tuning.rush_momentum_bonus_at_hot) < 0.02)


func _test_band_signals_and_missed_window(tuning: TuningConfig) -> void:
	print("\n2 & 3. The OVERDRIVE crossing announces once; an ignored vent window misses and overheats")
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
	# The hazard CAN legitimately open a window below heat 1.0 (it runs from the cruise point
	# up), so the crossing signal is "at most once, always OVERDRIVE" — with this seed the
	# ride crosses 1.0 before its first window, so exactly once.
	_check("band_entered fired exactly once on the way up (the 1.0 crossing)",
		bands_entered.size() == 1)
	_check("the crossing announced OVERDRIVE",
		bands_entered.size() >= 1 and bands_entered[0] == RushMomentumState.Band.OVERDRIVE)
	_check("exactly one vent window telegraphed before the shutdown", windows_opened[0] == 1)
	_check("the ignored window was judged a MISS with zero lifts done",
		misses.size() == 1 and misses[0][0] == 0)
	_check("overheated fired exactly once", overheat_count[0] == 1)
	print("     (missed the window and overheated at heat %.3f)" % state.heat)
	_check("the missed-window overheat lands in the hazard zone, below the hard ceiling",
		state.heat > state.cruise_heat()
			and state.heat < tuning.rush_momentum_hard_ceiling)

	# A second excursion rolls fresh hazard dice: the shutdown height differs because the
	# schedule (not the outcome) is the random part now — the anti-memorization property.
	var first_overheat_heat := state.heat
	state.reset()
	_rush_until_overheat(state)
	_check("second excursion also misses in the hazard zone, below the ceiling",
		state.heat > state.cruise_heat()
			and state.heat < tuning.rush_momentum_hard_ceiling)
	_check("second excursion's window arrived at a different time (fresh hazard rolls)",
		not is_equal_approx(state.heat, first_overheat_heat))


func _test_overheat_lockout(tuning: TuningConfig) -> void:
	print("\n4. The overheat lockout: dead rush, locked drain, then the re-arm delay")
	var state := _fresh_state(tuning, 777)
	var ready_fired := [false]
	state.rush_ready.connect(func() -> void: ready_fired[0] = true)
	# The visual re-arm timer's getter reads 0 during ordinary riding (nothing is re-arming).
	for _i in range(20):
		state.tick(TICK_SECONDS, true, false)
	_check("rearm_remaining_fraction() is 0 during normal riding",
		is_zero_approx(state.rearm_remaining_fraction()))
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
	# The visual re-arm timer's getter must stay flat 0 through the DRAIN phase — the UI's
	# receding gray may only start moving when the re-arm countdown actually exists.
	_check("rearm_remaining_fraction() is 0 while the drain still runs",
		is_zero_approx(state.rearm_remaining_fraction()))

	# Run the drain out, then time the re-arm: rush_ready fires only rearm_seconds AFTER empty.
	# (This excursion achieved no vent tiers, so there is no per-tier sting — section 18 covers it.)
	var elapsed := 0.0
	while state.heat > 0.0 and elapsed < 60.0:
		state.tick(TICK_SECONDS, false, false)
		elapsed += TICK_SECONDS
	_check("rush_ready has NOT fired when the bar first empties", not ready_fired[0])
	_check("is_rearming() is true once the bar is empty", state.is_rearming())
	_check("still locked out during the re-arm", state.is_locked_out() and not state.can_rush())
	# The tick that emptied the bar also STARTED the re-arm delay, so the fraction reads its
	# full 1.0 right now — the UI's gray covers the whole bar at this exact moment.
	_check("rearm_remaining_fraction() is exactly 1.0 the moment the re-arm delay starts",
		is_equal_approx(state.rearm_remaining_fraction(), 1.0))
	var fraction_monotone := true
	var last_fraction := state.rearm_remaining_fraction()
	var rearm_elapsed := 0.0
	while not ready_fired[0] and rearm_elapsed < 10.0:
		state.tick(TICK_SECONDS, false, false)
		rearm_elapsed += TICK_SECONDS
		var fraction := state.rearm_remaining_fraction()
		if fraction > last_fraction + 0.0001:
			fraction_monotone = false
		last_fraction = fraction
	_check("rearm_remaining_fraction() fell monotonically and reads 0.0 at rush_ready",
		fraction_monotone and is_zero_approx(state.rearm_remaining_fraction()))
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

	# HAZARD freeze: parked deep in the hazard zone (rate near its relentless top), a long burn
	# never opens a window — the dice simply are not rolled on frozen ticks. Heat is poked
	# straight to depth (white-box, like the sim's other deep probes) so the setup itself
	# cannot consume hazard rolls on the way up.
	var deep_burn := _fresh_state(tuning, 45)
	var windows_opened := [0]
	deep_burn.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: windows_opened[0] += 1)
	_press_and_engage(deep_burn)
	deep_burn.heat = 1.4  # deep: the per-tick hazard here would fire within a second or two
	for _i in range(200):  # 20 s of frenzy — dozens of expected windows if the dice rolled
		deep_burn.tick(TICK_SECONDS, true, true)
	_check("the hazard never opens a window during a burn (dice frozen)",
		windows_opened[0] == 0 and not deep_burn.is_locked_out())
	_check("deep heat holds exactly through the burn", is_equal_approx(deep_burn.heat, 1.4))

	# REFRACTORY freeze: the rolled post-engage quiet spell halts on frozen ticks too — it is
	# a vent clock like any other, and a burn draining it would silently eat the randomized
	# spacing the refractory exists to provide.
	var refractory_state := _fresh_state(tuning, 48)
	_press_and_engage(refractory_state)  # engaging rolls the refractory
	var refractory_before := refractory_state.vent_refractory_remaining()
	_check("(setup) engaging rolled a live refractory", refractory_before > 0.0)
	for _i in range(50):  # 5 s of frenzy — several times the longest possible roll
		refractory_state.tick(TICK_SECONDS, true, true)
	_check("the refractory clock halts during a burn",
		is_equal_approx(refractory_state.vent_refractory_remaining(), refractory_before))

	# APPROACH freeze: an in-flight event's approach clock halts too, so a burn can neither
	# advance the flight nor open its window (an open mid-frenzy would shortchange the lead
	# the player was promised to watch).
	var approach_state := _fresh_state(tuning, 47)
	var approach_opened := [0]
	approach_state.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: approach_opened[0] += 1)
	_press_and_engage(approach_state)
	_check("(setup) an event went in flight for the freeze probe", _ride_to_approach(approach_state) >= 0.0)
	var approach_before := approach_state.vent_approach_remaining()
	for _i in range(100):  # 10 s of frenzy — several times the whole approach
		approach_state.tick(TICK_SECONDS, true, true)
	_check("an in-flight APPROACH halts during a burn (no open, travel time held)",
		approach_state.is_vent_approaching() and approach_opened[0] == 0
			and is_equal_approx(approach_state.vent_approach_remaining(), approach_before))

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
	print("\n7. The bonus mapping hits the formula at each probe point, with NO kink above 1.0")
	var state := _fresh_state(tuning, 6)
	var hard_ceiling := tuning.rush_momentum_hard_ceiling
	# Expected values from the knobs, so the test tracks any retune automatically:
	#   heat 0.5      -> halfway up Building        = bonus_at_hot / 2
	#   heat 1.0      -> the overdrive edge         = bonus_at_hot
	#   heat midway   -> half the overdrive span    = lerp(bonus_at_hot, tier-0 peak, 0.5)
	#   hard ceiling  -> the tier-0 ladder peak     = bonus_peak
	var overdrive_midpoint := (1.0 + hard_ceiling) / 2.0
	var probes := [
		[0.5, tuning.rush_momentum_bonus_at_hot * 0.5],
		[1.0, tuning.rush_momentum_bonus_at_hot],
		[overdrive_midpoint,
				lerpf(tuning.rush_momentum_bonus_at_hot, tuning.rush_momentum_bonus_peak, 0.5)],
		[hard_ceiling, tuning.rush_momentum_bonus_peak],
	]
	for probe in probes:
		var probe_heat: float = probe[0]
		var expected: float = probe[1]
		var actual: float = state._bonus_for_heat(probe_heat)
		_check("bonus at heat %.2f is %.4f (got %.4f)" % [probe_heat, expected, actual],
			absf(actual - expected) < 0.0001)

	# NO-KINK continuity sweep (the depth-hazard rework's whole point at the mapping level):
	# sample the overdrive span densely and require the bonus to climb monotonically with every
	# step bounded near the span's uniform slope — a leftover band edge would show up as either
	# a jump (step too large) or a slope break (a run of steps well off uniform).
	const KINK_SAMPLE_STEP := 0.005
	var uniform_step := (tuning.rush_momentum_bonus_peak - tuning.rush_momentum_bonus_at_hot) \
			/ (hard_ceiling - 1.0) * KINK_SAMPLE_STEP
	var monotone := true
	var max_step := 0.0
	var previous := state._bonus_for_heat(1.0)
	var sample_heat := 1.0 + KINK_SAMPLE_STEP
	while sample_heat <= hard_ceiling + 0.0001:
		var sample: float = state._bonus_for_heat(minf(sample_heat, hard_ceiling))
		var step := sample - previous
		if step < -0.0000001:
			monotone = false
		max_step = maxf(max_step, step)
		previous = sample
		sample_heat += KINK_SAMPLE_STEP
	print("     (dense sweep 1.0..%.2f: max step %.6f, uniform step %.6f)"
			% [hard_ceiling, max_step, uniform_step])
	_check("the overdrive bonus climbs monotonically across the whole span", monotone)
	_check("no sampled step exceeds 1.5x the uniform slope (no kink, no jump)",
		max_step <= uniform_step * 1.5 + 0.0000001)


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
	_check("the OVERDRIVE crossing announced once on the way up",
		bands_entered == [RushMomentumState.Band.OVERDRIVE])
	_check("overdrive disengaged by the overheat", not state.is_overdrive_engaged())


func _test_overdrive_disengages_on_release(tuning: TuningConfig) -> void:
	print("\n10. Overdrive is per-excursion: releasing the hold disengages it")
	var state := _fresh_state(tuning, 101)
	_press_and_engage(state)
	# Ride ~2 s past the cruise point — shallow in the hazard zone. A check CAN arrive during
	# even this shallow ride under the depth hazard, so vent any window cleanly: this section
	# is about RELEASE semantics, and the setup must not die to an ignored telegraph.
	for _i in range(70):  # 7 s: ~6 s to heat 1.0 plus ~1 s of overdrive build
		state.tick(TICK_SECONDS, true, false)
		if state.is_vent_window_open():
			_perform_clean_gesture(state, state.vent_required_lifts())
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
	# the old +30% cap (overdrive bonuses stay exclusive to overdrive).
	var over_capped := _fresh_state(tuning, 103)
	over_capped.legacy_cruise_bonus = 0.50
	_check("cruise bonus hard-caps at bonus_at_hot no matter the Legacy points",
		is_equal_approx(over_capped.effective_cruise_bonus(), tuning.rush_momentum_bonus_at_hot))

	# THE BOUNDARY RULE: parked at heat 1.0 while cruising must not start an excursion or read
	# as OVERDRIVE — Building is inclusive of 1.0; only overdrive pushing PAST the tick opens the ride.
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
	_check("heat AT 1.0 while cruising still reads as BUILDING (never OVERDRIVE)",
		state.current_band() == RushMomentumState.Band.BUILDING)
	_check("no excursion started at the boundary (no band signal, no overheat)",
		bands_entered.is_empty() and overheat_count[0] == 0)

	# And engaging overdrive from that exact boundary starts a normal excursion PAST the tick.
	state.engage_overdrive()
	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 60.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	# Only ONE crossing signal exists now: pushing past the parked-at-1.0 boundary is it.
	_check("overdrive from the 1.0 boundary rides to a normal overheat",
		state.is_locked_out() and bands_entered == [RushMomentumState.Band.OVERDRIVE])


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


## The LEGACY balance measurement, reworked for the depth hazard: the pre-vent-window "skilled"
## strategy rode heat to 1.30 and released back to 1.00, and under the old zone scheduler that
## dodged every check (its Critical time per lap was shorter than any window's arrival). The
## depth hazard closes that loophole — checks can arrive ANYWHERE past the cruise point — so
## the old rhythm now eats the overheat it used to sidestep. This section keeps the cruise
## baseline number and PROVES the dodge is dead; the honest overdrive numbers live in the
## autopilot (section 21).
func _measure_duty_cycle(tuning: TuningConfig) -> void:
	print("\n13. LEGACY DUTY CYCLE — cruise baseline; the old ride/release dodge is dead, 120 s")
	const RIDE_TOP := 1.30    # the old release point
	const VENT_BOTTOM := 1.0  # the old re-engage point
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

	# The old gamble: ride toward the ceiling and release, over and over, never gesturing.
	# Each lap now spends seconds inside the hazard zone ignoring whatever window opens —
	# an expected ~1-2 checks per lap — so over 120 s an overheat is a statistical certainty.
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
		# The old rhythm: release at the ride top, re-engage at heat 1.0.
		# Each re-engage taps OVERDRIVE again — the release tick disengaged it (per-excursion).
		if rushing and state.heat >= RIDE_TOP:
			rushing = false
		elif not rushing and state.heat <= VENT_BOTTOM:
			rushing = true
			state.engage_overdrive()

	var average_bonus := total_bonus_seconds / total_seconds
	_check("the old ride/release dodge now OVERHEATS (the hazard reaches its whole ride)",
		overheated_during_run[0])
	print("  >>> CRUISE BASELINE AVERAGE BONUS: +%.1f%% (holds at +%.0f%% forever, zero risk) <<<"
			% [cruise_average * 100.0, cruise_state.effective_cruise_bonus() * 100.0])
	print("  >>> OLD RIDE/RELEASE (never venting) NOW AVERAGES: +%.1f%% — the dodge is dead <<<"
			% [average_bonus * 100.0])


func _test_scheduler_determinism(tuning: TuningConfig) -> void:
	print("\n14. The window hazard is deterministic under a seeded rng")
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
	# times are quantized to the 0.1 s tick — so probe a handful of seeds and require the
	# first-window time to vary somewhere in the batch.
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
	print("\n17. Venting floors at the cruise point; the escalation curves follow the knobs")

	# Floor: with an absurdly large vent drop, a success still lands exactly at the cruise
	# point — success never ends the ride (the ratchet is the reward, not an exit), and heat
	# at or under cruise is holdable for free anyway, so there is nothing lower to vent to.
	var deep_drop: TuningConfig = tuning.duplicate()
	deep_drop.rush_momentum_vent_heat_drop = 5.0
	var clamp_state := _fresh_state(deep_drop, 900)
	_press_and_engage(clamp_state)
	_check("(setup) floor-case vent succeeded", _vent_cleanly(clamp_state, 1))
	_check("an oversized vent floors heat at the cruise point exactly",
		is_equal_approx(clamp_state.heat, clamp_state.cruise_heat()))
	_check("the ride survived the vent (still engaged, not locked out)",
		clamp_state.is_overdrive_engaged() and not clamp_state.is_locked_out())

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

	# The floors, white-box at an absurd depth (tier 40): the duration decay has long bottomed
	# out and the lifts sit at their cap. Poking _vent_tier directly is fair game here —
	# riding 40 real vents would test nothing new. (There is no delay floor to probe anymore:
	# cadence is the depth hazard's, measured statistically in section 20.)
	var deep := _fresh_state(tuning, 902)
	deep._vent_tier = 40
	_check("duration bottoms out at duration_floor",
		is_equal_approx(deep._next_window_duration(), tuning.rush_momentum_vent_duration_floor))
	_check("demanded lifts bottom out at the 3-lift cap",
		deep._next_window_required_lifts() == 3)


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
	# For each combo, EVERY window — the first AND the escalated deep-tier ones, where heat
	# rides closest to the ceiling — must open with its full duration still ahead of the
	# projected hard-ceiling arrival: heat_at_open + duration × build_hot <= hard_ceiling
	# (plus one tick of slack, since the open is noticed on a tick boundary). Heat climbs
	# through the approach flight before that open, so the force-spawn must reserve approach +
	# window — this assert-at-open catches an under-reserved spawn automatically, and the
	# combos sweep the approach knob too (including a stretched 4.0). Each seed rides a clean
	# multi-vent excursion so the checks sample the whole escalation curve, and each combo runs
	# several seeds so the dice can't get lucky. The "rates 0" combos remove the hazard
	# entirely: every window must then come from the force-spawn, the guarantee's own
	# machinery, with no lucky early roll to hide behind.
	var combos := [
		{"label": "defaults",
			"rate_cruise": tuning.rush_momentum_vent_rate_at_cruise,
			"rate_ceiling": tuning.rush_momentum_vent_rate_at_ceiling,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": tuning.rush_momentum_vent_approach_seconds},
		{"label": "rates 0 (pure force-spawn)", "rate_cruise": 0.0, "rate_ceiling": 0.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": tuning.rush_momentum_vent_approach_seconds},
		{"label": "rate_ceiling x4",
			"rate_cruise": tuning.rush_momentum_vent_rate_at_cruise,
			"rate_ceiling": tuning.rush_momentum_vent_rate_at_ceiling * 4.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": tuning.rush_momentum_vent_approach_seconds},
		{"label": "build_hot x2",
			"rate_cruise": tuning.rush_momentum_vent_rate_at_cruise,
			"rate_ceiling": tuning.rush_momentum_vent_rate_at_ceiling,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second * 2.0,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": tuning.rush_momentum_vent_approach_seconds},
		{"label": "rates 0 + build_hot x2 + duration 1.5", "rate_cruise": 0.0, "rate_ceiling": 0.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second * 2.0,
			"duration": 1.5,
			"approach": tuning.rush_momentum_vent_approach_seconds},
		{"label": "approach 4.0",
			"rate_cruise": tuning.rush_momentum_vent_rate_at_cruise,
			"rate_ceiling": tuning.rush_momentum_vent_rate_at_ceiling,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": 4.0},
		{"label": "rates 0 + approach 4.0 (forced spawns, long flights)",
			"rate_cruise": 0.0, "rate_ceiling": 0.0,
			"build_hot": tuning.rush_momentum_heat_build_hot_per_second,
			"duration": tuning.rush_momentum_vent_window_duration,
			"approach": 4.0},
	]
	for combo_variant in combos:
		var combo: Dictionary = combo_variant
		var combo_tuning: TuningConfig = tuning.duplicate()
		combo_tuning.rush_momentum_vent_rate_at_cruise = combo["rate_cruise"]
		combo_tuning.rush_momentum_vent_rate_at_ceiling = combo["rate_ceiling"]
		combo_tuning.rush_momentum_heat_build_hot_per_second = combo["build_hot"]
		combo_tuning.rush_momentum_vent_window_duration = combo["duration"]
		combo_tuning.rush_momentum_vent_approach_seconds = combo["approach"]
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


## Trials per depth for the hazard-rate measurement. Wait times are geometric, so the sample
## mean's relative error is ~1/sqrt(n) — 400 trials puts it near 5%, far inside the loose
## 30% tolerance below (seeded, so a pass is a pass forever).
const HAZARD_TRIALS := 400

func _test_depth_hazard_statistics(tuning: TuningConfig) -> void:
	print("\n20. The depth hazard: measured spawn rates match the lerped knob rates by depth")
	# Pin heat at a target depth and repeatedly time how long the hazard takes to SPAWN an
	# event (vent_incoming — the approach after it is a fixed pipeline delay, not part of the
	# arrival process, so measuring to the open would just add a constant and break the rate
	# math). The measured rate (1 / mean wait) must match lerp(rate_at_cruise, rate_at_ceiling,
	# depth) at BOTH a shallow and a deep probe, and their ratio must match the knobs' ratio —
	# the statistical proof that depth really is the cadence axis. The deep probe sits at 0.60,
	# safely BELOW the force-spawn bound (~0.69 depth at default knobs, now that the bound
	# reserves the approach flight too): above it the guarantee fires instantly and the probe
	# would measure the machinery, not the dice.
	const SHALLOW_DEPTH := 0.15
	const DEEP_DEPTH := 0.60
	var expected_shallow := lerpf(tuning.rush_momentum_vent_rate_at_cruise,
			tuning.rush_momentum_vent_rate_at_ceiling, SHALLOW_DEPTH)
	var expected_deep := lerpf(tuning.rush_momentum_vent_rate_at_cruise,
			tuning.rush_momentum_vent_rate_at_ceiling, DEEP_DEPTH)

	# The refractory is ZEROED for this measurement: every trial re-engages (rolling a fresh
	# quiet spell), and a constant ~0.8 s mean head start added to every geometric wait would
	# bias the measured rates low. This section proves the HAZARD CURVE; the refractory's own
	# spacing behaviour has its own section (24).
	var stat_tuning: TuningConfig = tuning.duplicate()
	stat_tuning.rush_momentum_vent_refractory_min = 0.0
	stat_tuning.rush_momentum_vent_refractory_max = 0.0
	var measured_shallow := 1.0 / _measure_mean_arrival_seconds(stat_tuning, 5000, SHALLOW_DEPTH)
	var measured_deep := 1.0 / _measure_mean_arrival_seconds(stat_tuning, 5001, DEEP_DEPTH)
	var measured_ratio := measured_deep / measured_shallow
	var expected_ratio := expected_deep / expected_shallow
	print("     (shallow %.2f: measured %.3f/s vs knob-lerped %.3f/s | deep %.2f: measured %.3f/s vs %.3f/s)"
			% [SHALLOW_DEPTH, measured_shallow, expected_shallow,
			DEEP_DEPTH, measured_deep, expected_deep])
	print("     (deep/shallow rate ratio: measured %.2f vs knob-implied %.2f)"
			% [measured_ratio, expected_ratio])
	# Loose tolerances on purpose: this is a statistical property, not an exact formula. The
	# heat pin drifts up to one tick of build inside each tick (~1-2% of the span), and the
	# geometric wait's sampling noise is ~5% at 400 trials — 30% covers both with a wide berth
	# while still catching a broken lerp (which would be off by ~4x at one of the probes).
	_check("shallow-depth arrival rate is within 30% of the knob-lerped rate",
		absf(measured_shallow - expected_shallow) <= expected_shallow * 0.30)
	_check("deep-depth arrival rate is within 30% of the knob-lerped rate",
		absf(measured_deep - expected_deep) <= expected_deep * 0.30)
	_check("the deep/shallow rate ratio matches the knobs' ratio within 30%",
		absf(measured_ratio - expected_ratio) <= expected_ratio * 0.30)


## Mean seconds the hazard takes to SPAWN an event (the approach begins) with heat PINNED at
## `depth_frac` of the overdrive span (cruise point → hard ceiling). The pin re-writes heat
## after every tick so the measurement samples ONE point on the hazard curve instead of a
## climbing trajectory (inside each tick heat briefly builds one tick past the pin — a ~1%
## depth bias the loose tolerance absorbs). One state's rng stream serves every trial
## (reset() keeps the seed and cancels the spawned flight for the next trial).
func _measure_mean_arrival_seconds(tuning: TuningConfig, seed_value: int, depth_frac: float) -> float:
	var state := _fresh_state(tuning, seed_value)
	var target_heat := state.cruise_heat() \
			+ depth_frac * (tuning.rush_momentum_hard_ceiling - state.cruise_heat())
	var total_seconds := 0.0
	for _trial in range(HAZARD_TRIALS):
		state.reset()
		_press_and_engage(state)
		state.heat = target_heat
		var waited := 0.0
		while not state.is_vent_approaching() and waited < 120.0:
			state.tick(TICK_SECONDS, true, false)
			state.heat = target_heat
			waited += TICK_SECONDS
		total_seconds += waited
	return total_seconds / HAZARD_TRIALS


func _measure_vent_autopilot_survival(tuning: TuningConfig) -> void:
	print("\n21. AUTOPILOT SURVIVAL + DUTY CYCLE — ride-until-you-miss venters vs cruise, %d s x %d seeds"
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
	print("      (per-seed time split, skilled: %.0f s overdrive / %.0f s building / %.0f s locked out;"
			% [skilled["overdrive_seconds"], skilled["climbing_seconds"], skilled["locked_seconds"]])
	print("       per-seed time split, sloppy:  %.0f s overdrive / %.0f s building / %.0f s locked out)"
			% [sloppy["overdrive_seconds"], sloppy["climbing_seconds"], sloppy["locked_seconds"]])
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
		"locked_seconds": 0.0, "overdrive_seconds": 0.0, "climbing_seconds": 0.0,
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
		totals["overdrive_seconds"] += run["overdrive_seconds"] / AUTOPILOT_SEED_RUNS
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

## Ticks the autopilot waits after a window OPENS before starting the gesture — a human
## reaction beat (0.3 s), per the plan's modeled-venter spec. The approach phase hands a real
## player free anticipation (they watch the event coming for approach_seconds before the
## window opens), but the model deliberately keeps reacting from the OPEN and ignores that
## benefit — a conservative floor: thumbs on glass should do at least this well, so the gates
## below understate, never overstate, the mechanic's real pay.
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
	var overdrive_seconds := 0.0
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
		if state.current_band() == RushMomentumState.Band.OVERDRIVE:
			overdrive_seconds += TICK_SECONDS
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
		"overdrive_seconds": overdrive_seconds,
		"climbing_seconds": climbing_seconds,
	}


func _test_approach_phase(tuning: TuningConfig) -> void:
	print("\n22. The approach phase: spawns lead opens tick-exactly, lifts exactly as announced")
	var approach_ticks := int(round(tuning.rush_momentum_vent_approach_seconds / TICK_SECONDS))

	# --- The query surface, on one spawned flight ---
	var probe := _fresh_state(tuning, 6001)
	_press_and_engage(probe)
	_check("(setup) an event went in flight", _ride_to_approach(probe) >= 0.0)
	_check("in flight: is_vent_approaching() true, full lead remaining, no window open yet",
		probe.is_vent_approaching() and not probe.is_vent_window_open()
			and absf(probe.vent_approach_remaining()
					- tuning.rush_momentum_vent_approach_seconds) < 0.0001)
	probe.tick(TICK_SECONDS, true, false)
	_check("vent_approach_remaining() counts down on the tick clock",
		absf(probe.vent_approach_remaining()
				- (tuning.rush_momentum_vent_approach_seconds - TICK_SECONDS)) < 0.0001)
	var flight_guard := 0
	while probe.is_vent_approaching() and flight_guard < 200:
		probe.tick(TICK_SECONDS, true, false)
		flight_guard += 1
	_check("the flight ends in an OPEN window (approach cleared, remaining reads 0)",
		probe.is_vent_window_open() and not probe.is_vent_approaching()
			and is_zero_approx(probe.vent_approach_remaining()))

	# --- The pairing invariants, across the whole escalation: one clean ride through 8 vents
	# (with lifts_step_tiers = 3 that samples single, double, AND triple announcements),
	# capturing every spawn and open with the exact tick it landed on. Every state.tick in
	# this ride goes through the counted step closure, so the tick indices are honest.
	var state := _fresh_state(tuning, 6000)
	var tick_index := [0]
	var spawns: Array = []           # [tick, announced approach_seconds, announced lifts]
	var opens: Array = []            # [tick, demanded lifts]
	var overlapping_spawns := [0]    # spawns while another event was in flight or open — must stay 0
	var in_flight := [false]
	state.vent_incoming.connect(func(approach_seconds: float, required_lifts: int) -> void:
		if in_flight[0] or state.is_vent_window_open():
			overlapping_spawns[0] += 1
		in_flight[0] = true
		spawns.append([tick_index[0], approach_seconds, required_lifts]))
	state.vent_window_opened.connect(func(required_lifts: int, _duration: float) -> void:
		in_flight[0] = false
		opens.append([tick_index[0], required_lifts]))
	_press_and_engage(state)
	var step := func() -> void:
		state.tick(TICK_SECONDS, true, false)
		tick_index[0] += 1
	const APPROACH_PROBE_VENTS := 8
	var vents_done := 0
	var safety := 0
	while vents_done < APPROACH_PROBE_VENTS and not state.is_locked_out() and safety < 3000:
		safety += 1
		if state.is_vent_window_open():
			# A clean gesture on brisk counted beats (mirrors _perform_clean_gesture, but every
			# tick runs through the step closure so the captured indices stay exact).
			var lifts := state.vent_required_lifts()
			state.notify_rush_released()
			step.call()
			state.notify_rush_pressed()
			for _extra_lift in range(lifts - 1):
				step.call()
				state.notify_rush_released()
				step.call()
				state.notify_rush_pressed()
			vents_done += 1
		else:
			step.call()
	_check("(setup) 8 clean vents ridden with spawn/open capture",
		vents_done == APPROACH_PROBE_VENTS
			and spawns.size() == APPROACH_PROBE_VENTS and opens.size() == APPROACH_PROBE_VENTS)
	var leads_exact := true
	var announcements_match := true
	var announced_lift_counts := {}  # lifts value -> times announced (escalation coverage)
	for i in range(mini(spawns.size(), opens.size())):
		var spawn: Array = spawns[i]
		var open_entry: Array = opens[i]
		if int(open_entry[0]) - int(spawn[0]) != approach_ticks:
			leads_exact = false
		if absf(float(spawn[1]) - tuning.rush_momentum_vent_approach_seconds) > 0.0001:
			leads_exact = false
		if int(open_entry[1]) != int(spawn[2]):
			announcements_match = false
		announced_lift_counts[int(spawn[2])] = int(announced_lift_counts.get(int(spawn[2]), 0)) + 1
	print("     (spawn->open leads in ticks, announced lifts: %s)" % [spawns])
	_check("every window opened EXACTLY approach_seconds of tick time after its spawn",
		leads_exact)
	_check("every opened window demanded exactly the lifts its spawn announced",
		announcements_match)
	_check("the announced lifts covered the escalation (singles, doubles, and triples seen)",
		announced_lift_counts.has(1) and announced_lift_counts.has(2)
			and announced_lift_counts.has(3))
	_check("only one event was ever in flight or open at a time (no overlapping spawns)",
		overlapping_spawns[0] == 0)


func _test_approach_cancellation(tuning: TuningConfig) -> void:
	print("\n23. An in-flight approach cancels silently on release, overheat, and reset")
	var approach_ticks := int(round(tuning.rush_momentum_vent_approach_seconds / TICK_SECONDS))

	# --- Release: the bail move. The event never arrived, so there is no miss and no lockout —
	# and no phantom window later: after remounting, an open can only follow a FRESH spawn's
	# full approach, so nothing may open sooner than that.
	var release_state := _fresh_state(tuning, 6100)
	var release_misses := [0]
	var release_opens := [0]
	release_state.vent_missed.connect(func(_done: int, _required: int) -> void: release_misses[0] += 1)
	release_state.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: release_opens[0] += 1)
	_press_and_engage(release_state)
	_check("(setup) an event went in flight", _ride_to_approach(release_state) >= 0.0)
	release_state.notify_rush_released()
	release_state.tick(TICK_SECONDS, false, false)
	_check("one released tick cancels the flight silently (no miss, no lockout)",
		not release_state.is_vent_approaching()
			and is_zero_approx(release_state.vent_approach_remaining())
			and release_misses[0] == 0 and not release_state.is_locked_out())
	# Remount at once and hold: even an instant fresh spawn cannot open a window inside the
	# next approach_ticks - 1 ticks, so ANY open here would be the cancelled event's ghost.
	_press_and_engage(release_state)
	for _i in range(approach_ticks - 1):
		release_state.tick(TICK_SECONDS, true, false)
	_check("no phantom window after the cancel (nothing can open before a fresh full approach)",
		release_opens[0] == 0)

	# --- Overheat mid-flight: white-box shove heat onto the backstop while the event is still
	# approaching (a hand-poked build knob could do the same live). The backstop overheat must
	# cancel the flight without inventing a miss for a window that never opened.
	var overheat_state := _fresh_state(tuning, 6101)
	var overheat_misses := [0]
	var overheat_opens := [0]
	overheat_state.vent_missed.connect(func(_done: int, _required: int) -> void: overheat_misses[0] += 1)
	overheat_state.vent_window_opened.connect(func(_lifts: int, _duration: float) -> void: overheat_opens[0] += 1)
	_press_and_engage(overheat_state)
	_check("(setup) an event went in flight", _ride_to_approach(overheat_state) >= 0.0)
	overheat_state.heat = tuning.rush_momentum_hard_ceiling
	overheat_state.tick(TICK_SECONDS, true, false)
	_check("a backstop overheat mid-flight cancels silently (locked out, no miss, no open)",
		overheat_state.is_locked_out() and not overheat_state.is_vent_approaching()
			and overheat_misses[0] == 0 and overheat_opens[0] == 0)
	# Ride out the lockout, remount, and prove the machinery is clean: the next open arrives
	# only via a fresh spawn's full approach (never sooner), with no leftover flight state.
	var lockout_elapsed := 0.0
	while overheat_state.is_locked_out() and lockout_elapsed < 120.0:
		overheat_state.tick(TICK_SECONDS, false, false)
		lockout_elapsed += TICK_SECONDS
	_press_and_engage(overheat_state)
	var reopen_seconds := _ride_to_window_open(overheat_state)
	_check("after the lockout, windows arrive again — and never faster than a full approach",
		reopen_seconds >= tuning.rush_momentum_vent_approach_seconds - 0.0001
			and overheat_opens[0] == 1)

	# --- Reset (the First Contact wipe): the flight is gone with everything else.
	var reset_state := _fresh_state(tuning, 6102)
	var reset_misses := [0]
	reset_state.vent_missed.connect(func(_done: int, _required: int) -> void: reset_misses[0] += 1)
	_press_and_engage(reset_state)
	_check("(setup) an event went in flight", _ride_to_approach(reset_state) >= 0.0)
	reset_state.reset()
	_check("reset() wipes the flight silently (no miss, nothing approaching)",
		not reset_state.is_vent_approaching()
			and is_zero_approx(reset_state.vent_approach_remaining())
			and reset_misses[0] == 0)
	_press_and_engage(reset_state)
	_check("a fresh ride after the reset spawns and opens windows normally",
		_ride_to_window_open(reset_state) >= tuning.rush_momentum_vent_approach_seconds - 0.0001)


func _test_vent_refractory_spacing(tuning: TuningConfig) -> void:
	print("\n24. The vent refractory: gaps vary, never undercut the min, bounded once deep")
	var refractory_min := tuning.rush_momentum_vent_refractory_min
	var refractory_max := tuning.rush_momentum_vent_refractory_max
	var build_hot := tuning.rush_momentum_heat_build_hot_per_second

	# --- Engaging rolls a refractory, and it suppresses the DICE: with the hazard cranked to
	# a certainty (an expected spawn on virtually every eligible tick), the first spawn after
	# a hot re-engage still waits out the rolled quiet — and not a tick longer than it plus
	# tick-boundary slack, proving the quiet (not some other clock) was the delay.
	var certain_tuning: TuningConfig = tuning.duplicate()
	certain_tuning.rush_momentum_vent_rate_at_cruise = 1000.0
	certain_tuning.rush_momentum_vent_rate_at_ceiling = 1000.0
	var hot := _fresh_state(certain_tuning, 7000)
	# Heat poked to a mid-depth BEFORE the engage (as after bailing a deep ride and
	# re-pressing): far enough below the force-spawn bound that the roll is never clamped.
	hot.heat = 1.2
	_press_and_engage(hot)
	var rolled := hot.vent_refractory_remaining()
	_check("engaging rolls a refractory inside [min, max]",
		rolled >= refractory_min - 0.0001 and rolled <= refractory_max + 0.0001)
	var waited := 0.0
	while not hot.is_vent_approaching() and waited < 10.0:
		hot.tick(TICK_SECONDS, true, false)
		waited += TICK_SECONDS
	print("     (hot engage rolled %.2f s of quiet; certain hazard spawned after %.2f s)"
			% [rolled, waited])
	_check("a certain-spawn hazard still waits out the rolled quiet (and no longer)",
		waited >= rolled - 0.0001 and waited <= rolled + 2.0 * TICK_SECONDS + 0.0001)

	# --- The engage-time CLAMP: re-engaging with heat just under the force-spawn bound must
	# shrink the roll to the climb room left (the refractory suppresses the force-spawn, so an
	# unclamped roll here would let heat overshoot the reservation) — and the window that then
	# arrives must still fully fit before the ceiling: the guarantee outranks the breather.
	var near := _fresh_state(certain_tuning, 7001)
	near.heat = near._window_fit_heat_bound() - 0.01
	_press_and_engage(near)
	_check("a hot re-engage near the bound clamps the rolled quiet to the room left",
		near.vent_refractory_remaining() <= 0.01 / build_hot + 0.0001)
	_check("(setup) the near-bound ride still opened a window",
		_ride_to_window_open(near) >= 0.0)
	_check("that window still fully fits before the ceiling (guarantee intact)",
		near.heat + near.vent_window_remaining() * build_hot
			<= certain_tuning.rush_momentum_hard_ceiling + build_hot * TICK_SECONDS + 0.0001)

	# --- Post-vent spacing, on one long clean ride at the DEFAULT knobs: measure the gap from
	# every vent success to the next event's spawn, with every tick counted (section 22's
	# counted-step pattern). Per success, also record whether the top-off clamp bit — post-vent
	# heat landing exactly on fit_bound − refractory_max × build_hot — because only THOSE gaps
	# have a hard upper bound: the clamp leaves exactly refractory_max of climb to the
	# force-spawn bound, so the forced spawn caps the gap at refractory_max (+ tick slack).
	# Shallower gaps keep the open-ended hazard tail — that tail IS the randomness Tim wants.
	var state := _fresh_state(tuning, 7002)
	var tick_index := [0]
	var last_success_tick := [-1]
	var last_success_clamped := [false]
	var gaps: Array = []        # seconds, success → next spawn
	var gap_clamped: Array = [] # parallel: did the top-off clamp bite at that success?
	state.vent_succeeded.connect(func(_tier: int, _peak: float) -> void:
		last_success_tick[0] = tick_index[0]
		var post_vent_bound: float = state._window_fit_heat_bound() \
				- refractory_max * build_hot
		last_success_clamped[0] = absf(state.heat - post_vent_bound) < 0.0001)
	state.vent_incoming.connect(func(_approach: float, _lifts: int) -> void:
		if last_success_tick[0] >= 0:
			gaps.append(float(tick_index[0] - last_success_tick[0]) * TICK_SECONDS)
			gap_clamped.append(last_success_clamped[0])
			last_success_tick[0] = -1)
	_press_and_engage(state)
	var step := func() -> void:
		state.tick(TICK_SECONDS, true, false)
		tick_index[0] += 1
	const SPACING_PROBE_VENTS := 12
	var vents_done := 0
	var safety := 0
	while vents_done < SPACING_PROBE_VENTS and not state.is_locked_out() and safety < 5000:
		safety += 1
		if state.is_vent_window_open():
			var lifts := state.vent_required_lifts()
			state.notify_rush_released()
			step.call()
			state.notify_rush_pressed()
			for _extra_lift in range(lifts - 1):
				step.call()
				state.notify_rush_released()
				step.call()
				state.notify_rush_pressed()
			vents_done += 1
		else:
			step.call()
	print("     (post-vent gaps, s: %s)" % [gaps])
	print("     (top-off clamp bit on: %s)" % [gap_clamped])
	_check("(setup) %d clean vents ridden with %d gaps measured" % [SPACING_PROBE_VENTS,
			SPACING_PROBE_VENTS - 1],
		vents_done == SPACING_PROBE_VENTS and gaps.size() >= SPACING_PROBE_VENTS - 1)
	var all_at_least_min := true
	var clamped_bounded := true
	var clamped_count := 0
	var distinct_gaps := {}  # tick-quantized gap value -> seen (the variety proof)
	for i in range(gaps.size()):
		var gap: float = gaps[i]
		if gap < refractory_min - 0.0001:
			all_at_least_min = false
		distinct_gaps[snappedf(gap, TICK_SECONDS)] = true
		if gap_clamped[i]:
			clamped_count += 1
			if gap > refractory_max + 2.0 * TICK_SECONDS + 0.0001:
				clamped_bounded = false
	_check("every post-vent gap waits at least refractory_min", all_at_least_min)
	_check("consecutive gaps VARY (3+ distinct spacings — not a metronome)",
		distinct_gaps.size() >= 3)
	_check("(setup) the deep top-off clamp engaged for several vents", clamped_count >= 4)
	_check("clamped-deep gaps are bounded by refractory_max plus tick slack (the forced tail)",
		clamped_bounded)
