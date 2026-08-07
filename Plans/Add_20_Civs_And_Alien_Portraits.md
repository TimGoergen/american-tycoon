# Add 20 More Civilizations + Alien Staffer Portraits

**Status:** ⚠️ **DELIVERED — AND THIS DOC IS MATERIALLY STALE. Read this box before anything
below it.** (Corrected 2026-08-06.)

**The work is done.** Path B shipped in full: **326 properties across 27 game tiers**, merged
to `main` 2026-08-01 (commit `04a299e`). Alien portraits are complete for **every tier 3–27** —
`StafferFace.gd:475 _draw_alien` dispatches a bespoke `_draw_*` routine per civ
(`_draw_luminari` … `_draw_proprietors`), and the header at `:473` records that the
gray-headshot fallback is now unreachable in normal play.

**Four things below are WRONG. Do not build from them:**

1. **The whole of §6.1–§6.3 describes the REJECTED architecture.** Those sections specify a
   shared ~8-archetype system with an `archetype` string per epoch carried through the
   pipeline. **Decision 2 reversed that** in favour of a bespoke procedural design per civ —
   and bespoke is what shipped. Anyone implementing §6.2 today would build the wrong thing.
2. **§2's portrait claim is obsolete.** *"`StafferFace.draw_face()` returns `false` for any
   `tier != 1`"* was true when written; every alien tier now has its own routine.
3. **Everything framed as "Path A" is dead** (§3's recommendation, §4, §5, §10's phasing).
   Path A was wired first and then **reversed after the Sim** — see decision 1. The doc still
   recommends Path A in §3 and phases against it in §10.
4. **The tier numbers shifted +1.** The Earth split (2026-07-28,
   `Plans/Earth_Split_Epochs.md`) made Earth two epochs, so draft civ tier N is now game tier
   N+1. The 20 civs listed here as tiers 7–26 are **game tiers 8–27**; the "batch 2" cohort
   described as 12–26 is **game tiers 13–27**.

**What is still true and worth keeping:** §1 (the authored draft content and its field list,
including that `staff_income_multiplier` is a flat injected `1.0`, *"a constant to inject, not
content to author"*), §3's Path A/B analysis as the record of *why* B won, §7's UI dependency
list, and the decision log below. The durable build recipe for extending the ladder is **not**
here — it lives in the project memory's civ-content-pipeline entry.

**Still genuinely outstanding** (see `Device_Feel_Test_Checklist.md` §7.3):
- **Batch-2 device validation was never done.** Decision 3 was explicit — *"wire + portrait
  tiers 7–11 first, device-validate, then 12–26."* Batch 1 was validated; batch 2 shipped
  without it, and the checklist had no line for it until 2026-08-06.
- **The planet watermark decision (§9 item 4) is still open** — see §9's corrected status.
- **§6.4 Phase-2 step 3** (extra variation, optional hero overrides for flagship roles) is
  unbuilt; `manager_portrait` remains the authored escape hatch.

---

**Original status line:** APPROVED — decisions made by Tim 2026-07-25 (below); executing. Raised by Tim 2026-07-25.

**Decisions (Tim, 2026-07-25):**
1. ~~Path A now, B later~~ **→ PATH B (reversed after the Sim).** Path A was wired first, but the Sim
   proved the new epochs are *unreachable* with no new income: epoch 7 took 31 days, epoch 10 took
   169 **billion** years, because property count stayed at 52 while the threshold jumps ×16807/epoch.
   Tim chose Path B — each new epoch gets its own property cohort (like epochs 2–6). **DONE for the
   first batch (tiers 7–11):** 64 new properties generated from the draft's computed costs/incomes;
   Sim pacing restored (props 52→116, ~3–4 min/epoch, ~1.2 h total). Batch is fully playable.
2. **Richer per-civ portraits** — each alien civ gets its OWN bespoke design (still procedural /
   code-drawn, no art files) tuned to its identity, rather than a shared ~8-archetype system. §6 is
   revised accordingly: hand-craft a distinct procedural alien per civ, seeded per role for
   individual variation.
3. **First batch, then the rest** — wire + portrait tiers 7–11 first, device-validate, then 12–26.
**Goal:** grow the epoch frontier from **6 tiers (Earth + 5 aliens)** to **26 tiers (Earth + 25 aliens)**,
and extend the procedural staffer-portrait generator so every one of the new civilizations has a
distinct staffer look.
**Related:** `EpochCatalog.gd`, `docs/civilizations_v2_draft.json`, `claude/civ_v2_regen/assemble.py`,
`Plans/Escalating_Ladder.md`, `Plans/Layered_Staffer_Portrait_Generator.md`, GDD §6.2.

---

## 1. The good news — the content already exists

The 20 new civs are **already authored** in `docs/civilizations_v2_draft.json` (tiers 7–26). That file
is a superset of the shipped game: tiers 1–6 are Earth + the 5 live civs (synced from the game), and
tiers 7–26 are 20 brand-new civilizations:

> Vashti Deep-Court · Ssethraki Coil-Banks · Melissar Hive-Court · Norrvane Frostholm · The Resonant
> Octave · Umbrafex Syndicate · Karr'ghan Warhoard · The Politesse Ascendancy · Oneiroi Drift · The
> Glossolalia Lyceum · Ferrovore Guilds · The Vantablack Salon · Fortuna Cartel · Mirror Meridian ·
> Ossuary Compact · Spectacle Prime · Vek-Tor Kollektiv · Atlas Concordat · The Null Ledger · The
> Proprietors Absolute

Each draft civ carries: `civilization`, `home_planet`, `currency`, `economy_scale`, `hail`,
`contact_line`, `accent_color`, and a full `staffer_roster_all_properties`. Every field
`EpochCatalog.gd` needs is present **except** `staff_income_multiplier` (which is a flat `1.0` for
every tier — a constant to inject, not content to author).

So the creative writing is done. What's left is a wiring decision, a mechanical transform, some UI/art
scaling, and the alien portraits.

---

## 2. Current state (what we're extending)

- **6 epochs, 52 property slots.** Earth = 12 properties (tiers... indices 0–11); epochs 2–6 add
  cohorts of 6/7/8/9/10 = 40 alien properties (indices 12–51). All defined as `.tres` files in
  `ConfigLoader.PROPERTY_PATHS`. By epoch 6 every one of the 52 is unlocked.
- **`EpochCatalog.EPOCHS`** holds one dictionary per epoch; its `staffer_names` array re-skins **all
  52 properties** with that civ's flavor (a property staffed in the Luminari epoch shows a Luminari
  title, etc.). Adding a civ = appending one EPOCHS entry.
- **Scaling:** `economy_scale = 16807^(tier−1)`; consuming `earth_target × economy_scale` lifetime
  dollars advances to the next epoch. Tier 26 ≈ 1.6e105 — comfortably inside float64 (ceiling
  ~epoch 70), so no number-overflow work is needed for this range.
- **Portraits:** ~~`StafferFace.draw_face()` returns `false` for any `tier != 1`, so alien staffers
  currently fall back to the gray `headshot.svg`.~~ **NO LONGER TRUE (2026-08-06).** Every tier
  3–27 now has a bespoke routine via `StafferFace.gd:475 _draw_alien`; the gray fallback is
  unreachable in normal play and survives only as a safety net for a future tier 28+.

---

## 3. THE KEY DECISION — what does a new epoch DO? (Tim's call)

The draft is built for a **326-property, 26-epoch** ladder (each epoch introduces its own new property
cohort). The live game is **52 properties / 6 epochs**. Two ways to spend the draft:

### ~~Path A — Flavor + scale (re-skin the existing 52). **Recommended for this pass.**~~ — **REJECTED**

> Wired first, then reversed after the Sim proved the new epochs unreachable without new
> income (epoch 10: 169 billion years). Kept as the record of the argument that lost.
Each new epoch is a **first-contact beat + a re-skin of the 52 staffers + a ×16807 economy climb**. No
new properties, no new `.tres`, no economy re-tuning. Purely a mechanical transform of the draft's
first-52 roster slice into `EpochCatalog` (§4).
- **Pro:** deliverable now; low risk; append-only (old saves safe); gives 20 new civ identities,
  hails, accent colors, and — with §6 — 20 distinct alien staffer looks.
- **Con (be honest):** after epoch 6 all 52 properties are already owned, and staff income is flat, so
  epochs 7–26 add **no new thing to buy** — they're a long earn-toward-the-next-contact stretch with a
  flavor payoff. This matches the GDD's accepted "the frontier is allowed to slowly stagnate," but it
  is thin as *gameplay*. Mitigation lives in a **follow-on** (Path B properties, or the per-epoch
  modifier/upgrade track in Future Features — the real "engagement half").

### Path B — Full new-property epochs (the 326-property ladder). ✅ **CHOSEN AND SHIPPED**
Each new epoch introduces its own cohort (~6–9 new properties, capped ~12–14 rungs/epoch). The draft
already computes the costs/incomes, but this additionally requires **~274 new `.tres` property
resources**, extending every roster to 326, the staff-price-rank re-anchor at scale, and a full sim
re-tune.
- **Pro:** every epoch has genuinely new properties to unlock — real progression to epoch 26.
- **Con:** very large content + tuning effort; a project in its own right, not a "wire up the civs"
  task.

**Recommendation:** ship **Path A now** (20 civs as contact/flavor/scale/portraits), and treat
per-epoch gameplay depth (Path B properties *or* the modifier track) as a **separate, later
decision**. The rest of this plan assumes Path A; §8 notes what Path B would add.

---

## 4. Content transform (Path A) — draft JSON → EpochCatalog

A one-time, scriptable transform (or a careful hand-port) of draft tiers 7–26 into 20 new
`EpochCatalog.EPOCHS` dictionaries:

| EpochCatalog field | Source in draft | Transform |
|---|---|---|
| `tier` | `tier` | copy |
| `civilization` | `civilization` | copy |
| `home_planet` | `home_planet` | copy |
| `currency_flavor` | `currency` | rename |
| `economy_scale` | `economy_scale` | copy (verify == `16807^(tier−1)`) |
| `staff_income_multiplier` | — | inject constant `1.0` |
| `hail` | `hail` | copy |
| `contact_line` | `contact_line` | copy |
| `accent_color` | `accent_color` (bare hex) | `Color("#" + hex)` |
| `staffer_names[52]` | `staffer_roster_all_properties` | take the `staffer` string for the first 52 properties, in ladder order |

Do it as a small generator step (extend `assemble.py`, or a one-off script) that emits the GDScript
dictionaries, so it's reproducible if the draft is re-authored — rather than hand-copying 20 × 52
strings. Validate that each produced roster is exactly 52 long and every economy_scale is monotonic.

---

## 5. Scaling & save safety (Path A)

- **Append-only:** new epochs are tiers 7–26; existing tiers, property indices, and saves are
  untouched. The epoch gate is forward-only (a run already past a gate isn't retro-locked).
- **Float headroom:** fine through tier 26 (§2).
- **Consumption/contact:** `EpochCatalog.consume_threshold` and the first-contact flow are already
  data-driven off `economy_scale` — they extend for free.
- **Sim:** `EpochTest.gd` content-integrity must accept 26 epochs (still 52 properties, rosters length
  52, monotonic scale, non-empty hails/contact lines for tiers ≥2). A full `Sim.gd` dynasty playout
  should be run to confirm it can advance across 26 epochs without stalling (watch the ownership gate
  and run time; may need a longer protocol or a cap).

---

## 6. Face generator — Phase 2: alien staffer portraits (the heart of Tim's ask)

Goal: a **distinct, recognizable staffer look for each of the 25 alien civs**, procedurally (no
hand-authoring 25 × N portraits), building on the proven `StafferFace` pipeline.

> ⚠️ **§6.1, §6.2 and §6.3 below describe the REJECTED architecture — the shared ~8-archetype
> system. Decision 2 reversed it in favour of a bespoke procedural design per civ, and bespoke
> is what shipped.** There is no `archetype` tag in `EpochCatalog`, none in the draft JSON, and
> no archetype draw routines. The live implementation is a `match tier` dispatch in
> `StafferFace.gd:475 _draw_alien` to one hand-tuned routine per civilization.
>
> **Do not implement §6.2.** These sections are kept for the reasoning — the per-civ
> `accent_color` palette and the `(property_index, tier, generation)` seed for
> within-civ variation both carried forward into the bespoke routines, which is the part that
> survived. Only the shared-silhouette-family idea died.

### ~~6.1 Approach — abstract emblem, keyed to civ + role~~ *(superseded — see box above)*
For `tier >= 2`, `draw_face` dispatches to an **alien portrait** routine instead of returning false.
Each alien staffer is an abstract, flat-cartoon "being/emblem" composed from:
1. **The civ's `accent_color`** (from `EpochCatalog.accent_color`) → a per-civ palette (base + a
   lighter/darker shade), so every civilization reads as its own color world (Luminari amber vs.
   Vashti deep-teal, etc.). This alone differentiates 25 civs at a glance.
2. **An `archetype`** — a small set (~8) of abstract silhouette families, each its own draw routine:
   e.g. `orb/light`, `machine/visor`, `fungal/cap`, `crystal/cluster`, `chrono/hourglass`,
   `gas/cloud`, `deep/tentacled`, `void/mask`. The archetype sets the head silhouette + feature style
   (eye count, surface pattern); the accent color paints it.
3. **A per-role seed** `(property_index, tier, generation)` — the same determinism the human faces
   use — varying the individual details (eye arrangement, pattern, small features) so staffers within
   one civ still differ, and a role stays stable within a run.

25 civs across ~8 archetypes = ~3 civs per archetype, each in a different accent color and with
seeded variation — distinct enough without a bespoke design per civ. (If any flagship civ deserves a
one-off look later, the authored-`manager_portrait` override already exists.)

### ~~6.2 Data: add an `archetype` tag per alien epoch~~ *(NEVER BUILT — do not implement)*
`EpochCatalog` gains an `archetype` string per alien epoch (Earth stays human). The 20 draft civs are
freshly authored (not from the 10-category `alien_civilizations.md` taxonomy), so each needs an
archetype assigned — a small authoring step driven by name/currency/lore (e.g. Vashti Deep-Court
"Lures/anglerlight" → `deep/tentacled`; Vek-Tor Kollektiv → `machine`; Ossuary Compact → `void/mask`).
Store it in the draft too so the pipeline carries it.

### 6.3 Build & integration
- Extend `StafferFace.draw_face(property_index, tier, ...)`: `tier == 1` → human (done); `tier >= 2`
  → `_draw_alien(archetype, accent, seed, ...)`. It needs the civ's accent + archetype; simplest is to
  look them up from `EpochCatalog` by tier inside `StafferFace` (or pass them through `set_state` like
  the role is today).
- Build the ~8 archetype draw routines as flat vector shapes (same primitive style as the human
  faces), each: a head silhouette, 1–3 eyes, a surface treatment (facets / circuitry / spores / glow),
  in the civ palette. Reuse `ManagerCircle`'s disc + ring + level pill unchanged.
- **Iterate visually** — like the human faces, expect several rounds (windowed render → review). Build
  one archetype end-to-end first (prove the pipeline), then the rest.

### 6.4 Phasing within Phase 2
1. Alien dispatch + one archetype (e.g. `crystal`) wired for its civs; confirm on device.
2. The remaining archetypes, one at a time.
3. Polish: extra variation, optional hero overrides for flagship roles.

---

## 7. UI / art dependencies (surfaced by 26 epochs)

- **Epoch pager dots (`EpochPagerDots`).** A 26-dot strip won't fit. Replace with a compact indicator
  for large tab counts — e.g. an "Epoch 7 / 26" readout, or a windowed dot row (show a few around the
  current). UI task; honor the no-moving-UI and readability rules.
- **Planet watermark (`HeroStat.PLANET_IMAGE_PATHS`).** Currently 6 authored world SVGs (Earth →
  Chronophage), indexed by tier. Tiers 7–26 have no art → add a **bounds guard + fallback** (a generic
  "frontier world," or a procedural planet tinted by the civ accent color) so it never indexes out of
  range. Per-civ world art can come later as an art-pass item.
- **Pager label / contact screen.** Already data-driven off `EpochCatalog` (civilization name, hail,
  accent) — extends for free.

---

## 8. What Path B would add later (not this pass)

If/when new-property epochs are wanted: author ~274 `.tres` from the draft's computed
costs/incomes, extend every roster to 326, apply the staff-price-rank re-anchor
(`Plans/Escalating_Ladder.md` §"Staff-cost re-anchor") at scale, cap cohorts ~12–14 rungs, and re-run
the full pacing sim. The draft + `assemble.py` already produce the numbers; the game-side resources
and roster-length expansion are the work. Alternatively, deliver per-epoch engagement via the
**per-epoch modifier/upgrade track** (Future Features) instead of new properties.

---

## 9. Open decisions for Tim

**Status of these four, corrected 2026-08-06 — three are decided, one is still open.**

1. ~~**Path A vs Path B**~~ — **DECIDED: PATH B**, reversing this doc's own recommendation.
   The Sim was decisive: with property count stuck at 52, epoch 7 took 31 days and epoch 10
   took **169 billion years**. Shipped.
2. ~~**Alien portrait style**~~ — **DECIDED: bespoke per-civ**, rejecting the recommended
   abstract archetype system. Shipped for every tier 3–27.
3. ~~**How many to enable first**~~ — **DECIDED: first batch tiers 7–11, then the rest.**
   Both batches shipped. ⚠️ **The device-validation half of this decision was only honoured
   for batch 1** — see the status box at the top.
4. **Planet watermark — STILL OPEN.** `HeroStat.PLANET_IMAGE_PATHS` holds 6 authored world
   SVGs (Earth → Chronophage); tiers 7–27 have no art and rely on a bounds guard. The choice
   — generic/procedural planet tinted by the civ accent colour vs. commissioning ~20 world
   images — has never been made. Deferred as an art-pass item; tracked in
   `Device_Feel_Test_Checklist.md` §7.3.

---

## ~~10. Suggested phasing (assuming Path A)~~ — DEAD, Path A was reversed

> Kept only as a record of the plan that was abandoned. Path B shipped instead: cohort
> generation per epoch, bespoke portraits per civ, no `archetype` tags. The durable recipe
> for reproducing a ladder extension lives in the project memory's civ-content-pipeline
> entry, not here.

*Original phasing follows.*

- **P0 — decisions** (§9).
- **P1 — wire the civs:** transform draft → 20 `EpochCatalog` entries; extend `EpochTest` + run
  `Sim.gd`; fix the pager dots + planet-watermark fallback; boot + device pass. *(20 civs playable as
  contact/flavor/scale, staffers on the headshot fallback.)*
- **P2 — alien portraits:** add `archetype` tags; build `StafferFace` alien dispatch + archetypes;
  iterate on device. *(The face generator now supports all 26 tiers.)*
- **P3 — (optional, separate) per-epoch depth:** Path B properties or the modifier track.
