class_name MomentumBar
extends ProgressBar

# The Rush Momentum meter (Tim 2026-07-12): a display-only bar that fills as sustained rushing
# builds the momentum income bonus and drains when the player stops. Unlike the frenzy meter it is
# NOT a button — momentum is earned by rushing the PROPERTIES, not by tapping this bar — so there is
# no overlaid Button here. The large "+XX%" readout tells the player exactly how much extra income
# their rushing is currently earning, and watching it climb toward the cap is the feedback that
# makes sustained rushing feel rewarding.

var _rush_momentum: RushMomentumState
var _tuning: TuningConfig

## The big bonus readout ("+42%"), right-aligned; the caption on the left names the meter.
var _label: Label

## Eased fill: the true bonus is driven by the 10 Hz logic tick, so we glide the shown fill toward
## it each frame instead of copying it raw — otherwise the bar visibly steps ~10 times a second
## (the same smoothing the frenzy meter uses; see BarSmoothing).
var _displayed_fill := 0.0


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
	# Cool NEON_BLUE fill: energetic and clearly distinct from the frenzy meter's warm gold/red
	# sitting just below it, so the two reward meters never read as the same thing.
	UiPalette.style_framed_progress(self, UiPalette.NEON_BLUE, UiPalette.PROGRESS_TRACK_GRAY)

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

	# Left: the meter's name. Dark ink so it reads over both the pale empty track and the bright
	# neon fill (the caption sits at the left edge, filled first as momentum climbs).
	var caption := Label.new()
	caption.text = "RUSH MOMENTUM"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	caption.add_theme_font_override("font", UiPalette.make_bold_font())
	caption.add_theme_color_override("font_color", UiPalette.INK_NAVY)
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
	_label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)


func _process(delta: float) -> void:
	# Fill is the bonus as a fraction of its cap; guard the cap so a 0 knob can't divide by zero.
	var cap: float = maxf(_tuning.rush_momentum_max_bonus, 0.0001)
	var target_fill: float = clampf(_rush_momentum.bonus / cap, 0.0, 1.0)
	_displayed_fill = BarSmoothing.approach(_displayed_fill, target_fill, delta)
	value = _displayed_fill
	_label.text = "+%d%%" % int(round(_rush_momentum.bonus * 100.0))
