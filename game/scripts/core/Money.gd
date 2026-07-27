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


## Format as a real-dollar string: $1,234 / $14.3K / $2.1M / $14.3B / $1.3T / $4.2Qa …
## Never scientific notation (GDD §2).
## Pass max_decimals = 0 for a whole-number abbreviation ($14M, $2B) — used by the
## property panels' income readout, which reads cleaner without the fractional part.
func display(max_decimals: int = 1) -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	for rung in SUFFIXES:
		if v >= rung["scale"]:
			return prefix + trim(v / rung["scale"], max_decimals) + rung["suffix"]
	return prefix + str(int(v))


## Format specifically for the player's CASH BALANCE (Tim, 2026-06-14). This is more
## precise than display() at small scales — the balance is the one number the player
## watches grow, so it reads in full until it gets genuinely large:
##   • below $1,000:        exact, with cents only when there are any   ($950, $5.50)
##   • $1,000 – $999,999:   full number with comma separators, no cents ($1,250)
##   • $1,000,000 and up:   abbreviated, up to two decimals, spaced      ($1.25 M, $2 B)
## (Costs and income/sec keep the compact display() above so they fit in tight rows.)
func display_cash() -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	if v >= 1_000_000.0:
		# Abbreviated range: up to two decimals (trailing zeros dropped — "$1.5 M",
		# never "$1.50 M" or "$1.00 M"; Tim, 2026-07-03) and a spaced suffix, from the
		# same ladder display() uses so the two formats can never disagree on a suffix.
		for rung in SUFFIXES:
			if v >= rung["scale"]:
				return prefix + trim(v / rung["scale"], 2) + " " + rung["suffix"]
	if v >= 1_000.0:
		# Thousands range: the whole number with comma separators, cents dropped.
		return prefix + _group_thousands(int(floor(v)))
	elif v == floor(v):
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


## Insert comma thousands separators into a non-negative integer dollar amount.
## E.g. 1250 → "1,250", 999999 → "999,999". (GDScript has no built-in for this.)
static func _group_thousands(whole: int) -> String:
	var digits := str(whole)
	var grouped := ""
	var count := 0
	# Walk the digits right-to-left, prepending a comma after every third one.
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped


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
