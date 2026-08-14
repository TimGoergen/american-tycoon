class_name PropertyState

# Mutable runtime state for one property type during a game run.
# No scene-tree dependencies — safe to instantiate and tick headlessly.

var config: PropertyConfig
var tuning: TuningConfig

## How many units of this property the player currently owns.
var units_owned: int = 0

## Income earned per completed cycle, per unit. Starts at config.base_income_per_unit;
## multiplied by 2 when a milestone is crossed and the cycle is already at CYCLE_FLOOR.
var income_per_unit: float = 0.0

## Current cycle duration in seconds. Starts at config.base_cycle_length;
## halved at each milestone until CYCLE_FLOOR, then income_per_unit doubles instead.
var cycle_length: float = 0.0

## Running product of all cost ratios applied so far (starts at 1.0).
## Maintained incrementally so cost lookups stay O(1).
var cost_product: float = 1.0

## This property's position on its SINGLE sequential staff ladder (the epoch-depth
## redesign, GDD §6.1 / Plans/Epoch_Depth_Pass.md, Tim 2026-07-04). The ladder is one
## cumulative counter divided into 20-level BLOCKS; each block belongs to one epoch,
## starting at this property's unlock epoch (block 1 = home epoch, block 2 = the next
## epoch, …). Level 1 of every block IS that epoch's staffer hire: it swaps the staffer
## and carries the block's big entry step; levels 2–20 are that staffer's smaller equal
## steps. Both a block's costs and its effects are constants of the block — defined by
## the epoch it belongs to, never recomputed against the player's current epoch — so
## prices can never silently jump at a contact (the 2026-07-03 transition bug).
## Levels must be bought strictly in order; the cap (20 × blocks reached) is the only
## other gate. 0 = no staff at all (unstaffed, cycles need manual starts).
var staff_level: int = 0

## Permanent income + cycle-time bonus this property won from its First Contact minigame (GDD §5.5
## site 2; alien properties only). 1.0/1.0 = base (the guaranteed floor — the minigame is upside-
## only, never a penalty); a good negotiation raises the income multiplier and lowers the cycle
## multiplier (faster cycles). Set once when the trade deal resolves and kept for the run.
var first_contact_income_multiplier: float = 1.0
var first_contact_cycle_multiplier: float = 1.0

## Whether ANY staffer is hired, enabling auto-cycle forever. Read-only: derived from
## the staff ladder (level 1 of the first block IS the hire) so the many places that
## ask "is this staffed?" keep working while the level is the real stored fact.
var is_staffed: bool:
	get:
		return staff_level >= 1

## The ABSOLUTE epoch tier of the staffer currently on the job (0 = unstaffed). Derived,
## never stored: the latest block this property has entered, mapped to its epoch. An Earth
## property on levels 21–40 is staffed at tier 2 (the Luminari staffer); an alien property
## born at epoch 3 starts its very first block at tier 3. Drives staffer-name lookups
## (EpochCatalog.staffer_name) and the Estate Office roster display.
var staff_tier: int:
	get:
		if staff_level < 1:
			return 0
		return staff_block_epoch(staff_blocks_entered())

## How far through the current cycle (in seconds, 0 → cycle_length).
var cycle_progress: float = 0.0

## True while a cycle is in progress.
var is_cycle_running: bool = false

## Dynasty-wide cycle-speed multiplier from the Legacy "Efficiency Experts"
## upgrade (1.0 = normal). The cycle's EFFECTIVE length is cycle_length divided
## by this, so a higher value means cycles finish sooner and income/sec rises.
## Set by DynastyState from the purchased upgrades; defaults to 1.0 so a bare
## single-generation run (or the M1 sim) is unaffected.
var cycle_speed_multiplier: float = 1.0

## Dynasty-wide staff-hiring-cost multiplier from the "Loyal Staff" upgrade
## (1.0 = full price, below 1.0 = a discount). Applied in get_staff_cost.
var staff_cost_multiplier: float = 1.0

## Dynasty-wide rush-strength multiplier from the Legacy "Strong-Arm Tactics" upgrade
## (1.0 = base). Scales how far one rush-tap advances the cycle. Set by DynastyState.
var rush_power_multiplier: float = 1.0

## Dynasty-wide auto-rush SPEED multiplier from the Legacy auto-click upgrade (1.0 =
## base). The held-rush pulse RATE in PropertyRow is multiplied by this. Set by DynastyState.
var auto_rush_speed_multiplier: float = 1.0

## Rush Momentum multiplier currently applied to THIS property: 1.0 normally, (1 + bonus) while the
## player is ACTIVELY rushing it. Momentum boosts only the property being rushed, not the whole
## economy (Tim 2026-07-13), so it multiplies this property's income in both _collect (what it pays)
## and get_income_per_cycle (what its row shows). GameState sets it each tick from the grace below.
var rush_momentum_factor: float = 1.0

## Seconds of "actively rushed" credit left. Each rush verb refills it (see GameState); the tick
## decays it and drops rush_momentum_factor back to 1.0 when it runs out, so the boost fades a beat
## after the player stops rushing this property. The grace bridges the gaps between rush pulses.
var rush_active_grace: float = 0.0

## True while this property is DOWN from an overheat (Plans/Overdrive_Vent_Windows.md, Tim
## 2026-07-19): it was being actively rushed at the moment the excursion overheated, so the
## machine that was pushed too hard is the machine that shut down. GameState sets it at the
## overheat moment (every property inside its rushed grace freezes — all of them, if
## multi-touch rushing several) and clears it at rush_ready / First Contact reset / dynasty
## succession, so the freeze spans EXACTLY the lockout (drain + re-arm), never longer.
## While true: the cycle does not advance (cycle_progress holds), nothing collects, staffed
## auto-cycling is paused, and starting an idle cycle is refused — but SHOP actions (buying
## units, staff levels) stay allowed, because shopping is not production.
## NOT saved, on purpose: heat/lockout state never persists across sessions (RushMomentumState
## has no save block), so a persisted freeze flag would have no lockout to end it.
var is_overheat_frozen: bool = false

## True while this property is riding out a RELEASE TAIL (Plans/Overdrive_Vent_Windows.md
## "Bailing pays", Tim 2026-07-20): it was one of the properties being actively rushed at the
## moment the player let go, so it keeps collecting the decaying bonus — finger off the glass —
## for as long as the momentum meter takes to bleed empty. That is what makes STOPPING a real
## reward rather than merely a survivable exit, and it applies to EVERY release, plain cruise
## hold or deep overdrive bail alike (the mark used to be stamped only on overdrive rides, which
## is exactly why a plain rush's income snapped back while its bar was still draining).
##
## Deliberately shaped like is_overheat_frozen above: both are per-property marks that GameState
## sets from a moment in the shared heat model and clears on exactly one set of exits. The exits
## here are the end of the tail, an overheat (which zeroes the bonus on the spot — that contrast
## is the whole point of bailing), and the First Contact reset. GameState sweeps the flag off the
## instant the tail stops paying, because a property left marked with nothing behind it would
## carry a permanent income multiplier — an economy bug, not a cosmetic one.
## NOT saved, for the same reason the freeze is not: no heat/lockout state persists.
var is_rush_tail_rider: bool = false

## True if Shift Supervisors (Legacy upgrade) auto-restarts this unstaffed property's cycle.
var auto_restarts: bool = false

## Cycles completed by this property during the last tick() or rush_cycle() call.
var cycles_completed_this_tick: int = 0

## Dynasty-wide property-income multiplier (the Legacy "Family Fortune" upgrade), mirrored
## here for DISPLAY only so the row's per-cycle figure reflects it (the live tick applies
## the same factor at point of payment via the global multiplier). Set by DynastyState.
var legacy_income_multiplier: float = 1.0


## How many milestone bands have been crossed. Used to know which reward fires next.
var _milestones_crossed: int = 0


func _init(p_config: PropertyConfig, p_tuning: TuningConfig) -> void:
	config = p_config
	tuning = p_tuning
	income_per_unit = config.base_income_per_unit
	cycle_length = config.base_cycle_length


# ---------------------------------------------------------------------------
# Cost queries
# ---------------------------------------------------------------------------

## Cost to buy one more unit (exact, floored).
func get_next_cost() -> float:
	return CostCurve.get_next_cost(
		config.base_cost, config.r0, tuning.band_step, cost_product, units_owned
	)


## Exact sum of per-unit costs for buying `count` more units.
func get_bulk_cost(count: int) -> float:
	return CostCurve.get_bulk_cost(
		config.base_cost, config.r0, tuning.band_step, cost_product, units_owned, count
	)


## Cost to buy enough units to reach the next milestone count.
func get_to_milestone_cost() -> float:
	var needed := CostCurve.units_to_next_milestone(units_owned)
	if needed <= 0:
		return 0.0
	return get_bulk_cost(needed)


## Largest unit count purchasable with `available_cash` at exact-sum pricing
## (the MAX bulk-buy button). Capped so a degenerate config can't loop forever.
func get_max_affordable(available_cash: float, cap: int = 1000) -> int:
	var count := 0
	var remaining := available_cash
	var running_product := cost_product
	var owned := units_owned
	while count < cap:
		# Match the rounded price the player is actually charged (see CostCurve):
		# the running product BEFORE this unit's ratio, so unit #1 costs base_cost.
		var unit_cost := CostCurve.round_nice(config.base_cost * running_product)
		if remaining < unit_cost:
			break
		remaining -= unit_cost
		var band := CostCurve.get_band(owned + 1)
		running_product *= CostCurve.get_ratio(config.r0, band, tuning.band_step)
		owned += 1
		count += 1
	return count


# ---------------------------------------------------------------------------
# Purchases & staffing
# ---------------------------------------------------------------------------

## Purchase `count` units. Caller must verify affordability first.
func buy(count: int) -> void:
	for _i in range(count):
		cost_product = CostCurve.advance_cost_product(
			cost_product, config.r0, tuning.band_step, units_owned
		)
		units_owned += 1
		_check_milestone()

	# Staffed or auto-restarting properties auto-start; make sure a cycle is running.
	if (is_staffed or auto_restarts) and not is_cycle_running:
		_start_cycle_internal()


# ---------------------------------------------------------------------------
# The staff ladder — block arithmetic
# ---------------------------------------------------------------------------
# One sequential ladder of 20-level blocks (see the staff_level doc above). These
# helpers are the single home of the block math; EconomyState (costs) and the UI
# (button labels) route through them so no one can disagree about which block a
# level belongs to.

## Which 1-based block a 1-based ladder level belongs to (levels 1–20 → block 1, …).
func staff_block_of_level(level: int) -> int:
	@warning_ignore("integer_division")
	return (level - 1) / tuning.staff_levels_per_epoch + 1


## How many blocks this property has ENTERED (bought at least level 1 of). 0 = unstaffed.
func staff_blocks_entered() -> int:
	if staff_level < 1:
		return 0
	return staff_block_of_level(staff_level)


## The ABSOLUTE epoch a block belongs to: block 1 is this property's unlock epoch,
## each further block the next epoch. Anchors that block's costs (EconomyState) and
## picks its staffer name.
func staff_block_epoch(block: int) -> int:
	return config.unlock_tier + block - 1


## How many 20-level blocks are unlocked for THIS property once the dynasty has
## reached `reached_tier`. An Earth property (unlock_tier 1) has 1 block at tier 1,
## 2 at tier 2, up to 27. An alien property unlocking at tier 10 has 0 blocks at
## tier 9, 1 at tier 10, 2 at tier 11, up to (27 - 10 + 1) = 18.
func staff_blocks_available(reached_tier: int) -> int:
	var last_defined_block := EpochCatalog.tier_count() - config.unlock_tier + 1
	return clampi(reached_tier - config.unlock_tier + 1, 0, last_defined_block)


## Buy the next ladder level. Caller (EconomyState) verifies order, cap, and cash.
## Level 1 is the first hire: automation switches on and the cycle starts.
func add_staff_level() -> void:
	staff_level += 1
	if is_staffed and not is_cycle_running and units_owned > 0:
		_start_cycle_internal()


## Grant ladder levels outright (dynastic staff retention seeding an heir, GDD §6.3).
## Never lowers an existing level. Starts the cycle if the property can already run.
func will_staff_levels(level: int) -> void:
	staff_level = maxi(staff_level, level)
	if is_staffed and not is_cycle_running and units_owned > 0:
		_start_cycle_internal()


## A block's ENTRY step — the big income jump its level 1 (the staffer hire) adds. Blocks
## reuse the catalog's 40^(n−1) staff ladder as per-block DELTAS, indexed by the block's
## position on THIS property's ladder (block 1 = 0: a first hire is automation only, no
## jump — true for Earth's tier-1 staffer and for alien properties alike, whose epoch leap
## lives in their base magnitude). Relative-to-this-property steps are how "effects are
## defined by the block's epoch" stays true for aliens too: their base income is already
## home-epoch sized, so a relative step is a home-epoch-sized absolute effect.
## First-pass values pending the Phase 3 pacing retune (Plans/Epoch_Depth_Pass.md §4).
func staff_entry_step(block: int) -> float:
	if block <= 1:
		return 0.0
	return EpochCatalog.staff_income_multiplier(block) - EpochCatalog.staff_income_multiplier(block - 1)


## A block's per-level step — what each of its levels 2–20 adds. Scaled to the block the
## same way the entry step is, so every block's 19 small steps are sized to its epoch.
## Earth block 1 comes out at the plain staff_level_step (0.33), today's live value.
func staff_small_step(block: int) -> float:
	return tuning.staff_level_step * EpochCatalog.staff_income_multiplier(block)


## This property's full staffer income multiplier: 1 plus every ladder step bought so far —
## each entered block's entry step, plus its small step × the further levels bought in it.
## ADDITIVE (never compounding: 120 compounding levels would blow up income), with the step
## SIZES growing per block, so later blocks matter without runaway. Everything that pays or
## displays property income routes through here so the bonus applies uniformly (the same way
## _effective_cycle_length centralizes the speed bonus).
func _effective_staff_multiplier() -> float:
	var multiplier := 1.0
	var per_block := tuning.staff_levels_per_epoch
	for block in range(1, staff_blocks_entered() + 1):
		var levels_in_block := mini(staff_level - (block - 1) * per_block, per_block)
		multiplier += staff_entry_step(block) + staff_small_step(block) * float(levels_in_block - 1)
	return multiplier


## This property's full income multiplier: the staffer bonus (tier entry × within-epoch levels)
## AND the permanent First Contact minigame income bonus. Everything that pays or displays income
## routes through here so both apply uniformly.
func _effective_income_multiplier() -> float:
	return _effective_staff_multiplier() * first_contact_income_multiplier


## Apply this property's First Contact minigame result (income up, cycle down). Called once when the
## alien trade deal resolves; both are floored at base (income ≥ 1.0×, cycle ≤ 1.0×) so a poor run
## or a Skip never makes the property worse than its base — the minigame is upside-only.
func set_first_contact_bonus(income_multiplier: float, cycle_multiplier: float) -> void:
	first_contact_income_multiplier = maxf(1.0, income_multiplier)
	first_contact_cycle_multiplier = clampf(cycle_multiplier, 0.01, 1.0)


## Set the Legacy cycle-speed multiplier and keep the in-flight cycle consistent.
## Because the effective cycle length shrinks as speed rises, an in-progress
## cycle could suddenly be "past the end"; we clamp progress so it simply
## completes on the next tick rather than overshooting.
func set_cycle_speed_multiplier(multiplier: float) -> void:
	cycle_speed_multiplier = maxf(0.01, multiplier)
	cycle_progress = minf(cycle_progress, _effective_cycle_length())


## The cycle length actually used for timing — the base length sped up by the
## Legacy "Efficiency Experts" upgrade. Everything that measures cycle time goes
## through here so the speed bonus applies uniformly (completion, rush, rate).
func _effective_cycle_length() -> float:
	# The First Contact cycle bonus (≤ 1.0) shortens the effective cycle, so a well-negotiated alien
	# property also pays faster, not just more.
	return cycle_length / cycle_speed_multiplier * first_contact_cycle_multiplier


## Public accessor for the effective (sped-up) cycle length, so the UI can size its
## smooth cycle-progress bar against the SAME length the logic completes on. Without
## this the bar measured against the raw cycle_length and never fully filled once the
## Efficiency upgrade shortened the real cycle (Tim 2026-06-17).
func get_effective_cycle_length() -> float:
	return _effective_cycle_length()


## One-time hire cost: 50× the unit cost at band 1 (Spec §6).
## Computed fresh each call so it tracks the current cost curve.
func get_staff_cost() -> float:
	# Simulate the cost_product at the moment band 1 was first entered (unit 20).
	# For simplicity, compute band-1 ratio × base_cost × the product needed to
	# reach unit 20. We use CostCurve.get_bulk_cost from 0 owned to find that
	# point, then take the per-unit cost there × 50.
	# This is an approximation of Spec §6 "50× unit cost at band 1" that avoids
	# recomputing the full product curve from scratch.
	var band1_ratio := CostCurve.get_ratio(config.r0, 1, tuning.band_step)
	# Cost of the 20th unit (the first band-1 unit): base_cost × product-at-20
	# We get the running product at exactly 19 owned by running the accumulator.
	var prod := 1.0
	for i in range(19):
		var b := CostCurve.get_band(i + 1)
		prod *= CostCurve.get_ratio(config.r0, b, tuning.band_step)
	# floorf (not floor) — floor() returns Variant, which breaks := type inference.
	var unit_20_cost := floorf(config.base_cost * prod * band1_ratio)
	# The Legacy "Loyal Staff" upgrade discounts hiring (multiplier ≤ 1.0). Round the
	# final hire price to a clean number too, matching the property purchase costs.
	return CostCurve.round_nice(unit_20_cost * 50.0 * staff_cost_multiplier)


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

## Rebuild state from a save file. Only raw facts are restored (unit count, the
## staff-ladder level, in-flight cycle); cost_product, cycle_length, income_per_unit,
## the milestone count, and every staff multiplier are recomputed from those facts,
## so derived values can never drift from the math that produced them.
func restore(
		p_units: int,
		p_staff_level: int,
		p_cycle_progress: float,
		p_is_running: bool,
		p_first_contact_income_mult: float = 1.0,
		p_first_contact_cycle_mult: float = 1.0
) -> void:
	units_owned = 0
	cost_product = 1.0
	income_per_unit = config.base_income_per_unit
	cycle_length = config.base_cycle_length
	_milestones_crossed = 0
	staff_level = 0
	first_contact_income_multiplier = 1.0
	first_contact_cycle_multiplier = 1.0
	# The overheat freeze is transient (never saved — see its declaration), so a restored
	# property always comes back UP: there is no persisted lockout that could ever end it.
	is_overheat_frozen = false
	# Same reasoning for the release tail: no heat survives a session, so a restored property
	# must never come back still claiming one.
	is_rush_tail_rider = false
	rush_momentum_factor = 1.0

	if p_units > 0:
		buy(p_units)

	staff_level = maxi(0, p_staff_level)
	# Set the First Contact bonus before clamping cycle_progress — the cycle bonus shortens the
	# effective length the clamp measures against.
	set_first_contact_bonus(p_first_contact_income_mult, p_first_contact_cycle_mult)
	cycle_progress = clampf(p_cycle_progress, 0.0, _effective_cycle_length())
	is_cycle_running = (p_is_running or is_staffed or auto_restarts) and units_owned > 0


# ---------------------------------------------------------------------------
# Simulation tick
# ---------------------------------------------------------------------------

## Advance the property by `delta` seconds. Returns income earned this tick.
## Staffed properties loop automatically; unstaffed stop after one cycle.
## `income_multiplier` (frenzy, events) applies at point of payment (Spec §3.4).
func tick(delta: float, income_multiplier: float = 1.0) -> float:
	cycles_completed_this_tick = 0
	# Overheat freeze: the whole property is DOWN for the lockout — the cycle holds exactly
	# where it was (staffed auto-cycling included) and pays nothing. Returning before the
	# loop below is what guarantees no collection path can leak: _collect only ever runs
	# from this loop or from rush_cycle, and both are gated on the freeze.
	if is_overheat_frozen:
		return 0.0
	if not is_cycle_running or units_owned == 0:
		return 0.0

	var income_earned := 0.0
	var remaining := delta
	var effective_length := _effective_cycle_length()

	# A single tick may complete multiple short cycles (e.g., ATM at 0.4 s).
	while remaining > 0.0 and is_cycle_running:
		var time_to_complete := effective_length - cycle_progress
		if remaining >= time_to_complete:
			# Cycle completes.
			remaining -= time_to_complete
			cycle_progress = 0.0
			income_earned += _collect(income_multiplier)
			cycles_completed_this_tick += 1

			if is_staffed or auto_restarts:
				_start_cycle_internal()  # auto-restart
			else:
				is_cycle_running = false  # manual: stop after one pay
		else:
			cycle_progress += remaining
			remaining = 0.0

	return income_earned


## Start verb (Layer 2): tap on an idle, unstaffed property starts its cycle.
## Refused while overheat-frozen — a downed machine cannot be restarted early by tapping it
## (GameState refuses the tap too; this is the belt to that brace).
func start_cycle() -> void:
	if is_overheat_frozen:
		return
	if not is_cycle_running and units_owned > 0:
		_start_cycle_internal()


## Rush verb (Layer 2): tap/hold on a running cycle advances it by RUSH_PCT of cycle_length. If
## the advance FILLS the cycle, it completes RIGHT NOW — collects (at the given frenzy multiplier),
## resets, and auto-restarts if staffed — rather than leaving the bar sitting full until the next
## 10 Hz logic tick collects it. That tick delay was making rushed income visibly lag the rushed
## cycles (Tim 2026-07-11). Returns the income earned by this rush (0 unless a cycle completed).
func rush_cycle(income_multiplier: float = 1.0) -> float:
	cycles_completed_this_tick = 0
	# Belt to GameState's brace: rush verbs are already globally dead during an overheat
	# lockout (can_rush() is false whenever a property is frozen), but a frozen property must
	# never pay even if some future caller forgets that gate.
	if is_overheat_frozen:
		return 0.0
	if not is_cycle_running:
		return 0.0
	var effective_length := _effective_cycle_length()
	# The Legacy "Strong-Arm Tactics" upgrade makes each rush advance the cycle further.
	var rush_fraction := tuning.rush_pct * rush_power_multiplier
	cycle_progress += rush_fraction * effective_length
	if cycle_progress < effective_length:
		return 0.0
	# One rush pulse can fill MORE than a whole cycle — a big Strong-Arm Tactics rush_power, or a
	# short cycle — so collect EVERY complete cycle the progress now covers and CARRY THE REMAINDER
	# forward. Resetting to 0 (paying just one cycle) discarded the overshoot, so the player
	# collected far less than the rushed rate the row displays (Tim 2026-07-12: "collecting less than
	# the readout says"). This mirrors tick(), which also completes multiple cycles per step.
	var earned := 0.0
	if is_staffed:
		# Staffed: pay every full cycle covered, keep the leftover progress, and stay running.
		var completed := int(cycle_progress / effective_length)
		cycle_progress -= float(completed) * effective_length
		cycles_completed_this_tick += completed
		for _i in range(completed):
			earned += _collect(income_multiplier)
	else:
		# Manual (unstaffed): pays exactly one cycle then stops (Spec §4; a held pulse re-taps it),
		# unless Shift Supervisors auto-restarts it.
		cycle_progress = 0.0
		earned = _collect(income_multiplier)
		cycles_completed_this_tick += 1
		if auto_restarts:
			_start_cycle_internal()
		else:
			is_cycle_running = false
	return earned


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Income per second contributed by this property at current units and cycle.
func get_income_per_sec() -> float:
	if units_owned == 0 or cycle_length <= 0.0:
		return 0.0
	# Use the effective (sped-up) length so the Efficiency upgrade shows up as a
	# higher income/sec, matching what the property actually pays over time. The staffer
	# tier's multiplier is included so alien staff visibly raise this property's rate.
	return floor(units_owned * income_per_unit * _effective_income_multiplier()) / _effective_cycle_length()


## Cash paid out each time a full cycle completes, before frenzy/event
## multipliers (those apply at point of payment in _collect). This is the number
## the property row displays — it's what the player actually receives when the
## progress bar fills, so the on-screen figure matches the cash they get.
func get_income_per_cycle() -> float:
	if units_owned == 0:
		return 0.0
	# Includes the staffer-tier multiplier, the dynasty Family Fortune multiplier, AND the per-
	# property Rush Momentum factor (>1 only while this property is being actively rushed), so the
	# displayed figure tracks all three — matching what the live tick/rush pay. Frenzy/event
	# multipliers still apply on top, at payment.
	return floor(units_owned * income_per_unit * _effective_income_multiplier() * legacy_income_multiplier * rush_momentum_factor)


## Cash a SINGLE unit of this property would pay per cycle right now (Family Fortune
## included). Shown grayed on a rung the player owns none of yet, so they can see what
## the next tier is worth before buying in (Tim 2026-06-17).
func get_single_unit_income_per_cycle() -> float:
	return floor(income_per_unit * _effective_income_multiplier() * legacy_income_multiplier)


## Current milestone band (how many bands have been crossed).
func get_milestone_band() -> int:
	return CostCurve.get_band(max(units_owned, 1))


## The unit count at which the next milestone will be crossed, or 0 once the final
## milestone (400) has been passed (this property can no longer earn a milestone beat).
func get_next_milestone_count() -> int:
	return CostCurve.next_milestone_count(units_owned)


## The most recently crossed milestone count (0 before the first), the lower bound of
## the milestone progress slider.
func get_last_milestone_count() -> int:
	return CostCurve.last_milestone_count(units_owned)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _start_cycle_internal() -> void:
	is_cycle_running = true
	cycle_progress = 0.0


## Collect income at the end of a cycle and return the amount earned.
## Multipliers apply here — at point of payment — then floor (Spec §1, §3.4).
func _collect(income_multiplier: float = 1.0) -> float:
	# _effective_staff_multiplier() is this property's own alien-staffer bonus (tier entry
	# multiplier × within-epoch levels); the passed-in income_multiplier is the global
	# frenzy × Legacy factor; rush_momentum_factor is >1 only while THIS property is being actively
	# rushed. All apply here, at point of payment, then floor (Spec §1, §3.4).
	return floorf(units_owned * income_per_unit * _effective_income_multiplier() * income_multiplier * rush_momentum_factor)


## Check whether a milestone has been crossed and apply the adaptive reward.
func _check_milestone() -> void:
	# Milestones at 25/50/100/200/300/400 (CostCurve.MILESTONE_THRESHOLDS). After each
	# purchase, see how many bands units_owned now spans and pay any newly-crossed ones.
	var expected_milestones := CostCurve.get_band(max(units_owned, 1))
	while _milestones_crossed < expected_milestones:
		_apply_milestone_reward()
		_milestones_crossed += 1


## Adaptive milestone reward (Spec §3.3):
## - If halving cycle_length keeps it at or above CYCLE_FLOOR → halve it.
## - Otherwise → double income_per_unit.
func _apply_milestone_reward() -> void:
	if cycle_length / 2.0 >= tuning.cycle_floor:
		cycle_length /= 2.0
	else:
		income_per_unit *= 2.0
