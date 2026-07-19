class_name RushMomentumState

# Rush Overheat — the push-your-luck evolution of Rush Momentum (Tim 2026-07-15;
# design of record: Plans/Rush_Overheat.md), now with VENT WINDOWS (Tim 2026-07-17;
# design of record: Plans/Overdrive_Vent_Windows.md).
#
# The original momentum meter (Tim 2026-07-12) rewarded SUSTAINED rushing: hold long enough and
# the bonus caps and sits there. The optimal play became "never release" — a grip test, not a
# decision. Overheat converts it into a rhythm that rewards ATTENTION: the property literally
# heats up as you rush (that's WHY its productivity rises), and pushing it too hot shuts it down.
#
# ONE scalar, NO wall-clock timers. Heat IS the momentum meter, and it keeps climbing past the
# old cap (heat 1.0) while rush is held. The model has exactly TWO regions, never timed states
# (the Hot/Critical sub-bands were retired by the depth-hazard rework, Tim 2026-07-18 evening):
#
#   BUILDING   heat 0   → 1.0 incl.   bonus  0%  → +30%   (the old meter, unchanged feel)
#   OVERDRIVE  heat 1.0 → ceiling     bonus +30% → the LADDER PEAK, one continuous lerp
#   OVERHEAT   heat hits the ceiling, bonus 0, rush disabled until fully cooled + re-armed
#              OR a vent window is missed
#
# VENT WINDOWS (Plans/Overdrive_Vent_Windows.md) replaced the old secretly rolled per-excursion
# ceiling with a chain of telegraphed skill checks, and the DEPTH-HAZARD rework (Tim 2026-07-18
# evening) made their arrival a function of how hard you are pushing: while overdrive is engaged
# and heat sits past the cruise point, every tick rolls a window-open chance whose rate
# interpolates with DEPTH into the overdrive span — rare checks hovering shallow, relentless
# checks riding just under the backstop. Where you sit on that curve is partly your call
# (venting drops heat), so the intensity is player-authored. When a check comes it does NOT
# open instantly — the APPROACH PHASE (Tim 2026-07-19) puts the event IN FLIGHT first:
# `vent_incoming` fires the tick the hazard roll lands (the UI shows the event as a bright red
# bar traveling in from the right edge), and the window itself OPENS vent_approach_seconds of
# tick time later, when the event reaches the target — the player SEES IT COMING. The demanded
# lifts are decided AT SPAWN and announced with the approach, so the player commits based on
# what they saw coming; one event is in flight at a time (hazard rolls are suppressed while one
# is approaching or open). Each resolved vent — and each fresh overdrive engage — also starts a
# rolled REFRACTORY (Tim 2026-07-18 night: post-vent arrivals felt near-metronomic): a quiet
# spell of vent_refractory_min..max seconds during which neither the dice nor the force-spawn
# may fire, so the gap to the next event varies run to run. Releasing the hold / disengaging /
# overheating / resetting
# cancels an in-flight approach silently — the event never arrived, so there is no miss. Once
# the window opens the player must perform the vent gesture on the rushed property's button
# before it closes:
#
#   VENT    (1 lift):  release → re-press, gap ≤ vent_gap_max. One clean feather.
#   VENT ×2 (2 lifts): release → tap (press ≤ vent_tap_max, then release) → re-press,
#                      every gap ≤ vent_gap_max. Tim's "two separate lifts" pump gesture.
#
#   Success: a chunk of heat vents (never below the cruise point — success never ends the
#            ride), the climb resumes, and the bonus tier ratchets up one rung — the reward
#            for surviving the check.
#   Miss (window expires, gap too long, tap held too long): OVERHEAT, exactly as if the ceiling
#            had been hit — every overheat is now one the player caused by missing a read.
#
# Tim's 2026-07-15 "the exact overheat point should not be entirely predictable" is still
# honored, but the unpredictability moved from the OUTCOME to the SCHEDULE: `rng` rolls the
# per-tick hazard, so you never know exactly when the check comes — but once it telegraphs,
# the outcome is entirely in your hands. A fixed, visible HARD CEILING remains purely as the
# "you ignored everything" backstop, and a window is FORCE-OPENED (full duration still ahead)
# before heat could ever reach it — see the telegraph guarantee in _tick_vent_windows.
#
# The reward ladder is ENDLESS (Tim 2026-07-18, superseding the old 4-tier cap): the overdrive
# span's peak (reached at the hard ceiling) starts at bonus_peak (+55%) and each successful
# vent adds vent_bonus_step, with NO cap. The DIFFICULTY CURVE replaces the cap as the run's
# ending — per tier, the window duration decays geometrically (vent_duration_decay, floored at
# vent_duration_floor) and the demanded lifts step up 1 → 2 → 3 (one more every
# vent_lifts_step_tiers tiers, hard-capped at MAX_VENT_LIFTS). The old per-tier CADENCE decay
# is retired: depth is the cadence axis now — a small vent_heat_drop means long runs
# inevitably ride deeper, so faster checks fall out of the hazard curve naturally.
# Even perfect-looking play compounds away eventually — every overdrive run ends in flames,
# and the question is how high you got. The first vent stays approachable regardless.
#
# Overheating is the severe outcome (Tim: "more severe than waiting for a full cooldown"):
# the bonus drops to 0, rushing is disabled, heat drains to zero at a separate locked-drain
# rate (the visibly draining bar IS the cooldown display), and then a short re-arm delay adds
# the extra sting before rushing re-enables. Falling from higher hurts more: the re-arm gains
# vent_fail_rearm_per_tier extra seconds per vent tier achieved this excursion — but the sting
# is capped at vent_fail_rearm_cap, because on the endless ladder the failure pressure must
# come from the difficulty curve, not ever-longer timeouts (Tim 2026-07-18). Releasing
# NORMALLY just bleeds heat back down through the bands — and ends the excursion, clearing the
# vent ladder and any pending window (the gamble is always a fresh choice, and bailing out
# with the cash already banked is the endless ladder's legitimate cash-out move).
#
# CRUISE CONTROL amendment (Tim 2026-07-16; design of record: Plans/Rush_Cruise_Control.md):
# holding rush is SAFE FOREVER by default. Without overdrive engaged, heat climbs normally but
# clamps at the CRUISE POINT — the heat where the bonus equals the cruise-bonus knob (+25%
# first-cut) — and no overheat is possible. The danger zone above is an OPT-IN gamble behind
# engage_overdrive() (the OVERDRIVE button): once engaged, everything behaves as described.
# Overdrive is PER-EXCURSION — it disengages when the hold ends (and on overheat and reset).
#
# During a frenzy BURN everything freezes — no heat gain, no bleed, no lockout drain, no re-arm
# countdown, no hazard rolls, and no open-window countdown. Everything here advances on tick
# delta ONLY (never OS time), so the freeze is total and a window can never unfairly open or
# expire mid-frenzy.
#
# bonus stays a pure function of (heat, vent tier), is applied to PROPERTY income only (never
# the wage), and is threaded into both the payout AND the displayed rate so the cash always
# matches the readout. A full reset at every First Contact keeps it a per-epoch pinch.

## The two heat regions (the depth-hazard rework retired HOT and CRITICAL): BUILDING is the old
## momentum meter (heat ≤ 1.0, INCLUSIVE — the cruise-clamp boundary rule), OVERDRIVE is
## everything above it, one continuous danger zone up to the hard ceiling.
enum Band { BUILDING, OVERDRIVE }

## Where the vent-gesture judge is within the current OPEN window. Never a timed state on its
## own — the phase only changes on press/release edges, and the tick merely polices how long
## the current phase has lasted against the gap/tap tolerances. The same three phases judge
## every gesture length: an N-lift gesture is just N trips through GAP, with a TAP between
## each pair (release → [tap →] ... → re-hold).
enum VentPhase {
	WAITING_FOR_LIFT,  # finger down; the gesture starts with its first release
	GAP,               # finger up; must re-press within vent_gap_max
	TAP,               # finger down on an intermediate tap; must release within vent_tap_max
}

## The most lifts a window can ever demand, no matter how deep the tier: a quad-pump is thumb
## mush (Tim 2026-07-18), so past ×3 the cadence and duration axes carry the difficulty alone.
## The UI's pip display renders up to this many beats — raising it is a UI change too.
const MAX_VENT_LIFTS := 3

## Safety cushion (seconds of overdrive build) folded into the telegraph guarantee's fit bound.
## The force-spawn is noticed on a tick boundary, so it can overshoot the bound by up to one
## tick of build; without a cushion that overshoot would let heat touch the hard ceiling on an
## open window's LAST tick — an overheat mid-gesture, exactly what the guarantee forbids.
## Two 10 Hz ticks of build is plenty and costs the rider under 2% of the bar's depth.
## (The retired delay-based scheduler used the vent_delay_floor knob as this cushion.)
const GUARANTEE_CUSHION_SECONDS := 0.2

## Fired on the UPWARD heat-1.0 crossing only (BUILDING → OVERDRIVE) — the single region edge
## left. Sliding back down through it is silent (de-escalation needs no fanfare).
signal band_entered(band: Band)

## A vent event just SPAWNED (the hazard roll — or the telegraph guarantee — fired this tick):
## the window itself opens after `approach_seconds` of tick time, and will demand exactly
## `required_lifts` when it does. The UI's incoming event bar starts its travel on this signal.
signal vent_incoming(approach_seconds: float, required_lifts: int)

## A vent window just OPENED: the player has `duration` seconds to perform the gesture
## (`required_lifts` is 1 for the single feather, 2 for the double release).
signal vent_window_opened(required_lifts: int, duration: float)

## One lift beat of the gesture just landed (the re-press completed it) — the UI's pip display.
signal vent_lift_registered(lifts_done: int, required_lifts: int)

## The gesture completed in time: heat vented, and the bonus ladder ratcheted to `new_tier`
## (its peak — the bonus at the hard ceiling — is now `new_peak_bonus`).
signal vent_succeeded(new_tier: int, new_peak_bonus: float)

## The window was blown (expired, gap too long, or tap held too long). Fired just BEFORE
## `overheated`, carrying how far through the gesture the player got — miss-feedback must show
## WHICH beat was blown, or the skill is unlearnable (Plans/Overdrive_Vent_Windows.md).
signal vent_missed(lifts_done: int, required_lifts: int)

## Heat hit the hard ceiling, or a vent window was missed. The lockout begins now.
signal overheated

## The post-overheat re-arm delay just finished; rushing is available again.
signal rush_ready

var tuning: TuningConfig

## Current heat, in heat units where 1.0 = the old momentum cap = the OVERDRIVE region's edge.
## Ranges 0 .. tuning.rush_momentum_hard_ceiling.
var heat: float = 0.0

## Current bonus as a FRACTION of property income (0.3 = +30%). Recomputed from (heat, vent
## tier) every tick via the piecewise band mapping; forced to 0 for the whole overheat lockout.
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

## Rolls the per-tick vent-window hazard (the schedule is the unpredictable part now — the old
## random ceiling is retired). Public so the headless sim can seed it and get deterministic
## runs; the live game just uses its default random seed.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## True from the overheat moment until rush_ready fires (covers both the drain and the re-arm).
var _locked_out: bool = false

## Seconds left in the post-drain re-arm delay. Only meaningful while _locked_out and the
## drain has finished (heat == 0); counts down to the rush_ready moment.
var _rearm_remaining: float = 0.0

## The re-arm delay's FULL length, captured the moment it starts. The total varies per lockout
## (the per-tier sting and the Rapid Restart scale both move it), so the UI's re-arm timer
## cannot re-derive it from knobs — rearm_remaining_fraction() needs the real divisor.
var _rearm_total: float = 0.0

## True only during the post-drain re-arm delay (the tail end of the lockout).
var _rearming: bool = false

## The per-tier re-arm sting earned by the excursion that just overheated. Captured at the
## overheat moment (before the vent ladder is cleared) because the re-arm delay is not computed
## until the drain finishes, by which time the tier is gone.
var _rearm_tier_sting: float = 0.0

## True while the player has OPTED IN to the danger zone (the OVERDRIVE button). Per-excursion
## by design: cleared on a non-rushing tick, on overheat, and on reset (Plans/Rush_Cruise_Control.md).
var _overdrive_engaged: bool = false

## Whether the LAST tick counted as rushing — is_cruising() needs it so the UI can tell a live
## cruise hold apart from an idle bar without re-deriving the grace window itself.
var _was_rushing: bool = false

# --- Vent-window state (all cleared on overheat, reset, and release-disengage) ---

## Successful vents THIS excursion — UNBOUNDED (the endless ladder). Each tier raises the
## overdrive span's peak bonus by vent_bonus_step (see current_peak_bonus()) and escalates
## the next window's duration and demanded lifts. (Cadence escalates via DEPTH, not tier —
## see _tick_vent_windows.)
var _vent_tier: int = 0

## Tick-time seconds of post-vent (or post-engage) QUIET left before the next event may spawn —
## the rolled REFRACTORY (Tim 2026-07-18 night). While positive, hazard dice AND the force-spawn
## hold their fire, so back-to-back events can never land metronomically. Rolled on the seeded
## schedule rng in _start_refractory; ticks down on tick delta only (frenzy-frozen like every
## other vent clock); cleared with the rest of the vent state.
var _refractory_remaining: float = 0.0

## True while a spawned vent event is IN FLIGHT: `vent_incoming` has fired but the window has
## not opened yet (the UI's red event bar is still traveling toward the target). Hazard rolls
## are suppressed for the whole flight — one event in flight (or open) at a time.
var _approaching: bool = false

## Tick-time seconds until the in-flight event reaches the target and its window opens. The UI
## derives the event bar's position from remaining / vent_approach_seconds. Stale when idle.
var _approach_remaining: float = 0.0

## Lifts the in-flight event announced at spawn. LOCKED here, never re-derived at open: the
## window must demand exactly what vent_incoming told the player, because they commit to the
## check based on what they saw coming. (The tier cannot change mid-flight anyway — only a
## success moves it, and no window is open — but locking the value makes the promise explicit.)
var _approach_required_lifts: int = 1

## True while a vent window is OPEN (the gesture clock is running).
var _window_open: bool = false

## Seconds left in the open window. The gesture must COMPLETE before this hits zero.
var _window_remaining: float = 0.0

## Lifts the open window demands: 1 (single feather) .. MAX_VENT_LIFTS. Stale when closed.
var _window_required_lifts: int = 1

## Completed lift beats so far in the open window's gesture.
var _window_lifts_done: int = 0

## The gesture judge's phase within the open window (see VentPhase).
var _vent_phase: VentPhase = VentPhase.WAITING_FOR_LIFT

## Seconds spent in the current gesture phase. Reset on every press/release edge; the tick
## checks it against vent_gap_max / vent_tap_max so tolerances share the game's tick clock
## (never OS time — the frenzy freeze must stop gesture clocks too).
var _phase_elapsed: float = 0.0

## Whether the rushed property's button is currently held, tracked from the press/release
## edges GameState forwards. Needed so a window that opens mid-hold starts the judge in
## WAITING_FOR_LIFT, while one that opens with the finger already up starts in GAP.
var _button_pressed: bool = false


func _init(p_tuning: TuningConfig) -> void:
	tuning = p_tuning


## Advance the heat model by one tick. `rushing` is true if the player rushed within the grace
## window this tick; `frenzy_burning` is true while a frenzy burn is active. All rates are
## per-second (see the TuningConfig knobs), so the behaviour is frame-rate independent.
func tick(delta: float, rushing: bool, frenzy_burning: bool) -> void:
	# Frenzy burn = a TRUE freeze (Tim 2026-07-15): no gain, no bleed, no lockout drain, no
	# re-arm countdown — and no vent scheduling or window countdown either (a window expiring
	# mid-frenzy would be an unfair miss). Everything holds until the burn ends.
	if frenzy_burning:
		return

	if _locked_out:
		_tick_lockout(delta)
		return

	_was_rushing = rushing
	# Overdrive is PER-EXCURSION (Plans/Rush_Cruise_Control.md): letting go of the rush hold
	# disengages it, so the next press always starts back in safe cruise mode — the gamble is a
	# fresh choice every time, never a sticky mode left on by accident. Ending the excursion
	# also forfeits the vent ladder and any in-flight or open window (an approach cancels
	# silently — the event never arrived, so there is no miss): the ratchet is the reward for a
	# CONTINUOUS ride, not a bankable buff. (GameState keeps `rushing` true through a vent
	# gesture's lifts, so a mid-gesture lift can never land here by accident.)
	if not rushing:
		_overdrive_engaged = false
		_clear_vent_state()

	# Rushing WITHOUT overdrive = cruising: heat clamps at the cruise point and no overheat is
	# possible. Everything below — the band signals, the vent scheduler, the ceiling check —
	# belongs to the opt-in overdrive ride, so the cruise path skips it entirely.
	if rushing and not _overdrive_engaged:
		_tick_cruise(delta)
		return

	var band_before := current_band()
	if rushing:
		# Past heat 1.0 the climb slows to the overdrive build rate, stretching the ride
		# through the danger zone into a real decision window (~5–8 s, Tim 2026-07-15)
		# without changing the bar's geometry.
		var build_rate := tuning.rush_momentum_heat_build_per_second if heat < 1.0 \
			else tuning.rush_momentum_heat_build_hot_per_second
		heat += build_rate * delta
	else:
		heat = maxf(heat - tuning.rush_momentum_heat_bleed_per_second * delta, 0.0)

	# The one region edge left: announce the upward crossing into OVERDRIVE (the UI keys its
	# urgency continuously on depth, so this is the only discrete moment worth a signal).
	if band_before == Band.BUILDING and current_band() == Band.OVERDRIVE:
		band_entered.emit(Band.OVERDRIVE)

	# The vent scheduler and gesture judge only run on a live overdrive ride. A missed window
	# overheats inside this call, in which case this tick is finished.
	if _overdrive_engaged:
		_tick_vent_windows(delta)
		if _locked_out:
			return

	# The fixed hard ceiling is the "you ignored everything" backstop (the schedule guarantees
	# a window telegraphs first — see _schedule_next_window — so reaching it is always on you).
	if heat >= tuning.rush_momentum_hard_ceiling:
		_begin_overheat()
		return

	bonus = _bonus_for_heat(heat)


## The safe half of a rush hold (Plans/Rush_Cruise_Control.md): heat climbs normally but CLAMPS
## at the cruise point, and the bonus holds there indefinitely — no vent windows, no overheat.
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


## The vent side of an overdrive tick: run the open window's gesture clock, or — with no window
## open and heat past the cruise point — roll the DEPTH HAZARD for a fresh one. Written as one
## self-healing condition chain (instead of hooks on specific crossings) so EVERY path into the
## hazard zone gets checks: the normal climb, a re-engage while heat is still high from a
## bailed ride, and the resume after a vent.
func _tick_vent_windows(delta: float) -> void:
	if _window_open:
		_window_remaining -= delta
		_phase_elapsed += delta
		# Police the gesture tolerances on the tick clock. A blown beat is a MISS the moment it
		# becomes unrecoverable — waiting for the window to expire would just delay bad news.
		if _vent_phase == VentPhase.GAP and _phase_elapsed > tuning.rush_momentum_vent_gap_max:
			_miss_vent()
			return
		if _vent_phase == VentPhase.TAP and _phase_elapsed > tuning.rush_momentum_vent_tap_max:
			_miss_vent()
			return
		if _window_remaining <= 0.0:
			_miss_vent()
		return

	# An event in flight: run the approach clock down (tick delta only — the frenzy freeze
	# already stopped this whole call) and open the announced window when the event reaches the
	# target. No hazard rolls while approaching: one event in flight at a time.
	if _approaching:
		_approach_remaining -= delta
		if _approach_remaining <= 0.0:
			_open_window()
		return

	# The REFRACTORY: a rolled quiet spell after each resolved vent (and after engaging), so
	# consecutive events never arrive metronomically. It suppresses the hazard dice AND the
	# force-spawn below — which is only safe because every path that starts a refractory also
	# guarantees the climb through it still fits: the post-vent top-off reserves refractory_max
	# of extra climb room (_succeed_vent), and the engage-time roll is clamped so it expires
	# before heat could pass the fit bound (_start_refractory).
	if _refractory_remaining > 0.0:
		_refractory_remaining -= delta
		return

	# The hazard only runs past the cruise point: below it there is nothing at risk (that heat
	# is free to hold in cruise mode), so no check may ever demand a gesture there.
	var floor_heat := cruise_heat()
	if heat <= floor_heat:
		return

	# TELEGRAPH GUARANTEE (Plans/Overdrive_Vent_Windows.md): a window must always OPEN — with
	# its full duration still ahead — before heat could climb to the hard ceiling, or the
	# backstop could kill a rider who was never given a check. With no arrival delay left to
	# clamp (the hazard rolls tick by tick), the guarantee is a FORCE-SPAWN: the moment heat
	# reaches the last point where the whole EVENT — approach flight plus open window — still
	# fits at the overdrive build rate, the check spawns regardless of the dice. Fairness beats
	# randomness. _succeed_vent keeps post-vent heat at or below this bound, so the force-spawn
	# always has room to work.
	if tuning.rush_momentum_heat_build_hot_per_second > 0.0 and heat >= _window_fit_heat_bound():
		_spawn_vent_event()
		return

	# The depth hazard itself: expected windows/second interpolates from rate_at_cruise (just
	# past the cruise point) to rate_at_ceiling (at the backstop), and each tick rolls that
	# rate × delta. Depth is the cadence axis (Tim 2026-07-18 evening) — riding deeper IS
	# choosing more checks — and since a small vent_heat_drop makes long runs ride ever deeper,
	# per-tier cadence escalation falls out of this curve with no tier knob at all.
	var depth_frac := clampf((heat - floor_heat)
			/ (tuning.rush_momentum_hard_ceiling - floor_heat), 0.0, 1.0)
	var hazard_rate := lerpf(tuning.rush_momentum_vent_rate_at_cruise,
			tuning.rush_momentum_vent_rate_at_ceiling, depth_frac)
	if rng.randf() < hazard_rate * delta:
		_spawn_vent_event()


## How long the NEXT window will stay open: the base duration decayed per achieved tier
## (the speed escalation axis: less time per check, geometrically), floored at duration_floor.
func _next_window_duration() -> float:
	return maxf(tuning.rush_momentum_vent_window_duration
			* pow(tuning.rush_momentum_vent_duration_decay, _vent_tier),
			tuning.rush_momentum_vent_duration_floor)


## The highest heat from which the NEXT vent event still fully fits below the hard ceiling at
## the overdrive build rate. Heat keeps climbing through the WHOLE event — the approach flight
## AND the open window — so the derivation reserves both legs plus the tick-boundary cushion:
##
##   heat_at_spawn + (approach_seconds + duration + cushion) × build_hot ≤ hard_ceiling
##
## rearranged for heat_at_spawn. This is the telegraph guarantee's shared bound: the force-spawn
## fires when heat reaches it, and a vent's top-off clamps heat back to it (so the NEXT event's
## approach + window always fit too). Only meaningful when the overdrive build rate is positive.
func _window_fit_heat_bound() -> float:
	return tuning.rush_momentum_hard_ceiling \
			- (tuning.rush_momentum_vent_approach_seconds + _next_window_duration() \
					+ GUARANTEE_CUSHION_SECONDS) \
			* tuning.rush_momentum_heat_build_hot_per_second


## Lifts the NEXT window will demand (the complexity escalation axis): one more
## every lifts_step_tiers tiers, hard-capped at MAX_VENT_LIFTS. The step knob is guarded to at
## least 1 so a hand-poked 0 can never divide by zero (it would just demand the cap instantly).
func _next_window_required_lifts() -> int:
	var step := maxi(tuning.rush_momentum_vent_lifts_step_tiers, 1)
	# GDScript's int / int truncates, which is exactly the "+1 every N tiers" stair-step.
	return mini(1 + _vent_tier / step, MAX_VENT_LIFTS)


## The hazard fired (or the telegraph guarantee forced the moment): put a vent event IN FLIGHT.
## The demanded lifts are decided NOW and announced with the approach time — the gesture
## escalates with the ladder (the approachable single feather early, Tim's double release
## deeper, the triple pump deepest, capped at MAX_VENT_LIFTS) — and the window that opens when
## the flight ends must demand exactly this announcement.
func _spawn_vent_event() -> void:
	_approaching = true
	_approach_remaining = tuning.rush_momentum_vent_approach_seconds
	_approach_required_lifts = _next_window_required_lifts()
	vent_incoming.emit(_approach_remaining, _approach_required_lifts)


## The in-flight event reached the target: open its window and arm the gesture judge.
func _open_window() -> void:
	_approaching = false
	_approach_remaining = 0.0
	_window_open = true
	_window_remaining = _next_window_duration()
	# Exactly what the spawn announced — the player committed based on the incoming bar's pips.
	_window_required_lifts = _approach_required_lifts
	_window_lifts_done = 0
	# Seed the judge from the live button state: mid-hold (the normal case) the gesture starts
	# with its first release; if the finger happens to be up already, that release has in
	# effect just happened, so the gap clock starts now.
	_vent_phase = VentPhase.WAITING_FOR_LIFT if _button_pressed else VentPhase.GAP
	_phase_elapsed = 0.0
	vent_window_opened.emit(_window_required_lifts, _window_remaining)


## Press edge on the rushed property's button (forwarded by GameState). Outside an open window
## this only updates the tracked button state — ordinary rush taps stay ordinary (context
## gating: no gesture ambiguity exists when no window is open).
func notify_rush_pressed() -> void:
	_button_pressed = true
	if not _window_open:
		return
	match _vent_phase:
		VentPhase.GAP:
			# A re-press inside the gap completes one lift beat. (The gap length itself is
			# policed every tick, so reaching here means it was in time.)
			_window_lifts_done += 1
			vent_lift_registered.emit(_window_lifts_done, _window_required_lifts)
			if _window_lifts_done >= _window_required_lifts:
				_succeed_vent()
			else:
				# More lifts still owed, so this press is an intermediate tap (the ×2 gesture
				# has one, the ×3 gesture two): it must stay short or it reads as a re-hold.
				_vent_phase = VentPhase.TAP
				_phase_elapsed = 0.0
		_:
			# A press while already judged as down (duplicate edge) carries no meaning.
			pass


## Release edge on the rushed property's button (forwarded by GameState). See notify_rush_pressed.
func notify_rush_released() -> void:
	_button_pressed = false
	if not _window_open:
		return
	match _vent_phase:
		VentPhase.WAITING_FOR_LIFT:
			# The gesture's opening lift: the finger is up, the re-press gap clock starts.
			_vent_phase = VentPhase.GAP
			_phase_elapsed = 0.0
		VentPhase.TAP:
			# The intermediate tap ended in time (a long hold would have missed on a tick
			# already); the next gap clock starts.
			_vent_phase = VentPhase.GAP
			_phase_elapsed = 0.0
		_:
			# A release while already judged as up (duplicate edge) carries no meaning.
			pass


## The gesture completed inside the window: vent heat, ratchet the ladder. (The next check
## comes from the tick's hazard roll — or the force-open — no scheduling needed here.)
func _succeed_vent() -> void:
	# Venting never drops heat below the cruise point: success must never END the ride (the
	# reward for the check is the ratchet, not an exit), and everything at or under cruise is
	# heat the player could hold for free anyway — there is nothing there to vent.
	heat = maxf(heat - tuning.rush_momentum_vent_heat_drop, cruise_heat())
	_vent_tier += 1  # UNBOUNDED — the endless ladder's whole point (Tim 2026-07-18)
	# TELEGRAPH GUARANTEE, success half — STILL REQUIRED under the hazard model (re-derived
	# 2026-07-18; approach leg added 2026-07-19; refractory leg added 2026-07-18 night): the
	# guarantee's force-spawn can only fire at whatever heat the bar has ALREADY reached, so if
	# a small heat_drop leaves post-vent heat above the next event's fit bound, the forced event
	# would spawn too late for its approach AND window to fully fit and the backstop could kill
	# a clean rider mid-gesture. So a success also vents whatever extra heat is needed for the
	# next (escalated) event to fully fit — and now the reservation includes the WORST-CASE
	# refractory too, because the force-spawn holds its fire until the rolled quiet ends and
	# heat keeps climbing the whole time:
	#
	#   heat_post_vent + (refractory_max + approach + duration + cushion) × build_hot ≤ ceiling
	#   ⇔ heat_post_vent ≤ _window_fit_heat_bound() − refractory_max × build_hot
	#
	# An adaptive top-off that only bites near the ceiling, where it reads as "the vent bought
	# you exactly one more check," which is precisely the design.
	if tuning.rush_momentum_heat_build_hot_per_second > 0.0:
		var post_vent_bound := _window_fit_heat_bound() \
				- maxf(tuning.rush_momentum_vent_refractory_max, 0.0) \
				* tuning.rush_momentum_heat_build_hot_per_second
		heat = minf(heat, maxf(post_vent_bound, cruise_heat()))
	_window_open = false
	_window_lifts_done = 0
	bonus = _bonus_for_heat(heat)
	# The rolled breather before the next event may spawn — success is one of the two moments
	# that start a refractory (engaging overdrive is the other).
	_start_refractory()
	vent_succeeded.emit(_vent_tier, current_peak_bonus())
	# The next window is scheduled by the tick's self-healing condition chain once the
	# refractory expires — no need to roll an arrival here, and one code path keeps the rng
	# draw order simple.


## Roll and start a vent REFRACTORY: a quiet spell of uniformly random length (the two knobs)
## during which no event may spawn — the "slightly random spacing" Tim asked for (2026-07-18
## night). Rolled on the schedule rng so seeded sim runs stay reproducible. The roll is then
## CLAMPED to the tick-time left before heat would reach the force-spawn bound: the refractory
## suppresses the force-spawn too, so an uncapped roll started with heat already near the bound
## (re-engaging overdrive while still hot from a bailed deep ride) could let heat overshoot the
## reservation and reach the backstop without a check — the guarantee outranks the breather.
## (Post-vent rolls are never clamped in practice: the success top-off already reserved
## refractory_max of climb room below the bound. The clamp uses the OVERDRIVE build rate
## because the bound sits well above heat 1.0 — the only region where it can bite.)
func _start_refractory() -> void:
	var rolled := rng.randf_range(
			maxf(tuning.rush_momentum_vent_refractory_min, 0.0),
			maxf(tuning.rush_momentum_vent_refractory_max, 0.0))
	var build_hot := tuning.rush_momentum_heat_build_hot_per_second
	if build_hot > 0.0:
		var seconds_until_bound := maxf((_window_fit_heat_bound() - heat) / build_hot, 0.0)
		rolled = minf(rolled, seconds_until_bound)
	_refractory_remaining = rolled


## The open window was blown. Report HOW FAR the player got (the learnable feedback), then
## overheat exactly as if the ceiling had been hit.
func _miss_vent() -> void:
	vent_missed.emit(_window_lifts_done, _window_required_lifts)
	_begin_overheat()


## Forget the whole vent excursion: the ladder, the open window, AND any event still in flight
## (the hazard is stateless). An in-flight approach is cancelled SILENTLY — the event never
## arrived, so there is no miss to report. Called on overheat, on reset, and when a release
## ends the excursion. (_button_pressed is deliberately NOT touched — it mirrors the physical
## finger, not the excursion.)
func _clear_vent_state() -> void:
	_vent_tier = 0
	_refractory_remaining = 0.0
	_approaching = false
	_approach_remaining = 0.0
	_approach_required_lifts = 1
	_window_open = false
	_window_remaining = 0.0
	_window_lifts_done = 0
	_vent_phase = VentPhase.WAITING_FOR_LIFT
	_phase_elapsed = 0.0


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
			# Fully cooled — the re-arm delay starts only now. Falling from higher hurts more
			# (Plans/Overdrive_Vent_Windows.md): the per-tier sting captured at the overheat is
			# added to the base BEFORE the Rapid Restart scale, so the Legacy discount divides
			# the whole punishment, sting included.
			_rearming = true
			_rearm_remaining = (tuning.rush_momentum_rearm_seconds + _rearm_tier_sting) \
					* _safe_lockout_scale()
			# Remember the full length so the UI's visual re-arm timer can show remaining/total.
			_rearm_total = _rearm_remaining
	else:
		_rearm_remaining -= delta
		if _rearm_remaining <= 0.0:
			_rearming = false
			_locked_out = false
			_rearm_remaining = 0.0
			rush_ready.emit()


## Heat reached the hard ceiling, or a vent window was missed: kill the bonus, disable rushing,
## and start the locked drain.
func _begin_overheat() -> void:
	# A fast tick can overshoot past the ceiling; pin heat back so the bar starts its drain
	# from at most the ceiling. (A missed-window overheat simply drains from wherever heat was.)
	heat = minf(heat, tuning.rush_momentum_hard_ceiling)
	bonus = 0.0
	_locked_out = true
	_rearming = false
	# Capture the ladder's re-arm sting BEFORE clearing it — the re-arm delay is not computed
	# until the drain finishes (see _tick_lockout), by which time the tier is gone. The sting
	# is CAPPED: on the endless ladder, failure pressure comes from the difficulty curve, not
	# from ever-longer timeouts (Tim 2026-07-18).
	_rearm_tier_sting = minf(tuning.rush_momentum_vent_fail_rearm_per_tier * _vent_tier,
			tuning.rush_momentum_vent_fail_rearm_cap)
	_clear_vent_state()
	# The gamble ended (badly) — the next rush hold after the lockout starts back in cruise mode.
	_overdrive_engaged = false
	overheated.emit()


## The lockout time scale, guarded so a bad value can never stall the drain (divide-by-zero)
## or flip it negative. The catalog's Rapid Restart cap (level 5 = 0.5) keeps the real range
## far above this floor; the clamp only protects against a corrupt or hand-poked value.
func _safe_lockout_scale() -> float:
	return clampf(lockout_time_scale, 0.05, 1.0)


## The heat → bonus mapping: a pure, piecewise-LINEAR function of (heat, vent tier), so one
## function drives payout, display, and danger state (the "cash always matches the readout"
## invariant). Exactly TWO segments since the depth-hazard rework — no kink where the old band
## edges used to sit. The overdrive segment's top end is the LADDER peak — it rises with each
## successful vent — so a vent visibly re-steepens the reward for the heat still ahead.
func _bonus_for_heat(current_heat: float) -> float:
	var overdrive_start := 1.0  # by definition of the heat unit (1.0 = the old cap)
	var hard_ceiling := tuning.rush_momentum_hard_ceiling
	if current_heat <= overdrive_start:
		# Building: 0 → bonus_at_hot across [0, 1.0] — the old meter, unchanged.
		return tuning.rush_momentum_bonus_at_hot * (current_heat / overdrive_start)
	# Overdrive: bonus_at_hot → the current ladder peak, ONE lerp across [1.0, hard_ceiling].
	var overdrive_progress := clampf(
		(current_heat - overdrive_start) / (hard_ceiling - overdrive_start), 0.0, 1.0)
	return lerpf(tuning.rush_momentum_bonus_at_hot, current_peak_bonus(), overdrive_progress)


## The bonus at the hard ceiling with the CURRENT vent tier: the top of the reward ladder the
## bar and chip quote (base peak +55%, each vent adds vent_bonus_step, UNBOUNDED — the
## difficulty curve is the brake, not the reward curve).
func current_peak_bonus() -> float:
	return tuning.rush_momentum_bonus_peak + _vent_tier * tuning.rush_momentum_vent_bonus_step


## The live property-income multiplier (1 + bonus). Multiplied into every property payout AND its
## displayed rate — the same way frenzy is — so collection can never drift from the readout.
func factor() -> float:
	return 1.0 + bonus


## Opt in to the danger zone for THIS rush hold (the OVERDRIVE button). Releases the cruise
## clamp so heat resumes climbing into overdrive — vent windows, hard ceiling,
## lockout and all. A no-op during an overheat lockout (the button is dead).
func engage_overdrive() -> void:
	if _locked_out:
		return
	if not _overdrive_engaged:
		# Fresh opt-in: start a rolled refractory so the FIRST event of the ride is not
		# metronomic either (engaging at the cruise clamp used to make the first spawn's timing
		# depend only on the dice, but a hot re-engage near the force-spawn bound would fire it
		# on an exact schedule). Guarded on the flag so a duplicate engage tap mid-ride cannot
		# re-roll a quiet spell the player did not earn.
		_start_refractory()
	_overdrive_engaged = true


## True while the player has opted in to the danger zone this excursion.
func is_overdrive_engaged() -> bool:
	return _overdrive_engaged


## True while the player is holding a SAFE rush: the last tick counted as rushing, overdrive is
## not engaged, and no lockout is running. The UI's "CRUISE +25%" steady state keys off this.
func is_cruising() -> bool:
	return _was_rushing and not _overdrive_engaged and not _locked_out


## The sustainable bonus while cruising: the tuned base plus any Cooling Systems Legacy points,
## hard-capped at bonus_at_hot — cruise may re-earn the old always-on +30% cap but NEVER exceed
## it, so the overdrive bonuses stay exclusive to riding overdrive (Tim 2026-07-16).
func effective_cruise_bonus() -> float:
	return minf(tuning.rush_momentum_cruise_bonus + legacy_cruise_bonus,
			tuning.rush_momentum_bonus_at_hot)


## The heat the cruise clamp holds at: the INVERSE of the Building band's linear bonus mapping
## at the effective cruise bonus (bonus_at_hot maps to heat 1.0, so cruise_bonus/bonus_at_hot
## maps back to its heat). Derived from the existing knobs, not a new band edge, so the band
## geometry stays exactly as tuned in Plans/Rush_Overheat.md.
func cruise_heat() -> float:
	return effective_cruise_bonus() / tuning.rush_momentum_bonus_at_hot


## True while a spawned vent event is IN FLIGHT — vent_incoming has fired but its window has
## not opened yet. The UI shows the traveling event bar while this holds.
func is_vent_approaching() -> bool:
	return _approaching


## Seconds until the in-flight event reaches the target (its window opens); 0.0 when nothing is
## approaching. The UI derives the red event bar's position from remaining / approach_seconds.
func vent_approach_remaining() -> float:
	return _approach_remaining if _approaching else 0.0


## Seconds of rolled post-vent/post-engage QUIET left before the next event may spawn; 0.0 once
## expired. Exposed for the headless sim's spacing checks (the live UI ignores it — the quiet
## is deliberately invisible, so spacing FEELS random rather than reading as a mechanic).
func vent_refractory_remaining() -> float:
	return maxf(_refractory_remaining, 0.0)


## True while a vent window is OPEN (the gesture clock is running). GameState uses this to keep
## the player counted as rushing — and the rushed property's grace alive — through the lifts.
func is_vent_window_open() -> bool:
	return _window_open


## Seconds left to complete the gesture; 0 when no window is open.
func vent_window_remaining() -> float:
	return _window_remaining if _window_open else 0.0


## Lifts the OPEN window demands (1 .. MAX_VENT_LIFTS). Only meaningful while
## is_vent_window_open().
func vent_required_lifts() -> int:
	return _window_required_lifts


## Successful vents this excursion (unbounded) — the bonus ladder's current rung.
func vent_tier() -> int:
	return _vent_tier


## False from the overheat moment until rush_ready fires. GameState gates every rush verb on this.
func can_rush() -> bool:
	return not _locked_out


## True during the whole overheat lockout: the locked drain AND the re-arm delay.
func is_locked_out() -> bool:
	return _locked_out


## True only during the post-drain re-arm delay (the grayed-button tail of the lockout).
func is_rearming() -> bool:
	return _rearming


## How much of the re-arm delay is LEFT, as a fraction: 1.0 the moment the delay starts, 0.0
## at rush_ready — and 0.0 any time no re-arm is running (normal riding, the drain phase).
## The UI's dark-gray lockout timer drains on this. Divides by the captured _rearm_total, not
## the knobs, because the per-tier sting and the Rapid Restart scale vary the total per lockout.
func rearm_remaining_fraction() -> float:
	if not _rearming or _rearm_total <= 0.0:
		return 0.0
	return clampf(_rearm_remaining / _rearm_total, 0.0, 1.0)


## Which region the current heat sits in. Purely a heat-range lookup — regions are never
## timed states (the design's core rule).
func current_band() -> Band:
	# Building is INCLUSIVE of heat 1.0 (Plans/Rush_Cruise_Control.md boundary rule): with max
	# Cooling Systems the cruise clamp sits at exactly 1.0, and parking there must not read as
	# OVERDRIVE or start an excursion — an excursion begins only when overdrive pushes heat
	# PAST the tick.
	if heat <= 1.0:
		return Band.BUILDING
	return Band.OVERDRIVE


## Wipe everything — heat, bonus, the vent ladder, AND any in-progress lockout/re-arm. Called
## on each First Contact so every epoch builds its own momentum fresh, which is what keeps the
## mechanic a per-epoch pinch instead of a run-long snowball.
func reset() -> void:
	heat = 0.0
	bonus = 0.0
	_locked_out = false
	_rearming = false
	_rearm_remaining = 0.0
	_rearm_total = 0.0
	_rearm_tier_sting = 0.0
	_overdrive_engaged = false
	_was_rushing = false
	_clear_vent_state()
