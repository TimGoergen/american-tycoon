# Core Pace Study — the two-clock tuning pass

**Date:** 2026-07-03
**Status:** BUILT (see `game/sim/PaceStudy.gd`) — awaiting Tim's candidate pick
**Trigger:** Tim's device feel-test verdict: *"the game progresses too fast, but the
property cycle times feel too slow. I like the pace of mid-game Idle Slayer."*

## 1. The diagnosis

An idle game runs two separate clocks:

- **The feedback clock** — how often the screen rewards you for looking at it
  (cycles completing, bars filling, numbers ticking up).
- **The progression clock** — how often you make a meaningful strategic purchase
  (a new property rung, a milestone, a staff hire).

Mid-game Idle Slayer feels good because the feedback clock is *fast* (coins
stream constantly) while the progression clock is *slow* (the next upgrade worth
caring about is minutes away). American Tycoon currently has those inverted:
base cycles stretch to 272 s at the top of the ladder (slow feedback), while the
cost curve lets a mid-game player blow through rungs and milestones (fast
progression). Tim's "too slow AND too fast" is both clocks being wrong in
opposite directions.

## 2. The two levers

1. **Cycle curve** — compress base cycle lengths so owned properties hum.
   Applied **income-neutral**: when a tier's cycle shrinks by some factor, its
   income-per-cycle shrinks by the same factor, so income/sec — and therefore
   the epoch timings and prestige pacing we already tuned — is untouched.
   Cycle length becomes a pure *feel* knob.
2. **Cost growth** — steepen the per-unit cost ratio (`r0`, live 1.07) and/or the
   milestone band steepening (`band_step`, live 1.10) so meaningful purchases
   space out. This is the lever that actually slows progression.

## 3. The study (`game/sim/PaceStudy.gd`)

A standalone headless script (extends `Sim.gd` for its config loading) that
plays a 60-minute active session from $0 under each candidate (cycle top,
`r0`, `band_step`) tuple, using one fixed player policy: wage taps, greedy
best-income-per-dollar unit buys, greedy staff hires, greedy frenzy pops,
restart idle cycles. The policy is deliberately identical across candidates —
absolute times are a fast-handed proxy, but *relative* movement between
candidates is real.

**Windowing (v2):** the first cut measured fixed wall-clock windows, but the
sim's tireless thumb consumes Earth's whole economy in ~25 minutes and spends
the back half of the hour buying alien rungs — whose long, un-scaled cycles
drowned out the Earth compression in the readout. So every metric is anchored
to the candidate's own **Earth mid-game window: rung-8 unlock → First
Contact** — exactly the stretch of play Tim's complaint describes. The
window's own length is the headline progression number.

Per candidate it records, inside that window:

- **Progression clock:** every meaningful purchase (first unit of a new rung,
  milestone crossed, staff hire) → median gap between purchase moments, plus
  the rung-unlock time ladder and the First Contact time.
- **Feedback clock:** sampled each minute — the frontier (highest-owned)
  property's effective cycle length, the longest effective cycle on the board,
  and the share of owned rungs "humming" (effective cycle ≤ 10 s).

A final comparison table puts every candidate side by side.

**Target band (mid-game Idle Slayer):** a longer window with wider purchase
gaps (slower progression), while the longest cycle on the board stays under
~45 s and most owned rungs hum (faster feedback).

## 4. Deliberate scope cuts

- **Staff level-ups are not in the sim policy** (v1). They're a real mid-game
  sink, but folding them into the greedy policy changes its math; the units +
  hires + milestones cadence is the signal we need to pick a curve pair.
- **Aliens/epochs untouched.** A 60-minute from-$0 session never leaves Earth;
  alien configs are carried through un-scaled.
- **Cycle compression preserves each tier's income/sec exactly**, so the epoch
  timing study and Legacy conversion tuning remain valid by construction. Only
  cost steepening moves overall pace — its effect is visible in the study's own
  output (rung ladder + First Contact time).
- **Cost steepening reads weaker in the sim than it will on device.** The sim's
  near-permanent frenzy and superhuman tap rate make cash cheap, so the
  r0/band_step spread in the table is a *floor* on the brake's real effect.

## 5. How to run

```
D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe \
  --headless --path "C:\Claude\American Tycoon\game" --script res://sim/PaceStudy.gd
```

## 6. Next step

Tim reads the comparison table, picks a (cycle top, r0/band_step) pair — or asks
for new candidates — then a follow-up commit bakes the winner into the 12 Earth
`.tres` files (cycles + incomes rescaled together) and `tuning.tres`, and the
GDD §4 / Spec §3.2–3.3 tables get synced.
