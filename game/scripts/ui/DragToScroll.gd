class_name DragToScroll
extends RefCounted

# Makes a ScrollContainer swipe-scrollable even where its content is tiled with BUTTONS.
#
# THE PROBLEM THIS SOLVES. A ScrollContainer handles touch drags itself, but only for touches it
# actually receives. A Button swallows the touch it is pressed with, so a list whose whole surface is
# buttons — the property ladder, the Legacy shop, Balance Tuning, the Challenges list, the Settings
# page — becomes a dead patch you cannot scroll from. The player's finger lands on a button no matter
# where they put it (Tim, 2026-08-06: "the buttons block swipe scrolling").
#
# THE FIX. Watch each button's `gui_input`, and pan `scroll_vertical` by hand when a press turns into
# a drag. The event is never consumed, so a genuine tap still reaches the button's own signals.
#
# SUPPRESSING THE TAP. A drag ends with a release over whatever button it finished on, and that
# button will happily fire. So callers must check `moved` before acting on a press — see the note on
# that property. The Legacy shop learned this the expensive way: buying on press meant a swipe across
# the shop spent gems on every button it crossed, and a drag is not detectable until after the press
# has already happened. Anything irreversible therefore belongs on RELEASE, guarded by `moved`.
#
# Three screens grew their own copies of this before it was extracted here (LegacyScreen,
# DevTuningPanel, ChallengesScreen). They still carry theirs; this exists so the next screen does not
# become a fourth, and so any fix found later has one obvious home to move to.


## How far (px of travel) a press must move before it counts as a scroll rather than a tap. Small
## enough that a deliberate swipe is recognised immediately, large enough that the wobble in a real
## finger-press on a phone does not cancel the tap.
const DEFAULT_THRESHOLD := 12.0

## TRUE once the current gesture has travelled far enough to be a scroll. Callers read this in their
## button handlers and return early — that is what stops a swipe from also pressing whatever it
## happened to end on. Reset by the next fresh press.
var moved := false

var _scroll: ScrollContainer
var _threshold: float
## Total travel in the current gesture, unsigned — an up-then-down wiggle still counts as a drag.
var _accum := 0.0


func _init(scroll: ScrollContainer, threshold: float = DEFAULT_THRESHOLD) -> void:
	_scroll = scroll
	_threshold = threshold


## Route one control's input through this helper. Safe to call on any Control; it is a no-op for one
## that ignores the mouse.
func watch(control: Control) -> void:
	if control == null:
		return
	control.gui_input.connect(_on_control_gui_input)


## Route every button beneath `root`, including `root` itself. Use this after building a page so a
## control added later is picked up by re-walking rather than by remembering to register it.
func watch_buttons_under(root: Node) -> void:
	if root is BaseButton:
		watch(root as Control)
	for child in root.get_children():
		watch_buttons_under(child)


## A fresh press starts a new gesture; anything else may be a drag.
##
## The press is read off the RAW event rather than off the Button's `button_down` signal, because
## buttons in these lists are routinely `disabled` (maxed, unaffordable, locked) and a disabled
## Button emits no `button_down` while still swallowing the touch. Reading it here keeps a row of
## disabled controls from becoming a dead patch of list.
func _on_control_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_gesture()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_gesture()
		return
	_pan_on_drag(event)


func _begin_gesture() -> void:
	_accum = 0.0
	moved = false


## Pan the list when a press over a control turns into a drag.
func _pan_on_drag(event: InputEvent) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return

	var delta_y := 0.0
	if event is InputEventScreenDrag:
		delta_y = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# DESKTOP ONLY. Godot's emulate_mouse_from_touch (on by default) synthesises a mouse motion
		# for every InputEventScreenDrag, so counting both on a phone pans at twice the speed of the
		# finger and trips the threshold after half the intended travel.
		if OS.has_feature("mobile"):
			return
		delta_y = event.relative.y
	else:
		return

	# A finger moving DOWN the screen reveals content ABOVE, so scroll_vertical decreases.
	_scroll.scroll_vertical -= int(delta_y)
	_accum += absf(delta_y)
	if _accum >= _threshold:
		moved = true
