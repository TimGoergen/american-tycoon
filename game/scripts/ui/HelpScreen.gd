class_name HelpScreen
extends ColorRect

# The Help / Glossary modal (Plans/Tutorial_Onboarding_Plan.md, Phase 4): a scrollable reference of
# every tutorial concept, plus a REPLAY TUTORIAL action that re-arms the one-time coach cards.
# Opened from the Settings tab's HELP button; the Back button (top-left) closes it. Same
# black-bezel frame as the other full-window modals (modeled on AboutScreen). The glossary text is
# the single copy in TutorialCatalog, so the cards and this reference can never disagree.

signal closed
## The player asked to see the tutorial again — Main clears TutorialProgress and re-arms the tips.
signal replay_requested


func _ready() -> void:
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	viewing_area.add_child(column)

	# Back button, pinned top-left (matches the About / minigame Back button).
	var back_margin := MarginContainer.new()
	back_margin.add_theme_constant_override("margin_top", 28)
	back_margin.add_theme_constant_override("margin_left", 28)
	column.add_child(back_margin)
	var back_row := HBoxContainer.new()
	back_margin.add_child(back_row)
	var back := Button.new()
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(340, 108)
	back.add_theme_font_size_override("font_size", int(UiPalette.FONT_BUTTON * 1.5))
	back.add_theme_font_override("font", UiPalette.make_bold_font())
	back.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(back, false)
	back.pressed.connect(_on_back_pressed)
	back_row.add_child(back)
	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer)

	column.add_child(UiPalette.make_tab_title("HELP"))

	# Scrollable glossary — one titled entry per tutorial concept, in teaching order (Dictionary
	# iteration preserves the catalog's insertion order). Horizontal scroll off so the entries wrap.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 22)
	scroll.add_child(list)
	for tip_id in TutorialCatalog.TIPS:
		list.add_child(_make_entry(TutorialCatalog.TIPS[tip_id]))

	# Replay action at the bottom, clear of the list. Red "act" styling — it's a deliberate action.
	var replay := Button.new()
	replay.text = "REPLAY TUTORIAL"
	replay.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 1.2))
	replay.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	replay.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(replay, true)
	replay.pressed.connect(_on_replay_pressed)
	column.add_child(replay)


## One glossary entry: the concept's bold title over its explanation.
func _make_entry(tip: Dictionary) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = tip.get("title", "")
	title.add_theme_font_override("font", UiPalette.make_bold_font())
	title.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title)

	var body := Label.new()
	body.text = tip.get("body", "")
	body.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	body.add_theme_color_override("font_color", Color(UiPalette.NAVY, 0.85))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(body)

	return entry


func open() -> void:
	visible = true


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_replay_pressed() -> void:
	visible = false
	closed.emit()
	replay_requested.emit()
