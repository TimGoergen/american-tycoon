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
- [x] ~~**Rush / hold-to-rush feel.**~~ **KEEP (2026-07-07).** Landed on a deterministic
      solid rule: not rushing = solid under a 0.25s effective cycle; rush held = solid
      when the COMPUTED cycle-under-rush time is under 0.4s, entering via a quick
      sprint-to-full instead of a snap. Tim: "feels much better." Solid bars carry the
      briskest carbonation (faster under rush) as the "it's working" signal.
- [x] ~~**Solid-bar fast properties.**~~ **KEEP (2026-07-07).** A pinned bar reads as
      humming, not broken — helped by the week's additions: the brisk solid-bar
      carbonation (briskest on screen, faster under rush) and the sprint-to-full pin
      transition. The `$X / s` readout carries the rate.
- [x] ~~**Buy-mode + hold-to-buy/hire pacing.**~~ **KEEP both (2026-07-06).** Initial
      delay and repeat speed feel right for Buy and Hire as tuned.
- [x] ~~**Concurrent multi-touch.**~~ **KEEP (2026-07-07).** Scope expanded via the
      reusable SecondaryTapButton node: second finger now works on buy-mode, TURBO,
      and clock-in (tap + hold) as well as the rows' rush/Buy/Hire. Device-verified.

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
- [x] ~~**Minigame screen performance (2026-07-06).**~~ **FIXED, device-verified
      (Tim, 2026-07-07: "totally fixed").** Root cause: the whole game screen kept
      drawing at 60fps beneath the opaque modal (economy-freezing modals now hide the
      covered layers), plus per-frame hot-path cleanups in basketball/catch/timing-
      bar/host. Feel-verdicts for this section are now unblocked.

## 5. UI readability & polish (validate against the large-text/large-target rule)

Lower stakes, but this is where most recent commits live — so confirm they were
worth it. Check on the actual Pixel, at arm's length.

- [x] ~~**Global UI theme pass** (UiPalette FONT_* scale).~~ **KEEP (2026-07-07).** The
      one TWEAK (TURBO button text too small) is fixed: TURBO readout + buy-mode button
      matched at FONT_SUBHEAD, device-verified. Everything else already read well.
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
