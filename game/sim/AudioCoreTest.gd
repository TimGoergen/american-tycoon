extends SceneTree

# Headless gate for the Audio autoload's rules (Plans/Audio_System.md §0.4, §1.3, §4.1, §4.3).
#
# Usage: godot --headless --path . --script res://sim/AudioCoreTest.gd
#
# Audio disables itself headless, which is exactly right for the other gates — they must not need
# audio stubs — but it would make this test vacuous. So this test FORCE-ENABLES it and drives it
# directly. That is possible because the bus layout loads fine without an audio device: all five
# buses exist here, only the output does not.
#
# HOW A PLAY IS OBSERVED. Not by `playing`, which depends on the dummy driver's behaviour, but by
# whether a voice got ARMED — handed a stream. Every voice's stream is cleared before an assertion,
# so "some voice now holds a stream" means the play was accepted and "none does" means it was
# refused. That is driver-independent.
#
# WHAT IS WORTH PINNING HERE. The three rules that are invisible until they are violated in front of
# a player: muted really costs nothing, a bounded pool never grows, and intensity never depends on
# the SIZE of a number. The last is the one most likely to be broken by a well-meaning edit, because
# scaling a sound by the dollar amount is the obvious thing to write and it is wrong at every
# generation but the one you tested.

var _failures := 0

## The Audio autoload, resolved from the tree rather than by its global name.
##
## `--script` compiles THIS file before the engine registers autoload globals, so the identifier
## `Audio` is not in scope here even though the node is perfectly alive by the time we run. (Main.gd
## can use the global name freely — it is compiled later, when the scene is instantiated.)
var _audio: Node

## Bus names as literals for the same reason: Audio's constants are not reachable at compile time.
const BUS_SFX := &"SFX"


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Audio core ===\n")

	# Let the tree come up first: during _initialize() `root` is not yet IN the tree, and an absolute
	# path lookup from outside it errors. A relative lookup after a frame is the reliable form.
	await process_frame
	_audio = root.get_node_or_null(^"Audio")
	if _audio == null:
		print("FAILED: the Audio autoload is not in the tree")
		quit(1)
		return

	# Bring it up by hand: it turned itself off on boot because this is headless.
	_audio.set("_enabled", true)
	_audio.call("_load_catalog")
	_audio.call("_build_voice_pools")
	for bus in [&"Music", BUS_SFX, &"UI", &"Ceremony"]:
		_audio.set_bus_volume(bus, 1.0)

	_check_catalog()
	_check_mute_costs_nothing()
	_check_cooldown()
	_check_voice_pool_is_bounded()
	_check_tap_scale()
	await _check_buy_intensity_is_relative()
	_check_one_sound_per_gesture()

	# Tear the voices down before quitting: they are children of an autoload this test brought up by
	# hand, and leaving them alive prints leak warnings that would look like a product problem.
	for bus in (_audio.get("_voices") as Dictionary):
		for player in (_audio.get("_voices") as Dictionary)[bus]:
			(player as Node).queue_free()
	_audio.set("_voices", {})
	_audio.set("_events", {})
	await process_frame

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _check_catalog() -> void:
	print("-- catalog --")
	var events: Dictionary = _audio.get("_events")
	for id in [&"tap_note", &"buy_success", &"music_preview"]:
		_check("'%s' is in the catalog with a sample" % id,
			events.has(id) and (events[id] as AudioEvent).stream != null)
	# The tap sample is pitched by the scale, so a random detune on top would simply be out of tune.
	var tap: AudioEvent = events.get(&"tap_note")
	_check("the tap sample has NO random pitch variance",
		tap != null and is_zero_approx(tap.pitch_variance))
	# The purchase sound needs its brighter layer, or intensity above the threshold does nothing.
	var buy: AudioEvent = events.get(&"buy_success")
	_check("the purchase sound has a layer for big moments", buy != null and buy.layer_stream != null)


func _check_mute_costs_nothing() -> void:
	print("\n-- muted is a first-class state --")
	_audio.set_bus_volume(BUS_SFX, 0.0)
	_disarm_all()
	_audio.play(&"buy_success")
	_check("a play on a muted bus never reaches a voice", not _any_voice_armed(BUS_SFX))

	_audio.set_bus_volume(BUS_SFX, 1.0)
	_disarm_all()
	_audio.play(&"buy_success")
	_check("...and the same play DOES reach one once the bus is up", _any_voice_armed(BUS_SFX))


func _check_cooldown() -> void:
	print("\n-- per-event cooldown --")
	# Pretend the event just played, then ask again immediately.
	var last: Dictionary = _audio.get("_last_played_ms")
	last[&"buy_success"] = Time.get_ticks_msec()
	_disarm_all()
	_audio.play(&"buy_success")
	_check("a repeat inside the cooldown is dropped", not _any_voice_armed(BUS_SFX))

	last[&"buy_success"] = Time.get_ticks_msec() - 10_000
	_disarm_all()
	_audio.play(&"buy_success")
	_check("...and is allowed again once the cooldown has passed", _any_voice_armed(BUS_SFX))


func _check_voice_pool_is_bounded() -> void:
	print("\n-- the voice pool is fixed --")
	var pool: Array = (_audio.get("_voices") as Dictionary)[BUS_SFX]
	var size_before := pool.size()
	# Far more plays than voices, with the cooldown stepped around so every one is accepted.
	var last: Dictionary = _audio.get("_last_played_ms")
	for i in range(200):
		last[&"buy_success"] = -100_000
		_audio.play(&"buy_success")
	var pool_after: Array = (_audio.get("_voices") as Dictionary)[BUS_SFX]
	_check("200 plays did not allocate a single new voice (%d, was %d)" % [pool_after.size(), size_before],
		pool_after.size() == size_before)
	_check("the pool is the size the plan specifies (8 SFX voices)", size_before == 8)


func _check_tap_scale() -> void:
	print("
-- the tap scale --")
	_audio.reset_tap_scale()
	_check("it starts at the root", int(_audio.get("_tap_position")) == 0)

	for i in range(4):
		_audio.play_tap_note()
	_check("four taps advance four steps (position %d)" % int(_audio.get("_tap_position")),
		int(_audio.get("_tap_position")) == 3)

	# A pause drops it back to the root: the run belongs to one burst of tapping.
	_audio.set("_tap_last_ms", Time.get_ticks_msec() - 10_000)
	_audio.play_tap_note()
	_check("a pause resets the run to the root", int(_audio.get("_tap_position")) == 0)

	# And a tab change does the same, so a run never resumes after the player went elsewhere.
	_audio.play_tap_note()
	_audio.reset_tap_scale()
	_check("reset_tap_scale drops it to the root", int(_audio.get("_tap_position")) == 0)

	# THE COMPLAINT, PINNED. The figure used to climb and then repeat the top note for as long as
	# tapping continued, which is what made a sustained run "a single highly repetitive sound"
	# (Tim, 2026-08-08). What matters is not the exact contour but that the pitch KEEPS MOVING.
	var scale: Array = _audio.get_script().get_script_constant_map()["TAP_SCALE_SEMITONES"]
	var lap: int = _audio.call("_tap_run_length")
	var degrees: Array[int] = []
	for i in range(lap * 3):
		degrees.append(int(_audio.call("_degree_at", i % lap)))

	var longest_repeat := 1
	var current_repeat := 1
	for i in range(1, degrees.size()):
		current_repeat = current_repeat + 1 if degrees[i] == degrees[i - 1] else 1
		longest_repeat = maxi(longest_repeat, current_repeat)
	_check("a long run NEVER repeats a note (longest identical stretch: %d)" % longest_repeat,
		longest_repeat == 1)

	var distinct := {}
	for degree in degrees:
		distinct[degree] = true
	_check("it uses the whole scale (%d of %d degrees)" % [distinct.size(), scale.size()],
		distinct.size() == scale.size())

	# It must genuinely turn around rather than jump from the top back to the root.
	_check("the run rises to the top and falls back (top at %d of a %d-tap lap)"
			% [scale.size() - 1, lap],
		int(_audio.call("_degree_at", scale.size() - 1)) == scale.size() - 1
			and int(_audio.call("_degree_at", scale.size())) == scale.size() - 2)
	_check("the lap is long enough not to read as a short loop (%d taps)" % lap, lap >= 16)


## RULE 2: nothing may branch on a dollar MAGNITUDE.
##
## Purchase loudness is the only intensity-scaled sound left — cycle-end audio was removed on Tim's
## call (2026-08-08: "only when the user taps to purchase") — so this is where the rule is pinned. It
## is the rule most likely to be broken by a well-meaning edit, because scaling by the PRICE is the
## obvious thing to write and it is wrong at every generation except the one it was tested at.
##
## Main owns the calculation, so it is exercised through Main: the helper reads its floor and ceiling
## from a tuning knob.
func _check_buy_intensity_is_relative() -> void:
	print("
-- purchase intensity comes from ratios, never magnitudes --")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame

	# The SAME fractional gain, eighteen orders of magnitude apart: generation 1, and a deep estate.
	var early: float = main.call("_buy_intensity", 1_000.0, 1_200.0)
	var late: float = main.call("_buy_intensity", 1_000.0e18, 1_200.0e18)
	_check("a +20%% buy sounds the same at any scale (%.3f vs %.3f)" % [early, late],
		is_equal_approx(early, late))

	# The fraction has to matter, or the check above would pass on a constant.
	var tiny: float = main.call("_buy_intensity", 1_000.0, 1_005.0)     # +0.5%
	var huge: float = main.call("_buy_intensity", 1_000.0, 2_000.0)     # +100%
	_check("a marginal buy sits at the floor (%.3f)" % tiny, is_zero_approx(tiny))
	_check("a doubling maxes out (%.3f)" % huge, is_equal_approx(huge, 1.0))
	_check("bigger relative gains are louder", huge > tiny)

	# A colossal ABSOLUTE price that barely moves income must stay quiet. This is the whole point:
	# price-scaled audio would make this the loudest sound in the game.
	var expensive_but_marginal: float = main.call("_buy_intensity", 1.0e24, 1.0e24 * 1.005)
	_check("a buy costing a trillion that moves income 0.5%% is QUIET (%.3f)" % expensive_but_marginal,
		is_zero_approx(expensive_but_marginal))

	# The first staffed property has no prior income to be a fraction of; it is unambiguously big.
	_check("the very first income counts as a full-intensity moment",
		is_equal_approx(main.call("_buy_intensity", 0.0, 5.0), 1.0))

	main.queue_free()
	await process_frame


## ONE SOUND PER GESTURE, AND IT COMES FIRST.
##
## The rule "a hold sounds like one thing, not sixty" was first implemented as "silence the repeats",
## which quietly put the single sound at the END of the gesture — the release-fired purchase was the
## only audible one, so pressing and holding for half a second meant the confirmation arrived when
## the finger lifted (Tim, 2026-08-08: a noticeable delay between clicking buy and hearing it).
##
## PropertyRow is loaded through an assembled path: naming a UI class statically from a sim can
## create a class-resolution cycle that breaks parsing in unrelated files.
func _check_one_sound_per_gesture() -> void:
	print("
-- one purchase sound per gesture, at its START --")
	var row_script: GDScript = load("res://scripts/ui/" + "PropertyRow.gd")
	if row_script == null:
		_check("PropertyRow.gd loads", false)
		return
	var row = row_script.new()

	# PLAYER_TAP is the value Main sounds on; HOLD_REPEAT is the silent one.
	var sources: Array = []
	for i in range(5):
		sources.append(row.call("_next_buy_source"))
	var audible: int = row_script.get_script_constant_map()["ActionSource"]["PLAYER_TAP"]
	_check("the FIRST purchase of a gesture is the audible one", sources[0] == audible)
	var later_audible := 0
	for i in range(1, sources.size()):
		if sources[i] == audible:
			later_audible += 1
	_check("every later purchase in the same gesture is silent (%d audible)" % later_audible,
		later_audible == 0)

	# Ending the gesture re-arms it, or the second tap of a double-tap would be silent.
	row.set("_buy_gesture_acted", false)
	_check("a fresh gesture is audible again", row.call("_next_buy_source") == audible)

	# The hire path carries the same semantics, so its first action is the audible one too.
	_check("hire follows the same rule", row.call("_next_hire_source") == audible)
	_check("...and its repeats do not", row.call("_next_hire_source") != audible)

	row.free()


# --- Observing plays ----------------------------------------------------------------------------

## Clear every voice's stream, so "has a stream" afterwards means "was handed one just now".
func _disarm_all() -> void:
	for bus in (_audio.get("_voices") as Dictionary):
		for player in (_audio.get("_voices") as Dictionary)[bus]:
			(player as AudioStreamPlayer).stop()
			(player as AudioStreamPlayer).stream = null


func _any_voice_armed(bus: StringName) -> bool:
	for player in (_audio.get("_voices") as Dictionary).get(bus, []):
		if (player as AudioStreamPlayer).stream != null:
			return true
	return false


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
