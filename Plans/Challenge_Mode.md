# Challenge Mode Rework — Scoping

**Created:** 2026-07-20
**Status:** SCOPING (design draft, nothing built). Supersedes the dead-end arcade high-score mode.
**Design source:** `Plans/Minigame_Polish_Pass.md` §6.1 ("goals define bonuses = small % global
increase") + the three decisions below.

Challenge Mode today is a bare high-score store (`ChallengeScores.gd` → `user://challenge_scores.json`)
plus an endless arcade run reachable only under Settings → Minigame Tuning (a dev tool). It has no
goals, no stakes, no rewards — scores are written to a JSON file nothing reads back. This rework turns
it into a discoverable, player-facing progression that grants small permanent dynasty-wide bonuses.

---

## 1. Locked decisions (Tim, 2026-07-20)

1. **Stakes = push-your-luck tiers, no currency wager.** Each minigame has a ladder of goal tiers.
   You keep every tier you clear, permanently. Attempting a *harder* tier can fail and costs only your
   time — no Legacy/cash is risked. (Rejected: currency wager, streak gauntlet.)
2. **Goals = repeatable / escalating, no hard ceiling.** Tiers keep climbing (threshold grows each
   rung); each grants a small % bonus. Tim's own flag: this **must be rate-limited or it runs away**.
3. **Entry = a standalone, player-facing CHALLENGES screen** (a real button, not buried under the dev
   Minigame Tuning tool).

---

## 2. Current state (from the 2026-07-20 code audit)

**Exists and reusable:**
- `ChallengeScores.gd` — static `{type_name → best_score}` store, `get_high_score` / `record_score`,
  persists to `user://challenge_scores.json` (separate from the dynasty save).
- The endless-run path: `MinigameScreen.start_challenge(type_script)` (§1031) sets
  `Minigame.challenge_mode = true` (run endlessly, never self-complete, misses don't stop play) and
  scores via `Minigame.get_score() → int` (raw *unbounded cumulative* score — distinct from the
  reward path's `get_performance() → [0,1]`). Ends only via DONE/Back → `record_score`.
- The dev entry: Settings → **MINIGAME TUNING** (`Main.gd:1408`) → `MinigameReviewScreen` mode toggle
  "MINIGAME MODE / CHALLENGE MODE" (§159-266).
- **The dynasty-wide bonus lever the reward plugs into:** `LegacyUpgrades.property_income_multiplier()`
  (§109) → `DynastyState._apply_upgrade_effects(game)` (§301, pushes the multiplier onto every property
  each generation) → persisted in the **dynasty save** via `LegacyUpgrades.to_save_dict()` (§230) under
  `DynastyState`'s `"upgrades"` key. This is exactly §6.1's "reuses the same lever as Legacy upgrades."

**Missing (the whole rework):** goals, stakes, reward hookup, the global-bonus plumbing, and a
player-facing entry point.

---

## 3. Proposed design

### 3.1 The escalating tier ladder (per game, push-your-luck)
Each of the 6 minigames has its own **infinite escalating ladder** of goal tiers. Tier `t` (1, 2, 3, …)
has a **score threshold** on the game's `get_score()`:

```
threshold(game, t) = T0(game) × GROWTH^(t-1)
```

`T0` is the game's first-tier target; `GROWTH` (~1.5–1.8, tunable) makes each rung a real step up. A
challenge run is the existing endless `challenge_mode` play; the **highest tier whose threshold you
reached** is the tier you clear. You keep every cleared tier forever; a run that falls short of the next
threshold costs only time (the "push-your-luck" — mild, no currency). `ChallengeScores`' best-score per
game already gives "highest tier reached" for free.

### 3.2 Reward = a diminishing % global bonus (this is the rate-limiter)
Clearing tier `t` grants a permanent addition to a **global income bonus**, geometrically diminishing:

```
reward(t) = BASE_PCT × DECAY^(t-1)          # e.g. BASE_PCT = 0.5%, DECAY = 0.6
game_bonus(game) = Σ reward(t) for cleared tiers = BASE_PCT × (1 − DECAY^cleared) / (1 − DECAY)
```

Because `DECAY < 1`, the per-game sum **converges** to `BASE_PCT / (1 − DECAY)` even with infinitely
many tiers — so there is **no hard ceiling** (you can always climb one more rung) yet the total is
**bounded and cannot run away** (Tim's rate-limit requirement, satisfied by math, not a cap). Worked
example: `BASE_PCT = 0.5%`, `DECAY = 0.6` → each game asymptotes to **1.25%**, all 6 games → **~7.5%**
global income at the limit; the first few tiers deliver most of it, higher tiers taper to a trickle
(mastery/high-score becomes the draw past that point). All three constants are Balance-Tuning knobs.

`total_challenge_bonus = Σ game_bonus(game)` across all games.

### 3.3 Global-bonus plumbing (rides the dynasty save, survives prestige)
Lowest-risk fit (research "shape 1"): the bonus flows through the existing Legacy multiplier pipeline.
- **Authoritative state in the dynasty save:** per-game highest-tier-reached (6 ints), stored in
  `DynastyState` (not the arcade `user://` file), so the bonus applies to the run and **survives
  prestige** — a "lasting, dynasty-wide bump" per §6.1.
- **Applied** in `DynastyState._apply_upgrade_effects` (§301): fold `(1 + total_challenge_bonus)` into
  the property income multiplier alongside the Legacy `property_income_multiplier()`. Additive-then-
  multiplied (not compounding per tier) keeps the bounded total meaningful.
- **Persisted** by extending `DynastyState.to_save_dict` / `load_save_dict` (defaulted-get idiom); bump
  `SAVE_VERSION`. The separate `challenge_scores.json` can stay as a display mirror or be deprecated in
  favor of the dynasty-save record (decide in build).

### 3.4 The CHALLENGES screen (player-facing entry)
A standalone screen (modeled on the existing full-screen pattern — `AboutScreen`/`StatsScreen`),
reached by a **CHALLENGES** button (Settings top-level, or Main — see open Qs). It lists the 6 games,
each showing: highest tier cleared, the next tier's threshold, that tier's % reward, and the running
**total global bonus earned**. Tapping a game launches its challenge run. The dev mode-toggle inside
Minigame Tuning is retired for players (kept only as a dev shortcut, or removed).

### 3.5 Reuse, not rebuild
The reward-agnostic host already supports this: `start_challenge` + `challenge_mode` + `get_score`
exist. The rework adds (a) a goal/threshold catalog, (b) the diminishing-reward math, (c) the dynasty-
save bonus state + apply site, and (d) the player-facing screen. No change to the `get_performance()`
reward rounds (succession / welcome-back / first contact) — those are untouched.

---

## 4. Open decisions & tuning knobs
- **Reward variety:** v1 = a single global *income* bonus. Later tiers could alternate income / cycle-
  speed / Legacy-yield for flavor (defer to v2). *Recommend income-only for v1.*
- **Button home:** Settings top-level (safe, uncluttered) vs. a Main-screen CHALLENGES button (more
  discoverable, competes for Main real estate — and Tim's "no moving UI" rule). *Recommend Settings for
  v1.*
- **Threshold feel:** `T0` per game and `GROWTH` — first-pass, device-tune. Games score very differently
  (`get_score` scales differ per type), so `T0` is per-game, not shared.
- **Reward curve:** `BASE_PCT` and `DECAY` — first-pass 0.5% / 0.6 (→ ~7.5% total across 6 games). Size
  well under a single Legacy Family Fortune level (+20%) so it complements, not dwarfs, prestige.
- **Arcade store fate:** keep `challenge_scores.json` as a mirror, or move fully into the dynasty save.
- **Discoverability/tie to the tutorial idea:** the new CHALLENGES screen is a natural place the future
  tutorial (GDD Future Features) could point players to practice each system.

## 5. Phased plan
1. **Headless core** — `ChallengeGoals` catalog (per-game `T0`, shared `GROWTH`/`BASE_PCT`/`DECAY`);
   the reward math; per-game highest-tier state on `DynastyState` + save bump; fold `(1 + total)` into
   `_apply_upgrade_effects`. Balance-Tuning knobs. Sim/test: convergence, save round-trip, tier math.
2. **Wire to minigames** — on ending a challenge run, compute highest tier from `get_score`, credit any
   newly-cleared tiers into the dynasty bonus; surface "NEW TIER — +X% global" feedback.
3. **CHALLENGES screen** — the standalone player-facing screen + entry button; retire the dev toggle
   for players.
4. **Content + device tuning** — per-game `T0`, the reward curve, feel pass on the Pixel.

## 6. Key files
`ChallengeScores.gd`; `MinigameScreen.gd` (`start_challenge` §1031-1188, `start_game` §912);
`MinigameReviewScreen.gd` (mode toggle §159-266); `Minigame.gd` (`challenge_mode` §41, `get_score` §47,
`get_performance` §86); `Main.gd` (MinigameSite §140, tuning entry §1408); `LegacyUpgrades.gd` (§109
getter, §230 save); `DynastyState.gd` (§301 apply, §346 save); `LegacyUpgradeCatalog.gd` (§77-94
sizing reference).

## 7. First-pass numbers (all Balance-Tuning knobs, device-tune)
`GROWTH ≈ 1.6` · `BASE_PCT = 0.5%` · `DECAY = 0.6` (→ ~1.25%/game, ~7.5% total asymptote) · `T0` per
game TBD from each type's `get_score` scale.
