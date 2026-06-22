class_name MinigameScreen
extends ColorRect

# The prestige minigame (GDD §5.5): a quick match-3 played during succession. The
# player's score sets how much of the run's base Legacy they KEEP:
#   legacy_awarded = floor(base_legacy × mult)
# where mult rises from the keep floor (a poor round, score 0) → 1.0 "full" (score ≥
# minigame_full_score) → up to 1.0 + bonus_max "extra-high" (score ≥ minigame_extra_score).
# The extra-high bonus cap (0.25 base) is raised by the Family Reputation Legacy upgrade.
# Skipping / having the minigame off banks the keep floor — opting out is the worst
# result, so the minigame genuinely matters.
#
# Gems are free-positioned nodes on a board layer (not a GridContainer) so the resolution
# can be ANIMATED, and are moved by DRAGGING one toward a neighbor. The board math (and
# the step-by-step resolution script the animation replays) lives in the headless
# MatchThreeBoard; this file is presentation + input only.
#
# Two phases inside the one overlay:
#   PLAY   — the board, a countdown, and a "Legacy kept" spectrum indicator.
#   RESULT — the final multiplier and the kept/boosted Legacy, then Continue.

## Emitted when the round ends (Continue tapped, or Skip). `multiplier` is applied to the
## run's Legacy by Main; `opt_out` is true if the player asked to auto-skip the minigame
## on future prestiges (Main persists it to GameState.ui_minigame_enabled).
signal finished(multiplier: float, opt_out: bool)

const Board = preload("res://scripts/core/MatchThreeBoard.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const GEM_COLORS := 5

## A square cell, generously sized for thumb taps and low-vision readability (§1b),
## plus the gap between cells. PITCH is the cell-to-cell pixel stride.
const CELL_SIZE := 96
const GAP := 8
const PITCH := CELL_SIZE + GAP

## How far a press must move before it counts as a drag-swap (rather than a stray tap).
const DRAG_THRESHOLD := CELL_SIZE * 0.4

# Animation durations (seconds). Tuned short so a full cascade still feels snappy.
const SWAP_TIME := 0.16
const FLASH_TIME := 0.14
const CLEAR_TIME := 0.18
const FALL_TIME := 0.30

# Each gem id 0..4 gets a distinct color AND a distinct symbol, so gems are told apart
# by shape as well as hue (colour-blind / low-vision friendly — §1b).
const GEM_FILL := [
	UiPalette.KETCHUP_RED, UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL,
	UiPalette.MONEY_GREEN, UiPalette.NAVY,
]
const GEM_SYMBOL := ["$", "★", "●", "▲", "◆"]
const GEM_TEXT := [
	UiPalette.CREAM, UiPalette.NAVY, UiPalette.NAVY, UiPalette.CREAM, UiPalette.CREAM,
]

var _tuning: TuningConfig

var _board
var _base_legacy: int = 0
var _bonus_max: float = 0.25  # max extra-high bonus this run (from Family Reputation)
var _seconds_left: float = 0.0
var _playing: bool = false
var _animating: bool = false  # input is locked while a swap/cascade plays out
var _opt_out: bool = false
var _shown_score: int = 0     # score revealed so far (climbs as each cascade clears)

# Drag-to-swap state.
var _dragging: bool = false
var _drag_row: int = -1
var _drag_col: int = -1
var _drag_press_pos: Vector2 = Vector2.ZERO

# UI nodes.
var _play_view: Control
var _result_view: Control
var _timer_label: Label
var _keep_label: Label
var _keep_bar: Control
var _board_area: Control
## _gem_nodes[row][col] -> the gem Control currently shown at that cell (or null mid-clear).
var _gem_nodes: Array = []
var _result_mult_label: Label
var _result_legacy_label: Label
var _opt_out_check: CheckBox


## Call before adding to the tree.
func setup(tuning: TuningConfig) -> void:
	_tuning = tuning


func _ready() -> void:
	color = Color(UiPalette.INK_NAVY, 0.92)  # near-opaque scrim — the minigame owns the screen
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	center.add_child(panel)

	# Both phase views live stacked in the same panel slot; only one is visible at a time.
	var slot := MarginContainer.new()
	panel.add_child(slot)
	_play_view = _build_play_view()
	slot.add_child(_play_view)
	_result_view = _build_result_view()
	slot.add_child(_result_view)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_play_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)

	var title := _make_label("GROW THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := _make_label(
		"Drag a gem to match 3+. Fill the bar to keep your whole inheritance — overfill for a bonus.",
		UiPalette.FONT_LABEL, UiPalette.NAVY
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	_timer_label = _make_label("0:30", UiPalette.FONT_SUBHEAD, UiPalette.KETCHUP_RED)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_timer_label)

	# The "Legacy kept" readout: a worded amount above a spectrum bar that fills as the
	# score rises (red → gold below full, green at full, teal into the extra-high bonus).
	_keep_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
	_keep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keep_label)

	var board_width := GRID_WIDTH * PITCH - GAP
	_keep_bar = Control.new()
	_keep_bar.custom_minimum_size = Vector2(board_width, 34)
	_keep_bar.draw.connect(_draw_keep_bar)
	column.add_child(_keep_bar)

	# The gem board: a fixed-size canvas of free-positioned gem nodes. clip_contents so
	# gems spawned above the top edge are hidden until they fall into view. Drags are read
	# here via gui_input and mapped to a cell, so individual gems need no input handling.
	_board_area = Control.new()
	_board_area.custom_minimum_size = Vector2(board_width, GRID_HEIGHT * PITCH - GAP)
	_board_area.clip_contents = true
	_board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_area.gui_input.connect(_on_board_input)
	var board_center := CenterContainer.new()
	board_center.add_child(_board_area)
	column.add_child(board_center)

	# Skip: bank the keep floor (the worst result) and leave immediately.
	var skip_button := Button.new()
	skip_button.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(skip_button, false)
	skip_button.text = "SKIP (keep the minimum)"
	skip_button.pressed.connect(_on_skip_pressed)
	column.add_child(skip_button)

	# Opt-out: turn the minigame off for future prestiges (still applies this round).
	_opt_out_check = CheckBox.new()
	_opt_out_check.text = "Skip the minigame on future prestiges"
	_opt_out_check.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	_opt_out_check.add_theme_color_override("font_color", UiPalette.NAVY)
	_opt_out_check.toggled.connect(func(on: bool) -> void: _opt_out = on)
	column.add_child(_opt_out_check)

	return column


func _build_result_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.visible = false

	var heading := _make_label("THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_result_mult_label = _make_label("", UiPalette.FONT_DISPLAY, UiPalette.MUSTARD_GOLD)
	_result_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_mult_label)

	_result_legacy_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
	_result_legacy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_legacy_label)

	var continue_button := Button.new()
	continue_button.custom_minimum_size = Vector2(0, 80)
	UiPalette.style_button(continue_button, true)
	continue_button.text = "CONTINUE"
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)

	return column


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------------------
# Gem nodes
# ---------------------------------------------------------------------------

## Top-left pixel position of cell (row, col) within the board area.
func _cell_pos(row: int, col: int) -> Vector2:
	return Vector2(col * PITCH, row * PITCH)


## Build a gem visual for the given color: a colored, navy-bordered plate with the
## color's symbol centered. Pivot is centered so flash/clear scaling looks right. The
## color id is stored in meta so the drag highlight can rebuild the same plate.
func _make_gem(color_id: int) -> Control:
	var gem := Panel.new()
	gem.size = Vector2(CELL_SIZE, CELL_SIZE)
	gem.pivot_offset = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the board area handles input
	gem.set_meta("color", color_id)

	var label := Label.new()
	label.text = GEM_SYMBOL[color_id]
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	label.add_theme_color_override("font_color", GEM_TEXT[color_id])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.add_child(label)

	_style_gem(gem, false)
	return gem


## (Re)apply a gem's plate: its color fill, with a bold cream border while it's the gem
## being dragged.
func _style_gem(gem: Control, active: bool) -> void:
	var color_id: int = gem.get_meta("color")
	var box := StyleBoxFlat.new()
	box.bg_color = (GEM_FILL[color_id] as Color).lightened(0.25) if active else GEM_FILL[color_id]
	box.set_corner_radius_all(10)
	box.border_color = UiPalette.CREAM if active else UiPalette.INK_NAVY
	box.set_border_width_all(5 if active else 2)
	gem.add_theme_stylebox_override("panel", box)


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

## Start a round. `base_legacy` is the run's pre-minigame Legacy (from the will);
## `bonus_max` is the max extra-high bonus fraction (from the Family Reputation upgrade).
## Main shows this, then reads the `finished` multiplier to bank the kept Legacy.
func start_game(base_legacy: int, bonus_max: float) -> void:
	_base_legacy = base_legacy
	_bonus_max = maxf(0.0, bonus_max)
	_board = Board.new(GRID_WIDTH, GRID_HEIGHT, GEM_COLORS)
	_seconds_left = _tuning.minigame_duration_seconds
	_opt_out = false
	_animating = false
	_dragging = false
	_drag_row = -1
	_drag_col = -1
	_shown_score = 0
	if _opt_out_check != null:
		_opt_out_check.button_pressed = false

	_play_view.visible = true
	_result_view.visible = false
	_build_initial_gems()
	_update_status()

	_playing = true
	visible = true


## Tear down any old gems and lay out a fresh board of gem nodes.
func _build_initial_gems() -> void:
	for child in _board_area.get_children():
		child.queue_free()
	_gem_nodes = []
	for row in range(GRID_HEIGHT):
		var row_nodes: Array = []
		for col in range(GRID_WIDTH):
			var gem := _make_gem(_board.color_at(row, col))
			gem.position = _cell_pos(row, col)
			_board_area.add_child(gem)
			row_nodes.append(gem)
		_gem_nodes.append(row_nodes)


func _process(delta: float) -> void:
	# The clock pauses while a swap/cascade animates, so animation time isn't charged.
	if not _playing or _animating:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "0:%02d" % int(ceil(_seconds_left))
	if _seconds_left <= 0.0:
		_end_round()


# ---------------------------------------------------------------------------
# Input — drag a gem toward a neighbor to swap them
# ---------------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	if not _playing or _animating:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_cancel_drag()
	elif event is InputEventMouseMotion and _dragging:
		_continue_drag(event.position)


func _begin_drag(local: Vector2) -> void:
	var col := int(local.x / PITCH)
	var row := int(local.y / PITCH)
	if row < 0 or row >= GRID_HEIGHT or col < 0 or col >= GRID_WIDTH:
		return
	_dragging = true
	_drag_row = row
	_drag_col = col
	_drag_press_pos = local
	_style_gem(_gem_nodes[row][col], true)


## Once the finger/cursor has moved far enough, swap the held gem with the neighbor in
## the dominant drag direction (the swap itself decides whether it makes a match).
func _continue_drag(local: Vector2) -> void:
	var delta := local - _drag_press_pos
	if delta.length() < DRAG_THRESHOLD:
		return
	var d_col := 0
	var d_row := 0
	if absf(delta.x) > absf(delta.y):
		d_col = 1 if delta.x > 0.0 else -1
	else:
		d_row = 1 if delta.y > 0.0 else -1
	var target_row := _drag_row + d_row
	var target_col := _drag_col + d_col

	_style_gem(_gem_nodes[_drag_row][_drag_col], false)
	var from_row := _drag_row
	var from_col := _drag_col
	_dragging = false
	_drag_row = -1
	_drag_col = -1

	if target_row < 0 or target_row >= GRID_HEIGHT or target_col < 0 or target_col >= GRID_WIDTH:
		return
	var result: Dictionary = _board.resolve_swap(from_row, from_col, target_row, target_col)
	_play_resolution(result)


func _cancel_drag() -> void:
	if _dragging and _drag_row >= 0:
		_style_gem(_gem_nodes[_drag_row][_drag_col], false)
	_dragging = false
	_drag_row = -1
	_drag_col = -1


# ---------------------------------------------------------------------------
# Animation — replay the board's recorded resolution steps
# ---------------------------------------------------------------------------

## Play out a swap result: slide the two gems; if it made no match, slide them back; if
## it did, animate each cascade step (flash → clear → fall + spawn). Input is locked for
## the whole sequence (and the clock is paused, see _process).
func _play_resolution(result: Dictionary) -> void:
	_animating = true

	var a: Array = result["swap"]["a"]
	var b: Array = result["swap"]["b"]
	var node_a: Control = _gem_nodes[a[0]][a[1]]
	var node_b: Control = _gem_nodes[b[0]][b[1]]

	# Slide the two gems past each other.
	var swap_tween := create_tween().set_parallel(true)
	swap_tween.tween_property(node_a, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
	swap_tween.tween_property(node_b, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
	await swap_tween.finished

	if not result["valid"]:
		# No match — slide them back to where they started.
		var undo := create_tween().set_parallel(true)
		undo.tween_property(node_a, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
		undo.tween_property(node_b, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
		await undo.finished
		_animating = false
		return

	# Commit the swap in our node map (the board already swapped its grid internally).
	_gem_nodes[a[0]][a[1]] = node_b
	_gem_nodes[b[0]][b[1]] = node_a

	for step in result["steps"]:
		await _animate_step(step)

	_animating = false


func _animate_step(step: Dictionary) -> void:
	# 1. Flash the matched gems and pop a size badge over each match line, so the player
	#    sees WHAT matched and how big (3, 4, 5…) before it clears.
	for group in step["matches"]:
		_spawn_match_badge(group)
	var flash := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			flash.tween_property(gem, "scale", Vector2(1.25, 1.25), FLASH_TIME)
	await flash.finished

	# 2. Clear: shrink the matched gems to nothing and fade them out, then free them.
	var clear := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			clear.tween_property(gem, "scale", Vector2.ZERO, CLEAR_TIME)
			clear.tween_property(gem, "modulate:a", 0.0, CLEAR_TIME)
	await clear.finished
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			gem.queue_free()
		_gem_nodes[cell[0]][cell[1]] = null

	# Reveal this cascade's points now that its gems are gone (the keep bar climbs).
	_shown_score += step["cleared"].size()
	_update_status()

	# 3. Falls + spawns, all dropping together.
	var drop := create_tween().set_parallel(true)
	_apply_falls(step["falls"], drop)
	_apply_spawns(step["spawns"], drop)
	await drop.finished


## Move surviving gems down into the gaps. Read every source node first, then write the
## targets, so a gem falling into a slot another gem is leaving never clobbers it.
func _apply_falls(falls: Array, drop: Tween) -> void:
	var captured: Array = []  # [target_row, col, node]
	for fall in falls:
		var col: int = fall["col"]
		captured.append([fall["to_r"], col, _gem_nodes[fall["from_r"]][col]])
	for fall in falls:
		_gem_nodes[fall["from_r"]][fall["col"]] = null
	for entry in captured:
		var to_r: int = entry[0]
		var col: int = entry[1]
		var node: Control = entry[2]
		_gem_nodes[to_r][col] = node
		drop.tween_property(node, "position", _cell_pos(to_r, col), FALL_TIME)


## Create the new top gems for each column and drop them in from above the board. They
## start stacked just above the top edge (in their column order) so they slide into the
## emptied top rows.
func _apply_spawns(spawns: Array, drop: Tween) -> void:
	# How many new gems each column gets, so each can start that many rows above the top.
	var per_col: Dictionary = {}
	for spawn in spawns:
		var col: int = spawn["col"]
		per_col[col] = int(per_col.get(col, 0)) + 1
	for spawn in spawns:
		var col: int = spawn["col"]
		var to_r: int = spawn["to_r"]
		var gem := _make_gem(spawn["color"])
		# Start above the board: row (to_r - empty_count) is negative, i.e. off the top.
		gem.position = _cell_pos(to_r - int(per_col[col]), col)
		_board_area.add_child(gem)
		_gem_nodes[to_r][col] = gem
		drop.tween_property(gem, "position", _cell_pos(to_r, col), FALL_TIME)


## Pop a short-lived badge showing a match's size ("3", "4", …) at its center, so the
## player gets a clear read on how big each clear was.
func _spawn_match_badge(group: Array) -> void:
	if group.is_empty():
		return
	var sum := Vector2.ZERO
	for cell in group:
		sum += _cell_pos(cell[0], cell[1])
	var center: Vector2 = sum / float(group.size()) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0

	var badge := _make_label(str(group.size()), UiPalette.FONT_DISPLAY, UiPalette.CREAM)
	badge.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	badge.add_theme_constant_override("outline_size", 6)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = center - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	badge.size = Vector2(CELL_SIZE, CELL_SIZE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_area.add_child(badge)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(badge, "position:y", badge.position.y - 36.0, FLASH_TIME + CLEAR_TIME)
	tween.tween_property(badge, "modulate:a", 0.0, FLASH_TIME + CLEAR_TIME)
	tween.chain().tween_callback(badge.queue_free)


# ---------------------------------------------------------------------------
# The "Legacy kept" indicator
# ---------------------------------------------------------------------------

## Score → keep multiplier. Below minigame_full_score it scales from the keep floor up to
## 1.0 (keep everything); above it, into the extra-high bonus up to 1.0 + bonus_max.
func _multiplier_for_score(score: int) -> float:
	var floor_mult := _tuning.minigame_keep_floor
	var full := maxf(1.0, _tuning.minigame_full_score)
	if score < full:
		return floor_mult + (1.0 - floor_mult) * clampf(float(score) / full, 0.0, 1.0)
	var extra_span := maxf(1.0, _tuning.minigame_extra_score - full)
	var into_extra := clampf((float(score) - full) / extra_span, 0.0, 1.0)
	return 1.0 + _bonus_max * into_extra


## Color for a multiplier: red→gold below full (low→medium), green at full (high), then
## green→teal into the extra-high bonus.
func _keep_color(mult: float) -> Color:
	if mult < 1.0:
		var floor_mult := _tuning.minigame_keep_floor
		var t := clampf((mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult), 0.0, 1.0)
		return UiPalette.KETCHUP_RED.lerp(UiPalette.MUSTARD_GOLD, t)
	var into_extra := clampf((mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)
	return UiPalette.MONEY_GREEN.lerp(UiPalette.ATOMIC_TEAL, into_extra)


func _update_status() -> void:
	var mult := _multiplier_for_score(_shown_score)
	var kept := int(floor(float(_base_legacy) * mult))
	if mult > 1.0:
		var bonus := kept - _base_legacy
		_keep_label.text = "%d Legacy  (+%d bonus)" % [kept, bonus]
		_keep_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
	elif kept >= _base_legacy:
		_keep_label.text = "%d Legacy  (full)" % kept
		_keep_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	else:
		_keep_label.text = "%d of %d Legacy" % [kept, _base_legacy]
		_keep_label.add_theme_color_override("font_color", _keep_color(mult))
	_keep_bar.queue_redraw()


## Draw the spectrum bar: a navy track, a colored fill to the current multiplier, and a
## cream tick at the "full inheritance" (×1.0) mark so the player sees the keep line.
func _draw_keep_bar() -> void:
	var w := _keep_bar.size.x
	var h := _keep_bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var floor_mult := _tuning.minigame_keep_floor
	var span := maxf(0.0001, (1.0 + _bonus_max) - floor_mult)
	var mult := _multiplier_for_score(_shown_score)
	var fill_frac := clampf((mult - floor_mult) / span, 0.0, 1.0)
	var full_x := ((1.0 - floor_mult) / span) * w

	_keep_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	_keep_bar.draw_rect(Rect2(0, 0, fill_frac * w, h), _keep_color(mult))
	# The "full inheritance" line — left of it you're losing Legacy, right of it is bonus.
	_keep_bar.draw_rect(Rect2(full_x - 2.0, 0, 4.0, h), UiPalette.CREAM)
	_keep_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 2.0)


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------

## Time ran out — show the result phase with the final multiplier.
func _end_round() -> void:
	_playing = false
	_show_result(_multiplier_for_score(_board.score))


func _show_result(mult: float) -> void:
	var kept := int(floor(float(_base_legacy) * mult))
	if mult > 1.0:
		var bonus := kept - _base_legacy
		_result_mult_label.text = "+%d%% BONUS" % int(round((mult - 1.0) * 100.0))
		_result_mult_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
		_result_legacy_label.text = "+%d Legacy  (%d base +%d bonus)" % [kept, _base_legacy, bonus]
	elif kept >= _base_legacy:
		_result_mult_label.text = "FULL INHERITANCE"
		_result_mult_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
		_result_legacy_label.text = "+%d Legacy" % kept
	else:
		_result_mult_label.text = "KEPT %d%%" % int(round(mult * 100.0))
		_result_mult_label.add_theme_color_override("font_color", _keep_color(mult))
		_result_legacy_label.text = "+%d Legacy  (of %d)" % [kept, _base_legacy]

	_play_view.visible = false
	_result_view.visible = true
	visible = true


## Skip: bank the keep floor (the worst result), leave immediately. Honors the "skip on
## future prestiges" checkbox if the player ticked it before skipping.
func _on_skip_pressed() -> void:
	_playing = false
	visible = false
	finished.emit(_tuning.minigame_keep_floor, _opt_out)


func _on_continue_pressed() -> void:
	visible = false
	finished.emit(_multiplier_for_score(_board.score), _opt_out)
