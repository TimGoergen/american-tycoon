class_name HeroStat
extends PanelContainer

# The income/sec hero stat (GDD §3.1: the dopamine delivery vehicle — do
# not stub). Cream ticket plate with red frame, navy numerals (Style Guide §8).
#
# Layout is edge-pinned rather than stacked, to keep the readable values clear of
# a phone's top camera cutout (Tim's device):
#   • the income/sec NUMBER is pinned to the left edge, centered vertically;
#   • the CASH-on-hand is pinned to the right edge, centered vertically;
#   • the "INCOME PER SECOND" caption is pinned to the centre of the bottom edge.
# PanelContainer only fits a single child, so the labels live inside a plain
# Control ("content") that fills the plate, and we position them by hand each frame
# (their widths change as the values do) in _layout_labels.
#
# A purchase triggers a mild flash (a soft brightness pulse) — deliberately no color
# change and no size change (Tim's call, overriding §9's red delta and stamp-pop:
# read as a gentle "noted", not a recolor or resize).

# Type sizes (art direction, not game tuning). Large for at-a-glance reading; the
# matching-color outline fakes a bold weight until real bold fonts arrive in M3.
const INCOME_FONT_SIZE := 64
# Cash on hand reads at the same size as income/sec (Tim's call) — kept tied to
# INCOME_FONT_SIZE so the two stay matched if that value is ever retuned.
const CASH_FONT_SIZE := INCOME_FONT_SIZE
const CAPTION_FONT_SIZE := 30
const INCOME_BOLD := 3
const CASH_BOLD := 2
const CAPTION_BOLD := 2

## Gap kept between a pinned label and the panel edge it hugs.
const EDGE_MARGIN := 14
## Panel height — tall enough that the vertically-centered values clear the caption
## pinned along the bottom edge.
const PANEL_MIN_HEIGHT := 190

# The brightness flash briefly lifts the whole panel toward white and eases back.
# Multiplying modulate (rather than tinting the background) keeps the hue exactly
# the same — it's a flash of light, not a color change — and stays out of the way
# of the frenzy glow, which owns the background color.
const FLASH_BRIGHTNESS := 1.18
const FLASH_SECONDS := 0.18

var _content: Control
var _income_label: Label
var _cash_label: Label
var _caption_label: Label

# Frenzy glow: while a burn is active the ticket pulses toward red to signal the
# accelerated state. Subtle — navy numerals stay readable over the tint.
const GLOW_PULSE_HZ := 2.5
const GLOW_MAX_TINT := 0.30
var _panel_style: StyleBoxFlat
var _frenzy_glow := false
var _glow_time := 0.0


func _ready() -> void:
	var style := UiPalette.make_panel_style()
	style.border_color = UiPalette.KETCHUP_RED  # the red ticket frame (§8)
	add_theme_stylebox_override("panel", style)
	_panel_style = style  # kept so the frenzy glow can pulse its background

	# Free-form layer the labels are pinned within. Its minimum height drives the
	# whole panel's height (PanelContainer grows to fit it plus the stylebox margins).
	_content = Control.new()
	_content.custom_minimum_size = Vector2(0, PANEL_MIN_HEIGHT)
	add_child(_content)

	_income_label = _make_label(UiPalette.NAVY, INCOME_FONT_SIZE, INCOME_BOLD)
	_content.add_child(_income_label)

	_cash_label = _make_label(UiPalette.MONEY_GREEN, CASH_FONT_SIZE, CASH_BOLD)
	_content.add_child(_cash_label)

	_caption_label = _make_label(UiPalette.NAVY, CAPTION_FONT_SIZE, CAPTION_BOLD)
	_caption_label.text = "INCOME PER SECOND"
	_content.add_child(_caption_label)


## Build a large, faux-bold label in the given color. The bold weight is faked with
## a same-color outline (no bold font asset exists yet — they arrive in M3).
func _make_label(color: Color, font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", outline)
	return label


func set_income_per_sec(income_per_sec: float) -> void:
	_income_label.text = Money.of(income_per_sec).display() + "/s"


func set_cash(cash: float) -> void:
	_cash_label.text = "Cash: " + Money.of(cash).display()


## Toggle the frenzy glow. Main drives this from the live frenzy state each frame.
func set_frenzy_glow(active: bool) -> void:
	_frenzy_glow = active


## Announce a purchase: a mild flash (a soft brightness pulse). No color change and
## no size change — the panel never resizes — see the class header.
func flash_purchase() -> void:
	_flash()


func _process(delta: float) -> void:
	_layout_labels()

	# Frenzy glow: pulse the ticket background between cream and a soft red while
	# a burn is active; snap back to plain cream the moment it ends.
	if _frenzy_glow:
		_glow_time += delta
		var pulse := 0.5 + 0.5 * sin(_glow_time * TAU * GLOW_PULSE_HZ)
		_panel_style.bg_color = UiPalette.CREAM.lerp(UiPalette.KETCHUP_RED, pulse * GLOW_MAX_TINT)
	elif _panel_style.bg_color != UiPalette.CREAM:
		_glow_time = 0.0
		_panel_style.bg_color = UiPalette.CREAM


## Pin each label to its edge of the plate. Done every frame because the values'
## widths change, and a pinned label must stay flush to its edge as it does.
func _layout_labels() -> void:
	var area := _content.size

	# Income/sec number: left edge, centered vertically.
	_income_label.size = _income_label.get_minimum_size()
	_income_label.position = Vector2(EDGE_MARGIN, (area.y - _income_label.size.y) / 2.0)

	# Cash on hand: right edge, centered vertically.
	_cash_label.size = _cash_label.get_minimum_size()
	_cash_label.position = Vector2(
		area.x - _cash_label.size.x - EDGE_MARGIN,
		(area.y - _cash_label.size.y) / 2.0
	)

	# Caption: centre of the bottom edge.
	_caption_label.size = _caption_label.get_minimum_size()
	_caption_label.position = Vector2(
		(area.x - _caption_label.size.x) / 2.0,
		area.y - _caption_label.size.y - EDGE_MARGIN
	)


## The mild flash: lift the panel's brightness for an instant, then ease it back
## to normal. modulate is a multiply over the panel's real colors, so this only
## changes how bright it is, never its hue.
func _flash() -> void:
	modulate = Color(FLASH_BRIGHTNESS, FLASH_BRIGHTNESS, FLASH_BRIGHTNESS)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)
