extends SceneTree

# Headless checks for Money's display formatting — added with the 2026-07-03 suffix
# extension (K..T grew to K..Dd) so the ladder's order and thresholds are pinned by
# a test, not just eyeballed. Run:
#   godot --headless --path . --script res://sim/MoneyTest.gd

var _failures := 0


func _initialize() -> void:
	print("=== Money display checks ===")

	# display(): the compact cost/income format.
	_check_display(0.0, "$0")
	_check_display(950.0, "$950")
	_check_display(14_300.0, "$14.3K")
	_check_display(2_000_000.0, "$2M")
	_check_display(14_270_000_000_000.0, "$14.3T")
	# The rungs past T — the deep-epoch fix. Before this, everything rendered as "…T".
	_check_display(4.2e15, "$4.2Qa")
	_check_display(2.51748e19, "$25.2Qi")   # was the unreadable "$25174800T"
	_check_display(2.5e21, "$2.5Sx")
	_check_display(7.0e24, "$7Sp")
	_check_display(1.5e27, "$1.5Oc")
	_check_display(3.0e30, "$3No")
	_check_display(6.0e33, "$6Dc")
	_check_display(9.0e36, "$9Ud")
	_check_display(2.5e39, "$2.5Dd")
	# Past Dd — the ×16807/epoch scaling reaches these by epoch ~8; before 2026-07-26
	# they piled digits on "Dd" ($2500Dd) instead of climbing to the next named rung.
	_check_display(2.5e42, "$2.5Td")
	_check_display(3.0e54, "$3Spd")
	_check_display(7.0e63, "$7Vg")
	_check_display(4.2e93, "$4.2Tg")
	_check_display(-14_300.0, "-$14.3K")

	# display(0): whole-number abbreviations (property income readout).
	_check(Money.of(14_700_000.0).display(0), "$15M", "display(0) rounds to whole units")
	_check(Money.of(2.5e21).display(0), "$3Sx", "display(0) rounds past T too")

	# display_cash(): the balance format — spaced suffix, up to two decimals with
	# trailing zeros dropped (no ".0"/".00" noise anywhere on screen; Tim, 2026-07-03).
	# Cents under $1,000 keep their conventional two digits ($5.50, not $5.5).
	_check(Money.of(5.5).display_cash(), "$5.50", "cash shows cents under $1,000")
	_check(Money.of(1_250.0).display_cash(), "$1,250", "cash groups thousands")
	_check(Money.of(1_000_000.0).display_cash(), "$1 M", "whole cash drops the decimals")
	_check(Money.of(1_500_000.0).display_cash(), "$1.5 M", "cash drops only trailing zeros")
	_check(Money.of(1.23e15).display_cash(), "$1.23 Qa", "cash uses the extended ladder")
	_check(Money.of(2.5e21).display_cash(), "$2.5 Sx", "cash agrees with display on suffixes")

	# trim(): the shared "decimal only when it's non-zero" formatter every other
	# on-screen number routes through (cycle durations, TURBO multipliers, ×N effects).
	_check(Money.trim(2.0, 1), "2", "trim drops a whole number's .0")
	_check(Money.trim(4.3, 1), "4.3", "trim keeps a real decimal")
	_check(Money.trim(1.5, 2), "1.5", "trim(2dp) drops only the trailing zero")
	_check(Money.trim(1.06, 2), "1.06", "trim(2dp) keeps two real decimals")
	_check(Money.trim(14.7, 0), "15", "trim(0dp) rounds to whole")

	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit()
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _check_display(v: float, expected: String) -> void:
	_check(Money.of(v).display(), expected, "display(%s)" % str(v))


func _check(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		print("  [PASS] %s -> %s" % [label, actual])
	else:
		print("  [FAIL] %s -> %s (expected %s)" % [label, actual, expected])
		_failures += 1
