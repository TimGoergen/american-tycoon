class_name MomentumBar
extends HBoxContainer

# The Rush Momentum / Heat control (Tim 2026-07-12; Rush Overheat rework Tim 2026-07-15;
# Cruise Control amendment Tim 2026-07-16): the OVERDRIVE button beside a display-only meter —
# the same square-button-plus-meter shape as the frenzy TURBO control (FrenzyBar). Momentum is
# earned by rushing the PROPERTIES, so the meter itself is still not a button; the OVR button
# is the ONE tappable piece, enabled only mid-hold (see _process).
#
# APPROACH-BAR REWORK (Plans/Overdrive_Vent_Windows.md, Tim 2026-07-19): the meter is now TWO
# different instruments sharing one frame, keyed on whether overdrive is engaged:
#
#   • CRUISE/BUILD mode (overdrive NOT engaged, not locked out): the whole bar spans
#     0 → the cruise clamp — FILLING THE BAR IS REACHING CRUISE (Tim: clean and safe-reading).
#     Purple fill, gold-family bubbles, no hazard wash, no stripes, no blink. The old teal
#     cruise-bar marker is gone in this mode: the bar's own right edge IS the cruise point now,
#     so a marker for it would be redundant. The "CRUISE +25%" readout stays.
#
#   • OVERDRIVE mode (engage_overdrive → until disengage/overheat): the bar repurposes into
#     the vent-minigame instrument. A fixed gold TARGET BAR sits ~1/3 from the left; each
#     scheduled vent event enters as a bright red EVENT BAR at the right edge and travels left
#     (the player SEES IT COMING — this replaces the old held-open gold "VENT!" chip); the
#     event reaching the target IS the window opening. While a window is open, the whole
#     region right of the target renders the gesture pips and the countdown at full bar
#     scale (see OverdriveInstrumentOverlay). The ProgressBar fill is PINNED FULL and its
#     color carries the depth urgency: purple → amber with overdrive depth, the red warning
#     blink ramping on top — so between events the bar still FEELS hotter the deeper you
#     ride, even though it no longer plots heat's position. (Pinned-full was chosen over
#     repurposing the fill as the countdown: the overlay's timer strip already tells the
#     countdown story, and a second moving edge underneath it would just be noise — the fill's
#     job in this mode is to be the urgency-colored stage the minigame plays on.)
#
#   • OVERHEAT lockout: the fill shows heat / hard_ceiling visibly draining (the drain IS the
#     cooldown display), label swaps OVERHEATED → COOLING…, then the READY flash. The
#     instrument overlay paints the DEAD-BAR GRAY behind it (Tim 2026-07-18 night): the track
#     the draining fill reveals is dark gray, and once the drain finishes the gray itself
#     drains from the right in proportion to the re-arm countdown — the gray's movement IS the
#     re-arm timer, and the READY flash lands on a fully normal-looking bar.
#
# Vent resolutions still land as timed chips ABOVE the bar: green "VENTED — PEAK +X%!" plus
# the white flash on success; red "VENT MISSED!" with the unfinished pips strobing on a miss.
# The miss chip KEEPS its own pip row (VentPipRow) even though the bar now draws pips too:
# a miss immediately flips the bar into the OVERHEAT display, which wipes the in-bar pips —
# the chip is the only place the blown beat can stay visible long enough to learn from
# (the plan's rule: miss-feedback is what makes a skill mechanic learnable).
#
# BANKED BONUS (Tim 2026-07-20): bailing out voluntarily now KEEPS the earned bonus and spins it
# down gradually, while an overheat still zeroes it on the spot. That difference is invisible in
# the "+X%" readout alone — both cases just show a number — so a teal "BANKED +X% — DRAINING"
# chip rides above the bar for the whole spin-down. An overheat shows no such chip, so the two
# outcomes are told apart by the chip's PRESENCE, which is the only way a player ever discovers
# that bailing is a real option. Both chips share one upward-growing stack above the bar so they
# can never overlap.
#
# Cruise Control (Plans/Rush_Cruise_Control.md) rules still apply: the OVR button is ALWAYS
# visible (Tim 2026-07-16: moving UI elements are annoying) but ENABLED only once the hold has
# REACHED the cruise clamp; any other time it wears the gray-outlined "can't trigger" plate.

## The player tapped OVERDRIVE: release the cruise clamp for this excursion. Main routes this
## to GameState.engage_rush_overdrive() — the same seam as FrenzyBar.pop_requested.
signal overdrive_requested

var _rush_momentum: RushMomentumState
var _tuning: TuningConfig

## The OVR button, pinned left of the meter (the FrenzyBar layout). Always visible; enabled
## only while cruising — see _process.
var _overdrive_button: Button

## The display-only meter. All the overlays below live inside it.
var _meter: ProgressBar

## The big bonus readout ("+42%"), right-aligned; the caption on the left names the meter.
var _label: Label

## Carbonation in the fill; hidden while overheated (a locked meter is not accruing anything).
var _bubbles: GoldBubbles

## Fast neon-salmon streaks shown while overdrive is engaged — "you are riding the danger
## zone". With the fill pinned full in overdrive mode, the streaks are also the motion cue
## that the bar has switched instruments.
var _streaks: MomentumStreaks

## The custom-drawn overdrive instrument: target bar, traveling event bar with its trailing
## event backdrop, in-bar pips and the window's timer strip — plus the lockout's dead-bar gray
## (its one non-overdrive job). Draws NOTHING in cruise/build mode (the cruise bar is a clean,
## plain meter now). Formerly BandZoneOverlay — the hazard wash/stripes it painted moved into
## the fill's own depth coloring when the bar stopped plotting heat position.
var _instrument: OverdriveInstrumentOverlay

## The chip shown above the meter: the short-lived vent success/miss resolution plates.
## (The old HELD-OPEN gold "VENT!" telegraph chip is retired — the approaching red event bar
## is the telegraph now, with ~2 s of warning instead of a plate popping in.)
var _tier_chip: PanelContainer
var _tier_chip_label: Label
var _tier_chip_tween: Tween

## The column the chips live in, anchored above the meter (see _ready). Chips are stacked
## top-to-bottom so the one nearest the bar is the LAST child.
var _chip_stack: VBoxContainer

## The banked-bonus chip: shown for as long as a voluntarily banked bonus is spinning down,
## so the player can tell a bail (you keep it, it drains) from an overheat (it is gone now).
var _banked_chip: PanelContainer
var _banked_chip_label: Label

## The miss-feedback pips inside the chip (see VentPipRow at the bottom of this file).
## Visible only on the "VENT MISSED!" chip — see the class comment for why the chip keeps
## its own pips alongside the in-bar ones.
var _vent_pips: VentPipRow

## The open window's telegraphed duration (s), for the in-bar countdown fraction. Taken from
## the vent_window_opened signal rather than the tuning knob, because the core SHRINKS windows
## per achieved tier (the escalation's speed axis) — the countdown must drain over the
## window's REAL length.
var _vent_window_duration := 1.0

## The in-flight event's total approach time (s), from the vent_incoming signal — the divisor
## that turns vent_approach_remaining() into the event bar's 0..1 travel fraction.
var _vent_approach_seconds := 1.0

## Lifts landed in the OPEN window, from vent_lift_registered (the core exposes the demanded
## count via vent_required_lifts() but not the landed count, so the UI keeps this one tally).
## Reset when a window opens; meaningless while none is open.
var _window_lifts_done := 0

# Frame-rate display clocks for the two moving vent elements (Tim 2026-07-19: "the vent event bar
# movement is jerky, both the incoming event as well as the event timer"). The core owns both
# times, but it only republishes them on the 10 Hz LOGIC tick, while this bar redraws every frame
# — so reading them raw made the event bar and the timer strip step ~10 times a second. An event
# crosses its whole runway in ~1.2 s, which is only about a dozen steps: very visibly chunky.
#
# These local copies run down on the FRAME delta and stay pinned to the core's authoritative value
# (see _predict_clock). Deliberately NOT BarSmoothing: an eased follow would LAG, and these two
# elements make promises the core keeps exactly — the bar reaching the target IS the window
# opening, and the strip emptying IS the miss. Prediction keeps them frame-smooth AND on time.
var _approach_display := 0.0
var _approach_core_seen := 0.0
var _window_display := 0.0
var _window_core_seen := 0.0

## The re-arm gray's receding edge has the same 10 Hz source, but it is a cooldown readout rather
## than a promise the player acts on, so it takes the cheaper cure: the standard eased follow the
## fill already uses. A few ms of lag on "the bar is coming back" costs nothing.
var _rearm_display := 0.0

## Full-rect white flash played when rush re-arms — re-availability must be unmissable
## (Tim 2026-07-15), so the whole meter blinks bright once alongside the label reverting.
var _ready_flash: ColorRect

## Eased fill: heat is driven by the 10 Hz logic tick, so we glide the shown fill toward it each
## frame instead of copying it raw — otherwise the bar visibly steps ~10 times a second (the same
## smoothing the frenzy meter uses; see BarSmoothing).
var _displayed_fill := 0.0

## The fill StyleBoxFlat, kept so _process can recolor the fill per mode/depth (and drive the
## warning blink) by mutating bg_color — far cheaper than rebuilding the stylebox every frame.
var _fill_style: StyleBoxFlat

## Blink phase accumulator (radians). Advanced by the CURRENT blink frequency each frame, so the
## frequency can ramp with heat depth without the sine jumping discontinuously.
var _blink_phase := 0.0

## Which label state is currently applied (see _LabelState), so the color/outline overrides are
## only rebuilt when the state flips, not every frame.
enum _LabelState { NORMAL, CRUISING, OVERHEATED, COOLING }
var _label_state_applied: int = -1

## Where the fixed vent target bar sits, as a fraction of the bar's width (~1/3 from the left,
## Tim 2026-07-19). The region right of it is the event runway: events enter at the right edge
## and travel left across two-thirds of the bar, so the approach is long enough to read.
const TARGET_FRAC := 0.33

## Blink ramp (overdrive mode): the red warning blink keys CONTINUOUSLY on overdrive depth —
## heat's position within [cruise point .. hard ceiling]. Frequency runs BLINK_HZ_MIN →
## BLINK_HZ_MAX across that span; strength runs 0 → BLINK_STRENGTH_MAX. There is deliberately
## no strength floor: a floor would snap the blink on at some depth, re-creating the very band
## edge the depth-hazard rework removed (see _update_fill_color).
const BLINK_HZ_MIN := 2.5
const BLINK_HZ_MAX := 7.0
const BLINK_STRENGTH_MAX := 0.85

## How long the tier chip holds fully visible before fading (seconds).
const TIER_CHIP_HOLD_SEC := 1.0
## Pixels between the meter's top edge and the chip's bottom edge (Tim 2026-07-18: the chip
## must not cover the bar).
const TIER_CHIP_GAP_ABOVE_BAR := 8.0
## Vertical gap between stacked chips when more than one is up.
const CHIP_STACK_SEPARATION := 6.0
const TIER_CHIP_FADE_IN_SEC := 0.12
const TIER_CHIP_FADE_OUT_SEC := 0.4

## The READY flash's peak alpha and fade time.
const READY_FLASH_ALPHA := 0.75
const READY_FLASH_FADE_SEC := 0.5

# Haptic pulse lengths moved from constants to live Balance Tuning knobs (tuning
# rush_momentum_haptic_*_ms) so the device pass can dial them on the phone — see _vibrate.


## Call before adding to the tree.
func setup(rush_momentum: RushMomentumState, tuning: TuningConfig) -> void:
	_rush_momentum = rush_momentum
	_tuning = tuning


func _ready() -> void:
	add_theme_constant_override("separation", 8)  # match the TURBO row's button/meter gap

	# The OVR button, left of the meter like FrenzyBar's TURBO button. ALWAYS visible — it began
	# life appearing only mid-hold, but a control that pops in and out is annoying (Tim
	# 2026-07-16); a permanent fixture also earns the short "OVR" label, since it is learned
	# once rather than having to explain itself the instant it appears. The red action plate
	# (§8: red = spend/act) marks it as the opt-in gamble, apart from gold TURBO.
	_overdrive_button = Button.new()
	_overdrive_button.text = "OVR"
	# FONT_HEADLINE, not FONT_BUTTON: three letters can afford to be huge, and the button is
	# the meter row's one action so it should land at a glance (Tim's vision, §1b).
	_overdrive_button.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_overdrive_button.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(_overdrive_button, true)
	# When overdrive can't engage (no live rush hold, or locked out) the button grays its
	# OUTLINE too, exactly like the frenzy pop button — "can't trigger" must read at a glance
	# (Tim 2026-07-15). The standard disabled plate keeps the navy frame; swap ours for gray.
	var disabled_plate := StyleBoxFlat.new()
	disabled_plate.bg_color = UiPalette.CREAM
	disabled_plate.border_color = UiPalette.MID_GRAY
	disabled_plate.set_border_width_all(3)
	disabled_plate.set_corner_radius_all(4)
	disabled_plate.set_content_margin_all(12)
	_overdrive_button.add_theme_stylebox_override("disabled", disabled_plate)
	# Fill the row's height (the meter's 0.7 × standard-button height) rather than forcing the
	# whole momentum row taller than the meter; the minimum WIDTH keeps the tap target generous
	# now that the label is only three letters.
	_overdrive_button.custom_minimum_size = Vector2(UiPalette.STANDARD_BUTTON_HEIGHT, 0)
	_overdrive_button.size_flags_vertical = Control.SIZE_FILL
	_overdrive_button.pressed.connect(func() -> void: overdrive_requested.emit())
	# ESSENTIAL, not just convenient: the button is only ENABLED while a rush hold is live, so
	# the tap that presses it is ALWAYS a second finger — without this node it could never fire
	# on a phone (Godot only emulates the mouse from the gesture's first finger).
	_overdrive_button.add_child(SecondaryTapButton.new())
	_overdrive_button.disabled = true  # _process enables it only while cruising
	add_child(_overdrive_button)

	# The meter itself — display only, so it ignores the mouse entirely (FrenzyBar's meter
	# does the same); the button above is this control's one tappable piece.
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	# A touch shorter than a full action button — it is a secondary read-out, not a tap target,
	# but still tall enough to read at a glance. Raised 0.7 → 0.85 (Tim 2026-07-20: the in-bar
	# vent pips read as "readable but small"). The pips are sized off this inner height, and
	# at 0.7 there was no vertical room left to grow them once the timer strip along the
	# bottom edge is reserved. 0.85 also brings this meter CLOSER to the frenzy meter below
	# it, which is a full button tall.
	_meter.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 0.85))
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# DARK_PURPLE fill: a distinct hue from the frenzy meter's warm gold/red sitting just below it,
	# so the two reward meters never read as the same thing. Darkened from the lighter PURPLE
	# (Tim 2026-07-15) so the bright bubbles and white text pop against it.
	UiPalette.style_framed_progress(_meter, UiPalette.DARK_PURPLE, UiPalette.PROGRESS_TRACK_GRAY)
	add_child(_meter)
	# Keep a handle on the fill stylebox so the mode/depth coloring can mutate its bg_color
	# per frame instead of rebuilding styleboxes (see _process).
	_fill_style = _meter.get_theme_stylebox("fill") as StyleBoxFlat

	# The overdrive instrument overlay, custom-drawn (the same approach as MomentumStreaks).
	# Added FIRST among the meter's overlays so the bubbles, streaks, and text labels all draw
	# over its plates and bars.
	_instrument = OverdriveInstrumentOverlay.new()
	_meter.add_child(_instrument)

	# Carbonation in the fill, the same "value accruing automatically" cue the frenzy meter and the
	# property/economy bars carry: heat builds on its own while you rush. BRIGHT_PURPLE bubbles
	# glowing against the dark fill (flipped from dark-on-light, Tim 2026-07-15 — the same pairing
	# the maxed-momentum property bars use). Added BEFORE the label overlay so the readout draws
	# over the bubbles.
	_bubbles = GoldBubbles.new()
	_bubbles.edge_inset = 3.0  # match the framed fill's 3px inset (style_framed_progress)
	_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
	_bubbles.tier = GoldBubbles.Tier.FLOWING  # steady automatic accrual, like TURBO charging
	_meter.add_child(_bubbles)

	# Neon-salmon streaks over the fill, shown while overdrive is engaged (see _process).
	# Added over the gold bubbles but under the label overlay, so the "+XX%" still draws on top.
	_streaks = MomentumStreaks.new()
	_streaks.color = UiPalette.NEON_SALMON
	_streaks.visible = false
	_meter.add_child(_streaks)

	# READY flash: a full-rect white wash, normally invisible; _on_rush_ready tweens it bright and
	# back so the re-armed meter is unmissable even in peripheral vision (Tim's vision, §1b).
	_ready_flash = ColorRect.new()
	_ready_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ready_flash.color = Color(1, 1, 1, 0)
	_ready_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_ready_flash)

	# Overlay: a left caption and the big "+XX%" readout on the right. It ignores the mouse so it
	# never eats a tap meant for the rows or buttons around it.
	var text_overlay := MarginContainer.new()
	text_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_overlay.add_theme_constant_override("margin_left", 16)
	text_overlay.add_theme_constant_override("margin_right", 16)
	text_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(text_overlay)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_overlay.add_child(row)

	# Left: the meter's name. White (Tim 2026-07-15) so it reads over the dark purple fill (the
	# caption sits at the left edge, filled first as heat climbs).
	var caption := Label.new()
	caption.text = "RUSH MOMENTUM"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	caption.add_theme_font_override("font", UiPalette.make_bold_font())
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)

	# Right: the live bonus, large and bold. Takes the remaining width and right-aligns so it hugs
	# the frame's right edge while the caption stays pinned left.
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_apply_label_state(_LabelState.NORMAL)

	# The CHIP STACK: the column of plates that live ABOVE the meter, never over it (Tim
	# 2026-07-18: a chip covering the bar hid the fill exactly when the player most needs to read
	# it mid-vent). Anchored to the meter's top-center and growing UPWARD, so however tall its
	# chips get, the bottom chip's lower edge stays a fixed gap above the bar. Chips are listed
	# top-to-bottom, so the LAST child is the one nearest the bar. z_index lifts the whole stack
	# above the siblings drawn after this bar.
	#
	# A container (rather than two separately anchored chips) exists because there are now two
	# kinds of chip — the timed vent resolutions and the persistent banked-bonus readout — and
	# they must never share pixels when both are up.
	_chip_stack = VBoxContainer.new()
	_chip_stack.anchor_left = 0.5
	_chip_stack.anchor_right = 0.5
	_chip_stack.anchor_top = 0.0
	_chip_stack.anchor_bottom = 0.0
	_chip_stack.offset_bottom = -TIER_CHIP_GAP_ABOVE_BAR
	_chip_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chip_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chip_stack.add_theme_constant_override("separation", int(CHIP_STACK_SEPARATION))
	_chip_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_stack.z_index = 10
	_meter.add_child(_chip_stack)

	# The tier chip: a large bold plate for the vent resolutions — chips ease in, hold ~1 s,
	# then fade (see _show_tier_chip). Sits at the TOP of the stack, so a banked chip below it
	# never pushes it over the bar.
	_tier_chip = PanelContainer.new()
	_tier_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tier_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.visible = false
	_chip_stack.add_child(_tier_chip)

	# The chip's content column: the big text line, with the miss-feedback pips beneath it.
	# The pip row only shows on the miss chip; every other chip keeps it hidden, so those
	# chips collapse to exactly the text-only shape.
	var chip_column := VBoxContainer.new()
	chip_column.add_theme_constant_override("separation", 10)
	chip_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.add_child(chip_column)

	_tier_chip_label = Label.new()
	_tier_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# FONT_HEADLINE bold — the chip is the payoff/failure moment and must land at a glance
	# (Tim's vision, §1b: large text, unmissable signals).
	_tier_chip_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_tier_chip_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_tier_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_column.add_child(_tier_chip_label)

	_vent_pips = VentPipRow.new()
	_vent_pips.visible = false
	chip_column.add_child(_vent_pips)

	# The BANKED chip: the spin-down readout. Unlike the tier chip this one is not a timed
	# celebration — it is shown for as long as a bailed-out bonus is still draining, and it is
	# the ONLY place the player can learn that bailing pays at all (Tim 2026-07-20: "yes, and say
	# so in the UI"). Without it, bailing and overheating look identical from the outside and the
	# whole cash-out half of the loop stays invisible.
	#
	# Sits at the BOTTOM of the stack, nearest the bar, because it annotates the bar's own "+X%"
	# readout: it is saying "that number you are reading is banked, and it is going down".
	_banked_chip = PanelContainer.new()
	_banked_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banked_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banked_chip.visible = false
	_chip_stack.add_child(_banked_chip)

	# ATOMIC_TEAL on NAVY: teal is already this bar's "safe / settled" color (the CRUISE readout
	# uses it), which is exactly what a banked bonus is — deliberately nothing like the gold
	# act-now family or the red failure family. An overheat shows no chip at all and the number
	# simply goes, so the two outcomes are told apart by presence, not by shades of a plate.
	_banked_chip_label = Label.new()
	_banked_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banked_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banked_chip_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_banked_chip_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_banked_chip_label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	_banked_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banked_chip.add_child(_banked_chip_label)

	var banked_plate := StyleBoxFlat.new()
	banked_plate.bg_color = UiPalette.ATOMIC_TEAL
	banked_plate.border_color = UiPalette.NAVY
	banked_plate.set_border_width_all(3)
	banked_plate.set_corner_radius_all(8)
	banked_plate.set_content_margin_all(10)
	_banked_chip.add_theme_stylebox_override("panel", banked_plate)

	# Overheat/re-arm swap the whole meter's presentation. (Deliberately NO band_entered
	# connection: the depth-hazard rework retired the Critical band and its crossing chip —
	# the vent events are the escalation drama now; Tim 2026-07-18.)
	_rush_momentum.overheated.connect(_on_overheated)
	_rush_momentum.rush_ready.connect(_on_rush_ready)
	# Vent Windows: the approach telegraph, the in-window progress, and the two resolutions
	# (Plans/Overdrive_Vent_Windows.md, approach-bar rework).
	_rush_momentum.vent_incoming.connect(_on_vent_incoming)
	_rush_momentum.vent_window_opened.connect(_on_vent_window_opened)
	_rush_momentum.vent_lift_registered.connect(_on_vent_lift_registered)
	_rush_momentum.vent_succeeded.connect(_on_vent_succeeded)
	_rush_momentum.vent_missed.connect(_on_vent_missed)


func _process(delta: float) -> void:
	var locked_out := _rush_momentum.is_locked_out()
	var cruising := _rush_momentum.is_cruising()
	# Overdrive DISPLAY mode: the engaged flag, not heat position — the instant the player opts
	# in the bar becomes the minigame instrument, and the instant the ride ends (release,
	# overheat) it stops being one. Lockout is checked too so the overheat drain always wins.
	var overdrive := _rush_momentum.is_overdrive_engaged() and not locked_out

	# The fill target per display mode. Every mode boundary is CONTINUOUS by construction, so
	# the eased fill never visibly jumps on a transition:
	#   • cruise → overdrive: engaging requires heat AT the cruise clamp, i.e. a full bar,
	#     which is exactly overdrive's pinned 1.0;
	#   • overdrive → cruise (bail): heat is above the clamp, so heat/cruise clamps to 1.0
	#     and the bar stays full until the bleed brings heat back under the clamp;
	#   • overdrive → lockout (overheat): heat is at/near the hard ceiling, so heat/ceiling
	#     starts ≈ 1.0 and the drain animates down from there;
	#   • lockout → cruise (re-arm): heat drained to 0, and 0/cruise is 0.
	# A First Contact reset mid-anything is the one hard cut (heat snaps to 0) — the eased
	# fill glides down, which reads as the meter powering off, and is fine.
	var target_fill: float
	if locked_out:
		# OVERHEAT: the full-heat drain display, unchanged — fill = heat / hard_ceiling so the
		# visible drain IS the cooldown. Guard the knob so a 0 can't divide by zero.
		var hard_ceiling: float = maxf(_tuning.rush_momentum_hard_ceiling, 0.0001)
		target_fill = clampf(_rush_momentum.heat / hard_ceiling, 0.0, 1.0)
	elif overdrive:
		# OVERDRIVE: pinned full — the bar is the minigame stage, not a heat plot (see the
		# class comment for why pinned-full beat fill-as-countdown).
		target_fill = 1.0
	else:
		# CRUISE/BUILD: the whole bar spans 0 → the cruise clamp, so filling the bar IS
		# reaching cruise (Tim 2026-07-19). Legacy Cooling Systems moves the clamp; the
		# guard covers a hand-poked zero cruise bonus.
		var cruise: float = maxf(_rush_momentum.cruise_heat(), 0.0001)
		target_fill = clampf(_rush_momentum.heat / cruise, 0.0, 1.0)
	_displayed_fill = BarSmoothing.approach(_displayed_fill, target_fill, delta)
	_meter.value = _displayed_fill

	# Feed the overdrive instrument. Everything it shows is DERIVED FRESH each frame from the
	# core's live getters — that per-frame derivation IS the orphan watchdog: an approach or
	# window the core silently tore down (release-disengage, overheat, First Contact reset)
	# simply stops appearing on the very next frame, so a stale red bar or stale pips cannot
	# exist. (The old held-open "VENT!" chip needed an explicit watchdog for exactly this;
	# deriving instead of retaining removes the failure mode outright.)
	if overdrive:
		# The event bar's travel fraction: 1.0 at the right edge when the event spawns, 0.0 at
		# the target bar when the window opens — remaining / total, so a frenzy freeze (which
		# pauses the core's approach clock) visibly halts the bar mid-flight.
		var event_frac := -1.0  # negative = no event bar drawn
		if _rush_momentum.is_vent_approaching() and _vent_approach_seconds > 0.0:
			var approach_core := _rush_momentum.vent_approach_remaining()
			_approach_display = _predict_clock(
					_approach_display, approach_core, _approach_core_seen, delta)
			_approach_core_seen = approach_core
			event_frac = clampf(_approach_display / _vent_approach_seconds, 0.0, 1.0)
		var window_open := _rush_momentum.is_vent_window_open()
		var countdown_frac := 0.0
		if window_open:
			var window_core := _rush_momentum.vent_window_remaining()
			_window_display = _predict_clock(_window_display, window_core, _window_core_seen, delta)
			_window_core_seen = window_core
			countdown_frac = clampf(_window_display / _vent_window_duration, 0.0, 1.0)
		_instrument.update_overdrive(TARGET_FRAC, event_frac, window_open, countdown_frac,
				_rush_momentum.vent_required_lifts(), _window_lifts_done)
	elif locked_out:
		# The dead-bar gray: during the drain it back-fills behind the shown (eased) fill edge —
		# the same _displayed_fill the meter draws, so the gray meets the red with no seam —
		# and during the re-arm it recedes on the core's real countdown fraction.
		# Snap UP, ease DOWN. The fraction jumps 0 → 1 the instant the drain ends and the re-arm
		# begins; easing INTO that would draw a zero-width gray on the transition frame and grow
		# it, flashing the dead bar back to life for a moment before it recedes. Only the recede
		# needs smoothing.
		var rearm_core := _rush_momentum.rearm_remaining_fraction()
		_rearm_display = rearm_core if rearm_core > _rearm_display \
				else BarSmoothing.approach(_rearm_display, rearm_core, delta)
		_instrument.update_lockout(_displayed_fill, _rearm_display)
	else:
		_instrument.update_idle()

	# The OVR button is a permanent fixture (Tim 2026-07-16: moving UI elements are annoying);
	# it ENABLES only once the hold has actually REACHED the cruise clamp (Tim 2026-07-16) —
	# cruising during the climb toward it stays gray — and shows the gray "can't trigger"
	# plate any other time. The >= (not ==) covers the re-press-while-still-hot case: heat
	# bleeding DOWN toward the clamp is already at cruise depth, so the gamble is available
	# immediately rather than after the cooldown dips below and climbs back.
	var at_cruise_depth: bool = _rush_momentum.heat >= _rush_momentum.cruise_heat() \
			or is_equal_approx(_rush_momentum.heat, _rush_momentum.cruise_heat())
	_overdrive_button.disabled = not (cruising and at_cruise_depth)

	# The label: the live bonus normally; "CRUISE +X%" while the clamp is holding steady; the
	# lockout narration while shut down. is_rearming is checked FIRST — it is a sub-state of
	# is_locked_out (both true during the re-arm delay).
	if _rush_momentum.is_rearming():
		_label.text = "COOLING…"
		_apply_label_state(_LabelState.COOLING)
	elif locked_out:
		_label.text = "OVERHEATED"
		_apply_label_state(_LabelState.OVERHEATED)
	elif cruising and is_equal_approx(_rush_momentum.heat, _rush_momentum.cruise_heat()) \
			and not _rush_momentum.is_spinning_down():
		# Sitting exactly on the clamp: the steady, content cruise state. The bonus quotes
		# effective_cruise_bonus() (base +25% plus Cooling Systems levels), never a hardcoded
		# number. While still CLIMBING toward the clamp the normal "+X%" branch below narrates
		# the climb, exactly as before.
		#
		# The spin-down guard is load-bearing (Tim device report, 2026-07-20). After a bail you
		# can re-press and settle onto the clamp while a BANKED bonus is still leading — the core
		# is paying max(live, banked), so quoting the cruise constant here would show "+25%" while
		# the player actually earns the banked value, and the BANKED chip beside it said so. The
		# readout must never contradict what is being paid, least of all by UNDERSELLING the
		# reward this whole mechanic exists to grant. Falling through to the "+X%" branch below
		# reports the true effective bonus, and the chip keeps naming where it comes from.
		_label.text = "CRUISE +%d%%" % int(round(_rush_momentum.effective_cruise_bonus() * 100.0))
		_apply_label_state(_LabelState.CRUISING)
	else:
		_label.text = "+%d%%" % int(round(_rush_momentum.bonus * 100.0))
		_apply_label_state(_LabelState.NORMAL)

	# A locked meter is not accruing anything: hide the carbonation while it drains/re-arms so the
	# shutdown reads as dead air, not business as usual.
	_bubbles.visible = not locked_out

	# The BANKED chip: up for exactly as long as a voluntarily banked bonus is still worth more
	# than the live state would pay. This is the ONLY signal that bailing is different from
	# blowing up (Tim 2026-07-20: "yes, and say so in the UI") — an overheat zeroes the bonus
	# instantly, so it simply never shows this chip, and the contrast between "BANKED … DRAINING"
	# and nothing at all is what teaches the choice.
	#
	# The chip quotes banked_bonus() rather than the bar's own "+X%" readout on purpose: they are
	# the same number during a spin-down (the core's effective bonus IS the banked value while it
	# leads), and naming the source here keeps the chip honest if that ever stops being true.
	# Hidden during a lockout regardless, so a stale chip can never sit over the overheat display.
	var spinning_down: bool = _rush_momentum.is_spinning_down() and not locked_out
	_banked_chip.visible = spinning_down
	if spinning_down:
		_banked_chip_label.text = "BANKED +%d%% — DRAINING" \
				% int(round(_rush_momentum.banked_bonus() * 100.0))

	# The salmon streaks mark the overdrive ride itself now: with the fill pinned full, they are
	# the motion cue that the bar has switched into its minigame instrument. Never while merely
	# cruising or locked out.
	_streaks.visible = overdrive

	_update_fill_color(delta, locked_out, overdrive)


## Recolor the fill AND its bubbles for the current display mode. Cruise/build mode is the calm
## instrument: always DARK_PURPLE, no wash, no blink (Tim 2026-07-19: clean and safe-reading).
## In OVERDRIVE mode the fill is pinned full and its COLOR carries the depth urgency instead:
## Advance one frame-rate display clock (see the _approach_display fields for why these exist).
##
## `core_value` is the core's authoritative seconds-remaining, republished only on the 10 Hz logic
## tick; `core_seen` is what it read LAST frame. The rules:
##   • The core's value going UP means a brand-new event or window — prediction can never do that,
##     so take it exactly. (Comparing against core_seen, not against the display: between ticks the
##     display legitimately falls BELOW a held core value, and treating that as a jump would snap
##     the bar back every frame — the very stutter this fixes.)
##   • Otherwise run down on the frame delta, clamped to stay within one logic tick of the truth.
##     The display leaves each tick equal to the core and arrives at the next exactly a tick lower,
##     so it glides continuously while never drifting more than one tick out of step.
func _predict_clock(display: float, core_value: float, core_seen: float, delta: float) -> float:
	if core_value > core_seen:
		return core_value
	var tick_seconds := 1.0 / maxf(float(_tuning.logic_hz), 1.0)
	return clampf(display - delta, maxf(core_value - tick_seconds, 0.0), core_value)


## purple → amber sliding with overdrive depth — heat's position within [cruise point .. hard
## ceiling], the same fraction the core's hazard rate interpolates on, so the bar's urgency and
## the actual vent-check danger climb together — with the red warning blink ramping in strength
## and frequency on that same depth. The blink's strength ramp starts at ZERO, so shallow riding
## barely shimmers and there is no depth at which it snaps on (no re-created band edge).
## Mutates the cached fill stylebox's bg_color, so no styleboxes are rebuilt.
func _update_fill_color(delta: float, locked_out: bool, overdrive: bool) -> void:
	if locked_out:
		# Draining after an overheat: a flat dark red — the punishment color, no blink (the
		# urgency is over; the player is just watching the cooldown empty out).
		_fill_style.bg_color = UiPalette.BRICK
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		return

	if not overdrive:
		# Cruise/build: the steady, CONTENT look, whatever heat is doing (including bleeding
		# back down after a bailed ride — the bar left the danger business when overdrive
		# disengaged, so no danger color may linger).
		_fill_style.bg_color = UiPalette.DARK_PURPLE
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		_blink_phase = 0.0
		return

	# Overdrive depth: how far into [cruise point .. hard ceiling] heat is riding.
	var heat: float = _rush_momentum.heat
	var cruise_heat: float = _rush_momentum.cruise_heat()
	var hard_ceiling: float = maxf(_tuning.rush_momentum_hard_ceiling, 0.0001)
	var depth_span: float = maxf(hard_ceiling - cruise_heat, 0.0001)
	var depth_frac: float = clampf((heat - cruise_heat) / depth_span, 0.0, 1.0)

	# Base color: fill and bubbles slide purple → amber across the whole overdrive span.
	var base_fill: Color = UiPalette.DARK_PURPLE.lerp(UiPalette.MUSTARD_GOLD, depth_frac)
	_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE.lerp(UiPalette.PALE_GOLD, depth_frac)

	# The red warning blink, pulsing the base color toward KETCHUP_RED. Phase accumulates at
	# the CURRENT frequency so the ramping frequency never makes the sine jump. Strength
	# scales straight off depth_frac (zero at the cruise point): shallow overdrive barely
	# shimmers, riding just under the backstop flashes hard and fast.
	var blink_hz: float = lerpf(BLINK_HZ_MIN, BLINK_HZ_MAX, depth_frac)
	var strength: float = BLINK_STRENGTH_MAX * depth_frac
	_blink_phase += delta * blink_hz * TAU
	var pulse: float = (sin(_blink_phase) * 0.5 + 0.5) * strength
	_fill_style.bg_color = base_fill.lerp(UiPalette.KETCHUP_RED, pulse)


## Swap the readout label's look per state. Only rebuilds the overrides on a change.
## OVERHEATED reads in red with a cream outline — the fill behind it is dark red while draining,
## so the outline carries the contrast (§1b: the failure state must be readable, not subtle).
func _apply_label_state(state: int) -> void:
	if state == _label_state_applied:
		return
	_label_state_applied = state
	match state:
		_LabelState.CRUISING:
			# Calm teal: the "settled in, safe forever" color — deliberately nothing like the
			# amber/red danger escalation. The navy outline keeps it readable over both the
			# dark purple fill and the pale track.
			_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
			_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
			_label.add_theme_constant_override("outline_size", 6)
		_LabelState.OVERHEATED:
			_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
			_label.add_theme_color_override("font_outline_color", UiPalette.CREAM)
			_label.add_theme_constant_override("outline_size", 8)
		_LabelState.COOLING:
			# Calm near-white gold: "almost back" — distinct from both the red failure text and
			# the plain white live readout.
			_label.add_theme_color_override("font_color", UiPalette.PALE_GOLD)
			_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
			_label.add_theme_constant_override("outline_size", 6)
		_:
			_label.add_theme_color_override("font_color", Color.WHITE)
			_label.remove_theme_color_override("font_outline_color")
			_label.add_theme_constant_override("outline_size", 0)


## Heat hit the hard ceiling, or a vent window was missed: the shutdown moment. The
## label/fill/instrument changes are all per-frame state reads (see _process — the instrument
## clears itself the moment the mode flips, so there is no telegraph to dismiss here any more);
## this handler only adds the long haptic thump so the failure lands physically as well as
## visually.
func _on_overheated() -> void:
	_vibrate(_tuning.rush_momentum_haptic_overheat_ms)


## The re-arm delay finished: rush is available again. Flash the whole meter bright once (plus a
## short haptic tick) so re-availability is unmissable — the label reverts to "+0%" on its own
## via _process now that is_locked_out() is false.
func _on_rush_ready() -> void:
	_vibrate(_tuning.rush_momentum_haptic_ready_ms)
	_ready_flash.color = Color(1, 1, 1, READY_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_ready_flash, "color:a", 0.0, READY_FLASH_FADE_SEC)


# ---------------------------------------------------------------------------
# Vent Windows: the approach telegraph and its resolutions
# (Plans/Overdrive_Vent_Windows.md, approach-bar rework Tim 2026-07-19)
# ---------------------------------------------------------------------------

## A vent event just SPAWNED at the bar's right edge (~approach_seconds from triggering). Record
## the divisor for the event bar's travel math, and fire the vent haptic HERE, at the spawn —
## not at window-open — because a warning pulse with the whole approach still ahead is what a
## telegraph haptic is FOR (it preserves the shipped meaning: "a check is coming, get ready",
## with time to act on it). At window-open a buzz would land at the exact instant the player
## should already be lifting — too late to help, and it would smear the physical beat players
## calibrate their gesture timing against. The visual "NOW" is the red bar reaching the target.
## The pulse also COUNTS the demand: one buzz per required lift (Tim 2026-07-20) — see
## _pulse_vent_telegraph.
func _on_vent_incoming(approach_seconds: float, required_lifts: int) -> void:
	_vent_approach_seconds = maxf(approach_seconds, 0.001)
	# Start the display clock exactly at the spawn value: the event is at the right edge NOW.
	# (_predict_clock's snap-on-increase rule would catch this anyway; setting it here makes the
	# first drawn frame exact rather than inferred.)
	_approach_display = _vent_approach_seconds
	_approach_core_seen = _vent_approach_seconds
	_pulse_vent_telegraph(required_lifts)


## The event reached the target: the window is open, the gesture clock is running. All the
## presentation is in-bar now (pips + countdown via the instrument overlay, driven per frame by
## _process) — no chip: the old held-open gold "VENT!" plate is retired, replaced by the
## approaching red bar the player has been watching for the whole approach.
func _on_vent_window_opened(_required_lifts: int, duration: float) -> void:
	_vent_window_duration = maxf(duration, 0.001)
	# The countdown starts full this instant — same reasoning as the approach clock above.
	_window_display = _vent_window_duration
	_window_core_seen = _vent_window_duration
	_window_lifts_done = 0


## A gesture lift landed: the in-bar pip display fills one more (the ×2/×3 vents need the
## player to KNOW each lift registered). _process feeds the tally to the instrument.
func _on_vent_lift_registered(lifts_done: int, _required_lifts: int) -> void:
	_window_lifts_done = lifts_done


## Vent completed in time: heat drops and the bonus ladder ratchets up a rung. A timed chip
## quotes the NEW excursion peak (the signal's value, so the number can never drift from the
## core's ladder), in celebratory money-green, plus the same full-meter white flash the READY
## moment uses — success should feel like a payoff, not mere survival.
func _on_vent_succeeded(new_tier: int, new_peak_bonus: float) -> void:
	# "UP TO", not "PEAK" (Tim, 2026-07-20). This number is current_peak_bonus() — the CEILING of
	# the ladder you have just unlocked, i.e. what you would earn riding at the hard backstop — not
	# what you are earning right now. The bar's own "+X%" and the BANKED chip both report the LIVE
	# lerped bonus, which is always lower unless heat is pinned at the ceiling. Tim read all three
	# on device and reasonably took them for the same quantity disagreeing.
	#
	# The ceiling stays on screen deliberately rather than being hidden to make the numbers match:
	# it is the whole reason riding deeper pays, so it earns its place — it just has to be LABELLED
	# as a ceiling. Naming the tier alongside it also gives the run its running score, which is what
	# Tim was looking for in this chip. The green plate and the chip's arrival remain the "you did
	# it" signal, so the words are free to carry the new information instead of repeating it.
	_show_tier_chip(
			"TIER %d — UP TO +%d%%" % [new_tier, int(round(new_peak_bonus * 100.0))],
			UiPalette.MONEY_GREEN, UiPalette.NAVY)
	_ready_flash.color = Color(1, 1, 1, READY_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_ready_flash, "color:a", 0.0, READY_FLASH_FADE_SEC)


## The window was blown (expired, or the gesture fumbled) — fired just before the overheat
## lands. The blown beat must stay VISIBLE (the plan's rule: miss-feedback is what makes the
## skill check learnable), and the bar itself can't show it — the overheat flips the bar into
## its drain display, wiping the in-bar pips — so the miss CHIP carries the pips: the demanded
## count with the landed ones solid and the unfinished ones strobing red, held for the chip's
## timed life while the OVERHEATED presentation plays underneath.
func _on_vent_missed(lifts_done: int, required_lifts: int) -> void:
	_vent_pips.show_miss(required_lifts, lifts_done)
	_show_tier_chip("VENT MISSED!", UiPalette.KETCHUP_RED, UiPalette.PALE_GOLD)


## Show the tier chip: set its text/colors, ease it in, hold, fade out. A new chip request while
## the old chip is still up simply restarts the sequence with the new text. The end-of-fade
## cleanup also retires the miss pips + strobe, so a miss chip tidies itself up and the next
## chip can never inherit stale pips.
func _show_tier_chip(text: String, plate_color: Color, text_color: Color) -> void:
	_style_tier_chip(text, plate_color, text_color)
	if _tier_chip_tween != null and _tier_chip_tween.is_valid():
		_tier_chip_tween.kill()
	_tier_chip.visible = true
	_tier_chip.modulate = Color(1, 1, 1, 0)
	_tier_chip_tween = create_tween()
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 1.0, TIER_CHIP_FADE_IN_SEC)
	_tier_chip_tween.tween_interval(TIER_CHIP_HOLD_SEC)
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 0.0, TIER_CHIP_FADE_OUT_SEC)
	_tier_chip_tween.tween_callback(func() -> void:
		_tier_chip.visible = false
		_vent_pips.visible = false
		_vent_pips.stop_miss_flash())


## Apply text + plate/text colors to the chip.
func _style_tier_chip(text: String, plate_color: Color, text_color: Color) -> void:
	_tier_chip_label.text = text
	_tier_chip_label.add_theme_color_override("font_color", text_color)
	var plate := StyleBoxFlat.new()
	plate.bg_color = plate_color
	plate.border_color = UiPalette.NAVY
	plate.set_border_width_all(3)
	plate.set_corner_radius_all(8)
	plate.set_content_margin_all(14)
	_tier_chip.add_theme_stylebox_override("panel", plate)


## Haptic tap, mobile only — desktop must stay silent (Input.vibrate_handheld is a no-op on most
## desktops anyway, but the explicit guard documents the intent and costs nothing). Takes the
## tuning knob's float directly; a knob dialed to 0 (or below) disables that pulse.
func _vibrate(duration_ms: float) -> void:
	if duration_ms >= 1.0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration_ms))


## The vent telegraph's haptic: ONE PULSE PER REQUIRED LIFT (Tim 2026-07-20). A x2 window buzzes
## twice, a x3 three times, so the thumb already knows the demand before the eyes get to the pips
## — deliberate redundant encoding for the moment the mechanic is fastest.
##
## The pulses are played as a train rather than one long buzz: each pulse waits out its OWN length
## plus the gap knob before the next fires, so the player feels distinct counted beats. This is a
## coroutine (it awaits scene-tree timers), which is why it is fire-and-forget from the signal
## handler — the caller does not await it.
##
## Sized to fit inside the approach: at the shipped 80 ms pulse + 70 ms gap, three pulses take
## ~370 ms against a 1.2 s runway. The is_inside_tree() re-check after each wait covers the bar
## being torn down mid-train (screen change, First Contact reset).
func _pulse_vent_telegraph(required_lifts: int) -> void:
	var pulse_ms: float = _tuning.rush_momentum_haptic_vent_ms
	if pulse_ms < 1.0 or not OS.has_feature("mobile"):
		return  # knob disabled, or desktop — no train to play
	var pulses: int = maxi(required_lifts, 1)
	var gap_ms: float = maxf(_tuning.rush_momentum_haptic_vent_gap_ms, 0.0)
	for i in range(pulses):
		_vibrate(pulse_ms)
		if i == pulses - 1:
			return
		await get_tree().create_timer((pulse_ms + gap_ms) / 1000.0).timeout
		if not is_inside_tree():
			return


# ---------------------------------------------------------------------------
# The overdrive instrument overlay
# ---------------------------------------------------------------------------

## Custom-drawn overlay for the bar's OVERDRIVE minigame instrument (the same _draw approach
## MomentumStreaks uses), plus the OVERHEAT lockout's dead-bar gray — its one job outside
## overdrive. Draws NOTHING in cruise/build mode: the calm bar is deliberately unadorned now
## that its right edge IS the cruise point.
##
## In overdrive mode it draws, back to front:
##   • the APPROACH TRAIL: while the red event bar travels left, the region from the bar back
##     to the RIGHT edge fills with a dim gold wash — the event "fills in behind" its leading
##     edge (Tim 2026-07-18 night), so the approach reads as a REGION sweeping in, not a lone
##     thin bar. Dim MUSTARD_GOLD — the same act-now gold family as the target bar and the
##     open-window dressing — so the approach and the open event share one visual identity:
##     the trail IS the event backdrop, arriving.
##   • while a window is OPEN: the EVENT BACKDROP — the same gold wash, a step brighter, held
##     STEADY across the whole region right of the target. The trail grows to cover exactly
##     this region at the instant the event arrives, so opening reads as "the sweep completed
##     and lit up", never a cut to something new.
##   • while a window is OPEN: the TIMER STRIP — a thin, bright-gold horizontal bar hugging
##     the region's bottom edge, its right end draining left toward the target as time runs
##     out. It replaces the old full-region draining plate (which would now fight the steady
##     backdrop for the same pixels). Bottom placement keeps it clear of the centered pips;
##     spanning the full region means full strip = full window at a glance; and the leftward
##     drain continues the established motion language — everything about an event collapses
##     leftward into the target, so "the strip reaches the target = time's up" needs no
##     explanation.
##   • while a window is OPEN: the gesture pips, centered in the whole region right of the
##     target (VentPipRow's ring/disc drawing adapted to bar scale — ring = lift still owed,
##     solid disc = landed), brightened to be the most luminous marks on the bar (see the pip
##     color constants).
##   • the traveling EVENT BAR: bright red, entering at the right edge and moving left; its
##     reaching the target IS the window opening.
##   • the fixed TARGET BAR at TARGET_FRAC: the trigger point. Same wide-bar silhouette as the
##     retired teal cruise marker (a shape the player already reads as "a line that matters"),
##     but in MUSTARD_GOLD — the act-now family the old "VENT!" chip established — because
##     this line is where acting happens, not where safety ends. Drawn LAST so nothing tints it.
##
## In LOCKOUT (Tim 2026-07-18 night) it draws the dead-bar gray:
##   • drain phase: dark gray back-fills the track the shrinking red fill reveals, so the bar
##     visibly dies from the right as it cools;
##   • re-arm phase: the gray covers the whole bar, then its right edge recedes leftward in
##     proportion to the re-arm countdown, revealing the normal track gray behind it — the
##     gray's retreat IS the visual re-arm timer, and the READY flash lands on a bar that
##     already looks normal again.
##
## All x math uses the FILL's coordinate system (frac × size.x − inset): ProgressBar computes
## its fill rect across the bar's FULL width and the fill stylebox's −3px expand margin pulls
## the drawn edge back by the inset. Mapping fractions onto the inset track instead put markers
## ~1-2px off the true fill edge — the documented off-by-inset gotcha (Tim 2026-07-15).
class OverdriveInstrumentOverlay extends Control:
	## Match the framed fill's 3px inset (UiPalette.style_framed_progress).
	const EDGE_INSET := 3.0
	## The fixed target bar (the trigger point). Wide like the old cruise marker was — the one
	## landmark on the track must land at a glance (Tim 2026-07-16).
	const TARGET_BAR_WIDTH := 10.0
	const TARGET_BAR_COLOR := Color("#E3B23C")        # MUSTARD_GOLD — the act-now family
	## The traveling vent event: bright red, unmistakably "incoming trouble".
	const EVENT_BAR_WIDTH := 10.0
	const EVENT_BAR_COLOR := Color("#E8503A")         # KETCHUP_RED, brightened to read as LIVE
	## The approach trail and the open window's backdrop: ONE gold at two strengths. The
	## countdown plate's MUSTARD_GOLD family was kept on purpose (Tim 2026-07-18 night) so the
	## whole event lifecycle — trail, backdrop, timer strip, target bar — wears one identity;
	## the trail is the DIMMER of the two so the region lighting up a step at the arrival
	## instant reads as an escalation, not a repaint. Same hue, only alpha apart, so the trail
	## growing to full width IS the backdrop appearing — a seamless open.
	const APPROACH_TRAIL_COLOR := Color("#E3B23C", 0.25)   # dim translucent MUSTARD_GOLD
	const WINDOW_BACKDROP_COLOR := Color("#E3B23C", 0.40)  # the same gold, lit up
	## The open window's TIMER STRIP (replaces the full-region draining plate): thin, opaque,
	## and a notch brighter than MUSTARD_GOLD so it stays readable ON the translucent gold
	## backdrop it drains across. Geometry: hugs the region's bottom edge, below the centered
	## pips, with a small gap so it never welds visually onto the frame.
	## Device-pass contrast fix (Tim 2026-07-18: strip and pips were "too dim to see"): the
	## strip and pips sit on a GOLD backdrop over an amber fill wash, so gold-family marks
	## vanished into their own hue. Brightness alone can't fix same-hue stacking — each mark
	## now gets a DARK NAVY backing (a full-runway track under the strip, a halo behind each
	## pip) so the bright mark reads by contrast at any wash depth.
	const TIMER_STRIP_COLOR := Color("#FFF7E6")            # near-white warm, matches landed pips
	const TIMER_TRACK_COLOR := Color("#1D2D50", 0.85)      # UiPalette.NAVY backing track
	const TIMER_STRIP_HEIGHT := 8.0
	const TIMER_TRACK_PAD := 2.0                           # navy border visible around the strip
	const TIMER_STRIP_BOTTOM_GAP := 3.0
	## Everything the timer strip claims off the bar's bottom edge (gap + strip + the navy
	## backing track's padding). The pips are centered in the space ABOVE this band rather
	## than in the whole region, so the bigger pips (see PIP_RADIUS_MAX) can never overlap
	## the strip — two separate reads must never share pixels.
	const TIMER_STRIP_RESERVED := TIMER_STRIP_BOTTOM_GAP + TIMER_STRIP_HEIGHT + TIMER_TRACK_PAD
	## In-bar gesture pips, BRIGHTENED (Tim 2026-07-18 night — the old cream washed out against
	## the gold backdrop). A landed lift is a near-white disc — deliberately the most luminous
	## mark on the whole bar, because a registered beat is the confirmation the gesture lives
	## or dies on — and an owed lift is a bright-gold ring: luminous enough to pop off the
	## backdrop for contrast, while the solid-vs-outline SHAPE difference (not brightness
	## alone) is what keeps filled-vs-owed instantly distinguishable at a glance.
	const PIP_FILLED_COLOR := Color("#FFF7E6")             # near-white warm
	const PIP_RING_COLOR := Color("#FFF7E6")               # near-white too — the halo, not hue, separates it
	const PIP_HALO_COLOR := Color("#1D2D50", 0.85)         # navy halo behind every pip (contrast fix)
	const PIP_HALO_PAD := 5.0                              # halo radius beyond the pip silhouette
	const PIP_OUTLINE := 8.0
	## Pip radius as a fraction of the bar's inner height, with a hard cap so a desktop-resized
	## bar can't grow comedy pips. Three pips at this size fit the two-thirds-width region on
	## the narrowest supported phone with room to spare.
	## SIZE BUMP (Tim 2026-07-20: pips "readable but small"). BOTH numbers had to move: the
	## cap was the BINDING constraint at the shipped bar height, so raising the fraction
	## alone would have changed nothing on the phone. Radius 20 → 26 px (diameter 40 → 52).
	## The halo pad and the ring stroke went up with it (4 → 5, 6 → 8) so the proportions —
	## and so the filled-disc vs owed-ring read — stay as crisp as before, just larger.
	const PIP_HEIGHT_FRAC := 0.40
	const PIP_RADIUS_MAX := 26.0
	## Center-to-center pip spacing, in pip radii.
	const PIP_SPACING_RADII := 3.0

	## The lockout's dead-bar gray. Far darker than the normal PROGRESS_TRACK_GRAY (#B6BAC0)
	## so a locked bar is unmistakably DEAD at a glance, but a neutral slate rather than
	## near-black: the draining BRICK-red fill must still read against it, and red on a
	## neutral dark gray keeps its hue contrast where red on near-black would just be two
	## dark shapes.
	const LOCKOUT_GRAY := Color("#45464C")

	## Display state, fed every frame by the host's _process (derived fresh from the core each
	## frame — see the watchdog note there). _event_frac < 0 means no event bar. _active and
	## _lockout are mutually exclusive modes; both false = the invisible cruise/build idle.
	var _active := false
	var _target_frac := 0.33
	var _event_frac := -1.0
	var _window_open := false
	var _countdown_frac := 0.0
	var _required_lifts := 1
	var _lifts_done := 0
	var _lockout := false
	var _lockout_fill_frac := 0.0
	var _rearm_frac := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Overdrive mode: update the instrument's geometry; redraws only on actual change.
	func update_overdrive(target_frac: float, event_frac: float, window_open: bool,
			countdown_frac: float, required_lifts: int, lifts_done: int) -> void:
		if _active and not _lockout and is_equal_approx(target_frac, _target_frac) \
				and is_equal_approx(event_frac, _event_frac) \
				and window_open == _window_open \
				and is_equal_approx(countdown_frac, _countdown_frac) \
				and required_lifts == _required_lifts and lifts_done == _lifts_done:
			return
		_active = true
		_lockout = false
		_target_frac = target_frac
		_event_frac = event_frac
		_window_open = window_open
		_countdown_frac = countdown_frac
		_required_lifts = required_lifts
		_lifts_done = lifts_done
		queue_redraw()

	## Overheat lockout mode: the dead-bar gray. `fill_frac` is the meter's SHOWN (eased) fill,
	## so the gray's left edge meets the draining red fill with no seam; `rearm_frac` is the
	## core's re-arm countdown remaining (0 while the drain phase still runs).
	func update_lockout(fill_frac: float, rearm_frac: float) -> void:
		if _lockout and is_equal_approx(fill_frac, _lockout_fill_frac) \
				and is_equal_approx(rearm_frac, _rearm_frac):
			return
		_lockout = true
		_active = false
		_lockout_fill_frac = fill_frac
		_rearm_frac = rearm_frac
		queue_redraw()

	## Cruise/build mode: the instrument draws nothing.
	func update_idle() -> void:
		if not _active and not _lockout:
			return
		_active = false
		_lockout = false
		queue_redraw()

	func _draw() -> void:
		var top := EDGE_INSET
		var bottom := size.y - EDGE_INSET
		if size.x <= EDGE_INSET * 2.0 or bottom <= top:
			return
		if _lockout:
			_draw_lockout(top, bottom)
			return
		if not _active:
			return
		# Fraction → x pixel in the fill's coordinate system (see the class comment).
		var target_x := maxf(_target_frac * size.x - EDGE_INSET, EDGE_INSET)
		var right_x := size.x - EDGE_INSET
		var runway := right_x - target_x
		if runway <= 0.0:
			return

		if _window_open:
			# The steady event backdrop across the whole region right of the target — the lit
			# stage the pips and the timer strip play on (the countdown no longer moves it).
			draw_rect(Rect2(target_x, top, runway, bottom - top), WINDOW_BACKDROP_COLOR)
			# The timer strip: anchored at the target, right end draining left as the window
			# runs out (placement + drain-direction rationale in the class comment).
			var strip_top := bottom - TIMER_STRIP_BOTTOM_GAP - TIMER_STRIP_HEIGHT
		# Navy backing track across the FULL runway first — the strip drains against it,
			# so both the remaining time and the elapsed gap read at a glance (contrast fix).
			draw_rect(Rect2(target_x - TIMER_TRACK_PAD, strip_top - TIMER_TRACK_PAD,
					runway + TIMER_TRACK_PAD * 2.0,
					TIMER_STRIP_HEIGHT + TIMER_TRACK_PAD * 2.0), TIMER_TRACK_COLOR)
			var strip_width := runway * clampf(_countdown_frac, 0.0, 1.0)
			if strip_width > 0.0:
				draw_rect(Rect2(target_x, strip_top, strip_width, TIMER_STRIP_HEIGHT),
						TIMER_STRIP_COLOR)
			_draw_pips(target_x, right_x, top, bottom)

		if _event_frac >= 0.0:
			# The traveling event: position interpolates target → right edge on the approach
			# fraction (1.0 just spawned, 0.0 = arrived = window opening). Clamped so the bar
			# never pokes past the frame at either end of its run.
			var event_x := target_x + runway * clampf(_event_frac, 0.0, 1.0)
			var half := EVENT_BAR_WIDTH * 0.5
			event_x = clampf(event_x, target_x, right_x - half)
			# The approach trail FIRST, from the event bar's center back to the right edge —
			# the region filling in behind the leading edge (the event bar draws over the
			# seam). Center, not the bar's left edge, so the trail can never peek out ahead
			# of the red bar and muddy which edge is leading.
			if right_x - event_x > 0.0:
				draw_rect(Rect2(event_x, top, right_x - event_x, bottom - top),
						APPROACH_TRAIL_COLOR)
			draw_rect(Rect2(event_x - half, top, EVENT_BAR_WIDTH, bottom - top),
					EVENT_BAR_COLOR)

		# The target bar, drawn LAST so neither the backdrop nor an arriving event tints it.
		draw_rect(Rect2(target_x - TARGET_BAR_WIDTH * 0.5, top, TARGET_BAR_WIDTH,
				bottom - top), TARGET_BAR_COLOR)

	## The lockout's dead-bar gray (see the class comment's LOCKOUT section). The re-arm
	## branch is checked FIRST: the eased fill can lag a hair above zero when the re-arm
	## begins, and the full-width gray must win that frame rather than leave a red sliver.
	func _draw_lockout(top: float, bottom: float) -> void:
		var left_x := EDGE_INSET
		var right_x := size.x - EDGE_INSET
		if _rearm_frac > 0.0:
			# Re-arm phase: the gray anchors at the LEFT and its right edge recedes leftward
			# with the countdown — the same rightward-reveal direction the READY moment then
			# confirms. Width rides the core's real fraction, so Rapid Restart and the
			# per-tier sting are automatically honest.
			var gray_width := (right_x - left_x) * clampf(_rearm_frac, 0.0, 1.0)
			if gray_width > 0.0:
				draw_rect(Rect2(left_x, top, gray_width, bottom - top), LOCKOUT_GRAY)
			return
		# Drain phase: gray back-fills the track behind the shown fill edge — the same
		# frac × width − inset mapping the fill itself uses, so the two meet seamlessly.
		var fill_x := clampf(_lockout_fill_frac * size.x - EDGE_INSET, left_x, right_x)
		if right_x - fill_x > 0.0:
			draw_rect(Rect2(fill_x, top, right_x - fill_x, bottom - top), LOCKOUT_GRAY)

	## The gesture pips at bar scale, centered in the region right of the target: one per
	## demanded lift, ring = still owed, solid disc = landed (VentPipRow's language, adapted).
	## They sit ON TOP of the steady backdrop and keep a fixed position — progress is the pips
	## filling, time is the strip draining; two separate reads, neither moving the other.
	func _draw_pips(region_left: float, region_right: float, top: float, bottom: float) -> void:
		# The band the pips live in: everything above the pixels the timer strip reserves.
		var pip_band_bottom := bottom - TIMER_STRIP_RESERVED
		var center_y := (top + pip_band_bottom) * 0.5
		# Largest pip (INCLUDING its navy halo) that still fits inside that band. This is a
		# safety net for short/resized bars — at the shipped bar height PIP_RADIUS_MAX binds
		# first, which is the intended size.
		var radius_fit := (pip_band_bottom - top) * 0.5 - PIP_HALO_PAD
		var pip_radius := minf(minf((bottom - top) * PIP_HEIGHT_FRAC, PIP_RADIUS_MAX), radius_fit)
		if pip_radius <= 0.0:
			return
		var spacing := pip_radius * PIP_SPACING_RADII
		var row_width := spacing * float(_required_lifts - 1)
		var first_x := (region_left + region_right) * 0.5 - row_width * 0.5
		for i in range(_required_lifts):
			var center := Vector2(first_x + spacing * float(i), center_y)
			# Navy halo behind every pip — the contrast plate the bright mark reads against
			# (see the contrast-fix note at the constants).
			draw_circle(center, pip_radius + PIP_HALO_PAD, PIP_HALO_COLOR)
			if i < _lifts_done:
				draw_circle(center, pip_radius, PIP_FILLED_COLOR)
			else:
				# Radius inset by half the stroke so the ring's OUTER edge matches a filled
				# pip's silhouette — filling a pip must read as "same pip, now solid".
				draw_arc(center, pip_radius - PIP_OUTLINE * 0.5, 0.0, TAU, 48, PIP_RING_COLOR,
						PIP_OUTLINE, true)


# ---------------------------------------------------------------------------
# The miss-feedback pips (chip)
# ---------------------------------------------------------------------------

## The miss chip's gesture post-mortem, drawn inside the tier chip beneath its text line: one
## LARGE pip per demanded lift, the landed ones solid, the unfinished ones strobing red — the
## player sees exactly which beat was blown (the plan's learnability rule). This row exists
## ALONGSIDE the in-bar pips because the overheat that follows a miss instantly flips the bar
## into its drain display, wiping the in-bar pips — the chip is where the evidence survives.
## Live-window duties (the countdown, progressive filling) moved into the bar; this row only
## ever shows the frozen final state. Custom-drawn like OverdriveInstrumentOverlay: two circle
## primitives are cheaper and crisper than textures at this size.
class VentPipRow extends Control:
	## Pip geometry — sized for at-a-glance legibility beside the FONT_HEADLINE chip text
	## (Tim's vision, §1b). Three pips draw 192px wide (2 × spacing + one diameter), narrower
	## than the "VENT MISSED!" headline above them, so the chip's plate is sized by the text
	## and the pips never crowd or overflow it.
	const PIP_RADIUS := 24.0
	const PIP_SPACING := 72.0    # center-to-center
	const PIP_OUTLINE := 5.0
	## Unfinished-pip blink rate — a hard, urgent strobe, clearly a failure.
	const MISS_FLASH_HZ := 6.0

	## Pips draw in the chip's NAVY (matching its border); missed pips strobe KETCHUP_RED (the
	## failure color). Hex literals with palette-name comments, matching the overlay's convention.
	const PIP_COLOR := Color("#1D2D50")         # NAVY
	const MISS_FLASH_COLOR := Color("#B5402A")  # KETCHUP_RED

	var _required := 1
	var _filled := 0
	var _miss_flashing := false
	## Miss-strobe clock in blink cycles (advanced by MISS_FLASH_HZ per second); the integer
	## part's parity picks red vs navy — a square wave, not a sine: an alarm, not a glow.
	var _miss_phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## A window was missed: show the post-mortem — `required` pips, `filled` of them solid,
	## the rest strobing. The host's chip fade calls stop_miss_flash when the chip retires.
	func show_miss(required: int, filled: int) -> void:
		_required = maxi(required, 1)
		_filled = clampi(filled, 0, _required)
		_miss_flashing = true
		_miss_phase = 0.0
		visible = true
		# Reserve the drawn footprint so the chip's containers size the plate around it.
		custom_minimum_size = Vector2(
				PIP_SPACING * float(_required - 1) + PIP_RADIUS * 2.0,
				PIP_RADIUS * 2.0)
		queue_redraw()

	func stop_miss_flash() -> void:
		_miss_flashing = false

	func _process(delta: float) -> void:
		# Only the strobe animates; the row is otherwise static once shown.
		if _miss_flashing and visible:
			_miss_phase += delta * MISS_FLASH_HZ
			queue_redraw()

	func _draw() -> void:
		# Pips, centered horizontally in whatever width the chip's column gave us.
		var row_width := PIP_SPACING * float(_required - 1)
		var first_x := size.x * 0.5 - row_width * 0.5
		for i in range(_required):
			var center := Vector2(first_x + PIP_SPACING * float(i), PIP_RADIUS)
			if i < _filled:
				draw_circle(center, PIP_RADIUS, PIP_COLOR)
			else:
				var ring := PIP_COLOR
				if _miss_flashing and fmod(_miss_phase, 1.0) < 0.5:
					ring = MISS_FLASH_COLOR
				# Radius inset by half the stroke so the ring's OUTER edge matches a filled
				# pip's silhouette — filling a pip must read as "same pip, now solid".
				draw_arc(center, PIP_RADIUS - PIP_OUTLINE * 0.5, 0.0, TAU, 48, ring,
						PIP_OUTLINE, true)
