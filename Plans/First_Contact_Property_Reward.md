# First Contact Reward — New Alien Property Types

**Status:** BUILT (starting-units model) — **but being REDESIGNED (2026-07-01).** See the redesign
section immediately below; the original as-built model and plan follow it, kept for history.

---

## REDESIGN 2026-07-01 — property carries the epoch leap; minigame is an upside-only bonus

**Why.** On device, civ 2/3 felt too small. The configs confirm it: **all five alien properties
share the exact same base cost ($500B) and base income ($671.6B = 5× Executive Assets); only the
cycle length changes, and it gets *longer* each tier** — so Data Foundry (tier 3) is no better than
Photon Exchange (tier 2), and Time Bank (tier 6) pays *less per second* than the first alien
property. There is zero income scaling across the alien ladder. Separately, the "starting units"
head-start meant you already owned several of the new property the moment you arrived, which killed
the sense of achievement in reaching the income to buy your first one.

**New model (Tim's decisions, 2026-07-01):**

1. **The epoch income leap now lives in the PROPERTY, not staff.** Each alien property's base
   magnitude scales with its epoch band — **first-pass ~30×/tier**, tracking `economy_scale =
   30^(tier-1)` — and cycle length stops growing (ideally shrinks) so per-second improves each
   tier. Staff is demoted: it is no longer the epoch multiplier.

2. **No starting units — you own ZERO at epoch start.** The property unlocks but you must *buy* your
   first one. Tune each alien property to feel **expensive relative to your progress at arrival** —
   a real stretch to afford the first unit — then it pays off big as its higher income compounds.
   (Delete the `first_contact_starting_units` grant path.)

3. **The minigame is upside-only, bucketed.** The floor is always the property's **base income —
   the player never gets less, whatever the minigame result.** A bonus, if earned, is a **permanent
   boost to that property's income-per-cycle AND cycle-time**, sorted into **three buckets: low /
   medium / high**. A poor run or a Skip = base only, never a penalty. (This replaces the universal
   0.5×→1.25× keep-floor spectrum for THIS site; it becomes bonus-on-top-of-a-guaranteed-floor.)

**Decided (Tim, 2026-07-01):**
- **Alien properties stay staffable for hands-off automation only** — staffing grants **no epoch
  multiplier**; income scale is the base magnitude + the minigame bonus. (Full §6 staffing rewrite
  deferred until this model is validated.)
- **Bucket bonuses (first-pass, to feel-tune)** apply to **both income-per-cycle AND cycle-time**:
  low **+15% income / −5% cycle**, medium **+40% / −12%**, high **+80% / −20%**. Floor = base
  income with no bonus (poor run / Skip).

**Work implied (not yet done):**
- Re-tune the five alien property `.tres` magnitudes (cost + income) to the ~30×/tier ladder;
  flatten or shrink `base_cycle_length` down the ladder.
- Remove the starting-units grant; add the epoch minigame → 3-bucket permanent multiplier on the
  new property (income + cycle-time), with a base-income floor.
- Re-run the dynasty sim / epoch-timing study once the numbers land (it can't reach epoch 2 in a
  per-generation budget, so a targeted harness or dev-jump is needed).

**Open items:** the two defaults above (alien staffability, bucket values); exact per-tier magnitude
multiplier (~30× is a starting point); whether cycle-time is part of the bonus or income-only.

---

## Original as-built model (starting units) — kept for history

**Status (original):** BUILT — all 4 phases complete 2026-06-28 (branch `feature/first-contact-property-reward`,
Phases 1–4 = commits 6b9f9ab, d694e48, 0c750d2, + copy/doc-sync). NOT yet merged to main;
on-device feel-test (reach epoch 2 to play the negotiation) still owed.

**As-built deltas from the plan below:** (a) skip/opt-out banks the keep-floor SHARE of the cap,
not 0 units — matches the GDD §5.5 rule the other two minigame sites use (plan §2/§7-Q1 said "0");
(b) magnitude is a FIXED flagship (~5× Executive Assets), epoch scaling from staffing only — NOT
anchored to economy_scale (an economy_scale anchor double-counted the epoch; see §6 / Sim study);
(c) reveal-after-contact chosen for locked rungs (plan §7-Q2 recommendation).
**GDD reference:** §5.5 minigame usage site 2 ("Epoch change / First Contact").
**Decided by:** Tim chose "new property type" over the GDD's three TBD options
(entry income boost / starting cash / first-staffer discount) on 2026-06-24. Design
recommendations below were left to Claude's judgment (Tim "no preference", 2026-06-28).

---

## 1. The design problem

A property is **unlocked or not** — binary. The other two minigame sites (prestige,
welcome-back) map performance [0,1] onto a 0.5×→1.25× *multiplier*; an unlock can't be
multiplied. So First Contact needs a different mapping. Tim's intent: winning the alien
trade negotiation should "open a genuinely new *kind* of business," not just hand out cash.

## 2. Chosen model

**Each epoch's First Contact appends ONE new alien property to the ladder. The minigame sets
the TERMS of the deal — a head start — not whether you get the property.**

- The new property is a normal `PropertyConfig`, themed to the race, magnitude-tuned to that
  epoch's economy band. 5 aliens (Luminari, Geth-Sentinel, Mycelium, Quartzite, Chronophage)
  = **5 new properties** beyond the 12 Earth ones.
- It drops into the existing ladder, visibility/peek rule, milestones, staffing, and the
  per-epoch staff level-up track with **zero new mechanics** — it is simply not *purchasable*
  until its race is contacted.
- **Performance scales the opening head start, not the unlock.** You always walk away with the
  business (you made the deal). Chosen knob: **starting units** — performance [0,1] → N free
  units already running (0 → cap, first-pass cap ~8). A poor result or Skip = 0 starting units
  but you still own a normal property to buy into. This preserves "skip has a real cost"
  (you negotiated nothing) without the punishing "you lose the property."

Why starting units over the alternatives (cost discount / starting staff level): most legible
("you walked away with 6 already running"), reuses income math directly, no second concept
layered on the unlock. Knob is swappable later if feel-testing wants it.

## 3. What's genuinely new plumbing

Today all 12 properties live in a **fixed always-loaded array** (`ConfigLoader.PROPERTY_PATHS`)
with **no per-property unlock gate** — every property is purchasable, gated only by affordability
and the visibility/peek rule. The new concept needed:

- **Per-property "unlock at epoch tier N" gate.** Add `unlock_tier: int` to `PropertyConfig`
  (Earth's 12 = tier 1; each alien property = its epoch tier). A property is purchasable/visible
  only when `EpochState` has reached `unlock_tier`.
- **Visibility rule update.** `get_cheapest_unaffordable_unowned_index()` and the ladder build
  must skip not-yet-unlocked properties (don't peek-tease a property the player can't reach yet —
  or DO, as a deliberate tease; see open question Q2).
- **Starting-units grant** applied once at First Contact, after the minigame resolves.

## 4. Integration points (files)

- `scripts/resources/PropertyConfig.gd` — add `unlock_tier` (default 1).
- `config/properties/13_*.tres … 17_*.tres` — 5 new alien property configs + register paths in
  `ConfigLoader.PROPERTY_PATHS`.
- `scripts/core/EconomyState.gd` — unlock gate in visibility/purchasability; a
  `grant_starting_units(prop_index, n)` helper.
- `scripts/core/EpochState.gd` / `Main.gd` — on `contact_made`, fire the First Contact minigame
  (currently LEFT UNWIRED per GDD §5.5); on finish, map performance → starting units → grant on
  the epoch's new property; then show the contact overlay.
- `scripts/ui/MinigameScreen.gd` — a new reward context (reuse `make_reward`-style statics) so the
  result screen reads "Negotiated: 6 starting units of <Property>" instead of money/Legacy.
- `scripts/ui/FirstContactOverlay.gd` — surface the negotiated property + units.
- `GameState` — SAVE_VERSION bump if any new persisted field (unlock state derives from epoch tier,
  so likely none needed; confirm during build).
- `sim/EpochTest.gd` — new section: unlock-gate correctness, starting-units grant, save round-trip.

## 5. Prestige interaction

Prestige resets to Earth, so alien properties re-lock until each epoch is re-reached — consistent
with epochs being re-earned every run. The minigame fires again at each contact. No special-casing.

## 6. Content scope (deferred art per M3)

5 new `PropertyConfig`s, each needing: magnitude tuned to its epoch band (Mechanics Spec ladder
math already handles arbitrary properties), a themed name, accent color, and art (manager portrait
deferred to the M3 art pass like the Earth 12). First-pass magnitudes are sim-tunable.

## 7. Open questions for Tim (non-blocking)

- **Q1 — starting-units cap & curve.** First-pass cap ~8 units, linear performance→units. Feel-tune.
- **Q2 — tease locked properties?** Show the next epoch's alien property grayed/locked in the ladder
  before contact (anticipation), or only reveal it after contact (surprise)? Recommend: reveal after
  contact, matching the "negotiation opened it" fiction.
- **Q3 — one property per epoch, or could a richer epoch open several?** Recommend one (clean cadence).

## 8. Build phasing

1. `unlock_tier` on `PropertyConfig` + EconomyState gate + visibility update + EpochTest coverage.
2. One alien property config (Luminari, tier 2) end-to-end; wire First Contact minigame → starting
   units; verify the full loop headless + screenshot.
3. Author the remaining 4 alien properties; magnitude-tune via the sim.
4. Result/overlay copy polish; doc sync (GDD §5.5, Mechanics Spec, Art Guide).
