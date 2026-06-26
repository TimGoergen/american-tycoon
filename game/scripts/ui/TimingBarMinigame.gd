class_name TimingBarMinigame
extends Minigame

# The timing-bar minigame TYPE (GDD §5.5) — a quick precision game, the second entry in the
# library so the host's random draw has variety. A marker sweeps back and forth across a
# bar; the player taps LOCK to catch it inside the gold zone. The zone JUMPS to a new random
# spot after every successful lock and slowly SHRINKS (down to half its width) as locks pile
# up, so it gets harder. A click that misses the zone COSTS a lock. Each successful lock
# scores accuracy in [0,1]; after TARGET_LOCKS successful locks the game ends, and the marker
# speeds up a little each lock. Performance = average accuracy over TARGET_LOCKS (a never-made
# lock counts as zero, so you must keep landing them, not just nail one).
#
# Owns only its gameplay; the host owns the countdown / spectrum / result / multiplier.

## How many successful locks make a full game (and the denominator for performance).
## Tuned down from 12 to 10 for the shorter ~20s round: each lock now also pauses for a 0.5s
## freeze-burst (which does NOT count against the countdown), so 10 keeps a full game feasible
## inside ~20s of active play while still demanding a steady streak of good taps.
const TARGET_LOCKS := 10
## How long (seconds) each LOCK press freezes the marker/zone to show a hit-or-miss burst.
## The freeze pauses the host countdown (see is_busy()), so it is never charged to the player.
const FREEZE_TIME := 0.5
## Half-width of the gold "perfect" zone, as a fraction of the bar, at the START of the game.
const ZONE_HALF := 0.12
## Smallest the zone's half-width shrinks to (reached at TARGET_LOCKS) — half the start width.
const ZONE_HALF_MIN := ZONE_HALF * 0.5
## Marker sweep speed (bar-fractions per second) and how much it ramps each lock.
const BASE_SPEED := 0.9
const SPEED_RAMP := 1.06
## Seconds a click-feedback line lingers before it has fully faded out.
const CLICK_MARK_FADE := 2.0

var _marker_pos: float = 0.0
var _marker_dir: float = 1.0
var _marker_speed: float = BASE_SPEED
var _locks: int = 0
var _accuracy_sum: float = 0.0
var _running: bool = false
var _flash: float = 0.0       # brief cream highlight after a successful lock, decays in _process
var _miss_flash: float = 0.0  # brief red highlight after a missed click, decays in _process
var _zone_center: float = 0.5  # current center of the gold zone (bar fraction); jumps each lock
## Freeze-burst state. While _freeze_left > 0 the marker and zone hold still, a hit/miss burst
## is drawn, and is_busy() is true so the host pauses its countdown for the duration.
var _freeze_left: float = 0.0
var _freeze_success: bool = false  # true -> draw the white/gold "hit" burst; false -> gray "miss" burst
## Set when the FINAL lock lands: we keep running through that lock's freeze so its success burst
## is visible, then emit completed once the freeze ends (see _on_freeze_ended).
var _finish_after_freeze: bool = false
## Pulsing white lines left where each click landed; each is {pos, age} and fades over
## CLICK_MARK_FADE seconds so the player can see exactly where their taps were perceived.
var _click_marks: Array = []
var _rng := RandomNumberGenerator.new()

var _bar: Control
var _locks_label: Label


func display_name() -> String:
	return "Timing Bar"


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_marker_pos = 0.0
	_marker_dir = 1.0
	_marker_speed = BASE_SPEED
	_locks = 0
	_accuracy_sum = 0.0
	_running = true
	_move_zone()

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


func result_summary() -> String:
	return "Locked %d of %d" % [_locks, TARGET_LOCKS]


## True only during a freeze-burst; the host pauses its countdown so the 0.5s freeze (and its
## animation) is not charged against the player's time.
func is_busy() -> bool:
	return _freeze_left > 0.0


func _process(delta: float) -> void:
	# While frozen: hold the marker and zone exactly where they are, only count the freeze down
	# and redraw so the burst animates. We deliberately do NOT age _flash / _miss_flash / click
	# marks here — they simply pause and resume their decay once the freeze ends, which keeps
	# this branch dead simple.
	if _freeze_left > 0.0:
		_freeze_left = maxf(0.0, _freeze_left - delta)
		if _bar != null:
			_bar.queue_redraw()
		if _freeze_left <= 0.0:
			_on_freeze_ended()
		return
	if not _running:
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	_miss_flash = maxf(0.0, _miss_flash - delta * 4.0)
	# Age the click-feedback lines and drop any that have fully faded.
	for mark in _click_marks:
		mark["age"] += delta
	_click_marks = _click_marks.filter(func(m: Dictionary) -> bool: return m["age"] < CLICK_MARK_FADE)
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
	# Ignore taps during the freeze, or they would reset it and re-score the held marker position
	# (a double count). The player can only lock again once the bar has resumed sweeping.
	if _freeze_left > 0.0:
		return
	# Every LOCK press freezes the bar for a beat so the player can read a hit/miss burst. The
	# success flag (set below, once we know hit vs miss) chooses which burst _draw_bar shows.
	_freeze_left = FREEZE_TIME
	# Drop a fading white line wherever the marker was at the moment of the click — hit or miss —
	# so the player gets clear feedback on exactly where their tap was perceived.
	_click_marks.append({"pos": _marker_pos, "age": 0.0})
	var half := _current_zone_half()
	var distance := absf(_marker_pos - _zone_center)
	if distance > half:
		# Missed the zone: a misfire costs a lock (never below zero) and scores nothing.
		_locks = maxi(0, _locks - 1)
		_miss_flash = 1.0
		_freeze_success = false  # draw the gray drop-shadow "miss" burst during the freeze
		_update_locks_label()
		return

	# Hit: accuracy 1.0 dead-center of the zone, falling to 0 at its (current) edges.
	var accuracy := clampf(1.0 - distance / half, 0.0, 1.0)
	_accuracy_sum += accuracy
	_locks += 1
	_marker_speed *= SPEED_RAMP
	_flash = 1.0
	_freeze_success = true  # draw the white-with-gold-glow "hit" burst during the freeze
	_update_locks_label()
	if _locks >= TARGET_LOCKS:
		# Final lock: keep _running through the freeze so this success burst is visible, then
		# emit completed once the freeze ends (in _on_freeze_ended). The zone does NOT jump.
		_finish_after_freeze = true
		return
	# The zone holds where it was hit during the freeze, then jumps to a fresh spot once the
	# freeze ends (in _on_freeze_ended), so the burst clearly lands on the gold it just caught.


## Called once when a freeze finishes. Resolves whatever that lock set up: end the round on the
## final lock, or jump the zone after a non-final hit. (A miss leaves the zone where it is.)
func _on_freeze_ended() -> void:
	if _finish_after_freeze:
		_running = false
		completed.emit(get_performance())
	elif _freeze_success:
		_move_zone()


## The zone's current half-width: starts at ZONE_HALF and shrinks linearly to ZONE_HALF_MIN
## as successful locks climb toward TARGET_LOCKS, so the target gets steadily harder to hit.
func _current_zone_half() -> float:
	var progress := clampf(float(_locks) / float(TARGET_LOCKS), 0.0, 1.0)
	return lerpf(ZONE_HALF, ZONE_HALF_MIN, progress)


## Pick a new random zone center that keeps the whole zone on the bar (center within one
## half-width of either end), so a freshly placed zone is never clipped off the edge.
func _move_zone() -> void:
	var half := _current_zone_half()
	_zone_center = _rng.randf_range(half, 1.0 - half)


func _update_locks_label() -> void:
	_locks_label.text = "Locks: %d / %d" % [_locks, TARGET_LOCKS]


## Draw the bar: a navy track, the gold target zone at its current (roving, shrinking) spot,
## and the sweeping marker (flashing cream after a hit, red after a missed click).
func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	# Gold target zone at its current center and width.
	var half := _current_zone_half()
	var zone_x := (_zone_center - half) * w
	var zone_w := (half * 2.0) * w
	_bar.draw_rect(Rect2(zone_x, 0, zone_w, h), UiPalette.MUSTARD_GOLD)
	# Click-feedback lines: a white line at each recorded click, pulsing as it fades over
	# CLICK_MARK_FADE seconds (alpha falls with age; the pulse keeps it lively while visible).
	for mark in _click_marks:
		var life := 1.0 - clampf(float(mark["age"]) / CLICK_MARK_FADE, 0.0, 1.0)
		var pulse := 0.55 + 0.45 * absf(sin(float(mark["age"]) * PI * 3.0))
		var line_color := Color(1.0, 1.0, 1.0, life * pulse)
		var cx := float(mark["pos"]) * w
		_bar.draw_rect(Rect2(cx - 2.0, 0, 4.0, h), line_color)
	var mx := _marker_pos * w
	if _freeze_left > 0.0:
		# Frozen burst: a noticeably THICKER marker line, drawn instead of the normal one.
		if _freeze_success:
			# Hit: a white core wrapped in a layered gold glow — two wider, low-alpha gold
			# rectangles behind the solid white line so the glow fades outward from the core.
			_bar.draw_rect(Rect2(mx - 22.0, 0, 44.0, h), Color(UiPalette.MUSTARD_GOLD, 0.18))
			_bar.draw_rect(Rect2(mx - 13.0, 0, 26.0, h), Color(UiPalette.MUSTARD_GOLD, 0.40))
			_bar.draw_rect(Rect2(mx - 8.0, 0, 16.0, h), Color.WHITE)
		else:
			# Miss: a gray core with a wider near-black low-alpha rect behind it for a drop shadow.
			_bar.draw_rect(Rect2(mx - 16.0, 0, 32.0, h), Color(0.0, 0.0, 0.0, 0.45))
			_bar.draw_rect(Rect2(mx - 8.0, 0, 16.0, h), Color(0.55, 0.55, 0.55, 1.0))
	else:
		# Normal marker (a thick vertical bar): cream, briefly brightened after a hit or reddened on a miss.
		var marker_color := UiPalette.CREAM.lightened(_flash * 0.6).lerp(UiPalette.KETCHUP_RED, _miss_flash)
		_bar.draw_rect(Rect2(mx - 5.0, 0, 10.0, h), marker_color)
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
