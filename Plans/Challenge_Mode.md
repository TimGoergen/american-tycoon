# Challenge Mode — Design of Record

**Last rewritten:** 2026-07-22 (consolidated SHIPPED-state sync — verified against the code).
**Status:** **feature complete on `feature/challenge-mode-phase1`; DEVICE-CONFIRMED by Tim 2026-07-22; pending merge to main.**
**This document is the single source of truth for the CURRENT design.** §§1–6 describe what actually
shipped; §7 keeps the older models as clearly-marked history only. (Several earlier drafts of this doc
had themselves drifted — a flat-STEP table with "unreachable" flags on the low-ceiling games, a
"Wave 2 next" timer, `configure(bonus_scale, timer_start, timer_cap)`, seconds-per-point like Match
Three 0.02. Those numbers are wrong; the table below is verified against `ChallengeGoals.gd`,
`TuningConfig.gd`, and `tuning.tres`.)

Challenge Mode is a discoverable, player-facing progression laid over the six minigames. Each game has
its own tier ladder; clearing tiers grants small, permanent, dynasty-wide bonuses on two tracks
(property income and Legacy yield), and those bonuses survive prestige. A run is a short keep-alive
push: the clock starts low, drains, and is topped up by scoring — when it hits zero the run ends and
your best tier is banked.

**Where to find it in-game:** Settings → **CHALLENGES**, a standalone `ChallengesScreen`. (This is
NOT the old toggle on the Minigame Tuning screen — that model is retired; see §7.)

---

## 1. The run: a keep-alive timer (BUILT)

A challenge run is NOT endless. It is a keep-alive push, built in `MinigameScreen`:

- The run starts with a small time budget — `challenge_timer_start_seconds` (default **6.0s**). A game
  may override its opening budget: **Micro Basketball starts with 10.0s** (`ChallengeGoals.TIMER_START`),
  because lining up the first few shots is slow.
- The clock **drains 1 second per second** while you play.
- **Scoring tops the clock up**: each point the game's `get_score()` gains adds
  `seconds_per_point(game)` seconds (per-game table, §4).
- Top-ups are **capped** at `challenge_timer_cap_seconds` (default **15.0s**) — a hot streak can't
  stockpile an unlimited cushion.
- The clock **pauses while the game is busy** (mid-animation / resolving), so you're never drained by
  time you can't act in.
- When the clock reaches **0, the run ends**. The highest tier the run reached is credited (raise-only).
  **This is the fail state** — the only one. (The one exception is Memory Match, which has no keep-alive
  timer at all; see §5.)

The run's tension is "keep scoring fast enough to stay alive"; the reward is how deep a tier you bank
before the clock runs out.

---

## 2. The tier ladders (authored, finite)

Every game climbs a **FINITE** ladder capped at **`MAX_TIER = 30`** — a real "mastered" summit. But the
six games use **two different costing models**, because their `get_score()` values live on wildly
different scales:

**Model A — flat STEP (four games).** A game's tier is a plain round checkpoint on its raw score:

```
tier(game, score) = floor(score / STEP(game))        clamped to MAX_TIER (= 30)
```

No growth curve, just even round steps. Used by Match Three, Timing Bar, Catch the Money, Balance the
Books (STEP values in §4).

**Model B — escalating per-tier cost (two low-ceiling games).** Micro Basketball and Memory Match have
a small score ceiling (baskets sunk / climbs completed), so a flat STEP fails — either the early tiers
are unreachable or the summit is trivial. Instead, the cost of ONE tier starts cheap and climbs every
5 tiers, capped:

```
tier_cost(game, tier)        = min(base + floor((tier-1)/5) × increment, cap)     [tier ≥ 1]
score_to_reach_tier(game, N) = cumulative_cost = sum of tier_cost(1..N)
```

So the early tiers (and the first payouts) are reachable, and mastery is a real climb. **This SOLVES
the old low-ceiling problem** — the previous flat STEP = 1 made those two games' higher tiers likely
unreachable; that is fixed, and the ⚠ warnings from earlier drafts are gone.

You keep every tier you ever clear (crediting is raise-only); a worse or shorter run never lowers a
banked tier. This is the "push-your-luck, no currency wager" stake Tim locked: attempting a deeper tier
costs only your time.

---

## 3. The payout schedule + the two reward tracks

Most tiers are **progress-only**. A **percent payout lands on every 5th tier**, up to 6 payouts (tier 30
max), on **one schedule shared by every game** — alternating income and Legacy, escalating in value:

| Tier | Payout | Track  |
|------|--------|--------|
| 5    | +1%    | INCOME |
| 10   | +1%    | LEGACY |
| 15    | +2%   | INCOME |
| 20    | +2%   | LEGACY |
| 25    | +1%   | INCOME |
| 30    | +1%   | LEGACY |

The escalation is +1/+1/+2/+2/+1/+1 per track, so a single mastered game maxes at **+4% income and +4%
Legacy**. All six games mastered ≈ **+24% income + +24% Legacy** — Tim's **~25/25 target**. A global
`challenge_bonus_scale` knob (default 1.0) scales every payout on both tracks, so Tim can retune the
whole system live.

**Two reward tracks, both permanent and dynasty-wide (survive prestige):**

1. **Income track** → the property-income multiplier. Folded into
   `DynastyState.get_legacy_income_multiplier()` as `Family Fortune × (1 + total income bonus)` — the
   same lever the Legacy "Family Fortune" upgrade drives. Applied exactly once, on every property.
2. **Legacy track** → the Legacy-**yield** multiplier (the "Estate Lawyers" lever). Folded into
   `DynastyState.get_legacy_yield_multiplier()` as `Estate Lawyers × (1 + total Legacy bonus)`, the
   single site the estate-to-Legacy conversion (`get_draft_will`) uses — so the bonus lands exactly once.

The authoritative state is **per-game highest-tier-cleared** (`DynastyState.challenge_highest_tiers`,
`{game_key → int}`), persisted in the dynasty save (**`SAVE_VERSION 11`**, so it survives prestige) and
defaulted-empty on old saves. Crediting is raise-only.

---

## 4. Numbers (verified against tuning.tres; ALL first-pass except the device-tuned values noted)

**Model A — per-game flat STEP** (round score per tier), from `ChallengeGoals.STEP`:

| Game | STEP | `get_score()` is… | Tier 30 needs |
|------|------|-------------------|---------------|
| Match Three       | 1000 | cumulative points   | 30,000 points |
| Timing Bar        | 1.0  | successful locks    | 30 locks |
| Catch the Money   | 2.0  | coins caught        | 60 coins |
| Balance the Books | 2.0  | seconds in gold zone| 60 seconds |

**Model B — escalating per-tier cost** (`base / increment / cap`, in the game's own score units),
from the `basketball_tier_*` / `memory_tier_*` tuning knobs:

| Game | base | increment | cap | Reachability |
|------|------|-----------|-----|--------------|
| Micro Basketball | 1.0 | 1.0 | 5.0 | tier 5 = 5 baskets, tier 10 = 15, tier 15 = 30 |
| Memory Match     | 0.2 | 0.2 | 1.0 | tier 5 ≈ 1 climb, tier 10 ≈ 3, tier 15 = 6 |

**Keep-alive timer params** (Balance-Tuning knobs):

| Knob | Default | Meaning |
|------|---------|---------|
| `challenge_timer_start_seconds` | 6.0  | clock at run start (Basketball overrides to 10.0) |
| `challenge_timer_cap_seconds`   | 15.0 | top-up ceiling |
| `challenge_bonus_scale`         | 1.0  | global × on every payout (both tracks) |
| `challenge_miss_penalty_ratio`  | 0.5  | fraction of a hit's time-gain a MISS drains (§5) |

**Per-game keep-alive seconds-per-point** (each game now has its own live knob; device-tuned values
in **bold**), from `tuning.tres`:

| Game | seconds/point | Knob |
|------|---------------|------|
| Match Three       | **0.012** | `match3_keepalive_seconds_per_point` |
| Timing Bar        | **0.9**   | `timing_keepalive_seconds_per_point` |
| Memory Match      | 4.0       | `memory_keepalive_seconds_per_point` |
| Micro Basketball  | **3.5**   | `basketball_keepalive_seconds_per_point` |
| Catch the Money   | 1.5       | `catch_keepalive_seconds_per_point` |
| Balance the Books | 2.0       | `balance_keepalive_seconds_per_point` |

(`ChallengeGoals.SECONDS_PER_POINT` holds the same values as baked defaults for a headless call that
skips `configure()`.)

**Balance-the-Books challenge knobs** (read only in challenge mode): `balance_seconds_per_point` 1.0,
`balance_keepalive_seconds_per_point` 2.0, `balance_zone_reroll_seconds` 1.3, `balance_zone_ease` 1.6.

**ALL of these now live in the Balance-Tuning screen** (`TuningConfig` + `tuning.tres` + the
DevTuningPanel's game-grouped "Challenge Mode" section). Nothing about the challenge is a hardcoded
authored constant any more except the payout schedule and `MAX_TIER`.

---

## 5. Per-game challenge behaviors + the shared miss penalty

Each behavior below is **gated on `Minigame.challenge_mode`**; the reward/prestige round of every game
is unchanged.

**Shared MISS penalty.** `Minigame.challenge_time_penalty(points)` is a signal a game emits when the
player misses; the host (`MinigameScreen`) drains the keep-alive timer by
`challenge_miss_penalty_ratio` (0.5) × points × `seconds_per_point(game)` — so missing costs
proportionally to the hit it replaced. **Catch the Money** emits a dropped coin's value; **Timing Bar**
emits `1.0` on a failed lock.

**Memory Match** — the odd one out: **no keep-alive timer**. The run ends on the game's own completion
or a wrong tap. It is a Simon-style climb 1 → 6 and then resets; `get_score()` = climbs completed.

**Catch the Money** — an oscillating size/speed wave over the whole coin field, plus per-coin curving
sway, big-slow / small-fast coin archetypes, premium coins (worth 3×, never a legacy coin), a fixed
spawn interval of 0.60s, per-coin fall jitter, and a raised minimum fall speed (`CHALLENGE_SPEED_SLOW`
×1.25).

**Timing Bar** — the marker speed is a time-based wave with a swing that grows across regular mode's
speed range; the gold zone drifts, edge-bounces, flips direction every 3–5 locks, and its glide speed
and size are their own slow waves.

**Match Three** — legacy gems become a premium 5th gem type: they spawn on 5+ matches, score ×2.5, and
are never the "avoid" gem.

**Balance the Books** — keeps the keep-alive timer AND adds an in-zone "charge to the next point" gauge;
scoring is in-zone seconds-per-point (`balance_seconds_per_point`).

---

## 6. Chrome + tuning surface

- **The run display is a large PULSING `TIER {current}/{best}`** readout (`MinigameScreen`). The old
  tier-progress bar was removed.
- **A standalone CHALLENGES screen** (`ChallengesScreen`) reached from a Settings button, listing each
  game and its best tier. (A mode toggle still lives inside the Minigame Tuning screen, but only as a
  developer shortcut — the player-facing home is the Settings screen.) Credit routing is
  **source-aware** — a challenge run credits `challenge_highest_tiers`, while a reward/prestige round
  routes to the multiplier it always did.
- **All challenge knobs live in the Balance-Tuning screen** in a single **"Challenge Mode"** section of
  the `DevTuningPanel` (the panel's catch-all section — the knobs are grouped by their naming/source
  order within it, not by sub-headers). As part of this the panel was trimmed from **14 to 10** section
  headers and gained **drag-to-scroll**.
- `ChallengeGoals.configure()` takes the **whole `TuningConfig` object** (not a positional list) —
  `DynastyState` re-pushes it on every construction/load. A new challenge knob is wired by reading one
  more field inside `configure()`, never by growing a call site.

---

## 7. History — the two superseded models (context only)

**The very first model (retired 2026-07-20).** Every game had an **infinite** ladder with a
**geometrically diminishing** per-tier income bonus (`reward(t) = BASE_PCT × DECAY^(t-1)`) whose
per-game sum converged to a bounded limit — "no hard ceiling, bounded by math," a single income track,
an endless no-fail run. Its knobs (`challenge_goal_growth` / `challenge_reward_base_pct` /
`challenge_reward_decay`) are gone.

**The interim authored-ladder draft (2026-07-20, also now superseded in its details).** Introduced the
finite tier-30 ladder, the every-5th payout schedule, the two tracks, and the keep-alive timer as a
concept — but with a **flat STEP for all six games** (which left Memory and Basketball's higher tiers
likely unreachable, flagged with ⚠), the **timer described as an un-built "Wave 2"** mechanic, a
positional `configure(bonus_scale, timer_start, timer_cap)`, and provisional seconds-per-point (Match
Three 0.02, Basketball 3.0). The SHIPPED design in §§1–6 replaces those specifics: the escalating cost
model for the two low-ceiling games, the timer BUILT (with a per-game start override), the whole-object
`configure()`, the miss penalty, the per-game behaviors, and every knob exposed to Balance Tuning.
