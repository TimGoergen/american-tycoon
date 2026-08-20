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

### 2.1 Number formatting — one authority, named scale to sextillion+ (note added 2026-07-01)

**Problem.** The current formatter (`Money.display()` / `display_cash()`) tops out at **Trillion** — anything past $1e12 just piles digits in front of "T" ("$1000000T"). But the epoch ladder already blows past that: tier-6's economy is ~24.3M × Earth ≈ **$2.5 sextillion** ($2.5e21), and the proposed meta-tier upgrades (§8.7, ×10/×100 leaps) push higher still. Currency must read cleanly all the way up.

**Requirement 1 — extend the named-scale ladder.** Continue the short-scale suffixes past Trillion through at least **Decillion**, which covers the game's top scale with comfortable headroom:

| Suffix | Magnitude | | Suffix | Magnitude |
|---|---|---|---|---|
| K | 1e3 | | Sx (Sextillion) | 1e21 |
| M | 1e6 | | Sp (Septillion) | 1e24 |
| B | 1e9 | | Oc (Octillion) | 1e27 |
| T | 1e12 | | No (Nonillion) | 1e30 |
| Qa (Quadrillion) | 1e15 | | Dc (Decillion) | 1e33 |
| Qi (Quintillion) | 1e18 | | | |

The exact abbreviations are fixed here so they're unambiguous (Qa vs Qi, Sx vs Sp). **Never scientific notation BY DEFAULT** (the §2 Numbers rule) — amended 2026-07-30 (Tim): the default display never shows an exponent, but a planned Settings option lets the player opt into scientific notation (`$4.2e18`) alongside alphabet notation (`aa/ab/ac…`) and today's abbreviations. See `Plans/Roadmap.md` §6. Beyond Decillion is no longer out of range — the ladder was extended to 1e120 (`Money.SUFFIXES`, 40 rungs) for the 27-tier epoch ladder, and the AdCap-style `aa/ab/ac…` scheme anticipated here is now the roadmap's alphabet-notation mode.

> **IMPLEMENTED 2026-07-03** (Tim confirmed real abbreviations over letter schemes; the epoch
> roadmap may grow past 6, so headroom matters). `Money.SUFFIXES` is one shared ladder driving
> both `display()` and `display_cash()` (Requirement 2's "can't drift" form), running K → **Dd
> (duodecillion, 1e39)** — two rungs of extra headroom past this table's Decillion, covering
> roughly a 17-epoch ladder at ×30/epoch. *(2026-07-17 note: the continuous ladder since moved
> epochs to ×16807 each — §6.2 — so Dd 1e39 still clears the authored 6-epoch range (top
> threshold ~1.4e35) but the graceful-overflow item becomes real around epoch 7, not far
> beyond it.)* Pinned by `sim/MoneyTest.gd`. The call-site audit
> found no ad-hoc currency formatting outside `Money`. The compact-vs-spelled-word open
> decision above stands unchanged (compact everywhere today).

**Open decision — compact suffix vs. spelled word.** The §2 Numbers row states a deadpan preference for the readable real-dollar style ("$14.3 trillion") over obscure suffixes, yet the code uses compact suffixes ("$14.3T") to fit tight rows. Recommendation: keep **compact suffixes** in space-constrained UI (property costs, income/sec, buttons) and reserve the fuller style only where there's room (the cash hero, ceremony screens) — but the call is Tim's, and it bears on §14 readability (large text, imperfect vision). Whatever is chosen, the abbreviation set above is the canonical mapping.

**Requirement 2 — one formatting authority, used everywhere.** Every currency amount on screen must route through `Money` (`display()` for compact, `display_cash()` for the watched balance) — no ad-hoc `"$" + "%.2f"` formatting anywhere. Most call sites already do this; the task is to (a) extend **both** `Money` methods over the **same** suffix table (ideally a single shared ladder so they can't drift), and (b) audit every currency display site to confirm none bypasses `Money`.

**Underlying type.** `Money` wraps a float64, which loses *exact* integer precision beyond ~9e15 (2⁵³); amounts above that drift by dollars/thousands. For an idle game at this scale that display-only drift is standard and acceptable. If exactness ever matters, swap the internal representation to a mantissa+exponent big-number — the `Money` class already documents itself as that swap point, satisfying the §2 "big-number support from day one" intent for display today and precision later.

---

## 3. Core Loop Architecture — Three Nested Loops

1. **The Run (a lifetime).** Buy the ladder, ATM → Executive Assets. Ends in death/retirement.
2. **The Dynasty (prestige).** Estate passes to an heir, minus estate tax. Post-tax remainder converts to permanent dynastic advantage. Loopholes purchased via political assets erode the tax across generations.
3. **The Epoch (alien contact).** A generation captures the entire current economy (Earth's whole value, ~$103.6T). The game does not end — instead Earth makes **first contact** with an alien civilization, which opens a market orders of magnitude larger and a new alien-tech staffer tier for every property (§6.2). A game about wanting all the money cannot, by definition, end; it just keeps finding bigger economies to consume.

**Contact is the scale engine, not sci-fi spectacle.** The aliens are flavor and magnitude bands on a single dollar economy — capitalism ran out of Earth, so it opened the galaxy as a market. *(This replaces the earlier "relocate to a distinct new market" idea — see Future Features.)*

### 3.1 The Session Loop (the emotional heart — added v0.2)

The designer's peak dopamine moment is the **return spike**: spending offline-banked resources and seeing an immediate, material income increase. The check-in loop — away → pile accumulates → return → convert pile into a visibly higher income rate → leave knowing the next pile builds faster — is therefore the heart of the game, not the long-session grind. Requirements:

- **Offline accrual tuned to purchase thresholds, not just time:** a typical away-period banks roughly enough to cross at least one threshold (tier, hire, or count milestone).
- **Offline earnings unlock in the first session** — the peak moment cannot be gated late.
- **Bulk-buy UI is mandatory:** ×10, ×25, and "×to-next-milestone" buttons, so the pile converts to a spike in one or two taps. *(As shipped 2026-07-07: one global toggle cycling ×1 / ×10 / **NEXT** / MAX — NEXT buys exactly enough units to reach the next milestone threshold, all-or-nothing, replacing an earlier ×100 mode; this realizes the "×to-next-milestone" intent.)*
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

| # | Property Type | Cost† | Income/sec† | Cycle (sec)‡ | Income/Cycle† |
|---|---|---|---|---|---|
| 1 | ATM | $50 | $12.50 | 0.54 | $5 |
| 2 | Money Tree | $550 | $25 | 1.765 | $50 |
| 3 | NFTs | $6,050 | $50 | 3.077 | $200 |
| 4 | Tax Increment Financing | $66,550 | $100 | 4.47 | $800 |
| 5 | Cross Border Distribution | $732,050 | $200 | 6.233 | $3,200 |
| 6 | Money Laundering | $8,052,550 | $400 | 8.15 | $12,800 |
| 7 | Day Trading | $88,578,050 | $800 | 11.401 | $51,200 |
| 8 | Flipping Houses | $974,358,550 | $1,600 | 15.67 | $204,800 |
| 9 | Multi Level Marketing | $10.72B | $3,200 | 21.986 | $819,200 |
| 10 | Hedge Fund | $117.9B | $6,400 | 30.778 | $3.28M |
| 11 | Legislative Assets | $1.30T | $12,800 | 43.023 | $13.1M |
| 12 | Executive Assets | $14.27T | $25,600 | 60.0 | $52.4M |

> **‡ Cycle (sec) — synced to the live `.tres` configs (2026-07-23 doc pass).** These are the
> real `base_cycle_length` values shipped in `game/config/properties/01..12_*.tres`, replacing
> the original doubling curve (0.4s → 2048s) that never shipped. The curve is a gentle geometric
> taper — tier 1 ≈ 0.54s up to the tier-12 **top of 60.0s (1 min)**, per the 2026-07-03 pace-pass
> compression (see the rework notes below). **Note the top tier is 60s, *not* the 3–5 min base the
> earlier roadmap called for** — the 2026-06-25 stretch did reach ~272s (~4.5 min), but the
> 2026-07-03 core-pace reversal deliberately compressed it back down to 60s (income-neutral), so
> "top tier ≈ 3–5 min base" is superseded design intent, not the live state.
>
> **† Cost / Income/sec / Income/Cycle** columns are the *original xlsx design-intent* figures and
> are illustrative only — the live configs have since been reworked several times (income-neutral
> cycle changes, `r0` steepening, ~×5/tier income steps), so the live per-unit cost and income no
> longer match these cells. Only the Cycle column above is synced to code. See the `.tres` files
> for live cost/income.

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
> business collapses once maxed. (`.tres` values updated; the table's Cycle column above has since
> been re-synced to the live configs — the numbers narrated in this note are the 2026-06-25 stretch,
> which the 2026-07-03 pace pass below then reversed.)
>
> **Core pace pass — REVERSED the stretch 2026-07-03.** Device feel-test verdict: the game
> *progresses* too fast but *cycles* feel too slow — the two clocks were inverted vs. Tim's
> mid-game Idle Slayer target (fast feedback, slow progression). Per the pace study
> (`game/sim/PaceStudy.gd`, `Plans/Core_Pace_Study.md`), cycles were **compressed back down,
> income-neutral** (a geometric taper: tier 1 unchanged, tier 12 **272s → 60s**; each tier's
> `base_income_per_unit` scaled by the same factor, so income/sec — and the tuned epoch/Legacy
> pacing — is untouched). The progression brake moved to the cost curve instead: **`r0`
> 1.07 → 1.09 on all 17 rungs**. Study finding worth keeping: cost steepening widens the
> moment-to-moment purchase cadence but *cannot* slow the macro arc — income is self-funding
> exponential and the epoch wall is earnings-gated — so if the game still progresses too fast
> on device, the next lever is income-side (per-rung ~5× income step, milestone ×2 rewards),
> not more `r0`.
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

### 5.2 Rush Momentum → Overheat → Cruise Control → Overdrive Vent Windows (shipped; vent windows merged to main 2026-07-20)

Layer 2 grew a companion system: sustained rushing has its own meter on top of the per-tap value. It shipped in four dated steps, each reworking the last on device feedback:

- **Rush Momentum (the original ratchet).** Holding rush built a property-income bonus toward a flat capped **+30%** (`rush_momentum_max_bonus`, halved once on device from +60% for being overpowered). Problem: momentum built to the cap and sat there — the optimal play was "never release," a grip test, not a decision.
- **Rush Overheat (Tim 2026-07-15; design: `Plans/Rush_Overheat.md`).** Momentum became **HEAT — one scalar, no timers**; every tier is a heat *range*, so all feel questions are band-edge knobs. Rushing heats the property up (that's *why* its productivity rises); push it too hot and it shuts down. Bands: **Building** 0–100% (bonus 0 → +30%), **Hot** 100–125% (+30 → +40%, amber), **Critical** 125% → a **secretly rolled ceiling** (140–160%, re-rolled per excursion on entering Hot; randomness lives ONLY in Critical, so Hot's promised width is always honored) paying +40 → **+55%** — then **OVERHEAT**: rush disabled, bonus to 0, the bar visibly drains (~8–12 s lockout) plus a short re-arm delay before rush re-enables. Heat builds *slower* above the Hot edge so the danger ride is a real ~5–8 s decision window; releasing drains back down through the bands, so hysteresis falls out for free. **Frenzy freezes heat and bonus** (a true freeze — no overheat can gut a frenzy). Bonus stays a pure function of heat, preserving the cash-always-matches-the-readout invariant. The mechanic's job shifts from rewarding sustained engagement to rewarding **attention**: the effective bonus is the ride/vent duty cycle, which is why the peak rises to +55%.
- **Cruise Control (Tim 2026-07-16; design: `Plans/Rush_Cruise_Control.md`; both merged + device-verified 2026-07-16).** Tim missed the old zone-out infinite hold, so holding is now **safe forever at a +25% cruise bonus** (`rush_momentum_cruise_bonus`): heat clamps at the cruise point and cannot overheat there. The danger bands are **opt-in via the OVERDRIVE (OVR) button** — always visible per the no-moving-UI rule, gray-disabled until heat reaches the cruise clamp — and **per-excursion**: it disengages on release (and on overheat), so the gamble is a fresh choice every press, never a sticky mode. Two Legacy upgrades in a new **Rush** category, both additive with hard caps (compounding is reserved for the core accelerators): **Cooling Systems** (+1 point cruise bonus/level, 5 levels — capped at the old +30%, so a storied dynasty re-earns the old infinite rush *exactly*, never more) and **Rapid Restart** (−10% total overheat lockout time/level, 5 levels — half the punishment, never zero). Measured duty cycle: cruising averages **+24.5%** vs **~+34.8%** for skilled overdrive riding — the gamble is worth about ten points.
- **Overdrive Vent Windows (Rush Momentum Phase 3, Tim 2026-07-17→20; design: `Plans/Overdrive_Vent_Windows.md`; built on `feature/overdrive-vent-windows`, merged to main 2026-07-20).** That ~+10-point overdrive edge was too thin for "more active but not more interesting" play, so the danger ride was rebuilt into a telegraphed skill game. **RETIRED here: the secretly-rolled random ceiling (the old 140–160% roll) and the entire Critical band** — both are gone, so ignore the Rush Overheat bullet above where it describes them; it is kept only as the reasoning trail. Entry is unchanged — hold to rush, cruise clamps at +25%, a second finger on OVR opts into overdrive — but heat now runs just two regions, **Building (0 → 1.0)** then **OVERDRIVE (1.0 → a fixed hard ceiling of 1.60)**, with the bonus a single continuous lerp from +30% up to the current peak (no band kink). While overdrive is engaged, the chance of a **vent check** rises continuously with how DEEP into overdrive you are riding. A hazard roll *schedules* an event: a red bar sweeps in from the right edge over ~0.7 s toward a target line, and when it arrives the **window** opens — the player must complete a **lift gesture** (1 lift, +1 more every 3 tiers, capped at 3) before a timer strip drains. A success vents a little heat and **ratchets the bonus +30%**; a miss OVERHEATS. **There is no tier cap** — the difficulty curve (checks come faster, windows tighten, lifts stack) is the ending, so the bonus ladder is unbounded (base +55%, +30% per vent) and every skilled run eventually dies on a blown beat rather than a ceiling; how high you climbed is an implicit high score. **Overheat became a property freeze, not just a lockout:** the meter goes down empire-wide (no bonus anywhere) and every property that was *actively being rushed* freezes — cycle paused, no income — until it re-arms, while the rest of the empire keeps earning; because that freeze is a proportional, real-money penalty, the old dead-time re-arm sting is now **zero**. **Frenzy no longer freezes the heat model** (the 2026-07-15 freeze was removed 2026-07-19): burns and vent checks run together, and you can overheat mid-burn — the peak of the loop at the peak of the risk. **Bailing pays:** releasing keeps the earned bonus and spins it down as heat bleeds, on one clock (bar, income, and the "SPINNING DOWN" chip all end together), so a voluntary stop is rewarded — while an overheat still zeroes everything instantly. (The tail's bonus applies only while a property's cycle is running: a staffed property earns it for the whole tail, an unstaffed one through its current cycle, then it stops. An earlier separate "banked bonus" was built and then deleted in favor of this heat-unified tail.) Cruise Control and the two Rush Legacy upgrades (Cooling Systems, Rapid Restart) are untouched.

All knobs (the `rush_momentum_*` heat build/bleed rates, hard ceiling, bonuses, vent rates / approach / window duration / lift ladder / refractory, cruise bonus) live in Balance Tuning; `rush_momentum_max_bonus`, the random-ceiling roll, and the Critical-band edges are all superseded. Sim-measured duty cycle (current build, approach 0.7 s): cruise **+24.9%**, a skilled venter **+68.7%** (median death at tier 8), a sloppy venter **−18.3%** (bad overdrive play now loses real money — accepted by Tim as what makes cruise a genuine choice), and a timid cash-out farmer **+11.6%** (below cruise). Remaining open: two small follow-ons from Tim's 2026-07-20 interview — vent haptics that pulse once per demanded lift, and a best-streak record shown at the overheat moment and in a new stats screen (not on the momentum bar). The old open items are resolved: the per-tier haptic/sound polish shipped with the device passes, and the duty-cycle edge question is answered — cruise **+24.9%** vs a skilled venter **+68.7%** is a gap that reads as worth it, not the old ~+10 points.

### 5.5 Minigames (added 2026-06-21; reframed as a FRAMEWORK 2026-06-22)

Playing the game on vacation, Tim wanted **more energy at transitions** — the seams between
screens shouldn't be dead air. This grew (Tim, 2026-06-22) into a **minigame framework**:

- **A library of 6 distinct minigame TYPES (all BUILT):** Match Three, Timing Bar, Catch the
  Money, Memory Match, Balance the Books, and Micro Basketball.
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
2. **Epoch change / First Contact — reward = a NEW PROPERTY TYPE; minigame = upside-only bonus (REDESIGNED 2026-07-01 — supersedes the starting-units model).** Theme: *negotiating the alien trade deal*; winning opens a genuinely new *kind* of business in the bigger market.
   - **EARTH SPLIT (2026-07-27, `Plans/Earth_Split_Epochs.md`):** Earth is now two epochs — Blue Collar (tier 1, $75M threshold) and White Collar (tier 2, the full Earth target) — so the epoch grammar (progress bar → ownership gate → arrival beat → new cohort) runs from minute one, and every alien tier reads +1 (Luminari = 3; 27 epochs). Tier 2's arrival is the **promotion beat**: the contact overlay in an Earth voice ("MOVING UP"), quiet card only — its trade-deal minigame is a deferred follow-up needing moving-up copy, per Tim. Alien tier references in the older text below read as tier N+1.
   - **An ESCALATING property cohort per alien epoch** (`unlock_tier` on `PropertyConfig`): epoch 2 has 6 rungs and each later epoch adds one more — 6/7/8/9/10 for epochs 2–6 (cohort size = tier + 4). Flagships unchanged: Photon Exchange (epoch 2, Luminari), Data Foundry (3, Geth), Spore Bank (4, Mycelium), Prism Vault (5, Quartzite), Time Bank (6, Chronophage); each epoch's grandest venture (Starcore Syndicate, Singularity Holdings, Biosphere Trust, Geode Dominion, Causality Capital) stays its **top** rung, with the newer properties slotted into the upper-mid rungs. **Ladder = 52 rungs (12 Earth + 40 alien).** Each rung is hidden and unbuyable until its epoch is reached, then staged in by the cost/peek rule. *(Decision trail: resolves the 2026-07-03 "one property per epoch feels cheap" verdict — Tim chose 5, 2026-07-11; then **escalating cohorts, Tim 2026-07-15** — the unlock-cadence study showed fixed 5-rung cohorts made the gap between first-unit unlock beats GROW each epoch (median 4.4 → 7.1 min), because epoch durations creep while the rung count stays fixed; escalation holds the gap nearly flat (~3.2–4.0 min median) with epoch durations and thresholds unchanged by construction. Design: `Plans/Escalating_Ladder.md`.)*
   - **The cohort carries the epoch's income leap — not staff.** As shipped (continuous-ladder rework 2026-07-12, re-gridded for the escalating cohorts 2026-07-15): each epoch's cohort spans exactly **×16807** (= 7⁵, matching the per-epoch threshold growth) — rung k of an N-rung cohort costs `flagship_cost × (16807^(1/N))^k`, so the per-rung ratio shrinks as cohorts grow (×5.06 at epoch 2 down to ×2.64 at epoch 6). Income holds `income = cost × 0.25 × 0.80^(T−1)` (per 60 s, cycle-neutral) across every alien rung — **retuned 2026-07-27** (*Alien Payback Retune*, Tim's Candidate B, `Plans/Alien_Payback_Retune.md`): the earlier `× 0.01824` constant made the first alien property a ~19× income-per-dollar cliff (64-minute per-unit payback, felt on device as "rushing the Photon Exchange can't buy its own next unit"); the new rule continues Earth's payback ramp (~5 min at Luminari) and moves the intended prestige stall into the per-epoch ×0.80 decay (tier 26 ≈ 18 h). The flagship anchor (rung 0) is priced off the player's epoch-entry WEALTH — ~10% of the previous threshold, a real save-up — and the retune makes each flagship's step-up over a staffed Earth property far exceed the original ~3× floor (Tim 2026-07-11/12; still a floor, no longer the sizing rule). *(Supersedes the earlier threshold-anchored `economy_step 60 / DRIFT 0.95` formula of Phase 3, 2026-07-11 — see `Plans/Epoch_Depth_Pass.md` for that history; sim-verified via the pacing MEASUREMENT + PLAYOUT + step-up CHECK in `sim/Sim.gd` and the cohort pattern check in `sim/EpochTest.gd`.)*
   - **You start with ZERO of it (no free units).** At a new civilization the property unlocks but you own none. Each new property is deliberately **expensive relative to your current progress**, so earning the income to afford your *first* purchase is the achievement — then it pays off big as you scale in. (Directly reverses the old "starting units" head-start: owning several for free killed that sense of reaching a new tier.)
   - **The minigame is upside-only.** The floor is always the property's **base income — the player never receives less, regardless of the result.** A good run adds a **permanent bonus** to that property's income-per-cycle *and* cycle-time, sorted into **three buckets — low / medium / high**. A poor run or a Skip simply grants no bonus (base only) — never a penalty. (This departs from the universal 0.5×→1.25× spectrum the other two sites use; First Contact is bonus-on-top-of-a-guaranteed-floor.)
   - **Staff demoted from the epoch driver.** Staffing is no longer the epoch income multiplier; alien properties remain staffable for hands-off automation only (proposed default — see plan-doc open item). Broader §6 implications flagged in §6.2.
   All first-pass values (the low/med/high bonus sizes; the cohort magnitudes themselves are now fixed by the ×16807 grid above, superseding the old "~30×/tier" figure) need an on-device **and** sim tuning pass (the sim can't reach epoch 2 in its per-generation budget). Full design + open items: `Plans/First_Contact_Property_Reward.md`.
3. **Welcome-back / offline return — multiplier on the offline pile (BUILT 2026-06-24).** A
   round scales the overnight pile: the base pile is banked on resume, the minigame credits the
   +/- delta (earned income), then the welcome screen shows the final haul. *(Watch: welcome-back
   is the most FREQUENT transition and the genre intends a frictionless return — a mandatory
   minigame each open, with a 0.5× downside, may feel punishing. Tune cadence / lean on the
   opt-out; flagged for feel-testing.)*

**Player setting:** a persisted toggle (`GameState.ui_minigame_enabled`). **Default:
mandatory.** **Opting out — or tapping Skip — banks the keep floor** (the worst result, not a
safe 100%), so skipping has a real cost. A per-round Skip is always available. (At First Contact
with minigames off, the keep-floor head start is granted directly, no screen.) *(Slated to
change: the parked reward-curve reshape below makes skip/opt-out exactly neutral — see the
work-item-4 note after the Balance rework.)*

**Built 2026-06-22 — match-3 type (the first of the library):** drag a gem to swap; matches
flash with a size badge, clear, and survivors + new gems fall in.

**Polish pass (2026-06-29) — host shell + all six types.** A deliberate visual/juice/feel pass
(plan `Plans/Minigame_Polish_Pass.md`). Shared host treatment, applied once so every type
benefits: the **timer** is a large focal point that pulses amber under 10s and blinks gold under
3s; the **spectrum bar reads by fill + color ONLY (no numbers)** and now glides smoothly with an
edge-cap that brightens into the bonus band and a flash on first reaching "full"; the **SKIP
button shows the concrete kept reward** ("SKIP · keep N …") since the bar carries no numbers;
the **result reveal blooms** in; a **"⏸" cue** shows while a game pauses the clock mid-animation.
The **Get Ready gate** now states the game's goal AND the universal win/lose stakes (play well to
keep more + a bonus; a weak round or Skip keeps only the minimum) **before** the clock starts —
previously the player saw the goal only once play began (Tim, 2026-06-29) — then fades off to
unmask the game. Each type got its own juice + a locked difficulty *direction*
(some harder, some "made clearer", Basketball held) — all difficulty constants are first-pass,
pending an on-device re-tune (plan step 5). **Visual treatment (Tim, 2026-06-29 → 2026-06-30):**
the minigame screen and the Minigame Tuning screen float over a **themed casino/library backdrop**
(`art/backgrounds/minigame_background.png`, its corners CPU-rounded to the screen frame so the
bright bottom-corner art doesn't square off); the card is **semi-transparent (70% cream)** and
smaller (20% shorter, 10% narrower) so the scene reads around and through it. The **Minigame Tuning
list sits on a card that matches the Get Ready panel exactly** (same size/shape, same 70% cream).
The reward MATH is unchanged: every type still only reports a [0,1] performance and the host maps
it to the universal multiplier.

**Challenge Mode (feature complete on `feature/challenge-mode-phase1`; device-confirmed 2026-07-22;
pending merge).** A discoverable, player-facing progression laid over the six minigames, reached from
**Settings → CHALLENGES** (its own screen — the old "free-play arcade toggle on the Minigame Tuning
screen" is retired; see the history note below). Each game climbs its own **finite tier ladder** (30
tiers, a real "mastered" summit), and clearing tiers grants small, **permanent, dynasty-wide bonuses**
that **survive prestige** on two tracks: **property income** and **Legacy yield**.

- **A run is a keep-alive push, not endless.** The clock starts with just a few seconds (6s, though
  Micro Basketball opens with 10s), drains in real time, and each point you score tops it back up;
  when it hits zero the run ends and the best tier you reached is banked (banking is raise-only — a
  bad run never lowers a tier you already earned). The whole stake is your time; there is no currency
  wager. *(Memory Match is the exception — it has no timer and instead ends on a completed climb or a
  wrong tap.)*
- **Payouts land every 5th tier**, on one schedule shared by every game, alternating income and Legacy
  and escalating +1%/+1%/+2%/+2%/+1%/+1% per track — so **one mastered game is worth +4% income and +4%
  Legacy**, and all six mastered land near Tim's **~25/25%** target. Most tiers are progress-only; the
  screen shows how close the next reward is and which track it pays.
- **Each game reports a raw cumulative score** (points / locks / coins / climbs / seconds in zone /
  baskets) rather than the [0,1] reward metric. Four games earn a tier per fixed score step; the two
  low-ceiling games (Micro Basketball, Memory Match) use a gentle escalating per-tier cost so their
  early tiers are reachable and mastery is still a climb.
- **Each game plays harder in Challenge Mode** (an oscillating coin field in Catch, a drifting gold
  zone and waving marker in Timing, premium legacy gems in Match Three, a Simon climb in Memory), and
  a missed hit drains the keep-alive clock — but the reward/prestige version of every game is
  untouched. The run display is a large pulsing **TIER {current}/{best}**.

*(History: Challenge Mode began 2026-06-30 as a dev/settings "free-play arcade" toggle — endless play,
no timer, no reward, just a saved high score. It was reworked into the tiered, timed, dynasty-rewarding
progression above; the free-play toggle is gone. The per-game best score is still saved, but now feeds
the best-tier readout rather than a standalone Score/Best view.)*

**Basketball specifics (Tim, 2026-06-30).** The aim guide is a **force wedge**: a triangle whose
point sits at the ball's launch spot and fans out wide in the direction of travel, its size + a
single blue→purple→red color both scaling with the pull's force (red = maxed). Pull power was
raised so a short drag reaches the hoop (the ball rests near the floor with little room to pull).
The board has a generous margin, a **thick black rounded outline**, and a **gym backdrop**
(`art/backgrounds/basketball_court.png`) inside the rounded corners.

**Balance the Books — REWORKED 2026-07-08 (playtest verdict: the horizontal two-button version
"doesn't work," work item 6).** Now **vertical and single-input**, in the shape of Stardew
Valley's fishing minigame: hold anywhere to lift the marker, release and gravity drops it, and
the gold zone drifts up and down the track on its own — keep the marker inside it and the score
banks every moment it stays in (same banked time-in-zone scoring as before; Challenge score =
seconds in zone). A soft bounce at the track's floor/ceiling punishes slamming an edge.
First-pass physics values; **not yet device-verified.**

**Transition framing — WHY a minigame is happening (shipped 2026-07-08, work item 3).** The
2026-07-07 playtest found nothing in the game explains why a minigame suddenly plays at a
transition. The Get Ready gate now opens with a one-line **framing** per launch site — at
succession the heir proves what kind of tycoon they are before the fortune passes; at
welcome-back it's one bold move before the overnight pile banks; at First Contact it's the
opening of the trade negotiation — and every game's goal line grew from a fragment into real
guidance (match-3's now actually explains the avoid-gem mechanic). Framing is copy-first: the
**art pass is where the true transition content gets defined** (Tim, 2026-07-08).

**Reward curve reshape — DESIGNED, NOT BUILT (work item 4, parked pending Tim's feel pass).**
Direction from the 2026-07-07 debrief: replace the keep-floor model (bad/skip = 0.5×) with
**standard play ≈ neutral 1.0** (a flat middle band), a modest downside only for genuinely bad
play, a modest upside for great play — and **Skip/opt-out land at exactly 1.0** (free, not
penalized). Couples with a match-3 difficulty raise (Tim maxes its score almost every round;
once great play is the only upside, a reachable ceiling makes the bonus effectively flat). All
band numbers to live in TuningConfig.

**Build phasing:** (1) **framework** — a host that picks a random minigame type and maps its
[0,1] performance to the universal multiplier; refactor match-3 into the first type; route
prestige through it (no behavior change). (2) **add 2–4 more types** so the random draw has
variety. (3) **wire the First Contact and Welcome-back sites** with their rewards —
**welcome-back DONE 2026-06-24**; **First Contact DONE 2026-06-28** (its own 4-phase sub-build —
epoch unlock gate → first alien property + minigame hook → properties 14–17 + magnitude tuning →
copy polish + doc sync; site 2 above).

---

## 6. Staffing & Automation (rewritten v0.3 — epoch-keyed staffing)

Staffing is the moment **labor itself becomes something you purchase** — and in this game that purchase is no longer a one-time on/off switch. It is a **tiered upgrade track keyed to alien epochs** (see §6.2). Each property's staffer can be hired, then *upgraded* tier by tier as Earth makes contact with successive alien civilizations, with each tier a large income multiplier justified in-fiction by that civilization's technology ("the Luminari run your ATMs on coherent light now").

This is the diegetic engine behind the game's absurd scale: capitalism ran out of Earth, so it opened the galaxy as a market.

### 6.1 Per-property staff tiers

- **Hire, then upgrade.** Tier 0 = unstaffed (you collect by hand). Tier 1 = an Earth staffer: cycles now run and collect automatically, forever — automation behaves exactly as the old one-time hire did. Tiers 2+ replace that staffer with an alien-tech version that multiplies *that property's* income.
- **You can only reach a tier whose epoch you've reached this run** (§6.2). The next-tier upgrade is gated by contact, not just by cash.
- **The multiplier is honest.** A staffer's tier multiplier is applied at the point of payment alongside frenzy and Legacy, so it shows up in the on-screen income/sec — no hidden math.
- **Hire/upgrade cost climbs with tier** (alien talent costs more): the entry-hire cost is anchored to the target epoch's whole economy (§6.2). Retuned 2026-06-27 so the cheapest staffer is ~1% of the epoch economy (was ~0.1% — too cheap to feel at contact) and the full alien roster costs more than one epoch's earnings, making staffing a prioritized spend rather than a one-tap sweep. **Re-anchored 2026-07-15 (escalating ladder):** staff pricing grows by a per-property **staff price rank**, not the raw ladder index — Earth properties keep their ladder position (ranks 0–11); an alien property's rank is 12 + its cost rank *within its own cohort* (flagship = 12, exactly its old index, so flagship staff prices are unchanged). The appended cohort siblings sit out of cost order in the global array, so the global index had stopped meaning "how far up the ladder." Legacy staff retention (§6.3) prices off the identical rank (`EconomyState.compute_staff_price_ranks`).
- **Then keep leveling that staffer — the per-epoch upgrade track (added 2026-06-27).** After hiring an epoch's staffer, you LEVEL it up repeatedly *within* the epoch; each level compounds that property's income by a fixed step (`staff_level_step`), with the cost climbing geometrically (no hard cap — the cost is the only brake). This is the continuous "there's always a next upgrade to chase" sink (criterion #3) that fills an epoch, so an epoch is a steady income *ramp* rather than one hire then a wait. Levels **reset to 0 when you advance to the next epoch's staffer** (a fresh hire — the big tier jump is the payoff for crossing), and they are **per property**, keeping the cross-property allocation decision alive (§11). Design note: `Plans/Per_Epoch_Upgrade_Track.md`.

> **REDESIGN DIRECTIVE (Tim, 2026-07-03) — staff upgrades become epoch-anchored 20-level blocks.** Playtest surfaced both a bug and a model change:
> - **Bug/feel report:** after crossing from Earth into epoch 2, the hire/upgrade buttons went **disabled with amounts far higher than they showed moments before the transition**. (Consistent with the current design — tier-2 entry hires are anchored to the epoch-2 economy — but it *reads* as broken: the buttons the player was saving toward silently repriced out of reach.)
> - **New model:** (1) **Each staff upgrade's effect is STATIC** — a fixed effect defined once, not a value computed relative to whatever epoch the player is currently in. (2) **Staff upgrades come in blocks of 20 per epoch**, each block belonging to the epoch in which it became available. (3) **A level's cost and effect are anchored to its home epoch** — the epoch where that block unlocked — **not the epoch in which it is eventually purchased.** So unfinished Earth levels stay Earth-priced (and Earth-powered) even after contact, and each new epoch opens a fresh, expensive 20-level block priced to its own economy. This realizes the earlier note (dev-thoughts, June): "you should not be able to afford any staff upgrades at the very beginning of an epoch **unless there were missed upgrades from the previous epoch**."
> - Supersedes the uncapped geometric level track described above; detailed design + open questions in `Plans/Per_Epoch_Upgrade_Track.md` (2026-07-03 addendum).
> - **Decided (Tim, 2026-07-03 follow-up):** "static" means each level's relative impact (multiplier step etc.) is **defined at the moment its block becomes available** and never recomputed; and the blocks form **one sequential ladder** — levels must be bought in order, so a later epoch's block is reachable only after finishing all earlier levels (the missed-upgrade backlog is mandatory catch-up, not optional).
- **Tapping remains strictly additive** (§5, Layer 2) — an automated, alien-staffed empire rewards an active thumb but never demands one.
- **Named staffers in 50s-ad style, re-skinned per epoch.** Earth: the gleaming *ATM Technician*, the *NFT Community Manager*, up to the **Lobbyist** (Legislative Assets) and **Chief of Staff** (Executive Assets) — at that altitude even owning the government is delegated. Each later epoch renames the whole roster in its own flavor (the ATM Technician becomes the Luminari *Photon Teller*, then the Geth *Autonomous Teller Unit*, then the Mycelium *Spore-Cash Node*).

### 6.2 Epochs & First Contact

> **PROPOSED CHANGE (2026-07-01) — epoch income driver moving from staff to the property.** The redesign in §5.5 site 2 makes each **alien property's own base magnitude** (scaling ~30×/tier) the epoch income leap, with the First Contact minigame adding an upside-only bonus. Staff is demoted: no longer the epoch multiplier, kept for hands-off automation only. The staff-tier `staff_income_multiplier` (40^(tier-1)) described below is therefore under review — it double-counts the epoch once the property scales on its own. The per-epoch staff **level-up** track (§6.1) and **retention** (§6.3) keep working but lose their epoch-scaling role. Full §6 rewrite deferred until the new model is feel-/sim-validated. Design of record: `Plans/First_Contact_Property_Reward.md`. **SHIPPED (continuous-ladder rework, 2026-07-12):** exactly this — `staff_income_multiplier` is now FLAT (1.0 every tier); the property ladder's own base magnitude carries every epoch leap, and staff is a modest boost for automation only. See the dated note after the epoch table below.

> **PLAYTEST VERDICT (Tim, 2026-07-03) — early game GOOD; post-Earth epochs TOO FAST; epochs need 3–5 new properties.** First real early-game playthrough with the current build:
> - **Early-game pacing works.** Active play reaches the Earth stall point "relatively quickly," and the first prestige lands as a noticeable improvement — "that is perfect." Treat the current early-game curve as the reference feel; don't re-tune it casually.
> - **Time to the first contact is good, maybe slightly fast.** Acceptable as-is.
> - **Every epoch after that lands WAY too fast.** The accelerating duration law below (each epoch ≈0.75× the last) plus only one new thing to buy makes later epochs collapse into each other. The duration law needs a re-tune (direction: later epochs must hold their own weight, not accelerate into a blur).
> - **DIRECTIVE — each alien epoch should introduce at least 3–5 new properties, not 1.** "Having only a single additional property feels cheap." This supersedes the one-property-per-epoch model in §5.5 site 2 / `Plans/First_Contact_Property_Reward.md`. **Decided (Tim, 2026-07-03 follow-up):** the cohort unlocks are **staged through the epoch** (consistent with how the rest of the ladder reveals), and the First Contact minigame's low/med/high bonus applies to the **whole cohort**, not just the first property. Remaining design: how the 3–5 stagger across the epoch's magnitude band. *(Since resolved — the cohort is spread on an even geometric grid spanning ×16807 per epoch, escalating 6→10 rungs across epochs 2–6; see §5.5 site 2 and the ladder note below, 2026-07-12/15.)*
> - Related staff-upgrade semantics change + epoch-transition cost bug: see §6.1 note.

Earth runs on **one currency — the dollar.** Alien civilizations are *flavor, magnitude bands, and a staff-tier gate*, never a second money type.

- **Epochs are reached within a run by consuming the entire current economy.** Each epoch has a total economic value; Earth's is the existing Earth target (~$103.6T — "buy the Earth", §10). Once a generation has *earned* that whole value, contact with the next civilization fires and the next, orders-of-magnitude-larger epoch opens. The threshold ladder *is* the scale justification: "you ran out of Earth to buy, so the galaxy opens."
- **First Contact is a beat,** not just a number crossing: it names the civilization, its home world and tech, and declares new markets open. Each contact also unlocks the next staffer tier for every property.
  - **Each civilization SPEAKS (shipped 2026-07-08; copy approved).** The 2026-07-07 playtest found the contacts read samey — the narrator lines shared one cadence, so the second contact felt like the first. Every civilization now has a **hail**: its own first words, in a sharply distinct register (the Luminari radiant and faintly condescending; the Geth in machine-log fragments; the Mycelium a creeping lowercase whisper; the Quartzite a cold appraisal; the Chronophage politely quoting your remaining lifespan). The contact card's typewriter types the *hail* — the "INCOMING TRANSMISSION" eyebrow finally delivers an actual transmission — with the narrator's line rewritten as a short deadpan capper after the market-growth payoff. Each civ also carries an **accent color** tinting its name and hail, so contacts differ visually as well as verbally. Real art remains M3; per Tim, the copy is the interim carrier of the moment.
- **v1 epoch ladder** (Earth + 5 alien epochs shipped; more can be added as data rows):

  | Tier | Civilization | Economy vs. Earth | Staffer income ×| Flavor |
  |---|---|---|---|---|
  | 1 | **Earth** | 1× (~$103.6T) | 1× | The honest starting grind; tier 1 just turns on automation. |
  | 2 | **Luminari Collective** (Solaria Prime, *Photons*) | ×16,807 | 1× | Energy/light beings — money now moves at light speed. |
  | 3 | **Geth-Sentinel Grid** (Rannoch-01, *Logic Nodes*) | ×282,475,249 | 1× | Cybernetic collective — finance run entirely by machines. |
  | 4 | **Mycelium Unity** (Spore-Deep, *Spores*) | ×4.75e12 | 1× | Fungal hive-mind — money that literally spreads and self-replicates. |
  | 5 | **Quartzite Conglomerate** (Geode-7, *Prisms*) | ×7.98e16 | 1× | Crystalloid — wealth crystallized, harder than diamond and just as cold. |
  | 6 | **Chronophage Enclave** (Tempus, *Seconds*) | ×1.34e21 | 1× | Time-eaters — they sell you time itself, by the second, at a ruinous markup. |

  Arc: energy → automation → proliferation → crystallization → time, each a different flavor of "the aliens make your money machine inhuman." More civilizations can be added as data rows — `docs/alien_civilizations.md` holds 100.

  **Epoch pacing.** Time to clear an epoch ≈ (dollars to earn) ÷ (income/sec). As shipped: `economy_scale = (7^5)^(tier−1)` — each epoch's earn-to-clear threshold is **×16,807** the last — and `staff_income_multiplier` is **FLAT (1.0 every tier)**. The property cohort's own ~7×/rung base magnitude carries the epoch leap (not a staff-vs-economy exponent race), and the escalating cohorts (**6/7/8/9/10** rungs for epochs 2–6) hold the new-property unlock cadence nearly flat (~3.2–4.0 min median) so it "speeds up every time" without a wall. *Live values in `EpochCatalog.gd`; `sim/UnlockCadence.gd` measures the cadence and the dynasty sim confirms the feel. (History: the earlier v1 `economy 30^ / staff 40^` matched-geometric law is retired — it ballooned staffed old properties and made aliens feel weak, then trivially cheap.)* **Note — what the ladder does NOT govern:** alien-staff *affordability* is ~**1%** of the epoch economy (`earth_target × economy_scale × staff_cost_fraction`, `staff_cost_fraction = 0.01`), a separate knob; and the ladder fixes *pacing only* — the per-epoch upgrade-track / modifier-choice idea in Future Features remains the engagement half.

> **CONTINUOUS LADDER + ESCALATING COHORTS — SHIPPED (2026-07-12 / 2026-07-15).** The table and
> pacing paragraph above now show the live ladder (`EpochCatalog.gd`; the earlier matched-geometric
> `30^/40^` law is retired). The mechanics in full:
> - **Economy scale:** `economy_scale = (7^5)^(tier−1)` — each epoch's earn-to-clear threshold is
>   **×16807** the last (1, 16807, 2.82e8, 4.75e12, 7.98e16, 1.34e21). That matches how far the
>   property magnitudes climb within the epoch (Tim's "each new property is a ~7× jump, like a new
>   property on Earth" model, 2026-07-12), so pacing stays ~flat and you can never trivially buy
>   across epochs.
> - **Staff multiplier:** FLAT — `staff_income_multiplier = 1.0` every tier. The old 40^ ladder
>   ballooned staffed old properties and fought the "ladder carries the leap" intent (it made
>   aliens feel weak, then trivially cheap). The property cohort's own base magnitude is the
>   epoch's income leap (§5.5 site 2); staff is a modest automation boost only.
> - **Unlock cadence:** the escalating cohorts (6/7/8/9/10 rungs for epochs 2–6; cohort size =
>   tier + 4) hold the gap between new-property unlock beats nearly flat (~3.2–4.0 min median)
>   instead of growing 4.4 → 7.1 min — the "speeds up every time" feel now lives in the ladder,
>   not a staff-vs-economy exponent race. `sim/UnlockCadence.gd` measures it.
> - **Scaling beyond epoch 6:** the per-rung ratio is `16807^(1/N)`; cap cohort growth around
>   **~14 rungs (~epoch 10)** — below ~×2 per rung a new property stops feeling like a new
>   magnitude. The content draft `docs/civilizations_v2_draft.json` now covers **26 civs / 326
>   properties** with cohort = min(tier + 4, 14), pending Tim's review.
> - **Save compatibility:** the 15 new properties (2026-07-15) were APPENDED at indices 37–51
>   per the append-only convention, so old saves load unchanged.

### 6.3 Dynasty interaction — staff retention

- **Staff reset on prestige by default.** A new founder starts unstaffed, at the beginning of Earth (§8). Prestige is *how a juiced-up heir punches deeper into the epoch ladder than the last life did* (§5.1).
- **Every staffer is individually retainable via a Legacy upgrade.** Spend Legacy to keep a specific property's staffer at its tier across the reset, so the heir's empire starts pre-staffed exactly where you chose to invest. Buying retention again raises the retained tier. Inherited staff are dynastic infrastructure, front-loading each heir's acceleration. *(This is distinct from the existing "Loyal Staff" Legacy upgrade, which only discounts hire cost.)*
  - **Repriced 2026-07-07 (playtest verdict: the second prestige felt TOO BIG, and retention was the root cause — device-verified fixed).** The old flat pricing had **no property term** — retaining the ATM's staff cost the same as retaining Executive Assets' — and its level growth was so gentle that deep retention was near-free at a ~350-gem prestige. The rule now: **protecting a top earner costs like a top earner.** Cost scales geometrically per property rung *and* per retained level (formula in the Mechanics Spec; all three knobs live in the Balance Tuning screen), so the ATM anchor stays a 1-gem starter buy while willing a top property's staff deep is a genuine multi-prestige dynastic investment. *(Since 2026-07-15 the per-rung exponent is the staff price rank, not the raw ladder index — see §6.1; alien retention prices dropped to coherent values, Earth rows unchanged.)*

### 6.4 Deferred satire — "the quiet ratio"

A future staffer-card stat: one-time hire cost beside lifetime revenue generated — two numbers drifting apart by ten orders of magnitude, no commentary. The labor-vs-capital argument as a stat line. No longer the centerpiece now that staffing is a tiered track; tracked as a polish-phase addition.

### 6.5 Staffer portraits — the layered generator (proposed 2026-07-01, M3)

Every automated property shows a **face** in its portrait circle. There are ~312 role slots — **52 property rungs × 6 epoch tiers** (was "~100 / 17 rungs" when proposed; the ladder grew to 52 with the escalating cohorts, 2026-07-15, which only strengthens the case for generation) — so portraits are generated **procedurally from stacked art layers** rather than hand-authored one by one. A `PortraitGenerator` composites each face from a base/hair/eyes/clothing/accessory stack, picking one variant per layer from a **seed derived from the role** (so a given staffer is stable across redraws, screens, and the run's lifetime), then **bakes it once** to a cached texture (the portrait circle redraws every frame, so per-frame compositing is out). Layers are authored **white and tinted at draw time** — the same trick the icon set already uses — so a few parts and a small palette yield thousands of recognizable faces.

- **Per-epoch part sets.** The six tiers are different *kinds* of being (humans → light-beings → machines → fungal hive-mind → crystalloids → time-eaters, §6.2), so each tier draws from its own part set. Earth uses a full human paper-doll taxonomy; the alien tiers are expected to use a **cheaper, more abstract treatment** (a per-epoch silhouette + procedural accent patterns in that epoch's palette) since aliens don't need human features — this keeps the art bill for tiers 2–6 affordable while still distinct.
- **Override hatch.** `PropertyConfig.manager_portrait`, when set, replaces the generated face — an escape hatch for a hand-authored hero portrait on a flagship role.
- **Distinct from the dynasty heir** (§8.2), who stays portrait-less in v1. Full design + phasing (Earth-slice-first) and the three open decisions (seed basis, alien treatment, scope) live in `Plans/Layered_Staffer_Portrait_Generator.md`.

---

## 7. Offline Earnings — A Purchased Class Privilege

- **Not free.** A new player earns $0 while the app is closed — being broke means income stops when effort stops.
- An early **first-session** unlockable (Property Manager → eventually Family Office) grants offline accrual: the genre's default mechanic becomes a visible threshold — the moment your money starts working without you.
- Cap ladder per §3.2 (base ~4h, extensions cover overnight). Flavor: "your money now works three shifts."
- Reduced efficiency vs. live play (keeps Layers 2–3 meaningful; things run looser when the boss is away).
- **Welcome-back plays it completely straight:** big cheerful number, one deadpan stat — *Hours you worked: 0* — then directly into the spending spree (§3.1).

---

## 8. Death, Inheritance, Estate & Legacy

> **CREDIT & CLASS RETIRED (Tim, 2026-08).** The original concepts of **origins**, **debt & bankruptcy**, and **loan offers** have been permanently removed from the design. Handing the founder early cash flattens the opening climb, which is the most dopamine-rich part of generation one. The **founder starts at $0** and earns the first dollar by hand. Death, inheritance, the Will, estate tax, and the Legacy/Estate Office system (§8.1–§8.3) represent the complete dynastic loop.

### 8.1 Dynasty Identity (added v0.2)

- Each heir receives a **randomly generated inbred-royalty name**: stuffy first names (Bartholomew, Thurston, Wadsworth, Constance, Bitsy) + optional prep-school nickname ("Trip," "Chip," "Bunny," "Skipper") + hyphenated old-money surname (Ashworth-Vanderlyn, Pemberton-Howell). Surname persists per planet (the family brand); first names randomize.
- **The Roman numeral suffix is the prestige counter.** By mid-week you're Wellington Pemberton IX.
- No portraits in v1 — the names are the characters.
- **The Family Ledger:** one screen; each ancestor's name, fortune at death, and a deadpan cause of generation-end ("Retired to Palm Beach").

### 8.2 Death & The Estate — The Obituary Screen (expanded v0.2)

A **short ritual: one screen, two beats, ~30 seconds.**

1. **The Obituary:** name, years, a deadpan life summary assembled from the generation's actual stats — *"Bartholomew 'Chip' Ashworth-Vanderlyn IV, beloved employer of 11, grew the family fortune from $2.1B to $847B. Hours worked: 3."* The headline figure is the generation's **lifetime cash earned** (the never-spent career total that feeds the Legacy conversion — see Future Features "Lifetime cash earned"), not net worth at death.
2. **The Reading of the Will** — the estate math made legible as a document: gross estate → estate tax line (**each purchased loophole visibly shrinking it, in ink**) → net to heir → Legacy conversion. Loophole purchases pay off on this screen, every generation: strategic feedback delivered as ceremony.

Then the heir's name reveals, numeral incremented, into the faster run. All obituaries re-readable in the Family Ledger.

### 8.3 The Loophole Tree

Legislative & Executive Assets unlock estate-tax erosion: raised exemptions, dynasty trusts, stepped-up basis, the charitable foundation that owns the yacht. **All real mechanisms, real names, estate-attorney register.** Strategic spine of the late run: income for *this* lifetime vs. loopholes that pay off for the *next* generation.

### 8.4 Meta-tier upgrades — the second-order prestige track (proposed 2026-07-01)

> **PROPOSED — design note only, first-pass, no values or code.** Raised by Tim 2026-07-01. This deliberately **reopens the §14 / Future-Features decision that there is "exactly one spendable prestige currency"** (resolved 2026-06-14). See the "why this doesn't re-trigger the two-competing-tracks trap" note below; the reopening is intentional and flagged, not an oversight.

Today's Legacy upgrades (§8.4 Estate Office; the `LegacyUpgradeCatalog`) are mostly **compounding, geometric-cost** perks — "effectively endless," but by design each successive level is a smaller *relative* dent against a steeper price, so deep into a dynasty the base shop stalls. The **meta tier** sits *above* that shop: a small set of **standalone order-of-magnitude upgrades** — ×10 / ×100 leaps applied to a whole domain at once (e.g. "×100 to all property income," "×10 to every wage source") rather than another +20%/level line. They are the late-run "the numbers jump a whole order again" beat, matching the absurd scale escalation the epochs already embrace (§6.2, top-epoch economy ~24M× Earth).

- **Gated by epoch / First Contact.** The meta tier scales with the economy band: a given meta upgrade (or its next level) unlocks only once the run has reached the epoch it belongs to. This also gives First Contact a **lasting prestige reward** it currently lacks — today a contact grants a new property type (§5.5) and a staff tier (§6.2), but no persistent currency.
- **A NEW meta-currency, earned separately from Legacy.** Legacy is earned **per death** (within a bloodline); the meta-currency is earned **per epoch / first contact** (across the run). *Different faucets is exactly what keeps the two tracks orthogonal rather than competing:* Legacy = accelerate a bloodline; meta = buy the next order of magnitude as the galaxy opens. Working name **TBD** (see §14 currency-name question — candidates: *Ascendancy*, *Influence*, *Standing*). The one-currency guarantee in Future Features is superseded *for this track only*; Legacy remains the sole *death→Estate-Office* currency.
- **Kept small and legible.** A handful of headline leaps, not a second full catalog — the base Legacy shop stays the broad, textured one; the meta tier is a short list of big, expensive, epoch-gated jumps.

**Open (to pin before building):** the meta-currency's name and earn formula (flat per contact? scaled by epoch economy?); how many meta upgrades and which domains they hit; whether meta upgrades persist across the whole dynasty (they should, being epoch-sourced) or reset; and the interaction with the base-catalog refinement below (§14 open item — some base upgrades merge/retire, some gaps like offline-cap extension get filled).

---

## 9. Rare Events (added v0.2)

> **SHELVED (Tim, 2026-06-22; reaffirmed 2026-07-23).** Parked: not in current scope and not
> to be proactively recommended. On 2026-07-23 Tim reconsidered it and again shelved it — "it
> doesn't sound very interesting right now" — but may revisit if inspiration strikes. The
> design below is kept for reference. Nothing is built.

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

**v1.0 scope:** Earth complete + the Final Dollar / first-contact sequence + **the first 1–2 alien epochs ready** (`EpochCatalog.gd` now defines Earth + 5; epochs are cheap data rows, not unique markets — §6.2).

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
- **Asset bill (Earth):** ~12 property hero illustrations, 6–8 backdrops, ad-styled UI chrome, ceremony screens (obituary/will, Final Dollar set). **Staffer portraits are generated, not drawn one-by-one:** rather than ~312 hand-authored staffer cards (52 rungs × 6 epochs, per the 2026-07-15 escalating ladder), a layered generator composites faces from a small per-epoch part library (§6.5, `Plans/Layered_Staffer_Portrait_Generator.md`) — the Earth human part set is the priority slice.
- **Audio:** chipper exotica/muzak — the hold music of prosperity. (Winds down at the Final Dollar.) **Implemented 2026-08-10** as five era bands — Earth's muzak becoming progressively less of this world as the epochs deepen, the same tune on stranger instruments (`Plans/Audio_System.md` §3.1). Placeholder tracks are in place; the real ones are being sourced.

---

## 13. Development Milestones (added v0.2)

Sequenced as four playable plateaus — each a legitimate stopping point that is fun on its own:

| Milestone | Contents | Exit criterion |
|---|---|---|
| **M1 — The Slice** | Tap wage, buy ladder, cycles/collect, count-milestone speed-ups, bulk-buy UI, income/sec hero stat. Placeholder art. | Dopaminergic on real phone hardware; the return-spike loop verified against a real 3-hour gap |
| **M2 — The Dynasty** | Death, obituary/will screen, estate tax, Legacy (front-loaded), heir name generator, Family Ledger, lifetime-cash estate basis. (Origins, debt, and loans dropped from design). | "Speeds up every time" verified across ≥5 generations. **COMPLETE.** |
| **M3 — The Theme** | Art pass (backdrops, heroes, staffers incl. per-epoch reskins §6.1), ~~audio implementation (exotica/muzak per §12)~~ **DONE 2026-08-10, assets pending**, UI polish, narrator copy pass, epoch-keyed staffing UI & first-contact beat (§6), offline/welcome-back ritual, rare events, the Ledger | The game is *itself* |
| **M4 — The Epoch** | Earth target & percentage display, Final Dollar / first-contact sequence, epoch progression beyond Earth (alien contact, §6.2), balance simulator validation of the full week | Earth captured; first contact made |

Headless balance simulator is built during M1–M2, not after.

### Near-term tasks (app shell & tooling — not milestone-gated)

These are needed soon and run independently of the M-milestone narrative; schedule them
against current work rather than a specific plateau:

- **Start screen** — the app's entry/landing screen. *(BUILT — realized as the welcome /
  welcome-back screen (`WelcomeBackOverlay.gd`). The game ALWAYS opens to this overlay, never
  straight into Main (Tim, 2026-06-24): `show_welcome()` shows a plain welcome when no offline
  pile accrued, `show_pile(...)` shows the offline-return welcome-back when it did. So the app
  always lands on a framed entry beat. Fully exists; may want a polish pass with the M3 art, but
  no longer an open task — Tim, 2026-07-23.)*
- **Settings screen** — player-facing options. *(Now folds into the proposed bottom tab
  bar as the Settings tab — UI Notes §7.)*
- **Balance config screen** — a dev-facing tuning panel that reads/writes the `/config`
  values, so balance can be exercised on-device, not just in the headless simulator.
  *(BUILT; reworked 2026-07-07 as **"Balance Tuning"**: it now lives embedded inside the
  Settings tab — the button swaps it into the tab's slot, Close swaps back — with
  plain-language entry names instead of raw constant names, and the standard phone
  keyboard on value fields.)*
- **Bottom tab bar navigation (proposed 2026-06-22, UI Notes §7).** Four icon-only (SVG)
  bottom-pinned tabs — Property / Estate Planning / Settings / Family Ledger — replacing
  the single stacked Main screen for readability. Realizes the already-designed Estate
  Planning tab (Spec §9.1). Modal beats stay full-screen above the bar.

---

## 14. Open Questions (updated v0.2)

Resolved since v0.1: ~~automation/managers~~ (§6), ~~dynasty identity~~ (§8.2), ~~demo tier~~ (deleted — no monetization), Legacy's primary function (~~#2~~, §5.1: front-loaded early-ladder multipliers + staff persistence; full upgrade catalog still open).

1. **Legacy upgrade catalog.** Beyond early-ladder multipliers and per-staffer retention (§6.3) — full list and costs. *(2026-07-16: a new **Rush** category shipped — Cooling Systems and Rapid Restart, §5.2. 2026-07-14: all upgrade costs now carry the global ×2.0 `legacy_upgrade_cost_multiplier` — prestige Option C.)*
2. **Achievement design.** Bootstrapped, trillionaire-shift, debt-free Earth, etc. Achievements are a satire delivery channel; full pass needed.
3. **Canonical Earth figure.** Confirm $103.6T or choose another ~$100T-class number.
4. **Prestige currency name.** Legacy / Pedigree / Old Money / other.
5. **Sheet1 curves.** Confirm accelerating-multiplier design and tune against §3.2 pacing via the simulator.
6. **Ladder refresh.** Keep NFTs as period artifact or update rungs for 2026?
7. **Loan offer table.** Tiers, terms, cadence (§8.6).
8. ~~**Market Two design.**~~ **Superseded (2026-06-16)** by the epoch model (§6.2): there are no distinct markets — Earth advances through alien-contact epochs on one dollar economy. Remaining epoch open questions live in the Future Features "per-epoch modifier draft" note.
9. **Narrator copy pass.** Voice defined (§1.2); the writing itself is a dedicated effort (obituaries, will lines, staffer cards, event copy, the Letter).
10. **Name generator part-lists.** A fun evening of writing (§8.2).
11. ~~**Sound & haptics design.**~~ **RESOLVED & shipped 2026-08-10** (`Plans/Audio_System.md`, all phases; `main` @ `1bd2511`). Per-event sound mapping is complete: 78 cues across the economy, interface, rush/vent, ceremony, five era music bands, and all six minigames, each with a hook and a default. Haptics are a player-facing slider that scales the tuned pulse durations, with one call site (`Haptics.pulse`). The return-spike delta has its cue (`welcome_back`). **Remaining: the audio ASSETS themselves** — everything shipped is a synthesized placeholder — and the mix pass, which is only meaningful once real samples land. Sounds are found by filename; `game/audio/README.md` is the generated drop sheet.
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
    upgrade). The spectrum bar reads by **fill + color only** (no numeric readout); the SKIP
    button shows what skipping banks. Applied in `DynastyState.perform_succession`; setting
    persisted in `GameState.ui_minigame_enabled`. **Library now 6 types, all three sites wired,
    and a full polish pass shipped (2026-06-29) — see §5.5.** **Still open:** on-device feel-tune
    of the keep floor / bonus magnitudes / round duration **and** every per-type difficulty
    constant touched in the polish pass (plan step 5).

---

## Future Features (parking lot — not scheduled)

Captured ideas for later development. Nothing here is in current scope; each needs its
own design pass before it becomes a milestone.

- **Tutorial / onboarding system (Tim, 2026-07-20).** A guided layer that makes sure every system
  is understood and explained. The game now stacks a lot — the property ladder + milestones, the
  wage / clock-in, the rush → cruise → overdrive vent-check skill game, Frenzy / TURBO, epochs &
  First Contact, prestige + the Estate Office Legacy shop, staffing tiers & retention, the minigame
  library, the Balance Tuning panel — and a new player currently meets all of it at once with no
  explanation. **Open:** format (an interruptive step-by-step walkthrough vs. contextual
  *just-in-time* tips that fire when each system first becomes relevant — first rush, first
  milestone, first First Contact, first prestige); whether it is skippable and replayable; where
  progress persists (its own `user://` file so "already taught" survives prestige, rather than the
  per-generation save); whether it doubles as a **systems glossary / help screen** reachable from
  Settings for later reference; and how the prompts honor the standing low-vision / large-UI rule.
  *Take:* strong fit and probably overdue — the systems have outgrown "figure it out." Recommend
  contextual just-in-time teaching over a front-loaded wall: idle games are learned by doing, the
  systems already unlock gradually (rush before overdrive, epochs before prestige), and a glossary
  in Settings covers the "wait, what did that do?" case without gating the fun.

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
  trap. *(Amended 2026-07-01: the **meta-tier upgrade track (§8.7, proposed)** introduces a
  second, epoch-sourced prestige currency above Legacy. It does not violate the intent here —
  it is earned from a different faucet (per epoch/first contact, not per death), keeping the two
  tracks orthogonal. This decision governs the death→Estate-Office track only.)* Mechanically:
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
  `K_LEGACY` / `ALPHA` once the gross estate changes magnitude (`TBD-SIM`). **Re-tune DONE
  2026-07-14 — "prestige Option C" (the runaway fix):** `alpha_legacy` 0.30 → **0.22** (at 0.30
  the yield compounded ~18× per epoch), `k_legacy` 0.045 → **0.50** (raised to hold the first
  prestige near its old ~350 gems under the flatter exponent — the two move together), plus a new
  global **`legacy_upgrade_cost_multiplier` = 2.0** on every Legacy upgrade's cost as the second
  brake. Targets ~1 epoch per prestige; dynasty income growth tamed from ×237 to ×26.6. All three
  are Balance Tuning knobs. **Implementation is M2-later — recorded here, not scheduled now.**

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
  *(Partial progress 2026-07-03: the core pace pass bumped `r0` 1.07 → 1.09 everywhere —
  chosen from the pace study's candidate table for purchase cadence, not solved against a
  payback target, so this guardrail item remains open.)*

---

## 15. Source Artifacts (project knowledge inventory)

| Artifact | Status | Role |
|---|---|---|
| `AmericanTycoon_PropertyTypeConfig.xlsx` | Sheet2 captured in full (§4); Sheet1 partially captured — **upload original to project** | The economic skeleton |
| `AmericanTycoon_StartingChoicesFlow_Archive.png` | Captured (§8.1) | Opening sequence — preserved near-untouched |
| `DollarSign_Large.png` | Captured | Placeholder art, retired |
| Unity C# scripts | **Not yet reviewed — upload gameplay-logic scripts** (currencies, generators, upgrades, save, timers) | Design-intent mining only |
| GDD v0.1 | Superseded by this document | — |
