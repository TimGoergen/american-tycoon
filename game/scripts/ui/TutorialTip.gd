class_name TutorialTip
extends Control

# A lightweight, tap-to-dismiss "coach card" that teaches ONE concept the first time it becomes
# relevant (Plans/Tutorial_Onboarding_Plan.md). Non-blocking: it floats above the game WITHOUT
# freezing it, anchored near the control the tip is about, and dismisses on any tap. Main owns one
# instance and calls show_tip(); the "teach only once" gating and the on/off setting live in
# TutorialProgress, so this node is pure presentation.

signal dismissed

## The card's fixed column width (1080-wide design space) — wide enough to read, narrow enough to
## sit beside the control it points at.
const CARD_WIDTH := 720.0
## The card's inner content margin per side (matches UiPalette.make_panel_style's 12px plate
## padding). The wrapped text width is the card width minus both margins.
const CARD_PADDING := 12.0
## Gap between the card and the control it points at, and the minimum gap to any screen edge.
const GAP_FROM_TARGET := 16.0
const EDGE_MARGIN := 24.0
## Pointer-arrow (tail) dimensions, and the pulsing target-highlight ring.
const ARROW_WIDTH := 46.0
const ARROW_HEIGHT := 24.0
const HIGHLIGHT_MARGIN := 8.0
const HIGHLIGHT_BORDER := 6
const HIGHLIGHT_CORNER := 12
const HIGHLIGHT_PULSE_HZ := 1.4
## How far, toward screen centre, the card starts before sliding out to its anchor — extra travel
## to catch the eye that also leads it toward the target.
const SLIDE_DISTANCE := 190.0

var _card: PanelContainer
var _title_label: Label
var _body_label: Label
## The entrance pop-in and the looping attention "breathe" that follows it. Both are killed on
## dismiss / re-show so a stale tween can never keep scaling a hidden or reused card.
var _entrance_tween: Tween
var _pulse_tween: Tween
## The control this card points at (drives the arrow + highlight); null = a centered, undirected card.
var _target: Control
## The card's resting position: the entrance slides TO this from an offset, and the decorations
## (pointer arrow, target ring) are drawn relative to it.
var _final_pos := Vector2.ZERO
## Whether the arrow + ring are currently painted — revealed only once the slide-in settles, so a
## static decoration can never lag the moving card.
var _show_decorations := false
var _arrow_points_up := true
var _arrow_center_x := 0.0
## The pulsing ring drawn around the target; its border alpha is animated from _highlight_time.
var _highlight_style: StyleBoxFlat
var _highlight_time := 0.0


func _ready() -> void:
	# Cover the screen, but let every tap through EXCEPT on the card itself, so the game stays
	# fully interactive while a tip is up (the no-friction rule).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_card()
	_build_highlight_style()


func _build_card() -> void:
	_card = PanelContainer.new()
	# The standard cream card, lifted off the busy game background with a soft drop shadow so it
	# reads as a distinct "pay attention" surface instead of blending into the UI behind it.
	var card_style := UiPalette.make_panel_style()
	card_style.shadow_size = 14
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	card_style.shadow_offset = Vector2(0.0, 6.0)
	_card.add_theme_stylebox_override("panel", card_style)
	# The card is positioned by hand (see _place_near), so it anchors top-left and we set its
	# position directly rather than letting a container lay it out.
	_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card.custom_minimum_size.x = CARD_WIDTH
	# The card catches taps so a tap ON it dismisses; taps outside it pass through to the game.
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(_on_card_input)

	# Wrapped-text width = card width minus both content-margin sides. Pinning each label to this
	# width is what makes AUTOWRAP actually wrap: without a fixed width a Label reports its FULL
	# unwrapped text as its minimum width, which would balloon the card far past the screen (and
	# then the on-screen clamp collapses it into a corner).
	var text_width := CARD_WIDTH - CARD_PADDING * 2.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_card.add_child(column)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	_title_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size.x = text_width
	column.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_body_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size.x = text_width
	column.add_child(_body_label)

	var got_it := Button.new()
	got_it.text = "GOT IT"
	got_it.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	UiPalette.style_button(got_it, false)
	got_it.pressed.connect(_dismiss)
	column.add_child(got_it)

	add_child(_card)


## Reveal the card with this copy, anchored near `target` (or screen-centered if target is null).
func show_tip(title: String, body: String, target: Control) -> void:
	_target = target
	_title_label.text = title
	_body_label.text = body
	# The card's height depends on how the wrapped text lays out, which isn't known until after a
	# layout pass — so keep the card itself hidden for one frame to avoid a flash at the old spot,
	# then place it once its real size is known.
	_card.visible = false
	visible = true
	await get_tree().process_frame
	_place_near(target)
	_card.visible = true
	_animate_in()


func _place_near(target: Control) -> void:
	# Use the VIEWPORT rect for the screen bounds, not this control's own size: the tip node
	# starts hidden, and a hidden full-rect Control isn't laid out yet, so self.size reads ~0 and
	# would collapse the clamp below into the top-left corner. The viewport rect is always valid
	# and is in the same coordinate space as the target's global rect.
	var screen := get_viewport_rect().size
	# The card's size after a layout pass; fall back to its computed minimum if not yet laid out.
	var card_size := _card.size
	if card_size.x < 1.0 or card_size.y < 1.0:
		card_size = _card.get_combined_minimum_size()

	var pos := Vector2.ZERO
	if target != null and target.is_inside_tree():
		var t := target.get_global_rect()
		# Horizontally center the card on the target.
		pos.x = t.position.x + t.size.x * 0.5 - card_size.x * 0.5
		# Prefer just BELOW the target; fall back to above; else clamp on-screen.
		var below := t.end.y + GAP_FROM_TARGET
		var above := t.position.y - GAP_FROM_TARGET - card_size.y
		if below + card_size.y <= screen.y - EDGE_MARGIN:
			pos.y = below
		elif above >= EDGE_MARGIN:
			pos.y = above
		else:
			pos.y = t.position.y
	else:
		# No anchor control — center on screen.
		pos = (screen - card_size) * 0.5
	# Never let the card touch a screen edge.
	pos.x = clampf(pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, screen.x - card_size.x - EDGE_MARGIN))
	pos.y = clampf(pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, screen.y - card_size.y - EDGE_MARGIN))
	_final_pos = pos
	_card.position = pos

	# Pointer-arrow geometry, revealed once the entrance settles (see _on_entrance_finished): a tail
	# on the card's near edge, centred on the target and pointing at it.
	_show_decorations = false
	if target != null and target.is_inside_tree():
		var t := target.get_global_rect()
		_arrow_points_up = pos.y >= t.end.y  # card sits below the target -> the tail points up at it
		_arrow_center_x = clampf(t.position.x + t.size.x * 0.5, \
				pos.x + ARROW_WIDTH, pos.x + card_size.x - ARROW_WIDTH)


## Pop the card in — a scale + fade with a slight overshoot — then hand off to the pulse. Movement
## is what the eye catches, so the card announces itself rather than quietly appearing.
func _animate_in() -> void:
	_kill_tweens()
	_card.pivot_offset = _card.size * 0.5  # scale/pulse around the card's center, not its corner
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	# Start the card off toward screen centre and slide it out to its anchor: travel across the
	# screen is extra motion to catch the eye, and moving TO the target also leads the eye there.
	var screen := get_viewport_rect().size
	var toward_centre := signf(screen.x * 0.5 - (_final_pos.x + _card.size.x * 0.5))
	if toward_centre == 0.0:
		toward_centre = 1.0
	_card.position = _final_pos + Vector2(toward_centre * SLIDE_DISTANCE, 0.0)
	_entrance_tween = create_tween()
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(_card, "position", _final_pos, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_card, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_card, "modulate:a", 1.0, 0.2)
	_entrance_tween.finished.connect(_on_entrance_finished, CONNECT_ONE_SHOT)


## Entrance done: settle the card exactly at its anchor, reveal the pointer arrow + target ring,
## and start the gentle breathing pulse.
func _on_entrance_finished() -> void:
	_card.position = _final_pos
	_show_decorations = true
	queue_redraw()
	_start_pulse()


## The pulsing ring drawn around the target control (built once; its border alpha is animated).
func _build_highlight_style() -> void:
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color.TRANSPARENT
	_highlight_style.set_border_width_all(HIGHLIGHT_BORDER)
	_highlight_style.set_corner_radius_all(HIGHLIGHT_CORNER)


func _process(delta: float) -> void:
	# Repaint the pulsing target ring while a directed card is up (the arrow is static; the ring
	# breathes). Cheap, and skipped entirely when no card is showing.
	if visible and _show_decorations:
		_highlight_time += delta
		queue_redraw()


func _draw() -> void:
	if not _show_decorations or _target == null or not _target.is_inside_tree():
		return

	# Pointer arrow (tail): cream fill with navy slanted edges, on the card's near edge and pointing
	# at the target. Drawn behind the card (a Control's _draw sits under its children); the triangle
	# extends AWAY from the card into the gap, so it reads as a tail off the card toward the control.
	var base_y := _final_pos.y if _arrow_points_up else _final_pos.y + _card.size.y
	var tip_y := base_y - ARROW_HEIGHT if _arrow_points_up else base_y + ARROW_HEIGHT
	var a := Vector2(_arrow_center_x - ARROW_WIDTH * 0.5, base_y)
	var b := Vector2(_arrow_center_x + ARROW_WIDTH * 0.5, base_y)
	var tip := Vector2(_arrow_center_x, tip_y)
	draw_colored_polygon(PackedVector2Array([a, b, tip]), UiPalette.CREAM)
	draw_line(a, tip, UiPalette.NAVY, 3.0)
	draw_line(b, tip, UiPalette.NAVY, 3.0)

	# Target highlight: a mustard ring around the control, its alpha breathing so the actionable
	# element itself draws the eye ("do this").
	var pulse := 0.5 + 0.5 * sin(_highlight_time * TAU * HIGHLIGHT_PULSE_HZ)
	_highlight_style.border_color = Color(UiPalette.MUSTARD_GOLD, 0.4 + 0.5 * pulse)
	draw_style_box(_highlight_style, _target.get_global_rect().grow(HIGHLIGHT_MARGIN))


## A subtle, continuous "breathe" (tiny scale in/out) that keeps the card noticeable until it is
## dismissed — small enough not to nag, enough to catch a wandering eye that missed the pop-in.
func _start_pulse() -> void:
	if not visible:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_card, "scale", Vector2(1.03, 1.03), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_card, "scale", Vector2.ONE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_tweens() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()


func _on_card_input(event: InputEvent) -> void:
	# A tap anywhere on the card dismisses it (as well as the GOT IT button).
	var pressed_mouse := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var pressed_touch := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if pressed_mouse or pressed_touch:
		_dismiss()


func _dismiss() -> void:
	if not visible:
		return
	_kill_tweens()
	_card.scale = Vector2.ONE  # leave the card at rest for its next use
	_show_decorations = false
	_target = null
	queue_redraw()
	visible = false
	dismissed.emit()
