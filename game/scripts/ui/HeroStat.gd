class_name HeroStat
extends PanelContainer

# The income/sec hero stat (GDD §3.1: the dopamine delivery vehicle — do
# not stub). Cream ticket plate with red frame, navy numerals (Style Guide §8).
#
# Layout is edge-pinned rather than stacked, to keep the readable values clear of
# a phone's top camera cutout (Tim's device). Each value carries a small caption
# directly beneath it, and the value+caption pair is centered vertically:
#   • the income/sec NUMBER hugs the left edge, with an "INCOME" caption below it;
#   • the CASH-on-hand NUMBER hugs the right edge, with a "CASH" caption below it.
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
# The dynasty/heir name now lives in this panel (it used to be its own header
# strip). It sits centered between the two edge values, on the same line as their
# captions, so it reads as one band: "INCOME … NAME … CASH". Matched to the caption
# size so it belongs to that row rather than competing with the big numbers.
const NAME_FONT_SIZE := CAPTION_FONT_SIZE
const INCOME_BOLD := 3
const CASH_BOLD := 2
const CAPTION_BOLD := 2
const NAME_BOLD := 2

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
var _income_caption: Label
var _cash_caption: Label
var _name_label: Label

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

	# A small caption sits directly beneath each value (the old single, bottom-
	# centered "INCOME PER SECOND" caption is gone). Each is colored to match the
	# number it labels.
	_income_caption = _make_label(UiPalette.NAVY, CAPTION_FONT_SIZE, CAPTION_BOLD)
	_income_caption.text = "INCOME"
	_content.add_child(_income_caption)

	_cash_caption = _make_label(UiPalette.MONEY_GREEN, CAPTION_FONT_SIZE, CAPTION_BOLD)
	_cash_caption.text = "CASH"
	_content.add_child(_cash_caption)

	# The heir/dynasty name, centered between the two edge values and laid out on the
	# caption line (see _layout_labels). Navy to match the income side; Main feeds it
	# via set_dynasty_name each frame.
	_name_label = _make_label(UiPalette.NAVY, NAME_FONT_SIZE, NAME_BOLD)
	_content.add_child(_name_label)


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
	_cash_label.text = Money.of(cash).display()


## The current heir's full name (e.g. "Wellington Pemberton IX"). Shown UPPERCASE
## to match the ticket-plate convention the old header used.
func set_dynasty_name(dynasty_name: String) -> void:
	_name_label.text = dynasty_name.to_upper()


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
	var caption_gap := 2.0  # space between a value and its caption beneath it

	# Income (left edge): the number with the "INCOME" caption beneath it, the pair
	# centered vertically as one block and flush to the left.
	_income_label.size = _income_label.get_minimum_size()
	_income_caption.size = _income_caption.get_minimum_size()
	var income_block_h := _income_label.size.y + caption_gap + _income_caption.size.y
	var income_top := (area.y - income_block_h) / 2.0
	_income_label.position = Vector2(EDGE_MARGIN, income_top)
	_income_caption.position = Vector2(EDGE_MARGIN, income_top + _income_label.size.y + caption_gap)

	# Cash (right edge): the number with the "CASH" caption beneath it, the pair
	# centered vertically and flush to the right.
	_cash_label.size = _cash_label.get_minimum_size()
	_cash_caption.size = _cash_caption.get_minimum_size()
	var cash_block_h := _cash_label.size.y + caption_gap + _cash_caption.size.y
	var cash_top := (area.y - cash_block_h) / 2.0
	_cash_label.position = Vector2(area.x - _cash_label.size.x - EDGE_MARGIN, cash_top)
	var cash_caption_top := cash_top + _cash_label.size.y + caption_gap
	_cash_caption.position = Vector2(area.x - _cash_caption.size.x - EDGE_MARGIN, cash_caption_top)

	# Heir name: horizontally centered across the whole plate, and vertically centered
	# on the caption line so it sits level with the INCOME / CASH captions. (Income and
	# cash captions share the same y because both values are the same font size, so
	# either caption's top works as the reference.)
	_name_label.size = _name_label.get_minimum_size()
	var caption_center_y := cash_caption_top + _cash_caption.size.y / 2.0
	_name_label.position = Vector2(
		(area.x - _name_label.size.x) / 2.0,
		caption_center_y - _name_label.size.y / 2.0
	)


## The mild flash: lift the panel's brightness for an instant, then ease it back
## to normal. modulate is a multiply over the panel's real colors, so this only
## changes how bright it is, never its hue.
func _flash() -> void:
	modulate = Color(FLASH_BRIGHTNESS, FLASH_BRIGHTNESS, FLASH_BRIGHTNESS)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)
