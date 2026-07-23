# r0 / Property Self-Funding Guardrail — Sim-Backed Findings

**Date:** 2026-07-23. **Tooling:** `game/sim/PaybackStudy.gd` (new, payback-vs-units) +
`game/sim/PaceStudy.gd` (existing, progression/feedback clocks). **Status:** findings for
Tim's target decision — no tuning value changed yet.

## The question

GDD §4 / parking-lot guardrail: a property's income scales *linearly* with units owned but
next-unit cost grows *geometrically* at `r0` (live = 1.09 on all 12 Earth tiers), so the
**payback period** (next-unit cost ÷ own income/sec) *shrinks* as you stack units — the
property self-funds its own expansion, eroding cross-property allocation. The GDD asks us to
solve `r0` against a target payback, not hand-pick it.

## Finding 1 — "never falls within a band" is mathematically impossible

Inside a band, `payback(n) = K · r0ⁿ / n`, which bottoms at **n\* = 1/ln(r0)** — it falls to
n\*, then rises. To rise from unit 1 you'd need `r0 ≥ e ≈ 2.72` (cost nearly tripling per
unit). Linear income + geometric cost *guarantees* an early dip. **`r0` sets the dip's depth
and floor, not its existence.** The guardrail's real intent is the other clause: a next unit
should never be *trivially* affordable from the property's own income.

## Finding 2 — it is an EARLY-TIER, BAND-0-ONLY problem

`PaybackStudy` Section A — band-0 payback floor per tier at live `r0` = 1.09 (every tier
bottoms at unit 12):

| tier | property | band-0 floor | tier | property | band-0 floor |
|---|---|---|---|---|---|
| 1 | ATM | **1.26s** | 7 | Day Trading | 10.13s |
| 2 | Money Tree | **1.85s** | 8 | Flipping Houses | 14.62s |
| 3 | NFTs | **2.64s** | 9 | Multi Level Marketing | 18.35s |
| 4 | Tax Increment Financing | 3.69s | 10 | Hedge Fund | 25.31s |
| 5 | Cross Border Distribution | 5.06s | 11 | Legislative Assets | 36.92s |
| 6 | Money Laundering | 7.17s | 12 | Executive Assets | 47.46s |

The floor scales with each property's cost/income ratio, so only the **first ~3-4 tiers** are
"trivially" self-funding (~1-3s). By Day Trading the floor is 10s+; the top tiers are 25-47s —
already fine.

And it is **band-0-only**. Section C (ATM trajectory) shows that once you cross milestone 1
(25 units), `band_step` (1.10) compounds the cost ratio each band while income only doubles
per milestone, so payback *explodes*: unit 40 = 9.7s, unit 49 = 40.7s, unit 60 = 349s, unit
99 = ~10 million seconds. **A property cannot remotely self-fund its late-band growth — you
must push it with cross-property/economy income.** The self-funding window is just band 0 (and
the first few units after each milestone step) on the early tiers.

## Finding 3 — raising r0 shallows the dip at near-zero macro-pace cost

`PaybackStudy` Section B — dip shape + extreme floors across the sweep (shape is `r0`-only,
identical for all tiers; only the absolute floor scales):

| r0 | dip bottoms @ | dip depth (start ÷ floor) | ATM floor | Executive floor |
|---|---|---|---|---|
| 1.07 | unit 13 | 5.96× | 1.00s | 37.2s |
| **1.09 (live)** | unit 12 | **4.71×** | **1.26s** | **47.5s** |
| 1.12 | unit 10 | 3.55× | 1.67s | 62.4s |
| 1.15 | unit 6 | 2.87× | 2.07s | 77.0s |
| 1.18 | unit 6 | 2.67× | 2.43s | 91.1s |
| 1.20 | unit 5 | 2.40× | 2.70s | 100.8s |

`PaceStudy` — the progression cost of that (its C/D/E candidates sweep `r0` at the live 60s
cycle top). **Macro pace is nearly invariant:**

| candidate | Earth mid-game window | First Contact | purchases |
|---|---|---|---|
| C — r0 1.09 (≈ live) | 15.8m | 21:57 | 94 |
| D — r0 1.11 | 14.9m | 21:57 | 91 |
| E — r0 1.15 | 14.8m | 22:00 | 88 |

First Contact lands at ~22:00 regardless of `r0` — because `band_step` + milestones dominate
late-game cost and `r0` is a rounding error there. The only visible cost is the **early
grind**: rung-8 unlock slips 6:12 → 7:12 (about +1 min) going 1.09 → 1.15, and a few fewer
purchases. **Caveat (PaceStudy header):** the sim's near-permanent frenzy makes cash cheap, so
it *understates* cost steepening — treat the early-grind cost as a floor; on device a bump to
1.15 would feel grindier in the opening than these numbers suggest.

## Reading the trade-off

Raising `r0` fixes the early self-funding dip, and its cost is *also* concentrated in the early
game (a slower opening grind) — the same region. So it's a coherent trade: "early properties
self-fund too easily" ↔ "early properties cost a bit more to stack." Macro progression (First
Contact, the epoch/Legacy pacing already tuned) is untouched either way.

## Options

1. **Accept & close.** The violation is narrow (band 0, first ~3-4 tiers) and late bands are
   the *opposite* of self-funding. Tier-scaling (~5×/tier) drives diversification regardless,
   so the "collapse to one property" failure mode is weak in practice. Keep `r0` = 1.09,
   document the guardrail as accepted-not-met.
2. **Light global nudge → r0 = 1.12.** Halves the dip depth (4.71× → 3.55×), lifts the ATM
   floor 1.26 → 1.67s, at negligible macro cost and only a mild early-grind bump. Simple (one
   value, all tiers), safe, reversible; device-feel-check the opening.
3. **Stronger → r0 = 1.15.** Dip depth 2.87×, ATM floor 2.07s. Meaningfully firmer, but the
   opening grind cost is real on device (sim understates it) — wants a device pass before
   committing.
4. **Early-tier-weighted** (e.g. 1.15 on tiers 1-4, 1.09 above). Targets exactly the tiers that
   violate, protects late-tier grind. But macro pace barely moves under a global bump anyway,
   so the added per-tier config complexity buys little over option 2/3.

## Recommendation

**Option 2 (global r0 = 1.12), device-feel-checked** — or **Option 1 (accept & close)** if the
opening already feels good. The rigorous read is that this guardrail is a real but *narrow*
early-game texture issue, not the allocation-breaker it reads as on paper; a small global nudge
is the cheapest meaningful mitigation, and anything stronger should be earned by a device pass
showing the opening still feels good. Per-tier `r0` isn't worth the complexity given macro pace
is `r0`-insensitive.
