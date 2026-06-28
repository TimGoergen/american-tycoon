class_name EpochCatalog

# The fixed table of EPOCHS — the alien-contact eras that staffing is now keyed to
# (see Plans/Epoch_Staffing_System.md). A pure DATA TABLE in code, the same shape as
# LegacyUpgradeCatalog.gd: static, stateless, no scene tree.
#
# The single currency stays Earth dollars. An epoch is flavor + a magnitude gate +
# a staff tier:
#   - Each epoch has a *total economic value* — the dollars that economy is worth.
#     Earth's is the existing Earth target (~$103.6T). Once a generation has EARNED
#     that whole value, it has "consumed" the economy and makes contact with the next
#     civilization, opening the next (orders-of-magnitude larger) epoch (GDD §10 / Tim
#     2026-06-16). That climb is what justifies the economy reaching absurd scales.
#   - Each epoch unlocks a new STAFFER TIER for every property: an alien-tech upgrade
#     over the previous staffer that multiplies that property's income. Tier 1 = Earth
#     (multiplier 1.0 — just enables automation, matching old behavior); tiers 2+ are
#     the large alien jumps.
#
# Tiers are 1-based. Index 0 of the array is tier 1 (Earth). The Earth economy value is
# NOT stored here — it is sourced from TuningConfig.earth_economy_target and scaled by
# `economy_scale` so the win/contact threshold has a single source of truth.
#
# v1 ships Earth + 5 alien races (Plans doc §8 named the first 3; Quartzite and
# Chronophage were added in Phase 4).
#
# EPOCH PACING (reworked 2026-06-27 — the "second epoch stalls out" fix). The two
# ladders below race each other: economy_scale sets how much you must EARN to clear
# an epoch, and staff_income_multiplier sets how much your income GROWS in it. Time
# to clear an epoch is roughly (must-earn) / (income), so the per-epoch duration
# ratio is economy_step / staff_step (proven by sim/Sim.gd _run_epoch_timing_study).
# The old v1 numbers (economy ×1000/epoch, staff ×~17/epoch) made every epoch ~60×
# LONGER than the last — a guaranteed wall by epoch 2. We now use matched GEOMETRIC
# ladders with staff stepping slightly faster than the economy:
#   economy_scale          = 30^(tier-1)  -> 1, 30, 900, 27k, 810k, 24.3M
#   staff_income_multiplier = 40^(tier-1) -> 1, 40, 1.6k, 64k, 2.56M, 102.4M
# Because staff_step (40) > economy_step (30), each epoch is a touch FASTER than the
# one before (ratio ~0.75) — the GDD §5.1 "it speeds up every time" feel — instead of
# slower. Still first-pass feel-tuning values; the dynasty sim + epoch study verify them.


# Each epoch is one dictionary with these keys:
#   tier               — 1-based era number, also the property staff_tier it unlocks
#   civilization       — display name of the race Earth is trading with
#   home_planet        — flavor, shown on the first-contact screen
#   currency_flavor    — that civilization's currency name (flavor only; we stay in $)
#   economy_scale      — that economy's total value as a MULTIPLE of Earth's economy.
#                        Earth = 1; consuming `earth_target × economy_scale` dollars of
#                        lifetime earnings advances OUT of this epoch into the next.
#   staff_income_multiplier — income multiplier a property gets while staffed at this tier
#   contact_line       — the narrator's first-contact line (empty for Earth)
#   staffer_names      — the staffer title shown per property, indexed by ladder position
#                        (0–11 are the GDD §4 Earth properties; index 12+ are alien property
#                        types added at later epochs — GDD §5.5 site 2). One entry per property.
# (Alien staff cost is no longer a per-epoch multiplier; it is derived from economy_scale
#  × earth_economy_target in EconomyState.get_staff_cost — see TuningConfig.staff_cost_*.)
const EPOCHS := [
	{
		"tier": 1,
		"civilization": "Earth",
		"home_planet": "Earth",
		"currency_flavor": "Dollars",
		"economy_scale": 1.0,
		"staff_income_multiplier": 1.0,
		# Earth is where every run begins — there is no contact beat for it.
		"contact_line": "",
		# Earth staffers — these mirror the staffer_name in each property's .tres so the
		# tier system has one authoritative table; the .tres field is now vestigial.
		"staffer_names": [
			"ATM Technician", "Botanical Manager", "NFT Community Manager",
			"Tax Strategist", "Logistics Director", "Freshness Consultant",
			"Portfolio Analyst", "Property Manager", "Downline Coordinator",
			"Fund Administrator", "Lobbyist", "Chief of Staff",
			# Rungs 13–17 are the alien property types (Photon Exchange, Data Foundry, Spore Bank,
			# Prism Vault, Time Bank). Earth never staffs them (each is locked until its epoch),
			# but the roster stays the same length as the property ladder so indexing always works.
			"Exchange Floor Boss",
			"Data Foundry Manager", "Spore Bank Manager", "Vault Keeper", "Time Bank Manager",
		],
	},
	{
		"tier": 2,
		"civilization": "Luminari Collective",
		"home_planet": "Solaria Prime",
		"currency_flavor": "Photons",
		"economy_scale": 30.0,
		"staff_income_multiplier": 40.0,
		"contact_line": "You bought the Earth. The Luminari Collective noticed. " \
			+ "Now your money moves at the speed of light — and so does everyone else's.",
		# Energy/light beings — money now moves at the speed of light.
		"staffer_names": [
			"Photon Teller", "Solar Cultivator", "Lumen Curator",
			"Flux Auditor", "Lightstream Courier", "Radiance Cleaner",
			"Photon Day-Trader", "Solar Flipper", "Aura Recruiter",
			"Plasma Fund Manager", "Light-Speed Lobbyist", "Luminous Chief of Staff",
			"Photon Exchange Director",
			"Photon Foundry", "Light Spore Bank", "Prism Keeper", "Lumen Time Bank",
		],
	},
	{
		"tier": 3,
		"civilization": "Geth-Sentinel Grid",
		"home_planet": "Rannoch-01",
		"currency_flavor": "Logic Nodes",
		"economy_scale": 900.0,
		"staff_income_multiplier": 1_600.0,
		"contact_line": "The Geth-Sentinel Grid comes online. Every trade, every fund, " \
			+ "every hustle — handed to machines that never sleep, never quit, never ask why.",
		# Cybernetic collective — finance run entirely by machines.
		"staffer_names": [
			"Autonomous Teller Unit", "Cultivation Algorithm", "Mint Subroutine",
			"Tax Optimization Daemon", "Logistics Mainframe", "Laundering Protocol",
			"High-Frequency Core", "Property Acquisition Bot", "Recruitment Network Node",
			"Quant Supercluster", "Policy Compiler", "Executive Mainframe",
			"Exchange Daemon",
			"Foundry Core", "Spore Daemon", "Vault Subroutine", "Chrono Daemon",
		],
	},
	{
		"tier": 4,
		"civilization": "Mycelium Unity",
		"home_planet": "Spore-Deep",
		"currency_flavor": "Spores",
		"economy_scale": 27_000.0,
		"staff_income_multiplier": 64_000.0,
		"contact_line": "The Mycelium Unity spreads into your holdings. Money that grows " \
			+ "itself now — branching through the dark, feeding on everything it touches.",
		# Fungal hive-mind — money that literally spreads and self-replicates.
		"staffer_names": [
			"Spore-Cash Node", "Mycelial Grove-Tender", "Fungal Token Bloom",
			"Rhizome Financier", "Spore-Drift Network", "Decomposition Specialist",
			"Hyphae Trader", "Overgrowth Developer", "Mycelial Downline",
			"Spore Cloud Fund", "Root-Network Lobbyist", "Hive-Mind Chief of Staff",
			"Spore-Market Maker",
			"Mycelial Foundry", "Spore Banker", "Fungal Vault", "Spore Time Bank",
		],
	},
	{
		"tier": 5,
		"civilization": "Quartzite Conglomerate",
		"home_planet": "Geode-7",
		"currency_flavor": "Prisms",
		"economy_scale": 810_000.0,
		"staff_income_multiplier": 2_560_000.0,
		"contact_line": "The Quartzite Conglomerate refracts your fortune. Wealth, " \
			+ "crystallized — harder than diamond, and just as cold.",
		# Crystalloid life — capital made permanent, faceted, light bent to its will.
		"staffer_names": [
			"Prism Teller", "Crystal Cultivator", "Geode Curator",
			"Refraction Auditor", "Lattice Courier", "Facet Cleaner",
			"Quartz Day-Trader", "Geode Flipper", "Prism Recruiter",
			"Crystalline Fund Manager", "Bedrock Lobbyist", "Diamond Chief of Staff",
			"Prism Exchange Broker",
			"Crystal Foundry", "Crystal Spore Vault", "Prism Vault Keeper", "Crystal Time Bank",
		],
	},
	{
		"tier": 6,
		"civilization": "Chronophage Enclave",
		"home_planet": "Tempus",
		"currency_flavor": "Seconds",
		"economy_scale": 24_300_000.0,
		"staff_income_multiplier": 102_400_000.0,
		"contact_line": "The Chronophage Enclave opens the quarter. They sell you time " \
			+ "itself, by the second — at a markup you will never live long enough to repay.",
		# Time-eaters — they trade in stolen moments; your money compounds across hours
		# that were taken from someone else.
		"staffer_names": [
			"Second-Hand Teller", "Chrono Cultivator", "Moment Curator",
			"Hourglass Auditor", "Timeline Courier", "Era Cleaner",
			"Microsecond Day-Trader", "Era Flipper", "Tomorrow Recruiter",
			"Temporal Fund Manager", "Eternity Lobbyist", "Time-Lord Chief of Staff",
			"Temporal Exchange Lord",
			"Chrono Foundry", "Eternal Spore Bank", "Timeless Vault", "Time Banker",
		],
	},
]


## How many epochs (tiers) exist — also the maximum staff_tier any property can reach.
static func tier_count() -> int:
	return EPOCHS.size()


## The epoch definition for a 1-based tier, or an empty Dictionary if out of range.
static func get_epoch(tier: int) -> Dictionary:
	if tier < 1 or tier > EPOCHS.size():
		return {}
	return EPOCHS[tier - 1]


## Lifetime dollars a generation must EARN to consume this epoch's economy and make
## contact with the next civilization. Sourced from the Earth target so the win/contact
## threshold has one home; alien epochs scale it up by their economy_scale.
static func consume_threshold(tier: int, earth_economy_target: float) -> float:
	var epoch := get_epoch(tier)
	if epoch.is_empty():
		return INF  # unknown tier never advances
	return earth_economy_target * float(epoch["economy_scale"])


## Income multiplier a property earns while staffed at this tier (1.0 for Earth).
static func staff_income_multiplier(tier: int) -> float:
	var epoch := get_epoch(tier)
	if epoch.is_empty():
		return 1.0
	return float(epoch["staff_income_multiplier"])


## This epoch's total economic value as a MULTIPLE of Earth's economy (Earth = 1).
## Staff cost for an alien tier is anchored to this (× earth_economy_target), and the
## first-contact beat shows the jump between consecutive epochs.
static func economy_scale(tier: int) -> float:
	var epoch := get_epoch(tier)
	if epoch.is_empty():
		return 1.0
	return float(epoch["economy_scale"])


## The staffer's title for a given property at a given tier (e.g. "Photon Teller").
## Falls back to an empty string for an unknown tier/property.
static func staffer_name(tier: int, property_index: int) -> String:
	var epoch := get_epoch(tier)
	if epoch.is_empty():
		return ""
	var names: Array = epoch["staffer_names"]
	if property_index < 0 or property_index >= names.size():
		return ""
	return String(names[property_index])


## Display name of the civilization for a tier (e.g. "Luminari Collective").
static func civilization(tier: int) -> String:
	var epoch := get_epoch(tier)
	return String(epoch.get("civilization", "")) if not epoch.is_empty() else ""


## The narrator's first-contact line for a tier (shown on the FirstContactOverlay).
## Empty for Earth (tier 1), which has no contact beat.
static func contact_line(tier: int) -> String:
	var epoch := get_epoch(tier)
	return String(epoch.get("contact_line", "")) if not epoch.is_empty() else ""
