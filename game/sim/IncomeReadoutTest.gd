extends SceneTree

# Headless gate for the property row's income readout — the label over the cycle bar.
#
# Usage: godot --headless --path . --script res://sim/IncomeReadoutTest.gd
#
# WHY THIS EXISTS. The project's binding invariant is that whatever the row shows IS what the player
# earns. The label satisfied that literally and still misled, which is a failure the invariant does
# not catch on its own: it quoted a per-SECOND rate for a property that only pays when TAPPED.
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

	_check_unstaffed_reads_per_tap()
	_check_staffed_reads_as_a_rate()
	_check_rushing_still_reads_as_a_rate()
	_check_unowned_preview_is_unchanged()

	_row.free()

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Tim's case, in the numbers he reported.
func _check_unstaffed_reads_per_tap() -> void:
	print("-- owned but unstaffed: the honest unit is the TAP --")
	# ~2T a cycle, an 0.18 s cycle: the rate would read ~11T/s, which is the misleading figure.
	var text := _readout(2.0e12, 0.18, 0.0, true, false)
	_check("an unstaffed row reads per TAP, not per second (got '%s')" % text,
		text.ends_with("/ tap"))
	_check("...and quotes what one tap actually pays (got '%s')" % text, text.begins_with("2"))

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
		not slow.ends_with("/ s") and not slow.ends_with("/ tap"))


func _check_rushing_still_reads_as_a_rate() -> void:
	print("\n-- being rushed: the held finger restarts it, so the rate is delivered --")
	# An UNSTAFFED property under an active hold: the rush pulses restart it, so for as long as the
	# hold lasts the boosted rate is honest. This must beat the per-tap rule, or the readout would
	# flip to "/ tap" mid-rush and understate what the finger is actually earning.
	var rushed := _readout(2.0e12, 0.18, 8.0, true, false)
	_check("an unstaffed row being rushed reads as a rate, not per tap (got '%s')" % rushed,
		rushed.ends_with("/ s"))


func _check_unowned_preview_is_unchanged() -> void:
	print("\n-- unowned: the buy-in preview is not income and keeps its old shape --")
	var preview := _readout(5.0e9, 0.18, 0.0, false, false)
	_check("an unowned row does NOT claim a per-tap value (got '%s')" % preview,
		not preview.ends_with("/ tap"))


func _readout(per_cycle: float, length: float, rushed_fps: float, owned: bool, staffed: bool) -> String:
	return _row.call("_format_income_readout", per_cycle, length, rushed_fps, owned, staffed)


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
