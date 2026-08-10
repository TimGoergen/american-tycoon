extends SceneTree

# Headless gate for the player-settings plumbing (Plans/Audio_System.md §6.4, §9).
#
# Usage: godot --headless --path . --script res://sim/AudioSettingsTest.gd
#
# WHY THIS EXISTS. A succession builds a BRAND-NEW GameState, so anything parked there as a player
# CHOICE reverts to its default every prestige unless _carry_player_settings_to_heir copies it. That
# is not hypothetical: ui_buy_mode and ui_minigame_enabled were silently dropping this way for
# months, and it hid because Main keeps its own UI mirrors — the controls kept showing the old value
# while GameState had already reverted, and the loss only surfaced on the next launch once the
# reverted value had been saved over the real one.
#
# The audio settings are three more fields of exactly that kind, so this pins the RULE rather than
# just the three new fields: every `ui_` preference that survives a save round-trip must also survive
# a succession. That assertion is the one that would have caught the original bug, and it protects
# the older settings too.

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Audio settings persistence ===\n")

	var tuning: TuningConfig = load("res://config/tuning.tres")
	var configs := ConfigLoader.load_property_configs()
	if tuning == null or configs.is_empty():
		print("FAILED to load config")
		quit(1)
		return

	_check_defaults(tuning, configs)
	_check_round_trip(tuning, configs)
	_check_succession(tuning, configs)
	_check_every_ui_setting_is_carried(tuning, configs)
	_check_clamping(tuning, configs)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _check_defaults(tuning: TuningConfig, configs: Array) -> void:
	print("-- defaults --")
	var game := DynastyState.new(configs, tuning).current
	# Not full volume on a first launch: several sounds can land in one frame, and a game that is
	# too loud out of the box is a game that gets muted in its first minute.
	_check("music starts below full (%.2f)" % game.ui_music_volume,
		game.ui_music_volume > 0.0 and game.ui_music_volume < 1.0)
	_check("sfx starts below full (%.2f)" % game.ui_sfx_volume,
		game.ui_sfx_volume > 0.0 and game.ui_sfx_volume < 1.0)
	# Haptics DO start at full: the durations are already tuned values, and the slider scales them.
	_check("haptics start at full (%.2f)" % game.ui_haptics_scale,
		is_equal_approx(game.ui_haptics_scale, 1.0))


func _check_round_trip(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- save round-trip --")
	var dynasty := DynastyState.new(configs, tuning)
	dynasty.current.ui_music_volume = 0.35
	dynasty.current.ui_sfx_volume = 0.15
	dynasty.current.ui_haptics_scale = 0.0

	var loaded := DynastyState.new(configs, tuning)
	loaded.load_save_dict(dynasty.to_save_dict())
	_check("music volume survives a save", is_equal_approx(loaded.current.ui_music_volume, 0.35))
	_check("sfx volume survives a save", is_equal_approx(loaded.current.ui_sfx_volume, 0.15))
	# Zero specifically, because zero is the one value a "default when absent" bug silently eats.
	_check("a haptics setting of ZERO survives (not re-defaulted to 1.0)",
		is_equal_approx(loaded.current.ui_haptics_scale, 0.0))

	print("\n-- a save written before audio existed --")
	var old_save := dynasty.to_save_dict()
	(old_save["current"] as Dictionary).erase("music_volume")
	(old_save["current"] as Dictionary).erase("sfx_volume")
	(old_save["current"] as Dictionary).erase("haptics_scale")
	var upgraded := DynastyState.new(configs, tuning)
	upgraded.load_save_dict(old_save)
	_check("absent keys take their defaults rather than zero",
		upgraded.current.ui_music_volume > 0.0 and upgraded.current.ui_sfx_volume > 0.0)


func _check_succession(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- succession --")
	var dynasty := DynastyState.new(configs, tuning)
	dynasty.current.ui_music_volume = 0.25
	dynasty.current.ui_sfx_volume = 0.45
	dynasty.current.ui_haptics_scale = 0.0
	dynasty.current.economy.cash_earned_this_gen = 1.0e12

	dynasty.perform_succession()
	_check("music volume survives a succession (%.2f)" % dynasty.current.ui_music_volume,
		is_equal_approx(dynasty.current.ui_music_volume, 0.25))
	_check("sfx volume survives a succession (%.2f)" % dynasty.current.ui_sfx_volume,
		is_equal_approx(dynasty.current.ui_sfx_volume, 0.45))
	_check("haptics OFF survives a succession (it does not switch itself back on)",
		is_equal_approx(dynasty.current.ui_haptics_scale, 0.0))


## THE RULE, not the three fields: anything saved as a `ui_` preference must also be carried to the
## heir. Written generically so a preference added later is covered without editing this test — which
## is the entire point, since the bug class is "someone added a setting and forgot the second place".
func _check_every_ui_setting_is_carried(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- every ui_ preference is carried --")
	var dynasty := DynastyState.new(configs, tuning)

	# Move every ui_ field away from its default by a rule that works for each type, then prestige
	# and check nothing snapped back.
	var changed: Dictionary = {}
	for property in dynasty.current.get_property_list():
		var name: String = property["name"]
		if not name.begins_with("ui_"):
			continue
		var value = dynasty.current.get(name)
		var moved = value
		if typeof(value) == TYPE_BOOL:
			moved = not value
		elif typeof(value) == TYPE_INT:
			moved = 1 if value == 0 else 0
		elif typeof(value) == TYPE_FLOAT:
			moved = 0.25 if not is_equal_approx(value, 0.25) else 0.75
		else:
			continue
		dynasty.current.set(name, moved)
		changed[name] = moved

	_check("there are ui_ preferences to check (%d found)" % changed.size(), changed.size() >= 8)

	dynasty.current.economy.cash_earned_this_gen = 1.0e12
	dynasty.perform_succession()

	var dropped: Array[String] = []
	for name in changed:
		if dynasty.current.get(name) != changed[name]:
			dropped.append(name)
	_check("no ui_ preference is dropped by a succession (dropped: %s)" % str(dropped),
		dropped.is_empty())


func _check_clamping(tuning: TuningConfig, configs: Array) -> void:
	print("\n-- a corrupt save cannot reach the mixer --")
	var dynasty := DynastyState.new(configs, tuning)
	var save := dynasty.to_save_dict()
	# A level outside 0..1 would come through as a nonsense dB value, so load clamps rather than
	# trusting the file.
	(save["current"] as Dictionary)["music_volume"] = 9.0
	(save["current"] as Dictionary)["sfx_volume"] = -3.0
	var loaded := DynastyState.new(configs, tuning)
	loaded.load_save_dict(save)
	_check("an over-range level is clamped to 1.0", is_equal_approx(loaded.current.ui_music_volume, 1.0))
	_check("a negative level is clamped to 0.0", is_equal_approx(loaded.current.ui_sfx_volume, 0.0))


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
