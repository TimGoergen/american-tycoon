class_name GameState

# Top-level headless game state for one run. Composes the economy, the wage
# ladder, and the frenzy meter, and wires the frenzy multiplier into all
# income at point of payment (Spec §3.4). The scene layer and the balance
# simulator both drive the game exclusively through this class (Spec §13:
# same code, no rendering), so nothing here may touch the scene tree.

# v2 added the per-generation spend accumulators and peak net worth that the
# prestige/estate math reads (Spec §9). v3 added the generation's birth seed cash,
# excluded from the estate→Legacy conversion. v4 added cash_earned_this_gen, the
# lifetime-earned accumulator that is now the gross estate (Spec §9.1). v5 replaced the
# per-property is_staffed bool with a staff_tier int and added the run's reached epoch
# (the alien-staffing system). v6 replaced the named-title wage ladder with a numeric clock-in
# LEVEL (the wage save block now stores level + taps_into_level instead of a title index).
# v7 added the per-property within-epoch staff_level (the per-epoch upgrade track).
# v8 added the per-property permanent First Contact minigame bonus (income + cycle multipliers).
# v9 collapsed staffing to the SINGLE sequential staff ladder (the epoch-depth redesign):
# staff_tier is no longer stored — hiring is level 1 of each 20-level block, so staff_level
# alone reconstructs everything. Older saves still load (missing fields default to a clean
# slate / zero earned; a v4 is_staffed:true becomes one hire; a pre-v6 save starts the wage at
# level 0; pre-v9 staff_tier + staff_level pairs are merged onto the one ladder — each old
# tier hire counts as one ladder level; see the migration in load_save_dict).
# v11 added the dynasty's Challenge-Mode cleared-tier record (DynastyState.challenge_highest_tiers,
# the permanent diminishing income bonus); older saves load with a warning and default it to empty
# (→ 0 bonus).
# v12 is the EARTH SPLIT (Plans/Earth_Split_Epochs.md): Earth became TWO epochs (Blue Collar
# tier 1, White Collar tier 2), pushing every alien tier up one. A pre-v12 save's epoch_tier
# migrates on load: 2+ shift to 3+, and a mid-Earth tier-1 save maps to White Collar if it
# owns any White Collar property (indices 6-11) — so nothing a player owns ever locks on them.
# Staff levels need no migration: caps are identical at every equivalent moment (plan doc).
# v13 is the ENDGAME ECONOMY (Plans/Endgame_Economy.md): the mint curve bends at a knee,
# the compounders run uncapped on a steepening cost curve, and the utility tracks doubled
# their level counts at half the per-level effect. Pre-v13 utility levels migrate BY EFFECT
# (level ×2 = the same owned bonus) in DynastyState.load_save_dict; nothing else moves.
const SAVE_VERSION := 13

var tuning: TuningConfig
var economy: EconomyState
var wage: WageState
var frenzy: FrenzyState
var events: EventState

## Rush Momentum / Overheat — the climbing heat meter whose property-income bonus rewards
## ATTENTIVE rushing (ride the danger bands, vent before the shutdown — Tim 2026-07-15,
## evolving the 07-12 "pinch of active progression"). See RushMomentumState.
var rush_momentum: RushMomentumState

## Seconds of "rushing" credit remaining. Each rush verb refills it to tuning.rush_momentum_grace_
## seconds; the tick counts the player as rushing (momentum builds) while it is positive and drains
## it by delta. The grace bridges the gaps BETWEEN discrete auto-rush pulses (which fire at 5/s,
## slower than the 10/s tick) so momentum builds smoothly instead of bleeding between pulses. Not
## saved — momentum is transient.
var _rush_grace_remaining: float = 0.0

## Which alien epoch this generation has reached (1 = Earth). Gates the staff tier a
## property can be hired/upgraded to, and advances as the generation earns enough to
## "consume" the current economy (EpochState).
var epoch: EpochState

## Auto-Purchase Mode — the "Acquisitions Desk" buying policy (Plans/Auto_Purchase_And_Bulk_Hire.md).
## Headless policy, ticked by whoever drives the game (Main._process for the real game, sim/ for
## verification) against `ui_epoch_tab`. Held here rather than in the UI so the sims can drive the
## exact same object the game does. Its `enabled` flag is the single source of truth for whether
## the mode is on — nothing else stores a copy (see to_save_dict / load_save_dict).
var auto_purchase := AutoPurchaseState.new()

## Highest net worth this generation has reached. The next heir must out-earn
## this peak before its Legacy sprint multiplier gives way to the residual
## (Spec §9.4). Monotonic — only ever rises within a generation.
var peak_net_worth: float = 0.0

## UI preference: the player's selected global buy mode (a PropertyRow.BuyMode int).
## Stored here only so it persists in the save file across sessions; the headless
## model never reads it. Defaults to 3 = MAX (Tim, 2026-06-23 — a fresh game should
## start in buy-max). The literal avoids a UI-class dependency from this headless file.
var ui_buy_mode: int = 3

## The highest valid PropertyRow.HireMode ordinal (MAX). A literal rather than a reference to the
## enum, for the same reason ui_buy_mode's default is a literal: this file is headless and must not
## depend on a UI class. Keep it in step if HireMode ever gains or loses an entry.
const UI_HIRE_MODE_MAX := 2

## UI preference: the player's selected global staff HIRE mode (a PropertyRow.HireMode int).
## Same arrangement as ui_buy_mode above — parked here only so it survives the save file.
## Defaults to 0 = x1, because the bulk modes above it are gated by the Head Hunters Legacy
## track: a fresh dynasty has not bought them, so anything else would be an invalid default.
var ui_hire_mode: int = 0

## UI preference: the civ tab the property pager last showed (tab N is the cohort whose
## properties have unlock_tier N + 1 — Main._epoch_tab_of). Two jobs:
##   1. The pager reopens where the player left it instead of jumping to the deepest
##      unlocked tab every launch. Good behaviour on its own merits.
##   2. ~~It is the tab Auto-Purchase Mode buys from.~~ **No longer true (2026-08-07.)** The
##      mode now works in the epoch the player is actually in, so it takes no tab argument and
##      never reads this (Plans/Auto_Purchase_Restructure.md). Job 1 above is the only remaining
##      reason this field exists — worth confirming the pager still wants it before keeping it.
## Stored here only so it survives the save file; the headless model never reads it at all.
var ui_epoch_tab: int = 0

## UI preference: how every number on screen is formatted (a Money.Format value —
## ABBREVIATED / ALPHABET / SCIENTIFIC). Like ui_buy_mode this is parked here only so it
## survives the save; the headless model never reads it (the scene layer pushes it into
## Money.format_mode). Named rather than a literal because Money is a CORE class — referring
## to it from here adds no UI dependency, unlike ui_buy_mode's PropertyRow.BuyMode.
##
## DEFAULTS TO ALPHABET (Tim, 2026-08-05), not to the historical abbreviations. The suffix ladder
## stops being readable well before the end of the content — nobody can order SxVg against QaTg —
## so the letters are the better out-of-the-box experience, and since ALPHABET keeps K/M/B/T the
## early game looks exactly as it always did. Only an explicit choice moves it from here.
var ui_currency_format: int = Money.Format.ALPHABET

## UI preference: whether the prestige minigame is played (true) or auto-skipped for a
## flat 1.0× Legacy multiplier (false). Defaults to on (the minigame is mandatory until
## the player opts out — GDD §5.5). Persisted in the save like ui_buy_mode.
var ui_minigame_enabled: bool = true

## UI preferences: the three audio sliders, each a LINEAR 0..1 level the scene layer pushes into
## the Audio autoload (Plans/Audio_System.md §6). Parked here for the same reason as every other
## `ui_` field — so they survive the save — and read by nothing in the headless model.
##
## Linear, not decibels: the slider is linear, and a stored dB value would need a special case for
## "off" (silence is −∞ dB, not a number a slider can hold). The conversion happens once, at the
## AudioServer boundary.
##
## Default 0.8 rather than 1.0 leaves headroom: several sounds can land in the same frame, and a
## first launch at full scale is how a game gets muted in the first minute.
var ui_music_volume: float = 0.8
var ui_sfx_volume: float = 0.8

## UI preference: a 0..1 MULTIPLIER on every haptic duration, not a volume. At 0.0 the durations
## fall under the `>= 1.0` guard in the one vibrate call site, so zero disables haptics with no
## extra branch anywhere (Plans/Audio_System.md §6.3).
var ui_haptics_scale: float = 1.0

## UI preference: whether TURBO automatically pops at 100% full frenzy meter (Hair Trigger).
## Gated by the AUTO_POP_TURBO Legacy upgrade in the UI; stored here to persist across sessions and successions.
var ui_auto_pop_turbo: bool = false

## The headline income/sec shown on the hero panel. A STABLE, THEORETICAL rate computed from

## the player's current assets (see EconomyState.get_passive_income_per_sec): the sum over
## staffed properties of (per-cycle payout × multipliers) ÷ cycle duration. It is NOT a
## measurement of recent cash inflow — that swung wildly frame to frame between the lumpy
## cycle payouts, which read as random noise (Tim, 2026-06-24). This figure only moves when
## the holdings, staffing, or a permanent income multiplier change. Display-only.
var displayed_income_per_sec: float = 0.0


func _init(property_configs: Array, p_tuning: TuningConfig) -> void:
	tuning = p_tuning
	economy = EconomyState.new(property_configs, p_tuning)
	wage = WageState.new()
	frenzy = FrenzyState.new(p_tuning)
	rush_momentum = RushMomentumState.new(p_tuning)
	epoch = EpochState.new(p_tuning)
	events = EventState.new(p_tuning)
	# OVERHEAT PROPERTY FREEZE (Plans/Overdrive_Vent_Windows.md, Tim 2026-07-19): the signal
	# pair below is the one seam every overheat and every recovery flows through. `overheated`
	# is emitted synchronously from RushMomentumState._begin_overheat — the single funnel for
	# ALL overheat causes (missed window, blown gesture beat, AND the hard-ceiling backstop) —
	# so connecting here can never miss one, unlike detecting a lockout edge in tick() (which
	# would also fire a tick late, after the rushed-grace snapshot has started to decay).
	rush_momentum.overheated.connect(_freeze_actively_rushed_properties)
	rush_momentum.rush_ready.connect(unfreeze_all_properties)


## Advance the whole game by `delta` seconds of active play.
##
## `extra_property_multiplier` is an income multiplier applied to PROPERTY income
## only — never to the wage. The dynasty layer passes the Legacy sprint/residual
## multiplier here (Spec §9.4: "the wage is honest"). Frenzy still applies to
## both, so property income is scaled by frenzy × Legacy while the wage keeps
## only frenzy (paid separately in tap_wage). Defaults to 1.0 so a standalone
## single-generation run is unaffected.
func tick(delta: float, extra_property_multiplier: float = 1.0) -> void:
	frenzy.tick(delta)
	# Rush heat climbs while the player is actively rushing (rushed within the grace window)
	# and bleeds otherwise. A frenzy burn no longer freezes any of it (Tim 2026-07-19 — see
	# RushMomentumState): the two systems run at once and compound.
	# The bonus MAGNITUDE is global, but it is applied ONLY to the properties
	# being actively rushed (Tim 2026-07-13) — via each property's own rush_momentum_factor below,
	# NOT the whole-economy tick multiplier.
	# While a vent window is open, the gesture's lifts (finger deliberately OFF the button —
	# Plans/Overdrive_Vent_Windows.md) must not read as "stopped rushing": the player still
	# counts as rushing even with the grace expired, and the grace timers below are frozen so
	# neither the global build nor the rushed property's factor can bleed mid-gesture. The
	# window is at most ~1 s, so freezing the decay for its span is imperceptible elsewhere.
	var vent_gesture_holding := rush_momentum.is_vent_window_open()
	rush_momentum.tick(delta, _rush_grace_remaining > 0.0 or vent_gesture_holding)
	if not vent_gesture_holding:
		_rush_grace_remaining = maxf(_rush_grace_remaining - delta, 0.0)
	# Point each property's momentum factor at the current bonus while it is still inside its
	# actively-rushed grace, else back to 1.0; then decay that grace so the boost fades a beat after
	# the player stops rushing it. This is what confines momentum to the rushed property.
	# (Overheat-frozen properties always take the 1.0 branch: the freeze handler zeroed their
	# grace, and no rush verb can refill it while the lockout has every rush verb dead.)
	#
	# THE RELEASE TAIL (Plans/Overdrive_Vent_Windows.md "Bailing pays", Tim 2026-07-20) adds a
	# second way to be paid. Letting go no longer collapses the bonus: it spins down as the heat
	# bleeds, over several seconds. But the grace above expires half a second after the finger
	# lifts, so on its own the tail would be pure decoration — the bar would count a reward down
	# that the player never actually received (Tim, device, 2026-07-20: "the income rate per
	# second display immediately drops back to the default amount even though the bar takes some
	# seconds to drain"). So the properties that were RIDING keep the decaying multiplier with the
	# finger off, until the tail ends.
	#
	# EVERY release case, not just an overdrive bail (Tim, 2026-07-20): the mark below used to be
	# gated on is_overdrive_engaged(), which is precisely why a plain +15% cruise release paid
	# nothing while its bar drained. Any property being rushed is marked.
	#
	# Knowing WHO was riding has to be recorded DURING the ride: by the release tick every grace
	# is already zero (release_rush clears them the instant the finger lifts), so there is nothing
	# left to read at the moment it matters. Hence the running mark below — the same shape as
	# is_overheat_frozen, which is likewise stamped from a heat-model moment and cleared on one
	# known set of exits.
	var tail_bonus := rush_momentum.bonus if rush_momentum.is_spinning_down() else 0.0
	if tail_bonus <= 0.0:
		# The heat model is the single authority for when a tail ENDS. The moment it stops paying
		# the marks come off, so no property can be left holding an elevated factor with nothing
		# behind it — that would be a permanent income multiplier, not a cosmetic bug. (While the
		# player is actively rushing this also fires every tick, and the loop below immediately
		# re-marks whoever is in grace, which is how the "who was riding" record stays current.)
		clear_rush_tail_riders()
	for prop_variant in economy.properties:
		var p := prop_variant as PropertyState
		if p.rush_active_grace > 0.0:
			# Actively rushed: record it as a rider AND pay the live bonus. The branches are
			# mutually exclusive precisely so the tail can never be applied twice.
			p.is_rush_tail_rider = true
			p.rush_momentum_factor = rush_momentum.factor()
		elif p.is_rush_tail_rider and tail_bonus > 0.0:
			# Released, finger off, meter still bleeding — the reward for stopping. The tail is
			# confined to the properties that were actually being rushed, which is the rule this
			# whole loop exists to keep.
			p.rush_momentum_factor = 1.0 + tail_bonus
		else:
			p.rush_momentum_factor = 1.0
		if not vent_gesture_holding:
			p.rush_active_grace = maxf(p.rush_active_grace - delta, 0.0)
	events.tick(delta, self)
	var tier_before := epoch.current_tier
	economy.tick(delta, frenzy.get_multiplier() * extra_property_multiplier * events.get_property_income_multiplier())
	if economy.cycles_completed_this_tick > 0:
		frenzy.on_cycle_completed(economy.cycles_completed_this_tick)
	peak_net_worth = maxf(peak_net_worth, economy.get_net_worth())
	# Advance the alien epoch if this generation has now earned enough to consume the current
	# economy AND owns at least one of every property in it. Reads the same lifetime-earned tally
	# the estate waterfall uses; the ownership predicate is checked per-tier inside epoch.update.
	epoch.update(economy.cash_earned_this_gen, _owns_all_in_epoch)
	# Reaching a new epoch (First Contact) wipes momentum — each epoch builds its own from scratch,
	# which is what keeps Rush Momentum a per-epoch pinch instead of a run-long snowball. The
	# reset also ends any lockout, so every frozen property comes back up with it (a freeze may
	# never outlive the lockout that caused it). Dynasty succession needs no equivalent call:
	# it builds a brand-new GameState (DynastyState), whose properties are all born unfrozen.
	if epoch.current_tier > tier_before:
		rush_momentum.reset()
		unfreeze_all_properties()
		# reset() wipes the heat and the retained peak too, so the sweep above would clear these
		# next tick anyway — but a rider mark must never outlive its tail even for one tick, so
		# it goes here with the freeze, on the same one line of thinking.
		clear_rush_tail_riders()
		# First Contact is a per-run reset point, so the Acquisitions Desk starts its cadence
		# over rather than firing a purchase on the far side of the transition with credit it
		# banked before it. This deliberately leaves auto_purchase.enabled alone — the mode is
		# a persistent player setting bought with a Legacy upgrade, not per-generation state.
		auto_purchase.reset_timer()
	_update_displayed_income()
	# Refresh the wage's "executive compensation" floor from the passive rate just
	# computed: a clock-in tap pays a fraction of a second of the empire's income
	# whenever that beats the ladder wage (Tim, 2026-07-05 — see WageState's header).
	wage.executive_wage_floor = tuning.wage_passive_fraction * displayed_income_per_sec
	wage.executive_floor_bonus_per_level = tuning.wage_floor_bonus_per_level


## Recompute the headline income/sec as the theoretical passive rate from current assets.
## A pure function of the holdings — no smoothing, no inflow measurement — so it is rock
## steady and only moves when the player buys, upgrades, staffs, or a permanent multiplier
## changes (Tim, 2026-06-24, replacing the old smoothed-inflow average that read as noise).
func _update_displayed_income() -> void:
	displayed_income_per_sec = economy.get_passive_income_per_sec()


# ---------------------------------------------------------------------------
# Player verbs — every tap feeds the frenzy meter (Spec §7)
# ---------------------------------------------------------------------------

## Layer 1: tap the wage button. Pays the current level's wage immediately (and may level up).
## True if this generation owns at least one unit of every property in an epoch (unlock tier) —
## the ownership half of the epoch-advance gate (Tim, 2026-07-23). Passed to epoch.update as the
## per-tier predicate.
func _owns_all_in_epoch(tier: int) -> bool:
	if not economy.owns_at_least_one_of_each(economy.get_property_indices_for_unlock_tier(tier)):
		return false
	if tier <= EpochState.LAST_EARTH_TIER:
		return true  # Earth keeps the money gate; no flagship requirement (onboarding)
	# Second, non-dollar half of the gate: run the epoch's flagship at scale before moving on.
	# At the default of 1 this is already implied by the check above, so it is a no-op.
	var required := tuning.epoch_flagship_units_required
	if required <= 1:
		return true
	var flagship := economy.get_flagship_index_for_unlock_tier(tier)
	if flagship < 0:
		return true
	return (economy.properties[flagship] as PropertyState).units_owned >= required


## The flagship-units requirement for `tier` as (owned, required) — what the epoch progress
## bar and the blocked coach card both read. `required` is 0 for a tier with no flagship
## requirement (Earth, or the default no-op setting), which callers treat as "not applicable".
func get_flagship_progress(tier: int) -> Vector2i:
	if tier <= EpochState.LAST_EARTH_TIER:
		return Vector2i(0, 0)
	var required := tuning.epoch_flagship_units_required
	if required <= 1:
		return Vector2i(0, 0)
	var flagship := economy.get_flagship_index_for_unlock_tier(tier)
	if flagship < 0:
		return Vector2i(0, 0)
	return Vector2i((economy.properties[flagship] as PropertyState).units_owned, required)


## The index of `tier`'s flagship property, or -1 — so the UI can point the player at the
## exact row they need to keep buying.
func get_flagship_index(tier: int) -> int:
	return economy.get_flagship_index_for_unlock_tier(tier)


func tap_wage() -> void:
	frenzy.on_tap()
	var earned := wage.tap_wage(frenzy.get_multiplier())
	# The wage is honest, earned money — it feeds the lifetime-earned estate basis.
	economy.award_earned(earned)


## Layer 1 auto-tap: one held "clock in" pulse. Earns the wage in full (it is
## honest money) but fills frenzy at the reduced hold factor, exactly like held
## property rushes — holding is convenient, so deliberate tapping stays superior
## (Spec §7). The pulse rate lives in the UI (WagePanel), upgrade-scalable later.
func hold_tap_wage() -> void:
	frenzy.on_tap(tuning.frenzy_fill_hold_factor)
	# Every tap — manual or held — earns the SAME per-tap wage, so the clock-in button's amount is
	# exactly what each tap pays (Tim, 2026-07-26). Holding fills frenzy at the reduced hold factor
	# above, so deliberate manual tapping keeps its frenzy-charge edge; holding's own payoff lever is
	# Restless Hands (more auto-taps/sec), not a bigger per-tap amount.
	var earned := wage.tap_wage(frenzy.get_multiplier())
	economy.award_earned(earned)


## Layer 2: tap a property. Starts the cycle if idle, rushes it if running.
func tap_property(prop_index: int) -> void:
	var prop := economy.properties[prop_index] as PropertyState
	# An overheat-frozen property is DOWN: taps on it are fully dead — no frenzy fill, no cycle
	# start — until rush_ready brings it back up. (The rush branch below would refuse via
	# can_rush() anyway, since a freeze only exists during a lockout; this gate is what keeps
	# the START verb from sneaking a downed machine back into production early.)
	if prop.is_overheat_frozen:
		return
	if prop.is_cycle_running:
		# THE AUTO-PURCHASE RUSH LOCKOUT (plan §A5). This is the ONLY branch that refuses:
		# tapping a RUNNING cycle is the rush verb, and rush is the price of the mode. Tapping
		# a STOPPED cycle (the else branch below) is how the player restarts a property, which
		# is a core interaction and is deliberately still allowed while the mode is on.
		if is_rush_locked_out_by_auto_purchase():
			return
		frenzy.on_tap()
		# An overheat takes down the HEAT METER and the properties that were being rushed on it —
		# not the rest of the empire (Tim 2026-07-19: the lockout was reaching properties that had
		# nothing to do with the overheat, which read as the whole tab going dead). A property that
		# is not frozen stays rushable right through someone else's lockout: it earns its normal
		# rushed cycle and feeds frenzy. What it CANNOT do is build heat or carry a momentum bonus
		# — the meter is out of commission until rush_ready — so the punishment is losing the
		# bonus and the downed properties, never the ability to play.
		if rush_momentum.can_rush():
			# Keep the global momentum meter building, and mark THIS property as actively rushed so
			# the bonus applies to it and only it. Its rush_momentum_factor is refreshed now, so this
			# very payout already carries the bonus, and the tick keeps it lit while the grace holds.
			_rush_grace_remaining = tuning.rush_momentum_grace_seconds
			prop.rush_active_grace = tuning.rush_momentum_grace_seconds
			prop.rush_momentum_factor = rush_momentum.factor()
		# Rush pays at the SAME multiplier the tick uses — frenzy and the dynasty's Family Fortune;
		# Rush Momentum is now folded in per-property via _collect's rush_momentum_factor (set just
		# above), so the rushed cycle collects exactly the full rate the row shows (Tim 2026-07-12/13).
		economy.credit_property_income(prop.rush_cycle(frenzy.get_multiplier() * prop.legacy_income_multiplier * events.get_property_income_multiplier()))
	else:
		# Starting an idle cycle is still a real tap (it feeds frenzy) and is allowed even
		# during an overheat lockout — only a FROZEN property refuses, up at the top of this func.
		frenzy.on_tap()
		prop.start_cycle()


## Layer 2 held-rush: one auto-rush pulse while the rush button is held.
## Rushes exactly like a tap, but charges the frenzy meter at the reduced
## hold factor — holding is convenient, so real tapping stays superior.
func hold_rush_property(prop_index: int) -> void:
	# Refused OUTRIGHT while Auto-Purchase Mode is on (plan §A5). Unlike tap_property this verb
	# has no start-a-stopped-cycle job of its own — the cycle start on line ~333 exists only so a
	# very short cycle can still be RUSHED by the same pulse — so there is nothing here worth
	# keeping once rush is off the table.
	if is_rush_locked_out_by_auto_purchase():
		return
	var prop := economy.properties[prop_index] as PropertyState
	# A frozen property is DOWN: the held rush is dead on it until rush_ready. This guard is
	# LOAD-BEARING now — it used to be covered incidentally by the can_rush() gate below, but that
	# gate no longer refuses the whole empire (see tap_property).
	if prop.is_overheat_frozen:
		return
	if not prop.is_cycle_running:
		# An UNSTAFFED cycle stops the moment it pays out, so on a very short cycle it is
		# usually stopped when the next 5/s hold pulse lands. This used to bail out here,
		# which let a fast property (Photon Exchange, 0.54s base, shortened further by
		# Legacy cycle upgrades + the First Contact bonus) complete-and-stop between EVERY
		# pulse: each pulse saw an idle cycle, restarted it as a plain tap, and no rush verb
		# ever fired — so Rush Momentum never engaged on that one property (Tim's device
		# report, 2026-07-27). A held pulse on an idle property now STARTS the cycle and
		# rushes it in the same pulse, so holding always engages regardless of cycle length.
		if prop.units_owned == 0:
			return
		prop.start_cycle()
	frenzy.on_tap(tuning.frenzy_fill_hold_factor)
	# Same rule as tap_property: a property that is not frozen keeps rushing through someone
	# else's lockout for income and frenzy, but the downed meter grants no heat and no bonus.
	if rush_momentum.can_rush():
		# Keep the global momentum meter building, and mark THIS property as actively rushed so the
		# bonus applies to it and only it (refreshed now so this payout already carries it; the tick
		# keeps it lit while the grace holds).
		_rush_grace_remaining = tuning.rush_momentum_grace_seconds
		prop.rush_active_grace = tuning.rush_momentum_grace_seconds
		prop.rush_momentum_factor = rush_momentum.factor()
	# Rush pays at the SAME multiplier the tick uses — frenzy and the dynasty's Family Fortune — and
	# credits immediately if it completes; Rush Momentum is folded in per-property via _collect's
	# rush_momentum_factor (set just above), so the cash keeps pace with the rushed bar AND the full
	# displayed rate (Tim 2026-07-12: rush dropped Family Fortune; 07-13: momentum now rush-only).
	economy.credit_property_income(prop.rush_cycle(frenzy.get_multiplier() * prop.legacy_income_multiplier))


## The player let go of a rush hold on this property. The grace windows exist only to bridge
## the gaps BETWEEN pulses while the button is held (they fire at 5/s, slower than the 10/s
## tick) — on an actual release they would otherwise keep momentum BUILDING for another grace
## period, which read on-device as the bar growing a beat after the finger lifted (Tim
## 2026-07-15). So end this property's rushed state now, and stop the global build unless
## some OTHER property is still inside its own rushed grace (a second finger).
func release_rush(prop_index: int) -> void:
	# During an open vent window a lift is a GESTURE BEAT, not a quit (Plans/
	# Overdrive_Vent_Windows.md): zeroing the graces here would drop the rushed property's
	# factor and end the excursion mid-gesture. The judge in RushMomentumState decides how the
	# window resolves; a real walk-away simply misses the window and overheats there.
	if rush_momentum.is_vent_window_open():
		return
	var prop := economy.properties[prop_index] as PropertyState
	prop.rush_active_grace = 0.0
	prop.rush_momentum_factor = 1.0
	for prop_variant in economy.properties:
		if (prop_variant as PropertyState).rush_active_grace > 0.0:
			return
	_rush_grace_remaining = 0.0


## The overheat moment (rush_momentum.overheated, connected in _init): every property still
## inside its actively-rushed grace goes DOWN for the whole lockout (Tim 2026-07-19: ALL of
## them, if multi-touch rushing several) — the machine that was pushed too hard is the machine
## that shuts off, so the penalty is proportional to what was gambled. Fired synchronously
## from inside rush_momentum.tick, BEFORE this tick's grace decay runs, so the grace values
## are exactly the overheat-moment snapshot.
## `_ended_vent_tier` is the streak the excursion reached; this freeze handler does not use it
## (the death chip and the bloodline record do), but the parameter must match the signal.
func _freeze_actively_rushed_properties(_ended_vent_tier: int) -> void:
	# An overheat grants no tail and zeroes the bonus INSTANTLY (RushMomentumState._begin_overheat),
	# so every tail dies here — including one still running from an earlier release on some other
	# property. The contrast between this and a bail's gentle spin-down is the value of bailing.
	clear_rush_tail_riders()
	for prop_variant in economy.properties:
		var p := prop_variant as PropertyState
		if p.rush_active_grace > 0.0:
			p.is_overheat_frozen = true
			# A downed property is no longer "actively rushed": zero its grace so the factor
			# loop in tick() holds its rush_momentum_factor at 1.0 for the whole freeze (the
			# grace cannot refill meanwhile — every rush verb is dead during the lockout).
			p.rush_active_grace = 0.0
			p.rush_momentum_factor = 1.0


## Bring every overheat-frozen property back up. Connected to rush_momentum.rush_ready (the
## lockout's exact end) and called on the First Contact reset in tick(); dynasty succession
## needs nothing because it builds a fresh GameState. These are the ONLY exits from the frozen
## state, so a freeze can never outlive its lockout. Public so the headless sim can sweep-check
## the invariant; the live game never needs to call it directly.
func unfreeze_all_properties() -> void:
	for prop_variant in economy.properties:
		(prop_variant as PropertyState).is_overheat_frozen = false


## Drop every release-tail rider mark, and park the factors that were riding on it back at 1.0.
## These are the ONLY three ways a tail ends — the heat model ceasing to pay one (the sweep in
## tick()), an overheat (which zeroes the bonus on the spot), and the First Contact reset — so a
## mark can never outlive the tail that justified it. Public so the headless sim can sweep-check
## that invariant; the live game reaches it through the three callers above.
func clear_rush_tail_riders() -> void:
	for prop_variant in economy.properties:
		var p := prop_variant as PropertyState
		if not p.is_rush_tail_rider:
			continue
		p.is_rush_tail_rider = false
		# Only a property that is NOT currently being rushed gets parked: one still inside its
		# grace has its factor set from factor() every tick anyway, and stomping it here would
		# blank a live rushed bonus for a tick.
		if p.rush_active_grace <= 0.0:
			p.rush_momentum_factor = 1.0


## The OVERDRIVE opt-in (Plans/Rush_Cruise_Control.md): release the cruise clamp so heat resumes
## climbing into the danger bands — the push-your-luck ride, exactly as it shipped. Gated on
## can_rush() like every rush verb, so the button is fully dead during an overheat lockout (the
## state's own locked-out no-op is the belt to this brace, same as the rush verbs above).
func engage_rush_overdrive() -> void:
	# Overdrive is a rush verb, so it goes down with the rest while Auto-Purchase Mode is on.
	if is_rush_locked_out_by_auto_purchase():
		return
	if not rush_momentum.can_rush():
		return
	rush_momentum.engage_overdrive()


## True while Auto-Purchase Mode is switched on, which is exactly when the rush verbs refuse
## (plan §A5: giving up rush is the price of the mode). Public and named so Main and MomentumBar
## can gray their controls off the same answer the core refuses on, instead of each re-deriving
## the condition and drifting from it.
##
## Note what this does NOT do: it does not freeze the heat meter. GameState.tick keeps calling
## rush_momentum.tick every frame — with `rushing` false, because no verb can refill the grace
## any more — so the heat bleeds down and pays its normal spin-down tail. Turning the mode on
## simply IS "the player let go". Parking heat at a non-zero fill would show the player a bonus
## they are not being paid, which breaks the system's binding invariant (plan §A5).
## `is_running()`, not `enabled`: the flag persists in the save, so a run can load with the mode
## switched on but the desk unowned. Asking about `enabled` alone made that save refuse every rush
## forever while nothing was ever bought — all of the mode's cost, none of its benefit.
func is_rush_locked_out_by_auto_purchase() -> bool:
	return auto_purchase.is_running()


## Press edge on a property's rush button — the raw finger-down moment, forwarded to the vent
## gesture judge (Plans/Overdrive_Vent_Windows.md). Only meaningful during an overdrive ride:
## the core ignores edges when no vent window is open or pending, so ordinary rush taps are
## unaffected. `prop_index` is accepted for symmetry with the other property verbs; the heat
## model is global, so the judge does not need it (only one property rides overdrive at a time).
func notify_rush_pressed(_prop_index: int) -> void:
	rush_momentum.notify_rush_pressed()


## Release edge on a property's rush button — the raw finger-up moment. See notify_rush_pressed.
func notify_rush_released(_prop_index: int) -> void:
	rush_momentum.notify_rush_released()


## Pop the frenzy meter if allowed. Returns true if a burn started.
func pop_frenzy() -> bool:
	if not frenzy.can_pop():
		return false
	frenzy.pop()
	return true


## Buy `count` units of a property. Returns false if unaffordable, or if the property is
## still locked behind a later epoch (gated by the run's reached epoch, like hiring).
func try_buy(prop_index: int, count: int) -> bool:
	return economy.try_buy(prop_index, count, epoch.current_tier)


## Buy the next staff-ladder level for a property — the one staff verb (hiring a staffer
## IS level 1 of each 20-level block, GDD §6.1). Passes the reached epoch so the cap
## (20 × blocks opened) is enforced. Returns false at the cap or if unaffordable.
func try_buy_staff_level(prop_index: int) -> bool:
	return economy.try_buy_staff_level(prop_index, epoch.current_tier)


# ---------------------------------------------------------------------------
# Offline
# ---------------------------------------------------------------------------

## Bank offline earnings for `elapsed_seconds` away (closed-form, Spec §2).
## Returns the result for the welcome-back screen.
##
## AUTO-PURCHASE DOES NOT RUN HERE, on purpose (plan §A7). Offline is its own banked-pile
## system, and a mode that spent the pile before the player ever saw it would undermine the
## welcome-back beat. So this deliberately never touches `auto_purchase` — the mode only
## advances on live ticks driven by the caller.
func apply_offline(elapsed_seconds: float, effective_cap_seconds: float = -1.0) -> OfflineCalculator.OfflineResult:
	var result := OfflineCalculator.calculate(economy, tuning, elapsed_seconds, effective_cap_seconds)
	OfflineCalculator.apply(economy, result)
	return result


# ---------------------------------------------------------------------------
# Save / load (versioned JSON schema — M1 brief)
# ---------------------------------------------------------------------------

## Everything needed to reconstruct the run. Only raw facts are saved;
## derived values (cost products, milestone rewards) are recomputed on load.
func to_save_dict() -> Dictionary:
	var props: Array = []
	for prop in economy.properties:
		var p := prop as PropertyState
		props.append({
			"units_owned": p.units_owned,
			# v9: the property's position on its single sequential staff ladder. This is the
			# ONLY staffing fact saved — the staffer tier and every multiplier are derived
			# from it (same principle as recomputing cost_product from purchases).
			"staff_level": p.staff_level,
			# v8: the permanent First Contact minigame bonus (alien properties). Saved raw because
			# it is won from minigame performance and can't be re-derived (GDD §5.5 site 2).
			"first_contact_income_mult": p.first_contact_income_multiplier,
			"first_contact_cycle_mult": p.first_contact_cycle_multiplier,
			"cycle_progress": p.cycle_progress,
			"is_cycle_running": p.is_cycle_running,
		})
	return {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"cash": economy.cash,
		"peak_net_worth": peak_net_worth,
		"buy_mode": ui_buy_mode,
		"hire_mode": ui_hire_mode,
		"currency_format": ui_currency_format,
		"minigame_enabled": ui_minigame_enabled,
		"auto_pop_turbo": ui_auto_pop_turbo,
		"music_volume": ui_music_volume,
		"sfx_volume": ui_sfx_volume,
		"haptics_scale": ui_haptics_scale,
		# The civ tab the pager last showed — also the tab Auto-Purchase Mode buys from.
		"epoch_tab": ui_epoch_tab,
		# Read straight off the policy object rather than mirrored into a second field, so
		# there is exactly one answer to "is the mode on?".
		"auto_purchase_enabled": auto_purchase.enabled,
		# Which alien epoch this run has reached (1 = Earth).
		"epoch_tier": epoch.current_tier,
		# Per-generation book-value accumulators (Spec §9.2). Saved raw because
		# they are sunk history, not derivable from the current holdings.
		"spent_on_units_this_gen": economy.spent_on_units_this_gen,
		"spent_on_staff_this_gen": economy.spent_on_staff_this_gen,
		# Birth seed cash, excluded from the Legacy conversion (see DynastyState).
		"starting_cash": economy.starting_cash,
		# Lifetime dollars this generation earned — the gross estate (Spec §9.1).
		# Saved raw because it is sunk history, not derivable from current holdings.
		"cash_earned_this_gen": economy.cash_earned_this_gen,
		"properties": props,
		"wage": {
			# v6: the numeric clock-in level + clicks banked toward the next level-up.
			"level": wage.level,
			"taps_into_level": wage.taps_into_level,
			"lifetime_taps": wage.lifetime_taps,
		},
		# A frenzy burn does not survive an app close; only the charge does.
		"frenzy": {"meter": frenzy.meter},
		"events": events.to_save_dict(),
	}


## Restore a run from a save dict (the inverse of to_save_dict).
func load_save_dict(data: Dictionary) -> void:
	# Versioned schema: only version 1 exists today; future migrations branch here.
	var version := int(data.get("version", 1))
	if version != SAVE_VERSION:
		push_warning("Save version %d differs from current %d; loading anyway." % [
			version, SAVE_VERSION
		])

	economy.cash = float(data.get("cash", 0.0))
	peak_net_worth = float(data.get("peak_net_worth", 0.0))
	ui_buy_mode = int(data.get("buy_mode", 3))  # 3 = MAX; matches the fresh-game default
	# 0 = x1, the ungated default. CLAMPED to the live HireMode range because the BLOCK mode was
	# removed on 2026-08-01, shrinking that enum from 4 entries to 3: a save written while BLOCK
	# existed can hold a 3 that no longer names anything. Clamping lands both the old BLOCK (2) and
	# the old MAX (3) on the new MAX (2) — the generous direction, and harmless either way, since
	# Main clamps again to whatever the Head Hunters track has actually unlocked.
	ui_hire_mode = clampi(int(data.get("hire_mode", 0)), 0, UI_HIRE_MODE_MAX)
	# Absent on every save written before this setting existed, so those saves adopt the
	# fresh-game default, ALPHABET (Tim, 2026-08-05). A save that DOES carry the key keeps
	# whatever the player picked — including ABBREVIATED — so an explicit choice is never
	# overwritten by the new default. Still no migration and no SAVE_VERSION bump: the key is
	# simply absent, and absent means "never chose", which is exactly the default's job.
	# Clamped because an out-of-range int here would break the formatter's match.
	ui_currency_format = clampi(
		int(data.get("currency_format", Money.Format.ALPHABET)),
		0, Money.Format.size() - 1
	)
	# Pre-minigame saves have no flag; default to enabled (mandatory until opted out).
	ui_minigame_enabled = bool(data.get("minigame_enabled", true))
	ui_auto_pop_turbo = bool(data.get("auto_pop_turbo", false))
	# Clamped on load, not merely defaulted: a level outside 0..1 would come straight through to
	# AudioServer as a nonsense dB value. No SAVE_VERSION bump — absent keys take the defaults.
	ui_music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	ui_sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)
	ui_haptics_scale = clampf(float(data.get("haptics_scale", 1.0)), 0.0, 1.0)
	# Saves written before Auto-Purchase Mode have neither key. Both defaults are the pre-feature
	# behaviour exactly — tab 0 (which Main then re-clamps/overrides through its own pager rules)
	# and the mode off — so an old save loads clean with no migration and no version bump.
	# Only the lower bound is enforced here: the headless model has no notion of how many tabs
	# the pager shows, so the upper clamp belongs to the UI (Main._epoch_tab_max).
	ui_epoch_tab = maxi(int(data.get("epoch_tab", 0)), 0)
	auto_purchase.enabled = bool(data.get("auto_purchase_enabled", false))

	economy.spent_on_units_this_gen = float(data.get("spent_on_units_this_gen", 0.0))
	economy.spent_on_staff_this_gen = float(data.get("spent_on_staff_this_gen", 0.0))
	economy.starting_cash = float(data.get("starting_cash", 0.0))
	# Pre-v4 saves have no earned accumulator; default to 0.0. (A bare backfill from
	# total_income isn't kept here, so an in-progress old generation simply starts
	# its earned tally fresh — only matters until its next death.)
	economy.cash_earned_this_gen = float(data.get("cash_earned_this_gen", 0.0))

	# Reached epoch (pre-v5 saves default to Earth/tier 1).
	var saved_tier := int(data.get("epoch_tier", 1))
	if version <= 11:
		# Earth-split migration (v12): alien tiers shift up one. A tier-1 (mid-Earth) save
		# maps to White Collar only if it already owns a White Collar property — otherwise
		# it stays in Blue Collar and earns the new promotion beat like a fresh run.
		if saved_tier >= 2:
			saved_tier += 1
		else:
			var old_props: Array = data.get("properties", [])
			for i in range(6, mini(12, old_props.size())):
				if int((old_props[i] as Dictionary).get("units_owned", 0)) > 0:
					saved_tier = 2
					break
	epoch.restore(saved_tier)

	var saved_props: Array = data.get("properties", [])
	for i in range(mini(saved_props.size(), economy.properties.size())):
		var sp: Dictionary = saved_props[i]
		var prop := economy.properties[i] as PropertyState
		var staff_level := int(sp.get("staff_level", 0))
		# Pre-v9 migration: older saves stored staffing as a TIER (separate hire purchases)
		# plus the level ladder. On the v9 unified ladder each of those hires is itself one
		# ladder level (level 1 of its block), so an old save's ladder position is its level
		# count plus its hire count, clamped to the blocks its reached epoch had opened.
		# (Pre-v5 saves only have is_staffed, which was already mapped to tier 1.) The
		# clamp makes the mapping safe rather than exact — old block boundaries counted 20
		# levels PLUS a hire, v9 blocks are 20 including the hire — a one-level generosity
		# at full blocks, accepted for a one-time migration.
		if version <= 8 or sp.has("staff_tier"):
			var old_tier := int(sp.get("staff_tier", 1 if bool(sp.get("is_staffed", false)) else 0))
			if old_tier <= 0:
				staff_level = 0
			else:
				var cap := prop.tuning.staff_levels_per_epoch \
						* prop.staff_blocks_available(epoch.current_tier)
				staff_level = mini(staff_level + old_tier, maxi(cap, 1))
		# Pre-v8 saves have no First Contact bonus; default 1.0 (base — no bonus).
		prop.restore(
			int(sp.get("units_owned", 0)),
			staff_level,
			float(sp.get("cycle_progress", 0.0)),
			bool(sp.get("is_cycle_running", false)),
			float(sp.get("first_contact_income_mult", 1.0)),
			float(sp.get("first_contact_cycle_mult", 1.0))
		)

	var w: Dictionary = data.get("wage", {})
	# v6 stores the numeric clock-in level; pre-v6 saves (title index) simply start the wage
	# fresh at level 0, keeping only the dynastic Work Ethic tap count.
	wage.level = int(w.get("level", 0))
	wage.taps_into_level = int(w.get("taps_into_level", 0))
	wage.lifetime_taps = int(w.get("lifetime_taps", 0))

	var f: Dictionary = data.get("frenzy", {})
	frenzy.meter = float(f.get("meter", 0.0))

	if data.has("events"):
		events.load_save_dict(data["events"])
