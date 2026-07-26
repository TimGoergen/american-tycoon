class_name ConfigLoader

# Loads every config Resource under /config (M1 brief: nothing hardcoded).
# Shared by the game (Main.gd) and the balance simulator (Sim.gd) so the
# two can never drift apart on what they load.

const TUNING_PATH := "res://config/tuning.tres"

const PROPERTY_PATHS := [
	"res://config/properties/01_atm.tres",
	"res://config/properties/02_money_tree.tres",
	"res://config/properties/03_nfts.tres",
	"res://config/properties/04_tax_increment_financing.tres",
	"res://config/properties/05_cross_border_distribution.tres",
	"res://config/properties/06_money_laundering.tres",
	"res://config/properties/07_day_trading.tres",
	"res://config/properties/08_flipping_houses.tres",
	"res://config/properties/09_multi_level_marketing.tres",
	"res://config/properties/10_hedge_fund.tres",
	"res://config/properties/11_legislative_assets.tres",
	"res://config/properties/12_executive_assets.tres",
	# Alien property types (GDD §5.5 site 2): each is locked behind its epoch (unlock_tier)
	# and opened by that civilization's First Contact trade-deal minigame — one new kind of
	# business per alien epoch (Luminari → Chronophage). Phase 3 (2026-07-11) sizes each
	# alien magnitude from a threshold-anchored formula (grows at economy_step / DRIFT per
	# epoch), tuned so a new cohort does NOT out-earn the whole economy before it — the fix
	# for "every epoch too fast." See Plans/Epoch_Depth_Pass.md §4 + the sim's pacing
	# MEASUREMENT/PLAYOUT (sim/Sim.gd), which build the real economy to verify the pace.
	"res://config/properties/13_photon_exchange.tres",   # epoch 2 — Luminari Collective
	"res://config/properties/14_data_foundry.tres",      # epoch 3 — Geth-Sentinel Grid
	"res://config/properties/15_spore_bank.tres",        # epoch 4 — Mycelium Unity
	"res://config/properties/16_prism_vault.tres",       # epoch 5 — Quartzite Conglomerate
	"res://config/properties/17_time_bank.tres",         # epoch 6 — Chronophage Enclave
	# COHORT SIBLINGS (Epoch_Depth_Pass Phase 2/3): each alien epoch has FIVE properties —
	# the flagship above plus four siblings ×2.75 apart in magnitude (Phase 3 raised cohorts
	# 4→5, Tim 2026-07-11), so a cohort spans ~57× ≈ one economy_step-60 band and hands off
	# cleanly to the next epoch's flagship. APPENDED here (not re-slotted next to their
	# flagships) ON PURPOSE: this array's order is every save's property INDEX — retention
	# keys, per-property save rows, staffer rosters — so inserting mid-list would force an
	# index migration. The LADDER shows cost order instead (Main sorts the rows for display);
	# indices stay stable.
	"res://config/properties/18_beam_utilities.tres",     # epoch 2
	"res://config/properties/19_solar_futures_desk.tres", # epoch 2
	"res://config/properties/20_dyson_holdings.tres",     # epoch 2
	"res://config/properties/21_server_metropolis.tres",  # epoch 3
	"res://config/properties/22_algorithm_mines.tres",    # epoch 3
	"res://config/properties/23_robo_labor_agency.tres",  # epoch 3
	"res://config/properties/24_hyphae_networks.tres",    # epoch 4
	"res://config/properties/25_biomass_refinery.tres",   # epoch 4
	"res://config/properties/26_terraforming_coop.tres",  # epoch 4
	"res://config/properties/27_gem_exchange.tres",       # epoch 5
	"res://config/properties/28_laser_lens_works.tres",   # epoch 5
	"res://config/properties/29_monolith_realty.tres",    # epoch 5
	"res://config/properties/30_deadline_futures.tres",   # epoch 6
	"res://config/properties/31_moment_market.tres",      # epoch 6
	"res://config/properties/32_eternity_escrow.tres",    # epoch 6
	# The 5th (grandest, most-absurd) member of each cohort (Phase 3, 2026-07-11).
	"res://config/properties/33_starcore_syndicate.tres",   # epoch 2 — Luminari
	"res://config/properties/34_singularity_holdings.tres", # epoch 3 — Geth-Sentinel
	"res://config/properties/35_biosphere_trust.tres",      # epoch 4 — Mycelium
	"res://config/properties/36_geode_dominion.tres",       # epoch 5 — Quartzite
	"res://config/properties/37_causality_capital.tres",    # epoch 6 — Chronophage
	# ESCALATING LADDER additions (Tim 2026-07-15, unlock-cadence fix — see
	# Plans/Escalating_Ladder.md): each alien epoch now has one more property than the
	# last (epoch 2 -> 6 ... epoch 6 -> 10), each cohort still spanning ×16807 total so
	# thresholds and epoch pacing are untouched. The 15 additions sit on the upper-mid
	# rungs of their epochs (above the original siblings, below the grandest venture),
	# and are APPENDED here per this array's index-stability rule.
	"res://config/properties/38_supernova_underwriters.tres",   # epoch 2 — Luminari
	"res://config/properties/39_sentience_leasing_corp.tres",   # epoch 3 — Geth-Sentinel
	"res://config/properties/40_planetary_mainframe.tres",      # epoch 3
	"res://config/properties/41_rotworld_orchards.tres",        # epoch 4 — Mycelium
	"res://config/properties/42_panspermia_logistics.tres",     # epoch 4
	"res://config/properties/43_moonrot_colonies.tres",         # epoch 4
	"res://config/properties/44_bedrock_annuities.tres",        # epoch 5 — Quartzite
	"res://config/properties/45_tectonic_arbitrage.tres",       # epoch 5
	"res://config/properties/46_mantle_extraction_concern.tres", # epoch 5
	"res://config/properties/47_planetcore_assay.tres",         # epoch 5
	"res://config/properties/48_hindsight_hedge_fund.tres",     # epoch 6 — Chronophage
	"res://config/properties/49_nostalgia_refinery.tres",       # epoch 6
	"res://config/properties/50_timeline_repossessions.tres",   # epoch 6
	"res://config/properties/51_millennium_mortgage.tres",      # epoch 6
	"res://config/properties/52_big_bang_buyback.tres",         # epoch 6
	# --- New civilizations, first batch (tiers 7-11) — Plans/Add_20_Civs_And_Alien_Portraits.md ---
	"res://config/properties/53_anglerlight_storefronts.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/54_pressure_vaults.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/55_trench_tollway.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/56_leviathan_charter_fleet.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/57_whalefall_estates.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/58_ventworks_utility.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/59_siren_bond_market.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/60_hadal_mint.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/61_drowned_cathedral_exchange.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/62_midnight_zone_trust.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/63_abyssal_sovereignty.tres",  # epoch 7 — Vashti Deep-Court
	"res://config/properties/64_venom_underwriting.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/65_molt_reinsurance.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/66_coilfold_annuities.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/67_actuarial_temple.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/68_fang_liability_consortium.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/69_hatchling_whole_life.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/70_brumation_escrow_vaults.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/71_constriction_claims_tribunal.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/72_planetary_coverage_coils.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/73_extinction_rider_exchange.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/74_stellar_collapse_indemnity.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/75_the_ouroboros_perpetuity.tres",  # epoch 8 — Ssethraki Coil-Banks
	"res://config/properties/76_wax_works_combine.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/77_nectar_commodities.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/78_drone_placement_agency.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/79_honeycomb_estates.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/80_propolis_patent_office.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/81_royal_mead_distillery.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/82_the_waggle_bourse.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/83_swarm_assurance_society.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/84_pheromone_broadcasting_guild.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/85_meadow_annexation_bureau.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/86_ministry_of_lesser_hives.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/87_the_queen_s_mint.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/88_the_royal_jelly_reserve.tres",  # epoch 9 — Melissar Hive-Court
	"res://config/properties/89_permafrost_ledgers.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/90_cold_storage_monopoly.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/91_glacier_calving_yards.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/92_avalanche_derivatives.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/93_thaw_debt_collections.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/94_frostbite_annuities.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/95_blizzard_claims_hall.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/96_fjord_toll_dominion.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/97_winterlong_bond_vaults.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/98_frozen_sea_exchange.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/99_moraine_mineral_rights.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/100_polar_crown_holdings.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/101_ice_age_futures.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/102_the_deep_ice_endowment.tres",  # epoch 10 — Norrvane Frostholm
	"res://config/properties/103_jingle_licensing.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/104_chord_cartel.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/105_anthem_rights_bureau.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/106_symphony_futures.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/107_reverb_royalties.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/108_encore_futures.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/109_key_change_patents.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/110_silence_easements.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/111_octave_monopoly.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/112_planetary_reverb_chamber.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/113_orbital_amphitheater.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/114_spheres_music_exchange.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/115_cosmic_hum_licensing.tres",  # epoch 11 — The Resonant Octave
	"res://config/properties/116_the_final_movement.tres",  # epoch 11 — The Resonant Octave
]

## Returns null (with an error pushed) if the tuning file is missing.
##
## By default the dev/balance overrides written by the tuning panel (user://,
## see TuningOverrides) are layered on top of the baked defaults, so a tuned
## constant takes effect on the next boot. The balance simulator passes
## apply_user_overrides=false so it always measures the baked numbers, never a
## particular device's local tweaks.
static func load_tuning(apply_user_overrides: bool = true) -> TuningConfig:
	# Load a fresh copy (CACHE_MODE_IGNORE) rather than the shared cached resource:
	# we mutate it with overrides below, and those edits must never bleed into a
	# later baked-defaults load (e.g. the panel reading defaults for comparison).
	var tuning := ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	if tuning == null:
		push_error("ConfigLoader: could not load " + TUNING_PATH)
		return null
	if apply_user_overrides:
		TuningOverrides.apply(tuning, TuningOverrides.load())
	return tuning


## Returns the property ladder configs in order (the 12 Earth properties plus any alien
## property types appended for later epochs), or [] on failure.
static func load_property_configs() -> Array:
	return _load_all(PROPERTY_PATHS)


static func _load_all(paths: Array) -> Array:
	var configs: Array = []
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource == null:
			push_error("ConfigLoader: could not load " + str(path))
			return []
		configs.append(resource)
	return configs
