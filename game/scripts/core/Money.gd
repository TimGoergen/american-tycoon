class_name Money

# Wraps a float for Earth-scale numbers (~$1e14 max). Designed as a
# drop-in replacement point: swap the internal `value` type and the
# arithmetic methods when big-number planets need more than float64.
# All arithmetic floors at award/charge per Spec §1.

var value: float


func _init(v: float = 0.0) -> void:
	value = v


## Create a Money instance from a plain float.
static func of(v: float) -> Money:
	return Money.new(v)


## Return a new Money equal to self + other (not floored — floor at award time).
func add(other: Money) -> Money:
	return Money.new(value + other.value)


## Return a new Money equal to self - other, clamped to zero.
func subtract(other: Money) -> Money:
	return Money.new(maxf(0.0, value - other.value))


## Return a new Money equal to self × factor.
func multiply(factor: float) -> Money:
	return Money.new(value * factor)


## Return a new Money with value floored to the nearest dollar.
func floored() -> Money:
	return Money.new(floor(value))


func is_gte(other: Money) -> bool:
	return value >= other.value


func is_lte(other: Money) -> bool:
	return value <= other.value


func is_gt(other: Money) -> bool:
	return value > other.value


# The abbreviation ladder, LARGEST first (display walks it top-down and takes the first
# threshold the value clears). Real short-scale dollar names, per the GDD §2 convention
# (real-dollar formatting, never scientific notation) — extended past T on 2026-07-03,
# and past Dd on 2026-07-26 because the ×16807-per-epoch scaling (NOT the ~×30 an old
# comment claimed) blew past duodecillion by epoch ~8 and piled digits on "Dd".
# Two-letter forms so neighbors can't be misread (Qa ≠ Qi, Sx ≠ Sp); the -decillion
# family carries a trailing "d", the -vigintillion family "Vg", the -trigintillion "Tg".
# Now runs to 1e120 (novemtrigintillion) — past the whole 26-epoch roadmap's magnitudes.
const SUFFIXES := [
	{"scale": 1e120, "suffix": "NoTg"}, {"scale": 1e117, "suffix": "OcTg"},
	{"scale": 1e114, "suffix": "SpTg"}, {"scale": 1e111, "suffix": "SxTg"},
	{"scale": 1e108, "suffix": "QiTg"}, {"scale": 1e105, "suffix": "QaTg"},
	{"scale": 1e102, "suffix": "TTg"}, {"scale": 1e99, "suffix": "DTg"},
	{"scale": 1e96, "suffix": "UTg"}, {"scale": 1e93, "suffix": "Tg"},
	{"scale": 1e90, "suffix": "NoVg"}, {"scale": 1e87, "suffix": "OcVg"},
	{"scale": 1e84, "suffix": "SpVg"}, {"scale": 1e81, "suffix": "SxVg"},
	{"scale": 1e78, "suffix": "QiVg"}, {"scale": 1e75, "suffix": "QaVg"},
	{"scale": 1e72, "suffix": "TVg"}, {"scale": 1e69, "suffix": "DVg"},
	{"scale": 1e66, "suffix": "UVg"}, {"scale": 1e63, "suffix": "Vg"},
	{"scale": 1e60, "suffix": "Nod"}, {"scale": 1e57, "suffix": "Ocd"},
	{"scale": 1e54, "suffix": "Spd"}, {"scale": 1e51, "suffix": "Sxd"},
	{"scale": 1e48, "suffix": "Qid"}, {"scale": 1e45, "suffix": "Qad"},
	{"scale": 1e42, "suffix": "Td"}, {"scale": 1e39, "suffix": "Dd"},
	{"scale": 1e36, "suffix": "Ud"}, {"scale": 1e33, "suffix": "Dc"},
	{"scale": 1e30, "suffix": "No"}, {"scale": 1e27, "suffix": "Oc"},
	{"scale": 1e24, "suffix": "Sp"}, {"scale": 1e21, "suffix": "Sx"},
	{"scale": 1e18, "suffix": "Qi"}, {"scale": 1e15, "suffix": "Qa"},
	{"scale": 1e12, "suffix": "T"}, {"scale": 1e9, "suffix": "B"},
	{"scale": 1e6, "suffix": "M"}, {"scale": 1e3, "suffix": "K"},
]


# ── Player-selectable number format (Roadmap §6, 2026-07-30) ──────────────────────────
#
# The suffix ladder above stops being readable somewhere around epoch 12: "SxVg" and "QaTg"
# carry no intuition and, worse, cannot be ORDERED by eye. So the player may pick how every
# number on screen is rendered. The mode is presentation-only — it never touches save data
# (beyond its own preference int) and never takes part in a comparison.
#
#   ABBREVIATED (default) — the real short-scale suffix:       $4.2 Qa
#   ALPHABET              — K/M/B/T, then letter pairs:        $4.2 ab
#   SCIENTIFIC            — true scientific, 1 <= mantissa <10: $4.2e18
#
# NOTE: SCIENTIFIC deliberately overrides the standing "never scientific notation" rule in
# GDD §2 / Mechanics Spec §Display. That rule was rescoped on 2026-07-30 to describe only the
# DEFAULT format — the game still never shows an exponent unless the player asks for one.
enum Format { ABBREVIATED, ALPHABET, SCIENTIFIC }

# Static, like LegacyUpgradeCatalog's tuning-injected statics: every Money instance formats
# the same way, so the setting reaches all ~37 call sites without any of them changing.
# GameState owns the persisted preference and pushes it in here on load and on change.
static var format_mode: int = Format.ABBREVIATED

# The alphabet mode's digits. Indexed by position, so 0 → "a" … 25 → "z".
const _ALPHABET_LETTERS := "abcdefghijklmnopqrstuvwxyz"

# How many rungs at the BOTTOM of the ladder keep their real suffix in ALPHABET mode.
# Four: K (1e3), M (1e6), B (1e9), T (1e12). The letters begin at the fifth rung up,
# quadrillions (1e15) = "aa". See _suffix_for_rung() for the index arithmetic.
const _ALPHABET_FIRST_RUNG := 4


## Format as a real-dollar string: $950 / $14.3K / $2.1M / $14.3B / $1.3T / $4.2Qa …
## Pass max_decimals = 0 for a whole-number abbreviation ($14M, $2B) — used by the
## property panels' income readout, which reads cleaner without the fractional part.
##
## THRESHOLD RULE (shared with display_cash, Plan "Thresholds"): a non-default format
## replaces the abbreviation exactly where an abbreviation would have appeared, and changes
## NOTHING below that point. Both formatters abbreviate from $1,000, so the alternate formats
## also start at $1,000 and everything under it stays exact in all three modes.
## Consequence, and it is intended: SCIENTIFIC renders $14,300 as "$1.43e4".
func display(max_decimals: int = 1) -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	for i in SUFFIXES.size():
		var rung: Dictionary = SUFFIXES[i]
		if v >= rung["scale"]:
			if format_mode == Format.SCIENTIFIC:
				# Scientific ignores the rung it landed on: its exponent is a multiple of 1,
				# not of 3, so it re-derives the magnitude from the value itself.
				return _scientific(v, prefix)
			# ABBREVIATED and ALPHABET share the rung, and therefore the mantissa, exactly —
			# only the trailing label differs. No spacing here: display() is the tight form.
			return prefix + trim(v / rung["scale"], max_decimals) + _suffix_for_rung(i)
	return prefix + str(int(v))


## Format specifically for the player's CASH BALANCE (Tim, 2026-06-14). This is more
## precise than display() at small scales — the balance is the one number the player
## watches grow, so it reads in full until it gets genuinely large:
##   • below $1,000:      exact, with cents only when there are any    ($950, $5.50)
##   • $1,000 and up:     abbreviated, up to two decimals, spaced      ($18.61 K, $1.25 M)
## (Costs and income/sec keep the compact display() above so they fit in tight rows.)
##
## THE $1,000 THRESHOLD IS SHARED WITH display() ON PURPOSE (Tim, 2026-07-31). It used to
## abbreviate only from $1,000,000 and comma-group the thousands below that, which meant a
## $5,510 cost button and an $18,610 balance could sit on screen in two different NOTATION
## SYSTEMS at once ("$5.51e3" beside "18,610" in SCIENTIFIC). Tim: "I dislike having
## materially different text that means the same thing." So the comma-grouped thousands
## range is retired and $18,610 now reads "$18.61 K" in every mode.
##
## The two formatters still differ in PRECISION and SPACING (1dp tight vs 2dp spaced), which
## is deliberate and is not the same thing — "$2.3K" and "$2.3 K" are the same notation.
func display_cash() -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	if v >= 1_000.0:
		# Abbreviated range: up to two decimals (trailing zeros dropped — "$1.5 M",
		# never "$1.50 M" or "$1.00 M"; Tim, 2026-07-03) and a spaced suffix, from the
		# same ladder display() uses so the two formats can never disagree on a suffix.
		#
		# Per the threshold rule, the alternate formats take over here and only here — the
		# cents and whole dollars below $1,000 are byte-identical in all three modes.
		if format_mode == Format.SCIENTIFIC:
			# NO space before the "e". "$4.2 e18" would read as a number followed by a
			# suffix; the exponent is part of the number itself, not a label beside it.
			return _scientific(v, prefix)
		for i in SUFFIXES.size():
			var rung: Dictionary = SUFFIXES[i]
			if v >= rung["scale"]:
				# ALPHABET KEEPS the space ("$4.2 ab"): it occupies the suffix slot, so it
				# gets the suffix slot's spacing, and the balance readout stays visually
				# aligned when the player switches modes.
				return prefix + trim(v / rung["scale"], 2) + " " + _suffix_for_rung(i)
	if v == floor(v):
		# Below $1,000 and a whole number of dollars: no decimal point at all.
		return prefix + str(int(v))
	else:
		# Below $1,000 with a fractional part: show the cents.
		return prefix + ("%.2f" % v)


## The same magnitude abbreviation as display() but WITHOUT the "$" — for NON-dollar quantities
## (Legacy gems, etc.) that should still read like money (45, 1.5K, 10M) instead of raw integers
## like "10000000" (Tim 2026-07-13). Non-negative inputs (these are counts).
static func abbrev(v: float, max_decimals: int = 1) -> String:
	return Money.of(v).display(max_decimals).trim_prefix("$")


## The label that goes after the mantissa for rung `i` of SUFFIXES, in the current format.
## Both formatters call this, so ABBREVIATED and ALPHABET can never disagree about which
## label belongs to which magnitude. (SCIENTIFIC never gets here — it has no rung label.)
static func _suffix_for_rung(i: int) -> String:
	if format_mode == Format.ALPHABET:
		# ALPHABET KEEPS THE FAMILIAR FOUR (Tim, 2026-07-31): K / M / B / T are universally
		# read, so the generic letters only start where the vocabulary stops being obvious —
		# at QUADRILLIONS. Below that this mode is identical to ABBREVIATED.
		#
		# SUFFIXES is ordered LARGEST FIRST, but the alphabet counts UPWARD from the
		# smallest rung, so the two indices run in opposite directions and we flip; then we
		# subtract the four familiar rungs so 1e15 — not 1e3 — is alphabet index 0:
		#   i = 39 (K, 1e3)      → -4 → below the letters → "K"
		#   i = 36 (T, 1e12)     → -1 → below the letters → "T"
		#   i = 35 (Qa, 1e15)    → alphabet index 0  → "aa"
		#   i = 34 (Qi, 1e18)    → alphabet index 1  → "ab"
		#   i = 0  (NoTg, 1e120) → alphabet index 35 → "bj"
		# Deriving the letters from the INDEX rather than keeping a second, parallel table
		# is load-bearing: a parallel table could drift out of step with the ladder, while
		# this cannot. It also extends for free if the ladder ever grows past 1e120.
		var alphabet_index := (SUFFIXES.size() - 1 - i) - _ALPHABET_FIRST_RUNG
		if alphabet_index >= 0:
			return alphabet_for_rung(alphabet_index)
	return SUFFIXES[i]["suffix"]


## Turn a 0-based alphabet index into its letter pair: 0 → "aa", 1 → "ab", 25 → "az",
## 26 → "ba", 35 → "bj", 675 → "zz". Past 675 the pairs are exhausted, so it grows a third
## letter ("baa") rather than wrapping or asserting — a ladder that long is hypothetical, but
## a wrong-but-silent label would be worse than a slightly wider one.
##
## The index is the LETTERED rung's position, counting from quadrillions (1e15 = 0), NOT the
## position in SUFFIXES — the four rungs below it (K/M/B/T) have no letter pair at all. The
## ladder's top rung, 1e120, is index 35 → "bj".
##
## PUBLIC on purpose: the HELP glossary prints the alphabet ladder as a legend, and it needs the
## mapping regardless of which format the player currently has selected. It cannot use
## _suffix_for_rung() for that, because that one returns whichever label the CURRENT mode picks.
## Calling this instead of re-deriving base-26 locally is what keeps the legend and the live
## numbers provably in step.
static func alphabet_for_rung(alphabet_index: int) -> String:
	if alphabet_index < 0:
		return "aa"  # Defensive: no rung produces this, but never return an empty label.
	# Plain base-26 with 'a' as the zero digit: peel off one digit at a time, right to left.
	var letters := ""
	var remaining := alphabet_index
	while remaining > 0:
		letters = _ALPHABET_LETTERS[remaining % 26] + letters
		remaining = remaining / 26  # Integer division — both operands are ints.
	# Pad to the fixed two-character width every mode-comparison table assumes ("" → "aa").
	while letters.length() < 2:
		letters = "a" + letters
	return letters


## Render a POSITIVE magnitude in true scientific notation, e.g. 4.2e18 — mantissa always in
## [1, 10) (not engineering style), lowercase "e", no "+" on the exponent, no superscript
## (plain Labels cannot do it, and compactness is the whole point). `prefix` carries the
## already-decided "$" or "-$", so negatives read "-$4.2e18" like every other format.
static func _scientific(v: float, prefix: String) -> String:
	if v <= 0.0:
		return prefix + "0"  # Unreachable via the callers' thresholds; log10(0) is -inf.
	var exponent := int(floor(log(v) / log(10.0)))
	var mantissa := v / pow(10.0, exponent)

	# FLOAT TRAP, two halves. Both callers hand us a value big enough that log10 and pow are
	# doing real floating-point work, and neither the division nor the later rounding is exact:
	#
	#  (a) log10/pow round-trip error can put the raw mantissa a hair outside [1, 10) —
	#      9.999999 or 10.000001 — so nudge it back a rung. `while` rather than `if` costs
	#      nothing and cannot loop more than once in practice.
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while mantissa < 1.0:
		mantissa *= 10.0
		exponent -= 1

	#  (b) The real one: trim() ROUNDS to 2 decimals, and a mantissa legitimately inside the
	#      range can round UP to exactly 10 — 9.999e17 has mantissa 9.999, which prints as
	#      "10.00" and would render the nonsense "$10e17". If the 2-decimal rounding reaches
	#      10, the correct rendering at that precision is 1 of the next magnitude: "$1e18".
	if round(mantissa * 100.0) >= 1000.0:
		mantissa = 1.0
		exponent += 1

	# trim() (not a bare "%.2f") so the rounding and the trailing-zero rule match the other
	# two modes exactly: 4.20 → "4.2", 1.00 → "1".
	return prefix + trim(mantissa, 2) + "e" + str(exponent)


## Format a number to at most `decimals` decimal places, then drop any trailing zeros
## (and a bare trailing point), so a whole number never shows a pointless ".0":
##   trim(14.30, 1) → "14.3"    trim(2.00, 1) → "2"    trim(1.50, 2) → "1.5"
## Public and shared: EVERY on-screen number rule is "a decimal place only when the
## decimal is not zero" (Tim, 2026-07-03), so other scripts format through this too.
static func trim(v: float, decimals: int = 1) -> String:
	if decimals <= 0:
		# No decimal places allowed: round to the nearest whole unit (14.7 → "15").
		return str(int(round(v)))
	var text := "%.*f" % [decimals, v]
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text
