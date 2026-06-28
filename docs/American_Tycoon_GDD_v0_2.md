# American Tycoon — Game Design Document

**Version:** Draft v0.2
**Date:** June 12, 2026
**Status:** Design phase complete end-to-end (title screen → final dollar). Next: M1 build.
**Designer:** Tim
**Supersedes:** v0.1

---

## 0. Guiding Principles (binding, added v0.2)

1. **Built for an audience of one.** This game exists so the designer can play it on his phone. External validation, retention metrics, and genre expectations are irrelevant. Every "would players tolerate this?" question resolves to "do I enjoy this?"
2. **Dopamine is the prime directive.** When fun and theme conflict, fun wins. The satire is seasoning, not the meal.
3. **No monetization pressure may ever shape a mechanic.** There is no current intent to monetize or sell. If the game is ever sold, it will be for a one-time fee, and that decision will not alter any design.
4. **Playable-on-phone-and-fun is the first milestone, not the last.** The 2022 project died in technical details before reaching the dopamine. The revival sequences development to reach a fun core loop on real hardware as fast as possible; systems layer on after the loop already feels good in the hand.
5. **The game is composed, never needy.** It never pings, begs, or guilt-trips. It waits. (See §13: notifications are banned entirely.)

### 0.1 The Anti-Pillar: Stagnation Is the Only Fail State

The designer's cardinal sin in idle games: **too long between meaningful upgrades.** The moment a check-in offers nothing meaningful to do, the game has failed its only audience. Three structural defenses:

- **Prestige is the graceful exit from stagnation.** Tuned so the optimal moment to prestige arrives just as a generation's upgrade cadence flags — the player surfs from acceleration to acceleration and never inhabits a wall. When upgrade rate decays, the estate planner appears: *"Sir has accomplished so much. Perhaps it's time to think of the children."* Stagnation becomes the prompt for the game's biggest dopamine event.
- **Overlapping progression tracks with staggered cadences.** Property purchases, count milestones, staff hires, offline-cap extensions, loophole purchases, loan offers, generation turnover, and the Earth-target percentage — tuned so their quiet periods never align. No session depends on a single track having something ready.
- **Testable spec, enforced by simulation.** Hard requirement: every rhythmic check-in (~3-hour gap) affords at least one meaningful action; no active 10-minute stretch passes without a progression beat. Build a **headless balance simulator** early (script plays the full week at superhuman speed; graphs time-between-upgrades across all generations). Stagnation is caught in a graph before it reaches the phone.

---

## 1. High Concept

An idle/incremental game about the American Dream of making money. The player purchases income-generating "properties" to buy more income-generating properties, across generations of a wealthy dynasty, until the family has captured **every dollar in circulation on Earth** — at which point the game reveals that Earth was merely the first economy, and **first contact** with an alien civilization opens a market orders of magnitude larger (§6.2).

### 1.1 Thesis

The satire lives in the mechanics, not the writing. In America, success is defined by the progressive **decoupling of reward from effort**. The player begins by clicking for a wage — literal time for literal money — and ends as a dynast whose participation is optional. The game never moralizes; it demonstrates. Prestige is inheritance. Offline earnings are money for nothing. Credit access scales with wealth. The game cheerfully says "hard work pays off" while the math proves the work was never the point.

### 1.2 Tone Rules (binding)

- **The narrator is a true believer.** Hustle-culture sincerity, never a wink. Its sincerity *is* the comedy.
- **Deadpan accuracy over jokes.** Real mechanisms, real names, described the way an estate attorney or a 1950s ad would. The tax code is the joke.
- **Understated wit, never parody.**
- **The game never acknowledges its own satire.** No *words* ever break sincerity; only the math is allowed editorial teeth. The player's slightly queasy delight is the punchline.

---

## 2. Platform & Tech

| Decision | Value | Rationale |
|---|---|---|
| Platform | **Mobile-first**, portrait | Tap verbs native to thumb-on-glass; vertical ladder scrolled upward as you ascend |
| Engine | **Godot** (fresh build) | Existing toolchain, CLAUDE.md conventions, Claude Code workflow, mobile export pipeline from Critter Quitters |
| Original codebase | Unity/C#, barely functioning | **Mined for design intent only; not salvaged** |
| Numbers | **Big-number support from day one** | Planets exceed 64-bit floats eventually. Displayed figures stay readable, real-dollar style — deadpan prefers "$14.3 trillion" over "4.2 quadragintillion" |
| Content architecture | **Data-driven** (config files) | Earth is handcrafted; planets are data files. The galaxy is a pipeline |
| Push notifications | **None. Ever.** | Principle 5. Also zero infrastructure. Old money doesn't chase you; a full offline cap is something you discover, like interest |
| Balance tooling | **Headless balance simulator** (early build priority) | §0.1. The original spreadsheets were this instinct in embryo |

---

## 3. Core Loop Architecture — Three Nested Loops

1. **The Run (a lifetime).** Buy the ladder, ATM → Executive Assets. Ends in death/retirement — or bankruptcy.
2. **The Dynasty (prestige).** Estate passes to an heir, minus creditors and estate tax. Post-tax remainder converts to permanent dynastic advantage. Loopholes purchased via political assets erode the tax across generations.
3. **The Epoch (alien contact).** A generation captures the entire current economy (Earth's whole value, ~$103.6T). The game does not end — instead Earth makes **first contact** with an alien civilization, which opens a market orders of magnitude larger and a new alien-tech staffer tier for every property (§6.2). A game about wanting all the money cannot, by definition, end; it just keeps finding bigger economies to consume.

**Contact is the scale engine, not sci-fi spectacle.** The aliens are flavor and magnitude bands on a single dollar economy — capitalism ran out of Earth, so it opened the galaxy as a market. *(This replaces the earlier "relocate to a distinct new market" idea — see Future Features.)*

### 3.1 The Session Loop (the emotional heart — added v0.2)

The designer's peak dopamine moment is the **return spike**: spending offline-banked resources and seeing an immediate, material income increase. The check-in loop — away → pile accumulates → return → convert pile into a visibly higher income rate → leave knowing the next pile builds faster — is therefore the heart of the game, not the long-session grind. Requirements:

- **Offline accrual tuned to purchase thresholds, not just time:** a typical away-period banks roughly enough to cross at least one threshold (tier, hire, or count milestone).
- **Offline earnings unlock in the first session** — the peak moment cannot be gated late.
- **Bulk-buy UI is mandatory:** ×10, ×25, and "×to-next-milestone" buttons, so the pile converts to a spike in one or two taps.
- **Income/sec is the hero stat:** big, top-of-screen; every purchase animates the jump with a flashed delta ("**+38%**"), weight, sound, haptic.
- **Welcome-back is a two-beat ritual:** (1) the cheerful pile — *Hours worked: 0* — then (2) hand-off directly into the spending spree, not a menu.

### 3.2 Tempo (tuning anchors — added v0.2)

- Check-in rhythm: **4–6 sessions/day** (breaks, downtime), typical gap 2–4h, one overnight gap.
- **3-hour absence ≈ one threshold purchase.** Overnight pile funds the day's biggest spike; morning session is the daily highlight.
- Base offline cap **~4 hours**; cap-extension upgrades exist to cover the overnight gap (genuinely desirable, and thematically "your money learns to work longer shifts").
- Week shape: ~35 sessions to capture Earth; 12–20 generations → a death/inheritance every 2nd–3rd check-in, a return spike every check-in, a rare event every generation or two. **Every session contains ≥1 guaranteed dopamine beat; no two consecutive sessions have the same shape.**

---

## 4. The Property Ladder (Earth)

From the original `AmericanTycoon_PropertyTypeConfig.xlsx`, Sheet2. **Not one rung of honest work on it** — gag → grift → crime → respectable-grift → purchasing the United States government. The endgame tiers being deadpan accounting terms for owning politicians is the punchline and is protected.

| # | Property Type | Cost | Income/sec | Cycle (sec) | Income/Cycle |
|---|---|---|---|---|---|
| 1 | ATM | $50 | $12.50 | 0.4 | $5 |
| 2 | Money Tree | $550 | $25 | 2 | $50 |
| 3 | NFTs | $6,050 | $50 | 4 | $200 |
| 4 | Tax Increment Financing | $66,550 | $100 | 8 | $800 |
| 5 | Cross Border Distribution | $732,050 | $200 | 16 | $3,200 |
| 6 | Money Laundering | $8,052,550 | $400 | 32 | $12,800 |
| 7 | Day Trading | $88,578,050 | $800 | 64 | $51,200 |
| 8 | Flipping Houses | $974,358,550 | $1,600 | 128 | $204,800 |
| 9 | Multi Level Marketing | $10.72B | $3,200 | 256 | $819,200 |
| 10 | Hedge Fund | $117.9B | $6,400 | 512 | $3.28M |
| 11 | Legislative Assets | $1.30T | $12,800 | 1,024 | $13.1M |
| 12 | Executive Assets | $14.27T | $25,600 | 2,048 | $52.4M |

> **Cycle-time rework — IMPLEMENTED 2026-06-22 (moderate stretch, back half only).** The
> table's cycle column above is the *original intent* (doubling 0.4s → 2048s) and never shipped;
> the live build had flattened to a ~81s top with a badly tapering back half (top tiers only
> ~1.2× longer than the one below). Playing on vacation, Tim wanted the back-tier "leave it,
> come back to a fat pile" payoff back. **Shipped:** tiers **1–6 unchanged** (the tuned early
> game), tiers **7–12 stretched** to a clean ~1.6×/tier curve topping out at **272s (~4.5 min)**:
> Day Trading 26s · Flipping 41s · MLM 66s · Hedge Fund 106s · Legislative 170s · Executive
> 272s. (**Second stretch, 2026-06-25:** Tim wanted the top pushed further into the roadmap's
> stated 3–5 min ceiling, so the back-half ratio went from ~1.5× to ~1.6×/tier — tier 7 barely
> moved (24→26), the change concentrates at the top (180→272s), for a fatter leave-it-and-return
> payoff. Was 24/36/54/81/121/180s.) **Income-neutral:** each stretched tier's `base_income_per_unit` was scaled up by the
> same factor as its cycle, so base income/sec is unchanged — only the *rhythm* changes (longer
> waits → bigger lump-sum payouts, and more visible speed-up beats as the longer cycle halves
> more times before the 1s floor). Milestones + staffing compress it the way AdCap's long top
> business collapses once maxed. (`.tres` values updated; this table's cycle column is now
> historical — see the configs for live values.)
>
> **Milestone cadence — switched to AdCap 25/50/100/200/300/400 (Tim, 2026-06-22).** Replaces
> the old `20 × 2^k` (unbounded) with AdVenture Capitalist's six fixed milestones, after which a
> property is maxed (no further beat). `CostCurve.MILESTONE_THRESHOLDS`. **Known tradeoff (sim-
> measured):** this is *less* generous early than `20×2^k` (e.g. at 80 units: old gave 3
> doublings, AdCap gives 2), so the economy came out **~38% slower** (sim top income/sec
> $88.8M/s → $55M/s; 6-gen Legacy 51 → 42; dynasty still "speeds up every time", no band-wall).
> **Re-tune (2026-06-22):** `band_step` 1.15 → 1.10 recovered most of it — gen-1 peak back to
> $11.1M (~8% under baseline), income/sec ~$68M/s, Legacy 46. A residual 6-gen trajectory gap
> remains (the cadence's lost generosity compounds); accepted for now. See Mechanics Spec §15 #8.

**Structural notes:**
- Costs ×11/tier; income ×2; cycle times stretch tier-over-tier per the moderate-stretch
  rework above (`TBD-SIM`, was "double 0.4s → 34min"). Per-property **leveling with income
  multipliers** required (Sheet1's curves).
- Collect-cycle model — the substrate for tap-to-rush (§5) and count-milestone speed-ups (§5.1).
- Sheet1's **accelerating cost curves** (per-level multiplier +0.02–0.03/level) create soft per-property ceilings — retroactively justified by §11 decision cadence: real allocation choices (deepen this tier vs. save for the next) recur constantly, where fixed multipliers collapse into "buy whatever's affordable."
- NFTs timestamps the design to 2021–22; anachronism partially protected by art direction. *Open: refresh individual rungs?*
- Executive Assets ($14.3T) sits just below the Earth target — the ladder nearly reaches the win condition.

---

## 5. Active Play — The Three-Layer Click Hybrid

Clicking is always the best per-second action — but *what clicking is* evolves from labor to leverage. The evolution is the thesis in mechanical form.

- **Layer 1 — The Job (wage labor).** Tap for a flat wage; the only honest money in the game. Linear job-title ladder; dominant for minutes, then obliterated by the first ATM. **Never removed from the UI** — a monument, paying its honest little number beside billions/sec. Achievement: clock a shift as a trillionaire.
- **Layer 2 — The Hustle (cycle rushing).** Tapping a property advances its cycle. Auto-scales: rushing a Hedge Fund is worth millions more than rushing an ATM — same effort, leveraged by capital. Every tap makes the argument. **Strictly additive on top of automation** (§6) — an automated empire rewards an active thumb but never demands one.
- **Layer 3 — The Grindset (frenzy meter).** Sustained active play fills a meter → temporary global multiplier. Active sessions meaningfully outperform idling. Rise-and-grind flavor; the game cheerfully validating the lie.

### 5.1 Acceleration Feel — "It Speeds Up Every Time" (added v0.2)

The early game must *feel* faster on every timescale:

- **Within a run — punctuated, visible acceleration.** Ownership-count milestones: own 10 of a property → cycle time halves; 25 → halves again; etc. Properties visibly spin from labored crawl to blur — speed as *displayed motion*, not just bigger numbers. Early cost/income curves tuned so purchase cadence quickens in the opening minutes. Step-function acceleration feels like speeding up; smooth exponential growth paradoxically feels static.
- **Across generations — front-loaded Legacy, reaching deeper epochs.** Prestige bonuses disproportionately multiply the *early ladder*. Each heir tears through tiers the grandfather crawled across; run 1's first hour is run 5's first ninety seconds. Legacy is also **how the dynasty punches further into the epoch ladder** (§6.2): a juiced-up heir consumes Earth's economy fast enough to reach civilizations the founder never contacted, and per-staffer retention (§6.3) lets the heir start with alien staff already in place. Compounding advantage rendered as game-feel — the player experiences the unfairness from the privileged side. Garnish: each generation auto-skips ceremonies it has outgrown (the family office handles paperwork now).
- **Per property — the arc completes in automation.** Crawl → spin → blur → *someone else's problem* (§6).

### 5.5 Minigames (added 2026-06-21; reframed as a FRAMEWORK 2026-06-22)

Playing the game on vacation, Tim wanted **more energy at transitions** — the seams between
screens shouldn't be dead air. This grew (Tim, 2026-06-22) into a **minigame framework**:

- **A library of 3–5 distinct minigame TYPES** (match-3 is the first; others TBD — e.g. a
  timing/precision bar, catch-the-falling-money, a memory/sequence game, physics/balance).
- **Random selection at every site:** each time a minigame fires, the type is chosen **at
  random**, so the player doesn't know which they'll get — variety and surprise.
- **One universal outcome spectrum for ALL minigames:** performance maps to roughly
  **0.5× → 1.25×** of what's possible — the keep-floor → full → extra-high-bonus model the
  prestige game already uses. Worst/skip ≈ 0.5×; a "full" result = 1.0×; a great result
  reaches the bonus cap (0.25 base, raised by the **Family Reputation** upgrade). Each
  minigame type produces a normalized performance in [0,1]; the framework maps that to the
  multiplier, so all types share one reward curve.

**Usage sites (each rolls a random minigame type):**
1. **Prestige / succession — multiplier on Legacy (BUILT).** See the match-3 below.
2. **Epoch change / First Contact — reward = a NEW PROPERTY TYPE (design pending, Tim
   2026-06-24).** Theme: *negotiating the alien trade deal*. Tim chose this over the earlier
   TBD options (entry income boost / starting cash / first-staffer discount): winning the
   negotiation should open a genuinely new *kind* of business in the bigger market, not just
   hand out cash. **This breaks the universal 0.5×→1.25× multiplier model** (a property is
   unlocked or not — performance has to scale something else, e.g. the new property's starting
   units / a head-start discount on it), and the property ladder is currently 12 fixed Earth
   configs, so epoch-gated alien property *types* are a content + systems feature, not "wiring."
   **NOT built; needs its own design pass.** The First Contact minigame hook is therefore left
   unwired for now (firing a minigame that grants nothing would be worse than none).
3. **Welcome-back / offline return — multiplier on the offline pile (BUILT 2026-06-24).** A
   round scales the overnight pile: the base pile is banked on resume, the minigame credits the
   +/- delta (earned income), then the welcome screen shows the final haul. *(Watch: welcome-back
   is the most FREQUENT transition and the genre intends a frictionless return — a mandatory
   minigame each open, with a 0.5× downside, may feel punishing. Tune cadence / lean on the
   opt-out; flagged for feel-testing.)*

**Player setting:** a persisted toggle (`GameState.ui_minigame_enabled`). **Default:
mandatory.** **Opting out — or tapping Skip — banks the keep floor** (the worst result, not a
safe 100%), so skipping has a real cost. A per-round Skip is always available.

**Built 2026-06-22 — match-3 type (the first of the library):** drag a gem to swap; matches
flash with a size badge, clear, and survivors + new gems fall in; a live spectrum bar shows
the kept fraction (red→gold→green→teal) with the Legacy amount + bonus. Currently wired only
to the prestige site; the framework refactor (random type selection + the other two sites)
is the next build.

**Build phasing:** (1) **framework** — a host that picks a random minigame type and maps its
[0,1] performance to the universal multiplier; refactor match-3 into the first type; route
prestige through it (no behavior change). (2) **add 2–4 more types** so the random draw has
variety. (3) **wire the First Contact and Welcome-back sites** with their rewards —
**welcome-back DONE 2026-06-24** (host generalized to be reward-agnostic; pile multiplier
wired); **First Contact deferred** pending the "new property type" design (site 2 above).

---

## 6. Staffing & Automation (rewritten v0.3 — epoch-keyed staffing)

Staffing is the moment **labor itself becomes something you purchase** — and in this game that purchase is no longer a one-time on/off switch. It is a **tiered upgrade track keyed to alien epochs** (see §6.2). Each property's staffer can be hired, then *upgraded* tier by tier as Earth makes contact with successive alien civilizations, with each tier a large income multiplier justified in-fiction by that civilization's technology ("the Luminari run your ATMs on coherent light now").

This is the diegetic engine behind the game's absurd scale: capitalism ran out of Earth, so it opened the galaxy as a market.

### 6.1 Per-property staff tiers

- **Hire, then upgrade.** Tier 0 = unstaffed (you collect by hand). Tier 1 = an Earth staffer: cycles now run and collect automatically, forever — automation behaves exactly as the old one-time hire did. Tiers 2+ replace that staffer with an alien-tech version that multiplies *that property's* income.
- **You can only reach a tier whose epoch you've reached this run** (§6.2). The next-tier upgrade is gated by contact, not just by cash.
- **The multiplier is honest.** A staffer's tier multiplier is applied at the point of payment alongside frenzy and Legacy, so it shows up in the on-screen income/sec — no hidden math.
- **Hire/upgrade cost climbs with tier** (alien talent costs more): the entry-hire cost is anchored to the target epoch's whole economy (§6.2). Retuned 2026-06-27 so the cheapest staffer is ~1% of the epoch economy (was ~0.1% — too cheap to feel at contact) and the full alien roster costs more than one epoch's earnings, making staffing a prioritized spend rather than a one-tap sweep.
- **Then keep leveling that staffer — the per-epoch upgrade track (added 2026-06-27).** After hiring an epoch's staffer, you LEVEL it up repeatedly *within* the epoch; each level compounds that property's income by a fixed step (`staff_level_step`), with the cost climbing geometrically (no hard cap — the cost is the only brake). This is the continuous "there's always a next upgrade to chase" sink (criterion #3) that fills an epoch, so an epoch is a steady income *ramp* rather than one hire then a wait. Levels **reset to 0 when you advance to the next epoch's staffer** (a fresh hire — the big tier jump is the payoff for crossing), and they are **per property**, keeping the cross-property allocation decision alive (§11). Design note: `Plans/Per_Epoch_Upgrade_Track.md`.
- **Tapping remains strictly additive** (§5, Layer 2) — an automated, alien-staffed empire rewards an active thumb but never demands one.
- **Named staffers in 50s-ad style, re-skinned per epoch.** Earth: the gleaming *ATM Technician*, the *NFT Community Manager*, up to the **Lobbyist** (Legislative Assets) and **Chief of Staff** (Executive Assets) — at that altitude even owning the government is delegated. Each later epoch renames the whole roster in its own flavor (the ATM Technician becomes the Luminari *Photon Teller*, then the Geth *Autonomous Teller Unit*, then the Mycelium *Spore-Cash Node*).

### 6.2 Epochs & First Contact

Earth runs on **one currency — the dollar.** Alien civilizations are *flavor, magnitude bands, and a staff-tier gate*, never a second money type.

- **Epochs are reached within a run by consuming the entire current economy.** Each epoch has a total economic value; Earth's is the existing Earth target (~$103.6T — "buy the Earth", §10). Once a generation has *earned* that whole value, contact with the next civilization fires and the next, orders-of-magnitude-larger epoch opens. The threshold ladder *is* the scale justification: "you ran out of Earth to buy, so the galaxy opens."
- **First Contact is a beat,** not just a number crossing: it names the civilization, its home world and tech, and declares new markets open. Each contact also unlocks the next staffer tier for every property.
- **v1 epoch ladder** (Earth + 5 alien epochs shipped; more can be added as data rows):

  | Tier | Civilization | Economy vs. Earth | Staffer income ×| Flavor |
  |---|---|---|---|---|
  | 1 | **Earth** | 1× (~$103.6T) | 1× | The honest starting grind; tier 1 just turns on automation. |
  | 2 | **Luminari Collective** (Solaria Prime, *Photons*) | 30× | 40× | Energy/light beings — money now moves at light speed. |
  | 3 | **Geth-Sentinel Grid** (Rannoch-01, *Logic Nodes*) | 900× | 1,600× | Cybernetic collective — finance run entirely by machines. |
  | 4 | **Mycelium Unity** (Spore-Deep, *Spores*) | 27,000× | 64,000× | Fungal hive-mind — money that literally spreads and self-replicates. |
  | 5 | **Quartzite Conglomerate** (Geode-7, *Prisms*) | 810,000× | 2,560,000× | Crystalloid — wealth crystallized, harder than diamond and just as cold. |
  | 6 | **Chronophage Enclave** (Tempus, *Seconds*) | 24,300,000× | 102,400,000× | Time-eaters — they sell you time itself, by the second, at a ruinous markup. |

  Arc: energy → automation → proliferation → crystallization → time, each a different flavor of "the aliens make your money machine inhuman." More civilizations can be added as data rows — `docs/alien_civilizations.md` holds 100.

  **Epoch pacing — the law (reworked 2026-06-27).** Time to clear an epoch ≈ (dollars to earn) ÷ (income/sec), so the **per-epoch duration ratio = economy_step ÷ staff_step**. The original v1 numbers (economy ×1,000/epoch, staff ×~17/epoch) made each epoch ~60× *longer* than the last — epoch 2 stalled into hours of nothing-new, epoch 6 into millennia. The ladder is now **matched geometric, staff stepping slightly faster than the economy**: `economy_scale = 30^(tier−1)`, `staff_income_multiplier = 40^(tier−1)`. Because 40 > 30, each epoch arrives ~0.75× the time of the last — the §5.1 "it speeds up every time" feel, not a wall. The trade-off: top-epoch economy is now ~24M× Earth (still vast, ~7 orders of magnitude over the run) rather than 10¹⁵×. *Values are first-pass in `EpochCatalog.gd`; the epoch-timing study in `sim/Sim.gd` (`_run_epoch_timing_study`) measures the live ladder and verifies the duration ratio on every run, and the dynasty sim confirms "speeds up every time" still holds.* **Note — what the ladder does NOT govern:** alien-staff *affordability* is always 0.1% of the epoch economy (`earth_target × economy_scale × staff_cost_fraction`), independent of these steps; "staff too cheap at contact" is a separate `staff_cost_fraction` knob (open tuning item). And the ladder fixes *pacing only* — it does not by itself give the player something to **do** during an epoch (the per-epoch upgrade-track / modifier-choice idea in Future Features remains the engagement half).

### 6.3 Dynasty interaction — staff retention

- **Staff reset on prestige by default.** A new founder starts unstaffed, at the beginning of Earth (§8). Prestige is *how a juiced-up heir punches deeper into the epoch ladder than the last life did* (§5.1).
- **Every staffer is individually retainable via a Legacy upgrade.** Spend Legacy to keep a specific property's staffer at its tier across the reset, so the heir's empire starts pre-staffed exactly where you chose to invest. Buying retention again raises the retained tier. Inherited staff are dynastic infrastructure, front-loading each heir's acceleration. *(This is distinct from the existing "Loyal Staff" Legacy upgrade, which only discounts hire cost.)*

### 6.4 Deferred satire — "the quiet ratio"

A future staffer-card stat: one-time hire cost beside lifetime revenue generated — two numbers drifting apart by ten orders of magnitude, no commentary. The labor-vs-capital argument as a stat line. No longer the centerpiece now that staffing is a tiered track; tracked as a polish-phase addition.

---

## 7. Offline Earnings — A Purchased Class Privilege

- **Not free.** A new player earns $0 while the app is closed — being broke means income stops when effort stops.
- An early **first-session** unlockable (Property Manager → eventually Family Office) grants offline accrual: the genre's default mechanic becomes a visible threshold — the moment your money starts working without you.
- Cap ladder per §3.2 (base ~4h, extensions cover overnight). Flavor: "your money now works three shifts."
- Reduced efficiency vs. live play (keeps Layers 2–3 meaningful; things run looser when the boss is away).
- **Welcome-back plays it completely straight:** big cheerful number, one deadpan stat — *Hours you worked: 0* — then directly into the spending spree (§3.1).

---

## 8. Origins, Death, Inheritance, Debt

> **SHELVED → post-prestige (Tim, 2026-06-15).** The whole **credit/class system**
> — origins (§8.1), debt & bankruptcy (§8.5), and the offers system (§8.6) — is
> shelved for now. Reason: handing the founder *any* early cash (even the $1,000
> bootstrap, and especially the $200k/$500k loans) flattens the opening grind, which
> is the most dopamine-rich part of generation one. The **founder now starts at $0**
> and earns the first dollar by hand. The mechanic is expected to **return as a
> post-prestige feature**: an heir — already accelerated by Legacy — could be offered
> origins/credit as *extra options* (more ways to play a run), where an early influx
> adds choice instead of removing the climb. Death/inheritance/estate-tax (§8.2–8.4)
> are **NOT** shelved — they shipped in M2. Implementation is fully built and parked
> on the `shelved/credit-and-class` branch for resurrection; the sections below are
> the design of record for that future work.

### 8.1 The Opening (preserved from original flowchart)

First question: **"Do you have rich parents?"** Class origin as character creation.

| Path | Response | Start |
|---|---|---|
| **No** | Game shames the player, then begrudgingly grants a $1,000 tax rebate with a sneer about government handouts | $1,000 |
| **Yes** → token gift | "Your parents really want you to *earn your way through life*" | $50,000 gift |
| **Yes** → interest-free loan | — | $200,000 (debt) |
| **Yes** → high-interest loan | — | $500,000 (debt) |

No origin where the first dollar was earned — even bootstraps start with a government check. The player is always an heir, including generation one. Mechanically a difficulty selector disguised as a birth lottery. Achievement: **"Bootstrapped"** — capture Earth from $1,000.

### 8.2 Dynasty Identity (added v0.2)

- Each heir receives a **randomly generated inbred-royalty name**: stuffy first names (Bartholomew, Thurston, Wadsworth, Constance, Bitsy) + optional prep-school nickname ("Trip," "Chip," "Bunny," "Skipper") + hyphenated old-money surname (Ashworth-Vanderlyn, Pemberton-Howell). Surname persists per planet (the family brand); first names randomize.
- **The Roman numeral suffix is the prestige counter.** By mid-week you're Wellington Pemberton IX.
- No portraits in v1 — the names are the characters.
- **The Family Ledger:** one screen; each ancestor's name, fortune at death, and a deadpan cause of generation-end ("Retired to Palm Beach" / "Creditors").

### 8.3 Death & The Estate — The Obituary Screen (expanded v0.2)

A **short ritual: one screen, two beats, ~30 seconds.**

1. **The Obituary:** name, years, a deadpan life summary assembled from the generation's actual stats — *"Bartholomew 'Chip' Ashworth-Vanderlyn IV, beloved employer of 11, grew the family fortune from $2.1B to $847B. Hours worked: 3."* The headline figure is the generation's **lifetime cash earned** (the never-spent career total that feeds the Legacy conversion — see Future Features "Lifetime cash earned"), not net worth at death.
2. **The Reading of the Will** — the estate math made legible as a document: gross estate → **creditors first** → estate tax line (**each purchased loophole visibly shrinking it, in ink**) → net to heir → Legacy conversion. Loophole purchases pay off on this screen, every generation: strategic feedback delivered as ceremony.

Then the heir's name reveals, numeral incremented, into the faster run. All obituaries re-readable in the Family Ledger.

### 8.4 The Loophole Tree

Legislative & Executive Assets unlock estate-tax erosion: raised exemptions, dynasty trusts, stepped-up basis, the charitable foundation that owns the yacht. **All real mechanisms, real names, estate-attorney register.** Strategic spine of the late run: income for *this* lifetime vs. loopholes that pay off for the *next* generation.

### 8.5 Debt & Bankruptcy

- Debt = obligation paid on one or more occasions. **Milestone-triggered payments** (net-worth/income thresholds), never wall-clock — an idle game must not punish idling. "Your success has been noticed; first payment is now due."
- **Missed payment = forced end of generation.** Creditors strip the estate; almost nothing converts to Legacy. The individual fails; the dynasty persists from a worse position. *The dynasty is too big to fail.* The only clock that runs against the player.

### 8.6 Ongoing Credit — The Offers System

**Credit comes to you.** Periodic take-it-or-leave-it loan offers; fixed principal; fixed milestone schedule; **one active loan at a time.** **Terms improve as you need them less:** payday-lender terms for the bootstrapper → prime rates on enormous sums → late-game *bailouts* ("you're load-bearing now"). Implementation: a data table of offer tiers + §8.5 plumbing.

---

## 9. Rare Events (added v0.2)

> **SHELVED — uncertain (Tim, 2026-06-22).** Tim isn't sure he wants this idea at all, so it
> is parked: not in current scope and not to be proactively recommended. The design below is
> kept for reference if he decides to revisit it. Nothing is built.

**Cadence: roughly once per generation or two** — events function as *dynastic memory* (the Crash of '52 that gutted Bartholomew III's estate). Hard rule: **events hit capital, never the player's verbs.** The tap always works; the purr is preserved; events reprice the world occasionally.

| Event | Effect | The Joke |
|---|---|---|
| **Market Crash** | Capital income halved briefly; wage unaffected | Honest work is crash-proof — and it doesn't matter |
| **The Audit** | Purchased loopholes can be retroactively "examined" — unless you own enough legislators | The loophole tree gets teeth |
| **The Windfall** | A relative you've never heard of dies; unearned money arrives | The narrator congratulates your work ethic |

---

## 10. Win Condition — The Final Dollar (expanded v0.2)

- **Per-epoch win:** capture all money in the current economy. Earth target ≈ global broad money, ~$100T class (*candidate canonical figure: $103.6T* — confirm). The percentage is watchable throughout. **This capture is also the first-contact trigger** (§6.2): consuming Earth's whole economy is what opens the next epoch, so the Final Dollar is a *gateway*, not an ending (§3 loop 3).
- **Pacing: ~1 week of rhythmic daily play** to capture Earth. First death inside the first session (~30–45 min); 12–20 generations total, shortening as Legacy compounds.

### 10.1 The Final Dollar Sequence (four beats)

1. **The Parade.** Counter ticks to 100.000000%; the game's biggest celebration — ticker tape, brass band, sash and trophy in peak 50s-Americana. Narrator at maximum sincere wattage: *"Through grit, gumption, and good old-fashioned elbow grease, you've earned every last dollar on Earth!"* No irony anywhere.
2. **The Commemorative Ledger.** An award-certificate stat screen, presented as a high score: *Dollars in circulation: $103.6T. Yours: $103.6T. Everyone else's: $0.00.* The last line sits in celebratory gold leaf, unremarked. The game thinks it's bragging.
3. **The Engine Stops.** Behind the confetti: **income/sec = $0.** No one is left to pay you. Cycles spin and dispense nothing; the muzak winds down like a record losing power. The game never comments — the math tells the truth while the voice celebrates. Total victory and total stagnation are the same state; the player feels the anti-pillar (§0.1) *as the win condition*. (The one beat with editorial teeth — permitted because no *words* break sincerity.)
4. **First Contact.** Into the silence, a transmission: Earth's saturation has been *noticed*. A cheerful prospectus from the first alien civilization (the Luminari Collective, §6.2) arrives — *"Earth Market Status: SATURATED. Congratulations! An exciting opportunity awaits the discerning dynasty..."* A new, orders-of-magnitude-larger economy opens, every property gains an alien staffer tier, and the loop restarts with someone new to take it from. The bigger number gives the engine fuel again; new flavor, the game breathes. *(The earlier framing called this "relocating to the next planet/market"; it is now alien contact on a single dollar economy — §6.2.)*

**v1.0 scope:** Earth complete + the Final Dollar / first-contact sequence + **the first 1–2 alien epochs ready** (`EpochCatalog.gd` already defines Earth + 3; epochs are cheap data rows, not unique markets — §6.2).

---

## 11. UX Identity (added v0.2)

- **Information density: clean face, accountant's back office.** Main screen is the 50s advertisement — sunny, simple, vibe-forward. Stats live in **The Ledger**, styled as an annual report: lifetime wages vs. capital gains; hours worked; staff payroll vs. staff revenue. The satire's receipts are all there, only if you go looking.
- **Decision cadence: a steady stream of small optimization decisions.** Allocation choices from accelerating curves (§4), rush targets, loan offers, loophole-vs-income, milestone pushes. Decisions are frequent and small; generational forks (origin, estate strategy) are the rare big ones.
- **Notifications: never** (§0, Principle 5).

---

## 12. Art & Audio Direction — Mid-Century Americana

The native visual language of the American Dream: 1950s advertising — the era that invented selling prosperity as moral identity.

- **Style:** flat vector, limited palette (cream, ketchup red, navy, mustard gold), halftone textures, slab serifs + script logotypes. Solo-dev achievable; decisively not an AdCap clone.
- **The joke is sincerity:** Money Laundering as a Maytag ad ("Freshness You Can Bank On!"); MLM as a Tupperware party; Legislative Assets as a handshake under bunting.
- **Not a period setting.** NFTs and Day Trading rendered in 50s ad vocabulary — the anachronism is the gag. The aesthetic is the Dream's eternal branding.
- **Evolving backdrops (added v0.2):** 6–8 painted mid-century backdrops per planet, crossfading at net-worth thresholds — Main Street diner-and-alley → suburban boomtown → downtown skyline → penthouse → marble lobby → the Capitol dome at golden hour. An ambient progress bar needing no numbers. Prestige interaction: each heir inherits post-tax, so the backdrop briefly regresses a tier and re-climbs visibly faster — "speeds up every time," rendered in scenery.
- **Asset bill (Earth):** ~12 property hero illustrations, ~12 staffer cards, 6–8 backdrops, ad-styled UI chrome, ceremony screens (obituary/will, Final Dollar set).
- **Audio:** chipper exotica/muzak — the hold music of prosperity. (Winds down at the Final Dollar.)

---

## 13. Development Milestones (added v0.2)

Sequenced as four playable plateaus — each a legitimate stopping point that is fun on its own:

| Milestone | Contents | Exit criterion |
|---|---|---|
| **M1 — The Slice** | Tap wage, buy ladder, cycles/collect, count-milestone speed-ups, bulk-buy UI, income/sec hero stat. Placeholder art. | Dopaminergic on real phone hardware; the return-spike loop verified against a real 3-hour gap |
| **M2 — The Dynasty** | Death, obituary/will screen, estate tax, Legacy (front-loaded), heir name generator, Family Ledger, origins & debt, offers system | "Speeds up every time" verified across ≥5 generations |
| **M3 — The Theme** | Art pass (backdrops, heroes, staffers incl. per-epoch reskins §6.1), audio implementation (exotica/muzak per §12), UI polish, narrator copy pass, epoch-keyed staffing UI & first-contact beat (§6), offline/welcome-back ritual, rare events, the Ledger | The game is *itself* |
| **M4 — The Epoch** | Earth target & percentage display, Final Dollar / first-contact sequence, epoch progression beyond Earth (alien contact, §6.2), balance simulator validation of the full week | Earth captured; first contact made |

Headless balance simulator is built during M1–M2, not after.

### Near-term tasks (app shell & tooling — not milestone-gated)

These are needed soon and run independently of the M-milestone narrative; schedule them
against current work rather than a specific plateau:

- **Start screen** — the app's entry/landing screen.
- **Settings screen** — player-facing options. *(Now folds into the proposed bottom tab
  bar as the Settings tab — UI Notes §7.)*
- **Balance config screen** — a dev-facing tuning panel that reads/writes the `/config`
  values, so balance can be exercised on-device, not just in the headless simulator.
- **Bottom tab bar navigation (proposed 2026-06-22, UI Notes §7).** Four icon-only (SVG)
  bottom-pinned tabs — Property / Estate Planning / Settings / Family Ledger — replacing
  the single stacked Main screen for readability. Realizes the already-designed Estate
  Planning tab (Spec §9.1). Modal beats stay full-screen above the bar.

---

## 14. Open Questions (updated v0.2)

Resolved since v0.1: ~~automation/managers~~ (§6), ~~dynasty identity~~ (§8.2), ~~demo tier~~ (deleted — no monetization), Legacy's primary function (~~#2~~, §5.1: front-loaded early-ladder multipliers + staff persistence; full upgrade catalog still open).

1. **Legacy upgrade catalog.** Beyond early-ladder multipliers and per-staffer retention (§6.3) — full list and costs.
2. **Achievement design.** Bootstrapped, trillionaire-shift, debt-free Earth, etc. Achievements are a satire delivery channel; full pass needed.
3. **Canonical Earth figure.** Confirm $103.6T or choose another ~$100T-class number.
4. **Prestige currency name.** Legacy / Pedigree / Old Money / other.
5. **Sheet1 curves.** Confirm accelerating-multiplier design and tune against §3.2 pacing via the simulator.
6. **Ladder refresh.** Keep NFTs as period artifact or update rungs for 2026?
7. **Loan offer table.** Tiers, terms, cadence (§8.6).
8. ~~**Market Two design.**~~ **Superseded (2026-06-16)** by the epoch model (§6.2): there are no distinct markets — Earth advances through alien-contact epochs on one dollar economy. Remaining epoch open questions live in the Future Features "per-epoch modifier draft" note.
9. **Narrator copy pass.** Voice defined (§1.2); the writing itself is a dedicated effort (obituaries, will lines, staffer cards, event copy, the Letter).
10. **Name generator part-lists.** A fun evening of writing (§8.2).
11. **Sound & haptics design.** The return-spike delta (§3.1) needs weight; audio direction set, implementation now scheduled into M3 (§13). Remaining open: haptics and per-event sound mapping.
12. **Frenzy meter tuning.** Layer 3 charge rate, multiplier size, duration.
13. ~~**Cycle-time curve (post-vacation rework, §4).**~~ **RESOLVED & shipped 2026-06-22:** back
    half (tiers 7–12) stretched to a 180s top, income-neutral; milestone cadence switched to AdCap
    25/50/100/200/300/400 (§4 note, Spec §3.1/§3.3). **New follow-up:** the cadence runs the
    economy ~38% slower — a prestige/cost re-tuning pass is open (Spec §15 item 8).
14. **Minigames (§5.5).** **Prestige legacy minigame BUILT & iterated 2026-06-22:** a **match-3**
    (`MatchThreeBoard.gd` headless logic + `MinigameScreen.gd`) played mid-succession (after the
    will, before the heir reveal). **Drag** a gem to swap; matches flash with a size badge, clear,
    and survivors + new gems **fall** in (`resolve_swap` records steps; a board test asserts
    applying them reproduces the final grid, so the animation can't desync). Score sets the
    **kept fraction** of base Legacy: `minigame_keep_floor` 0.5 (also what Skip/opt-out banks) →
    **1.0 full** at `minigame_full_score` → up to **+bonus** at `minigame_extra_score`, bonus cap =
    `LegacyUpgrades.minigame_bonus_max()` (0.25 base, +5%/level via the **Family Reputation**
    upgrade). A live spectrum bar (red→gold→green→teal) + Legacy-with-bonus readout shows it.
    Applied in `DynastyState.perform_succession`; setting persisted in `GameState.ui_minigame_enabled`.
    **Still open:** transition minigames (deferred); on-device feel-tune of floor / full / extra
    scores / duration / bonus magnitudes.

---

## Future Features (parking lot — not scheduled)

Captured ideas for later development. Nothing here is in current scope; each needs its
own design pass before it becomes a milestone.

- **Temporary boosts.** Abilities that grant a *very high but very short-lived* increase in
  income — a brief, dramatic spike the player triggers on demand. Distinct from the Frenzy
  meter (§5.1/§9), which is an earned, self-charging burst. **Not cash-purchasable and not
  consumable items with a count:** each boost is unlocked by a *permanent upgrade* that
  establishes a specific bonus (magnitude + duration) gated by a specific *cooldown*. Once
  unlocked, the boost is always available, limited only by its cooldown — so the upgrade
  buys the *capability*, not a stock of charges. Open: where the permanent upgrades live
  (Legacy/Estate Office shop vs. their own track), the bonus/duration/cooldown values,
  whether boosts stack with Frenzy and the Legacy multipliers, and the satirical framing
  (e.g. "energy drink", "insider tip"). (Tim, 2026-06-14.)

- **Alien-contact epochs instead of distinct markets — ADOPTED & IN BUILD (2026-06-16).** This
  was a *possible* alternative to the multi-market expansion model (§14 Q8 "Market Two"); it is
  now the **chosen direction** and the core scale mechanism is **implemented** (epoch-keyed
  staffing, Phase 1 headless core — `EpochCatalog.gd` / `EpochState.gd`). The design of record
  now lives in **§6.2 (Epochs & First Contact)**; this entry is kept for the history and for the
  one piece still parked (the per-epoch modifier draft, below). Core mechanism, now built:
  rather than authoring new worlds that each need their own properties, names, and art, keep a
  single Earth dollar economy and advance it through *epochs* — each epoch is Earth being
  contacted by an alien race, which opens a market orders of magnitude larger and a new alien
  staffer tier for every property. The same property ladder and UI carry forward — only the
  scale shifts — which keeps the interface consistent and avoids the heavy content cost of
  unique per-market definitions. This is how numbers climb into absurd ranges without rebuilding
  the game each time.

  *Decisions (Tim, 2026-06-14, all carried into §6.2):* This is an **endless** game, not a
  narratively complete one. The §10 "Final Dollar" goal — owning all the money on Earth
  ($103.6T, §14 Q3) — is **repurposed as the trigger for the second epoch** (first contact),
  not the ending; each epoch ends with its own "own everything at this scale" line that triggers
  the next contact. The current top epoch is **allowed to slowly stagnate for now** — a soft
  ceiling at the frontier is acceptable rather than a hard finish. This direction is preferred
  over §8/§14 Q8's distinct-markets approach (Q8 is now superseded).

  *STILL PARKED — Per-epoch choice (Tim, 2026-06-14):* The one part of this idea **not** in the
  current build. Each epoch could be more than a scale bump — it introduces a
  **choice**. On entering a new epoch the player is prompted to pick **one of two modifiers**,
  and the two options are **drawn randomly from a larger pool** of possibilities. Framed as a
  choice between **specialization or expansion**. This is the novelty layer that keeps an epoch
  from being pure ×N multiplication: each era reshapes the run a little, and the random draw
  gives the endless game build variety and replay interest (a roguelike-style draft on top of
  the idle economy).

  *Still open:* the per-epoch scale multiplier and pacing; differentiation from the Legacy
  multipliers (keep them orthogonal — Legacy accelerates within a bloodline, epochs shift the
  whole era); the satirical framing of the alien-contact beat; the **modifier pool itself**
  (what's in it, specialization vs. expansion axes, magnitudes); whether chosen modifiers are
  permanent and **stack across epochs** or apply only to their epoch; whether the unpicked
  option is ever recoverable; and how the random draw stays fair/interesting (weighting,
  no-dup rules).

- **Lifetime cash earned as the universal progress metric — RESOLVED 2026-06-14.** Use **total
  cash earned over a lifetime** (a monotonic, never-spent accumulator, distinct from current
  spendable cash) as the general yardstick of progress. Because it only ever grows, it stays
  comparable across epochs no matter how absurd the scale becomes, and it reads on-theme as a
  career/obituary earnings stat (§8.3).

  **Decision (Tim, 2026-06-14): lifetime-cash-earned becomes the *basis* of the existing Legacy
  conversion — not a second currency.** There remains exactly **one** spendable prestige
  currency (Legacy, spent in the Estate Office; §8.4, Mechanics Spec §9.3). Lifetime-earned is
  the *meter*; Legacy is the *currency* it converts into. This avoids the two-competing-tracks
  trap. Mechanically:
  - The **dynasty** holds `lifetime_cash_earned`, a cumulative all-generations accumulator —
    the cross-epoch yardstick, the §8.3 obituary headline, and the Family Ledger career stat.
    It only ever grows; spending never reduces it.
  - Each **generation** tracks `cash_earned_this_gen` (the dollars that generation alone
    earned). That *per-generation* figure — **not** the cumulative total — is the gross estate
    fed into the death waterfall. (Per-generation is required: converting the cumulative total
    at every death would re-bank the whole dynasty's history and Legacy would explode.)
  - The estate waterfall is otherwise **unchanged**. The only swap is the will's *gross
    estate*, which becomes `cash_earned_this_gen` instead of net-worth-at-death. Creditors,
    exemption, estate tax, **loopholes** (§8.4), the `K_LEGACY × x^ALPHA` conversion curve, and
    the Estate Lawyers yield multiplier all keep working verbatim — so the loophole tree keeps
    its teeth.

  **Why this basis over net-worth-at-death:** net worth rewards *hoarding* (die holding a big
  pile) and quietly punishes spending on units/staff right before death; lifetime-earned rewards
  *earning over a life*, which is what the idle loop actually is. Being monotonic, it stays
  comparable across order-of-magnitude epoch jumps and through the §10.1 "Engine Stops"
  stagnation, where net worth freezes and reads awkwardly.

  **Theme note (accepted):** an estate tax literally taxes the *estate* (the pile), so taxing
  lifetime earnings is conceptually closer to an income tax. Tim accepted this in favor of the
  gameplay win — and the satire arguably sharpens ("they tax everything you ever earned").

  *Still open:* whether "earned" counts wage income + capital gains together or tracks them
  separately for the Ledger (§11 distinguishes lifetime wages vs. capital gains); and re-tuning
  `K_LEGACY` / `ALPHA` once the gross estate changes magnitude (`TBD-SIM`). **Implementation is
  M2-later — recorded here, not scheduled now.**

- **Balance guardrail: a property must not trivially self-fund its own expansion.** (Tim,
  2026-06-14.) Observed: buying additional units of a property is *too* affordable from that
  same property's income — and it gets *easier* the more you own, the opposite of what the
  ladder intends. Diagnosed cause: a property's income scales **linearly** with units owned
  (`units × income_per_unit`, Mechanics Spec §3.4), but the next-unit cost grows
  **geometrically** at only `r0 ≈ 1.07×` per unit (§3.2). At low counts linear `×n` outpaces
  `1.07^n`, so the *payback period* (next-unit cost ÷ current income) **shrinks** as you stack
  units — for the ATM it falls from ~6s at 1 unit to ~1s by the end of the 1–19 band — and the
  ×2 milestone reward at each threshold halves it again. *Worked example (ATM, `base_cost=50`,
  `r0=1.07`, `income/unit=5`, `cycle=0.54s` → $9.26/sec each): payback ∝ `r0^n / n`, which keeps
  falling until `n ≈ 1/ln(r0) ≈ 15` units — i.e. almost the whole first band.*

  **Why it matters:** if a property self-funds its own growth, the optimal play collapses to
  pouring everything into one property, which erases the cross-property allocation decisions the
  game is built on (§11). The guardrail: *a property's own income should never make its next
  unit trivially affordable; within a milestone band the payback period should hold flat or
  rise, never fall.*

  **Lever:** `r0` is the knob (too shallow against linear income). Don't hand-pick a number —
  define a **target payback period** per property (flat-to-rising across a band) and let the
  balance simulator (§13 / Mechanics Spec §13) solve `r0` against it, preserving the
  "milestones stay reachable" guarantee (§3.2). A `TBD-SIM` tuning pass, not scheduled now.

---

## 15. Source Artifacts (project knowledge inventory)

| Artifact | Status | Role |
|---|---|---|
| `AmericanTycoon_PropertyTypeConfig.xlsx` | Sheet2 captured in full (§4); Sheet1 partially captured — **upload original to project** | The economic skeleton |
| `AmericanTycoon_StartingChoicesFlow_Archive.png` | Captured (§8.1) | Opening sequence — preserved near-untouched |
| `DollarSign_Large.png` | Captured | Placeholder art, retired |
| Unity C# scripts | **Not yet reviewed — upload gameplay-logic scripts** (currencies, generators, upgrades, save, timers) | Design-intent mining only |
| GDD v0.1 | Superseded by this document | — |
