class_name LegacyUpgrades

# The player's purchased Legacy upgrades plus their spendable Legacy balance —
# the dynasty's permanent perk sheet (GDD §13 / the M2 prestige reward).
#
# This replaces the old "Legacy is an automatic multiplier" model: Legacy is now
# a CURRENCY the player spends here on lasting upgrades (more starting cash,
# higher property income, faster cycles, cheaper staff, a fatter wage, and a
# better Legacy yield). The estate→Legacy conversion still happens at every
# death (EstateWaterfall.legacy_gain); that gain is banked into `available` to
# be spent, and also summed into `earned_lifetime` for the long-arc score.
#
# Headless and scene-tree-free like the rest of the core, so the simulator and
# the shop UI drive the exact same purchase logic.

## Legacy the player can still spend. Goes up at each succession, down on a buy.
var available: int = 0

## Total Legacy ever earned across the whole dynasty — never spent down. This is
## the long-arc prestige score shown in the will/ledger; `available` is the wallet.
var earned_lifetime: int = 0

## Purchased level of each upgrade, keyed by catalog id. Absent id == level 0.
var levels: Dictionary = {}


# ---------------------------------------------------------------------------
# Banking and spending Legacy
# ---------------------------------------------------------------------------

## Bank Legacy earned at a succession: it becomes spendable AND adds to the
## lifetime total. Negative or zero gains are ignored.
func award(amount: int) -> void:
	if amount <= 0:
		return
	available += amount
	earned_lifetime += amount


## Current purchased level of an upgrade (0 if never bought).
func get_level(id: String) -> int:
	return int(levels.get(id, 0))


## Legacy cost to buy the NEXT level of an upgrade, or -1 if already maxed.
func get_next_cost(id: String) -> int:
	var definition := LegacyUpgradeCatalog.get_definition(id)
	if definition.is_empty():
		return -1
	var next_level := get_level(id) + 1
	if next_level > int(definition["max_level"]):
		return -1
	return LegacyUpgradeCatalog.cost_for_level(id, next_level)


## True if the upgrade can still be bought AND the player can afford the next level.
func can_buy(id: String) -> bool:
	var cost := get_next_cost(id)
	return cost >= 0 and available >= cost


## True once the upgrade has reached its maximum level.
func is_maxed(id: String) -> bool:
	var definition := LegacyUpgradeCatalog.get_definition(id)
	if definition.is_empty():
		return true
	return get_level(id) >= int(definition["max_level"])


## Buy one level of an upgrade. Spends the Legacy and raises the level. Returns
## true on success; false (and no change) if maxed or unaffordable.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var cost := get_next_cost(id)
	available -= cost
	levels[id] = get_level(id) + 1
	return true


# ---------------------------------------------------------------------------
# Effect getters — turn purchased levels into concrete bonuses/multipliers.
# The per-level magnitude lives in the catalog; the FORMULA lives here, next to
# the value that consumes it, so the two can never drift (mirrors how the cost
# formula sits beside cost_for_level in the catalog).
# ---------------------------------------------------------------------------

## Extra starting cash every heir is born with (Trust Fund). Additive dollars.
func starting_cash_bonus() -> float:
	return _per_level(LegacyUpgradeCatalog.SEED_CAPITAL) * float(get_level(LegacyUpgradeCatalog.SEED_CAPITAL))


## Permanent multiplier on PROPERTY income (Family Fortune). 1.0 with nothing bought.
## This is the dynasty's main accelerator now that the automatic Legacy sprint is gone.
##
## COMPOUNDING: each level multiplies income by (1 + per_level), so every level is the
## same RELATIVE jump (e.g. +20%) no matter how deep you are — the Idle-Slayer "there's
## always a meaningful next upgrade" feel (Tim, 2026-06-15). The geometric Legacy cost in
## the catalog is what stops you, not a diminishing effect, so the chase never goes flat.
func property_income_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.FAMILY_FORTUNE)
	var level := get_level(LegacyUpgradeCatalog.FAMILY_FORTUNE)
	return pow(1.0 + per_level, float(level))


## Multiplier on cycle SPEED (Efficiency Experts). 1.0 = normal; 1.5 = cycles
## complete in 2/3 the time. PropertyState divides its cycle length by this.
## Compounding per level, same rationale as property_income_multiplier (cycle_floor
## in PropertyState still caps how short a cycle can actually get).
func cycle_speed_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.EFFICIENCY)
	var level := get_level(LegacyUpgradeCatalog.EFFICIENCY)
	return pow(1.0 + per_level, float(level))


## Multiplier on staff HIRING cost (Loyal Staff). Below 1.0 means a discount.
## Floored at 0.2 so hiring can never become effectively free.
func staff_cost_multiplier() -> float:
	var discount := _per_level(LegacyUpgradeCatalog.LOYAL_STAFF) * float(get_level(LegacyUpgradeCatalog.LOYAL_STAFF))
	return maxf(0.2, 1.0 - discount)


## Multiplier on the wage earned per tap (Old-Money Connections). 1.0 = base wage.
## Compounding per level, same rationale as property_income_multiplier.
func wage_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.CONNECTIONS)
	var level := get_level(LegacyUpgradeCatalog.CONNECTIONS)
	return pow(1.0 + per_level, float(level))


## Multiplier on Legacy gained at each succession (Estate Lawyers). 1.0 = base yield.
func legacy_yield_multiplier() -> float:
	return 1.0 + _per_level(LegacyUpgradeCatalog.ESTATE_LAWYERS) * float(get_level(LegacyUpgradeCatalog.ESTATE_LAWYERS))


## Multiplier on held auto-tap / auto-rush SPEED (Restless Hands). Compounding, same
## rationale as property_income_multiplier. 1.0 with nothing bought.
func auto_click_speed_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.AUTO_CLICK_SPEED)
	var level := get_level(LegacyUpgradeCatalog.AUTO_CLICK_SPEED)
	return pow(1.0 + per_level, float(level))


## Multiplier on the wage earned per HELD auto-tap (Piecework Bonus). Compounding. 1.0
## with nothing bought. Applied only to held auto-taps, not manual taps (GameState).
func auto_click_power_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.AUTO_CLICK_POWER)
	var level := get_level(LegacyUpgradeCatalog.AUTO_CLICK_POWER)
	return pow(1.0 + per_level, float(level))


## Multiplier on how far one rush-tap advances a cycle (Strong-Arm Tactics). Compounding.
## 1.0 with nothing bought. PropertyState scales rush_pct by this.
func rush_power_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.RUSH_POWER)
	var level := get_level(LegacyUpgradeCatalog.RUSH_POWER)
	return pow(1.0 + per_level, float(level))


## The maximum EXTRA-HIGH bonus the prestige minigame can pay, as a fraction above full
## (GDD §5.5). 0.25 base (a perfect round keeps +25%), raised +5%/level by Family
## Reputation. Additive — a steady, ownable climb. MinigameScreen reads this to size its
## extra-high zone and cap the multiplier.
const MINIGAME_BONUS_BASE := 0.25

func minigame_bonus_max() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.MINIGAME_BONUS)
	var level := get_level(LegacyUpgradeCatalog.MINIGAME_BONUS)
	return MINIGAME_BONUS_BASE + per_level * float(level)


## The catalog's per-level magnitude for an upgrade (0.0 if unknown).
func _per_level(id: String) -> float:
	var definition := LegacyUpgradeCatalog.get_definition(id)
	if definition.is_empty():
		return 0.0
	return float(definition["effect_per_level"])


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"available": available,
		"earned_lifetime": earned_lifetime,
		# Duplicated into a plain dict so the JSON is a clean {id: level} map.
		"levels": levels.duplicate(),
	}


func load_save_dict(data: Dictionary) -> void:
	available = int(data.get("available", 0))
	earned_lifetime = int(data.get("earned_lifetime", 0))
	levels = {}
	var saved_levels: Dictionary = data.get("levels", {})
	for id in saved_levels:
		levels[id] = int(saved_levels[id])
