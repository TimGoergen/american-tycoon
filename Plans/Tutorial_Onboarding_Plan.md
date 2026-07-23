# Tutorial / Onboarding — Scoping Plan

**Status:** design plan for Tim's review — nothing built yet. Origin: GDD Future-Features
parking-lot note (Tim, 2026-07-20), promoted to active scoping 2026-07-23.

## 1. The problem

A new player currently meets ~10 systems at once with no explanation: the property ladder +
milestones, wage / clock-in, rush → cruise → overdrive vent-check, Frenzy / TURBO, epochs &
First Contact, prestige + the Estate Office Legacy shop, staffing tiers & retention, the
minigame library, buy-mode, and the Balance Tuning panel. The game has outgrown "figure it
out." Goal: make sure every system is understood **without gating the fun** or slowing the fast
pace Tim wants to keep ([[feedback-at-pace-vs-size]]).

## 2. Format decision — contextual just-in-time, not a front-loaded walkthrough

**Decision (Tim's leaning, confirmed): teach each system the moment it first becomes relevant,
plus an always-available glossary in Settings.** Rationale:
- Idle games are learned by *doing*; a wall of upfront text before the fun is the wrong shape.
- AT's systems already unlock **gradually and in a natural teaching order** — rush before
  overdrive, a full property before staffing, epochs before prestige — so just-in-time tips
  ride an ordering the game already enforces.
- A glossary in Settings covers the "wait, what did that just do?" case for reference, without
  gating anything.

**Two delivery channels, by weight of concept:**
1. **Lightweight coach card** (new, most tips) — a small non-blocking card that appears near the
   relevant control with one or two short sentences + a "GOT IT" dismiss. Does **not** freeze
   the economy (respects the no-friction rule). Fires at most once per concept, ever.
2. **Woven into existing full-screen beats** (no new interruptions) — the big concepts already
   have a full-screen moment on first occurrence, so the teaching copy rides *inside* it rather
   than adding a new pause: First Contact → the epoch system, first succession/will → prestige +
   the Estate Office, first welcome-back → offline earnings.

Everything taught is also recorded in the **Settings → Help / Glossary** for later reference.

## 3. Architecture — three small pieces + one-line hooks

The scout confirmed the core state classes emit almost no signals, but **every player verb flows
through a centralized handler in `Main.gd`** — the clean single place to fire tips. So the build
is small and low-risk:

- **`scripts/core/TutorialProgress.gd`** — a static "already taught" store, modeled 1:1 on the
  existing `ChallengeScores.gd` (`user://challenge_scores.json` → `user://tutorial_progress.json`).
  A `{tip_id: true}` dict with `has_seen(id)` / `mark_seen(id)` (write-on-change, not the autosave
  timer — a kill before autosave must not re-show a tip) and `clear()`. **Prestige-independent**
  by construction (it is NOT in the per-generation `GameState` save that resets on death).
- **`scripts/ui/TutorialTip.gd`** — the coach-card presenter, modeled on `NewVenturesOverlay.gd`
  (the existing once-per-thing nudge) but lighter: a `make_panel_style()` / `make_tab_panel_style()`
  card (NOT the full-screen phone bezel), large text, one dismiss button. A single instance owned
  by Main, shown via `show_tip(id, text)`; ignores the request if `TutorialProgress.has_seen(id)`.
- **`scripts/ui/HelpScreen.gd`** — the Settings glossary, modeled on `AboutScreen.gd` and reached
  via the existing **About-style modal pattern** (a HELP button in the Settings `bottom_buttons`
  VBox → `_help_screen.open()`; self-hides on Back; no visibility bookkeeping).
- **Hooks:** a one-line `_maybe_tip("id", "text")` call added inside the relevant existing Main
  verb handlers (see §4). Two moments lack any hook and need a tiny addition: **milestone
  crossing** (add a signal in `PropertyState._check_milestone`, or poll `get_milestone_band()`
  per row) and **frenzy becoming poppable** (poll `FrenzyState.can_pop()` in `Main._process`).

## 4. The teachable moments

Priority set for v1, with the real hook each fires from. Copy is a **sketch** — final wording is
a narrator-voice copy pass (§8, open).

| # | Concept | Fires from (hook) | Channel | Tip sketch |
|---|---|---|---|---|
| 1 | Buy a property | `_on_buy_requested` (Main ~L1358, on success) | card | "You own a business. It runs a cycle, then pays out. Tap it to collect / restart." |
| 2 | Rush (hold) | `_on_hold_rush_requested` (Main ~L1382) | card | "Hold a property to RUSH — finish cycles faster for a burst of income." |
| 3 | First milestone | `PropertyState._check_milestone` (needs signal) | card | "Milestone! Every 25/50/100… units doubles this property's income." |
| 4 | Buy-mode | `_on_buy_mode_toggled` (Main ~L1880) | card | "Buy ×1 / ×10 / NEXT (to milestone) / MAX — switch how many you purchase at once." |
| 5 | TURBO / Frenzy ready | poll `FrenzyState.can_pop()` in `_process` | card | "TURBO is charged — pop it for a temporary income multiplier." |
| 6 | Overdrive vent window | `RushMomentumState.vent_window_opened` (exists) | card | "Vent window: lift and re-press on the beat to keep Rush Momentum from overheating." |
| 7 | First staff hire | `_on_hire_requested` (Main ~L1407) | card | "Hire a staffer and this property runs itself — even while you're away." |
| 8 | Epochs / First Contact | weave into `FirstContactOverlay.show_contact` first time | beat | (add an epoch-explainer line to the contact beat) |
| 9 | Prestige / Estate Office | weave into first succession/will beat | beat | (explain Legacy earned at death, spent on permanent dynasty upgrades) |
| 10 | Offline / welcome-back | weave into first `WelcomeBackOverlay.show_pile` | beat | (explain staffed properties earned while away) |
| 11 | Staff tiers & retention | `_on_retain_requested` / Estate Office staff section | card | "Retain a staffer through prestige so your heir keeps them." |
| 12 | Minigames | first `MinigameScreen.start_game` | (already a screen) | (a one-line "how to score" header, first play) |

**Deliberately NOT taught:** the Balance Tuning / DEV panel (a developer tool, not player-facing).

## 5. Persistence & lifecycle

- **Store:** `user://tutorial_progress.json`, prestige-independent (survives death, unlike the
  `GameState` generation save). Write-on-change.
- **Dev "Reset Game":** the store should be **cleared** by the dev reset so onboarding can be
  re-tested from scratch — mirroring the `ChallengeScores.clear()` fix already wired at Main
  ~L1495 (that store otherwise survived resets by accident). *(Open: confirm — see §8.)*
- **Skippable:** a Settings toggle **"Show tutorial tips"** (default ON). Off suppresses all
  future tips; the glossary stays available. The very first tip can offer an inline "turn these
  off" affordance.
- **Replayable:** a Settings action **"Replay tutorial"** that calls `TutorialProgress.clear()`,
  so a curious player (or Tim, testing) can see them all again.

## 6. Presentation & readability

- Card uses `UiPalette.make_panel_style()` (cream + navy) or the translucent
  `make_tab_panel_style()`; **not** the full-screen `apply_screen_bezel` / `make_screen_panel_style`
  chrome (those are phone-bezel, full-screen only — there is no existing toast/callout style, so
  the card is the smallest new thing).
- Body `FONT_CARD_BODY` (37) / `FONT_BODY` (32); title via the `make_tab_title` pattern; bold via
  `make_bold_font()`. **Never below `FONT_SMALL` (26)** — the documented readability floor
  ([[feedback-ui-readability]]: Tim, imperfect vision). Dismiss button at `STANDARD_BUTTON_HEIGHT`
  (99) / full-width 96, styled with `style_button()`.
- Honors [[feedback-no-moving-ui]]: the card is an additive transient, not a control that
  hides/reshuffles the existing layout.

## 7. Phased build order

1. **Framework (prove the loop):** `TutorialProgress` store + `TutorialTip` card + the
   "Show tutorial tips" setting + **one** tip end-to-end (#1 buy a property). Headless-verify,
   then a device look at the card's placement/feel before filling in the rest.
2. **Early-game verbs:** tips #2–#7 (rush, milestone, buy-mode, TURBO, vent window, first hire) —
   the systems a new player meets in the first session. (Adds the two small hooks: milestone
   signal + frenzy-poppable poll.)
3. **Woven beats + later systems:** #8–#12 (epochs, prestige, welcome-back, retention, minigames)
   folded into the existing full-screen beats.
4. **Glossary:** `HelpScreen` in Settings + the "Replay tutorial" control + a narrator-voice copy
   pass on all tip text.

Each phase is independently shippable and device-checkable.

## 8. Decisions (resolved by Tim, 2026-07-23)

1. **Card vs pause:** ✅ Lightweight, **easily-dismissed non-blocking cards** for the tips;
   major concepts still woven into the beats that already pause. No hard freeze.
2. **Copy voice:** ✅ Claude drafts all tip copy (narrator voice); Tim tweaks later. Copy lives
   in `scripts/core/TutorialCatalog.gd` so it is reviewable/editable in one place.
3. **Dev reset wipes tutorial progress:** ✅ Yes — `TutorialProgress.clear()` next to the
   `ChallengeScores.clear()` call in the dev reset, so onboarding is re-testable.
4. **v1 scope:** ✅ **All 12** teachable moments in §4 are in v1 — nothing deferred.
5. **Placement:** ✅ Cards are **anchored to the relevant control** (positioned from the target's
   global rect, clamped to the viewport).

Build proceeds by the §7 phases regardless — Phase 1 (framework + one anchored card end-to-end +
the on/off setting) ships first for a device look at the card feel/anchoring before the other 11
hooks are wired, since anchoring is the part most worth validating once before replicating.
