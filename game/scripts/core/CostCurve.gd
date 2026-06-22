class_name CostCurve

# Pure math — all methods are static. Implements the piecewise band-ratio
# cost curve from Mechanics Spec §3.2. No state is stored here; callers
# (PropertyState) maintain the running cost_product.

# Milestone thresholds (Spec §3.1, AdVenture-Capitalist cadence adopted 2026-06-21):
# 25, 50, 100, 200, 300, 400 — then no more. Six fixed milestones, after which a
# property gets no further speed-up/income beat (it has "maxed out"). This both
# drives the milestone REWARD (PropertyState._apply_milestone_reward) and the cost
# curve's steepening band (get_ratio), so the cost ratio likewise caps at band 6.
const MILESTONE_THRESHOLDS: Array[int] = [25, 50, 100, 200, 300, 400]


## Return the milestone band for the unit at position `unit_index` (1-based).
## Band 0: units 1–24. Band 1: 25–49. Band 2: 50–99. … Band 6: 400+ (the cap).
static func get_band(unit_index: int) -> int:
	var band := 0
	for threshold in MILESTONE_THRESHOLDS:
		if unit_index >= threshold:
			band += 1
		else:
			break
	return band


## The next milestone count above `units_owned`, or 0 if the final milestone (400)
## has already been passed (no further milestones remain).
static func next_milestone_count(units_owned: int) -> int:
	for threshold in MILESTONE_THRESHOLDS:
		if threshold > units_owned:
			return threshold
	return 0


## The highest milestone count at or below `units_owned`, or 0 if none reached yet.
## Used as the lower bound of the per-property milestone progress slider.
static func last_milestone_count(units_owned: int) -> int:
	var last := 0
	for threshold in MILESTONE_THRESHOLDS:
		if threshold <= units_owned:
			last = threshold
		else:
			break
	return last


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
## cost_product is the running multiplier accumulated from all prior purchases
## (1.0 when nothing is owned yet), so base_cost is the literal sticker price of the
## very first unit; each unit's ratio is folded into cost_product only AFTER it is
## bought (see advance_cost_product). Formula: floor(base_cost × cost_product).
static func get_next_cost(
		base_cost: float,
		_r0: float,
		_band_step: float,
		cost_product: float,
		_units_owned: int
) -> float:
	return round_nice(base_cost * cost_product)


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
		# Price each unit at the running product BEFORE folding in its own ratio, so
		# the first unit (running_product == 1.0) costs exactly base_cost.
		total += round_nice(base_cost * running_product)
		var band := get_band(owned + 1)
		running_product *= get_ratio(r0, band, band_step)
		owned += 1
	return total


## How many more units to buy to reach the next milestone threshold.
## Returns 0 once the final milestone (400) has been passed — nothing left to reach.
static func units_to_next_milestone(units_owned: int) -> int:
	var next := next_milestone_count(units_owned)
	return next - units_owned if next > 0 else 0
