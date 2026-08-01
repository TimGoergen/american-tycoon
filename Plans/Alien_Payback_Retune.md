# Alien Payback Retune — fix the Earth→Luminari income cliff

**Status: Candidate B approved by Tim and implemented (2026-07-27).**
The live recipe constants are now **R = 0.25, d = 0.80** — any future tier extension
must generate alien incomes as `income(per 60s) = cost × 0.25 × 0.80^(tier−1)`
(4sf on the base step, then %.6g after decay, then %.6g after the cycle step),
replacing the retired 0.01824 ratio everywhere the batch-2 recipe is reproduced.
Target branch: `feature/civs-12-26` (this responds to the device feel-test of that branch,
and it edits the same 326-property content, so it should land there before merge).

## Why

Tim's device report (2026-07-27): second run, reached Luminari with 1.1K Legacy gems
invested — the Photon Exchange earns so little relative to its cost that rushing it
barely moves the needle on affording the next unit. "Feels like we went too far."

Diagnosis confirmed in the data. Per-unit payback time (cost ÷ income rate) on the
current branch:

| Property | Payback per unit |
|---|---|
| Earth ladder (ATM → Hedge Fund) | 0.1 → 1.8 min |
| Legislative Assets (Earth 11) | 2.6 min |
| Executive Assets (Earth 12) | 3.4 min |
| **Photon Exchange (Luminari flagship)** | **64.5 min** |
| Data Foundry (Geth flagship) | 75.9 min |

Earth ramps gently across twelve rungs, then income-per-dollar falls off a **19× cliff**
at the epoch boundary and never recovers — every alien property is pinned to
`income = cost × 0.01824` (per 60s), times `0.85^(tier−1)` decay. Rushing an alien
property can never meaningfully fund its own next unit; purchases are effectively
funded by the Earth economy alone.

The 0.01824 ratio is a fossil, not a choice: it was frozen by the Escalating Ladder
work (`Plans/Escalating_Ladder.md`) from the era when alien flagship income was
designed around a *total*-income step-up ("3× over staffed Earth") with income
deliberately decoupled from cost. Nobody chose "64-minute payback at epoch 2" as a
felt experience. The batch-2 decay (`d = 0.85`, commit `1bab060`) only shaved a
further 15% at tier 2 — Tim would have hit essentially the same wall on main.

## Goal (design intent, per locked principles)

- **Fast pace holds at the frontier the player is actually touching.** Luminari-entry
  payback should feel like a continuation of Earth's ramp (single-digit minutes), not
  a wall.
- **The deep-ladder stall stays — as a gradient.** Low stacks stalling deep IS the
  prestige cadence. The per-tier decay is the right brake; the boundary cliff is not.
- One lever pair, applied uniformly: a **base income/cost ratio** `R` and a **per-tier
  decay** `d`, giving `income(per 60s) = cost × R × d^(tier−1)` for every alien
  property (ids 13–326). Costs, cycles, r0, thresholds all stay untouched — this is an
  income-only retune, so the flagship "save-up" anchor (~10% of the previous
  threshold) is preserved exactly.

Per-unit payback in minutes is then `1 / (R × d^(tier−1))`.

## Candidates

All three put Luminari near Earth's frontier feel; they differ in how hard the deep
brake bites. Payback per unit, by tier:

| | R | d | T2 (Luminari) | T6 | T11 | T16 | T26 | vs. current |
|---|---|---|---|---|---|---|---|---|
| **Current (branch)** | 0.01824 | 0.85 | 64.5 min | 124 min | 4.6 h | 10.4 h | 53 h | — |
| A — keep decay | 0.235 | 0.85 | 5 min | 9.6 min | 21.6 min | 49 min | ~4 h | deep frontier 13× faster |
| **B — recommended** | 0.25 | 0.80 | 5 min | 12.2 min | 37 min | ~1.9 h | ~18 h | deep frontier 3× faster |
| C — keep deep stall | 0.22 | 0.76 | 6 min | 18 min | 71 min | ~4.7 h | ~72 h | deep frontier ≈ current |

- **A** trusts the decay we already shipped but likely erodes the deep prestige
  cadence too much (tier 26 payback drops from 53 h to 4 h).
- **B** starts Luminari at 5 min (Earth's Executive Assets is 3.4 — a natural next
  step on the ramp) and steepens the decay so the deep ladder still stalls hard,
  just later and gradually. **Recommended starting point.**
- **C** is the conservative bracket: fixes the boundary while keeping the tier-26
  stall at or beyond today's. Fallback if sims show B collapses epoch durations.

These are *starting* candidates — the sims decide. R and d are exactly the kind of
feel-tune constants the sim suite exists for.

## Knock-on effects to measure (why this is a sim project, not a ratio edit)

1. **Epoch durations shrink.** Thresholds are lifetime-earned money and stay fixed,
   so faster alien income = faster tier arrival. Re-measure the full duration table
   with `Sim.gd` playouts; if the ~1-epoch-per-prestige cadence breaks, raise `d`.
2. **Prestige gem economics.** Gems key off estate magnitude, and magnitudes are
   threshold-anchored (unchanged) — but gems *per hour* rise with pace. Re-run
   `PrestigeStudy.gd` and compare **ratios**, not raw magnitudes (per the sim-scale
   lesson: never tune prestige constants off raw sim numbers).
3. **The entry step-up inverts.** A Photon Exchange unit jumps from 2.7B/s to
   ~37B/s under B — first alien purchase becomes a large income event. Check via sim
   that it doesn't trivialize the remaining Earth tail (probably fine — it's the
   reward for a 10%-of-lifetime-earnings save-up — but verify).
4. **Unlock cadence within epochs.** `UnlockCadence.gd` LIVE row should stay ~flat
   (the escalating-cohort win must survive the retune).
5. **Offline earnings + Challenge goals.** Both consume income rates; sanity-check
   that no challenge becomes trivially instant at the new rates.

## Implementation sketch (when approved)

1. Regenerate `base_income_per_unit` for ids 13–326 only:
   `income = cost × R × d^(tier−1) × (cycle/60)`, each step re-rounded to `%.6g`
   **in that order** (decay, then cycle) — same rounding discipline as the batch-2
   recipe. Costs, cycles, r0, accents, names: untouched.
2. Update the sim pattern check that currently asserts the 0.01824 ratio
   (`EpochTest.gd` content-integrity section) to assert the new (R, d) formula.
3. Update the recipe record: this plan + the durable recipe notes, so a future tier
   extension generates incomes with the new constants, not 0.01824.
4. Headless gates: MoneyTest + EpochTest ALL PASS; Sim dynasty playouts (duration
   table, 10T-gem tier-26 run); PrestigeStudy ratio comparison; UnlockCadence.
5. Firebase APK → **Tim's device re-test of the exact reported scenario:** prestige
   once, re-enter Luminari with ~1K gems, feel the Photon Exchange unit cadence.

## Open questions for Tim

- Is ~5 min the right Luminari-entry payback, or should it be closer to Earth's
  3.4-min frontier? (Cheaper to decide now than after a sim round.)
- How much deep-tier stall do you want at tier 26 — hours (A), a long session (B),
  or multi-day/current (C)? This picks the candidate more than anything else.
- The old "3× step-up over staffed Earth" framing is formally dead under any
  candidate (the step-up becomes much larger). OK to retire it from the GDD?
