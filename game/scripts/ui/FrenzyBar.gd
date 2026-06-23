class_name FrenzyBar
extends ProgressBar

# The frenzy meter IS the TURBO button (Tim, 2026-06-21): the meter fill doubles as
# the button background — mustard while charging, red while burning — with a
# transparent Button overlaid on top that carries the TURBO label and catches the
# tap (the same "meter as button background" pattern the wage button uses).
#
# The label always previews the live reward ("TURBO 2.4× for 54s") — every
# irreversible decision shows its reward first (Spec §7 house rule).

signal pop_requested

var _frenzy: FrenzyState
var _tuning: TuningConfig

var _button: Button
var _showing_burn_style := false

## Eased fill shown on the bar. The true meter is driven by the 10 Hz logic tick,
## so we glide the displayed fill toward it each frame instead of copying it raw —
## otherwise the bar steps visibly ~10 times a second (see BarSmoothing).
var _displayed_fill := 0.0


## Call before adding to the tree.
func setup(frenzy: FrenzyState, tuning: TuningConfig) -> void:
	_frenzy = frenzy
	_tuning = tuning


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	show_percentage = false
	# The shared standard button height, matching the buy-mode button sharing its row.
	custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	size_flags_vertical = Control.SIZE_FILL
	UiPalette.style_framed_progress(self, UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL)

	# Transparent button overlaying the meter: the gold/red fill shows through, and
	# only the TURBO label and the tap belong to the button. Empty styleboxes (with a
	# little side padding) keep the meter visible while leaving room for the label so
	# it doesn't kiss the navy frame.
	var label_padding := StyleBoxEmpty.new()
	label_padding.content_margin_left = 14
	label_padding.content_margin_right = 14

	_button = Button.new()
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Horizontally centered label (Tim, 2026-06-21).
	_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	_button.add_theme_stylebox_override("normal", label_padding)
	_button.add_theme_stylebox_override("hover", label_padding)
	_button.add_theme_stylebox_override("pressed", label_padding)
	_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button.add_theme_color_override("font_color", UiPalette.NAVY)
	_button.add_theme_color_override("font_hover_color", UiPalette.NAVY)
	_button.add_theme_color_override("font_pressed_color", UiPalette.INK_NAVY)
	# Disabled is the common state (can't pop until charged) — keep the label dark and
	# readable rather than the default greyed-out wash.
	_button.add_theme_color_override("font_disabled_color", UiPalette.NAVY)
	_button.pressed.connect(func() -> void: pop_requested.emit())
	add_child(_button)


func _process(delta: float) -> void:
	_displayed_fill = BarSmoothing.approach(_displayed_fill, _frenzy.meter, delta)
	value = _displayed_fill

	if _frenzy.mode == FrenzyState.Mode.BURNING:
		_set_burn_style(true)
		var seconds_left := _frenzy.meter * _tuning.frenzy_burn_duration
		# Multiplier reads "2.4×" (the × trails the number) per Tim's call.
		_button.text = "%.1f× — %ds left" % [_frenzy.locked_multiplier, int(seconds_left)]
		_button.disabled = true
	else:
		_set_burn_style(false)
		# Live preview of what a pop right now would lock in.
		var preview_mult := 1.0 + (_tuning.frenzy_max_multiplier - 1.0) * _frenzy.meter
		var preview_secs := _frenzy.meter * _tuning.frenzy_burn_duration
		_button.text = "TURBO %.1f× for %ds" % [preview_mult, int(preview_secs)]
		_button.disabled = not _frenzy.can_pop()


## Swap the fill color when entering/leaving a burn. Only on change — the
## stylebox override is not worth rebuilding every frame.
func _set_burn_style(burning: bool) -> void:
	if burning == _showing_burn_style:
		return
	_showing_burn_style = burning
	var fill := UiPalette.KETCHUP_RED if burning else UiPalette.MUSTARD_GOLD
	UiPalette.style_framed_progress(self, fill, UiPalette.ATOMIC_TEAL)
