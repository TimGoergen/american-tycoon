class_name WelcomeBackOverlay
extends ColorRect

# The welcome-back / launch screen (GDD §3.1, §7). Two modes share one fixed layout
# (Tim, 2026-07-09 / re-specified 2026-07-15):
#   * show_pile()   — returning after offline income: the cheerful pile + deadpan stat line, then
#                     PUT IT TO WORK (bank it) or RISK IT (gamble it on a minigame).
#   * show_welcome() — a plain launch with no offline pile: just a BEGIN button.
#
# LAYOUT (Tim, 2026-07-15) — three bands, all positioned by hand in _relayout so both modes
# land identically:
#   * the logo IMAGE (its visible art, not its canvas) is vertically centered at 36% of the
#     screen height from the top;
#   * the button row is vertically centered at 16% of the screen height from the bottom;
#   * everything else (the WELCOME BACK stats) sits just ABOVE the button row, not by the logo.

signal dismissed
## Player chose to gamble the overnight pile on a minigame instead of banking it as-is.
signal risk_pressed

const LOGO_TEXTURE := preload("res://art/branding/american_tycoon_logo.png")

## Screen-height fraction (from the TOP) at which the logo art's vertical center sits.
const LOGO_CENTER_FRACTION := 0.36
## Screen-height fraction (from the BOTTOM) at which the button row's vertical center sits.
const BUTTONS_CENTER_FRACTION := 0.16
## Tallest the logo's canvas may be, as a fraction of the screen — keeps a wide desktop
## window from blowing the logo up past the bands below it.
const LOGO_MAX_HEIGHT_FRACTION := 0.5
## Gap between the stat block's bottom and the button row's top.
const STATS_ABOVE_BUTTONS_GAP := 24.0
## Shared width of the centered content column (stats and buttons alike).
const CONTENT_COLUMN_WIDTH := 760.0

var _pile_label: Label
var _spend_button: Button
var _risk_button: Button
var _away_label: Label
var _logo: TextureRect
## The pile-mode stat content (headline + pile + away line), shown/hidden as a group.
var _pile_content: VBoxContainer
## The strip carrying the stat content, placed just above the button strip.
var _stats_strip: HBoxContainer
## The plain-launch button, shown instead of the pile buttons when there was no offline income.
var _begin_button: Button
## The strip carrying whichever button row the mode shows.
var _button_strip: HBoxContainer
## The pile-mode choice row inside the strip (PUT IT TO WORK / RISK IT).
var _choice_row: HBoxContainer
## Vertical center of the logo ART inside its texture, as a fraction of the texture height.
## The canvas can carry transparent padding, so the used (opaque) rect is what the eye centers.
var _logo_art_center_fraction := 0.5


func _ready() -> void:
	# Black field framing a cream rounded viewing area — the same full-screen frame the main
	# game and dev panel use (Tim, 2026-06-23), so every full-window screen matches.
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	# The three bands are children of the overlay itself (not of a Container), so _relayout
	# is free to place each at its specified screen fraction.
	_logo = TextureRect.new()
	_logo.texture = LOGO_TEXTURE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_logo)

	_pile_content = _build_pile_content()
	_stats_strip = _make_content_strip()
	_strip_column(_stats_strip).add_child(_pile_content)

	_build_button_strip()

	# Where the logo art's vertical center sits inside its canvas (fraction of texture height).
	# Computed once from the imported texture's opaque pixels — the canvas can carry transparent
	# padding, so centering the raw texture would visually off-center the art.
	var logo_image := LOGO_TEXTURE.get_image()
	if logo_image != null:
		var used := logo_image.get_used_rect()
		if used.size.y > 0:
			_logo_art_center_fraction = \
					(float(used.position.y) + float(used.end.y)) / 2.0 / float(logo_image.get_height())

	resized.connect(_relayout)


## An overlay-positioned strip whose content column is horizontally centered: expanding pads on
## both sides of a fixed-width column, the same column pattern both bands use.
func _make_content_strip() -> HBoxContainer:
	var strip := HBoxContainer.new()
	add_child(strip)
	var pad_left := Control.new()
	pad_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(pad_left)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CONTENT_COLUMN_WIDTH, 0)
	strip.add_child(column)
	var pad_right := Control.new()
	pad_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(pad_right)
	return strip


## The fixed-width column at the center of a strip built by _make_content_strip.
func _strip_column(strip: HBoxContainer) -> VBoxContainer:
	return strip.get_child(1) as VBoxContainer


## Build the strip that carries the button row on both screens.
func _build_button_strip() -> void:
	_button_strip = _make_content_strip()
	var column := _strip_column(_button_strip)

	# Two choices on one row (Tim, 2026-06-24): take the overnight pile as-is, or gamble it on a
	# minigame that can swing the haul anywhere from 50% to 200%. The RISK button only appears
	# when transition minigames are enabled (show_pile's allow_risk) and never on the
	# post-minigame result screen — you get one roll.
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 12)
	column.add_child(_choice_row)

	_spend_button = Button.new()
	_spend_button.text = "PUT IT TO WORK"
	_spend_button.custom_minimum_size = Vector2(0, 96)
	_spend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spend_button.add_theme_font_size_override("font_size", 39)  # 28 * 1.4 — 40% larger (Tim)
	_spend_button.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(_spend_button, true)
	_spend_button.pressed.connect(_on_spend_pressed)
	_choice_row.add_child(_spend_button)

	_risk_button = Button.new()
	_risk_button.text = "RISK IT ON A MINIGAME?"
	_risk_button.custom_minimum_size = Vector2(0, 96)
	_risk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_risk_button.add_theme_font_size_override("font_size", 39)  # 28 * 1.4 — 40% larger (Tim)
	_risk_button.add_theme_font_override("font", UiPalette.make_bold_font())
	# The label is long; wrap it onto two lines rather than clipping at narrow widths.
	_risk_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPalette.style_button(_risk_button, false)
	_risk_button.pressed.connect(_on_risk_pressed)
	_choice_row.add_child(_risk_button)

	# The plain-launch BEGIN button (shown by show_welcome when there is no pile).
	_begin_button = Button.new()
	_begin_button.text = "BEGIN"
	_begin_button.custom_minimum_size = Vector2(0, 96)
	_begin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_begin_button.add_theme_font_size_override("font_size", 39)  # 28 * 1.4 — 40% larger (Tim)
	_begin_button.add_theme_font_override("font", UiPalette.make_bold_font())
	_begin_button.visible = false
	UiPalette.style_button(_begin_button, true)
	_begin_button.pressed.connect(_on_spend_pressed)  # same effect: hide the overlay, reveal the game
	column.add_child(_begin_button)


## Build the returning-player stat content: the WELCOME BACK headline and the pile/away stat
## lines. Kept as one group so show_welcome can hide it wholesale.
func _build_pile_content() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)

	var headline := Label.new()
	headline.text = "WELCOME BACK!"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.NAVY)
	headline.add_theme_font_size_override("font_size", 48)
	content.add_child(headline)

	_pile_label = Label.new()
	_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_pile_label.add_theme_font_size_override("font_size", 64)
	content.add_child(_pile_label)

	# A permanent one-line explainer for what the pile IS — the offline-earnings teaching lives
	# here, on the screen, rather than as a one-time card (a fresh launch has no "out", and this is
	# the natural place to explain the green number). Autowrap needs a fixed width or the Label
	# demands its full unwrapped width as a minimum and widens the whole column.
	var explainer := Label.new()
	explainer.text = "Your staffed businesses earned this while you were away."
	explainer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explainer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explainer.custom_minimum_size.x = CONTENT_COLUMN_WIDTH
	explainer.add_theme_color_override("font_color", UiPalette.NAVY)
	explainer.add_theme_font_size_override("font_size", 28)
	content.add_child(explainer)

	_away_label = Label.new()
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_away_label.add_theme_font_size_override("font_size", 26)
	content.add_child(_away_label)

	return content


## Place the three bands at their specified screen fractions (see the class header). Sizes come
## from live minimum sizes, so a mode switch (different buttons showing) just needs a re-call.
func _relayout() -> void:
	if _logo == null or _button_strip == null:
		return
	var screen := size

	# Logo band: full width; the canvas height is its natural aspect height, capped. With
	# KEEP_ASPECT_CENTERED the drawn texture fills the rect's height either way, so the art's
	# center sits at rect_top + rect_height × art_center_fraction — solve rect_top from that.
	var texture_size := Vector2(LOGO_TEXTURE.get_size())
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var natural_height := screen.x * texture_size.y / texture_size.x
		var rect_height := minf(natural_height, screen.y * LOGO_MAX_HEIGHT_FRACTION)
		var art_center_y := screen.y * LOGO_CENTER_FRACTION
		_logo.position = Vector2(0.0, art_center_y - rect_height * _logo_art_center_fraction)
		_logo.size = Vector2(screen.x, rect_height)

	# Button band: centered at the specified fraction up from the bottom edge.
	var strip_height := _button_strip.get_combined_minimum_size().y
	var strip_top := screen.y * (1.0 - BUTTONS_CENTER_FRACTION) - strip_height / 2.0
	_button_strip.position = Vector2(0.0, strip_top)
	_button_strip.size = Vector2(screen.x, strip_height)

	# Stat band: bottom-anchored just above the button band (Tim 2026-07-15: the stats belong
	# with the buttons, not up by the logo).
	var stats_height := _stats_strip.get_combined_minimum_size().y
	_stats_strip.position = Vector2(0.0, strip_top - STATS_ABOVE_BUTTONS_GAP - stats_height)
	_stats_strip.size = Vector2(screen.x, stats_height)


## Show the overlay for a banked pile. `allow_risk` reveals the RISK IT button — true on the
## initial welcome (when transition minigames are on), false on the post-minigame result.
func show_pile(pile: float, hours_away: float, allow_risk: bool = false) -> void:
	_pile_label.text = Money.of(pile).display()
	# Money.trim drops a whole number's ".0" — "away 2 hours", not "away 2.0 hours".
	_away_label.text = "You were away %s hours." % Money.trim(hours_away, 1)
	_risk_button.visible = allow_risk
	_pile_content.visible = true
	_choice_row.visible = true
	_begin_button.visible = false
	visible = true
	# Deferred so the bands' heights reflect the widgets just shown before they are placed.
	_relayout.call_deferred()


## Show the plain launch screen (no offline income to report): the logo over a single BEGIN button.
## Same band layout as the pile screen, minus the stats and choices (Tim, 2026-07-09).
func show_welcome() -> void:
	_pile_content.visible = false
	_choice_row.visible = false
	_begin_button.visible = true
	visible = true
	_relayout.call_deferred()


func _on_spend_pressed() -> void:
	visible = false
	dismissed.emit()


func _on_risk_pressed() -> void:
	visible = false
	risk_pressed.emit()
