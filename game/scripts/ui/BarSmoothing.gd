class_name BarSmoothing

# Exponential smoothing for progress-bar fills. Game logic updates at the fixed
# 10 Hz tick (Spec §2) while the screen renders at ~60 Hz, so a bar that copies the
# raw logic value each frame lurches forward in ~10 visible steps per second —
# jumpy and staccato. Easing the displayed value toward the true value every frame
# removes that staccato without misrepresenting the state: the bar simply glides to
# where the logic already is, and catches up within a fraction of a second.
#
# The property cycle bar does NOT use this — it predicts its own constant-velocity
# fill (see PropertyRow). This is for bars whose value is driven straight from
# tick-rate logic state: the frenzy meter and the wage promotion meter.


## Smoothing time constant in seconds: smaller tracks the true value more tightly
## (snappier), larger drifts more (floatier). ~0.09 s removes the 10 Hz stepping
## while still feeling responsive to a tap.
const RESPONSE_TIME := 0.09


## Move `current` one frame's worth toward `target` and return the new displayed
## value. Framerate-independent: the same RESPONSE_TIME produces the same motion at
## any frame rate because the step is derived from `delta`.
static func approach(current: float, target: float, delta: float) -> float:
	if delta <= 0.0:
		return current
	var alpha := 1.0 - exp(-delta / RESPONSE_TIME)
	return current + (target - current) * alpha
