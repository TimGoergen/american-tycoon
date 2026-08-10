class_name NewVenturesOverlay
extends ColorRect

# A light discoverability nudge for the epoch pager (Tim 2026-07-11): the player only sees one
# epoch tab at a time, so when a tab they have NOT opened first has a property they can afford,
# this modal pops up once to point them at it ("swipe over — there's something to buy"). Driven
# by Main, which tracks which tabs have been seen/nudged and when their cheapest venture becomes
# affordable. SHOW ME jumps to that tab; NOT NOW just closes. Fires at most once per tab.

signal show_requested   # "SHOW ME" — take me to the newly-affordable tab
signal dismissed        # "NOT NOW" — just close

var _message_label: Label


func _ready() -> void:
	# Same black-field + cream bezel as the other full-screen beats, so every modal matches.
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var center := CenterContainer.new()
	viewing_area.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	column.custom_minimum_size = Vector2(760, 0)
	center.add_child(column)

	var heading := Label.new()
	heading.text = "NEW VENTURES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	heading.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	heading.add_theme_constant_override("outline_size", 5)
	heading.add_theme_font_override("font", UiPalette.make_bold_font())
	heading.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(heading)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(760, 0)
	_message_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_message_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_message_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	column.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	var show_button := Button.new()
	show_button.text = "SHOW ME"
	show_button.custom_minimum_size = Vector2(320, 96)
	show_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(show_button, true)
	show_button.pressed.connect(_on_show_pressed)
	buttons.add_child(show_button)

	var later_button := Button.new()
	later_button.text = "NOT NOW"
	later_button.custom_minimum_size = Vector2(320, 96)
	later_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(later_button, false)
	later_button.pressed.connect(_on_later_pressed)
	buttons.add_child(later_button)


## Show the nudge for a tab, named by its big label and optional collar subtitle.
func show_for(tab_name: String, subtitle: String) -> void:
	if subtitle != "":
		_message_label.text = "You can now afford ventures in\n%s · %s" % [tab_name, subtitle]
	else:
		_message_label.text = "You can now afford ventures in\n%s" % tab_name
	visible = true


func _on_show_pressed() -> void:
	visible = false
	Audio.play(&"screen_open")
	show_requested.emit()


func _on_later_pressed() -> void:
	visible = false
	Audio.play(&"screen_close")
	dismissed.emit()
