# Legacy Bonus System — design of record

**Origin:** Tim, 2026-07-09, during the match-3 difficulty pass. Grew from "add a 5th gem"
into a cross-cutting reward that touches every minigame plus the dynasty wallet.

## The idea

Every minigame has a **small chance** to let the player earn **bonus Legacy gems** through a
game-specific action. The gems are "unearned" (a lucky perk, not the round's main reward). The
amount granted is **0.1% of the dynasty's lifetime-earned Legacy per gem collected**, gated by
how well the overall round went.

### How many gems can a round grant? (Tim's Q, 2026-07-09)
**Decision: cap collection at 1 per round by default** — you can only bank one legacy "moment"
per round, and it pays the FULL proportional amount (0.1%×lifetime×tier, min 1). Rationale: keeps
every game's legacy moment worth the same (fairness — Catch could rain gem-coins while Timing
gives one, so count-scaling would make some games better farms by mechanic, not skill), and reads
as a clean windfall rather than a grind. Implemented as a knob `legacy_bonus_max_gems` (default 1);
raise it to get the count-proportional model (grant scales with how many you collected).

### Gating by round result (all games)
- **Bad result** (below the "full" line): keep **nothing** — collected gems are forfeited.
- **Normal result** (at/above full): keep what was earned (full 0.1%×lifetime per gem).
- **Great result** (top bonus band): a proportional bonus on top (~+10%).
- **Minimum:** if the player has *any* lifetime Legacy and genuinely earned a bonus (collected ≥1,
  result not bad), they always receive **at least 1** gem, even if 0.1%×lifetime rounds below 1.

### Design intentions (Tim, 2026-07-09)
1. **Not guaranteed.** A legacy gem is never a sure thing in any minigame — the chance is a
   chance. (Holds already: every spawn chance is < 1.0.)
2. **Comparable difficulty across games.** Despite the very different mechanics, it should be
   *roughly equally hard* to earn a bonus in each minigame. This is the guiding goal for tuning the
   per-game `legacy_gem_chance_*` values (and each game's collection difficulty) on the device pass —
   the current first-pass numbers are NOT yet calibrated to each other.
3. **Stop once earned.** The instant the round's bonus is fully earned (enough gems collected to hit
   the cap — for a given game that may be one gem or several), NO further legacy gems spawn, to avoid
   pointless noise. Implemented via `Minigame.legacy_bonus_secured()`: the host sets each game's
   `legacy_bonus_cap` from `legacy_bonus_max_gems` before begin(), and every game checks
   `legacy_bonus_secured()` before spawning a new gem (match-3 disables its board's special spawns).

### Payout context (Tim: "any real run")
Grants only in real transition rounds — **succession/prestige, welcome-back, first contact**. No
grant in the Minigame Tuning practice screen or Challenge Mode (both are farmable).

### The grant is "unearned"
Banked to the spendable wallet (`LegacyUpgrades.available`) **only** — NOT added to
`earned_lifetime`, so it never inflates its own 0.1% base or the long-arc prestige score.
(Claude's call, flagged for Tim's veto.)

## Per-game mechanics (Tim's spec)

- **Match-3:** Legacy gem is a real 5th gem. It has **no random spawn** (Tim, 2026-07-09 — 5+
  matches make enough); a match of **5+ regular gems** (not the AVOID color) places one bonus Legacy
  gem at the swap's **target cell** (where the player moved). Legacy gems do
  nothing by themselves and score **0** normal points; **matching 3 of them** collects one bonus.
- **Catch money:** small chance a falling coin carries a Legacy gem; catching that coin earns the
  gem in addition to the coin.
- **Timing / lock:** small chance a gem appears in the **center of the target zone**; if the
  player's **next lock** lands in the zone they keep it, otherwise it disappears.
- **Fishing / balance:** small chance a gem appears in the zone; while the marker is **in the zone**
  a gem-progress bar fills, and **drains** while out; fill it to keep the gem (Stardew-style).
- **Basketball:** the gem is earned only if a shot passes **through** the gem **and** scores, in a
  single shot.
- **Memory:** UNDECIDED (Tim). Left out for now — no Legacy gem in Memory yet.

## Architecture

**`Minigame` (base):** `_legacy_gems_collected` + `collect_legacy_gem(n=1)` +
`get_legacy_gems_collected()`. A type calls `collect_legacy_gem()` when its mechanic succeeds.

**`MinigameScreen` (host):** knows the round's performance → tier. Reward context carries
`legacy_lifetime` (the dynasty's earned_lifetime). At a real completion it computes the granted
integer (fraction × lifetime × collected × tier factor, min-1 rule), shows a result line, and emits
`legacy_bonus_earned(amount)`. Suppressed in review/Challenge and on Skip (Skip = bad).

**`Main`:** passes `dynasty.upgrades.earned_lifetime` into each reward context; connects
`legacy_bonus_earned` → `dynasty.upgrades.grant_bonus(amount)` (available-only) + save.

**`LegacyUpgrades`:** new `grant_bonus(amount)` adds to `available` only.

**`MatchThreeBoard`:** optional special (Legacy) color — low spawn weight, kept out of the
no-match starting seed, and a "force one special into the next refill" counter bumped by each 4+
match. Default off (weight 0 / no special color) so existing behavior and tests are unchanged.

## Tuning knobs (TuningConfig, live in Balance Tuning)
- `legacy_bonus_fraction` (0.001 = 0.1% of lifetime per gem)
- `legacy_bonus_great_multiplier` (1.10 = +10% on a great round)
- `legacy_bonus_great_threshold` (fraction into the bonus band that counts as "great")
- per-game spawn chances: `legacy_gem_chance_match3` (natural), `_catch`, `_timing`, `_balance`,
  `_basketball` — all small first-pass values, device-tuned.

## Also in this pass (Tim, same conversation)
- **Match-3 combo removed:** cascade matches now score **statically** by gem count only (no rising
  combo multiplier), because lucky refill-cascades rewarded luck. Removes the `match3_combo_bonus`
  knob and the "COMBO ×N" flourish.

## Build order
1. Shared core: base + host + Main + LegacyUpgrades + TuningConfig knobs. **[DONE — 4b35194]**
2. Match-3: combo removal + Legacy gem (board + minigame) + board tests. **[DONE — 4b35194]**
3. Catch, Timing, Balance, Basketball mechanics (parallel). **[DONE — a15b562]**
4. Memory once Tim decides its mechanic. Device feel-tune all spawn chances + the great% + fraction.

## Status (2026-07-09)
Built on `feature/match3-difficulty` (NOT merged — awaiting Tim's device test). Everything
parse-checks, boots, MatchThreeTest (37) + EpochTest pass, and a runtime smoke ran all four new
games' gem paths without error. Memory has no legacy mechanic yet (Tim undecided). ALL spawn
chances, the fraction, the great%/threshold, and the max-gems cap are first-pass — device-tune.
To SEE a grant, reach a prestige with some lifetime Legacy (early on 0.1% is tiny; the min-1 floor
covers it).
