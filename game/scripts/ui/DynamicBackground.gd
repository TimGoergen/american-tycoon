class_name DynamicBackground
extends Control

## Dynamic scrolling background displaying Earth -> Near Space -> Deep Space progression
## across epochs from multi-panel panoramic assets (ScrollBackground_SetA / SetB).
##
## Each panoramic file contains three vertical panels side-by-side:
##   Column 0: Earth & Sky
##   Column 1: Near Space
##   Column 2: Deep Space
##
## Pacing rules:
## - Tier 1 begins at the bottom-most view of Column 0.
## - Each epoch advance shifts the viewable window upward by 10% of the vertical travel range.
## - After 10 epochs in a column, moving past the top resets to the bottom of the next column.
## - Completing all 3 columns (30 epochs) wraps to Column 0 and randomly picks Set A or Set B.
## - Rendering dynamically scales the column width to the device/container width and shows the exact
##   viewable height required by the device screen.

const SET_A_PATH := "res://art/backgrounds/ScrollBackground_SetA.png"
const SET_B_PATH := "res://art/backgrounds/ScrollBackground_SetB.png"

# Column pixel rectangles (x_offset, width) in source assets excluding the white divider lines
const COL_BOUNDS_A: Array = [
	Vector2(0, 293),    # Left: Earth / Sky
	Vector2(300, 286),  # Middle: Near Space
	Vector2(593, 294),  # Right: Deep Space
]

const COL_BOUNDS_B: Array = [
	Vector2(0, 289),    # Left: Earth / Sky
	Vector2(297, 292),  # Middle: Near Space
	Vector2(598, 289),  # Right: Deep Space
]

const TOTAL_EPOCHS_PER_COLUMN := 10
const TOTAL_EPOCHS_PER_CYCLE := 30
const STEP_FRACTION := 0.10

var _current_set_index: int = 0  # 0 for Set A, 1 for Set B
var _current_tier: int = 1
var _texture_a: Texture2D
var _texture_b: Texture2D


func _init() -> void:
	# Randomly pick between Set A and Set B for this session
	_current_set_index = randi() % 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Sets the active epoch tier and recalculates background positioning.
func set_tier(tier: int) -> void:
	var old_cycle: int = get_cycle_for_tier(_current_tier)
	var new_cycle: int = get_cycle_for_tier(tier)
	if new_cycle != old_cycle:
		# Pick randomly between Set A and Set B on wrapping / cycle change
		_current_set_index = randi() % 2
	_current_tier = tier
	queue_redraw()


## Returns the active texture resource.
func get_active_texture() -> Texture2D:
	if _current_set_index == 0:
		if _texture_a == null and ResourceLoader.exists(SET_A_PATH):
			_texture_a = load(SET_A_PATH)
		return _texture_a
	else:
		if _texture_b == null and ResourceLoader.exists(SET_B_PATH):
			_texture_b = load(SET_B_PATH)
		return _texture_b


## Sets the active set explicitly (0 = Set A, 1 = Set B).
func set_image_set(set_index: int) -> void:
	_current_set_index = clampi(set_index, 0, 1)
	queue_redraw()


func get_image_set() -> int:
	return _current_set_index


func _draw() -> void:
	var tex := get_active_texture()
	if tex == null:
		return
	var tex_size := Vector2(tex.get_width(), tex.get_height())
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var col_bounds := COL_BOUNDS_A if _current_set_index == 0 else COL_BOUNDS_B
	var src_rect := calculate_src_rect(_current_tier, tex_size, col_bounds, size)
	var dst_rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect_region(tex, dst_rect, src_rect)


# ---------------------------------------------------------------------------
# Static Math & Layout Helpers (Headless / Deterministic / Testable)
# ---------------------------------------------------------------------------

## Returns the 0-indexed 30-epoch cycle index for a tier (tier 1..30 = cycle 0, 31..60 = cycle 1, etc.).
static func get_cycle_for_tier(tier: int) -> int:
	var epoch_step: int = max(0, tier - 1)
	return int(epoch_step / TOTAL_EPOCHS_PER_CYCLE)


## Returns column index: 0 = Earth/Sky, 1 = Near Space, 2 = Deep Space.
static func get_column_index_for_tier(tier: int) -> int:
	var epoch_step: int = max(0, tier - 1)
	var step_in_cycle: int = epoch_step % TOTAL_EPOCHS_PER_CYCLE
	return int(step_in_cycle / TOTAL_EPOCHS_PER_COLUMN)


## Returns panel category name for tier.
static func get_panel_name_for_tier(tier: int) -> String:
	match get_column_index_for_tier(tier):
		0: return "Earth & Sky"
		1: return "Near Space"
		2: return "Deep Space"
		_: return "Earth & Sky"


## Returns vertical upward scroll progress [0.0 (bottom) to 0.9 (top-most step)] for the tier.
static func get_vertical_progress_for_tier(tier: int) -> float:
	var epoch_step: int = max(0, tier - 1)
	var step_in_cycle: int = epoch_step % TOTAL_EPOCHS_PER_CYCLE
	var step_in_col: int = step_in_cycle % TOTAL_EPOCHS_PER_COLUMN
	return float(step_in_col) * STEP_FRACTION


## Calculates the exact source Rect2 in texture coordinates for a given tier and screen size.
static func calculate_src_rect(
	tier: int,
	tex_size: Vector2,
	col_bounds: Array,
	viewport_size: Vector2
) -> Rect2:
	var col_index := get_column_index_for_tier(tier)
	var progress := get_vertical_progress_for_tier(tier)
	
	var col_bound: Vector2 = col_bounds[col_index]
	var col_x: float = col_bound.x
	var col_w: float = col_bound.y
	var tex_h: float = tex_size.y
	
	var view_w: float = maxf(1.0, viewport_size.x)
	var view_h: float = maxf(1.0, viewport_size.y)
	
	# Horizontal scale factor mapping column width to screen width
	var scale: float = view_w / col_w
	
	# Viewable height in texture pixel units
	var h_view: float = view_h / scale
	
	# Total scrollable vertical distance in texture pixels
	var d_tex: float = maxf(0.0, tex_h - h_view)
	
	# Top-Y offset: progress=0.0 is at bottom (y_top = d_tex), progress=0.9 is near top
	var y_top: float = (1.0 - progress) * d_tex
	
	return Rect2(col_x, y_top, col_w, minf(h_view, tex_h - y_top))
