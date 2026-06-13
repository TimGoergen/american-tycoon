class_name LegacyScreen
extends ColorRect

# "The Estate Office" — the Legacy upgrade shop (GDD §13 / the M2 prestige
# reward). Opened from the Main screen by a button that only appears once the
# player has prestiged at least once. Here the player spends banked Legacy on the
# permanent, dynasty-wide upgrades defined in LegacyUpgradeCatalog.
#
# This is a self-contained overlay, the same shape as WillScreen: a dark scrim
# over the game, a centered cream panel, large legible type (Tim reads large —
# UI notes §1). It reads and writes the live LegacyUpgrades state directly; Main
# is told when a purchase happens so it can re-apply the new effect to the living
# generation, and again when the player closes the shop.
#
# Drive it from Main.gd:
#   1. setup(upgrades)        once, after the state exists (builds the cards)
#   2. open()                 to show it (refreshes every card first)
#   3. listen for purchased   re-apply effects to the living generation
#   4. listen for closed      resume the game


## A purchase just succeeded for this upgrade id. Main re-applies effects + saves.
signal purchased(upgrade_id: String)

## The player closed the shop and wants to return to the game.
signal closed


# Type sizes — large for at-a-glance phone reading (UI notes §1).
const TITLE_SIZE   := 40
const WALLET_SIZE  := 30
const CATEGORY_SIZE := 24
const CARD_NAME_SIZE := 26
const CARD_BODY_SIZE := 20
const BUTTON_SIZE  := 22

# The live upgrade/wallet state this shop reads and spends from.
var _upgrades: LegacyUpgrades

# The spendable-Legacy readout at the top of the panel.
var _wallet_label: Label

# Per-upgrade live controls, keyed by upgrade id, so refresh() can update each
# card in place after a purchase without rebuilding the whole panel.
var _cards: Dictionary = {}


## Store the state and build the (static) card layout once.
func setup(upgrades: LegacyUpgrades) -> void:
	_upgrades = upgrades
	_build_ui()


func _ready() -> void:
	# Dark scrim over the game beneath the shop.
	color = Color(UiPalette.INK_NAVY, 0.75)
	visible = false


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(660, 0)
	panel.add_child(column)

	# ── Title + wallet ──
	var title := Label.new()
	title.text = "THE ESTATE OFFICE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	# Faux-bold via a same-color outline, matching the project's plate aesthetic.
	_wallet_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_wallet_label.add_theme_constant_override("outline_size", 2)
	_wallet_label.add_theme_font_size_override("font_size", WALLET_SIZE)
	column.add_child(_wallet_label)

	# ── Scrollable list of upgrade cards (grouped by category) ──
	# Scrolls so the panel never grows taller than the phone screen, however many
	# upgrades the catalog grows to hold.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var current_category := ""
	for definition in LegacyUpgradeCatalog.all():
		var category := String(definition["category"])
		if category != current_category:
			_add_category_heading(list, category)
			current_category = category
		_add_upgrade_card(list, definition)

	# ── Close button ──
	var close_button := Button.new()
	close_button.text = "BACK TO THE EMPIRE"
	close_button.custom_minimum_size = Vector2(0, 72)
	close_button.add_theme_font_size_override("font_size", 26)
	UiPalette.style_button(close_button, false)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)


## A section heading between groups of cards ("Wealth", "Operations", …).
func _add_category_heading(parent: VBoxContainer, category: String) -> void:
	var heading := Label.new()
	heading.text = category.to_upper()
	heading.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	heading.add_theme_font_size_override("font_size", CATEGORY_SIZE)
	parent.add_child(heading)


## One upgrade card: name + level on top, description, then effect + a BUY button
## that shows the next level's cost. The live labels/button are stored in _cards
## so refresh() can update them after a purchase.
func _add_upgrade_card(parent: VBoxContainer, definition: Dictionary) -> void:
	var id := String(definition["id"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	parent.add_child(card)

	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 6)
	card.add_child(card_column)

	# Top row: name (left) | level x/max (right).
	var top_row := HBoxContainer.new()
	card_column.add_child(top_row)

	var name_label := Label.new()
	name_label.text = String(definition["name"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.add_theme_font_size_override("font_size", CARD_NAME_SIZE)
	top_row.add_child(name_label)

	var level_label := Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_color_override("font_color", UiPalette.NAVY)
	level_label.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	top_row.add_child(level_label)

	# Description line.
	var description_label := Label.new()
	description_label.text = String(definition["description"])
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("font_color", UiPalette.NAVY)
	description_label.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	card_column.add_child(description_label)

	# Bottom row: current effect (left) | BUY button with cost (right).
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	card_column.add_child(bottom_row)

	var effect_label := Label.new()
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	effect_label.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	bottom_row.add_child(effect_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(200, 56)
	buy_button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(buy_button, true)  # red: this is a spend action
	# bind(id) passes which upgrade this button buys to the shared handler.
	buy_button.pressed.connect(_on_buy_pressed.bind(id))
	bottom_row.add_child(buy_button)

	_cards[id] = {
		"level_label": level_label,
		"effect_label": effect_label,
		"buy_button": buy_button,
	}


# ---------------------------------------------------------------------------
# Showing / refreshing
# ---------------------------------------------------------------------------

## Show the shop, refreshing every card against the current wallet first.
func open() -> void:
	refresh()
	visible = true


## Re-read the live state and update the wallet readout and every card.
func refresh() -> void:
	_wallet_label.text = "Legacy to spend: %d" % _upgrades.available

	for definition in LegacyUpgradeCatalog.all():
		var id := String(definition["id"])
		var controls: Dictionary = _cards[id]
		var level := _upgrades.get_level(id)
		var max_level := int(definition["max_level"])

		(controls["level_label"] as Label).text = "Level %d / %d" % [level, max_level]
		(controls["effect_label"] as Label).text = LegacyUpgradeCatalog.describe_effect(id, level)

		var buy_button := controls["buy_button"] as Button
		if _upgrades.is_maxed(id):
			buy_button.text = "MAXED"
			buy_button.disabled = true
		else:
			var cost := _upgrades.get_next_cost(id)
			buy_button.text = "BUY  %d" % cost
			# Greyed out (but still readable) when the player can't afford it.
			buy_button.disabled = not _upgrades.can_buy(id)


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _on_buy_pressed(id: String) -> void:
	if _upgrades.buy(id):
		refresh()           # update the wallet and this card immediately
		purchased.emit(id)  # let Main re-apply the effect to the living generation


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
