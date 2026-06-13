# HeirNames.gd
# Pure utility for generating the dynastic name displayed each generation.
# No scene tree presence, no state — static functions only.
# Called by Main.gd to produce names like "Wellington Pemberton IX".

class_name HeirNames


## The fixed house given-name and family surname for the current dynasty.
## A later slice (origins) will randomize these per playthrough.
const HOUSE_NAME := "Wellington"
const FAMILY_SURNAME := "Pemberton"


## Convert a positive integer to a Roman numeral string (1 -> "I", 4 -> "IV",
## 9 -> "IX", 40 -> "XL", 1990 -> "MCMXC", etc.). Must handle at least 1..3999
## correctly. For n < 1, return str(n) as a safe fallback.
static func roman_numeral(n: int) -> String:
	# Guard: Roman numerals are only defined for positive integers.
	# Returning str(n) keeps the caller's display from going blank on bad input.
	if n < 1:
		return str(n)

	# Standard descending value/symbol table. The subtractive pairs (CM, CD, etc.)
	# are listed explicitly so we can handle them in the same loop without special
	# cases — we just subtract the largest value that fits and append its symbol.
	var values: Array[int]   = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]

	var result := ""
	var remaining := n

	for i in range(values.size()):
		# Keep consuming this value as long as it still fits.
		while remaining >= values[i]:
			result += symbols[i]
			remaining -= values[i]

	return result


## The full dynastic name for a given 1-based generation, e.g.
## dynasty_name(9) -> "Wellington Pemberton IX".
static func dynasty_name(generation: int) -> String:
	return "%s %s %s" % [HOUSE_NAME, FAMILY_SURNAME, roman_numeral(generation)]
