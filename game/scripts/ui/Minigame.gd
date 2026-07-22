class_name Minigame
extends Control

# Common contract for one prestige/transition minigame TYPE (GDD §5.5). The MinigameHost
# picks a type at random, fills the play area with it, runs it, and reads a normalized
# performance in [0,1] (0 = worst, 1 = best possible) which the host maps to the universal
# 0.5x .. 1.25x outcome multiplier. A type renders ONLY its own gameplay and reports
# performance — it does not own the countdown, the spectrum bar, the result screen, the
# skip/opt-out, or the multiplier math (the host owns all of that, identically for every
# type, so they all share one outcome model).

## Emit when the game finishes on its own (e.g. a fixed number of rounds). The host also
## ends on its countdown; whichever happens first wins, using the final performance.
signal completed(performance: float)

## Ask the host to flash a big centered banner over the screen — the SAME look and size as the
## universal "MAX!" celebration — then run `after` once it finishes. A type uses this to announce a
## mid-round beat (Memory's "GEM ROUND" before its bonus round) so the announcement matches MAX!
## exactly. The host connects this and owns the flash; a type with no host (unit tests) simply sees
## nothing happen. `after` may be an empty Callable.
signal banner_requested(text: String, color: Color, after: Callable)

## The host's outcome curve, set by the host BEFORE begin() so a type that wants to align its
## internal scoring to where the shared "full" (1.0x) line falls can read it. `keep_floor` is
## the multiplier at performance 0; `bonus_max` is the extra-high bonus above 1.0x at
## performance 1.0. The 1.0x "full" line therefore sits at performance
## (1 - keep_floor) / ((1 - keep_floor) + bonus_max). Most types ignore these; match-3 uses
## them so "regular non-bonus play = exactly full" holds regardless of the site's bonus cap.
var outcome_keep_floor: float = 0.5
var outcome_bonus_max: float = 0.25
## The performance (0..1) the host maps to exactly 1.0 ("standard" play). Set by the host before
## begin(), so a type that aligns its scoring to the "full" line (match-3) reads the same neutral
## point the host uses. Below it the reward eases down to keep_floor; above it, up into the bonus.
var outcome_full_performance: float = 0.5

## Challenge Mode (Tim, 2026-06-30): the host sets this true BEFORE begin() when the player picks
## Challenge Mode on the Minigame Tuning screen. In Challenge Mode a type must run ENDLESSLY — no
## self-completion (never emit `completed`), no reliance on the host's countdown, and MISTAKES DO
## NOT STOP PLAY (a miss simply doesn't score; the player plays until they tap DONE). In normal
## (reward) mode it stays false and the type behaves exactly as before.
var challenge_mode: bool = false

## The type's raw cumulative SCORE, used only by Challenge Mode's high-score tracking — e.g. points
## scored, coins caught, baskets made, rounds recalled, seconds balanced. This is DISTINCT from
## get_performance() (the normalized [0,1] reward metric): a score is unbounded and grows the longer
## you play well. Override in each type; default 0.
func get_score() -> int:
	return 0

# --- Legacy Bonus (GDD §5.5; Plans/Legacy_Bonus_System.md) ------------------------------------
# Every type has a small, game-specific chance to let the player collect a bonus Legacy gem (match
# 3 legacy gems, catch a gem-coin, land a lock on a gem, fill the fishing gem bar, shoot through a
# gem). A collected gem is PROVISIONAL: the host gates the payout by the round's overall result
# (bad = keep none, normal = keep, great = +bonus) and grants a share of the dynasty's lifetime
# Legacy. A type only signals WHEN a gem is collected; the host owns the amount and the grant.

## Legacy gems collected this round via this type's own mechanic. Read by the host at round end.
var _legacy_gems_collected: int = 0

## How many gems fully earn this round's bonus (from tuning.legacy_bonus_max_gems). The host sets
## this before begin(). Once this many are collected the bonus is secured, so a type must STOP
## spawning new legacy gems (design rule 3 — no pointless noise once earned). See legacy_bonus_secured.
var legacy_bonus_cap: int = 1

## Call this from a type when its legacy-gem mechanic succeeds. Increments the provisional count.
func collect_legacy_gem(count: int = 1) -> void:
	_legacy_gems_collected += maxi(0, count)

## How many legacy gems this type collected this round (the host gates and grants from this).
func get_legacy_gems_collected() -> int:
	return _legacy_gems_collected

## True once enough gems are collected to fully earn this round's bonus. Every type must check this
## before spawning a NEW legacy gem and skip the spawn when it returns true, so no more gems appear
## once the player has already earned the bonus (Tim, 2026-07-09 — avoid unnecessary noise).
func legacy_bonus_secured() -> bool:
	return _legacy_gems_collected >= maxi(1, legacy_bonus_cap)


## Start play. The host calls this once, after adding this control to the play area.
func begin(tuning: TuningConfig) -> void:
	pass

## Current performance in [0,1]. The host reads it live for the spectrum bar, and as the
## final result when its countdown expires.
func get_performance() -> float:
	return 0.0

## True while the type is mid-animation; the host pauses its countdown so animation time
## isn't charged to the player. Most types never block.
func is_busy() -> bool:
	return false

## Whether this type runs against the host's countdown timer. Almost every type does, so the default
## is true. A type that returns false (Memory — recalling a sequence against a clock adds nothing and
## the bonus sequence can't be rushed) gets NO timer at all: the host hides the countdown and never
## ends the round on the clock or on a max-early-out. Such a type OWNS its own ending — it must emit
## `completed` itself when play is over (on a win, a miss, or its own bonus round).
func uses_timer() -> bool:
	return true

## CHALLENGE MODE self-ending hook (Plans/Challenge_Mode.md, Wave A). Override to TRUE if this game
## ends its OWN challenge run (via the `completed` signal — e.g. a wrong tap) instead of the shared
## keep-alive timer. The host then skips the timer for it and treats `completed` as the run end.
## (Memory will override this in Wave B.) Default false: the run is governed by the keep-alive timer.
func challenge_self_ends() -> bool:
	return false

## A short, human-readable name for this minigame type. The random prestige draw doesn't
## need it, but the Minigame Tuning review screen (Settings) lists every type by name so
## they can each be opened and tested. Override in each type.
func display_name() -> String:
	return "Minigame"

## A one-line "how to play" goal for this type, shown on the host's Get Ready gate BEFORE the
## clock starts (so the player learns the objective up front, not only once play begins). Each
## type also shows this same line as its in-round intro, so the two never diverge. Override in
## each type.
func how_to_play() -> String:
	return ""

## Extra seconds this type adds on top of the host's standard round length
## (tuning.minigame_duration_seconds). Most types add none; a type that needs more breathing
## room than the shared default — e.g. the slingshot basketball — overrides this. The host reads
## it once when the round starts and lengthens its countdown accordingly. Override in each type.
func extra_seconds() -> float:
	return 0.0

## A short line summarizing how the player DID this round (e.g. "Scored 1,240 points",
## "Caught 14 of 18"), shown on the host's result screen beneath the multiplier so the paused
## result clearly reflects the game just played. Default empty -> the host shows only the
## multiplier/amount. Override in each type.
func result_summary() -> String:
	return ""
