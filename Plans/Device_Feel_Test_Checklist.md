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

## How to run the §2–4 focused pass (protocol, 2026-07-07)

Three sittings. **A (§2, 45–60 min):** prestige into a fresh generation and note the
clock at: first staffed property / "opens up" / first nothing-in-reach stretch /
prestige tempting. Moments 3→4 = the mid-game drag zone. Something (milestone, buy,
hire) should land every couple of minutes through tiers 5–9; a 5–10 min dead stretch is
the finding — note epoch, cash magnitude, minutes-in. Do TWO successions (one short,
one long run): does the heir's first 10 min FEEL faster, and does the longer run pay
off visibly? Occasionally ask: Buy units or staff level — if staff level never tempts,
the sink is dead. Use Balance Tuning to probe suspect knobs live. **B (§3, end of the
same run):** in the last ~20% before contact, are you doing things or waiting? Does the
contact moment land? Time the 8× save-up (decision or parking lot?). Do the reward
minigame + 30× magnitudes still read? **C (§4, ~30 min):** Minigame Tuning, Challenge
OFF (matches real transition rounds). Each game twice — once to win, once deliberately
badly: input feel, reachable-but-hard goal, and does the bad result make the Legacy
LOST unmistakable? Then Challenge ON, one game, 10 min: do you chase the score even
once? Glance the backdrops/cards (§5) while there. Log one-word verdicts + specific
notes ("tier 7, ~$40M, 8 min with nothing to buy" is actionable; "feels slow" isn't).

## 2. Economy pacing — the long arc

*Status (2026-07-06): touched this pass and feeling good provisionally, but needs a
focused pass to confirm the MID-GAME stretch doesn't drag before any item is verdicted.*

*Full-session debrief 2026-07-07: three epochs reached across three runs, two
successions. Caveat on all §2 verdicts: Tim plays rush-heavy (often two properties at
once) — the active-player reading, which is the design's target.*

- [x] ~~**Milestone cadence.**~~ **KEEP (2026-07-07).** First staff in ~2 min,
      progression constant through Earth; slowdown arrives only at the last Earth
      property — which reads as the prestige invitation, not drag. Run 2's Earth was
      materially faster in a good way.
- [x] ~~**Legacy / prestige payoff.**~~ **KEEP (2026-07-07).** First prestige KEEP
      ("feels like an acceleration"); the too-big second prestige was retention
      pricing, fixed by work item 1 (per-property cost term, merged dd3e4ff) and
      device-verified. Knobs (retention_*) live in Balance Tuning for future nudging.
- [x] ~~**Staff level-up ROI.**~~ **KEEP at the frontier (2026-07-07).** Good value on
      current properties. Design note (not a TWEAK): trailing-property staff become
      dead value (maxing the ATM at millions/s income) — genre-normal; revisit only if
      the UI seems to pressure those buys.
- [x] ~~**Cumulative staff ladder.**~~ **KEEP (2026-07-07).** Levels and block
      boundaries read clearly across epochs.

## 3. First Contact / alien epoch

*Status (2026-07-06): touched this pass, seems good — same caveat as §2: confirm the
middle doesn't drag on a focused pass before verdicting.*

- [ ] **The leap.** **TWEAK (2026-07-07) — confirms Epoch_Depth_Pass Phase 2.** With a
      single property per post-Earth epoch, the shape is: save-up wall → brief burst →
      epoch over too quickly. The 4-property cohort design is the fix; its priority
      rises. (Save-up itself read as "a little time," not a hard wall.)
- [ ] **Contact overlay / moment.** **FIX SHIPPED (work item 2, merged 2d4de8b; copy
      approved by Tim 2026-07-08).** Each civ now SPEAKS: a typewritten hail in its own
      voice + accent color, market pop, rewritten narrator capper. Re-judge the moment
      at the next real contact on device; real art stays M3.
- [ ] **Transition minigame rewards & framing.** **TWEAK (2026-07-07, work items 3+4).**
      Functionally good overall, but (a) nothing explains WHY a minigame plays at a
      transition — needs framing copy in the Get Ready gate; (b) reshape rewards:
      standard play = neutral 1.0, modest downside for bad play, modest upside for
      great play; skip/opt-out must land exactly at 1.0. (Replaces the old keep_floor
      0.5 model where a bad/skipped round cost half the inheritance.)
- [x] ~~**Alien scale.**~~ **KEEP (2026-07-07).** Fully legible at 900× Earth; the
      magnitude *feeling* is mild-but-present — art/style (M3) and Phase 2 cohorts are
      expected to carry the "different world" sensation.

## 4. Minigames (host + 6 games)

Play each at least twice — once trying to win, once playing badly — and confirm
the score→Legacy mapping *feels* fair in both directions.

*Status (2026-07-06): touched this pass, seems good provisionally — but see the NEW
performance item at the end of this section before feel-verdicting anything here.*

*Per-game verdicts from the 2026-07-07 debrief ("overall I like them"). Blanket note:
the art / polish / copy needs called out below apply to ALL six games — copy/guidance
can land now (rides work item 3's framing pass); real art stays M3.*

- [ ] **Match-3** — **KEEP w/ TWEAKs:** good; wants element resizing, art, and
      guidance/context copy. **Avoid-gem clarified (2026-07-07):** the numbers are fine
      (clean ×1.15 / avoid-match ×0.40) but there's no per-match feedback — a docked
      match flashes identically to a clean one, so the −60% is imperceptible. Fix =
      distinct match feedback: red flash + docked score float on avoid matches, normal
      "+N" float on clean ones (make the impact visible, not bigger).
      **TOO EASY (2026-07-07):** Tim (a match-3 fan) maxes the score almost every
      round — the skill ceiling must be real once work item 4 makes great play the only
      upside, or the bonus is effectively flat. Levers to feel-tune (land WITH item 4):
      perfect threshold up from 200, tighter clock, or +1 gem color; put the threshold
      in TuningConfig.
- [ ] **Basketball** — **KEEP w/ TWEAKs; FIX SHIPPED (2026-07-10, `feature/minigame-feedback`).**
      Both TWEAKs built: (1) a backboard now sits behind the drifting hoop (translucent board + dark
      frame + shooter's square; cosmetic, no bank-shot collision yet); (2) the launch is no longer
      linear — speed now eases over the drag via `_throw_fraction` (LAUNCH_MAX_DRAG 200 /
      LAUNCH_CURVE_EXP 1.7, `PULL_POWER` removed), so small/medium pulls are gentle and full power
      needs a long drag. Re-judge the launch feel on device; the curve exponent is the lever.
- [ ] **Catch money** — **KEEP:** simple but serviceable; needs art + copy (polish
      pass, not mechanics).
- [ ] **Timing bar** — **KEEP:** serviceable; needs polish (same class as Catch).
- [x] ~~**Memory** — **TWEAK:** works, but the time limit makes a good score feel out of
      the player's control — rethink scoring (accuracy/moves rather than raw time?).~~
      **ADDRESSED (2026-07-10):** the Memory timer was REMOVED entirely (recall against a clock
      added nothing) — the game now owns its own ending. Also reshaped: 8→6 base rounds + a
      chance-gated identical-pad "gem round" bonus. Device-approved by Tim ("memory game changes
      look good"). Re-judge the no-timer scoring feel on the next device pass.
- [x] ~~**Balance the books**~~ — **REWORKED + KEEP (2026-07-09, Tim: "Fishing 1.0 is
      good").** Now vertical Stardew-fishing: hold the big LIFT button (a dedicated
      button below the track, matching how the other games take input — Tim's call) to
      raise the marker, gravity drops it, bank score inside the drifting gold zone.
      Difficulty device-tuned with Tim: GRAVITY 1.9, zone re-roll 1.3s, ZONE_EASE 1.6.
      The old layout's lag went with the old layout.
- [x] ~~**Get Ready gate**~~ — **KEEP (2026-07-10, Tim: "the get ready looks good").** Text scaled
      up (GET_READY_TEXT_SCALE 1.4) and the block vertically centered so it reads as one balanced
      group (fixed the tall-phone empty-gap look). Framing copy already lands via work item 3.
- [ ] **Challenge mode** — not separately verdicted this session.
- [ ] **Result screen** — re-judge after the work-item-4 reward reshape (the "Legacy
      lost" framing changes when standard play becomes neutral).
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
- [x] ~~**Carbonation + liquid polish batch (2026-07-06).**~~ **KEEP (2026-07-07).**
      Both holds released: minigame lag fixed and the rush-bar rule verdicted KEEP.
      One follow-up spun out: rush should agitate the carbonation more (work item 5,
      now shipped + verified 2026-07-08).

---

## Work queue from the 2026-07-07 full-session debrief

In build order (1–5 small/medium, then the big one):

1. **Retention repricing** — add a per-property cost term (cost scales with property
   index) and steepen per-level growth; move BASE/GROWTH/STEP into TuningConfig so
   they're live-tunable from Balance Tuning. Root cause of "second prestige too big."
2. **Contact-moment differentiation** — distinct per-civilization voice in each
   `contact_line` (source: docs/alien_civilizations.md), optional per-civ accent color
   on the overlay. Art itself stays M3.
3. **Transition framing copy** — Get Ready gate explains WHY the minigame plays (the
   heir proving themselves at succession; risking the pile on welcome-back).
4. ~~**Reward curve reshape**~~ — **SHIPPED (2026-07-10, `feature/minigame-feedback`).** The host
   multiplier is now a two-segment curve: `minigame_keep_floor` (retuned 0.5→**0.9**, a modest
   downside) at performance 0, exactly **1.0** at `minigame_full_performance` (new knob, 0.5 —
   "standard" play), up to 1.0+bonus at performance 1.0 (modest upside). Skip/opt-out already banks
   1.0. Match-3 reads the neutral point via the new `outcome_full_performance` the host sets (its
   "clean play = full" alignment holds). All numbers live in Balance Tuning — device-tune. NOTE: the
   result-screen "Legacy lost" framing is now gentle automatically (a bad round shows KEPT ~90%, not
   50%); re-judge its wording on device.
5. ~~**Rush excitement package**~~ — **SHIPPED + device-verified KEEP (merged to main
   e9174ac, 2026-07-08).** Tim: "I think we have finally figured this out, at least
   well enough to move on. i changed carb excited ease to 0.9 and that helps a lot"
   (0.9 promoted to the shipped default). The hard part was making the frenzy CONSTANT
   from press to release — solved by two frame shifts: (a) the bar sweep is a smooth
   trapezoid (eased engage → deterministic constant rushed rate → metronome wraps →
   eased release), and (b) excited bubble flow is RELATIVE — measured fill speed + a
   constant surge — because the eye judges bubbles against the moving fill, not in
   absolute px/s. All rush presentation gates on one `rush_engaged` flag.
   **Method lesson (keep):** seven blind feel-iterations failed; instrumenting won —
   on-device debug overlay (`carb_debug_overlay`) + live carb_* tuning knobs + the
   `CarbAutopilot` desktop CSV logger (`carb_autolog`). Instrument feel bugs, don't
   iterate blind.
   *Flagged trade-offs for Tim's veto:* excited bubbles now exceed the old absolute
   speed ladder during an active rush sweep (~330 px/s); comet tails default to 0.3
   visibility during frenzy (`carb_excited_tails` knob if full trails are wanted back).
6. ~~**Balance the books REWORK**~~ — **SHIPPED + device-verified KEEP (merged to main
   191c241, 2026-07-09; Tim: "Fishing 1.0 is good").** Vertical single-input Stardew-
   fishing mechanic; input is a large HOLD-TO-LIFT button below the track; difficulty
   tuned live with Tim (GRAVITY 1.9, zone re-roll 1.3s, ZONE_EASE 1.6). Lag cleared.

**Big build behind them: Epoch_Depth_Pass Phase 2** (4-property cohorts per epoch) —
priority raised by the §3 "epoch over too quickly" finding.

Smaller per-game TWEAKs (basketball backboard + launch curve, memory scoring, match-3
items, catch/timing polish) ride along when their game is touched.

### Parked design ideas (2026-07-07, not yet scheduled)

- **Epoch-tech currency:** a small grant of alien technology each time a NEW epoch is
  reached, with very high impact on speed/income. Design WITH Epoch Depth Phase 2
  (both rebuild the epoch-arrival moment). Identity guardrails: few-and-huge grants
  (not another incremental shop), and scope it apart from Legacy — e.g. run/epoch-
  scoped rocket fuel vs gems' permanent floor, or effects gems never touch.
- **Rush limiter:** evaluate constraining rush (currently always-correct to hold) via
  a cooldown reducible with Legacy gems. Lean toward a STAMINA METER (drain + refill,
  gems extend tank/rate) over a hard lockout, so it reads as a resource to spend, not
  a dead button. **Envisioned PER PROPERTY (Tim, 2026-07-07):** each property's crew
  tires independently, so constant rushing becomes a rotation across the ladder —
  rewarding active two-handed play instead of parking on one button. Prototype behind
  a tuning flag after the current economy items land.

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
