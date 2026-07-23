# Property Cycle-Length Curve — Tuning Proposal

**Date:** 2026-07-23
**Status:** PROPOSAL (no `game/` files changed — sim edits were temporary and reverted)
**Author:** balance-sim pass
**Scope:** the 12 Earth-tier property base cycle lengths (`base_cycle_length` in
`game/config/properties/01…12_*.tres`). Alien tiers (13–52) are untouched.

---

## 0. TL;DR — read this first

The original brief asked for a "moderate stretch" curve with the **top tier at ~3–5
minutes base**. During this pass that premise was corrected against the code + doc
changelog, and the sim data agrees with the correction:

- **The 3–5 min top is a rolled-back decision, not a live target.** A 2026-06-25
  "moderate stretch" *did* push tier 12 to ~272 s (~4.5 min). The **2026-07-03 Core
  Pace pass deliberately reversed it**, compressing tier 12 back to **60 s**
  (income-neutral) and moving the progression brake onto the **cost curve** instead
  (`r0` 1.07 → 1.09). See `Plans/Core_Pace_Study.md`.
- **A cycle-curve change is a pure *feel* knob — it cannot move progression pacing
  or "speeds up every time."** Both are governed by the cost curve and the Legacy
  curve, which a cycle change leaves bit-identical (proof in §3).
- **The sim shows a stretch strictly *worsens* the feel it would be sold on.**
  Stretching the top from 60 s → 240 s pushes the mid-game frontier property's
  cycle from 37 s to 128 s and drops "humming" rungs from 76 % to 66 %, while the
  progression clock (window length, purchase gap) does **not move at all**.

**Recommendation: keep the live 60 s-cap curve (Candidate 0).** It already sits
inside the Idle-Slayer feel target the last pace pass set. If Tim still wants longer
"anticipation" on the top rungs, Candidate 1 (120 s) is the mildest reversible step;
Candidate 2 (240 s) is a full reversal of the 2026-07-03 pass and is not advised on
the feel data. All three are laid out below so the call is informed, not blind.

---

## 1. Current (live) state — the baseline

### 1.1 The 12 Earth tiers, as shipped

| Tier | Property | base_cost | base_cycle_length (s) | base_income_per_unit | base income/sec | ×cycle vs prev |
|-----:|----------|----------:|----------------------:|---------------------:|----------------:|---------------:|
| 1 | ATM | $50 | **0.54** | 5.0 | $9/s | — |
| 2 | Money Tree | $350 | **1.765** | 78.45 | $44/s | 3.27 |
| 3 | NFTs | $2.5K | **3.077** | 683.74 | $222/s | 1.74 |
| 4 | Tax Increment Financing | $17.5K | **4.47** | 4,966 | $1.1K/s | 1.45 |
| 5 | Cross Border Distribution | $120K | **6.233** | 34,630 | $5.6K/s | 1.39 |
| 6 | Money Laundering | $850K | **8.15** | 226,381 | $27.8K/s | 1.31 |
| 7 | Day Trading | $6M | **11.401** | 1,583,415 | $138.9K/s | 1.40 |
| 8 | Flipping Houses | $42M | **15.67** | 10,552,056 | $673.4K/s | 1.37 |
| 9 | Multi Level Marketing | $290M | **21.986** | 81,430,202 | $3.7M/s | 1.40 |
| 10 | Hedge Fund | $2B | **30.778** | 569,958,344 | $18.5M/s | 1.40 |
| 11 | Legislative Assets | $14B | **43.023** | 3,824,309,933 | $88.9M/s | 1.40 |
| 12 | Executive Assets | $100B | **60.0** | 29,629,629,630 | $493.8M/s | 1.39 |

Shape: a fast two-rung "head" (ATM/Money Tree deliberately short so the opening
minutes hum), then a clean **geometric ×1.40 ladder** from tier 3 to a **60 s top**.
Every tier steps ~5× income/sec and ~7× cost over the previous — the ladder-magnitude
intent is intact and is not in question here.

### 1.2 How runtime compression works (why "base" ≠ "what the player sees")

`PropertyState._apply_milestone_reward()` is the key. Milestones fire at 25 / 50 /
100 / 200 / 300 / 400 units (6 bands). Each milestone **halves the cycle** as long as
the result stays ≥ `cycle_floor` (1.0 s); once halving would drop below the floor, it
**doubles income** instead. Either branch **doubles income/sec**. So:

- A 60 s base cycle halves 60 → 30 → 15 → 7.5 → 3.75 → 1.875 (6 bands, all land on
  cycle), so a maxed Executive Assets *shows* a ~2 s bar even though its base is 60 s.
- Staffing adds an income multiplier (not a cycle change), and Legacy "Efficiency
  Experts" divides the effective cycle further.

This is exactly why the brief says "compressed at runtime by milestones and staffing"
— the base cycle is the *pre-compression* number.

### 1.3 Baseline sim metrics (live curve, `res://sim/Sim.gd`)

Command that worked (from any dir; Godot is not on PATH):

```
& "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe" `
  --headless --path "C:\Claude\American Tycoon\game" --script res://sim/Sim.gd
```

Dynasty protocol ("speeds up every time", 6 generations, 180 s each):

| Gen | Born w/ Legacy | Time to founder's peak ($10.5M) | Peak net worth | +Legacy |
|----:|---------------:|--------------------------------:|---------------:|--------:|
| 1 | 0 | — (defines the yardstick) | $10.5M | +3 |
| 2 | 3 | 180.1 s | $10.5M | +3 |
| 3 | 6 | 180.1 s (0.0 s slower) | $10.5M | +3 |
| 4 | 9 | 180.1 s (0.0 s slower) | $10.5M | +3 |
| 5 | 4 | 159.4 s (20.7 s FASTER) | $17.1M | +3 |
| 6 | 7 | 159.4 s (0.0 s slower) | $17.1M | +3 |

**The "speeds up every time" curve is essentially FLAT here — and that is a known
sim-scale artifact, not a regression.** The protocol plays only 180 s/gen, so estates
plateau at ~$10–17M, roughly eight orders of magnitude below a real device run
($600T+). The Legacy curve is (correctly) calibrated for device scale, so at these toy
estates it mints too few gems to buy meaningful upgrades — hence flat times. Sim.gd
prints this caveat itself. Acceleration is validated on-device and by the conversion
study's monotonic table, neither of which a cycle change touches.

No runaway, no stall: Phase 4 return spike +93 %, epoch pacing measurement decelerates
gently (x0.78 → x0.85 per epoch), save round-trips PASS.

---

## 2. The decisive finding — what the sim actually says about cycle length

The purpose-built instrument for this question is **`res://sim/PaceStudy.gd`**, which
builds income-neutral variant configs *in memory* (no `.tres` edits) and measures two
clocks inside the Earth mid-game window (rung-8 unlock → First Contact):

- **Feedback clock** — frontier/longest effective cycle, % of rungs "humming" (≤10 s).
- **Progression clock** — window length + median gap between meaningful purchases.

I ran it at the live 60 s cap and at four stretches (temporary edit to its
`CANDIDATES` array, then reverted — file confirmed identical to backup):

| Top cycle | Frontier cycle (mid-game) | Longest cycle | Humming % | Window | Mid-game purchase gap |
|----------:|--------------------------:|--------------:|----------:|-------:|----------------------:|
| **60 s (LIVE)** | **37.2 s** | **37.2 s** | **76 %** | 15.8 m | 29 s |
| 120 s | 67.1 s | 67.1 s | 73 % | 16.1 m | 31 s |
| 180 s | 110.2 s | 110.2 s | 65 % | 15.7 m | 29 s |
| 240 s | 128.5 s | 128.5 s | 66 % | 16.1 m | 28 s |
| 300 s | 177.7 s | 177.7 s | 62 % | 15.6 m | 30 s |

Two things jump out:

1. **The progression clock is flat across every stretch** (window ~15.6–16.1 m,
   gap ~28–31 s). Cycle length does **not** slow progression — the cost curve does.
   This is the 2026-07-03 conclusion, now re-confirmed empirically at the stretched
   end of the range.
2. **The feedback clock degrades monotonically with the stretch.** The Pace-Study
   target (set by Tim in the last pass) is *longest cycle < ~45 s, most rungs
   humming*. The live 60 s curve **meets it** (37 s, 76 %). Every stretch **breaks
   it**: at 240 s the frontier property sits on a ~2-minute bar through the whole
   Earth mid-game — the opposite of the constant-drip feedback the pass was chasing.

A reference run of the shipped `CANDIDATES` (30 s and 90 s tops) brackets the trend
the same way: 30 s → 20.4 s longest / 84 % humming; 90 s → 58.1 s / 69 %. **Feedback
improves as the top *shrinks* and worsens as it *grows*.**

---

## 3. Why the dynasty/epoch numbers don't move (the neutrality proof)

Any cycle-curve candidate here is applied **income-neutral**: multiply a tier's
`base_cycle_length` by factor *F* **and** its `base_income_per_unit` by the same *F*.
Then:

- Base income/sec = income ÷ cycle is unchanged (the *F*'s cancel).
- Each milestone doubles income/sec whether it halves the cycle or doubles income
  (§1.2), so income/sec after *k* milestones = base × 2^k — independent of *F*.
- Staffing and Legacy multipliers act on income/sec, which is unchanged.

Therefore **every economic output of `Sim.gd` — founder's-peak times, epoch pacing,
step-up ratios, Legacy conversion — is bit-identical for any income-neutral cycle
curve.** Running each candidate through the full dynasty protocol would reproduce the
§1.3 table exactly; that is why the meaningful measurement lives in PaceStudy's *feel*
clocks, not in the dynasty protocol. (The one thing that is NOT neutral is forgetting
to rescale income alongside the cycle — that would rescale the whole economy and must
not happen. Every candidate table below lists the paired income factor.)

---

## 4. Candidate curves (full 12-tier tables)

All three keep the fast head (tiers 1–2) and the geometric body, and all are
income-neutral (the "×F" column is the factor applied to BOTH `base_cycle_length` and
`base_income_per_unit` for that tier). The taper is a geometric fade from ×1.0 at
tier 1 to the target at tier 12 — the same shape PaceStudy uses, so the sim numbers in
§2 correspond directly.

### Candidate 0 — KEEP LIVE (60 s top) — RECOMMENDED

No change. Curve = §1.1. Feel: frontier 37 s, humming 76 %, inside target. This is the
baseline every other row is measured against.

### Candidate 1 — Modest stretch to 120 s top (mild, reversible)

Doubles the top-rung anticipation while keeping most of the ladder humming. Frames as a
*partial* softening of the 2026-07-03 pass, not a full reversal.

| Tier | Property | ×F | new cycle (s) | new income/unit |
|-----:|----------|---:|--------------:|----------------:|
| 1 | ATM | 1.000 | 0.54 | 5.0 |
| 2 | Money Tree | 1.065 | 1.88 | 83.5 |
| 3 | NFTs | 1.134 | 3.49 | 775.6 |
| 4 | Tax Increment Financing | 1.208 | 5.40 | 5,999 |
| 5 | Cross Border Distribution | 1.287 | 8.02 | 44,569 |
| 6 | Money Laundering | 1.370 | 11.17 | 310,142 |
| 7 | Day Trading | 1.460 | 16.64 | 2,311,786 |
| 8 | Flipping Houses | 1.554 | 24.35 | 16,397,895 |
| 9 | Multi Level Marketing | 1.655 | 36.39 | 134,767,484 |
| 10 | Hedge Fund | 1.763 | 54.26 | 1,004,846,061 |
| 11 | Legislative Assets | 1.877 | 80.79 | 7,180,269,744 |
| 12 | Executive Assets | 2.000 | 120.0 | 59,259,259,260 |

Measured feel (§2): frontier 67 s, humming 73 %. **Slightly outside** the <45 s
target; progression unchanged.

### Candidate 2 — Full stretch to 240 s top (4 min) — explicit reversal, NOT advised

Restores something close to the rolled-back 2026-06-25 curve. Listed for completeness
and to make the tradeoff concrete.

| Tier | Property | ×F | new cycle (s) | new income/unit |
|-----:|----------|---:|--------------:|----------------:|
| 1 | ATM | 1.000 | 0.54 | 5.0 |
| 2 | Money Tree | 1.134 | 2.00 | 88.9 |
| 3 | NFTs | 1.287 | 3.96 | 879.9 |
| 4 | Tax Increment Financing | 1.459 | 6.52 | 7,246 |
| 5 | Cross Border Distribution | 1.655 | 10.32 | 57,315 |
| 6 | Money Laundering | 1.878 | 15.31 | 425,143 |
| 7 | Day Trading | 2.130 | 24.28 | 3,372,674 |
| 8 | Flipping Houses | 2.416 | 37.86 | 25,493,767 |
| 9 | Multi Level Marketing | 2.740 | 60.24 | 223,118,753 |
| 10 | Hedge Fund | 3.108 | 95.66 | 1,771,430,533 |
| 11 | Legislative Assets | 3.525 | 151.66 | 13,480,692,514 |
| 12 | Executive Assets | 4.000 | 240.0 | 118,518,518,520 |

Measured feel (§2): frontier 128 s, humming 66 %. **Well outside** the <45 s target —
the mid-game frontier property sits on a ~2-minute bar. Progression unchanged.

> A "gentler-early / steeper-late" variant (hold tiers 1–8 near live, concentrate the
> stretch in 9–12) was considered. It does not help: the mid-game window the player
> actually lives in *is* rungs 8–12, so concentrating the stretch there lands the full
> feedback penalty exactly where PaceStudy measures it. The geometric fade already
> spares the low rungs, which is why it is the shape presented.

---

## 5. Recommendation & rationale

**Adopt Candidate 0 — keep the live 60 s-cap curve. Change nothing.**

Rationale:

1. **The stated goal of a cycle stretch (fixing pace/progression feel) is not
   something a cycle change can deliver.** The sim shows the progression clock is flat
   across a 5× range of top-cycle values. Progression pacing is a cost-curve /
   Legacy-curve concern, and the 2026-07-03 pass already placed the brake there
   (`r0` 1.09). Re-opening the cycle lever to fix pace would be pulling the wrong knob.
2. **The live curve already hits the feel target** the previous pass defined (longest
   cycle 37 s < 45 s, 76 % humming). It is not broken.
3. **Every stretch strictly worsens the feedback clock** and reverses a deliberate,
   documented, device-confirmed decision from three weeks ago — with no offsetting
   gain the sim can find.
4. If Tim's underlying want is *"the top rungs should feel like a bigger, slower
   payoff"*, the cheapest honest lever is **Candidate 1 (120 s)** as a reversible
   experiment — but he should go in knowing it costs ~3 humming points and pushes the
   longest bar to ~67 s, i.e. it trades the last pass's feel target for more
   top-rung drama. **Candidate 2 (240 s) is a full reversal and is not recommended on
   the data.**

Footnote for the opposite direction: if anything, the data favors *compression*, not a
stretch — a 30 s top yields 84 % humming / 20 s longest. That is out of scope here
(the brief was a stretch) but worth flagging: the feel gradient points the other way.

---

## 6. Caveats

- **Sim player is superhuman.** PaceStudy's thumb taps ~3×/s with near-permanent
  frenzy and clears Earth in ~22 minutes; absolute clock values are a *fast proxy*.
  Read the columns **relatively** between candidates — the direction and magnitude of
  the feel change are the signal, not the literal minutes.
- **Staff level-ups are a scope cut in PaceStudy's policy** (hires only, no deeper
  levels). Deeper staffing would compress effective cycles *further*, making the live
  curve hum even more and the stretch look marginally less bad — but not enough to
  cross back over the target at 240 s.
- **Milestone/staff compression is modeled** in the effective-cycle feedback samples
  (they call `get_effective_cycle_length()`), so the humming numbers already reflect
  runtime compression — the stretch penalty survives it.
- **Neutrality depends on rescaling income with the cycle.** Any implementation of
  Candidate 1 or 2 MUST scale each tier's `base_income_per_unit` by the same ×F shown,
  or the whole economy (and all epoch/Legacy tuning) shifts. The §4 tables list the
  paired income values for exactly this reason.
- **Alien tiers (13–52) are out of scope** and unchanged; they sit at a flat 60 s base
  and are governed by the epoch/staff-block system, not this Earth cycle curve.

---

## 7. Reproduce the numbers

```
# Baseline dynasty + epoch metrics (§1.3):
& "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe" `
  --headless --path "C:\Claude\American Tycoon\game" --script res://sim/Sim.gd

# Feel clocks at the live 60 s cap (§2 baseline row):
& "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe" `
  --headless --path "C:\Claude\American Tycoon\game" --script res://sim/PaceStudy.gd
```

The §2 stretch rows (120/180/240/300 s) were produced by temporarily replacing
PaceStudy's `CANDIDATES` array with `{cycle_top: 120/180/240/300, r0: -1, band_step:
-1}` entries, running the same command, then reverting the file. No `.tres` or
`tuning.tres` file was edited at any point.
