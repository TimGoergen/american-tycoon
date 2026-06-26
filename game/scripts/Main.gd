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

## The income/sec panel is refreshed on a calm fixed cadence (not every render frame) so the
## number is easy to read and never flickers (Tim, 2026-06-24). The value itself is already
## stable; this just keeps the on-screen text from re-rendering 60×/second.
const INCOME_DISPLAY_INTERVAL := 0.1
var _income_display_timer := INCOME_DISPLAY_INTERVAL  # refresh on the very first frame

var _hero_stat: HeroStat
## The full-bleed play-field backdrop. Earth shows a prairie; it swaps to a space scene
## after first contact and to a centered space scene after the tenth contact (see
## _background_path_for_tier). Kept as a field so contact events can re-point its texture.
var _background: TextureRect
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
var _minigame_review_screen: MinigameReviewScreen
var _buy_mode_button: Button
var _plan_button: Button
var _rows: Array = []

# Bottom tab bar (UI Notes §7). The four surfaces share one content slot; one is
# visible at a time, switched by the icon buttons pinned along the bottom.
const TAB_PROPERTY := 0
const TAB_ESTATE := 1
const TAB_LEDGER := 2
const TAB_SETTINGS := 3

## On-screen size of each bottom-tab glyph. 40% larger than the 81px native SVG (Tim,
## 2026-06-24). A Button renders its `icon` at the texture's native size with no way to scale
## it UP, so we let the icon expand and cap it here at this width (icons are square).
const TAB_ICON_SIZE := 113

# The screen-frame constants (bezel + universal content margin) live in UiPalette now, so the
# Main screen and the full-screen overlays all frame identically (UiPalette.apply_screen_bezel
# / make_screen_panel_style).
var _tab_content: Control
var _tab_panels: Array = []   # the four content Controls, indexed by TAB_*
var _tab_buttons: Array = []  # the four bottom icon Buttons, indexed by TAB_*
var _active_tab: int = TAB_PROPERTY
var _minigame_check: CheckBox  # the Settings-tab "play the minigame" toggle

## Red-dot badge on the Estate tab button: shown when the current run has earned claimable
## Legacy (a succession right now would yield ≥1), and cleared the moment the player opens
## the Estate tab. It returns the next time the run earns claimable Legacy (e.g. after a
## succession resets the run back to zero).
var _estate_badge: Panel
var _estate_badge_dismissed := false

## Global buy mode — one toggle drives every row's buy button.
var _buy_mode: PropertyRow.BuyMode = PropertyRow.BuyMode.ONE

## Wall-clock seconds since the loaded save was written (0 on a fresh run).
var _elapsed_since_save := 0.0

# Which site launched the currently-running minigame, so _on_minigame_finished knows what its
# multiplier scales (GDD §5.5). One host serves both sites; only one runs at a time.
enum MinigameSite { NONE, SUCCESSION, WELCOME_BACK }
var _minigame_site: int = MinigameSite.NONE
## The offline pile awaiting the welcome-back minigame's verdict. The base pile is already
## banked when the minigame starts; on finish we credit the +/- delta and show the welcome
## screen with the final, post-minigame haul.
var _pending_offline_pile: float = 0.0
var _pending_offline_hours: float = 0.0

## The welcome-back minigame's outcome range is fixed at 50%–200% of the overnight pile,
## independent of the Family Reputation upgrade (Tim, 2026-06-24). The host's floor is
## tuning.minigame_keep_floor (0.5 = 50%); pairing it with this bonus cap of 1.0 puts the top
## of the range at 1.0 + 1.0 = 200%. The host's spectrum bar then visualizes the whole span.
const WELCOME_BACK_BONUS_MAX := 1.0


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
	if _will_screen.visible or _dev_panel.visible or _first_contact_overlay.visible \
			or _minigame_screen.visible or _minigame_review_screen.visible:
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

	# Headline income/sec: a STABLE, theoretical rate computed from current assets (not a
	# measurement of recent cash inflow, which swung wildly between lumpy cycle payouts).
	# Refreshed on a calm 100 ms cadence so the panel never flickers (Tim, 2026-06-24).
	_income_display_timer += delta
	if _income_display_timer >= INCOME_DISPLAY_INTERVAL:
		_income_display_timer = 0.0
		_hero_stat.set_income_per_sec(game.displayed_income_per_sec)
	# Cash keeps updating every frame so the balance still counts up smoothly.
	_hero_stat.set_cash(game.economy.cash)
	_hero_stat.set_frenzy_glow(game.frenzy.get_multiplier() > 1.0)

	# The heir name rides on the hero stat; the prestige-exit button and the Estate
	# Office button (with its Legacy balance) reflect the live state.
	_hero_stat.set_dynasty_name(HeirNames.dynasty_name(dynasty.generation))
	_hero_stat.set_planet_tier(game.epoch.current_tier)
	_update_epoch_label()
	_update_plan_button()
	_update_estate_badge()


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

	# Constructing the dynasty also builds generation 1, already seeded with
	# starting cash by DynastyState. So, unlike the old bare-GameState path, a
	# fresh game needs no extra award_cash here.
	dynasty = DynastyState.new(property_configs, tuning)

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
	if offline.pile <= 0.0:
		return
	var hours_away := offline.elapsed_seconds / 3600.0

	# The game always opens directly to the welcome-back screen (Tim, 2026-06-24) — never
	# straight into a minigame. The base pile is already banked by apply_offline, so PUT IT TO
	# WORK simply dismisses. When transition minigames are on, the screen also offers RISK IT ON
	# A MINIGAME?, handled by _on_welcome_risk_pressed, which scales the pile we stash here.
	_pending_offline_pile = offline.pile
	_pending_offline_hours = hours_away
	_welcome_overlay.show_pile(offline.pile, hours_away, game.ui_minigame_enabled)


# ---------------------------------------------------------------------------
# UI construction (placeholder chrome — hero art and fonts arrive in M3)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# The app-wide theme rides on the root and cascades to every control below,
	# including the overlays added later in this method (UiPalette.make_app_theme).
	theme = UiPalette.make_app_theme()

	# Outermost: solid black fills the whole physical screen, framing the game as a rounded
	# "viewing area" (Tim, 2026-06-22). The play-field is a rounded-corner area inset from the
	# edges (SCREEN_BEZEL_*), so the black showing around it reads as a defining border that
	# follows the phone's rounded screen shape.
	var black_field := ColorRect.new()
	black_field.color = Color.BLACK
	black_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black_field)

	# The play-field background: a full-bleed prairie scene behind all the UI (Tim, 2026-06-25),
	# occupying the same inset rect as the viewing area. This prairie is Earth's backdrop; later the
	# image is meant to SWAP PER EPOCH after each first contact (a Luminari / Geth / Mycelium scene,
	# etc.) — see Art Style Guide §7. For now it is a single fixed texture; when that lands, drive
	# `background.texture` off the reached epoch and refresh it on EpochState advancement.
	# It must show the SAME rounded corners as the frame so it nests inside the phone's screen
	# curve. We get that rounding without a shader
	# by using Godot's clip_children: the parent `bg_mask` draws a rounded rectangle that is used
	# purely as a stencil (CLIP_CHILDREN_ONLY draws the children only where the parent is opaque,
	# and does not paint the parent itself), so the square image is clipped to rounded corners.
	var bg_mask := Panel.new()
	UiPalette.apply_screen_bezel(bg_mask)
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE  # color is irrelevant — only this shape's alpha is the mask
	mask_style.set_corner_radius_all(UiPalette.SCREEN_CORNER_RADIUS)
	bg_mask.add_theme_stylebox_override("panel", mask_style)
	bg_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	bg_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_mask)

	# Pick the backdrop for the epoch we are starting in: a fresh founder (or a heir after
	# prestige) is on Earth and sees the prairie; a save loaded mid-run past first/tenth
	# contact opens straight onto the matching space scene. _on_contact_made swaps it live.
	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.texture = load(_background_path_for_tier(game.epoch.current_tier))
	# COVERED scales the square art to fill the tall play-field, cropping the overflow, so there
	# are never empty bars — the landscape always reaches all four edges of the rounded frame.
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mask.add_child(_background)

	# The viewing area: the shared rounded-rect frame (UiPalette) — inset from the screen edges by
	# the bezel so black frames it, with the universal inner margin so no element crowds the
	# border. Its fill is now TRANSPARENT (make_screen_frame_style) so the prairie behind it shows
	# through; the crisp black outline and inner padding are unchanged. The full-screen overlays
	# still use the cream make_screen_panel_style, so their framing matches.
	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_frame_style())
	add_child(viewing_area)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	viewing_area.add_child(column)

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
		_build_property_tab(), _build_estate_tab(), _ledger_screen, _build_settings_tab(),
	]
	for panel in _tab_panels:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		_tab_content.add_child(panel)

	_build_tab_bar(column)

	# The welcome-back overlay sits above everything and starts hidden.
	_welcome_overlay = WelcomeBackOverlay.new()
	_welcome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_welcome_overlay.risk_pressed.connect(_on_welcome_risk_pressed)
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

	# The Minigame Tuning review screen (Settings): a full-screen list that opens any minigame
	# in isolation for testing. It owns its own minigame host, so review play never touches the
	# run; Main freezes the economy while it is up, just like the other modal overlays.
	_minigame_review_screen = MinigameReviewScreen.new()
	_minigame_review_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_minigame_review_screen.setup(tuning)
	add_child(_minigame_review_screen)

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
	_buy_mode_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_buy_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Larger + bold BUY MODE label (Tim, 2026-06-25): 30% over the old FONT_SMALL lands at FONT_BUTTON.
	_buy_mode_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	_buy_mode_button.add_theme_font_override("font", UiPalette.make_bold_font())
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
	_wage_panel.setup(game.wage, tuning, game.frenzy)
	_wage_panel.wage_tapped.connect(_on_wage_tapped)
	_wage_panel.wage_hold_tapped.connect(_on_wage_hold_tapped)
	v.add_child(_wage_panel)

	return v


## Estate Planning tab: the prestige hub — the "Plan the Estate" succession action on
## top, with the Estate Office (Legacy upgrade shop) embedded directly beneath it (no
## modal). _update_plan_button drives the plan button each frame; _show_tab refreshes the
## office on entry.
func _build_estate_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	# The prestige exit: plan the estate, pass on, raise a faster heir. Red = big commit.
	_plan_button = Button.new()
	_plan_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_plan_button.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	UiPalette.style_button(_plan_button, true)
	_plan_button.text = "PLAN THE ESTATE"
	_plan_button.pressed.connect(_on_plan_estate_pressed)
	v.add_child(_plan_button)

	# The Estate Office (Legacy upgrade shop + staff retention) now lives right here on the
	# tab, not behind a modal button. It fills the rest of the tab and reads/writes the
	# live upgrade state; _show_tab refreshes it on entry, and purchases re-apply effects.
	_legacy_screen = LegacyScreen.new()
	_legacy_screen.setup(dynasty.upgrades)
	_legacy_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legacy_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_legacy_screen.purchased.connect(_on_upgrade_purchased)
	_legacy_screen.retain_requested.connect(_on_retain_requested)
	v.add_child(_legacy_screen)
	# Populate once now so the cards aren't blank on first view.
	_legacy_screen.set_retention_entries(_build_retention_entries())
	_legacy_screen.refresh()

	return v


## Settings tab: player options. Today the prestige-minigame toggle and the dev panel
## entry; later, audio / haptics. (Was previously a deferred standalone screen.)
##
## Layout (Tim, 2026-06-26): the settings options live in a transparent, gray-outlined panel
## held well clear of the screen edges; the two tuning buttons are pushed to the very bottom,
## below that panel, sitting larger and bolder than the in-panel options.
func _build_settings_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)

	# The settings panel sits inside a margin that is wider than the tab's normal inset, so the
	# transparent plate floats clear of the screen edges. A MarginContainer adds that gap; the
	# PanelContainer inside it is the gray-outlined, see-through plate.
	const SETTINGS_PANEL_EDGE_MARGIN := 40
	var panel_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top"]:
		panel_margin.add_theme_constant_override(side, SETTINGS_PANEL_EDGE_MARGIN)
	v.add_child(panel_margin)

	var settings_panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.TRANSPARENT          # see-through plate
	panel_style.border_color = UiPalette.MID_GRAY     # gray outline
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)            # keep the options clear of the outline
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	panel_margin.add_child(settings_panel)

	var panel_contents := VBoxContainer.new()
	panel_contents.add_theme_constant_override("separation", 24)
	settings_panel.add_child(panel_contents)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", UiPalette.NAVY)
	# 40% larger than before (FONT_HEADLINE 52 -> 73) and bolder (Tim, 2026-06-26). The bold
	# weight is faked with a FontVariation since the project ships no bold face yet.
	heading.add_theme_font_size_override("font_size", int(UiPalette.FONT_HEADLINE * 1.4))
	heading.add_theme_font_override("font", UiPalette.make_bold_font())
	panel_contents.add_child(heading)

	# Transition minigame toggle — the persistent home for the opt-out (GameState). Governs
	# every site that rolls a minigame (prestige and welcome-back), not just prestige.
	_minigame_check = CheckBox.new()
	_minigame_check.text = "Play transition minigames"
	# 40% larger than FONT_BODY (32 -> 45) at Tim's request.
	_minigame_check.add_theme_font_size_override("font_size", 45)
	# Navy text in every state — the default theme's checked/hover/pressed colors are a
	# pale near-white that was unreadable on the cream tab (Tim, 2026-06-22).
	for state in ["font_color", "font_pressed_color", "font_hover_color",
			"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		_minigame_check.add_theme_color_override(state, UiPalette.NAVY)
	# Custom check glyphs sized (~44px) to match the larger label, so the box is as tall
	# as the text instead of the tiny default icon.
	_minigame_check.add_theme_icon_override(
		"checked", load("res://art/icons/checkbox_checked.svg")
	)
	_minigame_check.add_theme_icon_override(
		"unchecked", load("res://art/icons/checkbox_unchecked.svg")
	)
	_minigame_check.button_pressed = game.ui_minigame_enabled
	_minigame_check.toggled.connect(func(on: bool) -> void: game.ui_minigame_enabled = on)
	panel_contents.add_child(_minigame_check)

	# A spacer pushes the two tuning buttons to the very bottom of the tab, below the panel.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Bottom-of-screen tuning buttons: 40% taller than the standard button, with a label
	# large enough to fill that extra height (Tim, 2026-06-26).
	var tuning_button_height := int(UiPalette.STANDARD_BUTTON_HEIGHT * 1.4)
	const TUNING_BUTTON_FONT := 50
	var bottom_buttons := VBoxContainer.new()
	bottom_buttons.add_theme_constant_override("separation", 16)
	v.add_child(bottom_buttons)

	# Dev tools entry: the balance tuning panel (GDD §13). Moved here from the action row.
	var dev_button := Button.new()
	dev_button.custom_minimum_size = Vector2(0, tuning_button_height)
	dev_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(dev_button, false)
	dev_button.text = "BALANCE TUNING"
	dev_button.pressed.connect(_on_dev_pressed)
	bottom_buttons.add_child(dev_button)

	# Minigame review tool: opens the full-screen list of every minigame so they can each be
	# played and reviewed on demand (GDD §5.5), independent of a real prestige.
	var minigame_tuning_button := Button.new()
	minigame_tuning_button.custom_minimum_size = Vector2(0, tuning_button_height)
	minigame_tuning_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(minigame_tuning_button, false)
	minigame_tuning_button.text = "MINIGAME TUNING"
	minigame_tuning_button.pressed.connect(_on_minigame_tuning_pressed)
	bottom_buttons.add_child(minigame_tuning_button)

	return v


## Build the bottom tab bar: four equal icon buttons pinned along the bottom.
func _build_tab_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)

	var icons := [
		"res://art/icons/tab_property.svg",
		"res://art/icons/tab_estate.svg",
		"res://art/icons/tab_ledger.svg",
		"res://art/icons/tab_settings.svg",
	]
	_tab_buttons = []
	for i in range(icons.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 185)  # 25% taller again (148 -> 185, Tim 2026-06-23)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load(icons[i])
		# Let the icon scale up from its 81px native size and cap it at TAB_ICON_SIZE (40%
		# larger). expand_icon grows it to fill the button; icon_max_width holds it at the target.
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", TAB_ICON_SIZE)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_show_tab.bind(i))
		bar.add_child(b)
		_tab_buttons.append(b)
		# The Estate tab carries the "you have Legacy to claim" red-dot badge.
		if i == TAB_ESTATE:
			_estate_badge = _make_estate_badge(b)


## Build the Estate tab's red-dot badge: a small red circle pinned to the button's top-right
## corner, hidden until there is claimable Legacy. mouse-ignoring so it never eats a tab tap.
func _make_estate_badge(button: Button) -> Panel:
	var dot := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.KETCHUP_RED
	style.set_corner_radius_all(20)        # half the 39px box → a full circle
	style.border_color = UiPalette.CREAM   # a cream ring so it reads on the navy/mustard plate
	style.set_border_width_all(4)
	dot.add_theme_stylebox_override("panel", style)
	# Pin a 39×39 dot (50% larger than the old 26px) well inside the button's top-right corner,
	# clear of the 12px tab outline it used to overlap (Tim, 2026-06-24).
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -59
	dot.offset_top = 20
	dot.offset_right = -20
	dot.offset_bottom = 59
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	button.add_child(dot)
	return dot


## Show the Estate badge while the run has claimable Legacy and the player has not yet opened
## the Estate tab; hide it otherwise. When nothing is claimable we also clear the "seen" flag,
## so the badge can light up again the next time the run earns Legacy (e.g. after a succession).
func _update_estate_badge() -> void:
	if _estate_badge == null:
		return
	if not dynasty.can_perform_succession():
		_estate_badge_dismissed = false
		_estate_badge.visible = false
		return
	_estate_badge.visible = not _estate_badge_dismissed


## Switch to tab `index`: show its panel, hide the rest, restyle the bar, and refresh
## the Family Ledger / Settings content that depends on live state when entered.
func _show_tab(index: int) -> void:
	_active_tab = index
	# Opening the Estate tab acknowledges the claimable-Legacy badge.
	if index == TAB_ESTATE:
		_estate_badge_dismissed = true
	for i in range(_tab_panels.size()):
		(_tab_panels[i] as Control).visible = (i == index)
		_style_tab_button(_tab_buttons[i] as Button, i == index, i)
	if index == TAB_ESTATE:
		_legacy_screen.set_retention_entries(_build_retention_entries())
		_legacy_screen.refresh()
	elif index == TAB_LEDGER:
		_ledger_screen.refresh(dynasty.ancestors, dynasty.lifetime_cash_earned)
	elif index == TAB_SETTINGS and _minigame_check != null:
		_minigame_check.button_pressed = game.ui_minigame_enabled


## The active tab button reads as a mustard plate; the rest as plain cream plates. The
## leftmost and rightmost tabs round their OUTER bottom corner to nest inside the phone's
## bottom screen corners (the Property tab's bottom-left, the Settings tab's bottom-right).
func _style_tab_button(button: Button, active: bool, index: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.MUSTARD_GOLD if active else UiPalette.CREAM
	box.border_color = UiPalette.NAVY
	box.set_border_width_all(12)  # outline +300% (3 -> 12) at Tim's request (2026-06-23)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(12)
	if index == 0:
		box.corner_radius_bottom_left = UiPalette.SCREEN_CORNER_RADIUS
	elif index == _tab_buttons.size() - 1:
		box.corner_radius_bottom_right = UiPalette.SCREEN_CORNER_RADIUS
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


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


func _on_pop_requested() -> void:
	game.pop_frenzy()


## Player opened the dev tuning panel: seed it with the live config (baked
## defaults + any active overrides) for the editor values, plus a pristine baked
## copy so it can tell which constants are overridden and diff edits on Apply.
func _on_dev_pressed() -> void:
	_dev_panel.open(tuning, ConfigLoader.load_tuning(false))


## Open the Minigame Tuning review screen (Settings). The economy freezes while it is up
## (see _process), just like the other full-screen overlays.
func _on_minigame_tuning_pressed() -> void:
	_minigame_review_screen.open()


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
		_plan_button.text = "PASS THE TORCH  (+%d Legacy)" % dynasty.projected_legacy_gain()
	else:
		_plan_button.text = "PASS THE TORCH"


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
	# Swap the play-field backdrop to match the newly reached epoch before the beat plays,
	# so when the first-contact overlay clears the player is looking at the new world.
	_background.texture = load(_background_path_for_tier(new_tier))
	_first_contact_overlay.show_contact(new_tier)


# Backdrops keyed to how many alien contacts have been made (Tim, 2026-06-26). The epoch
# tier is 1 on Earth, so the number of contacts made this run is (current_tier - 1):
# Earth keeps the prairie; the first contact opens onto deep space; the tenth swaps to a
# centered space composition. The space scenes cover every contact in between.
const BACKGROUND_EARTH := "res://art/backgrounds/prairie_background.png"
const BACKGROUND_SPACE := "res://art/backgrounds/space_background.jpg"
const BACKGROUND_SPACE_CENTERED := "res://art/backgrounds/space_centered_background.jpg"


## The backdrop image path for a given epoch tier. Used both to set the initial backdrop
## on load and to swap it the moment a contact advances the epoch.
func _background_path_for_tier(tier: int) -> String:
	var contacts_made := tier - 1
	if contacts_made >= 10:
		return BACKGROUND_SPACE_CENTERED
	if contacts_made >= 1:
		return BACKGROUND_SPACE
	return BACKGROUND_EARTH


## The Family Ledger is now a tab (UI Notes §7), refreshed on entry by _show_tab —
## no Main-screen button to reveal.


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
		_minigame_site = MinigameSite.SUCCESSION
		_minigame_screen.start_game(
			MinigameScreen.legacy_reward(dynasty.projected_legacy_gain()),
			dynasty.upgrades.minigame_bonus_max()
		)
	else:
		# Opting out banks the keep floor — skipping is the worst result (GDD §5.5).
		_finalize_succession(tuning.minigame_keep_floor)


## The minigame ended: persist the player's "skip future minigames" choice, then apply its
## multiplier at whichever site launched it (GDD §5.5). One host serves both sites, so we
## read _minigame_site to decide; clearing it first keeps a stray re-entry from double-firing.
func _on_minigame_finished(multiplier: float, opt_out: bool) -> void:
	game.ui_minigame_enabled = not opt_out
	var site := _minigame_site
	_minigame_site = MinigameSite.NONE
	match site:
		MinigameSite.WELCOME_BACK:
			_finish_welcome_back_minigame(multiplier)
		_:
			# SUCCESSION (and any unexpected NONE) finalize the death with the multiplier.
			_finalize_succession(multiplier)


## Player chose to gamble the overnight pile (the RISK IT button on the welcome screen). The
## base pile is already banked; this round scales it across a fixed 50%–200% range
## (WELCOME_BACK_BONUS_MAX, not the upgrade-driven cap), and _finish_welcome_back_minigame
## credits the +/- delta before re-showing the welcome screen with the final haul.
func _on_welcome_risk_pressed() -> void:
	_minigame_site = MinigameSite.WELCOME_BACK
	_minigame_screen.start_game(
		MinigameScreen.offline_pile_reward(_pending_offline_pile),
		WELCOME_BACK_BONUS_MAX
	)


## The welcome-back minigame produced `multiplier`: the base pile was already banked, so we
## credit only the delta (a bonus when >1.0, a clawback when <1.0) and then show the welcome
## screen with the final haul (no RISK button this time — the roll is spent). The delta is
## offline property income like the rest of the pile, so it is credited as EARNED (counts
## toward the estate basis), matching the base pile.
func _finish_welcome_back_minigame(multiplier: float) -> void:
	var final_pile := _pending_offline_pile * multiplier
	game.economy.award_earned(_pending_offline_pile * (multiplier - 1.0))
	_welcome_overlay.show_pile(final_pile, _pending_offline_hours, false)
	_pending_offline_pile = 0.0
	_pending_offline_hours = 0.0


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
