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

## The tap scale (plan §4.1, decision 2 and 6). Semitone offsets of a C major pentatonic across an
## octave and a half. FIXED, deliberately not keyed to the current music track: the point is that a
## burst of tapping always sounds like the same tune, whatever era you are in.
const TAP_SCALE_SEMITONES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]

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

## Where the tap scale has climbed to, and when it last advanced.
var _tap_step := 0
var _tap_last_ms := 0

## The msec clock reading of the last thing the PLAYER did (an SFX or UI sound). Collect audio and
## the Phase 2 idle fade both key off this — it is the codified form of rule 1.
var _last_interaction_ms := 0

## Collect aggregation (plan §4.3). Payouts are summed over a short window and reported as ONE
## sound; the raw event fires dozens of times a second at deep tiers and a chime per payout is
## unshippable.
var _collect_accum := 0.0
var _collect_income_per_sec := 0.0
var _collect_window_opened_ms := 0
var _collect_last_played_ms := 0

## Tunable knobs, pushed in by Main from TuningConfig so audio timing is adjustable in the dev panel
## like everything else. Defaults here match TuningConfig's and keep Audio usable before any push.
var _tap_scale_reset_seconds := 1.0
var _collect_window_ms := 250.0
var _collect_min_interval_ms := 250.0
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
		_tap_step = 0
	else:
		_tap_step = mini(_tap_step + 1, TAP_SCALE_SEMITONES.size() - 1)
	_tap_last_ms = now

	var semitones: int = TAP_SCALE_SEMITONES[_tap_step]
	# Equal temperament: each semitone is a factor of 2^(1/12).
	_play_event(&"tap_note", 1.0, false, pow(2.0, semitones / 12.0))


## Drop the tap scale back to its root. Called when the player changes tabs — a scale that resumed
## mid-climb after you went and did something else reads as a bug rather than as a reward.
func reset_tap_scale() -> void:
	_tap_step = 0
	# A sentinel far in the past, NOT 0. The clock is milliseconds since the engine started, so 0
	# means "at launch" — which in the first second of runtime still reads as RECENT, and the next
	# tap would climb instead of restarting at the root. Only visible in a test or in the first
	# moments of a session, but "0 means long ago" is the kind of assumption that is simply false.
	_tap_last_ms = -1_000_000


## Report one cycle payout. NOT one sound per call — see _process for the aggregation, and §4.3 for
## why: at deep tiers this fires dozens of times a second.
##
## `income_per_sec` is what makes the result relative: the window is judged against what the player's
## current portfolio was already producing, so a burst sounds like a burst at every scale.
func note_collect(payout: float, income_per_sec: float) -> void:
	if not _enabled:
		return
	if _collect_accum <= 0.0:
		_collect_window_opened_ms = Time.get_ticks_msec()
	_collect_accum += payout
	_collect_income_per_sec = income_per_sec


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
	_collect_window_ms = tuning.audio_collect_window_ms
	_collect_min_interval_ms = tuning.audio_collect_min_interval_ms
	_presence_window_ms = tuning.audio_presence_window_ms
	_scaled_min_db = tuning.audio_scaled_min_db
	_layer_threshold = tuning.audio_layer_threshold


## True when the player has done something recently enough that the game should still be making
## noise on their behalf. This is rule 1 in one place: everything that fires WITHOUT the player —
## passive cycle collections, auto-purchases — asks this before making a sound.
func player_is_present() -> bool:
	return Time.get_ticks_msec() - _last_interaction_ms <= int(_presence_window_ms)


# --- Internals ---------------------------------------------------------------------------------

## Flush the aggregated collect window.
func _process(_delta: float) -> void:
	if not _enabled or _collect_accum <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _collect_window_opened_ms < int(_collect_window_ms):
		return

	var aggregate := _collect_accum
	var income_per_sec := _collect_income_per_sec
	_collect_accum = 0.0

	# SILENT WHEN UNATTENDED (rule 1). A property finishing its cycle while nobody is touching the
	# screen is the game running, not the player acting — and this is precisely what makes a full
	# soundtrack survivable: the music carries the idle state, SFX are reserved for presence.
	if not player_is_present():
		return
	if now - _collect_last_played_ms < int(_collect_min_interval_ms):
		return
	_collect_last_played_ms = now
	play_scaled(&"collect", _collect_intensity(aggregate, income_per_sec))


## How loud an aggregated collect should be, from a RATIO and never from a dollar figure (rule 2).
##
## The window is compared against what the portfolio produces on its own over the same span. Purely
## passive income lands at about 1.0 and sits at the floor; a rush pushing several properties through
## their cycles at once lands well above it. So the sound reports "faster than usual", which is the
## only thing about a payout the player can actually act on — and a $250 window at generation 1
## sounds exactly like a $4.2Sx window at generation 15, as it should.
func _collect_intensity(aggregate: float, income_per_sec: float) -> float:
	var expected := income_per_sec * (_collect_window_ms / 1000.0)
	if expected <= 0.0:
		return 0.0
	return clampf(inverse_lerp(1.0, 3.0, aggregate / expected), 0.0, 1.0)


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

	# PRESENCE. SFX and UI mean the player did something; ceremony and music happen TO them, so they
	# must not count, or a cutscene would keep the collect sounds alive by itself.
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
