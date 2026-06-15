class_name WillScreen
extends ColorRect

# "The Reading of the Will" — the prestige/succession ceremony screen (GDD §13).
# This is the legible-math version: plain itemized estate waterfall document
# followed by an heir reveal. Ceremony copy, portraits, and art arrive in M3;
# this M1 build surfaces all the numbers clearly so the math feels real.
#
# Three phases live inside one overlay and are swapped in-place:
#   Phase 0 — the obituary (GDD §8.3 beat 1: who died + a deadpan life summary,
#             headlined by the generation's lifetime earnings)
#   Phase 1 — the will document (estate waterfall + "SIGN & PASS ON" button)
#   Phase 2 — heir reveal ("THE ESTATE PASSES TO" + "BEGIN THE NEW RUN" button)
#
# Main.gd drives the ceremony:
#   1. Call show_obituary(stats)         → player reads the obituary, clicks continue
#   2. Listen for continue_to_will signal
#   3. Call show_will(will, dying_name)  → player reads math, clicks confirm
#   4. Listen for pass_on_confirmed signal
#   5. Call show_heir_reveal(heir_name, generation) → player clicks begin
#   6. Listen for heir_begin_pressed signal


## Player dismissed the obituary to read the will (end phase 0).
signal continue_to_will

## Player has signed the will and chosen to pass the estate on (end phase 1).
signal pass_on_confirmed

## Player backed out of the will to keep playing the current generation (phase 1).
signal cancelled

## Player dismisses the heir reveal to begin the new generation (end phase 2).
signal heir_begin_pressed


# ── Phase 0 references (the obituary) ─────────────────────────────────────────

var _phase0_container: VBoxContainer

var _obituary_name_label: Label
var _obituary_fortune_label: Label
var _obituary_summary_label: Label


# ── Phase 1 references ────────────────────────────────────────────────────────

var _phase1_container: VBoxContainer

var _deceased_label: Label    # "The estate of {name}"
var _gross_value: Label
var _creditors_value: Label
var _subtotal_value: Label
var _tax_value: Label
var _net_value: Label
var _legacy_value: Label


# ── Phase 2 references ────────────────────────────────────────────────────────

var _phase2_container: VBoxContainer

var _heir_name_label: Label
var _generation_label: Label


func _ready() -> void:
	# Dark scrim covers the game screen beneath the ceremony.
	color = Color(UiPalette.INK_NAVY, 0.75)
	visible = false

	# A single CenterContainer positions the panel in the middle of the screen.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	center.add_child(panel)

	# The outer column holds padding and switches between the two phase containers.
	var outer_column := VBoxContainer.new()
	outer_column.add_theme_constant_override("separation", 0)
	outer_column.custom_minimum_size = Vector2(640, 0)
	panel.add_child(outer_column)

	_build_phase0(outer_column)
	_build_phase1(outer_column)
	_build_phase2(outer_column)

	# All phases start hidden; the show_* methods reveal exactly one at a time.
	_phase0_container.visible = false
	_phase1_container.visible = false
	_phase2_container.visible = false


# ── Phase 0 builder (the obituary) ────────────────────────────────────────────

func _build_phase0(parent: VBoxContainer) -> void:
	_phase0_container = VBoxContainer.new()
	_phase0_container.add_theme_constant_override("separation", 10)
	parent.add_child(_phase0_container)

	# ── Headline ──
	var headline := Label.new()
	headline.text = "IN MEMORIAM"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.NAVY)
	headline.add_theme_font_size_override("font_size", 44)
	_phase0_container.add_child(headline)

	# ── The deceased's name (populated in show_obituary) ──
	_obituary_name_label = Label.new()
	_obituary_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obituary_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obituary_name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_obituary_name_label.add_theme_font_size_override("font_size", 40)
	_phase0_container.add_child(_obituary_name_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_phase0_container.add_child(spacer)

	# ── The headline figure: lifetime earnings, in celebratory money-green ──
	# This is the obituary's hero number (GDD §8.3) — the dollars this life earned.
	_obituary_fortune_label = Label.new()
	_obituary_fortune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obituary_fortune_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_obituary_fortune_label.add_theme_font_size_override("font_size", 52)
	_phase0_container.add_child(_obituary_fortune_label)

	var caption := Label.new()
	caption.text = "earned in a lifetime of honest work"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", UiPalette.NAVY)
	caption.add_theme_font_size_override("font_size", 22)
	_phase0_container.add_child(caption)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	_phase0_container.add_child(spacer2)

	# ── Deadpan life summary (populated in show_obituary) ──
	_obituary_summary_label = Label.new()
	_obituary_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obituary_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obituary_summary_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_obituary_summary_label.add_theme_font_size_override("font_size", 26)
	_phase0_container.add_child(_obituary_summary_label)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	_phase0_container.add_child(spacer3)

	# ── Continue button → the will ──
	var continue_button := Button.new()
	continue_button.text = "READ THE WILL"
	continue_button.custom_minimum_size = Vector2(0, 80)
	continue_button.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(continue_button, true)
	continue_button.pressed.connect(_on_obituary_continue_pressed)
	_phase0_container.add_child(continue_button)


# ── Phase 1 builder ───────────────────────────────────────────────────────────

func _build_phase1(parent: VBoxContainer) -> void:
	_phase1_container = VBoxContainer.new()
	_phase1_container.add_theme_constant_override("separation", 10)
	parent.add_child(_phase1_container)

	# ── Headline ──
	var headline := Label.new()
	headline.text = "THE READING OF THE WILL"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.NAVY)
	headline.add_theme_font_size_override("font_size", 44)
	_phase1_container.add_child(headline)

	# ── Deceased subline (populated in show_will) ──
	_deceased_label = Label.new()
	_deceased_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deceased_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_deceased_label.add_theme_font_size_override("font_size", 26)
	_phase1_container.add_child(_deceased_label)

	# Visual separator between the header block and the document rows.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_phase1_container.add_child(spacer)

	# ── Itemized estate rows ──
	# Each row is an HBoxContainer: description on the left, value right-aligned.
	_gross_value    = _add_document_row(_phase1_container, "Gross estate:",    UiPalette.NAVY,        30)
	_creditors_value = _add_document_row(_phase1_container, "Creditors paid:",  UiPalette.NAVY,        30)
	_subtotal_value = _add_document_row(_phase1_container, "Subtotal:",         UiPalette.NAVY,        30)
	_tax_value      = _add_document_row(_phase1_container, "Estate tax:",       UiPalette.KETCHUP_RED, 30)

	# The "Net to heir" line is emphasized — larger text and money-green so the
	# player immediately sees what they're actually passing down.
	_add_divider(_phase1_container)
	_net_value      = _add_document_row(_phase1_container, "── Net to heir:",   UiPalette.MONEY_GREEN, 40)
	_legacy_value   = _add_document_row(_phase1_container, "Converts to Legacy:", UiPalette.MONEY_GREEN, 30)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	_phase1_container.add_child(spacer2)

	# ── Confirm button ──
	var confirm_button := Button.new()
	confirm_button.text = "SIGN & PASS ON"
	confirm_button.custom_minimum_size = Vector2(0, 80)
	confirm_button.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(confirm_button, true)
	confirm_button.pressed.connect(_on_sign_pressed)
	_phase1_container.add_child(confirm_button)

	# ── Cancel button ──
	# Backing out is not a spend/commit action, so it gets the calm mustard style
	# (red is reserved for "spend/act"). Lets the player close the will and keep
	# playing the current generation if they'd rather wait to prestige.
	var cancel_button := Button.new()
	cancel_button.text = "NOT YET — KEEP PLAYING"
	cancel_button.custom_minimum_size = Vector2(0, 64)
	cancel_button.add_theme_font_size_override("font_size", 24)
	UiPalette.style_button(cancel_button, false)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_phase1_container.add_child(cancel_button)


# ── Phase 2 builder ───────────────────────────────────────────────────────────

func _build_phase2(parent: VBoxContainer) -> void:
	_phase2_container = VBoxContainer.new()
	_phase2_container.add_theme_constant_override("separation", 16)
	parent.add_child(_phase2_container)

	# ── Headline ──
	var headline := Label.new()
	headline.text = "THE ESTATE PASSES TO"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.NAVY)
	headline.add_theme_font_size_override("font_size", 44)
	_phase2_container.add_child(headline)

	# ── Heir name (populated in show_heir_reveal) ──
	# Large enough to feel like a name being announced in a room.
	_heir_name_label = Label.new()
	_heir_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heir_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heir_name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_heir_name_label.add_theme_font_size_override("font_size", 56)
	_phase2_container.add_child(_heir_name_label)

	# ── Generation / deadpan subline ──
	_generation_label = Label.new()
	_generation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_generation_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_generation_label.add_theme_font_size_override("font_size", 26)
	_phase2_container.add_child(_generation_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_phase2_container.add_child(spacer)

	# ── Begin button ──
	var begin_button := Button.new()
	begin_button.text = "BEGIN THE NEW RUN"
	begin_button.custom_minimum_size = Vector2(0, 80)
	begin_button.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(begin_button, true)
	begin_button.pressed.connect(_on_begin_pressed)
	_phase2_container.add_child(begin_button)


# ── Public interface ──────────────────────────────────────────────────────────

## Show phase 0: the obituary for the dying generation (GDD §8.3 beat 1).
## `stats` keys:
##   name      — String, the deceased's full dynastic name ("Wellington Pemberton VIII")
##   fortune   — float, the life's lifetime cash earned (the headline figure)
##   seed      — float, the cash the generation was born with (the "grew from $X" anchor)
##   employees — int, how many properties the generation kept staffed (its payroll)
func show_obituary(stats: Dictionary) -> void:
	_obituary_name_label.text = String(stats.get("name", ""))
	_obituary_fortune_label.text = Money.of(float(stats.get("fortune", 0.0))).display()

	# Deadpan summary assembled from the life's real stats. The narrator is a true
	# believer (GDD §1.2): it credits hard work while reporting "Hours worked: 0" —
	# only the numbers wink. "employer of N" pluralizes so the grammar stays sincere.
	var employees := int(stats.get("employees", 0))
	var employer_clause := "a beloved employer of %d" % employees if employees != 1 else "a beloved employer of 1"
	var summary := "%s, grew the family fortune from %s to %s. Hours worked: 0." % [
		employer_clause,
		Money.of(float(stats.get("seed", 0.0))).display(),
		Money.of(float(stats.get("fortune", 0.0))).display(),
	]
	_obituary_summary_label.text = summary

	_phase0_container.visible = true
	_phase1_container.visible = false
	_phase2_container.visible = false
	visible = true


## Show phase 1: the itemized will for the dying generation.
## `will` keys (all floats unless noted):
##   estate_gross   — total accumulated wealth
##   creditors_paid — debts settled before the estate passes
##   after_credit   — subtotal after creditors
##   taxable        — the taxable portion (used by the tax calculation upstream)
##   tax            — estate tax amount withheld
##   estate_net     — cash the heir actually receives
##   legacy_gain    — integer legacy points awarded (treat as int)
## `dying_dynasty_name` — e.g. "Wellington Pemberton VIII"
func show_will(will: Dictionary, dying_dynasty_name: String) -> void:
	_deceased_label.text = "The estate of %s" % dying_dynasty_name

	# Format money amounts; deductions are prefixed with a minus sign so the
	# document reads like a real ledger (loss lines include the − in the string).
	_gross_value.text    = Money.of(will.estate_gross).display()
	_creditors_value.text = "−%s" % Money.of(will.creditors_paid).display()
	_subtotal_value.text = Money.of(will.after_credit).display()
	_tax_value.text      = "−%s" % Money.of(will.tax).display()
	_net_value.text      = Money.of(will.estate_net).display()

	# Legacy is a points integer, not a dollar figure — shown plainly with a + sign.
	_legacy_value.text   = "+%d" % int(will.legacy_gain)

	_phase0_container.visible = false
	_phase1_container.visible = true
	_phase2_container.visible = false
	visible = true


## Show phase 2: reveal the heir who inherits.
## `heir_dynasty_name` — e.g. "Wellington Pemberton IX"
## `generation`        — the new 1-based generation number
func show_heir_reveal(heir_dynasty_name: String, generation: int) -> void:
	_heir_name_label.text   = heir_dynasty_name
	# Deadpan subline: acknowledges the ceremony is perfunctory, which is the joke.
	_generation_label.text  = "Generation %d — the family office handles the paperwork now." % generation

	_phase0_container.visible = false
	_phase1_container.visible = false
	_phase2_container.visible = true
	# Overlay stays visible; it was already shown during phase 1.
	visible = true


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_obituary_continue_pressed() -> void:
	# Do NOT hide here. Main.gd will immediately call show_will(), swapping the
	# overlay from phase 0 to phase 1 without a flash of the game beneath.
	continue_to_will.emit()


func _on_sign_pressed() -> void:
	# Do NOT hide here. Main.gd will immediately call show_heir_reveal(),
	# which transitions the overlay to phase 2 without a flash of the game.
	pass_on_confirmed.emit()


func _on_cancel_pressed() -> void:
	# Close the will with no state change; the living generation simply resumes.
	visible = false
	cancelled.emit()


func _on_begin_pressed() -> void:
	visible = false
	heir_begin_pressed.emit()


# ── Layout helpers ────────────────────────────────────────────────────────────

# Creates one two-column document row: description on the left, value on the
# right. Returns the value Label so the caller can populate it in show_will().
func _add_document_row(parent: VBoxContainer, description: String, value_color: Color, value_size: int) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", UiPalette.NAVY)
	desc_label.add_theme_font_size_override("font_size", value_size)
	row.add_child(desc_label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_color_override("font_color", value_color)
	value_label.add_theme_font_size_override("font_size", value_size)
	row.add_child(value_label)

	return value_label


# Adds a thin visual rule between the subtotal block and the net-to-heir line.
# A one-pixel ColorRect in NAVY gives the same visual weight as a <hr> in print.
func _add_divider(parent: VBoxContainer) -> void:
	var divider := ColorRect.new()
	divider.color = UiPalette.NAVY
	divider.custom_minimum_size = Vector2(0, 2)
	parent.add_child(divider)
