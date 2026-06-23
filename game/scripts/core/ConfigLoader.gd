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
]

const TITLE_PATHS := [
	"res://config/titles/01_intern.tres",
	"res://config/titles/02_associate.tres",
	"res://config/titles/03_shift_supervisor.tres",
	"res://config/titles/04_assistant_manager.tres",
	"res://config/titles/05_manager.tres",
	"res://config/titles/06_senior_manager.tres",
	"res://config/titles/07_department_head.tres",
	"res://config/titles/08_director.tres",
	"res://config/titles/09_senior_director.tres",
	"res://config/titles/10_vice_president.tres",
	"res://config/titles/11_senior_vice_president.tres",
	"res://config/titles/12_executive_vice_president.tres",
	"res://config/titles/13_managing_director.tres",
	"res://config/titles/14_partner.tres",
	"res://config/titles/15_senior_partner.tres",
	"res://config/titles/16_chief_operating_officer.tres",
	"res://config/titles/17_chief_financial_officer.tres",
	"res://config/titles/18_chief_executive_officer.tres",
	"res://config/titles/19_president.tres",
	"res://config/titles/20_chairman.tres",
	"res://config/titles/21_founder.tres",
	"res://config/titles/22_magnate.tres",
	"res://config/titles/23_tycoon.tres",
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


## Returns the 12 PropertyConfigs in GDD §4 ladder order, or [] on failure.
static func load_property_configs() -> Array:
	return _load_all(PROPERTY_PATHS)


## Returns the wage-ladder TitleRows in rank order, or [] on failure.
static func load_title_configs() -> Array:
	return _load_all(TITLE_PATHS)


static func _load_all(paths: Array) -> Array:
	var configs: Array = []
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource == null:
			push_error("ConfigLoader: could not load " + str(path))
			return []
		configs.append(resource)
	return configs
