class_name GameState

# Top-level headless game state for one run. Composes the economy, the wage
# ladder, and the frenzy meter, and wires the frenzy multiplier into all
# income at point of payment (Spec §3.4). The scene layer and the balance
# simulator both drive the game exclusively through this class (Spec §13:
# same code, no rendering), so nothing here may touch the scene tree.

const SAVE_VERSION := 1

var tuning: TuningConfig
var economy: EconomyState
var wage: WageState
var frenzy: FrenzyState


func _init(property_configs: Array, titles: Array, p_tuning: TuningConfig) -> void:
	tuning = p_tuning
	economy = EconomyState.new(property_configs, p_tuning)
	wage = WageState.new(titles)
	frenzy = FrenzyState.new(p_tuning)


## Advance the whole game by `delta` seconds of active play.
func tick(delta: float) -> void:
	frenzy.tick(delta)
	economy.tick(delta, frenzy.get_multiplier())


# ---------------------------------------------------------------------------
# Player verbs — every tap feeds the frenzy meter (Spec §7)
# ---------------------------------------------------------------------------

## Layer 1: tap the wage button. Pays the current title's wage immediately.
func tap_wage() -> void:
	frenzy.on_tap()
	economy.award_cash(wage.tap_wage(frenzy.get_multiplier()))


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
