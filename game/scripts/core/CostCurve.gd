class_name CostCurve

# Pure math — all methods are static. Implements the piecewise band-ratio
# cost curve from Mechanics Spec §3.2. No state is stored here; callers
# (PropertyState) maintain the running cost_product.

# Milestone thresholds: 20, 40, 80, 160, ... (Spec §3.1: 20 × 2^k).


## Return the milestone band for the unit at position `unit_index` (1-based).
## Band 0: units 1–19. Band 1: units 20–39. Band 2: units 40–79. Etc.
static func get_band(unit_index: int) -> int:
	# Counted with an integer threshold walk instead of log() — floating-point
	# log ratios mis-round exactly at the power-of-two thresholds (e.g. at 160
	# units, log(8)/log(2) evaluates to 2.9999999999999996 and truncates wrong).
	var band := 0
	var threshold := 20
	while unit_index >= threshold:
		band += 1
		threshold *= 2
	return band


## Per-unit ratio for band b: r0 × band_step^b.
static func get_ratio(r0: float, band: int, band_step: float) -> float:
	return r0 * pow(band_step, band)


## Snap a raw cost to the nearest $5 (Tim's call), so the player never sees odd
## prices like $53 or $57 — costs land on clean multiples of five ($55, $375, …).
## Only the per-unit cost a player actually pays is rounded; the geometric
## cost_product that drives the curve is kept raw (see advance_cost_product), so
## the curve still climbs smoothly underneath. Snapping a strictly-rising curve to
## a fixed grid stays non-decreasing, so bulk costs never go backwards.
static func round_nice(value: float) -> float:
	return snappedf(value, 5.0)


## Cost to buy the next unit when `units_owned` are already owned.
## cost_product is the running multiplier accumulated from all prior purchases.
## Formula: floor(base_cost × cost_product × ratio_for_next_unit)  [Spec §3.2]
static func get_next_cost(
		base_cost: float,
		r0: float,
		band_step: float,
		cost_product: float,
		units_owned: int
) -> float:
	var next_band := get_band(units_owned + 1)
	var ratio := get_ratio(r0, next_band, band_step)
	return round_nice(base_cost * cost_product * ratio)


## Return the updated cost_product after purchasing one unit.
## Call this when `units_owned` is the count BEFORE the purchase.
static func advance_cost_product(
		cost_product: float,
		r0: float,
		band_step: float,
		units_owned: int
) -> float:
	var next_band := get_band(units_owned + 1)
	var ratio := get_ratio(r0, next_band, band_step)
	return cost_product * ratio


## Exact sum of per-unit costs for buying `count` units starting from `units_owned`.
## Bulk-buy is priced as the sum of individual costs to kill the 2022 MAX double-count bug.
static func get_bulk_cost(
		base_cost: float,
		r0: float,
		band_step: float,
		cost_product: float,
		units_owned: int,
		count: int
) -> float:
	var total := 0.0
	var running_product := cost_product
	var owned := units_owned
	for _i in range(count):
		var band := get_band(owned + 1)
		var ratio := get_ratio(r0, band, band_step)
		total += round_nice(base_cost * running_product * ratio)
		running_product *= ratio
		owned += 1
	return total


## How many more units to buy to reach the next milestone threshold.
## Returns 0 if already exactly on a milestone (shouldn't happen in practice).
static func units_to_next_milestone(units_owned: int) -> int:
	# Thresholds: 20, 40, 80, 160, ...
	var threshold := 20
	while threshold <= units_owned:
		threshold *= 2
	return threshold - units_owned
