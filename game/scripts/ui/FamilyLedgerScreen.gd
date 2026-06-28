class_name FamilyLedgerScreen
extends Control

# "The Family Ledger" (GDD §8.2) — lists every deceased generation of the dynasty:
# each ancestor's name and Roman numeral, the fortune they earned in their lifetime,
# and the deadpan cause of their generation's end ("Retired to Palm Beach" / "Creditors").
#
# This is the content of the **Family Ledger tab** (UI Notes §7) — it is embedded in the
# bottom tab bar, not a modal overlay, so there is no scrim or close button and the
# economy keeps ticking behind it (an idle game never pauses for a read-only page).
#
# Drive it from Main.gd:
#   1. setup()                       once, to build the static page chrome
#   2. refresh(ancestors, lifetime)  to (re)populate the list (call on entering the tab)
#
# The ancestor list grows every generation, so refresh() rebuilds the rows each time.


# Type sizes — large for at-a-glance phone reading (UI notes §1), but the title/total
# are a notch smaller than the old full-screen-overlay sizes: as an embedded tab the
# header must fit the tab width, and FONT_PAGE_TITLE/DISPLAY side-by-side overflowed.
const TOTAL_SIZE := UiPalette.FONT_SUBHEAD
const NAME_SIZE := UiPalette.FONT_HEADLINE
const BODY_SIZE := UiPalette.FONT_CARD_BODY


# The dynasty-wide lifetime-earned readout pinned to the header.
var _total_label: Label

# The container the ancestor rows are rebuilt into on every refresh().
var _list: VBoxContainer


## Build the static page chrome once (header + scroll frame).
func setup() -> void:
	_build_chrome()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# No inner margin (Tim, 2026-06-28): the shared tab panel (UiPalette.wrap_in_tab_panel) already
	# pads this tab, and an extra inset here pushed the title 8px lower than the Estate/Settings
	# titles, breaking their vertical alignment.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# ── Header: the centered "FAMILY LEDGER" title (shared tab-title style, matching the Settings
	# and Estate Planning tabs; "The" dropped — Tim 2026-06-28), then the dynasty lifetime-earned
	# readout beneath it on its own line. ──
	column.add_child(UiPalette.make_tab_title("FAMILY LEDGER"))

	_total_label = Label.new()
	_total_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_total_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_total_label.add_theme_font_size_override("font_size", TOTAL_SIZE)
	column.add_child(_total_label)

	# ── Scrollable list of ancestor rows ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# Let a swipe that lands on a card scroll the list, as elsewhere.
	UiPalette.allow_scroll_drag_through(_list)


# ---------------------------------------------------------------------------
# Populating
# ---------------------------------------------------------------------------

## Rebuild the ancestor rows from `ancestors` (oldest first, founder at top — a lineage
## reads chronologically). `lifetime_total` is the dynasty-wide cash-earned sum shown in
## the header. Call when the tab is opened, so it reflects the latest succession.
func refresh(ancestors: Array, lifetime_total: float) -> void:
	_total_label.text = "Dynasty total: %s" % Money.of(lifetime_total).display()

	# The list grows each generation, so rebuild it fresh rather than appending.
	for child in _list.get_children():
		child.queue_free()

	if ancestors.is_empty():
		var empty := Label.new()
		empty.text = "No ancestors yet. The dynasty begins with you."
		empty.add_theme_color_override("font_color", UiPalette.NAVY)
		empty.add_theme_font_size_override("font_size", BODY_SIZE)
		_list.add_child(empty)
	else:
		for record in ancestors:
			_add_ancestor_row(record as Dictionary)


## One ancestor card: name + numeral on top, then "Earned $X · {cause}" beneath.
func _add_ancestor_row(record: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	_list.add_child(card)

	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 6)
	card.add_child(card_column)

	var name_label := Label.new()
	name_label.text = String(record.get("name", ""))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	card_column.add_child(name_label)

	# Fortune (money-green) and cause on one line: the satire's receipt, unremarked.
	var detail := Label.new()
	detail.text = "Earned %s  ·  %s" % [
		Money.of(float(record.get("fortune", 0.0))).display(),
		String(record.get("cause", "")),
	]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	detail.add_theme_font_size_override("font_size", BODY_SIZE)
	card_column.add_child(detail)
