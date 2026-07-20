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
## the full crowd read as too busy there (Tim, 2026-07-06). Burning uses the full crowd.
const CHARGING_BUBBLE_DENSITY := 0.5

var _frenzy: FrenzyState
var _tuning: TuningConfig

## The square icon button that pops the frenzy — the control's only tappable piece.
var _pop_button: Button
## The display-only charge meter to the button's right.
var _meter: ProgressBar
## The reward readout drawn on the right of the meter. Set live in _process.
var _label: Label
## The carbonation overlay — kept so _set_burn_style can restyle it with the fill.
var _bubbles: GoldBubbles
## The pop-floor marker: a vertical line on the meter at the charge needed before TURBO can
## fire early, so the player can see how far away "poppable" is (Tim 2026-07-15). Hidden
## while burning — the bar is a countdown timer then, and the floor means nothing.
var _floor_marker: Control
var _showing_burn_style := false

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

	# The charge meter: display only — dark-gold fill with bright-gold carbonation
	# (Tim, 2026-07-15; it launched as a gold fill with dark bubbles).
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiPalette.style_framed_progress(_meter, UiPalette.DARK_GOLD, UiPalette.PROGRESS_TRACK_GRAY)
	add_child(_meter)

	# Carbonation in the meter (Tim, 2026-07-05 — re-added after a brief removal): bright gold,
	# glowing against the dark-gold charging fill and the red burning fill alike. Added BEFORE
	# the label overlay so the readout draws over the bubbles.
	_bubbles = GoldBubbles.new()
	_bubbles.edge_inset = 3.0  # match the framed fill's 3px inset (style_framed_progress)
	_bubbles.bubble_color = GoldBubbles.DEFAULT_GOLD
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
		_set_burn_style(true)
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
		_set_burn_style(false)
		if _frenzy.can_pop():
			# Live preview of what a pop right now would lock in.
			var preview_mult := 1.0 + (_tuning.frenzy_max_multiplier - 1.0) * _frenzy.meter
			# Same Second Wind scaling as the burn readout above — the promise the preview
			# makes must be the one the burn keeps.
			var preview_secs := _frenzy.meter * _tuning.frenzy_burn_duration * _frenzy.duration_multiplier
			_label.text = "%s× for %ds" % [Money.trim(preview_mult, 1), int(preview_secs)]
		else:
			# Below the pop floor there is no reward to preview — a pop isn't possible yet,
			# and a counting-up multiplier read as "already earned" (Tim, 2026-07-15).
			_label.text = ""
		_pop_button.disabled = not _frenzy.can_pop()


## Swap the fill color when entering/leaving a burn. Only on change — the
## stylebox override is not worth rebuilding every frame.
func _set_burn_style(burning: bool) -> void:
	if burning == _showing_burn_style:
		return
	_showing_burn_style = burning
	var fill := UiPalette.KETCHUP_RED if burning else UiPalette.DARK_GOLD
	UiPalette.style_framed_progress(_meter, fill, UiPalette.PROGRESS_TRACK_GRAY)
	# The pop-floor marker only means something while charging.
	_floor_marker.visible = not burning
	# Burning drains the meter right-to-left, so the liquid flows that way too, with the
	# full crowd; charging fills left-to-right with the reduced crowd (Tim, 2026-07-06).
	# The bright-gold bubble color reads on both fills, so it no longer swaps here.
	_bubbles.flow_reversed = burning
	_bubbles.density_scale = 1.0 if burning else CHARGING_BUBBLE_DENSITY
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
