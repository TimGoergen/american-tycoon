extends SceneTree

# Exports the LIVE game's property ladder and per-civilization staffer rosters to two JSON
# snapshots. These are the inputs that claude/civ_v2_regen/assemble.py reads to regenerate the
# civilizations v2 review draft (docs/civilizations_v2_draft.json).
#
# WHY THIS EXISTS: before this exporter the two snapshots were produced by hand into a throwaway
# session temp folder, so assemble.py's SCRATCH path pointed at a directory that no longer existed
# and a regen could not be reproduced. This script makes the live game the reproducible source of
# truth: run it, then run assemble.py.
#
# Usage:  godot --headless --path . --script res://sim/DumpLiveCivData.gd
# Output: <project root>/claude/civ_v2_regen/live_snapshot/
#           - live_properties.json : the 52 properties in ConfigLoader.PROPERTY_PATHS (id) order,
#                                    each {name, tier, cost, income, cycle, staffer}. NOTE: Earth's
#                                    tier is emitted as 0 (its .tres unlock_tier defaults to 1, but
#                                    assemble.py groups Earth under tier 0).
#           - live_rosters.json    : the 6 live civilizations, each {civilization, staffer_names},
#                                    where staffer_names is the full 52-entry ladder roster.

func _init() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")
	# The regen tooling lives beside the Godot project (game/), one level up under claude/.
	var output_dir := project_dir.path_join("../claude/civ_v2_regen/live_snapshot").simplify_path()

	var made := DirAccess.make_dir_recursive_absolute(output_dir)
	if made != OK and not DirAccess.dir_exists_absolute(output_dir):
		push_error("DumpLiveCivData: could not create output dir " + output_dir)
		quit(1)
		return

	var property_count := _write_properties(output_dir)
	_write_rosters(output_dir, property_count)

	print("DumpLiveCivData: wrote %d properties and %d civilizations to %s"
		% [property_count, EpochCatalog.tier_count(), output_dir])
	quit(0)


# Dumps the property ladder in PROPERTY_PATHS order. Returns the property count for the roster
# length check below.
func _write_properties(output_dir: String) -> int:
	var configs := ConfigLoader.load_property_configs()
	if configs.is_empty():
		push_error("DumpLiveCivData: no property configs loaded")
		quit(1)
		return 0

	var properties: Array = []
	for config in configs:
		# assemble.py expects Earth grouped under tier 0; the .tres unlock_tier defaults to 1
		# for the 12 Earth properties and is 2..6 for alien property types.
		var export_tier: int = 0 if config.unlock_tier <= 1 else config.unlock_tier
		properties.append({
			"name": config.display_name,
			"tier": export_tier,
			"cost": _whole_as_int(config.base_cost),
			"income": _whole_as_int(config.base_income_per_unit),
			"cycle": _whole_as_int(config.base_cycle_length),
			"staffer": config.staffer_name,
		})

	_write_json(output_dir.path_join("live_properties.json"), properties)
	return properties.size()


# Dumps each live civilization's full staffer roster (one title per ladder position).
func _write_rosters(output_dir: String, property_count: int) -> void:
	var rosters: Array = []
	for tier in range(1, EpochCatalog.tier_count() + 1):
		var epoch := EpochCatalog.get_epoch(tier)
		var staffer_names: Array = epoch["staffer_names"]
		# assemble.py zips this roster against the 52 properties; a short roster would silently
		# drop titles, so fail loudly if the lengths ever diverge.
		if staffer_names.size() != property_count:
			push_error("DumpLiveCivData: %s roster has %d names, expected %d"
				% [epoch["civilization"], staffer_names.size(), property_count])
			quit(1)
			return
		rosters.append({
			"civilization": epoch["civilization"],
			"staffer_names": staffer_names,
		})

	_write_json(output_dir.path_join("live_rosters.json"), rosters)


# Renders a whole-valued cost/income/cycle as an integer (50, not 50.0), matching the draft's
# number style so a regen stays byte-stable. Values of 1e15 or more (16+ significant digits — the
# alien-scale live costs at tiers 5-6) stay floats, matching how the original export serialized
# them, so the assembled draft is byte-for-byte reproducible.
func _whole_as_int(x: float) -> Variant:
	if x == floor(x) and absf(x) < 1_000_000_000_000_000.0:  # 1e15
		return int(x)
	return x


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DumpLiveCivData: could not open for write: " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
