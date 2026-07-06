class_name ScrollEdgeArrows
extends Control

# Slim, translucent, full-width arrow strips overlaid on a ScrollContainer's top and
# bottom edges (Tim, 2026-07-05). Each strip exists only while the list can actually
# scroll in its direction, so it doubles as a "there's more content this way" indicator
# — the discoverability cue a flick-only list lacks (a player who never realizes a 13th
# property sits below the fold never saves toward it) — and tapping it glides the list
# one "page". Flick scrolling is untouched: the overlay itself ignores the mouse and the
# strips are slim, so they steal almost none of the swipe surface. Costs ZERO layout
# space — it overlays the list instead of reserving rows above and below it.
#
# Usage — give the ScrollContainer a plain Control host, then lay this over it:
#   var host := Control.new()                  # host owns the area
#   host.add_child(scroll)                     # scroll anchored FULL_RECT inside
#   var arrows := ScrollEdgeArrows.new()
#   arrows.setup(scroll)
#   host.add_child(arrows)                     # drawn (and tapped) above the list

# The shared arrow art (navy strokes — authored for gold utility plates).
const ARROW_UP_TEX := preload("res://art/icons/arrow_up.svg")
const ARROW_DOWN_TEX := preload("res://art/icons/arrow_down.svg")

## Strip height — slim-ish (they overlay tappable rows beneath); 40 → 60 (+50%) for a
## comfier tap target (Tim, 2026-07-05).
const STRIP_HEIGHT := 60.0
## Icon height inside the strip (scaled with the taller strip).
const ICON_HEIGHT := 38.0
## How far one tap pages the list, as a fraction of the visible viewport — a bit under
## a full screen so the last row before the fold stays visible as a continuity anchor.
const PAGE_FRACTION := 0.8
## Seconds the paging glide takes.
const SCROLL_SECONDS := 0.25
## Strip plate: translucent mustard (the utility-button gold the navy arrows were
## authored against), so the strip reads over the cream rows without hiding them.
## Opacity raised 0.55 → 0.7 so the strip reads more clearly as a button (Tim, 2026-07-05).
const STRIP_ALPHA := 0.7
const STRIP_PRESSED_ALPHA := 0.9
## A strip hides when less than this much content (px) remains in its direction.
const EDGE_SLACK_PX := 2.0

var _scroll: ScrollContainer
var _up_button: Button
var _down_button: Button
## The running paging glide, held so a fresh tap restarts it cleanly.
var _glide: Tween


## Call before adding to the tree, with the ScrollContainer this overlay drives.
func setup(scroll: ScrollContainer) -> void:
	_scroll = scroll


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the strips themselves catch input — the space between them stays the list's.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_up_button = _make_strip(ARROW_UP_TEX)
	_up_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_up_button.offset_bottom = STRIP_HEIGHT
	_up_button.pressed.connect(_page.bind(-1.0))
	add_child(_up_button)

	_down_button = _make_strip(ARROW_DOWN_TEX)
	_down_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_down_button.offset_top = -STRIP_HEIGHT
	_down_button.pressed.connect(_page.bind(1.0))
	add_child(_down_button)


## One slim strip: a translucent gold plate with a centered navy arrow.
func _make_strip(arrow: Texture2D) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(UiPalette.MUSTARD_GOLD, STRIP_ALPHA)
	plate.set_corner_radius_all(8)
	var pressed_plate := plate.duplicate() as StyleBoxFlat
	pressed_plate.bg_color = Color(UiPalette.MUSTARD_GOLD, STRIP_PRESSED_ALPHA)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, plate)
	button.add_theme_stylebox_override("pressed", pressed_plate)

	var icon := TextureRect.new()
	icon.texture = arrow
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_top = (STRIP_HEIGHT - ICON_HEIGHT) / 2.0
	icon.offset_bottom = -(STRIP_HEIGHT - ICON_HEIGHT) / 2.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return button


## Show each strip only while the list can scroll its way — so the strips themselves
## are the "more above / more below" indicators, and vanish at the ends of the list
## (and entirely, when everything fits on one screen).
func _process(_delta: float) -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	_up_button.visible = float(_scroll.scroll_vertical) > EDGE_SLACK_PX
	_down_button.visible = float(_scroll.scroll_vertical) < max_scroll - EDGE_SLACK_PX


## Glide the list one page in `direction` (-1 up, +1 down), clamped to the ends.
func _page(direction: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	var step := bar.page * PAGE_FRACTION
	var target := clampf(
		float(_scroll.scroll_vertical) + direction * step, 0.0, bar.max_value - bar.page
	)
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_glide = create_tween()
	_glide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glide.tween_property(_scroll, "scroll_vertical", int(target), SCROLL_SECONDS)
