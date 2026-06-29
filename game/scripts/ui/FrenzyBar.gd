class_name FrenzyBar
extends ProgressBar

# The frenzy meter IS the TURBO button (Tim, 2026-06-21): the meter fill doubles as
# the button background — mustard while charging, red while burning — with a
# transparent Button overlaid on top that catches the tap (the same "meter as button
# background" pattern the wage button uses).
#
# On top of the button sit two pieces that ignore the mouse so the tap still reaches
# it (Tim, 2026-06-29): the green growth-arrow icon, left-aligned, standing in for the
# word "TURBO", and the live reward readout ("2.4× for 54s") right-aligned. The reward
# is always previewed — every irreversible decision shows its reward first (Spec §7).

signal pop_requested

## The growth-arrow symbol that replaces the word "TURBO" on the button.
const TURBO_TEX := preload("res://art/icons/turbo.svg")
## Side length of that icon, sized to sit comfortably inside the button's height.
const TURBO_ICON_SIZE := 64

var _frenzy: FrenzyState
var _tuning: TuningConfig

var _button: Button
## The reward readout drawn on the right of the button (the icon stands in for the
## word "TURBO" on the left). Set live in _process.
var _label: Label
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
	UiPalette.style_framed_progress(self, UiPalette.MUSTARD_GOLD, UiPalette.PROGRESS_TRACK_GRAY)

	# Transparent button overlaying the meter: the gold/red fill shows through, and only
	# the tap belongs to the button. Empty styleboxes in every state keep the meter visible
	# (a Button's default plate is opaque and would hide the fill).
	_button = Button.new()
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_button.pressed.connect(func() -> void: pop_requested.emit())
	add_child(_button)

	# Overlay sitting on top of the button: the icon on the left, the reward text on the
	# right. It ignores the mouse so taps pass straight through to the button beneath. The
	# side margins keep both pieces clear of the navy frame.
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 16)
	overlay.add_theme_constant_override("margin_right", 16)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(overlay)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)

	# Left: the growth-arrow icon standing in for the word "TURBO".
	var icon := TextureRect.new()
	icon.texture = TURBO_TEX
	icon.custom_minimum_size = Vector2(TURBO_ICON_SIZE, TURBO_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	# Right: the live reward readout. It takes the remaining width and right-aligns, so the
	# text hugs the frame's right edge while the icon stays pinned left.
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Larger + bold readout (Tim, 2026-06-25), white in all states so a tap never recolors it.
	_label.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(_label)


func _process(delta: float) -> void:
	_displayed_fill = BarSmoothing.approach(_displayed_fill, _frenzy.meter, delta)
	value = _displayed_fill

	if _frenzy.mode == FrenzyState.Mode.BURNING:
		_set_burn_style(true)
		var seconds_left := _frenzy.meter * _tuning.frenzy_burn_duration
		# Multiplier reads "2.4×" (the × trails the number) per Tim's call. The icon on the
		# left already conveys "TURBO", so the readout is just the reward.
		_label.text = "%.1f× — %ds left" % [_frenzy.locked_multiplier, int(seconds_left)]
		_button.disabled = true
	else:
		_set_burn_style(false)
		# Live preview of what a pop right now would lock in.
		var preview_mult := 1.0 + (_tuning.frenzy_max_multiplier - 1.0) * _frenzy.meter
		var preview_secs := _frenzy.meter * _tuning.frenzy_burn_duration
		_label.text = "%.1f× for %ds" % [preview_mult, int(preview_secs)]
		_button.disabled = not _frenzy.can_pop()


## Swap the fill color when entering/leaving a burn. Only on change — the
## stylebox override is not worth rebuilding every frame.
func _set_burn_style(burning: bool) -> void:
	if burning == _showing_burn_style:
		return
	_showing_burn_style = burning
	var fill := UiPalette.KETCHUP_RED if burning else UiPalette.MUSTARD_GOLD
	UiPalette.style_framed_progress(self, fill, UiPalette.PROGRESS_TRACK_GRAY)
