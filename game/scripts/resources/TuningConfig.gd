class_name TuningConfig
# PROVENANCE: docs/Tuning_Record.md records where each number came from — which were FITTED by a
# named study (do not change those freely; re-run the study), which are feel-tunes, and the two that
# currently ship at values DIFFERENT from the ones Tim seeded. The comments below say what a knob
# does; that document says how much rests on it.
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
@export var band_step: float = 1.1  # TBD-SIM; synced to tuning.tres 2026-07-31

# --- Cycles & milestones (Spec §3.3) ---

## Minimum cycle length a property can reach via milestone speed-ups, in seconds.
@export var cycle_floor: float = 1.0  # TBD-SIM

# --- Active tapping (Spec §4) ---

## Fraction of cycle_length that one rush-tap advances the cycle.
@export var rush_pct: float = 0.1  # TBD-SIM; synced to tuning.tres 2026-07-31

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
@export var buy_hold_initial_delay: float = 0.2  # feel-tune; synced to tuning.tres 2026-07-31
## Seconds between each BUY auto-repeat after the first.
@export var buy_hold_repeat_interval: float = 0.1  # device-tuned (Tim, 2026-07-20)
## Seconds a held HIRE/UPGRADE button waits before its first auto-repeat.
@export var hire_hold_initial_delay: float = 0.2  # feel-tune; synced to tuning.tres 2026-07-31
## Seconds between each HIRE/UPGRADE auto-repeat after the first.
@export var hire_hold_repeat_interval: float = 0.1  # device-tuned (Tim, 2026-07-20)

## How many units of an epoch's FLAGSHIP (its most expensive property) you must own before
## that epoch will advance — the non-dollar half of the advance gate.
##
## WHY THIS EXISTS (Tim, device report 2026-07-30): an epoch used to end the instant the
## roster was complete, so the flagship — the property the epoch is named for — got almost
## no playtime. `sim/EpochPhaseStudy.gd` measured the post-roster "stack" phase at 0.3% of
## an epoch, and showed that no DOLLAR-denominated fix works: end-of-epoch income grows
## super-exponentially, so a 10x money threshold is crossed in seconds and reshaping the
## cost ladder does nothing. A UNIT requirement is different in kind because it can only be
## satisfied AFTER the roster is complete, in the calmer post-unlock growth regime.
##
## DELIBERATE EXCEPTION to the "defaults mirror tuning.tres" convention: the shipped value is
## 35, but this default stays 1. 1 reproduces the pre-feature behaviour exactly (owning one of
## each already implies one flagship), so any code path that builds a TuningConfig without the
## resource degrades to the old gate rather than to a hard 35-unit wall it never asked for.
## Not drift — if a defaults-vs-tres audit flags this key, this comment is the answer.
@export var epoch_flagship_units_required: int = 1  # device-tune; shipped value lives in tuning.tres

# --- Auto-purchase mode (Plans/Auto_Purchase_And_Bulk_Hire.md §A3) ---
# The "Acquisitions Desk" Legacy upgrade buys property on the player's behalf: every CADENCE
# seconds it buys up to N units each of the BREADTH cheapest affordable properties on the
# targeted civ tab. Cadence shrinks with upgrade level, from the base down to the floor:
#   cadence = auto_purchase_base_cadence − 0.25 × (level − 1), floored at auto_purchase_min_cadence
# The per-level MAGNITUDES (N, and the 0.25 step) live in LegacyUpgradeCatalog, which is where
# per-level upgrade numbers now belong; only the shape of the cadence curve is tuned here.

## Seconds between auto-purchase ticks at upgrade level 1 — the slowest the desk ever runs.
@export var auto_purchase_base_cadence: float = 3.0  # device-tune
## Floor on the auto-purchase cadence, reached at the top upgrade level. Guards against a
## cadence that shrinks to zero and turns the mode into a per-frame buyer.
@export var auto_purchase_min_cadence: float = 1.0  # device-tune
## How many DISTINCT properties one auto-purchase tick buys into (X in the plan). Fixed rather
## than upgradable: a cohort is only ~14 properties, so breadth saturates almost immediately
## and stops being worth selling as an upgrade level.
@export var auto_purchase_breadth: int = 3  # device-tune

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
## Synced 4.0 → 5.6 to match tuning.tres (2026-07-31). It had drifted, which mattered more than
## usual here because frenzy_pop_floor is SOLVED from this value — at the stale 4.0 the "weakest
## pop is 2×" floor would be 1/3, not 1/4.6. Keep the two in step.
@export var frenzy_max_multiplier: float = 5.6  # feel-tune M1

## Duration of a full-charge frenzy burn in seconds.
@export var frenzy_burn_duration: float = 30.0  # feel-tune M1; synced to tuning.tres 2026-07-31

## Meter fill added per tap (fraction of full bar, 0–1).
@export var frenzy_fill_per_tap: float = 0.004  # feel-tune M1

## Meter decay rate per second when idle (fraction of full bar, 0–1).
@export var frenzy_decay_per_second: float = 0.005  # feel-tune M1

## Seconds without a tap before decay begins.
@export var frenzy_idle_grace: float = 5.0  # feel-tune M1

## Minimum meter charge at which the player can trigger a frenzy pop.
##
## SOLVED, not hand-picked (Tim, 2026-07-31): the floor is set so a NEW player's weakest
## possible pop is exactly 2×. A pop pays `1 + (frenzy_max_multiplier − 1) × intensity × meter`
## (FrenzyState.pop), and a fresh dynasty has intensity 1.0, so
##     floor = 1 / (frenzy_max_multiplier − 1) = 1 / 4.6 = 0.2174
## It was 0.15 (a 1.69× worst pop — the floor barely gated anything and cashing in early locked
## a weak multiplier), briefly 0.30 (2.38×) before landing on the exact-2× solve.
##
## THIS VALUE DEPENDS ON frenzy_max_multiplier. Change that and this stops meaning 2×; re-solve
## it. Killer Instinct raises intensity above 1.0, so an invested bloodline's worst pop is
## higher than 2× by design — the floor pins the new player's case only.
##
## The bar's floor marker and its grayscale-until-poppable treatment both read this, so they
## follow automatically.
@export var frenzy_pop_floor: float = 0.2174  # solved for a 2× worst pop

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
## spacing read as random again without touching the depth-hazard curve itself. Tick-time
## rather than OS time, so a pause or scene reload can never eat part of the breather.
## (This comment used to say the frenzy freeze pauses it "like every other vent clock" —
## that freeze was REMOVED 2026-07-19; the vent game now runs straight through a burn.
## See RushMomentumState.gd:323-330.)
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
@export var rush_momentum_vent_approach_seconds: float = 0.7  # device-tuned (Tim, 2026-07-20)

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
@export var k_legacy: float = 0.16  # feel-tune; synced to tuning.tres 2026-07-31 (prestige retune)

## Exponent on the estate-magnitude term of the Legacy curve — how fast gems grow with earnings.
## Lowered 0.30 → 0.22 (Tim 2026-07-14) to flatten the prestige runaway (at 0.30 the yield compounded
## ~18× per epoch, driving income to ×237 over a dynasty); paired with the upgrade-cost nerf below so
## the correction is split. Still rewards a better run (~+16% gems per 2× estate), just less punchy.
@export var alpha_legacy: float = 0.35  # feel-tune; synced to tuning.tres 2026-07-31 (prestige retune)

## Global multiplier on EVERY Legacy upgrade's cost (LegacyUpgradeCatalog.cost_multiplier). 1.0 = the
## authored prices; >1 makes a prestige's gems buy fewer upgrade levels, the second brake (with the
## lower alpha_legacy) on the multiplier runaway that made late epochs trivial (Tim 2026-07-14).
@export var legacy_upgrade_cost_multiplier: float = 3.0  # feel-tune; synced to tuning.tres 2026-07-31 (prestige retune)

## The estate net where the Legacy mint curve BENDS (Plans/Endgame_Economy.md, Tim 2026-07-28):
## below this the approved alpha_legacy power curve applies exactly; above it the shallow
## alpha_legacy_deep exponent takes over, so deep-frontier estates (1e80+) mint ~billions
## instead of septillions — big numbers that still read as valuable.
@export var legacy_knee_net: float = 1e21  # feel-tune (~the $1-sextillion estates the curve was tuned on)

## The mint curve's exponent ABOVE the knee — how fast gems keep growing once estates pass
## the tuned range. 0.06 = a 10x deeper estate mints ~+15% more gems (Tim: endgame mints
## should read in the BILLIONS; the old single-exponent curve ran to septillions).
@export var alpha_legacy_deep: float = 0.05  # feel-tune

## The upgrade shop's cost STEEPENING (LegacyUpgradeCatalog.cost_steepening): each level's
## cost-growth factor is itself multiplied by this per level, so the curve starts near the
## authored per-level growth and steepens without limit — the uncapped compounders' real
## brake (Plans/Endgame_Economy.md "Shape 2", Tim 2026-07-28). 1.0 = the old flat geometric.
@export var legacy_cost_steepening: float = 1.1  # fit: DynastyArcStudy (1.03 seed missed the dozen-run summit)

# Note: the old k_sprint / beta_sprint / k_residual constants were removed when
# Legacy became a spendable upgrade currency. Per-level upgrade magnitudes and
# costs now live in LegacyUpgradeCatalog.gd, not here.

# --- Challenge Mode tier ladders (Plans/Challenge_Mode.md) ---
# Each minigame climbs a FINITE authored ladder (tier = floor(score / per-game STEP), capped at tier
# 30); a payout lands every 5th tier on a single schedule shared by all games, alternating income and
# Legacy-yield and escalating in value, so each game maxes at +4% income + +4% Legacy (~24/24 across
# all six — Tim's ~25/25 target). The payout schedule and per-game STEP live in ChallengeGoals; these
# three knobs are the live-tunable global levers. All FIRST-PASS, device-tune.

## Global multiplier on every Challenge tier payout, both tracks. 1.0 = the authored schedule (~24/24
## across all six games). Raise to make mastery pay more, lower to soften it. Plans/Challenge_Mode.md.
@export var challenge_bonus_scale: float = 1.0  # feel-tune

## The Challenge keep-alive run TIMER's starting seconds — a run begins with this little on the clock
## and drains until scoring tops it up (Wave 2 mechanic; ChallengeGoals reads it). Plans/Challenge_Mode.md.
@export var challenge_timer_start_seconds: float = 6.0  # feel-tune

## The Challenge keep-alive run TIMER's maximum seconds — top-ups never bank the clock past this, so a
## strong streak can't stockpile a huge cushion (Wave 2 mechanic). Plans/Challenge_Mode.md.
@export var challenge_timer_cap_seconds: float = 15.0  # feel-tune

## Fraction of a hit's time-gain that a MISS costs the keep-alive timer, in challenge minigames (0.5 =
## half). A dropped Catch coin / a failed Timing lock drains this ratio x what catching/landing it would
## have added, so missing hurts proportionally to the hit it replaced. Plans/Challenge_Mode.md.
@export var challenge_miss_penalty_ratio: float = 0.5  # feel-tune

## 1 = the CHALLENGES screen shows EVERY minigame regardless of which ones the bloodline has met
## at a transition; 0 = only the met ones (the shipped rule, Roadmap §8). A dev/testing switch: six
## games are dealt at random, so reaching one specific game otherwise means replaying transitions
## until it comes up. DISPLAY ONLY — it never writes to the met set, so turning it off restores the
## real progress. A 0/1 float rather than a bool because the Balance Tuning panel only renders int
## and float properties (same convention as carb_debug_overlay).
@export var challenge_show_all_games: float = 0.0

# --- Challenge Mode: the two low-ceiling games' ESCALATING per-tier cost (Plans/Challenge_Mode.md) ---
# Micro Basketball (baskets sunk) and Memory Match (climbs completed) have a small get_score() ceiling,
# so a flat STEP is a bad fit. Instead each tier costs min(base + floor((tier-1)/5) x increment, cap) in
# that game's score units — cheap early, pricier every 5 tiers, capped. ChallengeGoals reads these.
# ALL FIRST-PASS, DEVICE-TUNE.

## Micro Basketball: cost (baskets) of each tier for tiers 1-5. At 1, tier 5 = 5 baskets (first payout).
@export var basketball_tier_base_cost: float = 1.0  # feel-tune
## Micro Basketball: added to the per-tier basket cost every 5 tiers (tier 6-10 cost base+this, etc.).
@export var basketball_tier_cost_increment: float = 1.0  # feel-tune
## Micro Basketball: the most a single tier can cost (baskets) — the escalation caps here.
@export var basketball_tier_cost_cap: float = 5.0  # feel-tune
## Micro Basketball: keep-alive seconds each sunk basket adds to the run clock (baskets are slow to
## line up, so a fat top-up). One of six per-game keep-alive knobs (each game has one);
## ChallengeGoals.seconds_per_point reads them.
@export var basketball_keepalive_seconds_per_point: float = 3.5  # feel-tuned on device (Tim, 2026-07-22)

## Memory Match: cost (climbs) of each tier for tiers 1-5. At 0.2, tier 5 ≈ 1 climb (first payout).
@export var memory_tier_base_cost: float = 0.2  # feel-tune
## Memory Match: added to the per-tier climb cost every 5 tiers.
@export var memory_tier_cost_increment: float = 0.2  # feel-tune
## Memory Match: the most a single tier can cost (climbs) — the escalation caps here.
@export var memory_tier_cost_cap: float = 1.0  # feel-tune
## Memory Match: keep-alive seconds each completed climb adds to the run clock (a climb is a big beat).
@export var memory_keepalive_seconds_per_point: float = 4.0  # feel-tune

# --- Balance the Books CHALLENGE-mode knobs (Plans/Challenge_Mode.md) ---
# Balance's challenge round scores by time-in-zone. These four knobs shape the challenge feel and are
# read by BalanceMinigame ONLY in challenge mode (the prestige/reward round keeps its own constants).
# ALL FIRST-PASS, DEVICE-TUNE.

## In-zone seconds needed to earn ONE Balance challenge point (get_score = time_in_zone / this).
@export var balance_seconds_per_point: float = 1.0  # feel-tune
## Keep-alive seconds each Balance challenge point adds to the run clock (ChallengeGoals.seconds_per_point).
@export var balance_keepalive_seconds_per_point: float = 2.0  # feel-tune
## Seconds between the Balance gold-zone re-rolling a new target center (challenge mode).
@export var balance_zone_reroll_seconds: float = 1.3  # feel-tune
## How fast the Balance gold-zone eases toward its target center, per second (challenge mode).
@export var balance_zone_ease: float = 1.6  # feel-tune

# --- Challenge Mode: the three FLAT games' keep-alive seconds-per-point (Plans/Challenge_Mode.md) ---
# Match Three, Timing Bar and Catch the Money score on a flat STEP (no per-game tier knobs), but their
# keep-alive top-up per point is still worth dialing. Sized inversely to how fast each scores so a
# top-up feels comparable — Match Three racks up points in bulk (tiny per-point top-up), the slower
# games grant a fat second or more. Defaults mirror ChallengeGoals' old SECONDS_PER_POINT table.
# ALL FIRST-PASS, DEVICE-TUNE.

## Match Three: keep-alive seconds each point adds to the run clock (points arrive in bulk, so tiny).
@export var match3_keepalive_seconds_per_point: float = 0.012  # feel-tune
## Timing Bar: keep-alive seconds each successful lock adds to the run clock.
@export var timing_keepalive_seconds_per_point: float = 0.9  # feel-tuned on device (Tim, 2026-07-22)
## Catch the Money: keep-alive seconds each caught coin adds to the run clock.
@export var catch_keepalive_seconds_per_point: float = 1.5  # feel-tune

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

# --- Match-3 difficulty & scoring (Tim, 2026-07-09) ----------
## Match-3 score that maps to the host's "full" line (keep 100%) — roughly a whole round of
## ordinary clean matching. Below this is a "bad" result (keeps less). Tim device-tuned to 600.
@export var match3_full_score: float = 600.0  # feel-tune

## Match-3 score that maps to performance 1.0 (the max extra-high bonus, and the early-out).
## Raised well above the old 1000 so a single lucky chain can no longer max the round.
@export var match3_max_score: float = 2200.0  # feel-tune

## How many gems a single match must contain to drop a Legacy gem (at the swap's target cell).
@export var match3_legacy_match_size: int = 4  # feel-tuned on device (Tim, 2026-07-09)

## Base score points awarded per gem in a match. Scales the entire point economy.
@export var match3_points_per_gem: float = 10.0  # feel-tune

## Score bonus multiplier per extra gem in matches >3 (n gems = base × n × (1 + size_bonus × (n-3))).
@export var match3_size_bonus: float = 0.5  # feel-tune

## Score multiplier bonus for match groups that avoid the designated Avoid Gem (+15% = 1.15).
@export var match3_clean_match_factor: float = 1.15  # feel-tune

## Score penalty multiplier for match groups containing the Avoid Gem (-60% = 0.40).
@export var match3_avoid_match_factor: float = 0.40  # feel-tune

## Challenge Mode: score multiplier for matching 5th-type Legacy gems (2.5x).
@export var match3_legacy_score_mult: float = 2.5  # feel-tune

# --- Micro Basketball Physics & Geometry (Tim, 2026-07-10) ------------
## Baskets sunk to reach performance 1.0 (full reward) in a standard round.
@export var basketball_target_baskets: int = 6  # feel-tune

## Slingshot throw speed curve exponent (higher = gentler low end, finer aim).
@export var basketball_launch_curve_exp: float = 1.7   # feel-tune

## Drag distance (px) for maximum launch speed.
@export var basketball_launch_max_drag: float = 200.0  # feel-tune (px)

## Maximum throw velocity cap in px/sec.
@export var basketball_max_throw_speed: float = 2900.0  # feel-tune (px/sec)

## Downward gravity acceleration in px/sec^2.
@export var basketball_gravity: float = 2400.0  # feel-tune

## Fraction of velocity retained on bouncing off walls, hoop, and floor.
@export var basketball_restitution: float = 0.46  # feel-tune

## Ball radius in pixels (thumb-sized).
@export var basketball_ball_radius: float = 53.2  # feel-tune

## Hoop horizontal ellipse radius in pixels.
@export var basketball_hoop_rx: float = 94.3  # feel-tune

## Hoop vertical ellipse radius in pixels.
@export var basketball_hoop_ry: float = 34.5  # feel-tune

# --- Balance the Books Physics & Zones --------------------------------
## Half-height of the gold zone as a fraction of the track (0.11 = 22% total height).
@export var balance_zone_half: float = 0.11  # feel-tune

## Upward acceleration while holding the lift button (track-fractions/sec^2).
@export var balance_lift_accel: float = 3.0  # feel-tune

## Downward gravity acceleration (track-fractions/sec^2).
@export var balance_gravity: float = 1.9  # feel-tune

## Velocity damping factor per second.
@export var balance_damping: float = 1.8  # feel-tune

## Velocity bounce restitution when hitting the top or bottom of the track.
@export var balance_edge_bounce: float = 0.35  # feel-tune

## Seconds of continuous holding inside the zone to fill and collect the bonus Legacy gem.
@export var balance_gem_fill_seconds: float = 2.2  # feel-tune

## Seconds to drain a full gem progress bar back to empty when drifting outside the zone.
@export var balance_gem_drain_seconds: float = 4.5  # feel-tune

# --- Timing Bar Sweep & Windows ---------------------------------------
## Number of successful locks required to complete a full round.
@export var timing_target_locks: int = 10  # feel-tune

## Freeze pause duration (seconds) when a lock is pressed to show hit burst.
@export var timing_freeze_time: float = 0.5  # feel-tune

## Half-width of the gold target zone at game start (fraction of bar).
@export var timing_zone_half: float = 0.12  # feel-tune

## Minimum half-width the gold zone shrinks to at final lock.
@export var timing_zone_half_min: float = 0.045  # feel-tune

## Initial marker sweep speed (bar-fractions per second).
@export var timing_base_speed: float = 0.9  # feel-tune

## Sweep speed multiplier applied after each successful lock (1.09 = +9%/lock).
@export var timing_speed_ramp: float = 1.09  # feel-tune

## Challenge Mode: period in seconds for one full slow-fast-slow sweep wave.
@export var timing_challenge_speed_period: float = 8.0  # feel-tune

## Challenge Mode: center glide drift speed of the gold zone (bar-fractions/sec).
@export var timing_challenge_zone_drift_mid: float = 0.08  # feel-tune

# --- Catch the Money Timing, Physics & Challenge Waves ----------------
## Coins spawned for a full standard game.
@export var catch_target_coins: int = 18  # feel-tune

## Starting spawn interval between falling coins (seconds).
@export var catch_spawn_interval_start: float = 0.55  # feel-tune

## Final spawn interval between falling coins during the late-round rush (seconds).
@export var catch_spawn_interval_end: float = 0.38  # feel-tune

## Base vertical fall speed of coins in px/sec.
@export var catch_fall_speed: float = 340.0  # feel-tune

## Penalty fraction deducted from net score for a missed coin.
@export var catch_miss_penalty: float = 0.75  # feel-tune

## Coin size shrink multiplier applied on each catch (0.95 = 5% smaller).
@export var catch_shrink_factor: float = 0.95  # feel-tune

## Challenge Mode: fixed spawn interval between coins (seconds).
@export var catch_challenge_spawn_interval: float = 0.60  # feel-tune

## Challenge Mode: duration of one easy->hard->easy difficulty wave in seconds.
@export var catch_challenge_wave_period: float = 9.0  # feel-tune

## Challenge Mode: peak horizontal sway drift amplitude in pixels.
@export var catch_challenge_sway_amplitude: float = 45.0  # feel-tune

## Challenge Mode: spawn chance for high-value green Premium Coins (0.06 = 6%).
@export var catch_premium_coin_chance: float = 0.06  # feel-tune

## Challenge Mode: score value awarded for catching a Premium Coin.
@export var catch_premium_score_value: int = 3  # feel-tune

# --- Memory Match Recall & Timing -------------------------------------
## Number of sequence rounds required to complete a full game.
@export var memory_target_rounds: int = 6  # feel-tune

## Duration in seconds a pad stays lit during sequence playback.
@export var memory_flash_on: float = 0.42  # feel-tune

## Silence gap in seconds between pad flashes during playback.
@export var memory_flash_gap: float = 0.18  # feel-tune

## Visual scale multiplier applied to a pad while lit (1.14 = +14% zoom).
@export var memory_pad_flash_scale: float = 1.14  # feel-tune

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
@export var legacy_gem_chance_catch: float = 0.12  # feel-tune
@export var legacy_gem_chance_timing: float = 0.12  # feel-tune
@export var legacy_gem_chance_balance: float = 0.15  # feel-tune
@export var legacy_gem_chance_basketball: float = 0.15  # feel-tune
@export var legacy_gem_chance_memory: float = 0.15  # feel-tune

## How many taps the Memory bonus round's sequence is (pure position recall).
@export var memory_gem_sequence_length: int = 5  # feel-tune


# --- Events (Spec §10) ---

## Income multiplier during a Market Crash event.
@export var crash_multiplier: float = 0.5  # TBD-SIM

## Base duration of a Market Crash event in active minutes for generation 1.
@export var crash_duration_base_minutes: float = 2.0  # feel-tune

## Growth in crash duration per generation reached.
@export var crash_duration_growth_per_gen: float = 0.5  # feel-tune

## Maximum duration cap for a Market Crash event in active minutes.
@export var crash_duration_max_minutes: float = 8.0  # feel-tune

## Legacy fallback duration of a Market Crash event in active minutes.
@export var crash_duration_minutes: float = 10.0  # TBD-SIM

## Settlement cost as a fraction of net worth during The Audit.
@export var audit_settle_rate: float = 0.08  # TBD-SIM

## Legislative Assets units required to make an audit case evaporate.
@export var audit_threshold: int = 1  # TBD-SIM (placeholder)

## Cash grant fraction of net worth during The Windfall.
@export var windfall_net_worth_fraction: float = 0.10  # feel-tune

## Cadence in active seconds between event rolls.
@export var event_roll_interval_seconds: float = 180.0  # 3 minutes

## Base probability of triggering an event on each roll interval.
@export var event_base_chance: float = 0.35  # feel-tune

## Grace period in active seconds at the start of a generation before random events can fire.
@export var event_grace_period_seconds: float = 60.0  # feel-tune


# --- Win condition (GDD §10) ---

## Total money in Earth's economy; capturing this wins the planet.
@export var earth_economy_target: float = 103_600_000_000_000.0  # $103.6T, confirm GDD §14.3

# --- Save ---

## Autosave interval in seconds.
@export var autosave_cadence: float = 10.0


# --- Audio (Plans/Audio_System.md) ---
#
# Every one of these is a FEEL knob: how long a tap run stays "hot", how often collect audio is
# allowed to speak, how quiet the small version of a scaled sound is. They live here rather than as
# consts for the same reason the haptic durations were promoted — the answers only come from playing
# it on a device, and a rebuild per guess is a bad way to find them.

## How long a gap in tapping resets the musical tap scale back to its root note, in seconds.
@export var audio_tap_scale_reset_seconds: float = 1.0

## Seconds between harmonic chord changes during sustained rush mode (2-4s).
@export var audio_rush_harmony_interval_seconds: float = 3.0

## How long after a player action the game still counts them as PRESENT (idle music fade window).
## Defaults to 180,000 ms (3 minutes of inactivity before music drifts out; Audio_System.md §3.3).
@export var audio_presence_window_ms: float = 180000.0

## How quiet the smallest version of an intensity-scaled sound is, relative to its loudest.
@export var audio_scaled_min_db: float = -10.0

## The intensity at which a scaled sound starts mixing in its brighter layer.
@export var audio_layer_threshold: float = 0.5

## The income/sec change (as a fraction) that a purchase must produce to reach the FLOOR and the
## CEILING of the purchase sound's intensity. A +2% buy sits at the floor, a +50% buy maxes out.
## Fractions, never dollars — the same purchase must sound the same at every generation.
@export var audio_buy_intensity_min_fraction: float = 0.02
@export var audio_buy_intensity_max_fraction: float = 0.50
