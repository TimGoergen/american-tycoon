class_name StatsScreen
extends ColorRect

# The Statistics screen (Tim 2026-07-20; Plans/Overdrive_Vent_Windows.md): a full-screen modal,
# opened from Settings, that collects the bloodline's headline numbers. It is deliberately built
# as a HOME for future stats — a reusable label-left / value-right row you drop new stats into
# with one call — not a page for its one first resident. Best Vent Streak is that first resident
# (the deepest overdrive vent streak the bloodline has ever reached, an implicit high score that
# has no other home: it is explicitly NOT on the momentum bar and NOT in the Family Ledger).
#
# Same black-bezel frame and top-left Back button as every other full-window modal (AboutScreen,
# MinigameReviewScreen). Like those, it does NOT freeze the economy — the game keeps running
# behind it; there is no run state to protect, only numbers to read.

signal closed

## The bloodline whose stats are shown. Threaded in from Main (set_dynasty) before open(); the
## values are read fresh on every open() so the page is never stale.
var _dynasty: DynastyState

## The column the stat rows live in — cleared and rebuilt on each open() so every value is current.
var _stats_column: VBoxContainer


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

	# Back button, pinned top-left with a generous margin (matches every other modal's Back).
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

	# The content, centered in the space beneath the Back button.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 28)
	# Wide enough that the label/value pairs have room to sit at their two edges (Tim's vision).
	content.custom_minimum_size = Vector2(900, 0)
	center.add_child(content)

	content.add_child(UiPalette.make_tab_title("STATISTICS"))

	# The stat rows live in their own column so open() can rebuild just the values, leaving the
	# title and frame untouched.
	_stats_column = VBoxContainer.new()
	_stats_column.add_theme_constant_override("separation", 22)
	content.add_child(_stats_column)


## Hand the screen the bloodline it reports on. Called by Main once, at build time.
func set_dynasty(dynasty: DynastyState) -> void:
	_dynasty = dynasty


func open() -> void:
	_rebuild_rows()
	visible = true


## Rebuild every stat row from the dynasty's current values. Adding a future stat is one
## _add_stat_row call here — that is the whole point of the reusable row helper.
func _rebuild_rows() -> void:
	for child in _stats_column.get_children():
		child.queue_free()
	if _dynasty == null:
		return

	# --- First-pass seed stats (Tim 2026-07-20) ---
	# Best Vent Streak is the intended first resident; the other three are bloodline numbers already
	# tracked elsewhere, surfaced here so the page is not a one-line stub. They are first-pass and
	# subject to Tim's review — no new tracking was invented for any of them.

	# The headline resident. A streak of 0 means no overdrive run has ever ended, i.e. the mechanic
	# is unproven for this bloodline — shown as an em dash rather than "0" so it reads as "nothing
	# yet" instead of a real score of zero.
	var best := _dynasty.get_best_vent_streak()
	_add_stat_row("Best Vent Streak", "—" if best <= 0 else str(best))

	_add_stat_row("Generation", str(_dynasty.generation))
	# Lifetime cash EARNED across the whole bloodline (the Family Ledger's career figure) — the
	# dynasty's monotonic yardstick, formatted with the same money abbreviator the rest of the UI
	# uses. Note: this is the banked total from deceased generations, matching the Ledger; the
	# living generation's in-progress earnings are not folded in until its succession.
	_add_stat_row("Lifetime Cash Earned", Money.abbrev(_dynasty.lifetime_cash_earned))


## One statistic: its name on the left, its value on the right, both large for readability. This is
## the reusable primitive — every stat is one call to this.
func _add_stat_row(stat_name: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # push the value to the right edge
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	value_label.add_theme_font_override("font", UiPalette.make_bold_font())
	value_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	row.add_child(value_label)

	_stats_column.add_child(row)


func _on_back_pressed() -> void:
	visible = false
	Audio.play(&"screen_close")
	closed.emit()
