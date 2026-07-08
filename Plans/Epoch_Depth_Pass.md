# Epoch Depth Pass — Implementation Plan

**Status:** DRAFT for Tim's review. Written 2026-07-04.
**Author:** Claude.
**Decisions of record:** GDD §6.1/§6.2 playtest-verdict + directive blocks (2026-07-03);
`Per_Epoch_Upgrade_Track.md` and `First_Contact_Property_Reward.md` addenda (decisions
recorded 2026-07-03).
**Supersedes (in part):** the one-property-per-epoch model in `First_Contact_Property_Reward.md`
and the current staff tier/level split described in `Per_Epoch_Upgrade_Track.md`.

---

## 0. What this pass delivers, in one paragraph

Each alien epoch becomes a real chapter instead of a speed bump: **four new properties
per civilization** that stage in through the epoch the same way Earth's ladder reveals
itself, a **single sequential staff-upgrade ladder** whose 20-level blocks keep the
prices and effects of the epoch they were born in (so nothing ever silently reprices),
and a **re-tuned epoch duration law** so post-Earth epochs hold their own weight instead
of blurring past. Three systems, one pass, because they share the same income math and
must be sim-balanced together.

---

## 1. Where the code actually is today (survey, 2026-07-04)

The build is closer to Tim's model than the design docs suggested. Key as-built facts:

- **20-level blocks already exist.** `TuningConfig.staff_levels_per_epoch = 20`;
  the level cap is already `20 × reached_tier` (`EconomyState.get_staff_level_cap`),
  and `staff_level` is already ONE cumulative ladder that persists across contacts
  (2026-07-02 change, `PropertyState.set_staff_tier` no longer resets it).
- **The cost curve already restarts per block** — `get_staff_level_cost` indexes
  `staff_level % 20` — **but it anchors to the CURRENT tier's entry cost**
  (`get_staff_cost(prop_index, prop.staff_tier)`). That re-anchoring is the exact
  repricing shock Tim hit at the Earth→Luminari transition.
- **The level effect is one global constant** (`staff_level_step = 0.33`, additive
  `1 + 0.33 × level`), not epoch-defined.
- **Tier hires are a separate purchase and a separate button state.** The hire button
  runs a three-state machine (HIRE → UPGRADE tier → LVL n), and at contact it flips
  from cheap LVL costs to an UPGRADE hire anchored to the NEW epoch's economy
  (`earth_target × economy_scale(tier) × staff_cost_fraction × 1.4^prop_index`) —
  the disabled-buttons-with-huge-numbers moment.
- **Earth properties still carry the 40^(tier−1) staff-tier entry multiplier**, while
  alien properties hire at multiplier 1.0 (automation only) and scale by their own
  base magnitude instead (the 2026-07-01 "property carries the leap" redesign). Two
  scaling systems co-exist; GDD §6.2 already flags the 40^ ladder as under review.
- **Staged unlocks are free.** `is_property_unlocked` gates by `unlock_tier`, and the
  peek rule (`get_cheapest_unaffordable_unowned_index`) reveals one rung at a time —
  a cohort of ascending-cost properties stages through an epoch with ZERO new
  mechanics, purely from data. Ladder iteration everywhere uses `.size()`; no
  hardcoded 12/17 (verified: ladder build, save restore via `mini()`, retention list,
  peek rule).
- **The First Contact bonus is per-property plumbing already** (save v8:
  `first_contact_income_mult` / `first_contact_cycle_mult` on every property, bucket
  table shared between Main and MinigameScreen). Cohort-wide = apply the same bucket
  to N properties instead of 1; the save schema doesn't change.

Implication: this pass is mostly **re-anchoring + data authoring + tuning**, not new
machinery. The riskiest piece is the save migration and the pacing re-tune, not the
systems themselves.

---

## 2. System A — one sequential staff ladder with home-epoch blocks

### 2.1 The model (realizes Tim's three rules, 2026-07-03)

Every property has a single integer `staff_level` (already exists) climbing ONE
ordered ladder. The ladder is divided into 20-level blocks; **block b belongs to the
epoch in which it became available** for that property:

- An Earth property's block 1 = Earth, block 2 = Luminari, block 3 = Geth, …
- An alien property's block 1 = its home epoch (`unlock_tier`), block 2 = the next
  epoch, … (its ladder simply starts later — same rule, no special case).

For each block, **both the costs and the effects are constants of that block's epoch**,
computed from the epoch the block belongs to and never from the player's current epoch:

- **Cost:** level `i` (0-based) within block `b` costs
  `block_anchor(property, b) × staff_level_cost_base × staff_level_cost_growth^i`
  where `block_anchor` is the existing epoch-economy formula evaluated at the BLOCK's
  epoch: `earth_target × economy_scale(block_epoch) × staff_cost_fraction ×
  staff_cost_property_growth^prop_index` (Earth blocks keep the property-scaled tier-1
  cost, as today). This is a one-argument change to `get_staff_level_cost` — pass the
  block's epoch instead of reading `prop.staff_tier`.
- **Effect:** each block defines a per-level income step for that epoch,
  `staff_level_step(block_epoch)`, replacing the single global `staff_level_step`.
  Total staff multiplier = `1 + Σ over blocks( step(b) × levels_bought_in_block(b) )`
  — still additive-within-block like today, so nothing compounds runaway; the sizes
  just grow with the epoch.

**Sequential ordering is automatic**: one integer cursor means level N+1 is the only
thing purchasable, and the existing cap (`20 × blocks available`) already prevents
climbing into an epoch you haven't reached. Arriving at epoch 2 with 14/20 Earth
levels = six cheap Earth rungs first, then the visibly-new Luminari block.

### 2.2 The tier hire folds into the ladder (kills the button state machine)

**Proposal: "hire the epoch's staffer" = level 1 of that epoch's block.** Buying the
first level of a block swaps the staffer portrait/name to that epoch's roster entry
and carries a larger step (the entry jump); levels 2–20 are that staffer's Mk II…Mk XX
refinements. Concretely per block: level 1 grants `entry_step(b)`, levels 2–20 grant
`step(b)` each, both block-epoch constants.

- `try_hire` / `try_upgrade_staff_level` collapse into one
  `try_buy_staff_level(prop_index)`; `staff_tier` becomes DERIVED
  (`unlock_tier − 1 + ceil(staff_level / 20)` bounded to blocks entered) instead of stored.
- The hire button loses its three-state machine: it always reads **"LVL n · $cost"**
  (or the staffer name + "HIRE" flavor on a block's first level, if we want the beat),
  and "MAX" only at the true cap. There is no moment where the button silently
  swaps meaning and magnitude — the transition bug class is gone, not patched.
- Automation (cycles run themselves) still switches on at level 1 of the FIRST block,
  exactly like today's first hire.
- The 40^(tier−1) `staff_income_multiplier` entry ladder is **retired** (it was
  already demoted for alien properties on 2026-07-01); Earth properties' epoch
  keep-up now comes from their block steps (tuned in §4). `EpochCatalog`'s
  staff_income_multiplier column survives only if the sim retune wants it as the
  source for `entry_step(b)` sizing.

### 2.3 Save migration (v8 → v9)

New save no longer stores `staff_tier` (derived). Migration for existing saves:

- Earth property (`unlock_tier == 1`), old `staff_tier = t ≥ 1`, old `staff_level = L`
  → new `staff_level = (t − 1) × 20 + L` (completed blocks for tiers below t, plus the
  partial current block; level-1-of-block "hire" rungs are counted by the `(t−1)×20`).
- Alien property, old `staff_tier = 1`, `staff_level = L` → `staff_level = L + 1`
  (the hire becomes level 1 of its home block). Unstaffed stays 0.
- Effects are recomputed from the new ladder (multipliers are derived, not stored) —
  same pattern as the v5 `is_staffed → staff_tier` migration.
- **Staff retention (Legacy)** currently retains a TIER per property. Reinterpret as
  retaining **completed blocks**: retained tier t → heir starts that property at
  `staff_level = blocks × 20` (or level 1 of the retained block — decide with Tim;
  see §6 Q3). Prestige otherwise resets the ladder to 0 as today (GDD §6.3).

### 2.4 Files touched

`PropertyState.gd` (derived tier, per-block multiplier fold), `EconomyState.gd`
(unified cost/buy, block math), `TuningConfig.gd` (per-epoch step tables replacing
`staff_level_step`; keep `staff_levels_per_epoch`, `staff_level_cost_base/growth`),
`GameState.gd` (SAVE_VERSION 9 + migration), `EpochCatalog.gd` (staffer name per
block already exists via `staffer_name(tier, prop)`), `PropertyRow.gd` (single-state
button), `StaffRetention` + Estate Office copy, `EpochTest.gd` (rewrite the staff
tracks: ordering, home-epoch costs, migration, retention).

---

## 3. System B — four-property cohorts per alien epoch

### 3.1 Shape

**Four new properties per alien civilization** (Tim's 3–5; four is the sweet spot —
see §3.2 spacing math), each a plain `PropertyConfig` with that epoch's `unlock_tier`.
5 epochs × 4 = **20 alien properties, 32 rungs total.** The existing flagship five
(Photon Exchange, Data Foundry, Spore Bank, Prism Vault, Time Bank) become the FIRST
member of their cohorts; three new siblings each.

### 3.2 Magnitude ladder (why four)

The epoch band is `economy_step ≈ 30×` wide (whatever §4 retunes it to). Spacing
cohort members ~×3 apart in cost/income makes four of them span `3^3 ≈ 27` — almost
exactly one band, so the last cohort member hands off cleanly to the next epoch's
first. (Three members ×3 spans only 9× and leaves a dead stretch; five squeeze to
×2.3 and arrive too fast to feel distinct.) First-pass rule:

- `base_cost(t, k) = flagship_cost(t) × 3.0^k` for cohort slot k = 0..3, where
  `flagship_cost(t)` keeps today's entry-premium anchoring (Photon Exchange $24T at
  epoch 2 — the 8× premium may relax to ~4–6× now that the epoch has four save-up
  moments instead of one; TBD-SIM).
- `base_income(t, k)` proportional to cost with roughly today's payback ratio; slot-0
  keeps the stiffest payback (the "you arrived" wall), later slots ease off so
  buying deeper into the cohort snowballs.
- `base_cycle_length` flat-to-shrinking across the cohort (per the 2026-07-01 rule:
  per-second must improve down the ladder).
- Exact `.tres` numbers are a TDD-SIM table generated once the §4 study picks the
  economy step; do not hand-tune 20 files twice.

### 3.3 Staged unlocks — pure data, zero new code

All four cohort members get `unlock_tier = t`. The existing peek rule then stages
them exactly like Earth's ladder: at contact the flagship appears (peek → afford →
buy), and each next sibling surfaces as the previous becomes affordable history. This
is precisely "consistent with the rest of the game" (Tim's decision) — no mid-epoch
unlock thresholds, no second gating mechanism. If feel-testing later wants a harder
tease, that's a peek-rule tweak, not a cohort change.

### 3.4 Cohort-wide First Contact bonus

The negotiation minigame's low/med/high bucket applies to **every property of that
epoch** (Tim's decision):

- `EconomyState.get_property_index_for_unlock_tier` →
  `get_property_indices_for_unlock_tier` (returns Array[int]);
  `Main._finish_first_contact_minigame` loops it, calling the existing
  `set_first_contact_bonus` per member. Storage/save unchanged (v8 fields are already
  per-property).
- Minigame framing: pitch the round as negotiating with the CIVILIZATION ("Broker the
  Luminari trade terms"), and the Get Ready gate lists what's at stake ("terms apply
  to all Luminari ventures").
- With minigames off / Skip: base terms (bucket 0) for the whole cohort — unchanged rule.

### 3.5 Content to author

- **20 `.tres` configs** (ids 13–32, re-slotting the 5 existing) + accent colors.
- **Names, first-pass** (satire register, one businesslike + increasingly absurd per civ):
  - *Luminari (light/energy):* Photon Exchange · Beam Utilities · Solar Futures Desk · Dyson Holdings
  - *Geth-Sentinel (machine/logic):* Data Foundry · Server Metropolis · Algorithm Mines · Robo-Labor Agency
  - *Mycelium (fungal/spread):* Spore Bank · Hyphae Networks · Biomass Refinery · Terraforming Co-op
  - *Quartzite (crystal):* Prism Vault · Gem Exchange · Laser Lens Works · Monolith Realty
  - *Chronophage (time):* Time Bank · Deadline Futures · Moment Market · Eternity Escrow
- **Staffer rosters:** `EpochCatalog.EPOCHS[*].staffer_names` holds 17 entries per
  tier today → 32 per tier × 6 tiers ≈ 90 new names. Draft them formulaically per civ
  voice (the ATM Technician pattern), Tim red-pens.
- **Portrait generator note (GDD §6.5, M3):** role slots grow 17×6 → 32×6 ≈ 192; no
  design change (it's procedural), just more seeds.

---

## 4. System C — pacing re-verify and retune

### 4.1 The problem restated

Playtest verdict: Earth pace is the reference feel (don't touch), time-to-first-contact
good/slightly fast, **every later epoch far too fast**. The old law deliberately made
each epoch ~0.75× the previous (staff step 40 > economy step 30). Tim rejects that
direction for epochs; **target: each epoch takes roughly as long as, or slightly longer
than, the previous** — prestige (not epoch churn) stays the acceleration fantasy.

### 4.2 The new income arithmetic (why retune is mandatory, not optional)

After A + B, income inside an epoch steps up from THREE sources: cohort magnitudes
(~economy_step across the band), the epoch's staff block (entry step + 19 levels), and
Legacy carryover. If cohorts alone track the economy step, epochs are duration-neutral
only when the staff block's total contribution is ~flat per epoch — otherwise we
re-create "too fast" with extra steps. So the block step tables (§2) and the cohort
magnitudes (§3) must be solved TOGETHER against the duration target. Knobs, in
preferred order: `economy_scale` step (30 → likely 45–60), staff block totals,
cohort payback ratios. Constraint kept: time-to-first-contact ≈ today's.

### 4.3 Sim work

- `_run_epoch_timing_study` (Sim.gd): replace the tier-multiplier projection with a
  playout-informed model that folds in (a) cohort buy staging, (b) block-level buying
  with home-epoch costs, (c) the cohort-wide contact bonus. Print per-epoch projected
  duration + ratio; verdict passes at ratio ∈ [1.0, ~1.4].
- Playout policies (`Sim.gd`, `PaceStudy.gd`): teach the greedy policy to buy staff
  levels (a known scope cut today) and cohort properties.
- `EpochTest.gd`: new pins — sequential ordering (can't buy block b+1 rung before
  finishing block b), home-epoch cost anchoring (Earth leftovers stay Earth-priced
  after contact), v9 migration correctness, cohort-wide bonus application, staged
  peek behavior with 4-member cohorts.
- Known limit stands: the sim can't reach epoch 2 organically in-budget; keep the
  measured-tier-1 + projection approach, plus a dev-jump harness case that starts a
  run AT epoch 2 with representative cash to sanity-check arrival feel numbers.

---

## 5. Phasing (each phase headless-verifiable before UI, then shippable)

1. **Phase 1 — Staff ladder rework.** §2 core + save v9 migration + EpochTest
   rewrite + single-state hire button. Ships alone: it fixes the transition
   bug/feel immediately, even before cohorts exist.
2. **Phase 2 — Cohort data + plumbing.** §3: 20 configs (sim-generated numbers),
   roster names, indices-for-tier + cohort bonus loop, First Contact copy tweak.
   **BUILT 2026-07-08 (`feature/epoch-depth-phase2`), headless-verified, NOT
   device-tested. One deviation from §3.5's "re-slotting the 5 existing": the 15
   siblings are APPENDED at property indices 17–31 and the LADDER sorts its rows by
   base cost for display, instead of re-slotting the flagships to new indices — same
   on-screen order, zero save migration (property index is every save's identity:
   per-property rows, retention keys, ladder highs, rosters). Veto if index-grouped
   configs matter more than migration-free saves. First-pass numbers per §3.2
   (cost ×3^k, income ×3^k×(1+0.15k), cycle ×(1−0.05k)) — Phase 3 regenerates them.**
3. **Phase 3 — Pacing retune.** §4: extend the timing study, run candidates, lock
   `economy_scale` step + block step tables + cohort magnitudes; regenerate the
   Phase-2 `.tres` numbers from the winning table.
4. **Phase 4 — Device pass.** Ladder scroll feel at 32 rungs (perf + the §1b
   readability bar), Estate Office retention list at 32 entries (needs scroll?),
   First Contact → minigame framing on device, epoch arrival feel (can I afford the
   flagship too soon?).

Suggested branch: `feature/epoch-depth`, phases as separate commits/PR checkpoints;
docs (GDD §5.5/§6, Spec §3.6/§6) sync at each phase like the epoch-staffing build.

---

## 6. Open questions for Tim (blocking their phase, not the plan)

1. **(Phase 1) Hire-as-level-1 — DECIDED YES (Tim, 2026-07-04).** The staffer hire
   folds into each block's first level: one button, one ladder.
2. **(Phase 1) Block effect shape — DECIDED (Tim, 2026-07-04): big entry step.**
   Level 1 of each block carries the large entry step (the "new staffer = felt jump"
   beat); levels 2–20 are that block's equal smaller steps.
3. **(Phase 1) Retention semantics at v9 — DECIDED (Tim, 2026-07-04, corrected same
   day): retention mirrors the ladder PER INDIVIDUAL LEVEL, not per block.** Tim's
   clarification: "I did not intend retention at the epoch / block level, I intended
   it to be every individual upgrade step." Retention is bought one ladder level at a
   time, in order, capped at the level the living generation holds ("you can only
   will what you have"), and **each additional retained level costs more Legacy**
   (first-pass: 1 Legacy × 1.12^level, geometric — TBD-SIM alongside the Phase 3
   retune). The heir starts the property at `staff_level = retained_levels`.
   Pre-redesign retained TIERS migrate as one full block of levels each. UX note:
   deep retention means many taps — a hold-to-repeat or "retain to current" bulk
   affordance may be wanted after device feel (flagged, not built).
4. **(Phase 2) Cohort size four** (vs 3 or 5) and the first-pass names above — veto
   freely, they're placeholders.
5. **(Phase 3) Duration target:** each epoch ≈ same length as the previous (flat), or
   drifting slightly longer (~1.2×)? Recommendation: flat-to-1.2×, decided by feel
   after the study prints both.

---

## 7. Explicitly out of scope

Minigame difficulty tuning (separate owed pass), the meta-currency idea (GDD §
Future Features), portrait generator (M3), rare events (SHELVED), any Earth-curve
retune (playtest verdict: early game is the reference feel — hands off).
