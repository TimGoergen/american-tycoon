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

### Chunkier UI pass — global Theme + targeted (Tim, 2026-06-21, post-vacation roadmap)

Playing on vacation, Tim wanted the UI **chunkier overall**: larger text, slightly larger
panels, and a deliberate look at button/label sizing and arrangement. **Decision: global
theme + targeted pass.**

- **Centralize sizing in a real Godot `Theme` resource.** Today base sizes are scattered as
  hardcoded constants in scripts — e.g. `PropertyRow.gd` (`BUTTON_ROW_HEIGHT := 80`,
  `BUTTON_LABEL_FONT_SIZE := 34`, name/income 30px, tap button 22px, bar heights 26/18px) and
  `UiPalette.gd` (StyleBoxes built by hand, `set_content_margin_all(10)`). There is **no
  central Theme**. Create one (default font size, default `Button` minimum size, panel content
  margins) so the readability bar above is set in one place, not chased across files.
- **Then a targeted layout pass on the property row** (the densest surface): bump fonts and
  heights, re-examine the `separation` overrides (6/8/10/12px) and bar heights for the larger
  scale, and confirm panels feel a notch roomier.
- **Base sizes (to define in the Theme, `TBD` exact values):** default body font, default
  button min-height, panel content margin. Pin these once and let screens inherit.

---

## 2. Opinions & issues — by screen / element

> Tim: dump here. Suggested format per note: **[element]** — what bugs you / what it should be / why.

### Main screen — overall layout & hierarchy
-

### Income/sec hero ticket
- **Effective income/sec, not just passive (Tim, 2026-06-13).** The headline income/sec
  should reflect what the player is *actually earning right now* across all inputs — active
  rushing (which completes cycles faster), wage taps, frenzy — not only the passive rate.
  Implemented as `GameState.effective_income_per_sec`: an exponential moving average
  (τ≈1.5s) of real cash inflow per tick (property completions + wage taps, frenzy included).
  Rises while active, settles back to passive when idle. This also reconciles the "holding
  rush gives ~10× money" report — the money was correct; the stat just wasn't showing it.
- **Reflect frenzy in the income readout.** When a frenzy is active, the income/sec
  displays (hero ticket + each property row) should show the boosted rate, not the base
  rate (Tim, 2026-06-13). *Interpretation note:* Tim's words were "reflect the changes to
  costs," but frenzy is an income multiplier (Spec §7), not a cost modifier — so this was
  read as "income values." Implemented by multiplying the displayed income/sec by
  `frenzy.get_multiplier()` (1.0 when no burn).
- **All temporarily-boosted values reflect the burn (Tim, 2026-06-13).** Extended to every
  number frenzy actually multiplies: income/sec (hero + rows) AND the wage **"$X / tap"** on
  the clock-in button (wage is paid `wage_per_tap × multiplier`). Values frenzy does NOT
  change stay put by design: buy/hire/tuition **costs** and the **cash balance** (frenzy is
  an income multiplier, not a cost or balance modifier — Spec §7).
- **Frenzy glow (Tim, 2026-06-13).** While a frenzy burn is active, the income ticket
  pulses its background toward red (subtle, ~2.5 Hz, up to 30% tint) to signal the
  accelerated state. Snaps back to plain cream when the burn ends.

### Frenzy bar
- **TURBO button = the meter (Tim, 2026-06-21) — DONE.** The separate frenzy progress bar is
  gone; the frenzy meter is now the **background of the TURBO button** (mustard fill while
  charging, red while burning), with a transparent label button on top — the same "meter as
  button background" pattern the wage clock-in button uses (now shared via
  `UiPalette.style_framed_progress`). The TURBO label is **horizontally centered**.
- **Action row layout (Tim, 2026-06-21) — DONE.** TURBO, DEV, and the buy-mode toggle now share
  **one row**: TURBO takes the **left half** (50%), DEV and buy-mode take **25% each**
  (HBox stretch ratios 2 : 1 : 1). `Main.gd` / `FrenzyBar.gd`.
  - *Watch on the chunkier-UI pass:* at 25% width on a narrow portrait screen the
    "BUY MODE: ×100" caption may clip — revisit font size or shorten the caption then.

### Property ladder / property row
- **Hold START/RUSH to auto-repeat.** Click-and-hold on the start/rush button should
  continually execute the next action (Tim, 2026-06-13). Note: hold-to-rush already exists
  for a *running* cycle (`PropertyRow._pump_held_rush`, rate `hold_rush_per_second`). The
  open gap is holding while *idle* (button shows START) — today the cycle only starts on
  release, so holding an idle property doesn't begin-then-auto-rush. Intended behavior:
  hold START → cycle begins → keeps rushing while held, no re-press.
- **Smooth cycle progress bar.** The per-property cycle progress bar should move smoothly,
  not jerkily (Tim, 2026-06-13). Cause: logic ticks at 10 Hz but the bar renders per frame,
  so the raw value steps ~10×/sec. Fix: ease the displayed value toward the true value each
  frame (`CYCLE_BAR_SMOOTH_SPEED`), snapping on cycle-reset so it refills cleanly.
- **Staffed hire button is faint green (Tim, 2026-06-13).** Once a property is staffed,
  its hire button turns a faint green (`UiPalette.make_staffed_style`) instead of the
  default disabled cream, so automated properties read at a glance.

### Buy-mode toggle & buy buttons
- **Buy / hire split 50/50 (Tim, 2026-06-21) — DONE.** The buy and hire buttons now each take
  half the property panel width. Previously the buy button was twice as wide
  (`size_flags_stretch_ratio = 2.0`); that override was removed so both `SIZE_EXPAND_FILL`
  buttons share equally. `PropertyRow.gd`.
- **Show the next-unit cost when unaffordable (Tim, 2026-06-13).** When the buy button has
  nothing affordable (MAX mode with insufficient cash), show the cost of the next single
  unit instead of a blank "—", so the player sees how close they are. (×1/×10/×100 already
  show their fixed cost and just disable when unaffordable.)
- **Buy-mode persists across sessions (Tim, 2026-06-13).** The selected toggle value is
  saved (`GameState.ui_buy_mode` in the save file) and restored on launch, so it survives
  closing the app. Defaults to ×1 for a fresh game.

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
- **Click impact (Tim, 2026-06-13).** Every wage tap **flashes** the button — a quick
  brighten that decays (`IMPACT_DECAY`). **No size change** (Tim: the button must not
  resize). While held, the same flash fires on each auto-tap pulse, so it visibly beats at
  the income-generation cadence. (The button's styleboxes are transparent so the gold meter
  shows through; this flash is its only press feedback.)

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
