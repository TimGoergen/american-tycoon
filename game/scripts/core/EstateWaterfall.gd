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
## POWER CURVE (Tim, 2026-07-02; "reward pushing a run" re-tune 2026-07-23). The old log² curve
## barely rewarded out-earning a past run, breaking the core "better run → more prestige currency"
## loop. A power curve fixes that; the exponent sets how much pushing pays. The 2026-07-14 Option-C
## runaway fix over-flattened it to ALPHA 0.22 (a 4-billion-fold run range mapped to only ~1→900
## gems — pushing felt pointless). The 2026-07-23 re-tune STEEPENED it back — ALPHA 0.35, K 0.16 —
## so a full Earth run mints ~830 gems (vs ~108) and out-earning is clearly rewarded, WITHOUT the
## runaway returning: the Legacy shop's geometric ×2/level costs (× the 3.0 cost multiplier) are
## the real brake — even the ~320k gems an endgame run mints buy only ~14 levels of one track, and
## the deepest levels cost billions, so it never "buys out the shop." Balance found via
## sim/PrestigeStudy.gd (device-scale gem-yield + shop-cost tables). Legacy accumulates.
static func legacy_gain(estate_net: float, k_legacy: float, alpha: float) -> int:
	if estate_net <= LEGACY_BASE:
		return 0
	return int(floor(k_legacy * pow(estate_net / LEGACY_BASE, alpha)))

# §9.4 note: Legacy is no longer applied as an automatic sprint/residual income
# multiplier. The prestige reward is now a spendable currency — the player buys
# permanent upgrades with it (LegacyUpgrades / LegacyUpgradeCatalog), and those
# upgrades provide the per-generation acceleration the old multipliers used to.
