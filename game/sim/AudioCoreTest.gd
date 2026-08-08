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
	_check_collect_is_relative()
	_check_collect_needs_presence()

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
	for id in [&"tap_note", &"buy_success", &"collect", &"music_preview"]:
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
	print("\n-- the tap scale --")
	_audio.reset_tap_scale()
	_check("it starts at the root", int(_audio.get("_tap_step")) == 0)

	for i in range(4):
		_audio.play_tap_note()
	_check("four taps climb four steps (step %d)" % int(_audio.get("_tap_step")),
		int(_audio.get("_tap_step")) == 3)

	# It must PIN at the top rather than run off the end of the scale.
	for i in range(50):
		_audio.play_tap_note()
	var scale: Array = _audio.get_script().get_script_constant_map()["TAP_SCALE_SEMITONES"]
	var top: int = scale.size() - 1
	_check("a long run pins at the top of the range (step %d of %d)" % [int(_audio.get("_tap_step")), top],
		int(_audio.get("_tap_step")) == top)

	# A gap in the tapping drops it back to the root: the run belongs to one burst.
	_audio.set("_tap_last_ms", Time.get_ticks_msec() - 10_000)
	_audio.play_tap_note()
	_check("a pause resets the climb to the root", int(_audio.get("_tap_step")) == 0)

	# And a tab change does the same, so a climb never resumes after the player went elsewhere.
	_audio.play_tap_note()
	_audio.reset_tap_scale()
	_check("reset_tap_scale drops it to the root", int(_audio.get("_tap_step")) == 0)


## RULE 2, the one this whole test exists for: nothing may branch on a dollar magnitude.
func _check_collect_is_relative() -> void:
	print("\n-- intensity comes from ratios, never magnitudes --")
	# The same RATIO at wildly different scales must give the same answer. These two windows are
	# eighteen orders of magnitude apart: generation 1, and a deep late-game estate.
	var early: float = _audio.call("_collect_intensity", 500.0, 1000.0)
	var late: float = _audio.call("_collect_intensity", 500.0e18, 1000.0e18)
	_check("a small window and a colossal one at the same ratio sound identical (%.3f vs %.3f)"
			% [early, late],
		is_equal_approx(early, late))

	# And the ratio itself has to matter, or the previous check would pass on a constant.
	var passive: float = _audio.call("_collect_intensity", 250.0, 1000.0)   # ~1x expected: idle
	var burst: float = _audio.call("_collect_intensity", 1000.0, 1000.0)    # ~4x expected: a rush
	_check("a passive window sits at the floor (%.3f)" % passive, is_zero_approx(passive))
	_check("a burst maxes out (%.3f)" % burst, is_equal_approx(burst, 1.0))
	_check("a burst is louder than idle", burst > passive)

	# Nothing to divide by must not become a divide by zero.
	_check("no income yields no sound rather than an error",
		is_zero_approx(_audio.call("_collect_intensity", 100.0, 0.0)))


## RULE 1: unattended events stay silent. This is what makes a full soundtrack survivable.
func _check_collect_needs_presence() -> void:
	print("\n-- unattended payouts are silent --")
	# Nobody has touched anything for a long time.
	_audio.set("_last_interaction_ms", Time.get_ticks_msec() - 60_000)
	_check("the player reads as absent", not _audio.player_is_present())

	_audio.set("_collect_last_played_ms", -100_000)
	_audio.note_collect(1000.0, 1.0)
	_audio.set("_collect_window_opened_ms", Time.get_ticks_msec() - 10_000)
	_disarm_all()
	_audio.call("_process", 0.016)
	_check("a payout window while absent makes NO sound", not _any_voice_armed(BUS_SFX))
	_check("...and the window is consumed rather than left to pile up",
		is_zero_approx(float(_audio.get("_collect_accum"))))

	# Now the player is here.
	_audio.set("_last_interaction_ms", Time.get_ticks_msec())
	_audio.set("_collect_last_played_ms", -100_000)
	(_audio.get("_last_played_ms") as Dictionary)[&"collect"] = -100_000
	_audio.note_collect(1000.0, 1.0)
	_audio.set("_collect_window_opened_ms", Time.get_ticks_msec() - 10_000)
	_disarm_all()
	_audio.call("_process", 0.016)
	_check("the same payout window DOES sound while the player is present",
		_any_voice_armed(BUS_SFX))


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
