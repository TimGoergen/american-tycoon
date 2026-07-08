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

## The commanded liquid speed (px/s) while a rush frenzy is engaged.
@export var carb_excited_flow: float = 90.0  # feel-tune

## Horizontal churn wobble amplitude (px) at full frenzy.
@export var carb_excited_wobble: float = 7.0  # feel-tune

## Per-bubble speed spread's LOWER bound at full frenzy (the crawler/streaker mix).
@export var carb_excited_spread_lower: float = 0.25  # feel-tune

## Comet-tail visibility during frenzy (0 = suppressed, 1 = full tails). Tails curl
## more at low speeds, which contributed edge bursts; partial by default.
@export var carb_excited_tails: float = 0.3  # feel-tune

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
## Solved from a $10T → ~45 gems anchor for the gentle power curve (Tim, 2026-07-02).
@export var k_legacy: float = 0.045  # feel-tune

## Exponent on the estate-magnitude term of the Legacy curve — how fast gems grow with earnings.
## ~0.30 means gems roughly DOUBLE per 10× of estate, so a better run is clearly rewarded (the old
## log² curve was ~flat: doubling a run added only ~3 gems). Higher = punchier AND faster late
## growth; the Legacy shop's geometric costs are the real brake on any windfall (Tim, 2026-07-02).
@export var alpha_legacy: float = 0.30  # feel-tune

# Note: the old k_sprint / beta_sprint / k_residual constants were removed when
# Legacy became a spendable upgrade currency. Per-level upgrade magnitudes and
# costs now live in LegacyUpgradeCatalog.gd, not here.

# --- Prestige minigame (GDD §5.5, Spec §9.3) ---
# At prestige the player plays a match-3 whose score sets how much of the run's base
# Legacy they KEEP: legacy_awarded = floor(base_legacy × mult). The multiplier rises
# from minigame_keep_floor (score 0) → 1.0 "full" (score ≥ minigame_full_score) → up to
# 1.0 + bonus (score ≥ minigame_extra_score), where the extra-high bonus cap comes from
# LegacyUpgrades.minigame_bonus_max() (0.25 base, +5%/level via Family Reputation).

## Fraction of the base Legacy kept on the WORST result (score 0) — also what a skip /
## minigame-off banks. Below 1.0, so a poor round (or opting out) loses Legacy.
@export var minigame_keep_floor: float = 0.5  # feel-tune

## Gems cleared to keep the FULL base Legacy (multiplier exactly 1.0). The multiplier
## scales linearly from the floor (score 0) up to 1.0 at this score.
@export var minigame_full_score: float = 100.0  # feel-tune

## Gems cleared to reach the MAX extra-high bonus (multiplier 1.0 + bonus_max). Between
## full_score and this, the multiplier scales linearly from 1.0 into the bonus.
@export var minigame_extra_score: float = 200.0  # feel-tune

## How long one minigame round lasts, in seconds. Every type is tuned to a ~20s round
## (Tim, 2026-06-25) — scoring targets in each minigame assume this length.
@export var minigame_duration_seconds: float = 20.0  # feel-tune


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
