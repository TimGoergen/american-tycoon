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
const SAVE_VERSION := 9

var tuning: TuningConfig
var economy: EconomyState
var wage: WageState
var frenzy: FrenzyState

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

## Highest net worth this generation has reached. The next heir must out-earn
## this peak before its Legacy sprint multiplier gives way to the residual
## (Spec §9.4). Monotonic — only ever rises within a generation.
var peak_net_worth: float = 0.0

## UI preference: the player's selected global buy mode (a PropertyRow.BuyMode int).
## Stored here only so it persists in the save file across sessions; the headless
## model never reads it. Defaults to 3 = MAX (Tim, 2026-06-23 — a fresh game should
## start in buy-max). The literal avoids a UI-class dependency from this headless file.
var ui_buy_mode: int = 3

## UI preference: whether the prestige minigame is played (true) or auto-skipped for a
## flat 1.0× Legacy multiplier (false). Defaults to on (the minigame is mandatory until
## the player opts out — GDD §5.5). Persisted in the save like ui_buy_mode.
var ui_minigame_enabled: bool = true

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
	# and bleeds otherwise; a frenzy BURN freezes the whole heat model (Tim 2026-07-15 — see
	# RushMomentumState). The bonus MAGNITUDE is global, but it is applied ONLY to the properties
	# being actively rushed (Tim 2026-07-13) — via each property's own rush_momentum_factor below,
	# NOT the whole-economy tick multiplier.
	# While a vent window is open, the gesture's lifts (finger deliberately OFF the button —
	# Plans/Overdrive_Vent_Windows.md) must not read as "stopped rushing": the player still
	# counts as rushing even with the grace expired, and the grace timers below are frozen so
	# neither the global build nor the rushed property's factor can bleed mid-gesture. The
	# window is at most ~1 s, so freezing the decay for its span is imperceptible elsewhere.
	var vent_gesture_holding := rush_momentum.is_vent_window_open()
	rush_momentum.tick(delta, _rush_grace_remaining > 0.0 or vent_gesture_holding,
			frenzy.is_burning())
	if not vent_gesture_holding:
		_rush_grace_remaining = maxf(_rush_grace_remaining - delta, 0.0)
	# Point each property's momentum factor at the current bonus while it is still inside its
	# actively-rushed grace, else back to 1.0; then decay that grace so the boost fades a beat after
	# the player stops rushing it. This is what confines momentum to the rushed property.
	# (Overheat-frozen properties always take the 1.0 branch: the freeze handler zeroed their
	# grace, and no rush verb can refill it while the lockout has every rush verb dead.)
	for prop_variant in economy.properties:
		var p := prop_variant as PropertyState
		p.rush_momentum_factor = rush_momentum.factor() if p.rush_active_grace > 0.0 else 1.0
		if not vent_gesture_holding:
			p.rush_active_grace = maxf(p.rush_active_grace - delta, 0.0)
	var tier_before := epoch.current_tier
	economy.tick(delta, frenzy.get_multiplier() * extra_property_multiplier)
	peak_net_worth = maxf(peak_net_worth, economy.get_net_worth())
	# Advance the alien epoch if this generation has now earned enough to consume the
	# current economy. Reads the same lifetime-earned tally the estate waterfall uses.
	epoch.update(economy.cash_earned_this_gen)
	# Reaching a new epoch (First Contact) wipes momentum — each epoch builds its own from scratch,
	# which is what keeps Rush Momentum a per-epoch pinch instead of a run-long snowball. The
	# reset also ends any lockout, so every frozen property comes back up with it (a freeze may
	# never outlive the lockout that caused it). Dynasty succession needs no equivalent call:
	# it builds a brand-new GameState (DynastyState), whose properties are all born unfrozen.
	if epoch.current_tier > tier_before:
		rush_momentum.reset()
		unfreeze_all_properties()
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
	# The auto-clicker's "amount" Legacy upgrade makes each HELD tap earn extra, on top of
	# the normal per-tap wage (manual taps don't get this bonus).
	var earned := floorf(wage.tap_wage(frenzy.get_multiplier()) * wage.auto_tap_power_multiplier)
	# Held auto-tap earns the wage in full, so it counts as earned money too.
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
		# During an overheat lockout the rush verb is fully DEAD (Plans/Rush_Overheat.md): no
		# frenzy fill, no grace, no rush income. Starting an idle cycle (the else branch) still
		# works while locked out — only rushing is the overheating act.
		if not rush_momentum.can_rush():
			return
		frenzy.on_tap()
		# Keep the global momentum meter building, and mark THIS property as actively rushed so the
		# bonus applies to it and only it. Its rush_momentum_factor is refreshed now, so this very
		# payout already carries the bonus, and the tick keeps it lit while the grace holds.
		_rush_grace_remaining = tuning.rush_momentum_grace_seconds
		prop.rush_active_grace = tuning.rush_momentum_grace_seconds
		prop.rush_momentum_factor = rush_momentum.factor()
		# Rush pays at the SAME multiplier the tick uses — frenzy and the dynasty's Family Fortune;
		# Rush Momentum is now folded in per-property via _collect's rush_momentum_factor (set just
		# above), so the rushed cycle collects exactly the full rate the row shows (Tim 2026-07-12/13).
		economy.credit_property_income(prop.rush_cycle(frenzy.get_multiplier() * prop.legacy_income_multiplier))
	else:
		# Starting an idle cycle is still a real tap (it feeds frenzy) and is allowed even
		# during an overheat lockout — see the can_rush() gate above.
		frenzy.on_tap()
		prop.start_cycle()


## Layer 2 held-rush: one auto-rush pulse while the rush button is held.
## Rushes exactly like a tap, but charges the frenzy meter at the reduced
## hold factor — holding is convenient, so real tapping stays superior.
func hold_rush_property(prop_index: int) -> void:
	var prop := economy.properties[prop_index] as PropertyState
	if not prop.is_cycle_running:
		return
	# During an overheat lockout the held rush is fully DEAD too: no frenzy fill, no grace, no
	# rush income (Plans/Rush_Overheat.md).
	if not rush_momentum.can_rush():
		return
	frenzy.on_tap(tuning.frenzy_fill_hold_factor)
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
func _freeze_actively_rushed_properties() -> void:
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


## The OVERDRIVE opt-in (Plans/Rush_Cruise_Control.md): release the cruise clamp so heat resumes
## climbing into the danger bands — the push-your-luck ride, exactly as it shipped. Gated on
## can_rush() like every rush verb, so the button is fully dead during an overheat lockout (the
## state's own locked-out no-op is the belt to this brace, same as the rush verbs above).
func engage_rush_overdrive() -> void:
	if not rush_momentum.can_rush():
		return
	rush_momentum.engage_overdrive()


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
func apply_offline(elapsed_seconds: float) -> OfflineCalculator.OfflineResult:
	var result := OfflineCalculator.calculate(economy, tuning, elapsed_seconds)
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
		"minigame_enabled": ui_minigame_enabled,
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
	# Pre-minigame saves have no flag; default to enabled (mandatory until opted out).
	ui_minigame_enabled = bool(data.get("minigame_enabled", true))
	economy.spent_on_units_this_gen = float(data.get("spent_on_units_this_gen", 0.0))
	economy.spent_on_staff_this_gen = float(data.get("spent_on_staff_this_gen", 0.0))
	economy.starting_cash = float(data.get("starting_cash", 0.0))
	# Pre-v4 saves have no earned accumulator; default to 0.0. (A bare backfill from
	# total_income isn't kept here, so an in-progress old generation simply starts
	# its earned tally fresh — only matters until its next death.)
	economy.cash_earned_this_gen = float(data.get("cash_earned_this_gen", 0.0))

	# Reached epoch (pre-v5 saves default to Earth/tier 1).
	epoch.restore(int(data.get("epoch_tier", 1)))

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
