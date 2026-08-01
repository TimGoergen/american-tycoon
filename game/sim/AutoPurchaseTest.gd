extends SceneTree

# Headless verification for AUTO-PURCHASE MODE — the "Acquisitions Desk" buying policy
# (design of record: Plans/Auto_Purchase_And_Bulk_Hire.md §A2-§A3; code under test:
# scripts/core/AutoPurchaseState.gd).
#
# Usage: godot --headless --path . --script res://sim/AutoPurchaseTest.gd
#
# The mode spends the player's money on a rule they cannot see, so every clause of that rule
# is worth a runnable assertion. Proves, without any rendering:
#   1. The cohort FLAGSHIP is never bought — the epoch-advance pacing gate cannot be
#      automated away. Plus the naming trap that makes this easy to get wrong (see below).
#   2. Purchases stay on the TARGETED tab, even when it is not the deepest one unlocked.
#   3. An unaffordable tick buys nothing AND does not bank credit — in both directions:
#      an empty tick stays primed (buys the instant cash arrives), and a successful tick
#      restarts the full wait (it cannot fire twice in quick succession).
#   4. PARTIAL FILL: min(N, get_max_affordable) — the mode buys 5 of 8 rather than nothing.
#   5. Disabled means inert.
#
# THE NAMING TRAP, recorded here in runnable form because a comment alone did not hold:
# EconomyState has two lookups whose names both say "flagship" and they mean OPPOSITE things.
#   - get_flagship_index_for_unlock_tier(tier) → the cohort's MOST EXPENSIVE property. This is
#     the one the 35-unit epoch-advance gate reads (GameState._owns_all_in_epoch), and so it is
#     the one auto-purchase must never buy.
#   - get_property_index_for_unlock_tier(tier)  → the cohort's CHEAPEST member, the First
#     Contact trade-deal anchor. (EpochTest confusingly calls this one "flagship" too.)
# Test 1 asserts the two differ for an alien tier, so a future rename or merge of the pair
# breaks a test instead of silently un-gating the pacing.
#
# Exits with code 0 only if every check passes (1 otherwise), so headless runs fail loudly.

## The civ tab the tests aim the mode at. Tab N is the cohort gated to unlock_tier N + 1
## (Main._epoch_tab_of), so tab 2 = tier 3 = Luminari, the FIRST alien cohort. Alien is the
## interesting case: it is where the 35-unit flagship gate applies and where a cohort is big
## enough for "cheapest" and "most expensive" to be different properties.
const TARGET_TAB := 2
const TARGET_TIER := TARGET_TAB + 1

## The epoch the test dynasty has actually reached. Deliberately DEEPER than the targeted tab
## so that a bug which ignores the `tab` argument (and buys the frontier, or everything) shows
## up as an off-tab purchase instead of passing by coincidence.
const REACHED_TIER := 6

## The Acquisitions Desk level the tests model. Level 8 is the top of the track: the fastest
## cadence and the largest N, i.e. the most stressful setting for every rule under test.
const DESK_LEVEL := 8

## Enough cash to buy anything on an alien-tier-3 tab many times over, without being INF
## (an infinite balance would make "could not afford it" untestable and hide arithmetic bugs).
const PLENTY_OF_CASH := 1.0e30

var _failures := 0

## Cadence and N for DESK_LEVEL, filled in from tuning + the catalog by _initialize so the
## harness measures the SAME numbers Main._drive_auto_purchase feeds the mode.
var _cadence := 0.0
var _units := 0
var _breadth := 0


func _initialize() -> void:
	print("=== Auto-Purchase Mode — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	var property_configs := ConfigLoader.load_property_configs()
	if tuning == null or property_configs.is_empty():
		print("FAILED to load configs")
		quit(1)
		return

	# Mirror Main._drive_auto_purchase exactly (Main.gd:2727-2735): cadence is the tuned base
	# less the upgrade's accumulated shave, clamped to the tuned floor; N is simply the level.
	var per_level := float(LegacyUpgradeCatalog.get_definition(
		LegacyUpgradeCatalog.ACQUISITIONS_DESK)["effect_per_level"])
	_cadence = clampf(
		tuning.auto_purchase_base_cadence - per_level * float(DESK_LEVEL - 1),
		tuning.auto_purchase_min_cadence, tuning.auto_purchase_base_cadence)
	_units = DESK_LEVEL
	_breadth = tuning.auto_purchase_breadth
	print("  (level %d desk: cadence %.2fs, N %d units, X %d properties)\n"
		% [DESK_LEVEL, _cadence, _units, _breadth])

	_test_flagship_is_never_bought(property_configs, tuning)
	_test_purchases_stay_on_target_tab(property_configs, tuning)
	_test_unaffordable_tick_banks_nothing(property_configs, tuning)
	_test_partial_fill(property_configs, tuning)
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

## A dynasty whose living generation has reached REACHED_TIER, with the mode switched on and
## `cash` in the bank. Built through DynastyState so the sims exercise the same construction
## path the game does (tuning is re-pushed onto the catalogs on construction — see sim/CLAUDE.md).
##
## The epoch is FORCED with epoch.restore() rather than earned by simulating play: reaching
## tier 6 honestly would take a long build-out, and none of the rules under test depend on how
## the run got there — only on which properties are unlocked.
func _make_run(configs: Array, tuning: TuningConfig, cash: float) -> GameState:
	var dynasty := DynastyState.new(configs, tuning)
	var game := dynasty.current
	game.epoch.restore(REACHED_TIER)
	game.economy.cash = cash
	game.auto_purchase.enabled = true
	return game


## Total units owned across the WHOLE ladder — the coarse "did anything at all get bought"
## measure the inert / unaffordable tests assert on.
func _total_units(game: GameState) -> int:
	var total := 0
	for prop in game.economy.properties:
		total += (prop as PropertyState).units_owned
	return total


## Every property's units_owned, by index — a snapshot to diff a run against.
func _snapshot_units(game: GameState) -> Array[int]:
	var counts: Array[int] = []
	for prop in game.economy.properties:
		counts.append((prop as PropertyState).units_owned)
	return counts


## The cheapest property the mode is allowed to buy on `tab`, computed INDEPENDENTLY of
## AutoPurchaseState (cohort minus flagship, ranked by current next-unit cost) so the tests
## do not just re-assert the implementation against itself. -1 if the tab has no such property.
func _cheapest_non_flagship_index(game: GameState, tab: int) -> int:
	var tier := tab + 1
	var flagship := game.economy.get_flagship_index_for_unlock_tier(tier)
	var best := -1
	var best_cost := 0.0
	for i in game.economy.get_property_indices_for_unlock_tier(tier):
		if i == flagship:
			continue
		var cost := (game.economy.properties[i] as PropertyState).get_next_cost()
		if best < 0 or cost < best_cost:
			best = i
			best_cost = cost
	return best


# ---------------------------------------------------------------------------
# 1. The flagship is never bought
# ---------------------------------------------------------------------------

## The pacing gate: advancing past an alien epoch requires owning `epoch_flagship_units_required`
## units of that cohort's MOST EXPENSIVE property. Auto-purchase excludes it by index, so no
## future increase to breadth (X) can quietly buy that gate down.
func _test_flagship_is_never_bought(configs: Array, tuning: TuningConfig) -> void:
	print("1. The cohort flagship is never bought, however long the mode runs")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)

	# The naming trap, asserted rather than merely commented (see the header note).
	var gate_flagship := game.economy.get_flagship_index_for_unlock_tier(TARGET_TIER)
	var trade_deal_anchor := game.economy.get_property_index_for_unlock_tier(TARGET_TIER)
	_check("tier %d has a flagship and a trade-deal anchor" % TARGET_TIER,
		gate_flagship >= 0 and trade_deal_anchor >= 0)
	_check("get_flagship_index_for_unlock_tier != get_property_index_for_unlock_tier "
			+ "(most expensive vs cheapest — the two are NOT synonyms)",
		gate_flagship != trade_deal_anchor)
	var flagship_cost := ((game.economy.properties[gate_flagship] as PropertyState).config \
		as PropertyConfig).base_cost
	var anchor_cost := ((game.economy.properties[trade_deal_anchor] as PropertyState).config \
		as PropertyConfig).base_cost
	_check("the gate flagship is the cohort's MOST expensive member", flagship_cost > anchor_cost)
	# GameState.get_flagship_index is what the epoch-progress UI reads; it must agree with the
	# lookup auto-purchase excludes, or the mode and the gate would be talking about different rows.
	_check("GameState.get_flagship_index agrees with the excluded index",
		game.get_flagship_index(TARGET_TIER) == gate_flagship)

	var flagship_prop := game.economy.properties[gate_flagship] as PropertyState
	var flagship_units_before := flagship_prop.units_owned
	var stayed_untouched := true
	var total_bought := 0
	# 200 ticks at the top desk level is far more buying than the 14-property cohort needs to
	# saturate the cheap rungs, so if the flagship were ever reachable it would be reached here.
	for _i in range(200):
		total_bought += game.auto_purchase.tick(
			_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
		if flagship_prop.units_owned != flagship_units_before:
			stayed_untouched = false
			break
	_check("the mode bought plenty over 200 ticks (so the run is meaningful)", total_bought > 0)
	_check("the flagship's units_owned never changed", stayed_untouched)
	_check("the flagship still owns nothing after the run", flagship_prop.units_owned == 0)

	# THE ASSERTION THAT ACTUALLY BITES. At the shipped X of 3, "the 3 cheapest" would miss the
	# flagship anyway — so the run above would pass even with the exclusion deleted, and would
	# prove nothing about the exclusion being STRUCTURAL. This second run sets breadth to the
	# WHOLE cohort, which is precisely the "someone raised X later" scenario the plan says the
	# by-index exclusion exists to survive. Delete the exclusion and only this check fails.
	var cohort_size := game.economy.get_property_indices_for_unlock_tier(TARGET_TIER).size()
	var wide := _make_run(configs, tuning, PLENTY_OF_CASH)
	var wide_flagship := wide.economy.properties[gate_flagship] as PropertyState
	for _i in range(50):
		wide.auto_purchase.tick(_cadence, wide, TARGET_TAB, _cadence, _units, cohort_size)
	_check("with breadth widened to the whole %d-property cohort, the mode still bought"
		% cohort_size, _total_units(wide) > 0)
	_check("...and the flagship is STILL untouched (the exclusion is by index, not by ranking)",
		wide_flagship.units_owned == 0)


# ---------------------------------------------------------------------------
# 2. Purchases stay on the targeted tab
# ---------------------------------------------------------------------------

## The mode is a control the player aims at ONE era. Anything it buys elsewhere is money spent
## somewhere the player did not point it — the most player-visible way this feature can break.
func _test_purchases_stay_on_target_tab(configs: Array, tuning: TuningConfig) -> void:
	print("\n2. Every purchase lands on the targeted tab, not the deepest unlocked one")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	_check("the run has reached tier %d, DEEPER than the targeted tier %d "
			% [REACHED_TIER, TARGET_TIER] + "(so ignoring the tab argument would show up)",
		game.epoch.current_tier > TARGET_TIER)

	var before := _snapshot_units(game)
	for _i in range(100):
		game.auto_purchase.tick(_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
	var after := _snapshot_units(game)

	var changed_indices: Array[int] = []
	var off_tab_indices: Array[int] = []
	for i in range(after.size()):
		if after[i] == before[i]:
			continue
		changed_indices.append(i)
		var cfg := (game.economy.properties[i] as PropertyState).config as PropertyConfig
		if cfg.unlock_tier != TARGET_TIER:
			off_tab_indices.append(i)
	_check("something on the tab was actually bought", not changed_indices.is_empty())
	_check("no property outside tier %d changed (off-tab: %s)" % [TARGET_TIER, off_tab_indices],
		off_tab_indices.is_empty())
	# Breadth is X DISTINCT properties per tick, and re-ranking every tick spreads the spend
	# across the low end — so a long run should touch MORE than X rows, never fewer.
	_check("re-ranking spread the spend across at least X (%d) rows" % _breadth,
		changed_indices.size() >= _breadth)


# ---------------------------------------------------------------------------
# 3. Empty ticks buy nothing and bank nothing
# ---------------------------------------------------------------------------

## Two rules pull in opposite directions and both have to hold:
##   - an EMPTY tick keeps the accumulator pinned at the cadence, so the desk fires the instant
##     something becomes affordable rather than making the player wait out another whole cycle;
##   - a SUCCESSFUL tick restarts the wait, so the mode is a steady drip and can never release
##     a burst of back-to-back purchases.
func _test_unaffordable_tick_banks_nothing(configs: Array, tuning: TuningConfig) -> void:
	print("\n3. An unaffordable tick buys nothing and banks no credit (both directions)")
	var game := _make_run(configs, tuning, 0.0)

	var cheapest_index := _cheapest_non_flagship_index(game, TARGET_TAB)
	_check("the targeted tab offers a non-flagship property to buy", cheapest_index >= 0)
	if cheapest_index < 0:
		return
	var cheapest := game.economy.properties[cheapest_index] as PropertyState
	_check("the mode reports the same cheapest price the test computed",
		is_equal_approx(game.auto_purchase.lowest_next_cost(game, TARGET_TAB),
			cheapest.get_next_cost()))

	# Broke: ten full cadences must buy nothing at all.
	var bought_while_broke := 0
	for _i in range(10):
		bought_while_broke += game.auto_purchase.tick(
			_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("ten ticks with no cash bought nothing", bought_while_broke == 0)
	_check("no units were acquired anywhere", _total_units(game) == 0)

	# Exactly one unit's worth of cash arrives. Because the empty ticks left the accumulator
	# pinned at the cadence, the very next tick — however small its delta — must buy.
	game.economy.cash = cheapest.get_next_cost()
	var bought_on_arrival := game.auto_purchase.tick(
		0.01, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("the next tick after cash arrives buys immediately (empty ticks stayed primed)",
		bought_on_arrival > 0)
	_check("it bought exactly the one unit the cash covered", bought_on_arrival == 1)

	# The opposite direction: having just bought, the desk owes a FULL cadence of waiting
	# before it may buy again, even with money to burn.
	game.economy.cash = PLENTY_OF_CASH
	var bought_too_soon := game.auto_purchase.tick(
		_cadence * 0.5, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("half a cadence after a purchase, the desk buys nothing", bought_too_soon == 0)
	var bought_after_wait := game.auto_purchase.tick(
		_cadence * 0.5, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("once the full cadence has elapsed it buys again", bought_after_wait > 0)


# ---------------------------------------------------------------------------
# 4. Partial fill
# ---------------------------------------------------------------------------

## GameState.try_buy is all-or-nothing, so asking for a flat N would make the mode do NOTHING
## whenever the player can afford 5 of 8 units — which reads as broken. The rule is
## min(N, get_max_affordable), and this test is the one that fails if it regresses to a flat N.
func _test_partial_fill(configs: Array, tuning: TuningConfig) -> void:
	print("\n4. Partial fill: the desk buys what it can afford, not all-or-nothing")
	var game := _make_run(configs, tuning, 0.0)

	var cheapest_index := _cheapest_non_flagship_index(game, TARGET_TAB)
	if cheapest_index < 0:
		_check("the targeted tab offers a non-flagship property to buy", false)
		return
	var cheapest := game.economy.properties[cheapest_index] as PropertyState

	# Fund exactly 5 units when N is 8, so a flat-N implementation buys zero and a correct one
	# buys 5. The 6th unit costs orders of magnitude more than any float slop in this sum, so
	# funding the exact bulk price cannot accidentally stretch to a sixth.
	var affordable_units := 5
	_check("this test needs N (%d) to exceed the %d units it funds"
		% [_units, affordable_units], _units > affordable_units)
	game.economy.cash = cheapest.get_bulk_cost(affordable_units)

	var bought := game.auto_purchase.tick(_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("the tick bought something rather than refusing the whole block", bought > 0)
	_check("it bought exactly the %d units the cash covered (got %d)"
		% [affordable_units, bought], bought == affordable_units)
	_check("the cheapest property owns those %d units" % affordable_units,
		cheapest.units_owned == affordable_units)
	_check("the spend emptied the wallet (no cash left unspent)", game.economy.cash < 1.0)


# ---------------------------------------------------------------------------
# 5. Disabled is inert
# ---------------------------------------------------------------------------

func _test_disabled_is_inert(configs: Array, tuning: TuningConfig) -> void:
	print("\n5. With the mode switched off, ticking buys nothing")
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	game.auto_purchase.enabled = false

	var bought := 0
	for _i in range(20):
		bought += game.auto_purchase.tick(_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("twenty ticks while disabled bought nothing", bought == 0)
	_check("no units were acquired anywhere", _total_units(game) == 0)

	# And switching it back on must work immediately — "off" parks the mode, it does not
	# break it. (The accumulator is untouched while disabled, so the first tick after the
	# switch still owes a full cadence.)
	game.auto_purchase.enabled = true
	var bought_after_enable := 0
	for _i in range(2):
		bought_after_enable += game.auto_purchase.tick(
			_cadence, game, TARGET_TAB, _cadence, _units, _breadth)
	_check("re-enabling the mode resumes buying", bought_after_enable > 0)
