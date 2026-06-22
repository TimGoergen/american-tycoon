class_name MinigameScreen
extends ColorRect

# The prestige minigame (GDD §5.5): a quick match-3 played during succession. The
# player's score grants an UPSIDE-ONLY multiplier on the Legacy earned that run
# (legacy_awarded = floor(base_legacy × mult), mult in [optout, max]). It can never
# lose you Legacy — skipping or running out the clock with 0 score just banks 1.0×.
#
# Two phases inside the one overlay:
#   PLAY   — the board, a countdown, a running score, and a Skip button.
#   RESULT — the earned multiplier and the boosted Legacy, then Continue.
#
# Mirrors the project overlay idiom (FirstContactOverlay): a scrim ColorRect with a
# centered cream panel. Main freezes the economy while this is visible and reads the
# result from the `finished` signal. The board math lives in the headless
# MatchThreeBoard; this file is presentation + input only.

## Emitted when the round ends (Continue tapped, or Skip). `multiplier` is applied to
## the run's Legacy by Main; `opt_out` is true if the player asked to auto-skip the
## minigame on future prestiges (Main persists it to GameState.ui_minigame_enabled).
signal finished(multiplier: float, opt_out: bool)

const Board = preload("res://scripts/core/MatchThreeBoard.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const GEM_COLORS := 5

## A square cell, generously sized for thumb taps and low-vision readability (§1b).
const CELL_SIZE := 96

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
var _seconds_left: float = 0.0
var _playing: bool = false
var _opt_out: bool = false

## The currently selected cell for a swap (-1 = nothing selected yet).
var _sel_row: int = -1
var _sel_col: int = -1

# UI nodes.
var _play_view: Control
var _result_view: Control
var _timer_label: Label
var _score_label: Label
var _grid: GridContainer
var _cell_buttons: Array = []  # flat row-major array of the GRID_WIDTH×GRID_HEIGHT Buttons
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
	column.add_theme_constant_override("separation", 14)

	var title := _make_label("GROW THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := _make_label(
		"Match 3+ to clear them — the more you clear, the bigger the bonus.",
		UiPalette.FONT_LABEL, UiPalette.NAVY
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	# Status row: time left on the left, score on the right.
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 20)
	column.add_child(status)

	_timer_label = _make_label("0:30", UiPalette.FONT_SUBHEAD, UiPalette.KETCHUP_RED)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_timer_label)

	_score_label = _make_label("Cleared: 0", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_score_label)

	# The gem grid. Built once; cell colors/symbols are refreshed from the board.
	_grid = GridContainer.new()
	_grid.columns = GRID_WIDTH
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	var grid_center := CenterContainer.new()
	grid_center.add_child(_grid)
	column.add_child(grid_center)

	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
			# Capture row/col by value for this cell's handler.
			cell.pressed.connect(_on_cell_pressed.bind(row, col))
			_grid.add_child(cell)
			_cell_buttons.append(cell)

	# Skip: bank the flat opt-out multiplier (no bonus) and leave immediately.
	var skip_button := Button.new()
	skip_button.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(skip_button, false)
	skip_button.text = "SKIP (no bonus)"
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

	var heading := _make_label("INHERITANCE SECURED", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_result_mult_label = _make_label("×1.0 bonus", UiPalette.FONT_DISPLAY, UiPalette.MUSTARD_GOLD)
	_result_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_mult_label)

	_result_legacy_label = _make_label("+0 Legacy", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
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
# Round lifecycle
# ---------------------------------------------------------------------------

## Start a round. `base_legacy` is the run's pre-minigame Legacy (from the will), used
## only to show the boosted total on the result screen. Main shows this, then reads the
## `finished` multiplier to bank the boosted Legacy.
func start_game(base_legacy: int) -> void:
	_base_legacy = base_legacy
	_board = Board.new(GRID_WIDTH, GRID_HEIGHT, GEM_COLORS)
	_seconds_left = _tuning.minigame_duration_seconds
	_sel_row = -1
	_sel_col = -1
	_opt_out = false
	if _opt_out_check != null:
		_opt_out_check.button_pressed = false

	_play_view.visible = true
	_result_view.visible = false
	_refresh_grid()
	_update_status()

	_playing = true
	visible = true


func _process(delta: float) -> void:
	if not _playing:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_update_status()
	if _seconds_left <= 0.0:
		_end_round()


func _update_status() -> void:
	var whole := int(ceil(_seconds_left))
	_timer_label.text = "0:%02d" % whole
	_score_label.text = "Cleared: %d" % _board.score


# ---------------------------------------------------------------------------
# Input — tap a gem, then tap an adjacent gem to swap
# ---------------------------------------------------------------------------

func _on_cell_pressed(row: int, col: int) -> void:
	if not _playing:
		return

	if _sel_row < 0:
		# First pick — select it.
		_sel_row = row
		_sel_col = col
		_refresh_grid()
		return

	if row == _sel_row and col == _sel_col:
		# Tapped the same gem — deselect.
		_sel_row = -1
		_sel_col = -1
		_refresh_grid()
		return

	if _board.is_adjacent(_sel_row, _sel_col, row, col):
		# Adjacent — attempt the swap. try_swap returns gems cleared (0 if no match).
		_board.try_swap(_sel_row, _sel_col, row, col)
		_sel_row = -1
		_sel_col = -1
		_refresh_grid()
		_update_status()
	else:
		# Not adjacent — treat the new tap as a fresh selection instead.
		_sel_row = row
		_sel_col = col
		_refresh_grid()


## Repaint every cell from the board (color + symbol), highlighting the selected one.
func _refresh_grid() -> void:
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			var cell := _cell_buttons[row * GRID_WIDTH + col] as Button
			var id: int = _board.color_at(row, col)
			var selected := (row == _sel_row and col == _sel_col)
			_style_cell(cell, id, selected)


func _style_cell(cell: Button, gem_id: int, selected: bool) -> void:
	var fill: Color = GEM_FILL[gem_id]
	# The selected gem brightens and gets a bold cream border so it reads as "picked".
	var box := StyleBoxFlat.new()
	box.bg_color = fill.lightened(0.25) if selected else fill
	box.set_corner_radius_all(8)
	box.border_color = UiPalette.CREAM if selected else UiPalette.INK_NAVY
	box.set_border_width_all(5 if selected else 2)
	cell.add_theme_stylebox_override("normal", box)
	cell.add_theme_stylebox_override("hover", box)
	cell.add_theme_stylebox_override("pressed", box)
	cell.add_theme_stylebox_override("focus", box)
	cell.text = GEM_SYMBOL[gem_id]
	cell.add_theme_color_override("font_color", GEM_TEXT[gem_id])
	cell.add_theme_color_override("font_hover_color", GEM_TEXT[gem_id])
	cell.add_theme_color_override("font_pressed_color", GEM_TEXT[gem_id])


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------

## Score → multiplier: scales linearly from optout (score 0) to max (score ≥ target).
func _multiplier_for_score(score: int) -> float:
	var span := _tuning.minigame_mult_max - _tuning.minigame_mult_optout
	var progress := clampf(float(score) / maxf(1.0, _tuning.minigame_score_target), 0.0, 1.0)
	return _tuning.minigame_mult_optout + span * progress


## Time ran out — compute the multiplier, show the result phase.
func _end_round() -> void:
	_playing = false
	var mult := _multiplier_for_score(_board.score)
	_show_result(mult)


func _show_result(mult: float) -> void:
	var boosted := int(floor(float(_base_legacy) * mult))
	var bonus := boosted - _base_legacy
	_result_mult_label.text = "×%.2f bonus" % mult
	if bonus > 0:
		_result_legacy_label.text = "+%d Legacy  (%d base +%d bonus)" % [boosted, _base_legacy, bonus]
	else:
		_result_legacy_label.text = "+%d Legacy" % boosted
	_play_view.visible = false
	_result_view.visible = true
	visible = true


## Skip: no bonus this round (flat opt-out multiplier), leave immediately. Honors the
## "skip on future prestiges" checkbox if the player ticked it before skipping.
func _on_skip_pressed() -> void:
	_playing = false
	visible = false
	finished.emit(_tuning.minigame_mult_optout, _opt_out)


func _on_continue_pressed() -> void:
	visible = false
	finished.emit(_multiplier_for_score(_board.score), _opt_out)
