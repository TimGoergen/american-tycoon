class_name GoldBubbles
extends Control

# Small gold "bubble" particles that drift left-to-right across a progress bar's
# FILLED region, with a gentle up-and-down sway — every progress bar in the game
# carries them so the bars read as alive (Tim, 2026-07-03). Their travel speed is
# tied to the bar's own fill speed: bubbles move at twice the rate the fill edge
# does (Tim's spec), so a fast-cycling bar shimmers busily and a slow one drifts.
#
# Usage — one line per bar:
#   bar.add_child(GoldBubbles.new())          # bar is a ProgressBar (or any Range)
# The node fills its parent's rect and reads the parent's value/ratio each frame.
# For a bar drawn by hand (not a Range node), add it over the bar's rect and feed
# the fraction yourself via set_fill_fraction().
#
# Deliberately cheap: a handful of circles per bar, no Particles2D nodes, no
# textures — many rows can be on screen at once on the property ladder.

## How many bubbles ride each bar. Kept tiny for the ladder's dozen simultaneous bars.
const BUBBLE_COUNT := 5
## Bubble radius range in pixels; each bubble picks a size in this band so they
## don't read as a mechanical row of identical dots.
const RADIUS_MIN := 3.0
const RADIUS_MAX := 5.0
## Bubble travel speed = this × the bar's fill speed (Tim's spec: twice the bar).
const SPEED_VS_BAR := 2.0
## Floor drift (px/s) so a bar that is full or barely moving (the TURBO meter at
## rest, the slow economy bar) still shimmers instead of freezing. Art knob —
## set to 0.0 for strictly-spec "frozen when the bar is frozen" behavior.
const MIN_DRIFT_PX_PER_SEC := 14.0
## Vertical sway: amplitude as a fraction of the bar's height, and sway speed (Hz).
const SWAY_FRACTION := 0.22
const SWAY_HZ := 0.9
## Bubble color: bright gold, translucent so it tints rather than covers the fill.
const BUBBLE_COLOR := Color(1.0, 0.85, 0.35, 0.75)
## Smoothing time constant for the measured fill speed, so one jumpy frame (a rush,
## a snap-back) doesn't make the bubbles lurch.
const SPEED_SMOOTH_TAU := 0.35
## Hide bubbles entirely when the filled region is narrower than this — a sliver of
## fill with dots crammed in reads as noise, not life.
const MIN_FILLED_WIDTH_PX := 36.0

## Left/right inset of the fill inside the bar, in pixels. Framed meters (TURBO, the
## wage button) draw their fill inset by the frame's border width — match it here so
## bubbles never ride over the frame. 0 for plain bars.
var edge_inset := 0.0

## Explicitly-fed fill fraction for hand-drawn bars; < 0 means "not fed — read the
## parent Range instead" (the normal ProgressBar case).
var _explicit_fraction := -1.0

var _time := 0.0
var _last_fraction := 0.0
var _smoothed_speed_px := 0.0  # measured fill-edge speed, px/s, smoothed
## Per-bubble state: horizontal position (px) and a phase offset that staggers both
## the sway and the wrap point so the bubbles never march in lockstep.
var _bubble_x: Array[float] = []
var _bubble_phase: Array[float] = []
var _bubble_radius: Array[float] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stagger the bubbles evenly along the bar with fixed (not random) phases, so
	# every bar looks organic but identical rows stay visually consistent.
	for i in range(BUBBLE_COUNT):
		var spread := float(i) / float(BUBBLE_COUNT)
		_bubble_x.append(spread * 200.0)  # provisional; wraps into the live width below
		_bubble_phase.append(spread * TAU)
		_bubble_radius.append(lerpf(RADIUS_MIN, RADIUS_MAX, fmod(spread * 2.61803, 1.0)))


## Feed the fill fraction (0–1) for a bar this node can't read on its own (a bar
## drawn with _draw rather than a Range node). Call every frame alongside the draw.
func set_fill_fraction(fraction: float) -> void:
	_explicit_fraction = clampf(fraction, 0.0, 1.0)


## The bar's current fill fraction: explicit if fed, else the parent Range's ratio.
func _current_fraction() -> float:
	if _explicit_fraction >= 0.0:
		return _explicit_fraction
	var bar := get_parent() as Range
	if bar != null:
		return clampf(bar.ratio, 0.0, 1.0)
	return 0.0


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta

	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)

	# Measure how fast the fill edge is moving (px/s). Only forward motion counts —
	# a cycle-reset snap backward would otherwise read as a huge negative speed.
	var raw_speed_px := maxf(0.0, (fraction - _last_fraction) * track_width / delta)
	_last_fraction = fraction
	# Ease the measurement so the bubble speed is steady, not frame-noisy.
	var blend := 1.0 - exp(-delta / SPEED_SMOOTH_TAU)
	_smoothed_speed_px = lerpf(_smoothed_speed_px, raw_speed_px, blend)

	# Twice the bar's speed (the spec), with a small floor so still bars shimmer.
	var bubble_speed := maxf(_smoothed_speed_px * SPEED_VS_BAR, MIN_DRIFT_PX_PER_SEC)

	var filled_width := fraction * track_width
	if filled_width >= MIN_FILLED_WIDTH_PX:
		for i in range(BUBBLE_COUNT):
			_bubble_x[i] = fmod(_bubble_x[i] + bubble_speed * delta, filled_width)
	queue_redraw()


func _draw() -> void:
	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)
	var filled_width := fraction * track_width
	if filled_width < MIN_FILLED_WIDTH_PX:
		return
	var mid_y := size.y / 2.0
	var sway_amp := size.y * SWAY_FRACTION
	for i in range(BUBBLE_COUNT):
		var radius := _bubble_radius[i]
		# Keep the whole circle inside the filled region horizontally.
		var x := edge_inset + clampf(_bubble_x[i], radius, filled_width - radius)
		var y := mid_y + sin(_time * TAU * SWAY_HZ + _bubble_phase[i]) * sway_amp
		draw_circle(Vector2(x, y), radius, BUBBLE_COLOR)
