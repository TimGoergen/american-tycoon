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
- **No trailing-zero decimals (Tim, 2026-07-03) — BUILT (feature/ui-polish).** On any screen,
  any currency amount or cycle/rate value shows a decimal place **only when the decimal is
  non-zero** — "$4.50" and "$4.5B" are fine, "$4.0B" and "2.0s" are defects. Enforced by the
  shared public `Money.trim(value, decimals)`; converted call sites: `Money.display_cash`,
  cycle durations (`PropertyRow`), TURBO multipliers (`FrenzyBar`), away-hours
  (`WelcomeBackOverlay`), ×N effect strings (`LegacyUpgradeCatalog`). Exception kept: real
  cents under $1,000 stay two digits ("$5.50"). Pinned by `sim/MoneyTest.gd`.

- **Icon renders must not distort the source canvas (Tim, 2026-07-08).** RichText
  `[img width= height=]` tags FORCE their box — a square-canvas SVG (the legacy gem is
  252×252) squishes if the tag isn't square. Rule: img dims match the canvas aspect;
  `TextureRect`s keep aspect. This is how the gem now renders identically in the Estate
  wallet, the Pass-the-Torch button, the Lifetime Earned line, and the Estate tab icon.
- **Minigame intro labels REQUIRE autowrap (2026-07-08).** A Label without autowrap
  demands its full text width as a MINIMUM and propagates it up the containers — longer
  guidance copy widened the whole card past the screen and put Catch-the-Money coins
  off-screen. Any new in-game text label defaults to `AUTOWRAP_WORD_SMART`.

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
- **Economy progress bar replaces the progress text block (Tim, 2026-07-03) — BUILT
  (feature/ui-polish).** The "42% · $X of $Y" text line is gone. A **green progress bar
  is pinned to the bottom of the income panel**, inside its red frame: a single 12px red
  divider (matching the frame) separates income content from the bar, and the panel's own
  frame closes the other three sides — exactly one line between panel and bar. The panel
  grew by the strip's height so the numerals didn't move; the bar hides on the final
  epoch (no next contact). `HeroStat.gd`.
- **Economy bar: taller + blue theme (Tim, 2026-07-07/08) — BUILT.** Now 54px (26 → 34 →
  54 across two asks), `CYCLE_BLUE` fill with **NEON_BLUE** carbonation (`#4DE8FF`,
  deliberately outside the era palette so the bubbles glow) — visually separating the
  epoch-economy bar from the green property cycle bars.
- **Income headline = the sum of the rows (Tim, 2026-07-07) — BUILT.** The hero panel's
  income/sec is now the simple SUM of the per-second rate each property row currently
  displays — **rush-boosted while rush is held**, frenzy included, unowned buy-previews
  contributing zero — so the panel always equals the rows beneath it and visibly jumps
  during a rush or a TURBO burn. (Each row's own label quotes its effective
  cycle-under-rush rate as "$X / s" while held.) Supersedes the EMA
  `effective_income_per_sec` note above and the later stable-theoretical-rate model;
  the core's theoretical rate still drives the executive wage floor, untouched.

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
- **TURBO readout + buy-mode text matched at FONT_SUBHEAD (Tim, 2026-07-07) — BUILT.**
  Both had been FONT_BUTTON (34) and read small; now 41, deliberately paired (they share
  the action row — resize together).
- **Buy-mode caption shortened (Tim, 2026-07-07) — BUILT.** The button reads
  **"BUY: ×1 / ×10 / NEXT / MAX"** — the word MODE dropped, ×100 replaced by NEXT
  (buys exactly to the next milestone threshold, all-or-nothing), and "NEXT TIER"
  shortened to "NEXT" so the button width stays stable as modes cycle. This resolves
  the caption-clipping watch item above.

### Property ladder / property row
- **Native scrollbar REMOVED — ghost handle instead (Tim, 2026-07-08) — BUILT.** The
  always-visible ladder scrollbar spent horizontal space on a control nobody drags on a
  phone; the rows now take its full width. `GhostScrollBar.gd` overlays a **transient
  handle** — a 16px translucent navy pill (0.6 alpha) hugging the right edge — that
  fades in only while the list is actually scrolling (0.6s hold, 0.4s fade), draws no
  track/background, ignores the mouse (flicking is the interaction), and never appears
  when everything fits on screen.
- **Edge fade at the scroll edges (Tim, 2026-07-06) — BUILT.** Rows dissolve (modulate
  alpha = their visible fraction) as they clip into the viewport's top/bottom — but only
  on an edge with more content beyond it, so a fully-scrolled edge stays solid. Chosen
  over an outline, which would have nested a third frame. Measured from the INNER edge
  of the ScrollEdgeArrows strips, so the fade and the paging strips agree on where the
  visible window starts.
- **Tab pages run full column width (Tim, 2026-07-06) — BUILT.** `wrap_in_tab_panel`
  keeps its 40px float margin on top/bottom only; every tab panel now sits flush with
  the hero stat panel and the tab buttons.
- **Second-finger play works across ALL Property-tab controls (Tim, 2026-07-07) —
  BUILT.** Reusable `SecondaryTapButton` (child of any Button; a secondary press emits
  the Button's own `pressed` signal so both input paths share one handler;
  `is_secondary_held()` feeds hold pumps) on the buy-mode toggle, TURBO, and clock-in
  (tap AND hold) — plus the rows' bespoke rush/buy/hire handler. One app-wide gate
  (`SecondaryTapButton.enabled`). A secondary-finger rush **presents identically** to a
  primary one: saturated green fill, rush-boosted income rate, solid-pin eligibility,
  agitated carbonation.
- **Every owned property is rushable, staffed or not (Tim, 2026-07-03).** The portrait
  disc accepts tap/hold on any owned row. Supersedes the earlier rule (dev-thoughts §
  "staff image as button": automated properties lost rush except the single highest
  owned). Rationale: rush is self-limiting economically — 5% of a short cycle is worth
  nothing, so only long-cycle rows reward the attention — and a disc that looks identical
  but ignores touches read as broken rather than automated. Matches GDD §5 Layer 2
  ("rewards an active thumb but never demands one"). Watch on device: more rush targets
  charge TURBO faster (`frenzy_fill_per_tap` / `frenzy_fill_hold_factor` are the knobs).
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
- **Cycle-rate unit reads "/ s", not "/ 1s" (Tim, 2026-07-03) — FIXED (feature/ui-polish).**
  A cycle of exactly 1.0s fell into the "$X / 1.0s" duration branch; the per-second branch
  now includes 1s cycles (per-cycle == per-second there), so the readout says **" / s"**.
- **First Contact render bug (Tim, 2026-07-03) — FIXED (feature/ui-polish).** The
  civilization name could park too low, behind the line below it: its slide-in animated
  `position.y` inside a VBoxContainer, captured from a layout computed before the new text
  resized the label. Replaced with the same center-pivot scale-pop the headline uses —
  scale never touches container layout, so it can't fight it. `FirstContactOverlay.gd`.
- **Larger, higher-contrast fonts on ALL epoch transition screens (Tim, 2026-07-03) —
  FIRST PASS BUILT (feature/ui-polish).** First Contact: every line stepped up a size
  (eyebrow 32→41, home world/flavor 28→32, narration 32→41, footnote 26→32), and the two
  gold lines ("FIRST CONTACT", "THE MARKET JUST GREW ×N") swapped their gold-on-gold
  outline for a **navy outline** so gold pops off the cream plate; flavor green darkened
  further. On-device eyeball still owed.

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

- **Gold bubble "carbonation" on progress bars (Tim, 2026-07-03; reworked through
  2026-07-08) — BUILT.** Shared `GoldBubbles.gd`, now a full liquid system:
  - **Motion:** each of 24 bubbles swims ONE clean sine (no stacked waves — those read
    as jitter), with its own rate, phase, amplitude, and off-center lane from a
    per-bubble **hash** (a salted-Weyl sequence correlated the traits and the crowd
    rolled as one visible wave). Antialiased draws, or sub-pixel drift steps.
  - **Trails:** each bubble drags a comet tail — ONE `draw_polyline_colors` per bubble
    with per-point alpha (ghost circles cost a draw call each and lagged the app).
  - **Liquid shading:** the filled region darkens at its top/bottom edges and brightens
    at the center line — light through a tube of liquid (4 gradient bands).
  - **Governed speed ladder (Tim, 2026-07-07):** carbonation speed is a ranked signal —
    a solid bar under held rush is the fastest liquid on screen (176 px/s), a solid bar
    second (110), every measured bar below both (capped 80), idle floor 14.
  - **Excitement knob (0–1, work item 5, first-pass — device pass owed):** rush-held
    rows agitate the liquid — +50% crowd, floor rises to 40 and the measured cap to 100
    (still under the solid speeds), sway rates up to +45%, and a small churn wobble
    that exists ONLY in proportion to excitement (calm bars keep the clean path).
  - **TURBO meter:** half the crowd while charging (full read as busy on gold); the full
    crowd flowing **right-to-left** while burning — the drain's direction.
  **PLACEMENT RULE (Tim, 2026-07-05): carbonation cues AUTOMATIC activity** — a value
  accruing on its own — never a response to the player's own events. Carries it:
  property cycle bars, the economy bar, the TURBO meter, and the minigame spectrum bar.
  Does NOT: the wage clock-in meter (moves only because the player taps) and
  in-minigame gameplay bars (play must read clean).

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

---

## 7. Navigation — bottom tab bar (FIRST CUT BUILT 2026-06-22)

> **Built:** a custom bottom tab bar (four equal icon `Button`s, `Main._build_tab_bar`)
> over a shared content slot (`_tab_content`); `_show_tab` toggles which panel is visible
> and refreshes ledger/settings on entry. Hero stat + epoch banner are **pinned above**
> the tabs; **tabs don't freeze the economy** (only modal overlays do). Tabs: **Property**
> (`_build_property_tab` — action row + ladder + wage), **Estate Planning**
> (`_build_estate_tab` — Plan the Estate + Estate Office, which still opens the shop modal),
> **Settings** (`_build_settings_tab` — minigame toggle + DEV), **Family Ledger**
> (`FamilyLedgerScreen` refactored from overlay → embedded content). Placeholder SVG icons
> in `game/art/icons/`. **Still to do:** real icon art; embed the live draft will in the
> Estate tab; possibly embed the Estate Office shop rather than open it modally; on-device
> layout pass. (Original proposal below.)

> **Addendum (2026-07-07/08):**
> - **Estate tab icon = the legacy gem** (`legacy_gem.svg`, Tim's own art) — the same
>   image as the wallet/torch/lifetime renders, so the tab's identity matches what
>   lives inside it. It's the one tab icon that DOWNSCALES (252px art → 113px slot), so
>   it takes the mipmapped filter; the other three tabs still carry placeholder glyphs
>   (real art owed).
> - **Balance Tuning lives INSIDE the Settings tab** (was a full-screen overlay): the
>   BALANCE TUNING button swaps the tab's normal page for the panel, CLOSE swaps back.
>   Retitled "Balance Tuning" to match its button; rows read in plain language
>   (`capitalize()` + hand-picked DISPLAY_NAMES: Starting Cash, Rush Percent, Legacy
>   Payout Scale, Legacy Payout Curve); value fields clear the overlaid scrollbar and
>   raise the STANDARD phone keyboard (the numeric pad has no arrow keys). The economy
>   no longer freezes while tuning is open — Apply saves and reloads anyway.

Replace the single stacked Main screen with a **bottom tab bar** (pinned to the screen
bottom, thumb-reachable) switching between four tabs. Reason: more real estate per screen
and far better readability — each surface does one job instead of cramming the ladder,
prestige buttons, and the Estate Office onto one scroll. Fits §1b (large, thumb-friendly)
and the §11 "clean face" UX. **This also realizes the already-designed "Estate Planning
tab" (Mechanics Spec §9.1 / §14).**

**The four tabs:**
1. **Property** — the income engine: hero income/cash stat, TURBO/frenzy, the property
   ladder, the wage button. The default/home tab.
2. **Estate Planning** — the live draft will (Spec §9.1) + "Plan the Estate" prestige
   action + the Estate Office (Legacy upgrade shop). Consolidates today's PLAN THE ESTATE
   and THE ESTATE OFFICE buttons.
3. **Settings** — finally a real home for player options: the minigame opt-out (today only
   a checkbox on the minigame screen), and later audio/haptics toggles, dev-panel access,
   etc. (Settings was previously deferred to M3 / §13 near-term — the tab bar gives it a
   place now.)
4. **Family Ledger** — the ancestor history (today a button → overlay).

**Presentation:**
- **Icons, not words** — each tab is an **intuitive SVG symbol** (e.g. building/ladder for
  Property, a will/quill or estate gate for Estate Planning, a gear for Settings, a
  family-tree/book for Family Ledger). Icons must be large and legible (§1b); placeholder
  glyphs until the art pass. SVG so they scale crisply.
- Pinned to the bottom; the active tab is clearly indicated (fill/underline/color).

**Open questions (resolve when we build it):**
- **Persistent chrome vs. per-tab:** does the income/sec hero stat (and the wage button)
  stay always-visible across all tabs, or live only on the Property tab? (Leaning: hero
  stat persistent on top — it's the heartbeat; wage button likely Property-only.)
- **How the existing full-screen overlays fit:** Will ceremony, First Contact, Welcome
  Back, and the minigame are *modal beats* that should still take over the whole screen
  (above the tab bar), not become tabs. The tab bar is for the persistent surfaces.
- **Icon set / source** — commission vs. an open icon set; must read at a glance.
- **Does the dev panel get a Settings entry** (vs. the current DEV button on Property)?
- Tab bar height + icon size against §1b; reserve space so it never overlaps content.

**Implementation note (surfaced for §5):** this is a real restructure of `Main.gd`'s
`_build_ui` (today one stacked column). A `TabContainer` (Godot built-in, tabs can be
bottom-aligned and icon-only) or a custom bottom bar + swapped content panels. The four
content areas already exist as scenes/overlays; the work is hosting them in tabs and
moving the prestige/ledger buttons into their tabs.

## 8. Minigame screen & Minigame Tuning (polish pass + visual treatment, BUILT 2026-06-29)

The shared minigame host (`MinigameScreen`) and the Minigame Tuning review screen
(`MinigameReviewScreen`, Settings) got a deliberate polish pass — plan
`Plans/Minigame_Polish_Pass.md`. As-built:

- **Themed backdrop.** Both screens float over a full-bleed casino/library image
  (`art/backgrounds/minigame_background.png`) inside the standard black bezel, its corners
  CPU-rounded to the screen frame (a plain TextureRect, not clip_children — only one clip stencil
  works at a time and Main owns it) so the bright bottom-corner art doesn't square off.
- **Translucent, smaller card — matched across both screens.** The minigame card fill is **70%
  cream** and the card is **20% shorter, 10% narrower**, so the backdrop reads around and through
  it. The **Minigame Tuning list now sits on a card of the SAME size, shape, and 70% cream as the
  Get Ready panel** (it no longer uses the old full-screen plate).
- **Timer as focal point.** Large, centered, faux-bold; pulses amber under 10s and blinks gold +
  scales under 3s. A **"⏸" cue** appears while a game pauses the clock mid-animation.
- **Spectrum bar = fill + color only (no numbers).** It glides (smoothed), with an edge-cap that
  brightens into the bonus band and a flash the instant it first reaches "full". The numeric
  "what you'd keep" readout was removed; legibility of the floor moves to the **SKIP button**,
  which now reads "SKIP · keep N …".
- **Get Ready gate states the goal + stakes up front.** Before the clock starts, the gate now
  shows the game's name, its one-line **goal** (`Minigame.how_to_play()`, also reused as each
  game's in-round intro so they can't diverge), and the universal **win/lose stakes** ("play well
  to keep more — a bonus on top; a weak round or Skip keeps only the minimum"). Previously the
  player only learned the goal once play began (Tim, 2026-06-29).
- **Reveal & transitions.** The result reveal blooms (fade + scale + color); the Begin gate fades
  off to unmask the game (the clock only starts after the fade).
- **Per-type juice & difficulty direction.** Each of the six types got its own juice and a locked
  difficulty *direction* (Timing Bar / Catch Money harder; Match Three / Memory / Balance made
  clearer; Basketball held). All difficulty constants are **first-pass — on-device re-tune owed**
  (use Settings → Minigame Tuning to preview each type).
- **Challenge Mode toggle (2026-06-30).** A large toggle on the Tuning list switches every game
  launch between Minigame Mode (default) and **Challenge Mode** — endless free play, no timer, no
  win/loss, per-game high scores saved across sessions. The toggle turns red when Challenge is
  active; the subtitle changes; each game button shows "Best: N". In a Challenge round the reward
  chrome (timer/spectrum/skip/opt-out) is swapped for a big live **Score** + **Best**, and DONE
  ends the run and saves the high score.
- **Basketball board (2026-06-30).** Generous margin around the board, a **thick black rounded
  outline**, and a gym backdrop (`art/backgrounds/basketball_court.png`) inside the rounded
  corners. The aim guide is a **force wedge** — point at the ball, fanning out toward the shot
  direction, size + a single blue→purple→red color scaling with pull force (red = maxed).

### Addendum (2026-07-07/08): framing, performance, and the Balance rework

- **Get Ready gate gains a WHY line (work item 3).** A muted-navy framing sentence under
  GET READY explains each round's place in the story, carried by the reward context:
  succession — *"The will is read. Before the fortune passes, the heir must show the
  estate what kind of tycoon they are."*; welcome-back — *"The empire earned this while
  you were away. One bold move before it banks."*; First Contact — *"Across the table: a
  civilization that has never seen a human make a deal…"*. Hidden in Challenge Mode and
  the review tuner. Every `how_to_play()` line also grew from a fragment into real
  guidance (match-3 now explains the AVOID gem in words; no exact numbers — tunable).
  Tim (2026-07-08): good shape; the art pass defines the true content.
- **Minigame-screen performance, root-caused (2026-07-06→08).** Three layered fixes:
  (1) economy-freezing modals now HIDE the covered game screen (it kept drawing at 60fps
  beneath the opaque overlay — the game tab's bubble bars billed their GPU cost to the
  minigame); (2) per-frame hot-path cleanups (a StyleBoxFlat allocated in basketball's
  draw pass, `filter()`/`duplicate()` array rebuilds, theme-override churn); (3) the
  backdrop bakes (minigame screen + basketball board) key their caches on **±1px
  tolerance**, not float equality — sub-pixel layout jitter across an integer boundary
  re-ran the full CPU image bake every frame — and cache their decompressed source
  images. Basketball also **substeps its physics** (≤24px of ball travel per collision
  pass) so a fast ball can never tunnel through the rim posts at any framerate.
- **Balance the Books REWORKED (work item 6, first-pass — device verdict owed).**
  Vertical, single-input, Stardew-fishing-shaped: HOLD anywhere to lift the marker,
  release and gravity drops it, keep it inside the gold zone drifting up and down the
  track; soft bounce at floor/ceiling punishes slamming an edge. Scoring unchanged
  (banked time-in-zone vs the fixed round; Challenge score = seconds in zone). Kept from
  the old game: wandering-zone easing, boundary warning glow, in-zone bounce, motion
  trail. Replaces the horizontal two-button version, which "didn't work and lagged"
  (Tim, 2026-07-07).
