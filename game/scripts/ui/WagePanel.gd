class_name WagePanel
extends VBoxContainer

# The wage button (Layer 1, GDD §5) — the only honest money in the game, and it
# is never removed from the screen.
#
# The "clock in" button doubles as a promotion-progress meter (UI notes §2): a
# dark-gold plate whose bright-gold bar fills toward the next title. A
# ProgressBar draws that fill; a transparent Button sits on top to catch taps and
# show the big (2×-size) CLOCK IN label. A compact context line below keeps the
# title/next-title detail without crowding the big button. When the tap threshold
# is met, the claim button appears.

signal wage_tapped
signal promotion_requested

var _wage: WageState
var _economy: EconomyState

var _wage_meter: ProgressBar
var _wage_button: Button
var _context_label: Label
var _promotion_button: Button


## Call before adding to the tree.
func setup(wage: WageState, economy: EconomyState) -> void:
	_wage = wage
	_economy = economy


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	# The meter is the button background; its bright-gold fill shows promotion
	# progress. It ignores the mouse so the Button on top handles every tap.
	_wage_meter = ProgressBar.new()
	_wage_meter.custom_minimum_size = Vector2(0, 170)  # tall: the primary tap target
	_wage_meter.min_value = 0.0
	_wage_meter.max_value = 1.0
	_wage_meter.show_percentage = false
	_wage_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiPalette.style_gold_progress(_wage_meter)
	add_child(_wage_meter)

	# Transparent button overlaying the meter — the gold shows through, only the
	# label and the click belong to the button. Font is 2× the old size (28→56).
	_wage_button = Button.new()
	_wage_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wage_button.add_theme_font_size_override("font_size", 56)
	_wage_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_wage_button.add_theme_color_override("font_color", UiPalette.NAVY)
	_wage_button.add_theme_color_override("font_hover_color", UiPalette.NAVY)
	_wage_button.add_theme_color_override("font_pressed_color", UiPalette.INK_NAVY)
	_wage_button.pressed.connect(func() -> void: wage_tapped.emit())
	_wage_meter.add_child(_wage_button)

	# Compact context line (not enlarged): which title you hold and what's next.
	_context_label = Label.new()
	_context_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_context_label.add_theme_font_size_override("font_size", 20)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_context_label)

	_promotion_button = Button.new()
	_promotion_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_promotion_button, true)  # tuition is a spend action
	_promotion_button.pressed.connect(func() -> void: promotion_requested.emit())
	add_child(_promotion_button)


func _process(_delta: float) -> void:
	var title := _wage.get_current_title()
	_wage_button.text = "CLOCK IN\n%s / tap" % Money.of(title.wage_per_tap).display()

	var next := _wage.get_next_title()
	if next == null:
		# Top of the placeholder ladder (the full title table arrives in M2).
		_wage_meter.value = 1.0
		_context_label.text = "%s — top of the ladder (for now)" % title.title_name
		_promotion_button.visible = false
		return

	if _wage.is_promotion_unlocked():
		# Threshold met — the claim is now just a purchase (the credential gag).
		_wage_meter.value = 1.0
		_context_label.text = "%s — promotion earned, claim it below" % title.title_name
		_promotion_button.visible = true
		_promotion_button.text = "CLAIM PROMOTION: %s — tuition %s" % [
			next.title_name, Money.of(next.tuition).display()
		]
		_promotion_button.disabled = _economy.cash < next.tuition
	else:
		_wage_meter.value = _promotion_progress(title, next)
		_context_label.text = "%s → %s: %d / %d taps + %s tuition" % [
			title.title_name, next.title_name,
			_wage.lifetime_taps, next.tap_threshold,
			Money.of(next.tuition).display()
		]
		_promotion_button.visible = false


## Fraction of the way from the current title's tap threshold to the next title's
## — the bright-gold fill level. lifetime_taps is dynastic and only grows, so this
## climbs from 0 to 1 across the current rung.
func _promotion_progress(title: TitleRow, next: TitleRow) -> float:
	var span := next.tap_threshold - title.tap_threshold
	if span <= 0:
		return 0.0
	return clampf(float(_wage.lifetime_taps - title.tap_threshold) / float(span), 0.0, 1.0)
