class_name PropertyRow
extends PanelContainer

# One rung of the property ladder on the Main screen (M1 brief §4): name,
# owned count, live cycle progress, milestone slider, and the buy/hire
# buttons. Pure view: it reads game state every frame and emits a signal
# for every action — all mutations happen in Main → GameState.

enum BuyMode { ONE, TEN, TO_MILESTONE, MAX }

signal buy_requested(prop_index: int, mode: BuyMode)
signal tap_requested(prop_index: int)
signal hire_requested(prop_index: int)

var prop_index: int = -1

var _prop: PropertyState
var _economy: EconomyState

var _name_label: Label
var _income_label: Label
var _tap_button: Button
var _cycle_bar: ProgressBar
var _milestone_bar: ProgressBar
var _milestone_label: Label
var _buy_one_button: Button
var _buy_ten_button: Button
var _buy_milestone_button: Button
var _buy_max_button: Button
var _hire_button: Button


## Call before adding to the tree.
func setup(p_index: int, prop: PropertyState, economy: EconomyState) -> void:
	prop_index = p_index
	_prop = prop
	_economy = economy


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPalette.make_panel_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	# Header: name ×count on the left, income/sec on the right.
	var header := HBoxContainer.new()
	column.add_child(header)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)

	_income_label = Label.new()
	_income_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_income_label.add_theme_font_size_override("font_size", 30)
	header.add_child(_income_label)

	# Cycle line: the tap verb button + live cycle progress (Style Guide §9:
	# the "spin" is the real cycle progress; placeholder bar until hero art).
	var cycle_line := HBoxContainer.new()
	cycle_line.add_theme_constant_override("separation", 10)
	column.add_child(cycle_line)

	_tap_button = Button.new()
	_tap_button.custom_minimum_size = Vector2(150, 0)
	_tap_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_tap_button, false)
	_tap_button.pressed.connect(func() -> void: tap_requested.emit(prop_index))
	cycle_line.add_child(_tap_button)

	_cycle_bar = ProgressBar.new()
	_cycle_bar.min_value = 0.0
	_cycle_bar.max_value = 1.0
	_cycle_bar.show_percentage = false
	_cycle_bar.custom_minimum_size = Vector2(0, 26)
	_cycle_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cycle_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_progress_bar(_cycle_bar, UiPalette.MONEY_GREEN)
	cycle_line.add_child(_cycle_bar)

	# Milestone slider: min = last milestone, max = next (Spec §3.5 — "the
	# pile can push me over 40" is part of the return spike).
	var milestone_line := HBoxContainer.new()
	milestone_line.add_theme_constant_override("separation", 10)
	column.add_child(milestone_line)

	_milestone_bar = ProgressBar.new()
	_milestone_bar.show_percentage = false
	_milestone_bar.custom_minimum_size = Vector2(0, 18)
	_milestone_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_milestone_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_progress_bar(_milestone_bar, UiPalette.NAVY)
	milestone_line.add_child(_milestone_bar)

	_milestone_label = Label.new()
	_milestone_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_milestone_label.add_theme_font_size_override("font_size", 22)
	milestone_line.add_child(_milestone_label)

	# Buy / hire buttons (bulk-buy is mandatory — GDD §3.1).
	var button_line := HBoxContainer.new()
	button_line.add_theme_constant_override("separation", 8)
	column.add_child(button_line)

	_buy_one_button = _make_buy_button(button_line, BuyMode.ONE)
	_buy_ten_button = _make_buy_button(button_line, BuyMode.TEN)
	_buy_milestone_button = _make_buy_button(button_line, BuyMode.TO_MILESTONE)
	_buy_max_button = _make_buy_button(button_line, BuyMode.MAX)

	_hire_button = Button.new()
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hire_button.add_theme_font_size_override("font_size", 20)
	UiPalette.style_button(_hire_button, false)
	_hire_button.pressed.connect(func() -> void: hire_requested.emit(prop_index))
	button_line.add_child(_hire_button)


func _make_buy_button(parent: Container, mode: BuyMode) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	UiPalette.style_button(button, true)  # red: buying is a spend action (§8)
	button.pressed.connect(func() -> void: buy_requested.emit(prop_index, mode))
	parent.add_child(button)
	return button


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var config := _prop.config as PropertyConfig
	_name_label.text = "%s  ×%d" % [config.display_name, _prop.units_owned]
	_income_label.text = Money.of(_prop.get_income_per_sec()).display() + "/s"

	# The tap verb mirrors Spec §4: START an idle cycle, RUSH a running one.
	if _prop.units_owned == 0:
		_tap_button.text = "—"
		_tap_button.disabled = true
	elif _prop.is_cycle_running:
		_tap_button.text = "RUSH"
		_tap_button.disabled = false
	else:
		_tap_button.text = "START"
		_tap_button.disabled = false

	_cycle_bar.value = _prop.cycle_progress / _prop.cycle_length if _prop.cycle_length > 0.0 else 0.0

	# Milestone slider runs from the last crossed milestone to the next one.
	var next_milestone := _prop.get_next_milestone_count()
	var last_milestone := next_milestone / 2 if _prop.units_owned >= 20 else 0
	_milestone_bar.min_value = last_milestone
	_milestone_bar.max_value = next_milestone
	_milestone_bar.value = _prop.units_owned
	_milestone_label.text = "%d / %d" % [_prop.units_owned, next_milestone]

	var cash := _economy.cash
	_refresh_buy_button(_buy_one_button, "+1", 1, cash)
	_refresh_buy_button(_buy_ten_button, "+10", 10, cash)
	_refresh_buy_button(_buy_milestone_button, "+MS", next_milestone - _prop.units_owned, cash)

	var max_count := _prop.get_max_affordable(cash)
	if max_count > 0:
		_buy_max_button.text = "MAX ×%d\n%s" % [
			max_count, Money.of(_prop.get_bulk_cost(max_count)).display()
		]
		_buy_max_button.disabled = false
	else:
		_buy_max_button.text = "MAX\n—"
		_buy_max_button.disabled = true

	if _prop.is_staffed:
		_hire_button.text = "STAFFED"
		_hire_button.disabled = true
	else:
		var staff_cost := _prop.get_staff_cost()
		_hire_button.text = "HIRE\n%s" % Money.of(staff_cost).display()
		_hire_button.disabled = cash < staff_cost


func _refresh_buy_button(button: Button, caption: String, count: int, cash: float) -> void:
	if count <= 0:
		button.text = "%s\n—" % caption
		button.disabled = true
		return
	var cost := _prop.get_bulk_cost(count)
	button.text = "%s\n%s" % [caption, Money.of(cost).display()]
	button.disabled = cash < cost
