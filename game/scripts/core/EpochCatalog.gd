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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Storefront Supervisor", "Vault Operations Manager", "Toll Booth Operator",
			"Fleet Dispatcher", "Estate Liquidator", "Utility Plant Operator",
			"Bond Trader", "Mint Operations Supervisor", "Exchange Floor Manager",
			"Trust Administrator", "Regional Governor", "Underwriting Agent",
			"Reinsurance Adjuster", "Annuities Advisor", "Staff Actuary",
			"Liability Adjuster", "Life Insurance Agent", "Escrow Vault Custodian",
			"Claims Examiner", "Coverage Specialist", "Policy Rider Analyst",
			"Indemnity Underwriter", "Perpetuity Trustee", "Wax Plant Foreman",
			"Commodities Trader", "Placement Recruiter", "Leasing Agent",
			"Patent Examiner", "Distillery Manager", "Floor Trader",
			"Assurance Agent", "Broadcast Station Manager", "Annexation Case Officer",
			"Regional Administrator", "Mint Director", "Reserve Warehouse Manager",
			"Ledger Clerk", "Cold Storage Supervisor", "Yard Foreman",
			"Derivatives Trader", "Debt Collector", "Annuity Salesman",
			"Claims Processor", "Toll Road Administrator", "Bond Vault Custodian",
			"Commodity Exchange Manager", "Mineral Rights Broker", "Holdings Portfolio Director",
			"Futures Trader", "Endowment Administrator", "Licensing Coordinator",
			"Booking Agent", "Rights Clearance Officer", "Concert Promoter",
			"Royalties Auditor", "Tour Manager", "Patent Attorney",
			"Easement Negotiator", "Antitrust Compliance Officer", "Acoustics Engineer",
			"Venue Operations Manager", "Music Rights Trader", "Licensing Account Manager",
			"Orchestra Conductor",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Bioluminescent Shopkeeper", "Deep-Glow Vault Keeper", "Abyssal Beacon Tollkeeper",
			"Leviathan Lantern Captain", "Whalefall Glow Realtor", "Ventlight Grid Engineer",
			"Siren Shimmer Bondsman", "Hadal Gleam Minter", "Sunken Cathedral Beacon Keeper",
			"Midnight Sun Trustee", "Last-Light Sovereign", "Radiant Venom Underwriter",
			"Shed-Glow Reinsurer", "Coiled Ray Annuitant", "Sunlit Actuary Priest",
			"Gleaming Fang Adjuster", "Hatchling Sunrise Underwriter", "Dormant Glow Escrow Agent",
			"Constricted Beam Magistrate", "Coiled Corona Underwriter", "Last-Flash Rider Broker",
			"Collapsing Star Indemnifier", "Perpetual Halo Trustee", "Sunwax Chandler",
			"Nectar Gleam Trader", "Sunbeam Drone Wrangler", "Honeyglow Estate Agent",
			"Propolis Glaze Patent Clerk", "Sunmead Distiller", "Waggle Shimmer Broker",
			"Swarmlight Assurer", "Scentbeam Broadcaster", "Sunlit Meadow Annexer",
			"Lesser Hive Glow Minister", "Queenshine Minter", "Royal Radiance Warden",
			"Frostlight Bookkeeper", "Cold Glow Custodian", "Glacier Glint Foreman",
			"Snowblind Derivatives Dealer", "Thawlight Debt Collector", "Frostbitten Gleam Annuitant",
			"Whiteout Claims Adjuster", "Fjordlight Tollmaster", "Winterlong Ember Vaultkeeper",
			"Sea-Ice Sparkle Trader", "Moraine Glint Rightsholder", "Polar Aurora Crownkeeper",
			"Ice Age Dawn Broker", "Aurora Endowment Chancellor", "Shimmer Jingle Licensor",
			"Chromatic Chord Boss", "Radiant Anthem Registrar", "Sunrise Symphony Broker",
			"Reverb Radiance Collector", "Encore Afterglow Broker", "Key-Change Prism Patenter",
			"Dimmed Silence Easement Agent", "Octave Spectrum Monopolist", "Planetary Echo Illuminator",
			"Orbital Limelight Usher", "Spherelight Music Trader", "Cosmic Hum Glow Licensor",
			"Fading-Light Maestro",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Lure Illumination Daemon", "Hull Integrity Warden", "Toll Collection Subroutine",
			"Fleet Navigation Mainframe", "Whalefall Salvage Crawler", "Vent Thermal Regulator",
			"Siren Signal Filter", "Hadal Minting Unit", "Submerged Exchange Kernel",
			"Midnight Zone Sentinel", "Deep Pressure Overmind", "Venom Toxicity Analyzer",
			"Molt Cycle Scheduler", "Annuity Payout Daemon", "Actuarial Logic Engine",
			"Fang Liability Calculator", "Hatchling Policy Daemon", "Brumation Standby Warden",
			"Constriction Claims Parser", "Coil Coverage Mainframe", "Extinction Rider Compiler",
			"Collapse Indemnity Engine", "Recursive Loop Core", "Wax Extrusion Unit",
			"Nectar Futures Bot", "Drone Assignment Compiler", "Hexagonal Zoning Array",
			"Propolis Patent Indexer", "Mead Fermentation Unit", "Waggle Signal Decoder",
			"Swarm Consensus Engine", "Pheromone Broadcast Daemon", "Meadow Annexation Bot",
			"Lesser Hive Subnet Warden", "Queen Mint Overseer", "Royal Reserve Overseer",
			"Frozen Ledger Daemon", "Cryogenic Storage Warden", "Calving Schedule Subroutine",
			"Avalanche Risk Engine", "Thaw-Debt Recovery Bot", "Frostbite Annuity Engine",
			"Blizzard Claims Processor", "Fjord Toll Subroutine", "Winterlong Bond Warden",
			"Frozen Exchange Kernel", "Moraine Rights Registrar", "Polar Crown Mainframe",
			"Ice Age Forecast Engine", "Deep-Ice Endowment Core", "Jingle Synthesis Bot",
			"Chord Compression Algorithm", "Rights Enforcement Daemon", "Orchestral Forecast Engine",
			"Reverb Royalty Tracker", "Encore Prediction Daemon", "Key Change Compiler",
			"Null Signal Warden", "Octave Allocation Core", "Reverb Chamber Mainframe",
			"Orbital Acoustics Array", "Spheres Harmony Router", "Cosmic Hum License Daemon",
			"Terminal Coda Processor",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Bioluminescent Lure-Bloom", "Deep-Pressure Spore Vault", "Trench-Hyphae Toll-Creeper",
			"Leviathan Mold Charterer", "Whalefall Bloom Realtor", "Vent-Fed Mycelier",
			"Siren-Spore Bondsman", "Hadal Spore Minter", "Drowned Rot Exchange",
			"Midnight Mold Trust", "Abyss-Root Overlord", "Toxin-Spore Underwriter",
			"Shed-Husk Decomposer", "Coiled Rhizome Annuitant", "Fungal Actuary Colony",
			"Fang-Rot Consortium", "Hatchling Spore Insurer", "Dormant-Vault Spore Keeper",
			"Constricting Hyphae Tribunal", "World-Coiling Rootmass", "Extinction Bloom Rider",
			"Star-Rot Indemnifier", "Self-Consuming Overgrowth", "Waxcap Combine-Tender",
			"Nectar-Rot Trader", "Spore-Drone Placer", "Honeycomb Mold Realtor",
			"Propolis Mold Patenter", "Fermenting Mead Culture", "Waggle Spore Bourse",
			"Swarm-Bloom Assurer", "Pheromone Spore-Caster", "Meadow Overgrowth Annexer",
			"Lesser-Hive Colonizer", "Queen-Rot Minter", "Royal Jelly Bloom-Baron",
			"Permafrost Spore-Keeper", "Cryo-Dormant Colonist", "Glacier-Crack Creeper",
			"Avalanche Bloom Broker", "Thaw-Rot Collector", "Frostbite Spore Annuitant",
			"Blizzard Bloom Adjuster", "Fjord-Root Toll-Taker", "Winterlong Spore Vault",
			"Frozen Mold Exchange", "Moraine-Vein Creeper", "Polar Overgrowth Crown",
			"Ice-Age Dormancy Futures", "Deep-Ice Rhizome Trust", "Spore-Jingle Licenser",
			"Mycelial Chord Cartel", "Anthem-Rot Rights Bloom", "Symphony Spore Futures",
			"Reverb-Rot Royalty", "Encore Bloom Futures", "Key-Change Spore Patenter",
			"Silent Hyphae Easement", "Octave Mold Monopoly", "World-Root Reverb Chamber",
			"Orbital Spore Amphitheater", "Sphere-Song Bloom Exchange", "Cosmic Hum Spore-Licenser",
			"Final Decay Movement",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Lure-Prism Shopkeeper", "High-Pressure Diamond Warden", "Trench Geode Tollkeeper",
			"Leviathan Lattice Admiral", "Whalefall Geode Realtor", "Thermal Vent Crystallizer",
			"Siren Resonance Bondsman", "Hadal Pressure Minter", "Sunken Cathedral Gemwright",
			"Lightless Depth Trustee", "Abyssal Facet Monarch", "Venom Inclusion Underwriter",
			"Shed-Shard Reinsurer", "Helix Lattice Annuitant", "Crystal Ball Actuary",
			"Fang Inclusion Assessor", "Hatchling Geode Underwriter", "Brumation Amber Warden",
			"Constriction Fracture Adjudicator", "Coiled Lattice Underwriter", "Extinction Inclusion Broker",
			"Collapsed-Star Indemnifier", "Ouroboros Ring Cutter", "Amber Wax Foundryman",
			"Crystallized Nectar Trader", "Drone Facet Placer", "Hex-Lattice Realtor",
			"Amber Propolis Patenter", "Crystallized Mead Distiller", "Waggle Refraction Broker",
			"Swarm Lattice Assurer", "Pheromone Prism Herald", "Meadow Vein Annexer",
			"Lesser-Geode Minister", "Queen's Facet Minter", "Crown Jewel Custodian",
			"Permafrost Ledger Engraver", "Ice-Lattice Monopolist", "Glacier Cleaving Foreman",
			"Avalanche Shard Quant", "Meltwater Debt Collector", "Frostbite Facet Annuitant",
			"Blizzard Shard Adjuster", "Fjord Crystal Tollmaster", "Winterlong Ice Vaultkeeper",
			"Sea-Ice Exchange Broker", "Moraine Vein Claimant", "Polar Crown Jeweler",
			"Glacial Epoch Speculator", "Deep-Ice Endowment Regent", "Chime Crystal Licensor",
			"Tuning-Crystal Cartel Boss", "Anthem Resonance Registrar", "Symphonic Quartz Speculator",
			"Resonant Quartz Royaltist", "Encore Resonance Speculator", "Key-Change Lattice Patenter",
			"Stilled-Crystal Easement Agent", "Octave Resonance Monopolist", "Geode Reverb Chamberlain",
			"Crystal Amphitheater Usher", "Harmonic Sphere Broker", "Cosmic Resonance Licensor",
			"Final Resonance Maestro",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Witching-Hour Shopkeeper", "Deep-Time Vault Warden", "Aeon Toll Collector",
			"Leviathan Lifespan Charterer", "Century-Fall Estate Agent", "Geologic-Vent Meter Reader",
			"Siren-Song Duration Broker", "Deepest-Hour Mintmaster", "Sunken-Century Exchange Sexton",
			"Perpetual Midnight Trustee", "Sovereign of Sunken Hours", "Slow-Acting Venom Underwriter",
			"Shed-Era Reinsurer", "Coiled Perpetuity Actuary", "Life-Expectancy High Priest",
			"Split-Second Strike Adjuster", "Whole-Lifespan Underwriter", "Dormant-Season Escrow Keeper",
			"Slow-Squeeze Claims Magistrate", "World-Coil Term Actuary", "Extinction-Date Rider Broker",
			"Star-Clock Collapse Indemnifier", "Ouroboros Rollover Underwriter", "Candle-Clock Wax Foreman",
			"Harvest-Hour Nectar Broker", "Perpetual-Intern Shift Scheduler", "Honeycomb Lease-Cycle Agent",
			"Twenty-Year Patent Beekeeper", "Slow-Aged Mead Distiller", "Waggle-Tempo Floor Trader",
			"Swarm-Season Assurance Agent", "Scent Half-Life Broadcaster", "Bloom-Window Annexation Clerk",
			"Minister of Borrowed Summers", "Mintmaster of the Queen's Reign", "Keeper of the Queen's Calendar",
			"Ten-Millennia Ledger Keeper", "Frozen-Clock Storage Baron", "Glacial-Pace Yard Foreman",
			"Sudden-Expiry Avalanche Trader", "Spring-Thaw Debt Collector", "Frostbite Payout Scheduler",
			"Whiteout-Hour Claims Clerk", "Fjord Passage Timekeeper", "Winterlong Maturity Warden",
			"Stopped-Clock Sea Trader", "Glacial-Eon Mineral Registrar", "Polar-Night Crown Regent",
			"Next Ice Age Broker", "Ice-Age Interest Trustee", "Thirty-Second Jingle Licensor",
			"Tempo Cartel Enforcer", "Anthem Duration Registrar", "Unfinished Symphony Futures Broker",
			"Lingering-Echo Royalty Clerk", "Encore Countdown Broker", "Key-Change Moment Patenter",
			"Rest-Measure Easement Agent", "Perpetual Octave Monopolist", "Thousand-Year Reverb Engineer",
			"Orbital-Period Concertmaster", "Celestial Tempo Trader", "Eternal Hum Licensor",
			"Conductor of the Last Measure",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Anglerlight Shopkeep", "Pressure Vault Warden", "Trench Toll Collector",
			"Leviathan Fleet Admiral", "Whalefall Estate Broker", "Hydrothermal Vent Baron",
			"Siren Bond Underwriter", "Hadal Mintmaster", "Bishop of Sunken Ledgers",
			"Regent of the Midnight Zone", "Sovereign of the Crushing Dark", "Eel-Venom Underwriter",
			"Scale-Shed Reinsurer", "Kraken Coil Annuitant", "Drowned Temple Actuary",
			"Anglerfang Liability Assessor", "Fry Whole-Life Underwriter", "Cold-Torpor Escrow Warden",
			"Kraken-Grip Claims Justice", "Sea-Serpent Coverage Coiler", "Last Species Rider Broker",
			"Star-Sink Indemnifier", "Sea-Serpent Perpetuist", "Whale-Wax Renderer",
			"Brine Nectar Trader", "Drift-Drone Placer", "Coral Comb Realtor",
			"Coral-Resin Patent Clerk", "Brine Mead Distiller", "Lure-Dance Floor Trader",
			"Shoal Assurance Actuary", "Scent-Plume Broadcaster", "Kelp Meadow Annexer",
			"Minister of Lesser Reefs", "Drowned Queen's Mintmaster", "Royal Jellyfish Custodian",
			"Frozen Depths Ledger-Keeper", "Cold Current Storekeeper", "Iceberg Keel Appraiser",
			"Undersea Landslide Broker", "Meltwater Debt Collector", "Icewater Annuitant",
			"Ice-Storm Claims Adjuster", "Fjord-Mouth Tollkeeper", "Long-Winter Bond Warden",
			"Under-Ice Exchange Broker", "Glacial Seabed Claimant", "Polar Deep Crownkeeper",
			"Frozen Epoch Broker", "Polar Trench Endowment Keeper", "Sonar Jingle Licensor",
			"Whalesong Chord Boss", "Deep-Chant Rights Clerk", "Leviathan Choir Broker",
			"Deep Echo Royalty Agent", "Second Song Broker", "Current-Shift Key Patenter",
			"Soundless Depths Easer", "Sonar Octave Monopolist", "Ocean-Basin Reverb Keeper",
			"Sunken Amphitheater Usher", "Tide-Sphere Music Broker", "Abyssal Hum Licensor",
			"Last Echo Conductor",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Lure Liability Assessor", "Crush Coverage Vaultkeeper", "Trench Toll Constrictor",
			"Leviathan Hull Underwriter", "Whalefall Estate Executor", "Thermal Vent Bask-Warden",
			"Siren Bond Hypnotist", "Hadal Depth Minter", "Sunken Nave Broker",
			"Lightless Pit Trustee", "Abyssal Dominion Assessor", "Chief Venom Underwriter",
			"Second-Skin Reinsurer", "Coilfold Annuity Actuary", "High Priest of Premiums",
			"Bite-Wound Claims Adjuster", "Clutch Policy Broker", "Deep-Sleep Escrow Custodian",
			"Grand Squeeze Arbiter", "World-Wrap Policy Magnate", "Doomsday Rider Broker",
			"Supernova Exclusions Actuary", "Ouroboros Perpetuity Trustee", "Wax Seal Notary",
			"Nectar Yield Assessor", "Drone Premium Recruiter", "Hexagonal Nest Realtor",
			"Propolis Patent Notary", "Venom-Mead Distiller", "Waggle Signal Broker",
			"Swarm Assurance Actuary", "Scent-Tongue Broadcaster", "Meadow Annexation Surveyor",
			"Lesser Hive Constrictor", "Queen's Premium Minter", "Jelly Reserve Custodian",
			"Brumation Ledger Keeper", "Cold-Blood Storage Magnate", "Iceberg Hatchling Foreman",
			"Avalanche Act-of-God Broker", "Post-Brumation Debt Collector", "Frostbite Rider Actuary",
			"Blizzard Claims Magistrate", "Fjord Coil Tollmaster", "Winterlong Bond Custodian",
			"Ice-Sheet Exchange Broker", "Moraine Rights Assessor", "Polar Crown Coil-Bearer",
			"Glacial Epoch Underwriter", "Deep-Freeze Endowment Warden", "Rattle Jingle Licensor",
			"Hiss Harmony Enforcer", "Anthem Rights Registrar", "Snake-Charmer Futures Broker",
			"Rattling Reverb Licensor", "Encore Strike Broker", "Key Change Patent Clerk",
			"Silent-Slither Easement Notary", "Octave Squeeze Monopolist", "Planetary Echo Warden",
			"Orbital Pit Impresario", "Celestial Hiss Broker", "Cosmic Hum Licensor",
			"Coda Claims Adjuster",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Glowbloom Shop Matron", "Deep Cell Sealer", "Dark Passage Tollkeeper",
			"Great Swarm Charter Admiral", "Sunken Feast Realtor", "Warm Vent Warden",
			"Siren Hum Bondmaker", "Deepest Cell Minter", "Sunken Comb Verger",
			"Lightless Deep Trustee", "Sunless Court Envoy", "Sting Liability Underwriter",
			"Larval Molt Adjuster", "Spiral Comb Annuitist", "Wax Temple Actuary",
			"Serpent Sting Assessor", "Brood Whole-Life Agent", "Long Sleep Escrow Keeper",
			"Squeezed Comb Adjudicator", "World-Coil Coverage Matron", "Last Swarm Rider Broker",
			"Falling Star Indemnitress", "Endless Swarm Perpetuist", "Master Wax Sculptress",
			"Nectar Futures Grandee", "Unpaid Drone Recruiter", "Hexagonal Estates Duchess",
			"Propolis Sealing Notary", "Mead Cellars Sommelier", "Waggle Floor Auctioneer",
			"Swarm Risk Actuary", "Scent Decree Herald", "Wildflower Annexation Envoy",
			"Viceroy of Lesser Hives", "Stamper of the Royal Profile", "Keeper of the Royal Jelly",
			"Winter Cluster Bookkeeper", "Honey Cellar Monopolist", "Frost Comb Cleaver",
			"Cold Snap Hedger", "Spring Thaw Debt Collectress", "Frostnip Annuity Matron",
			"Whiteout Claims Steward", "Frozen Channel Tollmistress", "Long Winter Bondkeeper",
			"Iced Nectar Exchanger", "Glacier Grit Claimant", "Polar Crown Regent",
			"Endless Winter Forecaster", "Deep Winter Endowment Regent", "Buzz Jingle Licensor",
			"Hum Cartel Conductress", "Hive Anthem Registrar", "Swarm Chorus Speculator",
			"Echoing Hum Collector", "Encore Buzz Speculator", "Pitch Shift Patentess",
			"Hushed Hive Easement Clerk", "Eight-Note Hum Monopolist", "World-Comb Resonance Warden",
			"Orbiting Swarm Chorister", "Celestial Hum Broker", "Great Hum Licensor",
			"Last Waggle Maestra",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Under-Ice Lantern Merchant", "Deep-Crush Vault Sentinel", "Black-Fathom Tollkeeper",
			"Whale-Road Fleet Master", "Whale-Fall Estate Reeve", "Deep-Vent Steam Warden",
			"Siren-Song Bond Skald", "Deepest-Fathom Minter", "Sunken-Hall Exchange Reeve",
			"Lightless-Fathom Trustee", "Sunless-Deep Sovereign", "Serpent-Bite Underwriter",
			"Shed-Skin Reinsurer", "Coiled-Wyrm Annuity Clerk", "Frost-Actuary High Priest",
			"Fang-Wound Liability Thane", "Wyrmling Whole-Life Clerk", "Winter-Torpor Escrow Warden",
			"Crushing-Coil Claims Judge", "World-Coil Coverage Reeve", "Kin-Death Rider Broker",
			"Star-Fall Indemnity Seer", "Tail-Eater Perpetuity Warden", "Tallow-Wax Combine Foreman",
			"Winter-Nectar Hoarder", "Drone-Thrall Placement Reeve", "Frost-Comb Estate Agent",
			"Hive-Resin Patent Carver", "Mead-Hall Distiller", "Waggle-Dance Floor Thane",
			"Swarm-Oath Assurer", "Scent-Saga Herald", "Frost-Meadow Annexer",
			"Lesser-Hive Overjarl", "Hive-Queen Coin Warden", "Royal Mead Reserve Keeper",
			"Permafrost Ledger-Carver", "Cold-Hoard Monopolist", "Berg-Calving Yardmaster",
			"Avalanche Rune-Reckoner", "Thaw-Debt Doomsayer", "Slow-Drip Annuity Skald",
			"Whiteout Claim-Denier", "Fjord-Gate Toll Jarl", "Thousand-Winter Bondsman",
			"Pack-Ice Floor Thane", "Moraine Claims Reeve", "Polar Crown Hoard-Keeper",
			"Glaciation Futures Völva", "Deep-Ice Endowment Elder", "Skald-Jingle Licenser",
			"War-Horn Cartel Boss", "Saga-Anthem Rights Reeve", "Glacier-Song Futures Broker",
			"Echoing-Fjord Royalty Clerk", "Second-Verse Futures Clerk", "Shifted-Key Patent Skald",
			"Deep-Hush Easement Reeve", "Eight-Tone Monopolist", "World-Echo Chamber Warden",
			"Sky-Ring Amphitheater Jarl", "Sphere-Song Barterer", "World-Hum Licenser",
			"Last-Verse Conductor",
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
			# --- first-batch new-civ properties (tiers 7-11), appended ---
			"Siren Song Shopkeeper", "Sub-Bass Vault Keeper", "Whale Song Toll Collector",
			"Sea Shanty Fleet Master", "Whalefall Requiem Realtor", "Hydrothermal Organ Tuner",
			"Siren Aria Bondsman", "Lowest-Note Minter", "Sunken Choir Exchange Broker",
			"Midnight Sonata Trustee", "Sovereign of the Low Register", "Poison Ballad Underwriter",
			"Second-Verse Reinsurer", "Spiral Groove Annuitant", "Hymnal Actuary",
			"Sharp-Note Liability Agent", "Debut Single Life Underwriter", "Long Rest Escrow Warden",
			"Tightening Tempo Tribune", "Global Cover Band Adjuster", "Extinction Tour Rider Agent",
			"Fallen Star Indemnifier", "Perpetual Round Cantor", "Wax Cylinder Presser",
			"Sweet Melody Merchant", "Drone Note Dispatcher", "Hexachord Estate Agent",
			"Beeswax Pressing Patent Clerk", "Mead-Hall Minstrel Distiller", "Waggle Dance Choreographer",
			"Swarm Harmony Assurer", "Pheromone Airplay Director", "Pastoral Symphony Annexer",
			"Opening Act Hive Minister", "Queen Tribute Minter", "Royal Fanfare Treasurer",
			"Frozen Score Archivist", "Chillwave Storage Baron", "Glacial Tempo Yardmaster",
			"Crescendo Collapse Trader", "Slow-Thaw Adagio Collector", "Frostbite Fugue Annuitant",
			"White Noise Claims Adjuster", "Fjord Echo Toll Warden", "Winter Ballad Bond Keeper",
			"Icebound Aria Broker", "Glacial Rock Rights Agent", "Coronation Anthem Holder",
			"Ice Age Overture Speculator", "Deep-Freeze Requiem Trustee", "Earworm Licensing Agent",
			"Power Chord Enforcer", "Anthem Rights Registrar", "Unfinished Symphony Broker",
			"Echo Residuals Collector", "Standing Ovation Wrangler", "Modulation Patent Clerk",
			"Moment-of-Silence Assessor", "Twelve-Tone Scale Baron", "Atmospheric Acoustician",
			"Void Venue Impresario", "Celestial Harmonics Broker", "Primordial Drone Licensor",
			"Conductor of the Final Movement",
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
