class_name LegacyScreen
extends ColorRect

# "The Estate Office" — the Legacy upgrade shop (GDD §13 / the M2 prestige
# reward). Opened from the Main screen by a button that only appears once the
# player has prestiged at least once. Here the player spends banked Legacy on the
# permanent, dynasty-wide upgrades defined in LegacyUpgradeCatalog.
#
# This is a FULL-SCREEN page: an opaque cream sheet that fills the whole screen
# while open (Main freezes the economy behind it), with large legible type (Tim
# reads large — UI notes §1). It reads and writes the live LegacyUpgrades state
# directly; Main is told when a purchase happens so it can re-apply the new effect
# to the living generation, and again when the player closes the shop.
#
# Drive it from Main.gd:
#   1. setup(upgrades)        once, after the state exists (builds the cards)
#   2. open()                 to show it (refreshes every card first)
#   3. listen for purchased   re-apply effects to the living generation
#   4. listen for closed      resume the game


## A purchase just succeeded for this upgrade id. Main re-applies effects + saves.
signal purchased(upgrade_id: String)

## The player asked to retain (buy one more tier of) a property's staffer (GDD §6.3).
## Main spends the Legacy, records it, then re-feeds the entries.
signal retain_requested(property_index: int)

## The player closed the shop and wants to return to the game.
signal closed


# Type sizes — large for at-a-glance phone reading (UI notes §1). Sized big for
# the full-screen page, then trimmed 15% from that pass (Tim's call).
const TITLE_SIZE   := UiPalette.FONT_PAGE_TITLE
const WALLET_SIZE  := UiPalette.FONT_DISPLAY
const CATEGORY_SIZE := UiPalette.FONT_HEADLINE
const CARD_NAME_SIZE := UiPalette.FONT_HEADLINE
const CARD_BODY_SIZE := UiPalette.FONT_CARD_BODY
const BUTTON_SIZE  := UiPalette.FONT_SUBHEAD

## Top inset (in the 1080×1920 design space) that pushes the header row clear of
## the phone's front camera cut-out, so the title and Legacy readout aren't hidden.
const CAMERA_CUTOUT_INSET := 130

## Hold-to-buy pacing (Tim, 2026-06-17): a quick tap buys one level; holding a buy
## button keeps buying at a calm cadence so the player can watch the wallet/effect and
## release when they want to stop. The initial delay keeps a tap from auto-repeating.
const HOLD_INITIAL_DELAY := 0.45
const HOLD_REPEAT_INTERVAL := 0.35

# The live upgrade/wallet state this shop reads and spends from.
var _upgrades: LegacyUpgrades

# The spendable-Legacy readout at the top of the panel.
var _wallet_label: Label

# Per-upgrade live controls, keyed by upgrade id, so refresh() can update each
# card in place after a purchase without rebuilding the whole panel.
var _cards: Dictionary = {}

# Host for the dynamic "Household Staff" retention rows. Unlike the upgrade cards, these
# depend on the living generation's current staff, so they are rebuilt each open from a
# snapshot Main passes to set_retention_entries (rather than built once here).
var _staff_list: VBoxContainer

# Hold-to-buy state: which upgrade's buy button is currently held (""=none), and the
# timer toward the next auto-repeat purchase. See _process and _on_buy_down/up.
var _held_buy_id := ""
var _hold_elapsed := 0.0
var _hold_repeating := false


## Store the state and build the (static) card layout once.
func setup(upgrades: LegacyUpgrades) -> void:
	_upgrades = upgrades
	_build_ui()


func _ready() -> void:
	# Opaque cream sheet filling the whole screen — this is a full page, not a
	# translucent card over the game. Main freezes the economy while it is visible.
	color = UiPalette.CREAM
	visible = false


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Fill the screen edge to edge with a margin, then stack the page contents
	# top-to-bottom. The scrolling card list (added below) takes all the leftover
	# height, so the page fits any phone without a fixed panel size.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	# Extra top inset clears the phone's camera cut-out (see CAMERA_CUTOUT_INSET).
	margin.add_theme_constant_override("margin_top", CAMERA_CUTOUT_INSET)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# ── Header row: "Estate Planning" pinned left, Legacy readout pinned right ──
	var header_row := HBoxContainer.new()
	column.add_child(header_row)

	var title := Label.new()
	title.text = "Estate Planning"
	# Expand fill pushes the title to the left edge and the wallet to the right.
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	header_row.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	# Faux-bold via a same-color outline, matching the project's plate aesthetic.
	_wallet_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_wallet_label.add_theme_constant_override("outline_size", 4)
	_wallet_label.add_theme_font_size_override("font_size", WALLET_SIZE)
	header_row.add_child(_wallet_label)

	# ── Scrollable list of upgrade cards (grouped by category) ──
	# Takes all the leftover height between the wallet readout and the close
	# button, and scrolls within it however many upgrades the catalog holds.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	# ── Household Staff (GDD §6.3): per-property staffer retention across prestige ──
	# The rows are dynamic (they depend on the living generation's current staff), so
	# here we lay out only the heading + host; set_retention_entries fills the host.
	_add_category_heading(list, "Household Staff")
	var staff_hint := Label.new()
	staff_hint.text = "Keep a staffer's tier when you pass on (staff reset otherwise)."
	staff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_hint.add_theme_color_override("font_color", UiPalette.NAVY)
	staff_hint.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	list.add_child(staff_hint)

	_staff_list = VBoxContainer.new()
	_staff_list.add_theme_constant_override("separation", 10)
	_staff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_staff_list)

	# Let a swipe that lands on a card surface (not its BUY button) scroll the
	# list, the same as the property ladder. See UiPalette.allow_scroll_drag_through.
	UiPalette.allow_scroll_drag_through(list)

	# ── Close button ──
	var close_button := Button.new()
	close_button.text = "BACK TO THE EMPIRE"
	close_button.custom_minimum_size = Vector2(0, 158)
	close_button.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
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
	buy_button.custom_minimum_size = Vector2(440, 123)
	buy_button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(buy_button, true)  # red: this is a spend action
	# Press buys one level immediately; holding then auto-repeats slowly until release
	# (see _process). bind(id) passes which upgrade this button buys.
	buy_button.button_down.connect(_on_buy_down.bind(id))
	buy_button.button_up.connect(_on_buy_up)
	bottom_row.add_child(buy_button)

	_cards[id] = {
		"level_label": level_label,
		"effect_label": effect_label,
		"buy_button": buy_button,
	}


# ---------------------------------------------------------------------------
# Household Staff retention rows (dynamic)
# ---------------------------------------------------------------------------

## Rebuild the Household Staff rows from Main's snapshot of the living generation's
## staff vs. the dynasty's retained tiers. Each entry is a Dictionary:
##   { index, property_name, staffer_name, current_tier, retained_tier, cost, can_afford }
## cost < 0 means there is nothing to buy (unstaffed, or already fully retained).
func set_retention_entries(entries: Array) -> void:
	for child in _staff_list.get_children():
		child.queue_free()

	if entries.is_empty():
		var none := Label.new()
		none.text = "No staff to retain yet — hire and upgrade staffers first."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", UiPalette.NAVY)
		none.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
		_staff_list.add_child(none)
		return

	for entry in entries:
		_add_retention_row(entry as Dictionary)
	# Newly-created rows need the scroll-drag-through filter applied too (the one-time
	# call in _build_ui only covered the static controls).
	UiPalette.allow_scroll_drag_through(_staff_list)


## One Household Staff card: property + current staffer on top, the now/retained tiers
## and a RETAIN button (or "RETAINED" when fully retained / unstaffed) beneath.
func _add_retention_row(entry: Dictionary) -> void:
	var index := int(entry["index"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	_staff_list.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var name_label := Label.new()
	name_label.text = "%s — %s" % [String(entry["property_name"]), String(entry["staffer_name"])]
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.add_theme_font_size_override("font_size", CARD_NAME_SIZE)
	col.add_child(name_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)

	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text = "Now tier %d  ·  Retained tier %d" % [
		int(entry["current_tier"]), int(entry["retained_tier"])
	]
	status.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	status.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	bottom.add_child(status)

	var button := Button.new()
	button.custom_minimum_size = Vector2(440, 123)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(button, true)  # red: spends Legacy
	var cost := int(entry["cost"])
	if cost < 0:
		# Nothing to buy: either unstaffed, or already retained at the live tier.
		button.text = "RETAINED"
		button.disabled = true
	else:
		button.text = "RETAIN TIER %d\n%d Legacy" % [int(entry["retained_tier"]) + 1, cost]
		button.disabled = not bool(entry["can_afford"])
		button.pressed.connect(func() -> void: retain_requested.emit(index))
	bottom.add_child(button)


# ---------------------------------------------------------------------------
# Showing / refreshing
# ---------------------------------------------------------------------------

## Show the shop, refreshing every card against the current wallet first.
func open() -> void:
	refresh()
	visible = true


## Re-read the live state and update the wallet readout and every card.
func refresh() -> void:
	# Short label so it fits beside the large title on the header row.
	_wallet_label.text = "Legacy: %d" % _upgrades.available

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

## Press: buy one level now, and arm the hold so continuing to hold auto-repeats.
func _on_buy_down(id: String) -> void:
	_held_buy_id = id
	_hold_elapsed = 0.0
	_hold_repeating = false
	_attempt_buy(id)


## Release: stop any auto-repeat.
func _on_buy_up() -> void:
	_held_buy_id = ""


## While a buy button is held, keep purchasing on a calm cadence (after an initial delay)
## until the player releases or the upgrade can no longer be bought (maxed / unaffordable).
func _process(delta: float) -> void:
	if _held_buy_id == "":
		return
	_hold_elapsed += delta
	var threshold := HOLD_REPEAT_INTERVAL if _hold_repeating else HOLD_INITIAL_DELAY
	if _hold_elapsed >= threshold:
		_hold_elapsed = 0.0
		_hold_repeating = true
		if not _attempt_buy(_held_buy_id):
			_held_buy_id = ""  # nothing left to buy — stop repeating


## Buy one level of an upgrade, refresh the shop, and notify Main. Returns whether the
## purchase actually went through (false when maxed or unaffordable).
func _attempt_buy(id: String) -> bool:
	if not _upgrades.buy(id):
		return false
	refresh()           # update the wallet and this card immediately
	purchased.emit(id)  # let Main re-apply the effect to the living generation
	return true


func _on_close_pressed() -> void:
	_held_buy_id = ""
	visible = false
	closed.emit()
