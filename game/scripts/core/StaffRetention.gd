class_name StaffRetention

# The dynasty's "Loyal Household Staff" made concrete (GDD §6.3 / Plans/Epoch_Depth_Pass.md).
#
# Staff normally RESET on prestige — a new founder starts unstaffed at the beginning
# of Earth. This class is the exception the player pays for: each property's staff
# ladder can be retained across the reset ONE LEVEL AT A TIME, so the heir is born
# with that property's ladder already climbed that far. Retention is bought with
# Legacy (the prestige currency) and mirrors the ladder itself: levels are retained
# in order, and each additional level costs more Legacy than the last (Tim,
# 2026-07-04 — "retention follows the same path as initial upgrading", clarified to
# mean every individual upgrade step, not whole 20-level blocks).
#
# Headless and scene-tree-free like the rest of the core, so the simulator and the
# Estate Office UI drive the exact same logic.

## Per-property retained LADDER LEVEL count, keyed by property index. An absent key
## means 0 (nothing retained). Counts match PropertyState.staff_level (level 1 = the
## first hire). When an heir is born, DynastyState grants each property exactly this
## many ladder levels.
var retained_levels: Dictionary = {}

## Per-property HIGHEST ladder level any generation of the bloodline has ever reached,
## keyed by property index. This is what retention can be bought UP TO (Tim, 2026-07-04):
## the bloodline's achievement, not the (reset) living ladder — so after a prestige the
## Estate Office still offers every staffer and level ever earned. DynastyState records
## each life's ladder here at succession; during a life the live ladder counts too.
var ladder_highs: Dictionary = {}

# Cost model: base × property_step^property_index × growth^(level-1). Repriced
# 2026-07-07 (Tim's playtest): the old flat model (1 × 1.12^level, no property term)
# priced the ATM's staff like Executive Assets' and made deep retention near-free at a
# 350-gem prestige. Now protecting a top earner costs like a top earner, and each
# further level is a visible commitment. The three knobs live in TuningConfig
# (retention_*) so they are editable from the Balance Tuning screen; DynastyState
# copies them in via configure() — this class stays scene-free and tuning-free.
var base_cost := 1.0        # Legacy for the FIRST property's FIRST level
var cost_growth := 1.25     # each additional level costs the previous × this
var property_step := 1.5    # each higher property multiplies cost by this


## Copy the pricing knobs from tuning (called by DynastyState on construction and load).
func configure(p_base_cost: float, p_cost_growth: float, p_property_step: float) -> void:
	base_cost = p_base_cost
	cost_growth = p_cost_growth
	property_step = p_property_step


## The retained ladder-level count for a property (0 if nothing is retained yet).
func get_retained_levels(property_index: int) -> int:
	return int(retained_levels.get(property_index, 0))


## The ladder level a fresh retention purchase for this property would add (current + 1).
func next_retention_level(property_index: int) -> int:
	return get_retained_levels(property_index) + 1


## Legacy cost to retain a property's Nth ladder level (the two-term geometric curve
## above): the property term prices WHICH staff is being protected, the level term
## prices HOW DEEP. Rounded up so the price always rises by at least a whole point
## eventually. Returns 0 for an invalid level so callers never charge a bogus price.
func cost_for_level(property_index: int, level: int) -> int:
	if level < 1 or property_index < 0:
		return 0
	return int(ceil(
		base_cost
		* pow(property_step, float(property_index))
		* pow(cost_growth, float(level - 1))
	))


## Record a property's retained level count directly (used by the buy path and on load).
func set_retained_levels(property_index: int, levels: int) -> void:
	if levels <= 0:
		retained_levels.erase(property_index)
	else:
		retained_levels[property_index] = levels


## The highest ladder level the bloodline has ever reached on a property (0 = never staffed).
func get_ladder_high(property_index: int) -> int:
	return int(ladder_highs.get(property_index, 0))


## Record a life's ladder position; only ever raises the stored high (a later life that
## climbs less can never lower the bloodline's achievement).
func record_ladder_high(property_index: int, level: int) -> void:
	if level > get_ladder_high(property_index):
		ladder_highs[property_index] = level


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

## How many ladder levels one PRE-REDESIGN retained "tier" is worth on load. Old saves
## retained whole staffer tiers; a tier maps to a full block of the ladder.
const LEVELS_PER_LEGACY_TIER := 20


func to_save_dict() -> Dictionary:
	return {
		"retained_levels": retained_levels.duplicate(),
		"ladder_highs": ladder_highs.duplicate(),
	}


func load_save_dict(data: Dictionary) -> void:
	retained_levels = {}
	ladder_highs = {}
	# JSON object keys load back as strings; normalize them to int property indices so
	# lookups by integer index (the way the rest of the code keys properties) hit.
	var saved: Dictionary = data.get("retained_levels", {})
	for key in saved:
		retained_levels[int(key)] = int(saved[key])
	var highs: Dictionary = data.get("ladder_highs", {})
	for key in highs:
		ladder_highs[int(key)] = int(highs[key])
	# Pre-redesign saves stored whole retained TIERS under "retained_tiers"; each old
	# tier becomes a full block's worth of retained levels (a one-time migration).
	var legacy_tiers: Dictionary = data.get("retained_tiers", {})
	for key in legacy_tiers:
		retained_levels[int(key)] = int(legacy_tiers[key]) * LEVELS_PER_LEGACY_TIER
	# Whatever is retained was certainly reached — seed the highs so an older save's
	# retention options never shrink below its own purchases.
	for key in retained_levels:
		record_ladder_high(int(key), int(retained_levels[key]))
