class_name FrenzyBar
extends HBoxContainer

# The TURBO control (reworked Tim, 2026-07-15): a square ICON BUTTON pinned to the left edge
# of the frenzy meter. The button — carrying the growth-arrow art — is now the ONLY thing
# that pops a frenzy; the meter beside it is a pure display (it used to be one big button
# with the fill as its background). The meter charges as a dark-gold fill with bright-gold
# carbonation, and carries the live reward readout ("2.4× for 54s") right-aligned — shown
# once the charge clears the pop floor, since every irreversible decision shows its reward
# first (Spec §7); below the floor no pop is possible, so no reward is previewed
# (Tim, 2026-07-15). While burning the fill turns red and the readout counts the burn down.

signal pop_requested

## The growth-arrow symbol on the pop button.
const TURBO_TEX := preload("res://art/icons/turbo.svg")
## Cap on the icon's drawn size inside the (square) pop button, so the symbol reads large
## without touching the button's frame (Tim, 2026-06-29 sizing, kept through the 07-15 rework).
const TURBO_ICON_SIZE := 90

## Bubble crowd size while CHARGING, as a fraction of the full crowd —
## the full crowd read as too busy there (Tim, 2026-07-06). Burning uses a denser crowd.
const CHARGING_BUBBLE_DENSITY := 0.5
## Bubble crowd size while BURNING — 50% denser than the normal full crowd so the red draining
## frenzy fill fizzes harder (Tim, 2026-07-26; paired with the faster, more agitated RUSHED tier).
const BURN_BUBBLE_DENSITY := 1.5

var _frenzy: FrenzyState
var _tuning: TuningConfig

## The square icon button that pops the frenzy — the control's only tappable piece.
var _pop_button: Button
## The display-only charge meter to the button's right.
var _meter: ProgressBar
## The reward readout drawn on the right of the meter. Set live in _process.
var _label: Label
## The carbonation overlay — kept so _apply_fill_style can restyle it with the fill.
var _bubbles: GoldBubbles
## The pop-floor marker: a vertical line on the meter at the charge needed before TURBO can
## fire early, so the player can see how far away "poppable" is (Tim 2026-07-15). Hidden
## while burning — the bar is a countdown timer then, and the floor means nothing.
var _floor_marker: Control

## The three looks the meter can wear. Below the pop floor it is GRAYSCALE — there is no
## reward available yet, so it should not wear the reward's colour (Tim, 2026-07-31). Crossing
## the floor turns it gold, which makes "TURBO is now available" a colour change the player
## catches out of the corner of their eye rather than something they have to read.
enum FillStyle {
	LOCKED,    # charging, still under tuning.frenzy_pop_floor — gray fill, gray bubbles
	READY,     # charging, at or past the floor — the dark-gold fill with gold carbonation
	BURNING,   # popped and draining — red fill
}
var _fill_style: FillStyle = FillStyle.LOCKED

## Carbonation colour while locked. A pale cool gray so the bubbles still read against the
## dark-gray fill, exactly as the bright gold reads against the dark gold.
const LOCKED_BUBBLE_GRAY := Color(0.82, 0.83, 0.86, 1.0)

## Width of the pop-floor marker line, in px.
const FLOOR_MARKER_WIDTH := 4.0
## Inset matching the framed meter's border (style_framed_progress), so the marker spans
## exactly the track the fill moves through.
const METER_FRAME_INSET := 3.0

## Eased fill shown on the meter. The true meter is driven by the 10 Hz logic tick,
## so we glide the displayed fill toward it each frame instead of copying it raw —
## otherwise the bar steps visibly ~10 times a second (see BarSmoothing).
var _displayed_fill := 0.0


## Call before adding to the tree.
func setup(frenzy: FrenzyState, tuning: TuningConfig) -> void:
	_frenzy = frenzy
	_tuning = tuning


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	# The pop button: a square gold plate with the turbo arrow, matching the standard button
	# height so it lines up with the buy-mode button sharing this row.
	_pop_button = Button.new()
	_pop_button.custom_minimum_size = Vector2(UiPalette.STANDARD_BUTTON_HEIGHT, UiPalette.STANDARD_BUTTON_HEIGHT)
	_pop_button.icon = TURBO_TEX
	_pop_button.expand_icon = true
	_pop_button.add_theme_constant_override("icon_max_width", TURBO_ICON_SIZE)
	_pop_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The project's default 2D filter is plain linear (no mipmaps), which aliases badly when a
	# large SVG texture is minified to this size. Switch to the mipmapped filter so the icon
	# actually uses the mipmaps we generate at import — same fix the Legacy gem icons use.
	_pop_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	UiPalette.style_button(_pop_button, false)
	# When a pop isn't available (mid-burn, or the meter is below the pop floor) the button
	# grays its OUTLINE too, so "can't trigger" reads at a glance (Tim 2026-07-15). The
	# standard disabled plate keeps the navy frame; this swaps just this button's for gray.
	var disabled_plate := StyleBoxFlat.new()
	disabled_plate.bg_color = UiPalette.CREAM
	disabled_plate.border_color = UiPalette.MID_GRAY
	disabled_plate.set_border_width_all(3)
	disabled_plate.set_corner_radius_all(4)
	disabled_plate.set_content_margin_all(12)
	_pop_button.add_theme_stylebox_override("disabled", disabled_plate)
	_pop_button.pressed.connect(func() -> void: pop_requested.emit())
	# A second finger can pop TURBO while the first holds a rush (Tim, 2026-07-07); the
	# disabled state (mid-burn / below the pop floor) blocks it the same as a primary tap.
	_pop_button.add_child(SecondaryTapButton.new())
	add_child(_pop_button)

	# The charge meter: display only. It is built in the LOCKED look (grayscale) because a
	# fresh meter starts empty, below the pop floor — and `_fill_style` starts at LOCKED to
	# match, so the first _apply_fill_style call that matters is the one that turns it gold.
	# Getting these two out of step would leave the bar gold until its first state change.
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiPalette.style_framed_progress(_meter, UiPalette.DARK_GRAY, UiPalette.PROGRESS_TRACK_GRAY)
	add_child(_meter)

	# Carbonation in the meter (Tim, 2026-07-05 — re-added after a brief removal). Gold once the
	# meter is poppable, glowing against the dark-gold charging fill and the red burning fill
	# alike; pale gray while locked. Added BEFORE the label overlay so the readout draws over it.
	_bubbles = GoldBubbles.new()
	_bubbles.edge_inset = 3.0  # match the framed fill's 3px inset (style_framed_progress)
	_bubbles.bubble_color = LOCKED_BUBBLE_GRAY
	_bubbles.density_scale = CHARGING_BUBBLE_DENSITY  # the meter starts in the charging state
	_meter.add_child(_bubbles)

	# The pop-floor marker, over the bubbles but under the readout.
	_floor_marker = Control.new()
	_floor_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_marker.draw.connect(_draw_floor_marker)
	_meter.add_child(_floor_marker)

	# Overlay on the meter carrying the reward readout, right-aligned. Mouse-ignoring — the
	# meter is not a button, so nothing here should catch a tap. The side margins keep the
	# text clear of the navy frame.
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 16)
	overlay.add_theme_constant_override("margin_right", 16)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(overlay)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Larger + bold readout (Tim, 2026-06-25), white in all states. FONT_SUBHEAD, deliberately
	# matching the buy-mode button sharing its row (Tim, 2026-07-07).
	_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_label.add_theme_color_override("font_color", Color.WHITE)
	overlay.add_child(_label)


func _process(delta: float) -> void:
	_displayed_fill = BarSmoothing.approach(_displayed_fill, _frenzy.meter, delta)
	_meter.value = _displayed_fill

	if _frenzy.mode == FrenzyState.Mode.BURNING:
		_apply_fill_style(FillStyle.BURNING)
		# Second Wind (duration_multiplier) divides the drain RATE, so real seconds left are
		# meter × base duration × that multiplier. Omitting it understated the countdown by
		# exactly the multiplier — at ~8 levels the label ticked down 1 per 3 real seconds
		# and read as a broken clock (Tim's device report, 2026-07-19).
		var seconds_left := _frenzy.meter * _tuning.frenzy_burn_duration * _frenzy.duration_multiplier
		# Multiplier reads "2.4×" (the × trails the number) per Tim's call — via Money.trim
		# so a whole multiplier reads "2×", never "2.0×" (Tim, 2026-07-03). The button's icon
		# already conveys "TURBO", so the readout is just the reward.
		_label.text = "%s× — %ds left" % [Money.trim(_frenzy.locked_multiplier, 1), int(seconds_left)]
		_pop_button.disabled = true
	else:
		# Gold the moment a pop is actually possible, so the meter's colour and the pop
		# button's enabled state always agree — they read the same can_pop().
		_apply_fill_style(FillStyle.READY if _frenzy.can_pop() else FillStyle.LOCKED)
		if _frenzy.can_pop():
			# Live preview of what a pop right now would lock in. Must include the Frenzy
			# Intensity (Killer Instinct) upgrade's intensity_multiplier — the SAME factor
			# FrenzyState.pop() applies to the bonus — or the preview understates the real pop
			# by that multiplier (Tim, 2026-07-26: charged read 5.6× but the pop locked 6.3×).
			var preview_mult := 1.0 + (_tuning.frenzy_max_multiplier - 1.0) * _frenzy.intensity_multiplier * _frenzy.meter
			# Same Second Wind scaling as the burn readout above — the promise the preview
			# makes must be the one the burn keeps.
			var preview_secs := _frenzy.meter * _tuning.frenzy_burn_duration * _frenzy.duration_multiplier
			_label.text = "%s× for %ds" % [Money.trim(preview_mult, 1), int(preview_secs)]
		else:
			# Below the pop floor there is no reward to preview — a pop isn't possible yet,
			# and a counting-up multiplier read as "already earned" (Tim, 2026-07-15).
			_label.text = ""
		_pop_button.disabled = not _frenzy.can_pop()


## Dress the meter for one of the three states. Only on CHANGE — rebuilding the stylebox
## every frame is not worth it, and the carbonation keeps its own animation state.
func _apply_fill_style(style: FillStyle) -> void:
	if style == _fill_style:
		return
	_fill_style = style
	var burning := style == FillStyle.BURNING
	var fill := UiPalette.DARK_GRAY
	if burning:
		fill = UiPalette.KETCHUP_RED
	elif style == FillStyle.READY:
		fill = UiPalette.DARK_GOLD
	UiPalette.style_framed_progress(_meter, fill, UiPalette.PROGRESS_TRACK_GRAY)
	# Carbonation goes gray with the fill, so a locked meter is grayscale throughout rather
	# than gray liquid fizzing gold.
	_bubbles.bubble_color = LOCKED_BUBBLE_GRAY if style == FillStyle.LOCKED else GoldBubbles.DEFAULT_GOLD
	# The pop-floor marker only means something while charging.
	_floor_marker.visible = not burning
	# Burning drains the meter right-to-left, so the liquid flows that way too, with the
	# full crowd; charging fills left-to-right with the reduced crowd (Tim, 2026-07-06).
	# Gold reads on both the dark-gold and red fills, so the colour only swaps for LOCKED
	# (handled above) — the two lively states share it.
	_bubbles.flow_reversed = burning
	_bubbles.density_scale = BURN_BUBBLE_DENSITY if burning else CHARGING_BUBBLE_DENSITY
	# Carbonation TIER (Tim, 2026-07-10): burning discharges the multiplier — a livelier RUSHED
	# flow; charging is the steady FLOWING accrual. Speeds are per-tier static values.
	_bubbles.tier = GoldBubbles.Tier.RUSHED if burning else GoldBubbles.Tier.FLOWING


## Draw the vertical pop-floor line at tuning.frenzy_pop_floor across the meter's track:
## charge past this line and TURBO can be triggered early. Navy, like the meter's frame, so
## it reads on both the dark-gold fill behind it and the pale empty track ahead of it.
func _draw_floor_marker() -> void:
	if _floor_marker.size.x <= METER_FRAME_INSET * 2.0:
		return
	# Match the FILL's coordinate system, not the visual track's: ProgressBar computes its fill
	# rect across the bar's FULL width (leading edge = fraction × width) and the fill stylebox's
	# −3px expand margin then pulls the drawn edge back by the inset. Mapping the fraction onto
	# the inset track instead left the marker ~1px right of the fill edge at the floor
	# (Tim 2026-07-15).
	var x := clampf(_tuning.frenzy_pop_floor, 0.0, 1.0) * _floor_marker.size.x - METER_FRAME_INSET
	_floor_marker.draw_rect(
		Rect2(x - FLOOR_MARKER_WIDTH / 2.0, METER_FRAME_INSET,
			FLOOR_MARKER_WIDTH, _floor_marker.size.y - METER_FRAME_INSET * 2.0),
		UiPalette.INK_NAVY)
