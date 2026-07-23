extends "res://sim/Sim.gd"

# Payback Study — the property self-funding guardrail readout (GDD §4 / parking-lot
# "Balance guardrail", Plans/R0_Self_Funding_Proposal.md).
#
# Usage: godot --headless --path . --script res://sim/PaybackStudy.gd
#
# The guardrail concern (GDD): a property's income scales LINEARLY with units owned,
# but its next-unit cost grows GEOMETRICALLY at r0. At low unit counts linear income
# outpaces the r0 climb, so the PAYBACK PERIOD (next-unit cost / current income/sec)
# SHRINKS as you stack units — the property starts to self-fund its own expansion,
# which erases the cross-property allocation the game is built on.
#
# This study measures payback = f(units, r0) directly off the real PropertyState /
# CostCurve (so it captures the $5 round_nice snap, the band_step milestone steepening,
# and the milestone income-doublings that a closed-form hand-calc skips). It is a
# STATIC walk — payback is a property of the cost/income curves, independent of play —
# so it does not simulate a session; the PACE cost of raising r0 is measured separately
# by PaceStudy.gd (its C/D/E candidates already sweep r0 1.09 / 1.11 / 1.15).
#
# Nothing here mutates the live configs: each candidate duplicates the config and
# overrides r0, exactly like PaceStudy._make_variant_property_configs.

## The r0 values to compare. 1.09 is the current live value on all 12 Earth tiers.
const R0_CANDIDATES: Array[float] = [1.07, 1.09, 1.12, 1.15, 1.18, 1.20]
const LIVE_R0 := 1.09

## Band 0 is units 1..24 (milestone 1 is at 25 units, CostCurve.MILESTONE_THRESHOLDS).
## The self-funding dip lives inside this first band, so it is where the guardrail bites.
const BAND0_LAST_UNIT := 24

## How far to walk each property. 110 covers bands 0-3 (milestones at 25/50/100), enough
## to show the milestone 2x income steps reshaping the curve.
const WALK_UNITS := 110

## One payback row per unit count for one property under one r0.
class Row:
	var unit: int
	var payback: float   # seconds of this property's own income to afford its next unit
	var band: int


func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return

	print("=== American Tycoon — Property Payback Study (self-funding guardrail) ===")
	print("payback(n) = cost of unit n+1 / income-per-sec at n units, on a bare property.")
	print("The guardrail wants payback to hold flat-or-rising within a band; linear income")
	print("+ geometric cost makes an early DIP unavoidable, so r0 only sets its depth/floor.")

	var earth := _earth_configs()

	_print_live_floor_by_property(earth)
	_print_dip_shape_by_r0(earth)
	_print_atm_trajectory(earth)

	quit()


# ---------------------------------------------------------------------------
# The walk — one property, one r0, real PropertyState
# ---------------------------------------------------------------------------

## Walk a property from 1 unit upward under an r0 override, recording payback at each
## unit count. Uses the real buy()/get_next_cost()/get_income_per_sec() path so the
## numbers match what the game actually charges and pays.
func _walk(config: PropertyConfig, r0_value: float) -> Array[Row]:
	var variant := config.duplicate() as PropertyConfig
	variant.r0 = r0_value
	var prop := PropertyState.new(variant, _tuning)
	prop.buy(1)  # own the first unit so income/sec is non-zero

	var rows: Array[Row] = []
	for n in range(1, WALK_UNITS + 1):
		var income := prop.get_income_per_sec()
		var next_cost := prop.get_next_cost()
		var row := Row.new()
		row.unit = n
		row.payback = next_cost / income if income > 0.0 else INF
		row.band = CostCurve.get_band(n)
		rows.append(row)
		prop.buy(1)  # advance to n+1 units (applies any milestone crossed)
	return rows


## The band-0 dip for one walk: the shallowest payback in units 1..24 and where it sits,
## plus the band's start (unit 1) and end (unit 24) paybacks.
func _band0_dip(rows: Array[Row]) -> Dictionary:
	var floor_payback := INF
	var floor_unit := 0
	var start_payback := 0.0
	var end_payback := 0.0
	for row in rows:
		if row.unit == 1:
			start_payback = row.payback
		if row.unit == BAND0_LAST_UNIT:
			end_payback = row.payback
		if row.unit <= BAND0_LAST_UNIT and row.payback < floor_payback:
			floor_payback = row.payback
			floor_unit = row.unit
	return {
		"floor_payback": floor_payback,
		"floor_unit": floor_unit,
		"start_payback": start_payback,
		"end_payback": end_payback,
		"depth": start_payback / floor_payback if floor_payback > 0.0 else INF,
	}


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

## Section A — at the LIVE r0, the band-0 payback floor for every Earth tier. Shows the
## guardrail is an EARLY-tier problem: the floor scales with a property's cost/income
## ratio, so the ATM bottoms out at ~1s (trivially self-funding) while the top tiers
## bottom out at tens of seconds (already fine).
func _print_live_floor_by_property(earth: Array[PropertyConfig]) -> void:
	print("")
	print("--- A. Band-0 self-funding floor by property, at LIVE r0 = %.2f ---" % LIVE_R0)
	print("%-28s %12s %10s %12s" % ["property", "floor(s)", "@ unit", "start(s)"])
	for config in earth:
		var dip := _band0_dip(_walk(config, LIVE_R0))
		print("%-28s %11.2fs %10d %11.2fs" % [
			config.display_name, dip["floor_payback"], dip["floor_unit"], dip["start_payback"],
		])
	print("Read: 'floor' = fewest seconds of a property's OWN income to buy its next unit")
	print("anywhere in band 0. Low = self-funding. The problem concentrates in early tiers.")


## Section B — the dip shape and the two extreme floors (ATM = smallest, Executive =
## largest cost/income ratio) across the r0 sweep. The shape (where the dip bottoms, how
## deep) is r0-only and identical for every property; only the absolute floor scales.
func _print_dip_shape_by_r0(earth: Array[PropertyConfig]) -> void:
	var atm := earth[0]
	var executive := earth[earth.size() - 1]
	print("")
	print("--- B. Dip shape + extreme floors across the r0 sweep ---")
	print("%-8s %10s %10s %12s %14s" % ["r0", "dip@unit", "depth(x)", "ATM floor(s)", "Exec floor(s)"])
	for r0_value in R0_CANDIDATES:
		var atm_dip := _band0_dip(_walk(atm, r0_value))
		var exec_dip := _band0_dip(_walk(executive, r0_value))
		var live_mark := "  <- live" if is_equal_approx(r0_value, LIVE_R0) else ""
		print("%-8.2f %10d %10.2f %11.2fs %13.1fs%s" % [
			r0_value, atm_dip["floor_unit"], atm_dip["depth"],
			atm_dip["floor_payback"], exec_dip["floor_payback"], live_mark,
		])
	print("Read: higher r0 => shallower dip (smaller depth x) + higher floor, but see")
	print("PaceStudy C/D/E for the progression-pace cost that buys.")


## Section C — the ATM's full payback trajectory across bands 0-3 at live r0 vs a steeper
## candidate, so the milestone 2x income steps (the sharp drops at 25/50/100) are visible
## alongside how r0 reshapes the within-band slope.
func _print_atm_trajectory(earth: Array[PropertyConfig]) -> void:
	var atm := earth[0]
	var sample_units := [1, 5, 10, 15, 20, 24, 25, 30, 40, 49, 50, 60, 99, 100, 110]
	var live_rows := _walk(atm, LIVE_R0)
	var steep_rows := _walk(atm, 1.15)
	print("")
	print("--- C. ATM payback trajectory (units across bands 0-3): live 1.09 vs 1.15 ---")
	print("%8s %8s %14s %14s" % ["unit", "band", "1.09 pay(s)", "1.15 pay(s)"])
	for u in sample_units:
		print("%8d %8d %13.2fs %13.2fs" % [
			u, live_rows[u - 1].band, live_rows[u - 1].payback, steep_rows[u - 1].payback,
		])
	print("Read: the sharp drops at units 25/50/100 are the milestone income-doublings")
	print("(each instantly halves payback); r0 sets the slope BETWEEN those steps.")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## The 12 Earth-tier configs (unlock_tier 1) in ladder order.
func _earth_configs() -> Array[PropertyConfig]:
	var earth: Array[PropertyConfig] = []
	for config in _property_configs:
		if (config as PropertyConfig).unlock_tier == 1:
			earth.append(config)
	return earth
