extends SceneTree

# Headless verification for CHALLENGE MODE's AUTHORED TIER LADDERS + two-track payout math (the core
# wave of the Challenge Mode rework; design of record: Plans/Challenge_Mode.md).
#
# Usage: godot --headless --path . --script res://sim/ChallengeGoalsTest.gd
#
# Proves, without any rendering:
#   1. tier_for_score = floor(score / STEP), clamped to MAX_TIER, monotonic, unknown key -> 0.
#   1b. ESCALATING tier cost for the two low-ceiling games (Basketball, Memory): tier_cost /
#      cumulative_cost / score_to_reach_tier follow min(base + floor((tier-1)/5) x inc, cap), the
#      cumulative cost is strictly increasing, tier_for_score inverts score_to_reach_tier at every
#      boundary, and the four FLAT games (tier x STEP) are unchanged.
#   2. payout_at_tier returns the authored schedule (income/legacy alternation, escalating values) on
#      every 5th tier and {} elsewhere; next_payout_tier walks the schedule and reports -1 when maxed.
#   3. income_bonus_for / legacy_bonus_for are the summed same-track payouts x bonus_scale (a mastered
#      game -> +4% income and +4% Legacy at scale 1.0), and the whole-mode totals sum across games.
#   4. DynastyState.challenge_highest_tiers: note_challenge_tier only ever RAISES, and the record (and
#      both bonuses) survive a save/load round-trip; a pre-Challenge save loads clean.
#   5. Both reward tracks fold in EXACTLY ONCE: get_legacy_income_multiplier = Family Fortune x (1 +
#      income bonus) on every property, and get_legacy_yield_multiplier = Estate Lawyers x (1 + Legacy
#      bonus) at the single Legacy-conversion site.
#   6. credit_challenge_score raises the tier, refreshes the living gen, and moves BOTH tracks live;
#      raise-only (a worse/short run changes nothing).
#   7. The GOTCHA: ChallengeGoals is configured from the TUNING fields, and DynastyState re-pushes that
#      config on construction — so poking the static then building a dynasty is overwritten.
#
# Exits 0 only if every check passes (1 otherwise), so headless/CI runs fail loudly.

var _failures := 0


func _initialize() -> void:
	print("=== Challenge Goals — headless verification (authored tier ladders) ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	if tuning == null:
		print("FAILED to load tuning config")
		quit(1)
		return

	_test_tier_for_score()
	_test_escalating_tiers(tuning)
	_test_payout_schedule()
	_test_bonus_sums()
	_test_dynasty_record_and_roundtrip(tuning)
	_test_both_tracks_fold_once(tuning)
	_test_credit_challenge_score(tuning)
	_test_configure_from_tuning_gotcha(tuning)

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


## Push the four global challenge levers into ChallengeGoals via a minimal TuningConfig — the unit-test
## stand-in for DynastyState's push, for the pure-math tests that only care about bonus_scale / timers.
## configure() now takes a whole TuningConfig (not a positional list); a fresh TuningConfig carries the
## baked @export defaults for everything else (escalating cost, per-game keep-alive).
func _configure_challenge(bonus_scale: float, timer_start: float, timer_cap: float, miss_ratio: float) -> void:
	var t := TuningConfig.new()
	t.challenge_bonus_scale = bonus_scale
	t.challenge_timer_start_seconds = timer_start
	t.challenge_timer_cap_seconds = timer_cap
	t.challenge_miss_penalty_ratio = miss_ratio
	ChallengeGoals.configure(t)


# ---------------------------------------------------------------------------
# 1. tier_for_score = floor(score / STEP), clamped, monotonic
# ---------------------------------------------------------------------------
func _test_tier_for_score() -> void:
	print("-- tier_for_score = floor(score/STEP), clamped to MAX_TIER, monotonic --")
	_configure_challenge(1.0, 6.0, 15.0, 0.5)  # scale 1.0 for a clean read
	var game := ChallengeGoals.TIMING_BAR       # STEP = 1.0
	var step := ChallengeGoals.score_step(game)

	_check("Timing Bar STEP is 1.0", is_equal_approx(step, 1.0))
	_check("a score below one STEP clears 0 tiers", ChallengeGoals.tier_for_score(game, step - 0.001) == 0)
	_check("score at 1x STEP clears tier 1", ChallengeGoals.tier_for_score(game, step) == 1)
	_check("score at 4.9x STEP clears tier 4 (floor)", ChallengeGoals.tier_for_score(game, step * 4.9) == 4)

	# Clamp: any score at/above MAX_TIER x STEP stops at MAX_TIER (finite summit).
	_check("score at MAX_TIER x STEP clears exactly MAX_TIER",
		ChallengeGoals.tier_for_score(game, step * ChallengeGoals.MAX_TIER) == ChallengeGoals.MAX_TIER)
	_check("a huge score is clamped to MAX_TIER (no runaway past the summit)",
		ChallengeGoals.tier_for_score(game, 1e9) == ChallengeGoals.MAX_TIER)

	# Match Three uses a much larger STEP (1000): confirms the per-game scale is honoured.
	_check("Match Three STEP is 1000", is_equal_approx(ChallengeGoals.score_step(ChallengeGoals.MATCH_THREE), 1000.0))
	_check("Match Three needs 5000 points for tier 5",
		ChallengeGoals.tier_for_score(ChallengeGoals.MATCH_THREE, 5000.0) == 5)

	# Monotonic: sweeping the score upward never lowers the cleared-tier count.
	var monotone := true
	var last := 0
	var s := 0.0
	while s <= 40.0:
		var tier := ChallengeGoals.tier_for_score(game, s)
		if tier < last:
			monotone = false
		last = tier
		s += 0.25
	_check("cleared-tier count never decreases as score rises (monotonic)", monotone)

	_check("an unknown game key clears 0 tiers", ChallengeGoals.tier_for_score("Not A Game", 1e9) == 0)


# ---------------------------------------------------------------------------
# 1b. ESCALATING tier cost (Basketball + Memory) vs. the four unchanged flat games
# ---------------------------------------------------------------------------
func _test_escalating_tiers(tuning: TuningConfig) -> void:
	print("-- escalating tier cost for Basketball & Memory; the four flat games unchanged --")
	# Configure via the TUNING fields (the GOTCHA): set the fields, then build a dynasty to push them
	# into the static config. Poking the statics directly would be overwritten by this construction.
	tuning.basketball_tier_base_cost = 1.0
	tuning.basketball_tier_cost_increment = 1.0
	tuning.basketball_tier_cost_cap = 5.0
	tuning.memory_tier_base_cost = 0.2
	tuning.memory_tier_cost_increment = 0.2
	tuning.memory_tier_cost_cap = 1.0
	var _dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)

	var bball := ChallengeGoals.BASKETBALL
	var memory := ChallengeGoals.MEMORY_MATCH

	# is_escalating flags the two low-ceiling games and NOT the four flat ones.
	_check("Basketball + Memory are escalating; Timing/Match/Catch/Balance are not",
		ChallengeGoals.is_escalating(bball) and ChallengeGoals.is_escalating(memory)
		and not ChallengeGoals.is_escalating(ChallengeGoals.TIMING_BAR)
		and not ChallengeGoals.is_escalating(ChallengeGoals.MATCH_THREE)
		and not ChallengeGoals.is_escalating(ChallengeGoals.CATCH_MONEY)
		and not ChallengeGoals.is_escalating(ChallengeGoals.BALANCE_BOOKS))

	# game_keys() still lists all six (it is no longer STEP.keys(), which now omits the escalating two).
	_check("game_keys() still lists all six games including the escalating pair",
		ChallengeGoals.game_keys().size() == 6
		and ChallengeGoals.game_keys().has(bball) and ChallengeGoals.game_keys().has(memory))

	# tier_cost = min(base + floor((tier-1)/5) x increment, cap): cheap early, +increment every 5, capped.
	_check("Basketball tier 1 costs base (1)", is_equal_approx(ChallengeGoals.tier_cost(bball, 1), 1.0))
	_check("Basketball tier 5 still costs 1 (first band)", is_equal_approx(ChallengeGoals.tier_cost(bball, 5), 1.0))
	_check("Basketball tier 6 costs base+increment (2)", is_equal_approx(ChallengeGoals.tier_cost(bball, 6), 2.0))
	_check("Basketball tier 11 costs 3", is_equal_approx(ChallengeGoals.tier_cost(bball, 11), 3.0))
	_check("Basketball tier cost caps at 5", is_equal_approx(ChallengeGoals.tier_cost(bball, 30), 5.0))

	# The headline cumulative costs (score_to_reach_tier = cumulative_cost). Basketball: 5 / 15 / 30.
	_check("Basketball reach tier 5 = 5 baskets", is_equal_approx(ChallengeGoals.score_to_reach_tier(bball, 5), 5.0))
	_check("Basketball reach tier 10 = 15 baskets", is_equal_approx(ChallengeGoals.score_to_reach_tier(bball, 10), 15.0))
	_check("Basketball reach tier 15 = 30 baskets", is_equal_approx(ChallengeGoals.score_to_reach_tier(bball, 15), 30.0))
	# Memory: 1 / 3 / 6 climbs.
	_check("Memory reach tier 5 = 1 climb", is_equal_approx(ChallengeGoals.score_to_reach_tier(memory, 5), 1.0))
	_check("Memory reach tier 10 = 3 climbs", is_equal_approx(ChallengeGoals.score_to_reach_tier(memory, 10), 3.0))
	_check("Memory reach tier 15 = 6 climbs", is_equal_approx(ChallengeGoals.score_to_reach_tier(memory, 15), 6.0))

	# cumulative_cost is strictly increasing (a deeper tier always costs strictly more score to reach).
	var monotone := true
	var prev := 0.0
	for t in range(1, ChallengeGoals.MAX_TIER + 1):
		var c := ChallengeGoals.cumulative_cost(bball, t)
		if c <= prev:
			monotone = false
		prev = c
	_check("Basketball cumulative_cost strictly increases with tier", monotone)

	# tier_for_score INVERTS score_to_reach_tier at every boundary: exactly the reach score sits at tier N,
	# a hair under sits at N-1. Proven for BOTH escalating games across the whole ladder.
	var bball_inverts := true
	var memory_inverts := true
	for t in range(1, ChallengeGoals.MAX_TIER + 1):
		var reach_b := ChallengeGoals.score_to_reach_tier(bball, t)
		if ChallengeGoals.tier_for_score(bball, reach_b) != t or ChallengeGoals.tier_for_score(bball, reach_b - 0.001) != t - 1:
			bball_inverts = false
		var reach_m := ChallengeGoals.score_to_reach_tier(memory, t)
		if ChallengeGoals.tier_for_score(memory, reach_m) != t or ChallengeGoals.tier_for_score(memory, reach_m - 0.001) != t - 1:
			memory_inverts = false
	_check("Basketball tier_for_score inverts score_to_reach_tier at every boundary", bball_inverts)
	_check("Memory tier_for_score inverts score_to_reach_tier at every boundary", memory_inverts)

	# Escalating games still clamp to the finite summit — a huge score never exceeds MAX_TIER.
	_check("a huge Basketball score clamps to MAX_TIER",
		ChallengeGoals.tier_for_score(bball, 1e9) == ChallengeGoals.MAX_TIER)

	# The FOUR flat games are UNCHANGED: score_to_reach_tier = tier x STEP, tier_for_score = floor(score/STEP).
	_check("Match Three (flat) reach tier 5 is still 5000 (5 x 1000)",
		is_equal_approx(ChallengeGoals.score_to_reach_tier(ChallengeGoals.MATCH_THREE, 5), 5000.0))
	_check("Timing Bar (flat) reach tier 10 is still 10 (10 x 1)",
		is_equal_approx(ChallengeGoals.score_to_reach_tier(ChallengeGoals.TIMING_BAR, 10), 10.0))
	_check("Catch the Money (flat) reach tier 30 is still 60 (30 x 2)",
		is_equal_approx(ChallengeGoals.score_to_reach_tier(ChallengeGoals.CATCH_MONEY, 30), 60.0))
	_check("Balance the Books (flat) reach tier 30 is still 60 (30 x 2)",
		is_equal_approx(ChallengeGoals.score_to_reach_tier(ChallengeGoals.BALANCE_BOOKS, 30), 60.0))
	_check("Timing Bar (flat) tier_for_score is still floor(score/STEP)",
		ChallengeGoals.tier_for_score(ChallengeGoals.TIMING_BAR, 7.5) == 7)

	# Every game's keep-alive seconds-per-point is now tunable from its own knob (was Balance-only).
	# Set two different games' knobs and confirm each flows through independently after a dynasty build.
	tuning.balance_keepalive_seconds_per_point = 3.3
	tuning.basketball_keepalive_seconds_per_point = 7.7
	var _dynasty2 := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	_check("seconds_per_point(Balance) returns the tuned keep-alive value",
		is_equal_approx(ChallengeGoals.seconds_per_point(ChallengeGoals.BALANCE_BOOKS), 3.3))
	_check("seconds_per_point(Basketball) returns its own tuned keep-alive value",
		is_equal_approx(ChallengeGoals.seconds_per_point(ChallengeGoals.BASKETBALL), 7.7))
	_check("seconds_per_point(an untouched game) keeps its baked default (Timing Bar = 3.0)",
		is_equal_approx(ChallengeGoals.seconds_per_point(ChallengeGoals.TIMING_BAR), 3.0))


# ---------------------------------------------------------------------------
# 2. the payout schedule + next_payout_tier
# ---------------------------------------------------------------------------
func _test_payout_schedule() -> void:
	print("-- payout_at_tier follows the authored income/legacy schedule; next_payout_tier walks it --")

	# The exact authored schedule: alternating tracks, escalating 1/1/2/2/1/1 per track.
	var expected := {
		5:  {"pct": 1.0, "type": "income"},
		10: {"pct": 1.0, "type": "legacy"},
		15: {"pct": 2.0, "type": "income"},
		20: {"pct": 2.0, "type": "legacy"},
		25: {"pct": 1.0, "type": "income"},
		30: {"pct": 1.0, "type": "legacy"},
	}
	var schedule_ok := true
	for tier in expected:
		var got := ChallengeGoals.payout_at_tier(tier)
		if got.is_empty() or not is_equal_approx(float(got["pct"]), float(expected[tier]["pct"])) \
				or String(got["type"]) != String(expected[tier]["type"]):
			schedule_ok = false
	_check("every payout tier (5,10,15,20,25,30) matches the authored pct + track", schedule_ok)

	# Progress-only tiers pay nothing; nothing past the summit pays.
	_check("a between-payout tier (12) pays nothing", ChallengeGoals.payout_at_tier(12).is_empty())
	_check("tier 0 pays nothing", ChallengeGoals.payout_at_tier(0).is_empty())
	_check("past the summit (35) pays nothing", ChallengeGoals.payout_at_tier(35).is_empty())

	# next_payout_tier: next multiple of 5 above cleared, -1 once maxed.
	_check("next payout above 0 is 5", ChallengeGoals.next_payout_tier(0) == 5)
	_check("next payout above 5 is 10", ChallengeGoals.next_payout_tier(5) == 10)
	_check("next payout above 7 is 10", ChallengeGoals.next_payout_tier(7) == 10)
	_check("next payout above 25 is 30", ChallengeGoals.next_payout_tier(25) == 30)
	_check("next payout above 30 (mastered) is -1", ChallengeGoals.next_payout_tier(30) == -1)


# ---------------------------------------------------------------------------
# 3. income_bonus_for / legacy_bonus_for sums + whole-mode totals
# ---------------------------------------------------------------------------
func _test_bonus_sums() -> void:
	print("-- income_bonus_for / legacy_bonus_for sum same-track payouts x bonus_scale --")
	_configure_challenge(1.0, 6.0, 15.0, 0.5)

	# Nothing cleared -> both bonuses 0.
	_check("income_bonus_for(0) is 0", is_zero_approx(ChallengeGoals.income_bonus_for(0)))
	_check("legacy_bonus_for(0) is 0", is_zero_approx(ChallengeGoals.legacy_bonus_for(0)))

	# Cleared tier 5 -> only the tier-5 income payout (+1%), no Legacy yet.
	_check("tier 5 gives +1% income", is_equal_approx(ChallengeGoals.income_bonus_for(5), 0.01))
	_check("tier 5 gives +0% Legacy", is_zero_approx(ChallengeGoals.legacy_bonus_for(5)))

	# Cleared tier 10 -> income 1% (t5), Legacy 1% (t10).
	_check("tier 10 gives +1% income", is_equal_approx(ChallengeGoals.income_bonus_for(10), 0.01))
	_check("tier 10 gives +1% Legacy", is_equal_approx(ChallengeGoals.legacy_bonus_for(10), 0.01))

	# Mastered (tier 30) -> income 1+2+1 = 4%, Legacy 1+2+1 = 4%.
	_check("a mastered game gives +4% income (1+2+1)", is_equal_approx(ChallengeGoals.income_bonus_for(30), 0.04))
	_check("a mastered game gives +4% Legacy (1+2+1)", is_equal_approx(ChallengeGoals.legacy_bonus_for(30), 0.04))

	# The bonus_scale knob scales BOTH tracks.
	_configure_challenge(0.5, 6.0, 15.0, 0.5)
	_check("bonus_scale 0.5 halves the income bonus (+2% at tier 30)",
		is_equal_approx(ChallengeGoals.income_bonus_for(30), 0.02))
	_check("bonus_scale 0.5 halves the Legacy bonus (+2% at tier 30)",
		is_equal_approx(ChallengeGoals.legacy_bonus_for(30), 0.02))
	_configure_challenge(1.0, 6.0, 15.0, 0.5)

	# Whole-mode totals sum across games. Two mastered games -> +8% each track.
	var tiers := {ChallengeGoals.TIMING_BAR: 30, ChallengeGoals.MATCH_THREE: 30}
	_check("total income across two mastered games is +8%",
		is_equal_approx(ChallengeGoals.total_income_bonus(tiers), 0.08))
	_check("total Legacy across two mastered games is +8%",
		is_equal_approx(ChallengeGoals.total_legacy_bonus(tiers), 0.08))

	# All six games mastered -> ~24% each track (Tim's ~25/25 target, scale 1.0).
	var all_maxed := {}
	for key in ChallengeGoals.game_keys():
		all_maxed[key] = 30
	_check("all six mastered is +24% income (~25 target)",
		is_equal_approx(ChallengeGoals.total_income_bonus(all_maxed), 0.24))
	_check("all six mastered is +24% Legacy (~25 target)",
		is_equal_approx(ChallengeGoals.total_legacy_bonus(all_maxed), 0.24))


# ---------------------------------------------------------------------------
# 4. DynastyState record: only-raises + save/load round-trip
# ---------------------------------------------------------------------------
func _test_dynasty_record_and_roundtrip(tuning: TuningConfig) -> void:
	print("-- DynastyState.challenge_highest_tiers: only-raises + save/load round-trip --")
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)

	_check("a fresh bloodline has no cleared tiers and 0 income/Legacy bonus",
		dynasty.challenge_highest_tiers.is_empty()
		and is_zero_approx(dynasty.get_challenge_income_bonus())
		and is_zero_approx(dynasty.get_challenge_legacy_bonus()))

	# note_challenge_tier raises only: a later WORSE run cannot lower a banked tier.
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 15)
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 3)  # worse -> ignored
	_check("note_challenge_tier keeps the MAX (a worse later run cannot lower it)",
		int(dynasty.challenge_highest_tiers[ChallengeGoals.TIMING_BAR]) == 15)
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 20)  # better -> raises
	_check("a better run raises the banked tier",
		int(dynasty.challenge_highest_tiers[ChallengeGoals.TIMING_BAR]) == 20)

	# A second game contributes its own independent bonus on both tracks.
	dynasty.note_challenge_tier(ChallengeGoals.BASKETBALL, 5)
	var expected_income := ChallengeGoals.income_bonus_for(20) + ChallengeGoals.income_bonus_for(5)
	var expected_legacy := ChallengeGoals.legacy_bonus_for(20) + ChallengeGoals.legacy_bonus_for(5)
	_check("the whole-mode income bonus sums both games' cleared tiers",
		is_equal_approx(dynasty.get_challenge_income_bonus(), expected_income))
	_check("the whole-mode Legacy bonus sums both games' cleared tiers",
		is_equal_approx(dynasty.get_challenge_legacy_bonus(), expected_legacy))

	# Round-trip: a reborn dynasty restores the record and the identical bonuses.
	var reborn := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	reborn.load_save_dict(dynasty.to_save_dict())
	_check("challenge_highest_tiers survives a save/load round-trip",
		int(reborn.challenge_highest_tiers.get(ChallengeGoals.TIMING_BAR, 0)) == 20
		and int(reborn.challenge_highest_tiers.get(ChallengeGoals.BASKETBALL, 0)) == 5)
	_check("the restored dynasty reports the identical income + Legacy bonuses",
		is_equal_approx(reborn.get_challenge_income_bonus(), expected_income)
		and is_equal_approx(reborn.get_challenge_legacy_bonus(), expected_legacy))

	# An old save with no challenge field loads clean with zero bonuses.
	var legacy_only := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	var stripped := dynasty.to_save_dict()
	stripped.erase("challenge_highest_tiers")
	legacy_only.load_save_dict(stripped)
	_check("a pre-Challenge-Mode save loads with an empty record and 0 bonuses",
		legacy_only.challenge_highest_tiers.is_empty()
		and is_zero_approx(legacy_only.get_challenge_income_bonus())
		and is_zero_approx(legacy_only.get_challenge_legacy_bonus()))


# ---------------------------------------------------------------------------
# 5. both reward tracks fold in exactly once
# ---------------------------------------------------------------------------
func _test_both_tracks_fold_once(tuning: TuningConfig) -> void:
	print("-- income folds into property income once; Legacy folds into the yield once --")
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)

	# Known Family Fortune + Estate Lawyers levels so both baselines are fixed, then clear tiers that
	# pay on BOTH tracks (tier 10 pays income at t5 and Legacy at t10).
	dynasty.upgrades.levels[LegacyUpgradeCatalog.FAMILY_FORTUNE] = 2
	dynasty.upgrades.levels[LegacyUpgradeCatalog.ESTATE_LAWYERS] = 3
	dynasty.note_challenge_tier(ChallengeGoals.MATCH_THREE, 10)
	dynasty.note_challenge_tier(ChallengeGoals.CATCH_MONEY, 15)
	dynasty.refresh_current_generation_effects()

	# --- Income track: Family Fortune x (1 + income bonus), applied once, on every property. ---
	var family_fortune := dynasty.upgrades.property_income_multiplier()
	var income_bonus := dynasty.get_challenge_income_bonus()
	var expected_income_mult := family_fortune * (1.0 + income_bonus)
	_check("the income bonus is non-zero for this test", income_bonus > 0.0)
	_check("get_legacy_income_multiplier() = Family Fortune x (1 + income bonus)",
		is_equal_approx(dynasty.get_legacy_income_multiplier(), expected_income_mult))
	var all_fields_match := true
	for prop in dynasty.current.economy.properties:
		if not is_equal_approx((prop as PropertyState).legacy_income_multiplier, expected_income_mult):
			all_fields_match = false
	_check("every property's legacy_income_multiplier field equals that same product (rush path)",
		all_fields_match)

	# --- Legacy track: Estate Lawyers x (1 + Legacy bonus), applied once at the conversion site. ---
	var estate_lawyers := dynasty.upgrades.legacy_yield_multiplier()
	var legacy_bonus := dynasty.get_challenge_legacy_bonus()
	var expected_yield_mult := estate_lawyers * (1.0 + legacy_bonus)
	_check("the Legacy bonus is non-zero for this test", legacy_bonus > 0.0)
	_check("get_legacy_yield_multiplier() = Estate Lawyers x (1 + Legacy bonus)",
		is_equal_approx(dynasty.get_legacy_yield_multiplier(), expected_yield_mult))

	# Prove the conversion site actually uses that multiplier once: with a fixed pre-multiplier gain,
	# the will's legacy_gain must equal floor(base_gain x get_legacy_yield_multiplier()). We back the
	# base gain out from the will with the bonus removed, then confirm re-applying it reproduces it.
	var will := dynasty.get_draft_will()
	var base_gain := EstateWaterfall.legacy_gain(will["estate_net"], tuning.k_legacy, tuning.alpha_legacy)
	var expected_gain := int(floor(float(base_gain) * expected_yield_mult))
	_check("the draft will's legacy_gain applies the yield multiplier exactly once",
		int(will["legacy_gain"]) == expected_gain)

	# With NO tiers cleared, both multipliers are plain (bonus is +0%, neutral).
	var plain := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	plain.upgrades.levels[LegacyUpgradeCatalog.FAMILY_FORTUNE] = 2
	plain.upgrades.levels[LegacyUpgradeCatalog.ESTATE_LAWYERS] = 3
	plain.refresh_current_generation_effects()
	_check("with no tiers cleared the income multiplier is exactly Family Fortune",
		is_equal_approx(plain.get_legacy_income_multiplier(), plain.upgrades.property_income_multiplier()))
	_check("with no tiers cleared the yield multiplier is exactly Estate Lawyers",
		is_equal_approx(plain.get_legacy_yield_multiplier(), plain.upgrades.legacy_yield_multiplier()))


# ---------------------------------------------------------------------------
# 6. credit_challenge_score: credits new tiers, refreshes, moves BOTH tracks, raise-only
# ---------------------------------------------------------------------------
func _test_credit_challenge_score(tuning: TuningConfig) -> void:
	print("-- credit_challenge_score: credits a new tier, refreshes, moves both tracks, raise-only --")
	# Build the dynasty FIRST (that re-pushes the tuned knobs into ChallengeGoals), then read STEP off
	# the configured table — so the test scores stay correct whatever the tuning values.
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	var game := ChallengeGoals.TIMING_BAR  # STEP = 1.0, so a score of N clears tier N

	# A run that clears tier 10 exactly — pays income (t5) AND Legacy (t10).
	var score := ChallengeGoals.score_step(game) * 10.0
	var expected_tier := ChallengeGoals.tier_for_score(game, score)
	var result := dynasty.credit_challenge_score(game, score)

	_check("a clearing run reports improved", bool(result["improved"]))
	_check("old_tier was 0 for a never-cleared game", int(result["old_tier"]) == 0)
	_check("new_tier matches tier_for_score", int(result["new_tier"]) == expected_tier)
	_check("tiers_gained equals new_tier - old_tier", int(result["tiers_gained"]) == expected_tier)
	_check("challenge_highest_tiers was raised to new_tier",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)

	# BOTH tracks moved in the report and match the live dynasty getters.
	_check("income_after rose above income_before",
		float(result["income_after"]) > float(result["income_before"]))
	_check("legacy_after rose above legacy_before",
		float(result["legacy_after"]) > float(result["legacy_before"]))
	_check("get_challenge_income_bonus() equals the reported income_after",
		is_equal_approx(dynasty.get_challenge_income_bonus(), float(result["income_after"])))
	_check("get_challenge_legacy_bonus() equals the reported legacy_after",
		is_equal_approx(dynasty.get_challenge_legacy_bonus(), float(result["legacy_after"])))
	# The legacy aliases still carry the income track (kept for the existing MinigameScreen readout).
	_check("bonus_after alias equals income_after (MinigameScreen compat)",
		is_equal_approx(float(result["bonus_after"]), float(result["income_after"])))

	# The LIVING generation already feels the income credit (proof refresh ran inside credit).
	var expected_income_mult := dynasty.upgrades.property_income_multiplier() * (1.0 + dynasty.get_challenge_income_bonus())
	var all_fields_match := true
	for prop in dynasty.current.economy.properties:
		if not is_equal_approx((prop as PropertyState).legacy_income_multiplier, expected_income_mult):
			all_fields_match = false
	_check("the living generation's property income multiplier reflects the credit (refresh applied)",
		all_fields_match)
	# And the live Legacy-yield multiplier reflects the credited Legacy track.
	var expected_yield_mult := dynasty.upgrades.legacy_yield_multiplier() * (1.0 + dynasty.get_challenge_legacy_bonus())
	_check("the live Legacy-yield multiplier reflects the credited Legacy track",
		is_equal_approx(dynasty.get_legacy_yield_multiplier(), expected_yield_mult))

	# A run BELOW the next tier clears nothing new -> improved false, nothing changes.
	var income_before := dynasty.get_challenge_income_bonus()
	var below := ChallengeGoals.score_step(game) * float(expected_tier + 1) - 0.001
	var no_gain := dynasty.credit_challenge_score(game, below)
	_check("a run short of the next tier does NOT improve", not bool(no_gain["improved"]))
	_check("a short run leaves the banked tier unchanged",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)
	_check("a short run leaves the income bonus unchanged",
		is_equal_approx(dynasty.get_challenge_income_bonus(), income_before))

	# A much LOWER score after the high one cannot lower the tier (raise-only push-luck).
	var worse := dynasty.credit_challenge_score(game, ChallengeGoals.score_step(game))
	_check("a lower later score does NOT improve", not bool(worse["improved"]))
	_check("raise-only: the banked tier is never lowered",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)


# ---------------------------------------------------------------------------
# 7. the config GOTCHA: DynastyState pushes the TUNING fields into the statics
# ---------------------------------------------------------------------------
func _test_configure_from_tuning_gotcha(tuning: TuningConfig) -> void:
	print("-- ChallengeGoals is configured from the TUNING fields (the DynastyState re-push GOTCHA) --")
	# Poke the statics with bogus values, set DIFFERENT values on the tuning fields, then build a
	# dynasty. Construction must overwrite the bogus statics with the tuning fields' values — which is
	# exactly why a sim must set the TUNING field, not the static (setting the static is futile).
	_configure_challenge(99.0, 99.0, 99.0, 99.0)
	tuning.challenge_bonus_scale = 0.75
	tuning.challenge_timer_start_seconds = 5.0
	tuning.challenge_timer_cap_seconds = 12.0
	tuning.challenge_miss_penalty_ratio = 0.6
	var _dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	_check("building a dynasty overwrote the static bonus_scale from tuning",
		is_equal_approx(ChallengeGoals.bonus_scale, 0.75))
	_check("building a dynasty overwrote the static timer_start from tuning",
		is_equal_approx(ChallengeGoals.timer_start_seconds(), 5.0))
	_check("building a dynasty overwrote the static timer_cap from tuning",
		is_equal_approx(ChallengeGoals.timer_cap_seconds(), 12.0))
	_check("building a dynasty overwrote the static miss_penalty_ratio from tuning",
		is_equal_approx(ChallengeGoals.miss_penalty_ratio(), 0.6))
