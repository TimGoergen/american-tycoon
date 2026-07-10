class_name AboutScreen
extends ColorRect

# The About modal (Tim, 2026-07-09): the game logo, name, version, and credits, opened from the
# Settings tab's About button. A full-screen overlay like the other modals; the Back button (top
# left) closes it. The same black-bezel frame every full-window screen uses, for consistency.

signal closed

const LOGO_TEXTURE := preload("res://art/branding/american_tycoon_logo.png")


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

	# Back button, pinned top-left with a generous margin (matches the minigame Back button style).
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

	# The content, centered in the space beneath the Back button.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	content.custom_minimum_size = Vector2(760, 0)
	center.add_child(content)

	# Logo at the top.
	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Fill the content column's width (min width 0 + shrink-center collapsed it to nothing); the SVG
	# keeps its aspect centered within the 520px-tall band.
	logo.custom_minimum_size = Vector2(0, 520)
	logo.size_flags_horizontal = Control.SIZE_FILL
	content.add_child(logo)

	content.add_child(_make_line(
		ProjectSettings.get_setting("application/config/name", "American Tycoon"),
		UiPalette.FONT_DISPLAY, UiPalette.NAVY))
	content.add_child(_make_line(
		"Version " + str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		UiPalette.FONT_SUBHEAD, UiPalette.DARK_GOLD))
	content.add_child(_make_line("Designed by Tim Goergen", UiPalette.FONT_HEADLINE, UiPalette.NAVY))
	content.add_child(_make_line(
		"Built by Claude Code with a little help from Copilot and Gemini",
		UiPalette.FONT_LABEL, Color(UiPalette.NAVY, 0.75)))


## A centered, wrapping text line for the About content.
func _make_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func open() -> void:
	visible = true


func _on_back_pressed() -> void:
	visible = false
	closed.emit()
