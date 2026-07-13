class_name RushMomentumState

# Rush Momentum — the "pinch of active progression" (Tim 2026-07-12).
#
# The economy grows exponentially through reinvestment, and in an exponential loop a FLAT income
# multiplier (like a rush that just pays more) is only a one-time head start — it doesn't change how
# fast you actually clear an epoch. Rush Momentum is different: it CLIMBS as you keep rushing, so it
# lifts your income most in the LATE part of an epoch, right when you're pushing for the threshold.
# That nudges your effective growth rate, so an engaged rusher reaches the next civilization
# noticeably sooner than someone who leaves the phone on the counter.
#
# It stays a *pinch* (never an epoch-skip) by two bounds: a hard cap on the bonus, and a full reset
# at every First Contact — each epoch earns its own momentum from scratch, so it can't snowball
# across the run. Stop rushing and it bleeds away, so the reward is for SUSTAINED engagement.
#
# It is applied to PROPERTY income only (never the wage), exactly like the frenzy multiplier, and it
# is threaded into both the payout AND the displayed rate so the cash always matches the readout.

var tuning: TuningConfig

## Current momentum as a BONUS FRACTION of property income: 0.0 = no bonus, 0.6 = +60% income.
## Clamped to [0, tuning.rush_momentum_max_bonus].
var bonus: float = 0.0


func _init(p_tuning: TuningConfig) -> void:
	tuning = p_tuning


## Advance momentum by one tick. `rushing` is true if the player rushed at least once during this
## tick — momentum then climbs toward the cap; otherwise it bleeds toward zero. Both rates are
## per-second (see the TuningConfig knobs), so the behaviour is frame-rate independent.
func tick(delta: float, rushing: bool) -> void:
	if rushing:
		bonus = minf(bonus + tuning.rush_momentum_build_per_second * delta, tuning.rush_momentum_max_bonus)
	else:
		bonus = maxf(bonus - tuning.rush_momentum_bleed_per_second * delta, 0.0)


## The live property-income multiplier (1 + bonus). Multiplied into every property payout AND its
## displayed rate — the same way frenzy is — so collection can never drift from the readout.
func factor() -> float:
	return 1.0 + bonus


## Wipe momentum. Called on each First Contact so every epoch builds its own momentum fresh, which
## is what keeps the mechanic a per-epoch pinch instead of a run-long snowball.
func reset() -> void:
	bonus = 0.0
