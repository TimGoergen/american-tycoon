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

## Convert an estate's post-tax net into dynastic Legacy points.
## legacy_gain = floor(K_LEGACY × estate_net ^ ALPHA). The ^0.5 (default ALPHA)
## compresses huge estates so a single monster generation can't trivialize the
## dynasty curve. Legacy is never spent down by this conversion — it accumulates.
static func legacy_gain(estate_net: float, k_legacy: float, alpha: float) -> int:
	if estate_net <= 0.0:
		return 0
	return int(floor(k_legacy * pow(estate_net, alpha)))


# ---------------------------------------------------------------------------
# §9.4 — Legacy application (the "speeds up every time" multipliers)
# ---------------------------------------------------------------------------

## The catch-up sprint: a large temporary multiplier on property income that is
## active only while the heir is still poorer than the predecessor's peak. This
## is what lets each heir tear through tiers the parent crawled across.
## SPRINT_MULT = 1 + K_SPRINT × Legacy ^ BETA
static func sprint_mult(legacy_total: int, k_sprint: float, beta: float) -> float:
	if legacy_total <= 0:
		return 1.0
	return 1.0 + k_sprint * pow(float(legacy_total), beta)


## The permanent residual that remains after the sprint ends — a smaller, lasting
## edge that grows with how many Legacy brackets the dynasty has attained.
## RESIDUAL_MULT = 1 + K_RES × brackets_attained
static func residual_mult(brackets_attained: int, k_res: float) -> float:
	return 1.0 + k_res * float(brackets_attained)


## How many Legacy "brackets" a running total has attained. Provisional model
## (TBD-SIM): one bracket per doubling of total Legacy, so the residual edge
## grows gently and never runs away. The GDD frames brackets as named tiers
## ("the estate now qualifies for…"); the names are a later content pass.
static func brackets_for(legacy_total: int) -> int:
	if legacy_total <= 0:
		return 0
	# log2(legacy + 1): 1→1, 3→2, 7→3, 15→4 … each doubling adds one bracket.
	return int(floor(log(float(legacy_total) + 1.0) / log(2.0)))
