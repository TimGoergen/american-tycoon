class_name DynastyState

# The dynastic layer that lives ABOVE a single run (Mechanics Spec §9, GDD §3.2).
#
# GameState models exactly one generation — one person's lifetime of earning. A
# DynastyState owns the whole bloodline: it holds the current generation plus the
# things that outlive any individual (the spendable Legacy wallet and the
# purchased upgrades, the generation counter, carried-over Work Ethic) and
# performs succession — death, the estate waterfall, Legacy conversion, and the
# birth of an heir.
#
# Prestige reward model (revised): Legacy is no longer an automatic income
# multiplier. It is a CURRENCY the player spends on permanent upgrades
# (LegacyUpgrades / LegacyUpgradeCatalog). Those upgrades are what make each heir
# faster — bigger starting cash, higher property income, quicker cycles, cheaper
# staff, a fatter wage. The dynasty applies the purchased effects to every
# generation it raises, and to the living generation the moment an upgrade is bought.
#
# This is headless and scene-tree-free, like the rest of the core, so the
# simulator drives it directly.

var tuning: TuningConfig

# Held so each new generation is built from the same configs the dynasty started with.
var _property_configs: Array

## The spendable Legacy wallet and the purchased upgrade sheet (GDD §13). All
## prestige value flows through here now: deaths bank Legacy into it, the shop
## spends it, and the dynasty reads its effect getters when raising each heir.
var upgrades: LegacyUpgrades

## Per-property retained staffer tiers (GDD §6.3). Staff reset on prestige by default;
## this is the Legacy-bought exception that carries a chosen property's staffer tier
## into every future heir. Spends from the same Legacy wallet as `upgrades`.
var staff_retention: StaffRetention

## Which generation is alive, 1-based — the Roman-numeral suffix (Wellington IX).
var generation: int = 1

## Lifetime taps across all generations ("Work Ethic"); persists per Spec §5.
var dynastic_taps: int = 0

## Total dollars EARNED across every generation of the bloodline — a monotonic,
## never-reset accumulator (GDD §8.3 decision 2026-06-14). It is the cross-epoch
## yardstick of dynasty progress, the obituary headline, and the Family Ledger
## career stat. Each death adds the dying generation's cash_earned_this_gen to it;
## spending never reduces it.
var lifetime_cash_earned: float = 0.0

## The highest CHALLENGE-MODE tier the bloodline has ever cleared, per minigame — {game_key ->
## highest tier cleared, int} (Plans/Challenge_Mode.md §3.3). Dynasty-wide and permanent: it lives
## in the dynasty save so the diminishing global income bonus it grants SURVIVES PRESTIGE, mirroring
## best_vent_streak (another dynasty-wide earned record). The game_key is a minigame's
## display_name() — see ChallengeGoals. Empty for a save that predates Challenge Mode → 0 bonus.
var challenge_highest_tiers: Dictionary = {}

## Every minigame the bloodline has actually MET at a real transition — a SET, {game_key -> true};
## the value is never read, only the presence of the key (Roadmap §8, Plans/Challenge_Mode_Gating.md).
## Challenge Mode lists only games in here, so each new one appears as a small reward in itself.
## The game_key is a minigame's display_name(), the same key challenge_highest_tiers, ChallengeGoals
## and ChallengeScores all use — anything else would drift.
## Dynasty-wide and permanent: it sits in the dynasty save beside challenge_highest_tiers, so
## prestige does NOT clear it and only wiping the save does. That falls out of the placement for
## free — there is no reset path to write, and none should be added.
var met_minigames: Dictionary = {}

## The deepest VENT TIER the bloodline has ever reached in a single overdrive excursion — an
## implicit high score (Plans/Overdrive_Vent_Windows.md, Tim 2026-07-20). A vent tier is the
## count of successful vents in one ride; a skilled run dies around tier 8. This is an ALL-TIME
## record that must outlive any single run: RushMomentumState._vent_tier is wiped on every reset
## (First Contact) and every overheat, so the lasting memory has to live up here, above the run.
## Updated by note_vent_streak, hooked to the living generation's `overheated` signal below.
var best_vent_streak: int = 0

## One record per deceased generation, oldest first — the Family Ledger (GDD §8.2).
## Each entry is a Dictionary: { "name": String (e.g. "Wellington Pemberton VIII"),
## "generation": int, "fortune": float (the life's cash_earned_this_gen — the
## obituary headline figure), "cause": String (how the generation ended) }.
var ancestors: Array = []

## The generation alive right now. All active play happens through this.
var current: GameState


func _init(property_configs: Array, p_tuning: TuningConfig) -> void:
	_property_configs = property_configs
	tuning = p_tuning
	upgrades = LegacyUpgrades.new()
	staff_retention = StaffRetention.new()
	_configure_retention_pricing()
	current = _new_generation()
	_record_overheats_from_current()


# ---------------------------------------------------------------------------
# Driving the living generation
# ---------------------------------------------------------------------------


## Fold a just-ended vent streak into the bloodline's all-time best. Wired to the LIVING
## generation's overheated signal (see _record_overheats_from_current). The tier arrives already
## captured pre-clear, so this is a plain running maximum.
func note_vent_streak(ended_vent_tier: int) -> void:
	best_vent_streak = maxi(best_vent_streak, ended_vent_tier)


## The deepest vent streak the bloodline has ever reached (0 if no overdrive run has ended yet).
func get_best_vent_streak() -> int:
	return best_vent_streak


## Record that a challenge run cleared `tier` of a minigame. Raises the per-game high only — a
## worse run can never lower a bank already earned (push-your-luck: you keep every tier cleared,
## Plans/Challenge_Mode.md §3.1). `game_key` is the minigame's display_name() (see ChallengeGoals).
func note_challenge_tier(game_key: String, tier: int) -> void:
	var previous := int(challenge_highest_tiers.get(game_key, 0))
	challenge_highest_tiers[game_key] = maxi(previous, tier)


## Record that the bloodline has now MET a minigame — it was dealt at a real transition and the
## player saw it. Idempotent: marking a game already met is a no-op, since this is a set and the
## stored value is never read. `game_key` is the minigame's display_name() (see ChallengeGoals).
func note_minigame_met(game_key: String) -> void:
	met_minigames[game_key] = true


## Has the bloodline met this minigame? Challenge Mode uses this to decide whether a game's row is
## playable or shown locked. `game_key` is the minigame's display_name().
func has_met_minigame(game_key: String) -> bool:
	return met_minigames.has(game_key)


## The whole-mode Challenge INCOME bonus in force right now (a fraction; 0.0 when nothing is cleared).
## The summed income-track payouts across all games — see ChallengeGoals.total_income_bonus. Folded
## into property income by get_legacy_income_multiplier below.
func get_challenge_income_bonus() -> float:
	return ChallengeGoals.total_income_bonus(challenge_highest_tiers)


## The whole-mode Challenge LEGACY-YIELD bonus in force right now (a fraction; 0.0 when nothing is
## cleared). The summed legacy-track payouts across all games — see ChallengeGoals.total_legacy_bonus.
## Folded into the Legacy-yield path by get_legacy_yield_multiplier below (the SECOND reward track).
func get_challenge_legacy_bonus() -> float:
	return ChallengeGoals.total_legacy_bonus(challenge_highest_tiers)


## Credit a finished CHALLENGE run for one minigame (Plans/Challenge_Mode.md §5 step 2). Reads the
## highest tier the run's `score` clears, and if that beats what the bloodline had banked for this
## game, raises the record and re-applies the living generation's effects so the higher global income
## bonus takes hold MID-LIFE — the same way a Legacy purchase applies immediately via
## refresh_current_generation_effects (never waiting for the next heir). RAISE-ONLY: a worse or equal
## run changes nothing (push-your-luck — you keep every tier you have ever cleared, §3.1). `game_key`
## is the minigame's display_name() (see ChallengeGoals). Returns a small report the UI turns into
## the "NEW TIER — +X% global" feedback (see MinigameScreen.show_challenge_credit):
## The reward now has TWO tracks (income + Legacy-yield), so the report carries both — Wave 2's
## feedback shows whichever track the newly-cleared tier paid:
##   improved       — bool, did this run raise the banked tier?
##   old_tier       — the banked tier before this run
##   new_tier       — the tier this run's score clears
##   tiers_gained   — new_tier − old_tier (positive only when improved)
##   income_before  — the whole-mode INCOME bonus (a fraction) before crediting
##   income_after   — the whole-mode INCOME bonus (a fraction) after crediting
##   legacy_before  — the whole-mode LEGACY-yield bonus (a fraction) before crediting
##   legacy_after   — the whole-mode LEGACY-yield bonus (a fraction) after crediting
##   bonus_before   — alias of income_before (kept so the existing MinigameScreen readout still works)
##   bonus_after    — alias of income_after  (kept so the existing MinigameScreen readout still works)
func credit_challenge_score(game_key: String, score: float) -> Dictionary:
	var old_tier := int(challenge_highest_tiers.get(game_key, 0))
	var new_tier := ChallengeGoals.tier_for_score(game_key, score)
	var income_before := get_challenge_income_bonus()
	var legacy_before := get_challenge_legacy_bonus()
	var improved := new_tier > old_tier
	if improved:
		note_challenge_tier(game_key, new_tier)
		# Apply the higher bonuses to the generation that is alive right now, mirroring how a Legacy
		# purchase takes hold mid-life — otherwise the reward wouldn't be felt until the next heir.
		refresh_current_generation_effects()
	var income_after := get_challenge_income_bonus()
	var legacy_after := get_challenge_legacy_bonus()
	return {
		"improved": improved,
		"old_tier": old_tier,
		"new_tier": new_tier,
		"tiers_gained": new_tier - old_tier,
		"income_before": income_before,
		"income_after": income_after,
		"legacy_before": legacy_before,
		"legacy_after": legacy_after,
		# Legacy aliases for the existing MinigameScreen readout (Wave 2 will read the split tracks).
		"bonus_before": income_before,
		"bonus_after": income_after,
	}


## Connect the living generation's overheat signal to the best-streak recorder. Called every time
## `current` is (re)assigned — construction, succession, and load all build a FRESH GameState with
## a FRESH RushMomentumState, so the record has to re-subscribe to the new instance each time or it
## would keep listening to a dead one. (A First Contact reset reuses the same instance, so its
## connection survives untouched.)
func _record_overheats_from_current() -> void:
	current.rush_momentum.overheated.connect(note_vent_streak)

## Advance the current generation by `delta` seconds, applying the dynasty's
## property-income multiplier (from the Legacy "Family Fortune" upgrade) to
## property income only — never to the wage (Spec §9.4: the wage is honest).
func tick(delta: float) -> void:
	current.tick(delta, get_legacy_income_multiplier())


## The property-income multiplier in force this instant. It is the purchased Family Fortune upgrade
## (1.0 when nothing is bought) TIMES the permanent Challenge-goal income bonus (1 + total), both
## dynasty-wide. This is the SINGLE source of that factor: the passive tick reads it live here (via
## tick() below), and _apply_upgrade_effects seeds each property's legacy_income_multiplier FIELD
## from this same method so the rush-collect path and the display read an identical value — the
## bonus therefore lands on income exactly once regardless of collection path.
func get_legacy_income_multiplier() -> float:
	return upgrades.property_income_multiplier() * (1.0 + get_challenge_income_bonus())


## The Legacy-YIELD multiplier in force this instant — the SECOND challenge reward track. It is the
## purchased Estate Lawyers upgrade (upgrades.legacy_yield_multiplier(), 1.0 when nothing is bought)
## TIMES the permanent Challenge-goal LEGACY bonus (1 + total). This is the SINGLE source of that
## factor: get_draft_will() converts the estate through this one method, so the Challenge Legacy bonus
## lands on the Legacy grant exactly once (mirrors how get_legacy_income_multiplier folds the income
## bonus once for property income).
func get_legacy_yield_multiplier() -> float:
	return upgrades.legacy_yield_multiplier() * (1.0 + get_challenge_legacy_bonus())


# ---------------------------------------------------------------------------
# Per-staffer retention (GDD §6.3) — the Legacy-bought exception to the
# "staff reset on prestige" default.
# ---------------------------------------------------------------------------

## Buy one more LEVEL of staff retention for a property, spending Legacy from the
## wallet. Retention climbs the same ladder the dollars did, one step at a time, up to
## the highest level ANY generation of the bloodline has ever reached on that property
## (Tim, 2026-07-04) — a prestige resets the living ladder, but not the family's
## achievement, so the Estate Office keeps offering every level ever earned. Returns
## true on success; false if there is no higher earned level or it is unaffordable.
func buy_staff_retention(property_index: int) -> bool:
	var prop := current.economy.properties[property_index] as PropertyState
	var next_level := staff_retention.next_retention_level(property_index)
	var bloodline_best := maxi(prop.staff_level, staff_retention.get_ladder_high(property_index))
	if next_level > bloodline_best:
		return false
	var cost := staff_retention.cost_for_level(property_index, next_level)
	if upgrades.available < cost:
		return false
	upgrades.available -= cost
	staff_retention.set_retained_levels(property_index, next_level)
	return true


## The highest retention level a property can currently be bought up to: the best any
## generation of the bloodline ever reached there. Shared by the bulk-buy path and the
## spend preview so the button's quote and the purchase can never disagree.
func retention_ceiling(property_index: int) -> int:
	var prop := current.economy.properties[property_index] as PropertyState
	return maxi(prop.staff_level, staff_retention.get_ladder_high(property_index))


## How many retention levels the wallet could buy on a property right now, capped at the
## bloodline's earned ceiling. This is what "RETAIN MAX" would purchase.
func max_affordable_retention_levels(property_index: int) -> int:
	return staff_retention.max_affordable_levels(
		property_index, upgrades.available, retention_ceiling(property_index)
	)


## The exact Legacy price of retaining the next `count` levels — the number the bulk-buy
## button shows BEFORE the player commits. Retention is the endgame's open gem sink, so a
## one-tap bulk buy must never spend a fortune the player couldn't see coming (Roadmap §3).
func retention_cost_for_levels(property_index: int, count: int) -> int:
	return staff_retention.bulk_cost_for_levels(property_index, count)


## Buy up to `count` more retention levels in one action, returning how many were actually
## bought. Deliberately PARTIAL-FILL (buys 7 of 10 rather than refusing outright), matching
## how the bulk property and staff buys behave — a bulk button that silently does nothing
## because the last level is a point short reads as broken.
##
## This loops the single-level buy_staff_retention() rather than reimplementing the
## deduction: one purchase path means the wallet accounting and the ladder-high ceiling
## can never drift between the single and bulk versions.
func buy_staff_retention_levels(property_index: int, count: int) -> int:
	var bought := 0
	while bought < count:
		if not buy_staff_retention(property_index):
			break
		bought += 1
	return bought


## Copy the retention pricing knobs from tuning into the (tuning-free) StaffRetention.
## Called on construction and again on load, since load rebuilds the object.
func _configure_retention_pricing() -> void:
	staff_retention.configure(
		tuning.retention_base_cost,
		tuning.retention_cost_growth,
		tuning.retention_property_step
	)
	# Also install the staff PRICE RANKS retention's property term exponentiates
	# (escalating ladder rework, Tim 2026-07-15) — the same rank the dollar staff
	# anchors use, so protecting a staffer in Legacy scales like hiring one did in
	# dollars. Computed from the dynasty's own configs via EconomyState's static
	# helper (the single source of the rank rule) rather than read off
	# current.economy, because `current` does not exist yet when this runs during
	# _init and load_save_dict.
	staff_retention.set_price_ranks(EconomyState.compute_staff_price_ranks(_property_configs))
	# Push the global Legacy-upgrade cost multiplier into the (stateless) catalog too, so every
	# upgrade price reflects the tuning knob (Tim 2026-07-14 — the prestige-runaway brake).
	LegacyUpgradeCatalog.cost_multiplier = tuning.legacy_upgrade_cost_multiplier
	# And the cost STEEPENING (Plans/Endgame_Economy.md): the per-level growth factor itself
	# grows by this each level, which is what lets the compounders run uncapped.
	LegacyUpgradeCatalog.cost_steepening = tuning.legacy_cost_steepening
	# Same pattern for the (stateless) Challenge-goal tables: push the whole tuning object in so every
	# payout, escalating-cost, and per-game keep-alive query sees the tuned values. Re-pushed on every
	# construction/load — see the GOTCHA in ChallengeGoals (a sim sets the TUNING field, not the
	# static, or this would overwrite it).
	ChallengeGoals.configure(tuning)


# ---------------------------------------------------------------------------
# The draft will and the succession gate (Spec §9.1–9.3)
# ---------------------------------------------------------------------------

## The live estate waterfall for the current generation — what the heir would
## inherit if death happened now. Used by the succession gate below and, later,
## displayed continuously on the Estate Planning tab. Debt is 0 until the
## debt/offers slice lands; the waterfall already accepts it as a parameter.
func get_draft_will() -> Dictionary:
	# The gross estate is the dollars this generation EARNED over its life (Spec §9.1,
	# GDD §8.3 decision 2026-06-14), not net worth at death. Earning over a life is what
	# the idle loop actually is, and being monotonic it stays comparable across the
	# order-of-magnitude epoch jumps. Granted money (birth seed, loan principal) is
	# excluded by construction — it never entered cash_earned_this_gen.
	var estate_gross := current.economy.cash_earned_this_gen
	var outstanding_debt := 0.0  # debt & offers system is a later M2 slice
	var will := EstateWaterfall.compute(
		estate_gross,
		outstanding_debt,
		tuning.estate_exemption_base,
		tuning.estate_tax_rate_base
	)
	# Legacy converts directly from the post-tax net (Spec §9.3); the exemption already
	# gates small estates. The old seed-cash subtraction is gone — seed money is granted,
	# so it was never part of the earned gross. The "Estate Lawyers" upgrade then boosts
	# the yield; floor after the multiplier so Legacy stays a whole number. The multiplier comes from
	# the single-source get_legacy_yield_multiplier so the Challenge Legacy-track bonus is folded in
	# here exactly once (the ONLY caller of that method) — never doubled, never missed.
	var base_gain := EstateWaterfall.legacy_gain(
		will["estate_net"], tuning.k_legacy, tuning.alpha_legacy,
		tuning.legacy_knee_net, tuning.alpha_legacy_deep
	)
	will["legacy_gain"] = int(floor(float(base_gain) * get_legacy_yield_multiplier()))
	return will


## Legacy the current estate would convert to if death happened now.
func projected_legacy_gain() -> int:
	return int(get_draft_will()["legacy_gain"])


## Succession is allowed once dying would actually grow the dynasty — i.e. the
## estate converts to at least 1 Legacy (Spec §9.1, the minimum-estate gate).
func can_perform_succession() -> bool:
	return projected_legacy_gain() >= 1


# ---------------------------------------------------------------------------
# Succession — death, inheritance, rebirth
# ---------------------------------------------------------------------------

## Kill the current generation and raise its heir. Banks the estate's Legacy into
## the spendable wallet, records the deceased in the Family Ledger, advances the
## generation counter, carries dynastic Work Ethic forward, and replaces `current`
## with a fresh generation that already has all purchased upgrade effects applied.
## `cause` is the deadpan generation-end recorded in the Ledger (GDD §8.2) — the
## natural-death default, or "Creditors" when the bankruptcy path calls this.
## Returns the executed will for ceremony.
func perform_succession(
		cause: String = "Retired to Palm Beach",
		minigame_multiplier: float = 1.0
) -> Dictionary:
	var will := get_draft_will()

	# The prestige minigame (GDD §5.5) sets how much of the run's Legacy is KEPT: the
	# will (get_draft_will) is the deterministic base, and the minigame multiplier scales
	# what is actually banked — below 1.0 for a poor round (or a skip), above 1.0 into the
	# extra-high bonus for a great one. Clamped to ≥0 only (never negative), floored like
	# the base conversion. The bankruptcy path calls with the default 1.0× (full).
	var awarded := int(floor(float(will["legacy_gain"]) * maxf(0.0, minigame_multiplier)))
	will["legacy_awarded"] = awarded
	will["minigame_multiplier"] = minigame_multiplier
	upgrades.award(awarded)
	# Roll this life's earnings into the dynasty's monotonic lifetime total before the
	# generation is replaced (the obituary headline / Family Ledger career stat).
	lifetime_cash_earned += current.economy.cash_earned_this_gen
	# Record the deceased in the Family Ledger before the generation counter advances,
	# so the name/numeral match the life that just ended (not the incoming heir's).
	ancestors.append({
		"name": HeirNames.dynasty_name(generation),
		"generation": generation,
		"fortune": current.economy.cash_earned_this_gen,
		"cause": cause,
	})
	dynastic_taps = current.wage.lifetime_taps
	generation += 1

	# Record this life's staff ladders as the bloodline's achievement BEFORE the reset —
	# retention can be bought up to these highs forever after (GDD §6.3, Tim 2026-07-04).
	for i in range(current.economy.properties.size()):
		var prop := current.economy.properties[i] as PropertyState
		staff_retention.record_ladder_high(i, prop.staff_level)

	current = _new_generation()
	_record_overheats_from_current()
	return will


# ---------------------------------------------------------------------------
# Building generations and applying purchased upgrade effects
# ---------------------------------------------------------------------------

## Build the next generation from scratch. The heir starts with the base opening
## capital plus any Trust Fund bonus, inherits Work Ethic, and has every other
## purchased upgrade effect (cycle speed, staff cost, wage) applied to its fresh
## state. Property income is multiplied at tick time, not seeded as cash.
func _new_generation() -> GameState:
	var heir := GameState.new(_property_configs, tuning)
	# Seed the heir with opening capital + any Trust Fund bonus, and record that
	# seed so the estate→Legacy conversion can later exclude it (granted money is
	# not dynastic achievement). award_cash floors the amount, so floor the record
	# to match exactly.
	var seed_cash := floorf(tuning.m1_starting_cash + upgrades.starting_cash_bonus())
	heir.economy.award_cash(seed_cash)
	heir.economy.starting_cash = seed_cash
	# Work Ethic (the lifetime tap count) carries forward as a number, but the heir
	# re-climbs the clock-in ladder from level 0 (a fresh WageState already starts there).
	heir.wage.lifetime_taps = dynastic_taps
	_carry_player_settings_to_heir(heir)
	_apply_upgrade_effects(heir)
	_apply_retained_staff(heir)
	return heir


## Carry the player's PREFERENCES across a succession.
##
## A succession builds a brand-new GameState, so anything living on GameState that is a player
## CHOICE rather than dynastic state silently reverts to its default every prestige. Tim caught
## this on the number-format setting (2026-08-05: "I think the currency formatting option I chose
## reset after prestige") — and it was never format-specific: the buy mode, the hire mode, the
## targeted epoch tab and the minigame opt-out were all being dropped the same way. It hid well,
## because Main keeps its own UI mirrors, so the CONTROLS still showed the old choice while
## GameState had already reverted; the loss only surfaced on the next launch, once the reverted
## value had been written to the save.
##
## These are settings, not achievements — and for anything gated behind a Legacy upgrade the
## distinction has teeth, because the upgrade itself survives succession by definition. Letting
## a mode switch itself off every generation would keep disabling something bought with gems.
##
## `current` is null on the very first call (the constructor builds generation one before there
## is anything to inherit from), so there is nothing to carry and the heir keeps its defaults.
func _carry_player_settings_to_heir(heir: GameState) -> void:
	if current == null:
		return
	heir.ui_buy_mode = current.ui_buy_mode
	heir.ui_hire_mode = current.ui_hire_mode
	heir.ui_minigame_enabled = current.ui_minigame_enabled
	heir.ui_epoch_tab = current.ui_epoch_tab
	heir.ui_currency_format = current.ui_currency_format
	heir.ui_music_volume = current.ui_music_volume
	heir.ui_sfx_volume = current.ui_sfx_volume
	heir.ui_haptics_scale = current.ui_haptics_scale
	# AUTO-PURCHASE IS DELIBERATELY NOT CARRIED — the heir wakes with the desk switched OFF
	# (Tim, 2026-08-01). It is the one setting here that SPENDS money rather than describing a
	# preference, and an heir owns almost nothing: the opening capital plus any Trust Fund. Left
	# on, the desk would skim that seed before the player could aim it, and it would also hold
	# rush shut during the fast early climb, which is exactly when rush is worth most. The track
	# stays bought, so switching it back on is one tap whenever the generation is ready for it.


## Seed an heir with the staff-ladder levels the dynasty has paid (in Legacy) to retain
## (GDD §6.3). Units do NOT carry over — only the ladder — so the heir is born with the
## staffer roster in place but no properties yet; the first unit they buy auto-cycles at
## the retained ladder's full multiplier. Retained levels can reach above the heir's
## current epoch: that is the whole point of prestige — willing an heir alien staff
## before it has earned its way back to that epoch.
func _apply_retained_staff(heir: GameState) -> void:
	for property_index in staff_retention.retained_levels:
		var levels := staff_retention.get_retained_levels(property_index)
		if levels >= 1:
			var prop := heir.economy.properties[property_index] as PropertyState
			prop.will_staff_levels(levels)


## Apply the purchased per-generation upgrade effects to a generation's state:
## cycle speed and staff-cost discount on every property, and the wage multiplier
## on the wage ladder. (Property income and Legacy yield are read live elsewhere,
## so they need no baking-in here.)
func _apply_upgrade_effects(game: GameState) -> void:
	var cycle_speed := upgrades.cycle_speed_multiplier()
	var staff_cost := upgrades.staff_cost_multiplier()
	var rush_power := upgrades.rush_power_multiplier()
	var auto_speed := upgrades.auto_click_speed_multiplier()
	# Family Fortune × the permanent Challenge-goal income bonus — the SAME value the passive tick
	# reads via get_legacy_income_multiplier(). Seeding the property field from that one method (not
	# from upgrades alone) is what keeps the rush-collect path (which reads this field) and the
	# passive path applying the challenge bonus identically — exactly once, never twice, never missed.
	var income_mult := get_legacy_income_multiplier()
	for prop in game.economy.properties:
		var p := prop as PropertyState
		p.set_cycle_speed_multiplier(cycle_speed)
		p.staff_cost_multiplier = staff_cost
		p.rush_power_multiplier = rush_power
		p.auto_rush_speed_multiplier = auto_speed
		# Display mirror of Family Fortune, so the row's per-cycle figure reflects it
		# (the live tick already applies the same factor at payment via tick()).
		p.legacy_income_multiplier = income_mult
	game.wage.wage_multiplier = upgrades.wage_multiplier()
	game.wage.auto_tap_speed_multiplier = auto_speed
	# Frenzy (TURBO) upgrades: a bigger popped multiplier (Killer Instinct) and a longer burn
	# (Second Wind). Read live by FrenzyState.pop()/tick().
	game.frenzy.intensity_multiplier = upgrades.frenzy_intensity_multiplier()
	game.frenzy.duration_multiplier = upgrades.frenzy_duration_multiplier()
	# Rush cruise upgrades: a hotter safe cruise point (Cooling Systems) and a shorter overheat
	# lockout (Rapid Restart). Read live by RushMomentumState's tick — and because this also runs
	# via refresh_current_generation_effects, a purchase takes hold mid-life, like every upgrade.
	game.rush_momentum.legacy_cruise_bonus = upgrades.cruise_bonus_points()
	game.rush_momentum.lockout_time_scale = upgrades.overheat_lockout_scale()


## Re-apply upgrade effects to the LIVING generation. Called after a purchase so a
## newly-bought cycle/staff/wage upgrade takes hold immediately, mid-life. (The
## Trust Fund starting-cash bonus is deliberately NOT retroactive — it only
## affects heirs born after it is bought, as the upgrade description says.)
func refresh_current_generation_effects() -> void:
	_apply_upgrade_effects(current)


# ---------------------------------------------------------------------------
# Save / load (the dynastic block wraps the current generation's save)
# ---------------------------------------------------------------------------

## Everything needed to reconstruct the dynasty: the cross-generation facts plus
## the current generation's own save dict (GameState.to_save_dict).
func to_save_dict() -> Dictionary:
	return {
		"upgrades": upgrades.to_save_dict(),
		"staff_retention": staff_retention.to_save_dict(),
		"generation": generation,
		"dynastic_taps": dynastic_taps,
		"lifetime_cash_earned": lifetime_cash_earned,
		"best_vent_streak": best_vent_streak,
		"challenge_highest_tiers": challenge_highest_tiers,
		"met_minigames": met_minigames,
		"ancestors": ancestors,
		"current": current.to_save_dict(),
	}


## Restore a dynasty from a save dict. Three save shapes load cleanly:
##   • current shape — has an "upgrades" block.
##   • the prior dynasty shape — had a flat "legacy_total"; we treat that banked
##     total as the player's starting wallet (nothing was spendable before, so it
##     becomes both available and lifetime).
##   • a bare M1 GameState save — no dynastic wrapper at all; it reconstructs as a
##     clean generation-1 dynasty, because every dynastic field defaults and the
##     whole dict is handed to the current generation to load.
func load_save_dict(data: Dictionary) -> void:
	generation = int(data.get("generation", 1))
	dynastic_taps = int(data.get("dynastic_taps", 0))
	# Pre-basis-swap saves have no dynasty-wide earned total; default to 0.0.
	lifetime_cash_earned = float(data.get("lifetime_cash_earned", 0.0))
	# Pre-stats-screen saves have no best-streak record; default to 0 (never reached a vent).
	best_vent_streak = int(data.get("best_vent_streak", 0))
	# Pre-Challenge-Mode saves have no cleared-tier record; default to empty (→ 0 income bonus).
	# Duplicate so the loaded dynasty owns its own dictionary, not the save's (like `ancestors`).
	challenge_highest_tiers = (data.get("challenge_highest_tiers", {}) as Dictionary).duplicate()
	# The met-minigame set (Plans/Challenge_Mode_Gating.md). No SAVE_VERSION bump: an additive key
	# that defaults safely needs none (the ui_currency_format precedent, 2026-08-05).
	#
	# We test has() rather than reading a {} default, because ABSENT and PRESENT-BUT-EMPTY are two
	# different states and must not be conflated:
	#   • ABSENT — a save written before this feature existed. Defaulting it to empty would show
	#     every game locked to a player who has already met them all, which is the exact failure
	#     Roadmap §8 rejects elsewhere. So we SEED it from the bloodline's own evidence: the keys of
	#     challenge_highest_tiers. You cannot have banked a cleared tier in a game without having
	#     played it, so those games are demonstrably met. (A pre-Challenge-Mode save has no tiers
	#     either, and correctly seeds to nothing.)
	#   • PRESENT AND EMPTY — a real, current state: a fresh dynasty that has met nothing yet. It
	#     must be left empty, never re-seeded.
	if data.has("met_minigames"):
		# Duplicate so the loaded dynasty owns its own dictionary, not the save's (like `ancestors`).
		met_minigames = (data["met_minigames"] as Dictionary).duplicate()
	else:
		met_minigames = {}
		for game_key in challenge_highest_tiers.keys():
			met_minigames[game_key] = true
	# Pre-Family-Ledger saves have no ancestor list; default to empty. Duplicate each
	# entry so the loaded dynasty owns its own dictionaries, not the save's.
	ancestors = []
	for record in data.get("ancestors", []):
		ancestors.append((record as Dictionary).duplicate())

	# Per-staffer retention (GDD §6.3); pre-retention saves default to nothing retained.
	staff_retention = StaffRetention.new()
	_configure_retention_pricing()
	if data.has("staff_retention"):
		staff_retention.load_save_dict(data["staff_retention"])

	upgrades = LegacyUpgrades.new()
	if data.has("upgrades"):
		upgrades.load_save_dict(data["upgrades"])
		# v13 utility restructure (Plans/Endgame_Economy.md): the capped utility tracks
		# doubled their level counts at half the per-level effect. Owned levels migrate
		# BY EFFECT — a pre-v13 level maps to twice the level number, which grants the
		# exact same total bonus the player had bought (never by raw level number).
		var save_version := int((data.get("current", data) as Dictionary).get("version", 1)) \
				if data.get("current", data) is Dictionary else 1
		if save_version <= 12:
			for id in [LegacyUpgradeCatalog.SEED_CAPITAL, LegacyUpgradeCatalog.LOYAL_STAFF,
					LegacyUpgradeCatalog.ESTATE_LAWYERS, LegacyUpgradeCatalog.MINIGAME_BONUS,
					LegacyUpgradeCatalog.COOLING_SYSTEMS, LegacyUpgradeCatalog.RAPID_RESTART]:
				if upgrades.get_level(id) > 0:
					var max_level := int(LegacyUpgradeCatalog.get_definition(id)["max_level"])
					upgrades.levels[id] = mini(upgrades.get_level(id) * 2, max_level)
	elif data.has("legacy_total"):
		# Migrate the old accumulate-only Legacy into the new spendable wallet.
		var carried := int(data.get("legacy_total", 0))
		upgrades.available = carried
		upgrades.earned_lifetime = carried

	current = GameState.new(_property_configs, tuning)
	_record_overheats_from_current()
	var current_data: Variant = data.get("current", data)
	if current_data is Dictionary:
		current.load_save_dict(current_data)
	# Make sure the restored living generation reflects purchased upgrades.
	_apply_upgrade_effects(current)
