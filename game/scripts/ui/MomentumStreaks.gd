class_name MomentumStreaks
extends Control

# Bright neon-salmon LASER SHOTS for the MAX-Rush-Momentum effect (Tim 2026-07-14): short straight
# horizontal lines, each no longer than 10% of the bar width, flying fast and dead-straight from left
# to right, spawning at RANDOM heights — a deliberate contrast to the side-to-side sway of the gold
# carbonation. Each shot fades from a bright leading head to a transparent tail so its direction
# reads. Drawn ONLY within the bar's FILLED region (reading the parent Range's ratio, like
# GoldBubbles), so they never spill past the progress into the empty track. Cheap: a few line segments.

## How many shots exist at once, spread across the bar. Kept small so it reads as a sparse volley.
const SHOT_COUNT := 5
## Each shot's length as a fraction of the (full) bar width — Tim: "no more than 10%."
const SHOT_LEN_FRAC := 0.10
## Very fast, constant px/s — the point is that these outrun the gentle gold drift.
const SPEED_PX := 1000.0
## Thickness of the bright HEAD, in px — 3x the old 2.8 line (Tim 2026-07-14). The tail tapers from
## this down to a point, so each shot is a thick head with a thinning trail.
const HEAD_WIDTH := 8.4
## Left/right inset so shots stay off the framed meter's border (matches the fill's 3px inset).
const EDGE_INSET := 3.0
## Keep spawn heights off the very top/bottom edge.
const HEIGHT_INSET_FRAC := 0.10
const MIN_FILLED_WIDTH_PX := 10.0
## On respawn a shot restarts this far (at most) off the left edge, chosen at random, so shots
## re-enter at randomized times rather than a fixed cadence. As a fraction of the bar width.
const SPAWN_DELAY_FRAC := 1.5

## The shot tint — the host sets this to UiPalette.NEON_SALMON.
var color := Color("#FF7A6B")

var _explicit_fraction := -1.0
var _head: Array[float] = []  # each shot's head x within the track (px)
var _y: Array[float] = []     # each shot's height (px) — re-rolled random on every respawn
var _seeded := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SHOT_COUNT):
		_head.append(0.0)
		_y.append(0.0)


## Feed the fill fraction (0–1) for a bar this node can't read on its own; else it reads the parent.
func set_fill_fraction(fraction: float) -> void:
	_explicit_fraction = clampf(fraction, 0.0, 1.0)


func _current_fraction() -> float:
	if _explicit_fraction >= 0.0:
		return _explicit_fraction
	var bar := get_parent() as Range
	return clampf(bar.ratio, 0.0, 1.0) if bar != null else 1.0


## A fresh random height within the bar (kept off the very top/bottom edge).
func _random_height() -> float:
	return lerpf(HEIGHT_INSET_FRAC, 1.0 - HEIGHT_INSET_FRAC, randf()) * size.y


func _process(delta: float) -> void:
	if not visible:
		return
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	if track < MIN_FILLED_WIDTH_PX:
		return
	var shot_len := track * SHOT_LEN_FRAC
	if not _seeded:
		# Scatter the initial heads (some on-screen, some waiting off the left edge) at random heights.
		for i in range(SHOT_COUNT):
			_head[i] = randf() * (track + track * SPAWN_DELAY_FRAC) - track * SPAWN_DELAY_FRAC
			_y[i] = _random_height()
		_seeded = true
	for i in range(SHOT_COUNT):
		_head[i] += SPEED_PX * delta
		if _head[i] - shot_len > track:
			# The whole shot has cleared the right edge — respawn it a RANDOM distance off the left
			# edge (a randomized re-entry delay) at a new random height (Tim 2026-07-14).
			_head[i] = -randf() * track * SPAWN_DELAY_FRAC
			_y[i] = _random_height()
	queue_redraw()


func _draw() -> void:
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	if track < MIN_FILLED_WIDTH_PX:
		return
	var filled := _current_fraction() * track
	if filled < MIN_FILLED_WIDTH_PX:
		return
	var shot_len := track * SHOT_LEN_FRAC
	var fill_right := EDGE_INSET + filled
	for i in range(SHOT_COUNT):
		var head_x := EDGE_INSET + _head[i]
		var tail_x := head_x - shot_len
		# Clip the shot to the FILLED region so it never draws past the progress into the empty track.
		var left_x := maxf(tail_x, EDGE_INSET)
		var right_x := minf(head_x, fill_right)
		if right_x <= left_x:
			continue
		var y := _y[i]
		# Both the WIDTH and the alpha taper from ~0 at the tail (left) to full at the head (right),
		# so each shot is a thick bright head with a thinning, fading trail. Drawn as a filled quad
		# (a line can't vary its width), with per-vertex color for the fade.
		var frac_left := clampf((left_x - tail_x) / shot_len, 0.0, 1.0)
		var frac_right := clampf((right_x - tail_x) / shot_len, 0.0, 1.0)
		var half_left := HEAD_WIDTH * 0.5 * frac_left
		var half_right := HEAD_WIDTH * 0.5 * frac_right
		var col_left := color
		col_left.a = color.a * frac_left
		var col_right := color
		col_right.a = color.a * frac_right
		draw_polygon(
			PackedVector2Array([
				Vector2(left_x, y - half_left), Vector2(right_x, y - half_right),
				Vector2(right_x, y + half_right), Vector2(left_x, y + half_left)]),
			PackedColorArray([col_left, col_right, col_right, col_left]))
