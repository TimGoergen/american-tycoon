class_name WageState

# Wage ladder runtime state (Spec §5) — Layer 1, the only honest money in the game.
# No scene-tree dependencies.
#
# The ladder is a simple numeric LEVEL (Tim, 2026-06-24), no longer a list of named job
# titles drawn from config. Each "clock in" tap earns a wage that grows with the level, and
# the level rises every time the player completes the clicks it requires: 10 clicks for the
# first level, then 20 for the next, then 30, and so on (advancing from level N costs
# (N+1)×10 clicks). The level is exactly the number of times the player has completed a
# level's click requirement.
#
# EXECUTIVE COMPENSATION (Tim, 2026-07-05): the ladder alone died the moment the first
# ATM was bought — a fixed dollar ladder can never keep pace with a per-second-compounding
# economy, so clocking in stopped being a viable play within minutes. A tap therefore pays
# the ladder wage OR a fraction of a second of the empire's passive income, whichever is
# GREATER (executive_wage_floor below, fed by GameState each tick). Early on it is an
# honest hourly wage; once you own the economy, "clocking in" is the tycoon awarding
# himself executive compensation — the number grows with the empire, and so does the joke.
#
# The clock-in LEVEL scales that compensation too (Tim, 2026-07-15): the floor pays
# (1 + bonus_per_level × level), so a level-up always visibly raises the per-tap payout.
# Before this, once the floor overtook the ladder, leveling up changed a number that had
# already lost the max() — the badge blinked and the payout stayed identical.


## Clicks the FIRST level-up costs; each later level costs this much more — 10, 20, 30, …
## (Tim's rule, 2026-06-24).
const CLICKS_PER_LEVEL_STEP := 10

## The wage one tap earns at level 0, before any multipliers. Feel-tune.
const WAGE_BASE_PER_TAP := 1.0

## How much the per-tap wage multiplies for each level gained. Deliberately above the old
## ladder's ~2× step so the clock-in income ramps up FASTER as the player levels (Tim,
## 2026-06-24). Feel-tune.
const WAGE_GROWTH_PER_LEVEL := 2.5

## The player's current clock-in level. 0 at the very start; rises by one each time the click
## requirement for the next level is met (= the number of completed level-ups).
var level: int = 0

## Clicks banked toward the NEXT level-up. Resets at each level-up, carrying any surplus
## clicks forward so no tap is wasted.
var taps_into_level: int = 0

## Dynastic lifetime wage-tap count ("Work Ethic" in the Ledger). Persists across generations
## and planets — never reset.
var lifetime_taps: int = 0

## Dynasty-wide wage multiplier from the Legacy "Old-Money Connections" upgrade (1.0 = base
## wage). Set by DynastyState from the purchased upgrades; multiplies the wage earned per tap
## on top of the frenzy multiplier.
var wage_multiplier: float = 1.0

## Dynasty-wide auto-tap SPEED multiplier from the Legacy auto-click upgrade (1.0 = base).
## WagePanel multiplies the held "clock in" auto-tap RATE by this. Set by DynastyState.
var auto_tap_speed_multiplier: float = 1.0

## The "executive compensation" floor: a fraction of a second of the empire's passive
## income (tuning.wage_passive_fraction × passive income/sec), refreshed by GameState
## every tick. A tap pays this whenever it beats the ladder wage, so clocking in stays a
## viable active-income verb at every scale of the economy (see the class header). Held
## here — not looked up — so WageState keeps zero dependencies on the economy.
var executive_wage_floor: float = 0.0

## Executive-pay bonus per clock-in level, as a fraction of the floor (0.05 = +5% per level).
## Fed by GameState from tuning.wage_floor_bonus_per_level alongside the floor itself, so
## WageState keeps zero dependencies and the knob stays live-tunable.
var executive_floor_bonus_per_level: float = 0.0


## Tap the wage button. Earns the current level's wage (floored at award, Spec §1), banks the
## click toward the next level-up, and levels up — carrying any surplus clicks — once the
## requirement is met. `income_multiplier` is the frenzy multiplier (frenzy applies to all
## income including the wage, Spec §7). The completing tap earns at the OLD level; the next
## tap earns at the new, higher level.
func tap_wage(income_multiplier: float = 1.0) -> float:
	lifetime_taps += 1
	var earned := peek_wage(income_multiplier)
	taps_into_level += 1
	# Level up as many times as the banked clicks allow (an early run of cheap levels could
	# clear more than one at once), carrying the remainder forward each time.
	while taps_into_level >= clicks_required_for_next_level():
		taps_into_level -= clicks_required_for_next_level()
		level += 1
	return earned


## The EXACT wage a single tap earns right now — manual or held — and the number the clock-in
## button previews. Folds in frenzy (income_multiplier) and Old-Money Connections (wage_multiplier,
## the "how much it pays" lever), floored ONCE. Does not mutate state, so the button's "+$x" and the
## payment always agree, for a tap OR a hold (Tim, 2026-07-26). Auto-tap SPEED (Restless Hands) is
## the separate "how fast holding works" lever; there is no per-held-tap payout bonus.
func peek_wage(income_multiplier: float = 1.0) -> float:
	return floorf(current_wage_per_tap() * income_multiplier * wage_multiplier)


## The base wage one tap earns right now, before frenzy / Legacy multipliers: the
## CURRENT level's ladder wage, or the level-boosted executive-compensation floor once the
## empire's passive income outgrows the ladder — whichever is greater. Payment (tap_wage) and
## the clock-in button's "+$x / tap" display both read this, so they can never disagree.
func current_wage_per_tap() -> float:
	# The level boosts the floor so a level-up always moves the payout, even deep into the
	# executive-compensation regime where the ladder wage lost the max() long ago.
	var boosted_floor := executive_wage_floor * (1.0 + executive_floor_bonus_per_level * float(level))
	return maxf(wage_per_tap_at_level(level), boosted_floor)


## The base wage one tap earns at `at_level`: base × growth^level (the per-level ramp).
func wage_per_tap_at_level(at_level: int) -> float:
	return WAGE_BASE_PER_TAP * pow(WAGE_GROWTH_PER_LEVEL, float(at_level))


## Clicks needed to advance from the current level to the next: 10 for level 0→1, 20 for
## 1→2, 30 for 2→3, … = (level + 1) × CLICKS_PER_LEVEL_STEP.
func clicks_required_for_next_level() -> int:
	return (level + 1) * CLICKS_PER_LEVEL_STEP


## The level the player is climbing toward — what the clock-in row's "<level> / <next>"
## label shows on its right side.
func next_level() -> int:
	return level + 1
