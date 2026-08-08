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

## Emitted when the player presses a retention row's buy button. `levels` is the count the
## button quoted on its face — Main buys exactly that, never a recomputed number, so a gem
## grant landing between paint and press can never charge more than the label promised.
signal retain_requested(property_index: int, levels: int)


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

## How far a finger must travel before a press on any control in this list counts as a SCROLL and
## not a tap (see the drag-to-scroll section at the bottom of this file). Matches the threshold
## DevTuningPanel and ChallengesScreen use, so every button-tiled list in the game agrees.
const DRAG_SCROLL_THRESHOLD := 12.0

# The live upgrade/wallet state this shop reads and spends from.
var _upgrades: LegacyUpgrades

## The list's ScrollContainer, kept so the drag-to-scroll handler can pan it (see the section at
## the bottom of this file).
var _scroll: ScrollContainer

## Drag-to-scroll bookkeeping for the current press gesture. _drag_accum is this gesture's total
## vertical travel; _drag_moved latches once it passes DRAG_SCROLL_THRESHOLD, and from then on the
## gesture is a scroll: it toggles no section and — critically — spends no gems.
var _drag_accum := 0.0
var _drag_moved := false

## Whether the current hold has already made its purchase. A tap buys on RELEASE (see the drag
## section), so these tell the release handler that the hold pump already did the work.
var _buy_fired_in_hold := false
var _retain_fired_in_hold := false

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

## The category key for the dynamic staff-retention section. It owns no catalog upgrade ids, so its
## affordable badge and invested total are computed from the retention entry snapshots instead of
## the catalog (Tim 2026-07-13).
const HOUSEHOLD_STAFF_CATEGORY := "Household Staff"

## The latest retention entry snapshot Main passed to set_retention_entries — kept so the Household
## Staff header can report its "+x affordable" count and total gems invested, like every other
## category. Each entry carries "best_levels", "retained_levels", "levels", and "gems_spent".
var _retention_entries: Array = []

# Hold-to-buy state: which upgrade's buy button is currently held (""=none), and the
# timer toward the next auto-repeat purchase. See _process and _on_buy_down/up.
var _held_buy_id := ""
var _hold_elapsed := 0.0
var _hold_repeating := false

# Per-property live controls of the Household Staff rows, keyed by property index, so a
# retention purchase can update each row IN PLACE (update_retention_entries). Rebuilding
# the rows on every purchase would free the button under a held finger and break the
# hold-to-retain repeat.
var _retention_rows: Dictionary = {}

# Hold-to-retain state, mirroring the upgrade cards' hold-to-buy (-1 = none held).
var _held_retain_index := -1
var _retain_hold_elapsed := 0.0
var _retain_hold_repeating := false

# The wallet balance this screen last rendered. _process compares it against the live
# wallet so that gems arriving or leaving WHILE the tab is open (a First Contact minigame
# grant, a dev-tool award) re-render affordability everywhere — cards, wallet label,
# retention rows, section badges — the frame the balance moves. Purchases made on this
# screen also move the wallet, so this watcher would re-refresh a frame after them too;
# harmless, refresh() is idempotent. -1 forces the first _process to sync. (Tim
# 2026-07-18: stale snapshots advertised retention buys the wallet could not pay for.)
var _last_rendered_wallet := -1


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
	_scroll = scroll  # kept for the drag-to-scroll handler (see _pan_scroll_on_drag)

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
		"Frenzy":
			return UiPalette.DARK_GOLD
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
	header.gui_input.connect(_on_list_control_gui_input)
	parent.add_child(header)

	# Right-aligned affordability badge (Tim, 2026-06-24; always-visible + MAX, 2026-07-31).
	# Tells the player at a glance how many of the category's upgrades they can buy right now
	# ("+x", x may be 0 — upgrades remain, none affordable), or "MAX" once the category is
	# finished. Shown whether the section is collapsed or expanded, since the header stays in
	# view while scrolling a long category. A child of the header Button, ignoring mouse input
	# so a tap anywhere still toggles the section. _update_section_count fills in the text.
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


## Greys for the MAX badge — deliberately NOT UiPalette.DARK_GRAY/LIGHT_GRAY. Those are the
## unowned-row greys, and several category accents sit near mid-luminance (Operations 0.51,
## Household Staff 0.61), where DARK_GRAY measures 1.16:1 against the plate — invisible. These
## are pushed to the ends of the range so MAX still reads as grey-and-quiet while staying
## legible on every accent, which the large-text/high-contrast rule requires.
const MAX_BADGE_ON_LIGHT := Color("#3E4247")
const MAX_BADGE_ON_DARK := Color("#DCE0E5")


## The MUTED counterpart of _readable_on, for the MAX badge (Tim, 2026-07-31): dark grey on a
## light accent, light grey on a dark one. Quieter than the live "+x" count — a finished
## category should recede rather than compete with the ones still worth spending on.
func _muted_on(color: Color) -> Color:
	return MAX_BADGE_ON_LIGHT if color.get_luminance() > 0.5 else MAX_BADGE_ON_DARK


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
	# A scroll, not a tap: swallow the toggle so swiping the list never flips sections open or shut.
	if _drag_moved:
		return
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
## open a collapsed section; "-" shows it is already open. The name is followed by the total gems
## the player has invested in this category so far, formatted like money (Tim, 2026-07-13) — shown
## only for catalog categories (Household Staff's retention isn't a catalog upgrade, so it has no id
## list and no total).
func _update_section_header(category: String) -> void:
	var section: Dictionary = _sections[category]
	var marker := "-" if bool(section["expanded"]) else "+"
	# The name is followed by the total gems invested in this category, formatted like money (Tim
	# 2026-07-13) — every category, including Household Staff.
	(section["button"] as Button).text = "%s  %s  (%s)" % [
		marker, category.to_upper(), Money.abbrev(_category_gems_invested(category))]


## Total Legacy gems the player has spent in this category. Catalog categories sum each upgrade's
## per-level costs (level 1 up to its current level); Household Staff sums the gems already spent
## retaining each staffer (carried on the retention entry snapshots).
func _category_gems_invested(category: String) -> int:
	if _upgrades == null:
		return 0  # may run during _build_ui before setup() supplies the live state
	if category == HOUSEHOLD_STAFF_CATEGORY:
		var staff_total := 0
		for entry_variant in _retention_entries:
			staff_total += int((entry_variant as Dictionary).get("gems_spent", 0))
		return staff_total
	var total := 0
	for id_variant in _sections[category]["upgrade_ids"]:
		var id := String(id_variant)
		for level in range(1, _upgrades.get_level(id) + 1):
			total += LegacyUpgradeCatalog.cost_for_level(id, level)
	return total


## Refresh the Household Staff header's invested total and its affordable badge from the latest
## retention snapshot. Safe before the section exists (during _build_ui) — it no-ops then.
func _refresh_staff_section_header() -> void:
	if _sections.has(HOUSEHOLD_STAFF_CATEGORY):
		_update_section_header(HOUSEHOLD_STAFF_CATEGORY)
		_update_section_count(HOUSEHOLD_STAFF_CATEGORY)


## Refresh a section header's right-aligned affordability badge (Tim, 2026-06-24; revised
## 2026-07-31). Rules:
##   • "MAX", in the muted grey, once EVERY upgrade in the category is maxed — the category is
##     finished, and saying so is more useful than saying nothing.
##   • Otherwise "+x", where x is how many of the category's upgrades are affordable AND not
##     maxed right now. x may be 0 ("+0"): there are upgrades to buy, just none affordable yet.
##   • Empty only when there is genuinely nothing to report — before the live state arrives, or
##     for a Household Staff section with no staff to retain yet (which is NOT the same as maxed).
##
## The badge now shows whether the section is collapsed OR expanded (Tim, 2026-07-31). It used
## to hide while expanded on the theory that the buy buttons said it instead — but with a long
## category you cannot see them all at once, and the header stays in view as you scroll.
func _update_section_count(category: String) -> void:
	var section: Dictionary = _sections[category]
	var label := section["count_label"] as Label

	# May run during _build_ui before setup() supplies the live state; nothing to count yet.
	if _upgrades == null:
		label.text = ""
		return

	var non_maxed_count := 0
	var affordable_count := 0
	# How many things this category CONTAINS at all. Distinguishes "everything is maxed" (show
	# MAX) from "there is nothing here yet" (show nothing) — the two collapse together if you
	# only look at the non-maxed count, and Household Staff legitimately starts empty.
	var total_count := 0
	if category == HOUSEHOLD_STAFF_CATEGORY:
		# Household Staff has no catalog upgrades — count the retention entries with a level still
		# left to buy and how many of those the player can afford right now. "Still left to buy"
		# is the level fields, not the price; "affordable" is levels > 0, since Main already
		# partial-filled that quote against the wallet.
		for entry_variant in _retention_entries:
			var entry := entry_variant as Dictionary
			total_count += 1
			if int(entry["retained_levels"]) >= int(entry["best_levels"]):
				continue  # this staffer is already retained to the bloodline's best level
			non_maxed_count += 1
			if int(entry.get("levels", 0)) > 0:
				affordable_count += 1
	else:
		for id in section["upgrade_ids"]:
			var upgrade_id := String(id)
			total_count += 1
			if _upgrades.is_maxed(upgrade_id):
				continue
			non_maxed_count += 1
			if _upgrades.can_buy(upgrade_id):
				affordable_count += 1

	var accent := _category_color(category)
	if total_count == 0:
		label.text = ""                      # nothing in this category yet — no claim to make
	elif non_maxed_count == 0:
		label.text = "MAX"
		label.add_theme_color_override("font_color", _muted_on(accent))
	else:
		label.text = "+%d" % affordable_count
		label.add_theme_color_override("font_color", _readable_on(accent))


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
	buy_button.gui_input.connect(_on_list_control_gui_input)
	bottom_row.add_child(buy_button)

	_cards[id] = {
		"level_label": level_label,
		"effect_label": effect_label,
		"buy_button": buy_button,
	}


# ---------------------------------------------------------------------------
# Household Staff retention rows (dynamic)
# ---------------------------------------------------------------------------

## Rebuild the Household Staff rows from Main's snapshot of the bloodline's staff-ladder
## achievements vs. the dynasty's retained ladder LEVELS. Each entry:
##   { index, property_name, staffer_name, best_levels, retained_levels, levels, cost,
##     gems_spent, next_level_cost (optional) }
##
## THIS SCREEN COMPUTES NOTHING. `levels` and `cost` are the whole quote, and Main derives them
## from the GLOBAL HIRE MODE toggle (×1 / ×10 / BLOCK / MAX) — the same toggle that drives staff
## hiring on the property tab — already partial-filled against the wallet and clamped to the
## bloodline's earned ceiling, exactly like every other bulk buy in the game:
##   levels = how many retention levels one press will buy (0 = nothing to buy)
##   cost   = the exact gem cost of exactly those `levels`
## They must be produced together, from the same pair of core calls, so the quote on the label
## can never disagree with the charge. Both are read with a default of 0, so an older snapshot
## paints the button disabled rather than quoting a price nobody computed.
##
## When `levels` is 0 the button greys in place and says why, and the two reasons are told apart
## from the level fields, not from the price: retained_levels >= best_levels means the bloodline's
## earned ceiling is reached; otherwise the wallet cannot cover even one level. In that second
## case the optional `next_level_cost` (the price of the single next level) lets the button name
## the shortfall; without it the button says only that it is unaffordable, never a wrong number.
func set_retention_entries(entries: Array) -> void:
	_retention_entries = entries
	_refresh_staff_section_header()  # its invested total + affordable badge track this snapshot
	for child in _staff_list.get_children():
		child.queue_free()
	_retention_rows = {}
	_held_retain_index = -1  # any held button is being freed — stop its repeat

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


## Refresh the Household Staff rows IN PLACE after a retention purchase, so a held
## RETAIN button keeps existing (and repeating). Falls back to a full rebuild if the
## row set itself changed (a property staffed for the first time adds a row).
func update_retention_entries(entries: Array) -> void:
	_retention_entries = entries
	if entries.size() != _retention_rows.size():
		set_retention_entries(entries)
		return
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if not _retention_rows.has(int(entry["index"])):
			set_retention_entries(entries)
			return
	for entry_variant in entries:
		_apply_retention_entry(entry_variant as Dictionary)
	_refresh_staff_section_header()  # in-place path: keep the header total + badge current too


## One Household Staff card: property + current staffer on top, the now/retained tiers and a
## single buy button beside them. ONE button (Tim, 2026-07-31): its count follows the global
## hire-mode toggle, so a second bulk button would only repeat what the toggle already says —
## and with many properties the extra row height was a lot of added scrolling.
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
	status.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	status.add_theme_font_size_override("font_size", CARD_BODY_SIZE)
	bottom.add_child(status)

	var button := Button.new()
	# 240 is a MINIMUM, not a fixed width (a fixed 440 once overflowed the framed viewport):
	# a long bulk quote like "RETAIN ×10 → LVL 22" grows the button past it, and the status
	# label beside it gives up the space because it is the one set to EXPAND_FILL. The smaller
	# font keeps that two-line quote on two comfortable lines (Tim, 2026-06-28).
	button.custom_minimum_size = Vector2(240, 80)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	UiPalette.style_button(button, true)  # red: spends Legacy
	# button_down/button_up (not `pressed`) so holding auto-repeats, exactly like the
	# upgrade cards' hold-to-buy: the down fires the first purchase, _process repeats it.
	button.button_down.connect(_on_retain_down.bind(index))
	button.button_up.connect(_on_retain_up)
	button.gui_input.connect(_on_list_control_gui_input)
	bottom.add_child(button)

	_retention_rows[index] = {"status": status, "button": button}
	_apply_retention_entry(entry)


## Paint one Household Staff row's live values (status line + RETAIN button) from its entry.
## Shared by the initial build and the in-place update so they can never disagree.
##
## THE BUTTON'S LABEL IS THE SPEND PREVIEW: it names both the level the press will REACH and the
## exact total it will charge, because retention is the endgame's open gem sink and one tap must
## never silently drain a fortune. Both numbers come straight off the snapshot (see
## set_retention_entries), which produced them from the same core calls the purchase itself uses.
##
## The button never hides (standing UI rule) — with nothing to buy it greys in place saying why:
##   • "FULLY RETAINED"        — already at the bloodline's earned ceiling.
##   • "RETAIN / NEED n Gems"  — levels remain but the wallet can't cover even one; n is the
##                               price of that next level, shown only when the snapshot supplies
##                               it as `next_level_cost`.
##   • "RETAIN / CAN'T AFFORD" — same case, but with no price to quote. Saying less is right:
##                               a number this screen guessed at would be worse than no number.
func _apply_retention_entry(entry: Dictionary) -> void:
	var row: Dictionary = _retention_rows[int(entry["index"])]
	var status := row["status"] as Label
	# "Best" is the deepest level any generation ever reached — retention shops against
	# the bloodline's record, not the living (resettable) ladder. LVL numbers match the
	# property row's readout, so the two screens agree.
	var best_levels := int(entry["best_levels"])
	var retained_levels := int(entry["retained_levels"])
	status.text = "Best LVL %d  ·  Retained LVL %d" % [best_levels, retained_levels]

	var button := row["button"] as Button
	# Default to 0 so a snapshot missing these fields disables the button rather than quoting a
	# price nobody computed (see set_retention_entries for the contract).
	var levels := int(entry.get("levels", 0))
	var cost := int(entry.get("cost", 0))

	# The quote was priced against the wallet as it stood when the snapshot was built. If gems
	# have left the wallet since, honour the wallet, not the stale quote — a button that offers
	# to spend money the player no longer has is the one failure this preview exists to prevent.
	# This can only ever SHRINK a quote to nothing; a wallet that GREW leaves the button
	# under-promising until Main re-feeds the snapshot, which is the harmless direction.
	if _upgrades != null and cost > _upgrades.available:
		levels = 0

	if levels > 0:
		button.text = "RETAIN ×%d → LVL %d\n%s Gems" % [
			levels, retained_levels + levels, Money.abbrev(cost)
		]
		button.disabled = false
	elif retained_levels >= best_levels:
		button.text = "FULLY RETAINED"
		button.disabled = true
	else:
		# Levels remain to buy; the wallet just can't reach the first one.
		var next_cost := int(entry.get("next_level_cost", 0))
		if next_cost > 0:
			button.text = "RETAIN\nNEED %s Gems" % Money.abbrev(next_cost)
		else:
			button.text = "RETAIN\nCAN'T AFFORD"
		button.disabled = true

	# Remember the quoted count so the press emits THIS number — the one on the label — rather
	# than letting Main re-derive a possibly different (larger) one.
	row["levels"] = levels


## Re-render the retention rows and the section header against the LIVE wallet, called by the
## wallet watcher in _process when gems arrive or leave while the tab is open.
##
## This pass cannot recompute a quote: `levels` depends on the hire mode and the core's cost
## curve, which this screen deliberately does not reach into. All it does is re-run
## _apply_retention_entry, whose wallet clamp shrinks a quote the wallet can no longer cover
## down to a disabled button. Main re-feeds the snapshot to grow one back.
func _refresh_retention_affordability() -> void:
	if _retention_entries.is_empty():
		return
	for entry_variant in _retention_entries:
		var entry := entry_variant as Dictionary
		if _retention_rows.has(int(entry["index"])):
			_apply_retention_entry(entry)
	_refresh_staff_section_header()


# ---------------------------------------------------------------------------
# Showing / refreshing
# ---------------------------------------------------------------------------

## Re-read the live state and update the wallet readout and every card.
func refresh() -> void:
	# Just the number — the gem icon beside it stands in for the word "Legacy" (Tim, 2026-06-28).
	# Formatted like money (45, 1.5K, 10M) rather than a raw integer (Tim, 2026-07-13).
	_wallet_label.text = Money.abbrev(_upgrades.available)

	for definition in LegacyUpgradeCatalog.all():
		var id := String(definition["id"])
		var controls: Dictionary = _cards[id]
		var level := _upgrades.get_level(id)
		var max_level := int(definition["max_level"])

		# An UNCAPPED compounder (Endgame Economy: max_level is a 9999 sentinel, the
		# steepening cost curve is the real ceiling) shows a plain level — "Level 12 / 9999"
		# would read as a bug, and there is deliberately no top to advertise.
		if max_level > 100:
			(controls["level_label"] as Label).text = "Level %d" % level
		else:
			(controls["level_label"] as Label).text = "Level %d / %d" % [level, max_level]
		var effect_label := controls["effect_label"] as Label
		effect_label.text = LegacyUpgradeCatalog.describe_effect(id, level)

		var buy_button := controls["buy_button"] as Button
		var required := _upgrades.requirement_for(id)
		var blocked := required != "" and not _upgrades.requirement_met(id)
		if _upgrades.is_maxed(id):
			buy_button.icon = null
			buy_button.text = "MAXED"
			buy_button.disabled = true
		elif blocked:
			# SAY WHY. A gray button that cannot explain itself is the exact failure that forced the
			# hire-mode toggle to hide instead of gray (tooltips never appear on touch), so a locked
			# card states its prerequisite in the line that would otherwise describe its effect.
			# The price is deliberately still shown: knowing what it will cost is part of deciding
			# whether to buy the thing it depends on.
			effect_label.text = "Requires %s" % LegacyUpgradeCatalog.get_definition(
				required).get("name", "an earlier upgrade")
			buy_button.icon = GEM_TEX
			buy_button.text = "  %s" % Money.abbrev(_upgrades.get_next_cost(id))
			buy_button.disabled = true
		else:
			var cost := _upgrades.get_next_cost(id)
			# The legacy-gem icon replaces the word "BUY"; the cost follows it (Tim, 2026-06-28).
			buy_button.icon = GEM_TEX
			buy_button.text = "  %s" % Money.abbrev(cost)
			# Greyed out (but still readable) when the player can't afford it.
			buy_button.disabled = not _upgrades.can_buy(id)

	# Update every section's header (its invested-gems total may have changed after a buy) and its
	# affordability badge, to match the new wallet/levels.
	for category in _sections:
		_update_section_header(String(category))
		_update_section_count(String(category))


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

## Press: arm the hold. Deliberately does NOT buy yet — see _on_buy_up.
func _on_buy_down(id: String) -> void:
	_held_buy_id = id
	_hold_elapsed = 0.0
	_hold_repeating = false
	_buy_fired_in_hold = false


## Release: this is where a TAP buys.
##
## The purchase used to fire on press, which cannot coexist with drag-to-scroll: a swipe across the
## list would spend gems on every buy button it crossed, and by the time a drag is detectable the
## money is already gone. Buying on release costs the few milliseconds of a tap and makes a swipe
## free. A HOLD still buys — the pump in _process fires at HOLD_INITIAL_DELAY — so this only acts
## when the hold never got that far and the gesture stayed put.
func _on_buy_up() -> void:
	var id := _held_buy_id
	_held_buy_id = ""
	if id == "" or _buy_fired_in_hold or _drag_moved:
		return
	_attempt_buy(id)


## While a buy or retain button is held, keep purchasing on a calm cadence (after an
## initial delay) until the player releases or nothing more can be bought.
func _process(delta: float) -> void:
	# Wallet watcher (see _last_rendered_wallet). Only while actually on screen — the
	# Estate tab re-syncs on entry anyway, and refreshing a hidden panel is wasted work.
	if is_visible_in_tree() and _upgrades != null \
			and _upgrades.available != _last_rendered_wallet:
		_last_rendered_wallet = _upgrades.available
		refresh()
		_refresh_retention_affordability()

	if _held_buy_id != "":
		if _drag_moved:
			_held_buy_id = ""  # the press became a scroll — buy nothing, spend nothing
		else:
			_hold_elapsed += delta
			var threshold := HOLD_REPEAT_INTERVAL if _hold_repeating else HOLD_INITIAL_DELAY
			if _hold_elapsed >= threshold:
				_hold_elapsed = 0.0
				_hold_repeating = true
				_buy_fired_in_hold = true  # the release must not buy a second time
				if not _attempt_buy(_held_buy_id):
					_held_buy_id = ""  # nothing left to buy — stop repeating

	if _held_retain_index >= 0:
		if _drag_moved:
			_held_retain_index = -1  # same rule as buy: a scroll never spends
		else:
			_retain_hold_elapsed += delta
			var retain_threshold := HOLD_REPEAT_INTERVAL if _retain_hold_repeating else HOLD_INITIAL_DELAY
			if _retain_hold_elapsed >= retain_threshold:
				_retain_hold_elapsed = 0.0
				# Main performs the purchase and updates this row in place; once the button
				# reads disabled (fully retained / unaffordable) the repeat stops itself.
				var row: Dictionary = _retention_rows.get(_held_retain_index, {})
				var quoted := int(row.get("levels", 0))
				if row.is_empty() or (row["button"] as Button).disabled:
					_held_retain_index = -1
				elif quoted != 1:
					# Auto-repeat is for SINGLE-level presses only (hire mode ×1). At ×10 / MAX the
					# button is already a bulk action, and repeating it three times a second would
					# let a finger resting on the screen empty the wallet over and over (Tim,
					# 2026-07-31). The hold simply idles here; the one bulk purchase happens on
					# release, in _on_retain_up.
					pass
				else:
					_retain_hold_repeating = true
					_retain_fired_in_hold = true  # the release must not retain a second time
					retain_requested.emit(_held_retain_index, quoted)


## Press on a RETAIN button: buy exactly the block this button's label just quoted, then arm the
## auto-repeat (mirrors _on_buy_down). At ×1 holding retains level after level at the hold-to-buy
## cadence — deep retention is many steps, so tapping each one would be a chore (Tim, 2026-07-04).
## At a bulk hire mode the pump in _process declines to repeat; see the comment there.
func _on_retain_down(property_index: int) -> void:
	var row: Dictionary = _retention_rows.get(property_index, {})
	var levels := int(row.get("levels", 0))
	if levels <= 0:
		return  # nothing quoted (disabled, or a snapshot without the quote fields)
	_held_retain_index = property_index
	_retain_hold_elapsed = 0.0
	_retain_hold_repeating = false
	_retain_fired_in_hold = false


## Release: this is where a TAP retains. Mirrors _on_buy_up, and for the same reason — retention is
## the most expensive thing on this screen, so a swipe across it must never spend.
##
## The quote is re-read here rather than captured on press: the wallet can change under a hold (the
## pump buys, Main updates the row in place), and the label the player last saw is the promise being
## honoured. Buying exactly the quoted count is the existing rule that stops a mid-press gem grant
## from overcharging.
func _on_retain_up() -> void:
	var index := _held_retain_index
	_held_retain_index = -1
	if index < 0 or _retain_fired_in_hold or _drag_moved:
		return
	var row: Dictionary = _retention_rows.get(index, {})
	var levels := int(row.get("levels", 0))
	if levels <= 0 or (row["button"] as Button).disabled:
		return
	retain_requested.emit(index, levels)


## Buy one level of an upgrade, refresh the shop, and notify Main. Returns whether the
## purchase actually went through (false when maxed or unaffordable).
func _attempt_buy(id: String) -> bool:
	if not _upgrades.buy(id):
		return false
	refresh()           # update the wallet and this card immediately
	purchased.emit(id)  # let Main re-apply the effect to the living generation
	return true


# ---------------------------------------------------------------------------
# Drag-to-scroll (2026-08-06)
# ---------------------------------------------------------------------------
# Every section header is a full-width Button, so with the sections collapsed — which is how they
# all start — the headers tile the whole list and a touch has nowhere neutral to grab. A Button's
# default MOUSE_FILTER_STOP swallows the press before the ScrollContainer sees a drag, so the list
# could not be swiped. Same failure DevTuningPanel and ChallengesScreen hit; same fix: pan the
# scroll ourselves and suppress the tap once the gesture is clearly a scroll.
#
# UiPalette.allow_scroll_drag_through() (called on the list and the staff list) cannot help: it
# deliberately early-returns on any BaseButton, because a MOUSE_FILTER_PASS button would forward
# its taps to the parent as well as acting on them. It rescues the card surfaces only.
#
# THE EXTRA STAKE ON THIS SCREEN: buy and retain used to purchase on button_down, so a swipe would
# have spent gems on every button it crossed — and a drag is not detectable until after the press.
# That is why _on_buy_down/_on_retain_down no longer buy; the purchase moved to release (or to the
# hold pump). Nothing here can undo a purchase, so the only safe design is not to make one yet.


## Route one list control's input: a fresh press starts a new gesture, anything else may be a drag.
##
## The press reset is read off the raw event rather than the Button's button_down signal, because
## buy and retain buttons are routinely `disabled` (maxed, unaffordable) and a disabled Button emits
## no button_down while still swallowing the touch. Reading the press here keeps a row of
## unaffordable upgrades from becoming a dead patch of list you cannot scroll from.
func _on_list_control_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_drag_gesture()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag_gesture()
		return
	_pan_scroll_on_drag(event)


## Start tracking a fresh press gesture, before any travel.
func _begin_drag_gesture() -> void:
	_drag_accum = 0.0
	_drag_moved = false


## Pan the list when a press over a control turns into a drag. Never consumes the event, so a
## genuine tap still reaches the button's own signals.
func _pan_scroll_on_drag(event: InputEvent) -> void:
	if _scroll == null:
		return
	var delta_y := 0.0
	if event is InputEventScreenDrag:
		delta_y = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# Desktop only. Godot's emulate_mouse_from_touch (on by default) also synthesises a mouse
		# motion for every InputEventScreenDrag, so counting both on a phone would pan at twice the
		# speed of the finger and trip the threshold after half the intended travel.
		if OS.has_feature("mobile"):
			return
		delta_y = event.relative.y
	else:
		return

	# Finger down the screen (delta_y > 0) reveals EARLIER cards, so scroll_vertical decreases.
	_scroll.scroll_vertical -= int(delta_y)
	_drag_accum += absf(delta_y)
	if _drag_accum >= DRAG_SCROLL_THRESHOLD:
		_drag_moved = true
