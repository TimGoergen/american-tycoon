class_name LegacyScreen
extends Control

# "The Estate Office" — the Legacy upgrade shop (GDD §13 / the M2 prestige reward).
# Here the player spends banked Legacy on the permanent, dynasty-wide upgrades defined in
# LegacyUpgradeCatalog, plus per-staffer retention (GDD §6.3).
#
# This is the LOWER part of the Estate Planning tab (UI Notes §7) — embedded content, not
# a modal. There is no scrim or close button; switching away is just switching tabs, and
# the economy keeps ticking (Legacy is a prestige currency, unaffected by the per-second
# tick). It reads/writes the live LegacyUpgrades state directly; Main is told when a
# purchase happens so it can re-apply the new effect to the living generation.
#
# Drive it from Main.gd:
#   1. setup(upgrades)            once, after the state exists (builds the cards)
#   2. refresh() + set_retention_entries(...)   on entering the Estate tab
#   3. listen for purchased / retain_requested  re-apply effects / spend Legacy


## A purchase just succeeded for this upgrade id. Main re-applies effects + saves.
signal purchased(upgrade_id: String)

## The player asked to retain (buy one more tier of) a property's staffer (GDD §6.3).
## Main spends the Legacy, records it, then re-feeds the entries.
signal retain_requested(property_index: int)


# Type sizes — large for at-a-glance phone reading (UI notes §1). The title/wallet are a
# notch smaller than the old full-screen sizes so the stacked header fits the tab width.
# The wallet balance amount is 25% larger than the rest of the header (Tim, 2026-06-28).
const WALLET_SIZE  := UiPalette.FONT_SUBHEAD
const WALLET_AMOUNT_SIZE := int(round(UiPalette.FONT_SUBHEAD * 1.25))
const CATEGORY_SIZE := int(round(UiPalette.FONT_HEADLINE * 0.85))  # 15% smaller (Tim, 2026-06-28)
const CARD_NAME_SIZE := UiPalette.FONT_HEADLINE
const CARD_BODY_SIZE := UiPalette.FONT_CARD_BODY
const BUTTON_SIZE  := UiPalette.FONT_SUBHEAD

## The legacy-gem currency icon (the new estate currency art) — shown in place of the word
## "Legacy" beside the balance and on each upgrade's buy button (Tim, 2026-06-28).
const GEM_TEX := preload("res://art/icons/legacy_gem.svg")
## The gem balance icon's size, ~25% larger than its baseline to match the enlarged amount.
const WALLET_GEM_SIZE := Vector2(46, 64)
## The smaller gem shown on each upgrade's buy button (in place of the word "BUY"). Sized to fit
## the shorter buy button.
const BUY_GEM_WIDTH := 38

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

# Each estate-planning category is a collapsible, color-themed section (Tim, 2026-06-24).
# Keyed by category name → { "button": Button header, "body": VBoxContainer, "expanded": bool }.
# All sections start collapsed; the header-row Collapse-All / Expand-All buttons drive them all.
var _sections: Dictionary = {}

# The Household Staff section's accent color, remembered so the retention rows rebuilt later by
# set_retention_entries carry the same themed border as the cards built up-front.
var _staff_accent: Color = UiPalette.MONEY_GREEN

# Hold-to-buy state: which upgrade's buy button is currently held (""=none), and the
# timer toward the next auto-repeat purchase. See _process and _on_buy_down/up.
var _held_buy_id := ""
var _hold_elapsed := 0.0
var _hold_repeating := false


## Store the state and build the (static) card layout once.
func setup(upgrades: LegacyUpgrades) -> void:
	_upgrades = upgrades
	_build_ui()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fill the tab area with a small margin, then stack the contents top-to-bottom. The
	# scrolling card list takes all the leftover height. No camera-cutout inset here —
	# the pinned hero stat above the tabs already clears it.
	# No outer margin here: the screen-wide universal content margin (Main) already insets the
	# whole Estate tab off the border, so adding more would doubly inset this one screen.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# ── Title: the centered "ESTATE PLANNING" heading, in the shared tab-title style (matches the
	# Settings and Family Ledger tabs). The Collapse-All / Expand-All controls moved down onto the
	# Legacy-wallet row below (Tim, 2026-06-28). ──
	column.add_child(UiPalette.make_tab_title("ESTATE PLANNING"))

	# ── Wallet row: the legacy-gem icon + balance on the left (the gem icon replaces the word
	# "Legacy", Tim 2026-06-28), and the Collapse-All / Expand-All arrow buttons right-aligned. ──
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 10)
	column.add_child(wallet_row)

	# The gem icon stands in for the word "Legacy" in front of the balance.
	var wallet_gem := TextureRect.new()
	wallet_gem.texture = GEM_TEX
	wallet_gem.custom_minimum_size = WALLET_GEM_SIZE
	wallet_gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallet_gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Mipmapped filtering so the detailed gem downscales smoothly instead of aliasing ("blocky").
	wallet_gem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wallet_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_row.add_child(wallet_gem)

	_wallet_label = Label.new()
	# Expand so the amount takes the slack and pushes the two icon buttons to the right edge.
	_wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # center against the taller buttons
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	# Faux-bold via a same-color outline, matching the project's plate aesthetic.
	_wallet_label.add_theme_color_override("font_outline_color", UiPalette.DARK_GOLD)
	_wallet_label.add_theme_constant_override("outline_size", 4)
	_wallet_label.add_theme_font_size_override("font_size", WALLET_AMOUNT_SIZE)
	wallet_row.add_child(_wallet_label)

	# Up arrow = collapse all (the list folds up); down arrow = expand all (it opens down) — the
	# intuitive convention (Tim, 2026-06-28). Icon-only, so they stay narrow and right-aligned via
	# the expanding wallet label beside them.
	var collapse_all_button := _make_bulk_button("res://art/icons/arrow_up.svg")
	collapse_all_button.pressed.connect(set_all_collapsed.bind(true))
	wallet_row.add_child(collapse_all_button)

	var expand_all_button := _make_bulk_button("res://art/icons/arrow_down.svg")
	expand_all_button.pressed.connect(set_all_collapsed.bind(false))
	wallet_row.add_child(expand_all_button)

	# ── Scrollable list of upgrade cards (grouped by category) ──
	# Takes all the leftover height between the wallet readout and the close
	# button, and scrolls within it however many upgrades the catalog holds.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# AUTO (not RESERVE): the scrollbar overlays the right inset rather than reserving a
	# one-sided gutter that pushed cards off the right edge. The MarginContainer below then
	# gives every card outline the SAME margin on the left and right.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)

	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(list_margin)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_child(list)

	# Group the upgrades by category, preserving each category's first-appearance order, so every
	# category becomes ONE collapsible section even though the catalog interleaves them (e.g.
	# Operations reappears after Labor). Each section is themed with the category's accent color.
	# As we group, also collect each category's upgrade ids in one array. The collapsed-section
	# header badge (the "+x affordable" count) needs that id list to ask the live state how many
	# of the category's upgrades the player can buy right now.
	var ordered_categories: Array = []
	var by_category: Dictionary = {}
	var ids_by_category: Dictionary = {}
	for definition in LegacyUpgradeCatalog.all():
		var category := String(definition["category"])
		if not by_category.has(category):
			by_category[category] = []
			ids_by_category[category] = []
			ordered_categories.append(category)
		(by_category[category] as Array).append(definition)
		(ids_by_category[category] as Array).append(String(definition["id"]))

	for category in ordered_categories:
		var category_name := String(category)
		var accent := _category_color(category_name)
		var body := _add_collapsible_section(list, category_name, accent, ids_by_category[category])
		for definition in by_category[category]:
			_add_upgrade_card(body, definition as Dictionary, accent)

	# ── Household Staff (GDD §6.3): per-property staffer retention across prestige ──
	# Its own themed, collapsible section. The rows are dynamic (they depend on the living
	# generation's current staff), so here we lay out only the hint + host; set_retention_entries
	# fills the host later, tinting each row with this section's accent (_staff_accent).
	# Household Staff has no catalog upgrade ids (its rows are dynamic retention rows, not
	# catalog upgrades), so it gets an empty id list and therefore never shows an affordable badge.
	_staff_accent = _category_color("Household Staff")
	var staff_body := _add_collapsible_section(list, "Household Staff", _staff_accent, [])
	var staff_hint := Label.new()
	staff_hint.text = "Keep a staffer's tier when you pass on (staff reset otherwise)."
	staff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_hint.add_theme_color_override("font_color", UiPalette.NAVY)
	staff_hint.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	staff_body.add_child(staff_hint)

	_staff_list = VBoxContainer.new()
	_staff_list.add_theme_constant_override("separation", 10)
	_staff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_body.add_child(_staff_list)

	# Let a swipe that lands on a card surface (not its BUY button) scroll the
	# list, the same as the property ladder. See UiPalette.allow_scroll_drag_through.
	UiPalette.allow_scroll_drag_through(list)


## The unique accent color for each estate-planning category (Tim, 2026-06-24). All are drawn
## from the §1 palette so the screen stays inside the house style; one per category so the
## sections read as distinct at a glance.
func _category_color(category: String) -> Color:
	match category:
		"Wealth":
			return UiPalette.MUSTARD_GOLD
		"Operations":
			return UiPalette.CYCLE_BLUE
		"Career":
			return UiPalette.ATOMIC_TEAL
		"Legacy":
			return UiPalette.KETCHUP_RED
		"Labor":
			return UiPalette.BRICK
		"Household Staff":
			return UiPalette.MONEY_GREEN
	return UiPalette.NAVY


## Build one collapsible, color-themed category section into `parent`: a full-width header
## button (filled with the category's accent color) that toggles a body container holding the
## cards. Every section starts COLLAPSED (Tim, 2026-06-24). Returns the body for the caller to
## fill with cards. `upgrade_ids` is this category's catalog upgrade ids (empty for Household
## Staff), used to count how many are currently affordable for the collapsed-section badge.
func _add_collapsible_section(parent: VBoxContainer, category: String, accent: Color, upgrade_ids: Array) -> VBoxContainer:
	var header := Button.new()
	header.custom_minimum_size = Vector2(0, 62)  # ~35% shorter (Tim, 2026-06-28)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", CATEGORY_SIZE)
	# Caret + name read from the left like a typical section/disclosure header.
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var text_color := _readable_on(accent)
	header.add_theme_stylebox_override("normal", _make_section_plate(accent))
	header.add_theme_stylebox_override("hover", _make_section_plate(accent))
	header.add_theme_stylebox_override("pressed", _make_section_plate(accent.darkened(0.15)))
	header.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		header.add_theme_color_override(state, text_color)
	header.pressed.connect(_toggle_section.bind(category))
	parent.add_child(header)

	# Right-aligned "+x affordable" badge (Tim, 2026-06-24). When the section is COLLAPSED, this
	# tells the player at a glance how many of the category's upgrades they can buy right now (x
	# may be 0 — meaning there are upgrades left, but none affordable). It is hidden while the
	# section is expanded (the buy buttons are visible then) and hidden entirely once every
	# upgrade in the category is maxed. A child of the header Button, ignoring mouse input so a
	# tap anywhere still toggles the section. _update_section_count fills in the text.
	var count_label := Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin to the header's right edge, vertically centered, with a small inset off the border.
	count_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	count_label.offset_left = -160
	count_label.offset_right = -16
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", text_color)
	count_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	header.add_child(count_label)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.visible = false   # collapsed by default
	parent.add_child(body)

	_sections[category] = {
		"button": header,
		"body": body,
		"expanded": false,
		"upgrade_ids": upgrade_ids,
		"count_label": count_label,
	}
	_update_section_header(category)
	_update_section_count(category)
	return body


## Pick a label color that reads on `color`: navy on light accents, cream on dark ones.
func _readable_on(color: Color) -> Color:
	return UiPalette.NAVY if color.get_luminance() > 0.5 else UiPalette.CREAM


## A colored plate (category accent fill, navy border) for a section header button.
func _make_section_plate(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UiPalette.NAVY
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)  # tighter so the name fits the shorter header (Tim, 2026-06-28)
	return style


## A card plate themed to its category: cream fill with the accent color as a slightly heavier
## border, so each card visibly belongs to its (color-coded) section.
func _make_accent_card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CREAM
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	return style


## A compact icon utility button (Collapse All / Expand All — an arrow glyph), styled as a
## standard (non-spend) button so it never reads as a buy action. Icon-only, so it stays narrow
## (Tim, 2026-06-28); expand_icon scales the arrow to fill the button square.
func _make_bulk_button(icon_path: String) -> Button:
	var button := Button.new()
	button.icon = load(icon_path)
	button.expand_icon = true
	# Center the arrow both ways in the button (default icon alignment is left/center).
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(84, 47)  # ~35% shorter (Tim, 2026-06-28)
	button.add_theme_constant_override("icon_max_width", 48)
	UiPalette.style_button(button, false)
	return button


## Flip one category section between expanded and collapsed (its header was tapped).
func _toggle_section(category: String) -> void:
	var section: Dictionary = _sections[category]
	section["expanded"] = not bool(section["expanded"])
	(section["body"] as Control).visible = bool(section["expanded"])
	_update_section_header(category)
	_update_section_count(category)


## Expand or collapse every category at once (the header-row Collapse-All / Expand-All).
func set_all_collapsed(collapsed: bool) -> void:
	for category in _sections:
		var section: Dictionary = _sections[category]
		section["expanded"] = not collapsed
		(section["body"] as Control).visible = not collapsed
		_update_section_header(String(category))
		_update_section_count(String(category))


## Refresh a section header's caret + name to match its expanded state. "+" invites a tap to
## open a collapsed section; "-" shows it is already open.
func _update_section_header(category: String) -> void:
	var section: Dictionary = _sections[category]
	var marker := "-" if bool(section["expanded"]) else "+"
	(section["button"] as Button).text = "%s  %s" % [marker, category.to_upper()]


## Refresh a collapsed section header's right-aligned "+x affordable" badge (Tim, 2026-06-24).
## Rules:
##   • Hidden entirely (empty text) when EVERY upgrade in the category is maxed — there is nothing
##     left to consider, so no badge.
##   • Hidden while the section is EXPANDED — the buy buttons themselves are visible then.
##   • Otherwise (collapsed, with at least one non-maxed upgrade) shows "+x", where x is how many
##     of the category's upgrades are affordable AND not maxed right now. x may be 0 ("+0"): there
##     are upgrades to buy, just none the player can afford yet.
## Household Staff (and any category with no catalog ids) never shows a badge.
func _update_section_count(category: String) -> void:
	var section: Dictionary = _sections[category]
	var label := section["count_label"] as Label

	# May run during _build_ui before setup() supplies the live state; nothing to count yet.
	if _upgrades == null:
		label.text = ""
		return

	var upgrade_ids: Array = section["upgrade_ids"]
	var non_maxed_count := 0
	var affordable_count := 0
	for id in upgrade_ids:
		var upgrade_id := String(id)
		if _upgrades.is_maxed(upgrade_id):
			continue
		non_maxed_count += 1
		if _upgrades.can_buy(upgrade_id):
			affordable_count += 1

	if non_maxed_count == 0 or bool(section["expanded"]):
		label.text = ""
	else:
		label.text = "+%d" % affordable_count


## One upgrade card: name + level on top, description, then effect + a BUY button
## that shows the next level's cost. The live labels/button are stored in _cards
## so refresh() can update them after a purchase.
func _add_upgrade_card(parent: VBoxContainer, definition: Dictionary, accent: Color) -> void:
	var id := String(definition["id"])

	var card := PanelContainer.new()
	# Cream card with its category's accent as the border, so it reads as part of that section.
	card.add_theme_stylebox_override("panel", _make_accent_card_style(accent))
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
	# Wrap so a long upgrade name can't set a minimum width wider than the card — which the
	# (horizontally non-scrolling) ScrollContainer would otherwise demand, pushing the whole
	# shop off the right edge (Tim, 2026-06-22).
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# Wrap so a long effect string (e.g. "×2.96 auto-tap / auto-rush speed") can't force
	# the card's minimum width past the tab and push the panel off the right edge.
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	effect_label.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	bottom_row.add_child(effect_label)

	var buy_button := Button.new()
	# A flexible width (was a fixed 440, wide enough to overflow the framed viewport): the
	# button hugs its own cost text while the effect label beside it takes the slack.
	buy_button.custom_minimum_size = Vector2(240, 80)  # ~35% shorter (Tim, 2026-06-28)
	buy_button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	# The legacy-gem icon (set in refresh) replaces the word "BUY"; cap its width so the tall gem
	# art sizes down to a button glyph beside the cost. Mipmapped filtering keeps it from aliasing.
	buy_button.add_theme_constant_override("icon_max_width", BUY_GEM_WIDTH)
	buy_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	# Match the Household Staff section's accent border, like the upgrade cards above.
	card.add_theme_stylebox_override("panel", _make_accent_card_style(_staff_accent))
	_staff_list.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var name_label := Label.new()
	name_label.text = "%s — %s" % [String(entry["property_name"]), String(entry["staffer_name"])]
	# Wrap so a long property+staffer name can't force the card wider than the viewport.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.add_theme_font_size_override("font_size", CARD_NAME_SIZE)
	col.add_child(name_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)

	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Now tier %d  ·  Retained tier %d" % [
		int(entry["current_tier"]), int(entry["retained_tier"])
	]
	status.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	status.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	bottom.add_child(status)

	var button := Button.new()
	# Flexible width (was a fixed 440 that overflowed the framed viewport), matching the
	# upgrade cards' RETAIN/BUY buttons. ~35% shorter (Tim, 2026-06-28); a smaller font so the
	# two-line "RETAIN TIER n / n Gems" still fits the shorter button.
	button.custom_minimum_size = Vector2(240, 80)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	UiPalette.style_button(button, true)  # red: spends Legacy
	var cost := int(entry["cost"])
	if cost < 0:
		# Nothing to buy: either unstaffed, or already retained at the live tier.
		button.text = "RETAINED"
		button.disabled = true
	else:
		button.text = "RETAIN TIER %d\n%d Gems" % [int(entry["retained_tier"]) + 1, cost]
		button.disabled = not bool(entry["can_afford"])
		button.pressed.connect(func() -> void: retain_requested.emit(index))
	bottom.add_child(button)


# ---------------------------------------------------------------------------
# Showing / refreshing
# ---------------------------------------------------------------------------

## Re-read the live state and update the wallet readout and every card.
func refresh() -> void:
	# Just the number — the gem icon beside it stands in for the word "Legacy" (Tim, 2026-06-28).
	_wallet_label.text = "%d" % _upgrades.available

	for definition in LegacyUpgradeCatalog.all():
		var id := String(definition["id"])
		var controls: Dictionary = _cards[id]
		var level := _upgrades.get_level(id)
		var max_level := int(definition["max_level"])

		(controls["level_label"] as Label).text = "Level %d / %d" % [level, max_level]
		(controls["effect_label"] as Label).text = LegacyUpgradeCatalog.describe_effect(id, level)

		var buy_button := controls["buy_button"] as Button
		if _upgrades.is_maxed(id):
			buy_button.icon = null
			buy_button.text = "MAXED"
			buy_button.disabled = true
		else:
			var cost := _upgrades.get_next_cost(id)
			# The legacy-gem icon replaces the word "BUY"; the cost follows it (Tim, 2026-06-28).
			buy_button.icon = GEM_TEX
			buy_button.text = "  %d" % cost
			# Greyed out (but still readable) when the player can't afford it.
			buy_button.disabled = not _upgrades.can_buy(id)

	# Update every collapsed section's "+x affordable" badge to match the new wallet/levels.
	for category in _sections:
		_update_section_count(String(category))


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
