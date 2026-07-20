# Overdrive Vent Windows (Rush Momentum Phase 3) — design of record

**Origin:** Tim, 2026-07-17. Overheat works but is not satisfying: overdrive is "a fairly small
additional boost for more active but not more interesting actions." The sim agrees — skilled
overdrive averages +34.8% vs cruise's +24.5%, a +10.3% edge for genuinely riskier play. Tim wants
overdrive **more skill-based, with larger risk and larger reward**. Vent Windows chosen in
conversation over combo-escalation (judgment-only) and active-venting-taps (too busy). The
**double-release vent gesture is Tim's idea** (2026-07-17): "the player releases, taps, then
holds, creating two separate lifts."

**Status:** Design agreed in conversation 2026-07-17; not yet implemented.

## The problem this solves

The current Critical band is a slot machine, not a skill test. The overheat ceiling is rolled
secretly per excursion (140–160%), so there is no read, no reaction, and no way to get better at
riding it: you hold, and you either vent early (leaving reward unclaimed) or eat a lockout you
could not have avoided. More effort, no more agency. Vent Windows replaces the hidden random
ceiling with **telegraphed skill checks**: every overheat becomes one the player caused by
missing a read, and the reward ladder climbs high enough to be worth interrupting cruise for.

## Core loop

Entry is unchanged: hold to rush, cruise clamps at +25%, second finger on OVR opts into the
danger bands. From there:

1. Heat climbs through Hot into Critical exactly as today (same build rates, same band edges).
2. Once in Critical, the property periodically threatens to blow: a **vent window** telegraphs
   (bar flash + haptic + a chip naming the demanded gesture — "VENT" or "VENT ×2").
3. The player must perform the vent gesture on the rushed property's button before the window
   closes:
   - **VENT (single feather):** lift the rush finger, then re-press. One clean lift.
   - **VENT ×2 (double release, Tim's gesture):** lift → tap (press + release) → re-press and
     hold. Two separate lifts, like pumping a release valve.
4. **Success:** a chunk of heat vents (you drop back within Critical, not out of it), the climb
   resumes, and the **bonus tier ratchets up one rung** — the reward for surviving the check.
5. **Miss (window expires) or reaching the hard ceiling:** OVERHEAT. Lockout severity scales
   with how high you had climbed (see penalty section).

The reward ladder, first-cut: base Critical peak +55% (today's), then +75% after the first
successful vent, +95% after the second, +115% after the third (cap). Early windows demand the
single feather; from the second vent onward the double release is demanded and windows tighten.
So climbing the ladder escalates **both** the timing pressure and the gesture itself — the
risk/reward/skill triangle in one mechanic — while the first vent stays approachable for a
player who has never overdriven.

## What replaces the randomness

The hidden random ceiling is **retired** (`rush_momentum_ceiling_min/max` superseded). Tim's
2026-07-15 "the exact overheat point should not be entirely predictable" is still honored, but
the unpredictability moves from the *outcome* to the *schedule*: each vent window's arrival time
is rolled within a knob range, so you never know exactly when the check comes — but once it
telegraphs, the outcome is entirely in your hands. A **hard ceiling** remains (fixed, visible as
the bar's end) purely as the "you ignored everything" backstop; window scheduling must guarantee
at least one window telegraphs before heat can reach it at overdrive build rates.

## The vent gesture, precisely

A small state machine on the rushed property's button, **armed only while a vent window is open
on an overdriven property** — outside a window, taps stay ordinary rush taps and there is no
ambiguity (context gating).

- Single feather: `release` → `re-press` with the gap ≤ `vent_gap_max`.
- Double release: `release` → `press` → `release` → `re-press`, every gap ≤ `vent_gap_max`,
  the middle tap's own press ≤ `vent_tap_max` (so a re-hold isn't mistaken for the tap).
- Gesture must **complete** before the window expires; starting it is not enough.
- First-cut tolerances are deliberately sloppy-thumb generous (`vent_gap_max` 0.40 s) and all
  live in Balance Tuning — thumbs on glass are the real calibration, not the sim.
- **Fumble = miss.** A wrong or incomplete gesture (single lift when ×2 was demanded, tap too
  late) overheats like a timeout, but the miss feedback must show WHICH beat was blown (e.g. the
  chip flashes the unfinished pips) — miss-feedback is what makes a skill mechanic learnable.
  A gentler soft-fail (forced vent to cruise, ratchet lost) was considered and parked; flip to
  it if device play shows full-overheat-on-fumble is rage-inducing. **Open for Tim's verdict.**

### Presentation rule — the hold must not flicker

A double release means two moments with the finger off the property mid-rush. The momentum grace
window already covers the *math* (widen it so a full worst-case gesture fits inside: grace ≥
2×`vent_gap_max` + `vent_tap_max`); this rule covers the *look*: while a vent window is open,
the property row keeps its held-rush presentation (bar, streaks, portrait dim) through the lifts.
The game must never appear to have dropped the hold mid-gesture, or venting will feel broken.

## Overheat penalty — scales with height

Falling from higher should hurt more (larger risk to match the larger reward):

1. Rush disabled, bonus to 0, locked drain from current heat — unchanged mechanics, but heat is
   now higher at deep tiers, so the drain is naturally longer.
2. **Additional re-arm sting per achieved vent tier** (`vent_fail_rearm_per_tier`, first-cut
   +1.0 s/tier on top of the base re-arm): overheating at tier 3 costs the ~10 s drain plus ~4.5 s
   of re-arm. The true cost remains the full rebuild climb from zero.
3. Rapid Restart (Legacy) keeps discounting lockout exactly as shipped — it divides the whole
   thing, including the per-tier sting.

## Interactions

- **Cruise Control: untouched.** Cruise stays the safe +25% floor; the honest choice is
  "reliable +25%, or play the skill game for up to +115%."
- **Frenzy: freeze extends to the window scheduler.** Heat, bonus, AND any pending/open vent
  window pause during frenzy (a window that were to expire mid-frenzy would be an unfair miss).
- **Cooling Systems (Legacy)** raises the cruise clamp as shipped; no interaction with vents.
- **Future Legacy idea (not in scope):** a "Pressure Valves" upgrade granting +1 ratchet cap or
  a wider vent window — parked until the base mechanic proves fun on device.

## Sim validation (before any device build — durable lesson: instrument, don't iterate blind)

Extend `RushOverheatTest.gd` + the autopilot duty-cycle harness with modeled venters:

- **Skilled** (95% vent success): target avg bonus ~**+60–80%** vs cruise's +24.5% — a gap that
  reads as "worth it," not the current +10.3%.
- **Sloppy** (≈70% success): should land **at or below cruise** — the risk has to be real, or
  cruise stops being a choice.
- Verify the penalty math: a tier-3 overheat must cost more accumulated bonus than the tier it
  was chasing would have paid in the same wall-clock (no "overheating is fine, actually").
- Verify window scheduling can never beat the telegraph to the hard ceiling at any knob combo
  the panel allows.

## Knobs (all live in Balance Tuning; `rush_momentum_` prefix groups them in the panel)

| Knob | First-cut | Meaning |
|---|---|---|
| `rush_momentum_vent_window_delay_min` | 2.0 | Earliest a window can arrive after entering Critical / after a vent (s) |
| `rush_momentum_vent_window_delay_max` | 4.0 | Latest arrival (s) — the rolled unpredictability |
| `rush_momentum_vent_window_duration` | 1.0 | Time to complete the gesture once telegraphed (s) |
| `rush_momentum_vent_window_tighten` | 0.10 | Duration shaved per achieved tier (s; floor 0.5) |
| `rush_momentum_vent_gap_max` | 0.40 | Max gap between gesture beats (s) |
| `rush_momentum_vent_tap_max` | 0.25 | Max press length that still counts as the middle tap (s) |
| `rush_momentum_vent_heat_drop` | 0.15 | Heat vented on success |
| `rush_momentum_vent_bonus_step` | 0.20 | Bonus added to the band peak per successful vent |
| `rush_momentum_vent_max_tiers` | 3 | Ratchet cap |
| `rush_momentum_vent_double_from_tier` | 1 | First tier whose NEXT window demands the ×2 gesture |
| `rush_momentum_hard_ceiling` | 1.60 | Fixed backstop ceiling (replaces the random roll) |
| `vent_fail_rearm_per_tier` → `rush_momentum_vent_fail_rearm_per_tier` | 1.0 | Extra re-arm seconds per achieved tier on a miss |

Superseded: `rush_momentum_ceiling_min` / `rush_momentum_ceiling_max` (the random roll).
Unchanged: all band edges, build/bleed/locked-drain rates, cruise knobs, the shipped
`rush_momentum_haptic_*_ms` knobs (the window telegraph should get its own haptic knob riding
the same pattern).

## Open items

- Gesture tolerances are a device question; the sim only validates the economy.
- Fumble severity: full overheat (current spec) vs soft-fail to cruise — Tim's device verdict.
- Telegraph visual language: sweeping zone vs flash cadence (prototype both cheap, pick on device).
- Whether VENT ×2 deserves a distinct haptic signature (double-pulse) — new knob if so.
- Whether the +115% cap should scale with epoch depth — parked, revisit with Late Epoch Sinks.

## Sim retune addendum (2026-07-17, build session — AWAITING TIM'S VETO)

The autopilot found the plan's first-cut knobs **cannot hit the plan's own targets**: with a
+115% tier-3 top, a skilled venter averages only ~+45–50% — climb time and occasional lockouts
dilute the average no matter how well you play. Hitting the +60–80% skilled target required a
**taller, faster, harsher** ladder, shipped as the new defaults:

| Knob | Plan first-cut | Shipped default |
|---|---|---|
| `vent_window_delay_min/max` | 2.0 / 4.0 | **0.8 / 1.6** (a check ~every 1.2 s in Critical) |
| `vent_bonus_step` | 0.20 | **0.45** |
| `vent_max_tiers` | 3 | **4** |
| `vent_fail_rearm_per_tier` | 1.0 | **3.0** |

Ladder peaks are now **+55% → +100% → +145% → +190% → +235%** (was +55…+115%). Measured duty
cycle: cruise +24.9%, **skilled (95%) +61.9%**, **sloppy (70%) +24.2%** — both targets hit
(old pre-vent skilled rhythm: +34.8%). Also: the sloppy model only lands below cruise because
the *bail decision* at the tier cap is judged at the same reliability as the gestures —
knowing when to let go is itself a skill moment.

**Tim's choice:** accept the tall ladder (+235% top, checks every ~1.2 s — an intense minigame),
or revert to plan-faithful knobs and accept a ~+45% skilled average. Both are two knob edits in
Balance Tuning; the cadence is equally a device-feel question.

## Endless escalation rework (Tim, 2026-07-18 — supersedes the tier cap)

Tim's verdict on the built v1: likes the vent mechanic, but it is "still relatively limited" —
he wants "more of an infinite scaling rather than a relatively short limit before you overheat,"
with the failure state coming "from the mechanic becoming more difficult and complicated,
including increasing the number of vent events and speed that must be accomplished in order to
keep going."

So: **the tier cap is gone; the difficulty curve replaces the ceiling as the ending.**

- **Windows never stop.** `vent_max_tiers` retired. Every successful vent ratchets the bonus
  AND the difficulty; the run ends when you finally miss (or bail by releasing). Deep runs are
  self-limiting: even at 95% per-gesture skill, survival odds compound away — the designed
  outcome is that every overdrive run eventually ends in flames, and the question is how high
  you got. Best streak = an implicit high score (numbers-go-brrr, pillar 4).
- **Three escalation axes, per tier (all knobs):**
  1. *Cadence* — window arrival delay decays geometrically (`vent_delay_decay`, first-cut 0.88)
     toward a floor (`vent_delay_floor`, 0.35 s): more vent events, faster.
  2. *Speed* — window duration decays (`vent_duration_decay`, 0.92) toward a floor
     (`vent_duration_floor`, 0.45 s): less time to perform each gesture.
  3. *Complexity* — required lifts escalate 1 → 2 → 3 (`vent_lifts_step_tiers`, first-cut: +1
     lift every 3 tiers, hard-capped at 3 — a quad-pump is thumb mush, so past ×3 the speed
     axes carry the difficulty alone). The old `vent_double_from_tier` is superseded.
- **Reward stays a flat unbounded step** (`vent_bonus_step`) per vent — the difficulty curve is
  the brake, not the reward curve. No cap on the peak bonus.
- **Punishment does NOT escalate without bound:** the per-tier fail sting keeps its rate but
  gains a cap (`vent_fail_rearm_cap`, first-cut 9 s extra) — Tim's direction is that failure
  pressure comes from difficulty, not from ever-longer timeouts. The hard heat ceiling remains
  only as the ignored-everything backstop.
- **Sim gates change shape:** report the skilled/sloppy *survival curves* (median and p90 tier
  reached) and average bonus; targets — skilled median run reaches tier ~6–10 with average
  bonus ≥ the v1 +61.9%, sloppy still at or below cruise, and the telegraph guarantee holds at
  every escalated cadence (floors included).

**Shipped tune (2026-07-18, sim-validated — 600 s × 5 seeds):** cruise +24.9% · skilled (95%)
**+71.3% avg, median death at tier 8, p90 tier 12** · sloppy (70%) +23.0%, median tier 2. Every
skilled run ends on a blown beat, never the backstop. Retunes vs first-cut, all sim-forced:
`vent_bonus_step` 0.45→**0.60**; `vent_heat_drop` 0.15→**0.06** (deep runs must visibly ride
just under the backstop or the average is unreachable — success also tops heat off so the next
window always fits before the ceiling); `vent_delay_decay` **0.85**; `vent_duration_decay`
0.92→**0.975** (at 0.92 a ×3 window became physically unfinishable right when triples begin —
a cliff, not a curve). Autopilot models skill **per lift** (not per gesture), which is what
makes triples genuinely harder and produces the compounding-odds survival curve above.
Effective ladder: +55% base, +60% per vent, unbounded — a median skilled run peaks ~+535%.

## Depth-hazard rework (Tim, 2026-07-18 evening — the Critical zone is retired)

Tim, after the seamless-bar pass: "I think there shouldn't be a critical zone. It should just be
the chance of a vent event goes up as they go further into the overheat zone as a whole."

- **No Critical band.** `rush_momentum_critical_start` and `rush_momentum_bonus_at_critical`
  retired. The heat model has two regions: Building (0 → 1.0, the old meter) and OVERDRIVE
  (1.0 → hard ceiling). Bonus is one continuous lerp `bonus_at_hot → current_peak_bonus()`
  across the whole overdrive span — no kink where a band edge used to be.
- **Vent checks are a depth hazard, not a zone event.** While overdrive is engaged and heat is
  past the cruise point, each tick rolls a window-open chance from a rate that interpolates
  with depth: `rate = lerp(vent_rate_at_cruise, vent_rate_at_ceiling, depth_frac)` where
  `depth_frac = (heat − cruise) / (hard_ceiling − cruise)`. First-cut knobs:
  `rush_momentum_vent_rate_at_cruise` 0.05 windows/s (a check every ~20 s hovering shallow),
  `rush_momentum_vent_rate_at_ceiling` 1.0 windows/s (relentless at the top). The per-tier
  cadence decay is retired — depth IS the cadence axis now, and since a small `vent_heat_drop`
  means long runs inevitably ride deeper, escalation-by-tier falls out naturally. Duration
  decay and the lifts ladder stay as the tier-difficulty axes.
- **Player-authored intensity:** venting drops heat, so where you sit in the hazard curve is
  partly your call — shallow overdrive = rare checks, small climb; riding deep = frantic and
  rich. The telegraph guarantee stays: a window always force-opens with its full duration
  available before heat can reach the backstop.
- **UI:** the "CRITICAL +X%!" band-crossing chip and its haptic are retired (the vent
  telegraphs are the drama); urgency (blink rate/strength) keys continuously on depth_frac.
  The band overlay's stripes/gradient already fade edge-free and merely lose the
  critical_start input. `rush_momentum_haptic_critical_ms` retired with its moment.
- **Sim gates unchanged in spirit:** skilled ≥ ~+62% avg with median death ~tier 6–10, sloppy
  ≤ cruise, telegraph guarantee at every depth, plus a new statistical check that measured
  arrival rate actually rises with depth. Retune the two rate knobs to hit them.

## Approach-bar presentation rework (Tim, 2026-07-18 night — the bar becomes two instruments)

Tim: vent events are good but need to be "as fun, but as intuitive as possible." The momentum
bar is redesigned into two display modes:

- **Cruise mode (overdrive NOT engaged):** the ENTIRE bar spans 0 → the cruise clamp — filling
  the whole bar IS reaching cruise. Clean and safe-reading; no hazard wash.
- **Overdrive mode (engaged):** the bar repurposes into the vent minigame instrument:
  - A **target bar** fixed ~1/3 of the way from the left edge — the trigger point.
  - Each scheduled vent event is a **bright red bar entering from the RIGHT edge**, traveling
    left so the player SEES IT COMING. When it reaches the target bar, the event triggers
    (the window opens).
  - While the event is open, **the whole region right of the target** renders the event
    mechanics — the lift pips and the window countdown — at bar scale.
- **Core change to enable it:** the hazard roll now SCHEDULES an event instead of opening it
  instantly — new signal `vent_incoming(approach_seconds, required_lifts)` fires at the roll,
  the window opens after `rush_momentum_vent_approach_seconds` (new knob, first-cut 2.0 s) of
  tick-time (frenzy freeze pauses the approach). One event in flight at a time; hazard rolls
  suppress while one is approaching or open. The telegraph guarantee now reserves room for
  approach + full window before the backstop.
- Overheat lockout keeps the full-bar drain display; the success/miss chips stay above the bar;
  heat still climbs underneath and still drives the hazard rate (urgency wash keyed on depth).

### Instrument refinements (Tim, 2026-07-18 night — five polish passes on the built v1)

1. **Trailing fill.** The approaching red bar is no longer alone: the region from the bar back
   to the RIGHT edge fills with a dim variant of the event gold as it travels — the event
   "fills in behind" its leading edge, reading as a region sweeping in. Same MUSTARD_GOLD
   family as the open-window dressing (dim 0.25 alpha vs the backdrop's 0.40), so the trail
   growing to full width IS the backdrop appearing — approach and open event share one
   identity, and the open lands as a brightness step, not a repaint.
2. **Brighter pips.** Landed lifts are now near-white discs (#FFF7E6 — the most luminous mark
   on the bar) and owed lifts bright-gold rings (#F5C542); the solid-vs-outline shape keeps
   filled-vs-owed unmistakable while both pop off the gold backdrop the old cream sank into.
3. **Thin timer strip.** The full-region draining countdown plate is replaced by a steady
   event backdrop plus a thin (5 px) bright-gold timer bar hugging the region's bottom edge,
   spanning target → right edge and draining right-to-left toward the target — the classic
   timer strip, continuing the everything-collapses-into-the-target motion language and
   staying clear of the centered pips.
4. **Rolled refractory (core).** Post-resolution arrivals felt near-metronomic (deep rides sit
   on the force-spawn bound). Every vent success — and every fresh overdrive engage — now
   rolls a quiet spell in [`vent_refractory_min` 0.4, `vent_refractory_max` 1.2] s (seeded
   rng, tick-time, frenzy-frozen) during which hazard dice AND the force-spawn hold fire.
   Guarantee reconciliation: the post-vent top-off now reserves refractory_max + approach +
   duration + cushion of climb room, and an engage-time roll is clamped to the climb room
   left, so a worst-case quiet can never push an event past the backstop. Miss/overheat paths
   need no refractory (they end in lockout). Sim retune (rates saturate — the free ride is
   approach + refractory, not hazard wait): rates 0.5/3.0 → **0.7/3.4**, fail sting
   6.0 → **12.0 s/tier**, cap 9.0 → **14.0 s**. Gates: cruise +24.9%, skilled +78.1%
   (median death tier 8, p90 13), sloppy +24.6% — at or below cruise.
5. **Lockout dead-bar gray.** During the overheat drain the track revealed behind the
   shrinking red fill is a dark slate gray (#45464C — clearly "dead" vs the normal #B6BAC0
   track, still hue-contrasting the BRICK fill); once drained, the gray covers the bar and
   its right edge recedes leftward on the real re-arm countdown (new core getter
   `rearm_remaining_fraction()`: 1.0 at re-arm start → 0.0 at rush_ready, 0.0 otherwise) —
   the gray's retreat IS the re-arm timer, and the READY flash lands on a normal bar.

## Overheat property freeze + shorter approach (Tim, 2026-07-19)

Two changes, tuned as ONE balance pass because they trade against the same gate:

- **Shorter approach:** `rush_momentum_vent_approach_seconds` 2.0 → **1.2** (Tim: "2 seconds
  feels leisurely — I want to see it coming but not feel like I'm waiting for it"). This also
  attacks the sloppy-player free ride at its root (less riskless pay bundled with each check).
- **Overheat freezes the rushed properties:** during the whole lockout (drain + re-arm),
  every property that was ACTIVELY BEING RUSHED at the overheat moment (Tim's clarification:
  all of them, if multi-touch rushing several) is FROZEN — cycle paused, no collections, no
  income from that property at all; it resumes at rush_ready. Rationale: makes the shutdown
  thematically real (the machine is DOWN, not just un-rushable); the penalty becomes
  PROPORTIONAL to what was gambled (your top earner goes dark, not a flat timer); it reaches
  the sloppy player as real stakes instead of dead time, so **the sting timeouts come back
  DOWN** (target: ≤ the original 3 s/tier / 9 s cap, lower if gates allow) — Tim's
  "failure pressure from difficulty, not timeouts" restored.
- Sim gate metric extended: frozen seconds count as −100% on that property (lost base income),
  so the sloppy ≤ cruise / skilled +62–80% gates now price the freeze honestly.
- UI: frozen property rows need a "down" presentation (dark/gray, consistent with the momentum
  bar's dead-gray lockout, no-moving-UI rules).

## Frenzy freeze REMOVED (Tim, 2026-07-19)

Tim: "I don't like the way that frenzy and rush lock each other out." The 2026-07-15 rule that a
frenzy burn FREEZES the whole heat model (no heat, no bleed, no lockout drain, no re-arm, no
hazard rolls, no window countdown) existed to protect a frenzy payoff from a hidden-fuse
overheat. Vent Windows replaced that fuse with telegraphed skill checks, so the guard outlived
its reason — while the freeze itself made the game's two best moments mutually exclusive
(a burn switched the vent game off; a lockout starved the frenzy meter).

- `RushMomentumState.tick()` no longer takes `frenzy_burning` at all — the heat model does not
  know what a frenzy is. Heat climbs, the hazard rolls, approaches fly, windows count down, and
  a lockout cools straight through a burn.
- **Consequence, accepted:** you CAN now overheat mid-frenzy, and the property freeze means the
  burn loses that property for the rest of the lockout. That is the drama that makes riding
  checks under a live multiplier worth doing — the peak of the loop, with the peak of the risk.
- Second consequence: a lockout can now COMPLETE inside a burn, so cooldown time and frenzy
  time overlap instead of queueing (sim §29 asserts exactly this).
- Chosen over two alternatives Tim declined: freezing heat but still serving windows, and
  letting a lockout charge the frenzy meter.

## Lockout scoped to the rushed properties (Tim, 2026-07-19)

Tim, on device: "The overheat lockout still appears to apply to all properties and not just
properties that were actively being rushed... other properties on the same tab that did not have
any staff were also locked." Two separate causes, both fixed:

- **Core:** `tap_property` / `hold_rush_property` refused the rush verb globally on
  `can_rush()`, so an overheat on one property made the WHOLE empire unrushable. Now only a
  FROZEN property refuses; every other property keeps rushing through the lockout — real income,
  real frenzy fill — but grants no heat and no momentum bonus, because the meter itself is down
  until rush_ready. (The explicit frozen guard in `hold_rush_property` is load-bearing now: it
  used to be covered incidentally by the `can_rush()` gate.)
- **UI:** `PropertyRow`'s lockout dim keyed off the shared meter's `is_locked_out()`, graying
  every row's portrait at once. It now keys off that row's own `is_overheat_frozen`.

So the punishment is exactly: the meter is down (no bonus anywhere) and the properties you were
riding are dark. The rest of the empire plays on. Sim §31 locks this in.

## Decision log

- Overdrive must be skill-based with larger risk and reward; cruise keeps the safe floor
  (Tim, 2026-07-17).
- Vent Windows chosen over combo-escalation and active-venting-taps (conversation, 2026-07-17).
- Double-release gesture — lift, tap, re-hold, "two separate lifts" (Tim, 2026-07-17).
- Escalating gesture ladder: single feather early, double release deep; windows tighten as the
  bonus climbs (Claude's proposal, accepted in conversation).
- Hidden random ceiling retired; unpredictability moves to window arrival time, outcome becomes
  player-owned (Claude's proposal, accepted in conversation).
- Miss-feedback must show which beat was blown (conversation, 2026-07-17).
- Hold presentation must persist through the gesture's lifts (Claude's guardrail, flagged in
  conversation).
