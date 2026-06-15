class_name OriginScreen
extends ColorRect

# The opening — "Do you have rich parents?" (GDD §8.1). Class origin as character
# creation, shown once at the very start of a brand-new dynasty. Mechanically a
# difficulty selector disguised as a birth lottery: there is no path where the
# first dollar was earned — even the bootstrapper starts with a government check.
#
# Full-screen page (same convention as LegacyScreen / FamilyLedgerScreen). Each
# choice emits `chosen` with the founder's opening cash and, for the two loan
# origins, the debt template to install. Main applies it via DynastyState.apply_origin.


## The player picked an origin. `starting_cash` seeds the founder; `debt_loan` is the
## origin debt template (null for the two cash-only origins).
signal chosen(starting_cash: float, debt_loan: LoanTier)


const TITLE_SIZE := 64
const PROMPT_SIZE := 34
const OPTION_TITLE_SIZE := 40
const OPTION_BODY_SIZE := 28
const CAMERA_CUTOUT_INSET := 130

# The four origins (GDD §8.1). Loan origins hand over the cash AND owe it back; the
# interest multiplier is the only difference between the two loan paths.
const ORIGIN_NO_PARENTS := 1000.0
const ORIGIN_GIFT := 50000.0
const ORIGIN_INTEREST_FREE := 200000.0
const ORIGIN_HIGH_INTEREST := 500000.0
const HIGH_INTEREST_MULTIPLIER := 1.6


func _ready() -> void:
	color = UiPalette.CREAM
	visible = false
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", CAMERA_CUTOUT_INSET)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	var title := Label.new()
	title.text = "Do you have rich parents?"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)

	var prompt := Label.new()
	prompt.text = "Every great fortune begins with a choice. Yours begins here."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", UiPalette.NAVY)
	prompt.add_theme_font_size_override("font_size", PROMPT_SIZE)
	column.add_child(prompt)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)

	# Let a swipe over the option cards scroll the list, as elsewhere.
	UiPalette.allow_scroll_drag_through(column)

	# ── The four origins ──
	_add_option(
		column, "No.",
		"A $1,000 tax rebate, and a lecture about government handouts. Pull yourself up.",
		"START WITH $1,000",
		ORIGIN_NO_PARENTS, null)

	_add_option(
		column, "Yes — a gift.",
		"\"Your parents really want you to earn your way through life.\" A modest $50,000 to begin.",
		"START WITH $50,000",
		ORIGIN_GIFT, null)

	_add_option(
		column, "Yes — an interest-free loan.",
		"$200,000 of family money, to be repaid in full as your fortune grows. No interest, between family.",
		"START WITH $200,000 (DEBT)",
		ORIGIN_INTEREST_FREE, _make_origin_loan(ORIGIN_INTEREST_FREE, 1.0))

	_add_option(
		column, "Yes — a high-interest loan.",
		"$500,000 now, on terms a family friend was kind enough to arrange. The vig is steep.",
		"START WITH $500,000 (DEBT)",
		ORIGIN_HIGH_INTEREST, _make_origin_loan(ORIGIN_HIGH_INTEREST, HIGH_INTEREST_MULTIPLIER))


## One origin card: title + deadpan blurb, then a button that commits the choice.
func _add_option(
		parent: VBoxContainer, option_title: String, blurb: String,
		button_text: String, starting_cash: float, debt_loan: LoanTier) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	parent.add_child(card)

	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 8)
	card.add_child(card_column)

	var name_label := Label.new()
	name_label.text = option_title
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	name_label.add_theme_font_size_override("font_size", OPTION_TITLE_SIZE)
	card_column.add_child(name_label)

	var blurb_label := Label.new()
	blurb_label.text = blurb
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.add_theme_color_override("font_color", UiPalette.NAVY)
	blurb_label.add_theme_font_size_override("font_size", OPTION_BODY_SIZE)
	card_column.add_child(blurb_label)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 96)
	button.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(button, true)  # red: this is the commit action
	button.pressed.connect(_on_option_pressed.bind(starting_cash, debt_loan))
	card_column.add_child(button)


## Build an origin debt template: the founder receives `amount` cash and owes it
## back (× interest) on the standard milestone schedule.
func _make_origin_loan(amount: float, interest_multiplier: float) -> LoanTier:
	var loan := LoanTier.new()
	loan.tier_name = "Family Loan"
	loan.principal = amount
	loan.interest_multiplier = interest_multiplier
	loan.payment_count = 3
	loan.first_trigger_multiple = 3.0
	loan.trigger_step_multiple = 3.0
	return loan


func show_origin() -> void:
	visible = true


func _on_option_pressed(starting_cash: float, debt_loan: LoanTier) -> void:
	visible = false
	chosen.emit(starting_cash, debt_loan)
