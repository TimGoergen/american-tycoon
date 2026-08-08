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
#   3. Purchases never leave the TAB THE PLAYER IS LOOKING AT.
#   4. Partial fill: a tick that runs out of money mid-run keeps what it bought and stops.
#   5. An unaffordable tick buys nothing AND does not bank credit — in both directions: an empty
#      tick stays primed (buys the instant cash arrives), and a successful tick restarts the full
#      wait (it cannot fire twice in quick succession).
#   6. Disabled means inert.
#
# REWRITTEN 2026-08-07 for the restructure. Two rules from the previous version are gone: the
# flagship exclusion (dropped — the desk may buy anything on its tab) and breadth (the N x X grid
# collapsed into a single purchase count).
#
# SCOPE went round a loop the same day and the detour is worth recording. Tab targeting was
# replaced by current-epoch scope, which briefly shipped and read as the feature being BROKEN: each
# epoch's entry rung costs ~16,807x the previous one's, so the frontier cohort is unaffordable for
# a long stretch after every First Contact while the player sits looking at an era they can afford.
# Tim clarified the intent — "auto buy should always and only purchase properties on the currently
# visible tab" — so the tab is the aim again, and it is the LIVE on-screen tab, not the reached
# epoch. Case 4 pins it hard: the run is aimed shallower than it has reached, so either mis-scoping
# shows up as an off-tab purchase.
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

## The civ tab the tests aim the desk at. Tab N is the cohort gated to unlock_tier N + 1, so tab 2
## is tier 3 — the FIRST alien cohort. Deliberately SHALLOWER than REACHED_TIER, so a bug that
## ignores the tab and buys the frontier instead shows up as an off-tab purchase rather than
## passing by coincidence. That is exactly the mis-scoping that shipped briefly on 2026-08-07.
const TARGET_TAB := 2

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
	_test_stays_on_the_targeted_tab(property_configs, tuning)
	_test_partial_fill(property_configs, tuning)
	_test_unaffordable_tick_banks_nothing(property_configs, tuning)
	_test_disabled_is_inert(property_configs, tuning)
	_test_deleted_upgrade_ids_are_inert(property_configs, tuning)
	_test_tracks_require_the_unlock(property_configs, tuning)
	_test_enabled_without_owned_is_fully_inert(property_configs, tuning)
	_test_lowest_next_cost_drives_the_idle_readout(property_configs, tuning)

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
## honestly would take a long build-out, and none of the rules under test depend on how the run got
## there — only on which properties are unlocked and which tab the desk is aimed at.
func _make_run(configs: Array, tuning: TuningConfig, cash: float) -> GameState:
	var dynasty := DynastyState.new(configs, tuning)
	var game := dynasty.current
	game.epoch.restore(REACHED_TIER)
	game.economy.cash = cash
	game.auto_purchase.enabled = true
	# BOTH halves. `enabled` is the player's switch; `unlocked` is whether the desk is owned, pushed
	# in by Main. The mode only runs when both are true — see case 10 for why they are separate.
	game.auto_purchase.unlocked = true
	return game


## The property indices on the TARGETED tab — the mode's whole world. Keyed off TARGET_TAB, not the
## reached epoch: the two are deliberately different so an off-tab purchase is detectable.
func _tab_indices(game: GameState) -> Array:
	return game.economy.get_property_indices_for_unlock_tier(TARGET_TAB + 1)


## Every property's units_owned, by index — a snapshot to diff a run against.
func _snapshot_units(game: GameState) -> Array[int]:
	var counts: Array[int] = []
	for prop in game.economy.properties:
		counts.append((prop as PropertyState).units_owned)
	return counts


## The cheapest next-unit cost on the targeted tab, computed INDEPENDENTLY of AutoPurchaseState
## so the tests do not just re-assert the implementation against itself.
func _cheapest_cost_on_tab(game: GameState) -> float:
	var best := -1.0
	for i in _tab_indices(game):
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

	# CASH SCALED TO THE TAB, not PLENTY_OF_CASH. This test measures the spend by subtracting two
	# cash readings, and float64 carries ~16 significant digits: with 1e30 in the bank and a 1e13
	# price, `cash_before - cash_after` rounds to exactly ZERO and every purchase looks free. The
	# assertion failed for that reason alone once the targeted tab became shallower than the
	# reached epoch. A million times the tab's own price is ample and keeps the subtraction honest.
	game.economy.cash = _cheapest_cost_on_tab(game) * 1.0e6

	# One purchase at a time, checking before each that the property the mode picks really is the
	# cheapest. Doing it purchase-by-purchase is the point: a bug that sorts once and then buys
	# down a stale list would pass a check made only at the start of the tick.
	# Measured by what the purchase COST, not by which property it hit: if the mode paid exactly
	# the cheapest price on offer, it bought the cheapest thing on offer. That uses only public
	# API and cannot be fooled by a stale sort.
	var mismatches := 0
	for _step in range(25):
		var expected_cost := _cheapest_cost_on_tab(game)
		var cash_before := game.economy.cash
		game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 1)
		var spent := cash_before - game.economy.cash
		if game.auto_purchase.last_purchased_indices.size() != 1 \
				or not is_equal_approx(spent, expected_cost):
			if mismatches == 0:
				print("      first mismatch: expected %s, spent %s, touched %d" % [
					Money.abbrev(expected_cost), Money.abbrev(spent),
					game.auto_purchase.last_purchased_indices.size()])
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
	var bought := game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 30)
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
	var indices := _tab_indices(game)
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
# 4. Scope is the tab on screen
# ---------------------------------------------------------------------------

func _test_stays_on_the_targeted_tab(configs: Array, tuning: TuningConfig) -> void:
	print("\n4. Purchases never leave the tab the desk is aimed at")

	# Part one: with money, everything stays in the current epoch.
	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	var tab_set := {}
	for i in _tab_indices(game):
		tab_set[i] = true
	_check("the targeted tab has a cohort to buy from", not tab_set.is_empty())

	# ONE SHORT TICK on purpose. Given long enough, escalating prices WILL push the epoch out of
	# reach and the fallback correctly kicks in — that is the feature, not a leak. This part is only
	# asserting the preference while the epoch is comfortably affordable.
	var before := _snapshot_units(game)
	game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 5)
	var after := _snapshot_units(game)

	var strayed: Array[int] = []
	var changed := 0
	for i in range(before.size()):
		if after[i] == before[i]:
			continue
		changed += 1
		if not tab_set.has(i):
			strayed.append(i)

	_check("something on the tab was bought (the run is meaningful)", changed > 0)
	_check("nothing outside the targeted tab was touched (strayed: %s)"
		% str(strayed), strayed.is_empty())

	# Part two: THE TAB IS THE AIM, not the reached epoch. This run has reached tier 6 but is aimed
	# at tab 2 (tier 3), and it has enough money to buy the frontier many times over — so if the
	# desk were scoped to the epoch, or to "everything unlocked", it would show up here as a
	# purchase outside the targeted cohort. That mis-scoping shipped briefly on 2026-08-07 and read
	# as the feature being broken, because the frontier cohort was unaffordable while the player sat
	# looking at an era they could afford.
	_check("the run has reached tier %d, DEEPER than the targeted tier %d"
		% [REACHED_TIER, TARGET_TAB + 1], game.epoch.current_tier > TARGET_TAB + 1)

	var long_before := _snapshot_units(game)
	for _tick in range(40):
		game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 8)
	var long_after := _snapshot_units(game)

	var off_tab: Array[int] = []
	var on_tab := 0
	for i in range(long_before.size()):
		if long_after[i] == long_before[i]:
			continue
		if tab_set.has(i):
			on_tab += 1
		else:
			off_tab.append(i)
	_check("a long run bought plenty on the targeted tab", on_tab > 0)
	_check("...and NEVER strayed off it, in either direction (strayed: %s)" % str(off_tab),
		off_tab.is_empty())


# ---------------------------------------------------------------------------
# 5. Partial fill
# ---------------------------------------------------------------------------

func _test_partial_fill(configs: Array, tuning: TuningConfig) -> void:
	print("\n5. A tick that runs out of money mid-run keeps what it bought")
	var game := _make_run(configs, tuning, 0.0)

	# Fund exactly three purchases ON THE TARGETED TAB, measured by running a probe and reading what
	# it actually spent. Measured rather than summed because try_buy prices through get_bulk_cost,
	# whose rounding differs from get_next_cost by a hair — summing the other getter left the budget
	# a fraction short and the tick bought 2, failing for a reason unrelated to partial fill.
	#
	# The probe also starts tab-scaled rather than at PLENTY_OF_CASH, for the float64 reason in
	# case 1: a 1e30 balance cannot represent a 1e13 withdrawal, so the measurement would be zero.
	var probe := _make_run(configs, tuning, 0.0)
	probe.economy.cash = _cheapest_cost_on_tab(probe) * 1.0e6
	var probe_before := probe.economy.cash
	for _i in range(3):
		probe.auto_purchase.tick(CADENCE, probe, TARGET_TAB, CADENCE, 1)
	var budget := probe_before - probe.economy.cash
	game.economy.cash = budget

	var bought := game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 20)
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
		bought_while_broke += game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 4)
	_check("ten ticks with no money bought nothing", bought_while_broke == 0)

	# Primed: the instant money arrives, the very next tick buys — no further wait.
	game.economy.cash = PLENTY_OF_CASH
	var bought_on_arrival := game.auto_purchase.tick(0.0, game, TARGET_TAB, CADENCE, 4)
	_check("the first tick after cash arrives buys immediately (stayed primed)",
		bought_on_arrival > 0)

	# And the opposite: a successful tick restarts the full wait.
	var bought_too_soon := game.auto_purchase.tick(CADENCE * 0.5, game, TARGET_TAB, CADENCE, 4)
	_check("a half-cadence later it does NOT buy again", bought_too_soon == 0)
	var bought_after_wait := game.auto_purchase.tick(CADENCE * 0.5, game, TARGET_TAB, CADENCE, 4)
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
		bought += game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 8)
	_check("twenty ticks while disabled bought nothing", bought == 0)
	_check("no units were acquired anywhere", _total_units(game) == 0)

	# Switching back on must work immediately — "off" parks the mode, it does not break it.
	game.auto_purchase.enabled = true
	var bought_after_enable := 0
	for _i in range(2):
		bought_after_enable += game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 8)
	_check("re-enabling the mode resumes buying", bought_after_enable > 0)


# ---------------------------------------------------------------------------
# 8. The deleted upgrade ids are inert
# ---------------------------------------------------------------------------

## The restructure deleted `acquisitions_desk` and `head_hunters` and wrote NO migration
## (Plans/Auto_Purchase_Restructure.md §2). That decision rests on one property: a save carrying
## unknown upgrade ids loads them without complaint and nothing ever resolves them against the
## catalog. This test pins that property, so if a future feature starts scanning the levels
## dictionary and calling get_definition() on each entry, it fails here rather than crashing on a
## real player's save.
func _test_deleted_upgrade_ids_are_inert(configs: Array, tuning: TuningConfig) -> void:
	print("\n8. A save carrying the DELETED upgrade ids still loads and plays")

	var old := DynastyState.new(configs, tuning)
	old.upgrades.available = 50000
	# Exactly what a pre-restructure save looks like: levels in tracks that no longer exist.
	old.upgrades.levels["acquisitions_desk"] = 8
	old.upgrades.levels["head_hunters"] = 2
	var save := old.to_save_dict()

	var loaded := DynastyState.new(configs, tuning)
	loaded.load_save_dict(save)
	_check("the save loaded without error", loaded.current != null)
	_check("the dead ids came through untouched (harmless baggage)",
		int(loaded.upgrades.levels.get("acquisitions_desk", 0)) == 8)
	_check("owning the OLD desk grants nothing — the mode is locked",
		not loaded.upgrades.auto_purchase_unlocked())
	_check("...and its quantity is 0, so no free desk runs",
		loaded.upgrades.auto_purchase_quantity() == 0)

	# Bulk hire is free now, so it must be fully available regardless of what was owned before.
	_check("bulk hire is unlocked for everyone", loaded.upgrades.max_hire_mode() >= 2)

	# And buying the NEW unlock works on top of that save.
	loaded.upgrades.available = 50000
	var bought := loaded.upgrades.buy(LegacyUpgradeCatalog.AUTO_PURCHASE_UNLOCK)
	_check("the new unlock can be bought on a migrated-from-nothing save", bought)
	_check("...and the mode is then live at 1 purchase per round",
		loaded.upgrades.auto_purchase_unlocked()
			and loaded.upgrades.auto_purchase_quantity() == 1)


# ---------------------------------------------------------------------------
# 9. The two tracks require the unlock
# ---------------------------------------------------------------------------

## Buying Power and Standing Orders do nothing while the mode is locked — auto_purchase_quantity()
## returns 0 — so buying one first would be 5,000 gems for literally no effect. The prerequisite is
## enforced in LegacyUpgrades.can_buy rather than in the shop UI, so every path obeys it: the buy
## button, the sims' greedy shopper, and anything written later.
func _test_tracks_require_the_unlock(configs: Array, tuning: TuningConfig) -> void:
	print("\n9. Buying Power and Standing Orders cannot be bought before the unlock")

	var dynasty := DynastyState.new(configs, tuning)
	dynasty.upgrades.available = 1000000

	for id in [LegacyUpgradeCatalog.AUTO_PURCHASE_QUANTITY,
			LegacyUpgradeCatalog.AUTO_PURCHASE_CADENCE]:
		_check("%s reports its requirement" % id,
			dynasty.upgrades.requirement_for(id) == LegacyUpgradeCatalog.AUTO_PURCHASE_UNLOCK)
		_check("%s cannot be bought while the desk is unowned" % id,
			not dynasty.upgrades.can_buy(id))
		_check("...and attempting it actually fails (not just greyed in the UI)",
			not dynasty.upgrades.buy(id))

	var wallet_before := dynasty.upgrades.available
	_check("a blocked attempt spent nothing", wallet_before == 1000000)

	# Own the desk, and both open up.
	_check("the unlock itself has no prerequisite",
		dynasty.upgrades.requirement_for(LegacyUpgradeCatalog.AUTO_PURCHASE_UNLOCK) == "")
	dynasty.upgrades.buy(LegacyUpgradeCatalog.AUTO_PURCHASE_UNLOCK)
	_check("with the desk owned, Buying Power is buyable",
		dynasty.upgrades.can_buy(LegacyUpgradeCatalog.AUTO_PURCHASE_QUANTITY))
	_check("...and Standing Orders too",
		dynasty.upgrades.can_buy(LegacyUpgradeCatalog.AUTO_PURCHASE_CADENCE))

	# And the effect actually lands: quantity is 1 (unlock) + purchased levels.
	dynasty.upgrades.buy(LegacyUpgradeCatalog.AUTO_PURCHASE_QUANTITY)
	dynasty.upgrades.buy(LegacyUpgradeCatalog.AUTO_PURCHASE_QUANTITY)
	_check("two Buying Power levels take the round to 3 purchases",
		dynasty.upgrades.auto_purchase_quantity() == 3)


# ---------------------------------------------------------------------------
# 10. Switched on but not owned is inert — including the rush lockout
# ---------------------------------------------------------------------------

## `enabled` PERSISTS IN THE SAVE. `unlocked` does not — it is pushed in from the dynasty every
## frame. So a run can legitimately load with the mode switched on and the desk unowned: after the
## 2026-08-07 restructure deleted the old track, or after any future change to what grants it.
##
## The rush lockout used to ask only about `enabled`, which meant such a save REFUSED EVERY RUSH
## FOREVER while never buying anything — all of the mode's cost and none of its benefit, with
## nothing on screen to explain it. Both halves now go through is_running(), and this pins it.
func _test_enabled_without_owned_is_fully_inert(configs: Array, tuning: TuningConfig) -> void:
	print("\n10. Switched on but NOT owned buys nothing AND does not lock rush")

	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	game.auto_purchase.unlocked = false      # the desk is not owned
	game.auto_purchase.enabled = true        # ...but the saved switch says on

	_check("the mode does not consider itself running", not game.auto_purchase.is_running())

	var bought := 0
	for _i in range(20):
		bought += game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 8)
	_check("twenty ticks bought nothing", bought == 0)
	_check("no units were acquired anywhere", _total_units(game) == 0)

	# THE IMPORTANT HALF: rushing must still work. This is what was broken.
	_check("rush is NOT locked out", not game.is_rush_locked_out_by_auto_purchase())

	# And owning it flips both back on together.
	game.auto_purchase.unlocked = true
	_check("owning the desk makes the mode run", game.auto_purchase.is_running())
	_check("...and rush is locked out again, as designed",
		game.is_rush_locked_out_by_auto_purchase())
	_check("...and it buys", game.auto_purchase.tick(CADENCE, game, TARGET_TAB, CADENCE, 4) > 0)


# ---------------------------------------------------------------------------
# 11. lowest_next_cost — the input to the "NOTHING TO BUY" readout
# ---------------------------------------------------------------------------

## Main compares this against cash to decide whether the desk is running-but-broke, which is what
## the momentum bar's readout says out loud. Worth pinning: a wrong answer here means the bar either
## cries "nothing to buy" while buying, or stays silent while stuck — and a silent stuck desk is
## exactly the report that prompted the readout (Tim, 2026-08-07).
func _test_lowest_next_cost_drives_the_idle_readout(configs: Array, tuning: TuningConfig) -> void:
	print("\n11. lowest_next_cost answers 'what is the desk waiting to afford'")

	var game := _make_run(configs, tuning, PLENTY_OF_CASH)
	var lowest := game.auto_purchase.lowest_next_cost(game, TARGET_TAB)
	_check("it reports a real price", lowest > 0.0)
	# Scoped to the SAME tab the desk buys from, so the readout answers the question the player is
	# actually asking: "why is nothing happening on the tab I am looking at?" A wider scan would
	# stay quiet while the targeted tab sat unaffordable, which is the silence that started all this.
	_check("...and it matches an independent scan of the targeted tab",
		is_equal_approx(lowest, _cheapest_cost_on_tab(game)))

	# AFFORDABILITY IS DELIBERATELY NOT PART OF THE ANSWER: the useful thing to show is the price
	# being saved toward, which by definition is one the player cannot pay yet.
	game.economy.cash = 0.0
	_check("it still reports that price with an empty wallet",
		is_equal_approx(game.auto_purchase.lowest_next_cost(game, TARGET_TAB), lowest))

	# Which is exactly how Main decides the desk is idle.
	_check("broke + running = idle (the readout condition)",
		game.auto_purchase.is_running() and game.economy.cash < lowest)

	# And with money, it is not idle.
	game.economy.cash = PLENTY_OF_CASH
	_check("funded = not idle", game.economy.cash >= game.auto_purchase.lowest_next_cost(game, TARGET_TAB))
