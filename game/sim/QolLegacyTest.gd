extends SceneTree

# Headless gate for the QoL and Frenzy Legacy upgrades:
#   1. Night Shift (Extended Offline Window)
#   2. Shift Supervisors (Auto-Restart Idle Cycles)
#   3. Hair Trigger (Auto-Pop TURBO Setting & Succession Carry)
#   4. Market Buzz (Cycle-Driven Frenzy Charging)
#   5. Market Momentum (Decay Resistance & Extended Grace)
#   6. Residual Momentum (Post-Frenzy Afterburn Tail)
#
# Usage: godot --headless --path game --script res://sim/QolLegacyTest.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== QoL & Frenzy Legacy Upgrades Test ===\n")

	var tuning: TuningConfig = load("res://config/tuning.tres")
	var configs := ConfigLoader.load_property_configs()
	if tuning == null or configs.is_empty():
		print("FAILED to load config")
		quit(1)
		return

	_test_extended_offline(tuning, configs)
	_test_shift_supervisors(tuning, configs)
	_test_hair_trigger_and_settings(tuning, configs)
	_test_market_buzz(tuning, configs)
	_test_market_momentum(tuning, configs)
	_test_residual_momentum(tuning, configs)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _test_extended_offline(tuning: TuningConfig, configs: Array) -> void:
	print("-- Night Shift (Extended Offline) --")
	var dynasty := DynastyState.new(configs, tuning)

	# Check base cost: with cost_multiplier = 3.0, Level 1 costs exactly 8,000 gems.
	LegacyUpgradeCatalog.cost_multiplier = 3.0
	LegacyUpgradeCatalog.cost_steepening = 1.0
	var cost_lvl1 := LegacyUpgradeCatalog.cost_for_level(LegacyUpgradeCatalog.EXTENDED_OFFLINE, 1)
	_check("level 1 cost is 8,000 gems (%d)" % cost_lvl1, cost_lvl1 == 8000)

	# Default cap with 0 levels = 14400s (4 hours)
	var cap_0 := dynasty.upgrades.offline_cap_seconds(14400.0)
	_check("0 levels gives 4h base cap (%.0fs)" % cap_0, is_equal_approx(cap_0, 14400.0))

	# Level 1 (+4h = 8h / 28800s)
	dynasty.upgrades.levels[LegacyUpgradeCatalog.EXTENDED_OFFLINE] = 1
	var cap_1 := dynasty.upgrades.offline_cap_seconds(14400.0)
	_check("level 1 gives 8h cap (%.0fs)" % cap_1, is_equal_approx(cap_1, 28800.0))

	# Level 5 (+20h = 24h / 86400s)
	dynasty.upgrades.levels[LegacyUpgradeCatalog.EXTENDED_OFFLINE] = 5
	var cap_5 := dynasty.upgrades.offline_cap_seconds(14400.0)
	_check("level 5 gives 24h cap (%.0fs)" % cap_5, is_equal_approx(cap_5, 86400.0))

	# Setup economy with a staffed property
	dynasty.current.economy.properties[0].buy(10)
	dynasty.current.economy.properties[0].add_staff_level()
	var rate := (dynasty.current.economy.properties[0] as PropertyState).get_income_per_sec()

	# Test 10 hours away (36000s) with 8h cap (level 1)
	var res_1 := OfflineCalculator.calculate(dynasty.current.economy, tuning, 36000.0, cap_1)
	_check("10h away is capped at 8h (%.0fs)" % res_1.paid_seconds, is_equal_approx(res_1.paid_seconds, 28800.0))
	_check("pile is 8h * rate * efficiency", is_equal_approx(res_1.pile, floorf(rate * tuning.offline_efficiency * 28800.0)))

	# Test 10 hours away (36000s) with 24h cap (level 5)
	var res_5 := OfflineCalculator.calculate(dynasty.current.economy, tuning, 36000.0, cap_5)
	_check("10h away is paid in full under 24h cap (%.0fs)" % res_5.paid_seconds, is_equal_approx(res_5.paid_seconds, 36000.0))


func _test_shift_supervisors(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- Shift Supervisors (Auto-Restart Idle Cycles) --")
	var dynasty := DynastyState.new(configs, tuning)
	var econ := dynasty.current.economy

	# Buy units of first 3 properties, unstaffed
	econ.properties[0].buy(10)
	econ.properties[1].buy(10)
	econ.properties[2].buy(10)

	_check("properties start unstaffed", not econ.properties[0].is_staffed)

	# With 0 levels, update_auto_restarts(0) sets all auto_restarts to false
	econ.update_auto_restarts(0)
	_check("0 levels: property 0 auto_restarts is false", not econ.properties[0].auto_restarts)
	_check("0 levels: passive income is 0", is_equal_approx(econ.get_passive_income_per_sec(), 0.0))

	# Start property 0 manually and let it complete
	econ.properties[0].start_cycle()
	_check("property 0 cycle is running", econ.properties[0].is_cycle_running)
	var length_0: float = econ.properties[0].get_effective_cycle_length()
	econ.properties[0].tick(length_0 + 0.1)
	_check("without auto-restart, property 0 stops after 1 cycle", not econ.properties[0].is_cycle_running)

	# Give 1 level of Shift Supervisors -> top 1 unstaffed auto-restarts
	dynasty.upgrades.levels[LegacyUpgradeCatalog.AUTO_RESTART_CYCLES] = 1
	dynasty.refresh_current_generation_effects()
	# Property 2 has highest income/sec because base_cost is highest
	_check("top unstaffed property is flagged auto_restarts", econ.properties[2].auto_restarts)
	_check("lower unstaffed property is not flagged", not econ.properties[0].auto_restarts)
	_check("auto-restarting property started its cycle", econ.properties[2].is_cycle_running)

	# Tick property 2 past its cycle length -> it should auto-restart!
	var length_2: float = econ.properties[2].get_effective_cycle_length()
	econ.properties[2].tick(length_2 + 0.1)
	_check("with auto-restart, cycle auto-restarts immediately", econ.properties[2].is_cycle_running)

	# Verify passive income includes auto-restarting properties
	var expected_passive: float = econ.properties[2].get_income_per_cycle() / length_2
	_check("passive income includes auto-restarting property (%.2f)" % econ.get_passive_income_per_sec(),
		is_equal_approx(econ.get_passive_income_per_sec(), expected_passive))


func _test_hair_trigger_and_settings(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- Hair Trigger (Auto-Pop TURBO Setting & Succession) --")
	var dynasty := DynastyState.new(configs, tuning)

	# Defaults
	_check("auto-pop TURBO setting defaults to false", not dynasty.current.ui_auto_pop_turbo)
	_check("auto-pop TURBO is initially locked", not dynasty.upgrades.auto_pop_turbo_unlocked())

	# Unlock Hair Trigger
	dynasty.upgrades.levels[LegacyUpgradeCatalog.AUTO_POP_TURBO] = 1
	_check("auto-pop TURBO is now unlocked", dynasty.upgrades.auto_pop_turbo_unlocked())

	# Toggle setting
	dynasty.current.ui_auto_pop_turbo = true

	# Test save / load round trip
	var save_dict := dynasty.to_save_dict()
	var loaded := DynastyState.new(configs, tuning)
	loaded.load_save_dict(save_dict)
	_check("auto_pop_turbo setting survives save/load", loaded.current.ui_auto_pop_turbo)

	# Test succession carry
	dynasty.current.economy.cash_earned_this_gen = 1.0e12
	dynasty.perform_succession()
	_check("auto_pop_turbo setting is carried to heir", dynasty.current.ui_auto_pop_turbo)


func _test_market_buzz(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- Market Buzz (Cycle-Driven Frenzy Charging) --")
	var dynasty := DynastyState.new(configs, tuning)
	var frenzy := dynasty.current.frenzy

	# With 0 levels, on_cycle_completed does not charge
	frenzy.cycle_charge_per_completion = 0.0
	frenzy.on_cycle_completed(5)
	_check("0 levels: cycle completion adds 0 charge", is_equal_approx(frenzy.meter, 0.0))

	# With 2 levels (0.001 per cycle = 0.1% per cycle)
	dynasty.upgrades.levels[LegacyUpgradeCatalog.FRENZY_CYCLE_CHARGE] = 2
	dynasty.refresh_current_generation_effects()
	_check("frenzy has cycle_charge_per_completion set", is_equal_approx(frenzy.cycle_charge_per_completion, 0.001))

	# Complete 10 cycles through economy.tick
	dynasty.current.economy.properties[0].buy(1)
	dynasty.current.economy.properties[0].add_staff_level()
	var cycle_len: float = dynasty.current.economy.properties[0].get_effective_cycle_length()

	# Tick 5 full cycles
	dynasty.current.tick(cycle_len * 5.0)
	_check("frenzy meter charged by completed cycles (%.4f)" % frenzy.meter, frenzy.meter > 0.0)


func _test_market_momentum(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- Market Momentum (Decay Resistance & Extended Grace) --")
	var dynasty := DynastyState.new(configs, tuning)
	var frenzy := dynasty.current.frenzy

	# 2 levels: +12s grace, -16% decay speed (0.84 multiplier)
	dynasty.upgrades.levels[LegacyUpgradeCatalog.FRENZY_DECAY_RESIST] = 2
	dynasty.refresh_current_generation_effects()

	_check("grace_bonus is +12s (%.1fs)" % frenzy.grace_bonus, is_equal_approx(frenzy.grace_bonus, 12.0))
	_check("decay_multiplier is 0.84 (%.2f)" % frenzy.decay_multiplier, is_equal_approx(frenzy.decay_multiplier, 0.84))

	# Charge meter to 50%
	frenzy.on_tap() # resets _seconds_since_tap
	frenzy.meter = 0.5

	# Advance by 10 seconds (base grace is 5.0s, effective grace is 17.0s) -> should NOT decay!
	frenzy.tick(10.0)
	_check("meter did not decay within extended grace period (meter: %.2f)" % frenzy.meter, is_equal_approx(frenzy.meter, 0.5))

	# Advance from 10s to 20s in 1.0s ticks (effective grace is 17.0s; ticks at 17, 18, 19, 20 decay = 4.0s)
	for _i in range(10):
		frenzy.tick(1.0)
	var expected_decay: float = 4.0 * (tuning.frenzy_decay_per_second * 0.84)
	_check("meter decayed at reduced rate (meter: %.4f)" % frenzy.meter, is_equal_approx(frenzy.meter, 0.5 - expected_decay))


func _test_residual_momentum(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- Residual Momentum (Post-Frenzy Afterburn Tail) --")
	var dynasty := DynastyState.new(configs, tuning)
	var frenzy := dynasty.current.frenzy

	# 2 levels: +3.0s afterburn
	dynasty.upgrades.levels[LegacyUpgradeCatalog.FRENZY_AFTERBURN] = 2
	dynasty.refresh_current_generation_effects()

	_check("afterburn_duration is 3.0s (%.1fs)" % frenzy.afterburn_duration, is_equal_approx(frenzy.afterburn_duration, 3.0))

	# Pop frenzy at full charge
	frenzy.meter = 1.0
	frenzy.pop()
	_check("frenzy is burning", frenzy.mode == FrenzyState.Mode.BURNING)
	var peak_mult := frenzy.locked_multiplier

	# Burn it to completion
	var burn_time := tuning.frenzy_burn_duration * frenzy.duration_multiplier
	frenzy.tick(burn_time + 0.1)

	# Should now be in AFTERBURN mode rather than abruptly FILLING
	_check("after burn ends, enters AFTERBURN mode", frenzy.mode == FrenzyState.Mode.AFTERBURN)
	_check("is_burning() is true during afterburn", frenzy.is_burning())
	_check("multiplier is still elevated (> 1.0)", frenzy.get_multiplier() > 1.0)

	# Advance halfway through afterburn (1.5s)
	frenzy.tick(1.5)
	var half_mult := 1.0 + (peak_mult - 1.0) * 0.5
	_check("multiplier at half-tail is ~half of peak bonus (%.2f vs %.2f)" % [frenzy.get_multiplier(), half_mult],
		is_equal_approx(frenzy.get_multiplier(), half_mult))

	# Advance to end of afterburn
	frenzy.tick(1.6)
	_check("afterburn completes and returns to FILLING mode", frenzy.mode == FrenzyState.Mode.FILLING)
	_check("multiplier is back to 1.0", is_equal_approx(frenzy.get_multiplier(), 1.0))


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
