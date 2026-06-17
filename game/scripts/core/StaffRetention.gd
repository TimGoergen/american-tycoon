class_name StaffRetention

# The dynasty's "Loyal Household Staff" made concrete (GDD §6.3 / Plans/Epoch_Staffing_System.md §4.4).
#
# Staff normally RESET on prestige — a new founder starts unstaffed at the beginning
# of Earth. This class is the exception the player pays for: each property's staffer
# tier can be individually RETAINED across the reset, so the heir is born already
# staffed there. Retention is bought with Legacy (the prestige currency), one tier at
# a time, and a retained tier persists for the whole rest of the bloodline.
#
# Headless and scene-tree-free like the rest of the core, so the simulator and the
# Estate Office UI drive the exact same logic.

## Per-property retained staffer tier, keyed by property index (0–11). An absent key
## means tier 0 (nothing retained). When an heir is born, DynastyState sets each
## property's staff tier to the value stored here.
var retained_tiers: Dictionary = {}

# Cost model (first-pass — meant for on-device feel-tuning, not final balance).
# Legacy is a small-scale currency, so retention is cheap at the Earth tier and grows
# geometrically with the alien tier being preserved: keeping a tier-1 ATM staffer is a
# minor convenience, but willing an heir a tier-3 alien-tech staffer is a real Legacy
# investment. The geometric growth is what keeps deep retention a meaningful choice.
const BASE_COST := 3        # Legacy to retain a staffer at tier 1 (the Earth staffer)
const COST_GROWTH := 2.5    # each higher retained tier costs the previous × this


## The retained tier for a property (0 if nothing is retained there yet).
func get_retained_tier(property_index: int) -> int:
	return int(retained_tiers.get(property_index, 0))


## The tier a fresh retention purchase for this property would raise it to (current + 1).
func next_retention_tier(property_index: int) -> int:
	return get_retained_tier(property_index) + 1


## Legacy cost to retain a staffer AT a given tier (the geometric curve above).
## Tier 1 costs BASE_COST; each further tier multiplies by COST_GROWTH. Returns 0 for
## an invalid tier so callers never charge a bogus price.
func cost_for_tier(tier: int) -> int:
	if tier < 1:
		return 0
	return int(floor(float(BASE_COST) * pow(COST_GROWTH, float(tier - 1))))


## Record a property's retained tier directly (used by the buy path and on load).
func set_retained_tier(property_index: int, tier: int) -> void:
	if tier <= 0:
		retained_tiers.erase(property_index)
	else:
		retained_tiers[property_index] = tier


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	# Duplicated into a plain dict so the JSON is a clean {index: tier} map.
	return {"retained_tiers": retained_tiers.duplicate()}


func load_save_dict(data: Dictionary) -> void:
	retained_tiers = {}
	var saved: Dictionary = data.get("retained_tiers", {})
	# JSON object keys load back as strings; normalize them to int property indices so
	# lookups by integer index (the way the rest of the code keys properties) hit.
	for key in saved:
		retained_tiers[int(key)] = int(saved[key])
