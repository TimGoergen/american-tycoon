extends SceneTree

# Headless balance simulator entry point (Mechanics Spec §13).
# Runs 10 simulated minutes of gameplay and reports income/sec over time.
#
# Usage: godot --headless --script res://sim/Sim.gd
#
# Strategy: "Greedy Optimizer" — on each decision cycle, spend available cash
# on whichever single unit yields the best marginal income/sec per dollar.
# This approximates an engaged player always making the optimal buy.
#
# The simulated player is ACTIVE: unstaffed cycles stop after each payout
# (Spec §4), so the player re-taps every idle property to restart it. Without
# these taps no income would ever accrue. (Staffing would automate this, but
# a free manual tap is economically identical in-sim, so we don't model hires.)

const SIM_DURATION_SECONDS := 600.0   # 10 minutes
const TICK_SIZE := 0.1                  # 0.1 s per tick (matches LOGIC_HZ = 10)
const REPORT_INTERVAL := 60.0          # print income/sec every simulated minute
const STARTING_CASH := 1000.0          # $1,000 — "No" origin path (GDD §8.1)


func _initialize() -> void:
	print("=== American Tycoon — Balance Simulator ===")
	print("Simulating %.0f seconds (%.0f minutes) of greedy-optimizer play." % [
		SIM_DURATION_SECONDS, SIM_DURATION_SECONDS / 60.0
	])
	print("")

	# Load tuning config.
	var tuning := ResourceLoader.load("res://config/tuning.tres") as TuningConfig
	if tuning == null:
		push_error("Sim: could not load res://config/tuning.tres")
		quit(1)
		return

	# Load all 12 property configs in GDD order.
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
	var configs: Array = []
	for path in property_files:
		var cfg := ResourceLoader.load(path) as PropertyConfig
		if cfg == null:
			push_error("Sim: could not load " + path)
			quit(1)
			return
		configs.append(cfg)

	# Create the economy and give the player their starting capital.
	var economy := EconomyState.new(configs, tuning)
	economy.award_cash(STARTING_CASH)

	print("Starting cash: %s" % Money.of(economy.cash).display())
	print("")

	var next_report_at := REPORT_INTERVAL
	var sim_time := 0.0

	# Simulation main loop.
	while sim_time < SIM_DURATION_SECONDS:
		# Decision phase: try to make the best possible buy this second.
		# Run decisions until no buy is affordable (max 100 buys per second of
		# sim time to avoid infinite loops on a degenerate config).
		var buys_this_second := 0
		while buys_this_second < 100:
			var best_index := -1
			var best_value := 0.0  # marginal income/sec per dollar

			for i in range(economy.properties.size()):
				var prop := economy.properties[i] as PropertyState
				var cost := prop.get_next_cost()
				if cost <= 0.0 or economy.cash < cost:
					continue
				# Marginal income/sec this unit adds.
				var current_ips := prop.get_income_per_sec()
				prop.units_owned += 1  # temporarily add unit to read new ips
				var new_ips := prop.get_income_per_sec()
				prop.units_owned -= 1  # restore
				var marginal := new_ips - current_ips
				var value := marginal / cost
				if value > best_value:
					best_value = value
					best_index = i

			if best_index == -1:
				break  # nothing affordable

			economy.try_buy(best_index, 1)
			buys_this_second += 1

		# Active-player taps: restart any idle cycle (the Layer-2 start verb).
		for i in range(economy.properties.size()):
			var prop := economy.properties[i] as PropertyState
			if prop.units_owned > 0 and not prop.is_cycle_running:
				economy.start_cycle(i)

		# Tick the economy forward by TICK_SIZE.
		economy.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		# Print report at each minute boundary.
		if sim_time >= next_report_at:
			var min_elapsed := int(sim_time / 60.0)
			var ips := economy.get_total_income_per_sec()
			var cash_display := Money.of(economy.cash).display()
			var ips_display := Money.of(ips).display()
			print("t=%02dm | income/sec: %s/s | cash: %s" % [
				min_elapsed, ips_display, cash_display
			])
			next_report_at += REPORT_INTERVAL

	# Final summary.
	print("")
	print("=== Simulation Complete ===")
	print("Sim duration : %.0f seconds" % sim_time)
	print("Total income : %s" % Money.of(economy.total_income).display())
	print("Final cash   : %s" % Money.of(economy.cash).display())
	print("Final ips    : %s/s" % Money.of(economy.get_total_income_per_sec()).display())
	print("")
	print("Property breakdown:")
	for i in range(economy.properties.size()):
		var prop := economy.properties[i] as PropertyState
		if prop.units_owned > 0:
			var cfg := prop.config as PropertyConfig
			print("  %-30s owned: %4d | ips: %s/s" % [
				cfg.display_name,
				prop.units_owned,
				Money.of(prop.get_income_per_sec()).display()
			])

	quit()
