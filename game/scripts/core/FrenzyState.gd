class_name FrenzyState

# Frenzy meter (Spec §7): one bar, modes:
#
# FILLING   — taps and completed property cycles charge the meter; idle time decays it.
#             The player may pop at or above the pop floor.
# BURNING   — the bar itself is the timer: it drains at a constant rate and the
#             multiplier locked at pop applies to all income until it empties.
# AFTERBURN — optional post-burn decay tail (Residual Momentum): multiplier eases back
#             smoothly to 1.0 rather than dropping instantly.

enum Mode { FILLING, BURNING, AFTERBURN }

var tuning: TuningConfig
var mode: Mode = Mode.FILLING

## Meter charge in [0, 1]. While BURNING, this is the remaining burn fraction.
var meter: float = 0.0

## Multiplier locked in at pop; 1.0 whenever not burning or afterburning.
var locked_multiplier: float = 1.0

## Legacy upgrades scale the burn (set per-generation by DynastyState from the purchased upgrades;
## 1.0 = nothing bought). intensity_multiplier boosts the popped multiplier's BONUS (Killer Instinct);
## duration_multiplier lengthens the burn (Second Wind).
var intensity_multiplier: float = 1.0
var duration_multiplier: float = 1.0

## Market Buzz: frenzy charge generated per completed property cycle.
var cycle_charge_per_completion: float = 0.0

## Market Momentum: extra idle grace seconds and decay speed reduction.
var grace_bonus: float = 0.0
var decay_multiplier: float = 1.0

## Residual Momentum: duration in seconds of the post-burn afterburn decay tail.
var afterburn_duration: float = 0.0
var _afterburn_remaining: float = 0.0
var _afterburn_peak_multiplier: float = 1.0

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


## Register completed property cycle(s) (Market Buzz). Charges the meter while FILLING.
func on_cycle_completed(count: int = 1) -> void:
	if cycle_charge_per_completion <= 0.0 or count <= 0:
		return
	_seconds_since_tap = 0.0
	if mode == Mode.FILLING:
		meter = minf(meter + cycle_charge_per_completion * float(count), 1.0)


func tick(delta: float) -> void:
	match mode:
		Mode.FILLING:
			_seconds_since_tap += delta
			var effective_grace := tuning.frenzy_idle_grace + grace_bonus
			if _seconds_since_tap >= effective_grace:
				var decay_rate := tuning.frenzy_decay_per_second * decay_multiplier
				meter = maxf(meter - decay_rate * delta, 0.0)
		Mode.BURNING:
			# A full bar drains in frenzy_burn_duration seconds, so a 60% pop
			# burns for 60% of that — duration scales with charge by construction.
			# The Second Wind Legacy upgrade lengthens the burn (duration_multiplier).
			meter -= delta / (tuning.frenzy_burn_duration * duration_multiplier)
			if meter <= 0.0:
				meter = 0.0
				if afterburn_duration > 0.0:
					mode = Mode.AFTERBURN
					_afterburn_remaining = afterburn_duration
					_afterburn_peak_multiplier = locked_multiplier
				else:
					locked_multiplier = 1.0
					mode = Mode.FILLING
					_seconds_since_tap = 0.0
		Mode.AFTERBURN:
			_afterburn_remaining -= delta
			if _afterburn_remaining <= 0.0:
				_afterburn_remaining = 0.0
				locked_multiplier = 1.0
				mode = Mode.FILLING
				_seconds_since_tap = 0.0
			else:
				var frac := _afterburn_remaining / afterburn_duration
				locked_multiplier = 1.0 + (_afterburn_peak_multiplier - 1.0) * frac


## True while a popped frenzy is burning down or in afterburn.
func is_burning() -> bool:
	return mode == Mode.BURNING or mode == Mode.AFTERBURN


func can_pop() -> bool:
	return mode == Mode.FILLING and meter >= tuning.frenzy_pop_floor


## Lock the multiplier at the current charge and start the burn.
## The multiplier never decays mid-burn (Spec §7).
func pop() -> void:
	if not can_pop():
		return
	# The Killer Instinct Legacy upgrade scales the BONUS (the amount above 1×), so a full pop
	# pays 1 + (max-1)×intensity×charge — a bigger frenzy the more you've invested.
	locked_multiplier = 1.0 + (tuning.frenzy_max_multiplier - 1.0) * intensity_multiplier * meter
	mode = Mode.BURNING


## Current income multiplier: locked value while burning/afterburning, 1.0 otherwise.
func get_multiplier() -> float:
	return locked_multiplier

