class_name TutorialProgress

# Durable, prestige-independent record of which one-time tutorial tips the player has already
# seen, plus the master on/off setting (Plans/Tutorial_Onboarding_Plan.md). Stored as a small
# JSON file in user://, deliberately SEPARATE from the dynasty save so "already taught" survives
# death/prestige (the per-generation GameState save resets on succession) and app restarts.
#
# Modeled 1:1 on ChallengeScores.gd. Static-only: call has_seen / mark_seen directly; there is no
# instance to create.

const SAVE_PATH := "user://tutorial_progress.json"

# The on/off flag shares the same file as the seen-tip ids, under a reserved key that can never
# collide with a tip id (tip ids never start with an underscore).
const ENABLED_KEY := "_tips_enabled"


## The stored map ({tip_id -> true, plus the enabled flag}), or an empty map if missing/unreadable.
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


static func _save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


## Has this tip already been shown once?
static func has_seen(tip_id: String) -> bool:
	return bool(_load().get(tip_id, false))


## Record that a tip has now been shown, so it never repeats. Writes immediately (not on the
## autosave timer) so a kill right after seeing a tip can't make it re-appear.
static func mark_seen(tip_id: String) -> void:
	var data := _load()
	if data.get(tip_id, false):
		return
	data[tip_id] = true
	_save(data)


## Whether tutorial tips are turned on. Defaults ON for a fresh install.
static func is_enabled() -> bool:
	return bool(_load().get(ENABLED_KEY, true))


static func set_enabled(on: bool) -> void:
	var data := _load()
	data[ENABLED_KEY] = on
	_save(data)


## Wipe all tutorial progress (seen tips + the on/off flag). Called by the dev "Reset Game" so
## onboarding can be re-tested from a clean state (Tim, 2026-07-23), and by a future "Replay
## tutorial" action. Like ChallengeScores, this file lives outside the dynasty save, so the dev
## reset must clear it explicitly or it would survive.
static func clear() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
