class_name PropertyRow
extends PanelContainer

# One rung of the property ladder on the Main screen (M1 brief §4): name,
# owned count, live cycle progress, milestone slider, and the buy/hire
# buttons. Pure view: it reads game state every frame and emits a signal
# for every action — all mutations happen in Main → GameState.
#
# Each row has a single buy button; what it buys is set by the global
# buy-mode toggle on the Main screen (×1 / ×10 / ×100 / MAX).

enum BuyMode { ONE, TEN, HUNDRED, MAX }

signal buy_requested(prop_index: int, mode: BuyMode)
signal tap_requested(prop_index: int)
signal hold_rush_requested(prop_index: int)
signal hire_requested(prop_index: int)

var prop_index: int = -1

var _prop: PropertyState
var _economy: EconomyState
var _frenzy: FrenzyState
var _buy_mode: BuyMode = BuyMode.ONE

## Accumulates held-down time on the tap button to pace auto-rush pulses.
var _hold_accumulator := 0.0

# The cycle progress bar is driven by our own smooth, per-frame prediction rather
# than the raw logic value. Logic ticks at LOGIC_HZ (10 Hz) while rendering runs
# every frame (~60 Hz), so reading cycle_progress directly makes the bar lurch in
# ~10 steps/sec — jumpy and staccato. Instead we advance a displayed fraction at
# real time (delta / cycle_length each frame, the true fill rate) and only re-sync
# to the logic state on the events that prediction can't see: a rush jumping the
# cycle forward, or the cycle completing and restarting. The result is constant-
# velocity motion at the full frame rate.
var _displayed_cycle_fraction := 0.0

## Last frame's true cycle fraction. Cycle progress only ever decreases when a
## cycle completes and restarts, so a drop tells us to snap the bar back to zero.
var _last_true_cycle_fraction := 0.0

## While the player holds the rush button, the cycle bar fills in a brighter green
## to signal the active push. How far the green is lightened toward white (0 = none).
const HELD_RUSH_LIGHTEN := 0.35
## Tracks the current fill color so we only rebuild the stylebox on a change, not
## every frame (the same approach FrenzyBar uses for its burn-color swap).
var _showing_held_rush := false

var _manager_circle: ManagerCircle
var _name_label: Label
var _income_label: Label
var _tap_button: Button
var _cycle_bar: ProgressBar
var _milestone_bar: ProgressBar
var _milestone_label: Label
var _buy_button: Button
var _hire_button: Button

## Set once when the property becomes staffed, so the faint-green restyle is applied
## a single time rather than every frame (staffing is permanent).
var _hire_staffed_styled := false


## Call before adding to the tree.
func setup(p_index: int, prop: PropertyState, economy: EconomyState, frenzy: FrenzyState) -> void:
	prop_index = p_index
	_prop = prop
	_economy = economy
	_frenzy = frenzy


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPalette.make_panel_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	# Top of the row: a round manager-portrait slot on the left, and to its right a
	# section holding the title and the cycle progress bar. The circle is sized in
	# _refresh to be a square as tall as that whole section (title + progress bar
	# combined), so it reads as one portrait spanning both lines.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	column.add_child(top_row)

	_manager_circle = ManagerCircle.new()
	_manager_circle.size_flags_vertical = Control.SIZE_FILL  # stretch to the section's height
	top_row.add_child(_manager_circle)

	var top_section := VBoxContainer.new()
	top_section.add_theme_constant_override("separation", 6)
	top_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_section)

	# Header: name ×count on the left, income/sec on the right.
	var header := HBoxContainer.new()
	top_section.add_child(header)

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
	top_section.add_child(cycle_line)

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

	# Buy / hire buttons (bulk-buy is mandatory — GDD §3.1). The buy button's
	# count follows the global buy-mode toggle.
	var button_line := HBoxContainer.new()
	button_line.add_theme_constant_override("separation", 8)
	column.add_child(button_line)

	_buy_button = Button.new()
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.size_flags_stretch_ratio = 2.0  # buy gets twice the hire button's width
	_buy_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_buy_button, true)  # red: buying is a spend action (§8)
	_buy_button.pressed.connect(func() -> void: buy_requested.emit(prop_index, _buy_mode))
	button_line.add_child(_buy_button)

	_hire_button = Button.new()
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hire_button.add_theme_font_size_override("font_size", 20)
	UiPalette.style_button(_hire_button, false)
	_hire_button.pressed.connect(func() -> void: hire_requested.emit(prop_index))
	button_line.add_child(_hire_button)

	# Let a swipe that lands anywhere on the row (the panel, labels, or progress
	# bars — anything that isn't one of the buttons above) scroll the ladder,
	# rather than being swallowed by the row. See UiPalette.allow_scroll_drag_through.
	UiPalette.allow_scroll_drag_through(self)


## Called by Main when the player cycles the global buy-mode toggle.
func set_buy_mode(mode: BuyMode) -> void:
	_buy_mode = mode


func _process(delta: float) -> void:
	_refresh(delta)
	_pump_held_rush(delta)


## Holding the start/rush button continually drives the property at the tuning
## hold rate (UI notes §2): an idle cycle is STARTED on the first held pulse,
## then a running cycle is RUSHED on every pulse after. Both are gated behind the
## same accumulator, so a quick tap accrues no pulse and stays a plain single
## action (which still fires on release via the button's pressed signal).
func _pump_held_rush(delta: float) -> void:
	if not _tap_button.button_pressed or _prop.units_owned == 0:
		_hold_accumulator = 0.0
		return
	_hold_accumulator += delta
	var pulse_interval := 1.0 / _prop.tuning.hold_rush_per_second
	while _hold_accumulator >= pulse_interval:
		_hold_accumulator -= pulse_interval
		if _prop.is_cycle_running:
			hold_rush_requested.emit(prop_index)
		else:
			# Idle: the held pulse starts the cycle. Signals are synchronous, so
			# the property is running by the next pulse/frame and rushes follow.
			tap_requested.emit(prop_index)


func _refresh(delta: float) -> void:
	# Ladder visibility: show only owned rungs plus the next rung up. A row is shown
	# if the player owns at least one unit of it, or it is the next property above the
	# highest they own (the one available to buy). Everything higher stays hidden until
	# a purchase unlocks it. An invisible child takes no space in the VBox, so the list
	# grows downward as the player climbs.
	visible = _prop.units_owned > 0 or prop_index == _economy.get_highest_owned_index() + 1

	var config := _prop.config as PropertyConfig
	_name_label.text = "%s  ×%d" % [config.display_name, _prop.units_owned]

	# Keep the portrait circle square and as tall as this top section: its height is
	# already stretched to the section by the layout, so we just match the width to it.
	_manager_circle.custom_minimum_size.x = _manager_circle.size.y
	_manager_circle.set_state(_prop.is_staffed, config.manager_portrait, config.staffer_name)
	# Show the cash paid out each time the bar fills (per cycle), so the figure on
	# screen matches what the player actually receives on a completion. During a
	# frenzy burn that payout is multiplied at point of payment (Spec §7), so the
	# readout lights up while the burn is active (multiplier is 1.0 when no burn).
	_income_label.text = Money.of(_prop.get_income_per_cycle() * _frenzy.get_multiplier()).display() + "/cycle"

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

	# Smooth, constant-velocity cycle bar (see _displayed_cycle_fraction above).
	var true_fraction := _prop.cycle_progress / _prop.cycle_length if _prop.cycle_length > 0.0 else 0.0
	if not _prop.is_cycle_running or _prop.units_owned == 0:
		# Idle or empty: nothing is advancing, so just mirror the true value exactly.
		_displayed_cycle_fraction = true_fraction
	elif true_fraction < _last_true_cycle_fraction:
		# The cycle just completed and restarted — snap back so the bar refills from
		# the start rather than sliding backward.
		_displayed_cycle_fraction = true_fraction
	else:
		# Running: advance at the real fill rate, and never let the bar lag behind the
		# true value. taking the max means a rush (which jumps cycle_progress forward)
		# pulls the bar up immediately instead of crawling to catch up.
		var advanced := _displayed_cycle_fraction + delta / _prop.cycle_length
		_displayed_cycle_fraction = clampf(maxf(advanced, true_fraction), 0.0, 1.0)
	_last_true_cycle_fraction = true_fraction
	_cycle_bar.value = _displayed_cycle_fraction

	# Brighter green while the rush button is held — a live cue that the player's
	# holding is actively driving this property's cycle.
	var rush_held := _tap_button.button_pressed and _prop.units_owned > 0
	_set_cycle_highlight(rush_held)

	# Milestone slider runs from the last crossed milestone to the next one.
	var next_milestone := _prop.get_next_milestone_count()
	var last_milestone := next_milestone / 2 if _prop.units_owned >= 20 else 0
	_milestone_bar.min_value = last_milestone
	_milestone_bar.max_value = next_milestone
	_milestone_bar.value = _prop.units_owned
	_milestone_label.text = "%d / %d" % [_prop.units_owned, next_milestone]

	_refresh_buy_button()

	var cash := _economy.cash
	if _prop.is_staffed:
		_hire_button.text = "STAFFED"
		_hire_button.disabled = true
		if not _hire_staffed_styled:
			# Staffing is permanent; recolor the button a faint green once to signal
			# the property is automated (instead of the default disabled cream).
			var staffed_style := UiPalette.make_staffed_style()
			_hire_button.add_theme_stylebox_override("disabled", staffed_style)
			_hire_button.add_theme_stylebox_override("normal", staffed_style)
			_hire_button.add_theme_color_override("font_disabled_color", UiPalette.NAVY)
			_hire_staffed_styled = true
	else:
		var staff_cost := _prop.get_staff_cost()
		_hire_button.text = "HIRE\n%s" % Money.of(staff_cost).display()
		_hire_button.disabled = cash < staff_cost


## Swap the cycle bar's fill between its normal green and a brighter green. Only on
## change — rebuilding the stylebox every frame would be wasteful (same pattern as
## FrenzyBar's burn-color swap).
func _set_cycle_highlight(active: bool) -> void:
	if active == _showing_held_rush:
		return
	_showing_held_rush = active
	var fill := UiPalette.MONEY_GREEN.lightened(HELD_RUSH_LIGHTEN) if active else UiPalette.MONEY_GREEN
	UiPalette.style_progress_bar(_cycle_bar, fill)


## Update the buy button's caption, cost, and enabled state for the
## current global buy mode.
func _refresh_buy_button() -> void:
	var count := 0
	var caption := ""
	match _buy_mode:
		BuyMode.ONE:
			count = 1
			caption = "BUY ×1"
		BuyMode.TEN:
			count = 10
			caption = "BUY ×10"
		BuyMode.HUNDRED:
			count = 100
			caption = "BUY ×100"
		BuyMode.MAX:
			count = _prop.get_max_affordable(_economy.cash)
			caption = "MAX ×%d" % count

	if count <= 0:
		# MAX mode with nothing affordable yet: show the next single unit's cost so
		# the player can see how close they are, instead of a blank "—".
		_buy_button.text = "MAX\n%s" % Money.of(_prop.get_bulk_cost(1)).display()
		_buy_button.disabled = true
		return

	var cost := _prop.get_bulk_cost(count)
	_buy_button.text = "%s\n%s" % [caption, Money.of(cost).display()]
	_buy_button.disabled = _economy.cash < cost
