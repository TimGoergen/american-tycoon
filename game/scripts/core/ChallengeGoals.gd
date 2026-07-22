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


# ── Two costing models: FLAT STEP vs. ESCALATING per-tier cost ────────────────
# Four of the six games use a FLAT per-tier STEP (this table): tier = floor(get_score() / STEP). The
# two LOW-CEILING games (Micro Basketball, Memory Match) use an ESCALATING cost instead (see the next
# block) — their get_score() tops out at a small count, so a flat cost is a bad fit: either the early
# tiers are unreachable or the summit is trivial. game_keys() lists ALL SIX in a stable order (it is no
# longer just STEP.keys(), since the escalating games are absent from STEP).

# ── The full roster, in a stable display order (used by the CHALLENGES screen + the total_* sums) ──
const GAME_KEYS := [MATCH_THREE, TIMING_BAR, MEMORY_MATCH, BASKETBALL, CATCH_MONEY, BALANCE_BOOKS]

# ── Per-game FLAT STEP (score per tier) — the four non-escalating games ────────
# ALL FIRST-PASS, DEVICE-TUNE. A game's tier is floor(get_score() / STEP), so STEP is the round score a
# single rung is worth. Sized off each game's get_score() scale so tier 30 (the +4/+4 summit) is a real
# but reachable mastery target. Rationale, read off each game's get_score():
#   Match Three       — get_score() = cumulative points (POINTS_PER_GEM = 10, a 3-match ≈ 30+); climbs
#                       into the thousands, so STEP = 1000 (tier 30 = 30,000 points — a long climb).
#   Timing Bar        — get_score() = successful lock count; STEP = 1 (one tier per lock).
#   Catch the Money   — get_score() = coins caught; a steady stream, STEP = 2 (tier 30 = 60 coins).
#   Balance the Books — get_score() = whole seconds in the gold zone; STEP = 2 (tier 30 = 60 seconds).
# Micro Basketball and Memory Match are DELIBERATELY ABSENT — they cost by the escalating model below.
const STEP := {
	MATCH_THREE:   1000.0,
	TIMING_BAR:    1.0,
	CATCH_MONEY:   2.0,
	BALANCE_BOOKS: 2.0,
}


# ── ESCALATING per-tier cost — the two low-ceiling games (Basketball, Memory) ──
# Tim's low-ceiling fix (Plans/Challenge_Mode.md): these two games' get_score() is a small count, so a
# flat STEP fails. Instead the cost of ONE tier starts cheap and climbs every 5 tiers, capped:
#
#     tier_cost(game, tier) = min(base + floor((tier-1)/5) * increment, cap)      [for tier >= 1]
#     score_to_reach_tier(game, tier) = cumulative_cost = sum of tier_cost(1..tier)
#
# So early tiers (and the first payouts) are reachable, and mastery is a real climb. The base/increment/
# cap are CONFIGURABLE from tuning (basketball_tier_* / memory_tier_* knobs) — pushed in by configure()
# — so the whole curve is live-tunable. Defaults (device-tune):
#   Micro Basketball  base 1, increment 1, cap 5 → tier 5 = 5 baskets, tier 10 = 15, tier 15 = 30.
#   Memory Match      base 0.2, increment 0.2, cap 1.0 → tier 5 ≈ 1 climb, tier 10 ≈ 3, tier 15 = 6.
# The defaults live in the static config below (escalating_cost); tuning.tres mirrors them so a headless
# call that skips configure() still behaves.


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


## Every game key, in a stable order (used by the CHALLENGES screen and by the total_* sums). Returns
## the full six-game roster — NOT STEP.keys(), which now omits the two escalating games.
static func game_keys() -> Array:
	return GAME_KEYS


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

## The escalating games' per-tier cost curve (base / increment / cap, in that game's score units),
## keyed by game. Pushed in from tuning (basketball_tier_* / memory_tier_* knobs) by configure(); the
## defaults here mirror tuning.tres so a headless call that skips configure() still behaves. See
## tier_cost() for how these are read.
static var escalating_cost := {
	BASKETBALL:   {"base": 1.0, "increment": 1.0, "cap": 5.0},
	MEMORY_MATCH: {"base": 0.2, "increment": 0.2, "cap": 1.0},
}

## The keep-alive top-up seconds a Balance point grants — the ONLY seconds_per_point that is tuned
## (tuning.balance_keepalive_seconds_per_point); every other game keeps its hardcoded SECONDS_PER_POINT
## table value. Pushed in by configure(); default mirrors tuning.tres / the old table entry (2.0).
static var balance_keepalive_seconds_per_point := 2.0
# The fraction of a hit's time-gain a MISS costs the keep-alive timer (tuning.challenge_miss_penalty_ratio).
# The backing var is `miss_penalty`, read through the miss_penalty_ratio() accessor below — a var and a
# func cannot share a name in GDScript, so this follows the same var/accessor split as timer_start /
# timer_start_seconds().
static var miss_penalty := 0.5


## Push the knobs in from tuning. Called by DynastyState wherever the other stateless tables are
## configured, so every bonus/timer/cost query sees the tuned values. The escalating-cost and
## balance-keepalive params are APPENDED with defaults so existing 4-arg callers (older sim harnesses)
## keep working — they simply reset the escalating curve to its defaults, which is what they want.
static func configure(
		p_bonus_scale: float, p_timer_start: float, p_timer_cap: float, p_miss_penalty_ratio: float,
		p_bball_base := 1.0, p_bball_increment := 1.0, p_bball_cap := 5.0,
		p_memory_base := 0.2, p_memory_increment := 0.2, p_memory_cap := 1.0,
		p_balance_keepalive := 2.0) -> void:
	bonus_scale = p_bonus_scale
	timer_start = p_timer_start
	timer_cap = p_timer_cap
	miss_penalty = p_miss_penalty_ratio
	escalating_cost[BASKETBALL] = {"base": p_bball_base, "increment": p_bball_increment, "cap": p_bball_cap}
	escalating_cost[MEMORY_MATCH] = {"base": p_memory_base, "increment": p_memory_increment, "cap": p_memory_cap}
	balance_keepalive_seconds_per_point = p_balance_keepalive


# ── The math ──────────────────────────────────────────────────────────────────

## True when a game costs by the ESCALATING model (Basketball, Memory) rather than the flat STEP.
static func is_escalating(game_key: String) -> bool:
	return escalating_cost.has(game_key)


## The round score one FLAT tier is worth for a game (STEP). Returns INF for an unknown/escalating key
## so the flat path can never clear a tier of a game that isn't in the STEP table (floor(score/INF)==0).
## Escalating games are priced by tier_cost()/cumulative_cost(), not this.
static func score_step(game_key: String) -> float:
	return float(STEP.get(game_key, INF))


## The cost (in that game's score units) of the SINGLE escalating tier `tier`, for an escalating game:
##     min(base + floor((tier-1)/5) * increment, cap)
## Cheap for tiers 1-5, then increment more expensive every 5 tiers, capped. 0 for tier < 1 or a
## non-escalating/unknown game (the flat games never call this).
static func tier_cost(game_key: String, tier: int) -> float:
	if tier < 1 or not is_escalating(game_key):
		return 0.0
	var cfg: Dictionary = escalating_cost[game_key]
	var bands_climbed: float = floorf(float(tier - 1) / float(PAYOUT_INTERVAL))  # +1 band every 5 tiers
	var cost: float = float(cfg["base"]) + bands_climbed * float(cfg["increment"])
	return minf(cost, float(cfg["cap"]))


## The cumulative escalating cost to REACH `tier` — the sum of tier_cost(1..tier). This is the score an
## escalating game needs to sit at exactly `tier`. 0 for tier <= 0. The loop runs to at most MAX_TIER,
## so it is cheap.
static func cumulative_cost(game_key: String, tier: int) -> float:
	var total := 0.0
	for t in range(1, tier + 1):
		total += tier_cost(game_key, t)
	return total


## The tier a given get_score() reaches for a game, clamped to [0, MAX_TIER]. Unknown key or negative
## score → 0. ESCALATING games count tiers while the cumulative cost is still covered by the score;
## FLAT games use floor(score / STEP) — simple round checkpoints, no growth curve.
static func tier_for_score(game_key: String, score: float) -> int:
	if score < 0.0:
		return 0
	if is_escalating(game_key):
		var tier := 0
		# Walk up while the score still covers the cost of the NEXT tier. The loop to MAX_TIER is cheap.
		while tier < MAX_TIER and cumulative_cost(game_key, tier + 1) <= score:
			tier += 1
		return tier
	var step := score_step(game_key)
	if step <= 0.0:
		return 0
	return clampi(int(floor(score / step)), 0, MAX_TIER)


## The score needed to REACH tier N — the number the UI should show as "reach X (tier N)". ESCALATING
## games → the cumulative escalating cost; FLAT games → tier * STEP. 0 for tier <= 0. This is the single
## helper both the CHALLENGES screen and any goal readout should use (never tier * score_step, which is
## wrong for the escalating games).
static func score_to_reach_tier(game_key: String, tier: int) -> float:
	if tier <= 0:
		return 0.0
	if is_escalating(game_key):
		return cumulative_cost(game_key, tier)
	return float(tier) * score_step(game_key)


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
## key (an unrecognised game grants no time). Balance the Books is the ONE tuned entry — it returns the
## live `balance_keepalive_seconds_per_point` knob so the Balance challenge feel is dialable; every
## other game keeps its hardcoded SECONDS_PER_POINT value.
static func seconds_per_point(game_key: String) -> float:
	if game_key == BALANCE_BOOKS:
		return balance_keepalive_seconds_per_point
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
