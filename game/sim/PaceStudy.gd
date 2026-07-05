extends "res://sim/Sim.gd"

# Core Pace Study — the two-clock tuning readout (Plans/Core_Pace_Study.md).
#
# Usage: godot --headless --path . --script res://sim/PaceStudy.gd
#
# Tim's device feel-test verdict (2026-07-03): the game PROGRESSES too fast, but
# property CYCLE TIMES feel too slow — he wants the pace of mid-game Idle Slayer.
# Those are two different clocks:
#
#   FEEDBACK clock    — how often the screen pays you (cycles completing).
#   PROGRESSION clock — how often you make a meaningful purchase (a new property
#                       rung, a milestone, a staff hire).
#
# Idle Slayer mid-game = fast feedback, slow progression. This study plays the
# same 60-minute active session from $0 under candidate (cycle curve, cost
# growth) pairs and reports both clocks for each, so Tim can pick a pair from
# data instead of another blind retune.
#
# The two levers, and why they separate cleanly:
#   * Cycle compression is applied INCOME-NEUTRAL — a tier whose cycle shrinks
#     by some factor has its income-per-cycle shrunk by the same factor, so
#     income/sec (and therefore the epoch timings and Legacy pacing already
#     tuned) is untouched. Cycle length becomes a pure feel knob.
#   * Cost growth (r0 per-unit ratio, band_step milestone steepening) is what
#     actually slows the progression clock.
#
# WINDOWING (v2 — the first cut measured the wrong thing): a tireless sim thumb
# consumes Earth's whole economy in ~25 minutes and spends the back half of the
# hour buying ALIEN rungs, whose long cycles drowned out the Earth compression
# in a fixed 30–60 m window. So every metric is now anchored to the candidate's
# own EARTH MID-GAME window — from the rung-8 unlock to First Contact — which
# is exactly the stretch of play Tim's complaint describes. The window's own
# LENGTH is the headline progression number: how long does the Earth mid-game
# last before the game moves on?
#
# The sim's player policy is identical across candidates (wage taps, greedy
# best-income-per-dollar buys, greedy hires, greedy frenzy pops, restart idle
# cycles). It is far faster than a human, so read the numbers RELATIVELY
# between candidates, not as literal device minutes. Deliberate scope cuts
# (Plans doc §4): staff level-ups are not in the policy, and cost steepening
# reads WEAKER here than it will on device — the sim's near-permanent frenzy
# makes cash cheap, so treat the r0/band_step spread as a floor on their effect.

## How long each candidate session runs. The sim reaches First Contact well
## inside the hour, so the full Earth arc fits with room to spare.
const SESSION_SECONDS := 3600.0

## The player policy acts (buys, hires, restarts) once per simulated second —
## roughly a human glancing at the ladder — rather than every 0.1 s logic tick.
const ACTION_PERIOD := 1.0

## Feedback-clock samples are taken once per simulated minute.
const SAMPLE_PERIOD := 60.0

## An owned property whose effective cycle is at or under this many seconds
## counts as "humming" — paying often enough that the row always feels alive.
const HUMMING_CYCLE_SEC := 10.0

## The Earth mid-game window opens when this rung (1-based) is first bought —
## rung 8 (Flipping Houses) is where the live ladder's long cycles begin.
const MIDGAME_OPEN_RUNG := 8

# Candidate matrix. cycle_top = compress the 12 Earth base cycles so the top
# tier lands here (seconds), income-neutral; -1.0 = leave the live curve alone.
# r0 / band_step = cost-growth overrides; -1.0 = live value. LIVE (all -1)
# anchors every comparison. The spread brackets the plausible answer: a pure
# feedback fix (B), the feedback fix with rising grades of per-unit cost brake
# (C/D/E) or milestone-band brake (F/G), and the brake on softer/harder cycle
# targets (H/I). v2 added the steeper brakes after the first run showed r0 1.11
# barely moving the sim's overheated progression clock.
const CANDIDATES: Array = [
	{"label": "A LIVE (272s top, r0 1.07, band 1.10)", "cycle_top": -1.0, "r0": -1.0, "band_step": -1.0},
	{"label": "B cycles 60s top", "cycle_top": 60.0, "r0": -1.0, "band_step": -1.0},
	{"label": "C cycles 60s + r0 1.09", "cycle_top": 60.0, "r0": 1.09, "band_step": -1.0},
	{"label": "D cycles 60s + r0 1.11", "cycle_top": 60.0, "r0": 1.11, "band_step": -1.0},
	{"label": "E cycles 60s + r0 1.15", "cycle_top": 60.0, "r0": 1.15, "band_step": -1.0},
	{"label": "F cycles 60s + band_step 1.18", "cycle_top": 60.0, "r0": -1.0, "band_step": 1.18},
	{"label": "G cycles 60s + band_step 1.30", "cycle_top": 60.0, "r0": -1.0, "band_step": 1.30},
	{"label": "H cycles 90s + r0 1.11", "cycle_top": 90.0, "r0": 1.11, "band_step": -1.0},
	{"label": "I cycles 30s + r0 1.11", "cycle_top": 30.0, "r0": 1.11, "band_step": -1.0},
]


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return

	print("=== American Tycoon — Core Pace Study ===")
	print("Two clocks, measured inside each candidate's Earth mid-game window")
	print("(rung-%d unlock -> First Contact). See Plans/Core_Pace_Study.md." % MIDGAME_OPEN_RUNG)
	print("Target (mid-game Idle Slayer): LONGER window + wider purchase gaps, with")
	print("the longest cycle on the board < ~45s and most rungs humming (cycle <= %.0fs)." % HUMMING_CYCLE_SEC)

	var summaries: Array = []
	for candidate in CANDIDATES:
		var result := _play_pace_session(candidate)
		_print_candidate_report(candidate, result)
		summaries.append({"candidate": candidate, "result": result})

	_print_comparison_table(summaries)
	quit()


# ---------------------------------------------------------------------------
# Candidate construction — variant configs, live ones never mutated
# ---------------------------------------------------------------------------

## Duplicate every property config and apply the candidate's levers. The cycle
## taper only touches the 12 Earth tiers (unlock_tier 1): each tier's cycle is
## scaled by pow(cycle_top / live_top, tier_position), a geometric fade from
## ×1.0 at tier 1 to exactly the target at tier 12 — the low rungs are already
## fast and shouldn't move much. Income-per-cycle scales by the same factor so
## every tier's income/sec is bit-identical to live (the neutrality guarantee).
func _make_variant_property_configs(cycle_top: float, r0_value: float) -> Array:
	# The live top-of-ladder cycle the taper is measured against (Executive
	# Assets, the highest Earth tier).
	var earth_configs: Array = []
	for config in _property_configs:
		if (config as PropertyConfig).unlock_tier == 1:
			earth_configs.append(config)
	var live_top := (earth_configs[earth_configs.size() - 1] as PropertyConfig).base_cycle_length

	var variants: Array = []
	for config in _property_configs:
		var live := config as PropertyConfig
		var dup := live.duplicate() as PropertyConfig
		if r0_value > 0.0:
			dup.r0 = r0_value
		if cycle_top > 0.0 and live.unlock_tier == 1:
			var earth_position := earth_configs.find(live)  # 0-based tier position
			var scale: float = pow(cycle_top / live_top, float(earth_position) / float(earth_configs.size() - 1))
			dup.base_cycle_length = live.base_cycle_length * scale
			dup.base_income_per_unit = live.base_income_per_unit * scale
		variants.append(dup)
	return variants


## Duplicate the tuning resource with the candidate's band_step override.
func _make_variant_tuning(band_step_value: float) -> TuningConfig:
	var dup := _tuning.duplicate() as TuningConfig
	if band_step_value > 0.0:
		dup.band_step = band_step_value
	return dup


# ---------------------------------------------------------------------------
# The session — one hour of the fixed player policy, both clocks recorded
# ---------------------------------------------------------------------------

## Play one 60-minute active session under the candidate's configs and return
## everything the report needs: purchase-event times, per-rung unlock times,
## the First Contact moment, and the per-minute feedback samples.
func _play_pace_session(candidate: Dictionary) -> Dictionary:
	var configs := _make_variant_property_configs(candidate["cycle_top"], candidate["r0"])
	var tuning := _make_variant_tuning(candidate["band_step"])
	var game := GameState.new(configs, tuning)
	game.economy.award_cash(tuning.m1_starting_cash)

	var prop_count := game.economy.properties.size()
	# Trackers for spotting purchase events: last seen unit count and milestone
	# band per property.
	var prev_units: Array = []
	var prev_band: Array = []
	for i in range(prop_count):
		prev_units.append(0)
		prev_band.append(0)

	var event_times: Array = []        # every meaningful-purchase moment (may repeat a second)
	var rung_unlock_times: Array = []  # first-unit time per property, -1.0 = never bought
	rung_unlock_times.resize(prop_count)
	rung_unlock_times.fill(-1.0)
	var contact_time := -1.0           # first moment the run reaches epoch 2 (Earth consumed)
	var milestone_count := 0
	var hire_count := 0
	var samples: Array = []            # per-minute feedback snapshots

	var sim_time := 0.0
	var next_wage_tap := 0.0
	var next_action := 0.0
	var next_sample := SAMPLE_PERIOD

	while sim_time < SESSION_SECONDS:
		if sim_time >= next_wage_tap:
			game.tap_wage()
			next_wage_tap += WAGE_TAP_PERIOD
		game.pop_frenzy()

		if sim_time >= next_action:
			_greedy_buy_spree(game)

			# Greedy hires: a staffer means the property runs itself, always worth it —
			# and a hire is one of the meaningful purchases we count. (Hiring is level 1
			# of the staff ladder; deeper levels stay a known scope cut — see header.)
			for i in range(prop_count):
				var prop := game.economy.properties[i] as PropertyState
				if prop.units_owned > 0 and not prop.is_staffed:
					if game.try_buy_staff_level(i):
						hire_count += 1
						event_times.append(sim_time)

			# Spot new-rung and milestone purchases made by the spree.
			for i in range(prop_count):
				var prop := game.economy.properties[i] as PropertyState
				if prop.units_owned > 0 and prev_units[i] == 0:
					rung_unlock_times[i] = sim_time
					event_times.append(sim_time)
				var band := CostCurve.get_band(maxi(prop.units_owned, 1))
				if prop.units_owned > 0 and band > prev_band[i]:
					milestone_count += band - prev_band[i]
					event_times.append(sim_time)
				prev_units[i] = prop.units_owned
				prev_band[i] = band

			# The active player restarts every idle (unstaffed) cycle.
			for i in range(prop_count):
				var prop := game.economy.properties[i] as PropertyState
				if prop.units_owned > 0 and not prop.is_cycle_running:
					game.tap_property(i)

			if contact_time < 0.0 and game.epoch.current_tier >= 2:
				contact_time = sim_time

			next_action += ACTION_PERIOD

		if sim_time >= next_sample:
			samples.append(_take_feedback_sample(game, sim_time))
			next_sample += SAMPLE_PERIOD

		game.tick(TICK_SIZE)
		sim_time += TICK_SIZE

	return {
		"event_times": event_times,
		"rung_unlock_times": rung_unlock_times,
		"contact_time": contact_time,
		"milestone_count": milestone_count,
		"hire_count": hire_count,
		"samples": samples,
		"final_ips": game.economy.get_total_income_per_sec(),
		"final_cash": game.economy.cash,
	}


## One feedback-clock snapshot: how alive does the board look right now?
func _take_feedback_sample(game: GameState, sim_time: float) -> Dictionary:
	var frontier_cycle := 0.0
	var longest_cycle := 0.0
	var owned := 0
	var humming := 0
	for prop in game.economy.properties:
		var p := prop as PropertyState
		if p.units_owned == 0:
			continue
		owned += 1
		var cycle := p.get_effective_cycle_length()
		frontier_cycle = cycle  # properties are ladder-ordered, so the last owned one is the frontier
		longest_cycle = maxf(longest_cycle, cycle)
		if cycle <= HUMMING_CYCLE_SEC:
			humming += 1
	return {
		"time": sim_time,
		"frontier_cycle": frontier_cycle,
		"longest_cycle": longest_cycle,
		"humming_share": float(humming) / float(owned) if owned > 0 else 0.0,
	}


# ---------------------------------------------------------------------------
# The Earth mid-game window — every metric is read inside this span
# ---------------------------------------------------------------------------

## [start, end) of the candidate's Earth mid-game: rung-8 unlock up to First
## Contact. Falls back to the session end when either edge never happened.
func _midgame_window(result: Dictionary) -> Array:
	var rung_unlock_times: Array = result["rung_unlock_times"]
	var open_time: float = rung_unlock_times[MIDGAME_OPEN_RUNG - 1]
	var start: float = open_time if open_time >= 0.0 else SESSION_SECONDS
	var contact: float = result["contact_time"]
	var end: float = contact if contact >= 0.0 else SESSION_SECONDS
	return [start, maxf(start, end)]


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

func _print_candidate_report(candidate: Dictionary, result: Dictionary) -> void:
	print("")
	print("--- %s ---" % candidate["label"])

	# Rung ladder: when each property tier was first bought, plus the contact beat.
	var ladder_parts: Array = []
	var rung_unlock_times: Array = result["rung_unlock_times"]
	for i in range(rung_unlock_times.size()):
		if rung_unlock_times[i] >= 0.0:
			ladder_parts.append("%d@%s" % [i + 1, _format_clock(rung_unlock_times[i])])
	print("  rung unlocks: %s" % " ".join(ladder_parts))

	var window := _midgame_window(result)
	var contact: float = result["contact_time"]
	print("  Earth mid-game: opens %s | First Contact %s | window %s" % [
		_format_clock(window[0]) if window[0] < SESSION_SECONDS else "never",
		_format_clock(contact) if contact >= 0.0 else "never",
		_format_gap(window[1] - window[0]),
	])

	var moments := _unique_sorted_times(result["event_times"])
	print("  purchases: %d moments (%d milestones, %d hires) | median gap early: %s | mid-game: %s" % [
		moments.size(),
		result["milestone_count"],
		result["hire_count"],
		_format_gap(_median_gap_in_window(moments, 0.0, window[0])),
		_format_gap(_median_gap_in_window(moments, window[0], window[1])),
	])

	var feel := _average_samples_in_window(result["samples"], window[0], window[1])
	print("  feedback (mid-game avg): frontier cycle %.1fs | longest cycle %.1fs | humming %d%%" % [
		feel["frontier_cycle"], feel["longest_cycle"], int(feel["humming_share"] * 100.0),
	])


## The side-by-side table — the thing Tim actually picks from. All clock
## columns are read inside each candidate's own Earth mid-game window.
func _print_comparison_table(summaries: Array) -> void:
	print("")
	print("=== Comparison — Earth mid-game window (rung-%d unlock -> First Contact) ===" % MIDGAME_OPEN_RUNG)
	print("%-38s %8s %8s %8s %8s %10s %10s %8s" % [
		"candidate", "opens", "contact", "window", "gap", "frontier", "longest", "humming",
	])
	for entry in summaries:
		var result: Dictionary = entry["result"]
		var window := _midgame_window(result)
		var contact: float = result["contact_time"]
		var moments := _unique_sorted_times(result["event_times"])
		var feel := _average_samples_in_window(result["samples"], window[0], window[1])
		print("%-38s %8s %8s %8s %8s %9.1fs %9.1fs %7d%%" % [
			entry["candidate"]["label"],
			_format_clock(window[0]) if window[0] < SESSION_SECONDS else "never",
			_format_clock(contact) if contact >= 0.0 else "never",
			_format_gap(window[1] - window[0]),
			_format_gap(_median_gap_in_window(moments, window[0], window[1])),
			feel["frontier_cycle"],
			feel["longest_cycle"],
			int(feel["humming_share"] * 100.0),
		])
	print("")
	print("Read: a LONGER window + wider gap = slower progression; a short longest-cycle")
	print("+ high humming%% = faster feedback. Idle Slayer mid-game wants both at once.")


# ---------------------------------------------------------------------------
# Small math/format helpers
# ---------------------------------------------------------------------------

## Collapse purchase events into unique "shop moments": one entry per simulated
## second that had any purchase, sorted ascending. A burst (buying to a
## milestone crosses it AND unlocks the next rung) counts as one trip to the shop.
func _unique_sorted_times(event_times: Array) -> Array:
	var seen := {}
	for t in event_times:
		seen[snappedf(t, 1.0)] = true
	var moments := seen.keys()
	moments.sort()
	return moments


## Median gap between consecutive purchase moments whose LATER moment falls in
## [window_start, window_end). -1.0 when the window has no gaps (fewer than two
## qualifying moments) — a stall, reported as such rather than as zero.
func _median_gap_in_window(moments: Array, window_start: float, window_end: float) -> float:
	var gaps: Array = []
	for i in range(1, moments.size()):
		var t: float = moments[i]
		if t >= window_start and t < window_end:
			gaps.append(t - moments[i - 1])
	if gaps.is_empty():
		return -1.0
	gaps.sort()
	return gaps[gaps.size() / 2]


## Average the feedback samples taken inside [window_start, window_end).
func _average_samples_in_window(samples: Array, window_start: float, window_end: float) -> Dictionary:
	var count := 0
	var totals := {"frontier_cycle": 0.0, "longest_cycle": 0.0, "humming_share": 0.0}
	for sample in samples:
		var t: float = sample["time"]
		if t >= window_start and t < window_end:
			count += 1
			for key in totals:
				totals[key] += sample[key]
	if count == 0:
		return totals
	for key in totals:
		totals[key] /= float(count)
	return totals


## Compact m:ss stamp for the rung-unlock ladder (e.g. 754.0 -> "12:34").
func _format_clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## A purchase gap or window length for the tables: seconds under a minute,
## minutes above, "stall" when there was nothing to measure.
func _format_gap(gap_seconds: float) -> String:
	if gap_seconds < 0.0:
		return "stall"
	if gap_seconds < 60.0:
		return "%.0fs" % gap_seconds
	return "%.1fm" % (gap_seconds / 60.0)
