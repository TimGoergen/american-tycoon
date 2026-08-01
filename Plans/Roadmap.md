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
the game buys as many properties as it can afford on a cadence — 3s by default, with further
upgrades shortening it. Rush is unavailable while the mode is on.

**Take: the strongest idea in this QoL family, and the rush trade-off is what makes it one.**
Every other entry here (§1-4) removes taps. This one removes the ACTIVITY, which would
normally make it strictly dominant — except that giving up rush is a real price. Rush is the
core active loop and a large multiplier (the sims model an engaged player as rush on the top 3
earners at ~Strong-Arm lv10). So the mode is a genuine choice between hands-off accumulation
and active throughput, not a straight upgrade. That is exactly the shape a QoL reward should
have, and it echoes the "minigames are a player setting" principle: choice, not chore.

Theme fit is clean too — a tycoon delegating purchasing to an acquisitions desk is the
fiction the game is already telling.

### The tension that has to be resolved first

**It automates the epoch tail we just deliberately built.** As of 2026-07-31 an alien epoch
advances on owning 35 units of its flagship (Plans/Epoch_Advance_Rework.md), and that stacking
phase — measured at 34% of an epoch — exists specifically so the flagship gets playtime.
Auto-purchase automates precisely that grind. Left unconstrained, this upgrade deletes the
pacing feature.

That is not automatically wrong: earning the right to automate a grind is the genre's core
progression, and it costs gems and rush to do it. But it is a deliberate decision, not a
detail, and it should be made with the flagship gate in view rather than by accident.

### The open question — what does "as many as it can afford" mean?

Income is NEUTRAL across a cohort (income/sec per dollar of cost is identical), so every
purchase is equally efficient and the optimal play is simply to spend to zero. An auto-buyer
that does that will hold the player's cash at ~0 forever, which means it can never SAVE. It
would starve the very thing the player most wants: the next rung up, and the 35 flagship
units. The mode would actively fight the epoch gate.

Options, in rough order of preference:
- **Priority + reserve (recommended).** Buy in a defined order — recommend most-expensive-first,
  since that is what actually advances the epoch — and never spend below a reserve sized to the
  next thing worth saving for. Keeps the mode useful without letting it hoover cash into cheap
  rungs.
- **Respect the current buy mode.** Auto-buy at ×1/×10/MAX as set. Simple and predictable, but
  MAX (the shipped default) still drains to zero.
- **Flagship-first.** Buy the epoch's flagship exclusively until the gate is met, then spread.
  Most aligned with the new gate, least flexible.

Whatever is chosen, it must be stated in the upgrade's own description — a mode that spends
the player's money on a rule they cannot see will read as a bug.

### Load-bearing facts for whoever builds it

- **Prior art exists and is proven:** `Sim._greedy_build_out` is this exact behaviour (buy
  units + staff + hires, spend down each tick) and has run at 10 Hz across every balance study.
  Start there rather than writing a new buyer. Note it allocates PERFECTLY, so it is a stronger
  buyer than a human — auto-purchase would hand the player sim-grade allocation, which is worth
  sizing before it ships.
- **Cadence:** 3s default with upgrades shortening it. Diminishing returns are steep — below
  roughly a second it is indistinguishable from continuous, so the track wants few levels with
  meaningful steps rather than many small ones. Watch device cost: the ladder is 326 properties
  and each buy touches UI.
- **Rush lockout is UI work, not just a flag.** Per the no-moving-UI rule the rush affordances
  gray in place, never disappear, and the reason has to be legible ("auto-buy is on") or it
  reads as a bug. `RushMomentumState` heat should presumably idle rather than decay-punish while
  locked out — check `Plans/Rush_Overheat.md` before deciding.
- The mode needs a persistent toggle (it is a player setting, like `ui_buy_mode` /
  `ui_minigame_enabled`, which live in the GameState save dict).
- **Interaction with offline earnings** is unspecified: does auto-buy run while away? Almost
  certainly not (offline is its own banked-pile system), but say so explicitly.
