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
## Emitted when the staff button is pressed in its LEVEL UP state — i.e. the property is
## already staffed at the best tier this epoch allows, so the button now buys a within-epoch
## staff level (the continuous upgrade sink, GDD §6.1) instead of a tier hire/upgrade.
signal level_up_requested(prop_index: int)

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

## Hold-to-buy pacing on the BUY button (Tim, 2026-06-22), mirroring the Estate shop: a
## quick tap buys once; holding auto-repeats after a short initial delay so the player can
## watch the cost climb and release when they want to stop.
const BUY_HOLD_INITIAL_DELAY := 0.45
const BUY_HOLD_REPEAT_INTERVAL := 0.35
var _buy_hold_accumulator := 0.0
var _buy_hold_repeating := false

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

## While the player holds the rush button, the cycle bar fills in a deeper, more vivid
## green to signal the active push (Tim, 2026-06-23 — was a lighter tint, now darker and
## more saturated so the push reads as "leaning in" rather than washing out).
## HELD_RUSH_DARKEN pulls the green toward black; HELD_RUSH_SATURATE scales its HSV
## saturation (1.0 = unchanged) so the deeper green still reads as green, not gray.
const HELD_RUSH_DARKEN := 0.18
const HELD_RUSH_SATURATE := 1.4

## Time constant (seconds) for the cycle bar to ease up to a rush-jumped target.
## A rush jumps the true progress forward in a discrete step (and held rushes fire
## several times a second); easing toward that target instead of snapping to it
## makes a held rush read as smooth acceleration rather than a stutter of jumps.
const RUSH_CATCHUP_TAU := 0.12

## Once a property's EFFECTIVE cycle is shorter than this (seconds), the cycle bar stops
## animating and is pinned solid-full, and its readout switches from "/cycle" to a steady
## "/sec" rate. Past this speed the bar would refill several times a second — a meaningless
## strobe at 60fps — so we instead show the property as a continuously-paying business
## (genre-standard, Tim 2026-06-25). This is a pure presentation / legibility threshold,
## NOT an economy value, so it lives here in the UI rather than in tuning.tres.
const SOLID_BAR_THRESHOLD_SEC := 0.25
## Which cycle-bar fill look is currently applied, so we only rebuild the stylebox on a
## change, not every frame (the same approach FrenzyBar uses for its burn-color swap):
##   0 = normal green (idle/running, rush available)
##   1 = brighter green (rush button held)
##   2 = calm blue (staffed and running itself — rush is no longer an option)
## -1 = not yet applied.
var _cycle_color_applied := -1

# Both action buttons lay their two pieces of text out the same way: a left-aligned
# label and a right-aligned label sharing one vertically-centered row (Tim 2026-06-17).
# The buy button shows "BUY ×N" on the left and the cost on the right; the hire button
# shows the verb/staffer on the left and the cost/tier on the right. The font is sized
# to fill this fixed row height — see _add_split_button_labels.
const BUTTON_ROW_HEIGHT := 80
const BUTTON_LABEL_FONT_SIZE := UiPalette.FONT_BUTTON
## Side length of the headshot icon that stands in for the word "HIRE"/"UPGRADE".
const HIRE_ICON_SIZE := 56

var _manager_circle: ManagerCircle
var _name_label: Label
var _income_label: Label
var _cycle_bar: ProgressBar
var _buy_button: Button
var _buy_caption_label: Label
var _buy_cost_label: Label
var _hire_button: Button
var _hire_left_label: Label
var _hire_cost_label: Label
## Small headshot icon shown on the hire button in place of the word "HIRE"/"UPGRADE"
## (Tim, 2026-06-22); hidden in the fully-staffed state, where the staffer name shows.
var _hire_icon: TextureRect

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

	# Top of the row: a round manager-portrait slot on the left, and to its right a section
	# holding the name, the cycle progress bar, AND the milestone (inventory count) bar. The
	# circle is sized in _refresh to be a square as tall as that whole section (all three
	# lines), so it reads as one tall portrait spanning them — and the milestone bar, now in
	# that section, lines up with the cycle bar's width instead of running the full row (Tim,
	# 2026-06-22).
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	column.add_child(top_row)

	_manager_circle = ManagerCircle.new()
	_manager_circle.size_flags_vertical = Control.SIZE_FILL  # stretch to the section's height
	# The portrait IS the start/rush control now (the old START button is gone): a single tap
	# starts an idle cycle (or rushes a running one); holding it auto-rushes (see _pump_held_rush).
	_manager_circle.pressed.connect(func() -> void: tap_requested.emit(prop_index))
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
	_name_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
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
	_income_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	header.add_child(_income_label)

	# Cycle line: live cycle progress (Style Guide §9: the "spin" is the real cycle
	# progress; placeholder bar until hero art). The old START/RUSH button is gone — the
	# portrait circle on the left is now the start/rush control (see ManagerCircle).
	_cycle_bar = ProgressBar.new()
	_cycle_bar.min_value = 0.0
	_cycle_bar.max_value = 1.0
	_cycle_bar.show_percentage = false
	_cycle_bar.custom_minimum_size = Vector2(0, 26)
	_cycle_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cycle_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_progress_bar(_cycle_bar, UiPalette.MONEY_GREEN)
	top_section.add_child(_cycle_bar)

	# Buy / hire buttons (bulk-buy is mandatory — GDD §3.1). The buy button's
	# count follows the global buy-mode toggle.
	var button_line := HBoxContainer.new()
	button_line.add_theme_constant_override("separation", 8)
	column.add_child(button_line)

	_buy_button = Button.new()
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Buy and hire each take half the panel width (default stretch ratio 1.0 on both).
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
	# The hire button does double duty (hire/upgrade a tier, then level up within the epoch),
	# so its single `pressed` is connected ONCE here and routed by state in _on_hire_pressed.
	# Reconnecting it per-state would stack handlers and fire the action twice.
	_hire_button.pressed.connect(_on_hire_pressed)
	var hire_labels := _add_split_button_labels(_hire_button)
	_hire_left_label = hire_labels[0]
	_hire_cost_label = hire_labels[1]

	# Headshot icon at the left of the hire button, standing in for the "HIRE"/"UPGRADE"
	# word (Tim, 2026-06-22). Reuses the white-authored headshot, tinted navy to match the
	# plate's text; hidden in the fully-staffed state (where the staffer name is shown).
	_hire_icon = TextureRect.new()
	_hire_icon.texture = ManagerCircle.HEADSHOT_TEX
	_hire_icon.custom_minimum_size = Vector2(HIRE_ICON_SIZE, HIRE_ICON_SIZE)
	_hire_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hire_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hire_icon.modulate = UiPalette.NAVY
	_hire_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hire_row := _hire_left_label.get_parent() as HBoxContainer
	hire_row.add_child(_hire_icon)
	hire_row.move_child(_hire_icon, 0)  # sit it before the (now empty) left label
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
	_pump_held_buy(delta)


## Holding the start/rush button continually drives the property at the tuning
## hold rate (UI notes §2): an idle cycle is STARTED on the first held pulse,
## then a running cycle is RUSHED on every pulse after. Both are gated behind the
## same accumulator, so a quick tap accrues no pulse and stays a plain single
## action (which still fires on release via the button's pressed signal).
func _pump_held_rush(delta: float) -> void:
	# is_held() is false whenever the portrait button is disabled (a locked rung, or an
	# automated property that is not the player's top one), so those simply never auto-rush.
	if not _manager_circle.is_held() or _prop.units_owned == 0:
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


## Holding the BUY button keeps purchasing on a calm cadence (hold-to-buy). A quick tap is
## handled by the button's own `pressed` signal (one purchase); this only adds the repeats
## while it stays held. Unaffordable pulses are skipped (the buy button disables itself), so
## a held button simply idles once the player runs out of cash rather than spamming failures.
func _pump_held_buy(delta: float) -> void:
	if not _buy_button.button_pressed:
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = false
		return
	_buy_hold_accumulator += delta
	var threshold := BUY_HOLD_REPEAT_INTERVAL if _buy_hold_repeating else BUY_HOLD_INITIAL_DELAY
	if _buy_hold_accumulator >= threshold:
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = true
		if not _buy_button.disabled:
			buy_requested.emit(prop_index, _buy_mode)


func _refresh(delta: float) -> void:
	# Ladder visibility (Tim, 2026-06-16): show every rung the player owns, plus every
	# rung they can already afford one unit of (buy button live), plus exactly the
	# single cheapest rung they cannot yet afford (grayed, a peek at what's next).
	# Everything beyond that one peek stays hidden. An invisible child takes no space in
	# the VBox, so the list grows as the player's reach grows.
	# A property still locked behind a later epoch never shows — not even as the grayed
	# peek rung. It is revealed only once First Contact opens its epoch (GDD §5.5 site 2).
	var current_tier := _epoch.current_tier
	var unlocked := _economy.is_property_unlocked(prop_index, current_tier)
	var can_afford_one := _economy.cash >= _prop.get_bulk_cost(1)
	visible = unlocked and ( \
			_prop.units_owned > 0 \
			or can_afford_one \
			or prop_index == _economy.get_cheapest_unaffordable_unowned_index(current_tier))

	var config := _prop.config as PropertyConfig
	# Name shows the owned count and, after the slash, the unit threshold of the next
	# milestone tier (the old progress bar's information, folded into the title — Tim,
	# 2026-06-29). Past the final milestone there is no next count, so we show "MAX".
	var next_milestone := _prop.get_next_milestone_count()
	if next_milestone <= 0:
		_name_label.text = "%s  ×%d / MAX" % [config.display_name, _prop.units_owned]
	else:
		_name_label.text = "%s  ×%d / %d" % [config.display_name, _prop.units_owned, next_milestone]

	# A rung the player owns no units of yet gets a drab gray "locked" look; once a
	# unit is bought it switches to the normal cream styling (applied on change).
	var owned := _prop.units_owned > 0
	_apply_ownership_styling(owned)

	# An unowned rung has no cycle to run, so the cycle bar is hidden until the player
	# owns at least one unit (Tim, 2026-06-28).
	_cycle_bar.visible = owned

	# Keep the portrait circle square and as tall as this top section: its height is already
	# stretched to the section by the layout, so we just match the width to it.
	_manager_circle.custom_minimum_size.x = _manager_circle.size.y

	# The portrait is the start/rush control (ManagerCircle). Decide its look and whether it
	# accepts input this frame:
	#   • LOCKED   — no units owned yet (drab, inert).
	#   • STAFFED  — automated; shows the property accent + staffer headshot. Interactive ONLY
	#                if it is the player's single highest-owned property — rush stays hands-on
	#                there, while every other automated property runs itself hands-off (GDD §6).
	#   • UNSTAFFED — owned but not automated; silver restart plate, always interactive.
	# The infinity icon shows whenever an interactive portrait is actively held (being rushed).
	var staffed := _prop.is_staffed
	var is_highest_owned := _economy.get_highest_owned_index() == prop_index
	var interactive := owned and (not staffed or is_highest_owned)
	var portrait_mode := ManagerCircle.PortraitMode.LOCKED
	if owned:
		portrait_mode = ManagerCircle.PortraitMode.STAFFED if staffed else ManagerCircle.PortraitMode.UNSTAFFED
	var show_rush_icon := interactive and _manager_circle.is_held()
	_manager_circle.set_state(
		portrait_mode, config.accent_color, config.manager_portrait, show_rush_icon, interactive
	)
	# Income readout. For an OWNED rung: the cash paid each time the bar fills (per cycle),
	# lit by the live frenzy multiplier so it matches what the player actually receives.
	# For an UNOWNED rung: the per-cycle value of a SINGLE unit, drawn dark gray (see
	# _apply_ownership_styling), so the player can see what the next tier is worth before
	# buying in (Tim 2026-06-17).
	# Effective (sped-up) cycle length drives both the readout below and the bar fill
	# further down. Once it drops below SOLID_BAR_THRESHOLD_SEC the property is paying so
	# fast that the bar can't meaningfully animate, so we treat it as "humming": pin the
	# bar solid (see further down) and quote a steady per-second rate instead of per-cycle.
	var effective_length := _prop.get_effective_cycle_length()
	var bar_is_solid := owned and _prop.is_cycle_running \
		and effective_length > 0.0 and effective_length < SOLID_BAR_THRESHOLD_SEC
	if owned:
		# get_income_per_cycle() already folds in the staffer and Family Fortune (Legacy)
		# multipliers; frenzy is applied live on top, matching what the player receives.
		var per_cycle := _prop.get_income_per_cycle() * _frenzy.get_multiplier()
		if bar_is_solid:
			# Derive the rate from the SAME per-cycle figure (not get_income_per_sec(),
			# which omits legacy + frenzy) so "/sec" stays consistent with "/cycle".
			_income_label.text = Money.of(per_cycle / effective_length).display() + "/sec"
		else:
			_income_label.text = Money.of(per_cycle).display() + "/cycle"
	else:
		_income_label.text = Money.of(_prop.get_single_unit_income_per_cycle()).display() + "/cycle"

	# Smooth, constant-velocity cycle bar (see _displayed_cycle_fraction above). Measured
	# against the EFFECTIVE (sped-up) cycle length so the bar still fills all the way to the
	# right once the Legacy "Efficiency Experts" upgrade shortens the real cycle — it just
	# fills faster (Tim 2026-06-17). Measuring against the raw length capped the fill at
	# 1 / cycle_speed_multiplier, so it stopped short of the right edge.
	var true_fraction := _prop.cycle_progress / effective_length if effective_length > 0.0 else 0.0
	if bar_is_solid:
		# Cycles faster than the eye/bar can follow — pin it full and skip the easing
		# predictor entirely (see SOLID_BAR_THRESHOLD_SEC). The "/sec" readout above
		# carries the information now; the bar just reads as "maxed and humming".
		_displayed_cycle_fraction = 1.0
	elif not _prop.is_cycle_running or _prop.units_owned == 0:
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

	# Cycle-bar fill color. Once a property is staffed and running itself hands-off, rush
	# is no longer an option (only the player's single highest-owned property stays
	# rushable — see `interactive` above), so the bar drops its active green for a calm
	# blue. Otherwise it stays green, brightening while the rush button is actively held.
	var rush_no_longer_option := staffed and not interactive
	var rush_held := _manager_circle.is_held() and _prop.units_owned > 0
	_set_cycle_color(rush_no_longer_option, rush_held)

	_refresh_buy_button()
	_refresh_hire_button()


## Pick the cycle bar's fill: calm blue once the property is automated and rush is no
## longer an option, otherwise the active green (brightened while the rush button is held).
## Only rebuilds the stylebox on a change — doing it every frame would be wasteful (same
## pattern as FrenzyBar's burn-color swap).
func _set_cycle_color(rush_no_longer_option: bool, rush_held: bool) -> void:
	var want := 0
	if rush_no_longer_option:
		want = 2
	elif rush_held:
		want = 1
	if want == _cycle_color_applied:
		return
	_cycle_color_applied = want
	var fill := UiPalette.MONEY_GREEN
	if want == 2:
		fill = UiPalette.CYCLE_BLUE
	elif want == 1:
		# Deeper, more saturated green for the active push. Color has no "saturate"
		# helper, so we nudge the HSV saturation by hand after darkening.
		fill = UiPalette.MONEY_GREEN.darkened(HELD_RUSH_DARKEN)
		fill.s = minf(fill.s * HELD_RUSH_SATURATE, 1.0)
	UiPalette.style_progress_bar(_cycle_bar, fill)


## Swap the row's panel background between the normal cream look (owned) and the drab gray
## "locked" look (no units owned yet). Only rebuilds the styleboxes when the state actually
## flips, not every frame. (The portrait button's own look is set live by ManagerCircle.)
func _apply_ownership_styling(owned: bool) -> void:
	var want := 0 if owned else 1
	if want == _ownership_style_applied:
		return
	_ownership_style_applied = want
	if owned:
		add_theme_stylebox_override("panel", UiPalette.make_panel_style())
		# Owned: the bold dark-money-green per-cycle payout.
		var income_green := UiPalette.MONEY_GREEN.darkened(0.4)
		_income_label.add_theme_color_override("font_color", income_green)
		_income_label.add_theme_color_override("font_outline_color", income_green)
	else:
		add_theme_stylebox_override("panel", UiPalette.make_unowned_panel_style())
		# Unowned: a drab dark-gray single-unit preview, matching the locked row look.
		_income_label.add_theme_color_override("font_color", UiPalette.DARK_GRAY)
		_income_label.add_theme_color_override("font_outline_color", UiPalette.DARK_GRAY)


## True once the property is staffed at the best tier this epoch allows. In that state the
## hire button stops being a tier hire/upgrade and becomes the within-epoch LEVEL UP sink
## (GDD §6.1). Used both to draw the button (_refresh_hire_button) and to route its press
## (_on_hire_pressed), so the two never disagree about which action the button performs.
func _is_in_level_up_state() -> bool:
	# Highest tier hireable right now: the reached epoch, capped at the defined epochs.
	var max_tier := mini(_epoch.current_tier, EpochCatalog.tier_count())
	return _prop.staff_tier >= 1 and _prop.staff_tier >= max_tier


## The hire button's single `pressed` handler. It performs different actions depending on
## the staff state, so we dispatch here rather than reconnecting the signal each frame.
func _on_hire_pressed() -> void:
	if _is_in_level_up_state():
		level_up_requested.emit(prop_index)
	else:
		hire_requested.emit(prop_index)


## Update the hire/upgrade/level-up button for the property's current staff tier and the
## reached epoch (the alien-staffing track, GDD §6). Three states:
##   • tier 0 → HIRE the Earth staffer (tier 1).
##   • a higher tier is unlocked by the reached epoch → UPGRADE to the next alien tier.
##   • staffed at the best tier this epoch allows → a live LEVEL UP button buying
##     within-epoch staff levels (the continuous upgrade sink), until the next first
##     contact unlocks a better tier and resets the level.
func _refresh_hire_button() -> void:
	var tier := _prop.staff_tier

	if _is_in_level_up_state():
		# Best tier for this epoch reached — the button now buys within-epoch staff levels,
		# each compounding this property's income (GDD §6.1). It is a live action, so it uses
		# the normal action styling, not the old faint-green disabled plate. The headshot icon
		# stands in for the staffer (we no longer spell out the job title); the left label just
		# shows the current level (Tim, 2026-06-29).
		_apply_hire_styling(false)
		_hire_icon.visible = true
		# `staff_level` is stored 0-based (the count of level-ups bought; 0 = freshly hired,
		# no compounding bonus yet). The player should read a freshly hired staffer as "LVL 1",
		# so the label adds one — a pure display offset, the economy still anchors level 0 to the
		# plain entry multiplier (Tim, 2026-06-29).
		_hire_left_label.text = "LVL %d" % (_prop.staff_level + 1)
		var level_cost := _economy.get_staff_level_cost(prop_index)
		_hire_cost_label.text = Money.of(level_cost).display()
		# Same gate as hiring: need the cash, and units for the staffer to run.
		_hire_button.disabled = _economy.cash < level_cost or _prop.units_owned == 0
		# Full navy when affordable; dimmed navy when not — matching the HIRE/UPGRADE state.
		var level_color := Color(UiPalette.NAVY, 0.45) if _hire_button.disabled else UiPalette.NAVY
		_set_split_label_color(_hire_left_label, _hire_cost_label, level_color)
		_hire_icon.modulate = level_color
		return

	# Otherwise a tier is available to buy: tier 1 (HIRE) from unstaffed, or the next
	# alien tier (UPGRADE) on an already-staffed property after a fresh contact. The headshot
	# icon stands in for the verb (Tim, 2026-06-22), so the left label is blanked and the cost
	# sits on the right.
	_apply_hire_styling(false)
	var next_tier := tier + 1
	var cost := _economy.get_staff_cost(prop_index, next_tier)
	_hire_icon.visible = true
	_hire_left_label.text = ""
	_hire_cost_label.text = Money.of(cost).display()
	# A property with no units can't be staffed yet — a staffer needs something to run.
	_hire_button.disabled = _economy.cash < cost or _prop.units_owned == 0
	# Navy on the live mustard plate, dimmed to match the disabled cream plate — applied to
	# both the cost label and the headshot icon so they read as one.
	var hire_color := Color(UiPalette.NAVY, 0.45) if _hire_button.disabled else UiPalette.NAVY
	_set_split_label_color(_hire_left_label, _hire_cost_label, hire_color)
	_hire_icon.modulate = hire_color


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
