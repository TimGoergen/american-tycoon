class_name FirstContactOverlay
extends ColorRect

# The "First Contact" beat (GDD §6.2 / §10.1 beat 4). When a generation consumes the
# entire current economy, Earth makes contact with the next alien civilization: a larger
# market opens and every property unlocks a new alien-tech staffer tier. This overlay is
# that moment — it names the civilization, its home world and currency, and the deadpan
# narrator line, then hands the player back to the (now bigger) game.
#
# Plain first-pass presentation, in the project's placeholder chrome; the full art/audio
# beat arrives with the M3 theme pass. Drive it from Main: connect EpochState.contact_made
# to a handler that calls show_contact(new_tier).

signal dismissed

var _civ_label: Label
var _planet_label: Label
var _flavor_label: Label
var _narration_label: Label


func _ready() -> void:
	color = Color(UiPalette.INK_NAVY, 0.85)  # a heavier scrim than welcome-back — this is a big beat
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(760, 0)
	panel.add_child(column)

	var headline := Label.new()
	headline.text = "FIRST CONTACT"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Gold: this is a celebratory milestone, like the Legacy reward chrome.
	headline.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	headline.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	headline.add_theme_constant_override("outline_size", 3)
	headline.add_theme_font_size_override("font_size", 40)
	column.add_child(headline)

	# The civilization Earth has just reached — the big name on the card.
	_civ_label = Label.new()
	_civ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_civ_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_civ_label.custom_minimum_size = Vector2(760, 0)
	_civ_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_civ_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_civ_label.add_theme_constant_override("outline_size", 2)
	_civ_label.add_theme_font_size_override("font_size", 60)
	column.add_child(_civ_label)

	# Home world + their currency (flavor only — Earth stays on dollars).
	_planet_label = Label.new()
	_planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_planet_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_planet_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN.darkened(0.2))
	_flavor_label.add_theme_font_size_override("font_size", 26)
	column.add_child(_flavor_label)

	# The narrator's contact line.
	_narration_label = Label.new()
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.custom_minimum_size = Vector2(760, 0)
	_narration_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_narration_label.add_theme_font_size_override("font_size", 30)
	column.add_child(_narration_label)

	var note := Label.new()
	note.text = "New markets open. Your staff can be upgraded with their technology."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.add_theme_color_override("font_color", UiPalette.NAVY)
	note.add_theme_font_size_override("font_size", 24)
	column.add_child(note)

	var proceed_button := Button.new()
	proceed_button.text = "OPEN THE MARKET"
	proceed_button.custom_minimum_size = Vector2(0, 88)
	proceed_button.add_theme_font_size_override("font_size", 32)
	UiPalette.style_button(proceed_button, true)
	proceed_button.pressed.connect(_on_proceed_pressed)
	column.add_child(proceed_button)


## Show the contact beat for a newly-reached epoch tier (2+), reading its flavor from
## EpochCatalog. Tier 1 (Earth) never triggers this — you begin there.
func show_contact(tier: int) -> void:
	var epoch := EpochCatalog.get_epoch(tier)
	if epoch.is_empty():
		return
	_civ_label.text = String(epoch["civilization"])
	_planet_label.text = "Home world: %s" % String(epoch["home_planet"])
	_flavor_label.text = "They trade in %s." % String(epoch["currency_flavor"])
	_narration_label.text = EpochCatalog.contact_line(tier)
	visible = true


func _on_proceed_pressed() -> void:
	visible = false
	dismissed.emit()
