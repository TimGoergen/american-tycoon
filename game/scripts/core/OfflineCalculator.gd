class_name OfflineCalculator

# Closed-form offline earnings (Spec §§2, 6). The away period is never
# cycle-simulated: income is a single rate × time formula. Offline draws
# from staffed properties only, at reduced efficiency, up to the cap.
# All methods are static — no state lives here.


## What happened while the player was away — feeds the welcome-back screen.
class OfflineResult:
	## Wall-clock seconds away (negative clock jumps clamp to 0, Spec §2).
	var elapsed_seconds: float = 0.0

	## Seconds actually paid out (elapsed, capped at OFFLINE_CAP).
	var paid_seconds: float = 0.0

	## Dollars banked while away.
	var pile: float = 0.0


## Compute the offline pile for `elapsed_seconds` away. Pure — mutates nothing.
static func calculate(
		economy: EconomyState,
		tuning: TuningConfig,
		elapsed_seconds: float
) -> OfflineResult:
	var result := OfflineResult.new()
	result.elapsed_seconds = maxf(elapsed_seconds, 0.0)
	result.paid_seconds = minf(result.elapsed_seconds, tuning.offline_cap_seconds)

	var offline_rate := 0.0
	for prop in economy.properties:
		var p := prop as PropertyState
		if p.is_staffed:
			offline_rate += p.get_income_per_sec()

	result.pile = floorf(offline_rate * tuning.offline_efficiency * result.paid_seconds)
	return result


## Bank a computed pile into the economy and reset staffed cycles.
## Staffed in-flight cycle progress resets to 0 on resume — it was already
## paid for by the rate calculation (Spec §2). Unstaffed progress is frozen
## while away, so it is left untouched.
static func apply(economy: EconomyState, result: OfflineResult) -> void:
	# The offline pile is property income earned while away, so it counts toward
	# the lifetime-earned estate basis (award_earned, not award_cash).
	economy.award_earned(result.pile)
	for prop in economy.properties:
		var p := prop as PropertyState
		if p.is_staffed:
			p.cycle_progress = 0.0
			p.is_cycle_running = p.units_owned > 0
