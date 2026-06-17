class_name EpochState

# Tracks which alien epoch the current generation has reached THIS RUN
# (see Plans/Epoch_Staffing_System.md). Headless and scene-tree-free like the rest
# of the core, so the simulator and the scene layer drive the exact same logic.
#
# The rule (Tim 2026-06-16): a generation advances to the next epoch once it has
# EARNED the current epoch's entire economic value — it has "consumed the economy",
# so the next civilization makes contact and a larger market opens. Earth is tier 1;
# the climb resets each generation (a fresh EpochState is built with each GameState),
# and prestige/Legacy is what lets a later heir punch deeper into the ladder than the last.

## Which epoch this generation is currently in (1 = Earth). Also the highest staff
## tier any property is allowed to be hired/upgraded to right now.
var current_tier: int = 1

var _tuning: TuningConfig

## Emitted the moment a new epoch is reached (contact made). Carries the new tier so
## the UI can play a first-contact beat; the headless sim simply ignores it.
signal contact_made(new_tier: int)


func _init(p_tuning: TuningConfig) -> void:
	_tuning = p_tuning


## Advance the epoch as far as the generation's lifetime earnings allow. Called each
## tick with economy.cash_earned_this_gen (the monotonic "value extracted from the
## economy"). May cross several thresholds at once if a tick is large; emits one
## contact signal per epoch crossed. Caps at the last defined epoch.
func update(cash_earned_this_gen: float) -> void:
	while current_tier < EpochCatalog.tier_count():
		var threshold := EpochCatalog.consume_threshold(current_tier, _tuning.earth_economy_target)
		if cash_earned_this_gen < threshold:
			break
		current_tier += 1
		contact_made.emit(current_tier)


## Restore the reached epoch from a save (clamped to the valid range).
func restore(tier: int) -> void:
	current_tier = clampi(tier, 1, EpochCatalog.tier_count())
