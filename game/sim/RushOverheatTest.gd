extends SceneTree

# Headless verification for Rush Overheat — the push-your-luck heat model that replaced the
# hold-forever momentum ratchet (Tim 2026-07-15; design of record: Plans/Rush_Overheat.md).
#
# Usage: godot --headless --path . --script res://sim/RushOverheatTest.gd
#
# Proves, without any rendering:
#   1. Building 0 → Hot takes ~6 s of sustained rushing (the old build feel is preserved).
#   2. band_entered fires on the upward crossings, HOT then CRITICAL, in order.
#   3. Overheat triggers at a per-excursion ceiling inside [ceiling_min, ceiling_max].
#   4. The lockout: rush disabled, bonus 0, heat drains at the locked rate, and rush_ready
#      fires only rearm_seconds AFTER the bar empties — then rushing re-enables.
#   5. A frenzy burn FREEZES everything: build, bleed, lockout drain, and re-arm countdown.
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
#  13. DUTY CYCLE: the cruise baseline (+25% forever, zero risk) vs a skilled ride/vent
#      overdrive player's average bonus over 120 s — the printed pair is what the gamble
#      is actually worth (measure, don't guess — durable lesson).
#
# NOTE: since Cruise Control, plain rushing CLAMPS at the cruise point — the danger-band
# sections below call engage_overdrive() first, matching what the OVERDRIVE button does.
#
# Exits with code 0 only if every check passes (1 otherwise), so CI/headless runs fail loudly.

## One logic tick, matching the game's 10 Hz timestep.
const TICK_SECONDS := 0.1

var _failures := 0


func _initialize() -> void:
	print("=== Rush Overheat — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	if tuning == null:
		print("FAILED to load tuning config")
		quit(1)
		return

	_test_build_time_to_hot(tuning)
	_test_band_signals_and_ceiling(tuning)
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


## A fresh heat state with a deterministic ceiling roll, so every run reproduces exactly.
func _fresh_state(tuning: TuningConfig, seed_value: int) -> RushMomentumState:
	var state := RushMomentumState.new(tuning)
	state.rng.seed = seed_value
	return state


## Rush a state upward until it overheats (or the safety cap trips). Returns the seconds spent.
## Engages overdrive first — since Cruise Control, a plain hold clamps safely at the cruise
## point, so reaching an overheat requires the opt-in (exactly like the OVERDRIVE button).
func _rush_until_overheat(state: RushMomentumState) -> float:
	state.engage_overdrive()
	var elapsed := 0.0
	while not state.is_locked_out() and elapsed < 60.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	return elapsed


func _test_build_time_to_hot(tuning: TuningConfig) -> void:
	print("1. Building 0 -> Hot takes ~6 s of sustained rushing")
	var state := _fresh_state(tuning, 1)
	# Overdrive so the climb runs past the cruise clamp — this section times the raw build rate.
	state.engage_overdrive()
	var elapsed := 0.0
	while state.heat < 1.0 and elapsed < 30.0:
		state.tick(TICK_SECONDS, true, false)
		elapsed += TICK_SECONDS
	print("     (reached Hot at %.1f s)" % elapsed)
	_check("Hot edge reached between 5.5 and 6.5 s", elapsed >= 5.5 and elapsed <= 6.5)
	_check("bonus at the Hot edge ~= bonus_at_hot",
		absf(state.bonus - tuning.rush_momentum_bonus_at_hot) < 0.02)


func _test_band_signals_and_ceiling(tuning: TuningConfig) -> void:
	print("\n2 & 3. Band signals fire upward in order; overheat lands inside the ceiling window")
	var state := _fresh_state(tuning, 12345)
	var bands_entered: Array = []
	var overheat_count := [0]  # single-element array so the lambda can mutate it
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))
	state.overheated.connect(func() -> void: overheat_count[0] += 1)

	_rush_until_overheat(state)
	_check("band_entered fired exactly twice on the way up", bands_entered.size() == 2)
	_check("first crossing was HOT",
		bands_entered.size() >= 1 and bands_entered[0] == RushMomentumState.Band.HOT)
	_check("second crossing was CRITICAL",
		bands_entered.size() >= 2 and bands_entered[1] == RushMomentumState.Band.CRITICAL)
	_check("overheated fired exactly once", overheat_count[0] == 1)
	print("     (overheated at heat %.3f)" % state.heat)
	_check("overheat heat is inside [ceiling_min, ceiling_max]",
		state.heat >= tuning.rush_momentum_ceiling_min
			and state.heat <= tuning.rush_momentum_ceiling_max)

	# A second excursion re-rolls the ceiling: cool below Hot, climb again, and confirm a
	# (deterministically) different shutdown point — the anti-memorization roll.
	var first_ceiling := state.heat
	state.reset()
	var bands_second: Array = []
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_second.append(band))
	_rush_until_overheat(state)
	_check("second excursion also overheats inside the window",
		state.heat >= tuning.rush_momentum_ceiling_min
			and state.heat <= tuning.rush_momentum_ceiling_max)
	_check("second excursion rolled a different ceiling (re-roll per excursion)",
		not is_equal_approx(state.heat, first_ceiling))


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
	_check("rush_ready fired ~rearm_seconds after the bar emptied",
		absf(rearm_elapsed - tuning.rush_momentum_rearm_seconds) <= TICK_SECONDS + 0.001)
	_check("can_rush() is true again after rush_ready", state.can_rush())
	_check("no longer locked out or re-arming", not state.is_locked_out() and not state.is_rearming())
	_check("heat is 0 for the fresh climb", is_zero_approx(state.heat))


func _test_frenzy_freeze(tuning: TuningConfig) -> void:
	print("\n5. A frenzy burn freezes heat exactly (build, bleed, and lockout all halt)")

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
	#   heat 1.5  -> partway through Critical    = lerp toward bonus_peak at ceiling_max
	var critical_fraction := (1.5 - tuning.rush_momentum_critical_start) \
			/ (tuning.rush_momentum_ceiling_max - tuning.rush_momentum_critical_start)
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
	state.band_entered.connect(func(band: RushMomentumState.Band) -> void: bands_entered.append(band))

	# Settle into the cruise clamp first, then opt in.
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
	_check("overheat landed inside [ceiling_min, ceiling_max]",
		state.heat >= tuning.rush_momentum_ceiling_min
			and state.heat <= tuning.rush_momentum_ceiling_max)
	_check("HOT and CRITICAL both announced on the way up",
		bands_entered == [RushMomentumState.Band.HOT, RushMomentumState.Band.CRITICAL])
	_check("overdrive disengaged by the overheat", not state.is_overdrive_engaged())


func _test_overdrive_disengages_on_release(tuning: TuningConfig) -> void:
	print("\n10. Overdrive is per-excursion: releasing the hold disengages it")
	var state := _fresh_state(tuning, 101)
	state.engage_overdrive()
	# Ride ~2 s past the cruise point — above the clamp but still safely below ceiling_min.
	for _i in range(70):  # 7 s: ~6 s to the Hot edge plus ~1 s into Hot
		state.tick(TICK_SECONDS, true, false)
	_check("(setup) rode above the cruise point without overheating",
		state.heat > state.cruise_heat() and not state.is_locked_out())
	_check("(setup) overdrive engaged mid-ride", state.is_overdrive_engaged())

	# One released tick = the hold ended. That alone must disengage overdrive.
	state.tick(TICK_SECONDS, false, false)
	_check("one non-rushing tick disengages overdrive", not state.is_overdrive_engaged())

	# Re-holding WITHOUT tapping overdrive again is back in cruise mode: heat left over from
	# the ride bleeds DOWN to the cruise point (never sustained for free) and pins there.
	var overheat_count := [0]
	state.overheated.connect(func() -> void: overheat_count[0] += 1)
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
	_check("overdrive from the 1.0 boundary rolls an excursion and overheats normally",
		state.is_locked_out() and bands_entered.size() == 2)


func _test_legacy_lockout_scale(tuning: TuningConfig) -> void:
	print("\n12. Rapid Restart at level 5 halves the whole lockout (drain AND re-arm together)")
	# Same seed = the same rolled ceiling, so the two lockouts start from identical heat and
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


## The balance measurement (not a pass/fail test): a SKILLED player rides heat up to 1.30 and
## vents back to 1.00, over and over, never overheating (1.30 is safely below ceiling_min 1.40).
## The average bonus over 120 s is the realistic value of the mechanic — and since Cruise
## Control it is measured AGAINST the zero-effort cruise baseline (+25% forever), so the
## printed pair is exactly what the overdrive gamble is worth (the number Tim needs).
func _measure_duty_cycle(tuning: TuningConfig) -> void:
	print("\n13. DUTY-CYCLE MEASUREMENT — cruise baseline vs skilled ride/vent, 120 simulated seconds")
	const RIDE_TOP := 1.30   # release point, below the earliest possible ceiling (1.40)
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

	# The gamble: the skilled overdrive player rides to the top and vents, over and over.
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
		# The skilled player's rhythm: vent at the ride top, re-engage at the Hot edge.
		# Each re-engage taps OVERDRIVE again — the release tick disengaged it (per-excursion).
		if rushing and state.heat >= RIDE_TOP:
			rushing = false
		elif not rushing and state.heat <= VENT_BOTTOM:
			rushing = true
			state.engage_overdrive()

	var average_bonus := total_bonus_seconds / total_seconds
	_check("the skilled rhythm never overheats", not overheated_during_run[0])
	print("")
	print("  >>> CRUISE BASELINE AVERAGE BONUS: +%.1f%% (holds at +%.0f%% forever, zero risk) <<<"
			% [cruise_average * 100.0, cruise_state.effective_cruise_bonus() * 100.0])
	print("  >>> SKILLED OVERDRIVE AVERAGE BONUS: +%.1f%% (peak is +%.0f%%) <<<"
			% [average_bonus * 100.0, tuning.rush_momentum_bonus_peak * 100.0])
	print("  >>> THE GAMBLE IS WORTH: +%.1f%% over cruising (before any overheat losses) <<<"
			% [(average_bonus - cruise_average) * 100.0])
	print("      (ride to heat %.2f, vent to %.2f, 120 s including the initial cold climb)"
			% [RIDE_TOP, VENT_BOTTOM])
