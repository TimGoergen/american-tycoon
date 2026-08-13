class_name Haptics
extends RefCounted

const ActionTracer := preload("res://scripts/core/ActionTracer.gd")

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
## At 0.0 haptics are completely disabled.
static var scale: float = 1.0

## Minimum safe vibration pulse duration in milliseconds. Calling OS vibration drivers with
## micro-durations (< 15ms) can cause native driver crashes / segfaults on mobile hardware.
const MIN_SAFE_VIBRATION_MS := 15.0
const MAX_SAFE_VIBRATION_MS := 500.0


## Vibrate for `duration_ms`, scaled by the player's setting. Mobile only: desktop must stay silent.
static func pulse(duration_ms: float) -> void:
	ActionTracer.trace("HAPTICS", "pulse(%.1f ms), scale=%.2f" % [duration_ms, scale])
	if scale <= 0.01 or duration_ms <= 0.0:
		return
	var scaled := duration_ms * scale
	if scaled >= MIN_SAFE_VIBRATION_MS and OS.has_feature("mobile"):
		var ms := clampi(int(scaled), int(MIN_SAFE_VIBRATION_MS), int(MAX_SAFE_VIBRATION_MS))
		ActionTracer.trace("HAPTICS", "Calling Input.vibrate_handheld(%d ms)" % ms)
		Input.vibrate_handheld(ms)
