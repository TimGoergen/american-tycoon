class_name EpochState

# Tracks which alien epoch the current generation has reached THIS RUN
# (see Plans/Epoch_Staffing_System.md). Headless and scene-tree-free like the rest
# of the core, so the simulator and the scene layer drive the exact same logic.
#
# The rule (Tim 2026-06-16, extended 2026-07-23): a generation advances to the next epoch once it
# has EARNED the current epoch's entire economic value — "consumed the economy" — AND has bought at
# least one unit of every property in that epoch. Only then does the next civilization make contact
# and a larger market open. The ownership half makes the player engage the whole ladder rather than
# rush contact on a couple of high earners (see update's owns_all_in_tier). Earth is tier 1;
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


## Advance the epoch as far as the generation's lifetime earnings allow AND as far as it has
## ENGAGED the ladder. A generation advances OUT of an epoch only once it has BOTH (a) earned that
## epoch's entire economic value and (b) bought at least one unit of every property in it (Tim,
## 2026-07-23 — contact is earned by playing the whole epoch, not by rushing a couple of high
## earners). `owns_all_in_tier` is an optional Callable taking a 1-based tier and returning bool;
## when omitted (e.g. isolated money-mechanic tests) only the money gate applies. The ownership
## check is per-tier INSIDE the loop, so a single large tick can never skip past an un-owned epoch.
## Emits one contact signal per epoch crossed. Caps at the last defined epoch.
func update(cash_earned_this_gen: float, owns_all_in_tier: Callable = Callable()) -> void:
	while current_tier < EpochCatalog.tier_count():
		var threshold := EpochCatalog.consume_threshold(current_tier, _tuning.earth_economy_target)
		if cash_earned_this_gen < threshold:
			break
		if owns_all_in_tier.is_valid() and not owns_all_in_tier.call(current_tier):
			break
		current_tier += 1
		contact_made.emit(current_tier)


## Restore the reached epoch from a save (clamped to the valid range).
func restore(tier: int) -> void:
	current_tier = clampi(tier, 1, EpochCatalog.tier_count())
