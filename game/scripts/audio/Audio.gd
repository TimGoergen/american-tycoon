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

# --- WHERE SOUNDS COME FROM -------------------------------------------------------------------
#
# BY CONVENTION, NOT BY CONFIGURATION. A cue named `tab_switch` plays whatever is at
# `res://audio/cues/tab_switch.ogg` (or `.wav`), and that is the whole rule — there is no manifest to
# edit and no id that can drift from its file. Dropping a sourced sample in with the right name is
# the entire integration step.
#
# This replaced a `config/audio_events.tres` catalog on 2026-08-09. The plan asked for the data to
# live outside GDScript so samples could be swapped without code changes (§1.4); a filename lookup
# achieves that better, because it also removes the second place a sound could be described.
#
# Three folders, by ROLE rather than by bus — what a sound IS predicts where it lives better than
# which fader it happens to sit on:
const CUES_DIR := "res://audio/cues/"        # one-shots: everything that fires and finishes
const LOOPS_DIR := "res://audio/loops/"      # continuous layers held for as long as a state lasts
# (music tracks live in MUSIC_DIR, named per era band — see MUSIC_BAND_FILES)

## How many numbered variants a cue may have. `tap_note.wav` alone is fine; add `tap_note_1.wav` …
## `tap_note_4.wav` and the game picks one at random per play, which is the cheapest way to stop a
## frequently-heard sample from wearing a groove. Probed by NAME rather than by scanning the folder:
## directory listings inside an exported PCK are a class of bug this project has already paid for
## once (raw .svg reads, 2026-08-05), and a fixed set of candidate names cannot have that problem.
const MAX_VARIANTS := 4

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_CEREMONY := &"Ceremony"


# --- THE CUE TABLE ------------------------------------------------------------------------------
#
# Every sound the game can make, and what it means. This is the ONE place a cue is defined: its id
# is its filename, and the row below is everything else about it.
#
# Columns:
#   bus       — which fader it answers to. SFX and UI also mark the player as PRESENT (see
#               player_is_present); Ceremony and Music deliberately do not, because those beats
#               happen TO the player rather than being something they did.
#   db        — trim relative to the bus. Set in isolation for now; the mix pass balances them.
#   cooldown  — ignore a repeat inside this many ms. Guards against one frame firing a cue twice.
#   variance  — random pitch spread, ±fraction. MUST be 0 for anything the game pitches on purpose.
#   layered   — the cue has a `_layer` companion sample mixed in above it at high intensity.
#
# A cue with NO FILE is silent and harmless: _resolve_stream returns null and play() returns. That is
# what lets this table describe the whole design while the samples arrive one at a time.
const CUES := {
	# --- The core loop ---------------------------------------------------------------------------
	&"tap_note":         {"bus": BUS_SFX, "db": -6.0, "cooldown": 45.0, "variance": 0.0},
	&"buy_success":      {"bus": BUS_SFX, "db": -3.0, "cooldown": 60.0, "variance": 0.0, "layered": true},
	&"hire_first":       {"bus": BUS_SFX, "db": -3.0, "cooldown": 60.0, "variance": 0.0},
	&"hire_levelled":    {"bus": BUS_SFX, "db": -7.0, "cooldown": 60.0, "variance": 0.04},
	&"retain_staff":     {"bus": BUS_SFX, "db": -6.0, "cooldown": 60.0, "variance": 0.03},
	&"milestone":        {"bus": BUS_SFX, "db": -2.0, "cooldown": 200.0, "variance": 0.0},
	&"cycle_started":    {"bus": BUS_SFX, "db": -12.0, "cooldown": 60.0, "variance": 0.05},
	&"frenzy_pop":       {"bus": BUS_SFX, "db": -2.0, "cooldown": 300.0, "variance": 0.0},
	&"frenzy_end":       {"bus": BUS_SFX, "db": -10.0, "cooldown": 300.0, "variance": 0.0},

	# --- Rush and overdrive ----------------------------------------------------------------------
	&"overdrive_engage": {"bus": BUS_SFX, "db": -3.0, "cooldown": 200.0, "variance": 0.0},
	&"vent_tick":        {"bus": BUS_SFX, "db": -12.0, "cooldown": 10.0, "variance": 0.0},
	&"vent_open":        {"bus": BUS_SFX, "db": -1.0, "cooldown": 100.0, "variance": 0.0},
	&"vent_lift":        {"bus": BUS_SFX, "db": -6.0, "cooldown": 10.0, "variance": 0.0},
	&"vent_success":     {"bus": BUS_SFX, "db": -2.0, "cooldown": 100.0, "variance": 0.0, "layered": true},
	&"vent_miss":        {"bus": BUS_SFX, "db": -4.0, "cooldown": 100.0, "variance": 0.0},
	&"overheat":         {"bus": BUS_SFX, "db": -2.0, "cooldown": 200.0, "variance": 0.0},
	&"rush_ready":       {"bus": BUS_SFX, "db": -8.0, "cooldown": 100.0, "variance": 0.0},

	# --- UI (decision 15: tabs and major actions only) --------------------------------------------
	&"tab_switch":       {"bus": BUS_UI, "db": -10.0, "cooldown": 60.0, "variance": 0.03},
	&"screen_open":      {"bus": BUS_UI, "db": -9.0, "cooldown": 100.0, "variance": 0.0},
	&"screen_close":     {"bus": BUS_UI, "db": -11.0, "cooldown": 100.0, "variance": 0.0},
	&"mode_toggle":      {"bus": BUS_UI, "db": -12.0, "cooldown": 50.0, "variance": 0.04},
	&"epoch_page":       {"bus": BUS_UI, "db": -12.0, "cooldown": 50.0, "variance": 0.03},
	&"make_contact":     {"bus": BUS_UI, "db": -1.0, "cooldown": 400.0, "variance": 0.0},
	&"tip_appear":       {"bus": BUS_UI, "db": -12.0, "cooldown": 200.0, "variance": 0.0},

	# --- Denials (plan §4.5, deferred by decision 15 — hooks exist, samples deliberately absent) ---
	# Registered so the moments are named and reachable. Ship a file only if the game turns out to
	# need it: most denials never reach code at all, because the button is already disabled and a
	# disabled Godot button emits nothing.
	&"denied_cash":      {"bus": BUS_UI, "db": -10.0, "cooldown": 250.0, "variance": 0.0},
	&"denied_locked":    {"bus": BUS_UI, "db": -10.0, "cooldown": 250.0, "variance": 0.0},

	# --- Challenge Mode ---------------------------------------------------------------------------
	&"challenge_start":  {"bus": BUS_UI, "db": -6.0, "cooldown": 200.0, "variance": 0.0},
	&"challenge_credit": {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 400.0, "variance": 0.0},
	&"challenge_tier":   {"bus": BUS_CEREMONY, "db": -3.0, "cooldown": 400.0, "variance": 0.0},

	# --- Ceremony: the story beats -----------------------------------------------------------------
	&"ceremony_obituary":       {"bus": BUS_CEREMONY, "db": -3.0, "cooldown": 800.0, "variance": 0.0},
	&"ceremony_will":           {"bus": BUS_CEREMONY, "db": -6.0, "cooldown": 800.0, "variance": 0.0},
	&"ceremony_heir":           {"bus": BUS_CEREMONY, "db": -2.0, "cooldown": 800.0, "variance": 0.0},
	&"ceremony_contact":        {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 800.0, "variance": 0.0},
	&"ceremony_contact_reveal": {"bus": BUS_CEREMONY, "db": -2.0, "cooldown": 800.0, "variance": 0.0},
	&"legacy_purchase":         {"bus": BUS_CEREMONY, "db": -6.0, "cooldown": 300.0, "variance": 0.0},
	&"welcome_back":            {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 800.0, "variance": 0.0},
	&"prestige_confirm":        {"bus": BUS_CEREMONY, "db": -2.0, "cooldown": 800.0, "variance": 0.0},

	# --- Minigames, shared beats ------------------------------------------------------------------
	# The SHARED layer only: every game has a start, a clock, a score, a miss and an ending, and those
	# are worth getting right before any game's own vocabulary (a swish, a match, a caught coin) is
	# written. The per-game cues are a separate pass.
	&"minigame_begin":     {"bus": BUS_UI, "db": -4.0, "cooldown": 200.0, "variance": 0.0},
	&"minigame_score":     {"bus": BUS_SFX, "db": -8.0, "cooldown": 40.0, "variance": 0.05},
	&"minigame_miss":      {"bus": BUS_SFX, "db": -7.0, "cooldown": 80.0, "variance": 0.03},
	&"minigame_countdown": {"bus": BUS_UI, "db": -9.0, "cooldown": 250.0, "variance": 0.0},
	&"minigame_best":      {"bus": BUS_CEREMONY, "db": -3.0, "cooldown": 500.0, "variance": 0.0},
	&"minigame_over":      {"bus": BUS_UI, "db": -4.0, "cooldown": 500.0, "variance": 0.0},

	# --- Basketball -------------------------------------------------------------------------------
	# The first game to get its own vocabulary. These LAYER over the shared beats rather than
	# replacing them (Tim, 2026-08-09): minigame_score still says "that counted", and these say what
	# the object did — the net, the rim, the ball. It keeps six games recognisably one game.
	#
	# The bounces carry pitch variance and want VARIANTS most of all: one shot can bounce a dozen
	# times, each quieter than the last, and a single unvaried sample would be the most fatiguing
	# thing in the build.
	&"bball_grab":        {"bus": BUS_SFX, "db": -16.0, "cooldown": 60.0, "variance": 0.05},
	&"bball_launch":      {"bus": BUS_SFX, "db": -6.0, "cooldown": 60.0, "variance": 0.04},
	&"bball_fizzle":      {"bus": BUS_SFX, "db": -14.0, "cooldown": 80.0, "variance": 0.05},
	&"bball_wall":        {"bus": BUS_SFX, "db": -12.0, "cooldown": 40.0, "variance": 0.09},
	&"bball_floor":       {"bus": BUS_SFX, "db": -11.0, "cooldown": 40.0, "variance": 0.09},
	&"bball_settle":      {"bus": BUS_SFX, "db": -18.0, "cooldown": 120.0, "variance": 0.06},
	&"bball_rim":         {"bus": BUS_SFX, "db": -8.0, "cooldown": 50.0, "variance": 0.06},
	&"bball_score":       {"bus": BUS_SFX, "db": -5.0, "cooldown": 120.0, "variance": 0.0},
	&"bball_swish":       {"bus": BUS_SFX, "db": -3.0, "cooldown": 120.0, "variance": 0.0},
	&"bball_gem_through": {"bus": BUS_SFX, "db": -8.0, "cooldown": 120.0, "variance": 0.0},
	&"bball_gem_earned":  {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 400.0, "variance": 0.0},

	# --- Match Three ------------------------------------------------------------------------------
	# The richest vocabulary of the six, and the one where the CASCADE is the whole feeling: a swap
	# that keeps paying is what the game is for, so the match cue rises in pitch with each step of a
	# chain (see MatchThreeMinigame._animate_step) rather than repeating flat.
	&"m3_select":   {"bus": BUS_SFX, "db": -16.0, "cooldown": 50.0, "variance": 0.05},
	&"m3_swap":     {"bus": BUS_SFX, "db": -11.0, "cooldown": 60.0, "variance": 0.04},
	&"m3_invalid":  {"bus": BUS_SFX, "db": -10.0, "cooldown": 80.0, "variance": 0.03},
	&"m3_match":    {"bus": BUS_SFX, "db": -6.0, "cooldown": 30.0, "variance": 0.0},
	&"m3_fall":     {"bus": BUS_SFX, "db": -15.0, "cooldown": 40.0, "variance": 0.08},
	&"m3_avoid":    {"bus": BUS_SFX, "db": -5.0, "cooldown": 150.0, "variance": 0.0},
	&"m3_legacy":   {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 300.0, "variance": 0.0},

	# --- Catch Money ------------------------------------------------------------------------------
	# The busiest game of the six: coins spawn every 0.6s and a good player catches nearly all of
	# them, so the ordinary catch is the single most-repeated sound in the build. It is the quietest
	# and shortest thing here, and it carries the most variants.
	&"catch_coin":    {"bus": BUS_SFX, "db": -10.0, "cooldown": 25.0, "variance": 0.07},
	&"catch_premium": {"bus": BUS_SFX, "db": -5.0, "cooldown": 60.0, "variance": 0.03},
	&"catch_legacy":  {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 300.0, "variance": 0.0},
	&"catch_miss":    {"bus": BUS_SFX, "db": -12.0, "cooldown": 60.0, "variance": 0.06},
	&"catch_spawn":   {"bus": BUS_SFX, "db": -22.0, "cooldown": 25.0, "variance": 0.10},

	# --- Memory -----------------------------------------------------------------------------------
	# A memory game's sounds CARRY INFORMATION rather than decorate: each pad has its own pitch, so
	# the sequence is a little tune and the player can rehearse it by ear. That is the whole design —
	# one cue, pitched per pad, exactly like the tap scale.
	&"mem_pad":     {"bus": BUS_SFX, "db": -7.0, "cooldown": 20.0, "variance": 0.0},
	&"mem_round":   {"bus": BUS_SFX, "db": -4.0, "cooldown": 200.0, "variance": 0.0},
	&"mem_wrong":   {"bus": BUS_SFX, "db": -3.0, "cooldown": 200.0, "variance": 0.0},
	&"mem_gem":     {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 300.0, "variance": 0.0},

	# --- Balance ----------------------------------------------------------------------------------
	# The only game with no discrete input: the player holds, and the beam drifts. So its sounds are
	# about CROSSING — entering and leaving the zone — because that is the only moment anything
	# actually changes.
	&"bal_enter":   {"bus": BUS_SFX, "db": -9.0, "cooldown": 150.0, "variance": 0.0},
	&"bal_leave":   {"bus": BUS_SFX, "db": -11.0, "cooldown": 150.0, "variance": 0.0},
	&"bal_lift":    {"bus": BUS_SFX, "db": -16.0, "cooldown": 80.0, "variance": 0.05},
	&"bal_gem":     {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 300.0, "variance": 0.0},

	# --- Timing Bar -------------------------------------------------------------------------------
	&"time_lock_hit":  {"bus": BUS_SFX, "db": -5.0, "cooldown": 80.0, "variance": 0.0},
	&"time_lock_miss": {"bus": BUS_SFX, "db": -8.0, "cooldown": 80.0, "variance": 0.04},
	&"time_gem":       {"bus": BUS_CEREMONY, "db": -4.0, "cooldown": 300.0, "variance": 0.0},

	# --- Settings previews (played when a slider is released) --------------------------------------
	&"music_preview":    {"bus": BUS_MUSIC, "db": -4.0, "cooldown": 200.0, "variance": 0.0},
}

## Cues that are deliberately NEVER played, listed so the decision is visible where the table is.
##
##   auto_purchase — the Acquisitions Desk buys without the player, and rule 1 says unattended events
##                   stay silent. It cannot even reach a hook: the desk buys inside AutoPurchaseState,
##                   in core, which never touches this layer. Silent by construction.
##   cycle_payout  — a cycle completing was built, heard, and removed (Tim, 2026-08-09: "only when
##                   the user taps to purchase").
const DELIBERATELY_SILENT := [&"auto_purchase", &"cycle_payout"]

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

# --- Music (plan §3) ---------------------------------------------------------------------------

## Where the era tracks live, and what each band is called. ONE FILE PER BAND, named for the band —
## dropping a new track in is a file copy, not a code change, which is the point (§7.2: the
## architecture must not care whether the tracks are commissioned or library).
##
## `.ogg` is preferred and tried first; a `.wav` of the same name is the fallback, which is how the
## generated placeholders work until real tracks arrive.
const MUSIC_DIR := "res://audio/music/"
const MUSIC_BAND_FILES := [
	"band_0_blue_collar",
	"band_1_white_collar",
	"band_2_early_contact",
	"band_3_mid",
	"band_4_deep",
]

## Which band an epoch tier belongs to (§3.2). Aligned to the ECONOMY's own bands, so the music
## changes character exactly where the maths does — free coherence, and one place to change it.
##
## A pure function on purpose: tier thresholds must not be scattered.
static func band_for_tier(tier: int) -> int:
	if tier <= 1:
		return 0        # Blue Collar
	if tier == 2:
		return 1        # White Collar
	if tier <= 11:
		return 2        # early contact
	if tier <= 19:
		return 3        # mid
	return 4            # deep


## Seconds to cross from one band to the next. Long enough to read as a dissolve rather than a cut.
const MUSIC_CROSSFADE_SECONDS := 2.0
## How long the idle fade takes out and back in (§3.3). Out is slow — the music should seem to drift
## away rather than be switched off; back in is quicker, because the player has just acted.
const MUSIC_IDLE_FADE_OUT_SECONDS := 4.0
const MUSIC_IDLE_FADE_IN_SECONDS := 1.5
## How far the music drops while a rush is on (§5.3), so the overdrive bed sits on top of it.
const MUSIC_DUCK_DB := -4.0
## Ceiling for the music players themselves. The Music BUS carries the player's slider; this is the
## mix trim underneath it.
const MUSIC_VOLUME_DB := -6.0

# --- The overdrive layer (plan §5.1, decision 9) ---------------------------------------------

## The two continuous streams a ride is made of, held as their own players rather than borrowed from
## a pool: they start once, run for the whole ride, and are never stolen mid-ride by a tap sound.
const HEAT_LOOP_NAME := "heat_loop"
const URGENCY_LOOP_NAME := "urgency_loop"

## How far the drone rises from cold to the top of the band, in semitones. About a fifth: enough that
## the ear tracks the climb without the tone becoming a whistle at the ceiling.
const HEAT_PITCH_SEMITONES := 7.0

## Where in the band the urgency layer starts fading in. The top quarter, so the approach to overheat
## is audible BEFORE it is visible — which is the one thing this layer exists to do.
const URGENCY_ENTERS_AT := 0.75

## Loudness of each layer at full. Both sit well under the one-shots: this is a bed, and a bed that
## competes with the cues would bury the vent window, which is the sound that actually matters.
const HEAT_VOLUME_DB := -14.0
const URGENCY_VOLUME_DB := -16.0

## How long the layers take to arrive and to leave. Fading rather than cutting, because a drone that
## snaps on is a click and a drone that snaps off sounds like a crash.
const HEAT_FADE_IN_SECONDS := 0.25
const HEAT_FADE_OUT_SECONDS := 0.45

## Fade applied to the master bus when the app loses focus (plan §3.4). Short enough to be gone
## before the app is backgrounded, long enough not to click.
const FOCUS_FADE_SECONDS := 0.2


# --- State -------------------------------------------------------------------------------------

## bus name → its pool of players.
var _voices: Dictionary = {}
## bus name → the index to steal next. Advancing this round-robin IS the steal-oldest policy: the
## least recently started voice on a bus is always the one furthest around the ring.
var _next_voice: Dictionary = {}

## cue id → its samples (one, or several if variants exist). Resolved once at boot.
var _events: Dictionary = {}
## cue id → the optional `_layer` sample mixed in above it at high intensity.
var _layers: Dictionary = {}

## event id → the msec clock reading when it last played, for per-event cooldowns.
var _last_played_ms: Dictionary = {}

## bus name → the player's linear 0..1 level. Held here as well as on the AudioServer so a muted
## check costs a Dictionary read rather than a dB conversion.
var _bus_levels: Dictionary = {}

## False when there is no usable audio at all — a headless sim run. Every public method turns into a
## cheap return, so the gates need no audio stubs (plan §0.4 rule 4).
var _enabled := true

## Two music players so a band change can cross between them; `_music_active` says which one is
## playing the current band.
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
## Per-player gain, 0..1, walked toward its target every frame. Plain numbers rather than tweens:
## the idle fade, the crossfade and the duck all move the same volume, and three tweens fighting over
## one property is how audio mixers develop a mind of their own.
var _music_gain: Array[float] = [0.0, 0.0]
## The band currently playing, or -1 for none.
var _music_band := -1
## The idle envelope (§3.3): 1 while the player is around, 0 once they have gone quiet.
var _music_idle_gain := 1.0
## Set false to silence music entirely (the player's slider is separate — this is the system's own
## on/off, used when no track exists for a band).
var _music_wanted := false
## True while a modal takeover owns the screen — a minigame. Separate from `_music_wanted` because it
## is a different question: the soundtrack is still WANTED, it is just not welcome right now.
var _music_suppressed := false

## The overdrive bed: two dedicated players and the gain envelope that owns their volume. No tween —
## see set_heat_active for why.
var _heat_player: AudioStreamPlayer
var _urgency_player: AudioStreamPlayer
var _heat_active := false
var _heat_gain := 0.0
## Last normalized heat pushed in, so the pitch/urgency mix can be recomputed when the layer starts.
var _heat_normalized := 0.0

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
	_build_heat_layer()
	_build_music_players()
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


## Find every cue's sample by NAME and remember what it resolved to. Done once at boot: the probing
## is cheap but it is not free, and a cue that fires forty times a second must not pay for it.
##
## A cue with no file is recorded as null and simply never sounds. That is the normal state while
## samples are being sourced one at a time, and it is why the table can describe the whole design
## before any of it has been recorded.
func _load_catalog() -> void:
	var missing: Array[String] = []
	for id in CUES:
		var variants := _resolve_variants(id)
		_events[id] = variants
		if variants.is_empty():
			missing.append(String(id))
		var layer_id := String(id) + "_layer"
		var layer := _resolve_stream(CUES_DIR + layer_id)
		if layer != null:
			_layers[id] = layer
	if not missing.is_empty():
		# Not a warning per cue — a half-populated cue folder is expected, and one line is the
		# difference between a useful note and a wall the reader learns to scroll past.
		print("Audio: %d of %d cues have no sample yet (%s)"
			% [missing.size(), CUES.size(), ", ".join(missing)])


## Every sample registered for a cue: the plain name first, then any numbered variants. Returns an
## empty array when the cue has no file at all.
func _resolve_variants(id: StringName) -> Array[AudioStream]:
	var found: Array[AudioStream] = []
	var plain := _resolve_stream(CUES_DIR + String(id))
	if plain != null:
		found.append(plain)
	for index in range(1, MAX_VARIANTS + 1):
		var variant := _resolve_stream(CUES_DIR + "%s_%d" % [id, index])
		if variant != null:
			found.append(variant)
	return found


## Load `path_without_extension` as .ogg if it exists, else .wav, else null.
##
## .ogg FIRST so a sourced track always wins over a generated placeholder of the same name — that is
## what makes replacing a sound a pure file drop, with no cleanup step and no chance of the old one
## lingering because someone forgot to delete it.
func _resolve_stream(path_without_extension: String) -> AudioStream:
	for extension in [".ogg", ".wav"]:
		var path: String = path_without_extension + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null


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


## Build the two continuous overdrive streams. Allocated once at boot like everything else, and
## started only when a ride begins.
func _build_heat_layer() -> void:
	_heat_player = _make_loop_player(LOOPS_DIR + HEAT_LOOP_NAME)
	_urgency_player = _make_loop_player(LOOPS_DIR + URGENCY_LOOP_NAME)


func _make_loop_player(path_without_extension: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := _resolve_stream(path_without_extension)
	if stream == null:
		push_warning("Audio: no loop at %s.(ogg|wav); that layer will stay silent." % path_without_extension)
		player.bus = BUS_MUSIC
		add_child(player)
		return player
	# LOOPING IS SET HERE, not in the .import file. Two reasons, and the second is the important one:
	# the WAV importer's loop setting did not survive a re-import, and `*.import` is gitignored in
	# this repo (the audio ones are force-added), so a setting held only there is one clean checkout
	# away from reverting to the default. A drone that stops looping fails SILENTLY — the bed just
	# ends a second into every ride — which is the worst way for a setting to go missing.
	#
	# The samples are generated with a whole number of wave cycles precisely so this seam is
	# inaudible (see seamless_loop in tools/generate_placeholder_audio.py).
	player.stream = _apply_loop(stream)
	# The MUSIC bus, not SFX (plan §5.3). A player who turned music off is saying they want the game
	# quiet, and a continuous drone is the least quiet thing here — it must obey that slider.
	player.bus = BUS_MUSIC
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = -60.0
	add_child(player)
	return player


## Two identical players, allocated at boot like everything else.
func _build_music_players() -> void:
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_MUSIC
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -60.0
		add_child(player)
		_music_players.append(player)


## Load a band's track, or null if there is none. Tries .ogg then .wav, so a real track dropped in
## beside a placeholder simply wins.
##
## A MISSING TRACK IS NOT AN ERROR. The game must run silent-but-correct with no music at all — that
## is how it shipped for its whole life until now, and a half-populated audio/music/ directory is the
## normal state while tracks are being auditioned one at a time.
func _load_band_track(band: int) -> AudioStream:
	if band < 0 or band >= MUSIC_BAND_FILES.size():
		return null
	for extension in [".ogg", ".wav"]:
		var path: String = MUSIC_DIR + MUSIC_BAND_FILES[band] + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null


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


## Play a sound at a deliberate pitch, where the pitch itself carries meaning — the vent-lift
## confirmation steps up one whole tone per lift, so the player hears progress toward the
## requirement. `pitch` is a ratio: 2^(semitones/12).
##
## Separate from play() rather than an optional argument, because a caller reaching for this is
## making a musical decision and should have to say so.
func play_pitched(event_id: StringName, pitch: float) -> void:
	_play_event(event_id, 1.0, false, pitch)


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


## Track the ride's heat, 0..1 across the band the BAR is showing (plan §5.1).
##
## Takes the normalized value rather than computing it, because there is no stored normal form — the
## view derives it, and it means different things in different modes (heat/cruise while building,
## heat/ceiling in overdrive). Recomputing it here would let the tone and the bar disagree, and the
## project's invariant that what the bar shows IS what the player gets. The sound has to be part
## of that promise, not a second opinion on it.
func set_heat(normalized: float) -> void:
	if not _enabled or _heat_player == null:
		return
	var safe_norm := clampf(normalized, 0.0, 1.0)
	if is_nan(safe_norm) or is_inf(safe_norm):
		safe_norm = 0.0
	_heat_normalized = safe_norm
	var pitch := pow(2.0, (_heat_normalized * HEAT_PITCH_SEMITONES) / 12.0)
	if is_nan(pitch) or is_inf(pitch) or pitch <= 0.0:
		pitch = 1.0
	_heat_player.pitch_scale = pitch


## Start or stop the ride's bed. Just a flag — the mix in _process does the rest.
##
## IT USED TO DO THE WORK HERE, killing and rebuilding a fade tween on every change and calling
## stop()/play() on two streaming players at the edges. That was fine in principle and dangerous in
## practice: the caller polls `is_cruising()` every frame, and heat hovering at the cruise clamp makes
## that answer flicker — so a busy moment could churn a tween and a stream restart sixty times a
## second on the audio thread. Tim's game closed outright while rushing and buying at the same time
## (2026-08-09), which is the heaviest such moment the game has.
##
## Now the flag is free to flicker: the gain walks toward it a frame at a time, so a state that
## changes its mind costs a few milliseconds of fade and nothing else.
func set_heat_active(active: bool) -> void:
	_heat_active = active


## Walk the bed's gain toward its target and resolve both layers' volumes. Everything about the bed
## that can change lives here, once per frame, so nothing can race anything else.
func _mix_heat_bed(delta: float) -> void:
	if _heat_player == null or _urgency_player == null:
		return
	var rate := 1.0 / (HEAT_FADE_IN_SECONDS if _heat_active else HEAT_FADE_OUT_SECONDS)
	_heat_gain = move_toward(_heat_gain, 1.0 if _heat_active else 0.0, delta * rate)

	if _heat_gain <= 0.001:
		# Fully out: stop, so a stopped stream decodes nothing. A ride is off far more than it is on.
		if _heat_player.playing:
			_heat_player.stop()
		if _urgency_player.playing:
			_urgency_player.stop()
		return

	if not _heat_player.playing and _heat_player.stream != null:
		_safe_play(_heat_player)

	var safe_gain := maxf(_heat_gain, 0.0001)
	_heat_player.volume_db = HEAT_VOLUME_DB + linear_to_db(safe_gain)

	var urgency_db := _urgency_db_for(_heat_normalized)
	_urgency_player.volume_db = urgency_db + linear_to_db(safe_gain)
	if urgency_db > -59.0:
		if not _urgency_player.playing and _urgency_player.stream != null:
			_safe_play(_urgency_player)
	elif _urgency_player.playing:
		_urgency_player.stop()


## The urgency layer's level at a given heat: silent until the top of the band, then up to full.
func _urgency_db_for(normalized: float) -> float:
	if normalized < URGENCY_ENTERS_AT:
		return -60.0
	var amount := inverse_lerp(URGENCY_ENTERS_AT, 1.0, normalized)
	return lerpf(-60.0, URGENCY_VOLUME_DB, clampf(amount, 0.0, 1.0))


## Play the track for `band`, crossfading from whatever is playing. A no-op if that band is already
## on, so callers can assert the current band every time the epoch changes without tracking edges.
##
## Callers must not invoke this DURING a ceremony (§3.1): a band change that lands under the First
## Contact overlay puts a new track's first bar beneath that beat's own sting and ruins both. Main
## calls it when the overlay dismisses instead.
func set_music_band(band: int) -> void:
	if not _enabled or band == _music_band:
		return

	var track := _load_band_track(band)
	if track == null:
		# No track for this band yet. Leave whatever is playing rather than cutting to silence: a
		# partially-populated music directory should degrade to "the old track keeps going", not to
		# a hole in the soundtrack.
		push_warning("Audio: no track for music band %d; leaving the current one playing." % band)
		return

	_music_band = band
	_music_wanted = true
	# The idle envelope must not carry over from a fade-out in progress, or a band change during a
	# quiet spell would start the new track already vanishing.
	_music_idle_gain = 1.0

	var next := 1 - _music_active
	var player := _music_players[next]
	player.stream = _apply_loop(track)
	player.play()
	_music_active = next


## Take the soundtrack out entirely for a modal takeover, and put it back afterwards.
##
## A MINIGAME IS NOT A PLACE FOR THE SOUNDTRACK (Tim, 2026-08-09: "remove soundtrack entirely during
## minigame modal"). It owns the whole screen, has its own pace, and its own sounds are fast and
## small — an era track playing underneath would fight all three. Ducking would only make the fight
## quieter; this removes it.
##
## Deliberately NOT stop_music(): the band is remembered, so returning restores the same track rather
## than deciding a new one, and no band-change logic runs on the way back.
func set_music_suppressed(suppressed: bool) -> void:
	_music_suppressed = suppressed


## Stop the music entirely (used by a caller that wants silence — not by the idle fade, which keeps
## the system armed).
func stop_music() -> void:
	_music_wanted = false
	_music_band = -1


## Make a music stream loop. Same reasoning as the overdrive bed: a track that stops after one pass
## fails silently, and the import setting for it lives in a gitignored file.
func _apply_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	return stream


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

## Drive the music mix every frame: crossfade, idle fade and duck, all resolved into one volume per
## player. THREE THINGS MOVE THE SAME NUMBER, which is exactly why they are computed together here
## rather than as three tweens racing each other for the property.
func _process(_delta_unused: float) -> void:
	if not _enabled or _music_players.is_empty():
		return
	var delta := get_process_delta_time()

	# IDLE (§3.3). The music carries the quiet, but not forever: after a long silence it drifts out,
	# and the next thing the player does brings it back. An active ride never counts as idle —
	# going quiet mid-rush because the player is HOLDING rather than tapping would be a bug that
	# feels like a bug.
	var present := player_is_present() or _heat_active
	var idle_rate := 1.0 / (MUSIC_IDLE_FADE_IN_SECONDS if present else MUSIC_IDLE_FADE_OUT_SECONDS)
	_music_idle_gain = move_toward(_music_idle_gain, 1.0 if present else 0.0, delta * idle_rate)

	_mix_heat_bed(delta)

	# DUCK (§5.3): the overdrive bed rides the same bus, so the music steps back under it. Keyed on
	# the GAIN rather than the flag, so the duck follows the bed in and out instead of snapping.
	var duck_db := MUSIC_DUCK_DB * _heat_gain

	var crossfade_rate := 1.0 / MUSIC_CROSSFADE_SECONDS
	for i in range(_music_players.size()):
		var player := _music_players[i]
		# A suppressed soundtrack targets silence on EVERY player, so a modal that opens mid-crossfade
		# takes both of them out rather than leaving the outgoing track audible underneath.
		var wanted := _music_wanted and not _music_suppressed
		var target := 1.0 if (i == _music_active and wanted) else 0.0
		_music_gain[i] = move_toward(_music_gain[i], target, delta * crossfade_rate)

		var level := _music_gain[i] * _music_idle_gain
		if level <= 0.001:
			# STOP rather than idle at silence. A stopped stream decodes nothing, and between the
			# idle fade and the crossfade one of these two is silent almost all the time.
			if player.playing:
				player.stop()
			continue
		if not player.playing and wanted:
			_safe_play(player)
		player.volume_db = MUSIC_VOLUME_DB + linear_to_db(level) + duck_db


func _play_event(event_id: StringName, intensity: float, scaled: bool, pitch := 1.0) -> void:
	if not _enabled:
		return
	var definition: Dictionary = CUES.get(event_id, {})
	if definition.is_empty():
		# An id with no row in the table is a typo, not a missing sample, and it would otherwise fail
		# by being silent — the hardest kind of bug to notice in an audio system.
		push_warning("Audio: no cue named '%s'" % event_id)
		return

	var samples: Array = _events.get(event_id, [])
	if samples.is_empty():
		return      # described but not yet recorded; silence is the correct behaviour

	var bus: StringName = definition["bus"]
	# MUTED COSTS NOTHING (rule 4). Bail before touching a voice, a clock, or a cooldown table.
	if float(_bus_levels.get(bus, 1.0)) <= 0.0:
		return

	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(event_id, -100000)) < int(definition["cooldown"]):
		return
	_last_played_ms[event_id] = now

	# PRESENCE. SFX and UI are things the player did; ceremony and music happen TO them and must not
	# count. See player_is_present for why this inference is only safe while every sound is a direct
	# response to a press.
	if bus == BUS_SFX or bus == BUS_UI:
		_last_interaction_ms = now

	var volume_db: float = definition["db"]
	if scaled:
		volume_db += lerpf(_scaled_min_db, 0.0, intensity)

	var variance: float = definition.get("variance", 0.0)
	if variance > 0.0:
		pitch *= randf_range(1.0 - variance, 1.0 + variance)

	# One of the cue's variants, at random. With a single sample this is simply that sample.
	_start(bus, samples[randi() % samples.size()], volume_db, pitch)

	# The brighter layer rides ON TOP of the base sample, never instead of it.
	var layer: AudioStream = _layers.get(event_id)
	if scaled and layer != null and intensity >= _layer_threshold:
		var layer_amount := inverse_lerp(_layer_threshold, 1.0, intensity)
		_start(bus, layer, volume_db + lerpf(_scaled_min_db, 0.0, layer_amount), pitch)


## Hand a stream to a voice on `bus`, stealing the oldest if the pool is busy.
##
## Stealing rather than queueing is deliberate: an unbounded queue is how an audio system becomes the
## frame-time problem, and a sound that arrives late is worse than one that never arrives — it lands
## after the thing it was describing.
func _start(bus: StringName, stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
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

	# STOP BEFORE REUSING. Assigning `stream` to a playing player is documented as stopping it, but
	# doing it explicitly makes the order unambiguous on the audio thread — this is the path taken
	# dozens of times a second when rushing and buying at once, which is when the game was closing.
	if chosen.playing:
		chosen.stop()
	chosen.stream = stream
	chosen.volume_db = clampf(volume_db, -120.0, 24.0)
	var safe_pitch := pitch
	if is_nan(safe_pitch) or is_inf(safe_pitch) or safe_pitch <= 0.0:
		safe_pitch = 1.0
	chosen.pitch_scale = safe_pitch
	_safe_play(chosen)


func _safe_play(player: AudioStreamPlayer) -> void:
	if player == null or not _enabled:
		return
	if OS.has_feature("mobile"):
		# Avoid stacking deferred play calls on a player that is already scheduled or actively playing
		if not player.playing:
			player.call_deferred(&"play")
	else:
		player.play()


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
