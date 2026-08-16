class_name EventState

# Headless state and rules engine for Rare Events (GDD §9 / Mechanics Spec §10).
# Manages active weather (Market Crash), pending dilemmas (The Audit), grants (The Windfall),
# duration ticking, and persistence.

signal weather_started(event_id: String, duration_seconds: float, multiplier: float)
signal weather_ended(event_id: String)
signal dilemma_opened(event_id: String, data: Dictionary)
signal dilemma_resolved(event_id: String, choice_index: int, outcome: Dictionary)
signal grant_received(event_id: String, amount: float)

var tuning: TuningConfig

## Currently active weather event ID (e.g. EventDef.ID_CRASH), or empty string if none.
var active_event_id: String = ""

## Seconds remaining on the active weather event. Ticks down ONLY during active play.
var active_event_remaining: float = 0.0

## Initial duration of the currently active weather event.
var active_event_duration: float = 0.0

## Currently pending dilemma ID (e.g. EventDef.ID_AUDIT), or empty string if none.
var pending_dilemma_id: String = ""

## Cached metadata and preview quotes for the pending dilemma.
var pending_dilemma_data: Dictionary = {}

## Time in seconds since the last event roll check.
var time_since_last_roll: float = 0.0

## Total active playtime in seconds during this generation.
var total_active_time: float = 0.0

## History of event IDs triggered during this generation.
var generation_events_triggered: Array[String] = []


func _init(p_tuning: TuningConfig) -> void:
	tuning = p_tuning


## Advance active event timers and check periodic roll cadence.
func tick(delta: float, game: GameState) -> void:
	total_active_time += delta

	# Tick active weather
	if active_event_remaining > 0.0:
		active_event_remaining = maxf(0.0, active_event_remaining - delta)
		if active_event_remaining <= 0.0:
			_end_active_weather()

	# Periodic event rolls during active play
	if total_active_time >= tuning.event_grace_period_seconds and pending_dilemma_id == "":
		time_since_last_roll += delta
		if time_since_last_roll >= tuning.event_roll_interval_seconds:
			time_since_last_roll = 0.0
			_maybe_trigger_random_event(game)


## Property income multiplier in effect from active weather events.
## Applies ONLY to property income, NEVER to wages (Spec §10 / GDD §9).
func get_property_income_multiplier() -> float:
	if active_event_id == EventDef.ID_CRASH and active_event_remaining > 0.0:
		return tuning.crash_multiplier
	return 1.0


## True if Market Crash weather is currently in progress.
func is_crash_active() -> bool:
	return active_event_id == EventDef.ID_CRASH and active_event_remaining > 0.0


## Trigger an event by ID explicitly (used by random roll or dev tuning panel).
func trigger_event(event_id: String, game: GameState) -> bool:
	if not EventDef.is_eligible(event_id, game):
		return false

	match event_id:
		EventDef.ID_CRASH:
			trigger_crash(tuning.crash_duration_minutes, game)
			return true
		EventDef.ID_AUDIT:
			trigger_audit(game)
			return true
		EventDef.ID_WINDFALL:
			trigger_windfall(game)
			return true
		_:
			return false


## Start a Market Crash weather event.
func trigger_crash(duration_minutes: float, _game: GameState) -> void:
	active_event_id = EventDef.ID_CRASH
	active_event_duration = maxf(1.0, duration_minutes * 60.0)
	active_event_remaining = active_event_duration
	generation_events_triggered.append(EventDef.ID_CRASH)
	weather_started.emit(EventDef.ID_CRASH, active_event_remaining, tuning.crash_multiplier)


## Present The Audit dilemma.
func trigger_audit(game: GameState) -> Dictionary:
	var net_worth := get_current_net_worth(game)
	var settle_cost := floorf(maxf(100.0, net_worth * tuning.audit_settle_rate))
	var leg_units := get_legislative_assets_count(game)
	var leg_threshold := tuning.audit_threshold
	var fight_penalty := settle_cost * 3.0

	pending_dilemma_id = EventDef.ID_AUDIT
	pending_dilemma_data = {
		"net_worth": net_worth,
		"settle_cost": settle_cost,
		"leg_units": leg_units,
		"leg_threshold": leg_threshold,
		"fight_penalty": fight_penalty,
		"has_enough_legislators": leg_units >= leg_threshold,
	}
	generation_events_triggered.append(EventDef.ID_AUDIT)
	dilemma_opened.emit(EventDef.ID_AUDIT, pending_dilemma_data)
	return pending_dilemma_data


## Resolve The Audit dilemma.
## choice_index: 0 = Settle, 1 = Fight.
func resolve_audit(choice_index: int, game: GameState) -> Dictionary:
	if pending_dilemma_id != EventDef.ID_AUDIT:
		return {}

	var data := pending_dilemma_data
	var outcome := {}

	if choice_index == 0:
		# Settle: Pay AUDIT_SETTLE (8% of net worth)
		var cost: float = data.get("settle_cost", 100.0)
		var actual_paid := minf(cost, game.economy.cash)
		game.economy.cash = maxf(0.0, game.economy.cash - cost)
		outcome = {
			"choice": "settle",
			"cost_assessed": cost,
			"cost_paid": actual_paid,
			"success": true,
			"message": "You agreed to settlement terms with the examiners.",
		}
	else:
		# Fight: If legislative assets >= threshold, case evaporates; else 3x penalty
		var leg_units: int = data.get("leg_units", 0)
		var threshold: int = data.get("leg_threshold", 1)
		if leg_units >= threshold:
			outcome = {
				"choice": "fight",
				"cost_assessed": 0.0,
				"cost_paid": 0.0,
				"success": true,
				"message": "Your friends in the legislature resolved the audit inquiries quietly.",
			}
		else:
			var penalty: float = data.get("fight_penalty", 300.0)
			var actual_paid := minf(penalty, game.economy.cash)
			game.economy.cash = maxf(0.0, game.economy.cash - penalty)
			outcome = {
				"choice": "fight",
				"cost_assessed": penalty,
				"cost_paid": actual_paid,
				"success": false,
				"message": "Without legislative representation, the court assessed triple damages.",
			}

	pending_dilemma_id = ""
	pending_dilemma_data = {}
	dilemma_resolved.emit(EventDef.ID_AUDIT, choice_index, outcome)
	return outcome


## Trigger The Windfall instant grant.
func trigger_windfall(game: GameState) -> float:
	var net_worth := get_current_net_worth(game)
	var amount := floorf(maxf(250.0, net_worth * tuning.windfall_net_worth_fraction))
	game.economy.award_cash(amount)
	generation_events_triggered.append(EventDef.ID_WINDFALL)
	grant_received.emit(EventDef.ID_WINDFALL, amount)
	return amount


## Clear any active weather or pending dilemmas immediately.
func clear_all_events() -> void:
	if active_event_id != "":
		var old_id := active_event_id
		active_event_id = ""
		active_event_remaining = 0.0
		active_event_duration = 0.0
		weather_ended.emit(old_id)
	pending_dilemma_id = ""
	pending_dilemma_data = {}


func _end_active_weather() -> void:
	var old_id := active_event_id
	active_event_id = ""
	active_event_remaining = 0.0
	active_event_duration = 0.0
	weather_ended.emit(old_id)


func _maybe_trigger_random_event(game: GameState) -> void:
	if randf() > tuning.event_base_chance:
		return

	var eligible: Array[String] = []
	for ev_id in EventDef.ALL_EVENTS:
		# Don't re-trigger an already active weather event
		if ev_id == active_event_id:
			continue
		if EventDef.is_eligible(ev_id, game):
			eligible.append(ev_id)

	if eligible.is_empty():
		return

	var picked: String = eligible[randi() % eligible.size()]
	trigger_event(picked, game)


## Query the unit count of Legislative Assets owned in the empire.
static func get_legislative_assets_count(game: GameState) -> int:
	if game == null or game.economy == null:
		return 0
	for prop_obj in game.economy.properties:
		var p := prop_obj as PropertyState
		if p.config.property_id == 11 or p.config.display_name == "Legislative Assets":
			return p.units_owned
	return 0


## Query estimated net worth for scaling event impacts.
static func get_current_net_worth(game: GameState) -> float:
	if game == null or game.economy == null:
		return 0.0
	var base_net: float = game.economy.cash + game.economy.spent_on_units_this_gen + game.economy.spent_on_staff_this_gen
	return maxf(base_net, game.peak_net_worth)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"active_event_id": active_event_id,
		"active_event_remaining": active_event_remaining,
		"active_event_duration": active_event_duration,
		"pending_dilemma_id": pending_dilemma_id,
		"pending_dilemma_data": pending_dilemma_data,
		"time_since_last_roll": time_since_last_roll,
		"total_active_time": total_active_time,
		"generation_events_triggered": generation_events_triggered,
	}


func load_save_dict(data: Dictionary) -> void:
	active_event_id = String(data.get("active_event_id", ""))
	active_event_remaining = float(data.get("active_event_remaining", 0.0))
	active_event_duration = float(data.get("active_event_duration", 0.0))
	pending_dilemma_id = String(data.get("pending_dilemma_id", ""))
	pending_dilemma_data = (data.get("pending_dilemma_data", {}) as Dictionary).duplicate()
	time_since_last_roll = float(data.get("time_since_last_roll", 0.0))
	total_active_time = float(data.get("total_active_time", 0.0))
	generation_events_triggered = []
	for ev in data.get("generation_events_triggered", []):
		generation_events_triggered.append(String(ev))
