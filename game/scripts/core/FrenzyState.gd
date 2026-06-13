class_name FrenzyState

# Frenzy meter (Spec §7): one bar, two modes.
#
# FILLING — taps charge the meter; idle time (after a grace period) decays it.
#           The player may pop at or above the pop floor.
# BURNING — the bar itself is the timer: it drains at a constant rate and the
#           multiplier locked at pop applies to all income until it empties.

enum Mode { FILLING, BURNING }

var tuning: TuningConfig
var mode: Mode = Mode.FILLING

## Meter charge in [0, 1]. While BURNING, this is the remaining burn fraction.
var meter: float = 0.0

## Multiplier locked in at pop; 1.0 whenever not burning.
var locked_multiplier: float = 1.0

var _seconds_since_tap: float = 0.0


func _init(p_tuning: TuningConfig) -> void:
	tuning = p_tuning


## Register a player tap (any verb). Charges the meter while FILLING;
## during a burn taps still perform their verbs but feed nothing (Spec §7).
## `fill_scale` discounts the charge for held-button auto-rushes (1.0 = a
## real tap; see TuningConfig.frenzy_fill_hold_factor).
func on_tap(fill_scale: float = 1.0) -> void:
	_seconds_since_tap = 0.0
	if mode == Mode.FILLING:
		meter = minf(meter + tuning.frenzy_fill_per_tap * fill_scale, 1.0)


func tick(delta: float) -> void:
	match mode:
		Mode.FILLING:
			_seconds_since_tap += delta
			if _seconds_since_tap >= tuning.frenzy_idle_grace:
				meter = maxf(meter - tuning.frenzy_decay_per_second * delta, 0.0)
		Mode.BURNING:
			# A full bar drains in frenzy_burn_duration seconds, so a 60% pop
			# burns for 60% of that — duration scales with charge by construction.
			meter -= delta / tuning.frenzy_burn_duration
			if meter <= 0.0:
				meter = 0.0
				locked_multiplier = 1.0
				mode = Mode.FILLING
				_seconds_since_tap = 0.0


func can_pop() -> bool:
	return mode == Mode.FILLING and meter >= tuning.frenzy_pop_floor


## Lock the multiplier at the current charge and start the burn.
## The multiplier never decays mid-burn (Spec §7).
func pop() -> void:
	if not can_pop():
		return
	locked_multiplier = 1.0 + (tuning.frenzy_max_multiplier - 1.0) * meter
	mode = Mode.BURNING


## Current income multiplier: locked value while burning, 1.0 otherwise.
func get_multiplier() -> float:
	return locked_multiplier
