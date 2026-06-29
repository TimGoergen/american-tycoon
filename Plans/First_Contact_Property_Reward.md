# First Contact Reward — New Alien Property Types

**Status:** BUILT — all 4 phases complete 2026-06-28 (branch `feature/first-contact-property-reward`,
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
