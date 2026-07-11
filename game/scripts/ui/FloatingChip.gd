class_name FloatingChip
extends RefCounted

# A small color-coded badge that pops over a successful action in a minigame, shows a short piece of
# context-specific text (e.g. "PERFECT!", "SWISH!", "CAUGHT!", "+3"), then floats up and fades away.
#
# Match-3 pioneered this "result chip" style (Tim, 2026-07-09); Tim asked every minigame to use the
# same feedback for a good action or round (2026-07-11), so this shared helper is the single place the
# look and the float-up animation live. Each game just picks the spot, the text, and the color.
#
# It's a plain helper (no node of its own): call FloatingChip.spawn(...) and it builds the chip, adds
# it to the parent you give, animates it, and frees it when the animation ends.

## Default text size — the big, readable headline size Match-3's chips use. Games that want a smaller
## chip (a lot of chips at once, or a tight space) can pass their own size.
const DEFAULT_FONT_SIZE := -1  # -1 means "use UiPalette.FONT_HEADLINE"; resolved in spawn()


## Pop a chip over a successful action.
##   parent:    the Control to add the chip to (the chip floats in this node's coordinate space).
##   center:    where to center the chip, in the parent's local coordinates.
##   text:      the short context message (kept to a word or two so it reads at a glance).
##   color:     the chip's background — green for a normal success, gold for a bonus/legacy moment,
##              etc. The text is always white with a navy outline so it reads on any of them.
##   font_size: text size; leave as DEFAULT_FONT_SIZE to use the shared headline size.
static func spawn(parent: Control, center: Vector2, text: String, color: Color,
		font_size: int = DEFAULT_FONT_SIZE) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eats a tap meant for the game
	chip.z_index = 3  # above the game's own drawing

	# Rounded, navy-bordered plate in the outcome color — the same styling as Match-3's chips so
	# every game's feedback matches.
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.border_color = UiPalette.INK_NAVY
	box.set_border_width_all(3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = text
	var resolved_size := UiPalette.FONT_HEADLINE if font_size == DEFAULT_FONT_SIZE else font_size
	label.add_theme_font_size_override("font_size", resolved_size)
	# White text with a thick navy outline reads on any chip color.
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)

	# Size the chip to its text, then center it on the requested spot and float it up as it fades.
	parent.add_child(chip)
	chip.reset_size()
	chip.position = center - chip.size / 2.0
	chip.pivot_offset = chip.size / 2.0
	chip.scale = Vector2(0.7, 0.7)

	# Pop in (a little overshoot), drift upward, and fade — then free itself. Same timing as Match-3.
	var tween := chip.create_tween().set_parallel(true)
	tween.tween_property(chip, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "position:y", chip.position.y - 44.0, 0.7)
	tween.tween_property(chip, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(chip.queue_free)
