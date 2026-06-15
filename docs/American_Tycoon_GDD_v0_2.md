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

An idle/incremental game about the American Dream of making money. The player purchases income-generating "properties" to buy more income-generating properties, across generations of a wealthy dynasty, until the family has captured **every dollar in circulation on Earth** — at which point the game reveals that Earth was merely the first market, and the dynasty relocates to a larger economy.

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
3. **The Planet (meta-prestige).** A dynasty captures all money in circulation. The game does not end — Earth is stamped *saturated market* and the family relocates to a larger economy. A game about wanting all the money cannot, by definition, end.

**Planets are markets, not sci-fi.** Emerging markets, with onboarding paperwork.

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

**Structural notes:**
- Costs ×11/tier; income ×2; cycles double (0.4s → 34min). Per-property **leveling with income multipliers** required (Sheet1's curves).
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
- **Across generations — front-loaded Legacy.** Prestige bonuses disproportionately multiply the *early ladder*. Each heir tears through tiers the grandfather crawled across; run 1's first hour is run 5's first ninety seconds. Compounding advantage rendered as game-feel — the player experiences the unfairness from the privileged side. Garnish: each generation auto-skips ceremonies it has outgrown (the family office handles paperwork now).
- **Per property — the arc completes in automation.** Crawl → spin → blur → *someone else's problem* (§6).

---

## 6. Staffing & Automation (added v0.2)

AdCap-style per-property hires — the moment **labor itself becomes something you purchase**.

- **One-time hire per property;** once staffed, cycles run and collect automatically, forever.
- Hire costs tuned to land just as manual collection turns from engaging to tedious (tedium-relief dopamine pop).
- Tapping remains strictly additive (§5, Layer 2).
- **Named staffers in 50s ad style:** the gleaming ATM technician, the NFT community manager — up to the **Lobbyist** (Legislative Assets) and **Chief of Staff** (Executive Assets), because at that altitude even owning the government is delegated.
- **The quiet ratio:** each staffer's card shows one-time hire cost beside lifetime revenue generated — two numbers drifting apart by ten orders of magnitude, no commentary. The labor-vs-capital argument as a stat line.
- **Dynasty interaction:** Legacy upgrade — *Loyal Household Staff* — lets staff persist across generations (possibly tiered: junior staff reset, senior staff persist). Inherited servants are dynastic infrastructure, front-loading each heir's acceleration (§5.1).

---

## 7. Offline Earnings — A Purchased Class Privilege

- **Not free.** A new player earns $0 while the app is closed — being broke means income stops when effort stops.
- An early **first-session** unlockable (Property Manager → eventually Family Office) grants offline accrual: the genre's default mechanic becomes a visible threshold — the moment your money starts working without you.
- Cap ladder per §3.2 (base ~4h, extensions cover overnight). Flavor: "your money now works three shifts."
- Reduced efficiency vs. live play (keeps Layers 2–3 meaningful; things run looser when the boss is away).
- **Welcome-back plays it completely straight:** big cheerful number, one deadpan stat — *Hours you worked: 0* — then directly into the spending spree (§3.1).

---

## 8. Origins, Death, Inheritance, Debt

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

1. **The Obituary:** name, years, a deadpan life summary assembled from the generation's actual stats — *"Bartholomew 'Chip' Ashworth-Vanderlyn IV, beloved employer of 11, grew the family fortune from $2.1B to $847B. Hours worked: 3."*
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

**Cadence: roughly once per generation or two** — events function as *dynastic memory* (the Crash of '52 that gutted Bartholomew III's estate). Hard rule: **events hit capital, never the player's verbs.** The tap always works; the purr is preserved; events reprice the world occasionally.

| Event | Effect | The Joke |
|---|---|---|
| **Market Crash** | Capital income halved briefly; wage unaffected | Honest work is crash-proof — and it doesn't matter |
| **The Audit** | Purchased loopholes can be retroactively "examined" — unless you own enough legislators | The loophole tree gets teeth |
| **The Windfall** | A relative you've never heard of dies; unearned money arrives | The narrator congratulates your work ethic |

---

## 10. Win Condition — The Final Dollar (expanded v0.2)

- **Per-planet win:** capture all money in circulation. Earth target ≈ global broad money, ~$100T class (*candidate canonical figure: $103.6T* — confirm). The percentage is watchable throughout.
- **Pacing: ~1 week of rhythmic daily play** to capture Earth. First death inside the first session (~30–45 min); 12–20 generations total, shortening as Legacy compounds.

### 10.1 The Final Dollar Sequence (four beats)

1. **The Parade.** Counter ticks to 100.000000%; the game's biggest celebration — ticker tape, brass band, sash and trophy in peak 50s-Americana. Narrator at maximum sincere wattage: *"Through grit, gumption, and good old-fashioned elbow grease, you've earned every last dollar on Earth!"* No irony anywhere.
2. **The Commemorative Ledger.** An award-certificate stat screen, presented as a high score: *Dollars in circulation: $103.6T. Yours: $103.6T. Everyone else's: $0.00.* The last line sits in celebratory gold leaf, unremarked. The game thinks it's bragging.
3. **The Engine Stops.** Behind the confetti: **income/sec = $0.** No one is left to pay you. Cycles spin and dispense nothing; the muzak winds down like a record losing power. The game never comments — the math tells the truth while the voice celebrates. Total victory and total stagnation are the same state; the player feels the anti-pillar (§0.1) *as the win condition*. (The one beat with editorial teeth — permitted because no *words* break sincerity.)
4. **The Letter.** Into the silence, mail: a cheerful relocation prospectus. *"Earth Market Status: SATURATED. Congratulations! An exciting opportunity awaits the discerning dynasty..."* The next market's bigger number restarts the loop: it gives you someone to take it from. Prestige conversion, new backdrop, the game breathes again.

**v1.0 scope:** Earth complete + the Final Dollar sequence + **1–2 follow-on markets ready** (the planet pipeline must be cheap — §2).

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
| **M3 — The Theme** | Art pass (backdrops, heroes, staffers), narrator copy pass, staffing system, offline/welcome-back ritual, rare events, the Ledger | The game is *itself* |
| **M4 — The Planet** | Earth target & percentage display, Final Dollar sequence, market two via data pipeline, balance simulator validation of the full week | Earth captured; the Letter arrives |

Headless balance simulator is built during M1–M2, not after.

---

## 14. Open Questions (updated v0.2)

Resolved since v0.1: ~~automation/managers~~ (§6), ~~dynasty identity~~ (§8.2), ~~demo tier~~ (deleted — no monetization), Legacy's primary function (~~#2~~, §5.1: front-loaded early-ladder multipliers + staff persistence; full upgrade catalog still open).

1. **Legacy upgrade catalog.** Beyond early-ladder multipliers and Loyal Household Staff — full list and costs.
2. **Achievement design.** Bootstrapped, trillionaire-shift, debt-free Earth, etc. Achievements are a satire delivery channel; full pass needed.
3. **Canonical Earth figure.** Confirm $103.6T or choose another ~$100T-class number.
4. **Prestige currency name.** Legacy / Pedigree / Old Money / other.
5. **Sheet1 curves.** Confirm accelerating-multiplier design and tune against §3.2 pacing via the simulator.
6. **Ladder refresh.** Keep NFTs as period artifact or update rungs for 2026?
7. **Loan offer table.** Tiers, terms, cadence (§8.6).
8. **Market Two design.** Identity, economy size, ladder reskin, modifier (the pipeline's first proof).
9. **Narrator copy pass.** Voice defined (§1.2); the writing itself is a dedicated effort (obituaries, will lines, staffer cards, event copy, the Letter).
10. **Name generator part-lists.** A fun evening of writing (§8.2).
11. **Sound & haptics design.** The return-spike delta (§3.1) needs weight; audio direction set, implementation unspecified.
12. **Frenzy meter tuning.** Layer 3 charge rate, multiplier size, duration.

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

- **Alien-contact epochs instead of distinct markets.** A *possible* alternative to the
  multi-market expansion model (§14 Q8 "Market Two"). Rather than authoring new worlds that
  each need their own properties, names, and art, keep a single Earth economy and advance it
  through *epochs*: each new epoch is Earth being contacted by an alien race, which triggers
  an **order-of-magnitude scale increase** in the economy. The same property ladder and UI
  carry forward — only the scale shifts — which keeps the interface consistent and avoids the
  heavy content cost of unique per-market definitions. This is the proposed mechanism for
  letting numbers climb into absurd ranges (potentially beyond octillion) without rebuilding
  the game each time. Open: how it interacts with the §10 "Final Dollar" win condition and
  the canonical Earth figure (§14 Q3), the per-epoch multiplier and pacing, what (if anything)
  visibly changes besides scale, and the satirical framing of the alien-contact beat. Tension
  to resolve: this competes with §8/§14 Q8's distinct-markets direction — pick one.
  (Tim, 2026-06-14.)

---

## 15. Source Artifacts (project knowledge inventory)

| Artifact | Status | Role |
|---|---|---|
| `AmericanTycoon_PropertyTypeConfig.xlsx` | Sheet2 captured in full (§4); Sheet1 partially captured — **upload original to project** | The economic skeleton |
| `AmericanTycoon_StartingChoicesFlow_Archive.png` | Captured (§8.1) | Opening sequence — preserved near-untouched |
| `DollarSign_Large.png` | Captured | Placeholder art, retired |
| Unity C# scripts | **Not yet reviewed — upload gameplay-logic scripts** (currencies, generators, upgrades, save, timers) | Design-intent mining only |
| GDD v0.1 | Superseded by this document | — |
