class_name TuningConfig
extends Resource

# Single source of truth for all numeric tuning constants (Mechanics Spec §12).
# Loaded at runtime from res://config/tuning.tres — never referenced directly
# from script defaults, which are only fallbacks for in-editor previews.

# --- Time / tick ---

## Fixed logic tick rate in Hz (Spec §2).
@export var logic_hz: int = 10

# --- Run start ---

## Starting cash for a fresh run (GDD §8.1 "No rich parents" path).
## The full origin flow with all four paths arrives in M2.
@export var m1_starting_cash: float = 1000.0

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
@export var wage_hold_taps_per_second: float = 5.0  # feel-tune

## Frenzy fill per held-rush pulse, as a fraction of a manual tap's fill.
## Holding is convenient, so it charges the meter slower than real tapping.
@export var frenzy_fill_hold_factor: float = 0.6  # feel-tune M1

# --- Staffing & offline (Spec §6) ---

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

## Scaling constant for Legacy gain: legacy = floor(K_LEGACY × estate_net ^ ALPHA).
@export var k_legacy: float = 1.0  # TBD-SIM

## Exponent for Legacy gain curve (0.5 = square-root compression).
@export var alpha_legacy: float = 0.5  # TBD-SIM

# Note: the old k_sprint / beta_sprint / k_residual constants were removed when
# Legacy became a spendable upgrade currency. Per-level upgrade magnitudes and
# costs now live in LegacyUpgradeCatalog.gd, not here.

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
