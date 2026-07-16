class_name RushMomentumState

# Rush Overheat — the push-your-luck evolution of Rush Momentum (Tim 2026-07-15;
# design of record: Plans/Rush_Overheat.md).
#
# The original momentum meter (Tim 2026-07-12) rewarded SUSTAINED rushing: hold long enough and
# the bonus caps and sits there. The optimal play became "never release" — a grip test, not a
# decision. Overheat converts it into a rhythm that rewards ATTENTION: the property literally
# heats up as you rush (that's WHY its productivity rises), and pushing it too hot shuts it down.
#
# ONE scalar, NO timers. Heat IS the momentum meter, and it keeps climbing past the old cap
# (heat 1.0) while rush is held. Every tier is a heat RANGE, never a timed state:
#
#   Building   heat 0    → 1.0        bonus  0%  → +30%   (the old meter, unchanged feel)
#   Hot        heat 1.0  → critical    bonus +30% → +40%   (warning 1 — safe for its width)
#   Critical   heat crit → ceiling     bonus +40% → +55%   (warning 2 — you are now gambling)
#   OVERHEAT   heat hits the ceiling   bonus 0, rush disabled until fully cooled + re-armed
#
# The overheat ceiling is rolled SECRETLY PER EXCURSION (Tim: "the exact point of overheating
# should not be entirely predictable"): each time heat crosses 1.0 upward we roll a fresh ceiling
# uniformly in [ceiling_min, ceiling_max], so probing-and-memorizing one run's fuse teaches you
# nothing about the next. Guardrail: the roll range lives entirely INSIDE Critical, so the Hot
# band's promised width is always honored — the warning tiers stay trustworthy.
#
# Overheating is the severe outcome (Tim: "more severe than waiting for a full cooldown"):
# the bonus drops to 0, rushing is disabled, heat drains to zero at a separate locked-drain
# rate (the visibly draining bar IS the cooldown display), and then a short re-arm delay adds
# the extra sting before rushing re-enables. Releasing NORMALLY just bleeds heat back down
# through the bands — hysteresis for free, no timer to game with a micro-flick.
#
# During a frenzy BURN everything freezes — no heat gain, no bleed, no lockout drain, no re-arm
# countdown; the bonus holds at its entry depth. Players will ride Critical into a frenzy on
# purpose, and an overheat mid-frenzy would gut the press-to-release payoff (Item 5).
#
# bonus stays a pure function of heat, is applied to PROPERTY income only (never the wage), and
# is threaded into both the payout AND the displayed rate so the cash always matches the readout.
# A full reset at every First Contact keeps it a per-epoch pinch, not a run-long snowball.

enum Band { BUILDING, HOT, CRITICAL }

## Fired on UPWARD band crossings only (BUILDING→HOT, HOT→CRITICAL) — the UI shows a tier chip.
## Sliding back down through a band edge is silent (de-escalation needs no fanfare).
signal band_entered(band: Band)

## Heat hit this excursion's secretly rolled ceiling. The lockout begins now.
signal overheated

## The post-overheat re-arm delay just finished; rushing is available again.
signal rush_ready

var tuning: TuningConfig

## Current heat, in heat units where 1.0 = the old momentum cap = the Hot band's lower edge.
## Ranges 0 .. the rolled ceiling (at most tuning.rush_momentum_ceiling_max).
var heat: float = 0.0

## Current bonus as a FRACTION of property income (0.3 = +30%). Recomputed from heat every tick
## via the piecewise band mapping; forced to 0 for the whole overheat lockout.
var bonus: float = 0.0

## Rolls the per-excursion overheat ceiling. Public so the headless sim can seed it and get
## deterministic runs; the live game just uses its default random seed.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## This excursion's secret overheat ceiling. Rolled fresh each time heat crosses 1.0 upward;
## between excursions it rests at ceiling_max (unreachable without crossing 1.0 first, which
## re-rolls it — so the resting value can never actually decide an overheat).
var _ceiling: float = 0.0

## True from the overheat moment until rush_ready fires (covers both the drain and the re-arm).
var _locked_out: bool = false

## Seconds left in the post-drain re-arm delay. Only meaningful while _locked_out and the
## drain has finished (heat == 0); counts down to the rush_ready moment.
var _rearm_remaining: float = 0.0

## True only during the post-drain re-arm delay (the tail end of the lockout).
var _rearming: bool = false


func _init(p_tuning: TuningConfig) -> void:
	tuning = p_tuning
	_ceiling = p_tuning.rush_momentum_ceiling_max


## Advance the heat model by one tick. `rushing` is true if the player rushed within the grace
## window this tick; `frenzy_burning` is true while a frenzy burn is active. All rates are
## per-second (see the TuningConfig knobs), so the behaviour is frame-rate independent.
func tick(delta: float, rushing: bool, frenzy_burning: bool) -> void:
	# Frenzy burn = a TRUE freeze (Tim 2026-07-15): no gain, no bleed, no lockout drain, no
	# re-arm countdown. Heat and bonus both hold exactly where they were until the burn ends.
	if frenzy_burning:
		return

	if _locked_out:
		_tick_lockout(delta)
		return

	var band_before := current_band()
	if rushing:
		heat += tuning.rush_momentum_heat_build_per_second * delta
	else:
		heat = maxf(heat - tuning.rush_momentum_heat_bleed_per_second * delta, 0.0)

	# Entering Hot from below starts a new EXCURSION: roll this run's secret ceiling now, before
	# the overheat check, so a single large tick that jumps straight past 1.0 still gets a roll.
	var band_after := current_band()
	if band_before == Band.BUILDING and band_after >= Band.HOT:
		_ceiling = rng.randf_range(tuning.rush_momentum_ceiling_min, tuning.rush_momentum_ceiling_max)
		band_entered.emit(Band.HOT)
	if band_before <= Band.HOT and band_after == Band.CRITICAL:
		band_entered.emit(Band.CRITICAL)

	if heat >= _ceiling:
		_begin_overheat()
		return

	bonus = _bonus_for_heat(heat)


## The lockout half of the tick: drain heat to zero at the locked rate, then run the re-arm
## delay, then re-enable rushing. The `rushing` flag is deliberately ignored here — rush taps
## during a lockout are dead (GameState refuses the verbs too; this is the belt to that brace).
func _tick_lockout(delta: float) -> void:
	bonus = 0.0
	if not _rearming:
		heat = maxf(heat - tuning.rush_momentum_locked_drain_per_second * delta, 0.0)
		if heat <= 0.0:
			# Fully cooled — the extra-sting re-arm delay starts only now, so its length is
			# a constant feel knob rather than varying with how deep the overheat was.
			_rearming = true
			_rearm_remaining = tuning.rush_momentum_rearm_seconds
	else:
		_rearm_remaining -= delta
		if _rearm_remaining <= 0.0:
			_rearming = false
			_locked_out = false
			_rearm_remaining = 0.0
			rush_ready.emit()


## Heat reached the ceiling: kill the bonus, disable rushing, and start the locked drain.
func _begin_overheat() -> void:
	# Pin heat at the rolled ceiling so the bar starts its drain from the exact shutdown point
	# (a fast tick could otherwise overshoot past it).
	heat = _ceiling
	bonus = 0.0
	_locked_out = true
	_rearming = false
	overheated.emit()


## The band → bonus mapping: a pure, piecewise-LINEAR function of heat, so one variable drives
## payout, display, and danger state (the "cash always matches the readout" invariant).
## The Critical segment always spans up to ceiling_MAX — the mapping never depends on the secret
## rolled ceiling, so the displayed bonus can't leak where this excursion's fuse ends.
func _bonus_for_heat(current_heat: float) -> float:
	var hot_start := 1.0  # by definition of the heat unit (1.0 = the old cap)
	var critical_start := tuning.rush_momentum_critical_start
	var ceiling_max := tuning.rush_momentum_ceiling_max
	if current_heat <= hot_start:
		# Building: 0 → bonus_at_hot across [0, 1.0].
		return tuning.rush_momentum_bonus_at_hot * (current_heat / hot_start)
	if current_heat <= critical_start:
		# Hot: bonus_at_hot → bonus_at_critical across [1.0, critical_start].
		var hot_progress := (current_heat - hot_start) / (critical_start - hot_start)
		return lerpf(tuning.rush_momentum_bonus_at_hot, tuning.rush_momentum_bonus_at_critical, hot_progress)
	# Critical: bonus_at_critical → bonus_peak across [critical_start, ceiling_max].
	var critical_progress := clampf(
		(current_heat - critical_start) / (ceiling_max - critical_start), 0.0, 1.0)
	return lerpf(tuning.rush_momentum_bonus_at_critical, tuning.rush_momentum_bonus_peak, critical_progress)


## The live property-income multiplier (1 + bonus). Multiplied into every property payout AND its
## displayed rate — the same way frenzy is — so collection can never drift from the readout.
func factor() -> float:
	return 1.0 + bonus


## False from the overheat moment until rush_ready fires. GameState gates every rush verb on this.
func can_rush() -> bool:
	return not _locked_out


## True during the whole overheat lockout: the locked drain AND the re-arm delay.
func is_locked_out() -> bool:
	return _locked_out


## True only during the post-drain re-arm delay (the grayed-button tail of the lockout).
func is_rearming() -> bool:
	return _rearming


## Which warning tier the current heat sits in. Purely a heat-range lookup — bands are never
## timed states (the design's core rule).
func current_band() -> Band:
	if heat < 1.0:
		return Band.BUILDING
	if heat < tuning.rush_momentum_critical_start:
		return Band.HOT
	return Band.CRITICAL


## Wipe everything — heat, bonus, AND any in-progress lockout/re-arm. Called on each First
## Contact so every epoch builds its own momentum fresh, which is what keeps the mechanic a
## per-epoch pinch instead of a run-long snowball.
func reset() -> void:
	heat = 0.0
	bonus = 0.0
	_locked_out = false
	_rearming = false
	_rearm_remaining = 0.0
	_ceiling = tuning.rush_momentum_ceiling_max
