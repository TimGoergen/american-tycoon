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
| Scope | **Current epoch only.** Not the last-viewed tab. |
| Flagship exclusion | **DROPPED.** Auto-buy may buy anything in the epoch, flagship included. |
| Track count | **Two** — quantity and cadence — plus a **separate unlock purchase**. |
| Unlock grants | **1 unit every 3.0s.** The weakest working version. |
| Cost curve | **Compounder-style steepening** (the accelerating curve the 7 uncapped tracks use). |
| Caps | Quantity **~30 levels**; cadence steps down to a **0.25s floor**. |
| Runaway governance | **Cost curves alone.** No hard throughput ceiling. |
| Head Hunters | **Deleted. Bulk hire becomes free.** |
| Existing owners | **Refunded to spendable Legacy.** |

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

The least-owned term matters more than it looks. Early rungs in a cohort are often priced
identically, and cost-then-index alone would pour every purchase into whichever one happens to
sort first, deepening a single property while its neighbours sat untouched. Preferring the
least-owned spreads the run across the cohort — and because buying raises that property's next
cost, the two rules reinforce rather than fight each other.

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

Both tracks use the compounder curve:

```
cost(n) = base × growth^(n-1) × s^((n-1)(n-2)/2)
```

with `legacy_cost_steepening` s = 1.10, the value already fitted for the compounders. Base and
growth per track are **unset in this plan** — they want the same `sim/DynastyArcStudy.gd`
treatment the compounders got, because a hand-picked pair on a steepening curve is exactly what
that study exists to catch. Deriving them is the first build step (§3.1).

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

### 3.1 Derive the cost curves first
Extend `sim/DynastyArcStudy.gd` to model the two tracks across a dynasty arc and fit `base` and
`growth` for each against the steepening s = 1.10. **Do this before writing UI**, because the
numbers decide whether ~30 levels is a real ladder or an unreachable asymptote — and because
hand-picked values on a steepening curve is precisely the mistake that study caught last time
(1.03 put the summit at generation 3).

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

### 3.4 UI
- Estate: three entries where there were two, grouped so the unlock reads as the gateway.
- Hire-mode buttons: always visible, delete the hidden-until-unlocked exception.
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
2. **Base/growth for both tracks** — deliberately unset pending §3.1.
3. **`ui_epoch_tab` may now be dead.** It was added *for* auto-purchase's tab targeting, which
   this plan removes. Check whether the pager still needs it before deleting; if the pager wants
   it, it stays and simply loses its second consumer.
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
