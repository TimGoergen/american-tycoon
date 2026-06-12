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
]


## Returns null (with an error pushed) if the tuning file is missing.
static func load_tuning() -> TuningConfig:
	var tuning := ResourceLoader.load(TUNING_PATH) as TuningConfig
	if tuning == null:
		push_error("ConfigLoader: could not load " + TUNING_PATH)
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
