class_name WagePanel
extends VBoxContainer

# The wage button (Layer 1, GDD §5) — the only honest money in the game,
# and it is never removed from the screen. The button's second line carries
# the promotion context: progress toward the next title (Spec §5 — promotion
# needs the lifetime-tap threshold AND tuition), or the rung you've reached.
# When the threshold is met, the claim button appears below.

signal wage_tapped
signal promotion_requested

var _wage: WageState
var _economy: EconomyState

var _wage_button: Button
var _promotion_button: Button


## Call before adding to the tree.
func setup(wage: WageState, economy: EconomyState) -> void:
	_wage = wage
	_economy = economy


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	_wage_button = Button.new()
	_wage_button.custom_minimum_size = Vector2(0, 110)
	_wage_button.add_theme_font_size_override("font_size", 28)
	UiPalette.style_button(_wage_button, false)
	_wage_button.pressed.connect(func() -> void: wage_tapped.emit())
	add_child(_wage_button)

	_promotion_button = Button.new()
	_promotion_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_promotion_button, true)  # tuition is a spend action
	_promotion_button.pressed.connect(func() -> void: promotion_requested.emit())
	add_child(_promotion_button)


func _process(_delta: float) -> void:
	var title := _wage.get_current_title()
	var clock_in_line := "CLOCK IN — %s / tap  (%s)" % [
		Money.of(title.wage_per_tap).display(), title.title_name
	]

	var next := _wage.get_next_title()
	if next == null:
		# Top of the placeholder ladder (the full title table arrives in M2).
		_wage_button.text = clock_in_line + "\nTop of the ladder (for now)"
		_promotion_button.visible = false
		return

	if _wage.is_promotion_unlocked():
		# Threshold met — the claim is now just a purchase (the credential gag).
		_wage_button.text = clock_in_line + "\nPromotion earned — claim it below"
		_promotion_button.visible = true
		_promotion_button.text = "CLAIM PROMOTION: %s — tuition %s" % [
			next.title_name, Money.of(next.tuition).display()
		]
		_promotion_button.disabled = _economy.cash < next.tuition
	else:
		_wage_button.text = clock_in_line + "\nNext: %s at %d taps (%d so far) + %s tuition" % [
			next.title_name, next.tap_threshold, _wage.lifetime_taps,
			Money.of(next.tuition).display()
		]
		_promotion_button.visible = false
