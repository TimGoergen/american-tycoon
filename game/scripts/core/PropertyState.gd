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

## Which staffer tier is currently hired for this property (0 = none, 1 = Earth
## staffer, 2+ = an alien-tech staffer unlocked by a later epoch — see EpochCatalog).
## A higher tier replaces the previous staffer and raises staff_income_multiplier.
var staff_tier: int = 0

## Income multiplier granted by the current staffer tier (1.0 when unstaffed or at the
## Earth tier). Set by set_staff_tier from EpochCatalog; applied at point of payment in
## _collect, the same way the global frenzy/Legacy multiplier is, so alien staff are
## what scale a property's income into absurd ranges.
var staff_income_multiplier: float = 1.0

## Whether ANY staffer is hired, enabling auto-cycle forever. Read-only: derived from
## staff_tier so the many places that ask "is this staffed?" keep working unchanged
## while the tier is the real stored fact.
var is_staffed: bool:
	get:
		return staff_tier >= 1

## How far through the current cycle (in seconds, 0 → cycle_length).
var cycle_progress: float = 0.0

## True while a cycle is in progress.
var is_cycle_running: bool = false

## Dynasty-wide cycle-speed multiplier from the Legacy "Efficiency Experts"
## upgrade (1.0 = normal). The cycle's EFFECTIVE length is cycle_length divided
## by this, so a higher value means cycles finish sooner and income/sec rises.
## Set by DynastyState from the purchased upgrades; defaults to 1.0 so a bare
## single-generation run (or the M1 sim) is unaffected.
var cycle_speed_multiplier: float = 1.0

## Dynasty-wide staff-hiring-cost multiplier from the "Loyal Staff" upgrade
## (1.0 = full price, below 1.0 = a discount). Applied in get_staff_cost.
var staff_cost_multiplier: float = 1.0

## Dynasty-wide rush-strength multiplier from the Legacy "Strong-Arm Tactics" upgrade
## (1.0 = base). Scales how far one rush-tap advances the cycle. Set by DynastyState.
var rush_power_multiplier: float = 1.0

## Dynasty-wide auto-rush SPEED multiplier from the Legacy auto-click upgrade (1.0 =
## base). The held-rush pulse RATE in PropertyRow is multiplied by this. Set by DynastyState.
var auto_rush_speed_multiplier: float = 1.0

## Dynasty-wide property-income multiplier (the Legacy "Family Fortune" upgrade), mirrored
## here for DISPLAY only so the row's per-cycle figure reflects it (the live tick applies
## the same factor at point of payment via the global multiplier). Set by DynastyState.
var legacy_income_multiplier: float = 1.0

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


## Largest unit count purchasable with `available_cash` at exact-sum pricing
## (the MAX bulk-buy button). Capped so a degenerate config can't loop forever.
func get_max_affordable(available_cash: float, cap: int = 1000) -> int:
	var count := 0
	var remaining := available_cash
	var running_product := cost_product
	var owned := units_owned
	while count < cap:
		# Match the rounded price the player is actually charged (see CostCurve):
		# the running product BEFORE this unit's ratio, so unit #1 costs base_cost.
		var unit_cost := CostCurve.round_nice(config.base_cost * running_product)
		if remaining < unit_cost:
			break
		remaining -= unit_cost
		var band := CostCurve.get_band(owned + 1)
		running_product *= CostCurve.get_ratio(config.r0, band, tuning.band_step)
		owned += 1
		count += 1
	return count


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


## Hire or upgrade this property's staffer to `tier`, applying that tier's income
## multiplier (looked up by the caller from EpochCatalog). Caller must verify the tier
## is unlocked and affordable. Tier 1 is the Earth staffer (multiplier 1.0); higher
## tiers replace it with progressively larger alien-tech multipliers. Hiring at all
## starts the auto-cycle.
func set_staff_tier(tier: int, income_multiplier: float) -> void:
	staff_tier = tier
	staff_income_multiplier = income_multiplier
	if staff_tier >= 1 and not is_cycle_running:
		_start_cycle_internal()


## Set the Legacy cycle-speed multiplier and keep the in-flight cycle consistent.
## Because the effective cycle length shrinks as speed rises, an in-progress
## cycle could suddenly be "past the end"; we clamp progress so it simply
## completes on the next tick rather than overshooting.
func set_cycle_speed_multiplier(multiplier: float) -> void:
	cycle_speed_multiplier = maxf(0.01, multiplier)
	cycle_progress = minf(cycle_progress, _effective_cycle_length())


## The cycle length actually used for timing — the base length sped up by the
## Legacy "Efficiency Experts" upgrade. Everything that measures cycle time goes
## through here so the speed bonus applies uniformly (completion, rush, rate).
func _effective_cycle_length() -> float:
	return cycle_length / cycle_speed_multiplier


## Public accessor for the effective (sped-up) cycle length, so the UI can size its
## smooth cycle-progress bar against the SAME length the logic completes on. Without
## this the bar measured against the raw cycle_length and never fully filled once the
## Efficiency upgrade shortened the real cycle (Tim 2026-06-17).
func get_effective_cycle_length() -> float:
	return _effective_cycle_length()


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
	# The Legacy "Loyal Staff" upgrade discounts hiring (multiplier ≤ 1.0). Round the
	# final hire price to a clean number too, matching the property purchase costs.
	return CostCurve.round_nice(unit_20_cost * 50.0 * staff_cost_multiplier)


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

## Rebuild state from a save file. Only raw facts are restored (unit count,
## staffing, in-flight cycle); cost_product, cycle_length, income_per_unit,
## and the milestone count are recomputed by replaying the purchases, so
## derived values can never drift from the math that produced them.
func restore(
		p_units: int,
		p_staff_tier: int,
		p_staff_income_multiplier: float,
		p_cycle_progress: float,
		p_is_running: bool
) -> void:
	units_owned = 0
	cost_product = 1.0
	income_per_unit = config.base_income_per_unit
	cycle_length = config.base_cycle_length
	_milestones_crossed = 0
	staff_tier = 0
	staff_income_multiplier = 1.0

	if p_units > 0:
		buy(p_units)

	staff_tier = p_staff_tier
	staff_income_multiplier = p_staff_income_multiplier
	cycle_progress = clampf(p_cycle_progress, 0.0, _effective_cycle_length())
	is_cycle_running = (p_is_running or is_staffed) and units_owned > 0


# ---------------------------------------------------------------------------
# Simulation tick
# ---------------------------------------------------------------------------

## Advance the property by `delta` seconds. Returns income earned this tick.
## Staffed properties loop automatically; unstaffed stop after one cycle.
## `income_multiplier` (frenzy, events) applies at point of payment (Spec §3.4).
func tick(delta: float, income_multiplier: float = 1.0) -> float:
	if not is_cycle_running or units_owned == 0:
		return 0.0

	var income_earned := 0.0
	var remaining := delta
	var effective_length := _effective_cycle_length()

	# A single tick may complete multiple short cycles (e.g., ATM at 0.4 s).
	while remaining > 0.0 and is_cycle_running:
		var time_to_complete := effective_length - cycle_progress
		if remaining >= time_to_complete:
			# Cycle completes.
			remaining -= time_to_complete
			cycle_progress = 0.0
			income_earned += _collect(income_multiplier)

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
	var effective_length := _effective_cycle_length()
	# The Legacy "Strong-Arm Tactics" upgrade makes each rush advance the cycle further.
	var rush_fraction := tuning.rush_pct * rush_power_multiplier
	cycle_progress = minf(cycle_progress + rush_fraction * effective_length, effective_length)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Income per second contributed by this property at current units and cycle.
func get_income_per_sec() -> float:
	if units_owned == 0 or cycle_length <= 0.0:
		return 0.0
	# Use the effective (sped-up) length so the Efficiency upgrade shows up as a
	# higher income/sec, matching what the property actually pays over time. The staffer
	# tier's multiplier is included so alien staff visibly raise this property's rate.
	return floor(units_owned * income_per_unit * staff_income_multiplier) / _effective_cycle_length()


## Cash paid out each time a full cycle completes, before frenzy/event
## multipliers (those apply at point of payment in _collect). This is the number
## the property row displays — it's what the player actually receives when the
## progress bar fills, so the on-screen figure matches the cash they get.
func get_income_per_cycle() -> float:
	if units_owned == 0:
		return 0.0
	# Includes the staffer-tier multiplier AND the dynasty Family Fortune multiplier, so
	# the displayed figure tracks a Legacy income upgrade (which the live tick also applies
	# at payment). Frenzy/event multipliers still apply on top, at payment.
	return floor(units_owned * income_per_unit * staff_income_multiplier * legacy_income_multiplier)


## Cash a SINGLE unit of this property would pay per cycle right now (Family Fortune
## included). Shown grayed on a rung the player owns none of yet, so they can see what
## the next tier is worth before buying in (Tim 2026-06-17).
func get_single_unit_income_per_cycle() -> float:
	return floor(income_per_unit * staff_income_multiplier * legacy_income_multiplier)


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
## Multipliers apply here — at point of payment — then floor (Spec §1, §3.4).
func _collect(income_multiplier: float = 1.0) -> float:
	# staff_income_multiplier is this property's own alien-staffer tier bonus; the
	# passed-in income_multiplier is the global frenzy × Legacy factor. Both apply here,
	# at point of payment, then floor (Spec §1, §3.4).
	return floorf(units_owned * income_per_unit * staff_income_multiplier * income_multiplier)


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
