extends Node

# THE AUDIO SINGLETON (Plans/Audio_System.md §1.1). Registered in project.godot as the project's
# first and only autoload.
#
# WHY AN AUTOLOAD, when this codebase otherwise prefers static classes (TutorialProgress,
# SaveManager, Money.format_mode): audio needs AudioStreamPlayer NODES that outlive Main. Main is
# rebuilt on every succession and on every tuning-apply, and music that restarted each time an heir
# took over would be unlistenable. A static class cannot own nodes; a scene-tree singleton can.
#
# EVERYTHING ROUTES THROUGH HERE. No other script creates an AudioStreamPlayer. That is the same
# containment the project already applies to haptics — one call site meant haptics could be made
# tunable later without hunting — and it is what makes "mute costs nothing" and the voice cap
# enforceable rather than aspirational.
#
# THE FOUR RULES THIS FILE EXISTS TO HOLD (plan §0.4):
#   1. Sound means the player DID something. Unattended repeating events stay silent.
#   2. No absolute magnitudes, ever. Intensity comes from ratios, never from dollars.
#   3. Audio never gates gameplay. Every call is fire-and-forget; nothing here is awaited.
#   4. Muted is a first-class state, and so is headless.

## Where the sound table lives. Editing that resource is how samples get swapped.
const CATALOG_PATH := "res://config/audio_events.tres"

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_CEREMONY := &"Ceremony"

## Voices per bus, allocated once at boot and never freed (plan §1.3). Sized for the worst honest
## case rather than generously: SFX gets the most because the tap scale is the highest-frequency
## sound in the game and the one most able to stack; Music gets two so a crossfade has somewhere to
## go in Phase 2. The heat drone arrives with Phase 3 and gets its own dedicated player then.
const VOICES_PER_BUS := {
	BUS_SFX: 8,
	BUS_UI: 4,
	BUS_CEREMONY: 2,
	BUS_MUSIC: 2,
}

## The tap scale (plan §4.1, decision 2 and 6). Semitone offsets of a C major pentatonic across two
## octaves. FIXED, deliberately not keyed to the current music track: the point is that a burst of
## tapping always sounds like the same tune, whatever era you are in.
##
## Pentatonic because every note in it agrees with every other — a player hammering the button in no
## particular rhythm cannot produce a wrong note.
##
## The set runs an octave BELOW the sample's authored pitch as well as above it. Extending downward
## rather than piling more octaves on top keeps the top of the range at ~1.7 kHz: a sine blip up at
## three octaves is shrill, and shrill is what a repeated sound cannot afford to be.
const TAP_SCALE_SEMITONES := [-12, -10, -8, -5, -3, 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

## How many of those degrees one lap of the figure moves through. The lap is the FAST movement; the
## window it occupies drifts slowly across the full set, which is the slow one (see _degree_at).
const TAP_WINDOW_SIZE := 8

## How far the window moves between laps, in scale degrees.
##
## TWO, not one, and the reason is the seam. A lap ends one degree above its window's root, so a
## drift of one would open the next lap on the pitch that just played — an audible stutter every
## fourteen taps, which is exactly the repeated-note artifact the turns are shaped to avoid. Drifting
## by two lands the new lap one step ABOVE the note that just played, so the seam becomes one more
## step of the rise instead of a repeat.
const TAP_WINDOW_DRIFT := 2

## Fade applied to the master bus when the app loses focus (plan §3.4). Short enough to be gone
## before the app is backgrounded, long enough not to click.
const FOCUS_FADE_SECONDS := 0.2


# --- State -------------------------------------------------------------------------------------

## bus name → its pool of players.
var _voices: Dictionary = {}
## bus name → the index to steal next. Advancing this round-robin IS the steal-oldest policy: the
## least recently started voice on a bus is always the one furthest around the ring.
var _next_voice: Dictionary = {}

## event id → AudioEvent, built once from the catalog.
var _events: Dictionary = {}

## event id → the msec clock reading when it last played, for per-event cooldowns.
var _last_played_ms: Dictionary = {}

## bus name → the player's linear 0..1 level. Held here as well as on the AudioServer so a muted
## check costs a Dictionary read rather than a dB conversion.
var _bus_levels: Dictionary = {}

## False when there is no usable audio at all — a headless sim run. Every public method turns into a
## cheap return, so the gates need no audio stubs (plan §0.4 rule 4).
var _enabled := true

## How far into the current lap we are, which lap the slow window drift is on, and when the run last
## advanced. Neither counter is a scale degree — see _degree_at.
var _tap_position := 0
var _tap_lap := 0
var _tap_last_ms := 0

## The msec clock reading of the last thing the PLAYER did (an SFX or UI sound). Collect audio and
## the Phase 2 idle fade both key off this — it is the codified form of rule 1.
var _last_interaction_ms := 0

## Tunable knobs, pushed in by Main from TuningConfig so audio timing is adjustable in the dev panel
## like everything else. Defaults here match TuningConfig's and keep Audio usable before any push.
var _tap_scale_reset_seconds := 1.0
var _presence_window_ms := 2000.0
var _scaled_min_db := -10.0
var _layer_threshold := 0.5


func _ready() -> void:
	# Keep running while the game is paused: menus and overlays that pause the tree still make
	# sounds, and a paused audio singleton would swallow them.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_enabled = _audio_is_available()
	if not _enabled:
		# A headless gate run lands here. Say so once — a silent disable is indistinguishable from a
		# broken one when someone is wondering why a device build has no sound.
		print("Audio: no audio device (headless); every audio call will be a no-op.")
		return

	_load_catalog()
	_build_voice_pools()
	for bus in [BUS_MUSIC, BUS_SFX, BUS_UI, BUS_CEREMONY]:
		_bus_levels[bus] = 1.0


## Headless Godot runs with a dummy display and no audio hardware. Detecting it HERE rather than at
## every call site is the same discipline MomentumBar._vibrate uses for the mobile-only guard.
func _audio_is_available() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	# A missing bus means the layout resource did not load, in which case every play would land on
	# Master at full volume with no slider controlling it. Silence is the better failure.
	return AudioServer.get_bus_index(BUS_SFX) >= 0


func _load_catalog() -> void:
	var catalog: AudioEventCatalog = load(CATALOG_PATH)
	if catalog == null:
		push_warning("Audio: no catalog at %s; sounds will be skipped." % CATALOG_PATH)
		return
	_events = catalog.index()


func _build_voice_pools() -> void:
	for bus in VOICES_PER_BUS:
		var pool: Array[AudioStreamPlayer] = []
		for i in range(VOICES_PER_BUS[bus]):
			var player := AudioStreamPlayer.new()
			player.bus = bus
			# Sounds must survive a paused tree for the same reason this node does.
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(player)
			pool.append(player)
		_voices[bus] = pool
		_next_voice[bus] = 0


# --- Public surface ----------------------------------------------------------------------------

## Play a sound. Fire and forget — never awaited, never fails loudly, never blocks an economy path.
## A dropped sound must never drop a purchase (rule 3).
func play(event_id: StringName) -> void:
	_play_event(event_id, 1.0, false)


## Play a sound whose loudness reflects HOW BIG the moment was, where `intensity` is 0..1 and was
## computed from a RATIO by the caller (rule 2). Above the layer threshold a brighter sample is
## mixed in on top, so a large moment is more of the same sound rather than a different one.
func play_scaled(event_id: StringName, intensity: float) -> void:
	_play_event(event_id, clampf(intensity, 0.0, 1.0), true)


## Play the next note of the tap scale (plan §4.1). Every manual tap climbs one step; the climb
## decays back to the root after `audio_tap_scale_reset_seconds` of not tapping, and pins at the top
## of the range rather than running away.
##
## This is the "spam becomes music" payoff, and it is deliberately reachable ONLY from real taps —
## see the note on reset_tap_scale, and note that held auto-taps do not call this at all (Tim,
## 2026-08-08: a hold should hold one note, or holding would sound better than tapping).
func play_tap_note() -> void:
	if not _enabled:
		return
	var now := Time.get_ticks_msec()
	if now - _tap_last_ms > int(_tap_scale_reset_seconds * 1000.0):
		# A fresh burst restarts the FAST figure at its root, but leaves the slow window drift where
		# it was — so two bursts a minute apart do not sound like the same three seconds replayed.
		# Only an explicit reset_tap_scale (a tab change) puts everything back to the start.
		_tap_position = 0
	else:
		_tap_position += 1
		if _tap_position >= _tap_run_length():
			_tap_position = 0
			_tap_lap = (_tap_lap + 1) % maxi(1, _tap_window_travel() * 2)
	_tap_last_ms = now

	var semitones: int = TAP_SCALE_SEMITONES[_degree_at(_tap_position, _tap_lap)]
	# Equal temperament: each semitone is a factor of 2^(1/12).
	_play_event(&"tap_note", 1.0, false, pow(2.0, semitones / 12.0))


## How many taps one lap of the figure takes. Both ends are visited ONCE — the turn at the top does
## not sound the top note twice, nor does the turn at the bottom — so a lap is two passes across the
## window minus its two shared ends.
func _tap_run_length() -> int:
	return (TAP_WINDOW_SIZE - 1) * 2


## How many drift steps the window has before it runs out of scale above it.
func _tap_window_travel() -> int:
	return (TAP_SCALE_SEMITONES.size() - TAP_WINDOW_SIZE) / TAP_WINDOW_DRIFT


## Which scale degree this tap plays. TWO movements at once, one fast and one slow.
##
## THE FAST ONE, within a lap: up the window and back down. It used to climb and then STICK at the
## top note for as long as tapping continued, so a sustained run became one note hammered over and
## over (Tim, 2026-08-08: "it becomes a single highly repetitive sound").
##
## THE SLOW ONE, across laps: the window's starting degree advances by one each lap, and itself rises
## and falls across the scale. So the figure keeps its shape while the register it sits in wanders —
## which is what stops a long run from being a single fourteen-tap loop played forever (Tim: "I like
## the idea of rotating the starting degree each lap"). The window drifts one degree per ~14 taps and
## takes 14 laps to come home, so nothing repeats exactly for around two hundred taps.
##
## Rotating the WINDOW rather than the scale itself is deliberate: rotating a fixed pitch set wraps
## the top note round to the bottom mid-figure, which puts an octave leap in the middle of what
## should be a smooth rise. A sliding window transposes the whole shape instead, so every lap has the
## same clean contour in a different register.
func _degree_at(position: int, lap: int) -> int:
	var window_start := _ping_pong(lap, _tap_window_travel()) * TAP_WINDOW_DRIFT
	return window_start + _ping_pong(position, TAP_WINDOW_SIZE - 1)


## Fold `index` into a there-and-back walk over 0..top, so it rises, turns, falls, and turns again.
## Both ends appear once per cycle rather than twice, which is what keeps the turns from repeating a
## note — the exact thing that made the old capped version so repetitive.
func _ping_pong(index: int, top: int) -> int:
	if top <= 0:
		return 0
	var period := top * 2
	var position := posmod(index, period)
	return position if position <= top else period - position


## Drop the tap scale back to its root. Called when the player changes tabs — a scale that resumed
## mid-climb after you went and did something else reads as a bug rather than as a reward.
func reset_tap_scale() -> void:
	_tap_position = 0
	_tap_lap = 0
	# A sentinel far in the past, NOT 0. The clock is milliseconds since the engine started, so 0
	# means "at launch" — which in the first second of runtime still reads as RECENT, and the next
	# tap would climb instead of restarting at the root. Only visible in a test or in the first
	# moments of a session, but "0 means long ago" is the kind of assumption that is simply false.
	_tap_last_ms = -1_000_000


## Set one player-facing level, 0..1 linear. The SFX slider drives three buses (§1.2).
func set_bus_volume(bus: StringName, linear: float) -> void:
	if not _enabled:
		return
	var level := clampf(linear, 0.0, 1.0)
	_bus_levels[bus] = level
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	# linear_to_db(0) is -inf, which the server takes as silence; mute explicitly anyway so the
	# state is inspectable rather than implied by a float.
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


## Push the tunable timings in from TuningConfig. Called by Main once the config is known.
func apply_tuning(tuning: TuningConfig) -> void:
	if tuning == null:
		return
	_tap_scale_reset_seconds = tuning.audio_tap_scale_reset_seconds
	_presence_window_ms = tuning.audio_presence_window_ms
	_scaled_min_db = tuning.audio_scaled_min_db
	_layer_threshold = tuning.audio_layer_threshold


## True when the player has done something recently enough for the game to still be making noise on
## their behalf. Rule 1 in one place.
##
## NOTHING CONSULTS THIS YET. It is kept because Phase 2's idle fade (plan §3.3) is built on exactly
## this signal — fade the music out after a stretch of no interaction, bring it back on the next one —
## and because the tracking is two lines that would otherwise be rediscovered.
##
## A TRAP WORTH REMEMBERING if a sound is ever added that fires WITHOUT the player: presence is
## inferred from the bus, so such a sound would refresh the very window that permitted it and hold it
## open forever. That is precisely what the collect sound did before it was removed (Tim, 2026-08-08),
## and it is why every sound in the catalog today is a direct response to a press.
func player_is_present() -> bool:
	return Time.get_ticks_msec() - _last_interaction_ms <= int(_presence_window_ms)


# --- Internals ---------------------------------------------------------------------------------


func _play_event(event_id: StringName, intensity: float, scaled: bool, pitch := 1.0) -> void:
	if not _enabled:
		return
	var event: AudioEvent = _events.get(event_id)
	if event == null or event.stream == null:
		return

	# MUTED COSTS NOTHING (rule 4). Bail before touching a voice, a clock, or a cooldown table.
	if float(_bus_levels.get(event.bus, 1.0)) <= 0.0:
		return

	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(event_id, -100000)) < int(event.cooldown_ms):
		return
	_last_played_ms[event_id] = now

	# PRESENCE. SFX and UI are things the player did; ceremony and music happen TO them and must not
	# count. See player_is_present for why this inference is only safe while every sound is a direct
	# response to a press.
	if event.bus == BUS_SFX or event.bus == BUS_UI:
		_last_interaction_ms = now

	var volume_db := event.volume_db
	if scaled:
		volume_db += lerpf(_scaled_min_db, 0.0, intensity)

	var variance := event.pitch_variance
	if variance > 0.0:
		pitch *= randf_range(1.0 - variance, 1.0 + variance)

	_start(event.bus, event.stream, volume_db, pitch)

	# The brighter layer rides ON TOP of the base sample, never instead of it.
	if scaled and event.layer_stream != null and intensity >= _layer_threshold:
		var layer_amount := inverse_lerp(_layer_threshold, 1.0, intensity)
		_start(event.bus, event.layer_stream, volume_db + lerpf(_scaled_min_db, 0.0, layer_amount), pitch)


## Hand a stream to a voice on `bus`, stealing the oldest if the pool is busy.
##
## Stealing rather than queueing is deliberate: an unbounded queue is how an audio system becomes the
## frame-time problem, and a sound that arrives late is worse than one that never arrives — it lands
## after the thing it was describing.
func _start(bus: StringName, stream: AudioStream, volume_db: float, pitch: float) -> void:
	var pool: Array = _voices.get(bus, [])
	if pool.is_empty():
		return

	var chosen: AudioStreamPlayer = null
	for player in pool:
		if not (player as AudioStreamPlayer).playing:
			chosen = player
			break
	if chosen == null:
		var index: int = _next_voice[bus]
		chosen = pool[index]
		_next_voice[bus] = (index + 1) % pool.size()

	chosen.stream = stream
	chosen.volume_db = volume_db
	chosen.pitch_scale = pitch
	chosen.play()


## Silence on focus loss, restore on return (decision 8).
##
## The master bus is FADED, not muted-and-left: a crash or a missed FOCUS_IN with a muted bus leaves
## the game permanently silent with nothing a player could diagnose. A fade plus a boolean is
## recoverable; a stuck mute flag is not.
func _notification(what: int) -> void:
	if not _enabled:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_fade_master(0.0)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_fade_master(1.0)


func _fade_master(target_linear: float) -> void:
	var index := AudioServer.get_bus_index(BUS_MASTER)
	if index < 0:
		return
	var tween := create_tween()
	tween.tween_method(
		func(level: float) -> void:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001))),
		db_to_linear(AudioServer.get_bus_volume_db(index)),
		maxf(target_linear, 0.0001),
		FOCUS_FADE_SECONDS)
