class_name EventHudBanner
extends PanelContainer

# Compact persistent HUD indicator shown during active weather events (Market Crash).
# Non-blocking: sits cleanly in the UI and displays time remaining and current penalty.
# Tapping re-opens the EventOverlay for full event details.

signal banner_tapped

var _text_label: Label
var _pulse_time: float = 0.0


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(0, 52)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.05, 0.05, 0.95)
	style.border_color = UiPalette.KETCHUP_RED
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_text_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_text_label.add_theme_color_override("font_color", UiPalette.CREAM)
	add_child(_text_label)

	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta * 2.0
	var alpha: float = 0.85 + 0.15 * sin(_pulse_time)
	modulate.a = alpha


## Update the displayed countdown and effect magnitude.
func update_status(remaining_seconds: float, multiplier: float) -> void:
	if remaining_seconds <= 0.0:
		visible = false
		return

	var mins := int(remaining_seconds) / 60
	var secs := int(remaining_seconds) % 60
	_text_label.text = "📉 MARKET CRASH (%d%% Income) · %02d:%02d" % [
		int(multiplier * 100.0), mins, secs
	]
	visible = true


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		banner_tapped.emit()
