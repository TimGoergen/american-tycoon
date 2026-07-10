class_name WelcomeBackOverlay
extends ColorRect

# The welcome-back / launch screen (GDD §3.1, §7). The game's logo fills the TOP HALF of the
# screen; the bottom half carries the content. Two modes share this layout (Tim, 2026-07-09):
#   * show_pile()   — returning after offline income: the cheerful pile + deadpan stat line, then
#                     PUT IT TO WORK (bank it) or RISK IT (gamble it on a minigame).
#   * show_welcome() — a plain launch with no offline pile: just a BEGIN button under the logo.

signal dismissed
## Player chose to gamble the overnight pile on a minigame instead of banking it as-is.
signal risk_pressed

const LOGO_TEXTURE := preload("res://art/branding/american_tycoon_logo.png")

var _pile_label: Label
var _spend_button: Button
var _risk_button: Button
var _away_label: Label
var _logo: TextureRect
## The pile-mode content (headline + stats + the two choice buttons), shown/hidden as a group.
var _pile_content: VBoxContainer
## The plain-launch button, shown instead of the pile content when there was no offline income.
var _begin_button: Button


func _ready() -> void:
	# Black field framing a cream rounded viewing area — the same full-screen frame the main
	# game and dev panel use (Tim, 2026-06-23), so every full-window screen matches.
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	# The screen is split by a fixed 3:2 weight (independent of which content shows), so the logo and
	# the content both sit at the SAME place on both the pile and the plain-launch screen (Tim,
	# 2026-07-09). The content is pinned to the TOP of its region, so its top edge — "the buttons/text
	# below" — lands at the same y regardless of height, and the logo is centered in the whole gap
	# above it.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	viewing_area.add_child(rows)

	_logo = TextureRect.new()
	_logo.texture = LOGO_TEXTURE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_logo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_logo.size_flags_stretch_ratio = 3.0  # logo gets the top ~60% (centered within it)
	rows.add_child(_logo)

	# The content region: fixed ~40% at the bottom, its content pinned to the TOP and horizontally
	# centered (a fixed y on both screens), so the logo above is centered in the same gap either way.
	var bottom := VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.size_flags_stretch_ratio = 2.0
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN  # content pinned to the TOP of this region
	rows.add_child(bottom)

	var center_row := HBoxContainer.new()
	center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(center_row)
	var pad_left := Control.new()
	pad_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(pad_left)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(760, 0)
	center_row.add_child(column)

	var pad_right := Control.new()
	pad_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(pad_right)

	_pile_content = _build_pile_content()
	column.add_child(_pile_content)

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


## Build the returning-player content: the WELCOME BACK headline, the pile/away stat lines, and the
## PUT IT TO WORK / RISK IT choice row. Kept as one group so show_welcome can hide it wholesale.
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

	_away_label = Label.new()
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_away_label.add_theme_font_size_override("font_size", 26)
	content.add_child(_away_label)

	# Two choices on one row (Tim, 2026-06-24): take the overnight pile as-is, or gamble it on a
	# minigame that can swing the haul anywhere from 50% to 200%. The RISK button only appears
	# when transition minigames are enabled (show_pile's allow_risk) and never on the
	# post-minigame result screen — you get one roll.
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	content.add_child(button_row)

	_spend_button = Button.new()
	_spend_button.text = "PUT IT TO WORK"
	_spend_button.custom_minimum_size = Vector2(0, 96)
	_spend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spend_button.add_theme_font_size_override("font_size", 39)  # 28 * 1.4 — 40% larger (Tim)
	_spend_button.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(_spend_button, true)
	_spend_button.pressed.connect(_on_spend_pressed)
	button_row.add_child(_spend_button)

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
	button_row.add_child(_risk_button)

	return content


## Show the overlay for a banked pile. `allow_risk` reveals the RISK IT button — true on the
## initial welcome (when transition minigames are on), false on the post-minigame result.
func show_pile(pile: float, hours_away: float, allow_risk: bool = false) -> void:
	_pile_label.text = Money.of(pile).display()
	# Money.trim drops a whole number's ".0" — "away 2 hours", not "away 2.0 hours".
	_away_label.text = "You were away %s hours." % Money.trim(hours_away, 1)
	_risk_button.visible = allow_risk
	_pile_content.visible = true
	_begin_button.visible = false
	visible = true


## Show the plain launch screen (no offline income to report): the logo over a single BEGIN button.
## Same layout as the pile screen, minus the stats and choices (Tim, 2026-07-09).
func show_welcome() -> void:
	_pile_content.visible = false
	_begin_button.visible = true
	visible = true


func _on_spend_pressed() -> void:
	visible = false
	dismissed.emit()


func _on_risk_pressed() -> void:
	visible = false
	risk_pressed.emit()
