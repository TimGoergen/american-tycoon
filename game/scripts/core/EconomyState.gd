class_name EconomyState

# The complete economy simulation state for one game run.
# Owns every PropertyState on the ladder and the player's cash balance.
# No scene-tree dependencies — safe to drive from the headless simulator.

## All property states, in ConfigLoader.PROPERTY_PATHS order (the save-stable property index).
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


## Each property's STAFF PRICE RANK, indexed by property index — the exponent all
## staff pricing grows by (see compute_staff_price_ranks). Computed once here at
## construction because the ladder never changes mid-run.
var _staff_price_ranks: Array[int] = []


func _init(configs: Array, tuning: TuningConfig) -> void:
	properties = []
	for cfg in configs:
		properties.append(PropertyState.new(cfg as PropertyConfig, tuning))
	_staff_price_ranks = compute_staff_price_ranks(configs)


## Compute each property's STAFF PRICE RANK from the configs (escalating ladder
## rework, Tim 2026-07-15). Staff pricing used to exponentiate the GLOBAL array
## index, which stopped meaning "how far up the ladder" once alien cohort siblings
## were APPENDED to the array for save compatibility instead of slotted by cost:
## epoch 2's second-cheapest property (appended around index 17) priced its staff
## above epoch 6's flagship (index 16), and the escalating ladder's 15 further
## appends would have detached the exponent completely. The rank restores a
## coherent price order without touching the save-stable array index:
##   • Earth properties (unlock_tier 1) keep their ladder index (0–11) — their
##     staff prices do not change at all.
##   • An alien property ranks earth_count + its COST RANK within its own epoch's
##     cohort (cheapest = 0). Every epoch's flagship therefore ranks 12 — exactly
##     the global index flagships had before, so flagship staff prices are also
##     unchanged — and its cohort's dearer rungs climb 13, 14, … within their own
##     epoch instead of across the whole array.
## Static so DynastyState can price Legacy staff retention off the identical rule
## without duplicating it (retention has the same disease for the same reason).
static func compute_staff_price_ranks(configs: Array) -> Array[int]:
	var ranks: Array[int] = []
	ranks.resize(configs.size())
	# Earth rungs: rank = position among Earth properties, which is their array
	# index today (Earth fills indices 0–11) and stays correct if that ever grows.
	var earth_count := 0
	for i in range(configs.size()):
		if (configs[i] as PropertyConfig).unlock_tier <= 1:
			ranks[i] = earth_count
			earth_count += 1
	# Alien rungs: gather each epoch's cohort, order it by base_cost, and rank each
	# member by that cost order — the cohort's ladder position, not its array slot.
	var cohort_indices_by_tier: Dictionary = {}  # unlock_tier -> Array of property indices
	for i in range(configs.size()):
		var tier := (configs[i] as PropertyConfig).unlock_tier
		if tier <= 1:
			continue
		if not cohort_indices_by_tier.has(tier):
			cohort_indices_by_tier[tier] = []
		(cohort_indices_by_tier[tier] as Array).append(i)
	for tier in cohort_indices_by_tier:
		var members: Array = cohort_indices_by_tier[tier]
		members.sort_custom(func(a: int, b: int) -> bool:
			return (configs[a] as PropertyConfig).base_cost < (configs[b] as PropertyConfig).base_cost)
		for cost_rank in range(members.size()):
			ranks[members[cost_rank]] = earth_count + cost_rank
	return ranks


## The staff price rank for one property — the exponent both the dollar staff-block
## anchors (below) and Legacy retention (StaffRetention) grow by.
func get_staff_price_rank(prop_index: int) -> int:
	return _staff_price_ranks[prop_index]


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

## Whether the player may buy into the property at `prop_index` yet. A property is locked
## until the run has reached its `unlock_tier` epoch (the 12 Earth properties are tier 1, so
## always unlocked); alien property types open only after First Contact with their race.
## `current_tier` is the generation's reached epoch (GameState passes EpochState.current_tier).
func is_property_unlocked(prop_index: int, current_tier: int) -> bool:
	var cfg := (properties[prop_index] as PropertyState).config as PropertyConfig
	return current_tier >= cfg.unlock_tier


## Try to buy `count` units of property at index `prop_index`. `current_tier` is the run's
## reached epoch — a property still locked behind a later epoch cannot be bought.
## Returns true if the purchase succeeded; false if locked or the player can't afford it.
func try_buy(prop_index: int, count: int, current_tier: int) -> bool:
	if not is_property_unlocked(prop_index, current_tier):
		return false
	var prop := properties[prop_index] as PropertyState
	var cost := prop.get_bulk_cost(count)
	if cash < cost:
		return false
	cash -= cost
	spent_on_units_this_gen += cost
	prop.buy(count)
	return true


## Index of the FLAGSHIP property that unlocks at `tier` — the first (cheapest) member
## of that epoch's cohort, which anchors the First Contact trade-deal minigame — or -1
## if no property is gated to that tier. Each alien epoch ships a multi-property
## cohort; PROPERTY_PATHS lists every flagship before any sibling, so "first match"
## is the flagship.
func get_property_index_for_unlock_tier(tier: int) -> int:
	var indices := get_property_indices_for_unlock_tier(tier)
	return indices[0] if not indices.is_empty() else -1


## Every property index gated to exactly `tier` — the epoch's whole COHORT
## (Epoch_Depth_Pass Phase 2). The First Contact bonus applies to all of them (Tim's
## call: the negotiated terms cover every venture in that civilization's market).
func get_property_indices_for_unlock_tier(tier: int) -> Array[int]:
	var indices: Array[int] = []
	for i in range(properties.size()):
		var cfg := (properties[i] as PropertyState).config as PropertyConfig
		if cfg.unlock_tier == tier:
			indices.append(i)
	return indices


# ---------------------------------------------------------------------------
# The staff ladder — costs and the single buy verb (GDD §6.1, epoch-depth redesign)
# ---------------------------------------------------------------------------
# One sequential ladder per property, in 20-level blocks; block 1 opens at the
# property's unlock epoch, each further block at the next epoch. Level 1 of a block
# is that epoch's staffer HIRE (priced at the block's full anchor); levels 2–20 are
# the cheap steps after it. A block's prices are constants of ITS epoch — never the
# player's current epoch — so a first contact can't silently reprice the button the
# player was saving toward (the 2026-07-03 transition bug). Block arithmetic lives
# on PropertyState (staff_block_of_level etc.); this file only prices and charges.

## The dollar anchor a block's costs hang off — the block's staffer-hire price.
## Block 1 (the property's home epoch): the modest property-scaled hire cost, exactly
## like today's first hire for Earth AND alien properties. Blocks 2+: anchored to the
## BLOCK's epoch economy — earth_economy_target × that epoch's economy_scale ×
## staff_cost_fraction, grown per STAFF PRICE RANK — so each epoch's staffer roster
## costs ~economy_scale more than the last, priced once and forever by its home epoch.
func get_staff_block_anchor(prop_index: int, block: int) -> float:
	var prop := properties[prop_index] as PropertyState
	if block <= 1:
		return prop.get_staff_cost()  # already includes the Legacy discount + rounding
	var tuning := prop.tuning
	var block_epoch := prop.staff_block_epoch(block)
	var epoch_economy := tuning.earth_economy_target * EpochCatalog.economy_scale(block_epoch)
	# Grown by the staff price rank, NOT the raw array index — appended alien
	# siblings sit out of cost order in the array (see compute_staff_price_ranks).
	var fraction := tuning.staff_cost_fraction \
			* pow(tuning.staff_cost_property_growth, float(get_staff_price_rank(prop_index)))
	return CostCurve.round_nice(epoch_economy * fraction * prop.staff_cost_multiplier)


## Cost of the NEXT ladder level (staff_level + 1) for a property. Level 1 of a block
## costs the block's full anchor (it is the staffer hire — the meaningful entry spend);
## each level after it costs anchor × staff_level_cost_base, climbing geometrically
## within the block. The climb restarts every block (an un-reset exponent would make a
## 120-level ladder unbuyable) off that block's own, permanently-fixed anchor.
func get_next_staff_level_cost(prop_index: int) -> float:
	var prop := properties[prop_index] as PropertyState
	var tuning := prop.tuning
	var next_level := prop.staff_level + 1
	var block := prop.staff_block_of_level(next_level)
	var anchor := get_staff_block_anchor(prop_index, block)
	# 1-based position of the level within its block (1 = the hire, 2–20 = the steps).
	var position := next_level - (block - 1) * tuning.staff_levels_per_epoch
	if position <= 1:
		return anchor
	var level_factor := tuning.staff_level_cost_base \
			* pow(tuning.staff_level_cost_growth, float(position - 2))
	return CostCurve.round_nice(anchor * level_factor)


## The hard cap on a property's staff_level: 20 × the blocks the run has opened for it
## (one per epoch from its unlock epoch to the reached epoch). The cap only ever rises,
## so levels skipped earlier stay buyable later — as the cheap next rung, since the
## ladder is strictly sequential.
func get_staff_level_cap(prop_index: int, reached_tier: int) -> int:
	var prop := properties[prop_index] as PropertyState
	return prop.tuning.staff_levels_per_epoch * prop.staff_blocks_available(reached_tier)


## True when a property has bought every staff level the reached epoch allows — the next
## block is gated behind the next first contact. Drives the "MAX" button and refuses the buy.
func is_staff_level_maxed(prop_index: int, reached_tier: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	return prop.staff_level >= get_staff_level_cap(prop_index, reached_tier)


## Buy the next staff-ladder level for a property — the ONLY staff purchase verb (hiring
## is simply level 1 of a block). Returns false at the reached-epoch cap or if the player
## can't afford it. Like the old hire, the spend counts toward the generation's staff
## book value. `reached_tier` comes from the run's EpochState so the cap tracks progress.
func try_buy_staff_level(prop_index: int, reached_tier: int) -> bool:
	var prop := properties[prop_index] as PropertyState
	if is_staff_level_maxed(prop_index, reached_tier):
		return false
	var cost := get_next_staff_level_cost(prop_index)
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
func rush_cycle(prop_index: int, income_multiplier: float = 1.0) -> void:
	credit_property_income((properties[prop_index] as PropertyState).rush_cycle(income_multiplier))


## Cumulative income that arrived via an off-tick RUSH payout (diagnostic only — the sim reads it
## to see what fraction of income comes from rushing vs the passive tick).
var rush_income_total: float = 0.0

## Credit income from an OFF-tick property payout (a rushed cycle that completed immediately),
## exactly the way tick() credits it — cash, total_income, and the lifetime-earned accumulator —
## so an instant rush payout is indistinguishable from one collected on a tick.
func credit_property_income(amount: float) -> void:
	if amount <= 0.0:
		return
	cash += amount
	total_income += amount
	cash_earned_this_gen += amount
	rush_income_total += amount


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
## single unit, matching what the buy button charges in ×1 mode.) `current_tier` is the
## run's reached epoch: a property still locked behind a later epoch is never the peek
## rung — it isn't yet a thing to save toward, so it stays hidden until First Contact.
func get_cheapest_unaffordable_unowned_index(current_tier: int) -> int:
	var best := -1
	var best_cost := INF
	for i in range(properties.size()):
		var p := properties[i] as PropertyState
		if p.units_owned > 0:
			continue
		if not is_property_unlocked(i, current_tier):
			continue
		var unit_cost := p.get_bulk_cost(1)
		if cash < unit_cost and unit_cost < best_cost:
			best_cost = unit_cost
			best = i
	return best


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
