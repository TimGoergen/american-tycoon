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
# The current EPOCH name lives in this panel (Tim, 2026-06-27 — it replaced the
# heir/dynasty name). It sits centered between the two edge values, on the same line
# as their captions, so it reads as one band: "INCOME … EPOCH … CASH". Uses
# UiPalette.FONT_SUBHEAD (Tim's call) so the epoch name carries more weight than the
# captions. The value shown is the civilization Earth is currently trading with
# ("Earth" on tier 1, an alien race's name on later epochs).
const NAME_FONT_SIZE := UiPalette.FONT_SUBHEAD
const INCOME_BOLD := 3
const CASH_BOLD := 2
const CAPTION_BOLD := 2
const NAME_BOLD := 2

# The dollar-bill icon shown next to the CASH caption. The art is a 2:1 green-and-gold
# bill; we draw it at a medium size on the caption line. Gap is the space between the
# bill and the "CASH" word.
const CASH_BILL_ICON_PATH := "res://art/icons/dollar_bill.svg"
const CASH_BILL_SIZE := Vector2(72, 36)
const CASH_BILL_GAP := 8.0

## Gap kept between a pinned label and the panel edge it hugs.
const EDGE_MARGIN := 14
## Panel height. Made 30% taller (171 -> 222) at Tim's request (2026-06-27) for a bigger,
## bolder income panel. The label layout height below is scaled with it so the numerals
## and captions stay proportionally placed in the taller plate.
const PANEL_MIN_HEIGHT := 222
## Height the labels are laid out against. Scaled up with the panel (190 -> 247, +30%) so
## the vertical centering tracks the taller plate.
const LABEL_LAYOUT_HEIGHT := 247

# Planet backdrop (Tim, 2026-06-26): the current planet's world image sits behind the numbers
# on a plain white plate, shown mostly whole and centred (zoomed out enough to read as a globe,
# not a close-up of one spot). The world SVGs have a transparent background (only the globe is
# painted), so the white plate shows around the globe and the frenzy glow can still tint it.
# Drawn as a faint watermark so the navy/green numerals stay readable on top.
#
# We BAKE the watermark into a fresh ImageTexture in code rather than letting a TextureRect crop
# and clip it. Two reasons, both learned the hard way (2026-06-26):
#   1. The world art is an imported SVG. Assigning that imported texture (or an AtlasTexture over
#      it) to a TextureRect draws nothing on the GPU here, even though the pixels are valid — so
#      we read them with get_image() and rebuild the texture, which draws reliably.
#   2. Godot's clip_children (the rounded-corner stencil trick Main uses for its backdrop) does
#      not work when a SECOND clip_children group exists elsewhere in the tree (Main already has
#      one). So we round the corners by writing transparency into the image's own alpha instead.
#
# FILL_FRACTION is how much of the plate the globe fills once scaled to fit (1.0 = as large as
# fits with the whole globe still visible; smaller leaves a margin). WATERMARK_ALPHA fades the
# globe so it reads as a background, not a foreground graphic. Both are art-direction knobs for
# Tim to eyeball — change them, not the layout code.
const PLANET_FILL_FRACTION := 1.0
const PLANET_WATERMARK_ALPHA := 0.6
# Corner rounding baked into the watermark, in pixels. Matches the white plate's own corners as
# seen at the content rect: the plate rounds its TOP corners by SCREEN_CORNER_RADIUS and its
# bottom corners only slightly, and the content sits ~12px (the border) inside that.
const PLANET_CORNER_RADIUS_TOP := UiPalette.SCREEN_CORNER_RADIUS - 12
const PLANET_CORNER_RADIUS_BOTTOM := 4
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
var _baked_planet_size := Vector2i.ZERO  # plate size the current watermark was baked for

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
var _cash_bill: TextureRect  # small dollar-bill icon shown beside the CASH caption
var _epoch_label: Label  # the current epoch / civilization name (was the heir name)

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

	# Planet backdrop, BEHIND the labels. The PanelContainer draws its own white plate first, then
	# its children in order, so adding this image before _content puts the watermark between the
	# plate and the numbers. The container sizes this child to the plate's interior rect; we bake
	# a texture to exactly that size (see _refresh_planet_watermark), so STRETCH_SCALE fills it
	# 1:1 with the cropping and rounded corners already baked in. EXPAND_IGNORE_SIZE keeps the
	# huge source image from inflating the panel's minimum size.
	_planet_image = TextureRect.new()
	_planet_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_planet_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_planet_image.stretch_mode = TextureRect.STRETCH_SCALE
	_planet_image.modulate = Color(1, 1, 1, PLANET_WATERMARK_ALPHA)
	_planet_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_planet_image)

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

	# A small green-and-gold dollar-bill icon sits just left of the "CASH" caption
	# (Tim, 2026-06-27) so the cash side reads as "💵 CASH". Medium size — tall enough
	# to read as a bill, small enough to sit on the caption line. KEEP_ASPECT_CENTERED
	# preserves the 2:1 bill shape inside its box.
	_cash_bill = TextureRect.new()
	_cash_bill.texture = load(CASH_BILL_ICON_PATH)
	_cash_bill.custom_minimum_size = CASH_BILL_SIZE
	_cash_bill.size = CASH_BILL_SIZE
	_cash_bill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cash_bill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cash_bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_cash_bill)

	# The current epoch / civilization name, centered between the two edge values and laid
	# out on the caption line (see _layout_labels). Navy to match the income side; Main feeds
	# it via set_epoch_name each frame.
	_epoch_label = _make_label(UiPalette.NAVY, NAME_FONT_SIZE, NAME_BOLD)
	_content.add_child(_epoch_label)


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


## The current epoch / civilization name (e.g. "EARTH", "LUMINARI COLLECTIVE"). Shown
## UPPERCASE to match the ticket-plate convention. Replaced the heir name (Tim, 2026-06-27).
func set_epoch_name(epoch_name: String) -> void:
	_epoch_label.text = epoch_name.to_upper()


## Toggle the frenzy glow. Main drives this from the live frenzy state each frame.
func set_frenzy_glow(active: bool) -> void:
	_frenzy_glow = active


## Show the current planet's world image (1-based EpochCatalog tier). Main calls this every
## frame; the watermark is only re-baked when the tier (or the plate size) actually changes,
## so the cost falls only on a first contact, not every frame.
func set_planet_tier(tier: int) -> void:
	if tier != _shown_planet_tier:
		_shown_planet_tier = tier
		_baked_planet_size = Vector2i.ZERO  # tier changed -> force a re-bake on the next refresh
	_refresh_planet_watermark()


## Build (or rebuild) the baked watermark texture if the tier or the plate size has changed.
## Called from set_planet_tier and from _process, since the plate's real size is not known until
## the container has laid this control out (the very first call usually has a zero size).
func _refresh_planet_watermark() -> void:
	var plate_size := Vector2i(_planet_image.size)
	if plate_size.x <= 0 or plate_size.y <= 0:
		return  # not laid out yet — try again next frame
	if plate_size == _baked_planet_size:
		return  # already baked for this tier and size
	_baked_planet_size = plate_size

	var tier := _shown_planet_tier
	if tier < 1 or tier >= PLANET_IMAGE_PATHS.size():
		_planet_image.texture = null
		return
	var source: Texture2D = load(PLANET_IMAGE_PATHS[tier])
	if source == null:
		_planet_image.texture = null
		return
	_planet_image.texture = _bake_planet_watermark(source.get_image(), plate_size)


## Turn a world image into the plate-sized, rounded, zoomed watermark texture. Done on the CPU
## (see the class header for why we copy pixels instead of using the imported texture directly).
func _bake_planet_watermark(full_image: Image, plate_size: Vector2i) -> ImageTexture:
	# 1. Frame the globe itself: crop away the SVG's transparent padding so we work with just the
	# painted planet. get_used_rect() is the bounding box of the non-transparent pixels (the memory
	# note on texture sizing: always use it, the canvas carries varying transparent padding).
	var globe := full_image.get_region(full_image.get_used_rect())

	# 2. Scale the WHOLE globe to fit inside the plate (contain, preserving aspect) so most/all of
	# it stays visible rather than zooming into one spot. The plate is far wider than it is tall,
	# so this fits the globe to the height and centres it, leaving the sides clear.
	var fit_scale := minf(
		float(plate_size.x) / globe.get_width(),
		float(plate_size.y) / globe.get_height()
	) * PLANET_FILL_FRACTION
	var globe_size := Vector2i(
		maxi(1, int(globe.get_width() * fit_scale)),
		maxi(1, int(globe.get_height() * fit_scale))
	)
	globe.resize(globe_size.x, globe_size.y, Image.INTERPOLATE_BILINEAR)
	globe.convert(Image.FORMAT_RGBA8)  # ensure an alpha channel for the transparent surround

	# 3. Compose the globe, centred, onto a transparent plate-sized canvas. The transparent
	# surround lets the white plate (and the frenzy glow) show around the planet.
	var watermark := Image.create(plate_size.x, plate_size.y, false, Image.FORMAT_RGBA8)
	watermark.fill(Color(0, 0, 0, 0))
	var center_offset := (plate_size - globe_size) / 2
	watermark.blit_rect(globe, Rect2i(Vector2i.ZERO, globe_size), center_offset)

	# 4. Round the corners by clearing the alpha outside the rounded rectangle, so the watermark
	# matches the white plate's curved corners (clip_children can't do this here — see the header).
	_clear_rounded_corners(watermark)
	return ImageTexture.create_from_image(watermark)


## Set alpha to 0 on the pixels of each corner that fall outside the rounded rectangle, matching
## the plate (large top corners, tiny bottom corners). Only the small corner boxes are scanned.
func _clear_rounded_corners(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corners := [
		{"radius": PLANET_CORNER_RADIUS_TOP, "center": Vector2i(PLANET_CORNER_RADIUS_TOP, PLANET_CORNER_RADIUS_TOP), "dir": Vector2i(-1, -1)},
		{"radius": PLANET_CORNER_RADIUS_TOP, "center": Vector2i(w - PLANET_CORNER_RADIUS_TOP, PLANET_CORNER_RADIUS_TOP), "dir": Vector2i(1, -1)},
		{"radius": PLANET_CORNER_RADIUS_BOTTOM, "center": Vector2i(PLANET_CORNER_RADIUS_BOTTOM, h - PLANET_CORNER_RADIUS_BOTTOM), "dir": Vector2i(-1, 1)},
		{"radius": PLANET_CORNER_RADIUS_BOTTOM, "center": Vector2i(w - PLANET_CORNER_RADIUS_BOTTOM, h - PLANET_CORNER_RADIUS_BOTTOM), "dir": Vector2i(1, 1)},
	]
	for corner in corners:
		var radius: int = corner["radius"]
		var center: Vector2i = corner["center"]
		var dir: Vector2i = corner["dir"]
		# Walk only the corner's square; a pixel that sits in the outward quadrant AND beyond the
		# radius from the arc's centre is outside the rounded edge, so we make it transparent.
		for offset_y in range(radius):
			for offset_x in range(radius):
				var pixel := center + Vector2i(dir.x * offset_x, dir.y * offset_y)
				if pixel.x < 0 or pixel.y < 0 or pixel.x >= w or pixel.y >= h:
					continue
				if Vector2(offset_x, offset_y).length() > radius:
					var color := image.get_pixel(pixel.x, pixel.y)
					color.a = 0.0
					image.set_pixel(pixel.x, pixel.y, color)


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

	# Dollar-bill icon: sits just left of the CASH caption, vertically centered on it, so the
	# pair reads as "[bill] CASH" flush to the right edge.
	_cash_bill.position = Vector2(
		_cash_caption.position.x - CASH_BILL_GAP - CASH_BILL_SIZE.x,
		cash_caption_top + (_cash_caption.size.y - CASH_BILL_SIZE.y) / 2.0
	)

	# Epoch name: horizontally centered across the whole plate, and BOTTOM-aligned with the
	# INCOME / CASH captions (Tim, 2026-06-21) so all three labels share one baseline — the
	# taller name (it's a larger font) now grows upward only, not below the captions.
	# (Income and cash captions share the same y because both values are the same font size,
	# so either caption's bottom is the baseline.)
	_epoch_label.size = _epoch_label.get_minimum_size()
	var caption_baseline_y := cash_caption_top + _cash_caption.size.y
	_epoch_label.position = Vector2(
		(area.x - _epoch_label.size.x) / 2.0,
		caption_baseline_y - _epoch_label.size.y
	)


## The mild flash: lift the panel's brightness for an instant, then ease it back
## to normal. modulate is a multiply over the panel's real colors, so this only
## changes how bright it is, never its hue.
func _flash() -> void:
	modulate = Color(FLASH_BRIGHTNESS, FLASH_BRIGHTNESS, FLASH_BRIGHTNESS)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)
