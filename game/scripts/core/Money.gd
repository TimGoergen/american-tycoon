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
# (real-dollar formatting, never scientific notation) — extended past T on 2026-07-03
# because deep alien epochs blew past it and rendered as digit-piles like "$25174800T".
# Two-letter forms so neighbors can't be misread for each other (Qa ≠ Qi, Sx ≠ Sp):
#   K  thousand      M  million        B  billion       T  trillion
#   Qa quadrillion   Qi quintillion    Sx sextillion    Sp septillion
#   Oc octillion     No nonillion      Dc decillion     Ud undecillion
#   Dd duodecillion (1e39)
# Each epoch is ~×30 (economy_scale), so this ladder covers roughly epoch 17+ before a
# value would pile up multipliers on "Dd" the way it used to on "T" — extend it here
# (one line per rung) if the epoch roadmap ever gets that deep.
const SUFFIXES := [
	{"scale": 1e39, "suffix": "Dd"},
	{"scale": 1e36, "suffix": "Ud"},
	{"scale": 1e33, "suffix": "Dc"},
	{"scale": 1e30, "suffix": "No"},
	{"scale": 1e27, "suffix": "Oc"},
	{"scale": 1e24, "suffix": "Sp"},
	{"scale": 1e21, "suffix": "Sx"},
	{"scale": 1e18, "suffix": "Qi"},
	{"scale": 1e15, "suffix": "Qa"},
	{"scale": 1e12, "suffix": "T"},
	{"scale": 1e9, "suffix": "B"},
	{"scale": 1e6, "suffix": "M"},
	{"scale": 1e3, "suffix": "K"},
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
