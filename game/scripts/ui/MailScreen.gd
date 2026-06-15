class_name MailScreen
extends ColorRect

# The mailbox (GDD §8.6, Mechanics Spec §10 delivery rule). Credit offers and
# debt-payment notices arrive here as mail — the game never pings or nags
# (Principle 5); the player discovers mail by choosing to open it. A pending offer
# expires silently if ignored; a due payment shows its remaining grace.
#
# Full-screen page (same convention as the other overlays). It is rebuilt from the
# live state on every open() and again after each action, so it always reflects
# what is currently pending.
#
# Drive it from Main.gd:
#   1. setup()                              once, to build the static chrome
#   2. open(offer, due, grace, can_afford)  to show / refresh it
#   3. listen for accept_offer / decline_offer / pay_debt → mutate state, re-open
#   4. listen for closed                    resume the game


signal accept_offer
signal decline_offer
signal pay_debt
signal closed


const TITLE_SIZE := 75
const CARD_TITLE_SIZE := 44
const BODY_SIZE := 32
const BUTTON_SIZE := 34
const CAMERA_CUTOUT_INSET := 130


# The list the offer/due cards are rebuilt into on every open().
var _list: VBoxContainer


func setup() -> void:
	_build_chrome()


func _ready() -> void:
	color = UiPalette.CREAM
	visible = false


func _build_chrome() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", CAMERA_CUTOUT_INSET)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Mail"
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	UiPalette.allow_scroll_drag_through(_list)

	var close_button := Button.new()
	close_button.text = "BACK TO THE EMPIRE"
	close_button.custom_minimum_size = Vector2(0, 158)
	close_button.add_theme_font_size_override("font_size", 48)
	UiPalette.style_button(close_button, false)
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)


## (Re)build the mail from the current state and show the page.
##   offer       — the pending LoanTier, or null
##   due_amount  — the debt payment due now, or 0.0
##   grace       — active-play seconds left to pay the due amount
##   can_afford  — whether the player can currently pay the due amount
func open(offer: LoanTier, due_amount: float, grace: float, can_afford: bool) -> void:
	for child in _list.get_children():
		child.queue_free()

	if due_amount > 0.0:
		_add_due_card(due_amount, grace, can_afford)
	if offer != null:
		_add_offer_card(offer)
	if due_amount <= 0.0 and offer == null:
		var empty := Label.new()
		empty.text = "No mail today. Old money waits."
		empty.add_theme_color_override("font_color", UiPalette.NAVY)
		empty.add_theme_font_size_override("font_size", BODY_SIZE)
		_list.add_child(empty)

	visible = true


# ── A due-payment notice ──────────────────────────────────────────────────────

func _add_due_card(amount: float, grace: float, can_afford: bool) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	_list.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var heading := Label.new()
	heading.text = "PAYMENT DUE"
	heading.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	heading.add_theme_font_size_override("font_size", CARD_TITLE_SIZE)
	col.add_child(heading)

	var body := Label.new()
	body.text = "Your success has been noticed. %s is due — settle it within about %d seconds of play, or the creditors will." % [
		Money.of(amount).display(), int(ceil(grace)),
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", UiPalette.NAVY)
	body.add_theme_font_size_override("font_size", BODY_SIZE)
	col.add_child(body)

	var pay_button := Button.new()
	pay_button.text = "PAY %s" % Money.of(amount).display() if can_afford else "CAN'T AFFORD YET"
	pay_button.custom_minimum_size = Vector2(0, 110)
	pay_button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(pay_button, true)
	pay_button.disabled = not can_afford
	pay_button.pressed.connect(_on_pay_pressed)
	col.add_child(pay_button)


# ── A credit offer ────────────────────────────────────────────────────────────

func _add_offer_card(offer: LoanTier) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_panel_style())
	_list.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var heading := Label.new()
	heading.text = offer.tier_name
	heading.add_theme_color_override("font_color", UiPalette.NAVY)
	heading.add_theme_font_size_override("font_size", CARD_TITLE_SIZE)
	col.add_child(heading)

	var flavor := Label.new()
	flavor.text = offer.flavor
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_color_override("font_color", UiPalette.NAVY)
	flavor.add_theme_font_size_override("font_size", BODY_SIZE)
	col.add_child(flavor)

	var terms := Label.new()
	terms.text = "Receive %s now. Repay %s over %d payments as you grow." % [
		Money.of(offer.principal).display(),
		Money.of(offer.principal * offer.interest_multiplier).display(),
		offer.payment_count,
	]
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	terms.add_theme_font_size_override("font_size", BODY_SIZE)
	col.add_child(terms)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)

	var accept := Button.new()
	accept.text = "ACCEPT"
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.custom_minimum_size = Vector2(0, 110)
	accept.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(accept, true)
	accept.pressed.connect(_on_accept_pressed)
	buttons.add_child(accept)

	var decline := Button.new()
	decline.text = "DECLINE"
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline.custom_minimum_size = Vector2(0, 110)
	decline.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(decline, false)
	decline.pressed.connect(_on_decline_pressed)
	buttons.add_child(decline)


# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_accept_pressed() -> void:
	accept_offer.emit()


func _on_decline_pressed() -> void:
	decline_offer.emit()


func _on_pay_pressed() -> void:
	pay_debt.emit()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
