# Auto-Purchase Restructure — Plan

**Status:** Planned, not started. Written 2026-08-07 from an interview with Tim.
**Supersedes:** the Acquisitions Desk / Head Hunters shape in
`Plans/Auto_Purchase_And_Bulk_Hire.md` Parts A and B. That doc stays as the record of the
buy-rule reasoning and the rush-lockout argument; **its "Open decisions for Tim" section is
now closed — see §0.1.**
**Branch:** `feature/auto-purchase-and-bulk-hire` (unmerged; this restructures work that
never shipped, so there is no `main` compatibility burden).

---

## 0. Decisions

### 0.1 The four open decisions, now closed

| # | Question | Tim's call (2026-08-07) |
|---|---|---|
| 1 | Rush lockout: heat decays vs idles | **DECAY — keep as shipped.** Auto-buy on simply *is* "the player let go"; the existing spin-down tail handles it, and idling would paint a bonus that isn't being paid. Closes the one item the plan called most worth a device check. |
| 2 | Retention bulk-buy gated or free | **FREE** (already true in code). |
| 3 | Upgrade costs | **Restructured entirely — see §1.** The doc's quoted 12/2.2 and 8/2.4 were already dead; the shipped 5,000 entry is superseded too. |
| 4 | N caps at 8 | **Gone with the restructure.** The N/X pair collapses into one axis (§1.1) with a ~30-level ceiling. |

### 0.2 The restructure

| Decision | Call |
|---|---|
| Buy rule | **Greedy cheapest-first.** Repeatedly buy the single cheapest available next-unit, re-pricing after every purchase. No "distinct property types" concept at all. |
| Scope | ~~Current epoch only~~ → **THE TAB CURRENTLY ON SCREEN** (corrected same day, see below). |
| Flagship exclusion | **DROPPED.** Auto-buy may buy anything in the epoch, flagship included. |
| Track count | **Two** — quantity and cadence — plus a **separate unlock purchase**. |
| Unlock grants | **1 unit every 3.0s.** The weakest working version. |
| Cost curve | **Compounder-style steepening** (the accelerating curve the 7 uncapped tracks use). |
| Caps | Quantity **~30 levels**; cadence steps down to a **0.25s floor**. |
| Runaway governance | **Cost curves alone.** No hard throughput ceiling. |
| Head Hunters | **Deleted. Bulk hire becomes free.** |
| Existing owners | **Refunded to spendable Legacy.** |

### 0.2b Scope was wrong, and shipped wrong (corrected 2026-08-07)

The interview answer "current epoch only" was a miscommunication, caught on device:

> "I think I realize why it looks broken to me, and it's in part because I miscommunicated about
> which team the auto buy should purchase from. Auto buy should always and only purchase
> properties on the currently visible tab."

**Why it read as broken rather than as mis-scoped.** Each epoch's entry rung costs about
**×16,807** the previous one's — that is `economy_scale` by design. Measured: tier 1's cheapest is
$50, tier 2's is $6M, tier 3's is $10.4T. So pinning the desk to the frontier means it can afford
*nothing there* for a long stretch after every First Contact, while the player sits looking at an
era they have plenty of money for. The desk did nothing, said nothing, and looked like a dead
feature.

**The tab is the control.** Paging the ladder IS how the player aims the desk, so the scope follows
what is on screen — Main's live `_epoch_tab`, not `game.ui_epoch_tab` and not the reached epoch.
(`ui_epoch_tab` keeps its job of restoring the pager across a launch, and therefore still decides
where the desk points at startup; `_set_epoch_tab` keeps the two in step. Open item 3 is closed by
this: the field is not dead.)

**A fallback was built and then removed.** Before the clarification arrived, the fix in flight was
"prefer the current epoch, drop to the cheapest thing anywhere unlocked when it is unaffordable."
That is *not* what tab targeting means and it is gone — recorded only so nobody re-derives it as an
improvement. With the tab as the aim, an unaffordable tab is a real answer, and the NOTHING TO BUY
readout (§0.2c) is how the player is told.

### 0.2c The desk says when it is running but broke

Added 2026-08-07 from the same report: a lit AUTO-BUY button with no purchases and no explanation
is indistinguishable from a broken feature. The momentum bar's readout now says **NOTHING TO BUY**
in place of NO RUSH whenever the mode is running and cannot afford the cheapest rung on the visible
tab. That slot normally spends its pixels on the mode's cost — the lit button already says what is
on — but when nothing is happening the urgent question changes.

### 0.3 One premise corrected during the interview

The flagship exclusion was originally justified as protecting epoch pacing. It protects
*less* than that framing implied: **`_create_game` turns `EpochState.auto_advance` off, so
leaving an era is always the MAKE CONTACT tap.** Auto-buy could never have advanced an epoch
on its own; the exclusion only stopped it *satisfying the ownership gate* unattended.

So dropping it converts the 35-unit gate from an **attention** gate into a **money** gate. The
player still chooses when to leave an era. That is the whole consequence — worth stating
plainly because the old code comments oversell what the exclusion was doing.

---

## 1. The new shape

### 1.1 Why two tracks and not three

The interview started at three axes — units per property, number of properties, cadence — and
Tim removed the middle one by changing the rule itself:

> "I do not want to have logic about how many different property types it may attempt to
> purchase from. Rather, I just want the logic to be that it will purchase the x most
> affordable properties ordered by cost, which may cross property type boundaries as the
> prices rise from each subsequent purchase."

Under that rule "how many units of one property" and "how many properties" stop being
separate ideas. There is one number: **how many purchases this tick.** Each purchase takes
whatever is cheapest *at that moment*, and because buying a unit raises that property's next
cost, a run of purchases naturally walks across properties as it goes.

This is strictly simpler than what shipped, and it removes the multiplication warning the
original plan carried ("throughput is X × N ÷ cadence — three multiplying axes will outrun
any of them tuned alone"). Two axes still multiply, but one of them (cadence) has a floor.

### 1.2 The buy rule, precisely

Per tick, repeat `quantity` times:

1. Among every property in the **current epoch** that is unlocked and whose next unit is
   affordable, pick the one with the **lowest next-unit cost**.
2. Buy exactly one unit of it.
3. If nothing is affordable, stop early — a partial fill is correct, and the tick banks no
   credit toward the next one (existing behaviour, `AutoPurchaseTest` covers it).

**Re-price between every purchase**, not once per tick. That is the clause that makes the run
cross properties, and it is the difference between this rule and the old one.

**Ties break cheapest → LEAST OWNED → property index** (Tim, 2026-08-07). Cost first; among
equal costs prefer the property you own fewest of; index only as a final determinism guarantee
so the sims can assert exact outcomes.

~~The least-owned term matters more than it looks. Early rungs in a cohort are often priced
identically…~~ **CORRECTED 2026-08-07 — that justification was wrong.** Measured: every cohort's
rungs sit on a geometric ladder roughly ×7 apart, and no two properties in tiers 1, 3 or 6 share
a price. Ties never arise from shipped data, so the least-owned term never fires. It is kept as
a cheap safety net — two comparisons, a deterministic outcome, and it starts mattering the moment
future content puts two rungs at one price. `AutoPurchaseTest` now asserts that no such pair
exists, so the day one appears the test fails and says the rule has gone live untested.

**What the ×7 spacing means for the rule — measured, and worth a decision.** The cheapest rung
must be bought about 21 times before its price overtakes its neighbour, so a greedy run is
heavily weighted toward the cheap end. Measured on a tier-6 cohort: **30 purchases in one tick
landed on just 2 properties, 21 units of them into the cheapest.**

That is not a bug — it is what "buy the most affordable" means on a geometric ladder — but it is
a different picture from "spreads across the cohort", and it is worth seeing before the UI is
built. If broader coverage is wanted, the lever is a per-property cap per tick, not the
tie-break.

### 1.3 The tracks

| Item | Levels | Effect |
|---|---|---|
| **Auto-Purchase unlock** | 1 | Turns the mode on. Grants quantity 1, cadence 3.0s. |
| **Quantity track** | ~30 | +1 purchase per tick per level (level *n* → *n* + 1 purchases). |
| **Cadence track** | 11 | −0.25s per level, 3.0s → 0.25s floor. |

**Quantity's +1 per level is an assumption, not a Tim decision** — it is the plain reading of
"how many properties it will purchase". At 30 levels that is 31 purchases per tick, and paired
with a 0.25s cadence, 124 purchases/second. That is the runaway Tim accepted; the steepening
cost curve is the only brake. Flag it at the first device pass.

**Cadence is the more dangerous axis** (it divides rather than adds), but it is also the one
with a hard floor, so it self-limits at 11 levels. No per-axis curve differences: Tim chose one
curve shape for both.

### 1.4 Pricing

Unlock stays at **5,000 Legacy**. This resolves an apparent contradiction in the interview —
Tim first said 5,000 was "too cheap for what it does", then "keep 5,000 to unlock, make the
UPGRADES expensive". Both hold, because the unlock now buys far less than it did: 1 unit every
3.0s instead of 3 units every 3.0s. The price is unchanged; the product shrank.

Both tracks use the shared curve, `cost(n) = base × growth^(n-1) × s^((n-1)(n-2)/2) × 3.0`
with s = 1.10.

**FITTED 2026-08-07** by `sim/AutoPurchaseCostStudy.gd` against a real 14-generation playout
(summit at generation 11, lifetime gems 1.3M → 235B):

| Track | base_cost | cost_growth | Level 1 | Depth at summit |
|---|---|---|---|---|
| Quantity | 1666.6667 | **1.6** | 5,000 | 15 of 30 — never maxes |
| Cadence | 1666.6667 | **3.5** | 5,000 | 10–11 of 11 — floor reached exactly at the summit |

Three findings from the fit, all of which changed the answer:

**1. "~30 levels" can never mean 30 reachable levels, and shouldn't.** The steepening term alone
is 1.10^406 ≈ 1e17 by level 30. Every quantity candidate lands at 13–16 regardless of pricing.
That is the compounders' "uncapped on a steepening curve" shape — the nominal cap is decorative
and the curve is the real ceiling, which is exactly what "cost curves alone govern the runaway"
asks for.

**2. For quantity, base and growth are WEAK LEVERS.** A 4× spread in base (833 → 3333) and
growth from 1.6 to 2.2 moves the summit depth only from 13 to 16. Steepening swamps both. So
the choice is close to arbitrary on pacing grounds, and `base 1666.6667 / growth 1.6` was picked
for two non-pacing reasons: it puts level 1 at exactly 5,000, in parity with the unlock, and it
is the deepest of the candidates, which leaves the most room to tune downward later.

**Consequence worth knowing:** most of the climb arrives early. Quantity reaches level 13 by
generation 3 and then gains ~2 more levels across the remaining eight. That is inherent to the
shared curve, not to these numbers. If late generations should keep delivering, the fix is a
per-track steepening override — a code change to `cost_for_level`, currently global — not a
different base or growth.

**3. Cadence needed a completely different scale, and this is where the fit earned its keep.**
It is capped at 11 levels by physics (3.0s → 0.25s in 0.25s steps), and 11 levels is far too few
for steepening to bite. At quantity's numbers the entire ladder totals under a billion and maxes
by **generation 3** — the track would have been decorative. Its climb has to come from growth
instead, hence 3.5 against quantity's 1.6. At that value a dedicated spender reaches the 0.25s
floor on the generation they crack tier 27, and a balanced spender never quite does.

### 1.5 Head Hunters is deleted

Bulk hire (×10, MAX) becomes free for everyone, on the same argument that made retention
bulk-buy free: **pressing hire 150 times is a defect, not a feature, and charging gems to fix a
defect is charging for a bug.**

Two consequences worth having:

- **The no-moving-UI exception disappears.** Both hire-mode buttons were HIDDEN until the
  track was bought — a deliberate, Tim-approved exception. With the modes free they are simply
  always visible, and the exception can be deleted rather than maintained.
- One fewer near-duplicate line in the Estate list.

---

## 2. Migration — there isn't one

**Revised 2026-08-07.** The first draft specified a refund migration. Tim: *"I'm not worried
about it because no one is actually playing this game yet, so just do what is easiest."*

The easiest thing turns out to be **nothing at all**, and it is also the safest — a refund is
the one part of this plan that could fail silently, and not writing it removes that risk
entirely rather than mitigating it.

### 2.1 Why doing nothing is safe (verified, not assumed)

Stale `acquisitions_desk` / `head_hunters` entries will sit in existing saves forever. That is
harmless here, and the reason is specific:

- `LegacyUpgrades.load_save_dict` (`:257-263`) copies **every** saved id into `levels` without
  validating it against the catalog, so unknown ids load without error.
- Nothing ever scans `levels` and resolves the result against `LegacyUpgradeCatalog`. The only
  iteration over that dictionary anywhere in the project is `DynastyState.gd:576-581`, and it
  walks a **hardcoded list of six ids**, not the dictionary's keys. Every other read goes
  through `get_level(SPECIFIC_ID)`.

So a dead id is inert: never read, never summed, never looked up. It costs a few bytes of JSON.

**This is exactly the property to re-check if that ever changes.** A future "total gems
invested" or "list everything owned" feature that iterates `levels` and calls
`get_definition(id)` would crash on these ghosts. If someone writes that, they must filter to
catalog-known ids — which is good practice regardless.

### 2.2 SAVE_VERSION

**No bump.** Nothing is destroyed, rewritten, or minted; the new upgrades are simply new ids
that default to level 0. This matches the currency-format precedent (additive change, no bump)
rather than the v13 utility restructure (which rewrote owned levels and did need one).

### 2.3 Tim's own save

He is out the gems he spent on both old tracks. That needs no code: **the dev panel already has
a grant-Legacy tool** (`DevTuningPanel.grant_legacy_requested`), so topping the test save back
up is a few taps. Writing a refund path to serve one save that has a dev tool for exactly this
would be the wrong trade.

### 2.4 The carry-to-heir list

`DynastyState._carry_player_settings_to_heir` must be checked, not assumed. Auto-purchase's
enabled flag is deliberately NOT carried (it is the one setting that spends). That stays true —
but if the restructure adds any new player-facing setting, it goes in that function **in the
same commit**, per the standing rule that has already bitten three times.

---

## 3. Build order

### 3.1 Derive the cost curves first — DONE 2026-08-07
`sim/AutoPurchaseCostStudy.gd` (new). Phase 1 plays a real dynasty for the gem budget; phase 2
sweeps candidate curves against it instantly. Results and reasoning in §1.4.

Two notes for whoever runs it next:

- It defaults to `USE_RECORDED_ARC = true`, fitting against the arc measured on 2026-08-07 so a
  sweep takes seconds instead of a quarter-hour. **Set it false and re-record after any economy
  retune** — the recorded numbers are a measurement, not a constant.
- Even in recorded mode it still constructs a `DynastyState`, because that is what pushes
  `cost_multiplier` and `cost_steepening` onto `LegacyUpgradeCatalog`. Both are static vars
  defaulting to 1.0, so reading them first would fit every candidate against a FLAT curve — a
  failure that looks entirely plausible in the output.

### 3.2 Core: the new buy rule
Rewrite `AutoPurchaseState.tick` for greedy cheapest-first with re-pricing, scoped to the
current epoch. Delete the breadth parameter and the flagship exclusion.

`sim/AutoPurchaseTest.gd` needs rewriting alongside, not after — three of its five cases assert
rules that no longer exist (flagship exclusion, tab targeting, breadth). Its two survivors
(unaffordable ticks bank nothing; disabled is inert) stay. New cases worth having:
- a run of purchases genuinely crosses properties as prices rise
- the cheapest next-unit is chosen at every step, not just the first
- purchases never leave the current epoch
- partial fill still stops cleanly when money runs out mid-run
- **equal-cost rungs go to the least-owned one**, and identical cost *and* count fall back to
  index — the tie-break is what stops the mode pouring everything into one property (§1.2)

### 3.3 Catalog
Delete the two old upgrade definitions, add the three new ones. No migration, no
`SAVE_VERSION` bump (§2). Worth one test asserting a save containing the dead ids still loads
and plays — cheap, and it pins the "unknown ids are inert" property §2.1 depends on.

### 3.4 UI — DONE 2026-08-07
- Estate: three entries where there were two. **Grouping turned out to be the wrong tool.** The
  step was written as a presentation problem — arrange the list so the unlock reads as the
  gateway — but nothing actually STOPPED a player buying Buying Power or Standing Orders first,
  and `auto_purchase_quantity()` returns 0 while the mode is locked. That was 5,000 gems for no
  effect. So the gateway is real now: definitions may carry a `requires` id, `can_buy` refuses
  anything whose prerequisite is unowned, and a locked card replaces its effect line with
  "Requires Acquisitions Desk" while still showing the price. The field is general, so any future
  dependent upgrade inherits both the gate and the copy.
- Hire-mode buttons: always visible; the hidden-until-unlocked exception is deleted.
- The AUTO-BUY button, its pulse, and the rush lockout are all unchanged.

### 3.5 Device pass
Ship an APK and confirm: bulk hire is free from generation 1, the greedy rule feels like it is
buying sensible things (watch whether the least-owned tie-break visibly spreads purchases
across a cohort), and a maxed-ish build is fun rather than alarming. Grant yourself Legacy from
the dev panel to re-buy the tracks (§2.3).

---

## 4. Open items

1. **Quantity's +1-per-level** (§1.3) is Claude's assumption. Alternatives: +1 early then
   accelerating, or a multiplicative step.
2. ~~**Base/growth for both tracks**~~ — **FITTED 2026-08-07, see §1.4.** Quantity 1666.6667 /
   1.6, cadence 1666.6667 / 3.5.
7. **Per-track steepening.** `cost_for_level` applies one global `cost_steepening` to every
   upgrade. That is why quantity front-loads its climb (level 13 by generation 3, ~2 more across
   the next eight) and why cadence needed growth 3.5 to compensate for having only 11 levels.
   A per-track override would let each ladder set its own shape. Not needed to ship, but it is
   the lever any future "the late levels don't matter" complaint will want.
3. ~~**`ui_epoch_tab` may now be dead.**~~ **CLOSED 2026-08-07** — tab targeting is back (§0.2b),
   so the field keeps both jobs: it restores the pager across a launch, and that restored tab is
   where the desk points at startup.
4. **`Auto_Purchase_And_Bulk_Hire.md` needs a superseded box at the top** pointing here, per the
   doc-rot rule — its Parts A/B describe a shape that will no longer exist.
5. **The "naming trap" assertion loses its home.** `AutoPurchaseTest` currently asserts that
   `get_flagship_index_for_unlock_tier` and `get_property_index_for_unlock_tier` are different
   properties, so a future rename merging the pair breaks a test rather than silently un-gating
   pacing. Dropping the flagship exclusion deletes the only caller that made that assertion
   natural. The collision is still real and still dangerous — the assertion should move to
   `EpochTest`, which reads one of the two lookups, rather than disappear.
6. **Quantity may want a per-tick spend ceiling instead of a count.** Not raised in the
   interview, noted while writing §1.2: at 31 purchases a tick the mode's *cost* varies wildly
   depending on where the cheapest rungs sit, so the same level feels very different early and
   late. A cap expressed as "spend up to X% of cash per tick" would be self-scaling. Mentioned
   only because it is cheap to consider now and expensive to retrofit.
