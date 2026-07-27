extends "res://sim/Sim.gd"

# One-off reachability check for the tier 12-26 rollout (2026-07-26). The full EpochPaceStudy
# grinds to the 6h sim cap when a run stalls in the deep epochs (the intended prestige wall),
# which is slow in wall-clock. This runs the SAME active-heir loop but with a short sim-time cap
# and heavy Legacy stacks, just to confirm a funded dynasty MECHANICALLY advances into the new
# tiers 12-26 (properties buyable, income flows, epoch gate keeps opening) — leaving the true
# pacing feel to Tim's device test. Usage:
#   Godot_console.exe --headless --path game --script res://sim/EpochDepthCheck.gd

const MY_CAP := 600.0   # sim-seconds; short so a stalled run returns fast

func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Epoch Depth Check (tiers 12-26 reachability) ===")
	print("Active heir (rush top 3, power 6), short %ss sim cap. Reports how deep each stack" % MY_CAP)
	print("reaches — confirming the new epochs are buyable/advanceable, not a structural dead-end.")
	for gems in [10_000_000_000_000]:
		_run_capped(gems)
	quit()


func _run_capped(heir_legacy: int) -> void:
	var dynasty := DynastyState.new(_property_configs, _tuning)
	dynasty.upgrades.award(heir_legacy)
	_buy_upgrades_greedily(dynasty)
	var game := dynasty.current
	game.economy.award_cash(_tuning.m1_starting_cash)
	for prop_variant in game.economy.properties:
		(prop_variant as PropertyState).rush_power_multiplier = 6.0
	var sim_time := 0.0
	var next_wage_tap := 0.0
	var rush_accumulator := 0.0
	var rush_pulse_interval := 1.0 / _tuning.hold_rush_per_second
	var start_tier := game.epoch.current_tier
	while game.epoch.current_tier < EpochCatalog.tier_count() and sim_time < MY_CAP:
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()
		_greedy_build_out(game)
		var targets := _top_running_property_indices(game, 3)
		rush_accumulator += TICK_SIZE
		while rush_accumulator >= rush_pulse_interval:
			rush_accumulator -= rush_pulse_interval
			for idx in targets:
				game.hold_rush_property(idx)
		dynasty.tick(TICK_SIZE)
		sim_time += TICK_SIZE
	var reached := game.epoch.current_tier
	print("  %14s gems: started tier %d, reached tier %d/%d in %.0fs sim%s"
		% [_group(heir_legacy), start_tier, reached, EpochCatalog.tier_count(), sim_time,
			("  (FINAL EPOCH REACHED)" if reached >= EpochCatalog.tier_count() else "  (still climbing at cap)")])


func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
