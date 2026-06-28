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


## Cost to hire/upgrade the staffer at `prop_index` to `tier`.
##
## Tier 1 (the Earth staffer) keeps its small, property-scaled cost (band-1 curve × the
## Legacy discount). Tiers 2+ (alien staff) are instead anchored to the TARGET epoch's
## whole economy — earth_economy_target × that epoch's economy_scale — so they cost
## roughly economy_scale (×1000) more each epoch (Tim 2026-06-17). That way you cannot
## afford the next epoch's staff the instant you make contact; you must earn into the
## new economy first (and any cash saved by skipping a previous epoch's upgrades carries
## straight over, letting you afford some immediately). Rounded to match purchase prices.
func get_staff_cost(prop_index: int, tier: int) -> float:
	var prop := properties[prop_index] as PropertyState
	if tier <= 1:
		return prop.get_staff_cost()  # already includes the Legacy discount + rounding
	# Tuning lives on the PropertyState (EconomyState has no direct handle to it).
	var tuning := prop.tuning
	var epoch_economy := tuning.earth_economy_target * EpochCatalog.economy_scale(tier)
	var fraction := tuning.staff_cost_fraction \
			* pow(tuning.staff_cost_property_growth, float(prop_index))
	return CostCurve.round_nice(epoch_economy * fraction * prop.staff_cost_multiplier)


## Cost to buy the NEXT within-epoch staff level for a property (the per-epoch upgrade track,
## GDD §6.1). Anchored to the CURRENT tier's entry-hire cost so it inherits the same epoch +
## per-property scaling: the first level is a small fraction of that hire, then each level
## climbs geometrically (staff_level_cost_growth) so there is always a next one but never a
## free one. Returns 0 if the property is not staffed yet (you must hire before you can level).
func get_staff_level_cost(prop_index: int) -> float:
	var prop := properties[prop_index] as PropertyState
	if prop.staff_tier < 1:
		return 0.0
	var tuning := prop.tuning
	var entry_cost := get_staff_cost(prop_index, prop.staff_tier)
	var level_factor := tuning.staff_level_cost_base \
			* pow(tuning.staff_level_cost_growth, float(prop.staff_level))
	return CostCurve.round_nice(entry_cost * level_factor)


## Try to buy one within-epoch staff level for a property. Returns true on success; false if
## the property is unstaffed or the player can't afford the next level. Like a hire, the spend
## counts toward the generation's staff book value.
func try_upgrade_staff_level(prop_index: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	if prop.staff_tier < 1:
		return false
	var cost := get_staff_level_cost(prop_index)
	if cash < cost:
		return false
	cash -= cost
	spent_on_staff_this_gen += cost
	prop.add_staff_level()
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


## The THEORETICAL passive income/sec from current assets — the figure shown on the hero
## panel (Tim, 2026-06-24). For each STAFFED (auto-cycling) property it is the per-cycle
## payout — units × per-unit income × the staffer-tier multiplier × the permanent Legacy
## "Family Fortune" multiplier — divided by the effective cycle duration, summed across
## properties. That is exactly the image's `Σ (Base Payout × Multipliers) / Cycle Duration`.
##
## It is a pure function of the holdings, NOT a measurement of recent cash inflow, so it is
## rock-steady: it changes only when the player buys units, hires/upgrades staff, crosses a
## milestone, or a permanent multiplier changes — never from the lumpy timing of payouts.
## Unstaffed properties are excluded (they only pay when tapped, so they earn nothing
## passively), and the temporary frenzy/event multiplier is excluded so the headline reads
## the dependable rate rather than spiking during a burn.
func get_passive_income_per_sec() -> float:
	var total := 0.0
	for prop in properties:
		var p := prop as PropertyState
		# get_income_per_cycle already folds in the staff-tier and Family Fortune multipliers
		# the live tick pays on; dividing by the effective (sped-up) cycle length turns that
		# per-cycle payout into a per-second rate.
		if p.is_staffed:
			total += p.get_income_per_cycle() / p.get_effective_cycle_length()
	return total


## Index of the CHEAPEST property the player owns none of and cannot yet afford one
## unit of, or -1 if there is no such property. Drives the Main screen's ladder
## "peek": on top of every owned rung and every rung the player can already afford,
## exactly this one unaffordable rung is shown (grayed) so the player always sees the
## next thing to save toward — but nothing further. (Cost compared at the price of a
## single unit, matching what the buy button charges in ×1 mode.)
func get_cheapest_unaffordable_unowned_index() -> int:
	var best := -1
	var best_cost := INF
	for i in range(properties.size()):
		var p := properties[i] as PropertyState
		if p.units_owned > 0:
			continue
		var unit_cost := p.get_bulk_cost(1)
		if cash < unit_cost and unit_cost < best_cost:
			best_cost = unit_cost
			best = i
	return best


## Index of the HIGHEST property the player owns at least one unit of, or -1 if they own
## nothing. Higher index = pricier, later-tier property, so this is the player's top rung.
## Drives the portrait button's rush rule (GDD §6): once a property is automated (staffed)
## its rush is disabled — except this single top property, which always stays hands-on.
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
