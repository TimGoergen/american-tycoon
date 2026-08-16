extends SceneTree

# Headless verification for Rare Events (GDD §9 / Mechanics Spec §10).
# Tests Market Crash weather, The Audit dilemma, The Windfall grant,
# save persistence, multiplier isolation, and prestige reset.
#
# Usage: godot --headless --path game --script res://sim/RareEventsTest.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	print("=== Rare Events — Headless Verification ===\n")

	_test_crash_weather_and_multipliers()
	_test_crash_duration_and_expiry()
	_test_audit_settle_vs_fight()
	_test_audit_legislative_evaporation()
	_test_windfall_grant()
	_test_events_save_load_round_trip()
	_test_prestige_weather_reset()

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED (%d checks)" % _checks)
		quit(0)
	else:
		print("FAILURES: %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _assert(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		_failures += 1
		print("  [FAIL] %s" % msg)


func _assert_approx(a: float, b: float, tolerance: float, msg: String) -> void:
	_checks += 1
	if absf(a - b) <= tolerance:
		print("  [PASS] %s (%.4f ≈ %.4f)" % [msg, a, b])
	else:
		_failures += 1
		print("  [FAIL] %s (got %.4f, expected %.4f)" % [msg, a, b])


func _build_test_game() -> GameState:
	var tuning := ConfigLoader.load_tuning(false)
	var configs := ConfigLoader.load_property_configs()
	var game := GameState.new(configs, tuning)
	# Buy 1 unit of ATM (prop 0) so it earns passive money
	game.economy.award_cash(1000.0)
	game.economy.try_buy(0, 1, 1)
	return game


func _test_crash_weather_and_multipliers() -> void:
	print("-- Market Crash: property income halved, wage unaffected --")
	var game := _build_test_game()

	_assert(game.events.get_property_income_multiplier() == 1.0, "Initial event multiplier is 1.0")
	_assert(!game.events.is_crash_active(), "Crash is not initially active")

	# Buy 2 units so base income is 2 * $5 = $10, which cleanly halves to $5.0 when floored
	var atm := game.economy.properties[0] as PropertyState
	atm.units_owned = 2
	atm.start_cycle()

	# Trigger crash
	game.events.trigger_crash(10.0, game)
	_assert(game.events.is_crash_active(), "Crash is active after trigger")
	_assert(game.events.get_property_income_multiplier() == 0.5, "Income multiplier is 0.5 during crash")

	# Property income is halved
	var normal_payout: float = atm.get_income_per_cycle()
	var earned_income: float = atm.tick(atm.cycle_length, game.events.get_property_income_multiplier())
	_assert_approx(earned_income, normal_payout * 0.5, 0.01, "Property earned income reflects 0.5 crash multiplier")

	# Wage is 100% unaffected (honest work is crash proof)
	var wage_before: float = game.wage.peek_wage(1.0)
	var earned_wage: float = game.wage.tap_wage(1.0)
	_assert_approx(earned_wage, wage_before, 0.001, "Wage payout is unaffected by crash multiplier")


func _test_crash_duration_and_expiry() -> void:
	print("-- Market Crash: duration ticks down and expires cleanly --")
	var game := _build_test_game()

	game.events.trigger_crash(1.0, game) # 1 minute = 60 seconds
	_assert(game.events.active_event_remaining == 60.0, "Remaining time starts at 60s")

	# Tick 30 seconds
	game.tick(30.0)
	_assert_approx(game.events.active_event_remaining, 30.0, 0.1, "Remaining time ticks down to 30s")
	_assert(game.events.is_crash_active(), "Crash still active at 30s")

	# Tick remaining 31 seconds
	game.tick(31.0)
	_assert(game.events.active_event_remaining == 0.0, "Remaining time hit zero")
	_assert(!game.events.is_crash_active(), "Crash ended on expiry")
	_assert(game.events.get_property_income_multiplier() == 1.0, "Multiplier restored to 1.0")


func _test_audit_settle_vs_fight() -> void:
	print("-- The Audit: settle vs fight without Legislative Assets --")
	var game := _build_test_game()
	game.economy.cash = 10000.0
	game.peak_net_worth = 10000.0
	var net_worth := EventState.get_current_net_worth(game)
	var expected_settle := floorf(net_worth * game.tuning.audit_settle_rate)

	var data := game.events.trigger_audit(game)
	_assert(data.has("settle_cost"), "Audit preview generates settle cost")
	_assert_approx(float(data["settle_cost"]), expected_settle, 0.01, "Settle cost is 8% of net worth ($" + str(int(expected_settle)) + ")")
	_assert(!data["has_enough_legislators"], "Does not have enough legislators initially")

	# Resolve by Settle (choice 0)
	var cash_before := game.economy.cash
	var outcome := game.events.resolve_audit(0, game)
	_assert(outcome["choice"] == "settle", "Audit resolved by settling")
	_assert_approx(game.economy.cash, cash_before - expected_settle, 0.01, "Cash reduced by settlement amount")

	# Reset and test fighting without legislators (choice 1)
	game.economy.cash = 10000.0
	data = game.events.trigger_audit(game)
	var expected_penalty: float = float(data["fight_penalty"])
	outcome = game.events.resolve_audit(1, game)
	_assert(outcome["choice"] == "fight", "Audit resolved by fighting")
	_assert(!outcome["success"], "Fight failed without legislative assets")
	_assert_approx(game.economy.cash, 10000.0 - expected_penalty, 0.01, "Cash penalized by 3x settle cost")


func _test_audit_legislative_evaporation() -> void:
	print("-- The Audit: fight with Legislative Assets evaporates case --")
	var game := _build_test_game()
	game.economy.cash = 100000.0
	game.peak_net_worth = 100000.0

	# Give player 1 Legislative Asset (Earth property 11, index 10)
	var leg_prop := game.economy.properties[10] as PropertyState
	leg_prop.units_owned = 1

	var count := EventState.get_legislative_assets_count(game)
	_assert(count == 1, "Player owns 1 Legislative Asset")

	var data := game.events.trigger_audit(game)
	_assert(data["has_enough_legislators"] == true, "Audit recognizes legislative influence")

	# Resolve by Fight (choice 1)
	var outcome := game.events.resolve_audit(1, game)
	_assert(outcome["success"] == true, "Case evaporated due to legislative assets")
	_assert(outcome["cost_paid"] == 0.0, "Zero dollars paid")
	_assert(game.economy.cash == 100000.0, "Treasury untouched ($100k)")


func _test_windfall_grant() -> void:
	print("-- The Windfall: instant capital grant --")
	var game := _build_test_game()
	game.economy.cash = 50000.0
	game.peak_net_worth = 50000.0
	var net_worth := EventState.get_current_net_worth(game)
	var expected_grant := floorf(net_worth * game.tuning.windfall_net_worth_fraction)

	var granted := game.events.trigger_windfall(game)
	_assert_approx(granted, expected_grant, 0.01, "Windfall granted 10% of net worth ($" + str(int(expected_grant)) + ")")
	_assert_approx(game.economy.cash, 50000.0 + expected_grant, 0.01, "Cash increased by windfall grant")


func _test_events_save_load_round_trip() -> void:
	print("-- Save/Load Round Trip --")
	var game := _build_test_game()
	game.events.trigger_crash(5.0, game)
	game.events.active_event_remaining = 142.5

	var save_dict := game.to_save_dict()
	_assert(save_dict.has("events"), "Save dict includes events payload")

	var restored_game := _build_test_game()
	restored_game.load_save_dict(save_dict)

	_assert(restored_game.events.is_crash_active(), "Restored game preserves active crash")
	_assert_approx(restored_game.events.active_event_remaining, 142.5, 0.01, "Restored remaining duration matches exactly")
	_assert(restored_game.events.get_property_income_multiplier() == 0.5, "Restored multiplier is 0.5")


func _test_prestige_weather_reset() -> void:
	print("-- Prestige: transient weather resets for new generation --")
	var tuning := ConfigLoader.load_tuning(false)
	var configs := ConfigLoader.load_property_configs()
	var dynasty := DynastyState.new(configs, tuning)

	# Start crash on current generation
	dynasty.current.events.trigger_crash(10.0, dynasty.current)
	_assert(dynasty.current.events.is_crash_active(), "Crash active on living generation")

	# Perform succession
	dynasty.perform_succession("Retired to Palm Beach", 1.0)
	_assert(!dynasty.current.events.is_crash_active(), "New heir wakes up with clean weather (no crash)")
	_assert(dynasty.current.events.get_property_income_multiplier() == 1.0, "New heir has 1.0 income multiplier")
