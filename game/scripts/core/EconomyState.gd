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

## Dollars this generation has EARNED over its life — property income plus wage
## taps plus the offline pile. Monotonic: it only ever rises, and spending never
## reduces it. This is the gross estate the death waterfall now taxes (Spec §9.1,
## GDD §8.3 decision 2026-06-14), and the obituary headline. Deliberately distinct
## from `cash`: granted money (loan principal, birth seed, windfalls) is NOT earned
## and must never be counted here, so it flows through award_cash() instead.
var cash_earned_this_gen: float = 0.0

## Total simulated time elapsed in seconds.
var time_elapsed: float = 0.0

## Lifetime dollars spent buying property units this generation. Together with
## staff spend, this is the estate's "asset book value" — what the holdings are
## worth on the will (Spec §9.2). Resets naturally each generation because a new
## generation builds a fresh EconomyState.
var spent_on_units_this_gen: float = 0.0

## Lifetime dollars spent hiring staff this generation (the other half of book value).
var spent_on_staff_this_gen: float = 0.0

## Cash this generation was seeded with at birth (starting capital + any Trust Fund
## bonus). Tracked so the estate→Legacy conversion can EXCLUDE granted seed money:
## you don't earn dynastic Legacy for cash you were simply handed, and early on the
## seed is far below even a single Legacy point (DynastyState.get_draft_will).
var starting_cash: float = 0.0


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
	# Property income is earned money, so it feeds the lifetime-earned accumulator
	# that the estate waterfall now grosses on (Spec §9.1).
	cash_earned_this_gen += income_this_tick
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


## Try to hire OR upgrade the staffer for the property at `prop_index`, advancing it
## one tier. `max_tier` is the highest tier currently unlocked (the generation's reached
## epoch — GameState passes EpochState.current_tier). Returns true on success; false if
## already at the highest unlocked/defined tier or the player can't afford the next one.
func try_hire(prop_index: int, max_tier: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	var next_tier := prop.staff_tier + 1
	if next_tier > max_tier or next_tier > EpochCatalog.tier_count():
		return false
	var cost := get_staff_cost(prop_index, next_tier)
	if cash < cost:
		return false
	cash -= cost
	spent_on_staff_this_gen += cost
	prop.set_staff_tier(next_tier, EpochCatalog.staff_income_multiplier(next_tier))
	return true


## Cost to hire/upgrade the staffer at `prop_index` to `tier`: the property's base hire
## cost (band-1 curve × the Legacy discount) scaled by that tier's alien-talent premium,
## rounded to a clean number to match purchase prices.
func get_staff_cost(prop_index: int, tier: int) -> float:
	var prop := properties[prop_index] as PropertyState
	var base_cost := prop.get_staff_cost()
	return CostCurve.round_nice(base_cost * EpochCatalog.hire_cost_multiplier(tier))


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


## Sum of income/sec from STAFFED properties only — the income the player keeps
## earning hands-off. Unstaffed cycles stop after one payout, so they are not
## guaranteed and do not count. Excludes frenzy/event multipliers, which are
## temporary; this is the dependable floor the headline stat never reads below.
func get_staffed_income_per_sec() -> float:
	var total := 0.0
	for prop in properties:
		var p := prop as PropertyState
		if p.is_staffed:
			total += p.get_income_per_sec()
	return total


## Highest property index the player owns at least one unit of, or -1 if they own
## none. Drives the Main screen's ladder: only owned rungs and the next rung up are
## shown, so the list grows as the player climbs instead of dumping all 12 at once.
func get_highest_owned_index() -> int:
	var highest := -1
	for i in range(properties.size()):
		if (properties[i] as PropertyState).units_owned > 0:
			highest = i
	return highest


## Credit GRANTED cash — money the player was handed, not earned: birth seed
## capital, Trust Fund bonus, loan principal, windfall gifts. Does NOT touch
## cash_earned_this_gen, so granted money can never inflate the estate or Legacy.
func award_cash(amount: float) -> void:
	cash += floor(amount)


## Credit EARNED cash — money the player worked for outside the property tick:
## wage taps (the offline pile is credited the same way). Feeds both the spendable
## balance and the lifetime-earned accumulator the estate waterfall grosses on.
func award_earned(amount: float) -> void:
	var credited := floorf(amount)
	cash += credited
	cash_earned_this_gen += credited


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
