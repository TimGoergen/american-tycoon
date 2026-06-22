class_name TimingBarMinigame
extends Minigame

# The timing-bar minigame TYPE (GDD §5.5) — a quick precision game, the second entry in the
# library so the host's random draw has variety. A marker sweeps back and forth across a
# bar; the player taps LOCK to stop it as close to the centered gold zone as possible. Each
# lock scores accuracy in [0,1]; after TARGET_LOCKS locks the game ends. The marker speeds
# up a little each lock. Performance = average accuracy over TARGET_LOCKS (missing locks
# count as zero, so you must keep locking, not just nail one).
#
# Owns only its gameplay; the host owns the countdown / spectrum / result / multiplier.

## How many locks make a full game (and the denominator for performance — fewer = lower).
const TARGET_LOCKS := 12
## Half-width of the gold "perfect" zone, as a fraction of the bar (centered on 0.5).
const ZONE_HALF := 0.12
## Marker sweep speed (bar-fractions per second) and how much it ramps each lock.
const BASE_SPEED := 0.9
const SPEED_RAMP := 1.06

var _marker_pos: float = 0.0
var _marker_dir: float = 1.0
var _marker_speed: float = BASE_SPEED
var _locks: int = 0
var _accuracy_sum: float = 0.0
var _running: bool = false
var _flash: float = 0.0  # brief post-lock highlight, decays in _process

var _bar: Control
var _locks_label: Label


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_pos = 0.0
	_marker_dir = 1.0
	_marker_speed = BASE_SPEED
	_locks = 0
	_accuracy_sum = 0.0
	_running = true

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var intro := Label.new()
	intro.text = "Tap LOCK when the marker hits the gold zone."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(intro)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 96)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)

	_locks_label = Label.new()
	_locks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locks_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_locks_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	column.add_child(_locks_label)
	_update_locks_label()

	var lock_button := Button.new()
	lock_button.text = "LOCK"
	lock_button.custom_minimum_size = Vector2(0, 110)
	UiPalette.style_button(lock_button, true)  # red: the act button
	lock_button.pressed.connect(_on_lock)
	column.add_child(lock_button)


func get_performance() -> float:
	return clampf(_accuracy_sum / float(TARGET_LOCKS), 0.0, 1.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	_marker_pos += _marker_dir * _marker_speed * delta
	if _marker_pos >= 1.0:
		_marker_pos = 1.0
		_marker_dir = -1.0
	elif _marker_pos <= 0.0:
		_marker_pos = 0.0
		_marker_dir = 1.0
	if _bar != null:
		_bar.queue_redraw()


func _on_lock() -> void:
	if not _running:
		return
	# Accuracy: 1.0 dead-center, falling to 0 at the bar ends.
	var accuracy := clampf(1.0 - absf(_marker_pos - 0.5) / 0.5, 0.0, 1.0)
	_accuracy_sum += accuracy
	_locks += 1
	_marker_speed *= SPEED_RAMP
	_flash = 1.0
	_update_locks_label()
	if _locks >= TARGET_LOCKS:
		_running = false
		completed.emit(get_performance())


func _update_locks_label() -> void:
	_locks_label.text = "Locks: %d / %d" % [_locks, TARGET_LOCKS]


## Draw the bar: a navy track, a centered gold target zone, and the sweeping marker
## (brightening briefly after each lock).
func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	# Gold target zone, centered.
	var zone_x := (0.5 - ZONE_HALF) * w
	var zone_w := (ZONE_HALF * 2.0) * w
	_bar.draw_rect(Rect2(zone_x, 0, zone_w, h), UiPalette.MUSTARD_GOLD)
	# Marker (a thick vertical bar), cream, flashing brighter just after a lock.
	var marker_color := UiPalette.CREAM.lightened(_flash * 0.6)
	var mx := _marker_pos * w
	_bar.draw_rect(Rect2(mx - 5.0, 0, 10.0, h), marker_color)
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
