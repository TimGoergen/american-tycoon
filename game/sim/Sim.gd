extends SceneTree

# Headless balance simulator entry point (Mechanics Spec §13).
#
# Usage: godot --headless --path . --script res://sim/Sim.gd
#
# Runs the M1 verification protocol end to end, headlessly:
#   Phase 1 — 10 minutes of active play (wage taps, greedy buys, frenzy pops).
#   Phase 2 — hire staffers wherever affordable (the offline income source).
#   Phase 3 — save, reload into a fresh GameState, and return from a
#             simulated 3-hour absence (closed-form, never cycle-simulated).
#   Phase 4 — the return spike: spend the pile, report the income/sec jump.
#             This is the moment M1 exists to verify (GDD §3.1).
#
# The simulated player is ACTIVE during Phase 1: unstaffed cycles stop after
# each payout (Spec §4), so the player re-taps every idle property to restart
# it. Every tap (wage, start, rush) feeds the frenzy meter, which is popped
# greedily the moment it crosses the pop floor.

const ACTIVE_SECONDS := 600.0          # Phase 1 duration: 10 minutes
const TICK_SIZE := 0.1                 # matches LOGIC_HZ = 10
const REPORT_INTERVAL := 60.0          # print a status line every sim minute
const STARTING_CASH := 1000.0          # "No rich parents" origin (GDD §8.1)
const OFFLINE_GAP_SECONDS := 10800.0   # 3 hours — the GDD §3.2 tuning anchor
const WAGE_TAP_PERIOD := 0.3           # an active thumb: ~3 wage taps per second
const SIM_SAVE_PATH := "user://sim_save.json"

var _property_configs: Array = []
var _title_configs: Array = []
var _tuning: TuningConfig


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return

	print("=== American Tycoon — Balance Simulator ===")
	print("")

	var game := GameState.new(_property_configs, _title_configs, _tuning)
	game.economy.award_cash(STARTING_CASH)
	print("Starting cash: %s" % Money.of(game.economy.cash).display())

	_run_active_phase(game)
	_run_hiring_phase(game)
	var resumed := _run_offline_phase(game)
	if resumed == null:
		quit(1)
		return
	_run_return_spike_phase(resumed)

	quit()


# ---------------------------------------------------------------------------
# Config loading — everything comes from /config, nothing from code
# ---------------------------------------------------------------------------

## Load every config Resource the sim needs. Returns false on any failure.
func _load_configs() -> bool:
	_tuning = ResourceLoader.load("res://config/tuning.tres") as TuningConfig
	if _tuning == null:
		push_error("Sim: could not load res://config/tuning.tres")
		return false

	var property_files := [
		"res://config/properties/01_atm.tres",
		"res://config/properties/02_money_tree.tres",
		"res://config/properties/03_nfts.tres",
		"res://config/properties/04_tax_increment_financing.tres",
		"res://config/properties/05_cross_border_distribution.tres",
		"res://config/properties/06_money_laundering.tres",
		"res://config/properties/07_day_trading.tres",
		"res://config/properties/08_flipping_houses.tres",
		"res://config/properties/09_multi_level_marketing.tres",
		"res://config/properties/10_hedge_fund.tres",
		"res://config/properties/11_legislative_assets.tres",
		"res://config/properties/12_executive_assets.tres",
	]
	for path in property_files:
		var prop_cfg := ResourceLoader.load(path) as PropertyConfig
		if prop_cfg == null:
			push_error("Sim: could not load " + path)
			return false
		_property_configs.append(prop_cfg)

	var title_files := [
		"res://config/titles/01_intern.tres",
		"res://config/titles/02_associate.tres",
		"res://config/titles/03_shift_supervisor.tres",
	]
	for path in title_files:
		var title_cfg := ResourceLoader.load(path) as TitleRow
		if title_cfg == null:
			push_error("Sim: could not load " + path)
			return false
		_title_configs.append(title_cfg)

	return true


# ---------------------------------------------------------------------------
# Phase 1 — active play
# ---------------------------------------------------------------------------

func _run_active_phase(game: GameState) -> void:
	print("")
	print("--- Phase 1: %d minutes of active play ---" % int(ACTIVE_SECONDS / 60.0))

	var sim_time := 0.0
	var next_report := REPORT_INTERVAL
	var next_wage_tap := 0.0
	var frenzy_pops := 0

	while sim_time < ACTIVE_SECONDS:
		# Wage taps (Layer 1) — also the early frenzy filler.
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD

		# Claim a promotion the moment it's unlocked and affordable.
		game.try_claim_promotion()

		# Pop frenzy greedily. (A real player would charge higher first; the
		# greedy policy just proves the state machine cycles correctly.)
		if game.pop_frenzy():
			frenzy_pops += 1

		_greedy_buy_spree(game)

		# Restart idle cycles — the Layer-2 start verb, tapped by the player.
		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			if prop.units_owned > 0 and not prop.is_cycle_running:
				game.tap_property(i)

		game.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		if sim_time >= next_report:
			print("t=%02dm | income/sec: %s/s | cash: %s | wage taps: %d | frenzy x%.2f" % [
				int(sim_time / 60.0),
				Money.of(game.economy.get_total_income_per_sec()).display(),
				Money.of(game.economy.cash).display(),
				game.wage.lifetime_taps,
				game.frenzy.get_multiplier(),
			])
			next_report += REPORT_INTERVAL

	print("Frenzy pops this session: %d | final title: %s" % [
		frenzy_pops, game.wage.get_current_title().title_name
	])


# ---------------------------------------------------------------------------
# Phase 2 — staff hires before stepping away
# ---------------------------------------------------------------------------

func _run_hiring_phase(game: GameState) -> void:
	print("")
	print("--- Phase 2: hiring staff before stepping away ---")

	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned == 0 or prop.is_staffed:
			continue
		var cost := prop.get_staff_cost()
		if game.try_hire(i):
			print("  Hired %s for %s" % [
				(prop.config as PropertyConfig).staffer_name,
				Money.of(cost).display(),
			])

	var staffed_ips := 0.0
	for prop in game.economy.properties:
		var p := prop as PropertyState
		if p.is_staffed:
			staffed_ips += p.get_income_per_sec()

	print("  Staffed income/sec: %s/s | cash remaining: %s" % [
		Money.of(staffed_ips).display(),
		Money.of(game.economy.cash).display(),
	])


# ---------------------------------------------------------------------------
# Phase 3 — save round-trip + the 3-hour absence
# ---------------------------------------------------------------------------

## Save, then load into a fresh GameState as if the app relaunched 3 hours
## later. Returns the resumed game, or null if the save round-trip failed.
func _run_offline_phase(game: GameState) -> GameState:
	print("")
	print("--- Phase 3: away for %.1f hours ---" % (OFFLINE_GAP_SECONDS / 3600.0))

	if not SaveManager.save_to_file(game, SIM_SAVE_PATH):
		push_error("Sim: save failed")
		return null

	var save_dict := SaveManager.load_from_file(SIM_SAVE_PATH)
	if save_dict.is_empty():
		push_error("Sim: load failed")
		return null

	var resumed := GameState.new(_property_configs, _title_configs, _tuning)
	resumed.load_save_dict(save_dict)

	# Sanity-check the round trip before trusting the rest of the run.
	# (Cash is always integer-valued — everything floors at award/charge —
	# so exact float comparison is safe here.)
	if resumed.economy.cash != game.economy.cash:
		push_error("Sim: cash mismatch after save round-trip")
		return null

	var offline := resumed.apply_offline(OFFLINE_GAP_SECONDS)
	print("  Welcome back. Hours worked: 0")
	print("  Offline pile: %s (%.1f of %.1f hours paid, at %.0f%% efficiency)" % [
		Money.of(offline.pile).display(),
		offline.paid_seconds / 3600.0,
		offline.elapsed_seconds / 3600.0,
		_tuning.offline_efficiency * 100.0,
	])
	return resumed


# ---------------------------------------------------------------------------
# Phase 4 — the return spike
# ---------------------------------------------------------------------------

func _run_return_spike_phase(game: GameState) -> void:
	print("")
	print("--- Phase 4: the return spike ---")

	var ips_before := game.economy.get_total_income_per_sec()
	var units_bought := _greedy_buy_spree(game)

	# Restart anything idle the spree left behind (staffed ones auto-run).
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0 and not prop.is_cycle_running:
			game.tap_property(i)

	var ips_after := game.economy.get_total_income_per_sec()
	var delta_pct := 0.0
	if ips_before > 0.0:
		delta_pct = (ips_after / ips_before - 1.0) * 100.0

	print("  Units bought with the pile: %d" % units_bought)
	print("  Income/sec: %s/s -> %s/s  (+%.0f%%)" % [
		Money.of(ips_before).display(),
		Money.of(ips_after).display(),
		delta_pct,
	])

	print("")
	print("=== Final property breakdown ===")
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0:
			print("  %-26s owned: %4d | %s | ips: %s/s" % [
				(prop.config as PropertyConfig).display_name,
				prop.units_owned,
				"staffed" if prop.is_staffed else "manual",
				Money.of(prop.get_income_per_sec()).display(),
			])


# ---------------------------------------------------------------------------
# Shared player policy
# ---------------------------------------------------------------------------

## Spend cash on whichever single unit adds the best income/sec per dollar,
## repeating until nothing is affordable. Returns the number of units bought.
## (Capped to avoid a pathological loop on a degenerate config.)
func _greedy_buy_spree(game: GameState) -> int:
	var units_bought := 0
	while units_bought < 1000:
		var best_index := -1
		var best_value := 0.0  # marginal income/sec per dollar

		for i in range(game.economy.properties.size()):
			var prop := game.economy.properties[i] as PropertyState
			var cost := prop.get_next_cost()
			if cost <= 0.0 or game.economy.cash < cost:
				continue
			var current_ips := prop.get_income_per_sec()
			prop.units_owned += 1  # peek at the post-purchase rate
			var new_ips := prop.get_income_per_sec()
			prop.units_owned -= 1
			var value := (new_ips - current_ips) / cost
			if value > best_value:
				best_value = value
				best_index = i

		if best_index == -1:
			break  # nothing affordable

		game.try_buy(best_index, 1)
		units_bought += 1

	return units_bought
