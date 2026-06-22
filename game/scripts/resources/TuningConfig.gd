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

## Frenzy fill per held-rush pulse, as a fraction of a manual tap's fill.
## Holding is convenient, so it charges the meter slower than real tapping.
@export var frenzy_fill_hold_factor: float = 0.6  # feel-tune M1

# --- Staffing & offline (Spec §6) ---

## Alien staff (tier 2+) cost as a fraction of the TARGET epoch's whole economy
## (earth_economy_target × that epoch's economy_scale). Anchoring to the epoch economy
## — not the property's tiny Earth base cost — is what makes alien staff cost ~1000×
## more each epoch, so you cannot afford the next epoch's staff the instant you arrive
## (Tim 2026-06-17). The Earth staffer (tier 1) keeps its small property-scaled cost.
@export var staff_cost_fraction: float = 0.001  # feel-tune

## Per-property growth of that fraction: cheaper rungs (ATM) get the base fraction, each
## higher rung multiplies by this, so pricier properties cost proportionally more to staff.
@export var staff_cost_property_growth: float = 1.4  # feel-tune

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

## Scale for Legacy gain on the LOG-compressed curve (see EstateWaterfall.legacy_gain,
## reworked 2026-06-17): legacy = floor(K_LEGACY × log10(estate_net / floor) ^ ALPHA),
## where the floor is EstateWaterfall.LEGACY_BASE. A plain power curve minted absurd
## Legacy at real trillion-dollar scale (a 20T run gave ~16k); the log keeps the whole
## range to a sane handful (≈ $1B→18, $8T→49 at the defaults).
@export var k_legacy: float = 0.5  # feel-tune

## Exponent on the log-decades term of the Legacy curve (shapes how fast Legacy grows
## with each order of magnitude of estate).
@export var alpha_legacy: float = 2.0  # feel-tune

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

## How long one minigame round lasts, in seconds.
@export var minigame_duration_seconds: float = 30.0  # feel-tune

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
