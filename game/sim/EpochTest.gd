extends SceneTree

# Headless verification for the epoch staffing system — the SEQUENTIAL STAFF LADDER
# (epoch-depth redesign, GDD §6.1 / Plans/Epoch_Depth_Pass.md, 2026-07-04).
#
# Usage: godot --headless --path . --script res://sim/EpochTest.gd
#
# Proves, without any rendering:
#   1. Epoch thresholds scale off the Earth target (consume_threshold).
#   2. A generation advances epochs as its lifetime earnings cross those thresholds.
#   3. The staff ladder: hiring IS level 1, blocks open per epoch, order via the cap.
#   4. HOME-EPOCH anchoring: a block's prices never change when a later epoch arrives
#      (the regression test for Tim's 2026-07-03 transition repricing bug).
#   5. Save → reload round-trips staff_level; pre-v9 tier+level saves migrate.
#   6. Retention wills COMPLETE blocks across prestige, escalating Legacy cost per block.
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
	_test_staff_ladder_basics(property_configs, tuning)
	_test_staff_ladder_costs(property_configs, tuning)
	_test_save_round_trip(property_configs, tuning)
	_test_staff_retention(property_configs, tuning)
	_test_epoch_content(property_configs)
	_test_epoch_locked_properties(property_configs, tuning)
	_test_first_contact_grant(property_configs, tuning)

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
	# The EARTH SPLIT (Plans/Earth_Split_Epochs.md, 2026-07-27): Blue Collar (tier 1) clears
	# at $75M (a fixed fraction of the Earth target), White Collar (tier 2) at the full Earth
	# target — the alien-frontier entry bar the split left unchanged.
	_check("Blue Collar (tier 1) consume threshold == $75M",
		is_equal_approx(EpochCatalog.consume_threshold(1, earth), earth * (75e6 / 103.6e12)))
	_check("White Collar (tier 2) consume threshold == Earth target",
		is_equal_approx(EpochCatalog.consume_threshold(2, earth), earth))
	# Continuous-ladder rework (2026-07-12): the threshold grows one 5-rung ladder block per
	# alien epoch (7^5 = 16807x); staff is a FLAT modest boost (multiplier 1.0 every tier).
	_check("Luminari (tier 3) threshold == Earth target x16807 (7^5, continuous ladder)",
		is_equal_approx(EpochCatalog.consume_threshold(3, earth), earth * 16807.0))
	# 27 epochs: the two Earth epochs (Blue/White Collar) + 25 aliens. Full 326-property ladder.
	_check("There are 27 epochs (Earth split + 25 aliens)", EpochCatalog.tier_count() == 27)
	_check("Staffer multiplier is FLAT 1.0 at every tier (the ladder carries the leap, not staff)",
		is_equal_approx(EpochCatalog.staff_income_multiplier(1), 1.0) \
			and is_equal_approx(EpochCatalog.staff_income_multiplier(2), 1.0) \
			and is_equal_approx(EpochCatalog.staff_income_multiplier(7), 1.0))


func _test_epoch_advances(configs: Array, tuning: TuningConfig) -> void:
	print("\n2. A generation advances epochs as lifetime earnings cross thresholds")
	var game := GameState.new(configs, tuning)
	_check("starts in epoch 1 (Earth Blue Collar)", game.epoch.current_tier == 1)

	# Just under the Blue Collar threshold: still tier 1.
	var blue_threshold := EpochCatalog.consume_threshold(1, tuning.earth_economy_target)
	game.epoch.update(blue_threshold - 1.0)
	_check("just under Blue Collar's value: still epoch 1", game.epoch.current_tier == 1)

	# Consume Blue Collar: the promotion into White Collar (epoch 2).
	game.epoch.update(blue_threshold)
	_check("consumed Blue Collar: promoted to epoch 2 (White Collar)", game.epoch.current_tier == 2)

	# Just under the full Earth target: still White Collar.
	game.epoch.update(tuning.earth_economy_target - 1.0)
	_check("just under Earth's full value: still epoch 2", game.epoch.current_tier == 2)

	# Exactly consume Earth's economy: contact with Luminari (epoch 3).
	game.epoch.update(tuning.earth_economy_target)
	_check("consumed Earth's economy: advanced to epoch 3 (Luminari)", game.epoch.current_tier == 3)

	# A huge jump can cross several epochs at once, capped at the last defined epoch. The factor is
	# large enough to blow past the top threshold regardless of how many epochs exist.
	game.epoch.update(tuning.earth_economy_target * 1e120)
	_check("enormous earnings cap at the last epoch", game.epoch.current_tier == EpochCatalog.tier_count())


func _test_staff_ladder_basics(configs: Array, tuning: TuningConfig) -> void:
	print("\n3. The staff ladder: hiring is level 1, blocks open per epoch, effects are per-block")
	var game := GameState.new(configs, tuning)
	# Plenty of cash and some units of the first property (ATM) so it earns.
	game.economy.award_cash(1.0e30)
	game.try_buy(0, 50)
	var atm := game.economy.properties[0] as PropertyState
	var per_block := tuning.staff_levels_per_epoch

	# Level 1 = the Earth hire: automation on, no income jump (entry step 0).
	var income_unstaffed := atm.get_income_per_sec()
	_check("level 1 (the hire) succeeds at epoch 1", game.try_buy_staff_level(0))
	_check("ATM is staffed after level 1", atm.is_staffed)
	_check("derived staff tier is 1 (the Earth block)", atm.staff_tier == 1)
	var income_hired := atm.get_income_per_sec()
	_check("the first hire is automation-only (income unchanged)",
		is_equal_approx(income_hired, income_unstaffed if income_unstaffed > 0.0 else income_hired))

	# Level 2 = the first small step: adds exactly staff_level_step (Earth block's step).
	_check("level 2 succeeds", game.try_buy_staff_level(0))
	_check("Earth-block levels are additive small steps",
		is_equal_approx(atm._effective_staff_multiplier(), 1.0 + tuning.staff_level_step))

	# The whole Blue Collar block is open at epoch 1 — and nothing past it.
	while not game.economy.is_staff_level_maxed(0, 1):
		game.try_buy_staff_level(0)
	_check("epoch 1 caps the ladder at one full block", atm.staff_level == per_block)
	_check("the White Collar hire (level %d) is refused before the promotion" % (per_block + 1),
		not game.try_buy_staff_level(0))

	# The promotion (epoch 2): the next block opens; its level 1 is the White Collar-era
	# hire (the Earth split's early staff-depth beat). Under the FLAT staff model
	# (continuous-ladder rework, 2026-07-12) a hire is automation only — no entry jump — and every
	# block's per-level step is the SAME modest size (the property's base magnitude carries the leap).
	game.epoch.current_tier = 2
	var multiplier_before := atm._effective_staff_multiplier()
	_check("the White Collar hire succeeds after the promotion", game.try_buy_staff_level(0))
	_check("derived staff tier advanced to 2", atm.staff_tier == 2)
	_check("block 2's hire adds no entry jump (flat staff)",
		is_equal_approx(atm.staff_entry_step(2), 0.0))
	_check("block 2's per-level step equals Earth's (flat staff)",
		is_equal_approx(atm.staff_small_step(2), atm.staff_small_step(1)))


func _test_save_round_trip(configs: Array, tuning: TuningConfig) -> void:
	print("\n5. Save/reload round-trips the staff ladder; pre-v9 saves migrate")
	var game := GameState.new(configs, tuning)
	game.economy.award_cash(1.0e30)
	game.try_buy(0, 30)
	game.epoch.current_tier = 2
	# Climb into the second block so both the level and the derived tier are non-trivial.
	for _i in range(tuning.staff_levels_per_epoch + 3):
		game.try_buy_staff_level(0)
	var atm := game.economy.properties[0] as PropertyState
	var level_before := atm.staff_level
	_check("ATM climbed into block 2 before save", atm.staff_tier == 2)

	var dict := game.to_save_dict()
	var reloaded := GameState.new(configs, tuning)
	reloaded.load_save_dict(dict)
	var atm2 := reloaded.economy.properties[0] as PropertyState
	_check("reloaded staff_level round-trips", atm2.staff_level == level_before)
	_check("reloaded derived staff tier matches", atm2.staff_tier == 2)
	_check("reloaded staff multiplier matches (derived, never stored)",
		is_equal_approx(atm2._effective_staff_multiplier(), atm._effective_staff_multiplier()))
	_check("reloaded epoch_tier == 2", reloaded.epoch.current_tier == 2)

	# A pre-v9 save stored a staff TIER (separate hire purchases) beside the level ladder.
	# Each old hire becomes one ladder level: tier 2 + 25 levels → level 27 on one ladder.
	var v8_dict := game.to_save_dict()
	v8_dict["version"] = 8
	for prop_dict in v8_dict["properties"]:
		prop_dict["staff_tier"] = 2
		prop_dict["staff_level"] = 25
	var migrated_v8 := GameState.new(configs, tuning)
	migrated_v8.load_save_dict(v8_dict)
	var atm_v8 := migrated_v8.economy.properties[0] as PropertyState
	_check("pre-v9 tier 2 + level 25 merges to ladder level 27", atm_v8.staff_level == 27)

	# The v12 EARTH SPLIT migration (Plans/Earth_Split_Epochs.md): a pre-v12 save's alien
	# tiers shift up one, and a mid-Earth tier-1 save maps to White Collar exactly when it
	# already owns a White Collar property (indices 6-11).
	var v11_alien := game.to_save_dict()
	v11_alien["version"] = 11
	v11_alien["epoch_tier"] = 2  # old Luminari
	var migrated_alien := GameState.new(configs, tuning)
	migrated_alien.load_save_dict(v11_alien)
	_check("v11 epoch_tier 2 (old Luminari) migrates to tier 3", migrated_alien.epoch.current_tier == 3)
	var v11_white := game.to_save_dict()
	v11_white["version"] = 11
	v11_white["epoch_tier"] = 1
	(v11_white["properties"][6] as Dictionary)["units_owned"] = 3  # owns Day Trading
	var migrated_white := GameState.new(configs, tuning)
	migrated_white.load_save_dict(v11_white)
	_check("v11 tier-1 save owning a White Collar property migrates to tier 2",
		migrated_white.epoch.current_tier == 2)
	var v11_blue := game.to_save_dict()
	v11_blue["version"] = 11
	v11_blue["epoch_tier"] = 1
	for k in range(6, 12):
		(v11_blue["properties"][k] as Dictionary)["units_owned"] = 0
	var migrated_blue := GameState.new(configs, tuning)
	migrated_blue.load_save_dict(v11_blue)
	_check("v11 tier-1 save with no White Collar holdings stays tier 1 (Blue Collar)",
		migrated_blue.epoch.current_tier == 1)

	# A pre-v5 save (is_staffed bool only) becomes a single hire (ladder level 1).
	var legacy_dict := game.to_save_dict()
	legacy_dict["version"] = 4
	legacy_dict.erase("epoch_tier")
	for prop_dict in legacy_dict["properties"]:
		prop_dict.erase("staff_tier")
		prop_dict.erase("staff_level")
		prop_dict["is_staffed"] = true
	var migrated := GameState.new(configs, tuning)
	migrated.load_save_dict(legacy_dict)
	var atm3 := migrated.economy.properties[0] as PropertyState
	_check("pre-v5 is_staffed:true migrates to ladder level 1", atm3.staff_level == 1)
	_check("pre-v5 save defaults to epoch 1", migrated.epoch.current_tier == 1)


## Retention wills the staff ladder across prestige ONE LEVEL AT A TIME (GDD §6.3,
## decision 2026-07-04, clarified: individual steps, not whole blocks): levels retain
## in order, capped at the living ladder, each additional level costing more Legacy.
func _test_staff_retention(configs: Array, tuning: TuningConfig) -> void:
	print("\n6. Retention wills the ladder level-by-level, escalating Legacy cost")
	var dynasty := DynastyState.new(configs, tuning)
	var game := dynasty.current
	game.economy.award_cash(1.0e30)
	game.try_buy(0, 50)              # own some ATMs so the staffer earns

	# Climb the ATM's ladder to level 5 this life.
	for _i in range(5):
		game.try_buy_staff_level(0)
	var atm := game.economy.properties[0] as PropertyState
	_check("ATM climbed to ladder level 5 this life", atm.staff_level == 5)

	# Retention is refused with no Legacy in the wallet.
	_check("retention refused when wallet is empty", not dynasty.buy_staff_retention(0))

	# Bank Legacy, then retain the first three levels — one purchase per level.
	dynasty.upgrades.award(1000)
	var wallet_before := dynasty.upgrades.available
	for _i in range(3):
		_check("retaining the next level succeeds", dynasty.buy_staff_retention(0))
	_check("ATM retained levels == 3", dynasty.staff_retention.get_retained_levels(0) == 3)

	# Each additional level costs more (the escalating path, mirroring the ladder), and
	# a higher property's retention costs more than the same level on a lower one (the
	# per-property term added in the 2026-07-07 repricing).
	var expected_spend := 0
	for level in range(1, 4):
		expected_spend += dynasty.staff_retention.cost_for_level(0, level)
	_check("a deep level costs more Legacy than an early one",
		dynasty.staff_retention.cost_for_level(0, 30) > dynasty.staff_retention.cost_for_level(0, 1))
	_check("a higher property's retention costs more than a lower one's",
		dynasty.staff_retention.cost_for_level(11, 1) > dynasty.staff_retention.cost_for_level(0, 1))
	_check("Legacy wallet was charged the three levels' cost",
		dynasty.upgrades.available == wallet_before - expected_spend)

	# Escalating-ladder re-anchor (Tim 2026-07-15): retention prices by STAFF PRICE
	# RANK, not global array index, so every epoch's flagship prices identically
	# (rank 12) and an appended cohort sibling can never out-price a later epoch's
	# flagship the way raw indices did.
	# Tier 3 = the first ALIEN epoch (the Earth split holds tiers 1-2); Earth properties keep
	# their index ranks, so only alien flagships share the anchored rank 12.
	var flagship_3 := game.economy.get_property_index_for_unlock_tier(3)
	# The LAST epoch that actually ships properties — not tier_count(): a flavor-only epoch
	# (Path A) adds no property cohort, so tier_count() may have no flagship.
	var last_prop_tier := 3
	for ps in game.economy.properties:
		last_prop_tier = maxi(last_prop_tier, ((ps as PropertyState).config as PropertyConfig).unlock_tier)
	var flagship_last := game.economy.get_property_index_for_unlock_tier(last_prop_tier)
	_check("every alien epoch's flagship retention prices identically (rank 12)",
		flagship_3 >= 0 and flagship_last >= 0
			and dynasty.staff_retention.cost_for_level(flagship_3, 1)
				== dynasty.staff_retention.cost_for_level(flagship_last, 1))

	# THE NAMING TRAP — rehomed here 2026-08-07 from sim/AutoPurchaseTest.gd.
	#
	# EconomyState has two lookups whose names both say "flagship" and they mean OPPOSITE things:
	#   - get_property_index_for_unlock_tier(tier)  -> the cohort's CHEAPEST member, its entry rung
	#     and the First Contact trade-deal anchor. It is the one used a few lines above, and the one
	#     this suite has always called "the flagship".
	#   - get_flagship_index_for_unlock_tier(tier)  -> the cohort's MOST EXPENSIVE property, which is
	#     what the 35-unit epoch-advance gate reads (GameState.can_advance_epoch).
	#
	# Both names are right for their own job; only the naming collides. This assertion lived in
	# AutoPurchaseTest because auto-purchase had to exclude the expensive one — that exclusion was
	# dropped in the restructure (Plans/Auto_Purchase_Restructure.md), which would have deleted the
	# guard along with its host. The collision is still real and still dangerous, so it moved to the
	# suite that reads one of the pair: a future rename merging them breaks a test rather than
	# silently changing which property gates epoch advance.
	var entry_rung := game.economy.get_property_index_for_unlock_tier(3)
	var gate_flagship := game.economy.get_flagship_index_for_unlock_tier(3)
	_check("the cohort's entry rung and its epoch-advance gate are DIFFERENT properties "
		+ "(entry %d, gate %d)" % [entry_rung, gate_flagship], entry_rung != gate_flagship)
	_check("...and the gate one is the more expensive of the two",
		entry_rung >= 0 and gate_flagship >= 0
			and (game.economy.properties[gate_flagship] as PropertyState).get_next_cost()
				> (game.economy.properties[entry_rung] as PropertyState).get_next_cost())

	# Pass on with only 3 of the 5 levels retained. The heir is born at the 3 retained
	# levels — no units — and the bloodline records the ancestor's best (5) forever.
	dynasty.perform_succession()
	var heir_atm := dynasty.current.economy.properties[0] as PropertyState
	_check("heir is born with the 3 retained ladder levels", heir_atm.staff_level == 3)
	_check("heir's retained ladder carries its multiplier (level 3 = 2 small steps)",
		is_equal_approx(heir_atm._effective_staff_multiplier(), 1.0 + tuning.staff_level_step * 2.0))
	_check("heir starts with no ATM units (only the ladder is retained, not holdings)",
		heir_atm.units_owned == 0)

	# EVER-REACHED rule (Tim, 2026-07-04): prestige reset the living ladder, but the
	# Estate Office still sells retention up to the bloodline's best (5) — not merely
	# the heir's current 3 — so levels 4 and 5 remain buyable, and level 6 does not.
	_check("bloodline best survives prestige", dynasty.staff_retention.get_ladder_high(0) == 5)
	_check("post-prestige retention reaches the ancestor's best",
		dynasty.buy_staff_retention(0) and dynasty.buy_staff_retention(0))
	_check("retention refused past the bloodline's best", not dynasty.buy_staff_retention(0))

	# Retention + the bloodline record survive a dynasty save round-trip, and
	# pre-redesign retained TIERS migrate to a full block's worth of levels each.
	var data := dynasty.to_save_dict()
	var reloaded := DynastyState.new(configs, tuning)
	reloaded.load_save_dict(data)
	_check("retained levels survive a dynasty save round-trip",
		reloaded.staff_retention.get_retained_levels(0) == 5)
	_check("the bloodline's ladder high survives a dynasty save round-trip",
		reloaded.staff_retention.get_ladder_high(0) == 5)
	var legacy_retention := StaffRetention.new()
	legacy_retention.load_save_dict({"retained_tiers": {"0": 2}})
	_check("a pre-redesign retained tier migrates to a full block of levels",
		legacy_retention.get_retained_levels(0) == 2 * StaffRetention.LEVELS_PER_LEGACY_TIER)
	_check("migrated retention seeds the bloodline high too",
		legacy_retention.get_ladder_high(0) == 2 * StaffRetention.LEVELS_PER_LEGACY_TIER)


## HOME-EPOCH cost anchoring — the regression test for Tim's 2026-07-03 transition bug:
## a block's prices are constants of its own epoch, so reaching a later epoch can never
## reprice the rungs the player was already saving toward.
func _test_staff_ladder_costs(configs: Array, tuning: TuningConfig) -> void:
	print("\n4. Home-epoch anchoring: a later contact never reprices an earlier block")
	var game := GameState.new(configs, tuning)
	game.economy.award_cash(1.0e30)
	game.try_buy(0, 50)
	var per_block := tuning.staff_levels_per_epoch

	# Climb partway into the Earth block, then note the next rung's price.
	for _i in range(5):
		game.try_buy_staff_level(0)
	var price_at_earth := game.economy.get_next_staff_level_cost(0)
	# Reaching epoch 3 must leave that leftover Earth rung at its Earth price.
	game.epoch.current_tier = 3
	_check("a leftover Earth level keeps its Earth price after two contacts",
		is_equal_approx(game.economy.get_next_staff_level_cost(0), price_at_earth))

	# The cost curve inside a block: level 2 is the cheap step off the block's anchor,
	# and each further step grows by staff_level_cost_growth (loose compare — prices
	# round to clean numbers, which nudges exact ratios).
	var anchor := game.economy.get_staff_block_anchor(0, 1)
	var step_cost := game.economy.get_next_staff_level_cost(0)
	game.try_buy_staff_level(0)
	var next_step_cost := game.economy.get_next_staff_level_cost(0)
	_check("in-block step costs grow geometrically",
		step_cost > 0.0 and absf(next_step_cost / step_cost - tuning.staff_level_cost_growth) < 0.1)
	_check("step costs hang off the block's own anchor", step_cost < anchor)

	# Block anchors climb with their epoch: block 2 (White Collar-priced, the full Earth
	# economy) dwarfs block 1, and block 3 (Luminari-priced) dwarfs block 2 — priced once,
	# by their home epochs.
	var anchor_2 := game.economy.get_staff_block_anchor(0, 2)
	var anchor_3 := game.economy.get_staff_block_anchor(0, 3)
	_check("each block's anchor dwarfs the previous block's", anchor_2 > anchor and anchor_3 > anchor_2)
	# A block's level 1 (the hire) costs its full anchor — the meaningful entry spend.
	while (game.economy.properties[0] as PropertyState).staff_level < per_block:
		game.try_buy_staff_level(0)
	_check("a new block's level 1 costs that block's full anchor",
		is_equal_approx(game.economy.get_next_staff_level_cost(0), anchor_2))

	# An ALIEN property's ladder starts at its home epoch: no blocks (cap 0) before its
	# epoch is reached, one block once it is, and its later blocks are priced by the
	# epochs AFTER its home epoch. Tier 3 (Luminari) is the first alien epoch since the
	# Earth split made tier 2 White Collar.
	var alien_index := game.economy.get_property_index_for_unlock_tier(3)
	if alien_index < 0:
		_check("ladder ships an epoch-3 alien property (needed for this test)", false)
		return
	var alien := game.economy.properties[alien_index] as PropertyState
	_check("an alien property has no staff blocks before its epoch",
		alien.staff_blocks_available(2) == 0)
	_check("its home epoch opens exactly one block", alien.staff_blocks_available(3) == 1)
	_check("its block 2 is priced by the NEXT epoch (block epoch 4)",
		alien.staff_block_epoch(2) == 4)
	_check("its first hire is automation-only (entry step 0)",
		is_equal_approx(alien.staff_entry_step(1), 0.0))


## Phase 4: every epoch ships a staffer roster covering the whole property ladder, and every
## alien epoch ships a narrator contact line. Guards against a new epoch row being added with
## missing copy, or a new property leaving a roster short an entry (e.g. the alien properties).
func _test_epoch_content(configs: Array) -> void:
	print("\n7. Every epoch has a full staffer roster (and aliens have contact copy)")
	var ladder_size := configs.size()
	for tier in range(1, EpochCatalog.tier_count() + 1):
		var epoch := EpochCatalog.get_epoch(tier)
		var civ := String(epoch["civilization"])
		var names: Array = epoch["staffer_names"]
		_check("epoch %d (%s) has a staffer name per property (%d)" % [tier, civ, ladder_size],
			names.size() == ladder_size)
		var all_named := true
		for staffer in names:
			if String(staffer).strip_edges() == "":
				all_named = false
		_check("epoch %d staffer names are all non-empty" % tier, all_named)
		if tier >= 2:
			_check("epoch %d (%s) has a contact line" % [tier, civ],
				EpochCatalog.contact_line(tier).strip_edges() != "")


## Phase 1 of the First Contact "new property type" reward (GDD §5.5 site 2): a property
## carrying an unlock_tier above the run's reached epoch is hidden, cannot be bought, and is
## never the ladder peek rung — until the epoch is reached, after which it buys normally.
func _test_epoch_locked_properties(configs: Array, tuning: TuningConfig) -> void:
	print("\n9. A property locked behind a later epoch is hidden and unbuyable until reached")

	# The Earth split: Blue Collar (ids 1-6) is tier 1, unlocked from the start; White Collar
	# (ids 7-12) is tier 2; the alien property types (id 13+) carry tier 3 and up.
	var earth_tiers_ok := true
	for cfg in configs:
		var pc := cfg as PropertyConfig
		if pc.property_id <= 6 and pc.unlock_tier != 1:
			earth_tiers_ok = false
		elif pc.property_id > 6 and pc.property_id <= 12 and pc.unlock_tier != 2:
			earth_tiers_ok = false
		elif pc.property_id > 12 and pc.unlock_tier < 3:
			earth_tiers_ok = false
	_check("Blue Collar is tier 1, White Collar tier 2, aliens tier 3+", earth_tiers_ok)

	# Build a run where property index 0 is gated behind epoch 2 (a stand-in for a future
	# alien property). Duplicate the config so we never mutate the shared loaded resource.
	var gated_configs := configs.duplicate()
	var gated := (configs[0] as PropertyConfig).duplicate() as PropertyConfig
	gated.unlock_tier = 2
	gated_configs[0] = gated

	var game := GameState.new(gated_configs, tuning)
	game.economy.cash = 1.0e12  # plenty to afford anything — so only the lock can stop a buy

	# On Earth (tier 1) the gated property is locked.
	_check("gated property reads locked at tier 1",
		not game.economy.is_property_unlocked(0, 1))
	_check("buying the gated property at tier 1 fails", not game.try_buy(0, 1))
	_check("gated property owns nothing after the blocked buy",
		(game.economy.properties[0] as PropertyState).units_owned == 0)
	_check("locked property is never the peek rung at tier 1",
		game.economy.get_cheapest_unaffordable_unowned_index(1) != 0)

	# A normal tier-1 property is unaffected by the gate.
	_check("a tier-1 property is unlocked and buyable at tier 1",
		game.economy.is_property_unlocked(1, 1) and game.try_buy(1, 1))

	# Reaching epoch 2 opens the gated property; it now buys like any other.
	game.epoch.restore(2)
	_check("gated property reads unlocked at tier 2",
		game.economy.is_property_unlocked(0, 2))
	_check("buying the gated property succeeds once its epoch is reached", game.try_buy(0, 1))
	_check("gated property owns a unit after the successful buy",
		(game.economy.properties[0] as PropertyState).units_owned == 1)


## Phase 2 of the First Contact reward (GDD §5.5 site 2): the real ladder ships an alien property
## gated to epoch 2, the tier→property lookup finds it, and grant_starting_units hands over free
## units (the negotiation head start) without counting them as spend on the estate's book value.
func _test_first_contact_grant(configs: Array, tuning: TuningConfig) -> void:
	print("\n10. First Contact opens an escalating cohort per epoch (tier→cohort lookup)")

	# Every alien epoch T (2..last) ships an ESCALATING cohort of T + 4 properties gated
	# to it (escalating ladder rework, Tim 2026-07-15: 6 at epoch 2 up to 10 at epoch 6),
	# with the total ladder being Earth's 12 plus those cohorts. The cohort lookup returns
	# every member with the FLAGSHIP (cheapest member) first — the order the trade-deal
	# minigame and the bonus loop rely on — and the singular lookup resolves that flagship.
	var game_for_lookup := GameState.new(configs, tuning)

	# Earth's staff price ranks are its indices — the re-anchor changes nothing for Earth.
	_check("Earth staff price ranks equal their indices (0 and 11 spot-checked)",
		game_for_lookup.economy.get_staff_price_rank(0) == 0
			and game_for_lookup.economy.get_staff_price_rank(11) == 11)

	# Cohort sizes since the Earth split: tier 2 is White Collar's classic Earth six; the
	# alien escalation is unchanged in content, re-tiered +1 (6 rungs at tier 3 up to the
	# 14-rung cap from ~tier 11). Blue Collar's six are the `expected_total` seed.
	var expected_total := 6
	for tier in range(2, EpochCatalog.tier_count() + 1):
		var cohort := game_for_lookup.economy.get_property_indices_for_unlock_tier(tier)
		if cohort.is_empty():
			continue  # flavor-only epoch (Path A): re-skins the ladder, adds no new properties
		var expected_size := 6 if tier == 2 else mini(tier + 3, 14)
		expected_total += expected_size
		var gated := 0
		for cfg in configs:
			if (cfg as PropertyConfig).unlock_tier == tier:
				gated += 1
		_check("epoch %d ships a %d-property cohort" % [tier, expected_size],
			gated == expected_size)
		_check("epoch %d's cohort lookup returns all %d members" % [tier, expected_size],
			cohort.size() == expected_size)
		_check("epoch %d's flagship resolves via the singular tier lookup" % tier,
			game_for_lookup.economy.get_property_index_for_unlock_tier(tier) == cohort[0])

		# Gather the cohort's costs, sorted ascending — the cohort's true ladder order
		# (the array order interleaves original members with appended ones).
		var sorted_costs: Array[float] = []
		for member in cohort:
			sorted_costs.append(((game_for_lookup.economy.properties[member] \
					as PropertyState).config as PropertyConfig).base_cost)
		sorted_costs.sort()
		_check("epoch %d's flagship is its cohort's cheapest member" % tier,
			is_equal_approx(((game_for_lookup.economy.properties[cohort[0]] \
					as PropertyState).config as PropertyConfig).base_cost, sorted_costs[0]))

		# The cohort spans exactly one epoch's worth of cost (×16807 = 7^5, the threshold
		# growth) split evenly across its rungs: consecutive sorted costs step by
		# ~16807^(1/N), so the whole cohort spans ~16807^((N-1)/N). Loose tolerances —
		# authored costs round to clean numbers. White Collar (tier 2) predates the alien
		# grid and keeps Earth's classic ~×7 per rung (Day Trading $6M → Executive $100B).
		var rung_ratio := 7.0 if tier == 2 else pow(16807.0, 1.0 / float(expected_size))
		var spacing_ok := true
		for k in range(1, sorted_costs.size()):
			var step := sorted_costs[k] / sorted_costs[k - 1]
			if absf(step / rung_ratio - 1.0) > 0.05:
				spacing_ok = false
		_check("epoch %d's rungs are spaced ~x%.2f apart (16807^(1/%d))" \
				% [tier, rung_ratio, expected_size], spacing_ok)
		var span := sorted_costs[sorted_costs.size() - 1] / sorted_costs[0]
		var expected_span := pow(rung_ratio, float(expected_size - 1))
		_check("epoch %d's cohort spans ~x%.0f flagship-to-top" % [tier, expected_span],
			absf(span / expected_span - 1.0) < 0.10)

		# Staff price ranks (escalating ladder re-anchor): an ALIEN flagship ranks 12 — its
		# old global index, so flagship staff prices are unchanged — and the cohort's ranks
		# are exactly 12..12+N-1 in cost order, regardless of array positions. White Collar
		# (tier 2) is Earth: its properties keep their plain index ranks, 6..11.
		var rank_start := 6 if tier == 2 else 12
		var cohort_ranks: Array[int] = []
		for member in cohort:
			cohort_ranks.append(game_for_lookup.economy.get_staff_price_rank(member))
		cohort_ranks.sort()
		var ranks_contiguous := cohort_ranks.size() == expected_size
		for k in range(cohort_ranks.size()):
			if cohort_ranks[k] != rank_start + k:
				ranks_contiguous = false
		_check("epoch %d's staff price ranks run %d..%d (flagship anchored at %d)" \
				% [tier, rank_start, rank_start + expected_size - 1, rank_start], ranks_contiguous)
	_check("the ladder totals Blue Collar's 6 + the epoch cohorts (%d)" % expected_total,
		configs.size() == expected_total)

	# The cohort-wide First Contact bonus: applying a bonus to every member of a tier's
	# cohort (exactly what Main does when the trade-deal minigame finishes) lands the
	# same income/cycle multipliers on every member. Tier 3 = the first alien cohort.
	var bonus_game := GameState.new(configs, tuning)
	for member in bonus_game.economy.get_property_indices_for_unlock_tier(3):
		(bonus_game.economy.properties[member] as PropertyState).set_first_contact_bonus(1.4, 0.88)
	var all_bonused := true
	for member in bonus_game.economy.get_property_indices_for_unlock_tier(3):
		var prop_state := bonus_game.economy.properties[member] as PropertyState
		if not is_equal_approx(prop_state.first_contact_income_multiplier, 1.4) \
				or not is_equal_approx(prop_state.first_contact_cycle_multiplier, 0.88):
			all_bonused = false
	_check("a cohort-wide First Contact bonus reaches every member", all_bonused)

	# The shipped ladder includes at least one alien property gated to a later epoch.
	var alien_index := -1
	for i in range(configs.size()):
		if (configs[i] as PropertyConfig).unlock_tier >= 2:
			alien_index = i
			break
	_check("ladder ships a property gated to a later epoch", alien_index >= 0)
	if alien_index < 0:
		return

	var alien_tier := (configs[alien_index] as PropertyConfig).unlock_tier
	var game := GameState.new(configs, tuning)
	_check("tier→property lookup finds the alien property at its epoch",
		game.economy.get_property_index_for_unlock_tier(alien_tier) == alien_index)

	# NOTE (2026-07-02): the old "First Contact grants free starting units" assertions were removed
	# here because the starting-units reward itself was cut on feature/ui-tap-targets (the reward is
	# now the upside-only property income bonus). grant_starting_units / first_contact_starting_units
	# no longer exist, which had left this whole EpochTest suite un-runnable. This section now only
	# covers the still-live tier→property unlock. A proper test of the upside-only reward is OWED and
	# belongs with that redesign — flagged to Tim.
