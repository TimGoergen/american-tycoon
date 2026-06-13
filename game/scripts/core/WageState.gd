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


## Promotion eligibility (Spec §5): enough lifetime taps for the next title.
## Claiming additionally costs tuition — GameState checks the cash.
func is_promotion_unlocked() -> bool:
	var next := get_next_title()
	return next != null and lifetime_taps >= next.tap_threshold


## Advance to the next title. Caller must have verified eligibility and paid tuition.
func claim_promotion() -> void:
	current_title_index += 1
