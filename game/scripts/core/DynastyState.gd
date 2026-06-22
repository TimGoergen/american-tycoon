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
var _title_configs: Array

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

## One record per deceased generation, oldest first — the Family Ledger (GDD §8.2).
## Each entry is a Dictionary: { "name": String (e.g. "Wellington Pemberton VIII"),
## "generation": int, "fortune": float (the life's cash_earned_this_gen — the
## obituary headline figure), "cause": String (how the generation ended) }.
var ancestors: Array = []

## The generation alive right now. All active play happens through this.
var current: GameState


func _init(property_configs: Array, titles: Array, p_tuning: TuningConfig) -> void:
	_property_configs = property_configs
	_title_configs = titles
	tuning = p_tuning
	upgrades = LegacyUpgrades.new()
	staff_retention = StaffRetention.new()
	current = _new_generation()


# ---------------------------------------------------------------------------
# Driving the living generation
# ---------------------------------------------------------------------------

## Advance the current generation by `delta` seconds, applying the dynasty's
## property-income multiplier (from the Legacy "Family Fortune" upgrade) to
## property income only — never to the wage (Spec §9.4: the wage is honest).
func tick(delta: float) -> void:
	current.tick(delta, get_legacy_income_multiplier())


## The property-income multiplier in force this instant. It comes entirely from
## the purchased Family Fortune upgrade now (1.0 when nothing is bought), so the
## acceleration is something the player chooses to buy, not an automatic bonus.
func get_legacy_income_multiplier() -> float:
	return upgrades.property_income_multiplier()


# ---------------------------------------------------------------------------
# Per-staffer retention (GDD §6.3) — the Legacy-bought exception to the
# "staff reset on prestige" default.
# ---------------------------------------------------------------------------

## Buy one more tier of retention for a property's staffer, spending Legacy from the
## wallet. You can only retain UP TO the tier the living generation's staffer actually
## holds right now ("you can only will what you have"). Returns true on success; false
## if there is nothing higher to retain or the player can't afford the next tier.
func buy_staff_retention(property_index: int) -> bool:
	var prop := current.economy.properties[property_index] as PropertyState
	var next_tier := staff_retention.next_retention_tier(property_index)
	# Can't retain a tier higher than the staffer currently is in this life.
	if next_tier > prop.staff_tier:
		return false
	var cost := staff_retention.cost_for_tier(next_tier)
	if upgrades.available < cost:
		return false
	upgrades.available -= cost
	staff_retention.set_retained_tier(property_index, next_tier)
	return true


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
	# the yield; floor after the multiplier so Legacy stays a whole number.
	var base_gain := EstateWaterfall.legacy_gain(
		will["estate_net"], tuning.k_legacy, tuning.alpha_legacy
	)
	will["legacy_gain"] = int(floor(float(base_gain) * upgrades.legacy_yield_multiplier()))
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

	current = _new_generation()
	return will


# ---------------------------------------------------------------------------
# Building generations and applying purchased upgrade effects
# ---------------------------------------------------------------------------

## Build the next generation from scratch. The heir starts with the base opening
## capital plus any Trust Fund bonus, inherits Work Ethic, and has every other
## purchased upgrade effect (cycle speed, staff cost, wage) applied to its fresh
## state. Property income is multiplied at tick time, not seeded as cash.
func _new_generation() -> GameState:
	var heir := GameState.new(_property_configs, _title_configs, tuning)
	# Seed the heir with opening capital + any Trust Fund bonus, and record that
	# seed so the estate→Legacy conversion can later exclude it (granted money is
	# not dynastic achievement). award_cash floors the amount, so floor the record
	# to match exactly.
	var seed_cash := floorf(tuning.m1_starting_cash + upgrades.starting_cash_bonus())
	heir.economy.award_cash(seed_cash)
	heir.economy.starting_cash = seed_cash
	heir.wage.lifetime_taps = dynastic_taps
	# The heir starts back at the first title, so baseline their promotion meter to the
	# inherited tap count: Work Ethic carries forward as a number, but the heir still
	# re-climbs the ladder from an empty meter rather than inheriting a full one.
	heir.wage.taps_at_title_start = dynastic_taps
	_apply_upgrade_effects(heir)
	_apply_retained_staff(heir)
	return heir


## Seed an heir with any staffers the dynasty has paid (in Legacy) to retain (GDD §6.3).
## Units do NOT carry over — only the staffer tier — so the heir is born with the
## staffer in place but no properties yet; the first unit they buy auto-cycles at the
## retained tier's multiplier. A retained tier can sit above the heir's current epoch:
## that is the whole point of prestige — willing an heir alien staff before it has
## earned its way back to that epoch.
func _apply_retained_staff(heir: GameState) -> void:
	for property_index in staff_retention.retained_tiers:
		var tier := staff_retention.get_retained_tier(property_index)
		if tier >= 1:
			var prop := heir.economy.properties[property_index] as PropertyState
			prop.set_staff_tier(tier, EpochCatalog.staff_income_multiplier(tier))


## Apply the purchased per-generation upgrade effects to a generation's state:
## cycle speed and staff-cost discount on every property, and the wage multiplier
## on the wage ladder. (Property income and Legacy yield are read live elsewhere,
## so they need no baking-in here.)
func _apply_upgrade_effects(game: GameState) -> void:
	var cycle_speed := upgrades.cycle_speed_multiplier()
	var staff_cost := upgrades.staff_cost_multiplier()
	var rush_power := upgrades.rush_power_multiplier()
	var auto_speed := upgrades.auto_click_speed_multiplier()
	var income_mult := upgrades.property_income_multiplier()
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
	game.wage.auto_tap_power_multiplier = upgrades.auto_click_power_multiplier()


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
	# Pre-Family-Ledger saves have no ancestor list; default to empty. Duplicate each
	# entry so the loaded dynasty owns its own dictionaries, not the save's.
	ancestors = []
	for record in data.get("ancestors", []):
		ancestors.append((record as Dictionary).duplicate())

	# Per-staffer retention (GDD §6.3); pre-retention saves default to nothing retained.
	staff_retention = StaffRetention.new()
	if data.has("staff_retention"):
		staff_retention.load_save_dict(data["staff_retention"])

	upgrades = LegacyUpgrades.new()
	if data.has("upgrades"):
		upgrades.load_save_dict(data["upgrades"])
	elif data.has("legacy_total"):
		# Migrate the old accumulate-only Legacy into the new spendable wallet.
		var carried := int(data.get("legacy_total", 0))
		upgrades.available = carried
		upgrades.earned_lifetime = carried

	current = GameState.new(_property_configs, _title_configs, tuning)
	var current_data: Variant = data.get("current", data)
	if current_data is Dictionary:
		current.load_save_dict(current_data)
	# Make sure the restored living generation reflects purchased upgrades.
	_apply_upgrade_effects(current)
