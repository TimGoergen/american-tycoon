extends SceneTree

# Headless checks for Money's display formatting — added with the 2026-07-03 suffix
# extension (K..T grew to K..Dd) so the ladder's order and thresholds are pinned by
# a test, not just eyeballed. Extended 2026-07-31 for the player-selectable currency
# format (Roadmap §6): ABBREVIATED / ALPHABET / SCIENTIFIC. Run:
#   godot --headless --path . --script res://sim/MoneyTest.gd
#
# STATE-LEAK WARNING. `Money.format_mode` is a STATIC — it is global to the whole run.
# A check block that set it and forgot to put it back would silently re-interpret every
# later assertion (the ABBREVIATED expectations would start comparing against alphabet
# labels and "fail" for the wrong reason). Three defences, all deliberate:
#   1. Nothing in this file assigns Money.format_mode directly. Every mode-specific block
#      goes through _enter_mode()/_leave_mode(), which restores the DEFAULT unconditionally.
#   2. _leave_mode() asserts the restore actually happened, so a future edit that breaks the
#      pairing fails loudly here rather than as a mystery failure 200 lines later.
#   3. The whole ABBREVIATED block is a function, and it is run TWICE: once first (its
#      original position) and once at the very end as a leak sentinel. If any block above
#      leaves the mode dirty, the second pass fails.

var _failures := 0


## The format every block in this harness returns to. It is the TEST's baseline, deliberately
## NOT "whatever Money's product default happens to be": the shipped default moved from
## ABBREVIATED to ALPHABET on 2026-08-05 (Tim), and when the two concepts were the same value,
## that change silently re-ran the entire ABBREVIATED block in alphabet mode — every expectation
## comparing "$4.2Qa" against "$4.2aa". Pinning the baseline here means a future default change
## can never reinterpret these checks again; the default itself is asserted separately below.
const BASELINE_FORMAT := Money.Format.ABBREVIATED


func _initialize() -> void:
	print("=== Money display checks ===")

	# The shipped default is a real part of the spec (a fresh game must open in letters), so
	# assert it BEFORE pinning the baseline — after this line the ambient value is the
	# harness's, not the product's.
	_check(str(Money.format_mode), str(Money.Format.ALPHABET),
		"the shipped default format is ALPHABET (a fresh game opens in letters)")
	Money.format_mode = BASELINE_FORMAT

	# ── ABBREVIATED: the original checks, unchanged ───────────────────────────────────
	_run_abbreviated_checks("first pass")

	# ── The three-mode checks (each restores the default before returning) ────────────
	_check_alphabet_maps_every_rung()
	_check_alphabet_spot_values()
	_check_scientific_mantissa_range()
	_check_scientific_values()
	_check_modes_agree_on_rung()
	_check_formatters_agree_on_notation()
	_check_small_values_identical_across_modes()
	_check_negatives_in_every_mode()

	# ── Leak sentinel: the ABBREVIATED expectations must still hold after all of the
	# above. If a mode block leaked, these fail and name the culprit by their labels.
	_check_mode_is_default("after all mode-specific blocks")
	_run_abbreviated_checks("second pass (leak sentinel)")

	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)   # explicit: the runner judges by exit code
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


# ──────────────────────────────────────────────────────────────────────────────────────
# ABBREVIATED — the pre-existing regression set, verbatim, wrapped in a function so it
# can be replayed at the end of the run as a state-leak sentinel.
# ──────────────────────────────────────────────────────────────────────────────────────
func _run_abbreviated_checks(pass_label: String) -> void:
	print("-- ABBREVIATED (%s) --" % pass_label)

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
	_check(Money.of(950.0).display_cash(), "$950", "cash under $1,000 stays exact")
	# The 2026-07-31 change: cash abbreviates from $1,000, like display(). The old
	# comma-grouped thousands range ("$1,250", "$18,610") is retired.
	_check(Money.of(1_250.0).display_cash(), "$1.25 K", "cash abbreviates from $1,000")
	_check(Money.of(18_610.0).display_cash(), "$18.61 K", "Tim's balance now reads in K")
	_check(Money.of(2_300.0).display_cash(), "$2.3 K", "Tim's example: 2,300 is 2.3 K")
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


# ──────────────────────────────────────────────────────────────────────────────────────
# ALPHABET
# ──────────────────────────────────────────────────────────────────────────────────────

## The invariant that stops the alphabet mapping from ever drifting away from the ladder:
## walk all 40 rungs of Money.SUFFIXES programmatically and, for each, compare the label the
## formatter actually prints against the label computed HERE from the rung's index.
## Nothing below is hand-typed, so adding a rung to the ladder extends this test for free.
func _check_alphabet_maps_every_rung() -> void:
	print("-- ALPHABET rung-for-rung (all %d rungs) --" % Money.SUFFIXES.size())
	_enter_mode(Money.Format.ALPHABET)

	for i in Money.SUFFIXES.size():
		var rung: Dictionary = Money.SUFFIXES[i]
		var scale: float = rung["scale"]
		var expected_label := _expected_label_for_rung(i)

		# 1.5× the rung's scale: comfortably inside this rung (the next one up is 1000×
		# away) and far from any rounding boundary that could bump the mantissa.
		var value := scale * 1.5

		var tight := Money.of(value).display()
		_check(_trailing_label(tight), expected_label,
			"display() rung %d (%s, %s) -> alphabet %s" % [i, rung["suffix"], _sci_str(scale), expected_label])

		# display_cash() must land on the SAME label for the same rung — since 2026-07-31 it
		# abbreviates from $1,000 too, so every rung on the ladder is checked in both
		# formatters with no exceptions.
		var spaced := Money.of(value).display_cash()
		_check(_trailing_label(spaced), expected_label,
			"display_cash() rung %d (%s) -> alphabet %s" % [i, rung["suffix"], expected_label])

	_leave_mode()


## The anchors the spec states in words, checked as whole strings so a mapping that is
## merely self-consistent (but shifted) still gets caught. Tim, 2026-07-31: ALPHABET keeps
## K / M / B / T and starts the generic letters at QUADRILLIONS.
func _check_alphabet_spot_values() -> void:
	print("-- ALPHABET anchors --")
	_enter_mode(Money.Format.ALPHABET)

	# The four familiar rungs are NOT lettered — they read exactly as in ABBREVIATED.
	_check(Money.of(14_300.0).display(), "$14.3K", "rung 39 (K, 1e3) keeps 'K'")
	_check(Money.of(2_000_000.0).display(), "$2M", "rung 38 (M, 1e6) keeps 'M'")
	_check(Money.of(7.0e9).display(), "$7B", "rung 37 (B, 1e9) keeps 'B'")
	_check(Money.of(1.3e12).display(), "$1.3T", "rung 36 (T, 1e12) keeps 'T'")
	# ...and the letters begin at the rung above T.
	_check(Money.of(4.2e15).display(), "$4.2aa", "rung 35 (Qa, 1e15) starts the letters at 'aa'")
	_check(Money.of(2.5e18).display(), "$2.5ab", "rung 34 (Qi, 1e18) is 'ab'")
	_check(Money.of(2.5e21).display(), "$2.5ac", "rung 33 (Sx, 1e21) is 'ac'")
	_check(Money.of(1.5e120).display(), "$1.5bj", "rung 0 (NoTg, 1e120) is 'bj'")
	_check(Money.of(1.5e90).display(), "$1.5" + _expected_alphabet_label(25), "the 26th lettered rung is 'az'")
	_check(Money.of(1.5e93).display(), "$1.5ba", "the 27th lettered rung rolls over to 'ba'")
	_check(Money.of(1.5e15).display_cash(), "$1.5 aa", "cash keeps the suffix slot's space")
	_check(Money.of(1_500_000.0).display_cash(), "$1.5 M", "cash keeps 'M' in alphabet mode")

	_leave_mode()


# ──────────────────────────────────────────────────────────────────────────────────────
# SCIENTIFIC
# ──────────────────────────────────────────────────────────────────────────────────────

## Mantissa must ALWAYS satisfy 1 <= m < 10 — including after the 2-decimal rounding, which
## is the case that actually bites (9.999 rounds to "10.00" and would print "$10e17").
## The mantissa is PARSED BACK out of the rendered string, so this measures what the player
## sees rather than what the helper computed internally.
func _check_scientific_mantissa_range() -> void:
	print("-- SCIENTIFIC mantissa in [1, 10) across every rung --")
	_enter_mode(Money.Format.SCIENTIFIC)

	var factors := [1.0, 4.2, 9.99, 9.995, 9.999]
	var sampled := 0
	var in_range := 0
	for i in Money.SUFFIXES.size():
		var scale: float = Money.SUFFIXES[i]["scale"]
		for factor in factors:
			var value: float = scale * factor
			sampled += 1
			if _check_mantissa_in_range(Money.of(value).display(),
					"display(%s x %s)" % [_sci_str(scale), str(factor)]):
				in_range += 1
			# display_cash() abbreviates from $1,000 too (2026-07-31), so every rung of the
			# ladder is sampled in both formatters.
			if value >= 1_000.0:
				sampled += 1
				if _check_mantissa_in_range(Money.of(value).display_cash(),
						"display_cash(%s x %s)" % [_sci_str(scale), str(factor)]):
					in_range += 1

	# One tally instead of 400 PASS lines; any failure printed itself above.
	_check(str(in_range), str(sampled),
		"%d of %d sampled renderings have a mantissa in [1, 10)" % [in_range, sampled])

	_leave_mode()


func _check_scientific_values() -> void:
	print("-- SCIENTIFIC rendering --")
	_enter_mode(Money.Format.SCIENTIFIC)

	# The rounding boundary, spelled out: 9.999e17 must carry to the next magnitude.
	_check(Money.of(9.999e17).display(), "$1e18", "9.999e17 rounds up to $1e18, never $10e17")
	_check(Money.of(9.999e17).display_cash(), "$1e18", "cash rounds the same way")
	# Lowercase 'e', no '+', trailing zeros trimmed by the shared trim().
	_check(Money.of(4.2e18).display(), "$4.2e18", "mantissa keeps one real decimal")
	_check(Money.of(1.0e18).display(), "$1e18", "a whole mantissa drops its decimals")
	_check(Money.of(1.23e15).display_cash(), "$1.23e15", "cash keeps two real decimals")
	_check(Money.of(1_500_000.0).display_cash(), "$1.5e6", "no space before the 'e'")
	# The intended consequence of the threshold rule: both formatters abbreviate from
	# $1,000, so SCIENTIFIC takes over from $1,000 in both.
	_check(Money.of(14_300.0).display(), "$1.43e4", "display() goes scientific from $1,000")
	# Tim's exact case, as it now renders: the cost button and the balance header agree.
	_check(Money.of(5_510.0).display(), "$5.51e3", "the cost button Tim saw")
	_check(Money.of(18_610.0).display_cash(), "$1.86e4", "the balance beside it, no longer '18,610'")

	_leave_mode()


# ──────────────────────────────────────────────────────────────────────────────────────
# The never-disagree invariant
# ──────────────────────────────────────────────────────────────────────────────────────

## All three modes must describe the SAME magnitude rung for a given value: the abbreviated
## suffix, the alphabet label and the scientific exponent are three renderings of one fact.
## Values are chosen mid-rung (never within rounding distance of the next one), because at a
## boundary like 9.999e17 the modes legitimately differ: scientific rounds the mantissa up a
## decade while the abbreviation stays on its rung as "999.9Qa".
func _check_modes_agree_on_rung() -> void:
	print("-- all three modes agree on the rung --")

	var values := [
		1_500.0, 14_300.0, 2_500_000.0, 7.0e9, 1.0e12, 4.2e15, 2.5e21,
		7.0e33, 1.0e45, 2.5e60, 7.0e75, 1.0e93, 4.2e105, 2.5e120,
	]
	for value in values:
		var expected_rung := _rung_index_for(value)
		var expected_alphabet := _expected_label_for_rung(expected_rung)

		_enter_mode(Money.Format.ABBREVIATED)
		var abbreviated_label := _trailing_label(Money.of(value).display())
		_leave_mode()

		_enter_mode(Money.Format.ALPHABET)
		var alphabet_label := _trailing_label(Money.of(value).display())
		_leave_mode()

		_enter_mode(Money.Format.SCIENTIFIC)
		var scientific := Money.of(value).display()
		_leave_mode()

		var scientific_rung := _rung_index_for_exponent(_exponent_of(scientific))

		_check(abbreviated_label, str(Money.SUFFIXES[expected_rung]["suffix"]),
			"%s: abbreviated names rung %d" % [_sci_str(value), expected_rung])
		_check(alphabet_label, expected_alphabet,
			"%s: alphabet names rung %d" % [_sci_str(value), expected_rung])
		_check(str(scientific_rung), str(expected_rung),
			"%s: scientific exponent (%s) names rung %d" % [_sci_str(value), scientific, expected_rung])


# ──────────────────────────────────────────────────────────────────────────────────────
# The two formatters never use two different NOTATION SYSTEMS at once
# ──────────────────────────────────────────────────────────────────────────────────────

## Regression for the bug Tim hit on 2026-07-31: in SCIENTIFIC, a property's cost button
## showed "$5.51e3" while the cash header showed "18,610" — two different notation systems on
## screen for the same order of magnitude, because display() abbreviated from $1,000 while
## display_cash() held out until $1,000,000. Tim: "I dislike having materially different text
## that means the same thing."
##
## So in EVERY mode the two formatters must agree on WHICH SYSTEM they are using: both a
## mantissa-plus-suffix, or both scientific, never one of each. They may still differ in
## precision and spacing ("$2.3K" vs "$2.3 K") — that is not a different system.
##
## The $1K–$1M band is where the two used to disagree, so it is sampled densely; a few values
## above and below confirm the rule holds off the old fault line too.
func _check_formatters_agree_on_notation() -> void:
	print("-- display() and display_cash() use the same notation system --")

	var values := [
		# Tim's exact case: the cost he saw and the balance he saw.
		5_510.0, 18_610.0,
		# The rest of the old disagreement band, plus its two edges.
		1_000.0, 2_300.0, 14_300.0, 250_000.0, 999_999.0,
		# Off the fault line, in both directions.
		999.99, 1_500_000.0, 4.2e15, 2.5e120,
	]
	for mode in [Money.Format.ABBREVIATED, Money.Format.ALPHABET, Money.Format.SCIENTIFIC]:
		_enter_mode(mode)
		for value in values:
			var tight := Money.of(value).display()
			var spaced := Money.of(value).display_cash()
			_check(_notation_of(tight), _notation_of(spaced),
				"mode %d, %s: display()=%s and display_cash()=%s share a notation"
					% [mode, _sci_str(value), tight, spaced])
		_leave_mode()


## Which notation system a rendered string uses: "suffix" (mantissa + rung label, e.g.
## "$14.3K" / "$1.5 ab"), "scientific" ("$1.43e4"), or "plain" (bare digits, "$950").
##
## The trailing label is tested FIRST and the "e" only after: the alphabet labels "ae" and
## "be" contain an "e", so a string ending in letters is a suffix rendering no matter what
## characters it holds. A scientific rendering always ends in the exponent's digits.
func _notation_of(text: String) -> String:
	if _trailing_label(text) != "":
		return "suffix"
	if text.find("e") != -1:
		return "scientific"
	return "plain"


# ──────────────────────────────────────────────────────────────────────────────────────
# Small values: byte-identical in all three modes
# ──────────────────────────────────────────────────────────────────────────────────────

## The threshold rule: a mode replaces the abbreviation exactly where an abbreviation would
## have appeared and changes NOTHING below it. Since 2026-07-31 BOTH formatters abbreviate
## from $1,000, so both are byte-identical across the three modes below $1,000 — cents,
## whole dollars and negatives alike — and neither is below it above $1,000.
func _check_small_values_identical_across_modes() -> void:
	print("-- small values are byte-identical in all three modes --")

	# display(): below its $1,000 abbreviation threshold.
	for value in [0.0, 5.5, 42.0, 950.0, 999.99, -0.5, -950.0]:
		_check_all_modes_identical(value, false, "display(%s)" % str(value))

	# display_cash(): below the SAME $1,000 threshold, cents included.
	for value in [0.0, 5.5, 950.0, 999.99, -999.99, -5.5]:
		_check_all_modes_identical(value, true, "display_cash(%s)" % str(value))


## Render one value in all three modes and require the three strings to be equal.
func _check_all_modes_identical(value: float, use_cash: bool, label: String) -> void:
	var rendered := []
	for mode in [Money.Format.ABBREVIATED, Money.Format.ALPHABET, Money.Format.SCIENTIFIC]:
		_enter_mode(mode)
		rendered.append(Money.of(value).display_cash() if use_cash else Money.of(value).display())
		_leave_mode()

	if rendered[0] == rendered[1] and rendered[1] == rendered[2]:
		print("  [PASS] %s identical in all modes -> %s" % [label, rendered[0]])
	else:
		print("  [FAIL] %s differs by mode -> abbreviated=%s alphabet=%s scientific=%s"
			% [label, rendered[0], rendered[1], rendered[2]])
		_failures += 1


# ──────────────────────────────────────────────────────────────────────────────────────
# Negatives
# ──────────────────────────────────────────────────────────────────────────────────────

## Every mode keeps the "-$" prefix — the minus goes OUTSIDE the dollar sign, and no mode
## is allowed to lose the sign or move it (e.g. "$-4.2e18").
func _check_negatives_in_every_mode() -> void:
	print("-- negatives keep the '-$' prefix in every mode --")

	_enter_mode(Money.Format.ABBREVIATED)
	_check(Money.of(-14_300.0).display(), "-$14.3K", "abbreviated display() negative")
	_check(Money.of(-4.2e18).display_cash(), "-$4.2 Qi", "abbreviated display_cash() negative")
	_leave_mode()

	_enter_mode(Money.Format.ALPHABET)
	_check(Money.of(-14_300.0).display(), "-$14.3K", "alphabet display() negative keeps 'K'")
	_check(Money.of(-4.2e18).display_cash(), "-$4.2 ab", "alphabet display_cash() negative")
	_leave_mode()

	_enter_mode(Money.Format.SCIENTIFIC)
	_check(Money.of(-14_300.0).display(), "-$1.43e4", "scientific display() negative")
	_check(Money.of(-4.2e18).display_cash(), "-$4.2e18", "scientific display_cash() negative")
	_leave_mode()


# ──────────────────────────────────────────────────────────────────────────────────────
# Mode handling — the only place this file touches Money.format_mode
# ──────────────────────────────────────────────────────────────────────────────────────

## Entering asserts the mode is currently the BASELINE — i.e. whoever ran last put it back.
## This is the check that actually catches a missing _leave_mode(): the end-of-run sentinel
## alone does NOT, because the very next block's _leave_mode() would quietly clean up after
## the offender. (Verified by deleting a _leave_mode() and re-running: without this guard the
## run still passed; with it, the next block fails and names the leak.)
func _enter_mode(mode: int) -> void:
	if Money.format_mode != BASELINE_FORMAT:
		print("  [FAIL] format_mode was %d on entry — a previous block skipped _leave_mode()"
			% Money.format_mode)
		_failures += 1
	Money.format_mode = mode


## Always restores the BASELINE (not "whatever was there before"), so a missing _leave_mode()
## cannot be papered over by a later block's restore, and verifies the restore took.
func _leave_mode() -> void:
	Money.format_mode = BASELINE_FORMAT
	if Money.format_mode != BASELINE_FORMAT:
		print("  [FAIL] _leave_mode() did not restore the harness baseline")
		_failures += 1


func _check_mode_is_default(where: String) -> void:
	if Money.format_mode == BASELINE_FORMAT:
		print("  [PASS] format_mode is back to the harness baseline %s" % where)
	else:
		print("  [FAIL] format_mode LEAKED (%d) %s" % [Money.format_mode, where])
		_failures += 1


# ──────────────────────────────────────────────────────────────────────────────────────
# Helpers used by the assertions (all independent of Money's own implementations)
# ──────────────────────────────────────────────────────────────────────────────────────

## How many bottom rungs of SUFFIXES keep their real suffix in ALPHABET mode: K, M, B, T.
## Spelled out here rather than read from Money, so a change to Money's own constant cannot
## silently move this test's expectations with it.
const ALPHABET_FIRST_RUNG := 4


## The label ALPHABET mode must print for rung `i` of Money.SUFFIXES, derived here from the
## rung's index alone. SUFFIXES is LARGEST first while the alphabet counts upward from the
## smallest LETTERED rung, so the index is flipped and then offset past K/M/B/T. Below that
## offset the rung has no letter pair at all and keeps its real suffix.
func _expected_label_for_rung(i: int) -> String:
	var alphabet_index := (Money.SUFFIXES.size() - 1 - i) - ALPHABET_FIRST_RUNG
	if alphabet_index < 0:
		return str(Money.SUFFIXES[i]["suffix"])
	return _expected_alphabet_label(alphabet_index)


## Base-26 letter pair for an alphabet index, computed independently of Money's own
## conversion: 0 -> "aa", 1 -> "ab", 25 -> "az", 26 -> "ba", 35 -> "bj". Straight
## quotient/remainder arithmetic rather than Money's digit-peeling loop, so a bug in that
## loop cannot hide behind an identical bug here. Only two digits are needed: the ladder is
## 40 rungs and the pairs do not run out until 676.
func _expected_alphabet_label(alphabet_index: int) -> String:
	var letters := "abcdefghijklmnopqrstuvwxyz"
	var high := alphabet_index / 26
	var low := alphabet_index % 26
	return letters[high] + letters[low]


## The letters at the end of a formatted string — "$14.3K" -> "K", "$1.5 ab" -> "ab".
## Returns "" when there is no label ("$950", or a scientific "$1.43e4").
##
## Read from the END backwards, not forwards: a rung label is always the final run of
## letters, while scientific notation always ends in the exponent's DIGITS. Scanning
## forwards and bailing on the first "e" looks equivalent and is not — the alphabet labels
## "ae" and "be" contain an "e", and that mistake made this helper return "" for two real
## rungs on the first run of these checks.
func _trailing_label(text: String) -> String:
	var label := ""
	for index in range(text.length() - 1, -1, -1):
		var character := text[index]
		if character >= "a" and character <= "z" or character >= "A" and character <= "Z":
			label = character + label
		else:
			break
	return label


## The exponent from a scientific rendering: "-$4.2e18" -> 18. Returns a sentinel far off
## the ladder if the string is not scientific, so a wrong-format string fails its check
## rather than silently matching rung 0.
func _exponent_of(text: String) -> int:
	var at := text.find("e")
	if at == -1:
		return -999
	return int(text.substr(at + 1))


## Which rung of SUFFIXES a value belongs to, derived from the value alone (largest-first
## walk, the same rule display() uses but written here so the test does not simply ask the
## code under test for the answer).
func _rung_index_for(value: float) -> int:
	var magnitude := absf(value)
	for i in Money.SUFFIXES.size():
		if magnitude >= float(Money.SUFFIXES[i]["scale"]):
			return i
	return -1


## Which rung a scientific exponent implies: rungs step by 1e3, so exponent 20 -> the 1e18
## rung. Returns -1 for anything below the ladder's first rung.
func _rung_index_for_exponent(exponent: int) -> int:
	if exponent < 3:
		return -1
	var rung_exponent := (exponent / 3) * 3
	for i in Money.SUFFIXES.size():
		# Compare exponents, not scales: 1e120 as a float cannot be equality-tested safely
		# against a recomputed pow(), but its base-10 exponent can.
		if int(round(log(float(Money.SUFFIXES[i]["scale"])) / log(10.0))) == rung_exponent:
			return i
	return -1


## Parse the mantissa back out of a scientific rendering and require 1 <= m < 10.
## SILENT on success (it runs 400 times — one line each would bury every other result);
## a failure still prints and still counts, and the caller prints a per-rung tally.
func _check_mantissa_in_range(text: String, label: String) -> bool:
	var at := text.find("e")
	if at == -1:
		print("  [FAIL] %s -> %s (not scientific: no 'e')" % [label, text])
		_failures += 1
		return false
	# Strip the "$"/"-$" prefix, then read the mantissa as written.
	var mantissa_text := text.substr(0, at).replace("-", "").replace("$", "")
	var mantissa := float(mantissa_text)
	if mantissa >= 1.0 and mantissa < 10.0:
		return true
	print("  [FAIL] %s -> %s (mantissa %s outside [1, 10))" % [label, text, mantissa_text])
	_failures += 1
	return false


## Compact "4.20e18"-style description of a value, for readable check labels only.
## Written by hand because GDScript's "%" formatter has no "%g" conversion (it errors).
func _sci_str(v: float) -> String:
	if v == 0.0:
		return "0"
	var magnitude := absf(v)
	var exponent := int(floor(log(magnitude) / log(10.0)))
	var mantissa := magnitude / pow(10.0, exponent)
	# log10/pow round-trip error can leave the mantissa a hair outside [1, 10) (1e93 comes
	# back as 10.00e92); nudge it back so the label reads sensibly.
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	# ...and a mantissa just under 10 can still PRINT as "10.00" once %.2f rounds it, which
	# is why 1e93 first showed up in these labels as "10.00e92".
	if round(mantissa * 100.0) >= 1000.0:
		mantissa = 1.0
		exponent += 1
	return ("-" if v < 0.0 else "") + ("%.2fe%d" % [mantissa, exponent])


func _check_display(v: float, expected: String) -> void:
	_check(Money.of(v).display(), expected, "display(%s)" % str(v))


func _check(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		print("  [PASS] %s -> %s" % [label, actual])
	else:
		print("  [FAIL] %s -> %s (expected %s)" % [label, actual, expected])
		_failures += 1
