class_name GameState

# Top-level headless game state for one run. Composes the economy, the wage
# ladder, and the frenzy meter, and wires the frenzy multiplier into all
# income at point of payment (Spec §3.4). The scene layer and the balance
# simulator both drive the game exclusively through this class (Spec §13:
# same code, no rendering), so nothing here may touch the scene tree.

# v2 added the per-generation spend accumulators and peak net worth that the
# prestige/estate math reads (Spec §9). v1 saves still load (missing fields
# default to a clean slate).
const SAVE_VERSION := 2

var tuning: TuningConfig
var economy: EconomyState
var wage: WageState
var frenzy: FrenzyState

## Highest net worth this generation has reached. The next heir must out-earn
## this peak before its Legacy sprint multiplier gives way to the residual
## (Spec §9.4). Monotonic — only ever rises within a generation.
var peak_net_worth: float = 0.0

## UI preference: the player's selected global buy mode (a PropertyRow.BuyMode int).
## Stored here only so it persists in the save file across sessions; the headless
## model never reads it.
var ui_buy_mode: int = 0

## The headline income/sec shown on the hero panel. It is built as a guaranteed
## floor plus a bonus: it never reads below the guaranteed staffed income (what
## idle play keeps earning), and on top of that it adds a smoothed average of the
## extra the player is currently generating through their own inputs — manual
## taps, rushes, wage clicks, and frenzy. Display-only.
var displayed_income_per_sec: float = 0.0

## Smoothed bonus rate ($/sec) earned ABOVE the guaranteed staffed floor. Tracked
## as a true average, so it can dip negative between the lumpy spikes of cycle
## payouts; it is clamped to 0 only when added to the floor for display, so the
## headline can never fall below the guaranteed staffed income.
var _smoothed_bonus_per_sec: float = 0.0

## Time constant (seconds) for the bonus average. Deliberately longer than a "live"
## readout: individual cycle payouts arrive as spikes, and a longer window averages
## those spikes (and the quiet gaps between them) into a steady bonus reading.
const BONUS_INCOME_TAU := 4.0

# Wage earned since the last tick (taps fire between ticks); folded into the
# bonus average on the next tick, then cleared.
var _wage_earned_since_tick: float = 0.0
var _bonus_seeded := false


func _init(property_configs: Array, titles: Array, p_tuning: TuningConfig) -> void:
	tuning = p_tuning
	economy = EconomyState.new(property_configs, p_tuning)
	wage = WageState.new(titles)
	frenzy = FrenzyState.new(p_tuning)


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
	economy.tick(delta, frenzy.get_multiplier() * extra_property_multiplier)
	peak_net_worth = maxf(peak_net_worth, economy.get_net_worth())
	_update_displayed_income(delta)


## Recompute the headline income/sec as "guaranteed staffed floor + smoothed bonus".
## The bonus is the average amount this tick's ACTUAL inflow (property completions +
## wage taps, frenzy included) ran above the guaranteed staffed rate. Because staffed
## payouts arrive in lumps, the raw bonus swings positive on a payout and negative in
## the gaps; we average it (allowing negatives so the swings cancel) and then clamp to
## 0 at display time, so the headline sits at the floor when idle and lifts smoothly
## above it while the player is actively earning extra.
func _update_displayed_income(delta: float) -> void:
	if delta <= 0.0:
		return
	var guaranteed := economy.get_staffed_income_per_sec()
	var inflow := economy.income_this_tick + _wage_earned_since_tick
	_wage_earned_since_tick = 0.0
	var bonus_instantaneous := inflow / delta - guaranteed
	if not _bonus_seeded:
		# Start with no bonus so a freshly loaded game reads exactly the floor.
		_smoothed_bonus_per_sec = 0.0
		_bonus_seeded = true
	var alpha := 1.0 - exp(-delta / BONUS_INCOME_TAU)
	_smoothed_bonus_per_sec += (bonus_instantaneous - _smoothed_bonus_per_sec) * alpha
	displayed_income_per_sec = guaranteed + maxf(_smoothed_bonus_per_sec, 0.0)


# ---------------------------------------------------------------------------
# Player verbs — every tap feeds the frenzy meter (Spec §7)
# ---------------------------------------------------------------------------

## Layer 1: tap the wage button. Pays the current title's wage immediately.
func tap_wage() -> void:
	frenzy.on_tap()
	var earned := wage.tap_wage(frenzy.get_multiplier())
	economy.award_cash(earned)
	_wage_earned_since_tick += earned


## Layer 1 auto-tap: one held "clock in" pulse. Earns the wage in full (it is
## honest money) but fills frenzy at the reduced hold factor, exactly like held
## property rushes — holding is convenient, so deliberate tapping stays superior
## (Spec §7). The pulse rate lives in the UI (WagePanel), upgrade-scalable later.
func hold_tap_wage() -> void:
	frenzy.on_tap(tuning.frenzy_fill_hold_factor)
	var earned := wage.tap_wage(frenzy.get_multiplier())
	economy.award_cash(earned)
	_wage_earned_since_tick += earned


## Layer 2: tap a property. Starts the cycle if idle, rushes it if running.
func tap_property(prop_index: int) -> void:
	frenzy.on_tap()
	var prop := economy.properties[prop_index] as PropertyState
	if prop.is_cycle_running:
		prop.rush_cycle()
	else:
		prop.start_cycle()


## Layer 2 held-rush: one auto-rush pulse while the rush button is held.
## Rushes exactly like a tap, but charges the frenzy meter at the reduced
## hold factor — holding is convenient, so real tapping stays superior.
func hold_rush_property(prop_index: int) -> void:
	var prop := economy.properties[prop_index] as PropertyState
	if not prop.is_cycle_running:
		return
	frenzy.on_tap(tuning.frenzy_fill_hold_factor)
	prop.rush_cycle()


## Pop the frenzy meter if allowed. Returns true if a burn started.
func pop_frenzy() -> bool:
	if not frenzy.can_pop():
		return false
	frenzy.pop()
	return true


## Buy `count` units of a property. Returns false if unaffordable.
func try_buy(prop_index: int, count: int) -> bool:
	return economy.try_buy(prop_index, count)


## Hire the staffer for a property. Returns false if unaffordable or staffed.
func try_hire(prop_index: int) -> bool:
	return economy.try_hire(prop_index)


## Claim the next wage-ladder title if the tap threshold is met and tuition
## is affordable (Spec §5: promotion needs both). Returns true on success.
func try_claim_promotion() -> bool:
	if not wage.is_promotion_unlocked():
		return false
	var next := wage.get_next_title()
	if economy.cash < next.tuition:
		return false
	economy.cash -= next.tuition
	wage.claim_promotion()
	return true


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
			"is_staffed": p.is_staffed,
			"cycle_progress": p.cycle_progress,
			"is_cycle_running": p.is_cycle_running,
		})
	return {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"cash": economy.cash,
		"peak_net_worth": peak_net_worth,
		"buy_mode": ui_buy_mode,
		# Per-generation book-value accumulators (Spec §9.2). Saved raw because
		# they are sunk history, not derivable from the current holdings.
		"spent_on_units_this_gen": economy.spent_on_units_this_gen,
		"spent_on_staff_this_gen": economy.spent_on_staff_this_gen,
		"properties": props,
		"wage": {
			"current_title_index": wage.current_title_index,
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
	ui_buy_mode = int(data.get("buy_mode", 0))
	economy.spent_on_units_this_gen = float(data.get("spent_on_units_this_gen", 0.0))
	economy.spent_on_staff_this_gen = float(data.get("spent_on_staff_this_gen", 0.0))

	var saved_props: Array = data.get("properties", [])
	for i in range(mini(saved_props.size(), economy.properties.size())):
		var sp: Dictionary = saved_props[i]
		var prop := economy.properties[i] as PropertyState
		prop.restore(
			int(sp.get("units_owned", 0)),
			bool(sp.get("is_staffed", false)),
			float(sp.get("cycle_progress", 0.0)),
			bool(sp.get("is_cycle_running", false))
		)

	var w: Dictionary = data.get("wage", {})
	wage.current_title_index = int(w.get("current_title_index", 0))
	wage.lifetime_taps = int(w.get("lifetime_taps", 0))

	var f: Dictionary = data.get("frenzy", {})
	frenzy.meter = float(f.get("meter", 0.0))
