# Challenge Mode — Design of Record

**Last rewritten:** 2026-07-20 (authored-ladder redesign; supersedes the 2026-07-20 scoping draft).
**Status:** phased build in progress. **This document is the single source of truth** — it describes
the CURRENT design, not the history. (The earlier geometric diminishing-returns model is gone; see
§7.)

Challenge Mode is a discoverable, player-facing progression laid over the six minigames. Each game has
its own tier ladder; clearing tiers grants small, permanent, dynasty-wide bonuses on two tracks
(property income and Legacy yield). The bonuses survive prestige. A run is a short keep-alive push:
the clock starts low, drains, and is topped up by scoring — when it hits zero, the run ends and your
best tier is banked.

---

## 1. The run: a keep-alive timer (Wave 2 mechanic)

A challenge run is NOT endless. It is a keep-alive push:

- The run starts with a small time budget — `challenge_timer_start_seconds` (default **6.0s**).
- The clock **drains** in real time while you play.
- **Scoring tops the clock up**: each point the game's `get_score()` gains adds
  `seconds_per_point(game)` seconds (per-game table, §4).
- Top-ups are **capped** at `challenge_timer_cap_seconds` (default **15.0s**) — a hot streak can't
  stockpile an unlimited cushion.
- The clock **pauses while the game is busy** (mid-animation / resolving), so you're never drained by
  time you can't act in. (Reuses each minigame's existing `is_busy`-style gate — Wave 2 wires this.)
- When the clock reaches **0, the run ends**. The highest tier the run reached is credited (raise-only).

The run's tension is "keep scoring fast enough to stay alive"; the reward is how deep a tier you bank
before the clock runs out. **The timer mechanic itself is built in Wave 2** (in `MinigameScreen`); the
core wave (this one) only exposes the tuning data it reads:
`ChallengeGoals.timer_start_seconds()`, `timer_cap_seconds()`, and `seconds_per_point(game_key)`.

---

## 2. The tier ladders (authored, finite)

A game's **tier** is a plain round checkpoint on its raw `get_score()`:

```
tier(game, score) = floor(score / STEP(game))        clamped to MAX_TIER (= 30)
```

`STEP` is **per game** because each game's `get_score()` lives on a very different scale (§4). There is
no growth curve and no threshold formula — just even round steps. The ladder is **FINITE**: tier 30 is
a real "mastered" summit.

> **This reverses the old "no hard ceiling" design (§7), intentionally.** Mastery is now a reachable
> top, not an endless trickle — a cleaner goal to chase and a bounded total by construction.

You keep every tier you ever clear (`note_challenge_tier` is raise-only); a worse or shorter run never
lowers a banked tier. This is the "push-your-luck, no currency wager" stake Tim locked: attempting a
deeper tier costs only your time.

---

## 3. The payout schedule + the two reward tracks

Most tiers are **progress-only** (the screen shows "Tier 12 — next reward at tier 15"). A **percent
payout lands on every 5th tier**, up to 6 payouts (tier 30 max), on **one schedule shared by every
game** — alternating income and Legacy, escalating in value:

| Tier | Payout | Track  |
|------|--------|--------|
| 5    | +1%    | INCOME |
| 10   | +1%    | LEGACY |
| 15   | +2%    | INCOME |
| 20   | +2%    | LEGACY |
| 25   | +1%    | INCOME |
| 30   | +1%    | LEGACY |

So a single mastered game maxes at **+4% income and +4% Legacy**. All six games mastered ≈
**+24% income + +24% Legacy** — Tim's **~25/25 target**. A global `challenge_bonus_scale` knob
(default 1.0) scales every payout on both tracks, so Tim can retune the whole system live.

**Two reward tracks, both permanent and dynasty-wide (survive prestige):**

1. **Income track** → the property-income multiplier. Folded into
   `DynastyState.get_legacy_income_multiplier()` as `Family Fortune × (1 + total income bonus)`, the
   same lever the Legacy "Family Fortune" upgrade already drives. Applied exactly once, on every
   property (the passive tick and the rush-collect path read the same field).
2. **Legacy track** → the Legacy-**yield** multiplier (the "Estate Lawyers" lever). Folded into
   `DynastyState.get_legacy_yield_multiplier()` as `Estate Lawyers × (1 + total Legacy bonus)`, which
   is the single site the estate-to-Legacy conversion (`get_draft_will`) uses — so the bonus lands on
   the Legacy grant exactly once.

The authoritative state is **per-game highest-tier-cleared** (`DynastyState.challenge_highest_tiers`,
`{game_key → int}`), persisted in the dynasty save (so it survives prestige) and defaulted-empty on old
saves.

---

## 4. First-pass numbers (ALL device-tune)

Per-game **STEP** (round score per tier). Read each game's `get_score()` to size the summit:

| Game | STEP | `get_score()` is… | Tier 30 needs |
|------|------|-------------------|---------------|
| Match Three       | 1000 | cumulative points   | 30,000 points |
| Timing Bar        | 1    | successful locks    | 30 locks |
| Memory Match      | 1    | rounds recalled     | 30 rounds — **⚠ likely unreachable** |
| Micro Basketball  | 1    | baskets sunk        | 30 baskets — **⚠ likely unreachable** |
| Catch the Money   | 2    | coins caught        | 60 coins |
| Balance the Books | 2    | seconds in gold zone| 60 seconds |

> **⚠ Low-ceiling flag (Memory, Basketball):** their `get_score()` is a small round/basket count, so
> tier 30 (and possibly the higher payout tiers) may be unreachable in a single run at STEP = 1. Device
> tuning options: drop their STEP below 1 (fractional), or accept that only the lower payout tiers are
> reachable for those games. Left at STEP = 1 first-pass; flagged here for the tuning pass.

Keep-alive timer params:

| Knob | Default | Meaning |
|------|---------|---------|
| `challenge_timer_start_seconds` | 6.0  | clock at run start |
| `challenge_timer_cap_seconds`   | 15.0 | top-up ceiling |
| `challenge_bonus_scale`         | 1.0  | global × on every payout (both tracks) |

Per-game **seconds-per-point** top-up (sized inversely to how fast each game scores, so a top-up feels
comparable): Match Three 0.02 · Timing Bar 3.0 · Memory 4.0 · Micro Basketball 3.0 · Catch the Money
1.5 · Balance the Books 2.0.

`challenge_bonus_scale`, `challenge_timer_start_seconds`, `challenge_timer_cap_seconds` are Balance-
Tuning knobs (`TuningConfig` + `tuning.tres` + the DevTuningPanel descriptions). STEP, the payout
schedule, and seconds-per-point are authored constants in `ChallengeGoals.gd`.

---

## 5. The code (the API Wave 2 builds against)

`ChallengeGoals.gd` (static, stateless — configured from tuning by `DynastyState`):
- game-key constants + `game_keys()`
- `score_step(game_key)`, `tier_for_score(game_key, score)` → int (floor/step, clamped to MAX_TIER)
- `payout_at_tier(tier)` → `{pct, type}` or `{}`; `next_payout_tier(cleared_tier)` → int (-1 if maxed)
- `income_bonus_for(cleared_tier)`, `legacy_bonus_for(cleared_tier)` (fraction, × bonus_scale)
- `total_income_bonus(highest_tiers)`, `total_legacy_bonus(highest_tiers)`
- `seconds_per_point(game_key)`, `timer_start_seconds()`, `timer_cap_seconds()`
- `configure(bonus_scale, timer_start, timer_cap)` — the tuning push (GOTCHA: re-pushed on every
  dynasty construction/load, so a sim sets the TUNING field, not the static).

`DynastyState.gd`:
- `challenge_highest_tiers` + `note_challenge_tier` (raise-only) + save/load
- `get_challenge_income_bonus()`, `get_challenge_legacy_bonus()`
- `get_legacy_income_multiplier()` (income fold), `get_legacy_yield_multiplier()` (Legacy fold — the
  single caller is `get_draft_will`)
- `credit_challenge_score(game_key, score)` → report `{improved, old_tier, new_tier, tiers_gained,
  income_before/after, legacy_before/after, bonus_before/after}` (the `bonus_*` aliases carry the
  income track for the existing feedback readout).

---

## 6. Phased status

1. **Core (THIS WAVE — done):** authored `ChallengeGoals` ladders + payout schedule + two-track math;
   `DynastyState` two-track folds + crediting; tuning knobs; sim (`sim/ChallengeGoalsTest.gd`).
2. **Wave 2 (next):** build the keep-alive run **timer** in `MinigameScreen` (start/drain/top-up/cap/
   busy-pause/0-ends), and rebuild the **CHALLENGES screen** against the API in §5 — showing tier
   progress, the next payout tier + which track it pays, and both running totals.
3. **Content + device tuning:** per-game STEP (esp. the low-ceiling games), the seconds-per-point
   table, the timer feel, and `challenge_bonus_scale` toward the 25/25 target, on the Pixel.

---

## 7. What changed from the old model (for context only)

The previous design gave every game an **infinite** ladder with a **geometrically diminishing** per-
tier income bonus (`reward(t) = BASE_PCT × DECAY^(t-1)`), whose per-game sum converged to a bounded
limit — "no hard ceiling, bounded by math." Playtest retired it in favour of the authored, finite
ladder above:
- **Finite (tier 30 summit)** replaces the endless trickle — a clear mastery goal.
- **Two tracks (income + Legacy-yield)** replace the single income bonus.
- **A keep-alive timer** replaces the endless no-fail run.
- Tuning knobs `challenge_goal_growth` / `challenge_reward_base_pct` / `challenge_reward_decay` are
  removed; `challenge_bonus_scale` / `challenge_timer_start_seconds` / `challenge_timer_cap_seconds`
  replace them.
