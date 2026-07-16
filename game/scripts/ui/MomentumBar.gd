class_name MomentumBar
extends HBoxContainer

# The Rush Momentum / Heat control (Tim 2026-07-12; Rush Overheat rework Tim 2026-07-15;
# Cruise Control amendment Tim 2026-07-16): the OVERDRIVE button beside a display-only heat
# meter — the same square-button-plus-meter shape as the frenzy TURBO control (FrenzyBar).
# Momentum is earned by rushing the PROPERTIES, so the meter itself is still not a button;
# the OVR button is the ONE tappable piece, enabled only mid-hold (see below).
#
# Overheat (Plans/Rush_Overheat.md) turned the old 0..cap meter into a push-your-luck heat
# gauge, so the meter shows the FULL heat range 0..ceiling_max:
#   • a wide teal CRUISE bar marks the cruise point — everything left of it is safe;
#   • from the cruise bar to the hazard zone the track is ONE continuous amber ramp in a single
#     hue, deepening across its whole width, with NO internal tick lines (Tim 2026-07-16: one
#     continuous section, a single base color, the effect changing throughout — this replaced
#     the original thin white heat==1.0 tick + flat amber Hot wash);
#   • the Critical band [critical_start .. ceiling_max] is hazard-striped dark red — the real
#     overheat point is rolled secretly inside it every excursion, so the WHOLE zone reads as
#     "gamble territory" rather than promising a precise edge (Tim 2026-07-15: the exact point
#     of overheating should not be predictable);
#   • the fill and its bubbles shift purple → amber continuously from the cruise point to the
#     hazard zone, then blinking red inside Critical, the blink growing faster and harder the
#     deeper the player pushes;
#   • crossing into Critical pops a large tier chip ("CRITICAL +55%!") quoting the peak bonus —
#     the prize being approached — so the escalation is legible without reading the number
#     (entering Hot is chipless: the fill shift and streaks carry it; Tim 2026-07-15);
#   • on overheat the label swaps to "OVERHEATED" while the fill visibly drains (the drain IS
#     the cooldown display), then "COOLING…" through the re-arm delay, then a bright READY flash.
#
# Cruise Control (Plans/Rush_Cruise_Control.md) made the danger bands OPT-IN: holding rush is
# safe forever, with heat clamped at the cruise point, until the player taps OVERDRIVE.
#   • The OVR button is ALWAYS visible (Tim 2026-07-16: moving UI elements are annoying) but
#     ENABLED only once the hold has REACHED the cruise clamp — is_cruising() AND heat at the
#     cruise point; the climb toward the clamp stays gray (Tim 2026-07-16). Any other time it
#     wears the gray-outlined "can't trigger" plate, like TURBO.
#   • While the clamp is holding, the readout reads "CRUISE +25%" in a calm teal — a steady,
#     CONTENT state, clearly apart from the amber/red danger escalation. The wide teal cruise
#     bar on the track marks the cruise point itself.
#   • Once overdrive engages, everything above presents exactly as shipped.

## The player tapped OVERDRIVE: release the cruise clamp for this excursion. Main routes this
## to GameState.engage_rush_overdrive() — the same seam as FrenzyBar.pop_requested.
signal overdrive_requested

var _rush_momentum: RushMomentumState
var _tuning: TuningConfig

## The OVR button, pinned left of the meter (the FrenzyBar layout). Always visible; enabled
## only while cruising — see _process.
var _overdrive_button: Button

## The display-only heat meter. All the overlays below live inside it.
var _meter: ProgressBar

## The big bonus readout ("+42%"), right-aligned; the caption on the left names the meter.
var _label: Label

## Carbonation in the fill; hidden while overheated (a locked meter is not accruing anything).
var _bubbles: GoldBubbles

## Fast neon-salmon streaks shown while heat is past the old cap (the Hot tick) and rushing is
## not locked out — "you are in overdrive" (was: only at max bonus; Tim 2026-07-15).
var _streaks: MomentumStreaks

## The custom-drawn band overlay: the wide teal cruise bar, the continuous amber ramp from it
## to the hazard zone, and the hazard-striped Critical segment.
var _zones: BandZoneOverlay

## The short-lived "CRITICAL +55%!" chip shown on entering the Critical band.
var _tier_chip: PanelContainer
var _tier_chip_label: Label
var _tier_chip_tween: Tween

## Full-rect white flash played when rush re-arms — re-availability must be unmissable
## (Tim 2026-07-15), so the whole meter blinks bright once alongside the label reverting.
var _ready_flash: ColorRect

## Eased fill: heat is driven by the 10 Hz logic tick, so we glide the shown fill toward it each
## frame instead of copying it raw — otherwise the bar visibly steps ~10 times a second (the same
## smoothing the frenzy meter uses; see BarSmoothing).
var _displayed_fill := 0.0

## The fill StyleBoxFlat, kept so _process can recolor the fill per band (and blink it in
## Critical) by mutating bg_color — far cheaper than rebuilding the stylebox every frame.
var _fill_style: StyleBoxFlat

## Blink phase accumulator (radians). Advanced by the CURRENT blink frequency each frame, so the
## frequency can ramp with heat depth without the sine jumping discontinuously.
var _blink_phase := 0.0

## Which label state is currently applied (see _LabelState), so the color/outline overrides are
## only rebuilt when the state flips, not every frame.
enum _LabelState { NORMAL, CRUISING, OVERHEATED, COOLING }
var _label_state_applied: int = -1

## Blink ramp: frequency (Hz) and color-pulse strength at the START of Critical vs. at the very
## top of the bar. Deeper into the gamble zone = faster, harder blinking = more urgent.
const BLINK_HZ_MIN := 2.5
const BLINK_HZ_MAX := 7.0
const BLINK_STRENGTH_MIN := 0.35
const BLINK_STRENGTH_MAX := 0.85

## How long the tier chip holds fully visible before fading (seconds).
const TIER_CHIP_HOLD_SEC := 1.0
const TIER_CHIP_FADE_IN_SEC := 0.12
const TIER_CHIP_FADE_OUT_SEC := 0.4

## The READY flash's peak alpha and fade time.
const READY_FLASH_ALPHA := 0.75
const READY_FLASH_FADE_SEC := 0.5

## Haptic pulse lengths (ms) per event — first-cut values, device pass pending (plan: open item).
const HAPTIC_CRITICAL_MS := 60
const HAPTIC_OVERHEAT_MS := 200
const HAPTIC_READY_MS := 40


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

	# The heat meter itself — display only, so it ignores the mouse entirely (FrenzyBar's meter
	# does the same); the button above is this control's one tappable piece.
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	# A touch shorter than a full action button — it is a secondary read-out, not a tap target,
	# but still tall enough to read at a glance.
	_meter.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 0.7))
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# DARK_PURPLE fill: a distinct hue from the frenzy meter's warm gold/red sitting just below it,
	# so the two reward meters never read as the same thing. Darkened from the lighter PURPLE
	# (Tim 2026-07-15) so the bright bubbles and white text pop against it.
	UiPalette.style_framed_progress(_meter, UiPalette.DARK_PURPLE, UiPalette.PROGRESS_TRACK_GRAY)
	add_child(_meter)
	# Keep a handle on the fill stylebox so the band coloring / Critical blink can mutate its
	# bg_color per frame instead of rebuilding styleboxes (see _process).
	_fill_style = _meter.get_theme_stylebox("fill") as StyleBoxFlat

	# Band zones + the 1.0 and cruise ticks, custom-drawn (the same approach as MomentumStreaks).
	# Added FIRST among the meter's overlays: it paints the Hot/Critical segments only over the
	# UNFILLED track (the fill covers them as it advances, so they read as track decoration behind
	# the fill), plus the always-on-top tick lines. Everything after it (bubbles, streaks, label)
	# draws over it.
	_zones = BandZoneOverlay.new()
	_meter.add_child(_zones)

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

	# Neon-salmon streaks over the fill, shown while heat rides past the old cap (see _process).
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
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 16)
	overlay.add_theme_constant_override("margin_right", 16)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(overlay)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)

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

	# The tier chip: a large bold plate that eases in over the meter on an upward band crossing,
	# holds ~1 s, then fades (see _show_tier_chip). Centered over the meter; z_index lifts it
	# above the siblings drawn after this bar (the TURBO row sits right below).
	_tier_chip = PanelContainer.new()
	_tier_chip.set_anchors_preset(Control.PRESET_CENTER)
	_tier_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tier_chip.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tier_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.z_index = 10
	_tier_chip.visible = false
	_meter.add_child(_tier_chip)

	_tier_chip_label = Label.new()
	_tier_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# FONT_HEADLINE bold — the chip is the "you just crossed a tier" moment and must land at a
	# glance (Tim's vision, §1b: large text, unmissable signals).
	_tier_chip_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_tier_chip_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_tier_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.add_child(_tier_chip_label)

	# Band-edge signals: the chip + haptics fire on the crossings; overheat/re-arm swap the
	# whole meter's presentation.
	_rush_momentum.band_entered.connect(_on_band_entered)
	_rush_momentum.overheated.connect(_on_overheated)
	_rush_momentum.rush_ready.connect(_on_rush_ready)


func _process(delta: float) -> void:
	# The meter spans the FULL heat range: fill fraction = heat / ceiling_max, so the Hot tick and
	# the Critical hazard zone sit at fixed positions on the track and the fill physically enters
	# them as heat climbs. Guard the knob so a 0 can't divide by zero.
	var ceiling_max: float = maxf(_tuning.rush_momentum_ceiling_max, 0.0001)
	var target_fill: float = clampf(_rush_momentum.heat / ceiling_max, 0.0, 1.0)
	_displayed_fill = BarSmoothing.approach(_displayed_fill, target_fill, delta)
	_meter.value = _displayed_fill

	# Feed the zone overlay the cruise point and the hazard edge (as fill fractions) plus the
	# current fill edge, so it can paint the ramp/hazard segments only over the still-unfilled
	# track and keep the cruise bar where the clamp actually sits (Legacy can move it).
	var critical_start_frac: float = clampf(_tuning.rush_momentum_critical_start / ceiling_max, 0.0, 1.0)
	var cruise_frac: float = clampf(_rush_momentum.cruise_heat() / ceiling_max, 0.0, 1.0)
	_zones.update_zones(cruise_frac, critical_start_frac, _displayed_fill)

	var locked_out := _rush_momentum.is_locked_out()
	var cruising := _rush_momentum.is_cruising()

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
	elif cruising and is_equal_approx(_rush_momentum.heat, _rush_momentum.cruise_heat()):
		# Sitting exactly on the clamp: the steady, content cruise state. The bonus quotes
		# effective_cruise_bonus() (base +25% plus Cooling Systems levels), never a hardcoded
		# number. While still CLIMBING toward the clamp the normal "+X%" branch below narrates
		# the climb, exactly as before.
		_label.text = "CRUISE +%d%%" % int(round(_rush_momentum.effective_cruise_bonus() * 100.0))
		_apply_label_state(_LabelState.CRUISING)
	else:
		_label.text = "+%d%%" % int(round(_rush_momentum.bonus * 100.0))
		_apply_label_state(_LabelState.NORMAL)

	# A locked meter is not accruing anything: hide the carbonation while it drains/re-arms so the
	# shutdown reads as dead air, not business as usual.
	_bubbles.visible = not locked_out

	# The salmon streaks mark riding past the cruise point — the whole overdrive ramp is danger
	# territory now that the old-cap tick is gone (Tim 2026-07-16: one continuous section past
	# cruise). NOT while cruising: with max Cooling Systems the cruise clamp sits exactly at
	# heat 1.0, and cruising there must stay a calm state (the boundary rule,
	# Plans/Rush_Cruise_Control.md).
	_streaks.visible = _rush_momentum.heat > _rush_momentum.cruise_heat() \
			and not locked_out and not cruising

	_update_fill_color(delta, locked_out, cruising)


## Recolor the fill AND its bubbles for the current heat: DARK_PURPLE at or below the cruise
## point (and always while cruising), then one continuous purple → amber slide from the cruise
## point all the way to the hazard edge — a single unbroken color story across the whole ramp
## section, no seam at the old heat-1.0 cap (Tim 2026-07-16) — then blinking red inside
## Critical, the blink ramping faster and harder as heat approaches the top of the bar.
## Mutates the cached fill stylebox's bg_color, so no styleboxes are rebuilt.
func _update_fill_color(delta: float, locked_out: bool, cruising: bool) -> void:
	var heat: float = _rush_momentum.heat
	var cruise_heat: float = _rush_momentum.cruise_heat()
	var critical_start: float = _tuning.rush_momentum_critical_start
	var ceiling_max: float = maxf(_tuning.rush_momentum_ceiling_max, 0.0001)

	if locked_out:
		# Draining after an overheat: a flat dark red — the punishment color, no blink (the
		# urgency is over; the player is just watching the cooldown empty out).
		_fill_style.bg_color = UiPalette.BRICK
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		return

	if cruising or heat <= cruise_heat:
		# Cruising (or simply below the cruise point): the steady, CONTENT look — including the
		# max-Legacy edge where the clamp sits exactly at 1.0, which must never wear the danger
		# ramp's amber (the boundary rule, Plans/Rush_Cruise_Control.md).
		_fill_style.bg_color = UiPalette.DARK_PURPLE
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		_blink_phase = 0.0
		return

	if heat < critical_start:
		# The overdrive ramp [cruise point .. hazard edge]: fill and bubbles slide purple → amber
		# by depth across the ENTIRE section, matching the track wash beneath.
		var ramp_span: float = maxf(critical_start - cruise_heat, 0.0001)
		var ramp_depth: float = clampf((heat - cruise_heat) / ramp_span, 0.0, 1.0)
		_fill_style.bg_color = UiPalette.DARK_PURPLE.lerp(UiPalette.MUSTARD_GOLD, ramp_depth)
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE.lerp(UiPalette.PALE_GOLD, ramp_depth)
		_blink_phase = 0.0
		return

	# Critical: blinking red, ramping with depth. Phase accumulates at the CURRENT frequency so
	# the ramp never makes the sine jump; strength widens the red↔pale-gold pulse.
	var crit_span: float = maxf(ceiling_max - critical_start, 0.0001)
	var crit_depth: float = clampf((heat - critical_start) / crit_span, 0.0, 1.0)
	var blink_hz: float = lerpf(BLINK_HZ_MIN, BLINK_HZ_MAX, crit_depth)
	var strength: float = lerpf(BLINK_STRENGTH_MIN, BLINK_STRENGTH_MAX, crit_depth)
	_blink_phase += delta * blink_hz * TAU
	# sin mapped to 0..1, scaled by strength: the fill pulses between pure KETCHUP_RED
	# and a bright warning flash toward PALE_GOLD; the bubbles stay bright gold so they
	# read through the pulse.
	var pulse: float = (sin(_blink_phase) * 0.5 + 0.5) * strength
	_fill_style.bg_color = UiPalette.KETCHUP_RED.lerp(UiPalette.PALE_GOLD, pulse)
	_bubbles.bubble_color = UiPalette.PALE_GOLD


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


## An upward band crossing. Only CRITICAL pops the tier chip (quoting the band's MAX bonus — the
## prize being approached) plus a haptic tap; entering HOT is deliberately chipless (Tim
## 2026-07-15: the amber fill shift and salmon streaks already announce it, and a chip at the
## old cap read as noise). The chip sells the last rung of the gamble, not every rung.
func _on_band_entered(band: RushMomentumState.Band) -> void:
	if band == RushMomentumState.Band.CRITICAL:
		_show_tier_chip(
			"CRITICAL +%d%%!" % int(round(_tuning.rush_momentum_bonus_peak * 100.0)),
			UiPalette.KETCHUP_RED, UiPalette.PALE_GOLD)
		_vibrate(HAPTIC_CRITICAL_MS)


## Heat hit the hidden ceiling: the shutdown moment. The label/fill/bubble changes are all
## per-frame state reads (see _process); here we only add the long haptic thump so the failure
## lands physically as well as visually.
func _on_overheated() -> void:
	_vibrate(HAPTIC_OVERHEAT_MS)


## The re-arm delay finished: rush is available again. Flash the whole meter bright once (plus a
## short haptic tick) so re-availability is unmissable — the label reverts to "+0%" on its own
## via _process now that is_locked_out() is false.
func _on_rush_ready() -> void:
	_vibrate(HAPTIC_READY_MS)
	_ready_flash.color = Color(1, 1, 1, READY_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_ready_flash, "color:a", 0.0, READY_FLASH_FADE_SEC)


## Show the tier chip: set its text/colors, ease it in, hold, fade out. A new crossing while the
## old chip is still up simply restarts the sequence with the new text.
func _show_tier_chip(text: String, plate_color: Color, text_color: Color) -> void:
	_tier_chip_label.text = text
	_tier_chip_label.add_theme_color_override("font_color", text_color)
	var plate := StyleBoxFlat.new()
	plate.bg_color = plate_color
	plate.border_color = UiPalette.NAVY
	plate.set_border_width_all(3)
	plate.set_corner_radius_all(8)
	plate.set_content_margin_all(14)
	_tier_chip.add_theme_stylebox_override("panel", plate)

	if _tier_chip_tween != null and _tier_chip_tween.is_valid():
		_tier_chip_tween.kill()
	_tier_chip.visible = true
	_tier_chip.modulate = Color(1, 1, 1, 0)
	_tier_chip_tween = create_tween()
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 1.0, TIER_CHIP_FADE_IN_SEC)
	_tier_chip_tween.tween_interval(TIER_CHIP_HOLD_SEC)
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 0.0, TIER_CHIP_FADE_OUT_SEC)
	_tier_chip_tween.tween_callback(func() -> void: _tier_chip.visible = false)


## Haptic tap, mobile only — desktop must stay silent (Input.vibrate_handheld is a no-op on most
## desktops anyway, but the explicit guard documents the intent and costs nothing).
func _vibrate(duration_ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


# ---------------------------------------------------------------------------
# The band-zone overlay
# ---------------------------------------------------------------------------

## Custom-drawn track decoration for the heat ranges (the same _draw approach MomentumStreaks
## uses): the wide teal CRUISE bar (where a plain hold clamps), then ONE continuous amber wash
## deepening from the cruise bar all the way to the hazard edge — a single section in a single
## hue with no internal tick lines (Tim 2026-07-16; this replaced the thin white heat==1.0 tick
## and the flat Hot segment) — then the hazard-striped dark-red Critical segment.
##
## The bar's fill is painted by the ProgressBar itself, UNDER all child overlays — so to make the
## zones read as if they were on the track BEHIND the fill, each segment is clipped to start at
## the CURRENT fill edge: the advancing fill "covers" the zone exactly as a background segment
## would be covered. The cruise bar, by contrast, is always drawn — over fill and track alike —
## so the "safe range ends here" marker never disappears.
class BandZoneOverlay extends Control:
	## Match the framed fill's 3px inset (UiPalette.style_framed_progress) so the segments sit
	## inside the navy frame exactly like the fill does.
	const EDGE_INSET := 3.0
	## The ramp wash: one hue (amber), alpha deepening across the section's whole width — a
	## continuous "warmer and warmer" read instead of discrete bands.
	const RAMP_COLOR := Color("#E3B23C")  # MUSTARD_GOLD
	const RAMP_ALPHA_START := 0.08
	const RAMP_ALPHA_END := 0.45
	## How many vertical slices approximate the wash's left-to-right alpha gradient (draw_rect
	## has no gradient fill; ~24 slices are indistinguishable from smooth at bar height).
	const RAMP_SLICES := 24
	## Critical segment: a dark red base with brighter red diagonal hazard stripes over it.
	const CRITICAL_BASE := Color("#8E2F1E", 0.55)   # BRICK, translucent over the gray track
	const CRITICAL_STRIPE := Color("#B5402A", 0.60)  # KETCHUP_RED stripes
	const STRIPE_WIDTH := 8.0
	## Horizontal distance between stripe left edges. Stripes run at 45°.
	const STRIPE_SPACING := 26.0
	## The cruise-point bar: WIDE (Tim 2026-07-16 — it is the one safety landmark on the track,
	## so it must land at a glance), in the same calm teal as the CRUISE readout so the marker
	## and the label read as one idea ("the hold settles here").
	const CRUISE_BAR_WIDTH := 10.0
	const CRUISE_BAR_COLOR := Color("#9FD8D4", 0.9)  # ATOMIC_TEAL

	## The cruise point, the hazard edge, and the current fill edge, all as fractions of the full
	## bar (0..1). Fed every frame by the host's _process via update_zones.
	var _cruise_frac := 0.0
	var _critical_start_frac := 0.78125
	var _fill_frac := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Update the geometry; redraws only when something actually moved.
	func update_zones(cruise_frac: float, critical_start_frac: float, fill_frac: float) -> void:
		if is_equal_approx(cruise_frac, _cruise_frac) \
				and is_equal_approx(critical_start_frac, _critical_start_frac) \
				and is_equal_approx(fill_frac, _fill_frac):
			return
		_cruise_frac = cruise_frac
		_critical_start_frac = critical_start_frac
		_fill_frac = fill_frac
		queue_redraw()

	func _draw() -> void:
		var top := EDGE_INSET
		var bottom := size.y - EDGE_INSET
		if size.x <= EDGE_INSET * 2.0 or bottom <= top:
			return
		# Fraction → x pixel, in the FILL's coordinate system: ProgressBar computes its fill rect
		# across the bar's FULL width (leading edge = fraction × width) and the fill stylebox's
		# −3px expand margin then pulls the drawn edge back by the inset. Mapping fractions onto
		# the inset track instead put the tick/zones ~1-2px right of the true fill edge — the same
		# off-by-inset the frenzy pop-floor marker had (Tim 2026-07-15). At fraction 1.0 this
		# lands on size.x − inset, flush with the frame's inner right edge.
		var cruise_x := maxf(_cruise_frac * size.x - EDGE_INSET, EDGE_INSET)
		var critical_x := maxf(_critical_start_frac * size.x - EDGE_INSET, EDGE_INSET)
		var right_x := size.x - EDGE_INSET
		var fill_x := maxf(_fill_frac * size.x - EDGE_INSET, EDGE_INSET)

		# The ramp wash [cruise bar .. hazard edge]: sliced left-to-right, each slice's alpha
		# interpolated across the FULL section width, then clipped to the unfilled track (see the
		# class comment). Slicing the full span and skipping covered slices keeps the gradient
		# anchored to the track — it never re-stretches as the fill advances.
		if critical_x > cruise_x:
			var span := critical_x - cruise_x
			var slice_width := span / float(RAMP_SLICES)
			for i in range(RAMP_SLICES):
				var slice_left := cruise_x + slice_width * float(i)
				var slice_right := slice_left + slice_width
				if slice_right <= fill_x:
					continue
				var alpha := lerpf(RAMP_ALPHA_START, RAMP_ALPHA_END,
						(float(i) + 0.5) / float(RAMP_SLICES))
				var visible_left := maxf(slice_left, fill_x)
				draw_rect(Rect2(visible_left, top, slice_right - visible_left, bottom - top),
						Color(RAMP_COLOR, alpha))

		# Critical segment (dark red + hazard stripes), clipped to the unfilled track.
		var crit_left := maxf(critical_x, fill_x)
		if right_x > crit_left:
			draw_rect(Rect2(crit_left, top, right_x - crit_left, bottom - top), CRITICAL_BASE)
			_draw_hazard_stripes(crit_left, right_x, top, bottom)

		# The cruise bar — where a plain hold clamps (Plans/Rush_Cruise_Control.md). ALWAYS
		# drawn, over fill and track alike, so the safety landmark is spatially real whatever
		# the meter is doing. Drawn LAST so the ramp wash never tints it.
		if _cruise_frac > 0.0:
			draw_rect(Rect2(cruise_x - CRUISE_BAR_WIDTH * 0.5, top, CRUISE_BAR_WIDTH,
					bottom - top), CRUISE_BAR_COLOR)

	## Diagonal 45° hazard stripes across [left_x, right_x]. Each stripe is a thick line from the
	## bottom edge up-right to the top edge; its endpoints are clipped in 1D along the line so no
	## stripe pokes past the segment's edges (inset by half the stripe width, since draw_line
	## spreads its width to both sides).
	func _draw_hazard_stripes(left_x: float, right_x: float, top: float, bottom: float) -> void:
		var height := bottom - top
		if height <= 0.0:
			return
		var clip_left := left_x + STRIPE_WIDTH * 0.5
		var clip_right := right_x - STRIPE_WIDTH * 0.5
		if clip_right <= clip_left:
			return
		# The first stripe starts far enough left that its top end can still land in the segment.
		var x0 := clip_left - height
		# Snap to the stripe grid so the pattern stays fixed to the bar (it does not crawl as the
		# segment's left edge moves with the fill).
		x0 = floorf(x0 / STRIPE_SPACING) * STRIPE_SPACING
		while x0 < clip_right:
			# The stripe runs from (x0, bottom) to (x0 + height, top). Clip its x-span to the
			# segment: parametrize t: x = x0 + t * height, t in [0, 1].
			var t_min := clampf((clip_left - x0) / height, 0.0, 1.0)
			var t_max := clampf((clip_right - x0) / height, 0.0, 1.0)
			if t_max > t_min:
				var from := Vector2(x0 + t_min * height, bottom - t_min * height)
				var to := Vector2(x0 + t_max * height, bottom - t_max * height)
				draw_line(from, to, CRITICAL_STRIPE, STRIPE_WIDTH)
			x0 += STRIPE_SPACING
