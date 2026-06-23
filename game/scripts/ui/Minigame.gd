class_name Minigame
extends Control

# Common contract for one prestige/transition minigame TYPE (GDD §5.5). The MinigameHost
# picks a type at random, fills the play area with it, runs it, and reads a normalized
# performance in [0,1] (0 = worst, 1 = best possible) which the host maps to the universal
# 0.5x .. 1.25x outcome multiplier. A type renders ONLY its own gameplay and reports
# performance — it does not own the countdown, the spectrum bar, the result screen, the
# skip/opt-out, or the multiplier math (the host owns all of that, identically for every
# type, so they all share one outcome model).

## Emit when the game finishes on its own (e.g. a fixed number of rounds). The host also
## ends on its countdown; whichever happens first wins, using the final performance.
signal completed(performance: float)

## Start play. The host calls this once, after adding this control to the play area.
func begin(tuning: TuningConfig) -> void:
	pass

## Current performance in [0,1]. The host reads it live for the spectrum bar, and as the
## final result when its countdown expires.
func get_performance() -> float:
	return 0.0

## True while the type is mid-animation; the host pauses its countdown so animation time
## isn't charged to the player. Most types never block.
func is_busy() -> bool:
	return false

## A short, human-readable name for this minigame type. The random prestige draw doesn't
## need it, but the Minigame Tuning review screen (Settings) lists every type by name so
## they can each be opened and tested. Override in each type.
func display_name() -> String:
	return "Minigame"
