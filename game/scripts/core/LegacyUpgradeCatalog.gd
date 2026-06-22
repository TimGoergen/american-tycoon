class_name LegacyUpgradeCatalog

# The fixed catalog of Legacy upgrades — the permanent, dynasty-wide perks the
# player buys with Legacy after a succession (GDD §13 / the M2 prestige reward).
#
# This is a pure DATA TABLE, defined in code the same way HeirNames.gd defines
# the dynasty's name table: static, stateless, no scene tree. The numbers here
# are tuning values (first-pass — see the note on costs below); they live in one
# place so a future balance pass changes only this file.
#
# Each upgrade is one dictionary with these keys:
#   id              — stable string key, also used in the save file
#   name            — display title on the upgrade card
#   category        — section heading in the shop ("Wealth", "Operations", …)
#   description     — one flavorful line explaining what it does
#   max_level       — how many times it can be bought (levels are 1..max_level)
#   base_cost       — Legacy cost of the FIRST level
#   cost_growth     — each further level costs the previous × this factor
#   effect_per_level — the raw magnitude added by one level (interpretation
#                      depends on the upgrade; see LegacyUpgrades effect getters)
#
# How the effects are consumed: LegacyUpgrades.gd reads an upgrade's level and
# turns it into a concrete multiplier or bonus (e.g. "+20% property income per
# level"). The catalog only stores the per-level magnitude; the formula lives
# next to the getter that uses it, so the two never drift.


# ── Stable id constants ───────────────────────────────────────────────────────
# Referenced by name from LegacyUpgrades.gd's effect getters, so a typo is a
# compile-time error rather than a silent miss.
const SEED_CAPITAL    := "seed_capital"
const FAMILY_FORTUNE  := "family_fortune"
const EFFICIENCY      := "efficiency"
const LOYAL_STAFF     := "loyal_staff"
const CONNECTIONS     := "connections"
const ESTATE_LAWYERS  := "estate_lawyers"
const AUTO_CLICK_SPEED := "auto_click_speed"
const AUTO_CLICK_POWER := "auto_click_power"
const RUSH_POWER       := "rush_power"
const MINIGAME_BONUS   := "minigame_bonus"


# ── The catalog ───────────────────────────────────────────────────────────────
# Cost note: Legacy is on a SMALL scale so each point feels hard-won. The estate→Legacy
# curve (k_legacy × estate_net ^ alpha — see tuning.tres / EstateWaterfall, tuned
# 2026-06-15 so a first prestige yields ~10–16 Legacy) keeps yields modest, and the
# single-digit first-level costs below are matched to it so a first prestige buys ~1–2
# upgrades the player can feel.
#
# Effect model (set 2026-06-15, modeled on Idle Slayer): the three core accelerators —
# Family Fortune (income), Efficiency (cycle speed), Connections (wage) — COMPOUND, so
# each level is the same relative jump no matter how deep you are (the getters in
# LegacyUpgrades.gd raise (1 + effect_per_level) to the level). Their caps are raised to
# 30 — effectively endless, since the geometric `cost_growth` below is the real brake, so
# there is always a meaningful next level to chase. The other three (Trust Fund flat
# dollars, Loyal Staff discount, Estate Lawyers Legacy-yield) stay additive and modestly
# capped on purpose: compounding a discount heads to free, and compounding the Legacy
# yield would run the whole prestige loop away.
# Verified against sim/Sim.gd's dynasty protocol ("speeds up every time"). Still starting
# numbers meant for on-device feel-tuning, not final balance.
const UPGRADES := [
	{
		"id": SEED_CAPITAL,
		"name": "Trust Fund",
		"category": "Wealth",
		"description": "Every heir is born into more money.",
		"max_level": 10,
		"base_cost": 4,
		"cost_growth": 1.8,
		"effect_per_level": 5000.0,   # +$5,000 starting cash per level
	},
	{
		"id": FAMILY_FORTUNE,
		"name": "Family Fortune",
		"category": "Wealth",
		"description": "The family name itself earns. All property income rises.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.20,     # COMPOUNDING: ×1.20 income per level (see LegacyUpgrades getter)
	},
	{
		"id": EFFICIENCY,
		"name": "Efficiency Experts",
		"category": "Operations",
		"description": "Sharper management. Every property cycles faster.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.12,     # COMPOUNDING: ×1.12 cycle speed per level (see LegacyUpgrades getter)
	},
	{
		"id": LOYAL_STAFF,
		"name": "Loyal Staff",
		"category": "Operations",
		"description": "Hardened family retainers work for less. Hiring costs drop.",
		"max_level": 8,
		"base_cost": 5,
		"cost_growth": 1.9,
		"effect_per_level": 0.08,     # −8% staff hiring cost per level (capped, see getter)
	},
	{
		"id": CONNECTIONS,
		"name": "Old-Money Connections",
		"category": "Career",
		"description": "Doors open faster for old money. Your wage per tap rises.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 4,
		"cost_growth": 1.9,
		"effect_per_level": 0.40,     # COMPOUNDING: ×1.40 wage per tap per level (see LegacyUpgrades getter)
	},
	{
		"id": ESTATE_LAWYERS,
		"name": "Estate Lawyers",
		"category": "Legacy",
		"description": "Clever paperwork. Each succession yields more Legacy.",
		"max_level": 6,
		"base_cost": 10,
		"cost_growth": 2.2,
		"effect_per_level": 0.15,     # +15% Legacy gained at succession per level
	},
	{
		"id": MINIGAME_BONUS,
		"name": "Family Reputation",
		"category": "Legacy",
		"description": "A name worth showing off. A great inheritance minigame pays a bigger bonus.",
		"max_level": 10,
		"base_cost": 8,
		"cost_growth": 2.0,
		# +5% to the minigame's extra-high bonus CAP per level, on top of the 0.25 base
		# (see LegacyUpgrades.minigame_bonus_max). Additive: a steady, ownable climb.
		"effect_per_level": 0.05,
	},
	{
		"id": AUTO_CLICK_SPEED,
		"name": "Restless Hands",
		"category": "Labor",
		"description": "Hold to work faster. Auto-tapping and auto-rushing speed up.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 5,
		"cost_growth": 1.9,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 held auto-tap/rush rate per level
	},
	{
		"id": AUTO_CLICK_POWER,
		"name": "Piecework Bonus",
		"category": "Labor",
		"description": "Every held auto-tap of Clock In pays out more.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 5,
		"cost_growth": 1.9,
		"effect_per_level": 0.25,     # COMPOUNDING: ×1.25 wage per HELD auto-tap per level
	},
	{
		"id": RUSH_POWER,
		"name": "Strong-Arm Tactics",
		"category": "Operations",
		"description": "Lean on it. Each rush-tap drives a property's cycle further.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.20,     # COMPOUNDING: ×1.20 rush advance per level
	},
]


## Return every upgrade definition, in catalog (display) order.
static func all() -> Array:
	return UPGRADES


## Look up one upgrade definition by id, or an empty Dictionary if unknown.
static func get_definition(id: String) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade["id"] == id:
			return upgrade
	push_error("LegacyUpgradeCatalog: unknown upgrade id '%s'" % id)
	return {}


## Legacy cost to buy a specific level of an upgrade (levels are 1-based).
## Level 1 costs base_cost; each further level multiplies by cost_growth.
## Returns 0 for an invalid level so callers never divide by a bogus price.
static func cost_for_level(id: String, level: int) -> int:
	var definition := get_definition(id)
	if definition.is_empty() or level < 1 or level > int(definition["max_level"]):
		return 0
	var base_cost := float(definition["base_cost"])
	var growth := float(definition["cost_growth"])
	# Geometric growth: level 1 = base, level 2 = base×growth, level 3 = base×growth², …
	return int(floor(base_cost * pow(growth, float(level - 1))))


## A human-readable summary of what ONE upgrade does at a given level — shown on
## the shop card ("Level 3 — +60% property income"). At level 0 it describes the
## effect of the first level so the player can see what they'd be buying.
static func describe_effect(id: String, level: int) -> String:
	# Describe the effect the player currently has (level), or the first level's
	# effect when nothing is owned yet, so the card always reads meaningfully.
	var shown_level := maxi(level, 1)
	var definition := get_definition(id)
	if definition.is_empty():
		return ""
	var per_level := float(definition["effect_per_level"])

	# The three compounding accelerators show their TOTAL multiplier at this level
	# (e.g. "×6.19 property income"), since (1 + per_level) ^ level is what the
	# LegacyUpgrades getters actually apply. The additive upgrades keep the "+X%" /
	# "+$X" wording, which reads true for their linear formula.
	match id:
		SEED_CAPITAL:
			var bonus := per_level * float(shown_level)
			return "+%s starting cash" % Money.of(bonus).display()
		FAMILY_FORTUNE:
			return "×%.2f property income" % pow(1.0 + per_level, float(shown_level))
		EFFICIENCY:
			return "×%.2f cycle speed" % pow(1.0 + per_level, float(shown_level))
		LOYAL_STAFF:
			return "−%d%% staff hiring cost" % int(round(per_level * 100.0 * float(shown_level)))
		CONNECTIONS:
			return "×%.2f wage per tap" % pow(1.0 + per_level, float(shown_level))
		ESTATE_LAWYERS:
			return "+%d%% Legacy per succession" % int(round(per_level * 100.0 * float(shown_level)))
		MINIGAME_BONUS:
			# Total cap = the 0.25 base + 5%/level (kept in sync with LegacyUpgrades).
			return "up to +%d%% inheritance bonus" % int(round(25.0 + per_level * 100.0 * float(shown_level)))
		AUTO_CLICK_SPEED:
			return "×%.2f auto-tap / auto-rush speed" % pow(1.0 + per_level, float(shown_level))
		AUTO_CLICK_POWER:
			return "×%.2f wage per held auto-tap" % pow(1.0 + per_level, float(shown_level))
		RUSH_POWER:
			return "×%.2f rush advance" % pow(1.0 + per_level, float(shown_level))
	return ""
