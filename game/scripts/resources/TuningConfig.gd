class_name TuningConfig
extends Resource

# Single source of truth for all numeric tuning constants (Mechanics Spec §12).
# Loaded at runtime from res://config/tuning.tres — never referenced directly
# from script defaults, which are only fallbacks for in-editor previews.

# --- Time / tick ---

## Fixed logic tick rate in Hz (Spec §2).
@export var logic_hz: int = 10

# --- Run start ---

## Starting cash for a fresh run. Intentionally $0 (Tim's call): the player taps
## the "clock in" wage button to earn the cash for their first property, even
## though that doesn't track thematically. The full origin flow arrives in M2.
@export var m1_starting_cash: float = 0.0

# --- Cost curve (Spec §3.2) ---

## Global band-steepening factor; ratio multiplies by this at each milestone band.
@export var band_step: float = 1.15  # TBD-SIM

# --- Cycles & milestones (Spec §3.3) ---

## Minimum cycle length a property can reach via milestone speed-ups, in seconds.
@export var cycle_floor: float = 1.0  # TBD-SIM

# --- Active tapping (Spec §4) ---

## Fraction of cycle_length that one rush-tap advances the cycle.
@export var rush_pct: float = 0.05  # TBD-SIM

## Auto-rush pulses per second while the rush button is held down.
@export var hold_rush_per_second: float = 5.0  # feel-tune M1

## Auto-tap pulses per second while the wage ("clock in") button is held down.
## This is the BASE rate; the effective rate is meant to be scaled by Legacy
## upgrades later (configurable by upgrades — GDD §8.4 loophole/upgrade catalog).
@export var wage_hold_taps_per_second: float = 2.5  # feel-tune

## The "executive compensation" wage floor: one clock-in tap pays at least this many
## SECONDS of the empire's passive income, whenever that beats the ladder wage (see
## WageState). Keeps clocking in a viable active play at every scale of the economy;
## without it the fixed ladder died the moment the first ATM was staffed (Tim,
## 2026-07-05). At 0.25 and a deliberate ~3 taps/sec, active clocking adds ~+75%
## on top of passive income.
@export var wage_passive_fraction: float = 0.25  # feel-tune

## Executive-pay bonus per clock-in level, as a fraction of the floor (0.15 = +15%/level).
## Scales the executive floor by (1 + this × level) so a level-up ALWAYS visibly raises the
## per-tap payout — without it, once the floor overtook the ladder wage, leveling up changed
## nothing and the ladder felt dead (Tim, 2026-07-15). A steady multiplier of the floor, so
## it tracks the economy rather than compounding past it. Tripled from the first-cut 0.05
## (Tim, 2026-07-15: clock-in should be more powerful).
@export var wage_floor_bonus_per_level: float = 0.15  # feel-tune

## Frenzy fill per held-rush pulse, as a fraction of a manual tap's fill.
## Holding is convenient, so it charges the meter slower than real tapping.
@export var frenzy_fill_hold_factor: float = 0.6  # feel-tune M1

# --- Hold-to-repeat purchasing (PropertyRow multi-purchase) ---
# Holding the Buy or the Hire/Upgrade button repeats the action: a short initial delay
# (so a normal tap acts only once), then a steady repeat cadence while held. Buy and Hire
# have SEPARATE knobs (Tim, 2026-07-03) so each can be paced independently on device — a
# held Buy may want to rip through units while a held Hire steps more deliberately.

## Seconds a held BUY button waits before its first auto-repeat.
@export var buy_hold_initial_delay: float = 0.45  # feel-tune
## Seconds between each BUY auto-repeat after the first.
@export var buy_hold_repeat_interval: float = 0.35  # feel-tune
## Seconds a held HIRE/UPGRADE button waits before its first auto-repeat.
@export var hire_hold_initial_delay: float = 0.45  # feel-tune
## Seconds between each HIRE/UPGRADE auto-repeat after the first.
@export var hire_hold_repeat_interval: float = 0.35  # feel-tune

# --- Staffing & offline (Spec §6) ---

## Alien staff (tier 2+) ENTRY hire cost as a fraction of the TARGET epoch's whole economy
## (earth_economy_target × that epoch's economy_scale). Anchoring to the epoch economy
## — not the property's tiny Earth base cost — is what makes alien staff scale with each
## epoch, so you cannot afford the next epoch's staff the instant you arrive (Tim 2026-06-17).
## The Earth staffer (tier 1) keeps its small property-scaled cost.
## RETUNED 2026-06-27 0.001 → 0.01: at 0.001 the cheapest new staffer was ~0.1% of the
## epoch's whole economy — trivially affordable at contact, which Tim flagged as "too cheap."
## At 0.01 the cheapest staffer is ~1% of the epoch economy and the full alien roster costs
## more than one epoch's earnings, so staffing is a prioritized spend, not a one-tap sweep.
@export var staff_cost_fraction: float = 0.01  # feel-tune

## Per-property growth of that fraction: cheaper rungs (ATM) get the base fraction, each
## higher rung multiplies by this, so pricier properties cost proportionally more to staff.
@export var staff_cost_property_growth: float = 1.4  # feel-tune

# --- The staff ladder (GDD §6.1 / Plans/Epoch_Depth_Pass.md, redesigned 2026-07-04) ---
# One sequential ladder per property, in blocks of staff_levels_per_epoch. Level 1 of each
# block IS that epoch's staffer hire (priced at the block's full anchor, carrying the block's
# big entry step); the rest are the staffer's smaller equal steps. A block's costs and
# effects are constants of ITS epoch — set when the block became available, never recomputed
# — so a first contact can never silently reprice the button (Tim's 2026-07-03 directive).

## Base income step per staff level, ADDITIVE. Each block's actual per-level step is this ×
## that block's catalog multiplier (PropertyState.staff_small_step), so later blocks' steps
## are sized to their epoch while Earth's block 1 keeps exactly this value. Additive (not
## compounding) because 120 compounding levels would explode income. First-pass value —
## the Phase 3 pacing retune owns the final numbers (Plans/Epoch_Depth_Pass.md §4).
@export var staff_level_step: float = 0.33  # feel-tune

## Levels per block — one block per epoch from the property's unlock epoch onward. The hard
## cap on staff_level is this × the blocks the run has opened for that property; the cap only
## ever rises, and the ladder is strictly sequential, so levels skipped earlier are always
## the next (cheap) rung rather than lost.
@export var staff_levels_per_epoch: int = 20  # feel-tune

## Cost of a block's SECOND level (the first small step after the hire), as a fraction of
## that block's own anchor (its hire price). Steps start cheap relative to the hire just
## paid, then climb by staff_level_cost_growth. Cut 0.10 -> 0.07 (Tim, 2026-07-02) so a
## level's ROI beats buying a unit.
@export var staff_level_cost_base: float = 0.07  # feel-tune

## Geometric growth of the step cost WITHIN a block: each level costs the previous × this.
## The climb restarts every block (an un-reset exponent would make a 120-level ladder
## literally unbuyable), but each block's anchor is ~economy_scale higher than the last,
## so absolute costs still trend up. Softened 1.6 -> 1.5 (Tim, 2026-07-02).
@export var staff_level_cost_growth: float = 1.5  # feel-tune

# --- Staff RETENTION pricing (the Estate Office "will your staff to the heir" buys) ---
# Repriced 2026-07-07 after Tim's playtest: the old flat model (1 Legacy × 1.12^level,
# no property term) made deep retention near-free at a 350-gem prestige and priced
# retaining the ATM the same as retaining Executive Assets — a big part of why the
# second prestige felt too big. Cost = base × property_step^property_index × growth^(level-1).

## Legacy to retain the FIRST ladder level of the FIRST property (the ATM anchor).
@export var retention_base_cost: float = 1.0  # feel-tune

## Per-LEVEL geometric growth of retention cost within a property (was 1.12 — so flat
## that levels 1-7 all cost 1 Legacy; 1.25 makes each further step a visible commitment).
@export var retention_cost_growth: float = 1.25  # feel-tune

## Per-PROPERTY geometric step: each higher property multiplies retention cost by this,
## so protecting a top earner costs like a top earner (ATM ×1, Executive Assets
## ×1.5^11 ≈ ×87). The missing term the playtest exposed.
@export var retention_property_step: float = 1.5  # feel-tune

# --- Carbonation frenzy (diagnosis + feel knobs, Tim 2026-07-08) ---
# The rush "frenzy" state on property bars, live-tunable from Balance Tuning so its
# elements can be isolated ON DEVICE (an edge burst kept surviving blind fixes).

## 1 = show a tiny per-row debug readout of the live carbonation numbers (excitement
## level, bubble base speed, measured fill speed, commanded sweep). 0 = off.
@export var carb_debug_overlay: float = 0.0

## 1 = on boot, run the scripted CarbAutopilot rush scenario (buy a long-cycle
## property, hold rush 10s, release, observe) while logging every frame's carbonation
## internals to user://carb_log.csv, then quit. A desktop diagnosis harness — never
## ship a build with this on.
@export var carb_autolog: float = 0.0

# --- Carbonation SPEED TIERS (Tim, 2026-07-10; values dialed on device 2026-07-11) ---
# The bubble speed is not measured from the bar's fill — every bar picks an excitement TIER and each
# tier has a STATIC px/s speed set here (Main pushes these into GoldBubbles at startup). IDLE = a
# still/full bar; FLOWING = a cycling property / the economy bar / TURBO charging; RUSHED = TURBO
# burning; FRENZY = a property's rush held. Values below are Tim's device-tuned set.
@export var carb_tier_idle_px: float = 20.0     # feel-tune
@export var carb_tier_flowing_px: float = 50.0  # feel-tune
@export var carb_tier_rushed_px: float = 150.0  # feel-tune
@export var carb_tier_frenzy_px: float = 200.0  # feel-tune
## Seconds a bar's bubble speed/agitation eases over when it changes tier. 0 = INSTANT (no accel/
## decel ramp when a rush engages/releases — a held rush is constant from press to release, Tim's
## long-standing "no edge burst" goal). Raise it only if some smoothing is ever wanted.
@export var carb_tier_ease: float = 0.0  # feel-tune

## Offline income efficiency vs. live play (0–1).
@export var offline_efficiency: float = 0.5  # TBD-SIM

## Base offline accrual cap in seconds (4 hours = 14400).
@export var offline_cap_seconds: float = 14400.0

# --- Frenzy meter (Spec §7) ---

## Peak frenzy multiplier (applied to all income during a burn).
@export var frenzy_max_multiplier: float = 4.0  # feel-tune M1

## Duration of a full-charge frenzy burn in seconds.
@export var frenzy_burn_duration: float = 90.0  # feel-tune M1

## Meter fill added per tap (fraction of full bar, 0–1).
@export var frenzy_fill_per_tap: float = 0.004  # feel-tune M1

## Meter decay rate per second when idle (fraction of full bar, 0–1).
@export var frenzy_decay_per_second: float = 0.005  # feel-tune M1

## Seconds without a tap before decay begins.
@export var frenzy_idle_grace: float = 5.0  # feel-tune M1

## Minimum meter charge at which the player can trigger a frenzy pop.
@export var frenzy_pop_floor: float = 0.15  # feel-tune M1

# --- Rush Momentum / Overheat (Tim 2026-07-15; design: Plans/Rush_Overheat.md) ---
# Rushing heats the property up — heat IS the momentum meter, in HEAT UNITS where 1.0 = the old
# momentum cap = the Hot band's lower edge. Deeper heat pays a bigger property-income bonus but
# risks an overheat shutdown. See RushMomentumState for the model. Since Vent Windows
# (Plans/Overdrive_Vent_Windows.md) the overheat point is no longer a secret roll — a fixed
# hard ceiling backstops a chain of telegraphed vent-gesture skill checks (knobs below).
# NOTE: the old bonus-fraction knobs (rush_momentum_max_bonus / _build_per_second /
# _bleed_per_second) were deliberately RENAMED rather than reused, so a stale user override
# saved in the old bonus-fraction units can never silently poison the new heat-unit semantics.
# The old rush_momentum_ceiling_min/_max knobs (the retired random ceiling) were REMOVED for
# the same reason — nothing may quietly re-inject the slot-machine ceiling.

## How fast heat climbs while actively rushing, in heat units per second
## (0.167 ≈ 6 s from cold to the Hot edge — matching the old build feel).
@export var rush_momentum_heat_build_per_second: float = 0.167  # feel-tune

## How fast heat climbs while rushing ABOVE heat 1.0 (the OVERDRIVE region), in heat units per
## second. Slower than the base build so the ride through the danger zone is a real decision
## window: 0.075 stretches the climb from heat 1.0 to the hard ceiling (0.60 units) to ~8 s
## (Tim 2026-07-15: "at least 5 to 8 seconds in the high heat zone").
@export var rush_momentum_heat_build_hot_per_second: float = 0.075  # feel-tune

## How fast heat bleeds away when NOT rushing, in heat units per second
## (0.333 ≈ 3 s to fully cool from heat 1.0 — matching the old bleed feel).
@export var rush_momentum_heat_bleed_per_second: float = 0.333  # feel-tune

## The FIXED overheat ceiling — the visible end of the bar and the "you ignored everything"
## backstop (Plans/Overdrive_Vent_Windows.md). Also the heat at which the bonus reaches the
## vent ladder's current peak. Replaces the retired random ceiling roll: unpredictability now
## lives in the vent windows' arrival times, never in the shutdown point itself.
@export var rush_momentum_hard_ceiling: float = 1.60  # feel-tune

## The sustainable "cruise" bonus while holding rush WITHOUT overdrive engaged (0.25 = +25%).
## Heat clamps at the matching point on the Building region and can never overheat there — the
## danger zone is opt-in via the OVERDRIVE button (Plans/Rush_Cruise_Control.md). The Cooling
## Systems Legacy upgrade adds to this, hard-capped at rush_momentum_bonus_at_hot (the old +30%).
@export var rush_momentum_cruise_bonus: float = 0.25  # feel-tune

## Bonus at the Hot edge (heat 1.0 — the top of the Building region, where OVERDRIVE begins),
## as a fraction of property income. 0.30 keeps the old cap's value — the Building region is
## exactly the pre-overheat meter. Above heat 1.0 the bonus is ONE continuous lerp from here to
## the ladder peak at the hard ceiling (the depth-hazard rework retired the Critical band and
## its kink — Tim 2026-07-18 evening).
@export var rush_momentum_bonus_at_hot: float = 0.30  # feel-tune

## Bonus at the hard ceiling with NO vents achieved — the ladder's tier-0 peak. Each successful
## vent adds rush_momentum_vent_bonus_step on top, with NO cap (endless escalation). Only ever
## held for seconds at a time — the realistic average is the ride/vent duty cycle
## (~+75% for a skilled venter; see the vent-window block comment below).
@export var rush_momentum_bonus_peak: float = 0.55  # feel-tune

# --- Vent windows (Tim 2026-07-17, endless escalation 2026-07-18, depth hazard 2026-07-18
# evening; design: Plans/Overdrive_Vent_Windows.md) ---
# While riding overdrive past the cruise point, telegraphed vent windows periodically demand a
# gesture on the rushed property's button: VENT = one lift (release → re-press), VENT ×2 = the
# double release (lift → tap → re-hold), VENT ×3 adds a second tap. Success vents heat and
# ratchets the bonus ladder up a rung; a miss (or reaching the hard ceiling) is a full
# overheat. Gesture tolerances are deliberately sloppy-thumb generous — thumbs on glass are
# the real calibration, not the sim.
#
# ENDLESS ESCALATION (Tim 2026-07-18, supersedes the old 4-tier cap): the windows never stop
# arriving, and the DIFFICULTY CURVE replaces the tier cap as the run's ending. Each tier the
# window duration decays geometrically toward a floor and the demanded lifts step up 1 → 2 → 3
# (hard-capped at 3 — a quad-pump is thumb mush; past ×3 the speed axes carry the difficulty
# alone). The reward stays a flat unbounded step per vent: the brake is the curve, not the
# reward. Every run therefore ends in flames eventually — the question is how high you got
# (best streak = an implicit high score).
#
# DEPTH HAZARD (Tim 2026-07-18 evening, retires the Critical band): window arrival is no longer
# a rolled delay inside a zone — it is a per-tick hazard whose rate interpolates with how DEEP
# into the overdrive span (cruise point → hard ceiling) the heat currently sits. Shallow riding
# = rare checks and a small climb; riding just under the backstop = relentless checks and the
# tall pay. The old per-tier cadence decay is retired with the band: a small heat_drop means
# long runs inevitably ride deeper, so cadence escalation now FALLS OUT of depth itself.
#
# TUNE HISTORY: the endless-model retunes (heat_drop 0.15 → 0.06 so the bar creeps toward the
# ceiling; duration_decay 0.92 → 0.975 so deep runs die to blown beats, not a too-short-to-
# finish cliff at the triples) carried over to the hazard model unchanged. The APPROACH PHASE
# retune (2026-07-19) rebalanced around the new 2 s telegraph flight — every check now carries
# approach_seconds of paid, riskless riding, which roughly doubled the pay per unit of risk —
# by densifying the check cadence (rates 0.05/1.0 → 0.5/3.0), trimming the per-vent reward
# step (0.60 → 0.30), and stiffening the low-tier fail sting (3.0 → 6.0 s/tier, cap
# unchanged). The REFRACTORY retune (2026-07-18 night) rebalanced again around the rolled
# post-vent quiet — another ~0.8 s of paid, check-free riding per event, the same class of
# drift the approach caused: rates 0.5/3.0 → 0.7/3.4 (denser rates alone SATURATE — the
# free ride is approach + refractory, not the hazard wait — three densities moved sloppy by
# only 0.3 points) and the fail sting to 12.0 s/tier, cap 14.0, which lands almost entirely
# on the shallow-death profile that was out-earning cruise.
#
# The PROPERTY FREEZE retune (Tim 2026-07-19) then reversed the whole sting arms race: the
# overheat now freezes the rushed properties for the entire lockout (see GameState), the sim
# prices every frozen second at −100% of base income, and against those honest gates the
# sting timeouts were not just unnecessary but HARMFUL (3.0/9.0 dragged a skilled venter to
# +45%, under the +62% floor) — so approach 2.0 → 1.2 s (less riskless telegraph pay) and
# the fail sting to 0.0/0.0 (the gates' floor; ~1.0/3.0 is the most they allow). Gates now:
# skilled (95% per lift) +74.8% freeze-priced average with median run tier 8, sloppy (70%)
# −12.7% — well under cruise (+24.9%), because a fumbled gamble now darkens your own earner.
# Every knob is live in Balance Tuning.

## Expected vent-event spawns per second when heat sits just past the cruise point — the
## SHALLOW end of the depth hazard (0.5 ≈ a check every ~2 s hovering there). Each tick rolls
## lerp(rate_at_cruise, rate_at_ceiling, depth) × delta against the schedule rng, so arrival
## stays the unpredictable part while the outcome stays player-owned. Raised 0.05 → 0.5 with
## the approach phase (2026-07-19): every event now includes approach_seconds of check-free
## riding, and at the old sparse cadence even a sloppy venter out-earned cruise on free ride
## time alone — denser checks put the risk back. 0.5 → 0.7 with the refractory (2026-07-18
## night), which added the same kind of check-free time (see the tune history above).
@export var rush_momentum_vent_rate_at_cruise: float = 0.7  # feel-tune

## Expected spawns per second at the hard ceiling — the DEEP end of the hazard (relentless).
## Depth is the cadence axis now: riding higher is the player choosing more checks for more
## pay. Raised 1.0 → 3.0 with the approach phase, 3.0 → 3.4 with the refractory — same
## reasoning as rate_at_cruise above both times.
@export var rush_momentum_vent_rate_at_ceiling: float = 3.4  # feel-tune

## VENT REFRACTORY (Tim 2026-07-18 night): the shortest quiet time after a resolved vent (and
## after first engaging overdrive) before the next event may spawn. Each vent success rolls a
## delay uniformly in [refractory_min, refractory_max] on the seeded schedule rng; hazard dice
## AND the telegraph guarantee's force-spawn both hold their fire until it expires. WHY: deep
## rides sit so close to the force-spawn bound that the next event used to spawn on almost the
## very tick a vent resolved — a metronome, not a hazard. A small rolled breather makes the
## spacing read as random again without touching the depth-hazard curve itself. Tick-time, so
## the frenzy freeze pauses it like every other vent clock.
@export var rush_momentum_vent_refractory_min: float = 0.4  # feel-tune

## The longest rolled post-vent quiet time (seconds). The success top-off reserves THIS much
## extra climb room below the force-spawn bound (see RushMomentumState._succeed_vent), so heat
## climbing through a worst-case refractory can never leave the next event unable to fit before
## the hard ceiling — the telegraph guarantee survives the added delay by construction.
@export var rush_momentum_vent_refractory_max: float = 1.2  # feel-tune

## The APPROACH PHASE (Tim 2026-07-19): the hazard roll SPAWNS a vent event instead of opening
## its window instantly, and this is the travel time (seconds of tick time) of the incoming
## event bar from the bar's right edge to the target — the telegraph lead the player watches
## before the window opens and the gesture clock starts. Frenzy freeze pauses the flight.
## Shortened 2.0 → 1.2 with the property freeze (Tim 2026-07-19: "2 seconds feels leisurely —
## I want to see it coming but not feel like I'm waiting for it"). The shorter flight also
## attacks the sloppy free ride at its root — less riskless telegraph pay bundled with every
## check — which, together with the freeze, is what let the fail sting drop to zero below.
@export var rush_momentum_vent_approach_seconds: float = 1.2  # feel-tune

## Seconds the player has to COMPLETE the gesture once a window telegraphs — the TIER-0 base
## of the escalating duration (each tier multiplies it by duration_decay).
@export var rush_momentum_vent_window_duration: float = 1.0  # feel-tune

## Per-tier multiplier on the window duration (escalation axis 2, SPEED). Retuned from the
## plan's first-cut 0.92: at 0.92 a ×3 window becomes too short for even a brisk clean triple
## right when triples begin (~tier 6 — a hard cliff, before the escalating gestures' odds
## ever get to bite); 0.975 keeps deep windows tight but finishable into the teens, so runs
## end the designed way — a blown beat on an ever-faster, ever-more-complex gesture.
@export var rush_momentum_vent_duration_decay: float = 0.975  # feel-tune

## The duration floor (seconds): the escalating window never shrinks below this — a shorter
## window stops being a skill check and becomes a reflex lottery.
@export var rush_momentum_vent_duration_floor: float = 0.45  # feel-tune

## Tiers between lift escalations (escalation axis 3, COMPLEXITY): required lifts =
## 1 + tier / this (integer division), so 3 = single at tiers 0-2, double from tier 3, triple
## from tier 6. HARD-CAPPED at 3 lifts in code — a quad-pump is thumb mush (Tim 2026-07-18);
## past ×3 the cadence and speed axes carry the difficulty alone.
@export var rush_momentum_vent_lifts_step_tiers: int = 3  # feel-tune

## Max gap between gesture beats — finger-up time before the re-press must land (seconds).
@export var rush_momentum_vent_gap_max: float = 0.40  # feel-tune

## Max press length that still counts as the ×2 gesture's middle tap (seconds); a longer hold
## is a fumbled re-hold, which misses the window.
@export var rush_momentum_vent_tap_max: float = 0.25  # feel-tune

## Heat vented on a successful gesture (floored at the cruise point — success never ends the
## ride). Retuned 0.15 → 0.06 for the endless model: smaller than the heat built between
## checks, so the bar CREEPS TOWARD THE CEILING as tiers deepen — deep runs visibly ride just
## under the backstop (drama AND pay: the overdrive bonus scales with how high the bar sits,
## and under the depth hazard so does the check cadence). A success additionally clamps heat
## down just enough that the next window always fits (see RushMomentumState._succeed_vent —
## the telegraph guarantee's other half).
@export var rush_momentum_vent_heat_drop: float = 0.06  # feel-tune

## Bonus added to the ladder's peak per successful vent (0.30 = +30 percentage points), with
## NO cap — the difficulty curve is the brake, not the reward curve (Tim 2026-07-18). The peak
## is only ever tasted near the top of a deep ride (a median skilled run tops out around
## +55% + 8 × 30% = +295% peak, held for seconds; the honest long-session average is the ~+75%
## the sim measures). Trimmed 0.60 → 0.30 for the approach phase (2026-07-19): every check now
## carries approach_seconds of paid telegraph riding, so the same tier pays for roughly twice
## as long — at the old step even a 70%-reliability rider out-earned cruise, killing the risk.
@export var rush_momentum_vent_bonus_step: float = 0.30  # feel-tune

## Extra re-arm seconds per achieved vent tier when an excursion overheats — falling from
## higher hurts more. Applied BEFORE the Rapid Restart lockout scale (which divides the total).
## ZEROED with the OVERHEAT PROPERTY FREEZE (Tim 2026-07-19). The sting had been ratcheted up
## (3 → 6 → 12) solely to keep a sloppy rider from out-earning cruise; the freeze now carries
## that deterrent for real — an overheat takes the rushed property itself offline for the
## whole lockout, a cost proportional to what was gambled — and the sim's freeze-priced gates
## actually FORCE the sting down: at the original 3.0/9.0 a skilled venter nets only +45%
## (below the +62% worth-the-risk floor), and ~1.0/3.0 is the highest sting that still
## passes. Zero is both the floor the gates allow and Tim's stated direction ("failure
## pressure from difficulty, not timeouts"); falling from higher STILL hurts more, because a
## higher fall drains longer and the frozen property is dark for all of it. The knob stays
## live in Balance Tuning should device feel want a token sting back (keep ≤ ~1.0 s/tier).
@export var rush_momentum_vent_fail_rearm_per_tier: float = 0.0  # feel-tune

## Cap on the per-tier re-arm sting (seconds). Deep runs must NOT earn ever-longer timeouts —
## Tim's direction (2026-07-18) is that failure pressure comes from the difficulty curve, not
## the punishment; past this the fall costs the same no matter how high it was from. Zeroed
## with the per-tier sting above (the property freeze is the punishment now — see its tune
## note); the cap machinery stays in code and in the panel for the same what-if reason.
@export var rush_momentum_vent_fail_rearm_cap: float = 0.0  # feel-tune

## Heat drained per second while OVERHEATED (the locked cooldown). 0.16 ≈ a 10 s lockout from a
## full 1.6 ceiling; the visibly draining bar is the cooldown display.
@export var rush_momentum_locked_drain_per_second: float = 0.16  # feel-tune

## Extra delay (seconds) after an overheated property fully cools before rushing re-enables —
## the extra sting Tim asked for beyond the drain itself.
@export var rush_momentum_rearm_seconds: float = 1.5  # feel-tune

## Grace window (seconds): you still count as "rushing" for momentum this long after your last
## rush. Must exceed the rush pulse interval (1 / hold_rush_per_second = 0.2 s at 5/s) so momentum
## keeps building smoothly BETWEEN the discrete auto-rush pulses instead of bleeding in the gaps.
@export var rush_momentum_grace_seconds: float = 0.5  # feel-tune

## Haptic pulse lengths (milliseconds) for the momentum bar's feedback beats: the long thump on
## overheating and the tick when rushing re-arms. Live knobs so the haptic device pass can be
## dialed on the phone without a code round-trip (phones vary a lot in how a given pulse length
## feels). 0 disables that pulse. (The old Critical band-crossing tap retired with its band —
## the vent telegraphs are the drama now.)
@export var rush_momentum_haptic_overheat_ms: float = 200.0  # feel-tune
@export var rush_momentum_haptic_ready_ms: float = 40.0  # feel-tune

## The vent-window telegraph's own pulse — long enough that "act NOW" is distinguishable by
## feel alone with the eyes on the property row (plan follow-up item). The telegraph fires ONE
## PULSE PER REQUIRED LIFT (Tim 2026-07-20): a x2 window buzzes twice, a x3 three times, so the
## thumb learns the demand before the eyes read the pips — deliberate redundant encoding for the
## moment the mechanic is fastest.
@export var rush_momentum_haptic_vent_ms: float = 80.0  # feel-tune

## Silence between those telegraph pulses (milliseconds). Without a gap a x3 window would feel
## like one long buzz rather than three counted beats, which is the whole point of the pulse
## train. 0 runs the pulses back-to-back.
@export var rush_momentum_haptic_vent_gap_ms: float = 70.0  # feel-tune

# --- Estate & tax (Spec §9) ---

## Base estate-tax exemption in dollars.
@export var estate_exemption_base: float = 1000000.0  # TBD-SIM

## Base estate tax rate (0–1). Intentionally brutal; loophole tree is the relief.
@export var estate_tax_rate_base: float = 0.60  # TBD-SIM

## Floor for the estate tax rate after loopholes (can never go below this).
@export var loophole_rate_floor: float = 0.05  # TBD-SIM

# --- Legacy / prestige (Spec §9.3–9.4) ---

## Coefficient on the Legacy gain curve (see EstateWaterfall.legacy_gain): legacy =
## floor(K_LEGACY × (estate_net / floor) ^ ALPHA), where the floor is EstateWaterfall.LEGACY_BASE.
## Raised 0.045 → 0.50 (Tim 2026-07-14) to keep the FIRST prestige near its old ~350 gems after
## alpha_legacy was lowered to 0.22 — the two move together (a lower exponent needs a higher
## coefficient to hold the same yield at the founder's estate scale).
@export var k_legacy: float = 0.50  # feel-tune

## Exponent on the estate-magnitude term of the Legacy curve — how fast gems grow with earnings.
## Lowered 0.30 → 0.22 (Tim 2026-07-14) to flatten the prestige runaway (at 0.30 the yield compounded
## ~18× per epoch, driving income to ×237 over a dynasty); paired with the upgrade-cost nerf below so
## the correction is split. Still rewards a better run (~+16% gems per 2× estate), just less punchy.
@export var alpha_legacy: float = 0.22  # feel-tune

## Global multiplier on EVERY Legacy upgrade's cost (LegacyUpgradeCatalog.cost_multiplier). 1.0 = the
## authored prices; >1 makes a prestige's gems buy fewer upgrade levels, the second brake (with the
## lower alpha_legacy) on the multiplier runaway that made late epochs trivial (Tim 2026-07-14).
@export var legacy_upgrade_cost_multiplier: float = 2.0  # feel-tune

# Note: the old k_sprint / beta_sprint / k_residual constants were removed when
# Legacy became a spendable upgrade currency. Per-level upgrade magnitudes and
# costs now live in LegacyUpgradeCatalog.gd, not here.

# --- Prestige minigame (GDD §5.5, Spec §9.3) ---
# At prestige the player plays a minigame whose performance sets how much of the run's base
# Legacy they KEEP: legacy_awarded = floor(base_legacy × mult). Reward curve reshaped (Tim,
# work item 4, 2026-07-10) so standard play is NEUTRAL, not punishing: the multiplier is
# minigame_keep_floor at performance 0 (a MODEST downside now, not half), exactly 1.0 at
# performance minigame_full_performance ("standard" play — the same value a skip / minigame-off
# banks), and up to 1.0 + bonus at performance 1.0 (a modest upside). The extra-high bonus cap
# comes from LegacyUpgrades.minigame_bonus_max() (0.25 base, +5%/level via Family Reputation).

## Fraction of the base Legacy kept on the WORST result (performance 0). Reshaped to a MODEST
## downside (Tim, work item 4): a bad round loses only a little, it no longer costs half. A skip /
## minigame-off banks 1.0 (full), not this floor.
@export var minigame_keep_floor: float = 0.9  # feel-tune

## The performance (0..1) that maps to exactly 1.0 — "standard" play, the neutral result. Below it
## the reward eases down toward minigame_keep_floor (modest downside); above it, up into the bonus
## (modest upside). Match-3 anchors its "full" score to this point (see MatchThreeMinigame).
@export var minigame_full_performance: float = 0.5  # feel-tune

## Gems cleared to keep the FULL base Legacy (multiplier exactly 1.0). The multiplier
## scales linearly from the floor (score 0) up to 1.0 at this score.
@export var minigame_full_score: float = 100.0  # feel-tune

## Gems cleared to reach the MAX extra-high bonus (multiplier 1.0 + bonus_max). Between
## full_score and this, the multiplier scales linearly from 1.0 into the bonus.
@export var minigame_extra_score: float = 200.0  # feel-tune

## How long one minigame round lasts, in seconds. Every type is tuned to a ~20s round
## (Tim, 2026-06-25) — scoring targets in each minigame assume this length.
@export var minigame_duration_seconds: float = 25.0  # feel-tuned on device (Tim, 2026-07-09)

# --- Match-3 difficulty (Tim, 2026-07-09: "too easy, I max it every time") ----------
# The match-3 game maps its own running score onto the host's reward curve; these two knobs set
# that mapping's difficulty and are live-tunable so Tim can dial the ceiling on device without a
# rebuild. Higher score targets = harder to reach "full"/"max". (Cascade combos were REMOVED this
# pass — subsequent matches now score statically by gem count only, so luck no longer inflates the
# score; there is no combo knob anymore.)

## Match-3 score that maps to the host's "full" line (keep 100%) — roughly a whole round of
## ordinary clean matching. Below this is a "bad" result (keeps less). Tim device-tuned to 600.
@export var match3_full_score: float = 600.0  # feel-tune

## Match-3 score that maps to performance 1.0 (the max extra-high bonus, and the early-out).
## Raised well above the old 1000 so a single lucky chain can no longer max the round — the
## player must sustain strong play to reach it.
@export var match3_max_score: float = 2200.0  # feel-tune

## How many gems a single match must contain to drop a Legacy gem (at the swap's target cell).
## Higher = Legacy gems are rarer. Match-3 has no other way to spawn them.
@export var match3_legacy_match_size: int = 4  # feel-tuned on device (Tim, 2026-07-09)

# --- Legacy Bonus (Plans/Legacy_Bonus_System.md; Tim, 2026-07-09) --------------------
# Every minigame has a small, game-specific chance to let the player collect a bonus Legacy gem.
# The grant is a share of the dynasty's lifetime-earned Legacy, gated by the round's overall result.
# All first-pass — device-tune the chances, the fraction, and the great-round bonus.

## Legacy granted per collected gem, as a fraction of lifetime-earned Legacy (0.001 = 0.1%).
@export var legacy_bonus_fraction: float = 0.001  # feel-tune

## Most legacy "moments" a single round can bank. 1 = every game's bonus is worth the same (a clean
## windfall); raise to make the grant scale with how many gems the player collected in the round.
@export var legacy_bonus_max_gems: int = 1  # feel-tune

## Multiplier applied to the legacy grant on a GREAT round (top bonus band). 1.10 = +10%.
@export var legacy_bonus_great_multiplier: float = 1.10  # feel-tune

## How far into the host's bonus band (0..1) a round must reach to count as GREAT for the legacy
## bonus. Below the "full" line = bad (keep nothing); at/above full but under this = normal.
@export var legacy_bonus_great_threshold: float = 0.75  # feel-tune

## Extra multiplier on the Legacy-gem grant at a FIRST CONTACT (epoch-transition) minigame only —
## reaching a new civilization is a milestone, so its gem is worth much more than a routine
## welcome-back / succession gem (Tim 2026-07-12: the epoch-transition gem paid too few gems).
## 1.0 = same as any other site; higher = a bigger epoch-transition windfall.
@export var legacy_bonus_first_contact_multiplier: float = 10.0  # feel-tune

## Per-game chance a Legacy gem becomes available in a round (small), a per-round appearance chance.
## (Match-3 has NO random chance — its Legacy gems come only from 5+ matches — so it has no knob.)
@export var legacy_gem_chance_catch: float = 0.12  # feel-tune
@export var legacy_gem_chance_timing: float = 0.12  # feel-tune
@export var legacy_gem_chance_balance: float = 0.15  # feel-tune
@export var legacy_gem_chance_basketball: float = 0.15  # feel-tune

# --- Basketball launch curve (Tim, 2026-07-10: device-tunable throw feel) ------------
# The slingshot throw speed = (drag / basketball_launch_max_drag, clamped 0..1) ^
# basketball_launch_curve_exp × basketball_max_throw_speed. Higher exponent = gentler low end
# (finer aim control); larger max-drag = more pull needed for full power; larger max-speed = more
# raw power. All feel-tune.
@export var basketball_launch_curve_exp: float = 1.7   # feel-tune
@export var basketball_launch_max_drag: float = 200.0  # feel-tune (px)
@export var basketball_max_throw_speed: float = 2900.0  # feel-tune (px/sec)

## Memory's Legacy gem is a chance-gated BONUS ROUND, offered only after the player clears the whole
## game (all 6 rounds). This is the per-run chance that bonus round appears once they've earned it.
@export var legacy_gem_chance_memory: float = 0.15  # feel-tune

## How many taps the Memory bonus round's sequence is. In that round all four pads look identical
## (each wears the gem), so this is recalled by pure position — the Memory gem's difficulty lever.
## Higher = harder to earn. Starts at 5 (Tim, 2026-07-10).
@export var memory_gem_sequence_length: int = 5  # feel-tune


# --- Events (Spec §10) ---

## Income multiplier during a Market Crash event.
@export var crash_multiplier: float = 0.5  # TBD-SIM

## Duration of a Market Crash event in active minutes.
@export var crash_duration_minutes: float = 10.0  # TBD-SIM

## Settlement cost as a fraction of net worth during The Audit.
@export var audit_settle_rate: float = 0.08  # TBD-SIM

## Legislative Assets units required to make an audit case evaporate.
@export var audit_threshold: int = 1  # TBD-SIM (placeholder)

# --- Win condition (GDD §10) ---

## Total money in Earth's economy; capturing this wins the planet.
@export var earth_economy_target: float = 103_600_000_000_000.0  # $103.6T, confirm GDD §14.3

# --- Save ---

## Autosave interval in seconds.
@export var autosave_cadence: float = 10.0
