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

var _card: PanelContainer
var _title_label: Label
var _body_label: Label


func _ready() -> void:
	# Cover the screen, but let every tap through EXCEPT on the card itself, so the game stays
	# fully interactive while a tip is up (the no-friction rule).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_card()


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
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


func _place_near(target: Control) -> void:
	var card_size := _card.size
	var pos := Vector2.ZERO
	if target != null and target.is_inside_tree():
		var t := target.get_global_rect()
		# Horizontally center the card on the target.
		pos.x = t.position.x + t.size.x * 0.5 - card_size.x * 0.5
		# Prefer just BELOW the target; fall back to above; else clamp on-screen.
		var below := t.end.y + GAP_FROM_TARGET
		var above := t.position.y - GAP_FROM_TARGET - card_size.y
		if below + card_size.y <= size.y - EDGE_MARGIN:
			pos.y = below
		elif above >= EDGE_MARGIN:
			pos.y = above
		else:
			pos.y = t.position.y
	else:
		# No anchor control — center on screen.
		pos = (size - card_size) * 0.5
	# Never let the card touch a screen edge.
	pos.x = clampf(pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, size.x - card_size.x - EDGE_MARGIN))
	pos.y = clampf(pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, size.y - card_size.y - EDGE_MARGIN))
	_card.position = pos


func _on_card_input(event: InputEvent) -> void:
	# A tap anywhere on the card dismisses it (as well as the GOT IT button).
	var pressed_mouse := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var pressed_touch := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if pressed_mouse or pressed_touch:
		_dismiss()


func _dismiss() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()
