class_name CarbAutopilot
extends Node

# Desktop diagnosis harness (tuning.carb_autolog = 1): runs a scripted rush scenario
# against the REAL running game — real PropertyRow, real input flags, real layout —
# while logging every frame's carbonation/bar internals to user://carb_log.csv, then
# quits. Exists because the frenzy edge burst survived several model-based fixes:
# probes that replicated the math missed the real branch routing (the per-lap sweep
# reset), and per-frame data caught it in one pass (Tim, 2026-07-08). Keep it — it is
# the regression harness for anything bar/carbonation feel-related.
#
# Timeline (seconds): 0–1 settle · 1 buy + start the target property · 1–4 calm
# observation · 4–14 rush HELD (via the row's secondary-finger path, the same flag a
# real second finger sets) · 14–20 released observation · 20 flush + quit.

## Property index to exercise: Hedge Fund — a long Earth cycle, unstaffed, so payouts
## stop/restart the cycle (the exact shape that exposed the sweep-reset bug).
const TARGET_INDEX := 9
const HOLD_START := 4.0
const HOLD_END := 14.0
const QUIT_AT := 20.0
## The fake finger's index in the row's secondary-targets dict — any int not used by
## a real touch works.
const FAKE_FINGER := 999

var _game: GameState
var _row: PropertyRow
var _elapsed := 0.0
var _bought := false
var _lines: Array[String] = []


## Call before adding to the tree, with the live game and the target property's row.
func setup(game: GameState, row: PropertyRow) -> void:
	_game = game
	_row = row


func _process(delta: float) -> void:
	_elapsed += delta

	# One-time setup beat: grant cash, buy two units, start the cycle.
	if _elapsed >= 1.0 and not _bought:
		_bought = true
		var prop := _game.economy.properties[TARGET_INDEX] as PropertyState
		_game.economy.cash += prop.get_bulk_cost(2) * 2.0
		_game.try_buy(TARGET_INDEX, 2)
		_game.tap_property(TARGET_INDEX)
		_lines.append("t,phase,agit,bub_px,tier,swp_rate,disp,true_frac,running,hold_s")

	if not _bought:
		return

	# Drive the hold through the row's real secondary-finger flag (what a second
	# finger on the portrait sets), so the entire rush path is the shipped one.
	var holding := _elapsed >= HOLD_START and _elapsed < HOLD_END
	if holding:
		_row._secondary_targets[FAKE_FINGER] = "rush"
	else:
		_row._secondary_targets.erase(FAKE_FINGER)

	var prop := _game.economy.properties[TARGET_INDEX] as PropertyState
	var phase := "calm"
	if holding:
		phase = "hold"
	elif _elapsed >= HOLD_END:
		phase = "rel"
	var effective := prop.get_effective_cycle_length()
	var true_frac := prop.cycle_progress / effective if effective > 0.0 else 0.0
	_lines.append("%.3f,%s,%.3f,%.1f,%d,%.4f,%.4f,%.4f,%s,%.2f" % [
		_elapsed, phase,
		_row._cycle_bubbles._agitation,
		_row._cycle_bubbles._base_speed_px,
		_row._cycle_bubbles.tier,
		_row._sweep_rate,
		_row._displayed_cycle_fraction,
		true_frac,
		str(prop.is_cycle_running),
		_row._rush_hold_seconds,
	])

	if _elapsed >= QUIT_AT:
		var file := FileAccess.open("user://carb_log.csv", FileAccess.WRITE)
		for line in _lines:
			file.store_line(line)
		file.close()
		print("CarbAutopilot: wrote %d samples to user://carb_log.csv" % (_lines.size() - 1))
		get_tree().quit()
