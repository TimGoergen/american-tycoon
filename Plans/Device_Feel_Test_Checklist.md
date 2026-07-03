# Device Feel-Test Checklist

**Purpose.** A large amount of American Tycoon work has been built, merged, and
documented as *"first-pass / NOT device-feel-tested."* This doc is the standing
agenda for draining that backlog. It exists so a play session on the Pixel has a
concrete list to work through instead of aimless play — and so "does it feel
good?" gets answered on the device, which is the only place it *can* be answered
for an idle/tycoon game.

**How to use it.**
1. Grab the phone, install the latest feature-branch APK from Firebase.
2. Walk the sections below. For each item, give a one-word verdict:
   - **KEEP** — feels right, promote as-is.
   - **TWEAK** — close, note the specific adjustment inline.
   - **REWORK** — the foundation is off, not just the polish.
3. Anything marked TWEAK/REWORK becomes the next feature branch. KEEP items get
   struck through here so the untested pile visibly shrinks.

This is a living doc. When a new first-pass feature merges, add a line here so it
doesn't silently join the untested backlog.

---

## 1. Core loop — the thing that has to feel good first

Everything else is polish on top of this. If any of these are off, fix them
*before* spending another session on cosmetics.

- [ ] **Cycle times across tiers.** The 7–12 stretch to a 180s top cycle was tuned
      income-neutral on paper. On device: does a mid-game cycle feel like a
      satisfying wait, or a dead one? Does the top cycle drag?
- [ ] **Rush / hold-to-rush feel.** Tap to start, hold to auto-rush. Is the hold
      cadence satisfying? Does the cycle bar read as smooth acceleration (the
      easing predictor) or as a stutter?
- [ ] **Solid-bar fast properties.** Once a cycle drops under the threshold the bar
      pins full and the readout switches to `$X / s`. Does a maxed property read as
      "humming," or does the frozen bar read as broken?
- [ ] **Buy-mode + hold-to-buy pacing.** Holding Buy/Hire auto-repeats after a short
      delay so you can watch the cost climb and release. Right speed? Too twitchy?
- [ ] **Concurrent multi-touch** (`d003c45`). Hold rush with one finger while
      tapping Buy/Hire with another. Does it actually work reliably on the Pixel's
      digitizer, or does it drop the second finger?

## 2. Economy pacing — the long arc

- [ ] **Milestone cadence** (25/50/100/200/300/400, ~38% slower economy). Does
      progress feel earned or grindy in the early-to-mid game?
- [ ] **Legacy / prestige payoff.** The retune (`pow .30` gentle power curve) is the
      open trajectory-gap item. Does a *better* run visibly pay off at succession,
      or does prestige feel flat? This is the highest-stakes feel question after the
      core loop.
- [ ] **Staff level-up ROI** (`e7e447d`). Bigger income step, cheaper levels. Does
      leveling a staffer feel like a live, tempting sink, or an afterthought?
- [ ] **Cumulative staff ladder** (`6dcce4c`, 0..20×epoch). Does the single
      persistent track read clearly as continuous progress?

## 3. First Contact / alien epoch

- [ ] **The leap.** Property carries the epoch jump; entry cost is an 8× save-up
      premium. Does the first alien-property purchase feel like a big, deliberate
      moment, or a wall?
- [ ] **Upside-only reward minigame.** No starting units; 3-bucket property bonus.
      Does "upside only" read as a reward, or as confusing (no downside to grasp)?
- [ ] **Alien scale** (30×/tier magnitudes, automation-only staff). Do the numbers
      feel appropriately alien-scale without becoming meaningless?

## 4. Minigames (host + 6 games)

Play each at least twice — once trying to win, once playing badly — and confirm
the score→Legacy mapping *feels* fair in both directions.

- [ ] **Get Ready gate** — does showing goal + stakes up front land, or add friction?
- [ ] **Match-3** — swap/clear/fall animation feel; is "perfect = 200 cleared"
      reachable-but-hard?
- [ ] **Timing bar** — gold-zone lock feel.
- [ ] **Basketball** — the big rework (force-wedge aim, stronger pull, roomier
      board). Does aiming feel good on a touch screen?
- [ ] **Catch money / Balance / Memory** — each feels distinct and fair.
- [ ] **Challenge mode** — endless free play + per-game high scores. Is it a fun
      side-mode or a dead toggle?
- [ ] **Result screen** — spectrum bar (red→gold→green→teal) + Legacy-with-bonus
      readout. Does a bad/skipped result clearly communicate the Legacy *lost*?
      (This is deliberately not upside-only — confirm that reads as intended.)

## 5. UI readability & polish (validate against the large-text/large-target rule)

Lower stakes, but this is where most recent commits live — so confirm they were
worth it. Check on the actual Pixel, at arm's length.

- [ ] **Global UI theme pass** (UiPalette FONT_* scale). Is text comfortably legible
      at a glance for imperfect vision? Any screen still too small?
- [ ] **Bottom tab bar** — 4 icon tabs, pinned hero stat + epoch banner. Reachable
      thumbs? Do the placeholder SVG icons read, or do they need real art?
- [ ] **Property panel** — full-height portrait/rush target, count chip, income-over-
      bar readout (now whole-dollar with a spaced slash). Tap targets big enough?
- [ ] **Themed minigame backdrops + 70% cards.** Legible, or busy?
- [ ] **Estate Planning / Family Ledger embedded tabs** — do the embedded (non-modal)
      screens read cleanly and refresh correctly?

---

## Untested-backlog ledger

One line per first-pass feature awaiting device sign-off. Strike through when
verdicted. (Seed list from project memory as of 2026-07-03 — extend as new work
merges.)

- [ ] Minigame polish pass (host + 6 games, Get Ready gate, themed backdrops)
- [ ] Challenge mode
- [ ] Basketball reworks
- [ ] First Contact "new property type" reward (Phases 1–4)
- [ ] Cumulative staff ladder + staff level-up buff
- [ ] Legacy conversion retune (gentle power curve)
- [ ] Cycle-time rework (tiers 7–12 → 180s)
- [ ] Milestone cadence change (~38% slower economy)
- [ ] Global UI theme pass + bottom tab bar
- [ ] Concurrent multi-touch on property panel
- [ ] Property-panel / income-readout polish (incl. whole-dollar income)
