class_name ManagerCircle
extends Control

# The round portrait slot on the left of a property row. It is empty — a thin
# outline ring — until the property is staffed; once a manager is hired it shows
# that manager's head shot.
#
# No portrait art exists yet (head-shot art arrives in M3), so until a texture is
# supplied the staffed state falls back to a filled disc bearing the manager's
# first initial — a stand-in that still reads as "this property now has a person
# running it". When portraits are authored they should be circular PNGs (round
# image, transparent corners), so drawing the texture into the circle's box reads
# as a round photo without needing a mask.

const OUTLINE_WIDTH := 2.0

var _staffed := false
var _portrait: Texture2D
var _initial := ""
## True when the property has no units bought yet; draws the circle a drab dark
## gray to match the locked/unowned look of its row.
var _owned := true


## Tell the circle what to show. Called by PropertyRow whenever the row refreshes.
## `owned` is false for a rung the player hasn't bought any units of yet.
func set_state(staffed: bool, portrait: Texture2D, manager_name: String, owned: bool = true) -> void:
	_staffed = staffed
	_portrait = portrait
	_initial = manager_name.substr(0, 1).to_upper() if manager_name != "" else ""
	_owned = owned
	queue_redraw()


func _draw() -> void:
	# The circle is inscribed in the (square) control rect.
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0

	if not _owned:
		# Unowned rung: a filled dark-gray disc with a mid-gray ring, so the
		# portrait slot reads as inactive alongside the gray row background.
		draw_circle(center, radius - OUTLINE_WIDTH, UiPalette.DARK_GRAY)
		draw_arc(center, radius - OUTLINE_WIDTH, 0.0, TAU, 64, UiPalette.MID_GRAY, OUTLINE_WIDTH, true)
		return

	if not _staffed:
		# Empty slot: just the outline ring, interior left clear.
		draw_arc(center, radius - OUTLINE_WIDTH, 0.0, TAU, 64, UiPalette.NAVY, OUTLINE_WIDTH, true)
		return

	if _portrait != null:
		var box := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		draw_texture_rect(_portrait, box, false)
	else:
		# Placeholder head shot: a filled disc with the manager's initial centered.
		draw_circle(center, radius - OUTLINE_WIDTH, UiPalette.MONEY_GREEN)
		if _initial != "":
			var font := ThemeDB.fallback_font
			var font_size := int(radius)
			var text_size := font.get_string_size(_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			# draw_string positions by the text baseline; nudge so the glyph sits
			# roughly centered in the disc.
			var baseline := center + Vector2(-text_size.x / 2.0, font_size / 3.0)
			draw_string(font, baseline, _initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiPalette.CREAM)

	# Outline ring on top, so the edge stays crisp over photo or placeholder alike.
	draw_arc(center, radius - OUTLINE_WIDTH, 0.0, TAU, 64, UiPalette.NAVY, OUTLINE_WIDTH, true)
