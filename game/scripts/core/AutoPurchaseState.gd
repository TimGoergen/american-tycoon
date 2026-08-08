class_name AutoPurchaseState

# Auto-Purchase Mode — the buying policy.
# Design of record: Plans/Auto_Purchase_Restructure.md (which supersedes the §A2-§A4 rule in
# Plans/Auto_Purchase_And_Bulk_Hire.md).
#
# While the mode is enabled, the game periodically spends cash on the player's behalf: every
# CADENCE seconds it makes up to QUANTITY purchases, and every one of those purchases takes
# whichever property in the CURRENT EPOCH is cheapest at that instant. That is the whole rule.
#
# THE RULE CHANGED ON 2026-08-07 (Tim). It used to be "N units each of the X cheapest
# properties", two numbers describing a grid. Tim removed the second idea outright:
#
#   "I do not want to have logic about how many different property types it may attempt to
#    purchase from. Rather, I just want the logic to be that it will purchase the x most
#    affordable properties ordered by cost, which may cross property type boundaries as the
#    prices rise from each subsequent purchase."
#
# So there is one number now — how many purchases this tick — and the spread across properties
# is EMERGENT rather than configured: buying a unit raises that property's next price, so a run
# of purchases naturally walks onto its neighbours as it goes. Re-pricing between every single
# purchase is what produces that, and it is the load-bearing detail of this file.
#
# This class is headless policy ONLY, exactly like the rest of scripts/core/: it holds no Node,
# touches no UI, and knows nothing about who is driving it. Main._process drives it for the real
# game and sim/ drives it for verification, so the two can never drift. It is deliberately NOT a
# Node: Main._process already returns early while a modal is up, so hanging the policy off that
# call site makes it inherit the frozen-economy rule for free. A self-ticking Node would not, and
# could quietly buy things behind the Will screen.


## True while the player has the mode switched on. Persisted by the caller alongside the other
## UI-mode flags; this object itself never touches the save file.
var enabled: bool = false

## True while the Acquisitions Desk is actually OWNED. Pushed in by the caller (Main) because the
## upgrade lives on the dynasty, which this headless model deliberately knows nothing about.
##
## THIS IS NOT REDUNDANT WITH `enabled`, and the pair being conflated was a real defect. `enabled`
## persists in the save, so a run could load with the mode switched on but the desk unowned — after
## a restructure that deleted the old track, or any future change to what grants it. The old
## `is_rush_locked_out_by_auto_purchase()` asked only about `enabled`, which meant that save
## REFUSED EVERY RUSH FOREVER while no auto-buying happened: the cost of the mode with none of the
## benefit, and nothing on screen to explain it. Both halves now go through is_running().
var unlocked: bool = false

## Seconds of tick time banked since the last purchase. Once this reaches the cadence the next
## tick fires. Clamped so it can never exceed one full cadence — see tick() for why.
var _time_since_last_purchase: float = 0.0

## The DISTINCT property indices bought into by the most recent buying tick — the UI reads this
## to mark the exact rows the desk just fed (Tim, 2026-08-01: he wanted to see WHERE the money
## went, rather than a headline flash that would strobe at this cadence).
##
## Distinct, not one entry per purchase: a tick now makes many single-unit buys and will often
## hit the same property repeatedly, and the reader wants rows to mark, not a purchase log.
##
## Deliberately a plain record rather than a signal: this class is headless policy with no scene
## tree, and the sims drive it too. Rewritten in place on every buying tick, so a reader must
## consume it right after tick() returns a non-zero count.
var last_purchased_indices: Array[int] = []


# ---------------------------------------------------------------------------
# The tick
# ---------------------------------------------------------------------------

## Advance the mode by `delta` seconds and buy if it is time to.
##
## `cadence`  — seconds between purchase ticks (shrinks as the cadence upgrade levels up).
## `quantity` — how many single-unit purchases to make this tick (the quantity upgrade).
##
## Returns the number of units actually bought this tick — 0 when the timer has not elapsed,
## and 0 when it has but nothing was affordable. The sims assert on this number.
## `tab`      — the civ tab currently on screen. Tab N is the cohort whose properties have
##              `unlock_tier == N + 1` (matching Main._epoch_tab_of). This is the desk's aim: the
##              player points it by paging the ladder.
func tick(delta: float, game: GameState, tab: int, cadence: float, quantity: int) -> int:
	if not is_running():
		return 0
	if game == null or cadence <= 0.0 or quantity <= 0:
		return 0

	_time_since_last_purchase += delta
	# Never bank more than one cadence of credit. Without this clamp, a long frame hitch or a
	# spell with no affordable property would let the accumulator run up and then release a burst
	# of back-to-back ticks. The mode is meant to be a steady drip, not a flush.
	if _time_since_last_purchase > cadence:
		_time_since_last_purchase = cadence
	if _time_since_last_purchase < cadence:
		return 0

	var units_bought := _buy_cheapest_repeatedly(game, tab, quantity)

	# EMPTY-TICK RULE. If we bought nothing, the accumulator stays pinned at the cadence instead
	# of resetting, so the very next frame in which something becomes affordable buys it
	# immediately. Otherwise a player who is one cent short when the timer fires would wait a
	# whole further cadence for no reason they can see. The wait only restarts once a purchase
	# actually happened.
	if units_bought > 0:
		_time_since_last_purchase -= cadence
	return units_bought


## True only when the mode is BOTH switched on and owned — i.e. when it is actually going to buy
## things. Everything that costs the player something for having the mode on (the rush lockout, and
## every rush visual the UI suppresses because of it) must ask THIS, never `enabled` alone.
func is_running() -> bool:
	return enabled and unlocked


## Clear the banked timer so a fresh run never inherits a primed accumulator from the last one
## (called on succession and on First Contact, alongside the other per-run resets).
##
## This deliberately does NOT touch `enabled`. The mode is unlocked by a Legacy upgrade, which
## survives succession by definition — switching the mode off every time the player prestiges
## would keep turning off something they paid for, which reads as a bug. It is a persistent
## player setting, like the buy mode, not per-generation state.
func reset_timer() -> void:
	_time_since_last_purchase = 0.0


# ---------------------------------------------------------------------------
# Queries for the UI
# ---------------------------------------------------------------------------

## The cheapest next-unit price in the current epoch, or -1.0 if there is nothing to buy.
## The UI uses this to tell the player what the desk is waiting to afford.
##
## Affordability is deliberately NOT part of this answer: the useful thing to show is the price
## the player is saving toward, which by definition is one they cannot pay yet.
## Scoped to the same tab the desk buys from, so Main's NOTHING TO BUY readout answers the question
## the player is actually asking: "why is nothing happening on the tab I am looking at?"
func lowest_next_cost(game: GameState, tab: int) -> float:
	if game == null:
		return -1.0
	var lowest := -1.0
	for i in _eligible_indices(game, tab):
		var cost := (game.economy.properties[i] as PropertyState).get_next_cost()
		if lowest < 0.0 or cost < lowest:
			lowest = cost
	return lowest


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Make up to `quantity` single-unit purchases, each taking whatever is cheapest at that moment.
## Returns the number of units actually bought.
func _buy_cheapest_repeatedly(game: GameState, tab: int, quantity: int) -> int:
	var eligible := _eligible_indices(game, tab)
	if eligible.is_empty():
		return 0

	var units_bought := 0
	last_purchased_indices.clear()
	for _purchase in range(quantity):
		var target := _cheapest_affordable(game, eligible)
		if target < 0:
			# Nothing on the tab is affordable any more. Everything this tick could buy has been
			# bought, so stop rather than spinning through the remaining quantity.
			break
		if not game.try_buy(target, 1):
			# Should not happen — _cheapest_affordable already checked the price — but a refusal
			# must end the tick rather than loop forever asking for something that is declined.
			break
		units_bought += 1
		# ONE unit at a time, deliberately. Buying a block would price the whole block up front
		# against the CURRENT cheapest property, which is exactly the behaviour Tim removed: the
		# run is supposed to re-price after every single purchase so it walks onto whichever
		# property has become the cheapest, crossing properties as it goes.
		if not last_purchased_indices.has(target):
			last_purchased_indices.append(target)
	return units_bought


## The index of the cheapest property the player can pay for right now, or -1 if none.
##
## Ties break cheapest -> LEAST OWNED -> lowest index (Tim, 2026-08-07).
##
## HONEST NOTE ON THE LEAST-OWNED TERM: it was specified on the assumption that a cohort's early
## rungs are often priced identically. Measured 2026-08-07, that is FALSE — every cohort sits on a
## geometric ladder roughly x7 apart and no two properties share a price, so this term never fires
## against shipped data. It is kept as a safety net: it costs two comparisons, keeps the outcome
## deterministic, and starts mattering the moment any future content puts two rungs at one price.
## sim/AutoPurchaseTest.gd asserts that no such pair exists, so if one ever appears the test fails
## and says so rather than letting an untested rule quietly go live.
##
## Index is the final term purely so the outcome is deterministic and the sims can assert exact
## sequences.
func _cheapest_affordable(game: GameState, eligible: Array[int]) -> int:
	var cash := game.economy.cash
	var best := -1
	var best_cost := 0.0
	var best_owned := 0
	for i in eligible:
		var prop := game.economy.properties[i] as PropertyState
		var cost := prop.get_next_cost()
		if cash < cost:
			continue
		var owned := prop.units_owned
		if best < 0 or cost < best_cost \
				or (cost == best_cost and owned < best_owned):
			best = i
			best_cost = cost
			best_owned = owned
	return best


## The single source of truth for "would this mode ever buy this property?". Both the buying path
## and lowest_next_cost() go through here so they can never disagree about what the desk targets.
##
## SCOPE IS THE TAB THE PLAYER IS LOOKING AT (Tim, 2026-08-07, clarifying an earlier answer):
## "Auto buy should always and only purchase properties on the currently visible tab."
##
## This briefly shipped as CURRENT EPOCH instead, and that was wrong in a way worth recording,
## because it looked like a broken feature rather than a mis-scoped one. Each epoch's entry rung
## costs about 16,807x the previous one's — that is `economy_scale` by design — so pinning the desk
## to the frontier meant it could afford nothing there for a long stretch after every First Contact,
## while the player sat looking at an era they had plenty of money for. The desk did nothing, said
## nothing, and read as broken.
##
## The tab is the control. Paging to an era IS how the player aims the desk, which is why the scope
## must follow what is on screen rather than where the run has reached.
##
## THERE IS NO FLAGSHIP EXCLUSION ANY MORE (Tim, 2026-08-07). The desk used to refuse the cohort's
## most expensive property, because owning 35 of it is the epoch-advance gate. That exclusion
## protected less than its comment claimed: `EpochState.auto_advance` is turned off in
## Main._create_game, so leaving an era is always the MAKE CONTACT tap and auto-buy could never
## have advanced an epoch by itself. Dropping it turns that gate from an ATTENTION gate into a
## MONEY gate — the player still chooses when to leave.
func _eligible_indices(game: GameState, tab: int) -> Array[int]:
	var eligible: Array[int] = []
	# Tab N shows the cohort gated to unlock_tier N + 1 (Main._epoch_tab_of).
	for i in game.economy.get_property_indices_for_unlock_tier(tab + 1):
		if not game.economy.is_property_unlocked(i, game.epoch.current_tier):
			continue
		eligible.append(i)
	return eligible
