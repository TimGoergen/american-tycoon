class_name WelcomeBackOverlay
extends ColorRect

# The welcome-back ritual, plain M1 version (GDD §3.1, §7): beat one is the
# cheerful pile with the deadpan stat line; the button hands the player
# straight into the spending spree. Ceremony copy arrives in M3.

signal dismissed

var _pile_label: Label
var _away_label: Label


func _ready() -> void:
	# Black field framing a cream rounded viewing area — the same full-screen frame the main
	# game and dev panel use (Tim, 2026-06-23), so every full-window screen matches.
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var center := CenterContainer.new()
	viewing_area.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(640, 0)
	center.add_child(column)

	var headline := Label.new()
	headline.text = "WELCOME BACK!"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.NAVY)
	headline.add_theme_font_size_override("font_size", 48)
	column.add_child(headline)

	_pile_label = Label.new()
	_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_pile_label.add_theme_font_size_override("font_size", 64)
	column.add_child(_pile_label)

	_away_label = Label.new()
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_away_label.add_theme_font_size_override("font_size", 26)
	column.add_child(_away_label)

	var worked := Label.new()
	worked.text = "Hours you worked: 0"
	worked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worked.add_theme_color_override("font_color", UiPalette.NAVY)
	worked.add_theme_font_size_override("font_size", 26)
	column.add_child(worked)

	var spend_button := Button.new()
	spend_button.text = "PUT IT TO WORK"
	spend_button.custom_minimum_size = Vector2(0, 80)
	spend_button.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(spend_button, true)
	spend_button.pressed.connect(_on_spend_pressed)
	column.add_child(spend_button)


## Show the overlay for a banked pile.
func show_pile(pile: float, hours_away: float) -> void:
	_pile_label.text = Money.of(pile).display()
	_away_label.text = "You were away %.1f hours." % hours_away
	visible = true


func _on_spend_pressed() -> void:
	visible = false
	dismissed.emit()
