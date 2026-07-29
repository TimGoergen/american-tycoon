extends "res://sim/Sim.gd"

# Dynasty Arc Study — the Endgame Economy's primary fit instrument
# (Plans/Endgame_Economy.md, 2026-07-28).
#
# Plays a WHOLE DYNASTY: generation after generation of (active playout to the wall →
# prestige → mint under the piecewise curve → greedy upgrade shopping on the steepening
# cost curve), printing one line per run. This closes the loop the single-stack studies
# can't: mints grow as runs push deeper, fortunes compound, and the steepening shop
# converts them to slowly-growing multipliers — so the run-by-run wall progression IS
# the felt game, measured.
#
# The fit target (Tim, 2026-07-28): "about a dozen deep runs" should crack tier 27 —
# read the `reached` column: it should climb a couple of epochs per run through the
# teens/twenties and hit 27 around generation ~12, with per-run mints in the billions
# at depth (never septillions).
#
# Usage: Godot_console.exe --headless --path game --script res://sim/DynastyArcStudy.gd

const GENERATIONS := 14
## Sim-time cap per generation. A run that stalls THIS long at its wall has clearly
## found it; prestiging then is exactly what a player would do.
const GEN_CAP := 7200.0

func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Dynasty Arc Study (endgame economy fit) ===")
	print("Each generation: active playout (rush top 3, power 6) to its wall or %.1fh sim," % (GEN_CAP / 3600.0))
	print("then prestige -> mint -> greedy shop. Target: tier 27 falls around generation ~12.")
	print("")
	print("  gen   reached   gen sim-time     minted this gen     lifetime gems   FamFortune lv")

	var dynasty := DynastyState.new(_property_configs, _tuning)
	for gen in range(1, GENERATIONS + 1):
		var game := dynasty.current
		game.economy.award_cash(_tuning.m1_starting_cash)
		for prop_variant in game.economy.properties:
			(prop_variant as PropertyState).rush_power_multiplier = 6.0

		var sim_time := 0.0
		var next_wage_tap := 0.0
		var rush_accumulator := 0.0
		var rush_pulse_interval := 1.0 / _tuning.hold_rush_per_second
		while game.epoch.current_tier < EpochCatalog.tier_count() and sim_time < GEN_CAP:
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
		var lifetime_before := dynasty.upgrades.earned_lifetime
		dynasty.perform_succession()
		var minted := dynasty.upgrades.earned_lifetime - lifetime_before
		_buy_upgrades_greedily(dynasty)
		print("  %3d   %5d/%d   %10s   %17s   %15s   %8d" % [
			gen, reached, EpochCatalog.tier_count(), _format_duration(sim_time),
			Money.abbrev(float(minted)), Money.abbrev(float(dynasty.upgrades.earned_lifetime)),
			dynasty.upgrades.get_level(LegacyUpgradeCatalog.FAMILY_FORTUNE),
		])
		if reached >= EpochCatalog.tier_count():
			print("  TIER %d REACHED at generation %d — the summit falls here." % [reached, gen])
			break
	quit()
