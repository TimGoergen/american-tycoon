extends Control

# Main screen driver (M1 brief §4: the one screen). Owns the GameState,
# advances it on a fixed timestep, autosaves, applies offline earnings on
# launch, and wires every UI verb into GameState.
#
# Logic ticks run at a fixed rate (LOGIC_HZ, Spec §2) regardless of frame
# rate; rendering and UI refresh happen per-frame and only read state.
# (Unity analogue: FixedUpdate for logic, Update for presentation — except
# Godot has no built-in fixed update for _process, so we accumulate.)

var game: GameState
var tuning: TuningConfig

var _tick_accumulator := 0.0
var _autosave_timer := 0.0

var _hero_stat: HeroStat
var _frenzy_bar: FrenzyBar
var _wage_panel: WagePanel
var _welcome_overlay: WelcomeBackOverlay
var _buy_mode_button: Button
var _rows: Array = []

## Global buy mode — one toggle drives every row's buy button.
var _buy_mode: PropertyRow.BuyMode = PropertyRow.BuyMode.ONE

## Wall-clock seconds since the loaded save was written (0 on a fresh run).
var _elapsed_since_save := 0.0


func _ready() -> void:
	_create_game()
	_build_ui()
	_apply_offline_if_due()


func _process(delta: float) -> void:
	# Fixed-timestep logic (Spec §2): accumulate render time and tick in
	# constant steps so the economy math is framerate-independent.
	var step := 1.0 / float(tuning.logic_hz)
	_tick_accumulator += delta
	while _tick_accumulator >= step:
		game.tick(step)
		_tick_accumulator -= step

	_autosave_timer += delta
	if _autosave_timer >= tuning.autosave_cadence:
		_autosave_timer = 0.0
		SaveManager.save_to_file(game)

	_hero_stat.set_income_per_sec(game.economy.get_total_income_per_sec())
	_hero_stat.set_cash(game.economy.cash)


func _notification(what: int) -> void:
	# Save on backgrounding (phone) and on close (desktop) — Spec §12.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game != null:
			SaveManager.save_to_file(game)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

func _create_game() -> void:
	tuning = ConfigLoader.load_tuning()
	var property_configs := ConfigLoader.load_property_configs()
	var titles := ConfigLoader.load_title_configs()
	game = GameState.new(property_configs, titles, tuning)

	var save_dict := SaveManager.load_from_file()
	if save_dict.is_empty():
		game.economy.award_cash(tuning.m1_starting_cash)
	else:
		game.load_save_dict(save_dict)
		_elapsed_since_save = SaveManager.get_seconds_since_save(save_dict)


func _apply_offline_if_due() -> void:
	if _elapsed_since_save <= 0.0:
		return
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
	column.add_child(scroll)

	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 10)
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ladder)

	for i in range(game.economy.properties.size()):
		var row := PropertyRow.new()
		row.setup(i, game.economy.properties[i] as PropertyState, game.economy)
		row.buy_requested.connect(_on_buy_requested)
		row.tap_requested.connect(_on_tap_requested)
		row.hold_rush_requested.connect(_on_hold_rush_requested)
		row.hire_requested.connect(_on_hire_requested)
		ladder.add_child(row)
		_rows.append(row)

	_wage_panel = WagePanel.new()
	_wage_panel.setup(game.wage, game.economy, tuning)
	_wage_panel.wage_tapped.connect(_on_wage_tapped)
	_wage_panel.wage_hold_tapped.connect(_on_wage_hold_tapped)
	_wage_panel.promotion_requested.connect(_on_promotion_requested)
	column.add_child(_wage_panel)

	# The welcome-back overlay sits above everything and starts hidden.
	_welcome_overlay = WelcomeBackOverlay.new()
	_welcome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_welcome_overlay)


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

	var ips_before := game.economy.get_total_income_per_sec()
	if game.try_buy(prop_index, count):
		var ips_after := game.economy.get_total_income_per_sec()
		_hero_stat.flash_purchase(ips_before, ips_after)


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


func _on_buy_mode_toggled() -> void:
	_buy_mode = ((_buy_mode + 1) % PropertyRow.BuyMode.size()) as PropertyRow.BuyMode
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
