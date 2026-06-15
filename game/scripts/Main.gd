extends Control

# Main screen driver (M1 brief §4: the one screen). Owns the GameState,
# advances it on a fixed timestep, autosaves, applies offline earnings on
# launch, and wires every UI verb into GameState.
#
# Logic ticks run at a fixed rate (LOGIC_HZ, Spec §2) regardless of frame
# rate; rendering and UI refresh happen per-frame and only read state.
# (Unity analogue: FixedUpdate for logic, Update for presentation — except
# Godot has no built-in fixed update for _process, so we accumulate.)

# The dynasty owns the whole bloodline (total Legacy, the generation counter,
# succession) and holds the living generation as `dynasty.current`. Every UI verb
# acts on that living generation, so `game` is kept as a direct handle to it.
var dynasty: DynastyState
var game: GameState
var tuning: TuningConfig

var _tick_accumulator := 0.0
var _autosave_timer := 0.0

var _dynasty_header: DynastyHeader
var _hero_stat: HeroStat
var _frenzy_bar: FrenzyBar
var _wage_panel: WagePanel
var _welcome_overlay: WelcomeBackOverlay
var _will_screen: WillScreen
var _legacy_screen: LegacyScreen
var _ledger_screen: FamilyLedgerScreen
var _mail_screen: MailScreen
var _origin_screen: OriginScreen
var _buy_mode_button: Button
var _plan_button: Button
var _legacy_button: Button
var _ledger_button: Button
var _mail_button: Button

## True while the ceremony in progress is a forced bankruptcy (a defaulted debt),
## so the will records the "Creditors" cause and offers no escape (GDD §8.5).
var _bankruptcy_pending: bool = false
var _rows: Array = []

## Global buy mode — one toggle drives every row's buy button.
var _buy_mode: PropertyRow.BuyMode = PropertyRow.BuyMode.ONE

## Wall-clock seconds since the loaded save was written (0 on a fresh run).
var _elapsed_since_save := 0.0


func _ready() -> void:
	_create_game()
	_build_ui()
	_apply_offline_if_due()

	# A brand-new dynasty meets the origin screen first (GDD §8.1). _process freezes
	# the economy while it is up, so the founder's opening cash is chosen before any
	# play. A loaded dynasty has origin_chosen = true and skips straight to the game.
	if not dynasty.origin_chosen:
		_origin_screen.show_origin()


func _process(delta: float) -> void:
	# Freeze the economy while a full-screen overlay is up (the succession
	# ceremony or the upgrade shop): no ticks, no autosave. This keeps the will's
	# numbers from shifting under the player, avoids half-saving the generation
	# swap mid-ceremony, and lets the shop spend Legacy against a steady balance.
	if _will_screen.visible or _legacy_screen.visible or _ledger_screen.visible \
			or _mail_screen.visible or _origin_screen.visible:
		return

	# Fixed-timestep logic (Spec §2): accumulate render time and tick in
	# constant steps so the economy math is framerate-independent. Ticking the
	# dynasty (not the bare generation) applies the Legacy multiplier to property
	# income — the dynastic acceleration that makes each heir faster (Spec §9.4).
	var step := 1.0 / float(tuning.logic_hz)
	_tick_accumulator += delta
	while _tick_accumulator >= step:
		dynasty.tick(step)
		_tick_accumulator -= step

	# A defaulted debt forces the bankruptcy generation-end (GDD §8.5). Detected
	# right after ticking; showing the ceremony freezes the economy on the next frame.
	if game.debt.defaulted:
		_begin_bankruptcy()
		return

	_autosave_timer += delta
	if _autosave_timer >= tuning.autosave_cadence:
		_autosave_timer = 0.0
		SaveManager.save_dict_to_file(dynasty.to_save_dict())

	# Headline income/sec: the guaranteed staffed floor plus a smoothed bonus from
	# active play (rushes, wage taps, frenzy). Built in GameState so it never reads
	# below the income staffed properties keep earning hands-off.
	_hero_stat.set_income_per_sec(game.displayed_income_per_sec)
	_hero_stat.set_cash(game.economy.cash)
	_hero_stat.set_frenzy_glow(game.frenzy.get_multiplier() > 1.0)

	# Dynastic identity strip shows the spendable Legacy wallet; the prestige-exit
	# button and the Estate Office button reflect the live state.
	_dynasty_header.set_dynasty(HeirNames.dynasty_name(dynasty.generation), dynasty.upgrades.available)
	_update_plan_button()
	_update_legacy_button()
	_update_ledger_button()
	_update_mail_button()


func _notification(what: int) -> void:
	# Save on backgrounding (phone) and on close (desktop) — Spec §12.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if dynasty != null:
			SaveManager.save_dict_to_file(dynasty.to_save_dict())


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

func _create_game() -> void:
	tuning = ConfigLoader.load_tuning()
	var property_configs := ConfigLoader.load_property_configs()
	var titles := ConfigLoader.load_title_configs()
	var loan_tiers := ConfigLoader.load_loan_tiers()

	# Constructing the dynasty also builds generation 1, already seeded with
	# starting cash by DynastyState. So, unlike the old bare-GameState path, a
	# fresh game needs no extra award_cash here.
	dynasty = DynastyState.new(property_configs, titles, tuning, loan_tiers)

	var save_dict := SaveManager.load_from_file()
	if not save_dict.is_empty():
		# Loads both the new dynastic save and a legacy bare-generation save: a
		# bare M1 save reconstructs as a clean generation-1 dynasty (see
		# DynastyState.load_save_dict).
		dynasty.load_save_dict(save_dict)
		_elapsed_since_save = _seconds_since_save(save_dict)

	# The UI verbs all act on the living generation; keep a direct handle to it.
	game = dynasty.current

	# Restore the saved buy-mode preference (defaults to ×1 for a fresh game).
	_buy_mode = game.ui_buy_mode as PropertyRow.BuyMode


## Wall-clock seconds since the save was written. The dynastic save nests the
## generation (which carries the saved_at_unix timestamp) under "current"; a
## legacy bare-generation save carries that timestamp at the top level. Read it
## from wherever it actually lives.
func _seconds_since_save(save_dict: Dictionary) -> float:
	var stamped: Dictionary = save_dict.get("current", save_dict)
	return SaveManager.get_seconds_since_save(stamped)


func _apply_offline_if_due() -> void:
	if _elapsed_since_save <= 0.0:
		return
	# Offline earnings accrue to the living generation at the staffed rate. They do
	# NOT yet receive the dynasty's Legacy multiplier (OfflineCalculator predates
	# the dynasty layer); folding Legacy into offline accrual is a later refinement.
	var offline := game.apply_offline(_elapsed_since_save)
	# The ritual only plays when a pile actually accrued (staffed income).
	if offline.pile > 0.0:
		_welcome_overlay.show_pile(offline.pile, offline.elapsed_seconds / 3600.0)


# ---------------------------------------------------------------------------
# UI construction (placeholder chrome — hero art and fonts arrive in M3)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = UiPalette.CREAM
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	# Dynastic identity strip at the very top: heir name + total Legacy (GDD §13).
	_dynasty_header = DynastyHeader.new()
	column.add_child(_dynasty_header)

	_hero_stat = HeroStat.new()
	column.add_child(_hero_stat)

	_frenzy_bar = FrenzyBar.new()
	_frenzy_bar.setup(game.frenzy, tuning)
	_frenzy_bar.pop_requested.connect(_on_pop_requested)
	column.add_child(_frenzy_bar)

	# Global buy-mode toggle: one button cycles ×1 → ×10 → UPGRADE → MAX
	# and every row's buy button follows it (GDD §3.1 bulk-buy requirement).
	var toggle_line := HBoxContainer.new()
	column.add_child(toggle_line)

	# Temporary play-testing tool: wipe the save and restart from a clean slate.
	# Sits on the left of the buy-mode toggle for now; it will move into a proper
	# settings screen later (Tim's note). Red because it is a destructive action.
	var reset_button := Button.new()
	reset_button.custom_minimum_size = Vector2(150, 56)
	reset_button.add_theme_font_size_override("font_size", 20)
	UiPalette.style_button(reset_button, true)
	reset_button.text = "RESET"
	reset_button.pressed.connect(_on_reset_requested)
	toggle_line.add_child(reset_button)

	var toggle_spacer := Control.new()
	toggle_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_line.add_child(toggle_spacer)

	_buy_mode_button = Button.new()
	_buy_mode_button.custom_minimum_size = Vector2(320, 56)
	_buy_mode_button.add_theme_font_size_override("font_size", 24)
	UiPalette.style_button(_buy_mode_button, false)
	_buy_mode_button.text = "BUY MODE: " + _buy_mode_caption(_buy_mode)
	_buy_mode_button.pressed.connect(_on_buy_mode_toggled)
	toggle_line.add_child(_buy_mode_button)

	# The property ladder: 12 rows in a vertical scroll (GDD §2: a vertical
	# ladder scrolled upward as you ascend).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Reserve the vertical scrollbar's width permanently so the rows never reflow when
	# it appears or disappears (Godot 4.4+ RESERVE: the space is always held, but the
	# bar itself only shows when there's something to scroll).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	column.add_child(scroll)

	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 10)
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ladder)

	for i in range(game.economy.properties.size()):
		var row := PropertyRow.new()
		row.setup(i, game.economy.properties[i] as PropertyState, game.economy, game.frenzy)
		row.buy_requested.connect(_on_buy_requested)
		row.tap_requested.connect(_on_tap_requested)
		row.hold_rush_requested.connect(_on_hold_rush_requested)
		row.hire_requested.connect(_on_hire_requested)
		row.set_buy_mode(_buy_mode)  # apply the restored buy-mode preference
		ladder.add_child(row)
		_rows.append(row)

	_wage_panel = WagePanel.new()
	_wage_panel.setup(game.wage, game.economy, tuning, game.frenzy)
	_wage_panel.wage_tapped.connect(_on_wage_tapped)
	_wage_panel.wage_hold_tapped.connect(_on_wage_hold_tapped)
	_wage_panel.promotion_requested.connect(_on_promotion_requested)
	column.add_child(_wage_panel)

	# The prestige exit: plan the estate, pass on, and raise a faster heir. Red
	# because it is the big commit action (§8). It stays disabled until dying
	# would actually grow the dynasty (dynasty.can_perform_succession()), and its
	# label then previews the Legacy gain — see _update_plan_button.
	_plan_button = Button.new()
	_plan_button.custom_minimum_size = Vector2(0, 72)
	_plan_button.add_theme_font_size_override("font_size", 26)
	UiPalette.style_button(_plan_button, true)
	_plan_button.text = "PLAN THE ESTATE"
	_plan_button.pressed.connect(_on_plan_estate_pressed)
	column.add_child(_plan_button)

	# The Estate Office: enter the Legacy upgrade shop to spend banked Legacy. It
	# is hidden until the player's first prestige — there is nothing to spend and
	# no shop to enter before then — and revealed for good once Legacy is earned
	# (see _update_legacy_button). Gold styling marks it as the prestige reward.
	_legacy_button = Button.new()
	_legacy_button.custom_minimum_size = Vector2(0, 64)
	_legacy_button.add_theme_font_size_override("font_size", 24)
	UiPalette.style_button(_legacy_button, false)
	_legacy_button.text = "THE ESTATE OFFICE"
	_legacy_button.pressed.connect(_on_estate_office_pressed)
	_legacy_button.visible = false
	column.add_child(_legacy_button)

	# The Family Ledger: re-read the obituaries of every past generation. Hidden
	# until the first ancestor exists (nothing to show on generation 1), then shown
	# for good (see _update_ledger_button). Calm mustard style — it is a reading
	# page, not a spend/commit action.
	_ledger_button = Button.new()
	_ledger_button.custom_minimum_size = Vector2(0, 64)
	_ledger_button.add_theme_font_size_override("font_size", 24)
	UiPalette.style_button(_ledger_button, false)
	_ledger_button.text = "THE FAMILY LEDGER"
	_ledger_button.pressed.connect(_on_family_ledger_pressed)
	_ledger_button.visible = false
	column.add_child(_ledger_button)

	# Mail: credit offers and debt notices. Hidden when the box is empty (the game
	# never nags — Principle 5); its label flips to red and shows the grace countdown
	# when a payment is due, so the one urgent thing is impossible to miss without
	# the game ever interrupting play. See _update_mail_button.
	_mail_button = Button.new()
	_mail_button.custom_minimum_size = Vector2(0, 64)
	_mail_button.add_theme_font_size_override("font_size", 24)
	UiPalette.style_button(_mail_button, false)
	_mail_button.text = "MAIL"
	_mail_button.pressed.connect(_on_mail_pressed)
	_mail_button.visible = false
	column.add_child(_mail_button)

	# The welcome-back overlay sits above everything and starts hidden.
	_welcome_overlay = WelcomeBackOverlay.new()
	_welcome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_welcome_overlay)

	# The succession ceremony overlay (the Reading of the Will + heir reveal),
	# also above everything and hidden until the player plans the estate.
	_will_screen = WillScreen.new()
	_will_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_will_screen.continue_to_will.connect(_on_continue_to_will)
	_will_screen.pass_on_confirmed.connect(_on_pass_on_confirmed)
	_will_screen.heir_begin_pressed.connect(_on_heir_begin_pressed)
	_will_screen.cancelled.connect(_on_will_cancelled)
	add_child(_will_screen)

	# The Legacy upgrade shop overlay, also above everything and hidden until the
	# player opens the Estate Office. It reads/writes the dynasty's upgrade state.
	_legacy_screen = LegacyScreen.new()
	_legacy_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_legacy_screen.setup(dynasty.upgrades)
	_legacy_screen.purchased.connect(_on_upgrade_purchased)
	_legacy_screen.closed.connect(_on_legacy_screen_closed)
	add_child(_legacy_screen)

	# The Family Ledger overlay, also above everything and hidden until opened.
	# Its rows are rebuilt from the dynasty's ancestor list each time it opens.
	_ledger_screen = FamilyLedgerScreen.new()
	_ledger_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ledger_screen.setup()
	_ledger_screen.closed.connect(_on_family_ledger_closed)
	add_child(_ledger_screen)

	# The mailbox overlay (offers + debt notices), rebuilt from live state on open.
	_mail_screen = MailScreen.new()
	_mail_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mail_screen.setup()
	_mail_screen.accept_offer.connect(_on_offer_accepted)
	_mail_screen.decline_offer.connect(_on_offer_declined)
	_mail_screen.pay_debt.connect(_on_debt_paid)
	_mail_screen.closed.connect(_on_mail_closed)
	add_child(_mail_screen)

	# The origin overlay ("rich parents?"), shown once at the start of a new dynasty.
	_origin_screen = OriginScreen.new()
	_origin_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_origin_screen.chosen.connect(_on_origin_chosen)
	add_child(_origin_screen)


# ---------------------------------------------------------------------------
# UI verb handlers — every player action flows through GameState
# ---------------------------------------------------------------------------

func _on_buy_requested(prop_index: int, mode: PropertyRow.BuyMode) -> void:
	var prop := game.economy.properties[prop_index] as PropertyState
	var count := 0
	match mode:
		PropertyRow.BuyMode.ONE:
			count = 1
		PropertyRow.BuyMode.TEN:
			count = 10
		PropertyRow.BuyMode.HUNDRED:
			count = 100
		PropertyRow.BuyMode.MAX:
			count = prop.get_max_affordable(game.economy.cash)
	if count <= 0:
		return

	if game.try_buy(prop_index, count):
		_hero_stat.flash_purchase()


func _on_tap_requested(prop_index: int) -> void:
	game.tap_property(prop_index)


func _on_hold_rush_requested(prop_index: int) -> void:
	game.hold_rush_property(prop_index)


func _on_hire_requested(prop_index: int) -> void:
	game.try_hire(prop_index)


func _on_wage_tapped() -> void:
	game.tap_wage()


func _on_wage_hold_tapped() -> void:
	game.hold_tap_wage()


func _on_promotion_requested() -> void:
	game.try_claim_promotion()


func _on_pop_requested() -> void:
	game.pop_frenzy()


## Temporary play-testing reset: delete the save and reload the scene, which
## re-runs startup with no save present and so begins a fresh run.
func _on_reset_requested() -> void:
	SaveManager.delete_save_file()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------------------
# Succession — the prestige loop (Spec §9, GDD §13)
# ---------------------------------------------------------------------------

## Refresh the Plan-the-Estate button: enabled only when dying would convert to
## at least 1 Legacy, and labeled with the Legacy it would yield right now.
func _update_plan_button() -> void:
	var can_succeed := dynasty.can_perform_succession()
	_plan_button.disabled = not can_succeed
	if can_succeed:
		_plan_button.text = "PLAN THE ESTATE  (+%d Legacy)" % dynasty.projected_legacy_gain()
	else:
		_plan_button.text = "PLAN THE ESTATE"


## Reveal the Estate Office button once the dynasty has ever earned Legacy — i.e.
## from the first prestige onward. earned_lifetime never falls back to 0, so once
## shown the button stays for good (even after the wallet is spent down to 0).
func _update_legacy_button() -> void:
	_legacy_button.visible = dynasty.upgrades.earned_lifetime > 0


## Reveal the Family Ledger button once there is at least one ancestor to read
## about (nothing to show on generation 1). Once shown, it stays — the ancestor
## list only ever grows.
func _update_ledger_button() -> void:
	_ledger_button.visible = not dynasty.ancestors.is_empty()


## Player opened the Family Ledger: populate it from the dynasty's ancestor list
## and the lifetime-earned total, then show it.
func _on_family_ledger_pressed() -> void:
	_ledger_screen.open(dynasty.ancestors, dynasty.lifetime_cash_earned)


## Player closed the Family Ledger: nothing to persist (it is read-only), the game
## simply resumes ticking on the next frame.
func _on_family_ledger_closed() -> void:
	pass


# ---------------------------------------------------------------------------
# Mail — credit offers and debt notices (GDD §8.6)
# ---------------------------------------------------------------------------

## Reveal the Mail button when something is waiting (an offer or a due payment),
## and make a due payment unmissable: its label turns urgent and shows the grace
## countdown. The game still never interrupts play — the player chooses to open it.
func _update_mail_button() -> void:
	var due := game.debt.due_amount > 0.0
	var has_mail := due or game.offers.has_offer()
	_mail_button.visible = has_mail
	if not has_mail:
		return
	if due:
		_mail_button.text = "MAIL — PAYMENT DUE (%ds)" % int(ceil(game.debt.grace_remaining))
		UiPalette.style_button(_mail_button, true)  # red: act now
	else:
		_mail_button.text = "MAIL"
		UiPalette.style_button(_mail_button, false)


func _on_mail_pressed() -> void:
	_open_mail()


## (Re)open the mailbox against the current offer/debt state.
func _open_mail() -> void:
	_mail_screen.open(
		game.offers.current_offer,
		game.debt.due_amount,
		game.debt.grace_remaining,
		game.debt.can_pay(game.economy),
	)


## Accepted the pending offer: take the loan, persist, and refresh the mailbox.
func _on_offer_accepted() -> void:
	game.accept_offer()
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	_open_mail()


## Declined the pending offer: it expires silently; refresh the mailbox.
func _on_offer_declined() -> void:
	game.decline_offer()
	_open_mail()


## Paid the due debt payment: persist and refresh the mailbox.
func _on_debt_paid() -> void:
	game.pay_due_debt()
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	_open_mail()


## Closed the mailbox: persist (offer/debt state may have changed) and resume.
func _on_mail_closed() -> void:
	SaveManager.save_dict_to_file(dynasty.to_save_dict())


# ---------------------------------------------------------------------------
# Origins (GDD §8.1) and bankruptcy (GDD §8.5)
# ---------------------------------------------------------------------------

## The founder picked an origin: seed the opening cash (and any origin debt) onto
## generation 1, then persist so the screen never shows again for this dynasty.
func _on_origin_chosen(starting_cash: float, debt_loan: LoanTier) -> void:
	dynasty.apply_origin(starting_cash, debt_loan)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())


## A debt payment lapsed: open the ceremony on the obituary, flagged as a forced
## bankruptcy. The will that follows seizes the estate for creditors and offers no
## escape; the generation is recorded in the Family Ledger as ending in "Creditors".
func _begin_bankruptcy() -> void:
	_bankruptcy_pending = true
	_will_screen.show_obituary({
		"name": HeirNames.dynasty_name(dynasty.generation),
		"fortune": dynasty.current.economy.cash_earned_this_gen,
		"seed": dynasty.current.economy.starting_cash,
		"employees": _count_staffed_properties(),
	})


## Player opened the Estate Office: show the upgrade shop. It refreshes itself
## against the current Legacy wallet on open.
func _on_estate_office_pressed() -> void:
	_legacy_screen.open()


## An upgrade was just bought in the shop. Apply its effect to the living
## generation immediately (faster cycles / cheaper staff / fatter wage take hold
## mid-life) and persist, so a purchase is never lost to a crash before autosave.
func _on_upgrade_purchased(_upgrade_id: String) -> void:
	dynasty.refresh_current_generation_effects()
	SaveManager.save_dict_to_file(dynasty.to_save_dict())


## Player closed the shop: persist and let the game resume on the next frame.
func _on_legacy_screen_closed() -> void:
	SaveManager.save_dict_to_file(dynasty.to_save_dict())


## Player opened the estate planner: open the ceremony on the obituary (beat 1),
## assembled from the dying generation's real stats (GDD §8.3). The will follows
## when the player taps through.
func _on_plan_estate_pressed() -> void:
	# Gated defensively even though the button is disabled when this is false.
	if not dynasty.can_perform_succession():
		return
	_will_screen.show_obituary({
		"name": HeirNames.dynasty_name(dynasty.generation),
		"fortune": dynasty.current.economy.cash_earned_this_gen,
		"seed": dynasty.current.economy.starting_cash,
		"employees": _count_staffed_properties(),
	})


## Player tapped through the obituary: show the itemized will (ceremony beat 2). A
## bankruptcy will offers no escape — the default cannot be walked back.
func _on_continue_to_will() -> void:
	var will := dynasty.get_draft_will()
	_will_screen.show_will(
		will, HeirNames.dynasty_name(dynasty.generation), not _bankruptcy_pending
	)


## How many of the living generation's properties are staffed — the obituary's
## "beloved employer of N" figure (its standing payroll, GDD §8.3).
func _count_staffed_properties() -> int:
	var staffed := 0
	for prop in game.economy.properties:
		if (prop as PropertyState).is_staffed:
			staffed += 1
	return staffed


## Player backed out of the will: it has already hidden itself, so there is
## nothing to undo — _process simply resumes ticking the living generation.
func _on_will_cancelled() -> void:
	pass


## Player signed the will: execute the death — bank Legacy, advance the
## generation, raise the heir — then reveal who inherits.
func _on_pass_on_confirmed() -> void:
	# A bankruptcy records "Creditors"; a chosen prestige is a natural death.
	var cause := "Creditors" if _bankruptcy_pending else "Retired to Palm Beach"
	dynasty.perform_succession(cause)
	_bankruptcy_pending = false
	_will_screen.show_heir_reveal(HeirNames.dynasty_name(dynasty.generation), dynasty.generation)


## Player dismissed the heir reveal: persist the new dynasty state, then reload
## the scene so the whole UI rebinds cleanly to the freshly-born generation
## (the same proven path as startup). Reloading avoids hand-re-wiring every
## property row, the wage panel, and the frenzy bar to the heir's new objects.
func _on_heir_begin_pressed() -> void:
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	get_tree().reload_current_scene()


func _on_buy_mode_toggled() -> void:
	_buy_mode = ((_buy_mode + 1) % PropertyRow.BuyMode.size()) as PropertyRow.BuyMode
	game.ui_buy_mode = _buy_mode  # persisted on the next autosave / on background
	_buy_mode_button.text = "BUY MODE: " + _buy_mode_caption(_buy_mode)
	for row in _rows:
		(row as PropertyRow).set_buy_mode(_buy_mode)


func _buy_mode_caption(mode: PropertyRow.BuyMode) -> String:
	match mode:
		PropertyRow.BuyMode.ONE:
			return "×1"
		PropertyRow.BuyMode.TEN:
			return "×10"
		PropertyRow.BuyMode.HUNDRED:
			return "×100"
		PropertyRow.BuyMode.MAX:
			return "MAX"
	return "×1"
