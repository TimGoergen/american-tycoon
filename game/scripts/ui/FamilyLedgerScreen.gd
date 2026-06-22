class_name FamilyLedgerScreen
extends ColorRect

# "The Family Ledger" (GDD §8.2) — a full-screen page listing every deceased
# generation of the dynasty: each ancestor's name and Roman numeral, the fortune
# they earned in their lifetime, and the deadpan cause of their generation's end
# ("Retired to Palm Beach" / "Creditors"). Opened from the Main screen by a button
# that appears once the first ancestor exists.
#
# Same full-page convention as LegacyScreen: an opaque cream sheet that fills the
# screen while open (Main freezes the economy behind it), large legible type (Tim
# reads large — UI notes §1), a scrolling list, and a big CLOSE button.
#
# Drive it from Main.gd:
#   1. setup()                       once, to build the static page chrome
#   2. open(ancestors, lifetime)     to (re)populate the list and show the page
#   3. listen for closed             resume the game
#
# Unlike LegacyScreen (a fixed catalog built once), the ancestor list grows every
# generation, so open() rebuilds the rows from the passed array each time.


## The player closed the ledger and wants to return to the game.
signal closed


# Type sizes — large for at-a-glance phone reading (UI notes §1), matching the
# trimmed scale LegacyScreen settled on.
const TITLE_SIZE := UiPalette.FONT_PAGE_TITLE
const TOTAL_SIZE := UiPalette.FONT_DISPLAY
const NAME_SIZE := UiPalette.FONT_HEADLINE
const BODY_SIZE := UiPalette.FONT_CARD_BODY

## Top inset (in the 1080×1920 design space) that clears the phone's camera
## cut-out, so the header is never hidden behind it. Matches LegacyScreen.
const CAMERA_CUTOUT_INSET := 130


# The dynasty-wide lifetime-earned readout pinned to the header.
var _total_label: Label

# The container the ancestor rows are rebuilt into on every open().
var _list: VBoxContainer


## Build the static page chrome once (header, scroll frame, close button).
func setup() -> void:
	_build_chrome()


func _ready() -> void:
	# Opaque cream sheet filling the whole screen — a full page, not a translucent
	# card over the game. Main freezes the economy while it is visible.
	color = UiPalette.CREAM
	visible = false


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
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

	# ── Header row: title pinned left, dynasty lifetime-earned readout pinned right ──
	var header_row := HBoxContainer.new()
	column.add_child(header_row)

	var title := Label.new()
	title.text = "The Family Ledger"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	header_row.add_child(title)

	_total_label = Label.new()
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_total_label.add_theme_font_size_override("font_size", TOTAL_SIZE)
	header_row.add_child(_total_label)

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

	# ── Close button ──
	var close_button := Button.new()
	close_button.text = "BACK TO THE EMPIRE"
	close_button.custom_minimum_size = Vector2(0, 158)
	close_button.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	UiPalette.style_button(close_button, false)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)


# ---------------------------------------------------------------------------
# Showing / populating
# ---------------------------------------------------------------------------

## Rebuild the ancestor rows from `ancestors` (oldest first, founder at top — a
## lineage reads chronologically) and show the page. `lifetime_total` is the
## dynasty-wide cash-earned sum shown in the header.
func open(ancestors: Array, lifetime_total: float) -> void:
	_total_label.text = "Dynasty total: %s" % Money.of(lifetime_total).display()

	# Clear the previous rows — the list grows each generation, so it is rebuilt
	# fresh on every open rather than appended to.
	for child in _list.get_children():
		child.queue_free()

	if ancestors.is_empty():
		# Defensive: the open button only appears once an ancestor exists, but show
		# a calm placeholder rather than a blank page if it is ever opened empty.
		var empty := Label.new()
		empty.text = "No ancestors yet. The dynasty begins with you."
		empty.add_theme_color_override("font_color", UiPalette.NAVY)
		empty.add_theme_font_size_override("font_size", BODY_SIZE)
		_list.add_child(empty)
	else:
		for record in ancestors:
			_add_ancestor_row(record as Dictionary)

	visible = true


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


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
