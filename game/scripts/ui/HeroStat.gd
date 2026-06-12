class_name HeroStat
extends PanelContainer

# The income/sec hero stat (GDD §3.1: the dopamine delivery vehicle — do
# not stub). Cream ticket plate with red frame, navy numerals (Style Guide
# §8). Purchases trigger a hard stamp-pop plus a flashed red delta
# (§9: stamps, not bounces — mechanical, ~120 ms).

# Animation feel values from Style Guide §9 (art direction, not game tuning).
const STAMP_SCALE := 1.12
const STAMP_SECONDS := 0.12
const DELTA_VISIBLE_SECONDS := 0.8

var _income_label: Label
var _cash_label: Label
var _delta_label: Label
var _delta_timer := 0.0


func _ready() -> void:
	var style := UiPalette.make_panel_style()
	style.border_color = UiPalette.KETCHUP_RED  # the red ticket frame (§8)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	add_child(column)

	var caption := Label.new()
	caption.text = "I N C O M E   P E R   S E C O N D"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", UiPalette.NAVY)
	caption.add_theme_font_size_override("font_size", 20)
	column.add_child(caption)

	var stat_line := HBoxContainer.new()
	stat_line.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_line.add_theme_constant_override("separation", 18)
	column.add_child(stat_line)

	_income_label = Label.new()
	_income_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_income_label.add_theme_font_size_override("font_size", 56)
	stat_line.add_child(_income_label)

	_delta_label = Label.new()
	_delta_label.visible = false
	_delta_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_delta_label.add_theme_font_size_override("font_size", 40)
	stat_line.add_child(_delta_label)

	_cash_label = Label.new()
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cash_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_cash_label.add_theme_font_size_override("font_size", 34)
	column.add_child(_cash_label)


func set_income_per_sec(income_per_sec: float) -> void:
	_income_label.text = Money.of(income_per_sec).display() + "/s"


func set_cash(cash: float) -> void:
	_cash_label.text = "Cash: " + Money.of(cash).display()


## Announce a purchase: stamp the ticket and flash the income/sec delta.
func flash_purchase(ips_before: float, ips_after: float) -> void:
	if ips_before > 0.0:
		_delta_label.text = "+%.0f%%" % ((ips_after / ips_before - 1.0) * 100.0)
	else:
		_delta_label.text = "NEW!"
	_delta_label.visible = true
	_delta_timer = DELTA_VISIBLE_SECONDS
	_stamp()


func _process(delta: float) -> void:
	if _delta_timer > 0.0:
		_delta_timer -= delta
		if _delta_timer <= 0.0:
			_delta_label.visible = false


## The hard stamp: scale up and straight back down, no easing curves —
## print-press energy, not mobile-game bounce (Style Guide §9).
func _stamp() -> void:
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * STAMP_SCALE, STAMP_SECONDS / 2.0)
	tween.tween_property(self, "scale", Vector2.ONE, STAMP_SECONDS / 2.0)
