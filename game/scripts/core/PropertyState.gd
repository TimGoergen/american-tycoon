class_name PropertyState

# Mutable runtime state for one property type during a game run.
# No scene-tree dependencies — safe to instantiate and tick headlessly.

var config: PropertyConfig
var tuning: TuningConfig

## How many units of this property the player currently owns.
var units_owned: int = 0

## Income earned per completed cycle, per unit. Starts at config.base_income_per_unit;
## multiplied by 2 when a milestone is crossed and the cycle is already at CYCLE_FLOOR.
var income_per_unit: float = 0.0

## Current cycle duration in seconds. Starts at config.base_cycle_length;
## halved at each milestone until CYCLE_FLOOR, then income_per_unit doubles instead.
var cycle_length: float = 0.0

## Running product of all cost ratios applied so far (starts at 1.0).
## Maintained incrementally so cost lookups stay O(1).
var cost_product: float = 1.0

## Whether a staffer has been hired, enabling auto-cycle forever.
var is_staffed: bool = false

## How far through the current cycle (in seconds, 0 → cycle_length).
var cycle_progress: float = 0.0

## True while a cycle is in progress.
var is_cycle_running: bool = false

## How many milestone bands have been crossed. Used to know which reward fires next.
var _milestones_crossed: int = 0


func _init(p_config: PropertyConfig, p_tuning: TuningConfig) -> void:
	config = p_config
	tuning = p_tuning
	income_per_unit = config.base_income_per_unit
	cycle_length = config.base_cycle_length


# ---------------------------------------------------------------------------
# Cost queries
# ---------------------------------------------------------------------------

## Cost to buy one more unit (exact, floored).
func get_next_cost() -> float:
	return CostCurve.get_next_cost(
		config.base_cost, config.r0, tuning.band_step, cost_product, units_owned
	)


## Exact sum of per-unit costs for buying `count` more units.
func get_bulk_cost(count: int) -> float:
	return CostCurve.get_bulk_cost(
		config.base_cost, config.r0, tuning.band_step, cost_product, units_owned, count
	)


## Cost to buy enough units to reach the next milestone count.
func get_to_milestone_cost() -> float:
	var needed := CostCurve.units_to_next_milestone(units_owned)
	if needed <= 0:
		return 0.0
	return get_bulk_cost(needed)


# ---------------------------------------------------------------------------
# Purchases & staffing
# ---------------------------------------------------------------------------

## Purchase `count` units. Caller must verify affordability first.
func buy(count: int) -> void:
	for _i in range(count):
		cost_product = CostCurve.advance_cost_product(
			cost_product, config.r0, tuning.band_step, units_owned
		)
		units_owned += 1
		_check_milestone()

	# Staffed properties auto-start; make sure a cycle is running.
	if is_staffed and not is_cycle_running:
		_start_cycle_internal()


## Pay to hire a staffer for this property. Caller must verify affordability.
func hire_staff() -> void:
	is_staffed = true
	if not is_cycle_running:
		_start_cycle_internal()


## One-time hire cost: 50× the unit cost at band 1 (Spec §6).
## Computed fresh each call so it tracks the current cost curve.
func get_staff_cost() -> float:
	# Simulate the cost_product at the moment band 1 was first entered (unit 20).
	# For simplicity, compute band-1 ratio × base_cost × the product needed to
	# reach unit 20. We use CostCurve.get_bulk_cost from 0 owned to find that
	# point, then take the per-unit cost there × 50.
	# This is an approximation of Spec §6 "50× unit cost at band 1" that avoids
	# recomputing the full product curve from scratch.
	var band1_ratio := CostCurve.get_ratio(config.r0, 1, tuning.band_step)
	# Cost of the 20th unit (the first band-1 unit): base_cost × product-at-20
	# We get the running product at exactly 19 owned by running the accumulator.
	var prod := 1.0
	for i in range(19):
		var b := CostCurve.get_band(i + 1)
		prod *= CostCurve.get_ratio(config.r0, b, tuning.band_step)
	# floorf (not floor) — floor() returns Variant, which breaks := type inference.
	var unit_20_cost := floorf(config.base_cost * prod * band1_ratio)
	return unit_20_cost * 50.0


# ---------------------------------------------------------------------------
# Simulation tick
# ---------------------------------------------------------------------------

## Advance the property by `delta` seconds. Returns income earned this tick.
## Staffed properties loop automatically; unstaffed stop after one cycle.
func tick(delta: float) -> float:
	if not is_cycle_running or units_owned == 0:
		return 0.0

	var income_earned := 0.0
	var remaining := delta

	# A single tick may complete multiple short cycles (e.g., ATM at 0.4 s).
	while remaining > 0.0 and is_cycle_running:
		var time_to_complete := cycle_length - cycle_progress
		if remaining >= time_to_complete:
			# Cycle completes.
			remaining -= time_to_complete
			cycle_progress = 0.0
			income_earned += _collect()

			if is_staffed:
				_start_cycle_internal()  # auto-restart
			else:
				is_cycle_running = false  # manual: stop after one pay
		else:
			cycle_progress += remaining
			remaining = 0.0

	return income_earned


## Start verb (Layer 2): tap on an idle, unstaffed property starts its cycle.
func start_cycle() -> void:
	if not is_cycle_running and units_owned > 0:
		_start_cycle_internal()


## Rush verb (Layer 2): tap on a running cycle advances it by RUSH_PCT of cycle_length.
func rush_cycle() -> void:
	if not is_cycle_running:
		return
	cycle_progress = minf(cycle_progress + tuning.rush_pct * cycle_length, cycle_length)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Income per second contributed by this property at current units and cycle.
func get_income_per_sec() -> float:
	if units_owned == 0 or cycle_length <= 0.0:
		return 0.0
	return floor(units_owned * income_per_unit) / cycle_length


## Current milestone band (how many bands have been crossed).
func get_milestone_band() -> int:
	return CostCurve.get_band(max(units_owned, 1))


## The unit count at which the next milestone will be crossed.
func get_next_milestone_count() -> int:
	var threshold := 20
	while threshold <= units_owned:
		threshold *= 2
	return threshold


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _start_cycle_internal() -> void:
	is_cycle_running = true
	cycle_progress = 0.0


## Collect income at the end of a cycle and return the amount earned.
func _collect() -> float:
	return floor(units_owned * income_per_unit)


## Check whether a milestone has been crossed and apply the adaptive reward.
func _check_milestone() -> void:
	# Milestones at 20 × 2^k. After each purchase, see if units_owned crossed one.
	var expected_milestones := CostCurve.get_band(max(units_owned, 1))
	while _milestones_crossed < expected_milestones:
		_apply_milestone_reward()
		_milestones_crossed += 1


## Adaptive milestone reward (Spec §3.3):
## - If halving cycle_length keeps it at or above CYCLE_FLOOR → halve it.
## - Otherwise → double income_per_unit.
func _apply_milestone_reward() -> void:
	if cycle_length / 2.0 >= tuning.cycle_floor:
		cycle_length /= 2.0
	else:
		income_per_unit *= 2.0
