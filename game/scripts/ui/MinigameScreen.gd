class_name MinigameScreen
extends ColorRect

# The minigame HOST (GDD §5.5). It picks a random minigame TYPE from the library, runs it,
# and converts its performance (0..1) into the universal outcome multiplier shared by every
# minigame: 0.5x (keep floor / skip) -> 1.0x (full) -> up to 1.0 + bonus_max (extra-high,
# bonus cap from the Family Reputation upgrade). The host owns everything common — the
# countdown, the live "Legacy kept" spectrum bar, the result, and the skip/opt-out — so all
# types behave identically; a type owns only its gameplay (see Minigame).
#
# Currently wired to the prestige/succession site (Legacy). Phase 3 adds the First Contact
# and Welcome-back sites; the reward labels would generalize then.

## Emitted when the round ends (Continue or Skip). `multiplier` is applied to the run's
## Legacy by Main; `opt_out` true if the player asked to auto-skip future minigames.
signal finished(multiplier: float, opt_out: bool)

## Emitted only in review mode (Settings → Minigame Tuning) when the player taps the Back
## button to abandon the round and return to the review list. Carries no result — review
## play never affects the run's Legacy.
signal back_pressed

# The minigame library — the host draws one at random each round so the player doesn't know
# which they'll get. Add new types here (Phase 2).
const MINIGAME_TYPES := [
	preload("res://scripts/ui/MatchThreeMinigame.gd"),
	preload("res://scripts/ui/TimingBarMinigame.gd"),
	preload("res://scripts/ui/CatchMoneyMinigame.gd"),
	preload("res://scripts/ui/MemoryMinigame.gd"),
	preload("res://scripts/ui/BalanceMinigame.gd"),
]

var _tuning: TuningConfig
var _base_legacy: int = 0
var _bonus_max: float = 0.25
var _seconds_left: float = 0.0
var _playing: bool = false
var _opt_out: bool = false
var _active_minigame: Minigame

## Review mode (Settings → Minigame Tuning): a Back button is shown so a tester can bail
## out at any time. False for the real prestige round, where there is no Back.
var _review_mode: bool = false
## The Back buttons (one per view), shown only in review mode. Tracked so start_game can
## flip their visibility for the chosen mode.
var _back_buttons: Array = []

var _play_view: Control
var _result_view: Control
var _timer_label: Label
var _keep_label: Label
var _keep_bar: Control
var _play_area: Control
var _result_mult_label: Label
var _result_legacy_label: Label
var _opt_out_check: CheckBox


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

	_add_back_button(column)

	var title := _make_label("GROW THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_timer_label = _make_label("0:30", UiPalette.FONT_SUBHEAD, UiPalette.KETCHUP_RED)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_timer_label)

	# The universal "Legacy kept" readout + spectrum bar — identical for every minigame
	# type; it reads the active type's live performance.
	_keep_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
	_keep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keep_label)

	_keep_bar = Control.new()
	_keep_bar.custom_minimum_size = Vector2(0, 34)
	_keep_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_bar.draw.connect(_draw_keep_bar)
	column.add_child(_keep_bar)

	# The chosen minigame TYPE fills this area each round.
	_play_area = Control.new()
	_play_area.custom_minimum_size = Vector2(620, 620)
	_play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_play_area)

	var skip_button := Button.new()
	skip_button.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(skip_button, false)
	skip_button.text = "SKIP (keep the minimum)"
	skip_button.pressed.connect(_on_skip_pressed)
	column.add_child(skip_button)

	_opt_out_check = CheckBox.new()
	_opt_out_check.text = "Skip minigames on future prestiges"
	_opt_out_check.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	for state in ["font_color", "font_pressed_color", "font_hover_color",
			"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		_opt_out_check.add_theme_color_override(state, UiPalette.NAVY)
	_opt_out_check.toggled.connect(func(on: bool) -> void: _opt_out = on)
	column.add_child(_opt_out_check)

	return column


func _build_result_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.visible = false

	_add_back_button(column)

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


## Add a left-aligned Back button to the top of a view's column. Hidden by default; only
## review mode (start_game's review_mode flag) makes it visible. A short HBox keeps it from
## stretching the full width — it sits in the top-left like a typical "back" affordance.
func _add_back_button(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(back, false)
	back.visible = false
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)
	# A spacer eats the rest of the row so the button keeps its natural width on the left.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_back_buttons.append(back)
	column.add_child(row)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

## Start a round. `base_legacy` is the run's pre-minigame Legacy; `bonus_max` is the max
## extra-high bonus fraction (Family Reputation). Normally picks a random minigame type;
## the review screen passes a specific `forced_type` and sets `review_mode` so a Back
## button appears. Prestige play leaves both at their defaults (random type, no Back).
func start_game(
		base_legacy: int, bonus_max: float, forced_type: Script = null, review_mode: bool = false
) -> void:
	_base_legacy = base_legacy
	_bonus_max = maxf(0.0, bonus_max)
	_seconds_left = _tuning.minigame_duration_seconds
	_opt_out = false
	if _opt_out_check != null:
		_opt_out_check.button_pressed = false

	_review_mode = review_mode
	for back in _back_buttons:
		(back as Button).visible = review_mode

	for child in _play_area.get_children():
		child.queue_free()
	var type_script: Script = forced_type if forced_type != null \
			else MINIGAME_TYPES[randi() % MINIGAME_TYPES.size()]
	_active_minigame = type_script.new()
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.add_child(_active_minigame)
	_active_minigame.completed.connect(_on_minigame_completed)
	_active_minigame.begin(_tuning)

	_play_view.visible = true
	_result_view.visible = false
	_playing = true
	_update_status()
	visible = true


func _process(delta: float) -> void:
	if not _playing:
		return
	# Pause the countdown while a type is mid-animation (e.g. match-3 cascades), so that
	# animation time isn't charged to the player. The spectrum still updates.
	if _active_minigame != null and _active_minigame.is_busy():
		_update_status()
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "0:%02d" % int(ceil(_seconds_left))
	_update_status()
	if _seconds_left <= 0.0:
		_end_round()


## A type finished on its own (e.g. the timing bar's last lock) — end with its result.
func _on_minigame_completed(_performance: float) -> void:
	if _playing:
		_end_round()


# ---------------------------------------------------------------------------
# The universal "Legacy kept" indicator
# ---------------------------------------------------------------------------

## Performance (0..1) -> kept multiplier: keep_floor at 0, 1.0 ("full") partway up, and the
## extra-high bonus (1.0 + bonus_max) at performance 1.0. One curve for every minigame type.
func _multiplier_for_performance(performance: float) -> float:
	var floor_mult := _tuning.minigame_keep_floor
	var span := (1.0 - floor_mult) + _bonus_max
	return floor_mult + clampf(performance, 0.0, 1.0) * span


func _current_performance() -> float:
	return _active_minigame.get_performance() if _active_minigame != null else 0.0


func _keep_color(mult: float) -> Color:
	if mult < 1.0:
		var floor_mult := _tuning.minigame_keep_floor
		var t := clampf((mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult), 0.0, 1.0)
		return UiPalette.KETCHUP_RED.lerp(UiPalette.MUSTARD_GOLD, t)
	var into_extra := clampf((mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)
	return UiPalette.MONEY_GREEN.lerp(UiPalette.ATOMIC_TEAL, into_extra)


func _update_status() -> void:
	var mult := _multiplier_for_performance(_current_performance())
	var kept := int(floor(float(_base_legacy) * mult))
	if mult > 1.0:
		_keep_label.text = "%d Legacy  (+%d bonus)" % [kept, kept - _base_legacy]
		_keep_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
	elif kept >= _base_legacy:
		_keep_label.text = "%d Legacy  (full)" % kept
		_keep_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	else:
		_keep_label.text = "%d of %d Legacy" % [kept, _base_legacy]
		_keep_label.add_theme_color_override("font_color", _keep_color(mult))
	_keep_bar.queue_redraw()


func _draw_keep_bar() -> void:
	var w := _keep_bar.size.x
	var h := _keep_bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var floor_mult := _tuning.minigame_keep_floor
	var span := maxf(0.0001, (1.0 + _bonus_max) - floor_mult)
	var mult := _multiplier_for_performance(_current_performance())
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

func _end_round() -> void:
	_playing = false
	_show_result(_multiplier_for_performance(_current_performance()))


func _show_result(mult: float) -> void:
	var kept := int(floor(float(_base_legacy) * mult))
	if mult > 1.0:
		_result_mult_label.text = "+%d%% BONUS" % int(round((mult - 1.0) * 100.0))
		_result_mult_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
		_result_legacy_label.text = "+%d Legacy  (%d base +%d bonus)" % [kept, _base_legacy, kept - _base_legacy]
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


## Back (review mode only): abandon the round and return to the review list. No result is
## emitted — reviewing a minigame never touches the run's Legacy.
func _on_back_pressed() -> void:
	_playing = false
	visible = false
	back_pressed.emit()


## Skip: bank the keep floor (the worst result), leave immediately.
func _on_skip_pressed() -> void:
	_playing = false
	visible = false
	finished.emit(_tuning.minigame_keep_floor, _opt_out)


func _on_continue_pressed() -> void:
	visible = false
	finished.emit(_multiplier_for_performance(_current_performance()), _opt_out)
