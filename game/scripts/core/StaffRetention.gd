class_name StaffRetention

# The dynasty's "Loyal Household Staff" made concrete (GDD §6.3 / Plans/Epoch_Depth_Pass.md).
#
# Staff normally RESET on prestige — a new founder starts unstaffed at the beginning
# of Earth. This class is the exception the player pays for: each property's staff
# ladder can be retained across the reset, one COMPLETE 20-level BLOCK at a time, so
# the heir is born with that property's ladder already climbed that far. Retention is
# bought with Legacy (the prestige currency) and mirrors the ladder itself: blocks are
# retained in order, and each additional block costs more than the last (Tim,
# 2026-07-04 — "retention follows the same path as initial upgrading").
#
# Headless and scene-tree-free like the rest of the core, so the simulator and the
# Estate Office UI drive the exact same logic.

## Per-property retained BLOCK count, keyed by property index. An absent key means 0
## (nothing retained). Blocks are property-relative ordinals (block 1 = the property's
## home-epoch staffer), matching PropertyState's ladder. When an heir is born,
## DynastyState grants each property 20 ladder levels per retained block.
## The save key keeps its historical name ("retained_tiers") so pre-redesign dynasty
## saves load unchanged — an old retained TIER count maps 1:1 onto retained blocks.
var retained_blocks: Dictionary = {}

# Cost model (first-pass — meant for on-device feel-tuning, not final balance).
# Legacy is a small-scale currency, so retaining the first block is cheap and each
# further block grows geometrically: willing an heir a deep alien-tech roster is a
# real Legacy investment. The geometric growth is what keeps deep retention a
# meaningful choice — the same escalating-path shape as the dollar ladder itself.
const BASE_COST := 3        # Legacy to retain a property's first block
const COST_GROWTH := 2.5    # each additional retained block costs the previous × this


## The retained block count for a property (0 if nothing is retained there yet).
func get_retained_blocks(property_index: int) -> int:
	return int(retained_blocks.get(property_index, 0))


## The block a fresh retention purchase for this property would add (current + 1).
func next_retention_block(property_index: int) -> int:
	return get_retained_blocks(property_index) + 1


## Legacy cost to retain a property's Nth block (the geometric curve above).
## Block 1 costs BASE_COST; each further block multiplies by COST_GROWTH. Returns 0
## for an invalid block so callers never charge a bogus price.
func cost_for_block(block: int) -> int:
	if block < 1:
		return 0
	return int(floor(float(BASE_COST) * pow(COST_GROWTH, float(block - 1))))


## Record a property's retained block count directly (used by the buy path and on load).
func set_retained_blocks(property_index: int, blocks: int) -> void:
	if blocks <= 0:
		retained_blocks.erase(property_index)
	else:
		retained_blocks[property_index] = blocks


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	# Duplicated into a plain dict so the JSON is a clean {index: blocks} map. The key
	# keeps its pre-redesign name so old saves round-trip (tiers ≡ blocks, 1:1).
	return {"retained_tiers": retained_blocks.duplicate()}


func load_save_dict(data: Dictionary) -> void:
	retained_blocks = {}
	var saved: Dictionary = data.get("retained_tiers", {})
	# JSON object keys load back as strings; normalize them to int property indices so
	# lookups by integer index (the way the rest of the code keys properties) hit.
	for key in saved:
		retained_blocks[int(key)] = int(saved[key])
