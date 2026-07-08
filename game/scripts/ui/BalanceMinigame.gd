class_name BalanceMinigame
extends Minigame

# "Balance the Books" minigame TYPE (GDD §5.5) — REWORKED 2026-07-08 (Tim's call, work
# item 6): vertical, single-input, in the shape of Stardew Valley's fishing minigame.
# The old horizontal two-button version didn't work and lagged.
#
# One vertical track. HOLD anywhere on the play area to lift the marker; release and
# gravity pulls it back down. The gold zone drifts up and down the track on its own;
# keep the marker inside it and the score banks every moment it stays in. Performance
# is banked time-in-zone against the FIXED round length, so it only ever rises (see
# get_performance). It has no natural end — the host's countdown ends the round.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

## Track positions run 0 (bottom) to 1 (top); the drawing flips to screen space.
const ZONE_HALF := 0.11          # half-height of the gold zone (track fraction)
## The single-input physics: holding accelerates the marker UP, gravity pulls it DOWN.
## LIFT beats GRAVITY (or holding forever couldn't climb); the margin between them and
## the damping set the game's tension. All first-pass values — feel-tune on device.
const LIFT_ACCEL := 3.0          # upward push while held (track-fractions / sec^2)
const GRAVITY := 1.5             # downward pull always (track-fractions / sec^2)
const DAMPING := 1.8             # velocity damping per second (keeps it controllable)
## Hitting the track's floor or ceiling bounces the marker back softly rather than
## sticking it there — the Stardew bobber "thunk" that punishes slamming an edge.
const EDGE_BOUNCE := 0.35

# The gold zone wanders: it eases toward a randomly re-rolled target center, so it
# slides smoothly rather than jumping. ZONE_EASE controls how quickly it catches up.
const ZONE_TARGET_CHANGE := 1.8  # seconds between new zone-target re-rolls
const ZONE_EASE := 1.4           # how fast the zone center eases toward its target (per sec)

## The vertical track's on-screen width.
const TRACK_WIDTH := 150.0

var _pos: float = 0.25           # marker position, 0 = bottom (it starts resting low)
var _vel: float = 0.0
var _held: bool = false
var _time_in_zone: float = 0.0
var _total_round_seconds: float = 1.0  # fixed performance denominator (set in begin)
var _zone_center: float = 0.6          # current center of the gold zone (wanders)
var _zone_target: float = 0.6          # center the zone is currently easing toward
var _zone_timer: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _track: Control

# A single accumulated phase drives every continuous pulse (the in-zone marker bounce +
# the zone-boundary warning glow) from _draw_track — per the standing rule, continuous
# pulses run off a phase float, not tweens.
var _pulse_phase: float = 0.0
# The marker's position one frame ago, so _draw_track can stretch a short motion trail
# behind it and the marker stays easy to follow as it moves.
var _prev_pos: float = 0.25


func display_name() -> String:
	return "Balance the Books"


func how_to_play() -> String:
	return "Hold anywhere to lift the marker; let go and it falls. Keep it inside " \
		+ "the drifting gold zone — the books balance every moment it stays in."


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The WHOLE play area is the input (single-input design): this control catches the
	# press/release itself in _gui_input, and every child ignores the mouse.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_running = true
	_pos = 0.25
	_prev_pos = _pos
	_pulse_phase = 0.0
	# Bank time-in-zone against the whole round, so the host's spectrum bar starts empty
	# and only climbs while the marker is in the zone (it never falls back).
	_total_round_seconds = maxf(0.1, tuning.minigame_duration_seconds)

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# AUTOWRAP is load-bearing (see CatchMoneyMinigame): without it the label's min
	# width propagates up and widens the whole card past the screen.
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The vertical track, centered horizontally, taking all the leftover height.
	_track = Control.new()
	_track.custom_minimum_size = Vector2(TRACK_WIDTH, 0)
	_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)

	var hint := Label.new()
	hint.text = "HOLD to lift  ·  RELEASE to drop"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	hint.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(intro)
	column.add_child(_track)
	column.add_child(hint)
	add_child(column)


## The single input: press anywhere = lift, release = drop. Touch arrives as Godot's
## emulated mouse (the first finger), which is all a modal minigame needs.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_held = click.pressed


func get_performance() -> float:
	# Fixed denominator (the round length), not elapsed time, so the meter rises
	# monotonically from empty. Staying in the zone the whole round reaches ~1.0.
	# NOTE: this is the NORMAL-mode reward metric; Challenge Mode uses get_score().
	return clampf(_time_in_zone / _total_round_seconds, 0.0, 1.0)


func get_score() -> int:
	# Challenge Mode's raw score: total whole seconds spent IN the gold zone this run.
	# _time_in_zone only ever grows, so this is cumulative and non-decreasing as the
	# host samples it live; in an endless run it just keeps climbing.
	return int(_time_in_zone)


func result_summary() -> String:
	return "Balanced %d%% of the time" % int(round(get_performance() * 100.0))


func _process(delta: float) -> void:
	if not _running:
		return

	# Advance the shared pulse clock (in-zone bounce + boundary warning glow).
	_pulse_phase += delta

	# Slide the gold zone: re-roll a new target center now and then, and ease the live
	# center toward it each frame so the zone glides smoothly instead of snapping.
	# Targets stay fully on the track so the whole zone is always reachable.
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_target = _rng.randf_range(ZONE_HALF, 1.0 - ZONE_HALF)
		_zone_timer = ZONE_TARGET_CHANGE
	_zone_center += (_zone_target - _zone_center) * minf(1.0, ZONE_EASE * delta)
	_zone_center = clampf(_zone_center, ZONE_HALF, 1.0 - ZONE_HALF)

	# The bobber physics: lift while held, gravity always, damped so it stays readable.
	var accel := (LIFT_ACCEL if _held else 0.0) - GRAVITY
	_vel += accel * delta
	_vel *= maxf(0.0, 1.0 - DAMPING * delta)
	_prev_pos = _pos
	_pos += _vel * delta
	# Soft bounce off the floor and ceiling — slamming an edge costs the momentum.
	if _pos <= 0.0:
		_pos = 0.0
		_vel = absf(_vel) * EDGE_BOUNCE
	elif _pos >= 1.0:
		_pos = 1.0
		_vel = -absf(_vel) * EDGE_BOUNCE

	if absf(_pos - _zone_center) <= ZONE_HALF:
		_time_in_zone += delta

	if _track != null:
		_track.queue_redraw()


## Track-space (0 bottom … 1 top) to screen y within the track control.
func _to_screen_y(track_value: float) -> float:
	return (1.0 - track_value) * _track.size.y


func _draw_track() -> void:
	var w := _track.size.x
	var h := _track.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_track.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)

	# How close the marker sits to the edge of the gold zone: 0 = dead center, 1 = at
	# the edge. Drives the boundary warning glow so the zone "lights up" before the
	# marker actually falls out.
	var edge_proximity := clampf(absf(_pos - _zone_center) / ZONE_HALF, 0.0, 1.0)
	var in_zone := edge_proximity < 1.0

	# The gold zone body, drawn at its live (wandering) center so it always matches the
	# _process hit test. Screen y comes from the zone's TOP edge (center + half, flipped).
	var zone_y := _to_screen_y(_zone_center + ZONE_HALF)
	var zone_h := (ZONE_HALF * 2.0) * h
	_track.draw_rect(Rect2(0, zone_y, w, zone_h), UiPalette.MUSTARD_GOLD)

	# Boundary warning: the zone's top/bottom edges brighten toward white (and thicken)
	# as the marker nears them, pulsing on the shared phase — an early "about to fall
	# out" cue rather than only the marker flipping red at the last instant.
	var pulse := 0.5 + 0.5 * sin(_pulse_phase * 9.0)
	var edge_glow := edge_proximity * (0.55 + 0.45 * pulse)
	var edge_color := UiPalette.MUSTARD_GOLD.lerp(Color.WHITE, edge_glow)
	var edge_thickness := 3.0 + 6.0 * edge_proximity
	_track.draw_rect(Rect2(0, zone_y, w, edge_thickness), edge_color)
	_track.draw_rect(Rect2(0, zone_y + zone_h - edge_thickness, w, edge_thickness), edge_color)

	# Marker: a horizontal band — green in-zone, red out — with a drop shadow + motion
	# trail so it tracks easily, gently bouncing (size pulse) while safely in the zone.
	# Out of the zone it holds steady red so "you're out" reads as a hard state.
	var marker_color := UiPalette.MONEY_GREEN if in_zone else UiPalette.KETCHUP_RED
	var bounce := (0.5 + 0.5 * sin(_pulse_phase * 7.0)) if in_zone else 0.0
	var marker_h := 24.0 * (1.0 + 0.18 * bounce)
	var marker_w := w * (0.86 + 0.14 * bounce)
	var marker_y := _to_screen_y(_pos)
	var marker_left := (w - marker_w) * 0.5

	# Motion trail: a translucent band stretched from the marker's previous spot to its
	# current one, so a fast rise or fall leaves a readable streak.
	var trail_color := marker_color
	trail_color.a = 0.35
	var trail_top := minf(_to_screen_y(_prev_pos), marker_y) - marker_h * 0.5
	var trail_bottom := maxf(_to_screen_y(_prev_pos), marker_y) + marker_h * 0.5
	_track.draw_rect(Rect2(marker_left, trail_top, marker_w, trail_bottom - trail_top), trail_color)

	# Drop shadow, offset down-right, then the body and a bright center line so the
	# marker reads crisp and high-contrast at arm's length.
	_track.draw_rect(Rect2(marker_left + 3.0, marker_y - marker_h * 0.5 + 3.0, marker_w, marker_h), Color(0, 0, 0, 0.35))
	_track.draw_rect(Rect2(marker_left, marker_y - marker_h * 0.5, marker_w, marker_h), marker_color)
	_track.draw_rect(Rect2(marker_left, marker_y - 2.0, marker_w, 4.0), marker_color.lerp(Color.WHITE, 0.6))

	_track.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
