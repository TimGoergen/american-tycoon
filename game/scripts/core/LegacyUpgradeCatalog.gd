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
# Auto-Purchase Mode (restructured 2026-08-07). `acquisitions_desk` and `head_hunters` were the
# old pair; both are gone. Existing saves keep those dead ids in their upgrade dictionary and that
# is harmless — LegacyUpgrades.load_save_dict copies unknown ids in without validating them, and
# nothing anywhere scans that dictionary and resolves it against this catalog (the only iteration
# over it, in DynastyState's v13 migration, walks a hardcoded id list). No migration needed.
#
# IF YOU ADD a feature that iterates upgrade levels and calls get_definition() on each — a "total
# invested" readout, an "everything you own" list — filter to catalog-known ids or it will crash
# on those ghosts.
const AUTO_PURCHASE_UNLOCK   := "auto_purchase_unlock"
const AUTO_PURCHASE_QUANTITY := "auto_purchase_quantity"
const AUTO_PURCHASE_CADENCE  := "auto_purchase_cadence"


# ── The catalog ───────────────────────────────────────────────────────────────
# Cost note: Legacy Gems are on a SMALL scale so each gem feels hard-won. The estate→Legacy curve
# (k_legacy × estate_net ^ alpha — see tuning.tres / EstateWaterfall) is the "reward for pushing"
# dial. The 2026-07-23 re-tune STEEPENED it (alpha 0.35, k 0.16) so a full Earth run mints ~830
# gems and out-earning clearly pays, and raised the global cost multiplier to 3.0 to keep the
# richer yields from buying out the shop (see sim/PrestigeStudy.gd for the yield-vs-cost tables).
# With that, first-level costs run ~3 (Trust Fund) to ~30, comfortably bought by a decent run,
# while the max-level compounders cost billions — the never-reached "endless chase" top end.
#
# TWO TRACKS SIT OUTSIDE THAT RANGE ON PURPOSE (Tim, 2026-08-01): the Acquisitions Desk and Head
# Hunters open at 5,000 Legacy each — roughly six full Earth runs — because automating the buying
# and hiring loops is meant to be a late, earned luxury rather than an early convenience pickup.
# They are the shop's PREMIUM tier; read their entries' notes before repricing either.
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
		# Utility restructure (Endgame Economy, Tim 2026-07-28): same +$50K ceiling over
		# twice the levels at half the step, so the climb lives longer under the new gem
		# curve. Level 1 stays the cheapest first-prestige buy (Tim, 2026-07-23) — a flat,
		# capped, ADDITIVE bonus, not a runaway vector.
		"max_level": 20,
		"base_cost": 1,
		"cost_growth": 1.8,
		"effect_per_level": 2500.0,   # +$2,500 starting cash per level
	},
	{
		"id": FAMILY_FORTUNE,
		"name": "Family Fortune",
		"category": "Wealth",
		"description": "The family name itself earns. All property income rises.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 6,
		"cost_growth": 2.8,
		"effect_per_level": 0.20,     # COMPOUNDING: ×1.20 income per level (see LegacyUpgrades getter)
	},
	{
		"id": EFFICIENCY,
		"name": "Efficiency Experts",
		"category": "Operations",
		"description": "Sharper management. Every property cycles faster.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 6,
		"cost_growth": 2.8,
		"effect_per_level": 0.12,     # COMPOUNDING: ×1.12 cycle speed per level (see LegacyUpgrades getter)
	},
	{
		"id": LOYAL_STAFF,
		"name": "Loyal Staff",
		"category": "Operations",
		"description": "Hardened family retainers work for less. Hiring costs drop.",
		# Utility restructure: same −64% ceiling over 16 half-steps; growth raised so the
		# deep levels price on the new gem curve (a discount must stay capped — free staff).
		"max_level": 16,
		"base_cost": 5,
		"cost_growth": 2.6,
		"effect_per_level": 0.04,     # −4% staff hiring cost per level (capped, see getter)
	},
	{
		"id": CONNECTIONS,
		"name": "Old-Money Connections",
		"category": "Career",
		"description": "Doors open faster for old money. Your wage per tap rises.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 4,
		"cost_growth": 2.7,
		"effect_per_level": 0.40,     # COMPOUNDING: ×1.40 wage per tap per level (see LegacyUpgrades getter)
	},
	{
		"id": ESTATE_LAWYERS,
		"name": "Estate Lawyers",
		"category": "Legacy",
		"description": "Clever paperwork. Each succession yields more Legacy.",
		# Utility restructure: same +90% ceiling over 12 half-steps; the STEEPEST utility
		# growth, because the gem-yield cap is load-bearing (compounding it runs the loop away).
		"max_level": 12,
		"base_cost": 10,
		"cost_growth": 3.8,
		"effect_per_level": 0.075,    # +7.5% Legacy gained at succession per level
	},
	{
		"id": MINIGAME_BONUS,
		"name": "Family Reputation",
		"category": "Legacy",
		"description": "A name worth showing off. A great inheritance minigame pays a bigger bonus.",
		# Utility restructure: same +50% ceiling over 20 half-steps (steepening carries the price).
		"max_level": 20,
		"base_cost": 8,
		"cost_growth": 2.0,
		# +2.5% to the minigame's extra-high bonus CAP per level, on top of the 0.25 base
		# (see LegacyUpgrades.minigame_bonus_max). Additive: a steady, ownable climb.
		"effect_per_level": 0.025,
	},
	{
		"id": AUTO_CLICK_SPEED,
		"name": "Restless Hands",
		"category": "Labor",
		"description": "Hold to work faster. Auto-tapping and auto-rushing speed up.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 5,
		"cost_growth": 2.7,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 held auto-tap/rush rate per level
	},
	{
		"id": RUSH_POWER,
		"name": "Strong-Arm Tactics",
		"category": "Operations",
		"description": "Lean on it. Each rush-tap drives a property's cycle further.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 6,
		"cost_growth": 2.8,
		"effect_per_level": 0.20,     # COMPOUNDING: ×1.20 rush advance per level
	},
	{
		"id": FRENZY_INTENSITY,
		"name": "Killer Instinct",
		"category": "Frenzy",
		"description": "In a market frenzy you go for the throat. TURBO's multiplier climbs higher.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 6,
		"cost_growth": 2.8,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 the TURBO bonus (amount above 1×) per level
	},
	{
		"id": FRENZY_DURATION,
		"name": "Second Wind",
		"category": "Frenzy",
		"description": "The frenzy just won't quit. Every TURBO burn lasts longer.",
		"max_level": 9999,            # UNCAPPED (Endgame Economy, Tim 2026-07-28): the steepening cost curve is the brake
		"base_cost": 6,
		"cost_growth": 2.8,
		"effect_per_level": 0.15,     # COMPOUNDING: ×1.15 burn duration per level
	},
	{
		"id": COOLING_SYSTEMS,
		"name": "Cooling Systems",
		"category": "Rush",
		"description": "Better heat sinks. The safe cruise rush bonus climbs with every level.",
		# ADDITIVE with a hard cap, NOT compounding: this is a limitation-remover, and a
		# compounding limitation-remover runs away (see the effect-model note above). Level 10
		# lifts cruise from +25% to +30% — the old always-on cap, re-earned, NEVER exceeded
		# (Tim 2026-07-16). Restructured to 10 half-steps; deliberately kept the CHEAPEST
		# climb with Rapid Restart — QoL must not feel withheld (Endgame Economy).
		"max_level": 10,
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.005,    # +0.005 cruise bonus per level (see LegacyUpgrades getter)
	},
	{
		"id": RAPID_RESTART,
		"name": "Rapid Restart",
		"category": "Rush",
		"description": "Seasoned cool-down crews. Overheat lockouts pass faster.",
		# ADDITIVE with a hard cap, same rationale as Cooling Systems: max level halves the
		# lockout (drain AND re-arm shrink together) — overheating always stings, but a
		# storied dynasty recovers faster. Never reaches zero by design. Restructured to
		# 10 half-steps; kept cheap alongside Cooling Systems (QoL, Endgame Economy).
		"max_level": 10,
		"base_cost": 6,
		"cost_growth": 2.0,
		"effect_per_level": 0.05,     # −5% total lockout time per level (see LegacyUpgrades getter)
	},
	# --- Auto-Purchase Mode: one unlock plus two upgrade axes -------------------------------------
	# Restructured 2026-08-07 (Plans/Auto_Purchase_Restructure.md), replacing the single
	# "Acquisitions Desk" track and deleting "Head Hunters" outright — bulk hire is now free for
	# everyone, on the argument that pressing HIRE 150 times is a defect, not a feature, and
	# charging gems to fix a defect is charging for a bug (the same call that made retention
	# bulk-buy free).
	#
	# All three prices are PRE-multiplier. Every cost is scaled by
	# tuning.legacy_upgrade_cost_multiplier (3.0), so 5000/3 here is what lands level 1 on exactly
	# 5,000. The literal is rounded UP in its last digit on purpose, so the floor() in
	# cost_for_level can never drop it to 4,999.
	#
	# The two ladders' base/growth were FITTED, not guessed — sim/AutoPurchaseCostStudy.gd, against
	# a real 14-generation playout. Re-run it after any economy retune.
	{
		"id": AUTO_PURCHASE_UNLOCK,
		"name": "Acquisitions Desk",
		"category": "Operations",
		# The buy rule is spelled out on purpose: a mode that spends the player's money on a rule
		# they cannot see reads as a bug, not a feature.
		"description": "Buyers work your current era, taking its cheapest holdings first. Rushing is closed while the desk is open.",
		# A gateway, not a magnitude. One level, and on its own it is the weakest working version of
		# the mode: ONE purchase every 3.0s. Everything beyond that is the two tracks below, which
		# is what makes 5,000 a fair price for it rather than a cheap one.
		"max_level": 1,
		"base_cost": 1666.6666666667,
		"cost_growth": 1.0,           # single level; growth never applies
		"effect_per_level": 1.0,      # unlocks the mode (see LegacyUpgrades.auto_purchase_unlocked)
	},
	{
		"id": AUTO_PURCHASE_QUANTITY,
		"name": "Buying Power",
		"category": "Operations",
		"description": "More buyers on the floor. Each level buys one more holding every round.",
		# NOMINALLY 30, but the shared steepening curve is the real ceiling: by level 30 the
		# steepening term alone is ~1e17, so nobody reaches it. Fitted depth at the summit is ~15
		# levels, and the track never maxes — the same "uncapped on a steepening curve" shape the
		# compounders use, which is what "cost curves alone govern the runaway" asks for.
		"max_level": 30,
		"base_cost": 1666.6666666667,
		"cost_growth": 1.6,           # FITTED — see AutoPurchaseCostStudy
		"effect_per_level": 1.0,      # +1 purchase per tick per level
	},
	{
		"id": AUTO_PURCHASE_CADENCE,
		"name": "Standing Orders",
		"category": "Operations",
		"description": "Faster paperwork. Each level shortens the wait between buying rounds.",
		# Capped at 11 by PHYSICS, not by cost: 3.0s down to a 0.25s floor in 0.25s steps. Eleven
		# levels is far too short for the steepening term to bite — at Buying Power's growth the
		# whole ladder totalled under a billion and maxed by generation 3, i.e. the track would
		# have been decorative. Its climb has to come from growth instead, hence 3.5 against 1.6.
		"max_level": 11,
		"base_cost": 1666.6666666667,
		"cost_growth": 3.5,           # FITTED — see AutoPurchaseCostStudy
		"effect_per_level": 0.25,     # seconds shaved off the cadence per level
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

## The cost curve's STEEPENING `s` (Plans/Endgame_Economy.md "Shape 2", Tim 2026-07-28): the
## step from level n to n+1 costs ×(cost_growth × s^n) — the growth factor itself grows each
## level, so the curve starts near the authored geometric and steepens without limit. That
## ever-steepening deep end is what lets the compounding tracks run uncapped: any gem fortune
## buys only a few more levels than a much smaller one. 1.0 = the old flat geometric. Set
## from tuning.legacy_cost_steepening at dynasty construction/load, like cost_multiplier.
static var cost_steepening := 1.0


## Legacy cost to buy a specific level of an upgrade (levels are 1-based).
## Level 1 costs base_cost; the step to level n multiplies by cost_growth × s^(n-2)
## (s = cost_steepening), so cost(n) = base × growth^(n-1) × s^((n-1)(n-2)/2) — the
## closed form of the progressively steepening curve. Returns 0 for an invalid level
## so callers never divide by a bogus price.
static func cost_for_level(id: String, level: int) -> int:
	var definition := get_definition(id)
	if definition.is_empty() or level < 1 or level > int(definition["max_level"]):
		return 0
	var base_cost := float(definition["base_cost"])
	var growth := float(definition["cost_growth"])
	var steps := float(level - 1)
	var steepen := pow(cost_steepening, steps * (steps - 1.0) / 2.0)
	return int(floor(base_cost * pow(growth, steps) * steepen * cost_multiplier))


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
		AUTO_PURCHASE_UNLOCK:
			# One level, and it says what the mode does on its own — deliberately modest, because
			# the two tracks below are where the power is.
			return "auto-buys 1 holding every 3s"
		AUTO_PURCHASE_QUANTITY:
			# The unlock already grants one purchase, so level N buys N + 1. Quoting the TOTAL
			# rather than the increment is what the player actually wants to compare.
			return "auto-buys %d holdings per round" % (shown_level + 1)
		AUTO_PURCHASE_CADENCE:
			# The base cadence being shaved from is a live tuning knob, so the card quotes the
			# shave alone rather than a total that could quietly go stale.
			return "%ss faster between rounds" % Money.trim(per_level * float(shown_level), 2)
	return ""
