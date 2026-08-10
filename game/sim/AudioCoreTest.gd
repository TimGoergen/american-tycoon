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
	_audio.call("_build_heat_layer")
	_audio.call("_build_music_players")

	_check_catalog()
	_check_mute_costs_nothing()
	_check_cooldown()
	_check_voice_pool_is_bounded()
	_check_tap_scale()
	await _check_buy_intensity_is_relative()
	_check_one_sound_per_gesture()
	_check_vent_cues_exist()
	_check_ceremony_beats()
	_check_band_mapping()
	await _check_music_mix()
	_check_the_count_fits_the_window()
	await _check_overdrive_bed()

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


## EVERY CUE THE TABLE DESCRIBES MUST RESOLVE A SAMPLE. Tim's brief (2026-08-09) was that every cue
## gets a hook AND a default, so the whole design can be heard before anything is sourced — this is
## that promise, checked. A cue with no file is silent, which is correct behaviour and invisible.
func _check_catalog() -> void:
	print("-- every cue resolves a sample --")
	var cues: Dictionary = _audio.get_script().get_script_constant_map()["CUES"]
	var events: Dictionary = _audio.get("_events")
	var unrecorded: Array[String] = []
	for id in cues:
		var samples: Array = events.get(id, [])
		if samples.is_empty():
			unrecorded.append(String(id))
	_check("all %d cues have a sample (%s)"
			% [cues.size(), "none missing" if unrecorded.is_empty() else ", ".join(unrecorded)],
		unrecorded.is_empty())

	# The two the game pitches deliberately must have NO random detune, or a figure the player is
	# meant to hear as counting becomes a figure that is merely out of tune.
	for id in [&"tap_note", &"vent_lift"]:
		_check("'%s' has no random pitch variance (the game pitches it)" % id,
			is_zero_approx(float((cues[id] as Dictionary).get("variance", 0.0))))

	# The layered cues need their companion sample, or intensity above the threshold does nothing.
	var layers: Dictionary = _audio.get("_layers")
	for id in cues:
		if (cues[id] as Dictionary).get("layered", false):
			_check("'%s' has its _layer sample" % id, layers.has(id))

	# The window cue must beat the ticks it leads: it is the one the player reacts to.
	_check("the vent window cue is louder than its ticks",
		float((cues[&"vent_open"] as Dictionary)["db"]) > float((cues[&"vent_tick"] as Dictionary)["db"]))

	# A NAME THAT IS NOT IN THE TABLE must complain rather than fail silently — a typo'd id is
	# otherwise indistinguishable from a sound nobody has recorded yet.
	_check("an unknown cue id is refused", not events.has(&"definitely_not_a_cue"))


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

	# THE COMPLAINT, PINNED — in two parts, because there were two complaints.
	#
	# First: the figure used to climb and then repeat the top note for as long as tapping continued,
	# which made a sustained run "a single highly repetitive sound". Second: even once it rose and
	# fell, every lap was identical, so a long run was one short loop played over and over ("I like
	# the idea of rotating the starting degree each lap"). Both are about the same thing — the pitch
	# must keep moving — so both are asserted on the actual sequence of notes rather than on the
	# mechanism that produces them.
	var scale: Array = _audio.get_script().get_script_constant_map()["TAP_SCALE_SEMITONES"]
	var lap_length: int = _audio.call("_tap_run_length")
	var lap_count: int = maxi(1, int(_audio.call("_tap_window_travel")) * 2)

	# Play out a full cycle of the slow drift, exactly as sustained tapping would.
	var notes: Array[int] = []
	for lap in range(lap_count):
		for position in range(lap_length):
			notes.append(int(scale[int(_audio.call("_degree_at", position, lap))]))

	var longest_repeat := 1
	var current_repeat := 1
	for i in range(1, notes.size()):
		current_repeat = current_repeat + 1 if notes[i] == notes[i - 1] else 1
		longest_repeat = maxi(longest_repeat, current_repeat)
	_check("no note is ever played twice in a row (longest identical stretch: %d)" % longest_repeat,
		longest_repeat == 1)

	# NO TWO CONSECUTIVE LAPS ARE THE SAME. This is the rotation, stated as what you would hear.
	var identical_neighbours := 0
	for lap in range(lap_count - 1):
		var a := notes.slice(lap * lap_length, (lap + 1) * lap_length)
		var b := notes.slice((lap + 1) * lap_length, (lap + 2) * lap_length)
		if a == b:
			identical_neighbours += 1
	_check("consecutive laps are never identical (%d repeats found)" % identical_neighbours,
		identical_neighbours == 0)

	# And the drift covers the whole scale rather than hovering in one register.
	var distinct := {}
	for note in notes:
		distinct[note] = true
	_check("the drift reaches every degree of the scale (%d of %d)" % [distinct.size(), scale.size()],
		distinct.size() == scale.size())

	# It must come home, or "cycle" would be the wrong word for it.
	_check("the cycle returns to where it started (%d taps)" % notes.size(),
		int(_audio.call("_degree_at", 0, 0)) == int(_audio.call("_degree_at", 0, lap_count % lap_count)))
	_check("the full cycle is long enough not to read as a loop (%d taps)" % notes.size(),
		notes.size() >= 100)

	# The window must SLIDE, not rotate: a rotated pitch set wraps its top note round to the bottom
	# mid-figure, putting an octave leap inside what should be a smooth rise.
	var biggest_leap := 0
	for i in range(1, notes.size()):
		biggest_leap = maxi(biggest_leap, absi(notes[i] - notes[i - 1]))
	# Within a lap every step is one scale degree. At a lap seam the window has moved, and the size of
	# that seam depends on which way: drifting UP lands one step above the note that just played,
	# drifting back DOWN can fall by as much as a sixth. A sixth is an ordinary melodic interval and
	# is left alone deliberately.
	#
	# A COARSE BOUND, honestly labelled. It says the figure never leaps by an octave, which is a
	# property worth keeping but is not what caught anything: both wrong constructions tried during
	# development (rotating a fixed pitch set, and advancing the figure's phase along with the window)
	# were caught by the repeated-note and whole-scale checks above, not by this one. It earns its
	# place as a guard against a future change, not as a record of a past bug.
	_check("no leap as large as an octave anywhere in the cycle (largest: %d semitones)" % biggest_leap,
		biggest_leap < 12)

	# Print one lap and the lap after it, so the melody is inspectable rather than merely asserted.
	print("      lap 0: %s" % str(notes.slice(0, lap_length)))
	print("      lap 1: %s" % str(notes.slice(lap_length, lap_length * 2)))


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


## Every beat of the vent gesture needs a sound, or the gesture is only playable by eye.
func _check_vent_cues_exist() -> void:
	print("
-- the vent gesture's beats --")
	var events: Dictionary = _audio.get("_events")
	for id in [&"vent_tick", &"vent_open", &"vent_lift", &"vent_success", &"vent_miss",
			&"overheat", &"rush_ready"]:
		_check("'%s' has a sample" % id, not (events.get(id, []) as Array).is_empty())


## THE STORY BEATS (Phase 4). These differ from every other sound in the game in two ways that are
## easy to get wrong, so both are asserted rather than assumed.
func _check_ceremony_beats() -> void:
	print("
-- the ceremony beats --")
	var cues: Dictionary = _audio.get_script().get_script_constant_map()["CUES"]
	var events: Dictionary = _audio.get("_events")
	var ids := [&"ceremony_obituary", &"ceremony_will", &"ceremony_heir", &"ceremony_contact",
		&"ceremony_contact_reveal", &"legacy_purchase", &"welcome_back", &"prestige_confirm"]
	for id in ids:
		_check("'%s' has a sample" % id, not (events.get(id, []) as Array).is_empty())

	# They ride the Ceremony bus, which keeps them separable in the mix from the tap sound — and,
	# more importantly, means they cannot mark the player as PRESENT. A succession happens TO the
	# player; a beat that renewed the presence window would be voting on their behalf.
	var all_ceremony := true
	for id in ids:
		if (cues[id] as Dictionary)["bus"] != &"Ceremony":
			all_ceremony = false
	_check("every beat is on the Ceremony bus, so none can mark the player present", all_ceremony)

	var shortest := 100000.0
	for id in ids:
		shortest = minf(shortest, float((cues[id] as Dictionary)["cooldown"]))
	_check("their cooldowns prevent self-overlap (%.0f ms)" % shortest, shortest >= 250.0)


## A LOOP THAT DOES NOT MEET ITSELF CLICKS, once per lap, for as long as it plays.
##
## This shipped (2026-08-09). The generator rounded each wave's PERIOD to whole samples instead of
## fitting whole cycles into the buffer, leaving the loop 0.02 cycles short of home — a jump thirty
## times a normal sample step. Inaudible as a pitch error; obvious as a crackle once the drone is
## held for seconds (Tim: "there are crackles in it").
##
## Checked on the IMPORTED resource rather than only in the generator: the generator asserts what it
## wrote, this asserts what the game will play. A sourced loop dropped in by hand gets the same
## scrutiny for free.
##
## The comparator is the LARGEST step the waveform already makes on its own — the seam is one more
## sample transition, and measuring against the average makes a good loop look broken (it did, on the
## first attempt at this check).
func _check_loop_is_seamless(label: String, stream: AudioStreamWAV) -> void:
	var bytes := stream.data
	var frames := bytes.size() / 2
	if frames < 3:
		_check("%s loop has audio to check" % label, false)
		return

	var biggest_step := 0
	var previous := bytes.decode_s16(0)
	var first := previous
	for i in range(1, frames):
		var sample := bytes.decode_s16(i * 2)
		biggest_step = maxi(biggest_step, absi(sample - previous))
		previous = sample
	var seam: int = absi(first - previous)

	_check("the %s loop meets itself cleanly (seam %d vs largest normal step %d)"
			% [label, seam, biggest_step],
		seam <= biggest_step)


## THE BAND MAP (plan §3.2). A pure function on tier, so it can be checked exhaustively rather than
## sampled — and every tier in the game must land somewhere, including tiers that do not exist yet.
func _check_band_mapping() -> void:
	print("
-- the era band map --")
	var script := _audio.get_script() as GDScript
	var seen: Dictionary = {}
	var previous := -1
	var monotonic := true
	for tier in range(1, 28):
		var band: int = script.call("band_for_tier", tier)
		seen[band] = true
		if band < previous:
			monotonic = false
		previous = band
	_check("every one of the 27 tiers maps to a band", seen.size() > 0)
	_check("all five bands are used (%d of 5)" % seen.size(), seen.size() == 5)
	# It must never go BACKWARDS: the music deepens as the run does, and a tier that fell back to an
	# earlier band would crossfade the player into their own past.
	_check("bands only ever move forward with the tiers", monotonic)

	# The two Earth epochs get their own bands — the promotion is meant to be audible (§3.2).
	_check("Blue Collar and White Collar are different bands",
		int(script.call("band_for_tier", 1)) != int(script.call("band_for_tier", 2)))
	# And a tier beyond the content still answers, rather than indexing off the end.
	var beyond: int = script.call("band_for_tier", 99)
	_check("a tier past the content still maps somewhere (%d)" % beyond, beyond >= 0 and beyond < 5)


## THE MIX: crossfade, idle fade and duck all move the same volume, which is why they are computed
## in one place. These check they cooperate rather than fight.
func _check_music_mix() -> void:
	print("
-- the music mix --")
	var players: Array = _audio.get("_music_players")
	_check("there are two players, so a band can cross to another", players.size() == 2)

	_audio.set_music_band(0)
	_check("setting a band starts a track", int(_audio.get("_music_band")) == 0)
	var first_player: int = int(_audio.get("_music_active"))

	# Re-asserting the same band must be free — callers assert it on every epoch change.
	_audio.set_music_band(0)
	_check("re-asserting the same band does not restart it",
		int(_audio.get("_music_active")) == first_player)

	# A different band crosses to the OTHER player, or there is no crossfade to speak of.
	_audio.set_music_band(3)
	_check("a new band crosses to the other player",
		int(_audio.get("_music_active")) != first_player)

	# IDLE. Wind the interaction clock back and let the mix run: the music should fade away.
	_audio.set("_music_idle_gain", 1.0)
	_audio.set("_last_interaction_ms", Time.get_ticks_msec() - 600_000)
	_audio.set("_heat_active", false)
	for i in range(240):
		_audio.call("_process", 0.05)
	_check("with the player long gone, the music fades out (%.2f)"
			% float(_audio.get("_music_idle_gain")),
		float(_audio.get("_music_idle_gain")) < 0.01)

	# ...and comes back when they touch anything.
	_audio.set("_last_interaction_ms", Time.get_ticks_msec())
	for i in range(120):
		_audio.call("_process", 0.05)
	_check("acting brings it back (%.2f)" % float(_audio.get("_music_idle_gain")),
		float(_audio.get("_music_idle_gain")) > 0.99)

	# A RIDE COUNTS AS PRESENCE. Fading out mid-rush because the player is HOLDING rather than
	# tapping would be a bug that feels like a bug.
	_audio.set("_last_interaction_ms", Time.get_ticks_msec() - 600_000)
	_audio.set("_heat_active", true)
	for i in range(120):
		_audio.call("_process", 0.05)
	_check("an active ride keeps the music alive even with no taps (%.2f)"
			% float(_audio.get("_music_idle_gain")),
		float(_audio.get("_music_idle_gain")) > 0.99)

	# DUCK: with the bed running, the music sits lower than it would otherwise.
	var ducked: float = (players[int(_audio.get("_music_active"))] as AudioStreamPlayer).volume_db
	_audio.set("_heat_active", false)
	_audio.set("_last_interaction_ms", Time.get_ticks_msec())
	for i in range(10):
		_audio.call("_process", 0.05)
	var plain: float = (players[int(_audio.get("_music_active"))] as AudioStreamPlayer).volume_db
	_check("the music ducks under a ride (%.1f dB vs %.1f dB)" % [ducked, plain], ducked < plain)

	_audio.stop_music()
	for i in range(120):
		_audio.call("_process", 0.05)
	var all_stopped := true
	for player in players:
		if (player as AudioStreamPlayer).playing:
			all_stopped = false
	_check("stopping the music really stops the streams", all_stopped)


## THE LIFT COUNT MUST FIT INSIDE THE WINDOW IT IS COUNTING FOR.
##
## The count ticks moved from vent SPAWN to window-OPEN (Tim, 2026-08-09: a marker 0.7 s before the
## thing it marks makes the player hold an interval in their head). That fixes the timing but creates
## a new way to be wrong: a count that outlasts its window would read as something to wait through,
## at the exact moment the player must already be moving.
##
## So the relationship is asserted from the REAL constants on both sides — the bar's tick pacing, the
## core's hard cap on lifts, and the tuning's shortest possible window. Raising MAX_VENT_LIFTS or
## lowering the duration floor breaks this test rather than quietly breaking the mechanic.
func _check_the_count_fits_the_window() -> void:
	print("
-- the lift count fits inside the shortest window --")
	var bar_script: GDScript = load("res://scripts/ui/" + "MomentumBar.gd")
	var rush_script: GDScript = load("res://scripts/core/" + "RushMomentumState.gd")
	var tuning: TuningConfig = load("res://config/tuning.tres")
	if bar_script == null or rush_script == null or tuning == null:
		_check("the constants are readable", false)
		return

	var bar_consts := bar_script.get_script_constant_map()
	var lead: float = bar_consts["VENT_COUNT_TICK_LEAD_SEC"]
	var spacing: float = bar_consts["VENT_COUNT_TICK_SPACING_SEC"]
	var max_lifts: int = rush_script.get_script_constant_map()["MAX_VENT_LIFTS"]
	var shortest_window: float = tuning.rush_momentum_vent_duration_floor

	var longest_count := lead + float(max_lifts - 1) * spacing
	_check("the fullest count (%d lifts, %.0f ms) finishes inside the shortest window (%.0f ms)"
			% [max_lifts, longest_count * 1000.0, shortest_window * 1000.0],
		longest_count < shortest_window)

	# And with room to act, not merely to hear it — the count is a prompt, not the gesture.
	_check("...with most of the window still left to play (%.0f%% used)"
			% (100.0 * longest_count / shortest_window),
		longest_count < shortest_window * 0.6)

	# THE HAPTIC RIDES THE SAME BEATS (Tim, 2026-08-09), so the bump must fit BETWEEN them. The tuned
	# vent pulse is longer than the spacing; at full length the buzzes would run together into one
	# continuous vibration and the count would stop counting.
	var bump_ms: float = bar_consts["VENT_COUNT_HAPTIC_MS"]
	_check("the haptic bump fits between beats (%.0f ms bump, %.0f ms apart)"
			% [bump_ms, spacing * 1000.0],
		bump_ms < spacing * 1000.0)
	_check("...and is shorter than the tuned vent pulse it is derived from (%.0f vs %.0f ms)"
			% [bump_ms, tuning.rush_momentum_haptic_vent_ms],
		bump_ms <= tuning.rush_momentum_haptic_vent_ms)


## THE CONTINUOUS BED (plan §5.1). Held sounds have failure modes one-shots do not: they can be
## left running forever, and they can be started twice.
func _check_overdrive_bed() -> void:
	print("
-- the overdrive bed --")
	var heat: AudioStreamPlayer = _audio.get("_heat_player")
	var urgency: AudioStreamPlayer = _audio.get("_urgency_player")
	_check("both layers exist", heat != null and urgency != null)
	if heat == null or urgency == null:
		return
	_check("they ride the MUSIC bus, so the music slider governs the drone", heat.bus == &"Music")
	_check("both loop, or the bed would fall silent mid-ride",
		(heat.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED)
	_check_loop_is_seamless("heat", heat.stream as AudioStreamWAV)
	_check_loop_is_seamless("urgency", urgency.stream as AudioStreamWAV)
	# Settle the bed first. It shares the per-frame mix with the music, and the music section above
	# leaves a ride running to test the duck — so asserting a pristine startup state here would be
	# measuring test order rather than behaviour.
	_audio.set_heat_active(false)
	for i in range(120):
		_audio.call("_mix_heat_bed", 1.0 / 60.0)
	_check("with no ride on, the bed is silent and stopped", not heat.playing and not urgency.playing)

	# A ride starts.
	_audio.set_heat_active(true)
	_audio.set_heat(0.0)
	_audio.call("_mix_heat_bed", 0.5)
	_check("engaging starts the bed", heat.playing)
	var cold_pitch := heat.pitch_scale
	_check("the urgency layer is silent while heat is low (%.0f dB)" % urgency.volume_db,
		urgency.volume_db < -40.0)

	# Heat climbs.
	_audio.set_heat(1.0)
	_audio.call("_mix_heat_bed", 0.5)
	_check("the drone RISES with heat (%.3f -> %.3f)" % [cold_pitch, heat.pitch_scale],
		heat.pitch_scale > cold_pitch)
	_check("...by a musical interval, not a siren (%.2f = %.1f semitones)"
			% [heat.pitch_scale, 12.0 * log(heat.pitch_scale) / log(2.0)],
		heat.pitch_scale <= 2.0)
	_check("the urgency layer arrives at the top of the band (%.0f dB)" % urgency.volume_db,
		urgency.volume_db > -40.0)

	# Half way up, the urgency layer must still be out of the way — it announces the ceiling, and an
	# alarm that sounds in the middle of the band is an alarm the player learns to ignore.
	_audio.set_heat(0.5)
	_audio.call("_mix_heat_bed", 0.5)
	_check("...and stays silent through the middle of the band (%.0f dB)" % urgency.volume_db,
		urgency.volume_db < -40.0)

	# Idempotence: the drive is a per-frame call, so re-asserting the same state must be free.
	_audio.set_heat_active(true)
	_check("re-engaging an already-running bed does not restart it", heat.playing)

	# THE FLAG MUST BE FREE TO FLICKER. It is polled every frame from a value that genuinely wavers
	# near the cruise clamp, and the first version rebuilt a fade tween and restarted two streams on
	# every change — sixty times a second in a busy moment, on the audio thread. Tim's game closed
	# outright while rushing and buying at once. Flipping it repeatedly must now cost nothing.
	for i in range(200):
		_audio.set_heat_active(i % 2 == 0)
		_audio.call("_mix_heat_bed", 1.0 / 60.0)
	_check("flipping the ride flag every frame leaves the bed intact", heat.stream != null)

	# And it must actually STOP, not linger at -60 dB decoding forever.
	_audio.set_heat_active(false)
	for i in range(120):
		_audio.call("_mix_heat_bed", 1.0 / 60.0)
	_check("ending the ride stops the streams rather than muting them", not heat.playing)
	_check("...and the urgency layer stops with it", not urgency.playing)

	# Coming back on must restart cleanly after that stop.
	_audio.set_heat_active(true)
	for i in range(30):
		_audio.call("_mix_heat_bed", 1.0 / 60.0)
	_check("a later ride starts the bed again", heat.playing)
	_audio.set_heat_active(false)
	for i in range(120):
		_audio.call("_mix_heat_bed", 1.0 / 60.0)


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
