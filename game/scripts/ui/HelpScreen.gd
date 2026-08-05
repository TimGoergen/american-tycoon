class_name HelpScreen
extends ColorRect

# The Help / Glossary modal (Plans/Tutorial_Onboarding_Plan.md, Phase 4): a scrollable reference of
# every tutorial concept, plus a REPLAY TUTORIAL action that re-arms the one-time coach cards.
# Opened from the Settings tab's HELP button; the Back button (top-left) closes it. Same
# black-bezel frame as the other full-window modals (modeled on AboutScreen). The glossary text is
# the single copy in TutorialCatalog, so the cards and this reference can never disagree.

signal closed
## The player asked to see the tutorial again — Main clears TutorialProgress and re-arms the tips.
signal replay_requested


func _ready() -> void:
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	viewing_area.add_child(column)

	# Back button, pinned top-left (matches the About / minigame Back button).
	var back_margin := MarginContainer.new()
	back_margin.add_theme_constant_override("margin_top", 28)
	back_margin.add_theme_constant_override("margin_left", 28)
	column.add_child(back_margin)
	var back_row := HBoxContainer.new()
	back_margin.add_child(back_row)
	var back := Button.new()
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(340, 108)
	back.add_theme_font_size_override("font_size", int(UiPalette.FONT_BUTTON * 1.5))
	back.add_theme_font_override("font", UiPalette.make_bold_font())
	back.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(back, false)
	back.pressed.connect(_on_back_pressed)
	back_row.add_child(back)
	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer)

	column.add_child(UiPalette.make_tab_title("HELP"))

	# Scrollable glossary — one titled entry per tutorial concept, in teaching order (Dictionary
	# iteration preserves the catalog's insertion order). Horizontal scroll off so the entries wrap.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 22)
	scroll.add_child(list)
	for tip_id in TutorialCatalog.TIPS:
		list.add_child(_make_entry(TutorialCatalog.TIPS[tip_id]))

	# The number-format reference goes LAST, after every tutorial concept: it is the one entry a
	# player looks up on purpose rather than reads through, and it is forty rows tall — putting it
	# anywhere else would push the short teaching entries below a screen and a half of table.
	list.add_child(_make_number_format_entry())

	# Replay action at the bottom, clear of the list. Red "act" styling — it's a deliberate action.
	var replay := Button.new()
	replay.text = "REPLAY TUTORIAL"
	replay.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 1.2))
	replay.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	replay.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(replay, true)
	replay.pressed.connect(_on_replay_pressed)
	column.add_child(replay)


## One glossary entry: the concept's bold title over its explanation.
func _make_entry(tip: Dictionary) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = tip.get("title", "")
	title.add_theme_font_override("font", UiPalette.make_bold_font())
	title.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title)

	var body := Label.new()
	body.text = tip.get("body", "")
	body.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	body.add_theme_color_override("font_color", Color(UiPalette.NAVY, 0.85))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(body)

	return entry


# The short-scale English names for the magnitudes a reader is likely to actually know, keyed by
# the power of ten. Deliberately STOPS at a quintillion: past that the real names ("sexdecillion",
# "novemtrigintillion") are exactly as unhelpful as the abbreviations this table exists to explain,
# so a rung with no entry here simply shows its power of ten and nothing else. Keyed by exponent
# rather than by rung position so it can never fall out of step with Money.SUFFIXES.
const FAMILIAR_MAGNITUDE_NAMES := {
	3: "thousand",
	6: "million",
	9: "billion",
	12: "trillion",
	15: "quadrillion",
	18: "quintillion",
}

## Fixed width (px) of the two narrow table columns, so all forty rows line up in a clean grid
## instead of drifting with each label's own text width.
const TABLE_LABEL_COLUMN_WIDTH := 190


## The number-format glossary entry (Plans/Currency_Format_Setting.md): what the three formats are,
## where to change them, and the complete ladder of magnitudes with both of its shorthands side by
## side. The table doubles as the ALPHABET legend — that mode exists because the abbreviations stop
## being orderable by eye around ten rungs up (is "SxVg" bigger than "QaTg"? It is not), and the
## only honest fix is to let the player look the answer up.
func _make_number_format_entry() -> VBoxContainer:
	var entry := _make_entry({
		"title": "Reading the big numbers",
		"body": "A growing fortune outruns plain digits in a hurry, so every figure on screen is "
			+ "shortened. How it is shortened is your choice — see NUMBER FORMAT in Settings.\n\n"
			+ "ABBREVIATED   $4.2 Qa   the traditional shorthand.\n"
			+ "ALPHABET   $4.2 ab   a letter pair for every step, in alphabetical order, so the "
			+ "larger of two fortunes always reads later in the alphabet.\n"
			+ "SCIENTIFIC   $4.2e18   the figure and its number of digits, stated plainly.\n\n"
			+ "Every step below is one thousand times the step above it. Familiar names run out "
			+ "long before the ladder does, so past a quintillion each step is given as its power "
			+ "of ten — the same figure the SCIENTIFIC format shows.",
	})

	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 20)
	table.add_theme_constant_override("v_separation", 10)
	entry.add_child(table)

	table.add_child(_make_table_cell("SHORT", true, true))
	table.add_child(_make_table_cell("LETTERS", true, true))
	table.add_child(_make_table_cell("MAGNITUDE", true, false))

	# Built from Money.SUFFIXES at runtime, never hand-typed: the ladder has already been extended
	# twice (past T in 2026-07-03, past Dd in 2026-07-26), and a copied table would have gone
	# quietly wrong both times. Walked in REVERSE because SUFFIXES is ordered largest-first while
	# the table reads smallest-first, the way the alphabet counts.
	for i in range(Money.SUFFIXES.size() - 1, -1, -1):
		var rung: Dictionary = Money.SUFFIXES[i]
		table.add_child(_make_table_cell(str(rung["suffix"]), false, true))
		# Money owns the index-to-letters rule (largest-first ladder, so the alphabet index counts
		# the other way). Calling Money's own helper rather than repeating the arithmetic here is
		# the point: the legend and the live labels cannot disagree if only one of them can be wrong.
		var letters := Money.alphabet_for_rung(Money.SUFFIXES.size() - 1 - i)
		table.add_child(_make_table_cell(letters, false, true))
		table.add_child(_make_table_cell(_describe_magnitude(rung["scale"]), false, false))

	return entry


## The magnitude column's text for one rung: its power of ten, plus the short-scale English name
## when there is one worth printing. "1e15  (quadrillion)" for the familiar steps, a bare "1e51"
## beyond them. The power of ten leads every row so the column stays scannable and strictly
## ordered — which is the failing of the abbreviations this table explains.
func _describe_magnitude(scale: float) -> String:
	var exponent := int(round(log(scale) / log(10.0)))
	var text := "1e" + str(exponent)
	if FAMILIAR_MAGNITUDE_NAMES.has(exponent):
		text += "  (" + str(FAMILIAR_MAGNITUDE_NAMES[exponent]) + ")"
	return text


## One cell of the magnitude table. Header cells are bold navy; body cells match the glossary's
## ordinary body text. `fixed_width` is set on the two shorthand columns so all forty rows line up
## as columns; the trailing magnitude column just takes the room it needs. Autowrap is left OFF
## (the default) — every cell is a handful of characters, and a Label that wrapped here would only
## ever break a suffix in half.
func _make_table_cell(text: String, is_header: bool, fixed_width: bool) -> Label:
	var cell := Label.new()
	cell.text = text
	cell.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	if is_header:
		cell.add_theme_font_override("font", UiPalette.make_bold_font())
		cell.add_theme_color_override("font_color", UiPalette.NAVY)
	else:
		cell.add_theme_color_override("font_color", Color(UiPalette.NAVY, 0.85))
	if fixed_width:
		cell.custom_minimum_size.x = TABLE_LABEL_COLUMN_WIDTH
	return cell


func open() -> void:
	visible = true


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_replay_pressed() -> void:
	visible = false
	closed.emit()
	replay_requested.emit()
