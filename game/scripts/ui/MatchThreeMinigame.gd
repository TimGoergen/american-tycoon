class_name MatchThreeMinigame
extends Minigame

# The match-3 minigame TYPE (GDD §5.5) — the first entry in the minigame library. Drag a
# gem toward a neighbor to swap; matches flash with a size badge, clear, and survivors +
# new gems fall into the gaps (resolution steps replayed from MatchThreeBoard, which a
# board test proves can't desync). Each game sets quotas on one or two required gem types;
# performance comes from meeting those quotas (with a penalty for clearing the wrong type)
# and is credited gem-by-gem as each cascade clears on screen — see get_performance.
#
# This control owns ONLY the board gameplay. The host (MinigameScreen) owns the countdown,
# the spectrum bar, the result, and the multiplier — see Minigame for the contract.

const Board = preload("res://scripts/core/MatchThreeBoard.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const GEM_COLORS := 5

# --- Quota challenge (Tim's minigame v2) -------------------------------------
# Each game randomly picks one or two gem types and assigns each a quota. Clearing the
# required types fills the quota; clearing the WRONG type costs you half as much. Meeting
# every quota earns "full inheritance"; clearing extra required gems beyond quota is the
# stretch goal that pushes into the bonus band.

## How many gem types are required this game (chosen at random within this range).
const MIN_REQUIRED_TYPES := 1
const MAX_REQUIRED_TYPES := 2
## The per-type quota is chosen at random in this range.
const QUOTA_MIN := 6
const QUOTA_MAX := 10
## A cleared wrong-type gem subtracts this fraction of one required clear (Tim: "lose half").
const WRONG_TYPE_PENALTY := 0.5

## Performance the player reaches by exactly meeting every quota. It corresponds to the host's
## "full inheritance" point (1.0x) at default tuning (keep_floor 0.5, bonus 0.25 -> full at
## ~0.67); clearing a second quota's worth of required gems as the stretch goal fills the rest
## of the bar up to 1.0 (the max bonus). Anchored as a constant for readability.
const FULL_QUOTA_PERFORMANCE := 0.67

## A square cell, generously sized for thumb taps and low-vision readability (§1b),
## plus the gap between cells. PITCH is the cell-to-cell pixel stride.
const CELL_SIZE := 96
const GAP := 8
const PITCH := CELL_SIZE + GAP

## How far a press must move before it counts as a drag-swap (rather than a stray tap).
const DRAG_THRESHOLD := CELL_SIZE * 0.4

# Animation durations (seconds).
const SWAP_TIME := 0.16
const FLASH_TIME := 0.14
const CLEAR_TIME := 0.18
const FALL_TIME := 0.30

# Each gem id 0..4 gets a distinct color AND symbol (colour-blind / low-vision friendly).
const GEM_FILL := [
	UiPalette.KETCHUP_RED, UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL,
	UiPalette.MONEY_GREEN, UiPalette.NAVY,
]
const GEM_SYMBOL := ["$", "★", "●", "▲", "◆"]
const GEM_TEXT := [
	UiPalette.CREAM, UiPalette.NAVY, UiPalette.NAVY, UiPalette.CREAM, UiPalette.CREAM,
]

var _board
var _animating: bool = false
var _rng := RandomNumberGenerator.new()

# Quota challenge state.
## color_id -> quota for the required types this game.
var _quotas: Dictionary = {}
## color_id -> how many of that required type have been cleared so far (can exceed the quota:
## the overflow is the stretch goal). Earned incrementally as each cascade clears on screen.
var _required_cleared: Dictionary = {}
## How many WRONG-type gems have been cleared (each costs WRONG_TYPE_PENALTY of one clear).
var _wrong_cleared: int = 0
## color_id -> the "symbol  cleared/quota" Label in the requirement header, refreshed as we go.
var _quota_labels: Dictionary = {}

# Drag-to-swap state.
var _dragging: bool = false
var _drag_row: int = -1
var _drag_col: int = -1
var _drag_press_pos: Vector2 = Vector2.ZERO

var _board_area: Control
## _gem_nodes[row][col] -> the gem Control currently at that cell (or null mid-clear).
var _gem_nodes: Array = []


func display_name() -> String:
	return "Match Three"


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_board = Board.new(GRID_WIDTH, GRID_HEIGHT, GEM_COLORS)
	_choose_quotas()

	var intro := Label.new()
	intro.text = "Clear the required gems to meet each quota. Wrong matches cost you."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# The requirement header sits directly above the grid: each required gem's symbol next to
	# its running "cleared / quota" tally (Tim's minigame v2 quota challenge).
	var requirement_header := _build_requirement_header()

	_board_area = Control.new()
	_board_area.custom_minimum_size = Vector2(GRID_WIDTH * PITCH - GAP, GRID_HEIGHT * PITCH - GAP)
	_board_area.clip_contents = true
	_board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_area.gui_input.connect(_on_board_input)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.add_child(_board_area)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(requirement_header)
	column.add_child(board_center)
	add_child(column)

	_build_initial_gems()


## Pick one or two required gem types and a quota for each, then seed the per-type tallies.
func _choose_quotas() -> void:
	var available: Array = range(GEM_COLORS)
	available.shuffle()
	var count := _rng.randi_range(MIN_REQUIRED_TYPES, MAX_REQUIRED_TYPES)
	for i in range(count):
		var color_id: int = available[i]
		_quotas[color_id] = _rng.randi_range(QUOTA_MIN, QUOTA_MAX)
		_required_cleared[color_id] = 0


## Build the "REQUIRED" header row: one chip per required type showing its colored symbol and a
## live tally Label (refreshed by _update_quota_display as gems clear).
func _build_requirement_header() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)

	for color_id in _quotas:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 8)

		var symbol := Label.new()
		symbol.text = GEM_SYMBOL[color_id]
		symbol.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
		symbol.add_theme_color_override("font_color", GEM_FILL[color_id])
		# A dark outline so a pale gem symbol (e.g. gold) still reads against the cream panel.
		symbol.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
		symbol.add_theme_constant_override("outline_size", 4)
		chip.add_child(symbol)

		var tally := Label.new()
		tally.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
		tally.add_theme_color_override("font_color", UiPalette.NAVY)
		chip.add_child(tally)
		_quota_labels[color_id] = tally

		row.add_child(chip)

	_update_quota_display()
	return row


func get_performance() -> float:
	if _board == null:
		return 0.0
	# Net effort = required gems cleared (capped per type at quota + one quota's worth of stretch)
	# minus the wrong-type penalty. Meeting every quota reaches FULL_QUOTA_PERFORMANCE ("full
	# inheritance"); clearing a full extra quota of required gems fills the rest of the bar.
	var quota_total := 0
	var required_progress := 0.0   # fraction of the combined quota met (0..1)
	var stretch_progress := 0.0    # fraction of the stretch (a second quota's worth) earned (0..1)
	for color_id in _quotas:
		var quota: int = _quotas[color_id]
		quota_total += quota
		var cleared: int = _required_cleared[color_id]
		required_progress += float(mini(cleared, quota))
		stretch_progress += float(clampi(cleared - quota, 0, quota))

	if quota_total <= 0:
		return 0.0
	# The wrong-type penalty eats into the required progress before it is normalized.
	var penalty := WRONG_TYPE_PENALTY * float(_wrong_cleared)
	var net_required := maxf(0.0, required_progress - penalty)
	var required_frac := clampf(net_required / float(quota_total), 0.0, 1.0)
	var stretch_frac := clampf(stretch_progress / float(quota_total), 0.0, 1.0)

	var performance := FULL_QUOTA_PERFORMANCE * required_frac
	performance += (1.0 - FULL_QUOTA_PERFORMANCE) * stretch_frac
	return clampf(performance, 0.0, 1.0)


## Record one cleared gem against the quota challenge: a required type advances its tally
## (overflow counts toward the stretch goal); any other type is a wrong match.
func _credit_cleared_gem(color_id: int) -> void:
	if _quotas.has(color_id):
		_required_cleared[color_id] += 1
	else:
		_wrong_cleared += 1


## Refresh each required type's "cleared / quota" tally (turns green once its quota is met).
func _update_quota_display() -> void:
	for color_id in _quota_labels:
		var quota: int = _quotas[color_id]
		var cleared: int = _required_cleared[color_id]
		var label: Label = _quota_labels[color_id]
		label.text = "%d / %d" % [cleared, quota]
		var met := cleared >= quota
		label.add_theme_color_override("font_color",
				UiPalette.MONEY_GREEN if met else UiPalette.NAVY)


func is_busy() -> bool:
	return _animating


# ---------------------------------------------------------------------------
# Gem nodes
# ---------------------------------------------------------------------------

func _cell_pos(row: int, col: int) -> Vector2:
	return Vector2(col * PITCH, row * PITCH)


func _make_gem(color_id: int) -> Control:
	var gem := Panel.new()
	gem.size = Vector2(CELL_SIZE, CELL_SIZE)
	gem.pivot_offset = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _style_gem(gem: Control, active: bool) -> void:
	var color_id: int = gem.get_meta("color")
	var box := StyleBoxFlat.new()
	box.bg_color = (GEM_FILL[color_id] as Color).lightened(0.25) if active else GEM_FILL[color_id]
	box.set_corner_radius_all(10)
	box.border_color = UiPalette.CREAM if active else UiPalette.INK_NAVY
	box.set_border_width_all(5 if active else 2)
	gem.add_theme_stylebox_override("panel", box)


func _build_initial_gems() -> void:
	_gem_nodes = []
	for row in range(GRID_HEIGHT):
		var row_nodes: Array = []
		for col in range(GRID_WIDTH):
			var gem := _make_gem(_board.color_at(row, col))
			gem.position = _cell_pos(row, col)
			_board_area.add_child(gem)
			row_nodes.append(gem)
		_gem_nodes.append(row_nodes)


# ---------------------------------------------------------------------------
# Input — drag a gem toward a neighbor to swap them
# ---------------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	if _animating:
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

func _play_resolution(result: Dictionary) -> void:
	_animating = true

	var a: Array = result["swap"]["a"]
	var b: Array = result["swap"]["b"]
	var node_a: Control = _gem_nodes[a[0]][a[1]]
	var node_b: Control = _gem_nodes[b[0]][b[1]]

	var swap_tween := create_tween().set_parallel(true)
	swap_tween.tween_property(node_a, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
	swap_tween.tween_property(node_b, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
	await swap_tween.finished

	if not result["valid"]:
		var undo := create_tween().set_parallel(true)
		undo.tween_property(node_a, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
		undo.tween_property(node_b, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
		await undo.finished
		_animating = false
		return

	_gem_nodes[a[0]][a[1]] = node_b
	_gem_nodes[b[0]][b[1]] = node_a

	for step in result["steps"]:
		await _animate_step(step)

	_animating = false


func _animate_step(step: Dictionary) -> void:
	for group in step["matches"]:
		_spawn_match_badge(group)
	var flash := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			flash.tween_property(gem, "scale", Vector2(1.25, 1.25), FLASH_TIME)
	await flash.finished

	var clear := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			clear.tween_property(gem, "scale", Vector2.ZERO, CLEAR_TIME)
			clear.tween_property(gem, "modulate:a", 0.0, CLEAR_TIME)
	await clear.finished
	# Award the cleared gems NOW, as they vanish on screen — not all at once when the move was
	# made. A cascade chain therefore credits its points step by step as each match resolves,
	# and the host's spectrum bar climbs in time with the animation (Tim's minigame v2).
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			_credit_cleared_gem(int(gem.get_meta("color")))
			gem.queue_free()
		_gem_nodes[cell[0]][cell[1]] = null
	_update_quota_display()

	var drop := create_tween().set_parallel(true)
	_apply_falls(step["falls"], drop)
	_apply_spawns(step["spawns"], drop)
	await drop.finished


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


func _apply_spawns(spawns: Array, drop: Tween) -> void:
	var per_col: Dictionary = {}
	for spawn in spawns:
		var col: int = spawn["col"]
		per_col[col] = int(per_col.get(col, 0)) + 1
	for spawn in spawns:
		var col: int = spawn["col"]
		var to_r: int = spawn["to_r"]
		var gem := _make_gem(spawn["color"])
		gem.position = _cell_pos(to_r - int(per_col[col]), col)
		_board_area.add_child(gem)
		_gem_nodes[to_r][col] = gem
		drop.tween_property(gem, "position", _cell_pos(to_r, col), FALL_TIME)


func _spawn_match_badge(group: Array) -> void:
	if group.is_empty():
		return
	var sum := Vector2.ZERO
	for cell in group:
		sum += _cell_pos(cell[0], cell[1])
	var center: Vector2 = sum / float(group.size()) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0

	var badge := Label.new()
	badge.text = str(group.size())
	badge.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	badge.add_theme_color_override("font_color", UiPalette.CREAM)
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
