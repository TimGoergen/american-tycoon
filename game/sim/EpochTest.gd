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
	if tuning == null or property_configs.is_empty():
		print("FAILED to load configs")
		quit(1)
		return

	_test_thresholds(tuning)
	_test_epoch_advances(property_configs, tuning)
	_test_staff_tier_income(property_configs, tuning)
	_test_save_round_trip(property_configs, tuning)
	_test_staff_retention(property_configs, tuning)
	_test_staff_levels(property_configs, tuning)
	_test_epoch_content()

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
	_check("Luminari (tier 2) threshold == Earth target x30 (2026-06-27 ladder)",
		is_equal_approx(EpochCatalog.consume_threshold(2, earth), earth * 30.0))
	_check("There are 6 epochs (Earth + 5 aliens)", EpochCatalog.tier_count() == 6)
	_check("Earth staffer multiplier is 1.0 (no income change)",
		is_equal_approx(EpochCatalog.staff_income_multiplier(1), 1.0))
	_check("Alien staffer multiplier is > 1.0", EpochCatalog.staff_income_multiplier(2) > 1.0)


func _test_epoch_advances(configs: Array, tuning: TuningConfig) -> void:
	print("\n2. A generation advances epochs as lifetime earnings cross thresholds")
	var game := GameState.new(configs, tuning)
	_check("starts in epoch 1 (Earth)", game.epoch.current_tier == 1)

	# Just under the Earth threshold: still Earth.
	game.epoch.update(tuning.earth_economy_target - 1.0)
	_check("just under Earth's value: still epoch 1", game.epoch.current_tier == 1)

	# Exactly consume Earth's economy: contact with Luminari (epoch 2).
	game.epoch.update(tuning.earth_economy_target)
	_check("consumed Earth's economy: advanced to epoch 2", game.epoch.current_tier == 2)

	# A huge jump can cross several epochs at once, capped at the last defined epoch.
	game.epoch.update(tuning.earth_economy_target * 1e30)
	_check("enormous earnings cap at the last epoch (6)", game.epoch.current_tier == EpochCatalog.tier_count())


func _test_staff_tier_income(configs: Array, tuning: TuningConfig) -> void:
	print("\n3 & 4. Hiring raises tier + income, and is gated by the reached epoch")
	var game := GameState.new(configs, tuning)
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


func _test_save_round_trip(configs: Array, tuning: TuningConfig) -> void:
	print("\n5. Save/reload round-trips staff_tier and the reached epoch")
	var game := GameState.new(configs, tuning)
	game.economy.award_cash(1.0e18)
	game.try_buy(0, 30)
	game.epoch.current_tier = 3          # pretend we reached the Geth-Sentinel epoch
	game.try_hire(0)                     # ATM staffer climbs tier 1
	game.try_hire(0)                     # → tier 2
	game.try_hire(0)                     # → tier 3
	var atm := game.economy.properties[0] as PropertyState
	_check("ATM reached staff tier 3 before save", atm.staff_tier == 3)

	var dict := game.to_save_dict()
	var reloaded := GameState.new(configs, tuning)
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
	var migrated := GameState.new(configs, tuning)
	migrated.load_save_dict(legacy_dict)
	var atm3 := migrated.economy.properties[0] as PropertyState
	_check("pre-v5 is_staffed:true migrates to staff_tier 1", atm3.staff_tier == 1)
	_check("pre-v5 save defaults to epoch 1", migrated.epoch.current_tier == 1)


## Phase 2: a Legacy-bought retained staffer tier carries into the heir on succession.
func _test_staff_retention(configs: Array, tuning: TuningConfig) -> void:
	print("\n6. Per-staffer retention carries a staffer tier across prestige (GDD §6.3)")
	var dynasty := DynastyState.new(configs, tuning)
	var game := dynasty.current
	game.economy.award_cash(1.0e18)
	game.try_buy(0, 50)              # own some ATMs so the staffer earns
	game.epoch.current_tier = 2     # pretend Luminari contact, so tier 2 is hireable
	game.try_hire(0)                 # ATM staffer → tier 1
	game.try_hire(0)                 # ATM staffer → tier 2
	var atm := game.economy.properties[0] as PropertyState
	_check("ATM staffer reached tier 2 this life", atm.staff_tier == 2)

	# Retention is refused with no Legacy in the wallet.
	_check("retention refused when wallet is empty", not dynasty.buy_staff_retention(0))

	# Bank Legacy, then retain the ATM staffer up to tier 2 (two purchases).
	dynasty.upgrades.award(100)
	var wallet_before := dynasty.upgrades.available
	_check("retain ATM to tier 1 succeeds", dynasty.buy_staff_retention(0))
	_check("retain ATM to tier 2 succeeds", dynasty.buy_staff_retention(0))
	_check("ATM retained tier is now 2", dynasty.staff_retention.get_retained_tier(0) == 2)
	# A third purchase is refused — can't retain above the staffer's current tier (2).
	_check("retention refused above the live staffer tier", not dynasty.buy_staff_retention(0))

	var expected_spend := dynasty.staff_retention.cost_for_tier(1) + dynasty.staff_retention.cost_for_tier(2)
	_check("Legacy wallet was charged the two tiers' cost",
		dynasty.upgrades.available == wallet_before - expected_spend)

	# Pass on. The heir should be born with the ATM already staffed at tier 2 (no units).
	dynasty.perform_succession()
	var heir_atm := dynasty.current.economy.properties[0] as PropertyState
	_check("heir is born with the ATM staffer at the retained tier 2", heir_atm.staff_tier == 2)
	_check("heir's retained staffer carries the tier-2 income multiplier",
		is_equal_approx(heir_atm.staff_income_multiplier, EpochCatalog.staff_income_multiplier(2)))
	_check("heir starts with no ATM units (only the staffer is retained, not holdings)",
		heir_atm.units_owned == 0)

	# Retention survives a dynasty save round-trip.
	var data := dynasty.to_save_dict()
	var reloaded := DynastyState.new(configs, tuning)
	reloaded.load_save_dict(data)
	_check("retained tiers survive a dynasty save round-trip",
		reloaded.staff_retention.get_retained_tier(0) == 2)


## The within-epoch staff-level track (Option A, 2026-06-27): hiring is followed by leveling
## the same staffer up through the epoch, each level a compounding income bonus; levels reset
## when the tier advances, and the cost climbs geometrically.
func _test_staff_levels(configs: Array, tuning: TuningConfig) -> void:
	print("\n8. Within-epoch staff levels: compounding income, reset on tier change, geometric cost")
	var game := GameState.new(configs, tuning)
	game.economy.award_cash(1.0e24)
	game.try_buy(0, 50)
	var atm := game.economy.properties[0] as PropertyState

	# Unstaffed: leveling is impossible until a staffer is hired.
	_check("unstaffed property has zero level cost", is_equal_approx(game.economy.get_staff_level_cost(0), 0.0))
	_check("unstaffed property refuses a level upgrade", not game.try_upgrade_staff_level(0))

	# Hire the Earth staffer (tier 1, multiplier 1.0), then level it up once.
	game.try_hire(0)
	var income_level0 := atm.get_income_per_sec()
	_check("a level upgrade succeeds once staffed", game.try_upgrade_staff_level(0))
	_check("ATM is now staff level 1", atm.staff_level == 1)
	var income_level1 := atm.get_income_per_sec()
	_check("one level multiplies income by (1 + staff_level_step)",
		income_level0 > 0.0 and is_equal_approx(income_level1 / income_level0, 1.0 + tuning.staff_level_step))

	# Advancing the tier (a fresh alien staffer at contact) resets the level track to 0.
	_check("ATM has a level before contact", atm.staff_level == 1)
	game.epoch.current_tier = 2
	game.try_hire(0)  # upgrade to the tier-2 alien staffer
	_check("ATM advanced to tier 2", atm.staff_tier == 2)
	_check("staff level reset to 0 on the new tier", atm.staff_level == 0)

	# The level cost climbs geometrically with each level. Checked at tier 2, where the
	# trillions-scale numbers make the $5 cost-rounding negligible (at Earth scale the
	# snapping would distort the ratio).
	var cost_level_1 := game.economy.get_staff_level_cost(0)
	game.try_upgrade_staff_level(0)
	var cost_level_2 := game.economy.get_staff_level_cost(0)
	_check("staff level 2 cost > level 1 cost (geometric)", cost_level_2 > cost_level_1)
	_check("level cost grows by staff_level_cost_growth",
		cost_level_1 > 0.0 and is_equal_approx(cost_level_2 / cost_level_1, tuning.staff_level_cost_growth))

	# Levels survive a save/reload round-trip (v7). Level is 1 from the geometric check above;
	# two more brings it to 3.
	game.try_upgrade_staff_level(0)
	game.try_upgrade_staff_level(0)
	_check("ATM reached staff level 3 before save", atm.staff_level == 3)
	var reloaded := GameState.new(configs, tuning)
	reloaded.load_save_dict(game.to_save_dict())
	var atm2 := reloaded.economy.properties[0] as PropertyState
	_check("reloaded ATM staff_level == 3 (v7 round-trip)", atm2.staff_level == 3)

	# A pre-v7 save (no staff_level key) defaults the level to 0.
	var legacy_dict := game.to_save_dict()
	for prop_dict in legacy_dict["properties"]:
		prop_dict.erase("staff_level")
	var migrated := GameState.new(configs, tuning)
	migrated.load_save_dict(legacy_dict)
	var atm3 := migrated.economy.properties[0] as PropertyState
	_check("pre-v7 save defaults staff_level to 0", atm3.staff_level == 0)


## Phase 4: every epoch ships a full 12-staffer roster, and every alien epoch ships a
## narrator contact line. Guards against a new epoch row being added with missing copy.
func _test_epoch_content() -> void:
	print("\n7. Every epoch has a full staffer roster (and aliens have contact copy)")
	for tier in range(1, EpochCatalog.tier_count() + 1):
		var epoch := EpochCatalog.get_epoch(tier)
		var civ := String(epoch["civilization"])
		var names: Array = epoch["staffer_names"]
		_check("epoch %d (%s) has 12 staffer names" % [tier, civ], names.size() == 12)
		var all_named := true
		for staffer in names:
			if String(staffer).strip_edges() == "":
				all_named = false
		_check("epoch %d staffer names are all non-empty" % tier, all_named)
		if tier >= 2:
			_check("epoch %d (%s) has a contact line" % [tier, civ],
				EpochCatalog.contact_line(tier).strip_edges() != "")
