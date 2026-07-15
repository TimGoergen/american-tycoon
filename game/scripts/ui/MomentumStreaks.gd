class_name MomentumStreaks
extends Control

# Small bright neon-salmon dots that fly FAST in a STRAIGHT horizontal line, each trailing a fading
# line behind it — a deliberate contrast to the swaying, comet-like gold carbonation (GoldBubbles).
# Shown while a property is being rushed at MAX Rush Momentum, and on the Rush Momentum bar itself
# (Tim 2026-07-14). Draws over the parent bar's FILLED region only, reading the parent Range's ratio
# the same way GoldBubbles does. Deliberately cheap: a handful of dots, each one short polyline.

const MAX_STREAKS := 40
## One streak per this many px of bar width — constant density across any bar size.
const SPACING_PX := 24.0
const HEAD_RADIUS := 2.4
## Very fast, constant px/s — the whole point is that these outrun the gentle gold drift.
const SPEED_PX := 900.0
## The trailing line's length (px) and how many points sample it (fading alpha back to the tail).
const TRAIL_LEN_PX := 54.0
const TRAIL_SAMPLES := 7
const TRAIL_WIDTH_VS_RADIUS := 1.3
const EDGE_INSET := 3.0
const MIN_FILLED_WIDTH_PX := 14.0
## Keep the lanes off the very top/bottom edge so streaks read as flowing inside the fill.
const LANE_INSET_FRAC := 0.14

## The streak tint — the host sets this to UiPalette.NEON_SALMON.
var color := Color("#FF7A6B")

var _explicit_fraction := -1.0
var _pos: Array[float] = []        # x position along the bar (px), per streak
var _lane_frac: Array[float] = []  # fixed vertical lane (0..1 of height), per streak — the straight line
var _seeded := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(MAX_STREAKS):
		_pos.append(0.0)
		# Golden-ratio spread so lanes don't line up into rows.
		_lane_frac.append(lerpf(LANE_INSET_FRAC, 1.0 - LANE_INSET_FRAC, fmod(float(i) * 0.61803, 1.0)))


## Feed the fill fraction (0–1) for a bar this node can't read on its own; else it reads the parent.
func set_fill_fraction(fraction: float) -> void:
	_explicit_fraction = clampf(fraction, 0.0, 1.0)


func _current_fraction() -> float:
	if _explicit_fraction >= 0.0:
		return _explicit_fraction
	var bar := get_parent() as Range
	return clampf(bar.ratio, 0.0, 1.0) if bar != null else 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	if track < MIN_FILLED_WIDTH_PX:
		return
	if not _seeded:
		for i in range(MAX_STREAKS):
			_pos[i] = fmod(float(i) * 0.61803, 1.0) * track
		_seeded = true
	# Constant fast drift, wrapping across the whole bar (only the ones under the fill are drawn).
	for i in range(MAX_STREAKS):
		_pos[i] = fposmod(_pos[i] + SPEED_PX * delta, track)
	queue_redraw()


func _pool_count(track_width: float) -> int:
	return clampi(int(track_width / SPACING_PX), 0, MAX_STREAKS)


func _draw() -> void:
	var fraction := _current_fraction()
	var track := maxf(0.0, size.x - EDGE_INSET * 2.0)
	var filled := fraction * track
	if filled < MIN_FILLED_WIDTH_PX:
		return
	var gap := TRAIL_LEN_PX / float(TRAIL_SAMPLES)
	for i in range(_pool_count(track)):
		if _pos[i] > filled:
			continue
		var y := _lane_frac[i] * size.y
		var head_x := clampf(EDGE_INSET + _pos[i], EDGE_INSET + HEAD_RADIUS, EDGE_INSET + filled - HEAD_RADIUS)
		# The trailing line: points back along the same lane (streaks move left→right, so the trail is
		# to the LEFT), alpha fading to the tail; clipped at the fill's left edge.
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		pts.append(Vector2(head_x, y))
		cols.append(color)
		for s in range(1, TRAIL_SAMPLES + 1):
			var tx := head_x - gap * float(s)
			if tx < EDGE_INSET:
				break
			pts.append(Vector2(tx, y))
			var faded := color
			faded.a = color.a * (1.0 - float(s) / float(TRAIL_SAMPLES + 1))
			cols.append(faded)
		if pts.size() >= 2:
			draw_polyline_colors(pts, cols, HEAD_RADIUS * TRAIL_WIDTH_VS_RADIUS, true)
		# The bright head dot on top of its trail.
		draw_circle(Vector2(head_x, y), HEAD_RADIUS, color, true, -1.0, true)
