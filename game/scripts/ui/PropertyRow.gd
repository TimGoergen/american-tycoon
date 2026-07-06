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
## The staff button was pressed. There is only ONE staff action now — buy the next rung of
## the property's sequential staff ladder (hiring a staffer IS level 1 of each 20-level
## block, GDD §6.1 epoch-depth redesign) — so the button needs no state dispatch.
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

## Hold-to-repeat pacing (Tim, 2026-06-22), mirroring the Estate shop: a quick tap acts once; holding
## auto-repeats after a short initial delay so the player can watch the cost climb and release when
## they want to stop. The Buy button and the staff (hire/upgrade/level-up) button now have SEPARATE,
## live-tunable pacing (Tim, 2026-07-03): the initial delay and repeat interval for each are read from
## TuningConfig (buy_hold_* / hire_hold_*) so they can be felt out on device via the balance screen.
var _buy_hold_accumulator := 0.0
var _buy_hold_repeating := false

## Hold-to-repeat state for the STAFF button (Tim, 2026-07-01): holding it keeps hiring/upgrading —
## and then leveling up the staffer — until the player releases, on its own hire_hold_* pacing
## (separate from the buy button's, Tim 2026-07-03).
var _hire_hold_accumulator := 0.0
var _hire_hold_repeating := false

# --- Concurrent multi-touch (Tim, 2026-07-02) ------------------------------------------------------
# Godot converts only the FIRST finger of a touch gesture into a mouse event (project setting
# input_devices/pointing/emulate_mouse_from_touch, on by default), and Buttons act on that single
# emulated mouse. So while one finger holds the rush portrait, a second finger on Buy or Hire produces
# NOTHING. To allow concurrent inputs — hold rush while tapping or holding buy/hire — this row also
# reads RAW touch events in _input and drives its three controls from SECONDARY fingers directly.
#
# The FIRST finger of a gesture (the "primary") is left ENTIRELY to the existing Button path, so
# single-touch behaviour is unchanged; only extra fingers are handled here, so there is never a
# double-fire against the emulated mouse. See _input and the _pump_held_* functions.

## Set by Main every frame: true only while the Property tab is showing and no full-screen overlay is
## up, so a stray second finger can never trigger a buy on a row sitting behind a modal (minigame,
## succession, settings, etc.). Static because it is a single app-wide condition shared by all rows.
static var multitouch_enabled := false

## Every finger currently on the screen (by index), primary and secondary alike. Used only to tell
## whether a new touch is the FIRST of a gesture (→ primary, left to the Button path) or an extra
## finger (→ secondary, handled here).
var _active_fingers := {}
## The primary finger's index — the one Godot emulates the mouse from. Tracked so its release is
## recognised, but never acted on here. -1 when no gesture is in progress.
var _primary_finger := -1
## Active SECONDARY fingers → which control each is currently over ("rush" / "buy" / "hire"). A finger
## over none of the three controls is simply absent. The hold pumps read this to tell when a second
## finger is holding a control down.
var _secondary_targets := {}
## The portrait's interactivity as last computed in _refresh, so a secondary tap on it obeys the
## same "rush allowed" rule the ManagerCircle uses (any owned property, staffed or not).
var _portrait_interactive := false

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
## animating and is pinned solid-full. Past this speed the bar would refill several times a
## second — a meaningless strobe at 60fps — so we instead show the property as a continuously-
## paying business (genre-standard, Tim 2026-06-25). This is a pure presentation / legibility
## threshold, NOT an economy value, so it lives here in the UI rather than in tuning.tres.
const SOLID_BAR_THRESHOLD_SEC := 0.25

## The portrait/rush button is a square sized to a fraction of the panel's full height, centered
## vertically (Tim, 2026-07-02): at 1.0 it filled the whole row; 0.9 trims it 10% so it no longer
## dominates the panel while staying a comfortably large tap target.
const PORTRAIT_HEIGHT_FRACTION := 0.9

## Once the EFFECTIVE cycle is shorter than this (seconds), the income readout over the bar switches
## from a per-cycle figure tagged with its length ("$X/4.3m" = $X every 4.3 minutes; see
## _format_cycle_duration) to a per-second rate ("$X/s") — a sub-second cycle reads more naturally as
## a rate than as "per 0.4 seconds" (Tim, 2026-07-01/02).
const PER_SECOND_READOUT_THRESHOLD_SEC := 1.0
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
## Raised 80 → 92 in the taller-panel pass (Tim, 2026-07-05) — the panel's height follows
## its rows, so growing the two row constants grows the whole panel (and the portrait
## disc with it, via PORTRAIT_HEIGHT_FRACTION).
const BUTTON_ROW_HEIGHT := 92
## Buy/hire button label size. Was a touch under FONT_BUTTON so long costs had room
## (Tim, 2026-07-01); +25% in the all-panel-text-larger pass (30 → 38), then a further
## +20% for the buttons specifically (38 → 46, Tim 2026-07-05).
const BUTTON_LABEL_FONT_SIZE := 46

## Property-row readability pass (Tim, 2026-07-01): the row is taller and its labels bigger.
## The property NAME reads in bold on the top line at this size — FONT_SUBHEAD (41) + 25%
## from the all-panel-text-larger pass (Tim, 2026-07-05).
const NAME_FONT_SIZE := 51
## Shared height of the second row's two elements — the cycle progress bar and the outlined
## "owned / next-threshold" count chip — kept equal so they read as one aligned band.
## Raised 52 → 60 (2026-07-05 taller-panel pass), then +50% → 90 (Tim, same day).
const SECOND_ROW_HEIGHT := 90
## Font for the count-panel text and the per-cycle income readout above the bar.
## FONT_BODY (32) → 41 with the 50%-taller band, +25% to 51 in the all-panel-text pass,
## then −20% back to 41 for this band specifically (Tim, 2026-07-05).
const SECOND_ROW_FONT_SIZE := 41

var _manager_circle: ManagerCircle
var _name_label: Label
## The "owned / next-milestone-threshold" readout, inside its own gray-outlined chip (Tim, 2026-07-01).
var _count_label: Label
var _income_label: Label
var _cycle_bar: ProgressBar
var _buy_button: Button
var _buy_caption_label: Label
var _buy_cost_label: Label
var _hire_button: Button
var _hire_cost_label: Label
## The hire button's hand-drawn "add staff" symbol: headshot + "+" (see StaffHireGlyph).
var _hire_glyph: StaffHireGlyph

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

	# The portrait/rush control sits on the LEFT as a single tall square spanning the WHOLE
	# panel height (Tim, 2026-07-01): on device the old section-height circle was a hard tap
	# target, so it now runs the full height of the row for a big, easy-to-hit button. To its
	# right, a column holds the stacked rows — the bold NAME, then the "owned / threshold" count
	# chip beside the income-over-progress-bar band, then the buy/hire buttons. The circle's
	# square size is set in _refresh to match its own height.
	var outer_row := HBoxContainer.new()
	outer_row.add_theme_constant_override("separation", 12)
	add_child(outer_row)

	_manager_circle = ManagerCircle.new()
	_manager_circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # sized in _refresh, centered
	# The portrait IS the start/rush control now (the old START button is gone): a single tap
	# starts an idle cycle (or rushes a running one); holding it auto-rushes (see _pump_held_rush).
	_manager_circle.pressed.connect(func() -> void: tap_requested.emit(prop_index))
	outer_row.add_child(_manager_circle)

	# The stacked rows to the right of the tall portrait.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_row.add_child(column)

	# Row 1 — the property name, in bold.
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip a long name rather than letting it force the whole row wider than the panel — otherwise a
	# long name sets the row's MINIMUM width and, paired with the tall (so wide) portrait, pushes the
	# panel off the right edge of the screen (Tim, 2026-07-01). Clipping lets the row shrink to fit.
	_name_label.clip_text = true
	column.add_child(_name_label)

	# Row 2 — the live cycle progress bar on the LEFT (with the per-cycle income drawn ON
	# TOP of it, bold black), and the outlined "owned / next-threshold" count chip on the
	# RIGHT — sitting directly above the buy button, since the count is exactly what that
	# button grows (Tim, 2026-07-05; mirrors the staff column, where the portrait's level
	# sits above the hire button). The chip and the bar share a height so they read as
	# one line.
	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 10)
	column.add_child(second_row)

	# The bar cell fills the row's leftover width and holds the progress bar with the income drawn
	# over it. A plain Control host (rather than parenting the income to the bar) keeps the income
	# overlay visible even on an unowned "peek" row, where the bar itself is hidden — no cycle to
	# run — but the single-unit income preview should still show.
	var bar_cell := Control.new()
	bar_cell.custom_minimum_size = Vector2(0, SECOND_ROW_HEIGHT)
	bar_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_cell.size_flags_vertical = Control.SIZE_SHRINK_END
	second_row.add_child(bar_cell)

	# The count chip: a gray-outlined plate wrapping the "owned / threshold" readout. Transparent
	# fill so only the outline shows, whatever the row's ownership background is. It takes only its
	# own width (SHRINK_END pins it right) and bottom-aligns so it sits level with the progress bar.
	var count_chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color.TRANSPARENT
	chip_style.border_color = UiPalette.MID_GRAY
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(4)
	# Side padding widened 16 → 26 so the chip reads a little roomier (Tim, 2026-07-05).
	chip_style.set_content_margin(SIDE_LEFT, 26)
	chip_style.set_content_margin(SIDE_RIGHT, 26)
	count_chip.add_theme_stylebox_override("panel", chip_style)
	count_chip.custom_minimum_size = Vector2(0, SECOND_ROW_HEIGHT)
	count_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_chip.size_flags_vertical = Control.SIZE_SHRINK_END
	second_row.add_child(count_chip)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_count_label.add_theme_font_size_override("font_size", SECOND_ROW_FONT_SIZE)
	# Every text on the panel reads bold (Tim, 2026-07-05).
	_count_label.add_theme_font_override("font", UiPalette.make_bold_font())
	count_chip.add_child(_count_label)

	# Cycle progress bar (Style Guide §9: the "spin" is the real cycle progress), filling the cell.
	_cycle_bar = ProgressBar.new()
	_cycle_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cycle_bar.min_value = 0.0
	_cycle_bar.max_value = 1.0
	_cycle_bar.show_percentage = false
	UiPalette.style_progress_bar(_cycle_bar, UiPalette.MONEY_GREEN)
	# Gold bubbles drifting through the fill — every progress bar carries them (Tim, 2026-07-03).
	_cycle_bar.add_child(GoldBubbles.new())
	bar_cell.add_child(_cycle_bar)

	# Per-cycle income: bold BLACK, LEFT-aligned, drawn ON TOP of the bar and vertically centered
	# in it (Tim, 2026-07-01; flipped left 2026-07-05 when the count chip moved to the row's right
	# — right-aligned it would butt against the chip and the two number groups would read as one
	# jumble). A cream outline (the project's faux-weight trick) keeps it legible over both the
	# green fill and the gray track. Inset a little from the cell's edges; ignores the mouse so a
	# tap on the bar area is never eaten by the label.
	_income_label = Label.new()
	_income_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_income_label.offset_left = 12
	_income_label.offset_right = -12
	_income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_income_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income_label.add_theme_font_size_override("font_size", SECOND_ROW_FONT_SIZE)
	_income_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_income_label.add_theme_color_override("font_color", Color.BLACK)
	_income_label.add_theme_color_override("font_outline_color", UiPalette.CREAM)
	_income_label.add_theme_constant_override("outline_size", 4)
	bar_cell.add_child(_income_label)

	# Buy / hire buttons (bulk-buy is mandatory — GDD §3.1). The buy button's
	# count follows the global buy-mode toggle.
	var button_line := HBoxContainer.new()
	button_line.add_theme_constant_override("separation", 8)
	column.add_child(button_line)

	# The HIRE button sits FIRST — next to the staff portrait — so everything staff-related
	# groups on the row's left side (Tim, 2026-07-05: portrait shows who + their level, the
	# button beside it grows them). It reads as a pure action: the headshot icon, a plus
	# sign, and the next rung's price — the level readout itself lives in the portrait now.
	_hire_button = Button.new()
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A little narrower than the buy button (0.85 : 1.0 ≈ a 46/54 split) — the freed width
	# goes to BUY, whose "BUY ×N" + cost labels are the longer text (Tim, 2026-07-05).
	_hire_button.size_flags_stretch_ratio = 0.85
	_hire_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_hire_button, false)
	# Connected ONCE here (a per-refresh reconnect would stack handlers and double-fire).
	_hire_button.pressed.connect(_on_hire_pressed)
	var hire_labels := _add_split_button_labels(_hire_button)
	var unused_left_label := hire_labels[0] as Label
	unused_left_label.queue_free()  # the headshot+plus glyph below replaces the left caption
	_hire_cost_label = hire_labels[1]

	# The "add staff" glyph — headshot + "+" — is DRAWN, not composed from nodes: a
	# Label's line box carries dead ascent above the "+" glyph and the headshot SVG
	# carries transparent padding, so container layout could neither top-align the pair
	# nor pull them close (Tim, 2026-07-05). See StaffHireGlyph at the end of this file.
	_hire_glyph = StaffHireGlyph.new()
	_hire_glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # pushes the cost right
	_hire_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hire_row := _hire_cost_label.get_parent() as HBoxContainer
	hire_row.add_child(_hire_glyph)
	hire_row.move_child(_hire_glyph, 0)  # the glyph first, then the cost label
	button_line.add_child(_hire_button)

	_buy_button = Button.new()
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_buy_button, true)  # red: buying is a spend action (§8)
	_buy_button.pressed.connect(func() -> void: buy_requested.emit(prop_index, _buy_mode))
	var buy_labels := _add_split_button_labels(_buy_button)
	_buy_caption_label = buy_labels[0]
	_buy_cost_label = buy_labels[1]
	button_line.add_child(_buy_button)

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
	_pump_held_hire(delta)


## Raw touch handling for CONCURRENT inputs (see the multi-touch note in the fields above). Only
## SECONDARY fingers are acted on here; the primary finger is left to the normal Button / emulated-
## mouse path, so single-touch behaviour is untouched and nothing ever double-fires.
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
		return
	# A held secondary finger sliding: re-check which control it is over now, so sliding OFF a control
	# cancels its hold (matching how lifting off a button stops the repeat).
	var drag := event as InputEventScreenDrag
	if drag != null and _secondary_targets.has(drag.index):
		var target := _control_under_point(drag.position)
		if target == "":
			_secondary_targets.erase(drag.index)
		else:
			_secondary_targets[drag.index] = target


func _on_touch_pressed(index: int, global_pos: Vector2) -> void:
	# The first finger of a gesture is the one Godot emulates the mouse from — leave it entirely to the
	# Button path. We still record it so its release is recognised, but we never act on it here.
	var is_first_finger := _active_fingers.is_empty()
	_active_fingers[index] = true
	if is_first_finger:
		_primary_finger = index
		return
	# A secondary finger: act only when the Property tab is live and this row is actually on screen,
	# so a stray finger can't trigger a purchase on a row hidden behind a modal overlay.
	if not multitouch_enabled or not is_visible_in_tree():
		return
	var control_id := _control_under_point(global_pos)
	if control_id == "":
		return
	_secondary_targets[index] = control_id
	_fire_secondary_action(control_id)


func _on_touch_released(index: int) -> void:
	_active_fingers.erase(index)
	_secondary_targets.erase(index)
	if index == _primary_finger:
		_primary_finger = -1


## Which of this row's three interactive controls, if any, sits under a global point — "" if none.
## Respects each control's current eligibility (a disabled Buy/Hire, or a non-interactive portrait, is
## not a target), so a secondary finger can only ever trigger what a primary finger could.
func _control_under_point(global_pos: Vector2) -> String:
	if _portrait_interactive and _manager_circle.is_visible_in_tree() \
			and _manager_circle.get_global_rect().has_point(global_pos):
		return "rush"
	if not _buy_button.disabled and _buy_button.is_visible_in_tree() \
			and _buy_button.get_global_rect().has_point(global_pos):
		return "buy"
	if not _hire_button.disabled and _hire_button.is_visible_in_tree() \
			and _hire_button.get_global_rect().has_point(global_pos):
		return "hire"
	return ""


## Fire the one-shot action for a secondary-finger PRESS on a control (the hold pumps add the repeats
## afterward, exactly as they do for the primary finger's Button).
func _fire_secondary_action(control_id: String) -> void:
	match control_id:
		"rush":
			tap_requested.emit(prop_index)  # start an idle cycle, or land one rush
		"buy":
			buy_requested.emit(prop_index, _buy_mode)
		"hire":
			_on_hire_pressed()


## True while any SECONDARY finger is currently holding the named control ("rush" / "buy" / "hire") —
## the hold pumps OR this with the primary finger's Button state so either finger can drive a hold.
func _secondary_held(control_id: String) -> bool:
	return _secondary_targets.values().has(control_id)


## Holding the start/rush button continually drives the property at the tuning
## hold rate (UI notes §2): an idle cycle is STARTED on the first held pulse,
## then a running cycle is RUSHED on every pulse after. Both are gated behind the
## same accumulator, so a quick tap accrues no pulse and stays a plain single
## action (which still fires on release via the button's pressed signal).
func _pump_held_rush(delta: float) -> void:
	# is_held() is false whenever the portrait button is disabled (a locked rung, or an
	# automated property that is not the player's top one), so those simply never auto-rush.
	# A secondary finger on the portrait (multi-touch) counts as held too.
	if (not _manager_circle.is_held() and not _secondary_held("rush")) or _prop.units_owned == 0:
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
	# Held via the primary finger's Button, or a secondary finger resting on it (multi-touch).
	if not _buy_button.button_pressed and not _secondary_held("buy"):
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = false
		return
	_buy_hold_accumulator += delta
	var threshold := _prop.tuning.buy_hold_repeat_interval if _buy_hold_repeating \
		else _prop.tuning.buy_hold_initial_delay
	if _buy_hold_accumulator >= threshold:
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = true
		if not _buy_button.disabled:
			buy_requested.emit(prop_index, _buy_mode)


## Holding the STAFF button keeps performing its current action on a calm cadence (Tim, 2026-07-01):
## a quick tap is handled by the button's own `pressed` (one hire/upgrade/level-up); this only adds
## the repeats while it stays held. It routes through _on_hire_pressed, so a held button naturally
## flows from hiring to upgrading to leveling up as the state changes. Unaffordable pulses are
## skipped (the button disables itself), so a held button simply idles once the player runs out of
## cash rather than spamming failures — exactly like the buy button.
func _pump_held_hire(delta: float) -> void:
	# Held via the primary finger's Button, or a secondary finger resting on it (multi-touch).
	if not _hire_button.button_pressed and not _secondary_held("hire"):
		_hire_hold_accumulator = 0.0
		_hire_hold_repeating = false
		return
	_hire_hold_accumulator += delta
	var threshold := _prop.tuning.hire_hold_repeat_interval if _hire_hold_repeating \
		else _prop.tuning.hire_hold_initial_delay
	if _hire_hold_accumulator >= threshold:
		_hire_hold_accumulator = 0.0
		_hire_hold_repeating = true
		if not _hire_button.disabled:
			_on_hire_pressed()


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
	# Row 1 is just the property name (bold). The owned-count and next-milestone threshold now live
	# in their own outlined chip on row 2 (Tim, 2026-07-01), no longer folded into the title.
	_name_label.text = config.display_name

	# The count chip: "<owned> / <next milestone threshold>", or "<owned> / MAX" past the last tier.
	var next_milestone := _prop.get_next_milestone_count()
	if next_milestone <= 0:
		_count_label.text = "%d / MAX" % _prop.units_owned
	else:
		_count_label.text = "%d / %d" % [_prop.units_owned, next_milestone]

	# A rung the player owns no units of yet gets a drab gray "locked" look; once a
	# unit is bought it switches to the normal cream styling (applied on change).
	var owned := _prop.units_owned > 0
	_apply_ownership_styling(owned)

	# An unowned rung has no cycle to run, so the cycle bar is hidden until the player
	# owns at least one unit (Tim, 2026-06-28).
	_cycle_bar.visible = owned

	# Keep the portrait circle square, sized to PORTRAIT_HEIGHT_FRACTION of the panel's full height
	# and centered vertically. The row's height is driven by the column of rows to the right, so we
	# read it back from the portrait's parent (the outer HBox) and shrink the square to fit.
	var outer_row := _manager_circle.get_parent() as Control
	var portrait_size: float = outer_row.size.y * PORTRAIT_HEIGHT_FRACTION
	_manager_circle.custom_minimum_size = Vector2(portrait_size, portrait_size)

	# The portrait is the start/rush control (ManagerCircle). Decide its look and whether it
	# accepts input this frame:
	#   • LOCKED   — no units owned yet (drab, inert).
	#   • STAFFED  — automated; shows the property accent + staffer headshot. Still rushable:
	#                the staffer runs it, but the boss can always lean on it (Tim, 2026-07-03 —
	#                was "only the single highest property"; opened to every owned row because
	#                rush is self-limiting economically: 5% of a short cycle is worth nothing,
	#                so only the long-cycle rows reward the attention, and a same-looking disc
	#                that ignored touches read as broken rather than automated).
	#   • UNSTAFFED — owned but not automated; silver restart plate.
	# The infinity icon shows whenever an interactive portrait is actively held (being rushed).
	var staffed := _prop.is_staffed
	var interactive := owned
	# Remembered for _control_under_point, so a secondary-finger rush obeys this same rule.
	_portrait_interactive = interactive
	var portrait_mode := ManagerCircle.PortraitMode.LOCKED
	if owned:
		portrait_mode = ManagerCircle.PortraitMode.STAFFED if staffed else ManagerCircle.PortraitMode.UNSTAFFED
	# The infinity "rushing" icon shows whether the primary Button or a secondary finger holds it.
	var show_rush_icon := interactive and (_manager_circle.is_held() or _secondary_held("rush"))
	_manager_circle.set_state(
		portrait_mode, config.accent_color, config.manager_portrait, show_rush_icon,
		interactive, _prop.staff_level
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
	# The amount paid per completed cycle. For an OWNED rung get_income_per_cycle() already folds in
	# the staffer and Family Fortune (Legacy) multipliers, with frenzy applied live on top so it
	# matches what the player receives; for an UNOWNED rung it's the per-cycle value of a single
	# unit (a buy-in preview).
	var per_cycle := _prop.get_income_per_cycle() * _frenzy.get_multiplier() if owned \
		else _prop.get_single_unit_income_per_cycle()
	# Rate context on the payout (Tim, 2026-07-02): a cycle of a second or more shows the per-cycle
	# payout WITH its cycle length, scaled to a sensible unit — "$X/4.3m" is $X every 4.3 minutes —
	# so the figure is never an unlabeled amount. A sub-second cycle instead reads as a per-second
	# rate ("$X/s"), the same per-cycle figure divided by the (tiny) cycle length.
	# The income amount shows a single decimal place only when it isn't zero (display()'s default —
	# _trim drops a trailing ".0"), with a space on either side of the slash (Tim, 2026-07-02/03):
	# "$14M / 4.3m" when whole, "$14.3M / 4.3m" when not.
	# "<=" so a cycle of EXACTLY one second also reads as the per-second rate " / s" —
	# per-cycle and per-second are the same number at 1s, and "$X / 1s" read as a defect
	# (Tim, 2026-07-03: a per-second rate says "/ s", never "/ 1s").
	if effective_length > 0.0 and effective_length <= PER_SECOND_READOUT_THRESHOLD_SEC:
		_income_label.text = Money.of(per_cycle / effective_length).display() + " / s"
	else:
		_income_label.text = "%s / %s" % [Money.of(per_cycle).display(), _format_cycle_duration(effective_length)]

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


## Format a cycle length (seconds) as a compact duration with a unit scaled to size —
## seconds (s), minutes (m), hours (h), or days (d) — for the "$X/<duration>" income readout (Tim,
## 2026-07-02). Units are lowercase, matching the "/s" per-second rate. At most one decimal,
## and only when it is non-zero (Money.trim): "4.3m" but "2m", never "2.0m" (Tim, 2026-07-03).
func _format_cycle_duration(seconds: float) -> String:
	if seconds >= 86400.0:
		return Money.trim(seconds / 86400.0, 1) + "d"
	elif seconds >= 3600.0:
		return Money.trim(seconds / 3600.0, 1) + "h"
	elif seconds >= 60.0:
		return Money.trim(seconds / 60.0, 1) + "m"
	return Money.trim(seconds, 1) + "s"


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
		# Owned: the per-cycle payout in bold black (Tim, 2026-07-01).
		_income_label.add_theme_color_override("font_color", Color.BLACK)
	else:
		add_theme_stylebox_override("panel", UiPalette.make_unowned_panel_style())
		# Unowned: a drab dark-gray single-unit preview, matching the locked row look.
		_income_label.add_theme_color_override("font_color", UiPalette.DARK_GRAY)


## The staff button's `pressed` handler. One action only — buy the next ladder rung —
## so no state dispatch (the pre-redesign HIRE/UPGRADE/LEVEL-UP state machine is gone).
func _on_hire_pressed() -> void:
	hire_requested.emit(prop_index)


## Update the staff button for the property's sequential ladder (GDD §6.1, epoch-depth
## redesign). The button is a pure BUY action — headshot + "+" on the left, the NEXT
## rung's price on the right (the current level shows in the portrait disc instead,
## Tim 2026-07-05) — plus a faint-green MAX park when every level the reached epoch
## allows has been bought. Because each block's price is fixed by its own epoch, the
## number here can never silently jump at a first contact; a new block's bigger price
## only appears once the player has actually climbed to it (the 2026-07-03 bug fix).
func _refresh_hire_button() -> void:
	# Cap reached: every level the reached epoch allows is bought. The next block unlocks
	# at the next first contact, so the button parks on the faint-green "staffed" plate
	# with the icon + plus grayed and "MAX" where the price was.
	if _economy.is_staff_level_maxed(prop_index, _epoch.current_tier):
		_apply_hire_styling(true)
		_hire_cost_label.text = "MAX"
		_hire_button.disabled = true
		_hire_cost_label.add_theme_color_override("font_color", UiPalette.NAVY)
		_hire_glyph.tint = UiPalette.NAVY
		return

	_apply_hire_styling(false)
	var cost := _economy.get_next_staff_level_cost(prop_index)
	_hire_cost_label.text = Money.of(cost).display()
	# A property with no units can't be staffed — a staffer needs something to run.
	_hire_button.disabled = _economy.cash < cost or _prop.units_owned == 0
	# Navy on the live mustard plate, dimmed to match the disabled cream plate — applied to
	# the cost and the headshot+plus glyph together so they read as one.
	var hire_color := Color(UiPalette.NAVY, 0.45) if _hire_button.disabled else UiPalette.NAVY
	_hire_cost_label.add_theme_color_override("font_color", hire_color)
	_hire_glyph.tint = hire_color


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
	# Every text on the panel reads bold (Tim, 2026-07-05).
	left.add_theme_font_override("font", UiPalette.make_bold_font())
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var right := Label.new()
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.size_flags_vertical = Control.SIZE_FILL
	right.add_theme_font_size_override("font_size", BUTTON_LABEL_FONT_SIZE)
	right.add_theme_font_override("font", UiPalette.make_bold_font())
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
	# How many units this press would buy under the current mode. The left label just shows that
	# count as "+N" (Tim, 2026-07-01) — no "BUY"/"MAX" wording, since the count alone reads as the
	# purchase; the cost sits on the right.
	var count := 0
	match _buy_mode:
		BuyMode.ONE:
			count = 1
		BuyMode.TEN:
			count = 10
		BuyMode.HUNDRED:
			count = 100
		BuyMode.MAX:
			count = _prop.get_max_affordable(_economy.cash)

	if count <= 0:
		# MAX mode with nothing affordable yet: "+0", and show the next single unit's cost so the
		# player can see how close they are, instead of a blank "—".
		_buy_caption_label.text = "+0"
		_buy_cost_label.text = Money.of(_prop.get_bulk_cost(1)).display()
		_buy_button.disabled = true
		_set_buy_label_colors()
		return

	var cost := _prop.get_bulk_cost(count)
	_buy_caption_label.text = "+%d" % count
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


# ---------------------------------------------------------------------------
# The hire button's "add staff" glyph
# ---------------------------------------------------------------------------

## The headshot icon with a large "+" tucked tight against its top-right, drawn as ONE
## control. Hand-drawn because node layout could not deliver "top-aligned and close"
## (Tim, 2026-07-05): a Label's line box carries dead ascent above the "+" glyph, and
## the headshot SVG carries transparent padding in its canvas — so container-aligned
## boxes left the plus visually low and far from the face. Drawing lets the plus hug
## the icon's VISIBLE bounds (get_used_rect — see the texture-sizing memory note).
class StaffHireGlyph extends Control:
	## Side of the square box the headshot canvas is fitted into.
	## 56 → 62 in the taller-panel pass (Tim, 2026-07-05).
	const ICON_SIZE := 62.0
	## The plus is bigger than the button's cost text so it carries as a symbol.
	## +25% in the all-panel-text-larger pass (42 → 52, Tim 2026-07-05).
	const PLUS_FONT_SIZE := 52
	## Gap between the face's visible right edge and the plus.
	const PAIR_GAP := 3.0
	## Distance from the "+" glyph's VISUAL top down to its text baseline, as a fraction
	## of the font size ("+" spans roughly the x-height band in most fonts). Art knob:
	## raise to push the plus down, lower to lift it.
	const PLUS_TOP_TO_BASELINE := 0.60

	## Tint for the whole glyph (navy live, dimmed navy when the button is disabled).
	var tint := Color.WHITE:
		set(value):
			if value != tint:
				tint = value
				queue_redraw()

	## The headshot art's opaque bounds inside its canvas, computed ONCE for all rows
	## (get_used_rect is a CPU pixel scan; the canvas carries transparent padding).
	static var _icon_used_rect := Rect2()
	## The bold face the "+" draws in (all panel text is bold, Tim 2026-07-05) —
	## cached: building a FontVariation per frame in _draw would be wasteful.
	static var _plus_font: FontVariation

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _icon_used_rect.size == Vector2.ZERO:
			_icon_used_rect = Rect2(ManagerCircle.HEADSHOT_TEX.get_image().get_used_rect())
		if _plus_font == null:
			_plus_font = UiPalette.make_bold_font()
		var plus_width := _plus_font.get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, PLUS_FONT_SIZE).x
		custom_minimum_size = Vector2(ICON_SIZE + PAIR_GAP + plus_width, ICON_SIZE)

	func _draw() -> void:
		# Fit the icon canvas into its square box preserving aspect (what the old
		# TextureRect's KEEP_ASPECT did), pinned LEFT and vertically centered.
		var tex := ManagerCircle.HEADSHOT_TEX
		var tex_size := Vector2(tex.get_size())
		var fit := minf(ICON_SIZE / tex_size.x, ICON_SIZE / tex_size.y)
		var canvas_size := tex_size * fit
		var canvas_pos := Vector2(0.0, (size.y - canvas_size.y) / 2.0)
		draw_texture_rect(tex, Rect2(canvas_pos, canvas_size), false, tint)

		# The face's VISIBLE bounds within that canvas — what the plus aligns against.
		var face_top := canvas_pos.y + _icon_used_rect.position.y * fit
		var face_right := canvas_pos.x + _icon_used_rect.end.x * fit

		var baseline_y := face_top + PLUS_FONT_SIZE * PLUS_TOP_TO_BASELINE
		draw_string(_plus_font, Vector2(face_right + PAIR_GAP, baseline_y), "+",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, PLUS_FONT_SIZE, tint)
