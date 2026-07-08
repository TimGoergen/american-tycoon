class_name GhostScrollBar
extends Control

# A scrollbar HANDLE that exists only while the list is actually moving (Tim,
# 2026-07-08): the property ladder's always-visible bar spent horizontal space on a
# control nobody drags on a phone — flicking is the interaction. The rows get that
# width back; this overlay fades a translucent handle in whenever the scroll position
# changes and fades it back out once the motion stops. No track/background is drawn,
# and it ignores the mouse entirely — it is a position INDICATOR, not a control.
#
# Usage — lay it over the ScrollContainer's host area, after (on top of) the scroll:
#   var ghost := GhostScrollBar.new()
#   ghost.setup(scroll)
#   host.add_child(ghost)

## Handle geometry: a rounded pill hugging the right edge. Widened 10 → 16 and made
## less transparent 0.45 → 0.6 — the first pass was hard to see (Tim, 2026-07-08).
const HANDLE_WIDTH := 16.0
const HANDLE_MIN_HEIGHT := 48.0  # never shrinks into an unreadable speck on long lists
const EDGE_INSET := 4.0          # gap between the handle and the area's right edge
const CORNER_RADIUS := 8         # half the width — full pill ends

## Visibility envelope: fully visible while scrolling and for HOLD_SECONDS after the
## last movement, then fading out over FADE_SECONDS.
const HANDLE_ALPHA := 0.6
const HOLD_SECONDS := 0.6
const FADE_SECONDS := 0.4

var _scroll: ScrollContainer
## Last observed scroll position; -1 marks "not yet observed" so the first sync after
## setup doesn't count as motion and flash the handle on tab open.
var _last_scroll := -1.0
## Seconds since the scroll position last changed (drives the fade envelope).
var _since_motion := 999.0
## The handle's pill stylebox, built once; only its color's alpha changes per frame.
var _handle_style: StyleBoxFlat


## Call before adding to the tree, with the ScrollContainer this overlay watches.
func setup(scroll: ScrollContainer) -> void:
	_scroll = scroll


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handle_style = StyleBoxFlat.new()
	_handle_style.bg_color = Color(UiPalette.NAVY, HANDLE_ALPHA)
	_handle_style.set_corner_radius_all(CORNER_RADIUS)


func _process(delta: float) -> void:
	if _scroll == null:
		return
	var value := float(_scroll.scroll_vertical)
	if value != _last_scroll:
		# Motion — but the very first observation is just syncing to wherever the list
		# already was, not a scroll, so it doesn't wake the handle.
		if _last_scroll >= 0.0:
			_since_motion = 0.0
		_last_scroll = value
	else:
		_since_motion += delta
	# Redraw only through the visible window (motion + hold + fade); once faded out,
	# the overlay draws nothing and costs nothing.
	if _since_motion <= HOLD_SECONDS + FADE_SECONDS:
		queue_redraw()


## The handle's current alpha on the show → hold → fade envelope (0 once faded out).
func _current_alpha() -> float:
	if _since_motion <= HOLD_SECONDS:
		return HANDLE_ALPHA
	var into_fade := (_since_motion - HOLD_SECONDS) / FADE_SECONDS
	return HANDLE_ALPHA * clampf(1.0 - into_fade, 0.0, 1.0)


func _draw() -> void:
	var alpha := _current_alpha()
	if alpha <= 0.0:
		return
	var bar := _scroll.get_v_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	if max_scroll <= 0.0:
		return  # everything fits on screen — there is no position to indicate
	# Handle height mirrors the visible fraction of the content; its travel covers the
	# full area height, positioned by the current scroll fraction. bar.value (float)
	# rather than scroll_vertical (int) so the handle glides with smooth scrolling.
	var handle_height := maxf(HANDLE_MIN_HEIGHT, size.y * float(bar.page) / float(bar.max_value))
	var y := (size.y - handle_height) * clampf(float(bar.value) / max_scroll, 0.0, 1.0)
	_handle_style.bg_color = Color(UiPalette.NAVY, alpha)
	draw_style_box(_handle_style, Rect2(
		size.x - EDGE_INSET - HANDLE_WIDTH, y, HANDLE_WIDTH, handle_height
	))
