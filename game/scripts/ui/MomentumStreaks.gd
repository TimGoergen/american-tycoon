class_name MomentumStreaks
extends Control

# Bright neon-salmon LASER SHOTS for the MAX-Rush-Momentum effect (Tim 2026-07-14): short straight
# horizontal lines, each no longer than 10% of the bar width, flying fast and dead-straight from left
# to right, spawning at RANDOM heights — a deliberate contrast to the side-to-side sway of the gold
# carbonation. Each shot fades from a bright leading head to a transparent tail so its direction
# reads. Deliberately cheap: a handful of gradient line segments, drawn across the WHOLE bar.

## How many shots are in flight at once. With random heights they read as a scattered volley.
const SHOT_COUNT := 12
## Each shot's length as a fraction of the bar width — Tim: "no more than 10%."
const SHOT_LEN_FRAC := 0.10
## Very fast, constant px/s — the point is that these outrun the gentle gold drift.
const SPEED_PX := 1000.0
const LINE_WIDTH := 2.8
## Left/right inset so shots stay off the framed meter's border (matches the fill's 3px inset).
const EDGE_INSET := 3.0
## Keep spawn heights off the very top/bottom edge.
const HEIGHT_INSET_FRAC := 0.10

## The shot tint — the host sets this to UiPalette.NEON_SALMON.
var color := Color("#FF7A6B")

var _head: Array[float] = []  # each shot's head x within the track (px)
var _y: Array[float] = []     # each shot's height (px) — re-rolled random on every respawn
var _seeded := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # so a shot entering/leaving is clipped cleanly to the bar
	for i in range(SHOT_COUNT):
		_head.append(0.0)
		_y.append(0.0)


## A fresh random height within the bar (kept off the very top/bottom edge).
func _random_height() -> float:
	return lerpf(HEIGHT_INSET_FRAC, 1.0 - HEIGHT_INSET_FRAC, randf()) * size.y


func _process(delta: float) -> void:
	if not visible:
		return
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	if track < 8.0:
		return
	var shot_len := track * SHOT_LEN_FRAC
	if not _seeded:
		# Stagger the initial heads across the bar (each at its own random height) so they read as a
		# stream from the first frame rather than all launching together.
		for i in range(SHOT_COUNT):
			_head[i] = (float(i) + 0.5) / float(SHOT_COUNT) * track
			_y[i] = _random_height()
		_seeded = true
	for i in range(SHOT_COUNT):
		_head[i] += SPEED_PX * delta
		if _head[i] - shot_len > track:
			# The whole shot has cleared the right edge — wrap it back to the left (tail off-screen)
			# at a NEW random height for its next pass.
			_head[i] -= track + shot_len
			_y[i] = _random_height()
	queue_redraw()


func _draw() -> void:
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	if track < 8.0:
		return
	var shot_len := track * SHOT_LEN_FRAC
	var tail_color := color
	tail_color.a = 0.0
	for i in range(SHOT_COUNT):
		var head_x := EDGE_INSET + _head[i]
		var tail_x := head_x - shot_len
		var y := _y[i]
		# A laser: bright at the leading (right) head, fading to a transparent tail on the left, so
		# the direction of travel reads. clip_contents trims anything past the bar's edges.
		draw_polyline_colors(
			PackedVector2Array([Vector2(tail_x, y), Vector2(head_x, y)]),
			PackedColorArray([tail_color, color]),
			LINE_WIDTH, true)
