class_name GoldBubbles
extends Control

# A crowd of small gold bubbles swirling through a progress bar's FILLED region, like
# carbonation in a liquid that is flowing to the right (Tim, 2026-07-03; reworked
# 2026-07-05: many small varied bubbles that swirl, not one blob). Their base drift is
# tied to the bar's own fill speed — the liquid flows at the same rate the fill edge
# moves, individual bubbles a little over or under it — with a floor so a still bar
# keeps gently fizzing.
#
# NOT for gold-filled bars (the wage and TURBO meters): gold bubbles are invisible on a
# gold fill and only read where they brush the frame (Tim, 2026-07-05).
#
# Usage — one line per bar:
#   bar.add_child(GoldBubbles.new())          # bar is a ProgressBar (or any Range)
# The node fills its parent's rect and reads the parent's value/ratio each frame.
# For a bar drawn by hand (not a Range node), add it over the bar's rect and feed
# the fraction yourself via set_fill_fraction().
#
# Deliberately cheap: a handful of circles per bar, no Particles2D nodes, no
# textures — many rows can be on screen at once on the property ladder.
#
# Each bubble's position along the fill is stored NORMALIZED (0–1 of the filled width),
# not in pixels: when the fill is a narrow sliver the bubbles stay evenly spread through
# it instead of being clamped into one overlapping clump (the "single gold thing" bug on
# the economy bar). Every bubble also gets its own size, speed, opacity, and swirl phase
# from a fixed golden-ratio sequence, so the crowd never marches in lockstep yet looks
# identical across identical bars.

## The full bubble crowd. Narrow fills show a subset (see BUBBLE_SPACING_PX).
const BUBBLE_COUNT := 12
## One bubble becomes active per this many pixels of filled width (min 2), so a sliver
## of fill fizzes with a couple of distinct bubbles instead of a crammed dozen.
const BUBBLE_SPACING_PX := 22.0
## Bubble radius range in pixels — small, like carbonation, not coins.
const RADIUS_MIN := 1.6
const RADIUS_MAX := 3.4
## Bubble drift = this × the bar's fill speed. 1.0 = the liquid flows WITH the bar
## (Tim, 2026-07-05: 2× read as too fast — and the per-bubble spread below already
## puts individual bubbles both above and below the target)…
const SPEED_VS_BAR := 1.0
## …with a floor (px/s) so a full or barely-moving bar still fizzes. Art knob —
## 0.0 restores strictly "frozen when the bar is frozen".
const MIN_DRIFT_PX_PER_SEC := 14.0
## Per-bubble drift variation: each bubble moves at base speed × (1 ± this), so the
## crowd spreads out over time instead of traveling as one body.
const SPEED_SPREAD := 0.45
## The swirl: two stacked sine waves on the vertical axis (a slow deep one and a faster
## shallow one, at incommensurate rates) plus a small horizontal wobble — the combined
## path traces loose loops, reading as bubbles tumbling in moving liquid.
const SWAY_FRACTION := 0.26        # primary vertical amplitude, × bar height
const SWAY_HZ := 0.55
const SWIRL_FRACTION := 0.12       # secondary vertical amplitude, × bar height
const SWIRL_HZ := 1.7
const WOBBLE_PX := 2.5             # horizontal wobble amplitude
const WOBBLE_HZ := 1.1
## Bubble color: bright gold; each bubble's own alpha varies around this (see _alpha_of).
const BUBBLE_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const ALPHA_MIN := 0.45
const ALPHA_MAX := 0.85
## Smoothing time constant for the measured fill speed, so one jumpy frame (a rush,
## a snap-back) doesn't make the bubbles lurch.
const SPEED_SMOOTH_TAU := 0.35
## Hide bubbles entirely when the filled region is narrower than this.
const MIN_FILLED_WIDTH_PX := 14.0

## Left/right inset of the fill inside the bar, in pixels (framed meters draw their
## fill inset by the frame's border width). 0 for plain bars.
var edge_inset := 0.0

## Explicitly-fed fill fraction for hand-drawn bars; < 0 means "not fed — read the
## parent Range instead" (the normal ProgressBar case).
var _explicit_fraction := -1.0

var _time := 0.0
var _last_fraction := 0.0
var _smoothed_speed_px := 0.0  # measured fill-edge speed, px/s, smoothed
## Per-bubble position along the filled region, NORMALIZED 0–1 (see the class header).
var _bubble_pos: Array[float] = []


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset, not set_anchors_preset: the latter only moves the
	# anchors and leaves the offsets compensating for the parent's size at call time, so
	# this control ended up with a ZERO-HEIGHT rect hugging the bar's top — the bubbles
	# drew as specks pinned to the top edge (Tim, 2026-07-05; proven by sim/BubbleProbe).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(BUBBLE_COUNT):
		_bubble_pos.append(float(i) / float(BUBBLE_COUNT))


## A stable per-bubble pseudo-random in [0,1) — the golden-ratio (Weyl) sequence, offset
## per use (`salt`) so a bubble's size, speed, phase, and alpha are independent of each
## other. Fixed, not random: identical bars look identical, and redraws never reshuffle.
func _variant(index: int, salt: float) -> float:
	return fmod(float(index) * 0.61803 + salt, 1.0)


func _alpha_of(index: int) -> float:
	return lerpf(ALPHA_MIN, ALPHA_MAX, _variant(index, 0.71))


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


## How many bubbles a fill this wide can host without crowding.
func _active_count(filled_width: float) -> int:
	return clampi(int(filled_width / BUBBLE_SPACING_PX), 2, BUBBLE_COUNT)


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

	# Twice the bar's speed (the spec), with a small floor so still bars keep fizzing.
	var base_speed := maxf(_smoothed_speed_px * SPEED_VS_BAR, MIN_DRIFT_PX_PER_SEC)

	var filled_width := fraction * track_width
	if filled_width >= MIN_FILLED_WIDTH_PX:
		for i in range(BUBBLE_COUNT):
			# Each bubble drifts at its own rate around the base, so the crowd spreads
			# out instead of traveling as one body. Positions advance in normalized
			# space: the same px/s reads as a bigger step through a narrower fill.
			var speed_px := base_speed * (1.0 + SPEED_SPREAD * (2.0 * _variant(i, 0.37) - 1.0))
			_bubble_pos[i] = fmod(_bubble_pos[i] + speed_px * delta / filled_width, 1.0)
	queue_redraw()


func _draw() -> void:
	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)
	var filled_width := fraction * track_width
	if filled_width < MIN_FILLED_WIDTH_PX:
		return
	var mid_y := size.y / 2.0
	for i in range(_active_count(filled_width)):
		var radius := lerpf(RADIUS_MIN, RADIUS_MAX, _variant(i, 0.13))
		var phase := _variant(i, 0.53) * TAU
		# Loose looping path: two vertical sines at incommensurate rates + a small
		# horizontal wobble — carbonation tumbling in a current, not beads on a wire.
		var sway := sin(_time * TAU * SWAY_HZ + phase) * size.y * SWAY_FRACTION \
				+ sin(_time * TAU * SWIRL_HZ + phase * 2.0) * size.y * SWIRL_FRACTION
		var wobble := sin(_time * TAU * WOBBLE_HZ + phase * 3.0) * WOBBLE_PX
		# Map the normalized position into the filled region, keeping the circle inside.
		var x := edge_inset + radius + _bubble_pos[i] * (filled_width - radius * 2.0) + wobble
		x = clampf(x, edge_inset + radius, edge_inset + filled_width - radius)
		var color := BUBBLE_COLOR
		color.a = _alpha_of(i)
		draw_circle(Vector2(x, mid_y + sway), radius, color)
