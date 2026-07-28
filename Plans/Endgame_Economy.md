# Endgame Economy — gems that stay worth wanting at any scale

**Status: draft for Tim's review (2026-07-28). Nothing implemented.**
Target branch: `feature/civs-12-26`. Companion to `Plans/Progressive_Decay.md` (the wall)
and successor to `Plans/Prestige_Retune.md` (the mint curve, device-approved 2026-07-23).

## Why

Tim's 5-trillion-gem device test (2026-07-28): every Legacy upgrade purchasable was
purchased, the whole ladder cleared "before you even had a chance to see it," the next
prestige quoted gems in the septillions, and the only open sink left was mashing through
dozens of staff-retention buttons. "Still not very well balanced."

Three saturations, hit simultaneously:

1. **Finite sinks.** Every upgrade track caps (the ×1.2 compounders at level 30); maxing
   the entire shop costs on the order of tens of billions of gems (PrestigeStudy Table 3).
   Past ~20B gems the currency has nothing left to buy.
2. **Unbounded faucet.** Minting is `floor(k × (net/$1000)^0.35)` — a power curve tuned
   against estates up to ~$2.5 sextillion (~320K gems). Deep-frontier runs reach net
   magnitudes of 10⁸⁰⁺, where the same curve mints septillions. The mint was never
   designed for the magnitudes the 27-tier ladder produces.
3. **The wall math collapses downstream.** Progressive decay positions the wall against a
   dynasty's multiplier stack — but with (1) and (2), every dynasty rapidly converges to
   the same maxed stack, which was also the "largest stacks finish" reference. The summit
   becomes the default state, and play degenerates into held buttons.

Structural statement: **one prestige layer + an unbounded currency + bounded sinks
guarantees this collapse at some scale, for any decay tuning.** The fix must restore the
locked Idle Slayer principle — *always a next upgrade worth wanting* — at every scale.

## Design goals (the contract)

- G1. At any gem fortune, the shop offers a purchasable next level whose price bites.
- G2. A bigger run always mints visibly more — but mints stay in designed territory
  (currency, not noise). **Decided (Tim, 2026-07-28): endgame mints read in the
  BILLIONS** — "right now the number grows so fast that it doesn't feel valuable."
- G3. The wall's position is a designed, sim-verified function of lifetime gems; the
  final tier falls, slowly, for a dynasty that has banked **about a dozen deep runs'
  mints** (Tim's confirmed summit target) — and only around there.
- G4. AMENDED (Tim, 2026-07-28): the upgrade shop's current curve is NOT preserved —
  "even the first 30 levels feel like they cost too few gems and grant outsized
  bonuses; I'd like the curve more gradual from the beginning." So the compounder
  re-curve applies from level 1 (no seam at 30). Still untouched: the mint below its
  knee, the decay bands, all property costs/cycles, and the pre-prestige game.

## Change A — uncapped compounders on ONE gradual curve from level 1 (the sink)

The ×1.2-per-level compounding tracks (Family Fortune, Efficiency Experts, Strong-Arm
Tactics, Killer Instinct, Second Wind, …) lose their max_level AND their current cost
curve. Per Tim's amendment there is no preserved region and no seam — one smooth curve
from the first level, steeper overall than today's, so early levels stop feeling like
outsized bonuses at throwaway prices and late levels absorb any fortune.

- **Effect per level: unchanged (×1.2 compounding).** All correction goes through COST —
  one lever, and an upgrade purchase always feels like the same meaningful step; it just
  has to be earned. (Flagged as open question 1 in case Tim also wants the effect eased.)
- **Cost shape candidates** (per track: `cost(n) = base × growth-product`, uncapped):
  - **Shape 1 — flat-but-steeper geometric, `g` per level, g ∈ {2.5, 2.75, 3.0}.**
    Simple, one knob. Early levels rise modestly in absolute terms (level 5 ≈ 2–5×
    today's), level 30 costs orders of magnitude more than today's 9.7B, and a fortune
    `G` maps to multiplier ~`G^(ln 1.2 / ln g)`: at g = 2.75, ×1000 more gems buys
    ~×3.7 more income — gradual, never worthless, never runaway.
  - **Shape 2 — progressively steepening: `growth(n) = g0 × s^n`** (e.g. g0 = 2.0,
    s ∈ {1.02, 1.03}). Starts almost exactly like today and steepens continuously —
    the most literal "more gradual from the beginning," and the strongest brake deep
    (each level's growth factor itself keeps climbing, so NO fixed fortune-exponent
    exists — deep fortunes buy ever fewer levels).
  - Recommendation: **Shape 2, s ≈ 1.03** — it honors "gradual from the beginning"
    exactly (first-prestige purchases at ~800-gem mints stay accessible), while its
    ever-steepening deep end pairs naturally with the dozen-runs summit.
- Knobs in TuningConfig (dev-panel tunable, no constants in code): the per-level base
  growth and, for Shape 2, the steepening rate. `legacy_upgrade_cost_multiplier` (the
  global ×3 brake) folds into the new curve rather than stacking on top.
- Non-compounding utility tracks (Trust Fund, Estate Lawyers, Cooling Systems, …) STAY
  capped — their caps are ergonomic, not economic (open question 3).
- No save migration: existing LEVELS remain valid at their owned counts; only future
  purchase prices change. (Tim's 5T save keeps its maxed levels and immediately has a
  real next price to look at.)
- UX: LegacyScreen's hold-to-buy already paces long climbs; the steepening price makes
  "hold until broke" self-limiting.
- Co-tuning constraint (the summit): under the new mint (Change B), a dozen deep runs
  banks roughly 50–200B lifetime gems; the curve constants are chosen so THAT fortune's
  multiplier — on top of maxed staff and normal play — is what cracks tier 27 slowly.
  This is the sim pass's primary fit target, not a hand-picked constant.

## Change B — mint soft-cap (the faucet)

Piecewise mint curve, keeping the approved behavior through its validated range:

```
net ≤ KNEE:  gems = floor(k × (net/$1000)^alpha)            (exactly today's curve)
net > KNEE:  gems = floor(gems(KNEE) × (net/KNEE)^alpha_deep)
```

- `KNEE` ≈ $1 sextillion (the neighborhood PrestigeStudy validated; exact value from the
  study so the curve is continuous through the device-approved rows).
- **Decided (Tim, 2026-07-28): `alpha_deep` = 0.06 — endgame mints read in the
  BILLIONS.** At a 10¹⁰⁰ estate this mints ~tens of billions per run (vs ~10²⁷ under
  today's curve): a dozen deep runs banks the ~50–200B-gem summit fortune, and the
  number on the prestige button stays a number that feels valuable.
- Two new TuningConfig knobs (`legacy_knee_net`, `alpha_legacy_deep`), dev-panel tunable.
- The waterfall (exemption/tax/loopholes) is untouched — this bends only the final curve.

## How A + B + the decay bands compose

Lifetime gems → (B keeps them on a designed curve) → (A maps them to a slowly-growing
multiplier) → (Progressive Decay positions the wall against that multiplier). Each link
is separately tunable and separately sim-checkable, so endgame balance stops being an
emergent accident.

**The designed top (decided: a dozen deep runs):** under alpha_deep 0.06 that is a
lifetime fortune of roughly 50–200B gems. The cost-curve constants are FIT to make that
fortune's multiplier the one that cracks tier 27 slowly — the summit is the target the
sim pass solves for, not an emergent accident.

## Validation matrix (all sim-gated before device)

1. **PrestigeStudy** extended with deep-magnitude rows (10³⁰ … 10¹⁰⁰ net) × knee/alpha_deep
   candidates — read down the columns: mints keep growing, stay legible, no runaway.
2. **EpochPaceStudy** with curve-aware greedy upgrade buying, stacks {830 (a first
   prestige), 10M, 66M, 447M, 5T, designed-top}: every below-top stack shows per-epoch
   ratios ≥ ~1.5 before the final tier; the designed-top row clears tier 27. Since the
   re-curve touches level 1, ALSO gate the entry experience: a first-prestige mint
   (~800 gems) must still buy several meaningful levels, and the low-stack rows'
   early-epoch pace must stay in today's band (no early-game slowdown creep).
3. **Dynasty protocol** (GDD §13 speeds-up-every-time) + waterfall spot-check still pass.
4. Full gate suite (EpochTest, MoneyTest, RushOverheatTest, ChallengeGoalsTest) + boot.
5. Device: Tim resumes the 5T-gem save — the shop must offer a real next purchase, the
   next prestige must quote a large-but-legible mint, and the deep epochs must resist.

## Explicitly separate (queued, not this plan)

- **Staff-retention bulk-buy UX** ("way too many buttons") — its own small plan; the
  pressure also drops once retention stops being the only open sink.
- Vent-bonus stacking cap (flagged in `Plans/Progressive_Decay.md`) — revisit only if
  deep pacing still feels off after this lands.

## Decisions so far (Tim, 2026-07-28)

- The compounder curve is re-shaped from LEVEL 1 — no preserved first-30, no seam;
  gradual and steeper throughout ("even the first 30 levels feel too cheap and grant
  outsized bonuses").
- Summit population: **a dozen deep runs' banked mints finishes the ladder.**
- Mint bend: **alpha_deep = 0.06** — endgame mints read in the billions.

## Open questions for Tim

1. Effects: keep ×1.2 per level and correct through COST only (recommended — one lever,
   every purchase stays a meaningful step), or also ease the per-level effect?
2. Curve shape: Shape 2 (progressively steepening, s ≈ 1.03 — recommended) or Shape 1
   (flat geometric ~×2.75 per level)?
3. OK that the capped utility tracks (Trust Fund etc.) stay capped?
