class_name WagePanel
extends VBoxContainer

# The wage button (Layer 1, GDD §5) — the only honest money in the game,
# and it is never removed from the screen. Shows the current title and
# per-tap wage; surfaces the promotion claim when its tap threshold is met.

signal wage_tapped
signal promotion_requested

var _wage: WageState
var _economy: EconomyState

var _wage_button: Button
var _promotion_button: Button
var _progress_label: Label


## Call before adding to the tree.
func setup(wage: WageState, economy: EconomyState) -> void:
	_wage = wage
	_economy = economy


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	_wage_button = Button.new()
	_wage_button.custom_minimum_size = Vector2(0, 110)
	_wage_button.add_theme_font_size_override("font_size", 32)
	UiPalette.style_button(_wage_button, false)
	_wage_button.pressed.connect(func() -> void: wage_tapped.emit())
	add_child(_wage_button)

	_promotion_button = Button.new()
	_promotion_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_promotion_button, true)  # tuition is a spend action
	_promotion_button.pressed.connect(func() -> void: promotion_requested.emit())
	add_child(_promotion_button)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_progress_label.add_theme_font_size_override("font_size", 20)
	add_child(_progress_label)


func _process(_delta: float) -> void:
	var title := _wage.get_current_title()
	_wage_button.text = "CLOCK IN — %s / tap  (%s)" % [
		Money.of(title.wage_per_tap).display(), title.title_name
	]

	var next := _wage.get_next_title()
	if next == null:
		# Top of the placeholder ladder (the full title table arrives in M2).
		_promotion_button.visible = false
		_progress_label.text = ""
		return

	if _wage.is_promotion_unlocked():
		_promotion_button.visible = true
		_promotion_button.text = "CLAIM PROMOTION: %s — tuition %s" % [
			next.title_name, Money.of(next.tuition).display()
		]
		_promotion_button.disabled = _economy.cash < next.tuition
		_progress_label.text = ""
	else:
		_promotion_button.visible = false
		_progress_label.text = "Next title: %s — taps %d / %d" % [
			next.title_name, _wage.lifetime_taps, next.tap_threshold
		]
