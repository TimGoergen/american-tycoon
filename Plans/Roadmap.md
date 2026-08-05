# Roadmap — logged future ideas (not scheduled)

A running capture doc for feature ideas Tim wants on the record before they have a plan.
One section per idea: Tim's ask, a short design take, and any load-bearing facts a future
implementer needs. When an idea graduates, it gets its own `Plans/` doc and this entry
points to it.

## 1. "MAX" buy mode for properties, unlocked by a Legacy upgrade (Tim, 2026-07-29)

**Take:** the QoL-as-prestige-reward pattern is exactly Idle Slayer's and fits the shop's
new uncapped structure — but this specific one collides with shipped behavior: **property
buy-MAX already exists, free, and is the DEFAULT buy mode** (`ui_buy_mode` 3 = MAX since
2026-06-23, "a fresh game should start in buy-max" — Tim's own call). Gating it now is a
take-away, not a gift. Options when this graduates: (a) revisit the default (start new
dynasties on ×1 and sell MAX as the upgrade — a real early-game rebalance, not a UI
tweak), or (b) keep MAX free and gate something above it (e.g. "MAX across the whole
tab/epoch in one tap"). Decide deliberately; don't ship the collision.

## 2. "MAX" hire mode for staffers, unlocked by a Legacy upgrade (Tim, 2026-07-29)

**Take:** clean fit, no collisions — staff levels today only have hold-to-repeat
(`hire_hold_*`), so a "buy to cap / buy N levels" mode is genuinely new value, and deep
runs (20-level blocks × 27 epochs) genuinely need it. Natural shape: a utility-family
Legacy track ("Head Hunters"?) whose levels unlock ×10 → block → MAX hire modes.

## 3. "MAX" mode for staffer retention — and maybe all upgrades — via Legacy upgrade (Tim, 2026-07-29)

**Take:** this IS the queued "staff-retention bulk-buy UX" item (Tim, 2026-07-28: "way
too many buttons to press"), upgraded from a UX fix to a prestige reward — better framing,
same work. One caution: retention is bought with the SAME currency (gems) that would buy
the unlock, and it's the endgame's open sink — a MAX button on it needs a spend-preview
("retain everything: 4.2B gems") so one tap can't silently drain a fortune. For "all
upgrades": the uncapped compounders have no MAX by design; a "buy 10 levels" repeat is
the right verb there instead.

## 4. More QoL-via-Legacy candidates (Tim, 2026-07-29 — wants this area explored)

Grounded candidates, each removing friction that exists today (not power — power is the
compounders' job). All fit the utility-track family (capped, additive, restructured 2026-07-28):

- **Auto-restart idle cycles** — unstaffed properties stop after each payout and need
  re-tapping; a capped track that auto-restarts the top N unstaffed properties.
- **Extended offline window** — `offline_cap_seconds` is 4h; levels push it to 8/12/24h.
  (Classic idle-genre Legacy purchase; pairs with the welcome-back minigame.)
- **Deeper ladder peek** — show the next 2/3/4 locked rungs' prices instead of one peek
  rung, for save-up planning in the escalating cohorts.
- **Auto-pop TURBO** — frenzy fires itself at full charge (opt-in toggle once bought);
  respects the "minigames are a player setting" philosophy of choice-not-chore.
- **Epoch-arrival auto-buy** — on contact, automatically buy 1 of each newly-unlocked
  cohort property if affordable (the ownership gate's grunt work, automated).
- **Faster hold-to-repeat rates** — buy/hire hold cadence scaled by a track (the knobs
  already exist per-action in tuning).

## 5. Challenge Mode gated until after the first prestige (Tim, 2026-07-29)

**Take:** good sequencing and cheap to build — it guarantees the minigames are first
experienced in their real context (transitions, with stakes) before free play, and it
matches the progressive-unlock philosophy already shipped (Estate/Ledger tabs). Gate
signal: `dynasty.ancestors.size() > 0` (the Ledger's own "first prestige happened"
signal). Per the no-moving-UI rule, the Settings → CHALLENGES button grays in place with
a "unlocks after your first succession" subtitle, never hides. Small enough to ship in
any session on Tim's word.

## 6. Currency formatting as a player setting (Tim, 2026-07-30)

> **GRADUATED 2026-08-05 → `Plans/Currency_Format_Setting.md`** (branch
> `feature/currency-format-setting`, cut from `main`). All three modes shipped as specified.
> One gap in the capture below had to be resolved: it says "keep today's small-value thresholds
> unchanged" but illustrates with `display_cash()`'s $1M, while `display()` abbreviates from
> $1K. Settled as "a non-default format replaces the abbreviation exactly where an abbreviation
> would have appeared" — so SCIENTIFIC renders $14,300 as `$1.43e4` in the tight formatter.
> The spelled-out-words FOURTH mode noted below is still unbuilt.

Tim's ask: a Settings option to choose how large numbers are formatted. Three modes —
ALPHABET NOTATION (Tim's "all letters": `aa`, `ab`, `ac`, …), the CURRENT abbreviations
(`Qa`, `Sx`, `OcTg`), and a third format (Tim: "something else"; recommendation below).

**Take: good idea, and it gets BETTER the deeper the ladder goes.** The current suffix
ladder (`Money.SUFFIXES`, 40 rungs to 1e120) is mnemonic for maybe ten rungs — `K/M/B/T`
are universal, `Qa/Qi/Sx/Sp` are learnable — and then it degrades. By the deep epochs the
player is reading `Nod`, `QaVg`, `SpTg`, `OcTg`, which carry no intuition at all and,
worse, are hard to ORDER at a glance: is `SxVg` bigger than `QaTg`? (It isn't.) A player
in tier 24 cannot tell whether a price went up or down by reading the suffix. That is a
real legibility problem in the part of the game Tim is actively tuning, and a format
setting is the cheap fix. It also fits the "minigames are a player setting" precedent —
presentation preferences belong to the player.

**Alphabet notation is the mode that earns this feature** (`$4.2aa`, `ab`, `ac`, … `az`,
`ba`, …), the idle-genre standard (AdVenture Capitalist, Cookie Clicker's option). It is
the only format that fixes the ordering problem: `ac` is obviously past `ab`, and it stays
two characters wide forever, so deep-epoch prices become both compact AND sortable by eye.
Map it straight onto the existing rung index so it can never disagree with the other
formats — rung 0 (`K`) = `aa`, rung 1 (`M`) = `ab`, … rung 39 (`NoTg`) = `bn`. Deriving it
from the index rather than a parallel table also means it extends for free if the ladder
ever grows past 1e120.

**Third format: SCIENTIFIC NOTATION — `$4.2e18` (Tim's call, 2026-07-30).** This overrides
the standing "never scientific notation" rule in GDD §2 / Mechanics Spec §Display, which
is now scoped to the DEFAULT rather than absolute: the game still never shows an exponent
unless the player asks for one. Both docs amended 2026-07-30 to say so.

It is a good fit for the third slot on the merits: it is the only format that is exactly
unambiguous at every magnitude with no vocabulary to learn and no ordering puzzle, it is
the shortest of the three at depth, and it is what a numerically-minded player actually
wants for comparing deep-epoch prices. It also sidesteps the "can never disagree on a
suffix" invariant entirely, because it uses no suffix — it just has to be arithmetically
exact.

Recommended specifics:
- **True scientific**, mantissa `1 ≤ m < 10` (`$4.2e18`), not engineering-style. That is
  what the name implies and it is maximally compact. (Engineering style — exponent forced
  to a multiple of 3, mantissa up to 1000 — would map 1:1 onto the existing rungs, which is
  tidy, but it reads as a half-measure and is wider. Noted as the alternative if Tim
  prefers the rung alignment.)
- Lowercase `e`, no `+` on the exponent, no superscript — plain `Label`s can't do
  superscript, and the whole point is compactness.
- 2 decimals in the mantissa with trailing zeros trimmed, reusing `Money.trim()` so it
  matches the other modes' rounding behaviour.
- Keep today's small-value thresholds unchanged: plain dollars below $1,000, comma-grouped
  thousands, and scientific only where the abbreviated range starts ($1M+). A player who
  picks this mode wants it for big numbers, not for `$4.20e2`.
- Negatives keep the existing prefix treatment: `-$4.2e18`.

Rejected for the third slot: **spelled-out words** (`$4.2 quadrillion`) — the teaching mode,
and the natural complement to the other two, but "$4.2 quattuorvigintillion" is 26
characters and cannot fit a property row's price button at this game's font sizes. Logged
here as a possible FOURTH mode if Tim ever wants it, scoped to the roomy readouts only
(cash header, Ledger, Will screen). If it is ever built, the layout question below is the
whole risk.

Rejected: **plain full digits with comma grouping.** Reads beautifully at $1,250,000 and is
unusable by mid-game — the costliest property is 2.243e118, a 119-digit number. It would
obliterate every layout it touched. If Tim wants it anyway it has to be a hybrid that falls
back to abbreviations above a ceiling, which is really "the current format with a higher
full-digits threshold" and belongs as a tweak to `display_cash()`, not a third mode.

**Load-bearing implementation facts:**
- Everything funnels through `Money.gd` — one `SUFFIXES` array plus two formatters,
  `display(max_decimals)` (tight: `$4.2Qa`) and `display_cash()` (spaced, 2dp: `$4.2 Qa`).
  A format mode is a static on `Money` read by both. They deliberately share the rung
  ladder "so the two formats can never disagree on a suffix" — any new mode must preserve
  that property, i.e. derive from the rung INDEX, never from a parallel table.
- **Spelled-out words will break tight layouts, and that is the whole risk of this
  feature.** "$4.2 quattuorvigintillion" is 26 characters. It cannot go in a property
  row's price button at the font sizes this game uses (large text is a locked
  accessibility requirement — Tim is 49 with imperfect vision). Before this ships, decide
  whether word mode applies EVERYWHERE or only to the few roomy readouts (cash header,
  Ledger, Will screen). Recommend: everywhere it fits, and let the tight controls fall
  back to abbreviations — but that is a real decision, not an implementation detail, and
  the no-moving-UI rule means nothing may resize or reflow when the setting changes.
- GDD §2 says "never scientific notation." A player-opt-in `1.23e18` mode is arguably a
  different thing from a default, but it is Tim's call and currently a no.
- Settings → HELP already has a glossary; a format setting wants an entry there, and the
  full 40-rung abbreviation table (every suffix and the number it stands for) is the
  natural content for it.
- The setting is presentation-only: it must never touch save data or any comparison, only
  the display string.

## 7. Auto-property-purchase mode, unlocked by a Legacy upgrade (Tim, 2026-07-31)

Tim's ask: a Legacy upgrade unlocks an AUTO-PURCHASE mode. While the player has it enabled,
the game buys on a cadence — 3s by default, with further upgrades shortening it. Rush is
unavailable while the mode is on. WHAT it buys is the X LEAST expensive properties the player
can afford, in a larger quantity each, **limited to the epoch page currently on screen**
(Tim's final rule, 2026-07-31 — see below).

**Take: the strongest idea in this QoL family, and the rush trade-off is what makes it one.**
Every other entry here (§1-4) removes taps. This one removes the ACTIVITY, which would
normally make it strictly dominant — except that giving up rush is a real price. Rush is the
core active loop and a large multiplier (the sims model an engaged player as rush on the top 3
earners at ~Strong-Arm lv10). So the mode is a genuine choice between hands-off accumulation
and active throughput, not a straight upgrade. That is exactly the shape a QoL reward should
have, and it echoes the "minigames are a player setting" principle: choice, not chore.

Theme fit is clean too — a tycoon delegating purchasing to an acquisitions desk is the
fiction the game is already telling.

### The tension this had to clear (resolved by the buy rule below)

As of 2026-07-31 an alien epoch advances on owning 35 units of its flagship
(Plans/Epoch_Advance_Rework.md), and that stacking phase — measured at 34% of an epoch —
exists specifically so the flagship gets playtime. Any auto-purchase rule that targets
expensive properties automates exactly that grind, and would sell away a pacing feature
shipped the same day.

**The least-expensive rule settles it structurally rather than by tuning:** the mode never
touches the epoch's most expensive property, so the gate is untouched by construction. Recorded
here because it is the constraint any future change to the buy rule has to keep clearing — if
someone later "improves" the mode to buy the best properties, this is what it breaks.

### DECIDED: the X LEAST expensive properties you can afford (Tim, 2026-07-31)

Tim's second revision, and the final rule: **each tick, buy the X least expensive properties
the player can afford**, in a larger quantity per purchase so the mode is worth its cost.
(History: "as many as it can afford" → "X most expensive" → this. Only this one is live.)

**This is the better of the three, and it is what dissolves the tension flagged above.** The
most-expensive rule aimed the automation squarely at the flagship — i.e. at the 35-unit
stacking phase that exists precisely to give the flagship playtime, so the upgrade would have
sold away a pacing feature shipped the same day. Least-expensive inverts that cleanly:

- **It automates the chore and leaves the decision.** The cheap end of a cohort is where the
  tedium lives — many small buys, each individually trivial. The flagship, which is what
  actually advances the epoch, stays a deliberate player purchase.
- **It cannot skip the gate.** The mode never touches the most expensive property, so the
  35-unit requirement is untouched by definition rather than by a tuning value.
- **It still earns real money.** Income is NEUTRAL across a cohort — income/sec per dollar of
  cost is identical at both ends of the ladder — so a dollar auto-spent on the cheapest rung
  earns exactly as much as a dollar spent on the flagship. Cheap does not mean weak here.

**The real trade-off, and it is a good one.** Because income is neutral, cheap and expensive
purchases compound identically — but only flagship units advance the epoch. So a player
running this mode grows income just as fast while advancing more slowly, and has given up rush
on top. That is a genuine strategic posture ("bank income, coast on the era") rather than a
straight power-up, which is exactly what a QoL reward should be.

Recommended specifics:
- **The larger quantity must be a BOUNDED number of units, never MAX.** MAX means "spend all
  cash" by definition, which resurrects the spend-to-zero problem the first rule had and would
  starve the flagship the player is saving for. A fixed N per property per tick keeps the drain
  proportionate — and the drain is naturally small anyway, since a cohort spans 2^13 = 8192×
  from cheapest to flagship, so even a generous N at the low end is a rounding error against
  one flagship unit.
- **Which axis does "larger" scale — breadth (X) or depth (N)?** Tim's wording covers both.
  Recommend making N (units per property) the upgrade axis and keeping X modest: a cohort is
  only 14 properties, so X saturates quickly and stops being a meaningful purchase, whereas N
  keeps mattering. If both become tracks, note that throughput is X × N ÷ cadence — three
  multiplying axes will outrun any of them tuned alone.
- **Re-evaluate affordability after each purchase within a tick.** Buy, deduct, re-check.
  Choosing the whole batch up front against the opening balance would try to buy things the
  earlier purchases just made unaffordable.
- **Rank by CURRENT next-unit cost**, not base cost — that is what "can afford" means, and it
  keeps the ranking honest as `r0` escalation reorders the low end. Note this makes the mode
  self-balancing: hammering the cheapest rung raises its price until another rung becomes the
  cheapest, so it spreads across the low end on its own instead of tunnelling into one row.
- **A newly-arrived epoch is all-cheap.** On contact, 14 unowned properties appear and the mode
  will sweep the bottom of them — which is the roster grunt work of §4's "epoch-arrival
  auto-buy", handled for free. Worth checking the two ideas do not end up duplicating.

The rule still has to be stated plainly in the upgrade's own description — a mode that spends
the player's money on a rule they cannot see reads as a bug.

### Why not the other candidates (Tim asked these be compared, 2026-07-31)

Four rules were considered: most expensive, least expensive, "next most profitable" ($/s
earned per dollar spent), and "whichever you own least of".

**Two of those four are the same rule.** For any property, income/sec per unit is
`base_cost × k(tier)` and the next unit costs `base_cost × r0^n`, so

    marginal $/s per $ spent  =  (base_cost × k) / (base_cost × r0^n)  =  k / r0^n

`base_cost` CANCELS. Within a cohort — where `k` is identical, because income is
income-neutral by construction — "the next most profitable property" is mathematically
identical to "the property you own the fewest units of". They only diverge across tiers (older
epochs have a better `k`, since the decay bands have not eaten it yet) and where staffing or a
milestone doubling has lifted one property's income per unit. Do not implement them as two
different features; they are one.

Interaction with the flagship gate is what separates the rest:

| rule | where the money goes | flagship gate |
|---|---|---|
| most expensive | straight into the flagship | automates the 35-unit tail |
| **least expensive** | bottom of the cohort only | **never touches it, by construction** |
| most profitable ≡ fewest owned | evenly across the cohort by unit count | pushes everything, flagship included, to 35 |

Against "most profitable" specifically, two further strikes:
- **It is not actually optimal.** Milestones at 25/50/100 units grant income DOUBLINGS, so a
  myopic marginal-ratio rule undervalues a property sitting at 24 units. It is neither simple
  nor correct.
- **It is unexplainable.** The honest answer to "why did it buy that one?" involves `r0`
  escalation and decay bands. If this behaviour is ever wanted, ship it as **fewest owned** —
  identical outcome, and it states itself ("keeps your portfolio even").

**A place for it later, if the track needs depth:** make the BUY RULE itself an upgrade axis.
Tier 1 sweeps the cheap end (chores). A much later, much more expensive tier switches to
fewest-owned — balanced portfolio, flagship included — which is openly "automate the whole
game", earned at a point where that is a legitimate prestige reward rather than something that
quietly deletes the pacing shipped alongside it.

### Scope and cadence behaviour (Tim, 2026-07-31)

**The mode operates on ONE civ tab: the last one the player was on.** It buys from that pager
tab's properties, never the whole ladder. While the player is on the property tab, that is
simply the tab in front of them — so purchases happen where they are looking. **It keeps
running when they are elsewhere in the app** (Estate, Ledger, Settings), still against that
last civ tab, and stops only while the economy is FROZEN (Tim, 2026-07-31).

So the guarantee is "never buys on a page other than the one you last chose", not "never buys
while you are not looking". Two consequences:

- **Reuse the existing frozen-economy condition; do not invent a second one.** Full-screen
  beats already freeze the economy (the Will sits behind the minigame scrim precisely so it
  stays frozen). Auto-purchase should ride that exact flag, so a beat can never be undermined by
  purchases ticking away behind it.
- **No "acting on era N" indicator is needed, but the ON/OFF state must be visible.** Purchases
  made while the property tab is up self-evidence — the row is on screen and animating. Ones
  made while the player is in the Estate tab do not, so the player has to at least know the mode
  is running. Cash spent off-tab is harmless in the one case that would matter: Estate spending
  is in GEMS, and prestige payout is computed from lifetime EARNED rather than cash on hand, so
  auto-purchase can never quietly eat a succession the player was planning.

This is the best part of the design, because it hands the allocation decision back to the
player in the most legible possible form: *which page did I last choose*. The mode stops being a hidden
optimiser and becomes a directed tool — point it at an era and it sweeps that era's cheap end.
It also produces a useful emergent control: parking on an early epoch, where everything costs a
rounding error against current wealth, effectively idles the mode without toggling it off.

**When a tick finds nothing affordable on that page, it does not burn the cycle.** It pauses,
fires the instant something becomes affordable, and only then restarts the wait timer. So the
cadence stays a genuine throttle — never more than one purchase per cadence — while the mode
never feels dead during a stretch where the player is poor.

Consequences worth building around:
- **The mode is maximally eager to spend on its page.** A player saving for flagship units
  while sitting on the current epoch will have cash skimmed the moment it clears the cheapest
  rung. That is bounded (a cohort spans 8192× from cheapest to flagship, so the skim is small)
  but it is real, and the answer is page away or toggle off — which only works if the UI makes
  the page-scoping obvious.
- **DECIDED — off-tab behaviour (Tim, 2026-07-31): keep buying.** On the Estate / Ledger /
  Settings tabs the mode continues against the last civ tab; only a frozen economy stops it. The
  alternative (pause whenever no civ page is visible) was rejected: it would make the upgrade
  stop working every time the player opened the shop it was bought from, which reads as broken.
  The state this needs is a persisted "last active civ tab", which the pager already tracks for
  its own navigation.
- Watching for affordability is cheap — compare cash against the minimum next-unit cost among
  that page's properties — so the paused state can be evaluated on the normal logic tick.

### Load-bearing facts for whoever builds it

- **Prior art, with a caveat:** `Sim._greedy_build_out` is the closest existing buyer (buy units
  + staff + hires, spend down each tick) and has run at 10 Hz across every balance study, so the
  purchase plumbing is proven. But do NOT reuse its POLICY: it is global and allocates perfectly,
  where this mode is deliberately page-scoped, cheap-end-only and bounded. Borrow the mechanism,
  not the strategy — reusing the strategy is exactly how this ends up handing the player
  sim-grade allocation, which the buy rule above was chosen to avoid.
- **Cadence:** 3s default with upgrades shortening it. Diminishing returns are steep — below
  roughly a second it is indistinguishable from continuous, so the track wants few levels with
  meaningful steps rather than many small ones. Device cost is modest now that the mode is
  page-scoped: one tick ranks ~14 properties, not the full 326 ladder.
- **Rush lockout is UI work, not just a flag.** Per the no-moving-UI rule the rush affordances
  gray in place, never disappear, and the reason has to be legible ("auto-buy is on") or it
  reads as a bug. `RushMomentumState` heat should presumably idle rather than decay-punish while
  locked out — check `Plans/Rush_Overheat.md` before deciding.
- The mode needs a persistent toggle (it is a player setting, like `ui_buy_mode` /
  `ui_minigame_enabled`, which live in the GameState save dict).
- **Interaction with offline earnings** is unspecified: does auto-buy run while away? Almost
  certainly not (offline is its own banked-pile system), but say so explicitly.

## 8. Challenge Mode shows only games you have met (Tim, 2026-07-31)

Tim's ask: on the CHALLENGES screen, only the minigames the player has actually encountered
are available. Plus a new Balance Tuning option to show ALL games, for testing.

**Take: good, and it completes the thought behind §5.** §5 gates Challenge Mode behind the
first prestige so the minigames are first met in their real context — a transition, with
stakes — before free play. This is the same principle applied per-GAME rather than to the
screen as a whole: a game you have never seen shouldn't be sitting in an arcade menu waiting
to be practised. Together the two turn the CHALLENGES screen into a trophy case of games you
have earned rather than a list handed over up front, and each new one appearing is a small
reward in itself.

The Balance Tuning escape hatch is not a nicety — it is required. With six types dealt at
random, testing one specific game currently means replaying transitions until it comes up.
That is exactly the workflow this gate would make worse, so the override ships with it.

### DECIDED: scoped to the DYNASTY (Tim, 2026-07-31)

Encounters persist for the whole bloodline. Prestige does NOT clear them — **only wiping the
full game save does.** Met is met.

This matches every neighbouring system: challenge records live on the bloodline, and
`DynastyState.best_vent_streak` is explicitly "another dynasty-wide earned record". The
per-generation alternative was rejected because a player who prestiged would lose access to
games they had demonstrably met while their SCORES for those games stayed on screen — a rule
that reads as a bug.

Consequence for storage: the encounter set belongs in the dynasty save dict, beside
`ui_buy_mode` and the challenge records — NOT in `user://minigame_history.json`, which is
deliberately a per-install presentation detail. Wiping the save is what clears it, which falls
out of that placement for free rather than needing its own reset path.

### Load-bearing facts

- **Locked games must still be VISIBLE.** Per the no-moving-UI rule they gray in place with a
  reason ("meet this game at a transition"), never vanish — otherwise the screen silently
  changes shape as the run goes on, which is the exact behaviour that rule forbids. This also
  preserves the trophy-case read: you can see what you have not met yet.
- **Encounter tracking does not exist yet.** The nearest thing is `MinigameScreen`'s
  `user://minigame_history.json`, added 2026-07-31, but that stores only the LAST dealt type
  for the repeat guard. This needs a SET of encountered types, and if scoped to the bloodline
  it belongs in the dynasty save instead, not that file.
- **Key games by `display_name()`.** `ChallengeGoals` deliberately keys everything — ladders,
  arcade scores, the CHALLENGES screen — off the same `display_name()` strings. An encounter
  set must use those same keys or the two will drift.
- **Count the right encounters.** A game met in Challenge Mode itself should probably NOT
  count (that would be circular once the override is on); a game met at a transition should.
  Forced/review rounds are already distinguished in `MinigameScreen.start_game`'s `forced_type`
  path, which is the natural place to tell the two apart.
- **The Balance Tuning toggle** is a display override only — it must not write to the encounter
  set, or testing with it on would permanently unlock everything.
