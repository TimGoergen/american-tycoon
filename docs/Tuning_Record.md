# The tuning record — which knobs are load-bearing, and where the numbers came from

`TuningConfig` exposes **134 knobs**. They are not equal: some were chosen, some were *fitted by a
simulation*, and two currently **differ from values Tim seeded**. Nothing distinguished them, so a
number that came out of a five-iteration fit looked exactly like a number someone typed once.

This document is the provenance record. It does not duplicate the per-knob comments in
`game/scripts/resources/TuningConfig.gd` — those explain what each knob *does*. This says **where the
value came from and how much rests on it.**

## The four kinds of number

| Kind | How to recognise it | How freely can it be changed |
|---|---|---|
| **Fitted** | Comment says `fit:` and names a study | Not freely — re-run the study |
| **Device-tuned** | Comment says `device-tuned` and names a date | Only on device, by feel |
| **Feel-tune** | Comment says `feel-tune` | Freely; that is what it is for |
| **TBD-SIM** | Comment says `TBD-SIM` | It is a placeholder — never shipped-verified |

`config/tuning.tres` **overrides** the baked defaults for the values that have been tuned. The sims
deliberately load the BAKED defaults (`ConfigLoader.load_tuning(false)`), so a study measures the
authored curve rather than whatever a device happens to have.

## The load-bearing numbers, and where they came from

These are the ones where a careless edit changes the shape of the whole game.

### The Legacy mint — how much a life is worth

| Knob | Value | Provenance |
|---|---|---|
| `alpha_legacy` | 0.35 | Prestige retune (2026-07-23). **Device-confirmed**: "prestige balance feels good" |
| `k_legacy` | 0.16 | Same retune. Moves *inversely* with `alpha_legacy` — a lower exponent needs a higher coefficient, so they must be changed together |
| `legacy_knee_net` | 1e21 | The piecewise knee. Below it the approved curve applies exactly |
| `alpha_legacy_deep` | 0.05 | **FITTED by `DynastyArcStudy`, and DEVIATES from Tim's seed of 0.06** |

### The upgrade shop — what a life buys

| Knob | Value | Provenance |
|---|---|---|
| `legacy_cost_steepening` | 1.10 | **FITTED by `DynastyArcStudy`, and DEVIATES from Tim's seed of 1.03.** The real brake on the uncapped compounders |
| `legacy_upgrade_cost_multiplier` | 3.0 | Prestige retune; device-confirmed |

### The frontier — how long a run lasts

Alien income decay is **banded**: ×0.80 for tiers 3–11, ×0.72 for 12–19, ×0.65 for 20–27
(`Plans/Progressive_Decay.md`). A flat 0.80 totalled ÷265 across the ladder, which endgame stacks
simply cancelled — no wall anywhere, the shop maxed, and septillions minting. The bands are the fix.

## ⚠️ The two deviations, stated plainly

**`legacy_cost_steepening` = 1.10** (Tim seeded 1.03) and **`alpha_legacy_deep` = 0.05** (Tim seeded
0.06).

Both were forced by `DynastyArcStudy` over five iterations: at the seeded 1.03 the dynasty summited
at generation 3 — the arc was over before it began — and at 1.12 it stalled absolutely at tier 25.
1.10 is what produced the intended curve: tier 26 around generation 11, summit near 15, mints
climbing 1.2M → 32B.

**They have never been judged on a device.** Tim confirmed the retune "feels really good in the first
5 or 6 epochs" (2026-07-29), which validates the early bands — but the deep bands and the shop curve,
which is exactly what these two constants govern, remain unverified by play.

This is written *here*, in a document about tuning, rather than only inside the plan that caused it,
because of a process failure the device checklist names explicitly: **a deviation flagged only in the
plan doc that produced it is invisible to the person doing the playtesting.**

## The vent-bonus ladder — modelled 2026-08-10

**The vent-bonus stacking cap — MEASURED 2026-08-10 by `sim/VentBonusStudy.gd`.** The result is
"yes and no", and the distinction matters.

The ladder is endless: each vent adds `vent_bonus_step` (+30%) with no ceiling, and the difficulty
curve is supposed to be the ending instead. It is — up to a point. The window decays geometrically
but **floors at 0.45s**, and the lift demand **caps at 3**. So the difficulty stops getting harder,
and the ladder's real ceiling is not a property of the tuning at all — it is a property of how fast
the player's hands are:

| Per-lift pace | Last tier reached | Peak bonus | Multiplier on rushed income |
|---|---|---|---|
| 0.65s (the legal maximum) | 2 | +115% | ×2.1 |
| 0.30s (unhurried) | 5 | +205% | ×3.0 |
| 0.18s (quick) | 24 | +775% | ×8.8 |
| 0.12s (expert) | unbounded | — | — |

**The boundary is about 0.15s per lift** — three of those fit the 0.45s floor. Below that pace the
design's claim holds and the mechanic ends the run; above it the mechanic never ends the run, and the
only brakes left are stamina and the heat curve's own lockouts.

Whether that is a problem is a design judgement, not a maths one: it depends on how fast a real
player is and how much multiplier the economy can absorb. The levers if it needs one are the duration
FLOOR (lower it and the ceiling drops for everyone), the lift cap (raising it past 3 was rejected in
July — "a quad-pump is thumb mush"), or a cap on the bonus itself, which is what the endless ladder
deliberately removed.

**A first correction worth recording:** the study's first version treated `vent_gap_max` and
`vent_tap_max` as the gesture's COST and concluded the ladder self-limited at tier 3 for everyone.
They are maximums — the slowest a beat may be before it counts as a fumble — so that answer was
pessimistic and, worse, hid the finding entirely.

## Changing a fitted number

1. Find the study named in its comment (inventory in `game/sim/CLAUDE.md`).
2. Run it against the BAKED defaults, then with your candidate value.
3. Compare the arc, not the endpoint — the failures above were "summit at generation 3" and "stall at
   tier 25", both of which look fine if you only check that the numbers are finite.
4. Record the new provenance in the knob's comment **and here** if it is load-bearing.

## Where the knobs are edited

In-game: **Settings → BALANCE TUNING**. `DevTuningPanel` reflects over `TuningConfig` and groups by
name prefix, so a new `foo_` knob lands in whichever section claims that prefix — or in the catch-all
if none does. It renders **INT and FLOAT only**: a `bool` export is silently skipped, which is why the
codebase uses 0/1 float knobs read as `> 0.5` for switches.
