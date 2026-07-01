class_name BalanceMinigame
extends Minigame

# "Balance" minigame TYPE (GDD §5.5) — a sustained-control game (the "balance" idea from
# Tim's vacation notes, done without a physics engine). A marker drifts left/right under a
# wandering force; hold LEFT / RIGHT to counter it and keep it inside the gold zone, which
# itself slides slowly back and forth so the player has to keep following it. Performance is
# banked time-in-zone against the FIXED round length, so it only ever rises (see
# get_performance). It has no natural end — the host's countdown ends the round.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

const ZONE_HALF := 0.13          # half-width of the gold zone (bar fraction)
const NUDGE_ACCEL := 1.7         # how hard a held button pushes (bar-fractions / sec^2)
# Direction for this pass: "slightly harder / confirm" (Tim, 2026-06-29). Nudged 0.9 -> 1.0 so the
# wander pushes a touch harder and the round feels controllable-but-tense rather than floaty.
# UN-PLAYTESTED first pass — confirm on-device; drop back toward 0.9 if it feels twitchy.
const DRIFT_MAX := 1.0           # magnitude of the wandering drift force
const DRIFT_CHANGE := 1.1        # seconds between drift re-rolls
const DAMPING := 2.4             # velocity damping per second (keeps it controllable)

# The gold zone wanders: it eases toward a randomly re-rolled target center, so it slides
# smoothly rather than jumping. ZONE_EASE controls how quickly it catches its target.
const ZONE_TARGET_CHANGE := 1.8  # seconds between new zone-target re-rolls
const ZONE_EASE := 1.5           # how fast the zone center eases toward its target (per sec)

var _pos: float = 0.5
var _vel: float = 0.0
var _drift: float = 0.0
var _drift_timer: float = 0.0
var _time_in_zone: float = 0.0
var _total_round_seconds: float = 1.0  # fixed performance denominator (set in begin)
var _zone_center: float = 0.5          # current center of the gold zone (wanders over time)
var _zone_target: float = 0.5          # center the zone is currently easing toward
var _zone_timer: float = 0.0
var _left_held: bool = false
var _right_held: bool = false
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _bar: Control

# Polish-pass juice state (Tim, 2026-06-29). A single accumulated phase drives every continuous
# pulse (the in-zone marker bounce + the zone-boundary warning glow) from _draw_bar, so no idle
# tween is ever created — per the standing rule, continuous pulses run off a phase float, not tweens.
var _pulse_phase: float = 0.0
# The marker's position one frame ago, so _draw_bar can stretch a short motion trail behind it and
# the thin marker stays easy to follow as it slides.
var _prev_pos: float = 0.5
# The arrow buttons, kept as fields so a press can briefly scale them (button_down / button_up).
var _left_button: Button
var _right_button: Button


func display_name() -> String:
	return "Balance the Books"


func how_to_play() -> String:
	return "Hold the arrows to keep the marker in the gold zone."


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	_pos = 0.5
	_prev_pos = 0.5
	_pulse_phase = 0.0
	# Bank time-in-zone against the whole round, so the host's spectrum bar starts empty and
	# only climbs while the marker is in the zone (it never falls back).
	_total_round_seconds = maxf(0.1, tuning.minigame_duration_seconds)

	var intro := Label.new()
	intro.text = how_to_play()
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
	# Each press both registers the hold AND gives the button a quick scale dip, so the control
	# physically "responds" under the thumb (plan §2.5 juice).
	left.button_down.connect(func() -> void: _left_held = true; _pulse_button(left, true))
	left.button_up.connect(func() -> void: _left_held = false; _pulse_button(left, false))
	_left_button = left

	var right := Button.new()
	right.text = "►"
	right.custom_minimum_size = Vector2(0, 130)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPalette.style_button(right, false)
	right.button_down.connect(func() -> void: _right_held = true; _pulse_button(right, true))
	right.button_up.connect(func() -> void: _right_held = false; _pulse_button(right, false))
	_right_button = right

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
	# Fixed denominator (the round length), not elapsed time, so the meter rises monotonically
	# from empty. Holding the marker in the zone for the whole round reaches ~1.0.
	# NOTE: this is the NORMAL-mode reward metric; Challenge Mode ignores it and uses get_score()
	# instead. The clamp to 1.0 is harmless in Challenge Mode (the host doesn't read it there).
	return clampf(_time_in_zone / _total_round_seconds, 0.0, 1.0)


func get_score() -> int:
	# Challenge Mode's raw score: total whole seconds the marker has spent IN the gold zone this run.
	# _time_in_zone only ever grows (see _process, which adds delta only while in-zone), so this is
	# cumulative and non-decreasing as the host samples it live. Unlike get_performance() it is NOT
	# normalized against the round length — in an endless Challenge run there is no fixed length, so
	# the score simply keeps climbing the longer the player keeps the marker balanced.
	return int(_time_in_zone)


func result_summary() -> String:
	return "In the zone %d%% of the time" % int(round(get_performance() * 100.0))


func _process(delta: float) -> void:
	if not _running:
		return

	# Advance the shared pulse clock that drives the in-zone bounce and the boundary warning glow.
	_pulse_phase += delta

	# Re-roll the wandering drift periodically.
	_drift_timer -= delta
	if _drift_timer <= 0.0:
		_drift = _rng.randf_range(-DRIFT_MAX, DRIFT_MAX)
		_drift_timer = DRIFT_CHANGE

	# Slide the gold zone: re-roll a new target center now and then, and ease the live center
	# toward it each frame so the zone glides smoothly instead of snapping. Targets stay fully
	# on the bar so the whole zone is always reachable.
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_target = _rng.randf_range(ZONE_HALF, 1.0 - ZONE_HALF)
		_zone_timer = ZONE_TARGET_CHANGE
	_zone_center += (_zone_target - _zone_center) * minf(1.0, ZONE_EASE * delta)
	_zone_center = clampf(_zone_center, ZONE_HALF, 1.0 - ZONE_HALF)

	var nudge := 0.0
	if _left_held:
		nudge -= NUDGE_ACCEL
	if _right_held:
		nudge += NUDGE_ACCEL

	_vel += (_drift + nudge) * delta
	_vel *= maxf(0.0, 1.0 - DAMPING * delta)  # damp toward rest so it stays controllable
	_prev_pos = _pos  # remember last frame's spot so _draw_bar can streak a trail behind the marker
	_pos += _vel * delta
	if _pos <= 0.0:
		_pos = 0.0
		_vel = 0.0
	elif _pos >= 1.0:
		_pos = 1.0
		_vel = 0.0

	if absf(_pos - _zone_center) <= ZONE_HALF:
		_time_in_zone += delta

	if _bar != null:
		_bar.queue_redraw()


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)

	# How close the marker sits to the edge of the gold zone: 0 = dead center, 1 = right at the edge.
	# Drives the boundary warning glow so the zone "lights up" before the marker actually falls out.
	var edge_proximity := clampf(absf(_pos - _zone_center) / ZONE_HALF, 0.0, 1.0)
	var in_zone := edge_proximity < 1.0

	# The gold zone body, drawn at its live (wandering) center so it matches the _process hit test.
	var zone_x := (_zone_center - ZONE_HALF) * w
	var zone_w := (ZONE_HALF * 2.0) * w
	_bar.draw_rect(Rect2(zone_x, 0, zone_w, h), UiPalette.MUSTARD_GOLD)

	# Boundary warning: the two zone edges brighten toward white (and thicken) as the marker nears
	# them, pulsing on the shared phase, so the player gets an early "about to fall out" cue rather
	# than only the marker flipping red at the last instant.
	var pulse := 0.5 + 0.5 * sin(_pulse_phase * 9.0)
	var edge_glow := edge_proximity * (0.55 + 0.45 * pulse)
	var edge_color := UiPalette.MUSTARD_GOLD.lerp(Color.WHITE, edge_glow)
	var edge_thickness := 3.0 + 6.0 * edge_proximity
	_bar.draw_rect(Rect2(zone_x, 0, edge_thickness, h), edge_color)
	_bar.draw_rect(Rect2(zone_x + zone_w - edge_thickness, 0, edge_thickness, h), edge_color)

	# Marker: green in-zone, red out. It is bigger than the old thin 14px sliver and carries a drop
	# shadow + motion trail so it tracks easily, and gently bounces (width/height pulse) while it is
	# safely in the zone — out of the zone it holds a steady red so "you're out" reads as a hard state.
	var marker_color := UiPalette.MONEY_GREEN if in_zone else UiPalette.KETCHUP_RED
	var bounce := (0.5 + 0.5 * sin(_pulse_phase * 7.0)) if in_zone else 0.0
	var marker_w := 24.0 * (1.0 + 0.18 * bounce)
	var marker_h := h * (0.86 + 0.14 * bounce)
	var marker_x := _pos * w
	var marker_top := (h - marker_h) * 0.5

	# Motion trail: a translucent band stretched from the marker's previous spot to its current one,
	# so a fast slide leaves a readable streak instead of the eye losing the thin bar.
	var trail_color := marker_color
	trail_color.a = 0.35
	var trail_left := minf(_prev_pos, _pos) * w - marker_w * 0.5
	var trail_right := maxf(_prev_pos, _pos) * w + marker_w * 0.5
	_bar.draw_rect(Rect2(trail_left, marker_top, trail_right - trail_left, marker_h), trail_color)

	# Drop shadow, offset down-right behind the marker so it lifts off the dark bar.
	_bar.draw_rect(Rect2(marker_x - marker_w * 0.5 + 3.0, marker_top + 3.0, marker_w, marker_h), Color(0, 0, 0, 0.35))

	# The marker body, plus a bright center line so it reads crisp and high-contrast at arm's length.
	_bar.draw_rect(Rect2(marker_x - marker_w * 0.5, marker_top, marker_w, marker_h), marker_color)
	_bar.draw_rect(Rect2(marker_x - 2.0, marker_top, 4.0, marker_h), marker_color.lerp(Color.WHITE, 0.6))

	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)


## Briefly scale an arrow button on press and back on release, so the control responds physically
## under the thumb. Each call is a short, self-completing tween (it ends on its own), so this does
## not leak a continuous tween. Pivot is set to the button's center so it scales in place.
func _pulse_button(button: Button, pressed: bool) -> void:
	if button == null:
		return
	button.pivot_offset = button.size / 2.0
	var target := Vector2(0.94, 0.94) if pressed else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(button, "scale", target, 0.08).set_trans(Tween.TRANS_QUAD)
