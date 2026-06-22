# American Tycoon — Mechanics Specification

**Version:** v0.1
**Date:** June 12, 2026
**Companion to:** GDD v0.2 (theme, vibe, systems intent). This document contains the math. Where the two conflict, this document wins on mechanics; the GDD wins on tone.
**Conventions:** Constants in CAPS live in §12 (Tuning Table). `TBD-SIM` = provisional value, validated/tuned by the balance simulator. `[ENG]` = engineering recommendation, not yet player-approved design — veto on review.

---

## 1. Currency & Numbers

- **Per-planet currency scale.** Each planet's economy resets the displayed scale (GDD §3); Earth's full arc fits comfortably in double precision (~$1e14 target vs. ~1e15 safe integer threshold). `[ENG]` Implement a `Money` wrapper type from day one (internally double for Earth) so a later mantissa+exponent backend for large planets is a drop-in, not a refactor.
- **Display:** real-dollar formatting throughout — `$#,##0` below $1M; named suffixes above ($14.27M / B / T). Never scientific notation, never "quadragintillion" (GDD §2).
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
- `R0_i` per property from config (genre-gentle, ~1.05–1.10 `TBD-SIM`).
- `BAND_STEP` global (provisional 1.15 `TBD-SIM`).
- Steepening applies only *after* each milestone is crossed — milestones stay reachable by construction.
- **Simulator guard (hard requirement):** no reachable game state may exist where every property is band-walled and no action is affordable (GDD §0.1).
- Bulk-buy costs = exact sum of per-unit costs (fixes the 2022 MAX double-count bug). Buttons: **+1 / +10 / +to-next-milestone / MAX** (GDD §3.1).

### 3.3 Milestone reward — adaptive
On crossing each milestone, the property receives, in priority order:
```
if cycle_length / 2 ≥ CYCLE_FLOOR:  cycle_length ÷= 2     (speed mode)
else:                               income_per_unit ×= 2   (income mode)
```
`CYCLE_FLOOR = 1.0s` (provisional `TBD-SIM`). Every property follows the arc *first it gets faster, then it gets richer*; conversion point is emergent per property (ATM converts almost immediately; political assets accelerate visibly for most of the game).

**Base cycle-length rework — IMPLEMENTED 2026-06-22 (moderate stretch, back half only).** Tiers
**1–6 unchanged**; tiers **7–12 stretched** ~1.5×/tier to a **180s** top (Day Trading 24 ·
Flipping 36 · MLM 54 · Hedge Fund 81 · Legislative 121 · Executive 180). **Income-neutral:** each
stretched tier's `base_income_per_unit` was scaled up by the same factor as its `base_cycle_length`,
so base income/sec (= income_per_cycle / cycle_length) is unchanged — only the cadence changes
(longer waits, bigger lump sums, more speed-up halvings before the 1s floor). The fix is purely in
`game/config/properties/07..12*.tres`; no formula change. (GDD §4's cycle column is now historical.)

### 3.4 Income
```
income_per_cycle(i) = floor( units_i × income_per_unit_i )   [2022 formula, preserved]
income_per_sec(i)   = income_per_cycle(i) / cycle_length_i   [for display & offline math]
```
Global multipliers (frenzy §7, sprint/residual §9.4, event modifiers §10) multiply income at point of payment.

### 3.5 Per-property UI
Milestone progress slider per property: min = last milestone, max = next (recovered 2022 design, kept — it feeds the return spike: "the pile can push me over 40").

## 4. Tapping (Active Layer 2)

- **Start verb:** a tap on an idle, unstaffed property starts its cycle (2022 verb, preserved). Cycles pay on completion; unstaffed cycles stop after paying.
- **Rush verb:** a tap on a *running* cycle advances it by `RUSH_PCT × cycle_length` (provisional 5% — ~20 taps completes any cycle at any altitude). Percentage, never fixed seconds: this is what makes tapping auto-scale with capital.
- Both verbs feed the frenzy meter (§7) and the dynastic tap count (§5).

## 5. Wage Ladder (Active Layer 1) — Hybrid Credentials

- Tap anywhere-defined wage button: pays `wage(title)` per tap. The button is **never removed** (GDD §5).
- **Promotion requires both:** `dynastic_lifetime_taps ≥ TAP_THRESHOLD(title+1)` **and** payment of `TUITION(title+1)`.
  - Tap count is **dynastic** — persists across generations and planets ("Work Ethic", a Ledger stat).
  - Eligibility is announced; claiming is a purchase (the credential gag — GDD-tone copy per title).
- **(Hon.) titles:** cash-only honorary titles purchasable at any time at obscene prices; grant **zero wage change**; rendered with "(Hon.)" in the Family Ledger, which refuses to respect them.
- Title table (thresholds, tuitions, wages, names) is a content-pass deliverable — schema in §11. Wage values tuned so the track is dominant for the first ~2–3 minutes of generation 1 and a rounding error thereafter.
- First tuition (~$50) deliberately competes with the second ATM — the game's one "invest in yourself vs. assets" beat.

## 6. Staffing & Offline (merged system)

- **Hire / upgrade (epoch-keyed, updated 2026-06-16):** staffing is a **per-property tier track**, not a one-time switch (GDD §6). `staff_tier` per property: `0` = unstaffed, `1` = Earth staffer (auto-start + auto-collect forever — the old "hired" behavior), `2+` = the alien staffer unlocked once the run reaches that epoch (§6.2). Each tier carries `staff_income_multiplier` (Earth = 1.0; alien tiers are large jumps), applied at point of payment alongside frenzy/Legacy. **Cost (reworked 2026-06-17):** the Earth staffer (tier 1) keeps its small property-scaled cost (≈50× band-1 unit cost × Legacy discount); **alien tiers (2+) are anchored to the target epoch's whole economy** — `earth_economy_target × economy_scale(tier) × staff_cost_fraction × growth^property_index` — so they cost ~1000× more each epoch and you cannot afford the next epoch's staff the instant you make contact (you must earn into the new economy; saved cash carries over). You can only reach a tier whose epoch the run has reached. Tap-rush remains additive at any tier ≥ 1. Data table: `EpochCatalog.gd`; state: `EpochState.gd`.
- **Offline accrual draws from staffed properties only:**
```
offline_rate  = Σ(staffed i) income_per_sec(i) × OFFLINE_EFF
offline_pile  = floor( offline_rate × min(elapsed_seconds, OFFLINE_CAP) )
```
- `OFFLINE_EFF` provisional 50% `TBD-SIM`; `OFFLINE_CAP` base 4h, extended by Family Office upgrades (ladder TBD content pass).
- **The first hire is the offline unlock** — no separate Property Manager purchase. Family Office = the upgrade institution for cap/efficiency.
- Frenzy, sprint, and event modifiers do **not** apply offline (offline is its own reduced-efficiency channel; keeps active play strictly superior).
- Welcome-back: two-beat ritual per GDD §3.1; pile stat line *Hours worked: 0* sourced from wage-tap count during absence (always 0, by construction — the joke is load-bearing and free).

## 7. Frenzy (Active Layer 3) — One Bar, Two Modes

State machine: `FILLING ⇄ BURNING`.

**FILLING:** meter M ∈ [0,1]. Each tap (any verb) adds `FRENZY_FILL`. After `IDLE_GRACE` seconds without taps, M decays at `FRENZY_DECAY`/s. Pop available at M ≥ `POP_FLOOR` (0.15).

**On pop:** multiplier locks at `1 + (FRENZY_MAX_MULT − 1) × M` for the entire burn (never decays mid-burn). Bar switches to BURNING.

**BURNING:** the bar *is* the timer — drains at constant rate `1 / T_BURN` per second (full bar burns in T_BURN seconds; a 60% pop has 60% of the bar to drain, hence duration scales with charge by construction). Taps perform their normal verbs but feed nothing into the meter; decay is suspended. At M = 0: multiplier ends, state returns to FILLING from empty.

- Frenzy multiplier applies to **all income** (properties + wage).
- Pop button always previews live value: "×2.4 for 38s" (house rule: every irreversible decision shows its reward first).
- Provisional constants: FRENZY_MAX_MULT 4×, T_BURN 90s, FRENZY_FILL 0.4%/tap, FRENZY_DECAY 0.5%/s, IDLE_GRACE 5s — all `TBD-SIM`/feel-tuned in M1.

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

### 9.3 Legacy conversion (root function, bracket display)
```
legacy_gain = floor( K_LEGACY × log10(estate_net / LEGACY_BASE) ^ ALPHA )   K=0.5 ALPHA=2 LEGACY_BASE=$1k
```
(`estate_net` here is the post-tax net of the §9.2 waterfall, whose gross is lifetime cash earned
this generation — not net worth at death. **Reworked 2026-06-17 from a plain power curve:** the old
`K × estate_net ^ 0.5` minted absurd Legacy at real trillion-dollar scale — a single 20T run gave
~16k, enough to buy out the whole shop. The log curve compresses the whole range to a sane handful
— ≈ $1B→18, $8T→49, $1Q→72 — and nothing converts below the `LEGACY_BASE` floor.)
**Prestige minigame multiplier (GDD §5.5; built 2026-06-22 as match-3).** The prestige
minigame scales how much of the converted award is **kept**:
```
legacy_awarded = floor( legacy_gain × MINIGAME_MULT )
MINIGAME_MULT = keep_floor          at score 0   (also what Skip / opt-out banks)
              → 1.0 (full)          at score ≥ minigame_full_score
              → 1.0 + bonus_max     at score ≥ minigame_extra_score
bonus_max = LegacyUpgrades.minigame_bonus_max()  = 0.25 + 0.05 × Family Reputation level
```
`legacy_gain` (the log curve above, × Estate Lawyers yield) is the **base**. Unlike the
2026-06-21 first pass, this is **NOT upside-only** — a poor round (or a skip) keeps less than
the base (floor 0.5 = half), which is what gives the minigame stakes; a great round overfills
into the extra-high bonus. Tuning: `minigame_keep_floor` 0.5, `minigame_full_score` 100,
`minigame_extra_score` 200, `minigame_duration_seconds` 30 (all `TBD-SIM`, dev-panel editable);
the extra bonus cap is the Family Reputation upgrade (LegacyUpgradeCatalog). Governed by the
persisted `GameState.ui_minigame_enabled` (default mandatory). Applied in
`DynastyState.perform_succession(cause, minigame_multiplier)`, floored, clamped ≥ 0.

Displayed as **brackets** (thresholds where legacy_gain crosses integers / named tiers); advisor announces bracket crossings. Total Legacy is dynastic and never spent down by conversion — Legacy *upgrades* cost Legacy per the upgrade table (content pass). The catalog includes **per-staffer retention** (GDD §6.3): spend Legacy to keep a specific property's staffer at its tier across the prestige reset, so the heir starts pre-staffed there. *(This is distinct from the existing "Loyal Staff" upgrade, which only discounts hire cost. Staff otherwise reset on prestige.)*

### 9.4 Legacy application — catch-up sprint + residual
```
SPRINT_MULT   = 1 + K_SPRINT × Legacy ^ BETA          (provisional BETA 0.5, K_SPRINT TBD-SIM)
active while:   heir net_worth < predecessor_peak_net_worth
RESIDUAL_MULT = 1 + K_RES × brackets_attained          (permanent, after sprint ends)
```
- "Predecessor's peak position" = **peak net worth of the immediately preceding generation** (provisional definition `TBD-SIM`; simulator validates against multi-generation decay cases, e.g., post-bankruptcy heirs).
- Estate Planning tab's headline projection — *"your heir reaches your current position in N minutes"* — is computed by the simulator core running headlessly in-game with SPRINT_MULT applied (§13).
- Sprint/residual multiply all property income (not wage — the wage is honest).

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
| RUSH_PCT | 5% of cycle | TBD-SIM |
| CYCLE_FLOOR | 1.0 s | TBD-SIM |
| BAND_STEP | 1.15 | TBD-SIM |
| R0 (per property) | 1.05–1.10 | TBD-SIM |
| STAFF_COST rule | 50× unit cost @ band 1 | TBD-SIM |
| OFFLINE_EFF | 50% | TBD-SIM |
| OFFLINE_CAP base | 4 h | TBD-SIM |
| FRENZY_MAX_MULT | 4× | feel-tune M1 |
| T_BURN | 90 s | feel-tune M1 |
| FRENZY_FILL / DECAY / IDLE_GRACE / POP_FLOOR | 0.4%/tap / 0.5%/s / 5 s / 15% | feel-tune M1 |
| EXEMPTION base / TAX_RATE base | $1M / 60% | TBD-SIM |
| LOOPHOLE_RATE_FLOOR | 5% | TBD-SIM |
| K_LEGACY / ALPHA / LEGACY_BASE (log curve) | 0.5 / 2 / $1k | feel-tune |
| minigame keep_floor / full_score / extra_score / duration | 0.5 / 100 / 200 / 30s | TBD-SIM |
| minigame extra bonus cap (Family Reputation) | 0.25 + 0.05/level | TBD-SIM |
| K_SPRINT / BETA / K_RES | tune / 0.5 / tune | TBD-SIM |
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
