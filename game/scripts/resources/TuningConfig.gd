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

## Executive-pay bonus per clock-in level, as a fraction of the floor (0.05 = +5%/level).
## Scales the executive floor by (1 + this × level) so a level-up ALWAYS visibly raises the
## per-tap payout — without it, once the floor overtook the ladder wage, leveling up changed
## nothing and the ladder felt dead (Tim, 2026-07-15). A steady multiplier of the floor, so
## it tracks the economy rather than compounding past it.
@export var wage_floor_bonus_per_level: float = 0.05  # feel-tune

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
# risks an overheat shutdown at a secretly rolled ceiling. See RushMomentumState for the model.
# NOTE: the old bonus-fraction knobs (rush_momentum_max_bonus / _build_per_second /
# _bleed_per_second) were deliberately RENAMED rather than reused, so a stale user override
# saved in the old bonus-fraction units can never silently poison the new heat-unit semantics.

## How fast heat climbs while actively rushing, in heat units per second
## (0.167 ≈ 6 s from cold to the Hot edge — matching the old build feel).
@export var rush_momentum_heat_build_per_second: float = 0.167  # feel-tune

## How fast heat climbs while rushing ABOVE the Hot edge (heat 1.0), in heat units per second.
## Slower than the base build so the ride through the danger bands is a real decision window:
## 0.075 stretches the climb from the Hot edge to the rolled ceiling (0.40–0.60 units) to
## ~5.3–8 s (Tim 2026-07-15: "at least 5 to 8 seconds in the high heat zone").
@export var rush_momentum_heat_build_hot_per_second: float = 0.075  # feel-tune

## How fast heat bleeds away when NOT rushing, in heat units per second
## (0.333 ≈ 3 s to fully cool from the Hot edge — matching the old bleed feel).
@export var rush_momentum_heat_bleed_per_second: float = 0.333  # feel-tune

## Heat at which the Critical band (warning 2) begins. The Hot band spans 1.0 to here, and its
## width is GUARANTEED safe — the random ceiling can never land inside it.
@export var rush_momentum_critical_start: float = 1.25  # feel-tune

## Lowest possible overheat ceiling (rolled per excursion). Being above critical_start guarantees
## a minimum stretch of Critical before the earliest possible shutdown — the anti-frustration floor.
@export var rush_momentum_ceiling_min: float = 1.40  # feel-tune

## Highest possible overheat ceiling, and the heat at which the bonus reaches its peak.
@export var rush_momentum_ceiling_max: float = 1.60  # feel-tune

## Bonus at the Hot edge (heat 1.0), as a fraction of property income. 0.30 keeps the old cap's
## value — the Building band is exactly the pre-overheat meter.
@export var rush_momentum_bonus_at_hot: float = 0.30  # feel-tune

## Bonus at the Critical edge (heat = critical_start).
@export var rush_momentum_bonus_at_critical: float = 0.40  # feel-tune

## Bonus at the maximum possible heat (ceiling_max). Only ever held for seconds at a time —
## the realistic average is the ride/vent duty cycle, well below this peak.
@export var rush_momentum_bonus_peak: float = 0.55  # feel-tune

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
