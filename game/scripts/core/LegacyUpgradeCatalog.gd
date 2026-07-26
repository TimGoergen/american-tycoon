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
const RUSH_POWER       := "rush_power"
const MINIGAME_BONUS   := "minigame_bonus"
const FRENZY_INTENSITY := "frenzy_intensity"
const FRENZY_DURATION  := "frenzy_duration"
const COOLING_SYSTEMS  := "cooling_systems"
const RAPID_RESTART    := "rapid_restart"


# ── The catalog ───────────────────────────────────────────────────────────────
# Cost note: Legacy Gems are on a SMALL scale so each gem feels hard-won. The estate→Legacy curve
# (k_legacy × estate_net ^ alpha — see tuning.tres / EstateWaterfall) is the "reward for pushing"
# dial. The 2026-07-23 re-tune STEEPENED it (alpha 0.35, k 0.16) so a full Earth run mints ~830
# gems and out-earning clearly pays, and raised the global cost multiplier to 3.0 to keep the
# richer yields from buying out the shop (see sim/PrestigeStudy.gd for the yield-vs-cost tables).
# With that, first-level costs run ~3 (Trust Fund) to ~30, comfortably bought by a decent run,
# while the max-level compounders cost billions — the never-reached "endless chase" top end.
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
		# The cheapest upgrade and the intended FIRST buy: base 1 → 3 Legacy after the ×3 cost
		# multiplier, so even a modest first prestige can afford something (Tim, 2026-07-23). Safe to
		# keep this low: Trust Fund is a flat, capped, ADDITIVE bonus, not a compounding runaway
		# vector, so its price doesn't affect the runaway the cost multiplier guards against.
		"base_cost": 1,
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
		"id": RUSH_POWER,
		"name": "Strong-Arm Tactics",
		"category": "Operations",
		"description": "Lean on it. Each rush-tap drives a property's cycle further.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.20,     # COMPOUNDING: ×1.20 rush advance per level
	},
	{
		"id": FRENZY_INTENSITY,
		"name": "Killer Instinct",
		"category": "Frenzy",
		"description": "In a market frenzy you go for the throat. TURBO's multiplier climbs higher.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 the TURBO bonus (amount above 1×) per level
	},
	{
		"id": FRENZY_DURATION,
		"name": "Second Wind",
		"category": "Frenzy",
		"description": "The frenzy just won't quit. Every TURBO burn lasts longer.",
		"max_level": 30,              # effectively endless: geometric cost is the real brake
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 burn duration per level
	},
	{
		"id": COOLING_SYSTEMS,
		"name": "Cooling Systems",
		"category": "Rush",
		"description": "Better heat sinks. The safe cruise rush bonus climbs a point per level.",
		# ADDITIVE with a hard cap, NOT compounding: this is a limitation-remover, and a
		# compounding limitation-remover runs away (see the effect-model note above). Level 5
		# lifts cruise from +25% to +30% — the old always-on cap, re-earned, NEVER exceeded
		# (Tim 2026-07-16: Hot/Critical bonuses stay exclusive to riding overdrive).
		"max_level": 5,
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.01,     # +0.01 cruise bonus per level (see LegacyUpgrades getter)
	},
	{
		"id": RAPID_RESTART,
		"name": "Rapid Restart",
		"category": "Rush",
		"description": "Seasoned cool-down crews. Overheat lockouts pass faster.",
		# ADDITIVE with a hard cap, same rationale as Cooling Systems: level 5 halves the
		# lockout (drain AND re-arm shrink together) — overheating always stings, but a
		# storied dynasty recovers faster. Never reaches zero by design.
		"max_level": 5,
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.10,     # −10% total lockout time per level (see LegacyUpgrades getter)
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


## A global multiplier on EVERY Legacy upgrade's cost — the "how much a prestige buys" dial. 1.0 =
## the authored prices; >1 makes upgrades pricier so the same gems buy fewer levels, which slows the
## prestige multiplier runaway (Tim 2026-07-14). A `static var` (not const) so DynastyState can set
## it from tuning.legacy_upgrade_cost_multiplier at construction/load — the same "config a stateless
## table from tuning" pattern GoldBubbles.tier_speed_px uses. Applied in cost_for_level below, so
## every cost query (buy, badge, invested total) sees the same price.
static var cost_multiplier := 1.0


## Legacy cost to buy a specific level of an upgrade (levels are 1-based).
## Level 1 costs base_cost; each further level multiplies by cost_growth.
## Returns 0 for an invalid level so callers never divide by a bogus price.
static func cost_for_level(id: String, level: int) -> int:
	var definition := get_definition(id)
	if definition.is_empty() or level < 1 or level > int(definition["max_level"]):
		return 0
	var base_cost := float(definition["base_cost"])
	var growth := float(definition["cost_growth"])
	# Geometric growth: level 1 = base, level 2 = base×growth, level 3 = base×growth², … then the
	# global cost_multiplier scales the whole ladder.
	return int(floor(base_cost * pow(growth, float(level - 1)) * cost_multiplier))


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
	# LegacyUpgrades getters actually apply — up to two decimals, trailing zeros
	# dropped ("×2", never "×2.00"; Tim, 2026-07-03). The additive upgrades keep the
	# "+X%" / "+$X" wording, which reads true for their linear formula.
	match id:
		SEED_CAPITAL:
			var bonus := per_level * float(shown_level)
			return "+%s starting cash" % Money.of(bonus).display()
		FAMILY_FORTUNE:
			return "×%s property income" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		EFFICIENCY:
			return "×%s cycle speed" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		LOYAL_STAFF:
			return "−%d%% staff hiring cost" % int(round(per_level * 100.0 * float(shown_level)))
		CONNECTIONS:
			return "×%s wage per tap" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		ESTATE_LAWYERS:
			return "+%d%% Legacy per succession" % int(round(per_level * 100.0 * float(shown_level)))
		MINIGAME_BONUS:
			# Total cap = the 0.25 base + 5%/level (kept in sync with LegacyUpgrades).
			return "up to +%d%% inheritance bonus" % int(round(25.0 + per_level * 100.0 * float(shown_level)))
		AUTO_CLICK_SPEED:
			return "×%s auto-tap / auto-rush speed" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		RUSH_POWER:
			return "×%s rush advance" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		FRENZY_INTENSITY:
			return "×%s TURBO power" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		FRENZY_DURATION:
			return "×%s TURBO duration" % Money.trim(pow(1.0 + per_level, float(shown_level)), 2)
		COOLING_SYSTEMS:
			# Shown as the POINTS added on top of the tuned cruise base (the base itself is a
			# live Balance Tuning knob, so the card can't quote a fixed total honestly).
			return "+%d%% safe cruise rush bonus" % int(round(per_level * 100.0 * float(shown_level)))
		RAPID_RESTART:
			return "−%d%% overheat lockout time" % int(round(per_level * 100.0 * float(shown_level)))
	return ""
