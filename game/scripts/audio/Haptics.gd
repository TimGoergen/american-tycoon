class_name Haptics
extends RefCounted

# The project's ONE vibrate call site (Plans/Audio_System.md §6.3).
#
# It used to be MomentumBar._vibrate, and keeping it to a single site is exactly why the haptic
# durations could later be promoted from consts to tuning knobs without hunting through the codebase.
# The player-facing haptics slider is the second such change, so the wrapper moved here rather than
# gaining a second caller: MomentumBar._vibrate still exists and now simply delegates.
#
# A static class rather than an autoload because, unlike audio, this owns no nodes and no state that
# has to survive Main — just a scale factor, which the same push that sets the audio volumes sets
# here (Main, on load and on every slider change).


## The player's haptics setting: a 0..1 MULTIPLIER on every pulse duration, not a separate on/off.
##
## At 0.0 every duration falls under the `>= 1.0` guard below, so haptics turn off with no extra
## branch anywhere — the same property that lets a tuning knob at zero disable its own pulse. One
## rule, two ways of reaching it.
static var scale: float = 1.0


## Vibrate for `duration_ms`, scaled by the player's setting. Mobile only: desktop must stay silent.
## (Input.vibrate_handheld is a no-op on most desktops anyway, but the explicit guard documents the
## intent, keeps the platform check out of every caller, and costs nothing.)
static func pulse(duration_ms: float) -> void:
	var scaled := duration_ms * scale
	if scaled >= 1.0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(scaled))
