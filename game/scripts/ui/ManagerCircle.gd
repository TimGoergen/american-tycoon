class_name ManagerCircle
extends Control

# The round portrait slot on the left of a property row — and, since the 2026-06-22
# redesign, the property's START / RUSH button too (GDD §5 / §6). The old standalone
# START button is gone; this circle is the control. It has three looks:
#
#   • LOCKED   — the player owns no units yet: a drab gray disc, not interactive.
#   • UNSTAFFED — owned but not yet automated: a SILVER disc bearing a restart icon.
#       Tapping it starts a cycle; holding it rushes (UI notes §2). While the player is
#       actively rushing, the restart icon swaps to an infinity icon.
#   • STAFFED  — automated: the disc fills with the PROPERTY'S accent color and shows a
#       large dark-gray headshot (the staffer running it). A staffed property auto-cycles,
#       so it is NOT interactive — EXCEPT the single highest property the player owns, which
#       always stays hands-on and can still be rushed (then it, too, shows the infinity icon).
#
# Input is handled by a transparent Button laid over the whole circle (the same "art is the
# button" pattern the wage/turbo meters use). The circle's own `_draw` paints the state; the
# button only catches the tap/hold. PropertyRow reads is_held() to pace auto-rush pulses, and
# listens to `pressed` for a single tap. No portrait ART exists yet (M3) — a staffed property
# falls back to the headshot icon; an authored circular PNG, when supplied, draws in its place.

## A single tap on the portrait (start the cycle / one rush). PropertyRow routes it.
signal pressed

# The state-icon set, authored in white so each can be tinted to any color at draw time
# (white × tint = the tint). Restart/infinity read navy on every background; the staffed
# headshot reads dark gray on the property's accent color.
const HEADSHOT_TEX := preload("res://art/icons/headshot.svg")
const RESTART_TEX := preload("res://art/icons/restart.svg")
const INFINITY_TEX := preload("res://art/icons/infinity.svg")

const OUTLINE_WIDTH := 2.0

## Side of the icon's draw box as a fraction of the circle's diameter — the icon sits
## centered and a little inside the outline ring.
const ICON_DIAMETER_FRACTION := 0.58

enum PortraitMode { LOCKED, UNSTAFFED, STAFFED }

var _mode: int = PortraitMode.LOCKED
var _accent: Color = UiPalette.MONEY_GREEN
var _portrait: Texture2D
## True while the player is actively rushing this property (button held on an interactive
## portrait): the state icon becomes the infinity symbol regardless of staffed/unstaffed.
var _show_rush_icon := false

## The transparent button overlaying the circle — the actual tap/hold target.
var _button: Button


func _ready() -> void:
	_button = Button.new()
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The circle art shows through; the button is purely an input catcher.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: pressed.emit())
	add_child(_button)


## Configure the circle for this frame. Called by PropertyRow every refresh.
##   mode         — LOCKED / UNSTAFFED / STAFFED (the look).
##   accent       — the property's accent color, used as the staffed background.
##   portrait     — authored head-shot texture, or null to fall back to the headshot icon.
##   show_rush_icon — draw the infinity icon (player is actively rushing).
##   interactive  — whether taps/holds are accepted (start/rush allowed right now).
func set_state(
		mode: int,
		accent: Color,
		portrait: Texture2D,
		show_rush_icon: bool,
		interactive: bool
) -> void:
	_mode = mode
	_accent = accent
	_portrait = portrait
	_show_rush_icon = show_rush_icon
	# A non-interactive portrait (locked, or an automated non-top property) must not eat
	# taps OR scroll drags, so disable it AND let pointer events pass through to the ladder.
	_button.disabled = not interactive
	_button.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Whether the portrait button is currently held down — PropertyRow uses this to pace
## auto-rush pulses while the player keeps their finger on the circle.
func is_held() -> bool:
	return _button.button_pressed


func _draw() -> void:
	# The circle is inscribed in the (square) control rect.
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0

	if _mode == PortraitMode.LOCKED:
		# Unowned rung: a filled dark-gray disc with a mid-gray ring, matching the locked row.
		draw_circle(center, radius - OUTLINE_WIDTH, UiPalette.DARK_GRAY)
		draw_arc(center, radius - OUTLINE_WIDTH, 0.0, TAU, 64, UiPalette.MID_GRAY, OUTLINE_WIDTH, true)
		return

	# Background disc: the property's accent color once staffed, otherwise the silver
	# start-button plate.
	var background := _accent if _mode == PortraitMode.STAFFED else UiPalette.SILVER
	draw_circle(center, radius - OUTLINE_WIDTH, background)

	# Icon on top. Actively rushing always shows the infinity symbol; otherwise a staffed
	# property shows its staffer (authored portrait, or the dark-gray headshot fallback) and
	# an unstaffed one shows the restart icon.
	if _show_rush_icon:
		_draw_icon(INFINITY_TEX, UiPalette.NAVY, radius, center)
	elif _mode == PortraitMode.STAFFED:
		if _portrait != null:
			var box := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			draw_texture_rect(_portrait, box, false)
		else:
			_draw_icon(HEADSHOT_TEX, UiPalette.DARK_GRAY, radius, center)
	else:
		_draw_icon(RESTART_TEX, UiPalette.NAVY, radius, center)

	# Navy outline ring on top, so the edge stays crisp over any fill or icon.
	draw_arc(center, radius - OUTLINE_WIDTH, 0.0, TAU, 64, UiPalette.NAVY, OUTLINE_WIDTH, true)


## Draw one white-authored state icon, tinted to `color`, centered in the circle.
func _draw_icon(texture: Texture2D, color: Color, radius: float, center: Vector2) -> void:
	var box_side := radius * 2.0 * ICON_DIAMETER_FRACTION
	var box := Rect2(center - Vector2(box_side, box_side) / 2.0, Vector2(box_side, box_side))
	draw_texture_rect(texture, box, false, color)
