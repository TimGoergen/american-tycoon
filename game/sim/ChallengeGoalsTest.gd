extends SceneTree

# Headless verification for CHALLENGE MODE's goal ladders + diminishing-reward math (Phase 1 of the
# Challenge Mode rework; design of record: Plans/Challenge_Mode.md).
#
# Usage: godot --headless --path . --script res://sim/ChallengeGoalsTest.gd
#
# Proves, without any rendering:
#   1. highest_tier_for_score is monotonic in score and exactly consistent with threshold() at the
#      boundaries (just below tier t -> t-1; at/above -> >= t).
#   2. The closed-form game_income_bonus equals an explicit tier-by-tier sum of tier_reward.
#   3. CONVERGENCE: game_income_bonus(cleared) climbs toward BASE_PCT/(1-DECAY) as cleared grows,
#      never exceeding it — the bounded-but-uncapped property that is the whole rate-limiter.
#   4. DynastyState.challenge_highest_tiers: note_challenge_tier only ever RAISES, and the record
#      (and its income bonus) survives a save/load round-trip.
#   5. _apply_upgrade_effects folds the challenge bonus into property income EXACTLY ONCE: a
#      property's effective income multiplier = Family Fortune x (1 + total challenge bonus).
#   6. The GOTCHA: ChallengeGoals is configured from the TUNING field, and DynastyState re-pushes
#      that config on construction — so poking the static then building a dynasty is overwritten.
#
# Exits 0 only if every check passes (1 otherwise), so headless/CI runs fail loudly.

var _failures := 0


func _initialize() -> void:
	print("=== Challenge Goals — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	if tuning == null:
		print("FAILED to load tuning config")
		quit(1)
		return

	_test_highest_tier_matches_threshold()
	_test_closed_form_equals_explicit_sum()
	_test_convergence()
	_test_dynasty_record_and_roundtrip(tuning)
	_test_bonus_folds_once(tuning)
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


# ---------------------------------------------------------------------------
# 1. highest_tier_for_score <-> threshold consistency
# ---------------------------------------------------------------------------
func _test_highest_tier_matches_threshold() -> void:
	print("-- highest_tier_for_score is monotonic and matches threshold --")
	# A clean curve so the arithmetic is easy to eyeball (T0 for Timing Bar = 6, growth = 2 here).
	ChallengeGoals.configure(2.0, 0.01, 0.5)
	var game := ChallengeGoals.TIMING_BAR

	# Below tier 1's threshold -> 0 tiers cleared.
	_check("a score below T0 clears 0 tiers", ChallengeGoals.highest_tier_for_score(game, 5.0) == 0)

	# At / above each tier's threshold clears exactly that tier; a hair below clears one less.
	var boundary_ok := true
	for tier in range(1, 9):
		var at := ChallengeGoals.threshold(game, tier)
		var just_below := at - 0.001
		if ChallengeGoals.highest_tier_for_score(game, at) < tier:
			boundary_ok = false  # a score AT the threshold must clear that tier
		if ChallengeGoals.highest_tier_for_score(game, just_below) != tier - 1:
			boundary_ok = false  # a score just under it must clear exactly tier-1
	_check("at/above threshold(t) clears >= t; just below clears t-1 (every boundary 1..8)",
		boundary_ok)

	# Monotonic: sweeping the score upward never lowers the cleared-tier count.
	var monotone := true
	var last := 0
	var s := 0.0
	while s <= 2000.0:
		var tiers := ChallengeGoals.highest_tier_for_score(game, s)
		if tiers < last:
			monotone = false
		last = tiers
		s += 3.0
	_check("cleared-tier count never decreases as score rises (monotonic)", monotone)

	# An unknown game key clears nothing.
	_check("an unknown game key clears 0 tiers",
		ChallengeGoals.highest_tier_for_score("Not A Game", 1e9) == 0)


# ---------------------------------------------------------------------------
# 2. closed-form geometric sum == explicit tier-by-tier sum
# ---------------------------------------------------------------------------
func _test_closed_form_equals_explicit_sum() -> void:
	print("-- game_income_bonus closed form == explicit sum of tier_reward --")
	ChallengeGoals.configure(1.6, 0.005, 0.6)

	_check("game_income_bonus(0) is exactly 0", is_zero_approx(ChallengeGoals.game_income_bonus(0)))

	var all_match := true
	for cleared in [1, 2, 3, 5, 10, 25]:
		var explicit := 0.0
		for t in range(1, cleared + 1):
			explicit += ChallengeGoals.tier_reward(t)
		var closed := ChallengeGoals.game_income_bonus(cleared)
		if not is_equal_approx(explicit, closed):
			all_match = false
	_check("closed form matches the tier-by-tier sum for cleared in {1,2,3,5,10,25}", all_match)

	# The DECAY == 1 guard: no singularity, and the sum degrades to linear cleared x BASE_PCT.
	ChallengeGoals.configure(1.6, 0.005, 1.0)
	_check("DECAY == 1 falls back to linear (5 tiers -> 5 x base_pct)",
		is_equal_approx(ChallengeGoals.game_income_bonus(5), 0.005 * 5.0))


# ---------------------------------------------------------------------------
# 3. convergence: bounded but uncapped
# ---------------------------------------------------------------------------
func _test_convergence() -> void:
	print("-- game_income_bonus converges to BASE_PCT/(1-DECAY), never exceeding it --")
	var base_pct := 0.005
	var decay := 0.6
	ChallengeGoals.configure(1.6, base_pct, decay)
	var limit := base_pct / (1.0 - decay)  # the per-game asymptote (0.005/0.4 = 0.0125 = +1.25%)

	# Monotonically increasing and always strictly under the limit.
	var increasing := true
	var under_limit := true
	var previous := ChallengeGoals.game_income_bonus(0)
	for cleared in range(1, 200):
		var bonus := ChallengeGoals.game_income_bonus(cleared)
		if bonus < previous:
			increasing = false
		if bonus > limit + 1e-9:
			under_limit = false
		previous = bonus
	_check("the per-game bonus rises monotonically with cleared tiers", increasing)
	_check("the per-game bonus NEVER exceeds the BASE_PCT/(1-DECAY) limit", under_limit)

	# Deep in the ladder it is within a whisker of the limit (converged) yet still strictly below it
	# (no hard ceiling). NOTE: tier 40 (not 200) because pow(0.6, 200) underflows to 0.0 in double
	# precision, which would make the closed form round to EXACTLY the limit — a float artifact, not
	# a real breach. At tier 40 the gap is still representable, so the strict inequality is honest.
	var deep := ChallengeGoals.game_income_bonus(40)
	_check("40 tiers is within 0.01%% of the limit (converged)", absf(limit - deep) < limit * 0.0001)
	_check("even 40 tiers is still strictly below the limit (no hard ceiling)", deep < limit)


# ---------------------------------------------------------------------------
# 4. DynastyState record: only-raises + save/load round-trip
# ---------------------------------------------------------------------------
func _test_dynasty_record_and_roundtrip(tuning: TuningConfig) -> void:
	print("-- DynastyState.challenge_highest_tiers: only-raises + save/load round-trip --")
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)

	_check("a fresh bloodline has no cleared tiers and 0 challenge bonus",
		dynasty.challenge_highest_tiers.is_empty()
		and is_zero_approx(dynasty.get_challenge_income_bonus()))

	# note_challenge_tier raises only: a later WORSE run cannot lower a banked tier.
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 3)
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 1)  # worse -> ignored
	_check("note_challenge_tier keeps the MAX (a worse later run cannot lower it)",
		int(dynasty.challenge_highest_tiers[ChallengeGoals.TIMING_BAR]) == 3)
	dynasty.note_challenge_tier(ChallengeGoals.TIMING_BAR, 5)  # better -> raises
	_check("a better run raises the banked tier",
		int(dynasty.challenge_highest_tiers[ChallengeGoals.TIMING_BAR]) == 5)

	# A second game contributes its own independent bonus.
	dynasty.note_challenge_tier(ChallengeGoals.BASKETBALL, 2)
	var expected_bonus := ChallengeGoals.game_income_bonus(5) + ChallengeGoals.game_income_bonus(2)
	_check("the whole-mode bonus sums both games' cleared tiers",
		is_equal_approx(dynasty.get_challenge_income_bonus(), expected_bonus))
	_check("the whole-mode bonus is positive with tiers cleared",
		dynasty.get_challenge_income_bonus() > 0.0)

	# Round-trip: a reborn dynasty restores the record and the identical bonus.
	var reborn := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	reborn.load_save_dict(dynasty.to_save_dict())
	_check("challenge_highest_tiers survives a save/load round-trip",
		int(reborn.challenge_highest_tiers.get(ChallengeGoals.TIMING_BAR, 0)) == 5
		and int(reborn.challenge_highest_tiers.get(ChallengeGoals.BASKETBALL, 0)) == 2)
	_check("the restored dynasty reports the identical challenge bonus",
		is_equal_approx(reborn.get_challenge_income_bonus(), expected_bonus))

	# An old save with no challenge field loads clean with a zero bonus.
	var legacy_only := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	var stripped := dynasty.to_save_dict()
	stripped.erase("challenge_highest_tiers")
	legacy_only.load_save_dict(stripped)
	_check("a pre-Challenge-Mode save loads with an empty record and 0 bonus",
		legacy_only.challenge_highest_tiers.is_empty()
		and is_zero_approx(legacy_only.get_challenge_income_bonus()))


# ---------------------------------------------------------------------------
# 5. the bonus folds into property income EXACTLY once
# ---------------------------------------------------------------------------
func _test_bonus_folds_once(tuning: TuningConfig) -> void:
	print("-- _apply_upgrade_effects folds the challenge bonus into property income exactly once --")
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)

	# Give the dynasty a known Family Fortune level so the baseline multiplier is a fixed number,
	# then clear some challenge tiers. The effective property multiplier must be the PRODUCT of the
	# two — the challenge bonus applied once, on top of Family Fortune (never squared, never dropped).
	dynasty.upgrades.levels[LegacyUpgradeCatalog.FAMILY_FORTUNE] = 2  # 1.20^2 = 1.44x income
	dynasty.note_challenge_tier(ChallengeGoals.MATCH_THREE, 4)
	dynasty.note_challenge_tier(ChallengeGoals.CATCH_MONEY, 2)
	dynasty.refresh_current_generation_effects()  # re-runs _apply_upgrade_effects on the living gen

	var family_fortune := dynasty.upgrades.property_income_multiplier()
	var challenge_bonus := dynasty.get_challenge_income_bonus()
	var expected := family_fortune * (1.0 + challenge_bonus)

	_check("the challenge bonus is actually non-zero for this test", challenge_bonus > 0.0)
	_check("get_legacy_income_multiplier() = Family Fortune x (1 + challenge bonus)",
		is_equal_approx(dynasty.get_legacy_income_multiplier(), expected))

	# Every property's live field (the one the rush-collect path and the row display read) carries
	# that exact same product — proof the passive path and the rush path apply the bonus identically.
	var all_fields_match := true
	for prop in dynasty.current.economy.properties:
		if not is_equal_approx((prop as PropertyState).legacy_income_multiplier, expected):
			all_fields_match = false
	_check("every property's legacy_income_multiplier field equals that same product (rush path)",
		all_fields_match)

	# With NO tiers cleared the multiplier is plain Family Fortune (the +0% baseline is neutral).
	var plain := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	plain.upgrades.levels[LegacyUpgradeCatalog.FAMILY_FORTUNE] = 2
	plain.refresh_current_generation_effects()
	_check("with no tiers cleared the multiplier is exactly Family Fortune (bonus is +0%)",
		is_equal_approx(plain.get_legacy_income_multiplier(), plain.upgrades.property_income_multiplier()))


# ---------------------------------------------------------------------------
# 5b. credit_challenge_score: the Phase 2 crediting path (raise-only, live refresh)
# ---------------------------------------------------------------------------
func _test_credit_challenge_score(tuning: TuningConfig) -> void:
	print("-- credit_challenge_score: credits new tiers, refreshes the living gen, raises only --")
	# Build the dynasty FIRST (that re-pushes the tuned curve into ChallengeGoals), then read the
	# thresholds off the configured curve — so the test scores stay correct whatever the tuning values.
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	var game := ChallengeGoals.TIMING_BAR

	# 1. A run that clears tier 3 exactly (a score AT tier 3's threshold, still below tier 4's).
	var score := ChallengeGoals.threshold(game, 3)
	var expected_tier := ChallengeGoals.highest_tier_for_score(game, score)
	var result := dynasty.credit_challenge_score(game, score)

	_check("a clearing run reports improved", bool(result["improved"]))
	_check("old_tier was 0 for a never-cleared game", int(result["old_tier"]) == 0)
	_check("new_tier matches highest_tier_for_score", int(result["new_tier"]) == expected_tier)
	_check("tiers_gained equals new_tier - old_tier", int(result["tiers_gained"]) == expected_tier)
	_check("challenge_highest_tiers was raised to new_tier",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)
	_check("the bonus rose from bonus_before to bonus_after",
		float(result["bonus_after"]) > float(result["bonus_before"]))
	_check("get_challenge_income_bonus() now equals the reported bonus_after",
		is_equal_approx(dynasty.get_challenge_income_bonus(), float(result["bonus_after"])))

	# The LIVING generation must already feel the credited bonus — proof refresh_current_generation_
	# effects ran inside credit_challenge_score (mid-life, not only for the next heir).
	var expected_mult := dynasty.upgrades.property_income_multiplier() * (1.0 + dynasty.get_challenge_income_bonus())
	var all_fields_match := true
	for prop in dynasty.current.economy.properties:
		if not is_equal_approx((prop as PropertyState).legacy_income_multiplier, expected_mult):
			all_fields_match = false
	_check("the living generation's property income multiplier reflects the credit (refresh applied)",
		all_fields_match)

	# 2. A run BELOW the next threshold clears no new tier -> improved false, nothing changes.
	var bonus_before := dynasty.get_challenge_income_bonus()
	var below := ChallengeGoals.threshold(game, expected_tier + 1) - 0.001
	var no_gain := dynasty.credit_challenge_score(game, below)
	_check("a run short of the next threshold does NOT improve", not bool(no_gain["improved"]))
	_check("a short run leaves the banked tier unchanged",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)
	_check("a short run leaves the income bonus unchanged",
		is_equal_approx(dynasty.get_challenge_income_bonus(), bonus_before))

	# 3. Crediting a much LOWER score after the high one cannot lower the tier (raise-only push-luck).
	var low := ChallengeGoals.threshold(game, 1)
	var worse := dynasty.credit_challenge_score(game, low)
	_check("a lower later score does NOT improve", not bool(worse["improved"]))
	_check("raise-only: the banked tier is never lowered",
		int(dynasty.challenge_highest_tiers.get(game, 0)) == expected_tier)


# ---------------------------------------------------------------------------
# 6. the config GOTCHA: DynastyState pushes the TUNING field into the static
# ---------------------------------------------------------------------------
func _test_configure_from_tuning_gotcha(tuning: TuningConfig) -> void:
	print("-- ChallengeGoals is configured from the TUNING field (the DynastyState re-push GOTCHA) --")
	# Poke the statics with bogus values, set DIFFERENT values on the tuning field, then build a
	# dynasty. Construction must overwrite the bogus statics with the tuning field's values — which
	# is exactly why a sim must set the TUNING field, not the static (setting the static is futile).
	ChallengeGoals.configure(99.0, 99.0, 99.0)
	tuning.challenge_goal_growth = 1.7
	tuning.challenge_reward_base_pct = 0.004
	tuning.challenge_reward_decay = 0.55
	var _dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	_check("building a dynasty overwrote the static growth from the tuning field",
		is_equal_approx(ChallengeGoals.growth, 1.7))
	_check("building a dynasty overwrote the static base_pct from the tuning field",
		is_equal_approx(ChallengeGoals.base_pct, 0.004))
	_check("building a dynasty overwrote the static decay from the tuning field",
		is_equal_approx(ChallengeGoals.decay, 0.55))
