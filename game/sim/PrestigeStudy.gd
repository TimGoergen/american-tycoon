extends "res://sim/Sim.gd"

# Prestige yield/cost study — "reward pushing a run" re-tune (Tim, 2026-07-23).
#
# Usage: godot --headless --path . --script res://sim/PrestigeStudy.gd
#
# The problem: the Legacy yield curve legacy_gain = floor(k × (net/$1000)^alpha) is very FLAT at
# the live alpha = 0.22, so out-earning a past run is barely rewarded (a 4-billion-fold range of
# run sizes maps to ~1 → ~900 gems). The 180s/gen dynasty protocol in Sim.gd can't show this — it
# reaches only toy ~$10M estates. This study works at DEVICE scale: it computes gems minted per
# realistic run size, and the property-income power a single prestige's gems can buy, so a steeper
# alpha can be balanced against the shop costs WITHOUT reigniting the runaway.
#
# Two tables:
#   1. Gems minted per run size — the "reward for pushing" curve (want: bigger run => clearly more).
#   2. Max property-income multiplier a run's gems buy if spent ALL on Family Fortune (×1.20/level,
#      the compounding runaway vector, capped at level 30 = ×237). The runaway CHECK: if a mid-size
#      run can already max it, the dynasty income explodes.

const EXEMPTION := 1_000_000.0
const TAX_RATE := 0.6

# Representative "lifetime cash earned this generation" (the gross estate fed to the waterfall),
# from a small run to a fully-consumed endgame epoch. 1.036e14 = the Earth economy target.
const RUN_SIZES: Array[float] = [
	1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1.036e14, 1e15, 1e16, 1e18, 2.5e21,
]

# Candidate yield+cost tunings. LIVE anchors the comparison. Each later candidate steepens alpha
# (more reward for pushing) and pulls k down + cost up to keep the endgame from exploding.
const CANDIDATES: Array = [
	{"label": "OLD   a0.22 k0.50 cost2.0", "k": 0.50, "alpha": 0.22, "cost": 2.0},  # pre-2026-07-23
	{"label": "LIVE  a0.35 k0.16 cost3.0", "k": 0.16, "alpha": 0.35, "cost": 3.0},  # applied 2026-07-23 (was cand. C)
	{"label": "steeper a0.40 k0.09 c3.5", "k": 0.09, "alpha": 0.40, "cost": 3.5},
]


func _initialize() -> void:
	print("=== American Tycoon — Prestige Yield/Cost Study (device scale) ===")
	print("legacy_gain = floor(k × (estate_net / $1,000) ^ alpha); net = waterfall(gross, $1M exempt, 60%% tax).")

	_print_gem_yield_table()
	_print_family_fortune_table()
	_print_max_cost_table()

	print("")
	print("Read table 1 DOWN a column: how much more a bigger run pays (the 'reward for pushing').")
	print("Read table 2: the compounding income a single run's gems can buy (×237 = Family Fortune")
	print("maxed = the runaway ceiling). A good candidate grows table 1 steeply while table 2 only")
	print("reaches the ceiling near the true endgame, not at a mid-size run.")
	quit()


## Post-tax net for a gross estate (lifetime cash earned), via the real waterfall.
func _net_of(gross: float) -> float:
	return EstateWaterfall.compute(gross, 0.0, EXEMPTION, TAX_RATE)["estate_net"]


func _print_gem_yield_table() -> void:
	print("")
	print("--- Table 1: Legacy gems minted per run size ---")
	var header := "%-14s" % "run (earned)"
	for c in CANDIDATES:
		header += " %12s" % String(c["label"]).substr(0, 12)
	print(header)
	for gross in RUN_SIZES:
		var net := _net_of(gross)
		var row := "%-14s" % Money.abbrev(gross)
		for c in CANDIDATES:
			row += " %12d" % EstateWaterfall.legacy_gain(net, float(c["k"]), float(c["alpha"]))
		print(row)


func _print_family_fortune_table() -> void:
	print("")
	print("--- Table 2: property income x if a run's gems go ALL to Family Fortune (cap ×237) ---")
	var header := "%-14s" % "run (earned)"
	for c in CANDIDATES:
		header += " %12s" % String(c["label"]).substr(0, 12)
	print(header)
	for gross in RUN_SIZES:
		var net := _net_of(gross)
		var row := "%-14s" % Money.abbrev(gross)
		for c in CANDIDATES:
			var gems := EstateWaterfall.legacy_gain(net, float(c["k"]), float(c["alpha"]))
			row += " %11.1fx" % _family_fortune_income(gems, float(c["cost"]))
		print(row)


## Per upgrade, the cost of its TOP level and the total to max it, under each candidate's cost
## multiplier — where the geometric brake really bites. Endgame yields for scale.
func _print_max_cost_table() -> void:
	print("")
	print("--- Table 3: cost of the TOP level | total-to-max, per candidate cost multiplier ---")
	print("(for scale: an endgame ~$2.5Sx run mints, per candidate, the last row of Table 1)")
	var header := "%-22s %6s" % ["upgrade (max_lvl)", "grow"]
	for c in CANDIDATES:
		header += " %20s" % ("cost×%.1f" % float(c["cost"]))
	print(header)
	for definition in LegacyUpgradeCatalog.all():
		var id := String(definition["id"])
		var max_lvl := int(definition["max_level"])
		var row := "%-22s %6.1f" % ["%s (%d)" % [definition["name"], max_lvl], float(definition["cost_growth"])]
		for c in CANDIDATES:
			LegacyUpgradeCatalog.cost_multiplier = float(c["cost"])
			var top := LegacyUpgradeCatalog.cost_for_level(id, max_lvl)
			var total := 0
			for lvl in range(1, max_lvl + 1):
				total += LegacyUpgradeCatalog.cost_for_level(id, lvl)
			row += " %9s|%9s" % [Money.abbrev(float(top)), Money.abbrev(float(total))]
		print(row)


## The property-income multiplier reached by spending `gems` entirely on Family Fortune under a
## given cost multiplier — the compounding runaway vector's ceiling for a single prestige.
func _family_fortune_income(gems: int, cost_mult: float) -> float:
	LegacyUpgradeCatalog.cost_multiplier = cost_mult
	var up := LegacyUpgrades.new()
	up.available = gems
	while up.can_buy(LegacyUpgradeCatalog.FAMILY_FORTUNE):
		up.buy(LegacyUpgradeCatalog.FAMILY_FORTUNE)
	return up.property_income_multiplier()
