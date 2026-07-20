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
      ~~**TOO EASY (2026-07-07):** Tim (a match-3 fan) maxes the score almost every
      round...~~ **RESOLVED (2026-07-20):** Tim: "the difficulty currently feels good, I do
      not max out the game as often as I used to due to other changes." The bigger 7×6 board,
      the harder ceiling, and the work-item-4 reward reshape did the job between them — no
      difficulty lever needed. The per-match feedback TWEAK above is still open.
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
- [ ] **Challenge mode** — **REWORK (Tim, 2026-07-20): the idea's right, the execution isn't.**
      Today it is endless free-play per minigame with a persistent best score per type
      (`ChallengeScores.gd`) and no stakes — a high-score table with no reason to visit it.
      Tim wants a **combination of two fixes**: (a) **give it stakes** — a run should pay
      something real (Legacy or a bonus), because pure high scores don't motivate him; and
      (b) **give it goals, not just scores** — replace the raw endless number with named
      targets to beat ("clear 12 rounds", "catch 40 coins"), a ladder to climb rather than a
      number to exceed. Needs a design pass before build; the two fixes interact (goals are
      the natural thing to attach payouts to).
- [ ] **Result screen** — **DECIDED (Tim, 2026-07-20): keep loss framing, soften the wording.**
      Losing something should still sting a little, but a 10% shortfall must not read as a
      catastrophe. Rejected: reframing everything as upside-only ("+18% BONUS", never mention
      loss) and leading with what was KEPT. Copy pass, no math change.
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
- ~~**Rush limiter:**~~ **DROPPED as superseded (Tim, 2026-07-20).** The idea was a per-property
  stamina meter so constant rushing became a rotation across the ladder. Rush Overheat and then
  Vent Windows arrived in the meantime and already constrain rushing while rewarding active
  play — Tim: a second limiter on top would be noise. Recorded rather than deleted because the
  underlying goal (reward two-handed play ACROSS properties, not parking on one button) is still
  a live design value and may want an expression someday; it just won't be this one.

---

## 6. Overdrive Vent Windows (branch `feature/overdrive-vent-windows`)

*Added 2026-07-19. This is the only section with a branch not yet on `main` — the whole
feature is waiting on this pass. Design of record: `Plans/Overdrive_Vent_Windows.md`;
read its "Shipped state" section for current behaviour and knob values. Install the
branch APK, not a `main` build.*

**The trap to avoid:** the three biggest open questions cannot be answered by playing
well. Skilled play is already sim-validated at +74.8%. What is unvalidated is what
happens when you are bad, careless, or greedy — so this protocol deliberately spends
half its time playing badly. Do not skip those sittings because they feel unproductive.

**Narrowed by the 2026-07-20 design interview.** Four of the five open questions turned out
to be design calls, not feel calls, and Tim answered them: the freeze stays a full stop and
sloppy play is ALLOWED to go negative; a fumble is a full overheat; the ladder stays
unbounded at every epoch; vent haptics will encode lift count as pulse count. So **sitting A
no longer asks whether the penalty should be softened — that is settled.** It now asks only
whether the settled design *feels* the way it reads on paper. Sitting B likewise keeps its
tolerance work and drops its fumble-severity question.

### Device verdicts — 2026-07-20 (Tim played the current build)

Four of the five sittings are now answered. **Only sitting E remains untested.**

- [x] ~~**Sitting A — the freeze.**~~ **KEEP w/ TWEAK.** Tim: "I like it, but I think there
      should be text over any overheated property to make it clear why they went dark." The
      penalty itself lands; the gap is legibility — a dark row currently states a fact without
      explaining it. **TWEAK: `OVERHEATED` + a countdown on each frozen row** (Tim's pick over
      a bare label, a softer "COOLING DOWN", or a voiced line) so the wait is bounded rather
      than open-ended. Not a moving-UI violation: it appears on a state the row already has.
- [x] ~~**Sitting B — tolerances.**~~ **KEEP.** Misses felt like Tim's own ("mine — I was too
      slow"), which is the answer we most wanted: `vent_gap_max` 0.40 / `vent_tap_max` 0.25
      stay as shipped. The feared failure mode — clean lifts going unregistered and reading as
      difficulty — did not occur. Fumble severity was settled by the 07-20 design interview.
- [ ] **Sitting C — the instrument.** **TWEAK ×2, both open.**
      1. **Approach still too slow at 1.2 s.** The smoothing fix landed (motion is no longer
         jerky) but the runway still reads as waiting. Tim wants a **live knob pass** rather
         than a guessed number — and `rush_momentum_vent_approach_seconds` is *already* exposed
         in Balance Tuning (labelled "Vent Approach Sec"), so this needs no build work; dial it
         on device. **Re-run the sim gates afterward:** a shorter runway trims the riskless paid
         time bundled into every check, which moves skilled *and* sloppy averages.
      2. **Pips readable but too small.** Contrast is fixed; size is the remaining gap. They are
         currently capped by `PIP_RADIUS_MAX` (20 px) in `MomentumBar.gd`, so raising
         `PIP_HEIGHT_FRAC` alone will do nothing — lift the cap too.
- [x] ~~**Sitting D — lockout scoping.**~~ **FIXED, confirmed.** Only the properties Tim was
      actually rushing went dark; the rest of the empire kept cycling and earning. The 07-19
      bug is closed.
- [ ] **Sitting E — frenzy + overdrive together.** **STILL UNTESTED** — the combination didn't
      come up. This is the one genuinely unknown interaction left on the branch: the mutual
      freeze was removed 07-19, so a burn and a vent run have never been played simultaneously,
      and overheating mid-burn (losing the property for the rest of the multiplier) has never
      been felt. Protocol below unchanged; do this before merging.

---

### Sitting A — the freeze, played badly (~20 min). Answers open verdict 1.

The sim says sloppy overdrive play now measures **−12.7%**: worse than not overdriving at
all, worse than cruise, actively losing money. That is deliberate, but it has never been
felt. Play a normal run and overdrive **recklessly** — ride deep, chase the ratchet, do
not bail when the gestures get thick.

- When a property freezes, what is the actual feeling: *tense and fair* (I gambled my
  best earner and lost it), or *punitive* (the game took my toy away)?
- Watch the income figure during a freeze. Does losing that property read as a
  consequence you caused, or as the game being broken for a few seconds?
- Roughly how long does a freeze last subjectively vs by the clock? A penalty that
  *feels* twice its length is the signal to soften.
- Do you find yourself avoiding overdrive entirely after two or three bad lockouts? That
  would be the mechanic failing — cruise is meant to be a *choice*, not the safe default.

**Verdict needed (revised 2026-07-20):** the full freeze is now settled design — Tim has
confirmed bad play SHOULD cost real money. So this sitting is no longer a keep-or-soften
vote; it asks whether the *execution* delivers the intent. If the freeze reads as punitive
rather than tense, the fix is presentation or duration, NOT reducing the income loss.

### Sitting B — fumbles and tolerances (~20 min). Answers verdicts 2 and 3.

Fumble severity has **never been device-judged**, and the gesture tolerances are
sloppy-thumb-generous first cuts (`vent_gap_max` 0.40 s, `vent_tap_max` 0.25 s) that only
thumbs on glass can calibrate. Deliberately blow gestures in specific ways:

- Perform a single lift when ×2 was demanded. Does the miss feedback show you *which
  beat* you blew, or just that you failed?
- Re-press too slowly (past the gap window). Was it obvious you were late, or did it feel
  like the game did not register a lift you made? **The second answer is the important
  one** — a tolerance problem masquerading as a skill problem is the worst outcome here.
- At tier 3+ where triples begin: is a triple genuinely *hard*, or physically
  awkward/unfinishable? Difficulty is the design; thumb mush is not.
- ~~Full overheat on a fumble, or the parked soft-fail?~~ **SETTLED 2026-07-20: full
  overheat, soft-fail rejected.** What remains is only whether a fumble is *legible* — after
  a blown gesture, did you know what you did wrong?

Use Balance Tuning to probe `vent_gap_max` live if a tolerance feels wrong; note the value
that fixed it rather than just "too tight."

### Sitting C — the instrument, read at speed (~15 min). Answers verdict 4.

Tonight's smoothing fix took the approach bar from moving on 15% of frames to 91%.

- Does the 1.2 s approach read as *seeing it coming*, or still as *waiting for it*?
  (2.0 s was your "leisurely"; 1.2 s is the correction — confirm it landed.)
- Track the timer strip during a window. Smooth now, or still stepping?
- The trailing gold sweep filling in behind the red bar — does the window opening land as
  a brightness step, or does it read as the display repainting?
- Landed pips (near-white discs) vs owed pips (gold rings): unmistakable at a glance
  mid-gesture, at arm's length? You reported these too dim once already.
- Frozen row presentation: dead slate bar, gray portrait, dark-gray 0 income. Does it say
  *this machine is down* without you having to reason about it?

### Sitting D — lockout scoping, verify the fix (~10 min). Regression check.

Your 07-19 report was that an overheat locked properties you had never rushed. Two causes
were fixed; confirm on device.

- Rush **two** properties with multi-touch. Have a third property on the same tab that is
  **unstaffed and untouched**. Overheat deliberately.
- Expected: exactly the two you were riding go dark. The third keeps cycling and earning
  normally, and you can still rush it — it just builds no heat and gets no bonus.
- Also confirm the meter itself reads as down empire-wide (no bonus anywhere) while the
  rest of the empire visibly plays on. That split is the whole design of the penalty; if
  it reads as confusing rather than fair, that is a finding.

### Sitting E — frenzy and overdrive together (~10 min). New interaction, never played.

The frenzy/heat mutual freeze was removed today, so these two systems now run
simultaneously for the first time.

- Trigger a burn, then overdrive *during* it. Riding vent checks under a live multiplier
  is meant to be the peak of the loop — is it thrilling or overwhelming?
- Overheat mid-burn on purpose. You lose that property for the rest of the burn. Is that
  the good kind of painful, or does it feel like the game wasted your best moment?
- Confirm a lockout now cools *through* a burn rather than queueing behind it.

**Log format, as always:** one-word verdict plus a specific note. "Tier 4 triple at ~9 s
in, missed the third lift twice, felt like the window closed early" is actionable;
"vents feel hard" is not.

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
- [ ] **Overdrive Vent Windows** (`feature/overdrive-vent-windows`, not merged) — see §6;
      the whole branch is blocked on that pass (2026-07-19)

### Gap notice (2026-07-19)

This doc lapsed between 2026-07-10 and 2026-07-19 — several features merged to `main` in
that window without a line here, which is exactly the silent-backlog failure the doc
exists to prevent. Only §6 has been backfilled so far. Still unrecorded and untested:

- [ ] Escalating 52-property ladder (merged to `main`)
- [ ] Rush Overheat heat model + prestige Option C + TURBO rework (merged)
- [ ] Rush Cruise Control — device-verified KEEP, merged d294478 *(listed for completeness;
      no action needed)*
- [ ] Legacy Bonus System across all minigames (`feature/match3-difficulty`, not merged)
- [ ] Match-3 difficulty rework: 7×6 board, harder ceiling, combo removed (same branch)
