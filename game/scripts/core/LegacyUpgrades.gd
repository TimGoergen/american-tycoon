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


## Grant an UNEARNED Legacy bonus (a minigame legacy-gem windfall — see Plans/Legacy_Bonus_
## System.md). Adds to the spendable wallet ONLY, deliberately NOT to earned_lifetime: the bonus is
## a perk, so it never inflates its own 0.1%-of-lifetime base or the long-arc prestige score.
func grant_bonus(amount: int) -> void:
	if amount <= 0:
		return
	available += amount


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
	if not requirement_met(id):
		return false
	var cost := get_next_cost(id)
	return cost >= 0 and available >= cost


## True when this upgrade's prerequisite (if it has one) is owned.
##
## Added 2026-08-07 for the auto-purchase restructure. Buying Power and Standing Orders only do
## anything once the Acquisitions Desk is owned — auto_purchase_quantity() returns 0 while the mode
## is locked — so without this a player could spend 5,000 gems on an upgrade that grants literally
## nothing, with no way to tell. That is a refund request, not a design.
##
## Enforced in can_buy rather than in the UI so every path obeys it: the shop's buy button, the
## sims' greedy shopper, and anything written later all go through the same gate.
func requirement_met(id: String) -> bool:
	var required := requirement_for(id)
	return required == "" or get_level(required) >= 1


## The upgrade id this one depends on, or "" if it stands alone.
func requirement_for(id: String) -> String:
	var definition := LegacyUpgradeCatalog.get_definition(id)
	if definition.is_empty():
		return ""
	return String(definition.get("requires", ""))


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
## Compounding per level, same rationale as property_income_multiplier. Note: cycle_floor
## only bounds the BASE cycle_length set by milestones; it does NOT cap the effective cycle
## after dividing by this multiplier, so effective time-between-payouts can fall below 1s.
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


## Multiplier on how far one rush-tap advances a cycle (Strong-Arm Tactics). Compounding.
## 1.0 with nothing bought. PropertyState scales rush_pct by this.
func rush_power_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.RUSH_POWER)
	var level := get_level(LegacyUpgradeCatalog.RUSH_POWER)
	return pow(1.0 + per_level, float(level))


## Multiplier on the frenzy (TURBO) BONUS — the amount the popped multiplier climbs above 1×
## (Killer Instinct). Compounding, same rationale as property_income_multiplier. FrenzyState.pop()
## scales the bonus by this. 1.0 with nothing bought.
func frenzy_intensity_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.FRENZY_INTENSITY)
	var level := get_level(LegacyUpgradeCatalog.FRENZY_INTENSITY)
	return pow(1.0 + per_level, float(level))


## Multiplier on the frenzy (TURBO) burn DURATION (Second Wind). Compounding. FrenzyState.tick()
## divides the burn-drain rate by this so a pop lasts longer. 1.0 with nothing bought.
func frenzy_duration_multiplier() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.FRENZY_DURATION)
	var level := get_level(LegacyUpgradeCatalog.FRENZY_DURATION)
	return pow(1.0 + per_level, float(level))


## Extra cruise-bonus POINTS for the rush heat meter (Cooling Systems), as an additive fraction
## (0.01/level, so level 5 = +0.05 — lifting the +25% cruise back to the old +30% cap). Additive
## with a hard cap on purpose: a limitation-remover must never compound (see the catalog note).
## RushMomentumState hard-caps the total at bonus_at_hot regardless, so this getter can stay simple.
func cruise_bonus_points() -> float:
	return _per_level(LegacyUpgradeCatalog.COOLING_SYSTEMS) \
			* float(get_level(LegacyUpgradeCatalog.COOLING_SYSTEMS))


## Scale on the TOTAL overheat lockout time (Rapid Restart): 1.0 with nothing bought, 0.5 at the
## level-5 cap — half the punishment, never zero. RushMomentumState divides the locked drain rate
## by this and multiplies the re-arm delay by it, so both halves of the lockout shrink together.
func overheat_lockout_scale() -> float:
	var reduction := _per_level(LegacyUpgradeCatalog.RAPID_RESTART) \
			* float(get_level(LegacyUpgradeCatalog.RAPID_RESTART))
	# Floored well above zero as a guard; the catalog cap (5 × 0.10) already stops at 0.5.
	return maxf(1.0 - reduction, 0.1)


## The maximum EXTRA-HIGH bonus the prestige minigame can pay, as a fraction above full
## (GDD §5.5). 0.25 base (a perfect round keeps +25%), raised +5%/level by Family
## Reputation. Additive — a steady, ownable climb. MinigameScreen reads this to size its
## extra-high zone and cap the multiplier.
const MINIGAME_BONUS_BASE := 0.25

## The top of the bulk-hire ladder, which everyone now has (see max_hire_mode). Must match the
## highest ordinal of PropertyRow.HireMode — currently { ONE, TEN, MAX }, so 2. Duplicated as a
## literal because scripts/core/ must not name a UI class; PropertyRow's enum comment points back
## here so the pair stays in step.
const ALL_HIRE_MODES_UNLOCKED := 2

func minigame_bonus_max() -> float:
	var per_level := _per_level(LegacyUpgradeCatalog.MINIGAME_BONUS)
	var level := get_level(LegacyUpgradeCatalog.MINIGAME_BONUS)
	return MINIGAME_BONUS_BASE + per_level * float(level)


## True once the Acquisitions Desk is owned, which is what makes the auto-purchase mode available
## to switch on at all (unowned = the AUTO-BUY button is absent entirely).
func auto_purchase_unlocked() -> bool:
	return get_level(LegacyUpgradeCatalog.AUTO_PURCHASE_UNLOCK) >= 1


## How many single-unit purchases the mode makes per round.
##
## The UNLOCK grants one on its own; Buying Power adds one per level. Returns 0 when the mode is
## not owned, so a caller that forgets to check auto_purchase_unlocked() still buys nothing rather
## than quietly running a free desk.
func auto_purchase_quantity() -> int:
	if not auto_purchase_unlocked():
		return 0
	return 1 + get_level(LegacyUpgradeCatalog.AUTO_PURCHASE_QUANTITY)


## SECONDS to shave off the auto-purchase cadence (Standing Orders). Returns 0.0 when the mode is
## not owned, so the unlock alone runs at the tuned base cadence.
##
## The caller subtracts this from the tuned base cadence and clamps to the tuned minimum — both
## knobs live in TuningConfig, so this getter reports the magnitude only. The track's 11 levels are
## sized to walk 3.0s down to that 0.25s floor exactly.
func auto_purchase_cadence_scale() -> float:
	if not auto_purchase_unlocked():
		return 0.0
	return _per_level(LegacyUpgradeCatalog.AUTO_PURCHASE_CADENCE) \
		* float(get_level(LegacyUpgradeCatalog.AUTO_PURCHASE_CADENCE))


## The deepest bulk-hire mode available. Now a CONSTANT: bulk hire is free for everyone since the
## Head Hunters track was deleted (2026-08-07). Pressing HIRE 150 times is a defect, not a feature,
## and charging gems to fix a defect is charging for a bug — the same call that made retention
## bulk-buy free.
##
## Kept as a function rather than inlined at the call sites so the ladder has one owner: if a mode
## is ever added to HireMode, this is the single place that has to learn about it.
##
## Returns a plain int rather than PropertyRow.HireMode.MAX on purpose. This is scripts/core/, and
## naming a UI class from here creates a class-resolution cycle that makes unrelated core members
## unresolvable and breaks parsing with errors pointing at innocent lines. The int contract is also
## what callers already used, back when this returned a purchased level.
func max_hire_mode() -> int:
	return ALL_HIRE_MODES_UNLOCKED


## Effective offline accrual cap in seconds (Night Shift), scaled from the base cap (14400 = 4h).
func offline_cap_seconds(base_cap: float = 14400.0) -> float:
	return base_cap + _per_level(LegacyUpgradeCatalog.EXTENDED_OFFLINE) \
		* float(get_level(LegacyUpgradeCatalog.EXTENDED_OFFLINE))


## How many unstaffed properties auto-restart their cycles (Shift Supervisors).
func auto_restart_count() -> int:
	return int(_per_level(LegacyUpgradeCatalog.AUTO_RESTART_CYCLES) \
		* float(get_level(LegacyUpgradeCatalog.AUTO_RESTART_CYCLES)))


## True if Hair Trigger is owned (enabling the auto-pop TURBO setting).
func auto_pop_turbo_unlocked() -> bool:
	return get_level(LegacyUpgradeCatalog.AUTO_POP_TURBO) >= 1


## Frenzy meter charge added per completed property cycle (Market Buzz).
func frenzy_cycle_charge_per_completion() -> float:
	return _per_level(LegacyUpgradeCatalog.FRENZY_CYCLE_CHARGE) \
		* float(get_level(LegacyUpgradeCatalog.FRENZY_CYCLE_CHARGE))


## Extra seconds of idle grace before frenzy decay begins (Market Momentum).
func frenzy_idle_grace_bonus() -> float:
	return _per_level(LegacyUpgradeCatalog.FRENZY_DECAY_RESIST) \
		* float(get_level(LegacyUpgradeCatalog.FRENZY_DECAY_RESIST))


## Multiplier on frenzy meter decay rate per second (Market Momentum): -8% per level down to min 0.20.
func frenzy_decay_rate_multiplier() -> float:
	var level := get_level(LegacyUpgradeCatalog.FRENZY_DECAY_RESIST)
	return maxf(1.0 - 0.08 * float(level), 0.20)


## Duration in seconds of the decaying afterburn tail after a frenzy burn ends (Residual Momentum).
func frenzy_afterburn_duration() -> float:
	return _per_level(LegacyUpgradeCatalog.FRENZY_AFTERBURN) \
		* float(get_level(LegacyUpgradeCatalog.FRENZY_AFTERBURN))


## Additional retained property income during a Market Crash (Hedging Strategies, 0.0 to 0.40).
func crash_income_retention_bonus() -> float:
	return _per_level(LegacyUpgradeCatalog.CRISIS_HEDGING) \
		* float(get_level(LegacyUpgradeCatalog.CRISIS_HEDGING))


## Percentage reduction in Market Crash duration (Emergency Liquidity, 0.0 to 0.48).
func crash_duration_reduction_pct() -> float:
	return _per_level(LegacyUpgradeCatalog.CRISIS_LIQUIDITY) \
		* float(get_level(LegacyUpgradeCatalog.CRISIS_LIQUIDITY))


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
