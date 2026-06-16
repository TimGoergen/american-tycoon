class_name TuningOverrides

# Dev/balance tuning overrides layered on top of the baked config/tuning.tres.
#
# Why this exists: on an exported build (Android) res://config/tuning.tres is
# read-only, so the on-device dev tuning panel (GDD §13 "Balance config screen")
# cannot write back to it. Instead the panel writes only the *changed* constants
# here, to a writable user:// JSON file, and ConfigLoader.load_tuning() applies
# them over the baked defaults at boot. Anything not listed falls back to the
# baked value, so removing an override — or shipping a new default — just works.
#
# This is a developer tool, not a player feature, but it lives in the normal
# load path so a tuned value takes effect on the next boot exactly as if it had
# been baked into the resource.

const OVERRIDE_PATH := "user://tuning_overrides.json"
const OVERRIDE_FILENAME := "tuning_overrides.json"


## Returns the saved overrides as { constant_name: number }, or an empty
## dictionary when no override file exists (the normal case on a clean install).
static func load() -> Dictionary:
	if not FileAccess.file_exists(OVERRIDE_PATH):
		return {}
	var file := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		push_warning("TuningOverrides: could not open " + OVERRIDE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("TuningOverrides: malformed override file, ignoring it")
	return {}


## Write the overrides to disk, replacing any previous file. `full_precision`
## keeps tiny constants (0.005) and huge ones ($103.6T) round-tripping exactly.
static func save(overrides: Dictionary) -> void:
	var file := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TuningOverrides: could not write " + OVERRIDE_PATH)
		return
	file.store_string(JSON.stringify(overrides, "\t", true, true))
	file.close()


## Delete the override file entirely, returning tuning to the baked defaults on
## the next load. Safe to call when no file exists.
static func clear() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(OVERRIDE_FILENAME):
		dir.remove(OVERRIDE_FILENAME)


## Set the overridden constants onto a freshly loaded TuningConfig. Unknown keys
## (a constant renamed since the override was written) and non-numeric values are
## skipped with a warning, so a stale override file can never crash the load.
## Each constant keeps its declared type — ints stay ints (JSON numbers parse as
## floats, so int constants are cast back).
static func apply(tuning: TuningConfig, overrides: Dictionary) -> void:
	for name in overrides.keys():
		var current: Variant = tuning.get(name)
		if current == null:
			push_warning("TuningOverrides: ignoring unknown constant '%s'" % name)
			continue
		var value: Variant = overrides[name]
		if not (value is float or value is int):
			push_warning("TuningOverrides: ignoring non-numeric override for '%s'" % name)
			continue
		if typeof(current) == TYPE_INT:
			tuning.set(name, int(value))
		else:
			tuning.set(name, float(value))
