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

# Grays for the "not yet owned" property state — a deliberately drab, inactive
# look so an unbought rung reads as locked next to the live cream rungs. A small
# extension of the §1 palette for this one UI state, pending style-guide blessing.
const LIGHT_GRAY := Color("#CBCBCB")  # unowned row background
const MID_GRAY := Color("#9A9A9A")    # unowned borders
const DARK_GRAY := Color("#6E6E6E")   # unowned start button + portrait circle

## Shared width (px) for the buy-mode toggle and the frenzy TURBO button. Kept equal
## and defined in one place so the two right-hand controls line up as one column
## (Tim's call) and can't drift apart when their widths are feel-tuned.
const ACTION_COLUMN_WIDTH := 280


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


## Light-gray plate with a mid-gray border — the background for a property rung
## the player does not own any units of yet (reads as locked/inactive).
static func make_unowned_panel_style() -> StyleBoxFlat:
	return _make_plate(LIGHT_GRAY, MID_GRAY)


## Style a button as the drab dark-gray "unowned" control (the START button on a
## rung the player doesn't own yet). All states share the one gray plate so the
## disabled button still reads as gray rather than the default cream.
static func style_unowned_button(button: Button) -> void:
	var plate := _make_plate(DARK_GRAY, MID_GRAY)
	button.add_theme_stylebox_override("normal", plate)
	button.add_theme_stylebox_override("hover", plate)
	button.add_theme_stylebox_override("pressed", plate)
	button.add_theme_stylebox_override("disabled", plate)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_disabled_color", CREAM)


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


## Dark-gold plate with a bright-gold fill — the "clock in" wage button doubles
## as a promotion-progress meter (UI notes §2: dark gold background, bright gold
## bar). The dark gold is a darkened MUSTARD_GOLD; it's a deliberate extension of
## the §1 nine-color palette for this one meter, pending style-guide blessing.
static func style_gold_progress(bar: ProgressBar) -> void:
	# Thick navy frame around the whole meter (Tim's call: a heavier outline).
	var border_width := 8
	var track := StyleBoxFlat.new()
	track.bg_color = MUSTARD_GOLD.darkened(0.45)
	track.border_color = NAVY
	track.set_border_width_all(border_width)
	track.set_corner_radius_all(4)

	var fill := StyleBoxFlat.new()
	fill.bg_color = MUSTARD_GOLD
	fill.set_corner_radius_all(4)
	# Negative expand margins shrink the fill's draw rect inward by the frame
	# thickness, so the bright-gold fill stays INSIDE the navy outline as it grows
	# rather than painting over the frame.
	fill.set_expand_margin_all(-float(border_width))

	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


## Faint-green plate for a staffed property's hire button — signals "this one is
## automated" (a soft money-green wash over the cream card, navy border).
static func make_staffed_style() -> StyleBoxFlat:
	return _make_plate(CREAM.lerp(MONEY_GREEN, 0.45), NAVY)


## Let a swipe that begins on `root` — or on any of its non-button children —
## fall through to an enclosing ScrollContainer, so the list scrolls when grabbed
## on a panel surface, not only on the bare background. Buttons are left at their
## default STOP filter so a tap on a button stays a tap, never a scroll.
##
## Godot detail: every Control defaults to MOUSE_FILTER_STOP, which swallows the
## press so the ScrollContainer never sees the drag begin (this is why a swipe
## that started on a row used to do nothing). Switching the non-interactive
## surfaces to PASS lets the unhandled press keep bubbling up the tree to the
## scroller, which then drives the scroll once the finger passes the deadzone.
static func allow_scroll_drag_through(root: Control) -> void:
	if root is BaseButton:
		return  # leave buttons (and their internals) alone — taps must stay taps
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in root.get_children():
		if child is Control:
			allow_scroll_drag_through(child as Control)


static func _make_plate(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	return style
