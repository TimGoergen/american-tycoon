# Per-Epoch Upgrade Track — Design Note

**Status:** design proposal, NOT built. Written 2026-06-27.
**Author:** Claude (for Tim's review).
**Companion to:** `Epoch_Staffing_System.md` (the system this extends), the 2026-06-27 epoch-pacing rework (GDD §6.2 "Epoch pacing — the law").

---

## 1. The problem this solves

The 2026-06-27 pacing rework fixed the *math* of epochs — each epoch now arrives
faster than the last instead of ~60× slower. But it only fixed pacing. The
moment-to-moment experience inside an epoch is still thin:

> "the only change is that new staff are available… moment-to-moment is still
> watching a bar." (Tim)

On contact you hire the new alien staffer for each property (one tap each), and
then there is **nothing left to buy that matters** until the next contact. Flat
property-unit purchases are irrelevant at that scale (the original complaint), and
the Legacy shop is a between-lives sink, not a within-life one. This violates the
prestige-loop acceptance criterion #3 (Idle Slayer model):

> **"There's always a next upgrade to chase, and it has meaningful feel."**

The fix is a **continuous purchase cadence that lives inside an epoch** — something
to spend the rising tide of dollars on, right now, that visibly speeds you up.

## 2. Design constraints (must respect)

1. **One currency.** Everything is Earth dollars (GDD §6.2). No new resource.
2. **Don't re-break the pacing law.** Per-epoch duration ratio = economy_step ÷
   staff_step must stay flat-or-accelerating. Any new sink that adds income has to
   be accounted for, not bolted on blind.
3. **Extend, don't rebuild.** The per-property `staff_tier` system already exists
   (`PropertyState.staff_tier`, `EconomyState.try_hire/get_staff_cost`,
   `EpochCatalog.staff_income_multiplier`). Prefer a small, reviewable addition.
4. **Orthogonal to Legacy.** Legacy upgrades accelerate *across a bloodline*
   (compounding, permanent). An epoch track should accelerate *within a life* and
   reset/re-climb each life, so the two never collapse into one dial.

## 3. Options

### Option A — Within-epoch staff levels (RECOMMENDED)

Today a property's staffer makes **one** jump per epoch (the ×40 ladder entry
multiplier), then sits flat. Instead, let the staffer **level up many times inside
the current epoch**, each level a small compounding income multiplier on that
property.

- Add a per-property `staff_level: int` (resets to 0 each time you advance a tier —
  the new alien staffer is a fresh hire).
- Total staff multiplier = `staff_income_multiplier(tier) × (1 + LEVEL_STEP)^staff_level`.
- The epoch's ×40 *entry* jump stays; the levels fill the long middle of the epoch
  with a steady "buy the next one" cadence.
- Cost per level anchored to the epoch economy (like alien hire cost is now), with
  a geometric growth so there's always a next one but it's never free.
- Gated by contact: `staff_level` can only be bought while you're in that epoch;
  reaching the next epoch swaps the staffer and restarts the track at a higher base.

**Theme fit:** strong. "The Luminari keep selling you better light-tech" — Photon
Teller Mk II, Mk III. Each epoch's roster already has names (`EpochCatalog`); levels
are just "+1" on the same staffer. Reads as *the alien relationship deepening*, not a
new screen.

**Pacing-law interaction:** clean. Income at "end of epoch T, fully leveled" =
base × staff_mult(T) × max_level_bonus. The *ratio* between epochs is still ≈
staff_step (the max_level_bonus is a constant factor present in every epoch), so the
acceleration property survives. Bonus: within an epoch income now *ramps* as you buy
levels instead of being flat — the epoch becomes a build-up curve, which is exactly
the engagement we want. (The epoch-timing study in `Sim.gd` will need a small update
to fold the level bonus into its projection so the law stays self-verifying.)

**Cost:** smallest of the three. One new int field, one formula, save-schema bump,
a UI affordance on the staff button (HIRE → UPGRADE → LV n). It is a direct
generalization of the system that already shipped.

### Option B — Per-epoch tech shop

On contact, open a shop of *that civilization's* tech: a handful of global upgrades
(income ×, cycle speed, offline cap, rush power…) bought with dollars, priced to the
epoch economy, that advance/reset per epoch.

**Theme fit:** good — a "first-contact marketplace." But it duplicates the Estate
Office shop UI and overlaps the Legacy catalog's effect types, risking "which shop
does what?" confusion. More content + a whole screen.

**Verdict:** more engagement variety than A, but heavier and with overlap risk.
Worth revisiting only if A proves too thin on its own.

### Option C — Per-epoch modifier choice (already PARKED in GDD Future Features)

GDD Future Features (Tim, 2026-06-14) parks the idea that entering an epoch prompts
a **one-of-two-modifier choice** (specialization vs. expansion).

**Relationship to this note:** C is a *one-time decision per epoch* (novelty,
flavor), NOT a continuous sink — so **it does not fix the bar-watching problem** on
its own. C and A are complementary: A gives the moment-to-moment cadence; C gives the
per-epoch "interesting choice." They can ship independently. This note recommends A
first because it targets the actual complaint; C stays parked as the novelty layer.

## 4. Recommendation

**Build Option A.** It is the smallest change, the strongest theme fit, it directly
extends the system that just shipped, and it preserves the pacing law we just
established. It converts each epoch from "one hire, then watch a bar" into a steady
ladder of meaningful purchases — criterion #3, satisfied *within* a life rather than
only across the bloodline.

Treat B and C as later, optional layers, not prerequisites.

## 5. Interactions to settle before building

- **`staff_cost_fraction` (the "staff too cheap at contact" item).** Independent of
  this note, but they touch the same code. The *entry hire* (level 0 of a new tier)
  is what `staff_cost_fraction` prices; the *levels* are a separate cost curve. Decide
  both together so the staff button's whole cost story is coherent: a meaningful entry
  hire, then a level track that stays affordable-but-not-free.
- **First-Contact "new property type" reward (GDD §5.5, design-pending).** If contact
  also unlocks a *new kind of business*, that new property would carry its own staffer
  and thus its own level track — A composes with it cleanly (every property, new or
  old, has the same staff_level mechanic). Worth confirming A's shape before locking
  the new-property reward so they share one staffing model.
- **Sim.** `_run_epoch_timing_study` and the dynasty protocol must be updated to
  exercise the level track, and the timing study's projection must fold in the
  level bonus, or it will under-report income and mis-state the pacing law.

## 6. Open questions for Tim

1. **Does `staff_level` reset each epoch (re-climb a fresh track) or carry across
   epochs (compounding)?** This note assumes RESET (clean repeated cadence, pacing-law
   safe). Carry-over compounds and risks runaway — would need its own tuning.
2. **One level track per property, or a single global staff level?** Per-property
   keeps the cross-property allocation decision alive (GDD §11); global is simpler but
   flatter. This note assumes per-property.
3. **How fast should the level track run relative to the epoch?** i.e. how many
   levels is "fully leveled," and what `LEVEL_STEP` — a TBD-SIM tuning pass once the
   mechanic exists (the dev tuning panel can expose it).
4. **Ship A alone first, or design A + the `staff_cost_fraction` retune as one staff
   pass** (since they share the staff button and cost story)? Recommend the latter.

## 7. Rough implementation sketch (if A is approved — NOT yet built)

- `PropertyState`: add `staff_level: int`; fold `(1 + LEVEL_STEP)^staff_level` into
  the staff multiplier used in `get_income_per_cycle`; reset on `set_staff_tier`.
- `EconomyState`: add `get_staff_level_cost(prop_index)` (epoch-economy anchored,
  geometric); extend `try_hire` (or add `try_upgrade_staff_level`) to spend it.
- `TuningConfig`: `staff_level_step`, `staff_level_cost_*` constants (dev-panel
  exposed, TBD-SIM).
- `GameState` save: bump SAVE_VERSION, persist `staff_level` (default 0 for old saves).
- `PropertyRow` UI: staff button shows HIRE → UPGRADE TIER (at contact) → LV n
  (within epoch); the existing tiered-button code is the starting point.
- `Sim.gd`: drive level buys in the playout; fold the level bonus into
  `_run_epoch_timing_study`'s projection.

All headless-verifiable before any UI, same as the original epoch-staffing build.
