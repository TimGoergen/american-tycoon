extends SceneTree

# Headless gate for what a property row DISPLAYS: the income label over the cycle bar, and the bar
# itself. Both had the same class of defect — arithmetically correct, and wrong in front of a player.
#
# Usage: godot --headless --path . --script res://sim/IncomeReadoutTest.gd
#
# WHY THIS EXISTS. The project's binding invariant is that whatever the row shows IS what the player
# earns. The label satisfied that literally and still misled, which is a failure the invariant does
# not catch on its own: it quoted a per-SECOND RATE for a property that produces no rate at all —
# one that pays a fixed lump each time it is tapped and then stops.
#
# Tim, at Luminari with Efficiency upgrades and an ~0.18 s cycle (2026-08-09): "the income display on
# that property says 11.4T/s, but tapping the staff portrait only gains around 2T... the disconnect
# between an income label specific to seconds but the actual income for a single cycle is much less."
#
# Both numbers were right. A tap buys one cycle, one cycle is 0.18 seconds long, so a tap is worth
# 0.18 seconds of the advertised rate — and every Efficiency upgrade widens that gap, because it
# shortens the cycle without changing what a tap pays. The rate was describing STAFFED throughput to
# a player who had no staffer.
#
# So these assertions are about what the label MEANS, not merely whether it is arithmetically true.
#
# PropertyRow is loaded through an assembled path: naming a UI class statically from a sim can create
# a class-resolution cycle that breaks parsing in unrelated files.

var _failures := 0
var _row: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Property row income readout ===\n")

	var row_script: GDScript = load("res://scripts/ui/" + "PropertyRow.gd")
	if row_script == null:
		print("FAILED to load PropertyRow.gd")
		quit(1)
		return
	_row = row_script.new()

	_check_unstaffed_shows_a_bare_amount()
	_check_staffed_reads_as_a_rate()
	_check_rushing_still_reads_as_a_rate()
	_check_unowned_preview_is_unchanged()
	_check_completion_pulse()
	await _check_a_short_cycle_visibly_fills()

	_row.free()

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Tim's case, in the numbers he reported.
func _check_unstaffed_shows_a_bare_amount() -> void:
	print("-- owned but unstaffed: no rate, because there is no rate --")
	# ~2T a cycle, an 0.18 s cycle: the rate would read ~11T/s, which is the misleading figure.
	var text := _readout(2.0e12, 0.18, 0.0, true, false)
	_check("an unstaffed row shows NO rate at all (got '%s')" % text, not text.contains("/"))
	_check("...just the amount one tap pays (got '%s')" % text, text.begins_with("2"))

	# The gap this closes: state the rate that WOULD have been shown, so the test records the size
	# of the lie rather than just the fix.
	var rate := _readout(2.0e12, 0.18, 0.0, true, true)
	print("      (a staffer would make the same property read '%s')" % rate)

	# A LONG unstaffed cycle is deliberately LEFT ALONE. It already reads as its lump plus its wait,
	# which is honest about what a tap pays and additionally tells the player how long they will wait
	# for it — information the per-tap form would throw away to solve a problem this case never had.
	var slow := _readout(2.0e12, 260.0, 0.0, true, false)
	_check("a long unstaffed cycle keeps its lump and its wait (got '%s')" % slow,
		slow.ends_with("4.3m"))


func _check_staffed_reads_as_a_rate() -> void:
	print("\n-- staffed: a staffer restarts it, so a rate is a real throughput --")
	var fast := _readout(2.0e12, 0.18, 0.0, true, true)
	_check("a staffed sub-second cycle reads as a per-second rate (got '%s')" % fast,
		fast.ends_with("/ s"))

	# Unchanged rule (Tim, 2026-07-13): money arriving every few minutes is not a per-second trickle.
	var slow := _readout(2.0e12, 260.0, 0.0, true, true)
	_check("a staffed long cycle still reads as a lump plus its wait (got '%s')" % slow,
		slow.contains("/") and not slow.ends_with("/ s"))


func _check_rushing_still_reads_as_a_rate() -> void:
	print("\n-- being rushed: the held finger restarts it, so the rate is delivered --")
	# An UNSTAFFED property under an active hold: the rush pulses restart it, so for as long as the
	# hold lasts the boosted rate is honest. This must beat the per-tap rule, or the readout would
	# flip to "/ tap" mid-rush and understate what the finger is actually earning.
	var rushed := _readout(2.0e12, 0.18, 8.0, true, false)
	_check("an unstaffed row being rushed reads as a rate, not a bare amount (got '%s')" % rushed,
		rushed.ends_with("/ s"))


func _check_unowned_preview_is_unchanged() -> void:
	print("\n-- unowned: the buy-in preview is not income and keeps its old shape --")
	var preview := _readout(5.0e9, 0.18, 0.0, false, false)
	_check("an unowned row still shows its preview as a rate (got '%s')" % preview,
		preview.ends_with("/ s"))


## THE COMPLETION PULSE (Tim, 2026-08-09): a cycle too short to animate must still be SEEN.
##
## Photon Exchange at Efficiency 10 runs 0.139 s. Pinned, the bar fills at 3 bars/sec, so it reaches
## 0.42 before the cycle ends and the pin releases — "an instantaneous flash of the income bar about
## a third full, and then nothing". These assertions are in FRAMES, because frames are the units the
## bug was made of: the old behaviour was arithmetically perfect and still invisible.
func _check_completion_pulse() -> void:
	print("
-- a cycle too short to animate still finishes visibly --")
	var frame := 1.0 / 60.0

	# Pick up where the real case leaves off: a third of a bar, cycle over, payout banked.
	_row.set("_displayed_cycle_fraction", 0.42)
	_row.set("_finish_lap_pending", true)
	_row.set("_completion_hold_remaining", 0.12)

	var frames_to_full := 0
	for i in range(120):
		if float(_row.get("_displayed_cycle_fraction")) >= 1.0:
			break
		_row.call("_advance_completion_pulse", frame)
		frames_to_full += 1
	_check("the bar reaches FULL rather than stopping partway (%d frames, %.0f ms)"
			% [frames_to_full, frames_to_full * frame * 1000.0],
		is_equal_approx(float(_row.get("_displayed_cycle_fraction")), 1.0))
	_check("...and takes long enough to be seen, not one frame (%d frames)" % frames_to_full,
		frames_to_full >= 4)

	# It must HOLD at full briefly. Arriving and vanishing on the next frame is the same bug in a
	# different costume — the eye needs the bar to rest at the right edge to read it as complete.
	var frames_at_full := 0
	for i in range(120):
		if not bool(_row.get("_finish_lap_pending")):
			break
		_row.call("_advance_completion_pulse", frame)
		frames_at_full += 1
	_check("it holds at full for a beat (%d frames, %.0f ms)"
			% [frames_at_full, frames_at_full * frame * 1000.0],
		frames_at_full >= 4)
	_check("the bar is still full throughout the hold",
		is_equal_approx(float(_row.get("_displayed_cycle_fraction")), 1.0))
	_check("the pulse then releases, so the next tap starts clean",
		not bool(_row.get("_finish_lap_pending")))

	# The whole flourish has to stay SHORT: it is a flash of feedback, not an animation the player
	# waits on. Anything approaching half a second would make rapid tapping feel laggy.
	var total := (frames_to_full + frames_at_full) * frame
	_check("the whole pulse lasts under a third of a second (%.0f ms)" % (total * 1000.0),
		total < 0.34)


## THE SAME BUG, END TO END, through a real row driven frame by frame.
##
## The unit check above proves the pulse ANIMATES; this proves it is WIRED IN. Without it, deleting
## the two lines that start and honour the pulse would leave every assertion above passing while the
## bar on screen stayed broken — which is exactly the shape of failure that let this ship unnoticed
## for months in the first place.
##
## Drives a genuine 0.12 s cycle (Photon Exchange with Efficiency maxed, Tim's own configuration) and
## watches the fill. Against the old code this peaks at 0.35 — "an instantaneous flash of the income
## bar about a third full, and then nothing" — so the assertion is simply that it reaches the end.
func _check_a_short_cycle_visibly_fills() -> void:
	print("
-- end to end: a real 0.12s cycle on a real row --")
	var tuning: TuningConfig = load("res://config/tuning.tres")
	var dynasty := DynastyState.new(ConfigLoader.load_property_configs(), tuning)
	dynasty.upgrades.available = 5.0e9
	for i in range(30):
		if dynasty.upgrades.can_buy("efficiency"):
			dynasty.upgrades.buy("efficiency")
	dynasty.refresh_current_generation_effects()

	var game := dynasty.current
	game.epoch.restore(3)
	var index: int = game.economy.get_property_indices_for_unlock_tier(3)[0]
	var prop := game.economy.properties[index] as PropertyState
	game.economy.cash = 1.0e40
	game.economy.try_buy(index, 15, 3)

	var row_script: GDScript = load("res://scripts/ui/" + "PropertyRow.gd")
	var row = row_script.new()
	row.setup(index, prop, game.economy, game.frenzy, game.epoch, game.rush_momentum,
		game.auto_purchase)
	root.add_child(row)
	await process_frame
	await process_frame

	var length := prop.get_effective_cycle_length()
	_check("the cycle really is too short to animate honestly (%.3fs)" % length, length < 0.2)

	game.tap_property(index)          # one tap: the whole interaction under test
	var frame := 1.0 / 60.0
	var peak := 0.0
	var frames_full := 0
	for i in range(45):
		dynasty.tick(frame)
		row.call("_refresh", frame)
		var fill: float = row.get("_displayed_cycle_fraction")
		peak = maxf(peak, fill)
		if fill >= 0.99:
			frames_full += 1
	_check("ONE TAP fills the bar all the way (peak %.2f)" % peak, peak >= 0.99)
	_check("...and it rests at full long enough to be seen (%d frames)" % frames_full,
		frames_full >= 3)
	_check("...then empties again, ready for the next tap (%.2f)"
			% float(row.get("_displayed_cycle_fraction")),
		float(row.get("_displayed_cycle_fraction")) < 0.01)

	row.queue_free()
	await process_frame


func _readout(per_cycle: float, length: float, rushed_fps: float, owned: bool, staffed: bool) -> String:
	return _row.call("_format_income_readout", per_cycle, length, rushed_fps, owned, staffed)


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
