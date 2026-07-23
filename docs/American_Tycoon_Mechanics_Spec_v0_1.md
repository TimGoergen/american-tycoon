# American Tycoon — Mechanics Specification

**Version:** v0.1
**Date:** June 12, 2026
**Companion to:** GDD v0.2 (theme, vibe, systems intent). This document contains the math. Where the two conflict, this document wins on mechanics; the GDD wins on tone.
**Conventions:** Constants in CAPS live in §12 (Tuning Table). `TBD-SIM` = provisional value, validated/tuned by the balance simulator. `[ENG]` = engineering recommendation, not yet player-approved design — veto on review.

---

## 1. Currency & Numbers

- **Per-planet currency scale.** Each planet's economy resets the displayed scale (GDD §3); Earth's full arc fits comfortably in double precision (~$1e14 target vs. ~1e15 safe integer threshold). `[ENG]` Implement a `Money` wrapper type from day one (internally double for Earth) so a later mantissa+exponent backend for large planets is a drop-in, not a refactor.
- **Display:** real-dollar formatting throughout — `$#,##0` below $1M; named suffixes above ($14.27M / B / T / Qa / Qi / Sx / Sp / Oc / No / Dc / Ud / Dd — the full ladder is the canonical table in GDD §2, implemented 2026-07-03 as `Money.SUFFIXES`, one shared ladder for both `display()` and `display_cash()`; pinned by `sim/MoneyTest.gd`). Never scientific notation, never "quadragintillion" (GDD §2).
- **All currency math floors** at the point of award/charge (matches 2022 code's `Mathf.Floor` convention).

## 2. Time & Tick Architecture `[ENG]`

- **Active:** fixed-timestep logic at LOGIC_HZ, rendering decoupled. Cycle progress accrues in logic ticks.
- **Away:** closed-form on resume — never simulate elapsed cycles. `offline_income = offline_rate × min(elapsed, cap)` (§6). In-flight cycle progress on unstaffed properties is frozen while closed; staffed properties are subsumed into the offline rate (their in-flight cycle resets to 0 on resume, paid for by the rate calc).
- **Clock policy:** trust the device clock; negative elapsed clamps to 0; the offline cap inherently bounds clock-jump exploitation to one pile. Audience of one — no anti-cheat beyond this.

## 3. Properties — Cost, Milestones, Income

### 3.1 Ownership-count milestones
Milestone thresholds at **25, 50, 100, 200, 300, 400** (AdVenture-Capitalist cadence, adopted
2026-06-22; was `20 × 2^k`). Six fixed milestones, then the property is **maxed** — no further
beat past 400. Band 0: units 1–24; band 1: 25–49; band 2: 50–99; band 3: 100–199; band 4:
200–299; band 5: 300–399; band 6: 400+ (the cap). `CostCurve.MILESTONE_THRESHOLDS` is the single
source; it drives both the milestone reward (§3.3) and the cost-curve band (§3.2), so the cost
ratio likewise caps at band 6. **Tradeoff (sim-measured):** this is *less* generous early than
`20×2^k` (at 80 units: old = 3 doublings, AdCap = 2), so the economy runs **~38% slower** — a
prestige/cost re-tune is the open follow-up (§15).

### 3.2 Cost curve — piecewise ratio, stepped at bands
Cost of the next unit when `n` units are owned (0-indexed purchase n+1, in band b):

```
unit_cost(n) = round_nice( BASE_COST_i × Π(over units 1..n) r_band(unit) )
r_band(b)    = R0_i × BAND_STEP^b
```

- **`BASE_COST_i` is the literal sticker price of the first unit** (Tim, 2026-06-14): the
  product runs over the units *already owned* (units 1..n), so at `n = 0` it is empty and
  the first unit costs exactly `BASE_COST_i`. Each unit's own ratio is folded in only once
  it is bought, pricing the next one. (Earlier the product ran to `n+1`, charging `BASE × R0`
  for the very first unit — e.g. the first ATM read $55 instead of $50.)
- Prices are snapped to the nearest $5 (`round_nice`) so the player never sees odd
  numbers; the underlying geometric product is kept raw so the curve still climbs smoothly.
- `R0_i` per property from config. **Live: 1.09 on all 52 rungs** (2026-07-03 core pace pass,
  was 1.07 — the progression brake chosen by the pace study, see §3.3; alien cohort rungs
  inherit their epoch flagship's r0, §3.6).
- `BAND_STEP` global (**live 1.10** since the 2026-06-22 re-tune, §15 item 8; was 1.15).
- Steepening applies only *after* each milestone is crossed — milestones stay reachable by construction.
- **Simulator guard (hard requirement):** no reachable game state may exist where every property is band-walled and no action is affordable (GDD §0.1).
- Bulk-buy costs = exact sum of per-unit costs (fixes the 2022 MAX double-count bug). Buttons: **+1 / +10 / +to-next-milestone / MAX** (GDD §3.1). **The to-next-milestone mode landed 2026-07-07** as `BuyMode.NEXT_TIER` (caption "BUY: NEXT"), replacing an interim ×100 in the same enum slot (saved mode prefs stay valid): `count = max(0, next_milestone_threshold − units_owned)`, **all-or-nothing** — the button disables until the full jump is affordable, and reads +0 past the last milestone (like MAX when broke).

### 3.3 Milestone reward — adaptive
On crossing each milestone, the property receives, in priority order:
```
if cycle_length / 2 ≥ CYCLE_FLOOR:  cycle_length ÷= 2     (speed mode)
else:                               income_per_unit ×= 2   (income mode)
```
`CYCLE_FLOOR = 1.0s` (provisional `TBD-SIM`). Every property follows the arc *first it gets faster, then it gets richer*; conversion point is emergent per property (ATM converts almost immediately; political assets accelerate visibly for most of the game).

**Base cycle-length rework — IMPLEMENTED 2026-06-22, stretched further 2026-06-25 (back half only).** Tiers
**1–6 unchanged**; tiers **7–12 stretched** ~1.6×/tier to a **272s (~4.5 min)** top (Day Trading 26 ·
Flipping 41 · MLM 66 · Hedge Fund 106 · Legislative 170 · Executive 272). (The 2026-06-22 first cut
topped at 180s/~1.5×; on 2026-06-25 Tim pushed the top deeper into the roadmap's 3–5 min ceiling —
the ratio rose to ~1.6×, concentrating the change at the top (tier 7 24→26, tier 12 180→272).)
**Income-neutral:** each
stretched tier's `base_income_per_unit` was scaled up by the same factor as its `base_cycle_length`,
so base income/sec (= income_per_cycle / cycle_length) is unchanged — only the cadence changes
(longer waits, bigger lump sums, more speed-up halvings before the 1s floor). The fix is purely in
`game/config/properties/07..12*.tres`; no formula change. (GDD §4's cycle column is now historical.)

**Core pace pass — REVERSED the stretch 2026-07-03.** Device verdict: progression too fast,
cycles too slow (the two clocks inverted vs. the mid-game Idle Slayer target). Cycles compressed
back down via a geometric taper — tier 1 unchanged, tier 12 **272s → 60s**, intermediate tiers
scaled by `(60/272)^(k/11)` — again strictly income-neutral (`base_income_per_unit` scaled by the
same factor per tier; the pace study confirmed First Contact timing is bit-identical before/after).
The progression brake moved to the cost curve: `r0` 1.07 → 1.09 on all 17 rungs (§3.2). Chosen as
candidate C of the pace study (`game/sim/PaceStudy.gd`, `Plans/Core_Pace_Study.md`); study finding:
cost steepening widens purchase cadence but cannot slow the macro arc (income is self-funding
exponential; the epoch wall is earnings-gated) — a still-too-fast macro arc needs an income-side
lever, not more `r0`.

### 3.4 Income
```
income_per_cycle(i) = floor( units_i × income_per_unit_i )   [2022 formula, preserved]
income_per_sec(i)   = income_per_cycle(i) / cycle_length_i   [for display & offline math]
```
Global multipliers (frenzy §7, the Family Fortune Legacy upgrade §9.4, event modifiers §10) multiply income at point of payment. The Rush Overheat factor (§4.1) also multiplies at point of payment but **per property** — only the property being actively rushed carries it (Tim 2026-07-13). A rushed collection therefore pays `frenzy × Family Fortune × rush_momentum_factor`; `rush_cycle` collects every full cycle the advance covers and carries the remainder (2026-07-12/13 fixes — rush previously dropped Family Fortune).

### 3.5 Per-property UI
Milestone progress slider per property: min = last milestone, max = next (recovered 2022 design, kept — it feeds the return spike: "the pile can push me over 40").

**Cycle-bar display rules (presentation only, settled 2026-07-06/07 after the rush-jank passes):**
- **Solid pin — deterministic.** The bar pins solid-full (no animation; the income readout carries the rate) exactly when the CURRENT completion time is too short to watch: effective cycle `< 0.25s` when not rushing, or — while rush is HELD — when the computed cycle-under-rush time `1 / (1/L + hold_rush_per_second × rush_pct × rush_power) ≤ 0.4s`. No measured cadence, no hysteresis (a measured-wraps rule stuck/unstuck unpredictably and was replaced).
- **Pin transitions.** Entering the pin sprints the bar to full at 3 bars/sec (snapping read as sudden); unpinning restarts the visible lap from empty and chases the true progress.
- **Rushed income readout (2026-07-07).** While rush is held a row's income label quotes the effective rate — `per_cycle × the completion rate above` — as `$X / s` (not gated on `is_cycle_running`: an unstaffed cycle stops momentarily at each payout and would flicker the readout). The hero panel's headline is the **simple sum of the rates the rows currently display** (unowned rows' buy-previews contribute 0), so it rises live under rush/frenzy; the core's `displayed_income_per_sec` (theoretical staffed-passive rate) is unchanged and still drives the executive wage floor (§5).

### 3.6 Alien property types — epoch unlock + First Contact reward (built 2026-06-28, GDD §5.5 site 2)
The ladder is **52** `PropertyConfig`s: the 12 Earth properties plus **40 alien properties in an escalating cohort per epoch — 6, 7, 8, 9, 10 rungs for epochs 2–6** (escalating-ladder rework, Tim 2026-07-15, the unlock-cadence fix; was one property per epoch at build, then 4-property cohorts in the Epoch Depth pass). Each epoch's cohort is anchored by its **flagship** — Photon Exchange (epoch 2), Data Foundry (3), Spore Bank (4), Prism Vault (5), Time Bank (6) — and topped by the epoch's grandest venture (Starcore Syndicate etc.). New rungs were APPENDED at array indices 37–51 (append-only convention), so saves load unchanged.

**Cohort grid (2026-07-15).** Per epoch T, cohort size `N = T + 4`; rung k (0-based, flagship = rung 0):
```
cost(k)   = flagship_cost × (16807^(1/N))^k     (the cohort spans exactly ×16807 = 7^5,
                                                 matching the per-epoch threshold growth)
income(k) = cost(k) × 0.01824                   (income/cost held constant across all rungs)
```
Cycle 60 s, r0, and accent color are inherited from the epoch's flagship. Because every cohort spans ×16807 regardless of size, epoch durations, thresholds, and the ~1-epoch-per-prestige cadence are untouched by construction — only the per-rung ratio shrinks (×5.06 at epoch 2 down to ×2.64 at epoch 6), which is what flattens the unlock cadence (sim-measured median gap ~3.2–4.0 min per epoch, vs. 4.4→7.1 min before).
- **`unlock_tier`** (new `PropertyConfig` field, default 1): a property is buyable/visible only once `EpochState.current_tier ≥ unlock_tier`. Earth's 12 are tier 1; each alien property carries its epoch tier. Gate enforced in `EconomyState.try_buy` / `is_property_unlocked` / `get_cheapest_unaffordable_unowned_index` (all take the run's reached tier) and hidden entirely in `PropertyRow` until unlocked. A locked property is also skipped by the sim's greedy buy.
- **Reward = an upside-only opening bonus, not the unlock (REWORKED 2026-07-02; free-units reward retired).** A property is unlocked-or-not, so the minigame can't multiply the unlock. Instead the First Contact trade-deal minigame's universal multiplier selects a **reward bucket** (`FIRST_CONTACT_BUCKETS`) that gives the newly-opened epoch a permanent opening **income boost + faster cycles** — pure upside, never a penalty (matches GDD §5.5: "you start with ZERO free units"). Full deal → the top bucket; skip / opt-out → a lower bucket; minigames-off banks the keep-floor bucket with no screen; bucket 0 = no bonus. Flow lives in `Main` (`MinigameSite.FIRST_CONTACT`): contact overlay → its `dismissed` signal launches the minigame → `_finish_first_contact_minigame` applies the boost + saves. (The earlier `grant_starting_units = floor(first_contact_starting_units × multiplier)` free-units model was cut on `feature/ui-tap-targets` and no longer exists in code; `first_contact_starting_units = 8` lingers only as a vestigial `tuning.tres` knob.)
- **Magnitude (REWORKED 2026-07-12, continuous ladder):** alien base magnitudes are no longer a fixed flagship — the 52 properties climb at ~×7/rung continuously (Earth already did: ATM $50 → Executive Assets $100B), and each epoch's flagship is **anchored to the player's epoch-entry wealth**: `flagship(T) ≈ 10%` of the previous epoch's threshold (≈ cash on hand at contact), with income anchored separately for a ~3× income step-up at each contact. So it is ×7 within and across alien epochs, with one "catch up to your wealth" jump at the Earth→alien boundary (Tim 2026-07-12: the flagship must not be pocket change on arrival). The rest of the cohort spaces off the flagship per the 2026-07-15 grid above. (The original 2026-06-28 cut was one fixed ~5×-Executive-Assets flagship per epoch, epoch scaling purely from staffing — superseded.)

## 4. Tapping (Active Layer 2)

- **Start verb:** a tap on an idle, unstaffed property starts its cycle (2022 verb, preserved). Cycles pay on completion; unstaffed cycles stop after paying.
- **Rush verb:** a tap on a *running* cycle advances it by `RUSH_PCT × cycle_length` (live 10% — ~10 taps completes any cycle at any altitude; scaled further by the Strong-Arm Tactics Legacy upgrade). Percentage, never fixed seconds: this is what makes tapping auto-scale with capital. Holding auto-rushes at `hold_rush_per_second` (5/s).
- Both verbs feed the frenzy meter (§7) and the dynastic tap count (§5).

### 4.1 Rush Overheat → Cruise → Overdrive Vent Windows (shipped; vent windows merged to main 2026-07-20)
**Design of record: `Plans/Overdrive_Vent_Windows.md`** (supersedes the Critical-band model of `Plans/Rush_Overheat.md`; cruise from `Plans/Rush_Cruise_Control.md` is unchanged).

Rushing heats the property up — **heat IS the momentum meter** (one scalar, no timers; heat unit 1.0 = the old Building cap). Bonus is a pure function of heat; the factor `1 + bonus` multiplies **only the actively rushed property's** income (magnitude builds globally, application is per-property — §3.4).

**RETIRED in the Vent Windows rework** (removed, not merely unused): the secretly-rolled overheat ceiling (`rush_momentum_ceiling_min/max`, the old uniform 1.40–1.60 roll) and the entire **Critical band** (`rush_momentum_critical_start`, `bonus_at_critical`, `haptic_critical_ms`). Heat now has just two regions:

| Region | Heat | Bonus | Rates |
|---|---|---|---|
| Building | 0 → 1.0 (inclusive) | 0% → +30% (`bonus_at_hot`) | build 0.167/s, bleed 0.333/s |
| OVERDRIVE | 1.0 → hard ceiling **1.60** (fixed) | continuous lerp `bonus_at_hot` → current peak (no kink) | overdrive build 0.075/s |
| OVERHEAT | miss a check, or hit the ceiling | 0%, rush frozen | locked drain 0.16/s, then 1.5 s re-arm |

- **Cruise (default):** holding without overdrive is safe forever — heat clamps at `cruise_heat = effective_cruise_bonus / bonus_at_hot` (≈0.833 at the base **+25%** `rush_momentum_cruise_bonus`). No overheat possible while cruising.
- **OVERDRIVE is the opt-in OVR button** (visible/enabled while a rush hold is live): releases the clamp. The bonus lerps from +30% at heat 1.0 toward the run's current **peak** = `bonus_peak` (base **+55%**) + `vent_bonus_step` (**+30%**) per successful vent — **unbounded, no tier cap.** Per-excursion: disengages on release, overheat, and reset.
- **Vent checks are a depth hazard.** While overdrive is engaged, each tick rolls a window-open chance at `rate = lerp(vent_rate_at_cruise, vent_rate_at_ceiling, depth_frac)`, where `depth_frac = (heat − cruise) / (hard_ceiling − cruise)` — **0.7 windows/s** shallow rising to **3.4/s** at the backstop. A roll **schedules** an event (signal `vent_incoming(approach_seconds, required_lifts)`): a red approach bar travels for `vent_approach_seconds` (**0.7 s**) toward a target line at ~1/3 bar width, then the **window opens** for `vent_window_duration` (1.0 s, decaying by `vent_duration_decay` 0.975 per tier toward a 0.45 s floor). One event in flight at a time; hazard rolls suppress while one is approaching or open. Every vent success and every fresh engage rolls a refractory quiet spell in [`vent_refractory_min` 0.4, `vent_refractory_max` 1.2] s.
- **The gesture:** complete `required_lifts` clean lifts (**1**, +1 more every `vent_lifts_step_tiers` = **3 tiers**, hard-capped at **3**) before the timer strip drains. Tolerances `vent_gap_max` 0.40 / `vent_tap_max` 0.25 s; `grace_seconds` **0.5** bridges the lifts so the held-rush presentation never flickers mid-gesture. **Success** vents `vent_heat_drop` (0.06) heat, tops heat off (so the next window still fits before the ceiling), and ratchets the bonus by `vent_bonus_step`. **A miss** (window expires, or a wrong/incomplete gesture) **= OVERHEAT.**
- **Telegraph guarantee:** scheduling always reserves approach + full window duration (+ `refractory_max` on the post-vent path) of climb room before heat can reach the hard ceiling, so every overheat is a missed check, never an ambush — at every escalated cadence including the floors.
- **Overheat = property freeze (not a global lockout).** The meter drains empire-wide with no bonus anywhere; every property that was **actively being rushed** at the overheat moment FREEZES — cycle paused, no collections, no income — until `rush_ready`. Every *other* property keeps rushing, earning, and filling frenzy, but grants no heat and no bonus while the meter is down (only a `is_overheat_frozen` property refuses the rush verb; the global `can_rush()` gate no longer blocks the whole empire). The re-arm sting is **zero** (`vent_fail_rearm_per_tier` and `vent_fail_rearm_cap` both 0.0) — the freeze is the whole penalty, proportional and real-money; failure costs exactly the drain, the re-arm, and the frozen property's lost income.
- **Frenzy no longer freezes the heat model** (removed 2026-07-19): `RushMomentumState.tick()` no longer takes `frenzy_burning`. Heat climbs, hazards roll, approaches fly, windows count down, and a lockout cools straight through a burn — you can overheat mid-frenzy and lose that property for the rest of the multiplier.
- **Bailing pays — the heat-unified tail.** A release that leaves a live bonus retains the ride's earned lerp target (`_retained_peak_bonus`), so `_bonus_for_heat(heat)` keeps lerping toward it as heat bleeds: the bonus decays to zero exactly as the bar empties, and bar, income, and the "SPINNING DOWN +X%" chip all run on the one heat clock. The tail ends the instant rushing resumes (cruise or a fresh engage — preserving the fresh-ladder anti-farm rule and closing the tap-OVR-on/off exploit), on overheat, and on reset. It applies **only while the property's cycle is running** (`is_cycle_running`): a staffed property earns it for the whole tail; an unstaffed one earns it through the one in-flight cycle it finishes, then its cycle stops. An **overheat still zeroes instantly, no tail** — the contrast is the whole value of bailing. (An earlier separate `banked_bonus()`/`banked_fraction()` mechanism was built, then deleted for this heat-unified tail.)
- Legacy ("Rush" category, §9.4): **Cooling Systems** +0.01 cruise bonus/level, max 5 (hard cap at +30%); **Rapid Restart** −10% total lockout/level, max 5 — both unchanged.
- **Duty cycle** (sim-measured, `RushOverheatTest.gd`, current build at approach 0.7 s): cruise **+24.9%**, a skilled venter (95%/lift) **+68.7%** (median death at tier 8), a sloppy venter (70%/lift) **−18.3%** (bad overdrive play loses real money — accepted by Tim as the honest cost of a proportional penalty), a timid cash-out farmer (bails tier 1–2) **+11.6%** (below cruise). All `rush_momentum_*` knobs live in Balance Tuning; `rush_momentum_max_bonus` and the retired knobs above are superseded. Full reset at each First Contact.

## 5. Wage Ladder (Active Layer 1) — Hybrid Credentials

- Tap anywhere-defined wage button: pays `wage(title)` per tap. The button is **never removed** (GDD §5).
- **Promotion requires both:** `dynastic_lifetime_taps ≥ TAP_THRESHOLD(title+1)` **and** payment of `TUITION(title+1)`.
  - Tap count is **dynastic** — persists across generations and planets ("Work Ethic", a Ledger stat).
  - Eligibility is announced; claiming is a purchase (the credential gag — GDD-tone copy per title).
- **(Hon.) titles:** cash-only honorary titles purchasable at any time at obscene prices; grant **zero wage change**; rendered with "(Hon.)" in the Family Ledger, which refuses to respect them.
- Title table (thresholds, tuitions, wages, names) is a content-pass deliverable — schema in §11. Wage values tuned so the track is dominant for the first ~2–3 minutes of generation 1 and a rounding error thereafter.
- First tuition (~$50) deliberately competes with the second ATM — the game's one "invest in yourself vs. assets" beat.

## 6. Staffing & Offline (merged system)

- **Hire / upgrade (epoch-keyed, updated 2026-06-16):** staffing is a **per-property tier track**, not a one-time switch (GDD §6). `staff_tier` per property: `0` = unstaffed, `1` = Earth staffer (auto-start + auto-collect forever — the old "hired" behavior), `2+` = the alien staffer unlocked once the run reaches that epoch (§6.2). Each tier carries `staff_income_multiplier` (Earth = 1.0; alien tiers are large jumps), applied at point of payment alongside frenzy/Legacy.
- **Within-epoch staff levels (the per-epoch upgrade track, added 2026-06-27, GDD §6.1):** after hiring a tier, a property's staffer is leveled up through the epoch. `staff_level` per property; the effective staffer multiplier is `staff_income_multiplier(tier) × (1 + staff_level_step)^staff_level`, routed through `PropertyState._effective_staff_multiplier()` so every income site (collect, per-sec, per-cycle, single-unit) uses it. Level cost is anchored to the current tier's entry hire: `round_nice(entry_hire × staff_level_cost_base × staff_level_cost_growth^staff_level)` (`EconomyState.get_staff_level_cost`). No hard cap — geometric cost is the brake. `staff_level` **resets to 0 on `set_staff_tier`** (a new epoch's staffer is a fresh hire) and is **per property**. Saved per property (GameState SAVE_VERSION → 7; pre-v7 defaults to 0). Constants live: `staff_level_step` (0.33; each block's per-level step is this × the block's catalog multiplier), `staff_level_cost_base` (0.07, cut from 0.10 2026-07-02 so a level's ROI beats buying a unit), `staff_level_cost_growth` (1.5, softened from 1.6), `staff_levels_per_epoch` (20 — the ladder became per-epoch BLOCKS in the 2026-07-04 Epoch Depth redesign: level 1 of each block IS that epoch's staffer hire at the block's anchor, costs/effects frozen to the block's epoch). **Cost (reworked 2026-06-17):** the Earth staffer (tier 1) keeps its small property-scaled cost (≈50× band-1 unit cost × Legacy discount); **alien tiers (2+) are anchored to the target epoch's whole economy** — `earth_economy_target × economy_scale(tier) × staff_cost_fraction × growth^staff_price_rank` — so they cost ~`economy_scale`× more each epoch (×16807 under the 2026-07-12 ladder) and you must earn into the new economy before affording them (saved cash carries over). **Staff price rank (RE-ANCHORED 2026-07-15, escalating ladder):** the growth exponent was the property's GLOBAL array index, which broke once alien cohort siblings were appended out of cost order — now Earth properties rank 0–11 (their old indices, prices unchanged), and an alien property ranks `12 + its cost rank within its own cohort` (every flagship = 12, exactly its old index, so flagship staff prices are also unchanged). Computed once in `EconomyState.compute_staff_price_ranks`; `StaffRetention.cost_for_level` (Legacy retention, §9.3) grows by the **same rank** for the same reason. You can only reach a tier whose epoch the run has reached. Tap-rush remains additive at any tier ≥ 1. Data table: `EpochCatalog.gd`; state: `EpochState.gd`.
- **Epoch pacing — the law (REWORKED AGAIN 2026-07-12, continuous ladder; then escalating cohorts 2026-07-15):** time to clear an epoch ≈ (dollars to earn) ÷ (income/sec). Dollars-to-earn scales with `economy_scale = (7^5)^(tier−1) = 16807^(tier−1)` — one 5-rung ×7 ladder block per epoch, matching how far the property magnitudes climb in that epoch (§3.6), so pacing stays ~flat and you can never trivially buy across epochs. *(The 2026-07-11 Phase-3 model — economy_step 60, threshold-anchored five-property cohorts drifting at `economy_step/DRIFT`, DRIFT 0.95 — was superseded the next day by Tim's "each new property is a ~7× jump, like Earth" continuous-ladder model.)* The old "ratio = economy_step ÷ staff_step" law stays RETIRED; pacing is MEASURED, not projected: `sim/Sim.gd` runs pacing measurement, a step-up check, and a cost-curve-aware PLAYOUT (an heir plays all epochs); epoch durations verified ~unchanged by the 2026-07-15 cohort rework. **Caveat:** on-device feel pass still owed.
- **Offline accrual draws from staffed properties only:**
```
offline_rate  = Σ(staffed i) income_per_sec(i) × OFFLINE_EFF
offline_pile  = floor( offline_rate × min(elapsed_seconds, OFFLINE_CAP) )
```
- `OFFLINE_EFF` provisional 50% `TBD-SIM`; `OFFLINE_CAP` base 4h, extended by Family Office upgrades (ladder TBD content pass).
- **The first hire is the offline unlock** — no separate Property Manager purchase. Family Office = the upgrade institution for cap/efficiency.
- Frenzy, rush bonuses, and event modifiers do **not** apply offline (offline is its own reduced-efficiency channel; keeps active play strictly superior).
- Welcome-back: two-beat ritual per GDD §3.1; pile stat line *Hours worked: 0* sourced from wage-tap count during absence (always 0, by construction — the joke is load-bearing and free).

## 7. Frenzy (Active Layer 3) — One Bar, Two Modes

State machine: `FILLING ⇄ BURNING`.

**FILLING:** meter M ∈ [0,1]. Each tap (any verb) adds `FRENZY_FILL`. After `IDLE_GRACE` seconds without taps, M decays at `FRENZY_DECAY`/s. Pop available at M ≥ `POP_FLOOR` (0.15).

**On pop:** multiplier locks at `1 + (FRENZY_MAX_MULT − 1) × M` for the entire burn (never decays mid-burn). Bar switches to BURNING.

**BURNING:** the bar *is* the timer — drains at constant rate `1 / T_BURN` per second (full bar burns in T_BURN seconds; a 60% pop has 60% of the bar to drain, hence duration scales with charge by construction). Taps perform their normal verbs but feed nothing into the meter; decay is suspended. At M = 0: multiplier ends, state returns to FILLING from empty.

- Frenzy multiplier applies to **all income** (properties + wage).
- Pop button always previews live value: "×2.4 for 38s" (house rule: every irreversible decision shows its reward first).
- Live constants (`tuning.tres`): FRENZY_MAX_MULT 5.6×, T_BURN 30s (device-tuned from the provisional 4×/90s), FRENZY_FILL 0.4%/tap (held rush pulses fill at ×0.6), FRENZY_DECAY 0.5%/s, IDLE_GRACE 5s. The Killer Instinct / Second Wind Legacy upgrades compound the popped multiplier and burn duration further (§9.4). Presented in-game as **TURBO**.

## 8. Debt, Loans, Credit Offers

- **Origin debts** per GDD §8.1 ($200k interest-free / $500k high-interest).
- **Repayment schedule: milestone-triggered**, never wall-clock. Each loan = ordered list of (trigger: net_worth ≥ X OR income_per_sec ≥ Y, amount due). Trigger fires only during active sessions (never resolves while away). Due presented as mail (§10 delivery rule); a GRACE window of active play time to pay; UI shows next trigger transparently.
- **Miss = forced generation end** (bankruptcy death): creditors seize `min(estate, outstanding_balance)` before tax; see §9.2.
- **Offers system:** data-driven tier table (schema §11): {eligibility band (net worth range), principal, payment schedule, flavor}. One active loan max. Terms improve with eligibility band (payday → prime → bailout). Offer cadence: rolled at generation start + on band promotion `TBD-SIM`. Offers arrive as mail; expire silently if ignored (never nag — Principle 5).

## 9. Death, Estate, Legacy

### 9.1 Generation end (non-bankruptcy)
Player-confirmed, always — no aging system. Available once projected Legacy gain ≥ 1 (the minimum-estate gate, emergent from §9.3). Initiated from the **Estate Planning tab**, which displays the live draft will (full §9.2 waterfall) at all times. Advisor pressure: heir status line escalates with upgrade-cadence decay (thresholds `TBD-SIM`); estate planner prompt at sustained stagnation (GDD §0.1).

### 9.2 The estate waterfall (executed at death, itemized on the will screen)
```
estate_gross   = cash_earned_this_gen               (the dollars THIS generation earned over its life; GDD Future Features decision 2026-06-14)
after_credit   = estate_gross − min(estate_gross, outstanding_debt)     (creditors first)
taxable        = max(0, after_credit − EXEMPTION)
tax            = floor(taxable × TAX_RATE)
estate_net     = after_credit − tax
```
- **Gross-estate basis changed 2026-06-14 (GDD Future Features "Lifetime cash earned"):** the gross is now the generation's **lifetime cash earned**, not net-worth-at-death (`cash + asset_book_value`). This rewards earning over a life rather than terminal hoarding, and gives a monotonic, cross-epoch-comparable basis. The per-generation figure feeds the waterfall; the dynasty also keeps a cumulative `lifetime_cash_earned` accumulator as the display/yardstick stat. Everything below the gross is unchanged. (`K_LEGACY`/`ALPHA` re-tuning expected once magnitude shifts — `TBD-SIM`.)
- `EXEMPTION` base $1M; `TAX_RATE` base 60% — both provisional `TBD-SIM`, deliberately brutal so the loophole tree feels like a jailbreak.
- **Loopholes** (purchased via Legislative/Executive Assets, persist across generations): two axes — exemption raisers (multiplicative on EXEMPTION) and rate cutters (subtractive on TAX_RATE, floored at LOOPHOLE_RATE_FLOOR ~5%). Catalog = content pass; each loophole = real mechanism, real name, itemized line on the will.

### 9.3 Legacy conversion (gentle power curve, bracket display)
```
legacy_gain = floor( K_LEGACY × (estate_net / LEGACY_BASE) ^ ALPHA )   K=0.50 ALPHA=0.22 LEGACY_BASE=$1k
```
(`estate_net` here is the post-tax net of the §9.2 waterfall, whose gross is lifetime cash earned
this generation — not net worth at death; nothing converts at or below the `LEGACY_BASE` floor.
**Curve history:** the 2026-06-17 log² curve — `floor(K × log10(net/base)²)` — fixed the original
`K × net^0.5` runaway but was so flat that doubling a run's earnings added only ~3 Legacy, breaking
the "better run → more prestige currency" loop; **2026-07-02** restored a deliberately GENTLE power
curve (ALPHA 0.30, K 0.045 — gems roughly double per 10× of earnings, anchored $10T→45).
**Prestige Option C, 2026-07-14:** ALPHA 0.30 → **0.22** and K 0.045 → **0.50** together (a lower
exponent needs a higher coefficient to keep the first prestige near its old ~350 gems) — at 0.30 the
yield compounded ~18× per epoch, driving income ×237 over a dynasty; 0.22 still rewards a better run
(~+16% gems per 2× estate). Paired with the second brake: **`legacy_upgrade_cost_multiplier` = 2.0**,
a NEW global × on every Legacy upgrade's cost (`LegacyUpgradeCatalog.cost_multiplier`, a static set
from tuning by DynastyState), so a prestige's gems buy fewer levels. Target: ~1 epoch per prestige.)
**Prestige minigame multiplier (GDD §5.5; built 2026-06-22 as match-3).** The prestige
minigame scales how much of the converted award is **kept**:
```
legacy_awarded = floor( legacy_gain × MINIGAME_MULT )
MINIGAME_MULT = keep_floor          at performance 0   (a MODEST downside)
              → 1.0 (neutral)       at performance minigame_full_performance  (= what Skip / opt-out banks)
              → 1.0 + bonus_max     at performance 1.0
bonus_max = LegacyUpgrades.minigame_bonus_max()  = 0.25 + 0.05 × Family Reputation level
```
`legacy_gain` (the power curve above, × Estate Lawyers yield) is the **base**. **Curve reshaped
2026-07-10 (work item 4):** STANDARD play is now neutral — the multiplier is `minigame_keep_floor`
(0.9, a modest downside, no longer half) at performance 0, exactly 1.0 at "standard" performance
(`minigame_full_performance` 0.5), and up into the bonus at perfect play; **skip / minigames-off
banks exactly 1.0**, not the floor (the 2026-06-21/22 stakes model, where a skip cost half the
award, is retired). Tuning: `minigame_keep_floor` 0.9, `minigame_full_performance` 0.5,
`minigame_full_score` 100, `minigame_extra_score` 200, `minigame_duration_seconds` 25 (device-tuned
2026-07-09; dev-panel editable); the extra bonus cap is the Family Reputation upgrade
(LegacyUpgradeCatalog). Governed by the
persisted `GameState.ui_minigame_enabled` (default mandatory). Applied in
`DynastyState.perform_succession(cause, minigame_multiplier)`, floored, clamped ≥ 0.

**Library + polish (2026-06-29).** Six minigame types are built — Match Three, Timing Bar, Catch
the Money, Memory Match, Balance the Books, Micro Basketball — each a `Minigame` subclass that
only reports `get_performance() → [0,1]`; the host (`MinigameScreen`) owns the countdown, the
spectrum bar, the result, the skip/opt-out, and the multiplier math identically for all. A polish
pass added shared host juice (focal pulsing timer with low-time warning states, a smoothed
spectrum bar that reads by **fill + color only — no numeric readout**, a **SKIP button that shows
the kept reward**, a blooming result reveal, a fading Begin gate, a frozen-clock cue) and per-type
juice + a locked per-type difficulty *direction*. Each type owns its own scoring/difficulty
constants in its script (e.g. Timing Bar `ZONE_HALF_MIN` / `SPEED_RAMP`, Catch Money
`MISS_PENALTY` + spawn ramp, Balance `DRIFT_MAX`, Match Three `POINTS_PER_GEM`/`SCORE_FULL`) —
all first-pass, pending an on-device re-tune. Visual treatment: the minigame screen and Minigame
Tuning screen render over a themed backdrop (`art/backgrounds/minigame_background.png`, corners
CPU-rounded to the frame) with a semi-transparent (70% cream), smaller card; the Tuning list sits
on a card matching the Get Ready panel exactly.

**Challenge Mode (SHIPPED on `feature/challenge-mode-phase1`; device-confirmed 2026-07-22; pending
merge).** A tiered, timed progression layered over every minigame, reached from a standalone
CHALLENGES screen (Settings → CHALLENGES), NOT the old Minigame-Tuning toggle (retired — see the
note below). The host sets `Minigame.challenge_mode = true` before `begin()`; a type then reports a
raw cumulative score via `Minigame.get_score()` (points / locks / coins / climbs / seconds in zone /
baskets). `get_performance()` is untouched and unused here. The math lives in
`ChallengeGoals.gd` (static, stateless, configured from tuning by `DynastyState`).

*Tier cost — two models, both capped at `MAX_TIER = 30`.* Four games use a **flat STEP**:
`tier = floor(get_score() / STEP)`, STEP = {Match Three 1000, Timing Bar 1, Catch the Money 2,
Balance the Books 2}. The two low-ceiling games use an **escalating per-tier cost** —
`tier_cost(tier) = min(base + floor((tier−1)/5) × increment, cap)`, and the score to REACH tier N is
the cumulative sum `tier_cost(1..N)`. Micro Basketball = base 1 / inc 1 / cap 5; Memory Match = base
0.2 / inc 0.2 / cap 1.0. `score_to_reach_tier()` is the single helper the UI uses (never `tier × STEP`,
which is wrong for the escalating games).

*Payout schedule (one schedule, shared by all six games).* A percent payout lands on every 5th tier,
alternating tracks and escalating: tier 5 +1% INCOME, 10 +1% LEGACY, 15 +2% INCOME, 20 +2% LEGACY,
25 +1% INCOME, 30 +1% LEGACY. So a mastered game = +4% income + +4% Legacy; six mastered ≈ 24/24%
(Tim's ~25/25 target). A global `challenge_bonus_scale` (1.0) scales both tracks. The bonus is a
FRACTION = summed whole-percent payouts ≤ cleared tier × bonus_scale ÷ 100.

*The two folds.* `total_income_bonus(highest_tiers)` and `total_legacy_bonus(highest_tiers)` sum each
game's cleared-tier payouts across `DynastyState.challenge_highest_tiers` ({game_key → int, raise-only,
in the dynasty save at `SAVE_VERSION 11`, so it survives prestige). Income folds into
`DynastyState.get_legacy_income_multiplier()` as `Family Fortune × (1 + total_income_bonus)` (once per
property); Legacy folds into `get_legacy_yield_multiplier()` as `Estate Lawyers × (1 + total_legacy_bonus)`
at the single `get_draft_will` site.

*Keep-alive run timer (built in `MinigameScreen`).* A run starts with `challenge_timer_start_seconds`
(6.0s; per-game override — Basketball 10.0s), drains 1 s/s, pauses while the game is busy, and each
point of `get_score()` gained tops it up by that game's `seconds_per_point`
(Match Three 0.012, Timing Bar 0.9, Memory 4.0, Basketball 3.5, Catch 1.5, Balance 2.0 — each a live
knob), capped at `challenge_timer_cap_seconds` (15.0s). Clock → 0 ends the run and credits the highest
tier reached (raise-only). This is the fail state (Memory Match is the exception: no timer — it ends on
a completed climb or a wrong tap).

*Miss penalty.* When a challenge game emits `Minigame.challenge_time_penalty(points)`, the host drains
the timer by `challenge_miss_penalty_ratio` (0.5) × points × `seconds_per_point`. Catch emits a dropped
coin's value; Timing emits 1.0 on a failed lock.

*Two persisted stores.* The **bonuses** read `DynastyState.challenge_highest_tiers` (cleared tier per
game, in the dynasty save). Separately, `ChallengeScores` still keeps each game's **best raw score** in
`user://challenge_scores.json` (independent of the dynasty save); `MinigameScreen` records it on run end
and converts it to the best tier for the `TIER {current}/{best}` readout (and the Minigame-Tuning review
screen's "Best: N"). The dev Reset wipes both.

*Configuration.* `ChallengeGoals.configure(tuning: TuningConfig)` takes the whole config object and is
re-pushed on every dynasty construction/load; every challenge knob (`challenge_*`, the two games'
`*_tier_*` escalating-cost knobs, all six `*_keepalive_seconds_per_point`, and the four Balance
challenge knobs) is a `TuningConfig` export in `tuning.tres`, editable from the Balance-Tuning screen.

*(History: Challenge Mode began 2026-06-30 as a Minigame-Tuning toggle for endless, reward-free
free-play with a per-type high score saved to `user://challenge_scores.json`. The free-play toggle is
retired; a run now also credits the dynasty's `challenge_highest_tiers` (the permanent bonuses). The
`challenge_scores.json` best-score store is still in use — see "Two persisted stores" above.)*

The same minigame host (`MinigameScreen`) serves **three sites** (GDD §5.5), each reusing the
universal multiplier for a different reward: this prestige round (scales Legacy), the welcome-back
round (scales the offline pile, §6), and First Contact (scales starting units on a new alien
property, §3.6). The host is reward-agnostic — it only emits the multiplier; the caller decides
what it scales and how it's worded. **Framing (2026-07-08):** the reward context (`make_reward`)
also carries a per-site `framing` string — one sentence of fiction on the Get Ready gate saying
WHY this round is happening (the heir proving themselves at succession; one bold move before the
overnight pile banks; opening terms with a new civilization). Hidden in Challenge Mode and the
review tuner.

**SHIPPED 2026-07-10 (was work item 4, planned 2026-07-07):** the neutral-standard-play outcome
curve above, landed together with the match-3 difficulty raise (bigger 7×6 board, cascade combos
removed for static per-match scoring, `match3_full_score` 600 / `match3_max_score` 2200 — a single
lucky chain can no longer max the round) and the cross-minigame **Legacy Bonus system**
(`Plans/Legacy_Bonus_System.md`): each minigame has a small game-specific chance at a bonus Legacy
gem worth `legacy_bonus_fraction` (0.1%) of lifetime-earned Legacy, gated by round result, min 1,
capped per round, ×10 at a First Contact site. All band numbers are TuningConfig exports.

Displayed as **brackets** (thresholds where legacy_gain crosses integers / named tiers); advisor announces bracket crossings. Total Legacy is dynastic and never spent down by conversion — Legacy *upgrades* cost Legacy per the upgrade table (content pass). The catalog includes **per-staffer retention** (GDD §6.3): spend Legacy to carry a property's staff ladder across the prestige reset **one LEVEL at a time** (2026-07-04 redesign), buyable up to the bloodline's ever-reached best on that property. *(Distinct from the "Loyal Staff" upgrade, which only discounts hire cost. Staff otherwise reset on prestige.)*

**Retention pricing (REPRICED 2026-07-07 — the "second prestige felt too big" fix):**
```
retention_cost(property, level) = ceil( retention_base_cost
                                        × retention_property_step ^ property_index
                                        × retention_cost_growth  ^ (level − 1) )
defaults: base 1.0 · property_step 1.5 · level_growth 1.25
```
The per-property term is the point: protecting a top earner costs like a top earner (ATM level 1 = 1 Legacy; Executive Assets level 1 ≈ 87). The old model — flat `ceil(1.0 × 1.12^(level−1))`, no property term — priced the ATM's staff like Executive Assets' and made deep retention near-free at a ~350-gem prestige. All three knobs are `TuningConfig` exports (`retention_*`) editable live from the Balance Tuning screen; `StaffRetention` stays tuning-free (DynastyState copies them in on construction and load).

### 9.4 Legacy application — spendable upgrade currency (sprint/residual RETIRED)
The automatic catch-up sprint + residual multipliers (`SPRINT_MULT = 1 + K_SPRINT × Legacy^BETA`,
`RESIDUAL_MULT = 1 + K_RES × brackets`) were **retired when Legacy became a spendable currency**:
the prestige reward is now gems the player spends on permanent upgrades in the Legacy shop
(`LegacyUpgradeCatalog.gd`), and those upgrades provide the per-generation acceleration the old
multipliers used to. `K_SPRINT` / `BETA` / `K_RES` no longer exist in TuningConfig.
- Each upgrade: `cost(level) = floor(base_cost × cost_growth^(level−1) × cost_multiplier)`, where
  `cost_multiplier` is the global 2.0 prestige-power brake (2026-07-14, §9.3).
- The catalog spans Wealth (Trust Fund, Family Fortune — the property-income multiplier applied at
  point of payment, §3.4), Operations (Efficiency Experts, Loyal Staff, Strong-Arm Tactics),
  Career/Labor (Old-Money Connections, Restless Hands, Piecework Bonus), Legacy (Estate Lawyers,
  Family Reputation), Frenzy (Killer Instinct, Second Wind), and — NEW 2026-07-16 — **Rush**:
  **Cooling Systems** (+0.01 cruise bonus/level, max 5, base_cost 6, growth 2.0; hard-capped at the
  old +30%) and **Rapid Restart** (−10% overheat lockout/level, max 5, base_cost 6, growth 2.0;
  additive with hard caps — a compounding limitation-remover runs away). See §4.1.
- Upgrade multipliers apply to property income (not wage — the wage is honest; the wage has its
  own Career/Labor upgrades instead).

## 10. Events — Schema-Ready Weather, Audit Dilemma

- **Cadence:** rolled per generation; expected ~1 event per 1–2 generations `TBD-SIM`. Events fire **only during active sessions** and their durations tick only while the app is open. Events never reduce an offline pile.
- **Delivery:** news splash (no decision) for weather onset; anything requiring a choice arrives as **mail** and waits indefinitely. The return ritual is never intercepted.
- **Schema (universal, from day one):** `{ id, eligibility, weight, choices[ { label, preview_formula, effects[] } ], duration, flavor }`. Weather = single choice ("Acknowledge"). No refactor needed when events gain options.
- **Launch set:** Market Crash (weather: capital income × CRASH_MULT 0.5 for CRASH_DUR active-minutes; wage unaffected — the joke is mechanical). Windfall (weather: instant grant scaled to net worth; narrator congratulates your work ethic). **The Audit (dilemma):** *Settle* (pay AUDIT_SETTLE 8% of net worth) vs. *Fight* (if Legislative Assets units ≥ AUDIT_THRESHOLD: case evaporates; else pay 3× settle). Previews shown honestly, including the player's current legislative count.

## 11. Data Schemas (config-driven content) `[ENG]`

Godot Resources (the 2022 ScriptableObject pattern, ported):
- **PropertyConfig:** id, name, BASE_COST, R0, base income_per_unit, base cycle_length, STAFF_COST rule, hero art ref. *(The per-property staffer name now lives in `EpochCatalog.gd` indexed by tier+property — the `.tres` `staffer_name` field is vestigial as of 2026-06-16.)*
- ~~**PlanetConfig**~~ — **superseded** by the epoch model (GDD §6.2): there are no distinct planet/market configs; epochs are rows in `EpochCatalog.gd` (civilization, economy_scale, staff multipliers) over one Earth-dollar economy.
- **LoanTier / TitleRow / LoopholeRow / LegacyUpgradeRow / EventDef:** per §§5–10.
- Earth's PropertyConfig values = GDD §4 table; R0 column = the one config value not recoverable from 2022 artifacts (the missing PropertyTypeConfigSO asset) — set provisionally and tune.

## 12. Tuning Table (single source of truth)

| Constant | Provisional | Status |
|---|---|---|
| LOGIC_HZ | 10 | [ENG] |
| RUSH_PCT | 10% of cycle | live (tuning.tres) |
| CYCLE_FLOOR | 1.0 s | TBD-SIM |
| BAND_STEP | 1.10 | live (2026-06-22 re-tune) |
| R0 (per property) | 1.09 all 52 rungs | live (2026-07-03) |
| STAFF_COST rule (Earth tier 1) | 50× unit cost @ band 1 | TBD-SIM |
| staff_cost_fraction / staff_cost_property_growth (alien anchors, exponent = staff price rank §6) | 0.01 / 1.4 | feel-tune (rank since 2026-07-15) |
| OFFLINE_EFF | 50% | TBD-SIM |
| OFFLINE_CAP base | 4 h | TBD-SIM |
| FRENZY_MAX_MULT | 5.6× | device-tuned (was 4×) |
| T_BURN | 30 s | device-tuned (was 90 s) |
| FRENZY_FILL / DECAY / IDLE_GRACE / POP_FLOOR | 0.4%/tap / 0.5%/s / 5 s / 15% | feel-tune M1 |
| rush heat build / overdrive build / bleed | 0.167 / 0.075 / 0.333 per s | live (§4.1) |
| rush hard ceiling / vent rate cruise–ceiling / approach | 1.60 heat / 0.7–3.4 win/s / 0.7 s | live (Vent Windows, §4.1) |
| rush bonus at hot / base peak / vent step / cruise | +30% / +55% / +30% per vent (unbounded) / +25% | live (Vent Windows, §4.1) |
| rush vent window dur / duration decay / lifts step / refractory | 1.0 s / 0.975 per tier (floor 0.45) / +1 per 3 tiers, cap 3 / 0.4–1.2 s | live (Vent Windows, §4.1) |
| rush vent gap_max / tap_max / grace / heat drop | 0.40 / 0.25 / 0.5 / 0.06 | live (Vent Windows, §4.1) |
| rush locked drain / re-arm / fail sting | 0.16 per s / 1.5 s / 0.0 (freeze is the penalty) | live (Vent Windows, §4.1) |
| ~~rush critical_start / ceiling_min–max / bonus_at_critical~~ | — | RETIRED (random ceiling + Critical band, §4.1) |
| EXEMPTION base / TAX_RATE base | $1M / 60% | TBD-SIM |
| LOOPHOLE_RATE_FLOOR | 5% | TBD-SIM |
| K_LEGACY / ALPHA / LEGACY_BASE (power curve) | 0.50 / 0.22 / $1k | feel-tune (Option C, 2026-07-14) |
| legacy_upgrade_cost_multiplier | 2.0 | feel-tune (Option C, 2026-07-14) |
| minigame keep_floor / full_performance / full_score / extra_score / duration | 0.9 / 0.5 / 100 / 200 / 25s | device-tuned 2026-07-09/10 |
| retention_base_cost / retention_property_step / retention_cost_growth | 1.0 / 1.5 / 1.25 | feel-tune (Balance Tuning; property term = staff price rank since 2026-07-15) |
| minigame extra bonus cap (Family Reputation) | 0.25 + 0.05/level | TBD-SIM |
| ~~K_SPRINT / BETA / K_RES~~ | — | RETIRED (Legacy is spendable, §9.4) |
| CRASH_MULT / CRASH_DUR | 0.5 / 10 active-min | TBD-SIM |
| AUDIT_SETTLE / AUDIT_THRESHOLD | 8% net worth / N units | TBD-SIM |
| Earth economy_target | $103.6T | confirm |
| Autosave cadence | 10 s + on pause/background | [ENG] |

## 13. Balance Simulator (deliverable, built M1–M2) `[ENG]`

- Headless build of the real game logic (same code, no rendering) + scripted player policies: **Optimizer** (greedy best-$/sec action) and **Rhythmic** (5 sessions/day, 3h gaps, plays like the audience of one).
- Outputs: time-between-meaningful-upgrades graph (the anti-pillar metric), total week length, milestone reachability per property per generation, band-wall detection (hard fail), sprint-duration per generation ("speeds up every time" verification), estate/Legacy growth curves.
- Doubles as the in-game projection engine for the Estate Planning tab (§9.4).

## 14. Screen Inventory `[ENG]`

Main (ladder, wage button, frenzy bar, income/sec hero stat, backdrop) · The Ledger · Estate Planning (draft will) · Family Ledger · Mail · Welcome Back (two beats) · Obituary/Will ceremony · Origin flow · Final Dollar sequence (4 beats) · Settings. Navigation map: M1 contains Main only; others land with their milestones.

**Navigation — bottom tab bar (proposed 2026-06-22, UI Notes §7):** the persistent surfaces become four bottom-pinned, icon-only (SVG) tabs — **Property** (ladder/wage/frenzy/hero), **Estate Planning** (draft will + prestige + Estate Office), **Settings** (minigame opt-out, later audio/haptics/dev), **Family Ledger**. Modal beats (Will ceremony, First Contact, Welcome Back, the minigame) still take over the full screen above the bar, not as tabs.

## 15. Open Items (content pass / later decisions)

1. Estate valuation rule (book value vs. alternatives) — validate in simulator (§9.2).
2. Title table; loophole catalog; Legacy upgrade catalog; loan tier table; (Hon.) title list; staffer names — content pass, M2–M3.
3. R0 per property; all TBD-SIM constants — simulator pass.
4. Earth canonical figure ($103.6T) — confirm.
5. Family Office upgrade ladder (cap/efficiency steps).
6. Heir-status pressure thresholds & copy.
7. ~~Planet/Market Two config~~ — superseded by epochs (`EpochCatalog.gd`); flesh out more alien epochs/rows, M3–M4.
8. **Pacing re-tune after the AdCap milestone cadence (§3.1) — PARTIALLY ADDRESSED 2026-06-22.**
   The 25/50/100/200/300/400 cadence ran the economy ~38% slower than `20×2^k`. Re-tune pass:
   **`BAND_STEP` 1.15 → 1.10** (cheaper high-band units; affects only band 1+/25+ units, so it
   does NOT touch the early self-funding guardrail). Sim result: gen-1 peak $9.2M → **$11.1M**
   (baseline $12.1M, ~8% under), top income/sec $55M → **$68M/s**, 6-gen Legacy 42 → 46
   (baseline 51); dynasty still "speeds up every time", no band-wall. `K_LEGACY` was probed at
   0.65 and **reverted** — extra Legacy didn't lift the wealth trajectory (the sim's greedy
   upgrade-buyer spent it ineffectively) and it disturbs the tuned prestige feel; per-generation
   income, not Legacy quantity, is the bottleneck. **Residual:** the 6-gen wealth trajectory
   still trails baseline (~$101M vs $195M at gen 6) because the cadence's lost milestone
   generosity compounds; closing it fully would mean reverting the cadence or deeper cost cuts
   that distort the curve. Accepted as "most of the gap closed"; revisit if on-device feel needs it.
