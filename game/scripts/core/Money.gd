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


## Format as a real-dollar string: $1,234 / $14.3K / $2.1M / $14.3B / $1.3T
## Never scientific notation (GDD §2).
func display() -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	if v >= 1_000_000_000_000.0:
		return prefix + _trim(v / 1_000_000_000_000.0) + "T"
	elif v >= 1_000_000_000.0:
		return prefix + _trim(v / 1_000_000_000.0) + "B"
	elif v >= 1_000_000.0:
		return prefix + _trim(v / 1_000_000.0) + "M"
	elif v >= 1_000.0:
		return prefix + _trim(v / 1_000.0) + "K"
	else:
		return prefix + str(int(v))


## Format specifically for the player's CASH BALANCE (Tim, 2026-06-14). This is more
## precise than display() at small scales — the balance is the one number the player
## watches grow, so it reads in full until it gets genuinely large:
##   • below $1,000:        exact, with cents only when there are any   ($950, $5.50)
##   • $1,000 – $999,999:   full number with comma separators, no cents ($1,250)
##   • $1,000,000 and up:   abbreviated to two decimals with a space     ($1.00 M)
## (Costs and income/sec keep the compact display() above so they fit in tight rows.)
func display_cash() -> String:
	var v := absf(value)
	var prefix := "-$" if value < 0.0 else "$"

	if v >= 1_000_000_000_000.0:
		return prefix + ("%.2f" % (v / 1_000_000_000_000.0)) + " T"
	elif v >= 1_000_000_000.0:
		return prefix + ("%.2f" % (v / 1_000_000_000.0)) + " B"
	elif v >= 1_000_000.0:
		return prefix + ("%.2f" % (v / 1_000_000.0)) + " M"
	elif v >= 1_000.0:
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


## Trim trailing zeros from a decimal string, keeping up to one decimal place.
static func _trim(v: float) -> String:
	# E.g. 14.300 → "14.3", 2.000 → "2", 1.050 → "1.1" (rounded to 1dp)
	var rounded := snappedf(v, 0.1)
	if fmod(rounded, 1.0) == 0.0:
		return str(int(rounded))
	return "%.1f" % rounded
