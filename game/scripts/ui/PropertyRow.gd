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
## The generation's reached epoch — the highest staffer tier any property may be hired
## or upgraded to right now. Read live so the hire button unlocks the moment a new
## civilization is contacted (EpochState.current_tier).
var _epoch: EpochState
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

## Time constant (seconds) for the cycle bar to ease up to a rush-jumped target.
## A rush jumps the true progress forward in a discrete step (and held rushes fire
## several times a second); easing toward that target instead of snapping to it
## makes a held rush read as smooth acceleration rather than a stutter of jumps.
const RUSH_CATCHUP_TAU := 0.12
## Tracks the current fill color so we only rebuild the stylebox on a change, not
## every frame (the same approach FrenzyBar uses for its burn-color swap).
var _showing_held_rush := false

# Both action buttons lay their two pieces of text out the same way: a left-aligned
# label and a right-aligned label sharing one vertically-centered row (Tim 2026-06-17).
# The buy button shows "BUY ×N" on the left and the cost on the right; the hire button
# shows the verb/staffer on the left and the cost/tier on the right. The font is sized
# to fill this fixed row height — see _add_split_button_labels.
const BUTTON_ROW_HEIGHT := 80
const BUTTON_LABEL_FONT_SIZE := 34

var _manager_circle: ManagerCircle
var _name_label: Label
var _income_label: Label
var _tap_button: Button
var _cycle_bar: ProgressBar
var _milestone_bar: ProgressBar
var _milestone_label: Label
var _buy_button: Button
var _buy_caption_label: Label
var _buy_cost_label: Label
var _hire_button: Button
var _hire_left_label: Label
var _hire_cost_label: Label

## Which hire-button look is currently applied, so the stylebox is only rebuilt when
## the state flips, not every frame. -1 = not yet applied, 0 = action (HIRE/UPGRADE,
## normal mustard), 1 = fully-staffed-for-now (faint green, disabled).
var _hire_style_applied := -1

## Tracks which ownership look is currently applied so the panel/start-button
## styleboxes are only rebuilt when ownership flips, not every frame.
## -1 = not yet applied, 0 = owned (normal), 1 = unowned (gray).
var _ownership_style_applied := -1


## Call before adding to the tree.
func setup(p_index: int, prop: PropertyState, economy: EconomyState, frenzy: FrenzyState, epoch: EpochState) -> void:
	prop_index = p_index
	_prop = prop
	_economy = economy
	_frenzy = frenzy
	_epoch = epoch


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
	# Darker green than the standard money-green, plus a same-color outline for faux
	# weight (Tim's call: the per-cycle payout should read darker and bolder). The
	# outline is the project-wide bold trick used until real bold fonts arrive in M3.
	var income_green := UiPalette.MONEY_GREEN.darkened(0.4)
	_income_label.add_theme_color_override("font_color", income_green)
	_income_label.add_theme_color_override("font_outline_color", income_green)
	_income_label.add_theme_constant_override("outline_size", 2)
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
	_buy_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_buy_button, true)  # red: buying is a spend action (§8)
	_buy_button.pressed.connect(func() -> void: buy_requested.emit(prop_index, _buy_mode))
	var buy_labels := _add_split_button_labels(_buy_button)
	_buy_caption_label = buy_labels[0]
	_buy_cost_label = buy_labels[1]
	button_line.add_child(_buy_button)

	_hire_button = Button.new()
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hire_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_hire_button, false)
	_hire_button.pressed.connect(func() -> void: hire_requested.emit(prop_index))
	var hire_labels := _add_split_button_labels(_hire_button)
	_hire_left_label = hire_labels[0]
	_hire_cost_label = hire_labels[1]
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
	# Ladder visibility (Tim, 2026-06-16): show every rung the player owns, plus every
	# rung they can already afford one unit of (buy button live), plus exactly the
	# single cheapest rung they cannot yet afford (grayed, a peek at what's next).
	# Everything beyond that one peek stays hidden. An invisible child takes no space in
	# the VBox, so the list grows as the player's reach grows.
	var can_afford_one := _economy.cash >= _prop.get_bulk_cost(1)
	visible = _prop.units_owned > 0 \
			or can_afford_one \
			or prop_index == _economy.get_cheapest_unaffordable_unowned_index()

	var config := _prop.config as PropertyConfig
	_name_label.text = "%s  ×%d" % [config.display_name, _prop.units_owned]

	# A rung the player owns no units of yet gets a drab gray "locked" look; once a
	# unit is bought it switches to the normal cream styling (applied on change).
	var owned := _prop.units_owned > 0
	_apply_ownership_styling(owned)

	# Keep the portrait circle square and as tall as this top section: its height is
	# already stretched to the section by the layout, so we just match the width to it.
	# The staffer's NAME now comes from EpochCatalog by the property's current tier (the
	# alien re-skin), not the vestigial .tres field, so the portrait initial tracks the
	# tier (e.g. Earth "ATM Technician" → Luminari "Photon Teller").
	_manager_circle.custom_minimum_size.x = _manager_circle.size.y
	var staffer := EpochCatalog.staffer_name(_prop.staff_tier, prop_index)
	_manager_circle.set_state(_prop.is_staffed, config.manager_portrait, staffer, owned)
	# Income readout. For an OWNED rung: the cash paid each time the bar fills (per cycle),
	# lit by the live frenzy multiplier so it matches what the player actually receives.
	# For an UNOWNED rung: the per-cycle value of a SINGLE unit, drawn dark gray (see
	# _apply_ownership_styling), so the player can see what the next tier is worth before
	# buying in (Tim 2026-06-17).
	if owned:
		_income_label.text = Money.of(_prop.get_income_per_cycle() * _frenzy.get_multiplier()).display() + "/cycle"
	else:
		_income_label.text = Money.of(_prop.get_single_unit_income_per_cycle()).display() + "/cycle"

	# The tap verb mirrors Spec §4: START an idle cycle, RUSH a running one.
	# While the button is held the cycle auto-restarts every completion, briefly going
	# idle between pulses; without this guard the label would flicker START→RUSH each
	# cycle. So a held button stays "RUSH" for the whole hold and only re-evaluates to
	# START/RUSH once the player lets go.
	if _prop.units_owned == 0:
		_tap_button.text = "—"
		_tap_button.disabled = true
	elif _tap_button.button_pressed:
		_tap_button.text = "RUSH"
		_tap_button.disabled = false
	elif _prop.is_cycle_running:
		_tap_button.text = "RUSH"
		_tap_button.disabled = false
	else:
		_tap_button.text = "START"
		_tap_button.disabled = false

	# Smooth, constant-velocity cycle bar (see _displayed_cycle_fraction above). Measured
	# against the EFFECTIVE (sped-up) cycle length so the bar still fills all the way to the
	# right once the Legacy "Efficiency Experts" upgrade shortens the real cycle — it just
	# fills faster (Tim 2026-06-17). Measuring against the raw length capped the fill at
	# 1 / cycle_speed_multiplier, so it stopped short of the right edge.
	var effective_length := _prop.get_effective_cycle_length()
	var true_fraction := _prop.cycle_progress / effective_length if effective_length > 0.0 else 0.0
	if not _prop.is_cycle_running or _prop.units_owned == 0:
		# Idle or empty: nothing is advancing, so just mirror the true value exactly.
		_displayed_cycle_fraction = true_fraction
	elif true_fraction < _last_true_cycle_fraction:
		# The cycle just completed and restarted — snap back so the bar refills from
		# the start rather than sliding backward.
		_displayed_cycle_fraction = true_fraction
	else:
		# Running: advance at the real fill rate. If the true progress has jumped
		# ahead of that prediction — a rush, or several per second while the rush
		# button is held — ease the bar UP toward it instead of snapping, so a held
		# rush reads as smooth acceleration rather than a stutter of discrete jumps.
		var advanced := _displayed_cycle_fraction + delta / effective_length
		if true_fraction > advanced:
			var catchup := 1.0 - exp(-delta / RUSH_CATCHUP_TAU)
			_displayed_cycle_fraction = clampf(lerpf(advanced, true_fraction, catchup), 0.0, 1.0)
		else:
			_displayed_cycle_fraction = clampf(advanced, 0.0, 1.0)
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
	_refresh_hire_button()


## Swap the cycle bar's fill between its normal green and a brighter green. Only on
## change — rebuilding the stylebox every frame would be wasteful (same pattern as
## FrenzyBar's burn-color swap).
func _set_cycle_highlight(active: bool) -> void:
	if active == _showing_held_rush:
		return
	_showing_held_rush = active
	var fill := UiPalette.MONEY_GREEN.lightened(HELD_RUSH_LIGHTEN) if active else UiPalette.MONEY_GREEN
	UiPalette.style_progress_bar(_cycle_bar, fill)


## Swap the row's panel background and START button between the normal cream look
## (owned) and the drab gray "locked" look (no units owned yet). Only rebuilds the
## styleboxes when the state actually flips, not every frame.
func _apply_ownership_styling(owned: bool) -> void:
	var want := 0 if owned else 1
	if want == _ownership_style_applied:
		return
	_ownership_style_applied = want
	if owned:
		add_theme_stylebox_override("panel", UiPalette.make_panel_style())
		UiPalette.style_button(_tap_button, false)
		# Owned: the bold dark-money-green per-cycle payout.
		var income_green := UiPalette.MONEY_GREEN.darkened(0.4)
		_income_label.add_theme_color_override("font_color", income_green)
		_income_label.add_theme_color_override("font_outline_color", income_green)
	else:
		add_theme_stylebox_override("panel", UiPalette.make_unowned_panel_style())
		UiPalette.style_unowned_button(_tap_button)
		# Unowned: a drab dark-gray single-unit preview, matching the locked row look.
		_income_label.add_theme_color_override("font_color", UiPalette.DARK_GRAY)
		_income_label.add_theme_color_override("font_outline_color", UiPalette.DARK_GRAY)


## Update the hire/upgrade/staffed button for the property's current staff tier and the
## reached epoch (the alien-staffing track, GDD §6). Three states:
##   • tier 0 → HIRE the Earth staffer (tier 1).
##   • a higher tier is unlocked by the reached epoch → UPGRADE to the next alien tier.
##   • staffed at the best tier this epoch allows → show the staffer name + tier,
##     disabled and faint green, until the next first contact unlocks a better tier.
func _refresh_hire_button() -> void:
	var tier := _prop.staff_tier
	# Highest tier hireable right now: the reached epoch, capped at the defined epochs.
	var max_tier := mini(_epoch.current_tier, EpochCatalog.tier_count())

	if tier >= 1 and tier >= max_tier:
		# Fully staffed for this epoch — nothing to upgrade until the next first contact.
		_apply_hire_styling(true)
		_hire_left_label.text = EpochCatalog.staffer_name(tier, prop_index).to_upper()
		_hire_cost_label.text = "TIER %d" % tier
		_hire_button.disabled = true
		# The faint-green staffed plate keeps full navy text, matching style_button's look.
		_set_split_label_color(_hire_left_label, _hire_cost_label, UiPalette.NAVY)
		return

	# Otherwise a tier is available to buy: tier 1 (HIRE) from unstaffed, or the next
	# alien tier (UPGRADE) on an already-staffed property after a fresh contact.
	_apply_hire_styling(false)
	var next_tier := tier + 1
	var cost := _economy.get_staff_cost(prop_index, next_tier)
	var verb := "HIRE" if tier == 0 else "UPGRADE"
	_hire_left_label.text = verb
	_hire_cost_label.text = Money.of(cost).display()
	# A property with no units can't be staffed yet — a staffer needs something to run.
	_hire_button.disabled = _economy.cash < cost or _prop.units_owned == 0
	# Navy text on the live mustard plate, dimmed to match the disabled cream plate.
	var hire_color := Color(UiPalette.NAVY, 0.45) if _hire_button.disabled else UiPalette.NAVY
	_set_split_label_color(_hire_left_label, _hire_cost_label, hire_color)


## Swap the hire button between the normal action look (HIRE/UPGRADE) and the faint-
## green "staffed for now" look. Only rebuilds the stylebox when the state flips.
func _apply_hire_styling(staffed: bool) -> void:
	var want := 1 if staffed else 0
	if want == _hire_style_applied:
		return
	_hire_style_applied = want
	if staffed:
		var staffed_style := UiPalette.make_staffed_style()
		_hire_button.add_theme_stylebox_override("disabled", staffed_style)
		_hire_button.add_theme_stylebox_override("normal", staffed_style)
		_hire_button.add_theme_color_override("font_disabled_color", UiPalette.NAVY)
	else:
		UiPalette.style_button(_hire_button, false)


## Overlay an action button with two labels — one left-aligned, one right-aligned —
## sharing a single vertically-centered row that fills the button's fixed height. A
## Button only draws one centered string, so to put the count on the left and the cost
## on the right we add our own labels on top of it. The overlay ignores the mouse so
## taps still reach the button underneath. Returns [left_label, right_label].
func _add_split_button_labels(button: Button) -> Array:
	# Fill the button, inset by the plate's content margin so the text clears the border.
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 12)
	overlay.add_theme_constant_override("margin_right", 12)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(overlay)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)

	var left := Label.new()
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_FILL
	left.clip_text = true  # if the two strings ever collide, the caption yields, never the cost
	left.add_theme_font_size_override("font_size", BUTTON_LABEL_FONT_SIZE)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var right := Label.new()
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.size_flags_vertical = Control.SIZE_FILL
	right.add_theme_font_size_override("font_size", BUTTON_LABEL_FONT_SIZE)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	return [left, right]


## Tint both of a split button's labels the one color. The overlay labels aren't the
## button's own text, so they don't follow its font_color/disabled theme overrides —
## we set their color to match the button's current state by hand.
func _set_split_label_color(left: Label, right: Label, color: Color) -> void:
	left.add_theme_color_override("font_color", color)
	right.add_theme_color_override("font_color", color)


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
		_buy_caption_label.text = "MAX"
		_buy_cost_label.text = Money.of(_prop.get_bulk_cost(1)).display()
		_buy_button.disabled = true
		_set_buy_label_colors()
		return

	var cost := _prop.get_bulk_cost(count)
	_buy_caption_label.text = caption
	_buy_cost_label.text = Money.of(cost).display()
	_buy_button.disabled = _economy.cash < cost
	_set_buy_label_colors()


## Color the buy button's labels to match its state: the action pale-gold when live,
## or the dimmed navy of style_button's disabled plate when it can't be afforded.
func _set_buy_label_colors() -> void:
	if _buy_button.disabled:
		_set_split_label_color(_buy_caption_label, _buy_cost_label, Color(UiPalette.NAVY, 0.45))
	else:
		_set_split_label_color(_buy_caption_label, _buy_cost_label, UiPalette.PALE_GOLD)
