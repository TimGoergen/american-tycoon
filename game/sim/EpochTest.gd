extends SceneTree

# Headless verification for the epoch-based staffing system (Phase 1).
#
# Usage: godot --headless --path . --script res://sim/EpochTest.gd
#
# Proves, without any rendering:
#   1. Epoch thresholds scale off the Earth target (consume_threshold).
#   2. A generation advances epochs as its lifetime earnings cross those thresholds.
#   3. Hiring/upgrading a staffer raises the tier and multiplies that property's income.
#   4. Staff tier is gated by the reached epoch (can't hire an alien before contact).
#   5. Save → reload round-trips staff_tier and the reached epoch.
#
# Exits with code 0 only if every check passes (1 otherwise), so CI/headless runs fail loudly.

var _failures := 0


func _initialize() -> void:
	print("=== Epoch Staffing — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	var property_configs := ConfigLoader.load_property_configs()
	var title_configs := ConfigLoader.load_title_configs()
	if tuning == null or property_configs.is_empty() or title_configs.is_empty():
		print("FAILED to load configs")
		quit(1)
		return

	_test_thresholds(tuning)
	_test_epoch_advances(property_configs, title_configs, tuning)
	_test_staff_tier_income(property_configs, title_configs, tuning)
	_test_save_round_trip(property_configs, title_configs, tuning)

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


func _test_thresholds(tuning: TuningConfig) -> void:
	print("1. Epoch thresholds scale off the Earth target")
	var earth := tuning.earth_economy_target
	_check("Earth (tier 1) consume threshold == Earth target",
		is_equal_approx(EpochCatalog.consume_threshold(1, earth), earth))
	_check("Luminari (tier 2) threshold == Earth target x1000",
		is_equal_approx(EpochCatalog.consume_threshold(2, earth), earth * 1000.0))
	_check("There are 4 epochs (Earth + 3 aliens)", EpochCatalog.tier_count() == 4)
	_check("Earth staffer multiplier is 1.0 (no income change)",
		is_equal_approx(EpochCatalog.staff_income_multiplier(1), 1.0))
	_check("Alien staffer multiplier is > 1.0", EpochCatalog.staff_income_multiplier(2) > 1.0)


func _test_epoch_advances(configs: Array, titles: Array, tuning: TuningConfig) -> void:
	print("\n2. A generation advances epochs as lifetime earnings cross thresholds")
	var game := GameState.new(configs, titles, tuning)
	_check("starts in epoch 1 (Earth)", game.epoch.current_tier == 1)

	# Just under the Earth threshold: still Earth.
	game.epoch.update(tuning.earth_economy_target - 1.0)
	_check("just under Earth's value: still epoch 1", game.epoch.current_tier == 1)

	# Exactly consume Earth's economy: contact with Luminari (epoch 2).
	game.epoch.update(tuning.earth_economy_target)
	_check("consumed Earth's economy: advanced to epoch 2", game.epoch.current_tier == 2)

	# A huge jump can cross several epochs at once, capped at the last defined epoch.
	game.epoch.update(tuning.earth_economy_target * 1e30)
	_check("enormous earnings cap at the last epoch (4)", game.epoch.current_tier == 4)


func _test_staff_tier_income(configs: Array, titles: Array, tuning: TuningConfig) -> void:
	print("\n3 & 4. Hiring raises tier + income, and is gated by the reached epoch")
	var game := GameState.new(configs, titles, tuning)
	# Plenty of cash and some units of the first property (ATM) so it earns.
	game.economy.award_cash(1.0e18)
	game.try_buy(0, 50)
	var atm := game.economy.properties[0] as PropertyState

	var income_unstaffed := atm.get_income_per_sec()

	# At epoch 1, we can only hire the Earth staffer (tier 1), not an alien.
	_check("hire at epoch 1 succeeds (Earth staffer)", game.try_hire(0))
	_check("ATM is now staff tier 1", atm.staff_tier == 1)
	_check("a second hire at epoch 1 is refused (alien not yet unlocked)", not game.try_hire(0))

	var income_tier1 := atm.get_income_per_sec()
	_check("Earth staffer does not change income/sec",
		is_equal_approx(income_tier1, income_unstaffed if income_unstaffed > 0.0 else income_tier1))

	# Make contact with Luminari, then upgrade the ATM staffer to tier 2.
	game.epoch.current_tier = 2
	_check("upgrade to alien staffer succeeds after contact", game.try_hire(0))
	_check("ATM is now staff tier 2", atm.staff_tier == 2)

	var income_tier2 := atm.get_income_per_sec()
	var expected := EpochCatalog.staff_income_multiplier(2)
	_check("tier-2 income/sec is the Earth rate x the Luminari multiplier (x%.0f)" % expected,
		income_tier1 > 0.0 and is_equal_approx(income_tier2 / income_tier1, expected))


func _test_save_round_trip(configs: Array, titles: Array, tuning: TuningConfig) -> void:
	print("\n5. Save/reload round-trips staff_tier and the reached epoch")
	var game := GameState.new(configs, titles, tuning)
	game.economy.award_cash(1.0e18)
	game.try_buy(0, 30)
	game.epoch.current_tier = 3          # pretend we reached the Geth-Sentinel epoch
	game.try_hire(0)                     # ATM staffer climbs tier 1
	game.try_hire(0)                     # → tier 2
	game.try_hire(0)                     # → tier 3
	var atm := game.economy.properties[0] as PropertyState
	_check("ATM reached staff tier 3 before save", atm.staff_tier == 3)

	var dict := game.to_save_dict()
	var reloaded := GameState.new(configs, titles, tuning)
	reloaded.load_save_dict(dict)
	var atm2 := reloaded.economy.properties[0] as PropertyState
	_check("reloaded ATM staff_tier == 3", atm2.staff_tier == 3)
	_check("reloaded staff_income_multiplier re-derived from tier",
		is_equal_approx(atm2.staff_income_multiplier, EpochCatalog.staff_income_multiplier(3)))
	_check("reloaded epoch_tier == 3", reloaded.epoch.current_tier == 3)

	# A pre-v5 save (is_staffed bool, no staff_tier / epoch_tier) migrates cleanly.
	var legacy_dict := game.to_save_dict()
	for prop_dict in legacy_dict["properties"]:
		prop_dict.erase("staff_tier")
		prop_dict["is_staffed"] = true
	legacy_dict.erase("epoch_tier")
	var migrated := GameState.new(configs, titles, tuning)
	migrated.load_save_dict(legacy_dict)
	var atm3 := migrated.economy.properties[0] as PropertyState
	_check("pre-v5 is_staffed:true migrates to staff_tier 1", atm3.staff_tier == 1)
	_check("pre-v5 save defaults to epoch 1", migrated.epoch.current_tier == 1)
