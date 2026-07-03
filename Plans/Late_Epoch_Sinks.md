# Late-Epoch Sinks — options for the pre-contact dead zone

**Date:** 2026-07-03
**Status:** OPTIONS SKETCH — for Tim to react to; nothing here is built
**Trigger:** Tim's device report: *"the game starts to stall after all properties are
purchased and most staff upgrades are maxed out."*

## 1. The problem, precisely

Late in an epoch every sink exhausts: all rungs owned, milestones capped at 400,
staff levels at the epoch cap (20 × epoch). From that moment income has
**plateaued**, and the only remaining goal — First Contact — is gated on
*cumulative earnings* reaching the epoch threshold. The tail of every epoch is
therefore a pure linear wait: no decisions, no purchases, nothing to press.

The pace study proved the wall is immune to cost tuning (it's earnings-gated),
and the design makes the wait unavoidable *within a generation*: prestige resets
the epoch climb, so you can't dodge the dead zone and still reach contact.

The contact-progress readout (`feature/contact-progress-readout`) makes the wait
*visible*. This doc is about making it *shorter and interactive*.

## 2. The shape of a correct fix

Any real fix must keep **income growing** through the tail of the epoch. Because
the wall is a fixed earnings target, income growth compounds against it — a sink
that buys +X% income doesn't just give you something to press, it pulls the
contact date closer superlinearly. Sinks that spend cash without touching income
(cosmetics, side-currency) would give busywork but leave the wait length intact.

## 3. Options

### A. Extend milestones past 400
Add thresholds (500 / 750 / 1000 / …) so unit-buying stays alive to the wall.
- **Pro:** zero new systems — the existing buy loop, bands, and ×2 rewards carry it.
- **Con:** breaks the "maxed out at 400" readability the milestone slider is
  built on; every extra band steepens costs (band_step) so late thresholds may
  be unreachable anyway; changes the tuned Earth economy for *all* phases, not
  just the tail.

### B. Raise or soften the staff-level cap
Let levels run past 20×epoch — e.g. an uncapped tail at sharply rising cost, or
a cap tied to milestone progress instead of epoch.
- **Pro:** the staff ladder is already the designed "always a next upgrade" sink;
  purely a knob change.
- **Con:** the +20-levels block is part of the *next contact's reward* — an
  uncapped ladder dilutes what First Contact hands you. Also re-opens the
  cumulative-ladder tuning that just shipped.

### C. A dedicated late-epoch repeatable sink (recommended shape)
A new purchase that only matters once the board is built out — repeatable,
geometric cost, small compounding income bonus. Thematically: **"Market
Expansion"** — lobbying campaigns / trade missions that grow the epoch's economy
you're consuming. Mechanically it's "convert a slice of your pile into +X%
income," i.e. the player actively *accelerates the wall*.
- **Pro:** surgical — touches only the dead zone (early game can't afford it,
  and unit/staff buys dominate until they cap); doesn't disturb milestones,
  staff-cap reward, or the tuned mid-game; gives the tail a real decision
  (spend now vs. bank toward the estate).
- **Con:** a new system (state + save + UI + tuning); interacts with the estate
  waterfall (spending lowers the estate → fewer gems — actually a interesting
  tension, but needs a look so it never feels like a trap).

### D. Signpost prestige at the stall (cheap companion, not a fix)
When sinks are exhausted and contact is still far, make "pass the torch" legible:
the Estate tab already shows projected gems — add a nudge on the property tab
(e.g. the plan button pulses, or shows "+N gems waiting") once the board is maxed.
- **Pro:** the stall is exactly when prestige *should* tempt; near-zero code.
- **Con:** doesn't help the player whose goal is contact this generation — the
  one Tim was being.

### E. Do nothing more — feel-test the readout first
The invisible wall was plausibly most of the pain. With progress now on screen,
the tail becomes "watch the number close in on 100%" — which is how idle games
usually frame it (plus offline accrual doing the waiting).
- **Pro:** free; avoids tuning on top of an unmeasured feeling.
- **Con:** if the tail is genuinely long (it's `remaining ÷ plateau income` —
  worth measuring on device), a progress bar makes it legible, not fun.

## 4. Recommendation

1. **Feel-test with the readout first (E)** — one session. Note how long the
   tail actually is at your plateau income.
2. If it stalls: build **C (Market Expansion)** as the real fix, with **D** as
   the cheap companion. A/B stay off the table unless C proves too heavy —
   they both spend tuning we just settled.

## 5. Open questions for the C design (if we go there)

- Bonus shape: flat +X% per level (additive, like staff levels) is the safe
  choice — compounding over an unbounded sink is the epoch double-count lesson.
- Cost anchor: a fraction of *remaining wall distance* keeps it relevant at any
  scale; a fraction of income/sec is simpler but can go degenerate.
- Reset rule: per-epoch (matches "this epoch's economy") or per-generation?
- Does it show on the property tab (a 13th-style row?) or the Estate tab?
