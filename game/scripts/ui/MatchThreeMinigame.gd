class_name MatchThreeMinigame
extends Minigame

# The match-3 minigame TYPE (GDD §5.5) — the first entry in the minigame library. Drag a
# gem toward a neighbor to swap; matches flash with a size badge, clear, and survivors +
# new gems fall into the gaps (resolution steps replayed from MatchThreeBoard, which a
# board test proves can't desync).
#
# Scoring (Tim's minigame v4, 2026-06-25) — you can never LOSE points, only earn them, and
# the skill is in choosing WHICH matches to make:
#   * Every match scores. A bigger match scores more PER gem (a 4- or 5-line is worth more
#     than a plain 3), so going for longer lines pays off.
#   * A single swap that cascades (one match drops gems into another) earns a rising COMBO
#     multiplier on each successive cascade step.
#   * Each round ONE gem type is flagged as the AVOID gem. A match group that does NOT contain
#     the avoid gem earns a +15% bonus (×1.15); a match group that DOES contain it is docked
#     −60% (×0.40). So the avoid gem is a gem to steer AROUND — clean matches pay far more.
#   * Calibration (Tim): a whole 20-second round of ordinary clean matching lands you at ~100%
#     (the host's "full" line, keep all your Legacy). Strong cascade / large-match play climbs
#     up into the extra-high bonus band toward the maximum. See get_performance, which maps the
#     running score onto the host's curve so this holds at any bonus cap.
#
# This control owns ONLY the board gameplay. The host (MinigameScreen) owns the countdown,
# the spectrum bar, the result, and the multiplier — see Minigame for the contract.

const Board = preload("res://scripts/core/MatchThreeBoard.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const GEM_COLORS := 4

# --- Match scoring (Tim's minigame v4) ---------------------------------------
## Base points for each gem in a match.
const POINTS_PER_GEM := 10.0
## Larger matches pay more PER gem: a group of n gems is worth POINTS_PER_GEM × n × (1 + this ×
## (n - 3)). So a 3-line is ×1, a 4-line ×1.5, a 5-line ×2 — bigger lines are worth chasing.
const SIZE_BONUS := 0.5
## Combo: each successive cascade step in ONE swap multiplies that step's points by
## 1 + COMBO_BONUS × step_index (step 0 = ×1, step 1 = ×2, step 2 = ×3 …). Rewards chain setups.
const COMBO_BONUS := 1.0
## A match group that AVOIDS the avoid gem earns this bonus (+15%).
const CLEAN_MATCH_FACTOR := 1.15
## A match group that INCLUDES the avoid gem is docked this much (−60%).
const AVOID_MATCH_FACTOR := 0.40

## Score that maps to the host's "full" (1.0x) line — roughly a whole ~20-second round of
## ordinary clean matching (Tim: "regular clean play = ~100%"). Feel-tune estimate for the
## v4 +15%/−60% model with NO ×10 bonus and the shorter 20-second round.
const SCORE_FULL := 300.0
## Score that maps to performance 1.0 (the host's max extra-high bonus) — roughly a whole round
## of strong cascade / large-match play. Feel-tune estimate (same v4 / 20-second basis).
const SCORE_MAX := 1000.0

## A square cell, generously sized for thumb taps and low-vision readability (§1b),
## plus the gap between cells. PITCH is the cell-to-cell pixel stride.
const CELL_SIZE := 96
const GAP := 8
const PITCH := CELL_SIZE + GAP

## The bonus banner's gem tile — deliberately much larger than a board cell so this round's
## AVOID gem stands out as a prominent "steer around this" cue pinned above the grid.
const BONUS_ICON_SIZE := 198

## How far a press must move before it counts as a drag-swap (rather than a stray tap).
const DRAG_THRESHOLD := CELL_SIZE * 0.4

# Animation durations (seconds).
const SWAP_TIME := 0.16
const FLASH_TIME := 0.14
const CLEAR_TIME := 0.18
const FALL_TIME := 0.30

# Each gem id 0..3 gets a distinct, hand-drawn SVG with its own COLOR and SHAPE (round,
# diamond, hexagon, teardrop) so they read at a glance for colour-blind / low-vision players.
# The SVGs live in art/icons/ so Tim can restyle a gem by editing one file.
const GEM_TEXTURE := [
	preload("res://art/icons/gem_red.svg"),
	preload("res://art/icons/gem_gold.svg"),
	preload("res://art/icons/gem_teal.svg"),
	preload("res://art/icons/gem_green.svg"),
]

var _board
var _animating: bool = false
var _rng := RandomNumberGenerator.new()

# Avoid-gem scoring state.
## The single AVOID gem type this round (a color id). Matching a group that contains this gem
## is docked −60%; matching only clean gems earns +15%.
var _avoid_type: int = 0
## Total points earned so far (only ever rises — there is no way to lose points).
var _score: float = 0.0
## Whether the player ever matched a group containing the avoid gem — used in the result summary.
var _matched_avoid_gem: bool = false
## The live "Score: N" readout above the grid.
var _score_label: Label

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
	_choose_avoid_type()

	var intro := Label.new()
	intro.text = "Match gems to score. Clean matches pay MORE — AVOID matching the marked gem!"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# A live running score readout, on its own line under the intro.
	var score_row := _build_score_row()

	# The banner and the framed board travel together as one group, vertically centered in the
	# space below the intro/score lines. A small separation keeps the AVOID banner pinned right
	# above the board.
	var bonus_banner := _build_bonus_banner()
	var board_frame := _build_board_frame()

	var board_group := VBoxContainer.new()
	board_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_group.alignment = BoxContainer.ALIGNMENT_CENTER
	board_group.add_theme_constant_override("separation", 8)
	board_group.add_child(bonus_banner)
	board_group.add_child(board_frame)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(score_row)
	column.add_child(board_group)
	add_child(column)

	_build_initial_gems()


## Pick the single AVOID gem type for this round (one random color id).
func _choose_avoid_type() -> void:
	_avoid_type = _rng.randi_range(0, GEM_COLORS - 1)


## The live running score readout (refreshed as cascades resolve by _update_score_display), on
## its own centered line under the intro.
func _build_score_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_score_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	row.add_child(_score_label)
	_update_score_display()

	return row


## Build the AVOID banner pinned directly above the grid: an "AVOID" tag next to this round's
## avoid gem, shown large inside a gold-framed panel so the player can see at a glance which gem
## to steer around (matching it is docked −60%; clean matches earn +15%).
func _build_bonus_banner() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	var avoid_tag := Label.new()
	avoid_tag.text = "AVOID"
	avoid_tag.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	avoid_tag.add_theme_color_override("font_color", UiPalette.NAVY)
	avoid_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(avoid_tag)

	row.add_child(_make_bonus_icon(_avoid_type))

	return row


## A single large AVOID gem tile for the banner: the gem texture centered inside a rounded panel
## with a thick MUSTARD_GOLD border over a dark-gold background, so it reads as a prominent,
## non-interactive "look out for this gem" cue.
func _make_bonus_icon(color_id: int) -> Control:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(BONUS_ICON_SIZE, BONUS_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	# Dark-gold background derived from the gold border so the panel reads as one gold object.
	box.bg_color = UiPalette.MUSTARD_GOLD.darkened(0.55)
	box.set_corner_radius_all(20)
	box.border_color = UiPalette.MUSTARD_GOLD
	box.set_border_width_all(9)
	icon.add_theme_stylebox_override("panel", box)

	# The gem texture, centered with padding so it sits well inside the gold frame.
	var tex := TextureRect.new()
	tex.texture = GEM_TEXTURE[color_id]
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 24
	tex.offset_top = 24
	tex.offset_right = -24
	tex.offset_bottom = -24
	icon.add_child(tex)

	return icon


## Wrap the playable grid in a thick, dark-gold, rounded frame so the board reads as a framed
## "table" the gems sit on. The grid (_board_area) keeps its own local coordinate space, so the
## drag/swap PITCH math in _on_board_input is unaffected by this wrapper.
func _build_board_frame() -> Control:
	_board_area = Control.new()
	_board_area.custom_minimum_size = Vector2(GRID_WIDTH * PITCH - GAP, GRID_HEIGHT * PITCH - GAP)
	_board_area.clip_contents = true
	_board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_area.gui_input.connect(_on_board_input)

	var frame := PanelContainer.new()
	# Shrink-center so the frame hugs the board's size instead of stretching across the column.
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CREAM
	box.border_color = UiPalette.MUSTARD_GOLD.darkened(0.5)
	box.set_border_width_all(10)
	box.set_corner_radius_all(24)
	# Content margin keeps gems off the border so the rounded corners read cleanly.
	box.content_margin_left = 12
	box.content_margin_top = 12
	box.content_margin_right = 12
	box.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", box)

	frame.add_child(_board_area)
	return frame


func get_performance() -> float:
	if _board == null:
		return 0.0
	# Map the running score onto the host's outcome curve with a two-segment curve so Tim's
	# calibration holds at ANY bonus cap:
	#   * 0 .. SCORE_FULL  -> performance 0 .. the host's "full" line (a whole round of ordinary
	#                         clean matching lands right at full = keep 100%).
	#   * SCORE_FULL .. SCORE_MAX -> the full line .. performance 1.0 (strong cascade / large-match
	#                         play climbs into the extra-high band toward the maximum).
	var full_line := _full_line_performance()
	if _score <= SCORE_FULL:
		return full_line * clampf(_score / SCORE_FULL, 0.0, 1.0)
	var into_bonus := clampf((_score - SCORE_FULL) / (SCORE_MAX - SCORE_FULL), 0.0, 1.0)
	return full_line + (1.0 - full_line) * into_bonus


## The performance value at which the host's curve hits exactly 1.0x ("full"), derived from the
## outcome curve the host set before begin(). Anchoring our score-to-performance mapping here is
## what makes "regular clean play = full" true whether the site's bonus cap is 0.25 or 1.0.
func _full_line_performance() -> float:
	var span := (1.0 - outcome_keep_floor) + outcome_bonus_max
	if span <= 0.0:
		return 1.0
	return (1.0 - outcome_keep_floor) / span


## Refresh the live score readout.
func _update_score_display() -> void:
	if _score_label != null:
		_score_label.text = "Score: %d" % int(round(_score))


func is_busy() -> bool:
	return _animating


# ---------------------------------------------------------------------------
# Gem nodes
# ---------------------------------------------------------------------------

func _cell_pos(row: int, col: int) -> Vector2:
	return Vector2(col * PITCH, row * PITCH)


func _make_gem(color_id: int) -> Control:
	# A gem is now its own SVG texture (not a styled panel + symbol). We size the TextureRect to a
	# full cell and center the artwork inside it, keeping aspect so the shapes never distort.
	var gem := TextureRect.new()
	gem.texture = GEM_TEXTURE[color_id]
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.size = Vector2(CELL_SIZE, CELL_SIZE)
	gem.pivot_offset = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.set_meta("color", color_id)

	_style_gem(gem, false)
	return gem


## Show a gem as selected/active during a drag. With textured gems there is no panel stylebox to
## restyle, so we brighten (modulate) and slightly enlarge the gem instead; clearing it resets to
## the plain look. Alpha is kept at 1 so we never interfere with the clear-fade animation.
func _style_gem(gem: Control, active: bool) -> void:
	if active:
		gem.modulate = Color(1.35, 1.35, 1.35, 1.0)
		gem.scale = Vector2(1.08, 1.08)
	else:
		gem.modulate = Color.WHITE
		gem.scale = Vector2.ONE


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

	# Score the whole swap up front from the recorded steps (deterministic), but AWARD it step by
	# step as each cascade clears on screen — so the score readout and the host's spectrum bar
	# climb in time with the animation.
	var scoring := _score_swap(result)
	var step_points: Array = scoring["step_points"]
	if scoring["matched_avoid"]:
		_matched_avoid_gem = true

	for i in range(result["steps"].size()):
		await _animate_step(result["steps"][i], float(step_points[i]))

	_animating = false


## Compute a swap's earnings from the board's recorded resolution steps. Returns the points to
## award for each cascade step plus whether the swap matched the avoid gem anywhere:
##   { "step_points": Array[float], "matched_avoid": bool }
## Each match GROUP is scored on its own: a clean group (no avoid gem) earns +15%, a group that
## contains the avoid gem is docked −60%. The groups' points are summed per step, then the step's
## rising COMBO multiplier is applied.
func _score_swap(result: Dictionary) -> Dictionary:
	var steps: Array = result["steps"]
	var matched_avoid := false
	var step_points: Array = []

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		# Build a quick cell -> color lookup for this step so we can tell each group's color. Every
		# cell in a match GROUP is the same color (a group is one straight line), so one lookup per
		# group is enough. cleared_colors is aligned with cleared (same order) by the board.
		var color_of_cell := {}
		var cleared: Array = step["cleared"]
		var cleared_colors: Array = step["cleared_colors"]
		for j in range(cleared.size()):
			var cell: Array = cleared[j]
			color_of_cell[cell[0] * GRID_WIDTH + cell[1]] = cleared_colors[j]

		# Combo: each successive cascade step in this swap multiplies its points (step 0 = ×1).
		var combo_multiplier := 1.0 + COMBO_BONUS * float(i)
		var step_raw := 0.0
		for group in step["matches"]:
			var cells: Array = group
			var n: int = cells.size()
			# Bigger lines score more per gem (see SIZE_BONUS).
			var group_points := POINTS_PER_GEM * float(n) * (1.0 + SIZE_BONUS * float(n - 3))
			# Find this group's color from any of its cells, then apply the clean/avoid factor.
			var first_cell: Array = cells[0]
			var group_color: int = color_of_cell[first_cell[0] * GRID_WIDTH + first_cell[1]]
			if group_color == _avoid_type:
				group_points *= AVOID_MATCH_FACTOR
				matched_avoid = true
			else:
				group_points *= CLEAN_MATCH_FACTOR
			step_raw += group_points
		step_points.append(step_raw * combo_multiplier)

	return {"step_points": step_points, "matched_avoid": matched_avoid}


func _animate_step(step: Dictionary, points: float) -> void:
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
	# Free the cleared gems and award this cascade step's points NOW, as the gems vanish — so the
	# score (and the host's spectrum bar) climbs step by step through a cascade.
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			gem.queue_free()
		_gem_nodes[cell[0]][cell[1]] = null
	_score += points
	_update_score_display()

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


func result_summary() -> String:
	var line := "Scored %d points" % int(round(_score))
	if _matched_avoid_gem:
		line += " — watch out for the AVOID gem next time!"
	else:
		line += " — clean matching, nicely done!"
	return line
