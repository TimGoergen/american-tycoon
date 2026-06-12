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


## Trim trailing zeros from a decimal string, keeping up to one decimal place.
static func _trim(v: float) -> String:
	# E.g. 14.300 → "14.3", 2.000 → "2", 1.050 → "1.1" (rounded to 1dp)
	var rounded := snappedf(v, 0.1)
	if fmod(rounded, 1.0) == 0.0:
		return str(int(rounded))
	return "%.1f" % rounded
