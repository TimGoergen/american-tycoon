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
# Uses UiPalette.FONT_HERO so the headline amounts read a touch larger.
const INCOME_FONT_SIZE := UiPalette.FONT_HERO
# Cash on hand reads at the same size as income/sec (Tim's call) — kept tied to
# INCOME_FONT_SIZE so the two stay matched if that value is ever retuned.
const CASH_FONT_SIZE := INCOME_FONT_SIZE
# Caption text uses UiPalette.FONT_BODY at Tim's request.
const CAPTION_FONT_SIZE := UiPalette.FONT_BODY
# The dynasty/heir name now lives in this panel (it used to be its own header
# strip). It sits centered between the two edge values, on the same line as their
# captions, so it reads as one band: "INCOME … NAME … CASH". Uses UiPalette.FONT_SUBHEAD
# (Tim's call) so the heir name carries more weight than the captions.
const NAME_FONT_SIZE := UiPalette.FONT_SUBHEAD
const INCOME_BOLD := 3
const CASH_BOLD := 2
const CAPTION_BOLD := 2
const NAME_BOLD := 2

## Gap kept between a pinned label and the panel edge it hugs.
const EDGE_MARGIN := 14
## Panel height — tall enough that the vertically-centered values clear the caption
## pinned along the bottom edge. Reduced 10% (190 -> 171) at Tim's request: the trim
## comes out of the empty space below the captions, and the label layout is frozen at
## the original height (LABEL_LAYOUT_HEIGHT) so NO text moves.
const PANEL_MIN_HEIGHT := 171
## Height the labels are laid out against. Held at the original 190 so the numerals and
## captions keep their exact positions even though the plate outline is now shorter.
const LABEL_LAYOUT_HEIGHT := 190

# Planet backdrop (Tim, 2026-06-26): a zoomed-in crop of the UPPER-LEFT section of the
# current planet's world image sits behind the numbers, on a plain white plate. The world
# SVGs have a transparent background (only the globe is painted), so the white plate shows
# around the globe and the frenzy glow can still tint it. Drawn as a faint watermark so the
# navy/green numerals stay readable on top.
#
# REGION_FRACTION picks how much of the source image's top-left we crop to (0.5 = exactly the
# upper-left quadrant, i.e. the top-left quarter); a smaller value zooms in tighter. WATERMARK_ALPHA
# fades the globe so it reads as a background, not a foreground graphic. Both are art-direction
# knobs for Tim to eyeball — change them, not the layout code.
const PLANET_REGION_FRACTION := 0.5
const PLANET_WATERMARK_ALPHA := 0.6
# Tier (1-based, EpochCatalog) -> world image. Index 0 is unused so the array is tier-aligned.
const PLANET_IMAGE_PATHS := [
	"",
	"res://art/worlds/earth.svg",
	"res://art/worlds/luminari.svg",
	"res://art/worlds/geth-sentinel.svg",
	"res://art/worlds/mycelium.svg",
	"res://art/worlds/quartzite.svg",
	"res://art/worlds/chronophage.svg",
]
var _planet_image: TextureRect
var _shown_planet_tier := 0  # which tier's image is currently loaded (0 = none yet)

# The brightness flash briefly lifts the whole panel toward white and eases back.
# Multiplying modulate (rather than tinting the background) keeps the hue exactly
# the same — it's a flash of light, not a color change — and stays out of the way
# of the frenzy glow, which owns the background color.
const FLASH_BRIGHTNESS := 1.18
const FLASH_SECONDS := 0.18

# Income readout throttle (Tim, 2026-06-16): the income/sec figure was repainting every
# frame, changing so fast it was unreadable. We now hold each shown value for a short
# interval and repaint a few times a second so the number settles long enough to read.
# (Responsiveness is governed by GameState.BONUS_INCOME_TAU, not this cadence.)
const INCOME_REFRESH_INTERVAL := 0.33
var _pending_income_per_sec := 0.0
var _income_refresh_accumulator := INCOME_REFRESH_INTERVAL  # repaint on the very first frame

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
	# Plain WHITE plate (Tim, 2026-06-26) so the planet watermark reads on a clean ground —
	# replaces the former cream fill.
	style.bg_color = Color.WHITE
	style.border_color = UiPalette.KETCHUP_RED  # the red ticket frame (§8)
	style.set_border_width_all(12)  # outline +300% (3 -> 12) at Tim's request (2026-06-23)
	# Round the TOP corners to nest inside the phone's rounded screen corners (Tim,
	# 2026-06-22); the bottom corners keep the standard small radius.
	style.corner_radius_top_left = UiPalette.SCREEN_CORNER_RADIUS
	style.corner_radius_top_right = UiPalette.SCREEN_CORNER_RADIUS
	add_theme_stylebox_override("panel", style)
	_panel_style = style  # kept so the frenzy glow can pulse its background

	# Planet backdrop, BEHIND the labels. A PanelContainer sizes every child to the same
	# interior rect, and draw order follows child order, so adding this mask before _content
	# puts it behind the numbers. The mask is a rounded rectangle used purely as a stencil
	# (clip_children ONLY draws its children where the mask is opaque, and never paints the
	# mask itself), so the square planet image is clipped to the plate's rounded corners —
	# the same trick Main uses for the prairie background. The corners are inset slightly from
	# the plate's so the image tucks just inside the red frame.
	var planet_mask := Panel.new()
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE  # only this shape's alpha matters — it is the stencil
	mask_style.corner_radius_top_left = UiPalette.SCREEN_CORNER_RADIUS - 12
	mask_style.corner_radius_top_right = UiPalette.SCREEN_CORNER_RADIUS - 12
	mask_style.corner_radius_bottom_left = 4
	mask_style.corner_radius_bottom_right = 4
	planet_mask.add_theme_stylebox_override("panel", mask_style)
	planet_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	planet_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(planet_mask)

	_planet_image = TextureRect.new()
	_planet_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	# COVERED fills the wide plate with the cropped upper-left region, scaling it up (the zoom).
	_planet_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_planet_image.modulate = Color(1, 1, 1, PLANET_WATERMARK_ALPHA)
	_planet_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_mask.add_child(_planet_image)

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


## Record the latest income/sec. The label itself only repaints on the throttled
## cadence in _process, so the displayed number stays still long enough to read.
func set_income_per_sec(income_per_sec: float) -> void:
	_pending_income_per_sec = income_per_sec


func set_cash(cash: float) -> void:
	# The cash balance uses its own fuller formatting (commas to $999,999, cents below
	# $1,000, "$1.00 M" above) rather than the compact display() costs/income use.
	_cash_label.text = Money.of(cash).display_cash()


## The current heir's full name (e.g. "Wellington Pemberton IX"). Shown UPPERCASE
## to match the ticket-plate convention the old header used.
func set_dynasty_name(dynasty_name: String) -> void:
	_name_label.text = dynasty_name.to_upper()


## Toggle the frenzy glow. Main drives this from the live frenzy state each frame.
func set_frenzy_glow(active: bool) -> void:
	_frenzy_glow = active


## Show the current planet's world image (1-based EpochCatalog tier). Main calls this every
## frame; we only rebuild the cropped texture when the tier actually changes, so it is cheap.
func set_planet_tier(tier: int) -> void:
	if tier == _shown_planet_tier:
		return
	_shown_planet_tier = tier
	if tier < 1 or tier >= PLANET_IMAGE_PATHS.size():
		_planet_image.texture = null
		return
	var source: Texture2D = load(PLANET_IMAGE_PATHS[tier])
	if source == null:
		_planet_image.texture = null
		return
	# Crop to the image's UPPER-LEFT corner (an AtlasTexture is just "show this sub-rectangle
	# of the source"); the TextureRect's COVERED stretch then scales that crop up to fill the
	# plate, which is what "zoomed in" means here.
	var region := AtlasTexture.new()
	region.atlas = source
	region.region = Rect2(
		Vector2.ZERO,
		source.get_size() * PLANET_REGION_FRACTION
	)
	_planet_image.texture = region


## Announce a purchase: a mild flash (a soft brightness pulse). No color change and
## no size change — the panel never resizes — see the class header.
func flash_purchase() -> void:
	_flash()


func _process(delta: float) -> void:
	_layout_labels()

	# Throttled income repaint: only update the visible number a few times a second so
	# it reads as a steady figure rather than a blur (see INCOME_REFRESH_INTERVAL).
	_income_refresh_accumulator += delta
	if _income_refresh_accumulator >= INCOME_REFRESH_INTERVAL:
		_income_refresh_accumulator = 0.0
		_income_label.text = Money.of(_pending_income_per_sec).display() + "/s"

	# Frenzy glow: pulse the ticket background between white and a soft red while a burn is
	# active; snap back to plain white the moment it ends. The glow shows through the planet
	# watermark's transparent areas (the world art is a globe on a clear background).
	if _frenzy_glow:
		_glow_time += delta
		var pulse := 0.5 + 0.5 * sin(_glow_time * TAU * GLOW_PULSE_HZ)
		_panel_style.bg_color = Color.WHITE.lerp(UiPalette.KETCHUP_RED, pulse * GLOW_MAX_TINT)
	elif _panel_style.bg_color != Color.WHITE:
		_glow_time = 0.0
		_panel_style.bg_color = Color.WHITE


## Pin each label to its edge of the plate. Done every frame because the values'
## widths change, and a pinned label must stay flush to its edge as it does.
func _layout_labels() -> void:
	var area := _content.size
	var caption_gap := 2.0  # space between a value and its caption beneath it

	# Captions stay put where the old centered value+caption block placed them; only the
	# big amounts move up. So we still compute the centered-block top (where the pair used
	# to sit) to anchor each caption, then nudge the amount to half that distance from the
	# top of the panel — i.e. twice as close to the top (Tim's call).

	# Income (left edge): caption stays at the centered-block position; amount moves up.
	# Vertical math uses LABEL_LAYOUT_HEIGHT (the original plate height), not the live
	# area.y, so shrinking the plate leaves every label exactly where it was.
	_income_label.size = _income_label.get_minimum_size()
	_income_caption.size = _income_caption.get_minimum_size()
	var income_block_h := _income_label.size.y + caption_gap + _income_caption.size.y
	var income_centered_top := (LABEL_LAYOUT_HEIGHT - income_block_h) / 2.0
	var income_caption_top := income_centered_top + _income_label.size.y + caption_gap
	_income_label.position = Vector2(EDGE_MARGIN, income_centered_top / 2.0)
	_income_caption.position = Vector2(EDGE_MARGIN, income_caption_top)

	# Cash (right edge): same treatment.
	_cash_label.size = _cash_label.get_minimum_size()
	_cash_caption.size = _cash_caption.get_minimum_size()
	var cash_block_h := _cash_label.size.y + caption_gap + _cash_caption.size.y
	var cash_centered_top := (LABEL_LAYOUT_HEIGHT - cash_block_h) / 2.0
	var cash_caption_top := cash_centered_top + _cash_label.size.y + caption_gap
	_cash_label.position = Vector2(area.x - _cash_label.size.x - EDGE_MARGIN, cash_centered_top / 2.0)
	_cash_caption.position = Vector2(area.x - _cash_caption.size.x - EDGE_MARGIN, cash_caption_top)

	# Heir name: horizontally centered across the whole plate, and BOTTOM-aligned with the
	# INCOME / CASH captions (Tim, 2026-06-21) so all three labels share one baseline — the
	# taller name (it's a larger font) now grows upward only, not below the captions.
	# (Income and cash captions share the same y because both values are the same font size,
	# so either caption's bottom is the baseline.)
	_name_label.size = _name_label.get_minimum_size()
	var caption_baseline_y := cash_caption_top + _cash_caption.size.y
	_name_label.position = Vector2(
		(area.x - _name_label.size.x) / 2.0,
		caption_baseline_y - _name_label.size.y
	)


## The mild flash: lift the panel's brightness for an instant, then ease it back
## to normal. modulate is a multiply over the panel's real colors, so this only
## changes how bright it is, never its hue.
func _flash() -> void:
	modulate = Color(FLASH_BRIGHTNESS, FLASH_BRIGHTNESS, FLASH_BRIGHTNESS)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)
