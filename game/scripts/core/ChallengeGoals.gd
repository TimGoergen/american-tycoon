class_name ChallengeGoals

# The catalog + math for CHALLENGE MODE's escalating goal ladders (Plans/Challenge_Mode.md §3).
# A pure DATA-plus-MATH table in code, the same shape as LegacyUpgradeCatalog.gd / EpochCatalog.gd:
# static, stateless, no scene tree, no instance to create.
#
# Each of the 6 minigames has its own INFINITE escalating ladder of goal tiers. Tier `t` (t ≥ 1)
# has a score threshold on that game's Minigame.get_score():
#
#     threshold(game, t) = T0(game) × GROWTH^(t-1)
#
# Clearing tier `t` grants a PERMANENT, geometrically DIMINISHING global income bonus:
#
#     tier_reward(t)          = BASE_PCT × DECAY^(t-1)                       (a fraction, e.g. 0.005)
#     game_income_bonus(n)    = BASE_PCT × (1 − DECAY^n) / (1 − DECAY)       (closed-form geo. sum)
#
# where n = the highest tier cleared for that game. Because DECAY < 1 the per-game sum CONVERGES to
# BASE_PCT/(1−DECAY) even with infinitely many tiers — so there is no hard ceiling (you can always
# climb one more rung) yet the total is bounded and cannot run away (Tim's rate-limit requirement,
# satisfied by math, not a cap — see §3.2). The whole-mode bonus is the sum across all six games.
#
# The game KEY is each minigame type's DISPLAY NAME — the exact string returned by that type's
# Minigame.display_name(). MinigameScreen keys ChallengeScores by _active_type_key =
# _active_minigame.display_name() (MinigameScreen.gd §1054), so using display_name() here keeps the
# challenge-goal ladders, the arcade high-score store, and the (later) player-facing screen all
# addressing each game by the SAME string. Verified against each *Minigame.gd's display_name().


# ── Game keys (the six display_name() strings) ────────────────────────────────
# Named constants so a typo is a compile-time miss rather than a silent lookup failure, exactly like
# LegacyUpgradeCatalog's id constants. Each value is copied from the matching *Minigame.gd.
const TIMING_BAR     := "Timing Bar"        # TimingBarMinigame.display_name()
const MEMORY_MATCH   := "Memory Match"      # MemoryMinigame.display_name()
const MATCH_THREE    := "Match Three"       # MatchThreeMinigame.display_name()
const BASKETBALL     := "Micro Basketball"  # BasketballMinigame.display_name()
const CATCH_MONEY    := "Catch the Money"   # CatchMoneyMinigame.display_name()
const BALANCE_BOOKS  := "Balance the Books" # BalanceMinigame.display_name()


# ── First-tier thresholds, per game (T0) ──────────────────────────────────────
# ALL FIRST-PASS, DEVICE-TUNE (Plans/Challenge_Mode.md §7 — "T0 per game TBD from each type's
# get_score scale"). Each game's get_score() measures something on a very different scale, so T0 is
# per-game, not shared. The rationale for each starting target, read off that game's get_score():
#   Timing Bar        — get_score() = successful lock count; a few good locks per round → T0 = 6.
#   Memory Match      — get_score() = rounds recalled; each round adds a step, so small → T0 = 4.
#   Match Three       — get_score() = cumulative points (POINTS_PER_GEM = 10, a 3-match ≈ 30+);
#                       climbs into the hundreds fast → T0 = 200.
#   Micro Basketball  — get_score() = baskets sunk (~6 a strong round) → T0 = 5.
#   Catch the Money   — get_score() = coins caught; a steady stream → T0 = 15.
#   Balance the Books — get_score() = whole seconds spent in the gold zone → T0 = 20.
const GAME_BASE_THRESHOLDS := {
	TIMING_BAR:    6.0,
	MEMORY_MATCH:  4.0,
	MATCH_THREE:   200.0,
	BASKETBALL:    5.0,
	CATCH_MONEY:   15.0,
	BALANCE_BOOKS: 20.0,
}


## Every game key, in a stable order (used by the later CHALLENGES screen and by total_income_bonus).
static func game_keys() -> Array:
	return GAME_BASE_THRESHOLDS.keys()


# ── Curve parameters (configured from TuningConfig) ───────────────────────────
# GROWTH, BASE_PCT and DECAY are Balance-Tuning knobs, but this table is stateless — so they live
# here as `static var` config with sensible defaults and are pushed in from tuning by DynastyState,
# the same "configure a stateless table from tuning" pattern LegacyUpgradeCatalog.cost_multiplier /
# StaffRetention use. The math below reads these statics.
#
# GOTCHA (project note): DynastyState re-pushes this config on EVERY construction/load, so a sim
# that wants a custom curve must set the TUNING field before building the dynasty (or call
# configure() AFTER), never poke the statics and then build a dynasty — the build would overwrite
# them. The defaults mirror tuning.tres so a headless call that skips configure() still behaves.
static var growth := 1.6     # per-tier score-threshold growth (tuning.challenge_goal_growth)
static var base_pct := 0.005 # tier-1 income bonus, a fraction (tuning.challenge_reward_base_pct)
static var decay := 0.6      # geometric decay of the per-tier bonus (tuning.challenge_reward_decay)


## Push the curve knobs in from tuning. Called by DynastyState wherever the other stateless tables
## are configured, so every threshold/reward query sees the tuned curve.
static func configure(p_growth: float, p_base_pct: float, p_decay: float) -> void:
	growth = p_growth
	base_pct = p_base_pct
	decay = p_decay


# ── The math ──────────────────────────────────────────────────────────────────

## The get_score() a run must reach to clear tier `t` (1-based) of a game: T0 × GROWTH^(t-1).
## Returns INF for an unknown game key so no score can ever "clear" a game that isn't in the table.
static func threshold(game_key: String, tier: int) -> float:
	if not GAME_BASE_THRESHOLDS.has(game_key) or tier < 1:
		return INF
	var t0 := float(GAME_BASE_THRESHOLDS[game_key])
	return t0 * pow(growth, float(tier - 1))


## The permanent income bonus (a fraction) granted by clearing ONE tier `t`: BASE_PCT × DECAY^(t-1).
## Diminishes geometrically, so tier 1 pays the most and each further rung pays a shrinking sliver.
static func tier_reward(tier: int) -> float:
	if tier < 1:
		return 0.0
	return base_pct * pow(decay, float(tier - 1))


## The total income bonus (a fraction) from keeping the highest tier cleared for ONE game — the
## closed-form geometric sum of tier_reward(1..cleared), NOT a loop:
##     BASE_PCT × (1 − DECAY^cleared) / (1 − DECAY)
## 0 when cleared = 0. Because DECAY < 1 this converges to BASE_PCT/(1−DECAY) as cleared grows.
static func game_income_bonus(cleared_tier: int) -> float:
	if cleared_tier <= 0:
		return 0.0
	# Guard the DECAY == 1 singularity (the closed form divides by 1 − DECAY). At exactly 1.0 the
	# per-tier reward never diminishes, so the sum is just linear: cleared × BASE_PCT. (This is a
	# safety net for a hand-set tuning value; the design intends DECAY < 1 so the sum converges.)
	if is_equal_approx(decay, 1.0):
		return base_pct * float(cleared_tier)
	return base_pct * (1.0 - pow(decay, float(cleared_tier))) / (1.0 - decay)


## How many tiers a given get_score() clears for a game — the highest tier `t` whose threshold the
## score meets (0 if it doesn't reach tier 1). Monotonic in score by construction: it counts up
## while score ≥ threshold(t), so it is exactly consistent with threshold() at every boundary (a
## score AT a tier's threshold clears that tier). A simple count keeps it provably aligned with the
## threshold formula; scores are small bounded integers, so the loop is cheap.
static func highest_tier_for_score(game_key: String, score: float) -> int:
	if not GAME_BASE_THRESHOLDS.has(game_key):
		return 0
	# A non-growing curve (GROWTH ≤ 1) would let every rung sit at/below the same score and the
	# count never terminate; the design keeps GROWTH > 1, but guard the misconfiguration anyway.
	if growth <= 1.0:
		return 1 if score >= threshold(game_key, 1) else 0
	var tier := 0
	while score >= threshold(game_key, tier + 1):
		tier += 1
	return tier


## The whole-mode income bonus (a fraction): the sum of each game's game_income_bonus over its
## highest cleared tier. `highest_tiers` is {game_key -> highest tier cleared, int}; missing games
## contribute 0. This is the number folded into property income as (1 + total_income_bonus).
static func total_income_bonus(highest_tiers: Dictionary) -> float:
	var total := 0.0
	for game_key in highest_tiers:
		total += game_income_bonus(int(highest_tiers[game_key]))
	return total
