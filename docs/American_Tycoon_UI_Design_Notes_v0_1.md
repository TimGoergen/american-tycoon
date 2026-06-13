# American Tycoon — UI Design Notes (v0.1)

**Started:** June 13, 2026
**Status:** Living document — capture, not implementation
**Relationship to canon:** This is a working design doc, subordinate to the GDD,
Mechanics Spec, and Art Style Guide. When something here matures into a decision,
it gets promoted into the relevant canon document. Until then, nothing here is a
commitment to build.

**Two-file workflow:** `american_tycoon_dev_thoughts.md` is Tim's **raw scratchpad** —
he writes there freely. *This* file is the **distilled, organized version** that Claude
maintains from that scratch. When Tim adds to the scratchpad, Claude folds the signal
into the right sections here. The scratchpad is the source of intent; this doc is the
curated read.

---

## Why this document exists

We decided (2026-06-13) **not** to start refining the UI yet, because M2 adds whole
new screens (origins/debt, loan offers, will screen, Estate Planning tab) and the
prestige loop reshapes the Main screen's information hierarchy. Pixel-tuning the
layout before those surfaces exist would guarantee rework.

But UI opinions are perishable, and some of them surface *system* requirements we
haven't speced. So this doc is the place to **dump every layout/design opinion now**,
while building systems, and then do **one deliberate UI refinement pass** once the
full screen inventory exists.

The three-step plan this serves:
1. Capture opinions here (ongoing).
2. Build M2 systems; define each new screen's UI *requirements* (what must show, not how it looks).
3. One refinement pass across the whole screen set, once the information architecture is visible all at once.

---

## How to use this doc

- **Dump freely.** Half-formed irritations are welcome — "the wage button feels lost
  at the bottom" is useful signal even without a fix.
- Tag each note with the screen/element it's about so we can sort later.
- If a UI thought implies a system or state value that doesn't exist yet, log it under
  **§5 System requirements surfaced by UI** so it feeds M2 design instead of getting lost.
- Date entries when it helps; opinions are point-in-time.

---

## 1. Current screen inventory

The only screen built today (M1). Listed so we can see what exists vs. what M2 adds.

**Main screen** (portrait), top to bottom:
- Income/sec hero ticket (stamp-pop on purchase) — `HeroStat.gd`
- Frenzy bar — `FrenzyBar.gd`
- Scrolling property ladder, 12 rows (name, owned count, milestone slider, cycle
  progress, buy buttons, hire button) — `PropertyRow.gd`
- Global buy-mode toggle (×1 / ×10 / UPGRADE / MAX)
- Wage button (permanent, bottom) — `WagePanel.gd`
- Welcome-back overlay (offline return) — `WelcomeBackOverlay.gd`

### Screens M2 will add (not built — listed so opinions can anticipate them)
- Origins / debt flow
- Loan offers
- Will screen
- Estate Planning tab
- (Prestige reshapes Main screen hierarchy: Legacy currency + multipliers compete
  for attention with income/sec, the ladder, and the wage button.)

---

## 1a. Branding / logo

- **Main logo (chosen 2026-06-13):** `capitalism_game_logo_v3.png` — vintage circular
  badge, red field, top-hatted tycoon waving from a red convertible whose coin wheels run
  over a fallen worker; "AMERICAN TYCOON" arched top and bottom. Establishes the satirical
  tone and the period-Americana palette.
- Source scratch: `art concepts\capitalism_game_logo_v3.png` (other concepts kept in that
  folder for reference). In-engine copy: `game\art\branding\american_tycoon_logo.png`,
  wired as `config/icon` (editor + window icon).
- **Deferred to art pass:** Android adaptive launcher icon (needs sized / safe-zone /
  transparent variants — current art is a 1024² badge on white) and boot splash / title
  screen use (no title screen exists in M1).

---

## 1b. Design guardrails (cross-cutting rules)

These apply to every screen, not one element. Strong candidates for promotion into the
Art Style Guide.

- **Readability / large UI (accessibility).** Text and elements default to **large** and
  high-readability. Driving reason: Tim is 49 and his vision isn't great. Bias toward
  bigger fonts and controls; treat small/cramped text as a defect, not a style choice.
- **Large, easy-to-tap buttons.** Buttons should be generously sized for thumb tapping.
- **Don't over-commit to vertical.** Portrait makes a stacked vertical layout tempting,
  but sometimes labels + data belong **packed on a single row** to use real estate
  better. Decide per element, not by reflex.

---

## 2. Opinions & issues — by screen / element

> Tim: dump here. Suggested format per note: **[element]** — what bugs you / what it should be / why.

### Main screen — overall layout & hierarchy
-

### Income/sec hero ticket
-

### Frenzy bar
-

### Property ladder / property row
- **Hold START/RUSH to auto-repeat.** Click-and-hold on the start/rush button should
  continually execute the next action (Tim, 2026-06-13). Note: hold-to-rush already exists
  for a *running* cycle (`PropertyRow._pump_held_rush`, rate `hold_rush_per_second`). The
  open gap is holding while *idle* (button shows START) — today the cycle only starts on
  release, so holding an idle property doesn't begin-then-auto-rush. Intended behavior:
  hold START → cycle begins → keeps rushing while held, no re-press.

### Buy-mode toggle & buy buttons
-

### Milestone slider
-

### Wage button  (Tim's term: "clock in" button)
- **Text size** — make the button text ~2× bigger.
- **Progress feedback** — the button background should fill to show progress toward the
  next promotion (the wage-ladder title-up). See §5 — needs promotion-progress state
  exposed to the UI.
- **Color treatment** — the button background is **dark gold**; a **bright gold bar** fills
  that space left-to-right as a progress fill, so the button itself reads as the progress
  meter (no separate bar). Fill fraction = progress toward the next promotion.
- **Hold to auto-clock-in** — holding the button auto-taps the wage at a configurable rate
  (Tim, 2026-06-13). Base rate `wage_hold_taps_per_second`; meant to be **scaled by Legacy
  upgrades** later. Auto-taps fill frenzy at the reduced hold factor (like held property
  rushes — holding is convenient, deliberate tapping stays superior).

### Welcome-back overlay
-

### Anticipated M2 screens (early opinions welcome)
-

---

## 3. Information hierarchy principles

> What deserves the eye, in what order, and what must never get buried. Especially
> important once prestige/Legacy lands and competes with income/sec.

-

---

## 4. Motion & feel language

> Cross-reference: Art Style Guide §9 (stamps, not bounces; cycle spin tied to real
> cycle progress). Log feel notes that refine or extend it.

-

---

## 5. System requirements surfaced by UI thinking

> When a layout opinion implies a state value, signal, or system that doesn't exist
> yet, log it here so it feeds M2 system design instead of getting lost.

- **Wage ("clock in") button promotion progress.** To fill the button background toward
  the next promotion, the UI needs a 0–1 "progress to next title" value from `WageState`.
  Today `WageState` tracks the current title and tap count; verify whether progress-to-
  next-title is derivable (taps accumulated vs. taps/threshold required) and expose it.

---

## 6. Open questions / decisions to make later

-
