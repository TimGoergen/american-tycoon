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
# COVERAGE MODEL (Tim, 2026-07-11): the bubbles are spread across the WHOLE BAR (a fixed pixel
# coordinate space, 0..track_width), drifting at the constant tier speed, and we only DRAW the ones
# currently under the fill. So the fill can never "outrun" them and leave the right side empty, and
# they never pile up at the left edge — when the fill grows, bubbles already sitting in that region
# (just not yet drawn) appear instantly, at constant density across the entire width. Each bubble
# draws its own size, speed, opacity, sway rate/phase, and lane from a fixed per-bubble hash, so the
# crowd never marches in lockstep yet looks identical across identical bars.

## The four excitement tiers a host can put a bar in. Index into tier_speed_px / TIER_AGITATION.
enum Tier { IDLE, FLOWING, RUSHED, FRENZY }

## The STATIC bubble drift speed (px/s) for each tier — the whole speed model. A `static var`
## (not const) so Main can overwrite it from the carb_tier_* tuning knobs once at startup, letting
## the ladder be tuned live (the panel reloads the scene on Apply, re-running that setup). Every
## GoldBubbles instance shares this one global ladder. Defaults are the first-pass feel values.
static var tier_speed_px: Array[float] = [20.0, 50.0, 150.0, 200.0]

## The STATIC agitation level (0–1) for each tier: how busy the liquid looks (bubble count boost,
## churn wobble, faster sway, comet-tail suppression). IDLE is calm; FRENZY is fully whipped up.
const TIER_AGITATION := [0.0, 0.15, 0.55, 1.0]

## The position pool: bubbles spread across the WHOLE bar. Sized to cover the widest bar at the
## densest (agitated) setting — track_width / BUBBLE_SPACING_PX × (1 + EXCITED_DENSITY_BOOST). Only
## the ones under the fill are drawn, so the actual drawn count still scales with the FILL.
const MAX_BUBBLE_COUNT := 64
## One bubble per this many pixels of BAR width — the constant density. (Was per filled-width; now
## the crowd is laid across the whole bar and clipped to the fill, so density stays constant.)
const BUBBLE_SPACING_PX := 16.0
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
## Sample count cut 20->12 with a wider gap (same ~tail length) for perf — the tail path is the
## carbonation hot cost (Tim, 2026-07-11). Falloff retuned so the fade still spans the shorter tail.
const TRACER_COUNT := 12
const TRACER_GAP_PX := 5.0
const TRACER_ALPHA_FALLOFF := 0.79
const TRACER_WIDTH_VS_RADIUS := 1.4
## Hide bubbles entirely when the filled region is narrower than this.
const MIN_FILLED_WIDTH_PX := 14.0

## Liquid shading over the filled region: top/bottom edges darken, the center line brightens,
## like light through a tube of liquid. Four vertical-gradient bands.
## Higher contrast (Tim, 2026-07-11): darker top/bottom edges, brighter center line.
const LIQUID_EDGE_DARKEN_ALPHA := 0.30
const LIQUID_CENTER_BRIGHT_ALPHA := 0.20

# --- Agitation visuals (apply in proportion to the eased agitation level) ---------------------
const EXCITED_DENSITY_BOOST := 0.5      # +50% crowd at full agitation
const EXCITED_SWAY_HZ_BOOST := 0.45     # sway rates run up to this much faster
## Horizontal churn wobble (px) at full agitation — sized to stay visible inside the fast flow.
const EXCITED_WOBBLE_PX := 7.0
const EXCITED_WOBBLE_HZ := 2.3
## At full agitation the per-bubble speed spread's LOWER bound drops to this, so the crowd is a
## chaotic mix of crawlers and streakers rather than a uniform stream.
const EXCITED_SPREAD_LOWER := 0.25
## Comet-tail visibility at full agitation. 0 = no tails at FRENZY (the tail path is then SKIPPED
## entirely — see _draw — so a rush is a cheap, smooth swarm of dots), which also reads best: frenzy
## is the swarm, calm is the comets (Tim, 2026-07-11).
const EXCITED_TAIL_VISIBILITY := 0.0

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
## Per-bubble position along the filled region, in ABSOLUTE PIXELS from the fill's left edge
## (Tim, 2026-07-11). This USED to be normalized 0–1 and multiplied by filled_width in _draw — but
## that made a WIDENING fill re-map every bubble rightward, adding an on-screen velocity that rode
## the fill speed (so the movement still swung with the bar and reacted to rush, defeating the whole
## point of static tiers). Pixels advance at a constant px/s regardless of how the fill grows.
var _bubble_pos: Array[float] = []
## Positions are seeded (spread across the fill) on the first frame the fill is wide enough, since
## filled_width isn't known at _ready.
var _pos_seeded := false
## The slow-bar speed-spread ceiling, cached each _process so _draw can recompute a bubble's own
## speed when laying its tracer path.
var _upper_mult := 1.0 + SPEED_SPREAD

# Per-bubble TRAITS, all derived from the fixed _variant hash and therefore CONSTANT for the life of
# the node. Cached once in _ready so the hot draw path (many bubbles × up to TRACER_COUNT tail
# samples × many bars, every frame) doesn't re-hash them with sines each time — the main carbonation
# perf cost (Tim, 2026-07-11). Only the time-varying sway/wobble sines are computed per frame.
var _c_radius: Array[float] = []      # bubble radius (px)
var _c_alpha: Array[float] = []       # head opacity
var _c_phase: Array[float] = []       # sway/wobble phase (radians)
var _c_sway_hz: Array[float] = []     # base sway rate (agitation boost applied at draw time)
var _c_sway_frac: Array[float] = []   # sway amplitude, × bar height
var _c_lane_frac: Array[float] = []   # resting lane offset, × bar height
var _c_speed_var: Array[float] = []   # position in the per-bubble speed-spread range


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset: the anchors-only variant leaves a zero-height rect hugging
	# the bar's top, drawing the bubbles as specks pinned to the top edge (Tim, 2026-07-05).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Placeholder positions (seeded to a golden-ratio spread across the bar on the first valid frame,
	# see _process) and the per-bubble trait cache (fixed for the node's life — see above).
	for i in range(MAX_BUBBLE_COUNT):
		_bubble_pos.append(0.0)
		_c_radius.append(lerpf(RADIUS_MIN, RADIUS_MAX, _variant(i, 0.13)))
		_c_alpha.append(lerpf(ALPHA_MIN, ALPHA_MAX, _variant(i, 0.71)))
		_c_phase.append(_variant(i, 0.53) * TAU)
		_c_sway_hz.append(lerpf(SWAY_HZ_MIN, SWAY_HZ_MAX, _variant(i, 0.29)))
		_c_sway_frac.append(lerpf(SWAY_FRACTION_MIN, SWAY_FRACTION_MAX, _variant(i, 0.83)))
		_c_lane_frac.append((_variant(i, 0.91) * 2.0 - 1.0) * LANE_OFFSET_FRACTION)
		_c_speed_var.append(_variant(i, 0.37))


## A stable per-bubble pseudo-random in [0,1), hashed from (index, salt) — fixed, not random, so
## identical bars look identical and redraws never reshuffle. A hash (not a shared sequence offset)
## so a bubble's phase/speed/size are independent of its start position (else the crowd rolls as
## one coherent wave — Tim, 2026-07-06).
func _variant(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 127.1 + salt * 311.7) * 43758.5453, 1.0)


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


## How many bubbles to lay across the WHOLE bar: constant density (1 / BUBBLE_SPACING_PX per px of
## bar), scaled by density_scale and the agitation boost. Only the ones under the fill are drawn (see
## _draw), so the DRAWN count still scales with the fill while the density stays constant. Capped at
## the pool size.
func _pool_count(track_width: float) -> int:
	var density := density_scale * (1.0 + EXCITED_DENSITY_BOOST * _agitation)
	return clampi(int(track_width / BUBBLE_SPACING_PX * density), 2, MAX_BUBBLE_COUNT)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta

	var track_width := maxf(0.0, size.x - edge_inset * 2.0)

	# Set the base speed and agitation from the current TIER's static values — the entire speed model.
	# By DEFAULT the change is INSTANT (tier_ease_tau 0): the tier's look is fully on the moment the
	# state changes, so a held rush is CONSTANT from press to release with NO accel/decel ramp at the
	# edges — the "edge burst" that the frenzy pass spent so long killing (Tim, 2026-07-11). A nonzero
	# tier_ease_tau eases the transition instead, if some smoothing is ever wanted.
	var t := clampi(tier, 0, tier_speed_px.size() - 1)
	if tier_ease_tau <= 0.001:
		_base_speed_px = tier_speed_px[t]
		_agitation = float(TIER_AGITATION[t])
	else:
		var blend := 1.0 - exp(-delta / tier_ease_tau)
		_base_speed_px = lerpf(_base_speed_px, tier_speed_px[t], blend)
		_agitation = lerpf(_agitation, float(TIER_AGITATION[t]), blend)

	# How close this tier is to a crawl: 1.0 at/under the reference, fading to 0 as it speeds up.
	# Widens the per-bubble speed range on slow tiers so they don't read as one uniform speed.
	var slowness := clampf(SLOW_SPEED_REFERENCE_PX / maxf(1.0, _base_speed_px), 0.0, 1.0)
	_upper_mult = lerpf(1.0 + SPEED_SPREAD, SLOW_UPPER_MULT, slowness)

	if track_width >= MIN_FILLED_WIDTH_PX:
		if not _pos_seeded:
			# Spread the crowd evenly across the WHOLE bar (in pixels) once its width is known, so a
			# bubble sits ready at every part of the bar and appears the instant the fill reaches it.
			for i in range(MAX_BUBBLE_COUNT):
				_bubble_pos[i] = fmod(float(i) * 0.61803, 1.0) * track_width
			_pos_seeded = true
		for i in range(MAX_BUBBLE_COUNT):
			# Advance at a CONSTANT pixel speed — the tier speed — wrapping across the whole bar. Only
			# the bubbles under the fill are drawn (see _draw), so the fill can't outrun them and the
			# right side is never empty. fposmod (not fmod) so a reversed flow wraps cleanly.
			var step := _bubble_speed_px(i) * delta
			if flow_reversed:
				step = -step
			_bubble_pos[i] = fposmod(_bubble_pos[i] + step, track_width)
	queue_redraw()


## One bubble's own drift speed (px/s), between the lower bound and the slow-tier-aware upper bound.
## Shared by the position advance and the tracer path so they always agree. Agitation WIDENS the
## spread downward (EXCITED_SPREAD_LOWER): a whipped-up crowd mixes crawlers with streakers.
func _bubble_speed_px(index: int) -> float:
	var lower := lerpf(1.0 - SPEED_SPREAD, EXCITED_SPREAD_LOWER, _agitation)
	return _base_speed_px * lerpf(lower, _upper_mult, _c_speed_var[index])


func _draw() -> void:
	var fraction := _current_fraction()
	var track_width := maxf(0.0, size.x - edge_inset * 2.0)
	var filled_width := fraction * track_width
	if filled_width < MIN_FILLED_WIDTH_PX:
		return
	_draw_liquid_shading(filled_width)
	for i in range(_pool_count(track_width)):
		# The crowd is spread across the WHOLE bar; only draw the ones currently under the fill, so
		# coverage is instant and even across the fill however fast it grew (see the header).
		if _bubble_pos[i] > filled_width:
			continue
		var radius := _c_radius[i]
		var head := _bubble_point(i, radius, filled_width, 0.0)
		# Only the head clamps into the fill; tail samples that fall outside are dropped (a clamped
		# sample would pile up at the edge rather than trail behind).
		head.x = clampf(head.x, edge_inset + radius, edge_inset + filled_width - radius)
		var head_alpha := _c_alpha[i]

		# Tail (drawn under the head): ONE antialiased polyline back along the bubble's own path.
		# SKIPPED ENTIRELY while agitated — the 20-sample tail path is the per-bubble hot cost, so a
		# whipped-up FRENZY (tail_visibility ~0) is a cheap swarm of tail-less dots that moves smoothly
		# on device, which also matches "frenzy is the swarm, calm is the comets" (Tim, 2026-07-11 perf).
		var tail_visibility := lerpf(1.0, EXCITED_TAIL_VISIBILITY, _agitation)
		if tail_visibility > 0.02:
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
			if tail_points.size() >= 2:
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
	# All per-bubble traits are cached (see _ready); only the two time-varying sines are per frame.
	var phase := _c_phase[index]
	var sway_hz := _c_sway_hz[index] * (1.0 + EXCITED_SWAY_HZ_BOOST * _agitation)
	var sway := sin(at_time * TAU * sway_hz + phase) * size.y * _c_sway_frac[index]
	var lane := _c_lane_frac[index] * size.y
	# The agitation wobble: horizontal churn scaled purely by the eased agitation.
	var wobble := sin(at_time * TAU * EXCITED_WOBBLE_HZ + phase * 3.0) \
			* EXCITED_WOBBLE_PX * _agitation
	# The pixel position along the fill, rolled back along the drift — backward is rightward when
	# reversed. NOT clamped here (the head clamps in _draw; tail samples are dropped). `filled_width`
	# and `radius` no longer scale the position — the head clamp keeps it inside the fill.
	var rollback := _bubble_speed_px(index) * seconds_ago
	if flow_reversed:
		rollback = -rollback
	var drift_px := _bubble_pos[index] - rollback
	var x := edge_inset + drift_px + wobble
	return Vector2(x, size.y / 2.0 + lane + sway)
