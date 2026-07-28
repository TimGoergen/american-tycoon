# Escalating Ladder — one more property per epoch

**Status: implementing (2026-07-15).** Branch: `feature/economy-ladder`.

## Why

Tim (2026-07-15): "the main thing that feels slow after Earth is that the pace of
unlocking new properties slows down." The Unlock Cadence study (`sim/UnlockCadence.gd`)
confirmed it: Earth delivers 12 first-unit unlock beats, every alien epoch delivers 5,
and the gap between beats GROWS each epoch (median 4.4m → 7.1m across epochs 2-5)
because epoch durations creep ~1.2× while the rung count stays fixed.

Tim's chosen fix: **escalating cohorts — epoch 2 gets 6 properties, each later epoch
gets one more** (6, 7, 8, 9, 10 for epochs 2-6). Sim-validated: per-epoch median gap
becomes 3.2 / 3.7 / 3.7 / 4.0m — nearly flat — with total run time unchanged. Each
epoch's ladder still spans exactly ×16807 (= 7^5, matching the threshold growth), so
epoch durations, thresholds, and the ~1-epoch-per-prestige cadence are untouched by
construction. Only the per-rung ratio shrinks: ×16807^(1/N) per rung — ×5.06 at epoch
2 down to ×2.64 at epoch 6.

## The new ladder

Per epoch T (rungs N = T + 4), rung k (0-based) of the cohort:

- `cost(k) = flagship_cost × (16807^(1/N))^k` — the flagship anchor (rung 0) keeps its
  live cost exactly, preserving the epoch-entry save-up (~10% of the previous
  threshold) and the ×3 step-up (both Tim-approved).
- `income(k) = cost(k) × 0.01824` — the live cohorts hold income/cost constant at
  0.01824 (verified against every shipped .tres by the sim's pattern check).
  **SUPERSEDED 2026-07-27:** the income rule is now `cost × 0.25 × 0.80^(tier−1)` —
  see `Plans/Alien_Payback_Retune.md`. The cost grid above is unchanged and still live.
- Cycle 60s, r0, accent color: inherited from the epoch's flagship.

Identity order on the grid: flagship (rung 0) → the 3 existing siblings (rungs 1-3) →
the NEW properties (upper-mid rungs) → the epoch's grandest venture (Starcore
Syndicate etc.) stays the TOP rung. 15 new properties total: +1 Luminari, +2 Geth,
+3 Mycelium, +4 Quartzite, +5 Chronophage.

## Save compatibility — why there is NO save-format change

`ConfigLoader.PROPERTY_PATHS` order is every save's property index (per-property save
rows, StaffRetention keys, EpochCatalog rosters). The 15 new properties are APPENDED
(indices 37-51), continuing the existing append-only convention, so every existing
index keeps its meaning and old saves load unchanged. Existing alien properties get
new base_cost/base_income values (re-spaced onto the new grid), but `PropertyState.
restore()` recomputes all derived values from raw facts (units, staff level), so a
mid-run save simply sees the new prices. The ID-keyed-save idea from the scaling
discussion is NOT needed for this (or any future append-only) growth; revisit only if
a rework ever has to re-order the array.

## Staff-cost re-anchor (required, load-bearing)

`EconomyState.get_staff_block_anchor` prices later staff blocks with
`staff_cost_fraction × 1.4^GLOBAL_property_index`. The global index was already
incoherent for aliens (siblings appended at 17-31 price above later epochs'
flagships at 12-16) and becomes nonsense at 52 properties. Replace the exponent with
a **staff price rank**: Earth properties keep their ladder index (0-11); an alien
property gets `12 + its cost rank within its own cohort` (flagship = 12 — exactly its
old index, so flagship staff prices are unchanged). Computed once in EconomyState
from the configs. `StaffRetention.cost_for_level` (Legacy pricing,
`property_step^index`) is re-anchored to the same rank for the same reason —
alien retention prices drop to coherent values (flagged to Tim; Earth rows 0-11
unchanged).

## Content (15 new properties)

Each needs: display_name (in its civ's register), staffer_name (.tres, home-civ
voice), and one staffer entry in ALL SIX rosters in `EpochCatalog.gd` (Earth +
5 civs, appended at indices 37-51 in PROPERTY_PATHS order). Follow-up (separate,
before Tim reviews it): regenerate the rosters in `docs/civilizations_v2_draft.json`.

## Verification

- `sim/EpochTest.gd` content-integrity section updated for escalating cohort sizes.
- Full `Sim.gd` run (pacing measurement, step-up check, playout) — epoch durations
  must stay ~unchanged; step-up ratios intact (flagship anchors untouched).
- `sim/UnlockCadence.gd` LIVE row must now show the escalating cadence (~flat gaps).
- Headless editor import + game boot, then device pass by Tim (Firebase APK).

## Scaling notes (beyond epoch 6, from the 2026-07-15 analysis)

Cap cohort growth around 12-14 rungs (~epoch 10) — below ~×2 per rung a new property
stops feeling like a new magnitude. Thresholds hit the float64 ceiling near epoch ~70;
irrelevant for the authored range.
