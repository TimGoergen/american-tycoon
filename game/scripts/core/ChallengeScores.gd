class_name ChallengeScores

# Persists Challenge Mode high scores — one best score per minigame TYPE, saved across sessions
# (Tim, 2026-06-30). Stored as a small JSON file in user:// keyed by the type's display name, so it
# survives app restarts and stays independent of the dynasty save (Challenge Mode is a free-play
# arcade layer, not part of a run). Static-only: call get_high_score / record_score directly; there
# is no instance to create.

const SAVE_PATH := "user://challenge_scores.json"


## The stored {type_key -> high_score} map, or an empty map if the file is missing/unreadable.
static func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


## The saved best score for a minigame type (0 if none yet). `type_key` is the type's display name.
static func get_high_score(type_key: String) -> int:
	return int(_load().get(type_key, 0))


## Record a Challenge Mode score for a type. If it beats the stored best, saves it and returns true
## (a new high score); otherwise leaves the file untouched and returns false.
static func record_score(type_key: String, score: int) -> bool:
	var scores := _load()
	if score <= int(scores.get(type_key, 0)):
		return false
	scores[type_key] = score
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(scores))
	return true
