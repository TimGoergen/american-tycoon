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
