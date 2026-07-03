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

## Dollars below which an estate converts to no Legacy at all. The estate is measured
## RELATIVE to this floor, so it sets the low end of the balance: low enough ($1k) that a
## first prestige still yields a handful of Legacy (and the sim's modest estates convert at
## all), while nothing below it converts.
const LEGACY_BASE := 1_000.0

## Convert an estate's post-tax net into dynastic Legacy Gems (the estate currency).
##
## legacy_gain = floor(K_LEGACY × (estate_net / LEGACY_BASE) ^ ALPHA).
##
## GENTLE POWER CURVE (Tim, 2026-07-02). The previous log² curve — floor(k × log10(net/base)²)
## — was so flat that doubling a run's earnings added only ~3 Legacy, so out-earning a past run
## felt unrewarded (it broke the core "better run → more prestige currency" loop). This restores
## a power curve, but a DELIBERATELY GENTLE one: ALPHA ≈ 0.30 means gems roughly DOUBLE per 10×
## of earnings (K solved from a $10T→45 anchor via sim/Sim.gd's conversion study). That is far
## below the old runaway exponent — a genuine endgame run (a fully-consumed 6th epoch, ~$2.5
## sextillion) mints ~15–20k gems, and the Legacy shop's geometric ×2 costs mean even that only
## buys a few levels of one upgrade track, so it never "buys out the shop." Legacy accumulates.
static func legacy_gain(estate_net: float, k_legacy: float, alpha: float) -> int:
	if estate_net <= LEGACY_BASE:
		return 0
	return int(floor(k_legacy * pow(estate_net / LEGACY_BASE, alpha)))

# §9.4 note: Legacy is no longer applied as an automatic sprint/residual income
# multiplier. The prestige reward is now a spendable currency — the player buys
# permanent upgrades with it (LegacyUpgrades / LegacyUpgradeCatalog), and those
# upgrades provide the per-generation acceleration the old multipliers used to.
