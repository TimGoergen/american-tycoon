# Progressive Decay — every gem stack finds its wall inside the ladder

**Status: Candidate B baked (2026-07-28, Tim-approved).** Decisions: seed with B; the
endgame must stay reachable in reasonable time (confirmed: 1T and 10T-gem dynasties reach
tier 27 in ~62s sim — EpochDepthCheck); the depth-check reachability bar moved to tier 25.
Band-1 (tiers 3–11) `.tres` files verified byte-identical after the bake; 224 deep-tier
incomes regenerated. The recipe's decay term is now `D(tier)` (banded), recorded below and
in the Mechanics Spec — any future tier extension must use it.

## Why

Tim's device report (2026-07-28, 447M lifetime gems): "every new epoch seems to go faster
and faster, but each new one should feel a little bigger than the last."

`sim/EpochPaceStudy.gd` reproduced and diagnosed it. The "each epoch a little bigger"
feel comes from the per-epoch income decay (×0.80/tier → per-epoch durations grow
~×1.25) — but the ramp only bites where income no longer trivially covers the epoch
threshold. Below that frontier every epoch sits on a mechanical floor and reads as
instant. The study's frontier-by-stack table:

| stack | ramp becomes felt | run outcome (sim scale) |
|---|---|---|
| bare heir | ~tier 5 | walls at tier 11 |
| 10M gems | ~tier 16 | crawls to the top in 34 m |
| 66M gems | ~tier 23 | clears everything in 11 m |
| **447M gems** | **~tier 25 — the content's edge** | **clears all 27 epochs in 3.5 m, ratios ~1.0–1.3 throughout** |

Root cause: the ladder's TOTAL resistance is finite and small against endgame stacks.
Across all 25 alien steps the flat decay compounds to 0.80²⁵ ≈ **÷265** income-per-dollar
— but Family Fortune alone reaches ×237, before Efficiency Experts, challenge bonuses,
and the rest. A ~half-billion-gem dynasty cancels the whole ladder: no wall anywhere, so
every epoch is a victory lap and each feels faster than the last.

Both locked feels must survive: GDD §13's "each generation speeds up" applies to
PREVIOUSLY-CLEARED content (the victory lap is correct and stays); "each epoch a little
bigger" is the FRONTIER feel — the fix is to make sure every stack still *has* a
frontier inside the 27 tiers.

## The lever: banded (progressive) decay

Keep one income formula, but let the per-tier decay step itself deepen with the tier:

```
income(per 60s) = cost × 0.25 × D(tier)
D(tier) = product of the per-step decays from tier 3 up to `tier`
```

- Band 1 — tiers 3–11 (the device-judged region): steps stay **×0.80** — the early feel
  Tim approved after the payback retune is untouched, byte-identical incomes.
- Band 2 — tiers 12–19: steps deepen.
- Band 3 — tiers 20–27: steps deepen again. Because the deep steps outpace any finite
  multiplier stack, every stack stalls somewhere inside the content, and each prestige
  pushes the stall a couple of epochs deeper — the Idle Slayer cadence at the top end.

Band boundaries align with the content batches (3–11 = the original + first-batch civs;
12+ = the batch-2 frontier), so the retuned region is exactly the shipped-and-judged one.
The band seams change the per-epoch duration ratio by ~×1.1 — imperceptible as a kink.

## Candidates (per-step decay by band; cumulative resistance at tier 27)

| | 3–11 | 12–19 | 20–27 | total ladder resistance | vs today (÷265) |
|---|---|---|---|---|---|
| Current | 0.80 | 0.80 | 0.80 | ÷265 | — |
| A — gentle | 0.80 | 0.75 | 0.70 | ÷1,290 | ~5× deeper |
| **B — recommended** | 0.80 | 0.72 | 0.65 | ÷3,240 | ~12× deeper |
| C — steep | 0.80 | 0.70 | 0.58 | ÷10,100 | ~38× deeper |

Directional reads (sim decides the final pick):
- **A** likely still lets multi-billion-gem stacks conquer the ladder — it only buys a
  few more prestiges of headroom.
- **B** puts the tier-27 wall ~12× beyond today's: a 447M stack should stall in the low
  20s with visibly growing epochs on the approach, and ~10B-gem dynasties still find
  tier 25+ genuinely hard.
- **C** risks making tiers 20+ feel parked even for enormous stacks — the "content you
  never see" failure the ladder was built to avoid.

**Success criterion (the sim gate, not vibes):** for every stack in {0, 1M, 10M, 66M,
447M, 1B, 10B}, `EpochPaceStudy` per-epoch ratios must exceed ~1.5 BEFORE the final
tier — i.e. every run meets a felt, growing wall inside the ladder — while the bare-heir
and 10M rows stay within ~10% of today's durations through tier 11 (the approved early
game must not move).

## What does NOT change

- Tiers 1–11: all incomes byte-identical (Earth split epochs + the payback-retune region).
- All costs, cycles, r0, thresholds, staff pricing, prestige/gem economics.
- The victory-lap speed-up through cleared content (GDD §13) — untouched by construction.

## Knock-ons to measure

1. Deep-epoch durations lengthen at every stack (intended); re-measure the full duration
   tables and the 10T-gem end-to-end advanceability check (it should now stall too —
   decide the new "advanceable end-to-end" reference stack, or accept none conquers it).
2. Tier 12+ payback times steepen (band 2/3 properties' self-funding) — check the
   epoch-entry save-up still resolves from whole-economy income at the intended stalls.
3. UnlockCadence beats inside deep epochs (should hold — costs don't move).

## Implementation sketch (when a candidate is approved)

1. Extend `EpochPaceStudy` stacks with 10B; prototype candidates via CLONED configs
   (the `EpochCadenceStudy` pattern — decay applied in-sim, no files touched) and run
   the success criterion across all three candidates.
2. Bake the winner: regenerate `base_income_per_unit` for ids 13–326 with
   `4sf(cost × 0.25) × D(tier) × (cycle/60)`, %.6g per step — the standing recipe with
   `D(tier)` replacing the flat exponent. Tiers 3–11 verify byte-identical.
3. Update the durable recipe records (this plan, the Mechanics Spec formula, memory,
   `assemble.py`'s decay note) so future tier extensions use `D(tier)`.
4. Full gates: EpochTest + MoneyTest + RushOverheatTest + Sim + UnlockCadence +
   EpochPaceStudy; boot; Firebase APK → Tim's device feel-test at his real stack.

## Related but separate (flagged, not in this plan)

- **Vent-bonus stacking is uncapped** (+20%/vent, no ceiling): across a long run this
  compounds rush income (~90% of an active player's income) without limit — a second,
  behavioral accelerator the sim doesn't model. If deep pacing still feels off after
  progressive decay, capping or per-epoch-decaying the vent stack is its own small tune.
- Challenge bonuses earned mid-run add a lesser within-run acceleration (finite, capped).

## Open questions for Tim

1. Candidate — A, B, or C as the starting point for the sim pass? (B recommended.)
2. Should ANY stack be able to fully conquer the ladder (a true endgame trophy), or
   should tier 27 stay out of reach forever? (B leaves ~trillion-gem dynasties able to
   finish; C effectively nobody.)
3. OK to fold the 10T-gem "advanceable end-to-end" sim check into "advanceable to ~tier
   25" (the check exists to prove no hard blocker, which a stall is not)?
