class_name GoldBubbles
extends Control

# A crowd of small gold bubbles swirling through a progress bar's FILLED region, like
# carbonation in a liquid that is flowing to the right (Tim, 2026-07-03; reworked
# 2026-07-05: many small varied bubbles that swirl, not one blob). Their base drift is
# tied to the bar's own fill speed — the liquid flows at the same rate the fill edge
# moves, individual bubbles a little over or under it — with a floor so a still bar
# keeps gently fizzing.
#
# PLACEMENT RULE (Tim, 2026-07-05): carbonation is the visual cue that something is
# happening AUTOMATICALLY — a value accruing on its own — never a response to the
# player's own events. So the property cycle bars, economy bar, and TURBO meter carry
# it, while the wage clock-in meter (which only moves because the player taps) does not.
# On gold-filled bars use a DARK gold `bubble_color`, or the bubbles vanish into the fill.
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
# the economy bar). Every bubble also gets its own size, speed, opacity, and sway rate/phase
# from a fixed golden-ratio sequence, so the crowd never marches in lockstep yet looks
# identical across identical bars.

## The full bubble crowd. Narrow fills show a subset (see BUBBLE_SPACING_PX).
const BUBBLE_COUNT := 15  # +25% (Tim, 2026-07-05)
## One bubble becomes active per this many pixels of filled width (min 2), so a sliver
## of fill fizzes with a couple of distinct bubbles instead of a crammed dozen.
const BUBBLE_SPACING_PX := 22.0
## Bubble radius range in pixels — small, like carbonation, not coins.
## Enlarged 5% at the small end, 15% at the large end (Tim, 2026-07-05).
const RADIUS_MIN := 1.7
const RADIUS_MAX := 3.9
## Bubble drift = this × the bar's fill speed. 1.0 = the liquid flows WITH the bar
## (Tim, 2026-07-05: 2× read as too fast — and the per-bubble spread below already
## puts individual bubbles both above and below the target)…
const SPEED_VS_BAR := 1.0
## …with a floor (px/s) so a full or barely-moving bar still fizzes. Art knob —
## 0.0 restores strictly "frozen when the bar is frozen".
const MIN_DRIFT_PX_PER_SEC := 14.0
## Per-bubble drift variation: each bubble moves at base speed × a factor between
## (1 − SPEED_SPREAD) and an upper limit, so the crowd spreads out over time instead of
## traveling as one body. The UPPER limit widens as the bar slows (Tim, 2026-07-05): at
## a fast bar's pace ±45% is plenty of visible variety, but near the idle-drift floor
## the absolute px/s differences it produces are too small to read — everything looks
## like one speed — so a crawling bar lets its quickest bubbles run up to
## SLOW_UPPER_MULT × the base instead.
const SPEED_SPREAD := 0.45
const SLOW_UPPER_MULT := 4.5  # raised from 3.0 (Tim, 2026-07-05)
## The sway: ONE smooth sine per bubble across the bar's height. Earlier versions stacked
## a second faster sine plus a horizontal wobble on top for a "tumbling" look, but the
## extra waves superimposed small jitters on the main back-and-forth and read as awkward,
## not liquid (Tim, 2026-07-06). Variety now comes from each bubble's own rate and phase,
## not from a busier path.
const SWAY_FRACTION := 0.30        # vertical amplitude, × bar height
const SWAY_HZ_MIN := 0.40          # each bubble sways at its own fixed rate in this range
const SWAY_HZ_MAX := 0.70
## Default bubble color: bright gold (see the `bubble_color` property for per-bar tints —
## a GOLD-filled bar wants DARK gold bubbles instead, Tim 2026-07-05). Each bubble's own
## alpha varies around it (see _alpha_of).
const DEFAULT_GOLD := Color(1.0, 0.85, 0.35, 1.0)
const ALPHA_MIN := 0.45
const ALPHA_MAX := 0.85
## Tracers: each bubble trails a few fading, shrinking ghosts of itself sampled a moment
## back along its own path (Tim, 2026-07-05) — a comet tail in the liquid's flow.
const TRACER_COUNT := 4
const TRACER_SPACING_SEC := 0.05   # how far apart (in time) the ghosts sample the path
const TRACER_RADIUS_FALLOFF := 0.8 # each ghost's radius vs the one ahead of it
const TRACER_ALPHA_FALLOFF := 0.5  # each ghost's alpha vs the one ahead of it
## Smoothing time constant for the measured fill speed, so one jumpy frame (a rush,
## a snap-back) doesn't make the bubbles lurch.
const SPEED_SMOOTH_TAU := 0.35
## Hide bubbles entirely when the filled region is narrower than this.
const MIN_FILLED_WIDTH_PX := 14.0

## Left/right inset of the fill inside the bar, in pixels (framed meters draw their
## fill inset by the frame's border width). 0 for plain bars.
var edge_inset := 0.0

## The bubble tint. Bright gold by default; bars whose FILL is itself gold set this to a
## dark gold so the bubbles still read (Tim, 2026-07-05 — the TURBO meter swaps it live
## between its charging-gold and burning-red states).
var bubble_color := DEFAULT_GOLD:
	set(value):
		if value != bubble_color:
			bubble_color = value
			queue_redraw()

## Explicitly-fed fill fraction for hand-drawn bars; < 0 means "not fed — read the
## parent Range instead" (the normal ProgressBar case).
var _explicit_fraction := -1.0

var _time := 0.0
var _last_fraction := 0.0
var _smoothed_speed_px := 0.0  # measured fill-edge speed, px/s, smoothed
## Per-bubble position along the filled region, NORMALIZED 0–1 (see the class header).
var _bubble_pos: Array[float] = []
## The crowd's base drift and slow-bar speed ceiling, cached each _process so _draw can
## recompute any bubble's own speed when laying its tracer ghosts back along its path.
var _base_speed_px := MIN_DRIFT_PX_PER_SEC
var _upper_mult := 1.0 + SPEED_SPREAD


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset, not set_anchors_preset: the latter only moves the
	# anchors and leaves the offsets compensating for the parent's size at call time, so
	# this control ended up with a ZERO-HEIGHT rect hugging the bar's top — the bubbles
	# drew as specks pinned to the top edge (Tim, 2026-07-05; proven by sim/BubbleProbe).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Starting positions come from the golden-ratio sequence, NOT even i/COUNT spacing:
	# narrow fills draw only the first N bubbles, and with even spacing those N all sat
	# in the first N/12th of the fill — a clump that a slow bar took ages to shake out
	# (Tim, 2026-07-05). A Weyl sequence is evenly spread for EVERY prefix, so whatever
	# subset is active starts well distributed through the fill.
	for i in range(BUBBLE_COUNT):
		_bubble_pos.append(_variant(i, 0.0))


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

	# The bar's own speed, with a small floor so still bars keep fizzing.
	_base_speed_px = maxf(_smoothed_speed_px * SPEED_VS_BAR, MIN_DRIFT_PX_PER_SEC)

	# How close the bar is to a crawl: 1.0 at (or below) the idle-drift floor, fading to
	# 0.0 as the bar speeds up. Widens the per-bubble speed range on slow bars (see the
	# SPEED_SPREAD / SLOW_UPPER_MULT comment).
	var slowness := clampf(MIN_DRIFT_PX_PER_SEC / _base_speed_px, 0.0, 1.0)
	_upper_mult = lerpf(1.0 + SPEED_SPREAD, SLOW_UPPER_MULT, slowness)

	var filled_width := fraction * track_width
	if filled_width >= MIN_FILLED_WIDTH_PX:
		for i in range(BUBBLE_COUNT):
			# Each bubble drifts at its own rate between the lower bound and the (speed-
			# dependent) upper bound, so the crowd spreads out instead of traveling as one
			# body. Positions advance in normalized space: the same px/s reads as a bigger
			# step through a narrower fill.
			_bubble_pos[i] = fmod(_bubble_pos[i] + _bubble_speed_px(i) * delta / filled_width, 1.0)
	queue_redraw()


## One bubble's own drift speed (px/s), between the lower bound and the slow-bar-aware
## upper bound. Shared by the position advance and the tracer path so they always agree.
func _bubble_speed_px(index: int) -> float:
	return _base_speed_px * lerpf(1.0 - SPEED_SPREAD, _upper_mult, _variant(index, 0.37))


func _draw() -> void:
	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)
	var filled_width := fraction * track_width
	if filled_width < MIN_FILLED_WIDTH_PX:
		return
	for i in range(_active_count(filled_width)):
		var radius := lerpf(RADIUS_MIN, RADIUS_MAX, _variant(i, 0.13))
		var head := _bubble_point(i, radius, filled_width, 0.0)
		# Only the head clamps into the fill; ghosts that fall outside are dropped instead
		# (a clamped ghost would pile up at the edge rather than trail behind).
		head.x = clampf(head.x, edge_inset + radius, edge_inset + filled_width - radius)
		var head_alpha := _alpha_of(i)

		# Tracers first (so the head draws over them): fading, shrinking ghosts sampled a
		# moment back along the bubble's own path — the wake it just swirled through.
		var ghost_radius := radius
		var ghost_alpha := head_alpha
		for ghost in range(1, TRACER_COUNT + 1):
			ghost_radius *= TRACER_RADIUS_FALLOFF
			ghost_alpha *= TRACER_ALPHA_FALLOFF
			var point := _bubble_point(i, radius, filled_width, float(ghost) * TRACER_SPACING_SEC)
			if point.x < edge_inset + ghost_radius:
				break  # the wake would poke out of the fill's left edge — stop the tail
			var ghost_color := bubble_color
			ghost_color.a = ghost_alpha
			draw_circle(point, ghost_radius, ghost_color, true, -1.0, true)

		var color := bubble_color
		color.a = head_alpha
		# antialiased = true (the last argument): the bubbles move fractions of a pixel per
		# frame, and without AA a circle only visibly moves when it crosses a whole pixel —
		# the drift and wobble read as discrete hops instead of liquid motion (Tim, 2026-07-06).
		draw_circle(head, radius, color, true, -1.0, true)


## Where bubble `index` sat `seconds_ago` on its path (0.0 = right now): the drift
## position rolled back by its own speed, with the sway/swirl/wobble sines evaluated at
## that earlier time. Analytic, so tracers need no stored position history.
func _bubble_point(index: int, radius: float, filled_width: float, seconds_ago: float) -> Vector2:
	var at_time := _time - seconds_ago
	var phase := _variant(index, 0.53) * TAU
	# One clean sine across the bar's height, at this bubble's own fixed rate and phase.
	# Deliberately NOT a stack of waves — see the SWAY_* comment above.
	var sway_hz := lerpf(SWAY_HZ_MIN, SWAY_HZ_MAX, _variant(index, 0.29))
	var sway := sin(at_time * TAU * sway_hz + phase) * size.y * SWAY_FRACTION
	# Map the normalized position into the filled region, rolled back along the drift.
	# NOT clamped here: the head clamps itself in _draw, while out-of-fill ghosts are
	# dropped by the caller (clamping them would pile the wake up at the fill's edge).
	var drift_px := _bubble_pos[index] * (filled_width - radius * 2.0) \
			- _bubble_speed_px(index) * seconds_ago
	var x := edge_inset + radius + drift_px
	return Vector2(x, size.y / 2.0 + sway)
