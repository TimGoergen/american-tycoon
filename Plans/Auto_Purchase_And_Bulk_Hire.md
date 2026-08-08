# Auto-Purchase Mode & Bulk Hire — Implementation Plan

> ⚠️ **PARTLY SUPERSEDED — read `Plans/Auto_Purchase_Restructure.md` first (2026-08-07/08).**
>
> The features shipped, but the buying rule and the upgrade shape in **Part A** were rebuilt, and
> **Part B's** Head Hunters track was deleted outright. What this doc still describes correctly is
> the *reasoning*: why the two features ship together, the rush-lockout argument (§A5, unchanged and
> device-confirmed), and the retention UX work.
>
> **What is WRONG here now:**
>
> | This doc says | The game does |
> |---|---|
> | Buys **N units each of the X cheapest** properties — an N × X grid | Makes **one number** of single-unit purchases, each taking whatever is cheapest at that instant, re-priced between every purchase |
> | Targets the **last-viewed civ tab**, read from the saved `ui_epoch_tab` | Targets the **tab currently on screen** (Main's live `_epoch_tab`) |
> | **Never buys the cohort flagship** — a structural pacing guard | No flagship exclusion. `auto_advance` is off, so leaving an era is always the MAKE CONTACT tap; the exclusion only ever stopped the desk *satisfying* the 35-unit gate |
> | One **Acquisitions Desk** track, 8 levels, level 1 unlocks the mode | A separate **unlock**, plus **Buying Power** (purchases per round) and **Standing Orders** (cadence) — both requiring the unlock |
> | **Head Hunters** gates bulk hire | Deleted. Bulk hire is free for everyone |
>
> Its "Open decisions for Tim" section is also closed — see the restructure plan §0.1.

Graduates **Roadmap §7** (auto-property-purchase via a Legacy upgrade) and **Roadmap §2/§3**
(bulk hire, bulk staff retention) into a build. Branch: `feature/auto-purchase-and-bulk-hire`.

Both features remove taps. They ship together on purpose: auto-purchase automates *property*
buying, which would leave staffing as the only remaining button-masher and make the imbalance
more obvious, not less.

Every design decision in Roadmap §7 is Tim's and is carried forward unchanged unless this
document says otherwise under **Corrections to the Roadmap** or **Open decisions**.

---

## Corrections to the Roadmap (found while mapping the code)

Three assumptions in the Roadmap entry do not match the shipped code. Each is small, but each
would have produced a wrong implementation if taken at face value.

1. **The last-active civ tab is NOT persisted.** Roadmap §7 says "the pager already tracks
   [it] for its own navigation", which is true within a session — `Main._epoch_tab`
   (`Main.gd:73`) — but nothing writes it to the save. On every launch the pager opens at
   `_epoch_default_tab()` (`Main.gd:912`) = the *deepest unlocked* tab. Left alone, a player
   who parked auto-purchase on an early epoch would find it re-aimed at the frontier after
   every app restart — the opposite of the "point it at an era" control the design is built
   around. **This plan persists it** (see §A4).

2. **"Rush is unavailable" cannot mean refusing `tap_property` outright.** The same core
   verb both *rushes a running cycle* and *starts an idle one*
   (`GameState.tap_property`, `GameState.gd:277`). A blanket refusal would stop players
   restarting stopped cycles, which is a core interaction and not what the design asks for.
   The lockout must refuse only the rush branch (§A5).

3. **`EpochCatalog.tier_count()` is 27**, so a tier-1 property's staff ladder caps at
   20 × 27 = 540 levels. (Recorded because the retention pain-point arithmetic below depends
   on it.)

---

## Part A — Auto-Purchase Mode

### A1. What the player gets

A Legacy upgrade, **Acquisitions Desk**, unlocks a persistent ON/OFF mode. While it is on:

- Every *cadence* seconds, the game buys **N units each of the X cheapest properties it can
  afford on the currently-targeted civ tab**.
- **Rush is unavailable.** That is the price, and it is what keeps the mode a genuine
  strategic posture rather than a straight upgrade (Roadmap §7).
- It keeps running while the player is on the Estate / Ledger / Settings tabs, still against
  the last civ tab they chose. It stops only while the economy is frozen.

### A2. The buy rule (Roadmap §7, decided by Tim)

Each tick, against the targeted tab only:

1. Collect that tab's property indices — `EconomyState.get_property_indices_for_unlock_tier(tab + 1)`
   (`EconomyState.gd:189`; tab N ⇔ `unlock_tier == N + 1`, per `Main._epoch_tab_of`, `Main.gd:895`).
2. **Drop the flagship** — `EconomyState.get_flagship_index_for_unlock_tier` (`:178`).
3. Drop anything not unlocked (`EconomyState.is_property_unlocked`, `:139`) or not affordable
   for at least one unit (`cash >= prop.get_next_cost()`, `PropertyState.gd:149`).
4. Sort the survivors by **current next-unit cost, ascending**. Take the cheapest X.
5. For each, buy `min(N, max_affordable)` units, deducting as you go, then re-check the next.

**Why the flagship is excluded explicitly rather than left to fall out of the ranking.**
Since Roadmap §7, the epoch advance for tiers 3+ requires owning 35 units of the cohort
flagship (`EpochState.gd:16-18`), and that stacking phase exists precisely to give the
flagship playtime. "X cheapest" already misses the flagship as long as X < 14 — but that is a
consequence of a tuning value, not a guarantee. An explicit exclusion by flagship index makes
it structural, so a later increase to X cannot silently automate the pacing gate away. This is
the constraint Roadmap §7 says any future change to the buy rule must keep clearing.

**Buy `min(N, max_affordable)`, not `N` flat.** `GameState.try_buy(i, count)` is all-or-nothing
— it prices the whole block via `get_bulk_cost` and refuses if cash falls short
(`EconomyState.gd:148`). Asking for a flat N would make the mode do *nothing* whenever the
player can afford 5 of 8 units, which reads as broken. `PropertyState.get_max_affordable`
(`:172`) already computes the honest number using the same rounding as the cost curve.

**Re-rank every tick, never cache.** Hammering the cheapest rung raises its price
(`r0` escalation, `CostCurve.gd:80`) until another rung becomes cheapest, so the mode spreads
across the low end on its own instead of tunnelling into one row. That self-balancing property
is a consequence of ranking by *current* cost, and is lost if the ranking is cached.

### A3. Cadence, breadth, depth

| axis | symbol | value |
|---|---|---|
| breadth — distinct properties per tick | X | fixed at 3 |
| depth — units per property per tick | N | = upgrade level (1…8) |
| cadence — seconds between ticks | — | `3.0 − 0.25 × (level − 1)`, floored at 1.0s |

Throughput is X × N ÷ cadence, so the two moving axes multiply: 1 unit/sec at level 1 to
19.2 units/sec at level 8. That spread is deliberately modest against a cohort spanning
2^13 = 8192× from cheapest to flagship — even at full tilt the drain on the low end is a
rounding error against one flagship unit, which is what keeps the mode from starving the
purchase the player is actually saving for.

X stays fixed because a cohort is only 14 properties, so breadth saturates almost immediately
and stops being a purchase worth making (Roadmap §7).

**Empty ticks do not burn the cycle.** If nothing is affordable, the accumulator is *not*
reset — it stays pinned at the threshold so the mode fires the instant something becomes
affordable, and only then restarts the wait. Clamped at one cadence so it cannot bank credit.

### A4. Code shape

**New: `game/scripts/core/AutoPurchaseState.gd`** (`class_name AutoPurchaseState`) — headless
policy, no scene tree, per the `scripts/core/` contract. Holds `enabled`, the tick accumulator,
and the ranking + buying logic. Signature:

```gdscript
func tick(delta: float, game: GameState, tab: int, cadence: float, units: int, breadth: int) -> int
```

returning the number of units bought (0 on an idle tick), so the sim harnesses can assert on it.

Keeping the policy here rather than in `Main` is what makes it verifiable headlessly. Note the
Roadmap's warning: `Sim._greedy_build_out` (`sim/Sim.gd:335`) is the proven *plumbing*, but its
*policy* is global and allocates perfectly. Borrow `try_buy`; do not borrow the strategy.

**Driven from `Main._process`**, immediately after the fixed-timestep economy loop
(~`Main.gd:266`). This placement is load-bearing: `_process` already returns early on
`modal_up` (`Main.gd:255`), so the mode inherits the frozen-economy rule for free and no second
freeze condition gets invented. A standalone `Node` (the `CarbAutopilot.gd:47` shape) would
*not* inherit it and could tick purchases away behind the Will screen.

**Tab persistence.** `GameState.ui_epoch_tab` beside `ui_buy_mode` (`GameState.gd:69`), saved
(`:510`) and loaded (`:546`) the same way, clamped on load to `_epoch_tab_max()`. `Main._set_epoch_tab`
(`:1167`) writes it. Worth having on its own merits — the pager reopening where you left it is
good behaviour independent of this feature.

**Upgrade track** — one dict appended to `LegacyUpgradeCatalog.UPGRADES` (`:66-217`):

```
id "acquisitions_desk", category "Operations" (existing — no _category_color edit needed),
max_level 8, base_cost 12, cost_growth 2.2, effect_per_level 0.25
```

Plus a `describe_effect` case (`LegacyUpgradeCatalog.gd:284`) — without one the card's effect
line renders blank — and two getters on `LegacyUpgrades.gd`: `auto_purchase_unlocked()` and
`auto_purchase_cadence_scale()`. No save migration is needed: an absent id reads as level 0
(`LegacyUpgrades.gd:222-237`).

**Tuning knobs** (hard rule: no tuning constants in code) — new `@export`s on `TuningConfig.gd`
and values in `tuning.tres`: `auto_purchase_base_cadence = 3.0`,
`auto_purchase_min_cadence = 1.0`, `auto_purchase_breadth = 3`. Per-level *magnitudes* stay in
the catalog, which is where `TuningConfig.gd:523-525` says they now belong.

### A5. The rush lockout

**Core refuses, UI grays** — the house split (`Plans/Overdrive_Vent_Windows.md`). Guard the
rush branch of `GameState.tap_property` (`:277`) and `hold_rush_property` (`:315`), and
`engage_rush_overdrive` (`:429`). Starting an idle cycle stays allowed (see Correction 2).

**Heat decays normally; it does not idle.** Roadmap §7 guessed heat "should presumably idle
rather than decay-punish" but flagged it as needing a check against `Plans/Rush_Overheat.md`.
That check says idle is wrong, for three reasons:

- The system's binding invariant is *"whatever the bar shows IS what the player earns"*
  (`Overdrive_Vent_Windows.md:528-596`). Heat idling at a non-zero fill while nothing is being
  rushed means the bar shows a bonus the player is not being paid — the exact desync Tim caught
  on device.
- Idling would make toggling auto-buy on a way to **park a bonus indefinitely**, against
  `Rush_Overheat.md:63` ("the true cost is the full rebuild climb from zero").
- Stopping is already non-punitive: the release edge captures `_retained_peak_bonus` and pays a
  spin-down tail all the way to zero (`RushMomentumState.gd:353-360`). Turning auto-buy on
  simply *is* "the player let go", and the existing tail handles it correctly and generously.

So: no new state in `RushMomentumState`. The mode just stops feeding it `rushing = true`, and
the shipped spin-down does the rest. Toggling off must not resurrect a stale
`_retained_peak_bonus` (`Overdrive_Vent_Windows.md:560-563`) — resuming rush already clears it.

**Where the reason is shown.** Not per-row. `Overdrive_Vent_Windows.md:375-391` records that a
*global* rush shutdown painting every row read as the whole tab being dead. So:

- `MomentumBar` status label (`MomentumBar.gd:576-601`) carries the reason: **AUTO-BUY ON**.
- OVR button grays in place with its existing disabled plate (`MomentumBar.gd:247-254`).
- Portrait discs take the existing uniform rush-lockout dim (`PropertyRow.gd:993-994`), no
  banner.

Nothing hides or moves. A finger already holding a rush when the mode is switched on must not
flicker (`Overdrive_Vent_Windows.md:344-347`).

**One trap:** the `overdrive` tutorial tip fires on `not get_overdrive_button().disabled`
(`Main.gd:314-316`). A permanently-disabled OVR button would silently suppress it forever. That
tip must ignore the auto-buy lockout.

### A6. The toggle

A sibling toggle beside the existing buy-mode button (`Main.gd:774-786`), visible from the
start and **grayed in place** with "unlocked in the Estate" until the upgrade is owned — the
no-moving-UI rule, and the same treatment the Roadmap specifies for Challenge Mode's gate.
Persisted like `ui_buy_mode`/`ui_minigame_enabled` in the GameState save dict.

The buy rule must be stated plainly in the upgrade's own description — "a mode that spends the
player's money on a rule they cannot see reads as a bug" (Roadmap §7).

### A7. Offline

Auto-purchase does **not** run while the app is away. Offline is its own banked-pile system,
and a mode that spent the pile before the player saw it would undermine the welcome-back beat.
Roadmap §7 lists this as unspecified; this is the answer, stated explicitly as it asks.

---

## Part B — Bulk Hire & Bulk Retention

### B1. The pain being fixed

Staff hiring is **one level per tap**. `PropertyRow._on_hire_pressed` (`:1428`) →
`GameState.try_buy_staff_level` (`:466`) → one `staff_level += 1` (`PropertyState.gd:247`).
Hold-to-repeat exists at 10/sec (`PropertyRow.gd:859`) and is the only bulk affordance.

Retention is worse — one level per tap per property, across up to 326 property rows, each with
its own ceiling of up to 540 levels, at a 0.35s hold repeat (`LegacyScreen.gd:50-51`), **and a
full save file write per level** (`Main.gd:2233`). A modest deep run (12 Earth properties at
LVL 150) is already ~1,800 repeats across 12 separate buttons. That is Tim's "way too many
buttons to press", quantified.

### B2. Bulk hire (Earth $)

A **HireMode** mirroring the shipped `BuyMode` pattern exactly (`PropertyRow.gd:14`):
`ONE, TEN, MAX`.

> **A `BLOCK` mode (buy to the next 20-level staffer boundary) shipped first and was REMOVED
> 2026-08-01 on Tim's review.** It was the staff-side analogue of `NEXT_TIER`. Because it was
> deleted rather than replaced, MAX moved down into its ordinal (3 → 2) and saves written while
> it existed are clamped into range on load (`GameState.load_save_dict`), landing an old BLOCK
> or MAX on the new MAX. Its core helper `get_staff_levels_to_next_block` was deleted with it.

New core APIs beside `get_next_staff_level_cost` (`EconomyState.gd:244`):

- `get_bulk_staff_level_cost(prop_index, count, reached_tier) -> float`
- `get_max_affordable_staff_levels(prop_index, reached_tier, cap) -> int`
- `try_buy_staff_levels(prop_index, count, reached_tier) -> int` (returns levels actually bought)

These must respect **block boundaries** — the per-level price depends on position within the
block and the block's anchor, which is frozen at the block's own epoch
(`EconomyState.gd:213-217`) — and stop at `get_staff_level_cap` (`:263`). Costs are sequential
and path-dependent, so this is a loop, mirroring `CostCurve.get_bulk_cost` (`:93`) rather than
a closed form.

Gated by a new capped track, **Head Hunters** (`head_hunters`, category "Operations",
max_level 2): L1 → ×10, L2 → MAX. Each level unlocks exactly one bulk mode, so `max_level` is
simply how many modes exist — it dropped from 3 with the BLOCK removal above, and must rise
again in step if a mode is ever added back, or the top level would buy nothing.

This gating is clean — unlike Roadmap §1's buy-MAX collision, staff hiring has no bulk mode
today, so it is a genuine gift rather than a take-away.

### B3. Bulk retention (gems)

`DynastyState.buy_staff_retention_levels(property_index, count) -> int` beside the existing
single-level `buy_staff_retention` (`:218`), plus a **RETAIN MAX** affordance per row.

**The button label is the spend preview** — "RETAIN TO LVL 150 · 4.2B Gems" — computed before
commit. Roadmap §3's caution is the reason: retention is the endgame's open gem sink, bought
with the same currency as everything else, so one tap must never silently drain a fortune. A
label that states the total makes the preview unmissable rather than a second confirm step.

**Move the save out of the loop.** `Main._on_retain_requested` currently writes the whole save
file per level (`Main.gd:2233`); a bulk buy must write once at the end. The in-place row-update
path (`LegacyScreen.gd:631-646`) exists so a held button is not freed mid-hold and must be kept.

**Recommendation: ship retention bulk-buy UNGATED**, not behind a Legacy track. Roadmap §3
upgrades it from a UX fix to a prestige reward, which is better *framing* for the same work —
but retention is bought with gems, so gating it means selling a gem-spend convenience for gems,
and more importantly it means charging the player to fix a usability defect Tim reported as a
defect. Head Hunters gates *hire* modes, which are new value; the retention fix ships free.
Flagged as an open decision below.

---

## Open decisions for Tim

Each has a recommendation, and the plan implements the recommendation unless Tim says otherwise.

1. **Rush lockout: heat decays (recommended) vs. idles.** §A5 argues decay, overturning the
   Roadmap's tentative "should presumably idle". This is the one place this plan contradicts
   the Roadmap on a gameplay-feel question, so it is the one most worth a device check.
2. **Retention bulk-buy gated or free.** Recommendation: free (§B3).
3. **Upgrade costs.** `acquisitions_desk` at base 12 / growth 2.2 and `head_hunters` at
   base 8 / growth 2.4 are proposals sized against the existing utility tracks
   (`seed_capital` 1/1.8 … `estate_lawyers` 10/3.8); they are unmodelled by any sim and want a
   device pass.
4. **N caps at 8 (level 8).** Chosen so max throughput stays a rounding error against a
   flagship unit. If it feels too slow on device the cap is the knob to move, not X.

---

## Verification

- Parse-check every touched script headlessly.
- Extend `sim/` rather than adding a new harness (permanent tooling, per the project memory):
  an auto-purchase case asserting (a) the flagship is never bought, (b) purchases stay on the
  targeted tab, (c) an unaffordable tick buys nothing and does not bank credit.
- Re-run `MoneyTest` + `EpochTest` — the flagship exclusion must leave epoch advance timing
  untouched.
- `git restore game/project.godot` after any editor import (the import rewrites it).
- Device pass by Tim for the four open decisions, especially the rush lockout feel.
