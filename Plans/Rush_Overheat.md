# Rush Overheat (Rush Momentum Phase 2) — design of record

**Origin:** Tim, 2026-07-15. Evolves Rush Momentum (Item 5's companion mechanic) from a
hold-forever ratchet into a push-your-luck heat system: the property "heats up" as you rush —
that's WHY its productivity rises — but push it too hot and it shuts down temporarily.

**Status:** Design agreed in conversation 2026-07-15; not yet implemented.

## The problem this solves

Today (`RushMomentumState.gd`) momentum builds to a cap and sits there; the optimal play is
"never release," which is a grip test, not a decision. Overheat converts it into a rhythm —
build, ride the danger zone, vent, re-engage — and the warning tiers turn the punishment-to-avoid
into a reward-to-chase: deeper heat = bigger bonus = closer to shutdown.

## Core model: ONE scalar, no timers

Heat and momentum are the SAME meter. Heat keeps climbing past the old cap while rush is held;
every tier is a **heat range**, not a timed state. All feel questions become band-edge knobs.

| Band | Heat range (first-cut) | Time in band while held | Bonus | Signal |
|---|---|---|---|---|
| Building | 0 → 100% | ~6 s (base build rate) | 0% → +30% | normal fill |
| Hot (warning 1) | 100% → 125% | ~3.3 s (slower overdrive build rate) | +30% → +40% | amber, gentle pulse |
| Critical (warning 2) | 125% → ceiling | ~2–4.7 s (random, see below) | +40% → +55% | red, blink + haptic |
| **Overheat** | heat hits ceiling | — | 0%, rush disabled | grayed button, bar drains |

- Above the Hot edge, heat builds at a separate **slower overdrive rate** (first-cut 0.075/s vs
  0.167/s base), so the whole ride from the tick to the rolled ceiling lasts ~5.3–8 s — a real
  decision window, not a flash (Tim 2026-07-15: "at least 5 to 8 seconds in the high heat zone").
- Bonus climbs **continuously** within each band (smooth, matches the bar); only the crossing
  into Critical shows a tier chip ("CRITICAL +55%") so the escalation is legible without reading
  a number. Entering Hot is deliberately chipless — the amber fill shift and streaks carry it
  (Tim 2026-07-15: no chip at the top of the Building stage).
- Releasing drains heat at the normal bleed rate, sliding back DOWN through the bands. Hysteresis
  falls out for free: escaping Critical costs real depth; there is no timer to game with a
  micro-flick. Re-engaging resumes from wherever you cooled to.
- Heat/bonus mapping stays a pure function `bonus = f(heat)` — one variable drives payout,
  display, and danger state, preserving the existing "cash always matches the readout" invariant.

## Randomized ceiling (Tim, 2026-07-15: "the exact point of overheating should not be entirely predictable")

- The overheat ceiling is **rolled secretly per excursion**: each time heat climbs into the Hot
  band from below, roll a fresh ceiling uniformly within the Critical band (first-cut: 140%–160%).
  Re-rolling per excursion prevents probing-and-memorizing.
- **Guardrail — randomness lives ONLY in Critical.** The ceiling can never land inside Hot; the
  Hot band's promised width is always honored, so the warning tiers stay trustworthy. Hot means
  "safe for its width." Critical means "you are now gambling and this run's fuse length is unknown."
- The random floor (140%) guarantees a minimum ~2 s in Critical before the earliest possible
  shutdown — anti-frustration, tunable.
- UI consequence: the bar cannot show the exact overheat point. Draw Critical as a hazard-striped
  region with blink intensity ramping by depth; the visible tick sits at the 100% (old cap) line.

## Overheat penalty (Tim: "more severe than waiting for a full cooldown")

1. Rush disabled immediately; bonus drops to 0.
2. Heat drains at a separate **locked-drain rate** (knob) — target lockout ~8–12 s from a full
   ceiling. The bar visibly draining IS the cooldown display.
3. After the bar reaches empty, a **re-arm delay of 1–2 s** (knob) before rush becomes available
   again — the extra sting Tim asked for. Visual: button stays grayed through the re-arm, then a
   ready flash (+ haptic) so re-availability is unmissable. Taps during lockout/re-arm are ignored,
   but the button must LOOK disabled — an unresponsive live-looking button reads as a bug.
4. The true cost of overheating is the full rebuild climb from zero; the lockout itself stays short.

## Frenzy interaction (Tim: freeze)

During frenzy, **heat gain pauses and the bonus freezes** at whatever depth the player entered
with. Rationale: the overdrive tiers will tempt players to ride Critical into a frenzy, and an
overheat mid-frenzy would gut Item 5's press-to-release payoff. Heat also does not drain during
frenzy (a true freeze) — venting-during-frenzy was considered and rejected to avoid re-tuning the
Item 5 surge flow.

## What changes about the mechanic's job

The old design comment says momentum rewards SUSTAINED engagement; overheat shifts that to
rewarding ATTENTION. The effective average bonus becomes the duty cycle of ride/vent, below the
peak. That's why the peak rises to +55% (from today's +30% cap, which was halved once on device
for being overpowered) — it is only reachable for seconds at a time. **The realistic average
bonus must be measured with the CarbAutopilot-style harness before device testing** (durable
lesson: instrument feel bugs, don't iterate blind).

## Knobs (all live in Balance Tuning)

| Knob | First-cut | Meaning |
|---|---|---|
| `rush_heat_hot_start` | 1.00 | Hot band lower edge (old cap; visible tick) |
| `rush_heat_critical_start` | 1.25 | Critical band lower edge |
| `rush_heat_ceiling_min` | 1.40 | Random ceiling floor (min Critical depth before shutdown) |
| `rush_heat_ceiling_max` | 1.60 | Random ceiling roof |
| `rush_bonus_at_hot` | 0.30 | Bonus at the Hot edge (unchanged from today's cap) |
| `rush_bonus_at_critical` | 0.40 | Bonus at the Critical edge |
| `rush_bonus_peak` | 0.55 | Bonus at max possible heat |
| `rush_locked_drain_per_second` | tune for 8–12 s lockout | Drain rate while overheated |
| `rush_rearm_seconds` | 1.5 | Delay after fully cooled before rush re-enables |

Existing knobs (`rush_momentum_build_per_second`, `rush_momentum_bleed_per_second`,
`rush_momentum_grace_seconds`) keep their roles; `rush_momentum_max_bonus` is superseded by the
band/bonus knobs above.

## Open items

- Exact haptic pattern per tier (device pass).
- Whether the tier chip needs a sound cue (device pass).
- Autopilot duty-cycle measurement to validate the +55% peak before Tim's device verdict.

## Decision log

- One meter — heat IS momentum (Tim, 2026-07-15).
- Safe-at-max window ≥ 3–5 s; two warning tiers, each higher bonus + higher risk (Tim, 2026-07-15).
- Natural-drain-while-locked, not a momentum wipe (Tim, 2026-07-15).
- Extra 1–2 s re-arm delay after full cool (Tim, 2026-07-15).
- Frenzy freezes heat and bonus (Tim, 2026-07-15).
- Randomized overheat point (Tim, 2026-07-15); confined to Critical band (Claude's guardrail,
  accepted in conversation).
