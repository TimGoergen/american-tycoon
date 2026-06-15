class_name FrenzyBar
extends HBoxContainer

# Frenzy meter UI (Spec §7, Style Guide §8): mustard fill while charging,
# red fill while burning down. The pop button always previews its live
# reward ("POP ×2.4 for 54s") — every irreversible decision shows its
# reward first (Spec §7 house rule).

signal pop_requested

var _frenzy: FrenzyState
var _tuning: TuningConfig

var _bar: ProgressBar
var _pop_button: Button
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
	add_theme_constant_override("separation", 10)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 34)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_progress_bar(_bar, UiPalette.MUSTARD_GOLD)
	add_child(_bar)

	_pop_button = Button.new()
	# Same width as the buy-mode toggle, so the two right-hand controls share a column.
	_pop_button.custom_minimum_size = Vector2(UiPalette.ACTION_COLUMN_WIDTH, 0)
	_pop_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_pop_button, true)  # red: the pop is an act button
	_pop_button.pressed.connect(func() -> void: pop_requested.emit())
	add_child(_pop_button)


func _process(delta: float) -> void:
	_displayed_fill = BarSmoothing.approach(_displayed_fill, _frenzy.meter, delta)
	_bar.value = _displayed_fill

	if _frenzy.mode == FrenzyState.Mode.BURNING:
		_set_burn_style(true)
		var seconds_left := _frenzy.meter * _tuning.frenzy_burn_duration
		# Multiplier reads "2.4×" (the × trails the number) per Tim's call.
		_pop_button.text = "%.1f× — %ds left" % [_frenzy.locked_multiplier, int(seconds_left)]
		_pop_button.disabled = true
	else:
		_set_burn_style(false)
		# Live preview of what a pop right now would lock in.
		var preview_mult := 1.0 + (_tuning.frenzy_max_multiplier - 1.0) * _frenzy.meter
		var preview_secs := _frenzy.meter * _tuning.frenzy_burn_duration
		_pop_button.text = "TURBO %.1f× for %ds" % [preview_mult, int(preview_secs)]
		_pop_button.disabled = not _frenzy.can_pop()


## Swap the fill color when entering/leaving a burn. Only on change — the
## stylebox override is not worth rebuilding every frame.
func _set_burn_style(burning: bool) -> void:
	if burning == _showing_burn_style:
		return
	_showing_burn_style = burning
	var fill := UiPalette.KETCHUP_RED if burning else UiPalette.MUSTARD_GOLD
	UiPalette.style_progress_bar(_bar, fill)
