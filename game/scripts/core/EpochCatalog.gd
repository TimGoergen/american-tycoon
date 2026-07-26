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
# EPOCH PACING (Continuous-ladder rework, 2026-07-12 — Tim's "each new property is a ~7×
# jump from the last, like a new property on Earth" model). The 52 properties climb at ~7×/rung:
# Earth's 12 are unchanged (already ~7×/rung, ATM $50 → Executive Assets $100B); the 40 alien rungs
# continue that ×7 progression in an ESCALATING cohort per epoch — 6, 7, 8, 9, 10 properties for
# epochs 2–6 (Tim's escalating-ladder decision 2026-07-15, the unlock-cadence fix; the 15 new
# properties are appended at indices 37–51) — ANCHORED to the player's epoch-entry WEALTH
# (not to the last Earth property) so each flagship is a real SAVE-UP: flagship(T) ≈ 10% of the
# previous threshold (≈ cash on hand), income anchored separately for a ~3× step-up. So it is ×7
# within and across alien epochs, with one "catch up to your wealth" jump at the Earth→alien
# boundary (Tim 2026-07-12: the flagship must not be pocket change on arrival).
#   economy_scale = 7^(5·(tier-1)) = (7^5)^(tier-1) -> 1, 16807, 2.82e8, 4.75e12, 7.98e16, 1.34e21
# i.e. the earn-to-clear threshold grows one 5-rung ladder block per epoch, matching how far the
# property magnitudes climb in that epoch — so pacing stays ~flat and you can never trivially buy
# across epochs (a rung 5 blocks up is 7^25× more expensive). The property BASE magnitude carries
# each step; staff is now only a MODEST boost, so staff_income_multiplier is FLAT (1.0 every tier)
# — the old 40^ ladder ballooned staffed old properties and fought the "ladder carries the leap"
# intent (it made aliens feel weak, then trivially cheap). First-pass; sim-verified, device pass owed.


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
			# (each is locked until its epoch), but every roster spans the full 52-property ladder.
			"Beam Utilities Foreman", "Futures Desk Chief", "Dyson Site Manager",
			"Server City Superintendent", "Mine Boss", "Labor Agency Director",
			"Network Line Manager", "Refinery Foreman", "Co-op Chairman",
			"Gem Floor Manager", "Lens Works Foreman", "Realty Broker",
			"Deadline Desk Manager", "Market Stall Keeper", "Escrow Officer",
			# Cohort 5th members (Phase 3, indices 32–36): Starcore, Singularity, Biosphere,
			# Geode, Causality. Earth never staffs them; the roster stays ladder-length.
			"Starcore Site Manager", "Singularity Project Director", "Biosphere Estate Director",
			"Geode Holdings Director", "Causality Fund Director",
			# Escalating-ladder additions (2026-07-15, indices 37–51): epochs 2–6 now hold
			# 6/7/8/9/10 properties — 1 new for epoch 2, then 2, 3, 4, 5, cheapest first.
			# Earth never staffs these either; the entries are plain professional titles.
			"Stellar Insurance Adjuster",
			"Sentience Leasing Agent", "Mainframe Operations Director",
			"Orchard Operations Manager", "Interstellar Logistics Coordinator",
			"Colony Operations Director",
			"Annuity Portfolio Manager", "Arbitrage Desk Chief", "Extraction Site Director",
			"Chief Assay Officer",
			"Hedge Fund Analyst", "Refinery Operations Manager", "Repossession Agent",
			"Mortgage Underwriter", "Chief Acquisitions Officer",
		],
	},
	{
		"tier": 2,
		"civilization": "Luminari Collective",
		"home_planet": "Solaria Prime",
		"currency_flavor": "Photons",
		"economy_scale": 16807.0,
		"staff_income_multiplier": 1.0,
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
			# Escalating-ladder additions (2026-07-15, indices 37–51); index 37 (Supernova
			# Underwriters) is the Luminari's own home-epoch venture, mirroring its .tres
			# staffer_name.
			"Supernova Underwriter",
			"Radiant Mind Lessor", "Photonic Mainframe Warden",
			"Sunripe Orchard Steward", "Lightsail Spore Courier",
			"Moonglow Colony Warden",
			"Everlight Annuity Broker", "Solar-Tide Arbitrageur", "Molten Radiance Tapper",
			"Core-Light Appraiser",
			"Afterglow Fund Manager", "Golden-Age Glow Refiner", "Lightpath Repossessor",
			"Thousand-Sunrise Lender", "First-Light Reclaimer",
		],
	},
	{
		"tier": 3,
		"civilization": "Geth-Sentinel Grid",
		"home_planet": "Rannoch-01",
		"currency_flavor": "Logic Nodes",
		"economy_scale": 282_475_249.0,
		"staff_income_multiplier": 1.0,
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
			# Escalating-ladder additions (2026-07-15, indices 37–51); indices 38–39
			# (Sentience Leasing Corp, Planetary Mainframe) are the Grid's own home-epoch
			# ventures, mirroring those .tres staffer_name fields.
			"Supernova Actuary Engine",
			"Sentience Lease Daemon", "Planetary Mainframe Core",
			"Orchard Yield Optimizer", "Panspermia Routing Engine",
			"Lunar Decomposition Unit",
			"Annuity Payout Daemon", "Plate Drift Predictor", "Mantle Bore Automaton",
			"Core Analysis Engine",
			"Retrospective Trading Engine", "Memory Distillation Unit", "Timeline Reclamation Daemon",
			"Amortization Horizon Engine", "Genesis Rollback Daemon",
		],
	},
	{
		"tier": 4,
		"civilization": "Mycelium Unity",
		"home_planet": "Spore-Deep",
		"currency_flavor": "Spores",
		"economy_scale": 4_747_561_509_943.0,
		"staff_income_multiplier": 1.0,
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
			# Escalating-ladder additions (2026-07-15, indices 37–51); indices 40–42
			# (Rotworld Orchards, Panspermia Logistics, Moonrot Colonies) are the Unity's
			# own home-epoch ventures, mirroring those .tres staffer_name fields.
			"Nova-Bloom Underwriter",
			"Borrowed-Mind Cultivator", "World-Root Processor",
			"Rotworld Orchard-Tender", "Panspermia Drift-Shepherd",
			"Moonrot Colony-Mother",
			"Deep-Root Annuitant", "Rift-Root Wedger", "Mantle-Vein Creeper",
			"Planet-Heart Rooter",
			"Old-Growth Fund Tender", "Memory-Compost Steeper", "Withered-Branch Pruner",
			"Heartwood Lienkeeper", "Seed-of-Everything Tender",
		],
	},
	{
		"tier": 5,
		"civilization": "Quartzite Conglomerate",
		"home_planet": "Geode-7",
		"currency_flavor": "Prisms",
		"economy_scale": 79_792_266_297_612_000.0,
		"staff_income_multiplier": 1.0,
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
			# Escalating-ladder additions (2026-07-15, indices 37–51); indices 43–46
			# (Bedrock Annuities, Tectonic Arbitrage, Mantle Extraction Concern, Planetcore
			# Assay) are the Conglomerate's own home-epoch ventures, mirroring those .tres
			# staffer_name fields.
			"Shattered-Star Appraiser",
			"Crystal-Mind Lessor", "Quartz Mainframe Mason",
			"Petrified Orchard Keeper", "Seeded-Comet Surveyor",
			"Hollowed-Moon Mason",
			"Bedrock Annuity Setter", "Tectonic Plate Broker", "Mantle Vein Magnate",
			"Planetcore Assay-Lord",
			"Hindsight Prism Polisher", "Rose-Quartz Memory Cutter", "Cracked-Timeline Lapidary",
			"Millennial Ledger Mason", "Uncut Universe Appraiser",
		],
	},
	{
		"tier": 6,
		"civilization": "Chronophage Enclave",
		"home_planet": "Tempus",
		"currency_flavor": "Seconds",
		"economy_scale": 1_341_068_619_663_964_900_000.0,
		"staff_income_multiplier": 1.0,
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
			# Escalating-ladder additions (2026-07-15, indices 37–51); indices 47–51
			# (Hindsight Hedge Fund, Nostalgia Refinery, Timeline Repossessions, Millennium
			# Mortgage, Big Bang Buyback) are the Enclave's own home-epoch ventures,
			# mirroring those .tres staffer_name fields.
			"Star-Death Actuary",
			"Rented-Consciousness Clerk", "World-Clock Overclocker",
			"Harvest-Season Hoarder", "Million-Year Freight Broker",
			"Lunar-Month Landlord",
			"Perpetuity Collections Agent", "Eon-Drift Speculator", "Deep-Time Prospector",
			"World-Age Auditor",
			"Hindsight Fund Oracle", "Nostalgia Distiller", "Timeline Repo Agent",
			"Thousand-Year Lienholder", "Repossessor of the First Second",
		],
	},
	{
		"tier": 7,
		"civilization": "Vashti Deep-Court",
		"home_planet": "Bathyros",
		"currency_flavor": "Lures",
		"economy_scale": 2.25393402906923e+25,
		"staff_income_multiplier": 1.0,
		"hail": "Weeelcome... dooown... little surface-thing... your weeealth siiinks so beautifully. The Deep-Court has appraiiised your empire... by the glow of a thousand luuures... and found it... edible. At these depths... everything... eventually... settles with us.",
		"contact_line": "Seven miles down, where the sun has never held an account, the aristocracy hangs glowing storefronts from their own foreheads. Foot traffic swims right in and is never itemized again.",
		"accent_color": Color("#0f4c5c"),
		"staffer_names": [
			"Lure-Lit Teller", "Kelp-Forest Cultivator", "Bioluminant Curator",
			"Pressure-Gradient Auditor", "Abyssal Current Courier", "Silt-Bed Cleaner",
			"Darkwater Day-Trader", "Shipwreck Flipper", "Anglerlight Recruiter",
			"Leviathan Fund Manager", "Deep-Court Lobbyist", "Trench Chief of Staff",
			"Lure-Light Exchange Broker", "Pressure-Forged Foundry", "Plankton Spore Banker",
			"Drowned Prism Keeper", "Tide-Time Banker", "Sonar Beam Operator",
			"Sunless Futures Broker", "Dyson Reef Foreman", "Sunken Server Warden",
			"Trench Mining Overseer", "Drift-Labor Dispatcher", "Coral Vein Tender",
			"Whalefall Refiner", "Seafloor Reshaper", "Pearl Floor Trader",
			"Lure-Lens Grinder", "Sunken Monolith Concierge", "Drowning Deadline Enforcer",
			"Still-Water Moment Appraiser", "Deep-Sleep Eternity Notary", "Drowned Star Magnate",
			"Hadal Singularity Regent", "Benthic Biosphere Warden", "Grotto Geode Sovereign",
			"Undertow Causality Baron", "Nova-Glow Underwriter", "Awakened Kraken Leaser",
			"Seabed Mainframe Keeper", "Whalefall Orchardist", "Drift-Spore Shipper",
			"Tide-Rot Colonist", "Seafloor Bedrock Annuitant", "Rift-Vent Arbitrageur",
			"Vent-Mantle Extractor", "Trench-Core Assayer", "Receding Tide Hedger",
			"Sunken Memory Refiner", "Undertow Repossessor", "Thousand-Fathom Mortgagor",
			"First Tide Buyback Agent",
		],
	},
	{
		"tier": 8,
		"civilization": "Ssethraki Coil-Banks",
		"home_planet": "Ssethra",
		"currency_flavor": "Premiums",
		"economy_scale": 3.78818692265665e+29,
		"staff_income_multiplier": 1.0,
		"hail": "Sssalutationsss, sssoft-ssskinned asssset. Our sssensorsss indicate you are — how tragic — entirely uninsssured. Sssign here, and here, and initial here; the sssqueeze you feel is ssimply the coverage taking hold.",
		"contact_line": "Serpents who founded a religion on insurance, then built a civilization on the paperwork. Their embrace is total coverage — in the constrictor sense.",
		"accent_color": Color("#4f7942"),
		"staffer_names": [
			"Cold-Blooded Teller", "Tree-Coiled Cultivator", "Shed-Skin Token Appraiser",
			"Municipal Squeeze Actuary", "Slither-Route Logistician", "Clean Molt Specialist",
			"Strike-Window Trader", "Nest Turnover Adjuster", "Coil-Upon-Coil Recruiter",
			"Hedgerow Ambush Manager", "Capitol Pit Lobbyist", "Chief Constrictor of Staff",
			"Basking Exchange Broker", "Cold Logic Underwriter", "Spore Premium Teller",
			"Prism Hoard Constrictor", "Actuarial Lifespan Teller", "Heat-Lamp Utilities Warden",
			"Solar Bask Actuary", "Star-Encoiling Foreman", "Server Den Warden",
			"Recursive Coil Miner", "Automated Fang Dispatcher", "Root-Slither Networker",
			"Slow Digestion Refiner", "Warm-Rock Terraformer", "Jeweled Scale Broker",
			"Slit-Pupil Lens Grinder", "Monolith Basking Realtor", "Term Expiry Broker",
			"Strike-Second Appraiser", "Perpetuity Escrow Notary", "Starcore Clutch Magnate",
			"Singularity Risk Oracle", "Terrarium Trust Officer", "Geode Den Sovereign",
			"Proximate Cause Financier", "Nova Claims Underwriter", "Sentience Lease Constrictor",
			"Cold-Blooded Mainframe Warden", "Carrion Orchard Assessor", "Spore-Slither Logistician",
			"Moonrot Colony Underwriter", "Bedrock Annuity Burrower", "Plate-Shift Arbitrageur",
			"Warm-Mantle Extraction Agent", "Core-Heat Assayer", "Hindsight Claims Adjuster",
			"Shed-Skin Nostalgia Refiner", "Timeline Repossession Agent", "Thousand-Year Mortgage Actuary",
			"Primordial Buyback Broker",
		],
	},
	{
		"tier": 9,
		"civilization": "Melissar Hive-Court",
		"home_planet": "Melissar VI",
		"currency_flavor": "Royal Jelly",
		"economy_scale": 6.36680576090903e+33,
		"staff_income_multiplier": 1.0,
		"hail": "By royal decree, We have tazzted your fortune upon the wind and pronounce it zzweet enough for Court. Your buzzness is hereby annexed to the Hive; your pozzition is Provisional Drone, compensated in exposure to Our radiance. Kneel, and bring nectar.",
		"contact_line": "A gilded-age bee aristocracy that turned the hive into a stock exchange and the drones into unpaid interns. The queen annexed your portfolio before you finished bowing.",
		"accent_color": Color("#c19a26"),
		"staffer_names": [
			"Comb Cell Teller", "Royal Orchard Pollinator", "Waggle-Dance Curator",
			"Hive Tithe Assessor", "Foraging Route Marshal", "Pollen Provenance Scrubber",
			"Swarm Floor Trader", "Comb Renovation Baroness", "Brood Downline Matron",
			"Hedgerow Fund Keeper", "Court Decree Whisperer", "Queen's Chief Attendant",
			"Sunbeam Nectar Broker", "Waggle Data Archivist", "Spore Cellar Matron",
			"Crystallized Honey Vaultess", "Season Cycle Banker", "Sunpatch Utilities Warden",
			"Bloom Season Forecaster", "Sun-Jar Estate Keeper", "Hive Mind Superintendent",
			"Pattern Dance Miner", "Clockwork Drone Wrangler", "Underhive Thread Steward",
			"Beebread Refinery Forewoman", "Meadow-Making Co-op Chair", "Amber Gem Appraiser",
			"Compound Eye Lensmith", "Great Comb Realtor", "Swarming Day Enforcer",
			"First Bloom Speculator", "Amber Preservation Notary", "Starcore Swarm Mistress",
			"One-Swarm Convergence Regent", "Blooming World Trustee", "Hollow-Stone Hive Duchess",
			"Pollination Chain Underwriter", "Dying Sun Underwriter", "Borrowed Mind Leaser",
			"World-Comb Overseer", "Rotbloom Orchardist", "Star Pollen Courier",
			"Moonrot Colony Matron", "Stonecomb Annuitress", "Quaking Meadow Arbitrageuse",
			"Deep Wax Extractor", "Core Nectar Assayer", "Yesterbloom Fund Keeper",
			"Old Honey Distiller", "Season Repossession Bailiff", "Thousand-Winter Mortgagor",
			"First Dawn Buyback Agent",
		],
	},
	{
		"tier": 10,
		"civilization": "Norrvane Frostholm",
		"home_planet": "Norrvane",
		"currency_flavor": "Glacier Shares",
		"economy_scale": 1.07006904423598e+38,
		"staff_income_multiplier": 1.0,
		"hail": "Hail, hasty little ember. Your wealth-hoard has been weighed and carved upon the ᚠᛖᚺᚢ-stone, where it shall sit unspent for a thousand winters, as is proper. Sit — the thaw-debt comes due for all who rush.",
		"contact_line": "Ice giants who compound interest once per ice age and regard a fiscal quarter as an act of violence. Try not to fidget; they can hear it.",
		"accent_color": Color("#6d8ea0"),
		"staffer_names": [
			"Coin-Slot Rimewarden", "Frost-Orchard Tender", "Unique-Snowflake Skald",
			"District Frost-Levy Seer", "Floe-Crossing Cargo Master", "Glacial Meltwater Purifier",
			"Vulgar Haste Speculator", "Longhouse Turnover Jarl", "Snowball-Scheme Recruiter",
			"Wealth-Hoard Hedgemaster", "Althing Vote-Hoarder", "High-Jarl Purse Keeper",
			"Aurora-Light Barterer", "Rune-Data Carver", "Frozen-Spore Vaultkeeper",
			"Ice-Prism Vaultwright", "Millennium Deposit Warden", "Sunbeam Ration Warden",
			"Midnight-Sun Futures Seer", "Sun-Cage Holdings Thane", "Cold-Server Hall Warden",
			"Logic-Seam Delver", "Iron-Thrall Hirer", "Under-Ice Root Weaver",
			"Bog-Peat Refiner", "World-Shaper Co-op Elder", "Hailstone Gem Appraiser",
			"Sun-Focus Lens Grinder", "Standing-Stone Landlord", "Ragnarok Deadline Broker",
			"Fleeting-Moment Disdainer", "Eon-Escrow Oathkeeper", "Starheart Forge Elder",
			"All-Devouring Crevasse Trustee", "Greenhouse-Dome Trustee", "Hollow-Boulder Dominion Jarl",
			"Norn-Thread Capitalist", "Star-Death Underwriter", "Thought-Thrall Leaser",
			"World-Mind Rune Warden", "Thaw-Rot Orchard Tender", "Star-Seed Cargo Reeve",
			"Moon-Rot Colony Jarl", "Deep-Stone Annuity Clerk", "Slow-Plate Arbitrageur",
			"Deep-Forge Extraction Thane", "World-Core Assayer", "Backward-Gaze Hedge Seer",
			"Old-Winter Longing Refiner", "Wyrd-Thread Repossessor", "Ten-Century Mortgage Reeve",
			"First-Fire Buyback Elder",
		],
	},
	{
		"tier": 11,
		"civilization": "The Resonant Octave",
		"home_planet": "Cadenza",
		"currency_flavor": "Notes",
		"economy_scale": 1.79846504264741e+42,
		"staff_income_multiplier": 1.0,
		"hail": "♪ hush… we heard your fortune humming from across the void, and darling, it was flat ♪ every coin that clinks is a note, and every note is licensed to US ♪ so begin quietly, invest steadily, and TOGETHER WE SHALL CRESCENDO ♪",
		"contact_line": "Beings made entirely of sound, and every note they've ever sung is under copyright. Try not to hum anything — it's licensed.",
		"accent_color": Color("#544e9e"),
		"staffer_names": [
			"Coin-Chime Teller", "Windchime Arborist", "One-Hit Wonder Curator",
			"Tempo Increment Auditor", "World Tour Roadie Captain", "Uncredited Remix Engineer",
			"Sight-Reading Day-Trader", "B-Side Flipper", "Fan Club Recruiter",
			"Perfect-Pitch Fund Manager", "Payola Lobbyist", "Maestro Chief of Staff",
			"Light-Motif Broker", "Waveform Foundry Chief", "Spore Chorale Banker",
			"Crystal Glissando Keeper", "Metronome Banker", "Beam Resonance Tuner",
			"Sunrise Overture Trader", "Sphere-Harmonic Foreman", "Synth Rack Warden",
			"Algo-Rhythm Miner", "Player-Piano Dispatcher", "Underground Scene Promoter",
			"Decomposition Composer", "World-Tuning Steward", "Rock Opera Trader",
			"Laser Show Technician", "Monolith Reverb Concierge", "Final Countdown Enforcer",
			"Beat-Drop Appraiser", "Endless Refrain Notary", "Stellar Chorus Magnate",
			"Infinite Loop Composer", "Ambient Biosphere Conductor", "Geode Acoustics Sovereign",
			"Call-and-Response Broker", "Showstopper Underwriter", "Self-Aware Synth Leaser",
			"Planetary Soundboard Operator", "Compost Cantata Orchardist", "Viral Melody Courier",
			"Moldy Oldies Colonist", "Rock-Steady Annuitant", "Seismic Bass Arbitrageur",
			"Deep Groove Extraction Foreman", "Planetcore Pitch Assayer", "Rewind Fund Manager",
			"Golden Oldies Refiner", "Skipped-Track Repo Agent", "Thousand-Bar Mortgage Broker",
			"First Downbeat Buyback Agent",
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
