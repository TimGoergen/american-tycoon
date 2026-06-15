class_name WageState

# Wage ladder runtime state (Spec §5) — Layer 1, the only honest money in
# the game. No scene-tree dependencies.

## Array[TitleRow] in ladder order; index 0 is the starting job.
var titles: Array

## Index into `titles` of the player's current job title.
var current_title_index: int = 0

## Dynastic lifetime wage-tap count ("Work Ethic" in the Ledger).
## Persists across generations and planets — never reset.
var lifetime_taps: int = 0

## The lifetime_taps value at the moment the CURRENT title was entered. Promotion
## progress is measured relative to this baseline, so the meter always reflects how
## far the player has climbed within their current job title — not the dynasty's
## ever-growing lifetime total. It moves forward on each promotion, and an heir is
## seeded with their inherited tap count so they re-climb the ladder from zero
## rather than inheriting a meter that is already full (set by DynastyState).
var taps_at_title_start: int = 0

## Dynasty-wide wage multiplier from the Legacy "Old-Money Connections" upgrade
## (1.0 = base wage). Set by DynastyState from the purchased upgrades; multiplies
## the wage earned per tap on top of the frenzy multiplier.
var wage_multiplier: float = 1.0


func _init(p_titles: Array) -> void:
	titles = p_titles


## Tap the wage button. Returns the dollars earned (floored at award, Spec §1).
## `income_multiplier` is the frenzy multiplier — frenzy applies to all income
## including the wage (Spec §7).
func tap_wage(income_multiplier: float = 1.0) -> float:
	lifetime_taps += 1
	var title := titles[current_title_index] as TitleRow
	return floorf(title.wage_per_tap * income_multiplier * wage_multiplier)


func get_current_title() -> TitleRow:
	return titles[current_title_index] as TitleRow


## The next rung up, or null at the top of the ladder.
func get_next_title() -> TitleRow:
	if current_title_index + 1 >= titles.size():
		return null
	return titles[current_title_index + 1] as TitleRow


## Taps earned since entering the current title — the rung-relative count that the
## promotion meter shows. (lifetime_taps is dynastic and only grows; this is what
## resets to 0 each time a new title begins.)
func taps_in_current_title() -> int:
	return lifetime_taps - taps_at_title_start


## Taps needed to climb the current rung: the gap between this title's threshold and
## the next's. 0 at the top of the ladder (no next title).
func taps_required_for_promotion() -> int:
	var next := get_next_title()
	if next == null:
		return 0
	return next.tap_threshold - get_current_title().tap_threshold


## Promotion eligibility (Spec §5): enough taps earned WITHIN the current title for
## the next one. Claiming additionally costs tuition — GameState checks the cash.
func is_promotion_unlocked() -> bool:
	var next := get_next_title()
	return next != null and taps_in_current_title() >= taps_required_for_promotion()


## Advance to the next title. Caller must have verified eligibility and paid tuition.
## The new title's progress starts fresh, so rebase the baseline to the current tap
## count (the meter refills from empty on the new rung).
func claim_promotion() -> void:
	current_title_index += 1
	taps_at_title_start = lifetime_taps
