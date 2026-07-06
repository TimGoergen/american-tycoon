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

- [x] ~~**Cycle times across tiers.**~~ **KEEP (2026-07-06).** The 7–12 stretch to a
      180s top cycle feels right on device.
- [ ] **Rush / hold-to-rush feel.** **TWEAK (2026-07-06).** The finishing-lap fix
      helped, but the bar still clips early under held rush — it's moving too fast to
      follow. Diagnosis: a held rush drives the COMPLETION CADENCE sub-second while the
      nominal cycle stays long, so the bar animates laps it can't finish; the solid-bar
      rule keys on effective cycle length and never notices. Fix candidate: pin the bar
      solid (or equivalent) based on actual wrap cadence, not just cycle length.
- [ ] **Solid-bar fast properties.** Once a cycle drops under the threshold the bar
      pins full and the readout switches to `$X / s`. Does a maxed property read as
      "humming," or does the frozen bar read as broken? *(Not yet tested 2026-07-06 —
      and directly related to the rush TWEAK above: rush-driven completion should
      probably qualify for the same solid treatment.)*
- [x] ~~**Buy-mode + hold-to-buy/hire pacing.**~~ **KEEP both (2026-07-06).** Initial
      delay and repeat speed feel right for Buy and Hire as tuned.
- [ ] **Concurrent multi-touch** (`d003c45`). **TWEAK — scope (2026-07-06).** Works
      where it's wired, but it's limited to certain controls; expectation is that a
      second finger works across ALL same-tab controls (buy mode, TURBO, clock-in,
      etc.), not just rush + Buy/Hire.

## 2. Economy pacing — the long arc

*Status (2026-07-06): touched this pass and feeling good provisionally, but needs a
focused pass to confirm the MID-GAME stretch doesn't drag before any item is verdicted.*

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

*Status (2026-07-06): touched this pass, seems good — same caveat as §2: confirm the
middle doesn't drag on a focused pass before verdicting.*

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

*Status (2026-07-06): touched this pass, seems good provisionally — but see the NEW
performance item at the end of this section before feel-verdicting anything here.*

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
- [ ] **NEW — Minigame screen performance (2026-07-06).** Noticeable lag on the
      minigame screen even after the bubble-trail polyline rework fixed the game tab.
      Investigate what the minigame screen renders per frame (keep-bar GoldBubbles is
      one suspect, but the game tab runs many more bubble bars smoothly — likely
      something screen-specific). Performance blocks feel-verdicts for this section.

## 5. UI readability & polish (validate against the large-text/large-target rule)

Lower stakes, but this is where most recent commits live — so confirm they were
worth it. Check on the actual Pixel, at arm's length.

- [ ] **Global UI theme pass** (UiPalette FONT_* scale). **TWEAK (2026-07-06):** the
      TURBO button text is still too small at arm's length; everything else reads.
- [ ] **Bottom tab bar** — **KEEP layout, wants real icon art (2026-07-06).** Structure,
      size, and reachability are right; the placeholder SVGs are the remaining gap.
- [x] ~~**Property panel**~~ **KEEP (2026-07-06).** Tap targets and readouts confirmed
      good, including after the full-width tab change.
- [ ] **Themed minigame backdrops + 70% cards.** Legible, or busy?
- [x] ~~**Estate Planning / Family Ledger embedded tabs**~~ **KEEP (2026-07-06).**
      Both read cleanly and refresh correctly.
- [ ] **NEW — Carbonation + liquid polish batch (2026-07-06, `feature/addl-ui-polish`).**
      Smooth single-sine sway w/ per-bubble amplitude+lane, trait hash, polyline trails,
      liquid shading, 3× slow-bar speed cap, ladder edge fade (strip-aware), full-width
      tab pages, +30% economy bar, cycle-bar finishing lap. **Verdict on the game tab:
      looks and works great (KEEP-leaning).** Held open for: minigame-screen lag (§4
      NEW item) and the rush-bar TWEAK (§1).

---

## Untested-backlog ledger

One line per first-pass feature awaiting device sign-off. Strike through when
verdicted. (Seed list from project memory as of 2026-07-03 — extend as new work
merges.)

- [ ] Minigame polish pass (host + 6 games, Get Ready gate, themed backdrops) —
      *provisionally good 2026-07-06; blocked on minigame-screen lag (§4 NEW)*
- [ ] Challenge mode
- [ ] Basketball reworks
- [ ] First Contact "new property type" reward (Phases 1–4) — *provisionally good
      2026-07-06; focused mid-game pass pending*
- [ ] Cumulative staff ladder + staff level-up buff
- [ ] Legacy conversion retune (gentle power curve)
- [x] ~~Cycle-time rework (tiers 7–12 → 180s)~~ — KEEP 2026-07-06
- [ ] Milestone cadence change (~38% slower economy) — *provisionally good 2026-07-06;
      focused mid-game pass pending*
- [ ] Global UI theme pass + bottom tab bar — *TWEAK: TURBO button text size; tab bar
      layout KEEP, wants real icon art (2026-07-06)*
- [ ] Concurrent multi-touch on property panel — *TWEAK: expand to all same-tab
      controls (2026-07-06)*
- [x] ~~Property-panel / income-readout polish (incl. whole-dollar income)~~ — KEEP
      2026-07-06
- [ ] Carbonation/liquid polish batch (`feature/addl-ui-polish`, 2026-07-06, not yet
      merged) — *game tab KEEP-leaning; held open on minigame lag + rush-bar TWEAK*
- [ ] Buy/Hire hold pacing — KEEP 2026-07-06 *(kept unstruck only until the tuned
      values are promoted from the Dev Tuning screen into shipped defaults)*
