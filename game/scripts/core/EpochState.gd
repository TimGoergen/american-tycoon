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

## The last EARTH epoch. Tiers 1-2 (Blue/White Collar) keep the money gate; alien epochs
## (3+) advance on the flagship-units requirement instead (Plans/Epoch_Advance_Rework.md).
## Earth is exempt because it is the onboarding stretch: measured on a bare heir, applying
## the flagship gate to Earth stretched it from ~1.6 min to ~6.7 min and made it 80-92%
## stacking with no new content, which the locked "never slow the early game" rule forbids.
const LAST_EARTH_TIER := 2

## Which epoch this generation is currently in (1 = Earth). Also the highest staff
## tier any property is allowed to be hired/upgraded to right now.
var current_tier: int = 1

## When false, meeting the requirements does NOT advance on its own: `contact_ready` latches
## and the player chooses the moment via the MAKE CONTACT control (advance()). The scene
## layer sets this false; headless sims leave it TRUE so playouts still climb by themselves
## and every existing study keeps working untouched.
var auto_advance: bool = true

## True when every requirement to leave `current_tier` is satisfied but contact has not been
## made yet. Only ever set while `auto_advance` is false. Drives the MAKE CONTACT control.
var contact_ready: bool = false

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
	contact_ready = false
	while current_tier < EpochCatalog.tier_count():
		if not _may_leave(current_tier, cash_earned_this_gen, owns_all_in_tier):
			break
		if not auto_advance:
			# Requirements met, but leaving is the player's call — latch and wait.
			contact_ready = true
			break
		_enter_next_epoch()


## Every requirement for leaving `tier`. Earth epochs use the money threshold; alien epochs
## use the ownership predicate alone, because the flagship-units requirement inside it makes
## the money threshold mathematically redundant — 35 units cost 215.6x the flagship's price
## against a 20x threshold, and you cannot spend what you have not earned (verified in
## sim/EpochPhaseStudy.gd: switching the money gate off reproduced the gated run exactly).
##
## The money gate ALSO still applies whenever no ownership predicate was supplied — that is
## the isolated money-mechanic path (EpochTest), which must keep its original behaviour.
func _may_leave(tier: int, cash_earned_this_gen: float, owns_all_in_tier: Callable) -> bool:
	if tier <= LAST_EARTH_TIER or not owns_all_in_tier.is_valid():
		var threshold := EpochCatalog.consume_threshold(tier, _tuning.earth_economy_target)
		if cash_earned_this_gen < threshold:
			return false
	if owns_all_in_tier.is_valid() and not owns_all_in_tier.call(tier):
		return false
	return true


## Make contact: the player pressed MAKE CONTACT. Returns false (and does nothing) unless
## the requirements are currently met, so a stale tap can never skip an epoch.
func advance() -> bool:
	if not contact_ready:
		return false
	contact_ready = false
	_enter_next_epoch()
	return true


func _enter_next_epoch() -> void:
	current_tier += 1
	contact_made.emit(current_tier)


## Restore the reached epoch from a save (clamped to the valid range).
func restore(tier: int) -> void:
	current_tier = clampi(tier, 1, EpochCatalog.tier_count())
