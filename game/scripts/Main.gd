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

var _hero_stat: HeroStat
## Small banner under the hero stat naming the civilization Earth is currently trading
## with (the reached epoch). Updates the moment a first contact advances the epoch.
var _epoch_label: Label
var _first_contact_overlay: FirstContactOverlay
var _frenzy_bar: FrenzyBar
var _wage_panel: WagePanel
var _welcome_overlay: WelcomeBackOverlay
var _will_screen: WillScreen
var _legacy_screen: LegacyScreen
var _ledger_screen: FamilyLedgerScreen
var _dev_panel: DevTuningPanel
var _minigame_screen: MinigameScreen
var _buy_mode_button: Button
var _plan_button: Button
var _legacy_button: Button
## Gold "LEGACY: N" balance pinned to the right end of the Estate Office button.
var _legacy_balance_label: Label
var _rows: Array = []

# Bottom tab bar (UI Notes §7). The four surfaces share one content slot; one is
# visible at a time, switched by the icon buttons pinned along the bottom.
const TAB_PROPERTY := 0
const TAB_ESTATE := 1
const TAB_SETTINGS := 2
const TAB_LEDGER := 3
var _tab_content: Control
var _tab_panels: Array = []   # the four content Controls, indexed by TAB_*
var _tab_buttons: Array = []  # the four bottom icon Buttons, indexed by TAB_*
var _active_tab: int = TAB_PROPERTY
var _minigame_check: CheckBox  # the Settings-tab "play the minigame" toggle

## Global buy mode — one toggle drives every row's buy button.
var _buy_mode: PropertyRow.BuyMode = PropertyRow.BuyMode.ONE

## Wall-clock seconds since the loaded save was written (0 on a fresh run).
var _elapsed_since_save := 0.0


func _ready() -> void:
	_create_game()
	_build_ui()
	_apply_offline_if_due()


func _process(delta: float) -> void:
	# Freeze the economy while a full-screen MODAL overlay is up (the succession
	# ceremony, the upgrade shop, the minigame, etc.): no ticks, no autosave. This keeps
	# the will's numbers steady, avoids half-saving the generation swap mid-ceremony, and
	# lets the shop spend Legacy against a steady balance. NOTE: switching TABS does NOT
	# freeze — an idle game keeps earning no matter which tab you're reading.
	if _will_screen.visible or _legacy_screen.visible \
			or _dev_panel.visible or _first_contact_overlay.visible \
			or _minigame_screen.visible:
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

	# The heir name rides on the hero stat; the prestige-exit button and the Estate
	# Office button (with its Legacy balance) reflect the live state.
	_hero_stat.set_dynasty_name(HeirNames.dynasty_name(dynasty.generation))
	_update_epoch_label()
	_update_plan_button()
	_update_legacy_button()


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

	# Constructing the dynasty also builds generation 1, already seeded with
	# starting cash by DynastyState. So, unlike the old bare-GameState path, a
	# fresh game needs no extra award_cash here.
	dynasty = DynastyState.new(property_configs, titles, tuning)

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
	# The app-wide theme rides on the root and cascades to every control below,
	# including the overlays added later in this method (UiPalette.make_app_theme).
	theme = UiPalette.make_app_theme()

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
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# Pinned across every tab (UI Notes §7): the income/cash hero stat (the heartbeat)
	# and the epoch banner just under it. Main feeds both each frame in _process.
	_hero_stat = HeroStat.new()
	column.add_child(_hero_stat)

	_epoch_label = Label.new()
	_epoch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epoch_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_epoch_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	column.add_child(_epoch_label)

	# Tab content: the four surfaces stacked in one slot, one visible at a time. It
	# expands so the bottom tab bar pins beneath it. Switching tabs never pauses the
	# economy (idle game) — only the modal overlays freeze it (see _process).
	_tab_content = Control.new()
	_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tab_content)

	# The Family Ledger tab IS the (now embedded) FamilyLedgerScreen; the other three
	# are built below. All four fill the content slot; _show_tab toggles visibility.
	_ledger_screen = FamilyLedgerScreen.new()
	_ledger_screen.setup()
	_tab_panels = [
		_build_property_tab(), _build_estate_tab(), _build_settings_tab(), _ledger_screen,
	]
	for panel in _tab_panels:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		_tab_content.add_child(panel)

	_build_tab_bar(column)

	# The welcome-back overlay sits above everything and starts hidden.
	_welcome_overlay = WelcomeBackOverlay.new()
	_welcome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_welcome_overlay)

	# The first-contact overlay (GDD §6.2): shown when a generation consumes the current
	# economy and reaches the next alien epoch. Main freezes the economy while it is up so
	# the beat lands. EpochState.contact_made fires it; it is rebuilt with the generation
	# on each scene reload, so its connection always points at the living epoch state.
	_first_contact_overlay = FirstContactOverlay.new()
	_first_contact_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_first_contact_overlay)
	game.epoch.contact_made.connect(_on_contact_made)

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
	_legacy_screen.retain_requested.connect(_on_retain_requested)
	_legacy_screen.closed.connect(_on_legacy_screen_closed)
	add_child(_legacy_screen)

	# The dev tuning panel (GDD §13), above everything and hidden until the DEV
	# button opens it. Main freezes the economy while it is up, applies its edits
	# by saving overrides + reloading the scene, and routes its save-wipe action.
	_dev_panel = DevTuningPanel.new()
	_dev_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_panel.setup()
	_dev_panel.apply_requested.connect(_on_dev_apply_requested)
	_dev_panel.defaults_requested.connect(_on_dev_defaults_requested)
	_dev_panel.reset_dynasty_requested.connect(_on_dev_reset_dynasty_requested)
	_dev_panel.closed.connect(_on_dev_closed)
	add_child(_dev_panel)

	# The prestige minigame (GDD §5.5): a match-3 played mid-succession (after the will,
	# before the heir reveal) whose score grants an upside-only multiplier on the run's
	# Legacy. Main freezes the economy while it is up and reads the multiplier back.
	_minigame_screen = MinigameScreen.new()
	_minigame_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_minigame_screen.setup(tuning)
	_minigame_screen.finished.connect(_on_minigame_finished)
	add_child(_minigame_screen)

	_show_tab(TAB_PROPERTY)


# ---------------------------------------------------------------------------
# Tab construction & switching (UI Notes §7)
# ---------------------------------------------------------------------------

## Property tab: the income engine — the TURBO/frenzy + buy-mode action row, the
## scrolling property ladder, and the wage button.
func _build_property_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	# Action row: the TURBO button (its background is the frenzy meter) takes the larger
	# share; the buy-mode toggle takes the rest.
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	v.add_child(action_row)

	_frenzy_bar = FrenzyBar.new()
	_frenzy_bar.setup(game.frenzy, tuning)
	_frenzy_bar.pop_requested.connect(_on_pop_requested)
	_frenzy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frenzy_bar.size_flags_stretch_ratio = 2.0  # TURBO ~2/3, buy-mode ~1/3
	action_row.add_child(_frenzy_bar)

	# Global buy-mode toggle: one button cycles ×1 → ×10 → ×100 → MAX; every row follows.
	_buy_mode_button = Button.new()
	_buy_mode_button.custom_minimum_size = Vector2(0, 56)
	_buy_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_mode_button.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	UiPalette.style_button(_buy_mode_button, false)
	_buy_mode_button.text = "BUY MODE: " + _buy_mode_caption(_buy_mode)
	_buy_mode_button.pressed.connect(_on_buy_mode_toggled)
	action_row.add_child(_buy_mode_button)

	# The property ladder: 12 rows in a vertical scroll (GDD §2).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	v.add_child(scroll)

	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 10)
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ladder)

	for i in range(game.economy.properties.size()):
		var row := PropertyRow.new()
		row.setup(i, game.economy.properties[i] as PropertyState, game.economy, game.frenzy, game.epoch)
		row.buy_requested.connect(_on_buy_requested)
		row.tap_requested.connect(_on_tap_requested)
		row.hold_rush_requested.connect(_on_hold_rush_requested)
		row.hire_requested.connect(_on_hire_requested)
		row.set_buy_mode(_buy_mode)
		ladder.add_child(row)
		_rows.append(row)

	_wage_panel = WagePanel.new()
	_wage_panel.setup(game.wage, game.economy, tuning, game.frenzy)
	_wage_panel.wage_tapped.connect(_on_wage_tapped)
	_wage_panel.wage_hold_tapped.connect(_on_wage_hold_tapped)
	_wage_panel.promotion_requested.connect(_on_promotion_requested)
	v.add_child(_wage_panel)

	return v


## Estate Planning tab: the prestige hub — plan the estate (succession) and open the
## Estate Office (Legacy upgrade shop). Both controls keep their existing visibility
## rules; _update_plan_button / _update_legacy_button drive them each frame.
func _build_estate_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)

	var heading := Label.new()
	heading.text = "ESTATE PLANNING"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", UiPalette.NAVY)
	heading.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	v.add_child(heading)

	# The prestige exit: plan the estate, pass on, raise a faster heir. Red = big commit.
	_plan_button = Button.new()
	_plan_button.custom_minimum_size = Vector2(0, 72)
	_plan_button.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	UiPalette.style_button(_plan_button, true)
	_plan_button.text = "PLAN THE ESTATE"
	_plan_button.pressed.connect(_on_plan_estate_pressed)
	v.add_child(_plan_button)

	# The Estate Office: open the Legacy upgrade shop (a modal). Hidden until the first
	# prestige has ever earned Legacy. The Legacy balance is pinned to its right edge.
	_legacy_button = Button.new()
	_legacy_button.custom_minimum_size = Vector2(0, 64)
	_legacy_button.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	UiPalette.style_button(_legacy_button, false)
	_legacy_button.text = "THE ESTATE OFFICE"
	_legacy_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_legacy_button.pressed.connect(_on_estate_office_pressed)
	_legacy_button.visible = false
	v.add_child(_legacy_button)

	_legacy_balance_label = Label.new()
	_legacy_balance_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_legacy_balance_label.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	_legacy_balance_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_legacy_balance_label.add_theme_constant_override("outline_size", 2)
	_legacy_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_legacy_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_legacy_balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legacy_balance_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_legacy_balance_label.offset_right = -14
	_legacy_button.add_child(_legacy_balance_label)

	var hint := Label.new()
	hint.text = "Pass on to convert this life's fortune into Legacy, then spend it on permanent dynasty upgrades."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UiPalette.NAVY)
	hint.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	v.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	return v


## Settings tab: player options. Today the prestige-minigame toggle and the dev panel
## entry; later, audio / haptics. (Was previously a deferred standalone screen.)
func _build_settings_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", UiPalette.NAVY)
	heading.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	v.add_child(heading)

	# Prestige minigame toggle — the persistent home for the opt-out (GameState).
	_minigame_check = CheckBox.new()
	_minigame_check.text = "Play the prestige minigame"
	_minigame_check.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_minigame_check.add_theme_color_override("font_color", UiPalette.NAVY)
	_minigame_check.button_pressed = game.ui_minigame_enabled
	_minigame_check.toggled.connect(func(on: bool) -> void: game.ui_minigame_enabled = on)
	v.add_child(_minigame_check)

	# Dev tools entry: the balance tuning panel (GDD §13). Moved here from the action row.
	var dev_button := Button.new()
	dev_button.custom_minimum_size = Vector2(0, 64)
	dev_button.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	UiPalette.style_button(dev_button, false)
	dev_button.text = "DEV — BALANCE TUNING"
	dev_button.pressed.connect(_on_dev_pressed)
	v.add_child(dev_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	return v


## Build the bottom tab bar: four equal icon buttons pinned along the bottom.
func _build_tab_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)

	var icons := [
		"res://art/icons/tab_property.svg",
		"res://art/icons/tab_estate.svg",
		"res://art/icons/tab_settings.svg",
		"res://art/icons/tab_ledger.svg",
	]
	_tab_buttons = []
	for i in range(icons.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load(icons[i])
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_show_tab.bind(i))
		bar.add_child(b)
		_tab_buttons.append(b)


## Switch to tab `index`: show its panel, hide the rest, restyle the bar, and refresh
## the Family Ledger / Settings content that depends on live state when entered.
func _show_tab(index: int) -> void:
	_active_tab = index
	for i in range(_tab_panels.size()):
		(_tab_panels[i] as Control).visible = (i == index)
		_style_tab_button(_tab_buttons[i] as Button, i == index)
	if index == TAB_LEDGER:
		_ledger_screen.refresh(dynasty.ancestors, dynasty.lifetime_cash_earned)
	elif index == TAB_SETTINGS and _minigame_check != null:
		_minigame_check.button_pressed = game.ui_minigame_enabled


## The active tab button reads as a mustard plate; the rest as plain cream plates.
func _style_tab_button(button: Button, active: bool) -> void:
	if active:
		UiPalette.style_button(button, false)  # mustard = selected
	else:
		var flat := UiPalette.make_panel_style()
		button.add_theme_stylebox_override("normal", flat)
		button.add_theme_stylebox_override("hover", flat)
		button.add_theme_stylebox_override("pressed", flat)


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


## Player opened the dev tuning panel: seed it with the live config (baked
## defaults + any active overrides) for the editor values, plus a pristine baked
## copy so it can tell which constants are overridden and diff edits on Apply.
func _on_dev_pressed() -> void:
	_dev_panel.open(tuning, ConfigLoader.load_tuning(false))


## Apply tuning edits: persist the overrides, save the run so no progress is lost,
## then reload the scene. Startup re-loads tuning with the new overrides layered
## over the baked defaults — the same proven reload path used after a succession.
func _on_dev_apply_requested(overrides: Dictionary) -> void:
	TuningOverrides.save(overrides)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	get_tree().reload_current_scene()


## Discard all overrides and reload on the baked defaults (the run is preserved).
func _on_dev_defaults_requested() -> void:
	TuningOverrides.clear()
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	get_tree().reload_current_scene()


## The folded-in save-wipe (was the standalone RESET button): delete the save and
## reload, which re-runs startup with no save present and so begins a fresh run.
func _on_dev_reset_dynasty_requested() -> void:
	SaveManager.delete_save_file()
	get_tree().reload_current_scene()


func _on_dev_closed() -> void:
	pass


# ---------------------------------------------------------------------------
# Succession — the prestige loop (Spec §9, GDD §13)
# ---------------------------------------------------------------------------

## Refresh the Plan-the-Estate button: enabled only when dying would convert to
## at least 1 Legacy, and labeled with the Legacy it would yield right now.
##
## Hidden entirely for a brand-new player who has never earned Legacy AND cannot yet
## perform a succession — prestige is not a concept worth showing them yet (Tim's
## call). It appears the moment a first succession would actually yield Legacy (so the
## first prestige is reachable), and once any Legacy has ever been earned it stays put
## for good, merely disabling when an heir is not yet ready to pass on.
func _update_plan_button() -> void:
	var can_succeed := dynasty.can_perform_succession()
	_plan_button.visible = dynasty.upgrades.earned_lifetime > 0 or can_succeed
	_plan_button.disabled = not can_succeed
	if can_succeed:
		_plan_button.text = "PLAN THE ESTATE  (+%d Legacy)" % dynasty.projected_legacy_gain()
	else:
		_plan_button.text = "PLAN THE ESTATE"


## Keep the epoch banner in sync with the civilization Earth is currently trading with.
func _update_epoch_label() -> void:
	var tier := game.epoch.current_tier
	if tier <= 1:
		_epoch_label.text = "EARTH"
	else:
		_epoch_label.text = "TRADING WITH: " + EpochCatalog.civilization(tier).to_upper()


## First contact: a new epoch was reached this tick. Show the beat (Main's _process
## guard freezes the economy while it is up).
func _on_contact_made(new_tier: int) -> void:
	_first_contact_overlay.show_contact(new_tier)


## Reveal the Estate Office button once the dynasty has ever earned Legacy — i.e.
## from the first prestige onward. earned_lifetime never falls back to 0, so once
## shown the button stays for good (even after the wallet is spent down to 0). While
## shown, keep its right-pinned balance in sync with the spendable wallet.
func _update_legacy_button() -> void:
	_legacy_button.visible = dynasty.upgrades.earned_lifetime > 0
	_legacy_balance_label.text = "LEGACY: " + str(dynasty.upgrades.available)


## The Family Ledger is now a tab (UI Notes §7), refreshed on entry by _show_tab —
## no Main-screen button to reveal.


## Player opened the Estate Office: feed the shop a fresh Household Staff snapshot
## (which depends on the living generation's staff), then show it. The upgrade cards
## refresh themselves against the current Legacy wallet inside open().
func _on_estate_office_pressed() -> void:
	_legacy_screen.set_retention_entries(_build_retention_entries())
	_legacy_screen.open()


## Snapshot of the living generation's staff vs. the dynasty's retained tiers, for the
## Estate Office's Household Staff section (GDD §6.3). Lists only properties that have a
## staffer now or a retained one — i.e. the actual household worth willing to an heir.
func _build_retention_entries() -> Array:
	var entries: Array = []
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		var current_tier := prop.staff_tier
		var retained_tier := dynasty.staff_retention.get_retained_tier(i)
		if current_tier < 1 and retained_tier < 1:
			continue
		# You can only retain up to the staffer's live tier; -1 means nothing to buy.
		var next_tier := retained_tier + 1
		var cost := -1
		var can_afford := false
		if next_tier <= current_tier:
			cost = dynasty.staff_retention.cost_for_tier(next_tier)
			can_afford = dynasty.upgrades.available >= cost
		entries.append({
			"index": i,
			"property_name": (prop.config as PropertyConfig).display_name,
			"staffer_name": EpochCatalog.staffer_name(maxi(current_tier, retained_tier), i),
			"current_tier": current_tier,
			"retained_tier": retained_tier,
			"cost": cost,
			"can_afford": can_afford,
		})
	return entries


## Player bought a tier of staffer retention in the Estate Office. Spend the Legacy,
## refresh the shop (wallet, upgrade cards, and the staff rows), and persist.
func _on_retain_requested(property_index: int) -> void:
	if dynasty.buy_staff_retention(property_index):
		_legacy_screen.refresh()
		_legacy_screen.set_retention_entries(_build_retention_entries())
		SaveManager.save_dict_to_file(dynasty.to_save_dict())


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


## Player tapped through the obituary: show the itemized will (ceremony beat 2).
func _on_continue_to_will() -> void:
	var will := dynasty.get_draft_will()
	_will_screen.show_will(will, HeirNames.dynasty_name(dynasty.generation))


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


## Player signed the will. If the prestige minigame is on (GDD §5.5), it runs now to
## set the Legacy multiplier (seeded with the base gain for its result display); the
## will stays up behind the minigame's scrim, so the economy stays frozen. Otherwise we
## finalize immediately at the flat opt-out multiplier.
func _on_pass_on_confirmed() -> void:
	if game.ui_minigame_enabled:
		# The minigame's extra-high bonus cap depends on the Family Reputation upgrade.
		_minigame_screen.start_game(
			dynasty.projected_legacy_gain(), dynasty.upgrades.minigame_bonus_max()
		)
	else:
		# Opting out banks the keep floor — skipping is the worst result (GDD §5.5).
		_finalize_succession(tuning.minigame_keep_floor)


## The minigame ended: persist the player's "skip future minigames" choice, then
## finalize the succession with the multiplier it produced.
func _on_minigame_finished(multiplier: float, opt_out: bool) -> void:
	game.ui_minigame_enabled = not opt_out
	_finalize_succession(multiplier)


## Execute the death with the given Legacy multiplier — bank (boosted) Legacy, advance
## the generation, raise the heir — then reveal who inherits.
func _finalize_succession(multiplier: float) -> void:
	dynasty.perform_succession("Retired to Palm Beach", multiplier)
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
