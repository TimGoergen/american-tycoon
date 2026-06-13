class_name EconomyState

# The complete economy simulation state for one game run.
# Owns all 12 PropertyState instances and the player's cash balance.
# No scene-tree dependencies — safe to drive from the headless simulator.

## All 12 property states, indexed 0–11 matching GDD §4 order.
var properties: Array  # Array[PropertyState]

## Player cash in dollars (stored as float; use Money.of(cash).display() to format).
var cash: float = 0.0

## Accumulated income paid out this tick (reset each tick — used by callers to read delta).
var income_this_tick: float = 0.0

## Total income paid out since economy creation (for simulator graphs).
var total_income: float = 0.0

## Total simulated time elapsed in seconds.
var time_elapsed: float = 0.0

## Lifetime dollars spent buying property units this generation. Together with
## staff spend, this is the estate's "asset book value" — what the holdings are
## worth on the will (Spec §9.2). Resets naturally each generation because a new
## generation builds a fresh EconomyState.
var spent_on_units_this_gen: float = 0.0

## Lifetime dollars spent hiring staff this generation (the other half of book value).
var spent_on_staff_this_gen: float = 0.0


func _init(configs: Array, tuning: TuningConfig) -> void:
	properties = []
	for cfg in configs:
		properties.append(PropertyState.new(cfg as PropertyConfig, tuning))


# ---------------------------------------------------------------------------
# Simulation driver
# ---------------------------------------------------------------------------

## Advance all properties by `delta` seconds and credit income to cash.
## `income_multiplier` (frenzy, events) applies at point of payment (Spec §3.4).
func tick(delta: float, income_multiplier: float = 1.0) -> void:
	income_this_tick = 0.0
	for prop in properties:
		income_this_tick += (prop as PropertyState).tick(delta, income_multiplier)
	cash += income_this_tick
	total_income += income_this_tick
	time_elapsed += delta


# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------

## Try to buy `count` units of property at index `prop_index`.
## Returns true if the purchase succeeded; false if the player can't afford it.
func try_buy(prop_index: int, count: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	var cost := prop.get_bulk_cost(count)
	if cash < cost:
		return false
	cash -= cost
	spent_on_units_this_gen += cost
	prop.buy(count)
	return true


## Try to hire a staffer for the property at `prop_index`.
## Returns true on success; false if can't afford or already staffed.
func try_hire(prop_index: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	if prop.is_staffed:
		return false
	var cost := prop.get_staff_cost()
	if cash < cost:
		return false
	cash -= cost
	spent_on_staff_this_gen += cost
	prop.hire_staff()
	return true


## Layer 2 start verb: tap on an idle, unstaffed property.
func start_cycle(prop_index: int) -> void:
	(properties[prop_index] as PropertyState).start_cycle()


## Layer 2 rush verb: tap on a running cycle to advance it by RUSH_PCT.
func rush_cycle(prop_index: int) -> void:
	(properties[prop_index] as PropertyState).rush_cycle()


# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

## Sum of income/sec across all properties (staffed and running).
func get_total_income_per_sec() -> float:
	var total := 0.0
	for prop in properties:
		total += (prop as PropertyState).get_income_per_sec()
	return total


## Credit cash directly (for starting money, offline pile, events).
func award_cash(amount: float) -> void:
	cash += floor(amount)


## Estate "asset book value" — lifetime spent on units + staff this generation
## (Spec §9.2). A provisional valuation rule (TBD-SIM): holdings are worth what
## was paid for them, not a resale or income-multiple estimate.
func get_asset_book_value() -> float:
	return spent_on_units_this_gen + spent_on_staff_this_gen


## Net worth = liquid cash + book value of holdings. Drives the death waterfall's
## gross estate and the peak-net-worth the next heir must out-sprint (Spec §9.4).
## Provisional definition (TBD-SIM): equals estate_gross before debt/tax.
func get_net_worth() -> float:
	return cash + get_asset_book_value()
