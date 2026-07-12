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
# EPOCH PACING (Phase 3 rework, 2026-07-11 — the "every epoch too fast" fix; plan
# Plans/Epoch_Depth_Pass.md §4). economy_scale sets how much you must EARN to clear an
# epoch; the alien COHORT magnitudes (per-property .tres) set how much your income grows
# in it. Time to clear ~= (must-earn) / (income).
#   economy_scale = 60^(tier-1)  -> 1, 60, 3.6k, 216k, 12.96M, 777.6M   (the threshold ladder)
# The cohort .tres magnitudes are generated to grow at a slightly SMALLER step than the
# threshold (economy_step / DRIFT, DRIFT ~1.08), so income grows a touch slower than the
# goalpost and each epoch runs ~1.05x LONGER than the last — Tim's 2026-07-11 target (gentle
# drift; prestige, not epoch churn, is the acceleration fantasy). The earlier 30^/40^ "race"
# model is retired: it assumed a linear per-tier staff factor that the Phase 1/2 per-block
# staff ladder + four-property cohorts broke (see the sim's pacing MEASUREMENT + PLAYOUT,
# which build the real economy instead of projecting). staff_income_multiplier below is now
# only the per-block staff STEP scaler, not the epoch income law. First-pass; sim-verified,
# device pass owed (Phase 4).


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
			# Cohort siblings (Phase 2, property indices 17–31). Earth never staffs them
			# (each is locked until its epoch), but every roster spans all 32 properties.
			"Beam Utilities Foreman", "Futures Desk Chief", "Dyson Site Manager",
			"Server City Superintendent", "Mine Boss", "Labor Agency Director",
			"Network Line Manager", "Refinery Foreman", "Co-op Chairman",
			"Gem Floor Manager", "Lens Works Foreman", "Realty Broker",
			"Deadline Desk Manager", "Market Stall Keeper", "Escrow Officer",
			# Cohort 5th members (Phase 3, indices 32–36): Starcore, Singularity, Biosphere,
			# Geode, Causality. Earth never staffs them; the roster stays ladder-length.
			"Starcore Site Manager", "Singularity Project Director", "Biosphere Estate Director",
			"Geode Holdings Director", "Causality Fund Director",
		],
	},
	{
		"tier": 2,
		"civilization": "Luminari Collective",
		"home_planet": "Solaria Prime",
		"currency_flavor": "Photons",
		"economy_scale": 60.0,
		"staff_income_multiplier": 40.0,
		# Energy/light beings — money now moves at the speed of light. The hail is THEIR
		# first words (radiant, warm, faintly condescending); the contact_line is our
		# narrator's deadpan capper. Each civilization gets its own voice + accent color
		# so no two contacts read alike (Tim, 2026-07-07).
		"hail": "Your little sun is charming. We measured your fortune the moment " \
			+ "it crossed the void — such a lovely flicker. Come. Shine with us.",
		"contact_line": "Beings of living light, and they still noticed your money first. " \
			+ "Everything moves at lightspeed here. Including mistakes.",
		"accent_color": Color("#B8730A"),  # solar amber
		"staffer_names": [
			"Photon Teller", "Solar Cultivator", "Lumen Curator",
			"Flux Auditor", "Lightstream Courier", "Radiance Cleaner",
			"Photon Day-Trader", "Solar Flipper", "Aura Recruiter",
			"Plasma Fund Manager", "Light-Speed Lobbyist", "Luminous Chief of Staff",
			"Photon Exchange Director",
			"Photon Foundry", "Light Spore Bank", "Prism Keeper", "Lumen Time Bank",
			# Cohort siblings 17–31; 17–19 are the Luminari's own (home-epoch) staffers,
			# mirroring those .tres staffer_name fields.
			"Beam Grid Operator", "Flare Futures Broker", "Dyson Site Foreman",
			"Lumen Server Warden", "Photonic Mine Sifter", "Radiant Labor Broker",
			"Lightline Weaver", "Solar Compost Refiner", "Terraform Ray Steward",
			"Prism Floor Trader", "Sunbeam Lens Grinder", "Lightspire Concierge",
			"Sundial Enforcer", "Golden-Hour Appraiser", "Eternal Dawn Notary",
			# Cohort 5th members (indices 32–36); index 32 (Starcore Syndicate) is the Luminari's
			# own grandest home-epoch venture, mirroring its .tres staffer_name.
			"Stellar Core Magnate", "Event-Horizon Financier", "Living-World Radiance Steward",
			"Prismatic Dominion Curator", "Lightcone Causality Broker",
		],
	},
	{
		"tier": 3,
		"civilization": "Geth-Sentinel Grid",
		"home_planet": "Rannoch-01",
		"currency_flavor": "Logic Nodes",
		"economy_scale": 3_600.0,
		"staff_income_multiplier": 1_600.0,
		# Cybernetic collective — finance run entirely by machines. Hail = machine-log
		# fragments, all protocol, no warmth.
		"hail": "HANDSHAKE ACCEPTED. ASSETS: CATALOGUED. OWNER: DESIGNATED " \
			+ "‘THE VARIABLE.’ SENTIMENT: NOT FOUND. COMMENCING COMMERCE.",
		"contact_line": "Machines that never sleep, never quit, never ask why. " \
			+ "Your money just stopped asking, too.",
		"accent_color": Color("#1F7A85"),  # circuit teal
		"staffer_names": [
			"Autonomous Teller Unit", "Cultivation Algorithm", "Mint Subroutine",
			"Tax Optimization Daemon", "Logistics Mainframe", "Laundering Protocol",
			"High-Frequency Core", "Property Acquisition Bot", "Recruitment Network Node",
			"Quant Supercluster", "Policy Compiler", "Executive Mainframe",
			"Exchange Daemon",
			"Foundry Core", "Spore Daemon", "Vault Subroutine", "Chrono Daemon",
			# Cohort siblings 17–31; 20–22 are the Grid's own (home-epoch) staffers,
			# mirroring those .tres staffer_name fields.
			"Beam Routing Daemon", "Futures Prediction Engine", "Dyson Assembly Swarm",
			"Rack City Warden", "Mining Subroutine", "Labor Dispatch Core",
			"Network Crawler Prime", "Biomass Process Unit", "Terraforming Compiler",
			"Gem Sorting Array", "Lens Calibration Bot", "Monolith Logic Broker",
			"Deadline Scheduler Daemon", "Momentary Cache Trader", "Escrow Checksum Warden",
			# Cohort 5th members (indices 32–36); index 33 (Singularity Holdings) is the Grid's
			# own grandest home-epoch venture, mirroring its .tres staffer_name.
			"Stellar Core Overseer", "Singularity Overmind", "Biosphere Management Engine",
			"Geode Dominion Core", "Causality Compiler",
		],
	},
	{
		"tier": 4,
		"civilization": "Mycelium Unity",
		"home_planet": "Spore-Deep",
		"currency_flavor": "Spores",
		"economy_scale": 216_000.0,
		"staff_income_multiplier": 64_000.0,
		# Fungal hive-mind — money that literally spreads and self-replicates. Hail =
		# a creeping lowercase whisper, plural and patient.
		"hail": "we felt you buying… through the roots… through the dark… " \
			+ "everything joins the network, eventually… grow with us… grow…",
		"contact_line": "Money that grows itself, branching through the dark, " \
			+ "feeding on everything it touches. Best not to ask what it eats.",
		"accent_color": Color("#6E4B8E"),  # spore violet
		"staffer_names": [
			"Spore-Cash Node", "Mycelial Grove-Tender", "Fungal Token Bloom",
			"Rhizome Financier", "Spore-Drift Network", "Decomposition Specialist",
			"Hyphae Trader", "Overgrowth Developer", "Mycelial Downline",
			"Spore Cloud Fund", "Root-Network Lobbyist", "Hive-Mind Chief of Staff",
			"Spore-Market Maker",
			"Mycelial Foundry", "Spore Banker", "Fungal Vault", "Spore Time Bank",
			# Cohort siblings 17–31; 23–25 are the Unity's own (home-epoch) staffers,
			# mirroring those .tres staffer_name fields.
			"Beam-Fed Mycelier", "Spore Futures Whisperer", "Dyson Grove Cultivator",
			"Server-Rot Colonist", "Mycelial Mine Creeper", "Fungal Labor Bloom",
			"Hyphae Line-Tender", "Decay Refiner", "Sporefall Steward",
			"Crystal Mold Trader", "Spore Lens Polisher", "Overgrowth Realtor",
			"Rot-Clock Keeper", "Momentary Bloom Broker", "Everspore Notary",
			# Cohort 5th members (indices 32–36); index 34 (Biosphere Trust) is the Unity's own
			# grandest home-epoch venture, mirroring its .tres staffer_name.
			"Starcore Grove-Baron", "Void-Rooted Overgrowth", "All-Biosphere Overlord",
			"Geode-Vein Colonist", "Root-of-Consequence Tender",
		],
	},
	{
		"tier": 5,
		"civilization": "Quartzite Conglomerate",
		"home_planet": "Geode-7",
		"currency_flavor": "Prisms",
		"economy_scale": 12_960_000.0,
		"staff_income_multiplier": 2_560_000.0,
		# Crystalloid life — capital made permanent, faceted, light bent to its will.
		# Hail = a cold appraisal, unimpressed and precise.
		"hail": "Appraisal complete. Your empire is… adequate. Inclusions detected. " \
			+ "We will permit it to be cut, faceted, and polished.",
		"contact_line": "Wealth, crystallized. Harder than diamond, and exactly as warm.",
		"accent_color": Color("#3E6FA8"),  # crystal blue
		"staffer_names": [
			"Prism Teller", "Crystal Cultivator", "Geode Curator",
			"Refraction Auditor", "Lattice Courier", "Facet Cleaner",
			"Quartz Day-Trader", "Geode Flipper", "Prism Recruiter",
			"Crystalline Fund Manager", "Bedrock Lobbyist", "Diamond Chief of Staff",
			"Prism Exchange Broker",
			"Crystal Foundry", "Crystal Spore Vault", "Prism Vault Keeper", "Crystal Time Bank",
			# Cohort siblings 17–31; 26–28 are the Conglomerate's own (home-epoch)
			# staffers, mirroring those .tres staffer_name fields.
			"Refracted Beam Cutter", "Crystal Futures Assayer", "Dyson Lattice Mason",
			"Quartz Server Setter", "Geode Mine Surveyor", "Crystalline Labor Agent",
			"Lattice Network Fitter", "Petrified Biomass Refiner", "Crystal Terraform Sculptor",
			"Facet Floor Trader", "Lens Grinder Prime", "Monolith Concierge",
			"Hourstone Enforcer", "Moment Crystal Appraiser", "Amber Escrow Keeper",
			# Cohort 5th members (indices 32–36); index 35 (Geode Dominion) is the Conglomerate's
			# own grandest home-epoch venture, mirroring its .tres staffer_name.
			"Starcore Facet-Lord", "Compressed-Core Magnate", "Petrified Biosphere Warden",
			"Geode Sovereign", "Crystallized Causality Assayer",
		],
	},
	{
		"tier": 6,
		"civilization": "Chronophage Enclave",
		"home_planet": "Tempus",
		"currency_flavor": "Seconds",
		"economy_scale": 777_600_000.0,
		"staff_income_multiplier": 102_400_000.0,
		# Time-eaters — they trade in stolen moments; your money compounds across hours
		# that were taken from someone else. Hail = politely terrifying, and it knows
		# exactly how much of you is left.
		"hail": "Good afternoon. You have approximately 1.4 billion seconds remaining. " \
			+ "Would you care to spend them profitably? Interest accrues… momentarily.",
		"contact_line": "They sell time itself, by the second — at a markup you will " \
			+ "never live long enough to repay.",
		"accent_color": Color("#8E2F45"),  # hourglass maroon
		"staffer_names": [
			"Second-Hand Teller", "Chrono Cultivator", "Moment Curator",
			"Hourglass Auditor", "Timeline Courier", "Era Cleaner",
			"Microsecond Day-Trader", "Era Flipper", "Tomorrow Recruiter",
			"Temporal Fund Manager", "Eternity Lobbyist", "Time-Lord Chief of Staff",
			"Temporal Exchange Lord",
			"Chrono Foundry", "Eternal Spore Bank", "Timeless Vault", "Time Banker",
			# Cohort siblings 17–31; 29–31 are the Enclave's own (home-epoch) staffers,
			# mirroring those .tres staffer_name fields.
			"Beam-Time Arbitrageur", "Yesterday's Futures Broker", "Dyson Epoch Engineer",
			"Server Uptime Usurer", "Chrono-Mine Excavator", "Overtime Labor Baron",
			"Timeline Network Splicer", "Fossil Biomass Refiner", "Epoch Terraformer",
			"Age-of-Gems Trader", "Timelens Grinder", "Monolith-of-Hours Warden",
			"Deadline Enforcer", "Moment Appraiser", "Eternity Notary",
			# Cohort 5th members (indices 32–36); index 36 (Causality Capital) is the Enclave's
			# own grandest home-epoch venture, mirroring its .tres staffer_name.
			"Stellar Lifespan Broker", "Infinite-Density Usurer", "Evergrowth Time-Baron",
			"Ageless Geode Warden", "Sovereign of Cause & Effect",
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


## The civilization's own first words — the typewritten transmission on the contact
## card, in that race's distinct voice (Tim, 2026-07-07). Empty for Earth/unknown tiers.
static func hail(tier: int) -> String:
	var epoch := get_epoch(tier)
	return String(epoch.get("hail", "")) if not epoch.is_empty() else ""


## The civilization's accent color: the contact card tints the civ name and hail with
## it, so each contact reads visually distinct too. Navy (the default text color) for
## Earth/unknown tiers.
static func accent_color(tier: int) -> Color:
	var epoch := get_epoch(tier)
	if epoch.is_empty():
		return Color("#1D2D50")  # UiPalette.NAVY, restated: core stays UI-import-free
	return epoch.get("accent_color", Color("#1D2D50"))
