class_name EventOverlay
extends ColorRect

# Full-screen modal overlay for Rare Events (GDD §9 / Mechanics Spec §10).
# Displays weather alerts (Market Crash), dilemma choices (The Audit), and windfall notices (The Windfall).
# Styled in 50s-Americana advertising aesthetic using UiPalette tokens.

signal choice_selected(choice_index: int)
signal dismissed

var _eyebrow_label: Label
var _headline_label: Label
var _description_label: Label
var _impact_card: PanelContainer
var _impact_column: VBoxContainer
var _impact_label: Label
var _detail_label: Label
var _narrator_label: Label
var _buttons_container: HBoxContainer
var _single_button: Button
var _choice_button_a: Button
var _choice_button_b: Button

var _current_event_id: String = ""
var _is_dilemma: bool = false


func _ready() -> void:
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var center := CenterContainer.new()
	viewing_area.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.custom_minimum_size = Vector2(800, 0)
	center.add_child(column)

	# 1. Eyebrow Tag
	_eyebrow_label = Label.new()
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_eyebrow_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	column.add_child(_eyebrow_label)

	# 2. Main Headline
	_headline_label = Label.new()
	_headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_headline_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_headline_label.add_theme_constant_override("outline_size", 5)
	_headline_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_headline_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(_headline_label)

	# 3. Description Copy
	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(760, 0)
	_description_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_description_label.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	column.add_child(_description_label)

	# 4. Impact Card / Callout Plate
	_impact_card = PanelContainer.new()
	var impact_style := UiPalette.make_panel_style()
	impact_style.bg_color = UiPalette.CREAM
	impact_style.border_color = UiPalette.NAVY
	impact_style.set_border_width_all(3)
	impact_style.set_corner_radius_all(14)
	impact_style.content_margin_left = 24
	impact_style.content_margin_right = 24
	impact_style.content_margin_top = 20
	impact_style.content_margin_bottom = 20
	_impact_card.add_theme_stylebox_override("panel", impact_style)
	column.add_child(_impact_card)

	_impact_column = VBoxContainer.new()
	_impact_column.add_theme_constant_override("separation", 10)
	_impact_card.add_child(_impact_column)

	_impact_label = Label.new()
	_impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_impact_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_impact_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_impact_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	_impact_column.add_child(_impact_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
	_detail_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_impact_column.add_child(_detail_label)

	# 5. Satirical Narrator Quote
	_narrator_label = Label.new()
	_narrator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrator_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrator_label.custom_minimum_size = Vector2(760, 0)
	_narrator_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_narrator_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_narrator_label)

	# 6. Action Buttons
	_buttons_container = HBoxContainer.new()
	_buttons_container.add_theme_constant_override("separation", 20)
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_buttons_container)

	_single_button = Button.new()
	_single_button.text = "ACKNOWLEDGE"
	_single_button.custom_minimum_size = Vector2(380, 96)
	UiPalette.style_button(_single_button, false)
	_single_button.pressed.connect(_on_single_button_pressed)
	_buttons_container.add_child(_single_button)

	_choice_button_a = Button.new()
	_choice_button_a.text = "SETTLE"
	_choice_button_a.custom_minimum_size = Vector2(360, 96)
	UiPalette.style_blue_button(_choice_button_a)
	_choice_button_a.pressed.connect(func() -> void: _on_choice_pressed(0))
	_buttons_container.add_child(_choice_button_a)

	_choice_button_b = Button.new()
	_choice_button_b.text = "FIGHT"
	_choice_button_b.custom_minimum_size = Vector2(360, 96)
	UiPalette.style_button(_choice_button_b, false)
	_choice_button_b.pressed.connect(func() -> void: _on_choice_pressed(1))
	_buttons_container.add_child(_choice_button_b)


## Display Market Crash weather notification.
func show_crash(duration_minutes: float, multiplier: float, dollars_lost: float = 0.0, legacy_bonuses: Dictionary = {}) -> void:
	_current_event_id = EventDef.ID_CRASH
	_is_dilemma = false

	_eyebrow_label.text = EventDef.get_eyebrow(_current_event_id)
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_headline_label.text = EventDef.get_title(_current_event_id)
	_headline_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_description_label.text = EventDef.get_description(_current_event_id)

	var penalty_pct: int = 100 - int(multiplier * 100.0)
	_impact_label.text = "PROPERTY CAPITAL: %d%% (−%d%% Penalty)" % [int(multiplier * 100.0), penalty_pct]
	_impact_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)

	var detail_lines: Array[String] = []
	var dur_str: String = "%.1f" % duration_minutes if duration_minutes < 1.0 or fmod(duration_minutes, 1.0) != 0.0 else "%d" % int(duration_minutes)
	detail_lines.append("⏱️ Duration: %s Active Minutes" % dur_str)
	detail_lines.append("🛡️ Hourly Wages: 100% UNAFFECTED (Crash-Proof)")

	var hedging_bonus: float = float(legacy_bonuses.get("hedging_bonus", 0.0))
	var dur_shave: float = float(legacy_bonuses.get("duration_reduction_pct", 0.0))
	if hedging_bonus > 0.0 or dur_shave > 0.0:
		var bonus_parts: Array[String] = []
		if hedging_bonus > 0.0:
			bonus_parts.append("+%d%% Hedged Income" % int(hedging_bonus * 100.0))
		if dur_shave > 0.0:
			bonus_parts.append("−%d%% Duration Shaved" % int(dur_shave * 100.0))
		detail_lines.append("💼 Legacy Mitigations: %s" % " · ".join(bonus_parts))

	if dollars_lost > 0.0:
		detail_lines.append("📉 Capital Lost So Far: −%s" % Money.of(dollars_lost).display_cash())

	_detail_label.text = "\n".join(detail_lines)
	_detail_label.add_theme_color_override("font_color", UiPalette.NAVY)

	_narrator_label.text = EventDef.get_narrator_quote(_current_event_id)

	_single_button.visible = true
	_single_button.text = "WEATHER THE STORM"
	UiPalette.style_button(_single_button, false)
	_choice_button_a.visible = false
	_choice_button_b.visible = false

	visible = true


## Display The Audit dilemma choice.
func show_audit(data: Dictionary) -> void:
	_current_event_id = EventDef.ID_AUDIT
	_is_dilemma = true

	_eyebrow_label.text = EventDef.get_eyebrow(_current_event_id)
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_headline_label.text = EventDef.get_title(_current_event_id)
	_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_description_label.text = EventDef.get_description(_current_event_id)

	var has_legislators: bool = data.get("has_enough_legislators", false)
	var leg_units: int = data.get("leg_units", 0)
	var threshold: int = data.get("leg_threshold", 1)

	if has_legislators:
		_impact_label.text = "LEGISLATIVE ASSETS: %d OWNED" % leg_units
		_impact_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
		_detail_label.text = "✓ Sufficient influence to dissolve all audit inquiries with zero penalty."
		_detail_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
	else:
		_impact_label.text = "LEGISLATIVE ASSETS: %d OWNED (%d REQUIRED)" % [leg_units, threshold]
		_impact_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
		_detail_label.text = "✗ Lack of representation will result in 3× treble damages if contested."
		_detail_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)

	_narrator_label.text = EventDef.get_narrator_quote(_current_event_id)

	_single_button.visible = false
	_choice_button_a.visible = true
	_choice_button_b.visible = true

	var settle_cost: float = data.get("settle_cost", 100.0)
	_choice_button_a.text = "SETTLE · %s" % Money.of(settle_cost).display()
	UiPalette.style_blue_button(_choice_button_a)

	if has_legislators:
		_choice_button_b.text = "FIGHT · FREE ($0)"
		UiPalette.style_button(_choice_button_b, false)
	else:
		var penalty: float = data.get("fight_penalty", 300.0)
		_choice_button_b.text = "FIGHT · %s" % Money.of(penalty).display()
		UiPalette.style_button(_choice_button_b, true)

	visible = true


## Display The Windfall grant card.
func show_windfall(amount: float) -> void:
	_current_event_id = EventDef.ID_WINDFALL
	_is_dilemma = false

	_eyebrow_label.text = EventDef.get_eyebrow(_current_event_id)
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
	_headline_label.text = EventDef.get_title(_current_event_id)
	_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_description_label.text = EventDef.get_description(_current_event_id)

	_impact_label.text = "+%s" % Money.of(amount).display()
	_impact_label.add_theme_color_override("font_color", UiPalette.DARK_MONEY_GREEN)
	_detail_label.text = "Estate disbursement directly credited to family treasury."
	_detail_label.add_theme_color_override("font_color", UiPalette.NAVY)

	_narrator_label.text = EventDef.get_narrator_quote(_current_event_id)

	_single_button.visible = true
	_single_button.text = "COLLECT INHERITANCE"
	UiPalette.style_button(_single_button, false)
	_choice_button_a.visible = false
	_choice_button_b.visible = false

	visible = true


func _on_single_button_pressed() -> void:
	visible = false
	dismissed.emit()


func _on_choice_pressed(choice_index: int) -> void:
	visible = false
	choice_selected.emit(choice_index)
