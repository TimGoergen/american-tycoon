class_name MomentumBar
extends ProgressBar

# The Rush Momentum / Heat meter (Tim 2026-07-12; Rush Overheat rework Tim 2026-07-15): a
# display-only bar that fills as sustained rushing HEATS the property up and drains when the
# player stops. Unlike the frenzy meter it is NOT a button — momentum is earned by rushing the
# PROPERTIES, not by tapping this bar — so there is no overlaid Button here.
#
# Overheat (Plans/Rush_Overheat.md) turned the old 0..cap meter into a push-your-luck heat
# gauge, so the bar now shows the FULL heat range 0..ceiling_max:
#   • a thin white TICK marks heat == 1.0 (the old cap) — everything left of it is safe;
#   • the Hot band [1.0 .. critical_start] is a subtle amber wash on the track;
#   • the Critical band [critical_start .. ceiling_max] is hazard-striped dark red — the real
#     overheat point is rolled secretly inside it every excursion, so the WHOLE zone reads as
#     "gamble territory" rather than promising a precise edge (Tim 2026-07-15: the exact point
#     of overheating should not be predictable);
#   • the fill shifts purple → amber → blinking red as heat climbs the bands, the blink growing
#     faster and harder the deeper into Critical the player pushes;
#   • crossing into Critical pops a large tier chip ("CRITICAL +55%!") quoting the peak bonus —
#     the prize being approached — so the escalation is legible without reading the number
#     (entering Hot is chipless: the fill shift and streaks carry it; Tim 2026-07-15);
#   • on overheat the label swaps to "OVERHEATED" while the fill visibly drains (the drain IS
#     the cooldown display), then "COOLING…" through the re-arm delay, then a bright READY flash.

var _rush_momentum: RushMomentumState
var _tuning: TuningConfig

## The big bonus readout ("+42%"), right-aligned; the caption on the left names the meter.
var _label: Label

## Carbonation in the fill; hidden while overheated (a locked meter is not accruing anything).
var _bubbles: GoldBubbles

## Fast neon-salmon streaks shown while heat is at/over the old cap (the Hot tick) and rushing is
## not locked out — "you are in overdrive" (was: only at max bonus; Tim 2026-07-15).
var _streaks: MomentumStreaks

## The custom-drawn band overlay: Hot/Critical track segments, hazard stripes, and the 1.0 tick.
var _zones: BandZoneOverlay

## The short-lived "CRITICAL +55%!" chip shown on entering the Critical band.
var _tier_chip: PanelContainer
var _tier_chip_label: Label
var _tier_chip_tween: Tween

## Full-rect white flash played when rush re-arms — re-availability must be unmissable
## (Tim 2026-07-15), so the whole bar blinks bright once alongside the label reverting.
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
enum _LabelState { NORMAL, OVERHEATED, COOLING }
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
	min_value = 0.0
	max_value = 1.0
	show_percentage = false
	# A touch shorter than a full action button — it is a secondary read-out, not a tap target,
	# but still tall enough to read at a glance.
	custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 0.7))
	size_flags_vertical = Control.SIZE_FILL
	# DARK_PURPLE fill: a distinct hue from the frenzy meter's warm gold/red sitting just below it,
	# so the two reward meters never read as the same thing. Darkened from the lighter PURPLE
	# (Tim 2026-07-15) so the bright bubbles and white text pop against it.
	UiPalette.style_framed_progress(self, UiPalette.DARK_PURPLE, UiPalette.PROGRESS_TRACK_GRAY)
	# Keep a handle on the fill stylebox so the band coloring / Critical blink can mutate its
	# bg_color per frame instead of rebuilding styleboxes (see _process).
	_fill_style = get_theme_stylebox("fill") as StyleBoxFlat

	# Band zones + the 1.0 tick, custom-drawn (the same approach as MomentumStreaks). Added FIRST
	# among the overlays: it paints the Hot/Critical segments only over the UNFILLED track (the
	# fill covers them as it advances, so they read as track decoration behind the fill), plus the
	# always-on-top tick line. Everything after it (bubbles, streaks, label) draws over it.
	_zones = BandZoneOverlay.new()
	add_child(_zones)

	# Carbonation in the fill, the same "value accruing automatically" cue the frenzy meter and the
	# property/economy bars carry: heat builds on its own while you rush. BRIGHT_PURPLE bubbles
	# glowing against the dark fill (flipped from dark-on-light, Tim 2026-07-15 — the same pairing
	# the maxed-momentum property bars use). Added BEFORE the label overlay so the readout draws
	# over the bubbles.
	_bubbles = GoldBubbles.new()
	_bubbles.edge_inset = 3.0  # match the framed fill's 3px inset (style_framed_progress)
	_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
	_bubbles.tier = GoldBubbles.Tier.FLOWING  # steady automatic accrual, like TURBO charging
	add_child(_bubbles)

	# Neon-salmon streaks over the fill, shown while heat rides at/over the old cap (see _process).
	# Added over the gold bubbles but under the label overlay, so the "+XX%" still draws on top.
	_streaks = MomentumStreaks.new()
	_streaks.color = UiPalette.NEON_SALMON
	_streaks.visible = false
	add_child(_streaks)

	# READY flash: a full-rect white wash, normally invisible; _on_rush_ready tweens it bright and
	# back so the re-armed meter is unmissable even in peripheral vision (Tim's vision, §1b).
	_ready_flash = ColorRect.new()
	_ready_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ready_flash.color = Color(1, 1, 1, 0)
	_ready_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ready_flash)

	# Overlay: a left caption and the big "+XX%" readout on the right. It ignores the mouse so it
	# never eats a tap meant for the rows or buttons around it.
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 16)
	overlay.add_theme_constant_override("margin_right", 16)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

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

	# The tier chip: a large bold plate that eases in over the bar on an upward band crossing,
	# holds ~1 s, then fades (see _show_tier_chip). Centered over the meter; z_index lifts it
	# above the siblings drawn after this bar (the TURBO row sits right below).
	_tier_chip = PanelContainer.new()
	_tier_chip.set_anchors_preset(Control.PRESET_CENTER)
	_tier_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tier_chip.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tier_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.z_index = 10
	_tier_chip.visible = false
	add_child(_tier_chip)

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
	# The bar spans the FULL heat range: fill fraction = heat / ceiling_max, so the Hot tick and
	# the Critical hazard zone sit at fixed positions on the track and the fill physically enters
	# them as heat climbs. Guard the knob so a 0 can't divide by zero.
	var ceiling_max: float = maxf(_tuning.rush_momentum_ceiling_max, 0.0001)
	var target_fill: float = clampf(_rush_momentum.heat / ceiling_max, 0.0, 1.0)
	_displayed_fill = BarSmoothing.approach(_displayed_fill, target_fill, delta)
	value = _displayed_fill

	# Feed the zone overlay the band edges (as fill fractions) and the current fill edge, so it
	# can paint the Hot/Critical segments only over the still-unfilled track.
	var critical_start_frac: float = clampf(_tuning.rush_momentum_critical_start / ceiling_max, 0.0, 1.0)
	_zones.update_zones(1.0 / ceiling_max, critical_start_frac, _displayed_fill)

	var locked_out := _rush_momentum.is_locked_out()

	# The label: the live bonus normally; the lockout narration while shut down. is_rearming is
	# checked FIRST — it is a sub-state of is_locked_out (both true during the re-arm delay).
	if _rush_momentum.is_rearming():
		_label.text = "COOLING…"
		_apply_label_state(_LabelState.COOLING)
	elif locked_out:
		_label.text = "OVERHEATED"
		_apply_label_state(_LabelState.OVERHEATED)
	else:
		_label.text = "+%d%%" % int(round(_rush_momentum.bonus * 100.0))
		_apply_label_state(_LabelState.NORMAL)

	# A locked meter is not accruing anything: hide the carbonation while it drains/re-arms so the
	# shutdown reads as dead air, not business as usual.
	_bubbles.visible = not locked_out

	# The salmon streaks mark OVERDRIVE — heat at or past the old cap (the tick) while rushing is
	# still allowed (Tim 2026-07-15; was "only at max bonus" before overheat existed).
	_streaks.visible = _rush_momentum.heat >= 1.0 and not locked_out

	_update_fill_color(delta, locked_out)


## Recolor the fill for the current band: DARK_PURPLE while Building, shifting to amber across
## Hot, and blinking red in Critical — the blink ramping faster and harder as heat approaches the
## top of the bar (deeper into the secret-ceiling zone = more urgent). Mutates the cached fill
## stylebox's bg_color, so no styleboxes are rebuilt.
func _update_fill_color(delta: float, locked_out: bool) -> void:
	var heat: float = _rush_momentum.heat
	var critical_start: float = _tuning.rush_momentum_critical_start
	var ceiling_max: float = maxf(_tuning.rush_momentum_ceiling_max, 0.0001)

	if locked_out:
		# Draining after an overheat: a flat dark red — the punishment color, no blink (the
		# urgency is over; the player is just watching the cooldown empty out).
		_fill_style.bg_color = UiPalette.BRICK
		return

	match _rush_momentum.current_band():
		RushMomentumState.Band.BUILDING:
			_fill_style.bg_color = UiPalette.DARK_PURPLE
			_blink_phase = 0.0
		RushMomentumState.Band.HOT:
			# Slide purple → amber across the Hot band so the fill itself narrates the climb.
			var hot_span: float = maxf(critical_start - 1.0, 0.0001)
			var hot_depth: float = clampf((heat - 1.0) / hot_span, 0.0, 1.0)
			_fill_style.bg_color = UiPalette.DARK_PURPLE.lerp(UiPalette.MUSTARD_GOLD, hot_depth)
			_blink_phase = 0.0
		RushMomentumState.Band.CRITICAL:
			# Blinking red, ramping with depth. Phase accumulates at the CURRENT frequency so the
			# ramp never makes the sine jump; strength widens the red↔pale-gold pulse.
			var crit_span: float = maxf(ceiling_max - critical_start, 0.0001)
			var crit_depth: float = clampf((heat - critical_start) / crit_span, 0.0, 1.0)
			var blink_hz: float = lerpf(BLINK_HZ_MIN, BLINK_HZ_MAX, crit_depth)
			var strength: float = lerpf(BLINK_STRENGTH_MIN, BLINK_STRENGTH_MAX, crit_depth)
			_blink_phase += delta * blink_hz * TAU
			# sin mapped to 0..1, scaled by strength: the fill pulses between pure KETCHUP_RED
			# and a bright warning flash toward PALE_GOLD.
			var pulse: float = (sin(_blink_phase) * 0.5 + 0.5) * strength
			_fill_style.bg_color = UiPalette.KETCHUP_RED.lerp(UiPalette.PALE_GOLD, pulse)


## Swap the readout label's look per lockout state. Only rebuilds the overrides on a change.
## OVERHEATED reads in red with a cream outline — the fill behind it is dark red while draining,
## so the outline carries the contrast (§1b: the failure state must be readable, not subtle).
func _apply_label_state(state: int) -> void:
	if state == _label_state_applied:
		return
	_label_state_applied = state
	match state:
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


## The re-arm delay finished: rush is available again. Flash the whole bar bright once (plus a
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

## Custom-drawn track decoration for the heat bands (the same _draw approach MomentumStreaks
## uses): the subtle amber Hot segment, the hazard-striped dark-red Critical segment, and the
## thin white tick at heat == 1.0 (the old cap — the "safe range ends here" line).
##
## The bar's fill is painted by the ProgressBar itself, UNDER all child overlays — so to make the
## zones read as if they were on the track BEHIND the fill, each segment is clipped to start at
## the CURRENT fill edge: the advancing fill "covers" the zone exactly as a background segment
## would be covered. The tick, by contrast, is always drawn — over fill and track alike — so the
## safe-range boundary never disappears.
class BandZoneOverlay extends Control:
	## Match the framed fill's 3px inset (UiPalette.style_framed_progress) so the segments sit
	## inside the navy frame exactly like the fill does.
	const EDGE_INSET := 3.0
	## Hot segment: a quiet amber wash — a hint, not a warning (the warning is Critical's job).
	const HOT_WASH := Color("#E3B23C", 0.35)  # MUSTARD_GOLD at low alpha
	## Critical segment: a dark red base with brighter red diagonal hazard stripes over it.
	const CRITICAL_BASE := Color("#8E2F1E", 0.55)   # BRICK, translucent over the gray track
	const CRITICAL_STRIPE := Color("#B5402A", 0.60)  # KETCHUP_RED stripes
	const STRIPE_WIDTH := 8.0
	## Horizontal distance between stripe left edges. Stripes run at 45°.
	const STRIPE_SPACING := 26.0
	## The heat == 1.0 tick: thin, light, always visible.
	const TICK_WIDTH := 3.0
	const TICK_COLOR := Color(1, 1, 1, 0.9)

	## Band edges and the current fill edge, all as fractions of the full bar (0..1). Fed every
	## frame by the host's _process via update_zones.
	var _hot_start_frac := 0.625
	var _critical_start_frac := 0.78125
	var _fill_frac := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Update the geometry; redraws only when something actually moved.
	func update_zones(hot_start_frac: float, critical_start_frac: float, fill_frac: float) -> void:
		if is_equal_approx(hot_start_frac, _hot_start_frac) \
				and is_equal_approx(critical_start_frac, _critical_start_frac) \
				and is_equal_approx(fill_frac, _fill_frac):
			return
		_hot_start_frac = hot_start_frac
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
		var hot_x := maxf(_hot_start_frac * size.x - EDGE_INSET, EDGE_INSET)
		var critical_x := maxf(_critical_start_frac * size.x - EDGE_INSET, EDGE_INSET)
		var right_x := size.x - EDGE_INSET
		var fill_x := maxf(_fill_frac * size.x - EDGE_INSET, EDGE_INSET)

		# Hot segment (amber), clipped to the unfilled track (see the class comment).
		var hot_left := maxf(hot_x, fill_x)
		if critical_x > hot_left:
			draw_rect(Rect2(hot_left, top, critical_x - hot_left, bottom - top), HOT_WASH)

		# Critical segment (dark red + hazard stripes), same clip.
		var crit_left := maxf(critical_x, fill_x)
		if right_x > crit_left:
			draw_rect(Rect2(crit_left, top, right_x - crit_left, bottom - top), CRITICAL_BASE)
			_draw_hazard_stripes(crit_left, right_x, top, bottom)

		# The tick at heat == 1.0 — ALWAYS drawn, over fill and track alike, so the "end of the
		# safe range" line is spatially real whatever the meter is doing.
		draw_rect(Rect2(hot_x - TICK_WIDTH * 0.5, top, TICK_WIDTH, bottom - top), TICK_COLOR)

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
