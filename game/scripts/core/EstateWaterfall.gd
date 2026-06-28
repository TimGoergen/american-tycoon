class_name EstateWaterfall

# Pure, headless estate/Legacy math (Mechanics Spec §9.2–9.4). Static helpers
# only — no state, no scene tree — so the simulator and the eventual will-screen
# UI compute the exact same numbers from the same place. Same pattern as
# CostCurve.gd and OfflineCalculator.gd.
#
# This is the financial spine of the prestige loop: a generation dies, its
# estate is taxed down to a "net", and that net converts to dynastic Legacy
# which makes the next heir accelerate faster.


# ---------------------------------------------------------------------------
# §9.2 — The estate waterfall (executed at death, itemized on the will screen)
# ---------------------------------------------------------------------------

## Run the death waterfall. Creditors are paid first, then the estate tax takes
## a brutal cut of whatever is left above the exemption. Returns every line so
## the will screen can show the math (each value is dollars, floored like all
## money in the game).
##
##   after_credit = estate_gross − min(estate_gross, outstanding_debt)
##   taxable      = max(0, after_credit − exemption)
##   tax          = floor(taxable × tax_rate)
##   estate_net   = after_credit − tax
static func compute(
		estate_gross: float,
		outstanding_debt: float,
		exemption: float,
		tax_rate: float
) -> Dictionary:
	var credited := minf(estate_gross, maxf(outstanding_debt, 0.0))
	var after_credit := estate_gross - credited
	var taxable := maxf(0.0, after_credit - exemption)
	var tax := floorf(taxable * tax_rate)
	var estate_net := after_credit - tax
	return {
		"estate_gross": estate_gross,
		"creditors_paid": credited,
		"after_credit": after_credit,
		"taxable": taxable,
		"tax": tax,
		"estate_net": estate_net,
	}


# ---------------------------------------------------------------------------
# §9.3 — Legacy conversion (root function)
# ---------------------------------------------------------------------------

## Dollars below which an estate converts to no Legacy at all. The log curve is measured
## in orders of magnitude ABOVE this floor, so the floor sets BOTH ends of the balance:
## low enough ($1k) that a first prestige still yields a handful of Legacy (and the sim's
## modest estates convert at all), yet because the curve is logarithmic a real
## trillion-dollar run still only mints tens of Legacy, not the thousands the old power
## curve produced.
const LEGACY_BASE := 1_000.0

## Convert an estate's post-tax net into dynastic Legacy Gems (the estate currency).
##
## legacy_gain = floor(K_LEGACY × log10(estate_net / LEGACY_BASE) ^ ALPHA).
##
## Reworked 2026-06-17 from a plain power curve. A power curve calibrated for the sim's
## tiny estates minted absurd Legacy at real scale (a single 20T run gave ~16k —
## enough to buy out the whole shop). Measuring the estate in ORDERS OF MAGNITUDE above
## the floor compresses the entire range into a sane handful of Legacy: each additional
## 10× of estate adds only a little (≈ $1B→18, $8T→49, $1Q→72 at the default tuning),
## and nothing converts below the floor. Legacy never spends down by this — it accumulates.
static func legacy_gain(estate_net: float, k_legacy: float, alpha: float) -> int:
	if estate_net <= LEGACY_BASE:
		return 0
	# log10(x) = ln(x) / ln(10); GDScript's log() is the natural log.
	var decades := log(estate_net / LEGACY_BASE) / log(10.0)
	return int(floor(k_legacy * pow(decades, alpha)))

# §9.4 note: Legacy is no longer applied as an automatic sprint/residual income
# multiplier. The prestige reward is now a spendable currency — the player buys
# permanent upgrades with it (LegacyUpgrades / LegacyUpgradeCatalog), and those
# upgrades provide the per-generation acceleration the old multipliers used to.
