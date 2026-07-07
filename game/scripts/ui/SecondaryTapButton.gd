class_name SecondaryTapButton
extends Node

# Presses the parent Button with SECONDARY fingers, so two-finger play works on any
# control that adds this node — the buy-mode toggle, the TURBO meter, and the clock-in
# button, not just the property rows (Tim, 2026-07-07). The rows keep their own bespoke
# handler in PropertyRow (same pattern, three targets per row, predating this node).
#
# Background (see Plans/Concurrent_Multitouch_Property_Panel.md): Godot emulates the
# mouse from the FIRST finger of a gesture only, and Buttons act on that emulated
# mouse. While finger 1 holds something, finger 2 produces no mouse event at all. So
# this node reads raw InputEventScreenTouch, classifies each finger as primary (the
# gesture's first — left entirely to the normal Button path) or secondary, and drives
# the parent Button for secondary presses: a press inside the button emits its
# `pressed` signal, exactly as a primary tap would. The primary finger is never acted
# on here, so single-touch behaviour is unchanged and nothing ever double-fires.
#
# Usage:
#   some_button.add_child(SecondaryTapButton.new())
# For a hold-driven control (the clock-in auto-tap), keep the reference and OR the
# Button's button_pressed with is_secondary_held() in the hold pump.

## Global gate, set by Main._process each frame: true only while the Property tab is
## showing and no full-screen overlay is up, so a stray second finger can never press a
## control hidden behind a modal. Shared by every instance AND by PropertyRow's
## row-level secondary handler — one rule for all secondary-finger input.
static var enabled := false

var _button: BaseButton
## Every finger currently down (primary included), keyed by finger index. Tracked even
## while the gate is off, so the primary/secondary classification is always correct.
var _active_fingers := {}
## The gesture's first finger — the one Godot emulates the mouse from. Locked until it
## releases (matching Godot's own emulation rule); never acted on here.
var _primary_finger := -1
## Secondary fingers currently holding the parent button, keyed by finger index.
var _held_fingers := {}


func _ready() -> void:
	_button = get_parent() as BaseButton
	assert(_button != null, "SecondaryTapButton must be added as a child of a Button")


## True while any SECONDARY finger is holding the parent button — hold pumps OR this
## with the Button's own button_pressed so either finger can drive the hold.
func is_secondary_held() -> bool:
	return not _held_fingers.is_empty()


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
		return
	# A held secondary finger sliding OFF the button cancels its hold, matching how
	# lifting a finger off a button stops its repeat.
	var drag := event as InputEventScreenDrag
	if drag != null and _held_fingers.has(drag.index) and not _hits_button(drag.position):
		_held_fingers.erase(drag.index)


func _on_touch_pressed(index: int, global_pos: Vector2) -> void:
	# The first finger of a gesture is the one Godot emulates the mouse from — leave it
	# entirely to the Button path. Record it so its release is recognised, never act on it.
	var is_first_finger := _active_fingers.is_empty()
	_active_fingers[index] = true
	if is_first_finger:
		_primary_finger = index
		return
	if not enabled or not _hits_button(global_pos):
		return
	_held_fingers[index] = true
	# Emitting the Button's own `pressed` signal routes through the exact handlers a
	# primary tap reaches, so the two paths can never drift apart.
	_button.pressed.emit()


func _on_touch_released(index: int) -> void:
	_active_fingers.erase(index)
	_held_fingers.erase(index)
	if index == _primary_finger:
		_primary_finger = -1


## Whether a global point lands on the parent button while it could actually be pressed.
## Respects disabled/visibility, so a secondary finger can only ever trigger what a
## primary finger could.
func _hits_button(global_pos: Vector2) -> bool:
	return not _button.disabled and _button.is_visible_in_tree() \
			and _button.get_global_rect().has_point(global_pos)
