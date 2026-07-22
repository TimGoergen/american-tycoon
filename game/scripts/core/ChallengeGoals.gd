class_name ChallengeGoals

# The catalog + math for CHALLENGE MODE's AUTHORED TIER LADDERS (Plans/Challenge_Mode.md).
# A pure DATA-plus-MATH table in code, the same shape as LegacyUpgradeCatalog.gd / EpochCatalog.gd:
# static, stateless, no scene tree, no instance to create.
#
# THE MODEL (rebuilt 2026-07-20 — replaces the old geometric diminishing-returns curve):
# Each of the six minigames climbs a simple, FINITE ladder of round score checkpoints. A game's TIER
# is just how many whole STEPs its Minigame.get_score() has passed:
#
#     tier(game, score) = floor(score / STEP(game))          clamped to MAX_TIER (30)
#
# STEP is per-game because each game's get_score() lives on a wildly different scale (Match Three's
# cumulative points vs. Memory's round count). Tiers are mostly progress-only; a PERCENT PAYOUT lands
# on every 5th tier, on a SINGLE schedule shared by all six games, ALTERNATING income and Legacy and
# escalating in value:
#
#     tier  5 → +1% INCOME      tier 10 → +1% LEGACY
#     tier 15 → +2% INCOME      tier 20 → +2% LEGACY
#     tier 25 → +1% INCOME      tier 30 → +1% LEGACY
#
# So a single mastered game maxes at +4% income AND +4% Legacy; all six maxed ≈ +24% income + +24%
# Legacy (Tim's ~25/25 target). A `bonus_scale` knob nudges the whole thing and lets Tim retune live.
# This is FINITE — there is a real "mastered" top at tier 30 (MAX_TIER). That intentionally REVERSES
# the old "no hard ceiling" design: mastery is now a reachable summit, not an endless trickle.
#
# TWO REWARD TRACKS, both permanent and dynasty-wide (survive prestige):
#   • the INCOME payouts feed the property-income multiplier (DynastyState.get_legacy_income_multiplier)
#   • the LEGACY payouts feed the Legacy-YIELD multiplier (the Estate Lawyers lever —
#     DynastyState.get_legacy_yield_multiplier, alongside LegacyUpgrades.legacy_yield_multiplier()).
#
# The game KEY is each minigame type's DISPLAY NAME — the exact string returned by that type's
# Minigame.display_name(). MinigameScreen keys challenge scores by _active_minigame.display_name(), so
# using display_name() here keeps the ladders, the arcade score store, and the CHALLENGES screen all
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


# ── The payout schedule (shared by all six games) ─────────────────────────────
const PAYOUT_INTERVAL := 5   # a payout lands on every 5th tier
const MAX_TIER := 30         # the finite "mastered" summit — 6 payouts, then done

## The single payout schedule: {tier -> {"pct": whole-percent float, "type": "income"|"legacy"}}.
## `pct` is in WHOLE PERCENT (1.0 = +1%); the *_bonus_for() helpers divide by 100 to a fraction and
## apply the bonus_scale knob. ALTERNATES income/legacy and escalates 1→1→2→2→1→1 per track, so each
## game tops out at +4% income and +4% Legacy. THE SAME for every game (score scale differs, reward
## schedule does not). See Plans/Challenge_Mode.md.
const PAYOUT_SCHEDULE := {
	5:  {"pct": 1.0, "type": "income"},
	10: {"pct": 1.0, "type": "legacy"},
	15: {"pct": 2.0, "type": "income"},
	20: {"pct": 2.0, "type": "legacy"},
	25: {"pct": 1.0, "type": "income"},
	30: {"pct": 1.0, "type": "legacy"},
}


# ── Per-game STEP (score per tier) ────────────────────────────────────────────
# ALL FIRST-PASS, DEVICE-TUNE. A game's tier is floor(get_score() / STEP), so STEP is the round score
# a single rung is worth. Sized off each game's get_score() scale so tier 30 (the +4/+4 summit) is a
# real but reachable mastery target. Rationale, read off each game's get_score():
#   Match Three       — get_score() = cumulative points (POINTS_PER_GEM = 10, a 3-match ≈ 30+); climbs
#                       into the thousands, so STEP = 1000 (tier 30 = 30,000 points — a long climb).
#   Timing Bar        — get_score() = successful lock count; STEP = 1 (one tier per lock).
#   Memory Match      — get_score() = rounds recalled. LOW-CEILING game: a small round count, so a
#                       STEP of 1 put the summit far out of reach. STEP = 0.2 (five rungs per whole
#                       round) so the ladder is reachable. NOTE: this pairs with Wave B, which makes
#                       Memory's get_score() = completed 1→6 CLIMBS — so 0.2 means one climb clears one
#                       PAYOUT tier (every 5th rung), and 6 climbs = tier 30 mastered. If Wave B changes
#                       Memory's scoring, re-check this. See Plans §"Low-ceiling games".
#   Micro Basketball  — get_score() = baskets sunk; ~6 a strong round, so a STEP of 1 put the summit out
#                       of reach. STEP = 0.25 (four rungs per basket) so ~8 baskets reach the top tier —
#                       a reachable mastery target for a slow-to-line-up game.
#   Catch the Money   — get_score() = coins caught; a steady stream, STEP = 2 (tier 30 = 60 coins).
#   Balance the Books — get_score() = whole seconds in the gold zone; STEP = 2 (tier 30 = 60 seconds).
const STEP := {
	MATCH_THREE:   1000.0,
	TIMING_BAR:    1.0,
	MEMORY_MATCH:  0.2,   # low-ceiling: 5 rungs per round; pairs with Wave B's 1→6-climb Memory scoring
	BASKETBALL:    2.0,   # ~2 baskets per tier (Tim 2026-07-22: a basket shouldn't jump tiers); its low
	                      # score ceiling then caps it at low tiers — intended, not a bug
	CATCH_MONEY:   2.0,
	BALANCE_BOOKS: 2.0,
}


# ── Per-game keep-alive TIMER seconds-per-point (Wave 2 reads this) ───────────
# The challenge run's keep-alive timer tops up by this many seconds for each POINT the run's
# get_score() gains (Plans §"Keep-alive run timer"; the mechanic itself is Wave 2). Sized inversely to
# how fast each game scores so a top-up feels comparable across games — Match Three racks up points in
# bulk (tiny per-point top-up), the slower games grant a fat second or more per point. ALL FIRST-PASS,
# DEVICE-TUNE.
const SECONDS_PER_POINT := {
	MATCH_THREE:   0.012,  # less clock per match → a harder push (Tim, 2026-07-21; was 0.02)
	TIMING_BAR:    3.0,
	MEMORY_MATCH:  4.0,
	BASKETBALL:    5.0,    # more clock per basket — baskets are slow to line up (Tim; was 3.0)
	CATCH_MONEY:   1.5,
	BALANCE_BOOKS: 2.0,
}


# ── Per-game keep-alive TIMER starting-seconds override ───────────────────────
# A game listed here starts its keep-alive run with THIS many seconds instead of the global
# `timer_start` knob, so a game that needs a longer runway to get going can have one. FIRST-PASS,
# DEVICE-TUNE. Micro Basketball gets a longer opening budget because lining up the first few shots is
# slow (Tim, 2026-07-21: "too difficult to line up multiple shots"). Games not listed fall back to the
# global knob (default 6.0). See timer_start_seconds().
const TIMER_START := {
	BASKETBALL: 10.0,
}


## Every game key, in a stable order (used by the CHALLENGES screen and by the total_* sums).
static func game_keys() -> Array:
	return STEP.keys()


# ── Configurable knobs (pushed in from TuningConfig) ──────────────────────────
# bonus_scale, timer_start and timer_cap are Balance-Tuning knobs, but this table is stateless — so
# they live here as `static var` config with sensible defaults and are pushed in from tuning by
# DynastyState, the same "configure a stateless table from tuning" pattern LegacyUpgradeCatalog and
# StaffRetention use. The math below reads these statics.
#
# GOTCHA (project note): DynastyState re-pushes this config on EVERY construction/load, so a sim that
# wants custom knobs must set the TUNING field before building the dynasty (or call configure() AFTER),
# never poke the statics and then build a dynasty — the build would overwrite them. The defaults mirror
# tuning.tres so a headless call that skips configure() still behaves.
static var bonus_scale := 1.0    # global x on every payout (tuning.challenge_bonus_scale)
static var timer_start := 6.0    # keep-alive timer's starting seconds (tuning.challenge_timer_start_seconds)
static var timer_cap := 15.0     # keep-alive timer's max seconds (tuning.challenge_timer_cap_seconds)
# The fraction of a hit's time-gain a MISS costs the keep-alive timer (tuning.challenge_miss_penalty_ratio).
# The backing var is `miss_penalty`, read through the miss_penalty_ratio() accessor below — a var and a
# func cannot share a name in GDScript, so this follows the same var/accessor split as timer_start /
# timer_start_seconds().
static var miss_penalty := 0.5


## Push the knobs in from tuning. Called by DynastyState wherever the other stateless tables are
## configured, so every bonus/timer query sees the tuned values.
static func configure(p_bonus_scale: float, p_timer_start: float, p_timer_cap: float, p_miss_penalty_ratio: float) -> void:
	bonus_scale = p_bonus_scale
	timer_start = p_timer_start
	timer_cap = p_timer_cap
	miss_penalty = p_miss_penalty_ratio


# ── The math ──────────────────────────────────────────────────────────────────

## The round score one tier is worth for a game (STEP). Returns INF for an unknown key so no score can
## ever clear a tier of a game that isn't in the table (floor(score / INF) == 0).
static func score_step(game_key: String) -> float:
	return float(STEP.get(game_key, INF))


## The tier a given get_score() reaches for a game: floor(score / STEP), clamped to [0, MAX_TIER].
## Simple round checkpoints — no growth curve. Unknown game key or non-positive score → 0.
static func tier_for_score(game_key: String, score: float) -> int:
	var step := score_step(game_key)
	if step <= 0.0 or score < 0.0:
		return 0
	var tier := int(floor(score / step))
	return clampi(tier, 0, MAX_TIER)


## The payout that lands AT a given tier: {"pct": whole-percent float, "type": "income"|"legacy"}.
## Empty {} for a progress-only tier (anything not on the every-5th schedule, or above MAX_TIER).
static func payout_at_tier(tier: int) -> Dictionary:
	return PAYOUT_SCHEDULE.get(tier, {})


## The next tier that pays out, above `cleared_tier` — the next multiple of PAYOUT_INTERVAL. Returns -1
## when the ladder is mastered (no payout tier left ≤ MAX_TIER). Used by the screen for "next reward
## at tier N".
static func next_payout_tier(cleared_tier: int) -> int:
	var next_tier := (int(floor(float(cleared_tier) / float(PAYOUT_INTERVAL))) + 1) * PAYOUT_INTERVAL
	if next_tier > MAX_TIER:
		return -1
	return next_tier


## Sum the whole-percent payouts of one track ("income" or "legacy") at every payout tier ≤ cleared,
## then scale and convert to a FRACTION (× bonus_scale ÷ 100). The shared helper behind income_bonus_for
## and legacy_bonus_for.
static func _summed_payout(cleared_tier: int, track: String) -> float:
	var pct_total := 0.0
	for tier in PAYOUT_SCHEDULE:
		if int(tier) <= cleared_tier and String(PAYOUT_SCHEDULE[tier]["type"]) == track:
			pct_total += float(PAYOUT_SCHEDULE[tier]["pct"])
	return pct_total * bonus_scale / 100.0


## The permanent INCOME bonus (a fraction) from a single game's cleared tier — the summed income
## payouts up to that tier, × bonus_scale. A game mastered to tier 30 gives +4% (× scale).
static func income_bonus_for(cleared_tier: int) -> float:
	return _summed_payout(cleared_tier, "income")


## The permanent LEGACY-YIELD bonus (a fraction) from a single game's cleared tier — the summed legacy
## payouts up to that tier, × bonus_scale. A game mastered to tier 30 gives +4% (× scale).
static func legacy_bonus_for(cleared_tier: int) -> float:
	return _summed_payout(cleared_tier, "legacy")


## The whole-mode INCOME bonus (a fraction): the sum of each game's income_bonus_for over its highest
## cleared tier. `highest_tiers` is {game_key -> highest tier cleared, int}; missing games contribute 0.
## This is folded into property income as (1 + total_income_bonus).
static func total_income_bonus(highest_tiers: Dictionary) -> float:
	var total := 0.0
	for game_key in highest_tiers:
		total += income_bonus_for(int(highest_tiers[game_key]))
	return total


## The whole-mode LEGACY-YIELD bonus (a fraction): the sum of each game's legacy_bonus_for over its
## highest cleared tier. Folded into the Legacy-yield path as (1 + total_legacy_bonus).
static func total_legacy_bonus(highest_tiers: Dictionary) -> float:
	var total := 0.0
	for game_key in highest_tiers:
		total += legacy_bonus_for(int(highest_tiers[game_key]))
	return total


# ── Keep-alive run timer params (Wave 2 reads these) ──────────────────────────

## Seconds the keep-alive timer tops up per POINT of get_score() gained, for a game. 0 for an unknown
## key (an unrecognised game grants no time).
static func seconds_per_point(game_key: String) -> float:
	return float(SECONDS_PER_POINT.get(game_key, 0.0))


## The keep-alive timer's starting seconds for a game: the per-game TIMER_START override if the game
## has one, else the global `timer_start` tuning knob. Called with a game key by the host; called with
## no key (the default "") it always returns the global knob.
static func timer_start_seconds(game_key := "") -> float:
	return float(TIMER_START.get(game_key, timer_start))


## The keep-alive timer's maximum seconds — top-ups never bank past this (tuning knob).
static func timer_cap_seconds() -> float:
	return timer_cap


## The fraction of a hit's time-gain that a MISS costs the keep-alive timer (0.5 = half). When a
## challenge minigame emits Minigame.challenge_time_penalty(points), the host drains the timer by
## miss_penalty_ratio() x points x seconds_per_point (tuning.challenge_miss_penalty_ratio).
static func miss_penalty_ratio() -> float:
	return miss_penalty
