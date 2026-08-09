class_name AudioEvent
extends Resource

# One playable sound, described as DATA rather than as code (Plans/Audio_System.md §1.4).
#
# The point of this class is that "which file plays for buy_success, how loud, on which bus" lives in
# game/config/audio_events.tres, editable in the inspector. Phase 1 ships synthesized placeholder
# samples on purpose; replacing them with sourced ones must be a resource edit, not a code change,
# because that swap will happen many times while auditioning library packs.

## The name the game calls this sound by — `Audio.play(&"buy_success")`. Must be unique in a catalog.
@export var id: StringName = &""

## The sample. WAV, loaded fully into memory at import (streaming a 200 ms blip means a disk seek in
## the tap path, which is exactly the battery cost the plan's hard constraint asks us to avoid).
@export var stream: AudioStream

## An OPTIONAL brighter sample mixed in ABOVE `stream` when an intensity-scaled call is loud enough.
## It layers, never replaces: the event keeps one identity and simply gets more of itself. Intensity
## drives volume and layering but NEVER pitch — pitch belongs to the tap scale, and two systems
## pitching the same voice would fight.
@export var layer_stream: AudioStream

## Which bus this plays on. Also decides whether the sound counts as the player being PRESENT: see
## Audio.play (SFX and UI do, Music and Ceremony do not).
@export var bus: StringName = &"SFX"

## Trim for this event alone, relative to its bus.
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0

## Ignore repeat requests for this event within this many milliseconds. Guards against a single
## frame firing the same sound several times, which reads as a click rather than as emphasis.
@export_range(0.0, 2000.0, 5.0) var cooldown_ms: float = 40.0

## Whether hearing this sound means THE PLAYER DID SOMETHING.
##
## Almost every sound does — they are responses to a press. `collect` does not: it is the game
## reporting its own automated payouts, and it is the reason this flag exists.
##
## Presence was originally inferred from the bus alone (SFX and UI count, Music and Ceremony do not).
## That looked right and was quietly circular: collect plays on the SFX bus, so each collect sound
## refreshed the presence window that had allowed it, and the window never closed again. One purchase
## and every staffed property blipped at the end of every cycle forever (Tim, 2026-08-08). Rule 1 says
## unattended events stay silent — so an unattended event must not be able to vote on whether the
## player is here.
@export var counts_as_presence: bool = true

## Random pitch spread, ±this fraction, applied per play. A tiny amount stops a rapidly repeated
## sound from turning into a machine-gun drone. MUST stay 0 for anything the tap scale pitches —
## random detune on top of a musical interval is just out of tune.
@export_range(0.0, 0.5, 0.01) var pitch_variance: float = 0.0
