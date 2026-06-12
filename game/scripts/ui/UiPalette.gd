class_name UiPalette

# The nine-color palette from the Art Style Guide §1, plus the shared style
# builders for M1's placeholder chrome (§8). The limited palette is the
# consistency engine: no colors outside this table appear anywhere.
# (Colors are art direction with the style guide as their source of truth,
# not game tuning, so they live here rather than in /config.)

const CREAM := Color("#F4ECD8")
const KETCHUP_RED := Color("#B5402A")
const NAVY := Color("#1D2D50")
const MUSTARD_GOLD := Color("#E3B23C")
const ATOMIC_TEAL := Color("#9FD8D4")
const MONEY_GREEN := Color("#7DA87B")
const INK_NAVY := Color("#0D1830")
const BRICK := Color("#8E2F1E")
const PALE_GOLD := Color("#F0D49A")


## Cream plate with a navy border — the standard card/panel (§8).
static func make_panel_style() -> StyleBoxFlat:
	return _make_plate(CREAM, NAVY)


## Style a Button in place. Standard buttons are navy-on-mustard; action
## buttons (spend/act: buy, pop, tuition) are pale-gold-on-red — red is
## reserved for "spend/act", never decoration (§8).
static func style_button(button: Button, is_action: bool) -> void:
	var plate := KETCHUP_RED if is_action else MUSTARD_GOLD
	var pressed_plate := BRICK if is_action else PALE_GOLD
	var label_color := PALE_GOLD if is_action else NAVY

	button.add_theme_stylebox_override("normal", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("hover", _make_plate(plate, NAVY))
	button.add_theme_stylebox_override("pressed", _make_plate(pressed_plate, NAVY))
	button.add_theme_stylebox_override("disabled", _make_plate(CREAM, NAVY))

	button.add_theme_color_override("font_color", label_color)
	button.add_theme_color_override("font_hover_color", label_color)
	button.add_theme_color_override("font_pressed_color", NAVY)
	button.add_theme_color_override("font_disabled_color", Color(NAVY, 0.45))


## Teal track with a fill in the given color (§8: sliders and meters).
static func style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = ATOMIC_TEAL
	track.set_corner_radius_all(3)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)

	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


static func _make_plate(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	return style
