class_name SaveManager

# Save-file I/O: versioned JSON (M1 brief). Static methods only; FileAccess
# works headlessly, so the simulator round-trips saves with the exact code
# the game uses.

const DEFAULT_SAVE_PATH := "user://save.json"


## Write the game's save dict to `path` as JSON. Returns true on success.
static func save_to_file(game: GameState, path: String = DEFAULT_SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing (error %d)" % [
			path, FileAccess.get_open_error()
		])
		return false
	file.store_string(JSON.stringify(game.to_save_dict(), "\t"))
	file.close()
	return true


## Read and parse a save file. Returns an empty Dictionary if the file is
## missing or unreadable — callers treat that as "no save; fresh start".
static func load_from_file(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not valid save JSON" % path)
		return {}
	return data


## Wall-clock seconds since the save was written — the offline-calc input.
## Negative values (device clock moved backwards) clamp to 0 (Spec §2).
static func get_seconds_since_save(save_dict: Dictionary) -> float:
	var saved_at := float(save_dict.get("saved_at_unix", Time.get_unix_time_from_system()))
	return maxf(Time.get_unix_time_from_system() - saved_at, 0.0)
