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
	# --- REMAINING CIVS (tiers 12-26), appended 2026-07-26. Same append-only rule as above:
	# array order is the save-file property INDEX, so new cohorts go at the END, not re-slotted.
	# --- epoch 12 — Umbrafex Syndicate ---
	"res://config/properties/117_redacted_ledgers.tres",
	"res://config/properties/118_umbral_shell_foundry.tres",
	"res://config/properties/119_blackout_brokerage.tres",
	"res://config/properties/120_deniability_trust.tres",
	"res://config/properties/121_whisper_clearinghouse.tres",
	"res://config/properties/122_favor_futures_desk.tres",
	"res://config/properties/123_ghost_payroll_bureau.tres",
	"res://config/properties/124_the_silent_auction.tres",
	"res://config/properties/125_bank_of_nowhere.tres",
	"res://config/properties/126_leverage_reserve_vault.tres",
	"res://config/properties/127_retroactive_erasure_group.tres",
	"res://config/properties/128_shadow_central_bank.tres",
	"res://config/properties/129_ministry_of_nonexistence.tres",
	"res://config/properties/130_the_unlit_exchange.tres",
	# --- epoch 13 — Karr'ghan Warhoard ---
	"res://config/properties/131_ransom_escrow.tres",
	"res://config/properties/132_siege_logistics.tres",
	"res://config/properties/133_mercenary_exchange.tres",
	"res://config/properties/134_war_bond_colosseum.tres",
	"res://config/properties/135_protection_racket_annex.tres",
	"res://config/properties/136_plunder_clearinghouse.tres",
	"res://config/properties/137_tribute_futures_pit.tres",
	"res://config/properties/138_warpath_toll_authority.tres",
	"res://config/properties/139_hostile_takeover_legion.tres",
	"res://config/properties/140_scorched_earth_realty.tres",
	"res://config/properties/141_conquest_dividend_bureau.tres",
	"res://config/properties/142_orbital_blockade_consortium.tres",
	"res://config/properties/143_grand_pillage_portfolio.tres",
	"res://config/properties/144_the_warhoard_citadel.tres",
	# --- epoch 14 — The Politesse Ascendancy ---
	"res://config/properties/145_courtesy_tolls.tres",
	"res://config/properties/146_apology_notary.tres",
	"res://config/properties/147_invitation_futures.tres",
	"res://config/properties/148_grudge_endowment.tres",
	"res://config/properties/149_thank_you_note_mint.tres",
	"res://config/properties/150_small_talk_reserve.tres",
	"res://config/properties/151_rsvp_clearinghouse.tres",
	"res://config/properties/152_seating_chart_exchange.tres",
	"res://config/properties/153_condolence_consortium.tres",
	"res://config/properties/154_debutante_bond_exchange.tres",
	"res://config/properties/155_faux_pas_tribunal.tres",
	"res://config/properties/156_orbital_finishing_school.tres",
	"res://config/properties/157_forgiveness_reserve_bank.tres",
	"res://config/properties/158_the_last_word_estate.tres",
	# --- epoch 15 — Oneiroi Drift ---
	"res://config/properties/159_sleep_debt_collections.tres",
	"res://config/properties/160_lucid_licensing.tres",
	"res://config/properties/161_nightmare_insurance.tres",
	"res://config/properties/162_subconscious_real_estate.tres",
	"res://config/properties/163_snooze_button_tolls.tres",
	"res://config/properties/164_counting_sheep_leasing.tres",
	"res://config/properties/165_deja_vu_royalties.tres",
	"res://config/properties/166_melatonin_futures.tres",
	"res://config/properties/167_somnambulist_staffing.tres",
	"res://config/properties/168_insomnia_subscriptions.tres",
	"res://config/properties/169_rem_cycle_refineries.tres",
	"res://config/properties/170_circadian_grid_utilities.tres",
	"res://config/properties/171_collective_unconscious_trust.tres",
	"res://config/properties/172_the_waking_monopoly.tres",
	# --- epoch 16 — The Glossolalia Lyceum ---
	"res://config/properties/173_syllable_mint.tres",
	"res://config/properties/174_etymology_mines.tres",
	"res://config/properties/175_thesaurus_vaults.tres",
	"res://config/properties/176_dead_language_estates.tres",
	"res://config/properties/177_idiom_refinery.tres",
	"res://config/properties/178_grammar_debtors_prison.tres",
	"res://config/properties/179_pronunciation_tollway.tres",
	"res://config/properties/180_rhetoric_futures_exchange.tres",
	"res://config/properties/181_untranslatable_word_reserve.tres",
	"res://config/properties/182_proto_tongue_derricks.tres",
	"res://config/properties/183_babel_reconstruction_trust.tres",
	"res://config/properties/184_mother_tongue_monopoly.tres",
	"res://config/properties/185_the_silence_concession.tres",
	"res://config/properties/186_the_unspeakable_lexicon.tres",
	# --- epoch 17 — Ferrovore Guilds ---
	"res://config/properties/187_scrap_tithes.tres",
	"res://config/properties/188_rust_refineries.tres",
	"res://config/properties/189_alloy_dynasties.tres",
	"res://config/properties/190_smelter_sovereignty.tres",
	"res://config/properties/191_corrosion_escrow.tres",
	"res://config/properties/192_ore_debt_registries.tres",
	"res://config/properties/193_tarnish_futures.tres",
	"res://config/properties/194_slag_baronies.tres",
	"res://config/properties/195_foundry_cartels.tres",
	"res://config/properties/196_rust_tithe_cathedrals.tres",
	"res://config/properties/197_magnetosphere_monopolies.tres",
	"res://config/properties/198_mantle_mining_concordats.tres",
	"res://config/properties/199_the_molten_mint.tres",
	"res://config/properties/200_the_core_iron_throne.tres",
	# --- epoch 18 — The Vantablack Salon ---
	"res://config/properties/201_velvet_rope_concessions.tres",
	"res://config/properties/202_taste_tribunals.tres",
	"res://config/properties/203_couture_foundries.tres",
	"res://config/properties/204_auction_seances.tres",
	"res://config/properties/205_vernissage_circuits.tres",
	"res://config/properties/206_gala_blacklist_registries.tres",
	"res://config/properties/207_restoration_ateliers.tres",
	"res://config/properties/208_provenance_vaults.tres",
	"res://config/properties/209_biennale_monopolies.tres",
	"res://config/properties/210_movement_manufactories.tres",
	"res://config/properties/211_the_zeitgeist_refinery.tres",
	"res://config/properties/212_obsolescence_bureaus.tres",
	"res://config/properties/213_negative_space_exchange.tres",
	"res://config/properties/214_the_canon_estate.tres",
	# --- epoch 19 — Fortuna Cartel ---
	"res://config/properties/215_scratch_shrine_franchises.tres",
	"res://config/properties/216_house_edge_utilities.tres",
	"res://config/properties/217_jackpot_reservoirs.tres",
	"res://config/properties/218_destiny_bookmakers.tres",
	"res://config/properties/219_loaded_dice_foundries.tres",
	"res://config/properties/220_comp_suite_arcologies.tres",
	"res://config/properties/221_roulette_ring_worlds.tres",
	"res://config/properties/222_whale_harvest_fleets.tres",
	"res://config/properties/223_probability_refineries.tres",
	"res://config/properties/224_luck_futures_exchange.tres",
	"res://config/properties/225_vigorish_gravity_wells.tres",
	"res://config/properties/226_casino_moon_consortium.tres",
	"res://config/properties/227_the_infinite_parlay.tres",
	"res://config/properties/228_the_rigged_table.tres",
	# --- epoch 20 — Mirror Meridian ---
	"res://config/properties/229_mirror_mints.tres",
	"res://config/properties/230_doppelganger_staffing.tres",
	"res://config/properties/231_vanity_exchanges.tres",
	"res://config/properties/232_reflection_royalties.tres",
	"res://config/properties/233_echo_escrow.tres",
	"res://config/properties/234_selfsame_insurance.tres",
	"res://config/properties/235_likeness_licensing_bureau.tres",
	"res://config/properties/236_the_gallery_of_you.tres",
	"res://config/properties/237_kaleidoscope_trust.tres",
	"res://config/properties/238_quicksilver_sea_refinery.tres",
	"res://config/properties/239_mirror_moon_works.tres",
	"res://config/properties/240_orbital_vanity_ring.tres",
	"res://config/properties/241_the_second_speculum.tres",
	"res://config/properties/242_the_infinite_regress.tres",
	# --- epoch 21 — Ossuary Compact ---
	"res://config/properties/243_probate_catacombs.tres",
	"res://config/properties/244_ancestor_annuities.tres",
	"res://config/properties/245_mausoleum_realty.tres",
	"res://config/properties/246_reliquary_trusts.tres",
	"res://config/properties/247_columbarium_exchange.tres",
	"res://config/properties/248_cenotaph_securities.tres",
	"res://config/properties/249_charnel_clearinghouse.tres",
	"res://config/properties/250_eulogy_underwriting.tres",
	"res://config/properties/251_seance_brokerage.tres",
	"res://config/properties/252_barrow_bond_market.tres",
	"res://config/properties/253_necropolis_bourse.tres",
	"res://config/properties/254_purgatory_escrow.tres",
	"res://config/properties/255_afterlife_sovereign_fund.tres",
	"res://config/properties/256_the_estate_eternal.tres",
	# --- epoch 22 — Spectacle Prime ---
	"res://config/properties/257_engagement_farms.tres",
	"res://config/properties/258_attention_refineries.tres",
	"res://config/properties/259_parasocial_bonds.tres",
	"res://config/properties/260_virality_futures.tres",
	"res://config/properties/261_clickbait_foundries.tres",
	"res://config/properties/262_sponsored_content_mills.tres",
	"res://config/properties/263_follower_hatcheries.tres",
	"res://config/properties/264_drama_exchanges.tres",
	"res://config/properties/265_cancellation_insurance.tres",
	"res://config/properties/266_persona_cloning_vats.tres",
	"res://config/properties/267_the_algorithm_cathedral.tres",
	"res://config/properties/268_planetwide_livestream_grid.tres",
	"res://config/properties/269_attention_singularity.tres",
	"res://config/properties/270_the_eternal_feed.tres",
	# --- epoch 23 — Vek-Tor Kollektiv ---
	"res://config/properties/271_queue_concessions.tres",
	"res://config/properties/272_rubber_stamp_foundries.tres",
	"res://config/properties/273_permit_pyramids.tres",
	"res://config/properties/274_committee_of_committees.tres",
	"res://config/properties/275_triplicate_archives.tres",
	"res://config/properties/276_waiting_room_estates.tres",
	"res://config/properties/277_bureau_of_grievances.tres",
	"res://config/properties/278_signature_refinery.tres",
	"res://config/properties/279_inspectorate_of_inspections.tres",
	"res://config/properties/280_lost_records_vault.tres",
	"res://config/properties/281_stamp_reserve_bank.tres",
	"res://config/properties/282_the_eternal_queue.tres",
	"res://config/properties/283_ministry_of_pending.tres",
	"res://config/properties/284_the_central_plan.tres",
	# --- epoch 24 — Atlas Concordat ---
	"res://config/properties/285_border_tollbooths.tres",
	"res://config/properties/286_meridian_leases.tres",
	"res://config/properties/287_cartography_copyrights.tres",
	"res://config/properties/288_territorial_nebulae.tres",
	"res://config/properties/289_compass_rose_franchises.tres",
	"res://config/properties/290_legend_licensing.tres",
	"res://config/properties/291_projection_patents.tres",
	"res://config/properties/292_antipode_holdings.tres",
	"res://config/properties/293_equator_toll_ring.tres",
	"res://config/properties/294_magnetic_pole_trust.tres",
	"res://config/properties/295_continental_drift_futures.tres",
	"res://config/properties/296_terra_incognita_escrow.tres",
	"res://config/properties/297_the_master_graticule.tres",
	"res://config/properties/298_the_edge_of_the_map.tres",
	# --- epoch 25 — The Null Ledger ---
	"res://config/properties/299_zero_sum_clearinghouses.tres",
	"res://config/properties/300_decay_arbitrage.tres",
	"res://config/properties/301_entropy_audit_bureaus.tres",
	"res://config/properties/302_heat_death_reserves.tres",
	"res://config/properties/303_half_life_holdings.tres",
	"res://config/properties/304_redshift_receivership.tres",
	"res://config/properties/305_vacuum_decay_futures.tres",
	"res://config/properties/306_proton_decay_trusts.tres",
	"res://config/properties/307_stellar_foreclosure_courts.tres",
	"res://config/properties/308_galactic_liquidation_fleets.tres",
	"res://config/properties/309_black_hole_escrow.tres",
	"res://config/properties/310_universal_write_down_office.tres",
	"res://config/properties/311_the_penultimate_kelvin.tres",
	"res://config/properties/312_the_final_balance.tres",
	# --- epoch 26 — The Proprietors Absolute ---
	"res://config/properties/313_fine_print_mills.tres",
	"res://config/properties/314_concept_copyrights.tres",
	"res://config/properties/315_liens_on_existence.tres",
	"res://config/properties/316_title_registry_of_everything.tres",
	"res://config/properties/317_soul_escrow_services.tres",
	"res://config/properties/318_gravity_easement_office.tres",
	"res://config/properties/319_mathematics_licensing_bureau.tres",
	"res://config/properties/320_timeshares_in_time.tres",
	"res://config/properties/321_probability_trust_holdings.tres",
	"res://config/properties/322_mortgages_on_causality.tres",
	"res://config/properties/323_eminent_domain_of_reality.tres",
	"res://config/properties/324_divine_foreclosure_division.tres",
	"res://config/properties/325_escheat_of_the_multiverse.tres",
	"res://config/properties/326_the_deed_to_the_universe.tres",
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
