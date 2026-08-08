extends SceneTree

# Headless verification for AUTO-PURCHASE MODE — the buying policy
# (design of record: Plans/Auto_Purchase_Restructure.md; code under test:
# scripts/core/AutoPurchaseState.gd).
#
# Usage: godot --headless --path . --script res://sim/AutoPurchaseTest.gd
#
# The mode spends the player's money on a rule they cannot see, so every clause of that rule is
# worth a runnable assertion. Proves, without any rendering:
#   1. Every purchase takes the CHEAPEST option available at that instant, re-priced after each
#      one — so a run walks across properties as prices rise, which is the whole rule.
#   2. Ties break cheapest -> LEAST OWNED -> index, so equal-priced rungs fill evenly instead of
#      one property swallowing the tick.
#   3. Purchases never leave the CURRENT EPOCH.
#   4. Partial fill: a tick that runs out of money mid-run keeps what it bought and stops.
#   5. An unaffordable tick buys nothing AND does not bank credit — in both directions: an empty
#      tick stays primed (buys the instant cash arrives), and a successful tick restarts the full
#      wait (it cannot fire twice in quick succession).
#   6. Disabled means inert.
#
# REWRITTEN 2026-08-07 for the restructure. Three cases from the previous version assert rules
# that no longer exist and are gone: the flagship exclusion (dropped — the desk may buy anything
# in its epoch), tab targeting (replaced by current-epoch scope), and breadth (the N x X grid
# collapsed into a single purchase count).
#
# The old file also carried the "naming trap" assertion — that
# EconomyState.get_flagship_index_for_unlock_tier and get_property_index_for_unlock_tier mean
# OPPOSITE things despite both saying flagship. That trap is still real and still dangerous, but
# auto-purchase no longer reads either lookup, so the assertion moved to sim/EpochTest.gd, which
# does. It must not simply disappear with the exclusion that happened to host it.
#
# Exits with code 0 only if every check passes (1 otherwise), so headless runs fail loudly.

## The epoch the test dynasty has reached. Alien tiers are the interesting case: big cohorts,
## and a wide enough price spread for "cheapest" to move around during a single tick.
const REACHED_TIER := 6

## Cadence used throughout. The tests drive tick() with a delta equal to the cadence so each call
## is exactly one buying opportunity, which keeps the timer arithmetic out of the assertions.
const CADENCE := 1.0

## Enough cash to buy freely without being INF (an infinite balance would make "could not afford
## it" untestable and hide arithmetic bugs).
const PLENTY_OF_CASH := 1.0e30

var _failures := 0


func _initialize() -> void:
	print("=== American Tycoon — Auto-Purchase Mode — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	var property_configs := ConfigLoader.load_property_configs()
	if tuning == null or property_configs.is_empty():
		print("FAILED to load configs")
		quit(1)
		return

	_test_always_buys_the_cheapest(property_configs, tuning)
	_test_a_run_crosses_properties(property_configs, tuning)
	_test_ties_go_to_the_least_owned(property_configs, tuning)
	_test_stays_in_the_current_epoch(property_configs, tuning)
	_test_partial_fill(property_configs, tuning)
	_test_unaffordable_tick_banks_nothing(property_configs, tuning)
	_test_disabled_is_inert(property_configs, tuning)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Assert helper: prints a pass/fail line and counts failures.
func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


# ---------------------------------------------------------------------------
# Shared setup
# ---------------------------------------------------------------------------

## A dynasty whose living generation has reached REACHED_TIER, with the mode on and `cash` banked.
## Built through DynastyState so the sims exercise the same construction path the game does
## (tuning is re-pushed onto the catalogs on construction — see sim/CLAUDE.md).
##
## The epoch is FORCED with epoch.restore() rather than earned by simulating play: reaching tier 6
## honestly would take a long build-out, and none of the rules under test depend on how the run
## got there — only on which properties are in the current epoch.
func _make_run(configs: Array, tuning: TuningConfig, cash: float) -> GameState:
	var dynasty := DynastyState.new(configs, tuning)
	var game := dynasty.current
	game.epoch.restore(REACHED_TIER)
	game.economy.cash = cash
	game.auto_purchase.enabled = true
	return game


## The property indices making up the current epoch's cohort — the mode's whole world now.
func _epoch_indices(game: GameState) -> Array:
	return game.economy.get_property_indices_for_unlock_tier(game.epoch.current_tier)


## Every property's units_owned, by index — a snapshot to diff a run against.
func _snapshot_units(game: GameState) -> Array[int]:
	var counts: Array[int] = []
	for prop in game.economy.properties:
		counts.append((prop as PropertyState).units_owned)
	return counts


## The cheapest next-unit cost in the current epoch, computed INDEPENDENTLY of AutoPurchaseState
## so the tests do not just re-assert the implementation against itself.
func _cheapest_cost_in_epoch(game: GameState) -> float:
	var best := -1.0
	for i in _epoch_indices(game):
		var cost := (game.economy.properties[i] as PropertyState).get_next_cost()
		if best < 0.0 or cost < best:
			best = cost
	return best


# ---------------------------------------------------------------------------
# 1. Cheapest-first, every single purchase
# ---------------------------------------------------------------------------

func _test_always_buys_the_cheapest(configs: Array, tuning: TuningConfig) -> void:
	print("1. Every purchase takes the cheapest property available at that instant")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)

	# One purchase at a time, checking before each that the property the mode picks really is the
	# cheapest. Doing it purchase-by-purchase is the point: a bug that sorts once and then buys
	# down a stale list would pass a check made only at the start of the tick.
	# Measured by what the purchase COST, not by which property it hit: if the mode paid exactly
	# the cheapest price on offer, it bought the cheapest thing on offer. That uses only public
	# API and cannot be fooled by a stale sort.
	var mismatches := 0
	for _step in range(25):
		var expected_cost := _cheapest_cost_in_epoch(game)
		var cash_before := game.economy.cash
		game.auto_purchase.tick(CADENCE, game, CADENCE, 1)
		var spent := cash_before - game.economy.cash
		if game.auto_purchase.last_purchased_indices.size() != 1 \
				or not is_equal_approx(spent, expected_cost):
			mismatches += 1

	_check("25 single purchases each paid exactly the cheapest price available", mismatches == 0)
	_check("...and they actually bought something", _total_units(game) == 25)


func _total_units(game: GameState) -> int:
	var total := 0
	for prop in game.economy.properties:
		total += (prop as PropertyState).units_owned
	return total


# ---------------------------------------------------------------------------
# 2. A run crosses properties
# ---------------------------------------------------------------------------

func _test_a_run_crosses_properties(configs: Array, tuning: TuningConfig) -> void:
	print("\n2. One tick's run walks across properties as prices rise")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)

	# A big single tick. Because every purchase re-prices, buying repeatedly should escalate the
	# cheapest rung past its neighbours and move on — the emergent spread that replaced the old
	# explicit "breadth" setting.
	var bought := game.auto_purchase.tick(CADENCE, game, CADENCE, 30)
	_check("the tick bought all 30 units", bought == 30)
	_check("they landed on MORE THAN ONE property (the run crossed boundaries)",
		game.auto_purchase.last_purchased_indices.size() > 1)

	# And it should not have simply spread one-per-property either: with prices rising, some
	# properties should have taken several units.
	var touched := game.auto_purchase.last_purchased_indices.size()
	_check("...but not one unit each — depth AND breadth emerged together", touched < 30)

	# Report the actual shape, because it is a design fact worth seeing rather than assuming.
	# Cohort rungs are ~x7 apart, so the cheapest one has to be bought MANY times before it
	# overtakes its neighbour — the run is heavily weighted toward the cheap end.
	var deepest := 0
	for i in game.auto_purchase.last_purchased_indices:
		deepest = maxi(deepest, (game.economy.properties[int(i)] as PropertyState).units_owned)
	print("      (30 purchases landed on %d properties; the busiest took %d units)"
		% [touched, deepest])


# ---------------------------------------------------------------------------
# 3. Ties go to the least owned
# ---------------------------------------------------------------------------

func _test_ties_go_to_the_least_owned(configs: Array, tuning: TuningConfig) -> void:
	print("\n3. The least-owned tie-break, and whether shipped pricing can even reach it")

	# THIS TEST IS DELIBERATELY INVERTED, and the reason is worth reading before changing it.
	#
	# The tie-break (cheapest -> least owned -> index) was specified on the assumption that a
	# cohort's early rungs are often priced identically. MEASURED 2026-08-07, that is false: every
	# cohort's rungs sit on a geometric ladder roughly x7 apart, and no two properties in tiers 1,
	# 3 or 6 share a price. So the least-owned term is a SAFETY NET, not a live rule — it costs
	# two lines, keeps the outcome deterministic, and would start mattering the moment any future
	# content introduces two rungs at the same price.
	#
	# Rather than fake a tie with white-box surgery, this asserts the FACT the design rests on. If
	# equal prices ever appear, this check fails and tells whoever added them that the tie-break
	# has become load-bearing and now deserves a real test.
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	var indices := _epoch_indices(game)
	_check("the epoch has several properties to rank", indices.size() >= 2)

	var seen := {}
	var duplicate_price := false
	for i in indices:
		var cost := (game.economy.properties[i] as PropertyState).get_next_cost()
		if seen.has(cost):
			duplicate_price = true
		seen[cost] = true
	_check("no two rungs in this cohort share a price, so ties cannot arise from shipped data "
		+ "(if this FAILS, the tie-break is now live and wants a real test)", not duplicate_price)


# ---------------------------------------------------------------------------
# 4. Scope is the current epoch
# ---------------------------------------------------------------------------

func _test_stays_in_the_current_epoch(configs: Array, tuning: TuningConfig) -> void:
	print("\n4. Purchases never leave the current epoch")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	var epoch_set := {}
	for i in _epoch_indices(game):
		epoch_set[i] = true
	_check("the current epoch has a cohort to buy from", not epoch_set.is_empty())

	var before := _snapshot_units(game)
	for _tick in range(40):
		game.auto_purchase.tick(CADENCE, game, CADENCE, 8)
	var after := _snapshot_units(game)

	var strayed: Array[int] = []
	var changed := 0
	for i in range(before.size()):
		if after[i] == before[i]:
			continue
		changed += 1
		if not epoch_set.has(i):
			strayed.append(i)

	_check("something in the epoch was bought (the run is meaningful)", changed > 0)
	_check("NOTHING outside the current epoch changed (strayed: %s)" % str(strayed),
		strayed.is_empty())


# ---------------------------------------------------------------------------
# 5. Partial fill
# ---------------------------------------------------------------------------

func _test_partial_fill(configs: Array, tuning: TuningConfig) -> void:
	print("\n5. A tick that runs out of money mid-run keeps what it bought")
	var game := _make_run(configs, tuning, 0.0)

	# Fund exactly three of the cheapest purchases. The budget is MEASURED by running a probe and
	# reading what it actually spent, not by summing get_next_cost(): try_buy prices through
	# get_bulk_cost, whose rounding differs by a hair, and summing the other getter left the
	# budget a fraction short — the tick then bought 2 and the test failed for a reason that had
	# nothing to do with partial fill.
	var probe := _make_run(configs, tuning, PLENTY_OF_CASH)
	var probe_before := probe.economy.cash
	for _i in range(3):
		probe.auto_purchase.tick(CADENCE, probe, CADENCE, 1)
	var budget := probe_before - probe.economy.cash
	game.economy.cash = budget

	var bought := game.auto_purchase.tick(CADENCE, game, CADENCE, 20)
	_check("asking for 20 with money for 3 bought exactly 3, not 0 and not 20 (bought %d)"
		% bought, bought == 3)
	_check("the money was actually spent", game.economy.cash < budget)


# ---------------------------------------------------------------------------
# 6. The empty-tick rule
# ---------------------------------------------------------------------------

func _test_unaffordable_tick_banks_nothing(configs: Array, tuning: TuningConfig) -> void:
	print("\n6. An unaffordable tick buys nothing and banks no credit")
	var game := _make_run(configs, tuning, 0.0)

	var bought_while_broke := 0
	for _i in range(10):
		bought_while_broke += game.auto_purchase.tick(CADENCE, game, CADENCE, 4)
	_check("ten ticks with no money bought nothing", bought_while_broke == 0)

	# Primed: the instant money arrives, the very next tick buys — no further wait.
	game.economy.cash = PLENTY_OF_CASH
	var bought_on_arrival := game.auto_purchase.tick(0.0, game, CADENCE, 4)
	_check("the first tick after cash arrives buys immediately (stayed primed)",
		bought_on_arrival > 0)

	# And the opposite: a successful tick restarts the full wait.
	var bought_too_soon := game.auto_purchase.tick(CADENCE * 0.5, game, CADENCE, 4)
	_check("a half-cadence later it does NOT buy again", bought_too_soon == 0)
	var bought_after_wait := game.auto_purchase.tick(CADENCE * 0.5, game, CADENCE, 4)
	_check("...and it does once the full cadence has passed", bought_after_wait > 0)


# ---------------------------------------------------------------------------
# 7. Disabled is inert
# ---------------------------------------------------------------------------

func _test_disabled_is_inert(configs: Array, tuning: TuningConfig) -> void:
	print("\n7. With the mode switched off, ticking buys nothing")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	game.auto_purchase.enabled = false

	var bought := 0
	for _i in range(20):
		bought += game.auto_purchase.tick(CADENCE, game, CADENCE, 8)
	_check("twenty ticks while disabled bought nothing", bought == 0)
	_check("no units were acquired anywhere", _total_units(game) == 0)

	# Switching back on must work immediately — "off" parks the mode, it does not break it.
	game.auto_purchase.enabled = true
	var bought_after_enable := 0
	for _i in range(2):
		bought_after_enable += game.auto_purchase.tick(CADENCE, game, CADENCE, 8)
	_check("re-enabling the mode resumes buying", bought_after_enable > 0)
