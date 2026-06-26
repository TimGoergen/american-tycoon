# Plan: Solid cycle bar + per-second readout for ultra-fast properties

**Date:** 2026-06-25
**Status:** Implemented

## Problem

A property's *effective* cycle time = `cycle_length / cycle_speed_multiplier`. The base
`cycle_length` is floored at 1.0s by the milestone system, but `cycle_speed_multiplier`
(the Legacy "Efficiency Experts" upgrade, up to ~30x at max level) has no upper cap. So a
property's effective time-between-payouts can fall well below 1s — as low as ~0.03s.

At that speed the cycle progress bar refills several times per second. At 60fps each frame
jumps >6.7% (and far more as it gets faster), so the bar reads as a meaningless strobe.

## Design (genre-standard)

Once cycles are short enough that the bar can't meaningfully animate, stop chasing the
fill: pin the bar solid-full and switch the readout from `$X/cycle` to a steady `$X/sec`.
This reads as "this business is now so big it just prints money continuously" — a
satisfying graduation from a hands-on task bar to a status light. Pure presentation; no
economy impact (the underlying tick/income math is unchanged).

## Threshold

`SOLID_BAR_THRESHOLD_SEC = 0.25` (effective seconds). Below this the bar flips to solid.
Chosen on legibility/frame-rate grounds (≈4+ refills/sec is already a strobe at 60fps),
not economy balance.

**Layering decision:** kept as a UI constant in `PropertyRow.gd` next to the other cycle-bar
constants (`RUSH_CATCHUP_TAU`, `HELD_RUSH_*`), NOT in `tuning.tres`. `tuning.tres` holds
economy/simulation values; this is a render-legibility knob. Easy to relocate if we later
want it data-driven.

## Changes (all in `game/scripts/ui/PropertyRow.gd`)

1. New `const SOLID_BAR_THRESHOLD_SEC := 0.25` with explanatory comment.
2. In `_refresh()`: hoist `effective_length`, derive `bar_is_solid` (owned + running +
   `0 < effective_length < SOLID_BAR_THRESHOLD_SEC`).
3. Income label: when solid, show `per_cycle * frenzy / effective_length` + `"/sec"`.
   Derived from the SAME per-cycle figure already displayed (`get_income_per_cycle()` ×
   frenzy), so the rate stays consistent with the per-cycle number. Deliberately not
   `get_income_per_sec()`, which omits the legacy & frenzy multipliers.
4. Cycle bar: when solid, pin `_displayed_cycle_fraction = 1.0` and skip the easing
   predictor; existing smooth-fill path otherwise untouched. Fill color logic unchanged
   (solid green when rushable, solid blue when automated).

## Out of scope / follow-ups

- The misleading comment at `LegacyUpgrades.gd:108` (claims `cycle_floor` caps the actual
  cycle — it does not). Left for a separate cleanup unless folded in.
- No new clamp on `_effective_cycle_length()` — sub-second payout is intentional; we only
  change how it's *displayed*.
