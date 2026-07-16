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
# CRUISE CONTROL amendment (Tim 2026-07-16; design of record: Plans/Rush_Cruise_Control.md):
# holding rush is SAFE FOREVER by default. Without overdrive engaged, heat climbs normally but
# clamps at the CRUISE POINT — the heat where the bonus equals the cruise-bonus knob (+25%
# first-cut) — and no overheat is possible. The danger bands above are an OPT-IN gamble behind
# engage_overdrive() (the OVERDRIVE button): once engaged, everything behaves exactly as shipped.
# Overdrive is PER-EXCURSION — it disengages when the hold ends (and on overheat and reset), so
# the gamble is always a fresh choice, never a sticky mode you forgot you left on.
#
# During a frenzy BURN everything freezes — no heat gain, no bleed, no lockout drain, no re-arm
# countdown; the bonus holds at its entry depth. Players will ride Critical into a frenzy on
# purpose, and an overheat mid-frenzy would gut the press-to-release payoff (Item 5).
#
# bonus stays a pure function of heat, is applied to PROPERTY income only (never the wage), and
# is threaded into both the payout AND the displayed rate so the cash always matches the readout.
# A full reset at every First Contact keeps it a per-epoch pinch, not a run-long snowball.

enum Band { BUILDING, HOT, CRITICAL }

## Fired on UPWARD band crossings only (BUILDING→HOT, HOT→CRITICAL) — the UI reacts per band
## (currently only CRITICAL pops a tier chip; HOT is announced by the fill alone).
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

## Extra cruise-bonus points from the "Cooling Systems" Legacy upgrade, as an additive fraction
## (0.01 per level, so level 5 = 0.05). Pushed in by DynastyState._apply_upgrade_effects — an
## instance field, not a static, so a sim's throwaway dynasties can never leak a value across runs.
var legacy_cruise_bonus: float = 0.0

## Scale on the TOTAL overheat lockout time, from the "Rapid Restart" Legacy upgrade: 1.0 = the
## full punishment, 0.5 at max level = half. Applied by DIVIDING the locked drain rate by it AND
## MULTIPLYING the re-arm delay by it, so both halves of the lockout shrink together. Pushed in
## by DynastyState._apply_upgrade_effects, like legacy_cruise_bonus above.
var lockout_time_scale: float = 1.0

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

## True while the player has OPTED IN to the danger bands (the OVERDRIVE button). Per-excursion
## by design: cleared on a non-rushing tick, on overheat, and on reset (Plans/Rush_Cruise_Control.md).
var _overdrive_engaged: bool = false

## Whether the LAST tick counted as rushing — is_cruising() needs it so the UI can tell a live
## cruise hold apart from an idle bar without re-deriving the grace window itself.
var _was_rushing: bool = false


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

	_was_rushing = rushing
	# Overdrive is PER-EXCURSION (Plans/Rush_Cruise_Control.md): letting go of the rush hold
	# disengages it, so the next press always starts back in safe cruise mode — the gamble is a
	# fresh choice every time, never a sticky mode left on by accident.
	if not rushing:
		_overdrive_engaged = false

	# Rushing WITHOUT overdrive = cruising: heat clamps at the cruise point and no overheat is
	# possible. Everything below — the excursion roll, the band signals, the ceiling check —
	# belongs to the opt-in overdrive ride, so the cruise path skips it entirely.
	if rushing and not _overdrive_engaged:
		_tick_cruise(delta)
		return

	var band_before := current_band()
	if rushing:
		# Past the Hot edge the climb slows to the overdrive build rate, stretching the ride
		# through the danger bands into a real decision window (~5–8 s, Tim 2026-07-15)
		# without widening the bar's band geometry.
		var build_rate := tuning.rush_momentum_heat_build_per_second if heat < 1.0 \
			else tuning.rush_momentum_heat_build_hot_per_second
		heat += build_rate * delta
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


## The safe half of a rush hold (Plans/Rush_Cruise_Control.md): heat climbs normally but CLAMPS
## at the cruise point, and the bonus holds there indefinitely — no excursion roll, no overheat.
func _tick_cruise(delta: float) -> void:
	var clamp_heat := cruise_heat()
	if heat < clamp_heat:
		# The cruise point is at most heat 1.0 (the bonus cap is bonus_at_hot), so the climb here
		# always uses the base Building build rate — the old meter's exact feel.
		heat = minf(heat + tuning.rush_momentum_heat_build_per_second * delta, clamp_heat)
	else:
		# Re-pressed WITHOUT overdrive while still hot from an earlier overdrive ride: holding
		# must not sustain danger-band bonuses for free, so heat bleeds back DOWN to the cruise
		# point (at the normal cooling rate) instead of freezing wherever it was.
		heat = maxf(heat - tuning.rush_momentum_heat_bleed_per_second * delta, clamp_heat)
	bonus = _bonus_for_heat(heat)


## The lockout half of the tick: drain heat to zero at the locked rate, then run the re-arm
## delay, then re-enable rushing. The `rushing` flag is deliberately ignored here — rush taps
## during a lockout are dead (GameState refuses the verbs too; this is the belt to that brace).
func _tick_lockout(delta: float) -> void:
	bonus = 0.0
	if not _rearming:
		# Rapid Restart shortens the whole lockout by lockout_time_scale: DIVIDING the drain rate
		# by the scale makes the bar empty proportionally faster (half the scale = twice the rate
		# = half the drain time), the mirror of MULTIPLYING the re-arm delay below.
		heat = maxf(heat - tuning.rush_momentum_locked_drain_per_second / _safe_lockout_scale() * delta, 0.0)
		if heat <= 0.0:
			# Fully cooled — the extra-sting re-arm delay starts only now, so its length is
			# a constant feel knob rather than varying with how deep the overheat was.
			_rearming = true
			_rearm_remaining = tuning.rush_momentum_rearm_seconds * _safe_lockout_scale()
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
	# The gamble ended (badly) — the next rush hold after the lockout starts back in cruise mode.
	_overdrive_engaged = false
	overheated.emit()


## The lockout time scale, guarded so a bad value can never stall the drain (divide-by-zero)
## or flip it negative. The catalog's Rapid Restart cap (level 5 = 0.5) keeps the real range
## far above this floor; the clamp only protects against a corrupt or hand-poked value.
func _safe_lockout_scale() -> float:
	return clampf(lockout_time_scale, 0.05, 1.0)


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


## Opt in to the danger bands for THIS rush hold (the OVERDRIVE button). Releases the cruise
## clamp so heat resumes climbing through Hot and Critical exactly as shipped — secret rolled
## ceiling, overheat, lockout and all. A no-op during an overheat lockout (the button is dead).
func engage_overdrive() -> void:
	if _locked_out:
		return
	_overdrive_engaged = true


## True while the player has opted in to the danger bands this excursion.
func is_overdrive_engaged() -> bool:
	return _overdrive_engaged


## True while the player is holding a SAFE rush: the last tick counted as rushing, overdrive is
## not engaged, and no lockout is running. The UI's "CRUISE +25%" steady state keys off this.
func is_cruising() -> bool:
	return _was_rushing and not _overdrive_engaged and not _locked_out


## The sustainable bonus while cruising: the tuned base plus any Cooling Systems Legacy points,
## hard-capped at bonus_at_hot — cruise may re-earn the old always-on +30% cap but NEVER exceed
## it, so the Hot/Critical bonuses stay exclusive to riding overdrive (Tim 2026-07-16).
func effective_cruise_bonus() -> float:
	return minf(tuning.rush_momentum_cruise_bonus + legacy_cruise_bonus,
			tuning.rush_momentum_bonus_at_hot)


## The heat the cruise clamp holds at: the INVERSE of the Building band's linear bonus mapping
## at the effective cruise bonus (bonus_at_hot maps to heat 1.0, so cruise_bonus/bonus_at_hot
## maps back to its heat). Derived from the existing knobs, not a new band edge, so the band
## geometry stays exactly as tuned in Plans/Rush_Overheat.md.
func cruise_heat() -> float:
	return effective_cruise_bonus() / tuning.rush_momentum_bonus_at_hot


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
	# Building is INCLUSIVE of heat 1.0 (Plans/Rush_Cruise_Control.md boundary rule): with max
	# Cooling Systems the cruise clamp sits at exactly 1.0, and parking there must not read as
	# Hot or start an excursion — an excursion begins only when overdrive pushes heat PAST the
	# tick. tick()'s excursion roll keys off this band crossing, so the rule lives here once.
	if heat <= 1.0:
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
	_overdrive_engaged = false
	_was_rushing = false
	_ceiling = tuning.rush_momentum_ceiling_max
