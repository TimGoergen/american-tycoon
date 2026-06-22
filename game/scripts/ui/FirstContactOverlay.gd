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

var _eyebrow_label: Label
var _civ_label: Label
var _planet_label: Label
var _flavor_label: Label
var _market_label: Label
var _narration_label: Label

## Drives the eyebrow's slow blink so the moment reads as a live, urgent transmission.
var _blink_time := 0.0


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

	# Eyebrow: a blinking "incoming transmission" line so the screen reads as a live event
	# breaking in, not a quiet notice (Tim 2026-06-17). Its alpha pulses in _process.
	_eyebrow_label = Label.new()
	_eyebrow_label.text = "◄  INCOMING TRANSMISSION  ►"
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_eyebrow_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_eyebrow_label)

	var headline := Label.new()
	headline.text = "FIRST CONTACT"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Gold: this is a celebratory milestone, like the Legacy reward chrome.
	headline.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	headline.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	headline.add_theme_constant_override("outline_size", 3)
	headline.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(headline)

	# The civilization Earth has just reached — the big name on the card.
	_civ_label = Label.new()
	_civ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_civ_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_civ_label.custom_minimum_size = Vector2(760, 0)
	_civ_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_civ_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_civ_label.add_theme_constant_override("outline_size", 2)
	_civ_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	column.add_child(_civ_label)

	# Home world + their currency (flavor only — Earth stays on dollars).
	_planet_label = Label.new()
	_planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_planet_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	column.add_child(_planet_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN.darkened(0.2))
	_flavor_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	column.add_child(_flavor_label)

	# The headline payoff: how many times larger the new market is. Big and gold, so the
	# scale jump lands as the reason this is worth celebrating.
	_market_label = Label.new()
	_market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_market_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_market_label.add_theme_constant_override("outline_size", 2)
	_market_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(_market_label)

	# The narrator's contact line.
	_narration_label = Label.new()
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.custom_minimum_size = Vector2(760, 0)
	_narration_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_narration_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_narration_label)

	var note := Label.new()
	note.text = "New markets open. Your staff can be upgraded with their technology."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.add_theme_color_override("font_color", UiPalette.NAVY)
	note.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	column.add_child(note)

	var proceed_button := Button.new()
	proceed_button.text = "ANSWER THE CALL"
	proceed_button.custom_minimum_size = Vector2(0, 96)
	proceed_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(proceed_button, true)
	proceed_button.pressed.connect(_on_proceed_pressed)
	column.add_child(proceed_button)


## Blink the "incoming transmission" eyebrow while the overlay is up.
func _process(delta: float) -> void:
	if not visible:
		return
	_blink_time += delta
	_eyebrow_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink_time * TAU * 1.5))


## Show the contact beat for a newly-reached epoch tier (2+), reading its flavor from
## EpochCatalog. Tier 1 (Earth) never triggers this — you begin there.
func show_contact(tier: int) -> void:
	var epoch := EpochCatalog.get_epoch(tier)
	if epoch.is_empty():
		return
	_civ_label.text = String(epoch["civilization"])
	_planet_label.text = "Home world: %s" % String(epoch["home_planet"])
	_flavor_label.text = "They trade in %s." % String(epoch["currency_flavor"])
	# How many times larger the new market is than the one just consumed (the scale jump
	# between this epoch and the previous one) — the celebratory payoff line.
	var growth := EpochCatalog.economy_scale(tier) / EpochCatalog.economy_scale(tier - 1)
	_market_label.text = "THE MARKET JUST GREW ×%s" % _format_multiplier(growth)
	_narration_label.text = EpochCatalog.contact_line(tier)
	_blink_time = 0.0
	visible = true


## Compact ×N formatting for the market-growth line (1,000 / 1 million / 1 billion …),
## so an order-of-magnitude jump reads cleanly instead of as a wall of zeroes.
func _format_multiplier(value: float) -> String:
	if value >= 1_000_000_000.0:
		return "%g billion" % (value / 1_000_000_000.0)
	if value >= 1_000_000.0:
		return "%g million" % (value / 1_000_000.0)
	# Group the thousands with commas (e.g. 1000 → "1,000").
	var digits := str(int(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped


func _on_proceed_pressed() -> void:
	visible = false
	dismissed.emit()
