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
  (currency, not noise).
- G3. The wall's position is a designed, sim-verified function of lifetime gems; the
  final tier is reachable "in reasonable time" by a dynasty near the TOP of the designed
  gem curve (Tim, 2026-07-28) — and only near it.
- G4. Everything device-approved is untouched: upgrade levels 1–30 (costs AND effects),
  the mint below its knee, decay bands, all property costs/cycles, early/mid pacing.

## Change A — uncapped compounder tails (the sink)

The four-plus ×1.2-per-level compounding tracks (Family Fortune, Efficiency Experts,
Strong-Arm Tactics, Killer Instinct, Second Wind, …) lose their max_level. Levels 1–30
keep their exact shipped costs and effects. From level 31 the track enters its TAIL:

- Effect per level: unchanged (×1.2 compounding — the track stays itself).
- Cost growth per level: jumps from the shipped ~×2 to a much steeper `tail_growth`.

Why this shape works: with cost growth `g` per level, a fortune `G` buys ~log_g(G) tail
levels, so the effective multiplier grows as `G^(ln 1.2 / ln g)` — POLYNOMIALLY SLOWER
than the fortune. Gems never go worthless (G1), yet no fortune runs away (G3's wall
always sits ahead). The wall-position-vs-gems curve becomes a designed dial:

| tail_growth g | multiplier scales as | ×1000 more gems buys… |
|---|---|---|
| ×5 | G^0.113 | ×2.2 income |
| **×8 (recommended)** | **G^0.088** | **×1.8 income** |
| ×12 | G^0.073 | ×1.7 income |

- One global `legacy_tail_cost_growth` knob in TuningConfig (dev-panel tunable, no
  constants in code), applied by every compounding track past its old cap.
- Non-compounding utility tracks (Trust Fund, Estate Lawyers, Cooling Systems, …) STAY
  capped — their caps are ergonomic, not economic.
- No save migration: existing levels remain valid; the cap simply stops existing.
- UX: LegacyScreen's hold-to-buy already paces long climbs; the tail's price growth makes
  "hold until broke" self-limiting.

## Change B — mint soft-cap (the faucet)

Piecewise mint curve, keeping the approved behavior through its validated range:

```
net ≤ KNEE:  gems = floor(k × (net/$1000)^alpha)            (exactly today's curve)
net > KNEE:  gems = floor(gems(KNEE) × (net/KNEE)^alpha_deep)
```

- `KNEE` ≈ $1 sextillion (the neighborhood PrestigeStudy validated; exact value from the
  study so the curve is continuous through the device-approved rows).
- `alpha_deep` candidates: **0.10 (recommended)** / 0.06. At a 10¹⁰⁰ estate: ~tens of
  trillions of gems per run at 0.10, ~tens of billions at 0.06 — big, legible, and the
  tail cost curve absorbs either logarithmically. (For contrast, today's curve mints
  ~10²⁷ there.)
- Two new TuningConfig knobs (`legacy_knee_net`, `alpha_legacy_deep`), dev-panel tunable.
- The waterfall (exemption/tax/loopholes) is untouched — this bends only the final curve.

## How A + B + the decay bands compose

Lifetime gems → (B keeps them on a designed curve) → (A maps them to a slowly-growing
multiplier) → (Progressive Decay positions the wall against that multiplier). Each link
is separately tunable and separately sim-checkable, so endgame balance stops being an
emergent accident.

**The "designed top"** (G3's summit population): propose "a dynasty that has banked the
mints of ~a dozen deep runs under the new curve" — concretely a lifetime fortune around
10¹⁴–10¹⁵ gems at alpha_deep 0.10. Tail level ≈ 30 + log₈(10¹⁵/20e9) ≈ 35–36 levels →
total multiplier ≈ maxed-shop × ~2.5-3 — sized so tier 27 falls, slowly, at that stack.
(These are starting figures; the validation matrix decides.)

## Validation matrix (all sim-gated before device)

1. **PrestigeStudy** extended with deep-magnitude rows (10³⁰ … 10¹⁰⁰ net) × knee/alpha_deep
   candidates — read down the columns: mints keep growing, stay legible, no runaway.
2. **EpochPaceStudy** with tail-aware greedy upgrade buying, stacks {66M, 447M, 5T,
   10¹², designed-top}: every below-top stack shows per-epoch ratios ≥ ~1.5 before the
   final tier; the designed-top row clears tier 27; bare/10M/66M rows byte-match today's
   through their unchanged regions.
3. **Dynasty protocol** (GDD §13 speeds-up-every-time) + waterfall spot-check still pass.
4. Full gate suite (EpochTest, MoneyTest, RushOverheatTest, ChallengeGoalsTest) + boot.
5. Device: Tim resumes the 5T-gem save — the shop must offer a real next purchase, the
   next prestige must quote a large-but-legible mint, and the deep epochs must resist.

## Explicitly separate (queued, not this plan)

- **Staff-retention bulk-buy UX** ("way too many buttons") — its own small plan; the
  pressure also drops once retention stops being the only open sink.
- Vent-bonus stacking cap (flagged in `Plans/Progressive_Decay.md`) — revisit only if
  deep pacing still feels off after this lands.

## Open questions for Tim

1. Tail growth: ×8 as the seed? (×5 keeps late shopping sprees juicier; ×12 pins the
   wall harder.)
2. Mint bend: alpha_deep 0.10 (trillions-scale endgame fortunes) or 0.06
   (billions-scale)? Purely about what NUMBER you like reading on the prestige button.
3. The designed top: is "roughly a dozen deep runs' worth of banked mints finishes the
   ladder" the right summit population?
4. OK that the capped utility tracks (Trust Fund etc.) stay capped?
