class_name GoldBubbles
extends Control

# A crowd of small gold bubbles swirling through a progress bar's FILLED region, like
# carbonation in a flowing liquid — decorative "moving lights" that signal a bar is doing
# something automatically (Tim, 2026-07-03; reworked 2026-07-05 to many small varied bubbles).
#
# SPEED MODEL — TIERS (Tim, 2026-07-10): the bubbles do NOT try to match the bar's fill
# speed. That earlier "flow with the liquid" model needed per-frame speed measurement,
# smoothing, caps, and overrides, and its output SWUNG whenever the fill speed pulsed
# (lap wraps, cycle stop/restart, eased fills) — impossible to tune to look clean. Instead
# every bar just declares an EXCITEMENT TIER, and each tier has a STATIC bubble speed and a
# STATIC agitation level. No calculation from the bar's fill at all; a constant looks
# constant. The host sets `tier` from simple state flags:
#   IDLE     — a still / full / paused bar: a gentle fizz.
#   FLOWING  — a normally cycling property, the economy bar, TURBO charging.
#   RUSHED   — TURBO burning (discharging the frenzy multiplier).
#   FRENZY   — a property with its rush held: the liquid whipped up.
# The per-tier speeds are LIVE TUNING KNOBS (see tier_speed_px, set from TuningConfig by
# Main) so the ladder can be dialed on device. Transitions EASE between tiers so a change
# doesn't snap, but every steady state is exactly the tier's value.
#
# PLACEMENT RULE (Tim, 2026-07-05): carbonation marks a value accruing AUTOMATICALLY, never
# a response to the player's own taps — so property cycle bars, the economy bar, and the
# TURBO meter carry it, while the wage clock-in meter does not. On gold-filled bars use a
# DARK gold `bubble_color` or the bubbles vanish into the fill.
#
# Usage — one line per bar:
#   var b := GoldBubbles.new(); bar.add_child(b); b.tier = GoldBubbles.Tier.FLOWING
# The node fills its parent's rect and reads the parent's value/ratio each frame (for the
# fill WIDTH the bubbles occupy). For a hand-drawn bar, feed the fraction via set_fill_fraction().
#
# Deliberately cheap: a handful of circles per bar, no Particles2D, no textures.
#
# Each bubble's position along the fill is stored NORMALIZED (0–1 of the filled width) so a
# narrow sliver stays evenly spread instead of clumping, and every bubble draws its own size,
# speed, opacity, sway rate/phase, and lane from a fixed per-bubble hash — the crowd never
# marches in lockstep yet looks identical across identical bars.

## The four excitement tiers a host can put a bar in. Index into tier_speed_px / TIER_AGITATION.
enum Tier { IDLE, FLOWING, RUSHED, FRENZY }

## The STATIC bubble drift speed (px/s) for each tier — the whole speed model. A `static var`
## (not const) so Main can overwrite it from the carb_tier_* tuning knobs once at startup, letting
## the ladder be tuned live (the panel reloads the scene on Apply, re-running that setup). Every
## GoldBubbles instance shares this one global ladder. Defaults are the first-pass feel values.
static var tier_speed_px: Array[float] = [16.0, 70.0, 150.0, 220.0]

## The STATIC agitation level (0–1) for each tier: how busy the liquid looks (bubble count boost,
## churn wobble, faster sway, comet-tail suppression). IDLE is calm; FRENZY is fully whipped up.
const TIER_AGITATION := [0.0, 0.15, 0.55, 1.0]

## The full CALM bubble crowd. Narrow fills show a subset (see BUBBLE_SPACING_PX).
const BUBBLE_COUNT := 24
## The position pool is sized for the biggest crowd agitation can ask for
## (BUBBLE_COUNT × (1 + EXCITED_DENSITY_BOOST)) so the boost never indexes past it.
const MAX_BUBBLE_COUNT := 36
## One bubble becomes active per this many pixels of filled width (min 2).
const BUBBLE_SPACING_PX := 13.75
## Bubble radius range in pixels — small, like carbonation, not coins.
const RADIUS_MIN := 1.7
const RADIUS_MAX := 3.9
## Per-bubble drift variation: each bubble moves at the tier speed × a factor between
## (1 − SPEED_SPREAD) and an upper limit, so the crowd spreads out instead of moving as one body.
## The upper limit widens as the tier speed drops (a crawling IDLE bar reads as one speed unless
## its quickest bubbles run well ahead), up to SLOW_UPPER_MULT × the base.
const SPEED_SPREAD := 0.45
const SLOW_UPPER_MULT := 3.0
## Reference speed for the "how slow is this tier" ramp above: at/under this the spread is widest.
const SLOW_SPEED_REFERENCE_PX := 16.0
## The sway: ONE smooth sine per bubble across the bar's height, each at its own rate, phase,
## amplitude, and lane so the crowd reads as many depths, not one path.
const SWAY_FRACTION_MIN := 0.08
const SWAY_FRACTION_MAX := 0.32
const SWAY_HZ_MIN := 0.40
const SWAY_HZ_MAX := 0.70
## Each bubble's resting lane sits up to this far off the bar's center line (× bar height, either side).
const LANE_OFFSET_FRACTION := 0.12
## Default bubble color: bright gold. Bars whose FILL is gold set a dark gold via `bubble_color`.
const DEFAULT_GOLD := Color(1.0, 0.85, 0.35, 1.0)
const ALPHA_MIN := 0.45
const ALPHA_MAX := 0.85
## Tracers: each bubble trails ONE antialiased polyline back along its own path, per-point alpha
## fading out. Samples spaced by DISTANCE (not time) so a slow bar's tail still clears the head.
const TRACER_COUNT := 20
const TRACER_GAP_PX := 3.0
const TRACER_ALPHA_FALLOFF := 0.87
const TRACER_WIDTH_VS_RADIUS := 1.4
## Hide bubbles entirely when the filled region is narrower than this.
const MIN_FILLED_WIDTH_PX := 14.0

## Liquid shading over the filled region: top/bottom edges darken, the center line brightens,
## like light through a tube of liquid. Four vertical-gradient bands.
const LIQUID_EDGE_DARKEN_ALPHA := 0.16
const LIQUID_CENTER_BRIGHT_ALPHA := 0.10

# --- Agitation visuals (apply in proportion to the eased agitation level) ---------------------
const EXCITED_DENSITY_BOOST := 0.5      # +50% crowd at full agitation
const EXCITED_SWAY_HZ_BOOST := 0.45     # sway rates run up to this much faster
## Horizontal churn wobble (px) at full agitation — sized to stay visible inside the fast flow.
const EXCITED_WOBBLE_PX := 7.0
const EXCITED_WOBBLE_HZ := 2.3
## At full agitation the per-bubble speed spread's LOWER bound drops to this, so the crowd is a
## chaotic mix of crawlers and streakers rather than a uniform stream.
const EXCITED_SPREAD_LOWER := 0.25
## Comet-tail visibility at full agitation (0 = suppressed, 1 = full). Curly slow-bubble tails
## read as chaos; partial by default so a whipped-up bar is a swarm, a calm bar is comets.
const EXCITED_TAIL_VISIBILITY := 0.3
## A whipped-up fill keeps at least this many bubbles no matter how narrow, so a fast-wrapping
## rushed bar still shows a churning swarm instead of collapsing to a handful.
const EXCITED_MIN_ACTIVE := 12

## Left/right inset of the fill inside the bar (framed meters inset by their border width).
var edge_inset := 0.0

## The bubble tint. Bright gold by default; gold-filled bars set a dark gold so bubbles read.
var bubble_color := DEFAULT_GOLD:
	set(value):
		if value != bubble_color:
			bubble_color = value
			queue_redraw()

## Explicitly-fed fill fraction for hand-drawn bars; < 0 means "read the parent Range instead".
var _explicit_fraction := -1.0

## Scales the size of the bubble crowd. 1.0 = full; the TURBO meter halves it while charging.
var density_scale := 1.0

## When true the liquid flows right-to-left — for bars that DRAIN (the TURBO meter while burning).
var flow_reversed := false

## The excitement TIER this bar is in (set by the host each frame from its state). Drives the
## static speed and agitation via the tables above; transitions ease (see tier_ease_tau).
var tier: int = Tier.FLOWING

## Ease time constant (seconds) for tier transitions, so speed and agitation ramp between tiers
## rather than snapping. Both the base speed and the agitation level ease at this rate.
var tier_ease_tau := 0.3

var _time := 0.0
## The current eased base drift (px/s) and agitation level (0–1), each easing toward the tier's
## static value. `_base_speed_px` is what the crowd rides; `_agitation` scales the busy visuals.
var _base_speed_px := tier_speed_px[Tier.FLOWING]
var _agitation := 0.0
## Per-bubble position along the filled region, NORMALIZED 0–1.
var _bubble_pos: Array[float] = []
## The slow-bar speed-spread ceiling, cached each _process so _draw can recompute a bubble's own
## speed when laying its tracer path.
var _upper_mult := 1.0 + SPEED_SPREAD


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset: the anchors-only variant leaves a zero-height rect hugging
	# the bar's top, drawing the bubbles as specks pinned to the top edge (Tim, 2026-07-05).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Starting positions from the golden-ratio (Weyl) sequence: evenly spread for EVERY prefix, so
	# whatever subset a narrow fill draws starts well distributed instead of clumped at the left.
	for i in range(MAX_BUBBLE_COUNT):
		_bubble_pos.append(fmod(float(i) * 0.61803, 1.0))


## A stable per-bubble pseudo-random in [0,1), hashed from (index, salt) — fixed, not random, so
## identical bars look identical and redraws never reshuffle. A hash (not a shared sequence offset)
## so a bubble's phase/speed/size are independent of its start position (else the crowd rolls as
## one coherent wave — Tim, 2026-07-06).
func _variant(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 127.1 + salt * 311.7) * 43758.5453, 1.0)


func _alpha_of(index: int) -> float:
	return lerpf(ALPHA_MIN, ALPHA_MAX, _variant(index, 0.71))


## Feed the fill fraction (0–1) for a bar this node can't read on its own (a hand-drawn bar).
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


## How many bubbles a fill this wide can host (scaled by density_scale, boosted while agitated,
## and never below EXCITED_MIN_ACTIVE while agitated however narrow the fill).
func _active_count(filled_width: float) -> int:
	var density := density_scale * (1.0 + EXCITED_DENSITY_BOOST * _agitation)
	var cap := clampi(int(round(BUBBLE_COUNT * density)), 2, MAX_BUBBLE_COUNT)
	var min_active := 2 + int(round((float(EXCITED_MIN_ACTIVE) - 2.0) * _agitation))
	return clampi(int(filled_width / BUBBLE_SPACING_PX * density), mini(min_active, cap), cap)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta

	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)

	# Ease the base speed and agitation toward the current TIER's static values — the entire speed
	# model. No fill measurement; a constant target means a constant steady-state (no swings), and
	# the ease only shapes the brief transition between tiers.
	var blend := 1.0 - exp(-delta / maxf(0.01, tier_ease_tau))
	var t := clampi(tier, 0, tier_speed_px.size() - 1)
	_base_speed_px = lerpf(_base_speed_px, tier_speed_px[t], blend)
	_agitation = lerpf(_agitation, float(TIER_AGITATION[t]), blend)

	# How close this tier is to a crawl: 1.0 at/under the reference, fading to 0 as it speeds up.
	# Widens the per-bubble speed range on slow tiers so they don't read as one uniform speed.
	var slowness := clampf(SLOW_SPEED_REFERENCE_PX / maxf(1.0, _base_speed_px), 0.0, 1.0)
	_upper_mult = lerpf(1.0 + SPEED_SPREAD, SLOW_UPPER_MULT, slowness)

	var filled_width := fraction * track_width
	if filled_width >= MIN_FILLED_WIDTH_PX:
		for i in range(MAX_BUBBLE_COUNT):
			# Advance in NORMALIZED space so the same px/s reads as a bigger step through a narrower
			# fill. fposmod (not fmod) so a reversed flow wraps cleanly from 0 back to 1.
			var step := _bubble_speed_px(i) * delta / filled_width
			if flow_reversed:
				step = -step
			_bubble_pos[i] = fposmod(_bubble_pos[i] + step, 1.0)
	queue_redraw()


## One bubble's own drift speed (px/s), between the lower bound and the slow-tier-aware upper bound.
## Shared by the position advance and the tracer path so they always agree. Agitation WIDENS the
## spread downward (EXCITED_SPREAD_LOWER): a whipped-up crowd mixes crawlers with streakers.
func _bubble_speed_px(index: int) -> float:
	var lower := lerpf(1.0 - SPEED_SPREAD, EXCITED_SPREAD_LOWER, _agitation)
	return _base_speed_px * lerpf(lower, _upper_mult, _variant(index, 0.37))


func _draw() -> void:
	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)
	var filled_width := fraction * track_width
	if filled_width < MIN_FILLED_WIDTH_PX:
		return
	_draw_liquid_shading(filled_width)
	for i in range(_active_count(filled_width)):
		var radius := lerpf(RADIUS_MIN, RADIUS_MAX, _variant(i, 0.13))
		var head := _bubble_point(i, radius, filled_width, 0.0)
		# Only the head clamps into the fill; tail samples that fall outside are dropped (a clamped
		# sample would pile up at the edge rather than trail behind).
		head.x = clampf(head.x, edge_inset + radius, edge_inset + filled_width - radius)
		var head_alpha := _alpha_of(i)

		# Tail first (so the head draws over it): ONE antialiased polyline back along the bubble's
		# own path. Tails are SUPPRESSED while agitated (a tail's curl is inversely proportional to
		# speed, so slow agitated bubbles rendered curlier tails that read as chaos — frenzy is the
		# swarm, calm is the comets, Tim 2026-07-08).
		var tail_visibility := lerpf(1.0, EXCITED_TAIL_VISIBILITY, _agitation)
		var seconds_per_gap := TRACER_GAP_PX / maxf(1.0, _bubble_speed_px(i))
		var tail_width := radius * TRACER_WIDTH_VS_RADIUS
		var tail_points := PackedVector2Array()
		var tail_colors := PackedColorArray()
		var head_point_color := bubble_color
		head_point_color.a = head_alpha * tail_visibility
		tail_points.append(head)
		tail_colors.append(head_point_color)
		var sample_alpha := head_alpha * tail_visibility
		for sample in range(1, TRACER_COUNT + 1):
			sample_alpha *= TRACER_ALPHA_FALLOFF
			var point := _bubble_point(i, radius, filled_width, float(sample) * seconds_per_gap)
			# The wake pokes out of the fill's TRAILING edge — right when reversed, left otherwise.
			if flow_reversed:
				if point.x > edge_inset + filled_width - tail_width / 2.0:
					break
			elif point.x < edge_inset + tail_width / 2.0:
				break
			tail_points.append(point)
			var sample_color := bubble_color
			sample_color.a = sample_alpha
			tail_colors.append(sample_color)
		if tail_points.size() >= 2 and tail_visibility > 0.02:
			draw_polyline_colors(tail_points, tail_colors, tail_width, true)

		var color := bubble_color
		color.a = head_alpha
		# antialiased so the sub-pixel drift reads as motion, not discrete pixel hops.
		draw_circle(head, radius, color, true, -1.0, true)


## Four stacked vertical-gradient bands over the filled region — edges dark, center bright — under
## the bubbles, so they read as floating in lit liquid.
func _draw_liquid_shading(filled_width: float) -> void:
	var left := edge_inset
	var right := edge_inset + filled_width
	var quarter := size.y / 4.0
	var dark := Color(0.0, 0.0, 0.0, LIQUID_EDGE_DARKEN_ALPHA)
	var dark_clear := Color(0.0, 0.0, 0.0, 0.0)
	var bright := Color(1.0, 1.0, 1.0, LIQUID_CENTER_BRIGHT_ALPHA)
	var bright_clear := Color(1.0, 1.0, 1.0, 0.0)
	_draw_vertical_gradient(left, right, 0.0, quarter, dark, dark_clear)
	_draw_vertical_gradient(left, right, quarter, quarter * 2.0, bright_clear, bright)
	_draw_vertical_gradient(left, right, quarter * 2.0, quarter * 3.0, bright, bright_clear)
	_draw_vertical_gradient(left, right, quarter * 3.0, size.y, dark_clear, dark)


## One rectangle whose color blends vertically from `top_color` to `bottom_color`.
func _draw_vertical_gradient(
	left: float, right: float, top: float, bottom: float,
	top_color: Color, bottom_color: Color
) -> void:
	draw_polygon(
		PackedVector2Array([
			Vector2(left, top), Vector2(right, top),
			Vector2(right, bottom), Vector2(left, bottom),
		]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)


## Where bubble `index` sat `seconds_ago` on its path (0.0 = now): the drift position rolled back
## by its own speed, with the sway sine evaluated at that earlier time. Analytic, so tracers need
## no stored history.
func _bubble_point(index: int, radius: float, filled_width: float, seconds_ago: float) -> Vector2:
	var at_time := _time - seconds_ago
	var phase := _variant(index, 0.53) * TAU
	# One clean sine at this bubble's own rate/phase/amplitude around its own lane.
	var sway_hz := lerpf(SWAY_HZ_MIN, SWAY_HZ_MAX, _variant(index, 0.29)) \
			* (1.0 + EXCITED_SWAY_HZ_BOOST * _agitation)
	var sway_fraction := lerpf(SWAY_FRACTION_MIN, SWAY_FRACTION_MAX, _variant(index, 0.83))
	var sway := sin(at_time * TAU * sway_hz + phase) * size.y * sway_fraction
	var lane := (_variant(index, 0.91) * 2.0 - 1.0) * size.y * LANE_OFFSET_FRACTION
	# The agitation wobble: horizontal churn scaled purely by the eased agitation.
	var wobble := sin(at_time * TAU * EXCITED_WOBBLE_HZ + phase * 3.0) \
			* EXCITED_WOBBLE_PX * _agitation
	# Map the normalized position into the filled region, rolled back along the drift — backward is
	# rightward when reversed. NOT clamped here (the head clamps in _draw; tail samples are dropped).
	var rollback := _bubble_speed_px(index) * seconds_ago
	if flow_reversed:
		rollback = -rollback
	var drift_px := _bubble_pos[index] * (filled_width - radius * 2.0) - rollback
	var x := edge_inset + radius + drift_px + wobble
	return Vector2(x, size.y / 2.0 + lane + sway)
