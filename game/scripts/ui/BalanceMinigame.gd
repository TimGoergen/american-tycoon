class_name BalanceMinigame
extends Minigame

# "Balance" minigame TYPE (GDD §5.5) — a sustained-control game (the "balance" idea from
# Tim's vacation notes, done without a physics engine). A marker drifts left/right under a
# wandering force; hold LEFT / RIGHT to counter it and keep it in the centered gold zone.
# Performance = fraction of time spent in the zone. It has no natural end — the host's
# countdown ends the round.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

const ZONE_HALF := 0.13          # half-width of the gold zone (bar fraction), centered on 0.5
const NUDGE_ACCEL := 1.7         # how hard a held button pushes (bar-fractions / sec^2)
const DRIFT_MAX := 0.9           # magnitude of the wandering drift force
const DRIFT_CHANGE := 1.1        # seconds between drift re-rolls
const DAMPING := 2.4             # velocity damping per second (keeps it controllable)

var _pos: float = 0.5
var _vel: float = 0.0
var _drift: float = 0.0
var _drift_timer: float = 0.0
var _time_in_zone: float = 0.0
var _elapsed: float = 0.0
var _left_held: bool = false
var _right_held: bool = false
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _bar: Control


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	_pos = 0.5

	var intro := Label.new()
	intro.text = "Hold the arrows to keep the marker in the gold zone."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 120)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar.draw.connect(_draw_bar)

	var left := Button.new()
	left.text = "◄"
	left.custom_minimum_size = Vector2(0, 130)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPalette.style_button(left, false)
	left.button_down.connect(func() -> void: _left_held = true)
	left.button_up.connect(func() -> void: _left_held = false)

	var right := Button.new()
	right.text = "►"
	right.custom_minimum_size = Vector2(0, 130)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPalette.style_button(right, false)
	right.button_down.connect(func() -> void: _right_held = true)
	right.button_up.connect(func() -> void: _right_held = false)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.add_child(left)
	buttons.add_child(right)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	column.add_child(intro)
	column.add_child(_bar)
	column.add_child(buttons)
	add_child(column)


func get_performance() -> float:
	if _elapsed <= 0.0:
		return 0.0
	return clampf(_time_in_zone / _elapsed, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _running:
		return

	# Re-roll the wandering drift periodically.
	_drift_timer -= delta
	if _drift_timer <= 0.0:
		_drift = _rng.randf_range(-DRIFT_MAX, DRIFT_MAX)
		_drift_timer = DRIFT_CHANGE

	var nudge := 0.0
	if _left_held:
		nudge -= NUDGE_ACCEL
	if _right_held:
		nudge += NUDGE_ACCEL

	_vel += (_drift + nudge) * delta
	_vel *= maxf(0.0, 1.0 - DAMPING * delta)  # damp toward rest so it stays controllable
	_pos += _vel * delta
	if _pos <= 0.0:
		_pos = 0.0
		_vel = 0.0
	elif _pos >= 1.0:
		_pos = 1.0
		_vel = 0.0

	if absf(_pos - 0.5) <= ZONE_HALF:
		_time_in_zone += delta
	_elapsed += delta

	if _bar != null:
		_bar.queue_redraw()


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	var zone_x := (0.5 - ZONE_HALF) * w
	var zone_w := (ZONE_HALF * 2.0) * w
	_bar.draw_rect(Rect2(zone_x, 0, zone_w, h), UiPalette.MUSTARD_GOLD)
	# Marker: green while in the zone, red while out, so the player reads success at a glance.
	var in_zone := absf(_pos - 0.5) <= ZONE_HALF
	var marker_color := UiPalette.MONEY_GREEN if in_zone else UiPalette.KETCHUP_RED
	_bar.draw_rect(Rect2(_pos * w - 7.0, 0, 14.0, h), marker_color)
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
