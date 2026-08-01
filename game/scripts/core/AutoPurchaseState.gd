class_name AutoPurchaseState

# Auto-Purchase Mode — the "Acquisitions Desk" buying policy.
# Design of record: Plans/Auto_Purchase_And_Bulk_Hire.md §A2-§A4.
#
# While the mode is enabled, the game periodically spends cash on the player's behalf:
# every CADENCE seconds it buys up to N units each of the X cheapest properties it can
# afford, on ONE targeted civ tab. That is the whole rule, and it is deliberately small —
# the player pays for it by giving up rush (§A5), so the mode has to stay legible.
#
# This class is headless policy ONLY, exactly like the rest of scripts/core/: it holds no
# Node, touches no UI, and knows nothing about who is driving it. Main._process drives it
# for the real game and sim/ drives it for verification, so the two can never drift.
# It is deliberately NOT a Node: Main._process already returns early while a modal is up,
# so hanging the policy off that call site makes it inherit the frozen-economy rule for
# free. A self-ticking Node would not, and could quietly buy things behind the Will screen.
#
# Three behaviours in here are load-bearing rather than incidental. Each is commented at
# the point it happens:
#   1. The cohort FLAGSHIP is excluded structurally (see _collect_eligible_indices).
#   2. Purchases are sized with get_max_affordable, never a flat N (see tick).
#   3. An empty tick does NOT burn the cadence (see tick).


## True while the player has the mode switched on. Persisted by the caller alongside the
## other UI-mode flags; this object itself never touches the save file.
var enabled: bool = false

## Seconds of tick time banked since the last purchase. Once this reaches the cadence the
## next tick fires. Clamped so it can never exceed one full cadence — see tick() for why.
var _time_since_last_purchase: float = 0.0


# ---------------------------------------------------------------------------
# The tick
# ---------------------------------------------------------------------------

## Advance the mode by `delta` seconds and buy if it is time to.
##
## `tab`      — the civ tab the player has the mode pointed at. Tab N is the cohort whose
##              properties have `unlock_tier == N + 1` (matching Main._epoch_tab_of).
## `cadence`  — seconds between purchase ticks (shrinks as the upgrade levels up).
## `units`    — N, the units to buy per property per tick (the upgrade level, 1..8).
## `breadth`  — X, how many DISTINCT properties to buy into per tick.
##
## Returns the number of UNITS actually bought this tick — 0 when the timer has not
## elapsed, and 0 when it has but nothing was affordable. The sims assert on this number.
func tick(delta: float, game: GameState, tab: int, cadence: float, units: int, breadth: int) -> int:
	if not enabled:
		return 0
	if game == null or cadence <= 0.0 or units <= 0 or breadth <= 0:
		return 0

	_time_since_last_purchase += delta
	# Never bank more than one cadence of credit. Without this clamp, a long frame hitch or
	# a spell with no affordable property would let the accumulator run up and then release
	# a burst of back-to-back ticks. The mode is meant to be a steady drip, not a flush.
	if _time_since_last_purchase > cadence:
		_time_since_last_purchase = cadence
	if _time_since_last_purchase < cadence:
		return 0

	var units_bought := _buy_cheapest(game, tab, units, breadth)

	# EMPTY-TICK RULE (plan §A3). If we bought nothing, the accumulator stays pinned at the
	# cadence instead of resetting, so the very next frame in which something becomes
	# affordable buys it immediately. Otherwise a player who is 1 cent short when the timer
	# fires would wait a whole further cadence for no reason the player can see.
	# The wait only restarts once a purchase actually happened.
	if units_bought > 0:
		_time_since_last_purchase -= cadence
	return units_bought


## Clear the banked timer so a fresh run never inherits a primed accumulator from the last
## one (called on succession and on First Contact, alongside the other per-run resets).
##
## This deliberately does NOT touch `enabled`. The mode is unlocked by a Legacy upgrade,
## which survives succession by definition — switching the mode off every time the player
## prestiges would keep turning off something they paid for, which reads as a bug. It is a
## persistent player setting, like the buy mode, not per-generation state.
func reset_timer() -> void:
	_time_since_last_purchase = 0.0


# ---------------------------------------------------------------------------
# Queries for the UI
# ---------------------------------------------------------------------------

## The cheapest next-unit price among the properties this mode is willing to buy on `tab`,
## or -1.0 if the tab has nothing it would ever touch (all locked, or flagship-only).
## The UI uses this to tell the player what the desk is waiting to afford.
##
## Affordability is deliberately NOT part of this answer: the useful thing to show is the
## price the player is saving toward, which by definition is one they cannot pay yet.
func lowest_next_cost(game: GameState, tab: int) -> float:
	if game == null:
		return -1.0
	var lowest := -1.0
	for i in _collect_eligible_indices(game, tab, false):
		var cost := (game.economy.properties[i] as PropertyState).get_next_cost()
		if lowest < 0.0 or cost < lowest:
			lowest = cost
	return lowest


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Rank this tab's buyable properties by CURRENT next-unit cost and buy into the cheapest
## `breadth` of them. Returns the total units bought.
func _buy_cheapest(game: GameState, tab: int, units: int, breadth: int) -> int:
	var candidates := _collect_eligible_indices(game, tab, true)
	if candidates.is_empty():
		return 0

	# Rank by the price RIGHT NOW, every tick, never cached. This is what makes the mode
	# self-balancing: hammering the cheapest rung escalates its own price until a sibling
	# becomes the cheapest, so the spending spreads across the low end instead of tunnelling
	# into one row. Caching the ranking would lose that for free (plan §A2).
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return (game.economy.properties[a] as PropertyState).get_next_cost() \
			< (game.economy.properties[b] as PropertyState).get_next_cost()
	)

	var units_bought := 0
	for rank in range(mini(breadth, candidates.size())):
		var prop_index: int = candidates[rank]
		var prop := game.economy.properties[prop_index] as PropertyState

		# Buy min(N, what we can actually pay for) rather than a flat N. GameState.try_buy is
		# all-or-nothing — it prices the whole block and refuses outright if cash falls short —
		# so asking for a flat N would make the mode do NOTHING whenever the player can afford
		# 5 of 8 units, which reads as a bug. get_max_affordable computes the honest number
		# using the same rounding as the cost curve (plan §A2).
		var affordable := prop.get_max_affordable(game.economy.cash, units)
		var count := mini(units, affordable)
		if count <= 0:
			# Cash ran out on an earlier property in this same tick. Everything after it in the
			# ranking is more expensive, so there is nothing left to find.
			break
		if game.try_buy(prop_index, count):
			# try_buy has already deducted the cost, so the next iteration's affordability
			# check reads the reduced balance. That re-check is why this is a loop and not a
			# batch: the cheapest property can legitimately consume the whole tick's budget.
			units_bought += count
	return units_bought


## The single source of truth for "would this mode ever buy this property?".
## Both tick() and lowest_next_cost() go through here so they can never disagree about
## what the desk is targeting.
##
## `require_affordable` adds the one filter that differs between the two callers: the buying
## path only wants properties it can pay for this instant, while the UI query wants the
## price of the thing being saved for.
func _collect_eligible_indices(game: GameState, tab: int, require_affordable: bool) -> Array[int]:
	# Tab N shows the cohort gated to unlock_tier N + 1 (Main._epoch_tab_of).
	var unlock_tier := tab + 1

	# EXCLUDE THE COHORT FLAGSHIP — structural, not incidental.
	# The epoch advance for tiers 3+ requires owning 35 units of the cohort flagship
	# (Plans/Epoch_Advance_Rework.md; enforced in EpochState). That stacking phase exists
	# precisely to give the flagship playtime, and it is the game's main pacing gate.
	# "The X cheapest" already misses the flagship while X stays small — but that is a
	# consequence of a tuning value, not a guarantee. Excluding it BY INDEX means a later
	# increase to breadth can never silently automate the pacing gate away.
	var flagship_index := game.economy.get_flagship_index_for_unlock_tier(unlock_tier)

	var eligible: Array[int] = []
	for i in game.economy.get_property_indices_for_unlock_tier(unlock_tier):
		if i == flagship_index:
			continue
		if not game.economy.is_property_unlocked(i, game.epoch.current_tier):
			continue
		if require_affordable:
			var prop := game.economy.properties[i] as PropertyState
			if game.economy.cash < prop.get_next_cost():
				continue
		eligible.append(i)
	return eligible
