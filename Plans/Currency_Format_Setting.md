# Currency Format Setting — Implementation Plan

Graduates **Roadmap §6** (currency formatting as a player setting) into a build.
Branch: `feature/currency-format-setting`, cut from `main`.

Every design decision below is Tim's, recorded in Roadmap §6 on 2026-07-30. This document
adds only the implementation shape and the places where the Roadmap left a gap.

---

## Why now

Tim is device-testing epochs 12–27. That is exactly the range where the current suffix ladder
stops working: `Nod`, `QaVg`, `SpTg`, `OcTg` carry no intuition and — worse — cannot be
*ordered* by eye (is `SxVg` bigger than `QaTg`? No). A player in tier 24 cannot tell whether a
price went up or down by reading the suffix, which is a real problem while judging pacing and
pricing. The setting is the cheap fix, and it is presentation-only, so it cannot destabilise
the balance testing happening on the other branch.

It is also the lowest-conflict work available: `Money.gd` (163 lines) and `HelpScreen.gd` are
both untouched by `feature/auto-purchase-and-bulk-hire`.

---

## The three modes

| mode | example | why it exists |
|---|---|---|
| **ABBREVIATED** (default) | `$4.2 Qa` | today's behaviour; unchanged |
| **ALPHABET** | `$4.2 ab` | the mode that earns the feature — orderable at a glance, two chars forever |
| **SCIENTIFIC** | `$4.2e18` | exact at every magnitude, no vocabulary, shortest at depth |

**ALPHABET is derived from the rung INDEX, never a parallel table.** `Money.SUFFIXES` is ordered
LARGEST first, so the alphabet index is `SUFFIXES.size() - 1 - i`: rung 0 (`K`) = `aa`,
rung 1 (`M`) = `ab`, … rung 39 (`NoTg`) = `bn`. Deriving it this way is load-bearing — the two
existing formatters deliberately share one ladder "so the two formats can never disagree on a
suffix", and a third format must preserve that. It also extends for free if the ladder ever
grows past 1e120.

**SCIENTIFIC specifics** (all Tim's, Roadmap §6): true scientific with mantissa `1 ≤ m < 10`
(not engineering style); lowercase `e`; no `+` on the exponent; no superscript (plain `Label`s
cannot do it, and compactness is the point); 2 decimals in the mantissa with trailing zeros
trimmed via the existing `Money.trim()` so rounding matches the other modes; negatives keep the
existing prefix treatment (`-$4.2e18`).

**This overrides the standing "never scientific notation" rule in GDD §2 / Mechanics Spec
§Display**, which was rescoped to the DEFAULT on 2026-07-30 — the game still never shows an
exponent unless the player asks for one. Both docs were already amended.

---

## REVISED 2026-08-05 after device testing — read this before the section below

Tim tested SCIENTIFIC in the early game and found a buy button reading `5.51e3` beside a cash
header reading `18,610` — two different notation systems on screen at once. The cause was the
threshold rule below: `display()` abbreviates from $1,000 but `display_cash()` only from
$1,000,000, so between those two points one formatter was scientific and the other was
comma-grouped. **His Roadmap §6 note was right and the "each formatter keeps its own
switchover" reading below was wrong.** Three changes followed, all his:

1. **Buttons and other displays must always agree** — "I dislike having materially different
   text that means the same thing." Both formatters now switch notation at the SAME threshold
   in every mode.
2. **Everything abbreviates from $1,000** — `display_cash()`'s comma-grouped thousands range is
   RETIRED, so $18,610 renders `$18.61 K`. This deliberately changes the DEFAULT experience,
   not just the new modes. Below $1,000 is unchanged (exact, with cents in the cash formatter).
   The per-formatter decimal difference (1dp vs 2dp) and the cash formatter's space before the
   suffix are KEPT — those are precision and spacing, not different notation systems.
3. **ALPHABET keeps K / M / B / T and starts lettering at QUADRILLIONS**: 1e15 → `aa`,
   1e18 → `ab`, … 1e120 → `bj`. The letters now begin exactly where the familiar names run out,
   which is the better design — `Qa` onward was always the unreadable part, and nobody needed
   `K` replaced. Implemented as `_ALPHABET_FIRST_RUNG := 4` with the index rule
   `(SUFFIXES.size() - 1 - i) - 4`, lettering only when that is >= 0 and otherwise falling
   through to the real suffix. Still derived from the rung INDEX, never a parallel table.

`Money._group_thousands` was deleted with the comma-grouped branch — it was that branch's only
caller (the other screens carry their own private copies). `MoneyTest` gained a permanent
regression for the reported bug: across the old fault band, in all three modes, `display()` and
`display_cash()` must classify to the same notation system.

## Thresholds — the one gap the Roadmap left (SUPERSEDED — see above)

Roadmap §6 says "keep today's small-value thresholds unchanged", then illustrates with
`display_cash()`'s thresholds ($1M+). But there are **two** formatters with **different**
thresholds, and the note only describes one:

- `display(max_decimals)` — tight (`$4.2Qa`), abbreviates from **$1,000**.
- `display_cash()` — spaced, 2dp (`$4.2 Qa`), abbreviates from **$1,000,000**; below that it
  comma-groups thousands and shows cents under $1,000.

**Resolution: a new mode replaces the abbreviation exactly where an abbreviation would have
appeared, and changes nothing below it.** That is the literal reading of "thresholds
unchanged", it keeps both formatters' small-value behaviour identical across all three modes,
and it means no mode can make a tight row wider than the abbreviated one at the same value.

Consequence worth stating plainly: `display()` in SCIENTIFIC will render `$1.43e4` for $14,300,
because that formatter's abbreviated range starts at $1,000. That is louder than Tim's
"not for `$4.20e2`" instinct, but it follows from the rule he set, and the alternative
(scientific in one formatter and `K` in the other at the same value) would be worse — two
different renderings of the same number on one screen.

---

## Code shape

**`Money.gd` carries the mode as a static**, exactly as `LegacyUpgradeCatalog` carries its
tuning-injected statics:

```gdscript
enum Format { ABBREVIATED, ALPHABET, SCIENTIFIC }
static var format_mode: int = Format.ABBREVIATED
```

Both `display()` and `display_cash()` read it. **No call site changes** — all 37 formatter uses
across `scripts/` funnel through these two functions plus `abbrev()` (which already delegates to
`display()`), so the setting reaches every number on screen for free. That is the whole reason
this feature is cheap.

Add one private helper, `_suffix_for_rung(i) -> String`, so the alphabet mapping exists in
exactly one place, and one `_scientific(v, prefix) -> String`.

**Persistence.** `GameState.ui_currency_format: int = 0` beside `ui_buy_mode`, saved as
`"currency_format"` and read with `data.get("currency_format", 0)` — absent on every existing
save, so it defaults to today's behaviour with no migration and no `SAVE_VERSION` bump. The
value is pushed into `Money.format_mode` on load and on change.

> **NOTE for whoever merges this with `feature/auto-purchase-and-bulk-hire`:** that branch adds
> `ui_hire_mode`, `ui_epoch_tab` and `auto_purchase_enabled` to the same two save blocks, and
> adds `_carry_player_settings_to_heir` in `DynastyState`. This setting belongs in that carry
> list too — it is a pure preference, so it must survive succession like `ui_buy_mode`. Whichever
> branch lands second must add it.

**Setting UI.** A cycling button in `Main._build_settings_tab()` (`Main.gd:1389`), following the
minigame toggle already there — the established precedent for a player setting. Per the
no-moving-UI rule it never hides and never resizes between captions.

**HELP glossary.** `HelpScreen.gd` already has a glossary; Roadmap §6 calls for an entry, and
says the full 40-rung table (every suffix and the number it stands for) is the natural content.
With ALPHABET shipping, that table should show BOTH columns side by side, since it is now also
the alphabet legend.

---

## Explicitly out of scope

**Spelled-out words** (`$4.2 quadrillion`) — rejected as a mode by Tim: 26 characters cannot fit
a property row's price button at this game's font sizes, and large text is a locked
accessibility requirement. Logged in Roadmap §6 as a possible fourth mode scoped to roomy
readouts only.

**Full digits with comma grouping** — rejected: the costliest property is 2.243e118.

---

## Verification

- The mode is **presentation-only**. It must never touch save data (beyond its own preference
  int) or any comparison. A sim assertion should prove the formatters never feed a parse-back
  path — i.e. nothing reads a formatted string.
- Extend `sim/MoneyTest.gd` (permanent tooling — extend, do not add a sibling harness) with,
  per mode: the rung-boundary values, that ALPHABET's index mapping matches the suffix ladder
  rung-for-rung across all 40 rungs, that SCIENTIFIC's mantissa stays in `[1, 10)`, negatives,
  and that all three agree on which RUNG a value falls in (the never-disagree invariant).
- Confirm the small-value paths are byte-identical across the three modes.
- Parse-check every touched script; boot headless.
