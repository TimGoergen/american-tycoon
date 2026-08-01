extends SceneTree

# Blue Collar epoch threshold study (Plans/Earth_Split_Epochs.md, Tim 2026-07-27).
#
# Usage: godot --headless --path game --script res://sim/BlueCollarStudy.gd
#
# The Earth-split plan makes Blue Collar (properties 1-6) its own epoch, which needs a
# NEW earn-to-clear threshold. Tim's brief: the threshold should land roughly when a new
# player (a) owns at least one of every Blue Collar property, (b) has bought "a few" of
# each, and (c) can afford the first White Collar property (Day Trading, $6M).
#
# Model: a bare, fresh founder (zero Legacy, $0) plays with the same policy as Sim.gd's
# epoch playout — wage taps to bootstrap, greedy reinvest (units + staff levels + hires +
# cycle restarts), frenzy popped when ready — but BUYING IS RESTRICTED to the six Blue
# Collar properties, simulating the post-split world where White Collar is locked until
# the new epoch arrives. Cash therefore piles up once Blue Collar saturates, exactly as
# it would for a real pre-split player.
#
# For each play style we print lifetime-earned + cash-on-hand at each milestone; the
# threshold recommendation is read off the "owns a few of each AND can afford Day
# Trading" row. Play styles: pure idle (floor), and active rush on the top 2 earners at
# rush_power 1 (a NEW player has no Strong-Arm Tactics levels — this is the realistic
# ceiling for a first run).

const TICK_SIZE := 0.1                 # matches LOGIC_HZ = 10 (same as Sim.gd)
const WAGE_TAP_PERIOD := 0.3           # an active thumb: ~3 wage taps per second
const TIME_CAP := 3600.0               # 1 sim hour is far beyond any expected milestone
const BLUE_COUNT := 6                  # properties 0-5 are Earth Blue Collar
const DAY_TRADING_INDEX := 6           # the first White Collar property ($6M base)
const FEW_OF_EACH := 3                 # "a few" of each — the brief's midpoint...
const MORE_OF_EACH := 5                # ...plus a deeper reference point

var _property_configs: Array = []
var _tuning: TuningConfig


func _initialize() -> void:
	_tuning = ConfigLoader.load_tuning(false)  # baked defaults, never device overrides
	_property_configs = ConfigLoader.load_property_configs()
	if _tuning == null or _property_configs.is_empty():
		quit(1)
		return

	print("=== Blue Collar epoch threshold study (Earth split) ===")
	var day_trading_cost := (_property_configs[DAY_TRADING_INDEX] as PropertyConfig).base_cost
	print("Buying restricted to properties 1-6; Day Trading costs %s."
			% Money.of(day_trading_cost).display())
	print("")

	_run_playout("IDLE — no rush (passive floor)", 0, day_trading_cost)
	_run_playout("ACTIVE — rush top 2, no Strong-Arm (new player)", 2, day_trading_cost)

	quit()


## Play a fresh founder under the given rush model and print each milestone as it is
## reached: sim time, lifetime earned, and cash on hand.
func _run_playout(label: String, rush_top_n: int, day_trading_cost: float) -> void:
	print("--- %s ---" % label)
	var game := GameState.new(_property_configs, _tuning)
	game.economy.award_cash(_tuning.m1_starting_cash)

	var sim_time := 0.0
	var next_wage_tap := 0.0
	var rush_accumulator := 0.0
	var rush_pulse_interval := 1.0 / _tuning.hold_rush_per_second

	# Milestones print once each, in whatever order the run reaches them.
	# Candidate thresholds: what would ARRIVAL look like if the Blue Collar epoch cleared at
	# this lifetime-earned mark? Prints cash on hand + ownership at the crossing, so the
	# chosen threshold can match the alien-boundary convention (flagship ≈ cash at contact).
	var pending := {
		"candidate threshold $60M": func() -> bool: return game.economy.cash_earned_this_gen >= 60e6,
		"candidate threshold $100M": func() -> bool: return game.economy.cash_earned_this_gen >= 100e6,
		"candidate threshold $150M": func() -> bool: return game.economy.cash_earned_this_gen >= 150e6,
		"own 1 of each Blue Collar": func() -> bool: return _owns_n_of_each(game, 1),
		"own %d of each" % FEW_OF_EACH: func() -> bool: return _owns_n_of_each(game, FEW_OF_EACH),
		"own %d of each" % MORE_OF_EACH: func() -> bool: return _owns_n_of_each(game, MORE_OF_EACH),
		"cash covers Day Trading": func() -> bool: return game.economy.cash >= day_trading_cost,
		"THE BRIEF: %d of each + cash covers Day Trading" % FEW_OF_EACH:
			func() -> bool: return _owns_n_of_each(game, FEW_OF_EACH) \
					and game.economy.cash >= day_trading_cost,
	}

	while not pending.is_empty() and sim_time < TIME_CAP:
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()
		_greedy_build_blue(game)
		if rush_top_n > 0:
			var targets := _top_running_blue_indices(game, rush_top_n)
			rush_accumulator += TICK_SIZE
			while rush_accumulator >= rush_pulse_interval:
				rush_accumulator -= rush_pulse_interval
				for idx in targets:
					game.hold_rush_property(idx)
		game.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		for milestone in pending.keys():
			if (pending[milestone] as Callable).call():
				print("  %-46s  t=%s   earned %s   cash %s" % [
					milestone,
					_format_time(sim_time),
					Money.of(game.economy.cash_earned_this_gen).display(),
					Money.of(game.economy.cash).display(),
				])
				pending.erase(milestone)

	for milestone in pending.keys():
		print("  %-46s  NOT REACHED within %s" % [milestone, _format_time(TIME_CAP)])
	print("")


## True when every Blue Collar property has at least `n` units.
func _owns_n_of_each(game: GameState, n: int) -> bool:
	for i in range(BLUE_COUNT):
		if (game.economy.properties[i] as PropertyState).units_owned < n:
			return false
	return true


## Sim.gd's _greedy_build_out, restricted to the Blue Collar six: each step takes whichever
## action — one more unit or the next staff level — adds the most passive income/sec per
## dollar, then hires (automation) and restarts idle cycles. White Collar and beyond are
## treated as locked, so surplus cash accumulates.
func _greedy_build_blue(game: GameState) -> void:
	var actions := 0
	while actions < 400:
		actions += 1
		var best_index := -1
		var best_is_staff := false
		var best_value := 0.0
		for i in range(BLUE_COUNT):
			var prop := game.economy.properties[i] as PropertyState
			var unit_cost := prop.get_next_cost()
			if unit_cost > 0.0 and game.economy.cash >= unit_cost:
				var before_units := prop.get_income_per_sec()
				prop.units_owned += 1
				var after_units := prop.get_income_per_sec()
				prop.units_owned -= 1
				var unit_value := (after_units - before_units) / unit_cost
				if unit_value > best_value:
					best_value = unit_value
					best_index = i
					best_is_staff = false
			if prop.units_owned > 0 and prop.staff_level >= 1 \
					and not game.economy.is_staff_level_maxed(i, game.epoch.current_tier):
				var level_cost := game.economy.get_next_staff_level_cost(i)
				if level_cost > 0.0 and game.economy.cash >= level_cost:
					var before_level := prop.get_income_per_sec()
					prop.staff_level += 1
					var after_level := prop.get_income_per_sec()
					prop.staff_level -= 1
					var level_value := (after_level - before_level) / level_cost
					if level_value > best_value:
						best_value = level_value
						best_index = i
						best_is_staff = true
		if best_index == -1:
			break
		if best_is_staff:
			game.try_buy_staff_level(best_index)
		else:
			game.try_buy(best_index, 1)
	# Automation pass: hire any owned-but-unstaffed Blue Collar property and restart
	# idle cycles, so income never silently stalls (unstaffed cycles stop after paying).
	for i in range(BLUE_COUNT):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0:
			if not prop.is_staffed:
				game.try_buy_staff_level(i)
			if not prop.is_cycle_running:
				game.tap_property(i)


## The top `n` owned + running Blue Collar properties by income/sec (the rush targets).
func _top_running_blue_indices(game: GameState, n: int) -> Array:
	var candidates: Array = []
	for i in range(BLUE_COUNT):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0 and prop.is_cycle_running:
			candidates.append({"i": i, "ips": prop.get_income_per_sec()})
	candidates.sort_custom(func(a, b): return float(a["ips"]) > float(b["ips"]))
	var out: Array = []
	for j in range(mini(n, candidates.size())):
		out.append(int(candidates[j]["i"]))
	return out


func _format_time(seconds: float) -> String:
	if seconds < 60.0:
		return "%.0f s" % seconds
	return "%.1f m" % (seconds / 60.0)
