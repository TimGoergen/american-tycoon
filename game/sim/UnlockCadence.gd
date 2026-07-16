extends "res://sim/Sim.gd"

# Unlock Cadence Study — how often does the player get a NEW PROPERTY beat?
#
# Usage: godot --headless --path . --script res://sim/UnlockCadence.gd
#
# Tim's device read (2026-07-15): "the main thing that feels slow after Earth is
# that the pace of unlocking new properties slows down." That matches the ladder
# shape: Earth has 12 first-unit unlock moments across its epoch, every alien
# epoch has only 5 — spread over a similar or longer stretch of play — plus a
# zero-unlock save-up drought right after each First Contact (the flagship is
# anchored to ~10% of the previous threshold on purpose).
#
# The 2026-07-13 pacing experiment showed cohort WIDTH does not change how fast
# an epoch CLEARS (greedy reinvestment reaches the same aggregate economy no
# matter how many rungs it is spread across). This study measures the thing that
# experiment didn't: the time BETWEEN unlock beats. The candidate fix keeps each
# epoch's total ladder span at x16807 (= 7^5, matching the threshold growth, so
# epoch durations / thresholds / prestige cadence all stay untouched) but slices
# it into MORE rungs at a smaller per-rung ratio:
#
#   5 rungs x7.00/rung   (live)          8 rungs x3.37/rung
#   6 rungs x5.07/rung                  10 rungs x2.64/rung
#
# Every candidate plays the SAME run: one bare heir, active-rush model (rush held
# on the top 2 earners, Strong-Arm rush_power 6 — the standard playout player),
# from $0 through all six epochs. We record the sim-time of every first-unit
# purchase and every First Contact, then report per epoch: how many unlock beats,
# the entry drought (contact -> first new unlock), and the median/longest gap
# between beats. Read the numbers RELATIVELY between candidates.
#
# Known softness (fine for a relative read): staff block anchors grow by property
# INDEX (staff_cost_property_growth^index), so adding rungs nudges deep-ladder
# staff prices; and the greedy policy buys a new rung the moment it is the best
# value, which is close to (slightly keener than) a real player.

## The standard active-rush playout player: rush the top 2 earners with a
## Strong-Arm Tactics investment of ~level 10 (rush_power 6).
const RUSH_TOP_N := 2
const RUSH_POWER := 6.0

## One full-epoch ladder block: 7^5 — the cost span each alien epoch's rungs
## must cover so the ladder stays continuous across epochs (rung 1 of epoch T+1
## lands exactly one rung ratio above the top rung of epoch T).
const EPOCH_LADDER_SPAN := 16807.0

## Candidates. rungs -1 = the live shipped ladder (5 rungs at x7), the anchor
## every variant is read against. flat N = every alien epoch gets N rungs.
## escalate_from N = epoch 2 gets N rungs and each later epoch gets one more
## (Tim 2026-07-15: "each epoch having 1 more property than the last") — the
## flat-cadence shape, since epoch durations creep up ~1.2x each.
const CANDIDATES: Array = [
	{"label": "LIVE — 5 rungs/epoch (x7.00/rung)", "rungs": -1},
	{"label": "flat 8 rungs/epoch (x3.37/rung)", "rungs": 8},
	{"label": "escalating 6,7,8,9 rungs (epochs 2-5)", "escalate_from": 6},
]


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return

	print("=== American Tycoon — Unlock Cadence Study ===")
	print("How often the player gets a first-unit unlock beat, per epoch, under the")
	print("live 5-rung alien ladder vs more-rungs-same-span variants. One bare heir,")
	print("active rush (top %d, rush_power %.0f), $0 through all %d epochs." % [
		RUSH_TOP_N, RUSH_POWER, EpochCatalog.tier_count(),
	])

	_print_live_ladder_pattern()

	var summaries: Array = []
	for candidate in CANDIDATES:
		var label: String = candidate["label"]
		var configs := _configs_for_candidate(candidate)
		print("")
		print("--- %s (%d properties total) ---" % [label, configs.size()])
		var result := _play_unlock_run(configs)
		_print_run_report(result)
		summaries.append({"label": label, "result": result})

	_print_comparison(summaries)
	quit()


# ---------------------------------------------------------------------------
# The live ladder's pattern, verified before it is resampled
# ---------------------------------------------------------------------------

## Print each alien cohort's flagship cost, per-rung cost ratio, and income/cost
## ratio, so the variant generator's assumptions (geometric rungs, income scaling
## with cost) are checked against the shipped .tres instead of trusted.
func _print_live_ladder_pattern() -> void:
	print("")
	print("Live alien cohorts (variant generator resamples this pattern):")
	print("  tier   rungs   flagship cost   cost ratio/rung   income/cost")
	for tier in range(2, EpochCatalog.tier_count() + 1):
		var cohort := _cohort_sorted_by_cost(_property_configs, tier)
		if cohort.is_empty():
			continue
		var flagship := cohort[0] as PropertyConfig
		var top := cohort[cohort.size() - 1] as PropertyConfig
		var per_rung := pow(top.base_cost / flagship.base_cost, 1.0 / float(cohort.size() - 1)) \
				if cohort.size() > 1 else 0.0
		print("  %4d   %5d   %13s   %15.2f   %11.5f" % [
			tier,
			cohort.size(),
			Money.of(flagship.base_cost).display(),
			per_rung,
			flagship.base_income_per_unit / flagship.base_cost,
		])


## The configs whose unlock_tier == tier, cheapest first.
func _cohort_sorted_by_cost(configs: Array, tier: int) -> Array:
	var cohort: Array = []
	for cfg in configs:
		if (cfg as PropertyConfig).unlock_tier == tier:
			cohort.append(cfg)
	cohort.sort_custom(func(a, b): return (a as PropertyConfig).base_cost < (b as PropertyConfig).base_cost)
	return cohort


# ---------------------------------------------------------------------------
# Variant ladder construction — same span, more rungs
# ---------------------------------------------------------------------------

## Resolve a candidate entry to its property configs: the live ladder, a flat
## rung count, or an escalating count (epoch 2 = N, each later epoch +1).
func _configs_for_candidate(candidate: Dictionary) -> Array:
	if candidate.has("escalate_from"):
		var start: int = candidate["escalate_from"]
		var per_tier: Array = []
		for tier in range(2, EpochCatalog.tier_count() + 1):
			per_tier.append(start + (tier - 2))
		return _make_variant_ladder(per_tier)
	var rungs: int = candidate["rungs"]
	if rungs < 0:
		return _property_configs
	var flat: Array = []
	for _tier in range(2, EpochCatalog.tier_count() + 1):
		flat.append(rungs)
	return _make_variant_ladder(flat)


## Rebuild the alien ladder with `rungs_per_tier[T-2]` properties in epoch T.
## Earth's 12 configs pass through untouched. Each alien epoch keeps its live
## flagship as the anchor (same cost, same income, same cycle — so the
## epoch-entry save-up and the 3x step-up are preserved) and fills the SAME
## x16807 span above it geometrically, income scaling with cost (the live
## cohorts hold income/cost constant — verified by the pattern printout above).
func _make_variant_ladder(rungs_per_tier: Array) -> Array:
	var variants: Array = []
	for cfg in _property_configs:
		if (cfg as PropertyConfig).unlock_tier == 1:
			variants.append(cfg)
	for tier in range(2, EpochCatalog.tier_count() + 1):
		var cohort := _cohort_sorted_by_cost(_property_configs, tier)
		if cohort.is_empty():
			continue
		var rungs: int = rungs_per_tier[tier - 2]
		var rung_ratio := pow(EPOCH_LADDER_SPAN, 1.0 / float(rungs))
		var flagship := cohort[0] as PropertyConfig
		for k in range(rungs):
			var dup := flagship.duplicate() as PropertyConfig
			var step := pow(rung_ratio, float(k))
			dup.display_name = "%s +%d" % [flagship.display_name, k]
			dup.base_cost = flagship.base_cost * step
			dup.base_income_per_unit = flagship.base_income_per_unit * step
			variants.append(dup)
	return variants


# ---------------------------------------------------------------------------
# The run — one heir through all epochs, every unlock beat timestamped
# ---------------------------------------------------------------------------

## Play the standard active-rush heir over `configs` and record the sim-time of
## every first-unit unlock and every epoch entry (First Contact).
func _play_unlock_run(configs: Array) -> Dictionary:
	var dynasty := DynastyState.new(configs, _tuning)
	var game := dynasty.current
	game.economy.award_cash(_tuning.m1_starting_cash)
	for prop_variant in game.economy.properties:
		(prop_variant as PropertyState).rush_power_multiplier = RUSH_POWER

	var prop_count := game.economy.properties.size()
	var unlocked: Array = []
	unlocked.resize(prop_count)
	unlocked.fill(false)

	var unlock_events: Array = []           # {time, tier} — tier = reached epoch at that moment
	var entry_times := {1: 0.0}             # tier -> sim-time the run entered it

	var sim_time := 0.0
	var next_wage_tap := 0.0
	var rush_accumulator := 0.0
	var rush_pulse_interval := 1.0 / _tuning.hold_rush_per_second
	var last_tier := game.epoch.current_tier

	while game.epoch.current_tier < EpochCatalog.tier_count() and sim_time < PLAYOUT_TIME_CAP:
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()
		_greedy_build_out(game)
		var targets := _top_running_property_indices(game, RUSH_TOP_N)
		rush_accumulator += TICK_SIZE
		while rush_accumulator >= rush_pulse_interval:
			rush_accumulator -= rush_pulse_interval
			for idx in targets:
				game.hold_rush_property(idx)
		dynasty.tick(TICK_SIZE)
		sim_time += TICK_SIZE

		for i in range(prop_count):
			if not unlocked[i] and (game.economy.properties[i] as PropertyState).units_owned > 0:
				unlocked[i] = true
				unlock_events.append({"time": sim_time, "tier": game.epoch.current_tier})
		if game.epoch.current_tier > last_tier:
			for tier in range(last_tier + 1, game.epoch.current_tier + 1):
				entry_times[tier] = sim_time
			last_tier = game.epoch.current_tier

	return {
		"unlock_events": unlock_events,
		"entry_times": entry_times,
		"sim_time": sim_time,
		"completed": game.epoch.current_tier >= EpochCatalog.tier_count(),
	}


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

## Per-epoch cadence table for one run. An epoch's window runs from its entry to
## the next epoch's entry (or the run end); its beats are the unlock events that
## happened inside that window.
func _print_run_report(result: Dictionary) -> void:
	if not result["completed"]:
		print("  (did not reach the final epoch within the %s cap — read with care)" \
				% _format_duration(PLAYOUT_TIME_CAP))
	print("  epoch     entered    duration   unlocks   drought   median gap   longest gap")
	for tier in range(1, EpochCatalog.tier_count() + 1):
		var stats := _epoch_cadence_stats(result, tier)
		if stats.is_empty():
			continue
		print("  %4d   %9s   %9s   %7d   %7s   %10s   %11s" % [
			tier,
			_format_duration(stats["entered"]),
			_format_duration(stats["duration"]),
			stats["unlocks"],
			_format_duration(stats["drought"]) if stats["drought"] >= 0.0 else "—",
			_format_duration(stats["median_gap"]) if stats["median_gap"] >= 0.0 else "—",
			_format_duration(stats["longest_gap"]) if stats["longest_gap"] >= 0.0 else "—",
		])


## Cadence stats for one epoch window. drought = entry -> first unlock inside the
## window (Earth's is just its first buy, seconds in). Gaps include the run-in
## from the window's opening beat to each later beat; -1 = nothing to measure.
func _epoch_cadence_stats(result: Dictionary, tier: int) -> Dictionary:
	var entry_times: Dictionary = result["entry_times"]
	if not entry_times.has(tier):
		return {}
	var start: float = entry_times[tier]
	var end: float = entry_times[tier + 1] if entry_times.has(tier + 1) else float(result["sim_time"])

	var beat_times: Array = []
	for event in result["unlock_events"]:
		var t: float = event["time"]
		if t >= start and t < end:
			beat_times.append(t)

	var gaps: Array = []
	for i in range(1, beat_times.size()):
		gaps.append(float(beat_times[i]) - float(beat_times[i - 1]))
	gaps.sort()

	return {
		"entered": start,
		"duration": end - start,
		"unlocks": beat_times.size(),
		"drought": (float(beat_times[0]) - start) if not beat_times.is_empty() else -1.0,
		"median_gap": gaps[gaps.size() / 2] if not gaps.is_empty() else -1.0,
		"longest_gap": gaps[gaps.size() - 1] if not gaps.is_empty() else -1.0,
	}


## The side-by-side: for each candidate, the alien-epoch cadence averaged over
## epochs 2..5 (epoch 6 is terminal — the run stops at contact, so its window is
## a stub) against Earth's, which is identical across candidates.
func _print_comparison(summaries: Array) -> void:
	print("")
	print("=== Comparison — Earth beats vs alien beats (epochs 2-5 averaged) ===")
	print("%-36s %9s %11s %12s %11s %11s" % [
		"candidate", "unlocks", "median gap", "longest gap", "drought", "run total",
	])
	for entry in summaries:
		var result: Dictionary = entry["result"]
		var unlocks_total := 0
		var medians: Array = []
		var longests: Array = []
		var droughts: Array = []
		for tier in range(2, EpochCatalog.tier_count()):
			var stats := _epoch_cadence_stats(result, tier)
			if stats.is_empty():
				continue
			unlocks_total += int(stats["unlocks"])
			if float(stats["median_gap"]) >= 0.0:
				medians.append(float(stats["median_gap"]))
			if float(stats["longest_gap"]) >= 0.0:
				longests.append(float(stats["longest_gap"]))
			if float(stats["drought"]) >= 0.0:
				droughts.append(float(stats["drought"]))
		print("%-36s %9s %11s %12s %11s %11s" % [
			entry["label"],
			"%d" % unlocks_total,
			_format_duration(_mean(medians)),
			_format_duration(_mean(longests)),
			_format_duration(_mean(droughts)),
			_format_duration(float(result["sim_time"])),
		])
	print("")
	print("Read: unlocks = alien first-unit beats across epochs 2-5; gaps/drought are")
	print("per-epoch values averaged over those epochs. Earth's own cadence (12 beats,")
	print("front-loaded) is the feel bar the alien columns are compared against.")


func _mean(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())
