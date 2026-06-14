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

## Which generation is alive, 1-based — the Roman-numeral suffix (Wellington IX).
var generation: int = 1

## Lifetime taps across all generations ("Work Ethic"); persists per Spec §5.
var dynastic_taps: int = 0

## The generation alive right now. All active play happens through this.
var current: GameState


func _init(property_configs: Array, titles: Array, p_tuning: TuningConfig) -> void:
	_property_configs = property_configs
	_title_configs = titles
	tuning = p_tuning
	upgrades = LegacyUpgrades.new()
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
# The draft will and the succession gate (Spec §9.1–9.3)
# ---------------------------------------------------------------------------

## The live estate waterfall for the current generation — what the heir would
## inherit if death happened now. Used by the succession gate below and, later,
## displayed continuously on the Estate Planning tab. Debt is 0 until the
## debt/offers slice lands; the waterfall already accepts it as a parameter.
func get_draft_will() -> Dictionary:
	var estate_gross := current.economy.get_net_worth()
	var outstanding_debt := 0.0  # debt & offers system is a later M2 slice
	var will := EstateWaterfall.compute(
		estate_gross,
		outstanding_debt,
		tuning.estate_exemption_base,
		tuning.estate_tax_rate_base
	)
	# Legacy is earned only on wealth the generation BUILT: the seed cash every heir
	# is handed (starting capital + Trust Fund) is excluded, so granted money can
	# never be converted into Legacy. The seed is far below one point early on, so
	# this is what makes the first Legacy point take real playtime to reach.
	var built_estate := maxf(0.0, will["estate_net"] - current.economy.starting_cash)
	# Base estate→Legacy conversion, then the "Estate Lawyers" upgrade boosts the
	# yield. Floor after the multiplier so Legacy stays a whole number.
	var base_gain := EstateWaterfall.legacy_gain(
		built_estate, tuning.k_legacy, tuning.alpha_legacy
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
## the spendable wallet, advances the generation counter, carries dynastic Work
## Ethic forward, and replaces `current` with a fresh generation that already has
## all purchased upgrade effects applied. Returns the executed will for ceremony.
func perform_succession() -> Dictionary:
	var will := get_draft_will()

	upgrades.award(int(will["legacy_gain"]))
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
	_apply_upgrade_effects(heir)
	return heir


## Apply the purchased per-generation upgrade effects to a generation's state:
## cycle speed and staff-cost discount on every property, and the wage multiplier
## on the wage ladder. (Property income and Legacy yield are read live elsewhere,
## so they need no baking-in here.)
func _apply_upgrade_effects(game: GameState) -> void:
	var cycle_speed := upgrades.cycle_speed_multiplier()
	var staff_cost := upgrades.staff_cost_multiplier()
	for prop in game.economy.properties:
		var p := prop as PropertyState
		p.set_cycle_speed_multiplier(cycle_speed)
		p.staff_cost_multiplier = staff_cost
	game.wage.wage_multiplier = upgrades.wage_multiplier()


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
		"generation": generation,
		"dynastic_taps": dynastic_taps,
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
