class_name WelcomeBackOverlay
extends ColorRect

# The welcome-back ritual, plain M1 version (GDD §3.1, §7): beat one is the
# cheerful pile with the deadpan stat line; the button hands the player
# straight into the spending spree. Ceremony copy arrives in M3.

signal dismissed
## Player chose to gamble the overnight pile on a minigame instead of banking it as-is.
signal risk_pressed

var _pile_label: Label
var _away_label: Label
var _spend_button: Button
var _risk_button: Button


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
	column.custom_minimum_size = Vector2(760, 0)
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

	# Two choices on one row (Tim, 2026-06-24): take the overnight pile as-is, or gamble it on a
	# minigame that can swing the haul anywhere from 50% to 200%. The RISK button only appears
	# when transition minigames are enabled (show_pile's allow_risk) and never on the
	# post-minigame result screen — you get one roll.
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)

	_spend_button = Button.new()
	_spend_button.text = "PUT IT TO WORK"
	_spend_button.custom_minimum_size = Vector2(0, 96)
	_spend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spend_button.add_theme_font_size_override("font_size", 28)
	UiPalette.style_button(_spend_button, true)
	_spend_button.pressed.connect(_on_spend_pressed)
	button_row.add_child(_spend_button)

	_risk_button = Button.new()
	_risk_button.text = "RISK IT ON A MINIGAME?"
	_risk_button.custom_minimum_size = Vector2(0, 96)
	_risk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_risk_button.add_theme_font_size_override("font_size", 28)
	# The label is long; wrap it onto two lines rather than clipping at narrow widths.
	_risk_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPalette.style_button(_risk_button, false)
	_risk_button.pressed.connect(_on_risk_pressed)
	button_row.add_child(_risk_button)


## Show the overlay for a banked pile. `allow_risk` reveals the RISK IT button — true on the
## initial welcome (when transition minigames are on), false on the post-minigame result.
func show_pile(pile: float, hours_away: float, allow_risk: bool = false) -> void:
	_pile_label.text = Money.of(pile).display()
	_away_label.text = "You were away %.1f hours." % hours_away
	_risk_button.visible = allow_risk
	visible = true


func _on_spend_pressed() -> void:
	visible = false
	dismissed.emit()


func _on_risk_pressed() -> void:
	visible = false
	risk_pressed.emit()
