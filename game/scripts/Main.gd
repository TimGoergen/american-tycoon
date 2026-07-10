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
var _first_contact_overlay: FirstContactOverlay
var _frenzy_bar: FrenzyBar
var _wage_panel: WagePanel
var _welcome_overlay: WelcomeBackOverlay
var _about_screen: AboutScreen
var _will_screen: WillScreen
var _legacy_screen: LegacyScreen
var _ledger_screen: FamilyLedgerScreen
var _dev_panel: DevTuningPanel
var _minigame_screen: MinigameScreen
var _minigame_review_screen: MinigameReviewScreen
var _buy_mode_button: Button
var _plan_button: Button
## Rich-text content overlaid on the plan button so the "(+x [gem])" parenthetical can show the
## legacy-gem image inline (a plain Button can't put an image mid-text). _update_plan_button drives it.
var _plan_label: RichTextLabel
## The dynasty's lifetime-earned Legacy readout above the plan button ("[gem] Lifetime
## Earned: x"). Driven by _update_plan_button; _shown_lifetime_earned caches the last
## painted value so the rich text isn't reparsed every frame.
var _lifetime_earned_label: RichTextLabel
var _shown_lifetime_earned := -1
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
## The Settings tab's normal page — hidden while the embedded Balance Tuning panel
## (_dev_panel) is swapped into the tab's slot, restored on its Close.
var _settings_page: Control

## Red-dot badge on the Estate tab button: shown when the current run has earned claimable
## Legacy (a succession right now would yield ≥1), and cleared the moment the player opens
## the Estate tab. It returns the next time the run earns claimable Legacy (e.g. after a
## succession resets the run back to zero).
var _estate_badge: Panel
var _estate_badge_dismissed := false

## Global buy mode — one toggle drives every row's buy button.
var _buy_mode: PropertyRow.BuyMode = PropertyRow.BuyMode.ONE

## The property ladder's ScrollContainer, kept for the edge fade below
## (Tim, 2026-07-06; chosen over an outline, which would have nested a third frame).
var _ladder_scroll: ScrollContainer

## The game screen's drawing layers (backdrop mask + viewing area), hidden while an
## economy-freezing modal covers them so they stop costing draw time (see _process).
var _covered_game_layers: Array = []

## Wall-clock seconds since the loaded save was written (0 on a fresh run).
var _elapsed_since_save := 0.0

# Which site launched the currently-running minigame, so _on_minigame_finished knows what its
# multiplier scales (GDD §5.5). One host serves every site; only one runs at a time.
enum MinigameSite { NONE, SUCCESSION, WELCOME_BACK, FIRST_CONTACT }
var _minigame_site: int = MinigameSite.NONE
## First Contact (GDD §5.5 site 2): the property whose head-start units the running negotiation
## minigame is for, and the epoch tier that opened it. Set when the contact beat is dismissed
## into the minigame; consumed when the minigame finishes and the units are granted.
var _first_contact_prop_index: int = -1
var _pending_contact_tier: int = 0
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
	# Desktop diagnosis harness (see CarbAutopilot): scripted rush scenario + per-frame
	# CSV logging, enabled only by the carb_autolog tuning flag. Rows are built in
	# ladder-display order, so find the target's row by its property index.
	if tuning.carb_autolog > 0.5:
		for row in _rows:
			if (row as PropertyRow).prop_index == CarbAutopilot.TARGET_INDEX:
				var autopilot := CarbAutopilot.new()
				autopilot.setup(game, row as PropertyRow)
				add_child(autopilot)
				break


func _process(delta: float) -> void:
	# Concurrent multi-touch on the property tab (secondary fingers drive the rows'
	# rush/buy/hire plus the buy-mode, TURBO, and clock-in buttons — see
	# SecondaryTapButton): allow it ONLY while the Property tab is showing and no
	# full-screen overlay is up, so a stray second finger can never press a control
	# sitting behind a modal. Computed here every frame (before the freeze return
	# below) so it always reflects the current screen, including while an overlay is up.
	# (The Balance Tuning panel is no longer in this list: embedded in the Settings tab,
	# it neither covers the game nor needs the freeze — Apply saves and reloads anyway.)
	var modal_up := _will_screen.visible or _first_contact_overlay.visible \
			or _minigame_screen.visible or _minigame_review_screen.visible
	var overlay_up := modal_up or _welcome_overlay.visible
	SecondaryTapButton.enabled = _active_tab == TAB_PROPERTY and not overlay_up

	# A modal that freezes the economy also HIDES the game screen beneath it (Tim,
	# 2026-07-06): the modals are opaque and full-screen, but a covered Control still
	# draws every frame — the property ladder's bubble bars alone are a real per-frame
	# GPU spend, and paying it under the minigame screen showed up as minigame lag.
	# Hidden Controls skip _draw but their _process still runs, so the bubbles simply
	# resume where they left off when the modal closes.
	for layer in _covered_game_layers:
		(layer as Control).visible = not modal_up

	# Freeze the economy while a full-screen MODAL overlay is up (the succession
	# ceremony, the upgrade shop, the minigame, etc.): no ticks, no autosave. This keeps
	# the will's numbers steady, avoids half-saving the generation swap mid-ceremony, and
	# lets the shop spend Legacy against a steady balance. NOTE: switching TABS does NOT
	# freeze — an idle game keeps earning no matter which tab you're reading.
	if modal_up:
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

	# Headline income/sec: the simple SUM of the rate each property row currently
	# displays — rush-boosted while rush is held (Tim, 2026-07-07) — so the panel always
	# equals the rows beneath it. Still a computed rate (not an inflow measurement, which
	# swung wildly between lumpy payouts) on the calm 100 ms cadence (Tim, 2026-06-24).
	# The core's game.displayed_income_per_sec (theoretical staffed-passive rate) still
	# drives the executive wage floor, untouched.
	_income_display_timer += delta
	if _income_display_timer >= INCOME_DISPLAY_INTERVAL:
		_income_display_timer = 0.0
		_hero_stat.set_income_per_sec(_sum_displayed_property_income())
	# Cash keeps updating every frame so the balance still counts up smoothly.
	_hero_stat.set_cash(game.economy.cash)
	_hero_stat.set_frenzy_glow(game.frenzy.get_multiplier() > 1.0)

	# The current epoch name rides on the hero stat (replaced the heir name, Tim 2026-06-27);
	# the prestige-exit button and the Estate Office button (with its Legacy balance) reflect
	# the live state.
	_hero_stat.set_epoch_name(EpochCatalog.civilization(game.epoch.current_tier))
	_hero_stat.set_planet_tier(game.epoch.current_tier)
	_refresh_contact_progress()
	_update_plan_button()
	_update_estate_badge()
	_update_ladder_edge_fade()


## Apply the ladder's edge fade: a property row the scroll viewport is clipping shows at
## the alpha of its VISIBLE FRACTION — half-clipped means half-faded, dissolving to
## nothing as it slides fully out — but only on an edge that actually has more content
## beyond it. A dissolving row says "the list continues" without drawing extra chrome.
## (First cut faded over a fixed 48px zone measured from the row's far edge, which only
## triggered on the last sliver of a ~150px row — invisible in practice, Tim 2026-07-06.)
func _update_ladder_edge_fade() -> void:
	if _active_tab != TAB_PROPERTY:
		return
	var view_height := _ladder_scroll.size.y
	var scroll_bar := _ladder_scroll.get_v_scroll_bar()
	var more_above := _ladder_scroll.scroll_vertical > 0
	# The furthest scroll_vertical can go is the content height minus one page; anything
	# less than that (with 1px slack for rounding) means content is clipped below.
	var more_below := float(_ladder_scroll.scroll_vertical) < scroll_bar.max_value - scroll_bar.page - 1.0
	for row_node in _rows:
		var row := row_node as PropertyRow
		if row.size.y <= 0.0:
			continue
		# The row's top edge in viewport space: its position in the ladder, shifted up by
		# the scroll offset (the ladder column sits at the scroll content's origin).
		var row_top := row.position.y - float(_ladder_scroll.scroll_vertical)
		var alpha := 1.0
		# Each fading edge is measured from the INNER edge of its ScrollEdgeArrows strip,
		# not the viewport itself: the strip shows under the same "more content this way"
		# condition and covers the rows beneath it, so fading against the raw viewport
		# left rows behind the strip looking solid-but-buried (Tim, 2026-07-06). The strip
		# and the fade agree on where the visible window starts.
		if more_above:
			# Fraction of the row below the top strip (its visible share).
			var below_strip := row_top + row.size.y - ScrollEdgeArrows.STRIP_HEIGHT
			alpha = minf(alpha, clampf(below_strip / row.size.y, 0.0, 1.0))
		if more_below:
			# Fraction of the row above the bottom strip (its visible share).
			var above_strip := view_height - ScrollEdgeArrows.STRIP_HEIGHT - row_top
			alpha = minf(alpha, clampf(above_strip / row.size.y, 0.0, 1.0))
		row.modulate.a = alpha


## Feed the hero stat's contact-progress line: how much of the CURRENT epoch's economy this
## generation has consumed (Tim, 2026-07-03 — the run toward First Contact was invisible, so
## the late-epoch stretch read as a stall). Both values are passed relative to the previous
## contact threshold, so every epoch reads 0% -> 100% of ITS economy rather than resuming
## partway (the consume thresholds are cumulative lifetime earnings, EpochState.update).
func _refresh_contact_progress() -> void:
	var tier := game.epoch.current_tier
	if tier >= EpochCatalog.tier_count():
		_hero_stat.set_epoch_progress(0.0, 0.0)  # final civilization — no next contact to chase
		return
	var goal := EpochCatalog.consume_threshold(tier, tuning.earth_economy_target)
	var epoch_start := 0.0
	if tier > 1:
		epoch_start = EpochCatalog.consume_threshold(tier - 1, tuning.earth_economy_target)
	_hero_stat.set_epoch_progress(
		game.economy.cash_earned_this_gen - epoch_start,
		goal - epoch_start
	)


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
	# Offline earnings accrue to the living generation at the staffed rate. They do
	# NOT yet receive the dynasty's Legacy multiplier (OfflineCalculator predates
	# the dynasty layer); folding Legacy into offline accrual is a later refinement.
	if _elapsed_since_save > 0.0:
		var offline := game.apply_offline(_elapsed_since_save)
		# The welcome-back ritual plays whenever a pile actually accrued (staffed income).
		if offline.pile > 0.0:
			var hours_away := offline.elapsed_seconds / 3600.0
			# The game always opens directly to the welcome-back screen (Tim, 2026-06-24) — never
			# straight into a minigame. The base pile is already banked by apply_offline, so PUT IT TO
			# WORK simply dismisses. When transition minigames are on, the screen also offers RISK IT ON
			# A MINIGAME?, handled by _on_welcome_risk_pressed, which scales the pile we stash here.
			_pending_offline_pile = offline.pile
			_pending_offline_hours = hours_away
			_welcome_overlay.show_pile(offline.pile, hours_away, game.ui_minigame_enabled)
			return

	# No offline income to report: still open on the branded launch screen (logo + BEGIN) rather
	# than dropping straight into the game (Tim, 2026-07-09).
	_welcome_overlay.show_welcome()


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

	# Pinned across every tab (UI Notes §7): the income/cash hero stat (the heartbeat).
	# The epoch name now rides inside the hero stat itself (Tim, 2026-06-28), so the
	# separate banner that used to sit here was removed.
	_hero_stat = HeroStat.new()
	column.add_child(_hero_stat)

	# Tab content: the four surfaces stacked in one slot, one visible at a time. It
	# expands so the bottom tab bar pins beneath it. Switching tabs never pauses the
	# economy (idle game) — only the modal overlays freeze it (see _process).
	_tab_content = Control.new()
	_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tab_content)

	# The Family Ledger tab IS the (now embedded) FamilyLedgerScreen; the other three
	# are built below. Every tab's content is wrapped in the same edge-margin + outlined
	# translucent-cream panel (UiPalette.wrap_in_tab_panel) so all four share one framed look.
	# All four wrappers fill the content slot; _show_tab toggles visibility.
	_ledger_screen = FamilyLedgerScreen.new()
	_ledger_screen.setup()
	_tab_panels = [
		UiPalette.wrap_in_tab_panel(_build_property_tab()),
		UiPalette.wrap_in_tab_panel(_build_estate_tab()),
		UiPalette.wrap_in_tab_panel(_ledger_screen),
		UiPalette.wrap_in_tab_panel(_build_settings_tab()),
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

	# The About modal (Settings → About), hidden until opened.
	_about_screen = AboutScreen.new()
	_about_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_about_screen)

	# The first-contact overlay (GDD §6.2): shown when a generation consumes the current
	# economy and reaches the next alien epoch. Main freezes the economy while it is up so
	# the beat lands. EpochState.contact_made fires it; it is rebuilt with the generation
	# on each scene reload, so its connection always points at the living epoch state.
	_first_contact_overlay = FirstContactOverlay.new()
	_first_contact_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_first_contact_overlay)
	game.epoch.contact_made.connect(_on_contact_made)
	# When the player answers the contact, the trade-deal minigame negotiates their head start
	# on the new alien property (GDD §5.5 site 2), so the negotiation follows the narration.
	_first_contact_overlay.dismissed.connect(_on_contact_dismissed)

	# The succession ceremony overlay (the Reading of the Will + heir reveal),
	# also above everything and hidden until the player plans the estate.
	_will_screen = WillScreen.new()
	_will_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_will_screen.continue_to_will.connect(_on_continue_to_will)
	_will_screen.pass_on_confirmed.connect(_on_pass_on_confirmed)
	_will_screen.heir_begin_pressed.connect(_on_heir_begin_pressed)
	_will_screen.cancelled.connect(_on_will_cancelled)
	add_child(_will_screen)

	# (The Balance Tuning panel now lives inside the Settings tab — see
	# _build_settings_tab — rather than as a full-screen overlay here.)

	# The prestige minigame (GDD §5.5): a match-3 played mid-succession (after the will,
	# before the heir reveal) whose score grants an upside-only multiplier on the run's
	# Legacy. Main freezes the economy while it is up and reads the multiplier back.
	_minigame_screen = MinigameScreen.new()
	_minigame_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_minigame_screen.setup(tuning)
	_minigame_screen.finished.connect(_on_minigame_finished)
	_minigame_screen.legacy_bonus_earned.connect(_on_legacy_bonus_earned)
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
	# Match the vertical gaps between the action row, the ladder, and the wage panel to the tab
	# panel's own 24px content margin (make_tab_panel_style). The tab panel already insets the
	# content 24px on every outer side, so with this separation the top action row gets an equal
	# 24px on ALL sides (its bottom gap now matches its top/left/right), and likewise the bottom
	# clock-in wage panel gets an equal 24px on all sides (its top gap now matches). The two top
	# buttons keep their own tighter 10px spacing — that's the action_row HBox below, not this gap
	# (Tim, 2026-07-01: uniform margin around the button groups, but not between the two buttons).
	v.add_theme_constant_override("separation", 24)

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

	# Global buy-mode toggle: one button cycles ×1 → ×10 → NEXT TIER → MAX; every row follows.
	_buy_mode_button = Button.new()
	_buy_mode_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_buy_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# FONT_SUBHEAD, deliberately matching the TURBO button's readout beside it — the two
	# were resized together (Tim, 2026-07-07; both had been FONT_BUTTON and read small).
	_buy_mode_button.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_buy_mode_button.add_theme_font_override("font", UiPalette.make_bold_font())
	UiPalette.style_button(_buy_mode_button, false)
	_buy_mode_button.text = "BUY: " + _buy_mode_caption(_buy_mode)
	_buy_mode_button.pressed.connect(_on_buy_mode_toggled)
	# A second finger can cycle the buy mode while the first holds a rush (Tim, 2026-07-07).
	_buy_mode_button.add_child(SecondaryTapButton.new())
	action_row.add_child(_buy_mode_button)

	# The property ladder: the rows in a vertical scroll (GDD §2), hosted in a plain
	# Control so the two overlays can sit ON the list without reserving layout space:
	# the ScrollEdgeArrows paging strips (Tim, 2026-07-05), and the GhostScrollBar.
	# The native scrollbar is gone entirely (Tim, 2026-07-08) — it spent horizontal
	# space on a control nobody drags on a phone. The rows take its full width, and the
	# ghost handle fades in over them only while the list is actually scrolling.
	var ladder_area := Control.new()
	ladder_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ladder_area)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ladder_area.add_child(scroll)
	_ladder_scroll = scroll

	var ladder_arrows := ScrollEdgeArrows.new()
	ladder_arrows.setup(scroll)
	ladder_area.add_child(ladder_arrows)

	# The transient scroll-position indicator, drawn over everything on the right edge.
	var ghost_bar := GhostScrollBar.new()
	ghost_bar.setup(scroll)
	ladder_area.add_child(ghost_bar)

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

	# The Estate Office (Legacy upgrade shop + staff retention) lives right here on the tab,
	# not behind a modal button. It fills the tab and reads/writes the live upgrade state;
	# _show_tab refreshes it on entry, and purchases re-apply effects. It is added FIRST so it
	# takes all the vertical slack and the prestige button pins to the bottom (Tim, 2026-06-28).
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

	# The dynasty's long-arc score, just above the prestige exit (Tim, 2026-07-05):
	# every Legacy gem the bloodline has ever banked, across all successions. A
	# RichTextLabel so the gem image stands in for the word "Legacy" (the same inline-
	# image pattern the plan button uses). Refreshed by _update_plan_button.
	_lifetime_earned_label = RichTextLabel.new()
	_lifetime_earned_label.bbcode_enabled = true
	_lifetime_earned_label.fit_content = true
	_lifetime_earned_label.scroll_active = false
	_lifetime_earned_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lifetime_earned_label.add_theme_font_override("normal_font", UiPalette.make_bold_font())
	# FONT_SUBHEAD (41) + 60% ≈ 66 (Tim, 2026-07-05).
	_lifetime_earned_label.add_theme_font_size_override("normal_font_size", 66)
	_lifetime_earned_label.add_theme_color_override("default_color", UiPalette.DARK_GOLD)
	# Mipmapped filtering so the inline gem image downscales smoothly rather than aliasing.
	_lifetime_earned_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# RichTextLabels need a real minimum size or they render as stray pixels (memory note).
	_lifetime_earned_label.custom_minimum_size = Vector2(0, 88)
	v.add_child(_lifetime_earned_label)

	# The prestige exit, pinned to the BOTTOM of the tab (Tim, 2026-06-28): plan the estate,
	# pass on, raise a faster heir. Red = big commit.
	_plan_button = Button.new()
	# Was STANDARD_BUTTON_HEIGHT × 1.4 (matching the Settings tuning buttons); raised to
	# × 2.0 for the two-row label — PASS THE TORCH over the gem count (Tim, 2026-07-05).
	_plan_button.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 2.0))
	UiPalette.style_button(_plan_button, true)
	_plan_button.pressed.connect(_on_plan_estate_pressed)
	v.add_child(_plan_button)

	# The button's label is a RichTextLabel so the parenthetical can show the legacy-gem image
	# inline (Tim, 2026-06-28). It is bold and sized to match the Settings tuning buttons'
	# font (Tim, 2026-07-01). A CenterContainer centers it over the button; both ignore the
	# mouse so the press still reaches the button.
	var plan_center := CenterContainer.new()
	plan_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan_button.add_child(plan_center)

	_plan_label = RichTextLabel.new()
	_plan_label.bbcode_enabled = true
	_plan_label.fit_content = true
	_plan_label.scroll_active = false
	_plan_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_plan_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan_label.add_theme_font_override("normal_font", UiPalette.make_bold_font())
	# Was 50 (the Settings tuning buttons' size); +40% → 70 (Tim, 2026-07-05).
	_plan_label.add_theme_font_size_override("normal_font_size", 70)
	_plan_label.add_theme_color_override("default_color", UiPalette.PALE_GOLD)
	# Mipmapped filtering so the inline gem image downscales smoothly rather than aliasing.
	_plan_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plan_center.add_child(_plan_label)
	_plan_label.text = "[center]PLAN THE ESTATE[/center]"

	return v


## Settings tab: player options. Today the prestige-minigame toggle and the dev panel
## entry; later, audio / haptics. (Was previously a deferred standalone screen.)
##
## Layout (Tim, 2026-06-26): the settings options live in a transparent, gray-outlined panel
## held well clear of the screen edges; the two tuning buttons are pushed to the very bottom,
## below that panel, sitting larger and bolder than the in-panel options.
func _build_settings_tab() -> Control:
	# Settings content now sits directly inside the shared per-tab panel
	# (UiPalette.wrap_in_tab_panel), which supplies the edge margin, gray outline, and inner
	# padding this tab used to build for itself — so every tab is framed identically. Everything,
	# including the bottom tuning buttons, lives inside that one panel.
	#
	# The tab holds TWO pages sharing one slot (Tim, 2026-07-06): the normal settings page,
	# and the Balance Tuning panel the BALANCE TUNING button swaps in (its Close swaps back).
	# It used to be a full-screen overlay; embedded, it reads as part of Settings.
	var stack := Control.new()

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 24)

	# The shared tab-title style (UiPalette.make_tab_title) — the same centered, faux-bold,
	# FONT_HEADLINE×1.4 navy heading every tab now uses.
	v.add_child(UiPalette.make_tab_title("SETTINGS"))

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
	v.add_child(_minigame_check)

	# A spacer pushes the two tuning buttons to the bottom of the panel, clear of the options above.
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

	# About: opens the modal with the logo, name, version, and credits (Tim, 2026-07-09).
	var about_button := Button.new()
	about_button.custom_minimum_size = Vector2(0, tuning_button_height)
	about_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(about_button, false)
	about_button.text = "ABOUT"
	about_button.pressed.connect(_on_about_pressed)
	bottom_buttons.add_child(about_button)

	stack.add_child(v)
	_settings_page = v

	# The Balance Tuning panel, hidden until its button swaps it in. Main applies its
	# edits by saving overrides + reloading the scene, and routes its save-wipe action.
	_dev_panel = DevTuningPanel.new()
	_dev_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_panel.setup()
	_dev_panel.apply_requested.connect(_on_dev_apply_requested)
	_dev_panel.defaults_requested.connect(_on_dev_defaults_requested)
	_dev_panel.reset_dynasty_requested.connect(_on_dev_reset_dynasty_requested)
	_dev_panel.closed.connect(_on_dev_closed)
	stack.add_child(_dev_panel)

	return stack


## Build the bottom tab bar: four equal icon buttons pinned along the bottom.
func _build_tab_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)

	var icons := [
		"res://art/icons/tab_property.svg",
		# The legacy gem IS the Estate tab's identity — the same art as the wallet and
		# the Pass-the-Torch button, replacing the placeholder glyph (Tim, 2026-07-08).
		"res://art/icons/legacy_gem.svg",
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
		# The Estate tab carries the "you have Legacy to claim" red-dot badge. Its gem
		# icon also DOWNSCALES (252px art → 113px slot, unlike the 81px placeholder
		# glyphs that scale up), so it needs the mipmapped filter to avoid aliasing —
		# the same fix every other gem render uses.
		if i == TAB_ESTATE:
			_estate_badge = _make_estate_badge(b)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


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

## The hero panel's income headline: the sum of the per-second rate each property row
## currently shows (see PropertyRow.get_displayed_income_per_sec).
func _sum_displayed_property_income() -> float:
	var total := 0.0
	for row in _rows:
		total += (row as PropertyRow).get_displayed_income_per_sec()
	return total


func _on_buy_requested(prop_index: int, mode: PropertyRow.BuyMode) -> void:
	var prop := game.economy.properties[prop_index] as PropertyState
	var count := 0
	match mode:
		PropertyRow.BuyMode.ONE:
			count = 1
		PropertyRow.BuyMode.TEN:
			count = 10
		PropertyRow.BuyMode.NEXT_TIER:
			# Exactly enough to reach the next milestone threshold (0 past the last tier).
			count = maxi(0, prop.get_next_milestone_count() - prop.units_owned)
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


## Player pressed a row's staff button: buy the next rung of that property's sequential
## staff ladder (hiring IS level 1 of each block — GDD §6.1, epoch-depth redesign). The
## row re-reads game state every frame, so a purchase shows on the next _process refresh.
func _on_hire_requested(prop_index: int) -> void:
	game.try_buy_staff_level(prop_index)


func _on_wage_tapped() -> void:
	game.tap_wage()


func _on_wage_hold_tapped() -> void:
	game.hold_tap_wage()


func _on_pop_requested() -> void:
	game.pop_frenzy()


## Player opened Balance Tuning: swap it into the Settings tab's slot, seeded with the
## live config (baked defaults + any active overrides) for the editor values, plus a
## pristine baked copy so it can tell which constants are overridden and diff on Apply.
func _on_dev_pressed() -> void:
	_settings_page.visible = false
	_dev_panel.open(tuning, ConfigLoader.load_tuning(false))


## Open the Minigame Tuning review screen (Settings). The economy freezes while it is up
## (see _process), just like the other full-screen overlays.
func _on_minigame_tuning_pressed() -> void:
	_minigame_review_screen.open()


## About pressed: show the modal with the logo, name, version, and credits. Its own Back button
## hides it again (no state to restore — the game keeps running behind it).
func _on_about_pressed() -> void:
	_about_screen.open()


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


## Balance Tuning closed without applying: restore the Settings tab's normal page.
## (Apply/Defaults/Wipe reload the whole scene, which rebuilds everything anyway.)
func _on_dev_closed() -> void:
	_settings_page.visible = true


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
	# SQUARE img dims below: the gem SVG's canvas is square (252×252), so the old forced
	# non-square boxes (50×70, 48×67) squished the gem ~28% narrower than the Estate
	# tab's aspect-keeping wallet icon — the mismatch Tim spotted (2026-07-08).
	if can_succeed:
		# Two centered rows (Tim, 2026-07-05): the verb on top, the banked gems beneath —
		# "(+x [gem])", the legacy-gem image standing in for the word "Legacy".
		_plan_label.text = "[center]PASS THE TORCH\n+%d [img width=70 height=70]res://art/icons/legacy_gem.svg[/img][/center]" % dynasty.projected_legacy_gain()
	else:
		_plan_label.text = "[center]PASS THE TORCH[/center]"

	# The lifetime-earned line above the button (Tim, 2026-07-05). Repainted only when the
	# value actually changes — rebuilding rich text every frame would be wasted parsing.
	if dynasty.upgrades.earned_lifetime != _shown_lifetime_earned:
		_shown_lifetime_earned = dynasty.upgrades.earned_lifetime
		# Gem image scaled with the 66px text so the pair keeps its proportions.
		_lifetime_earned_label.text = "[center][img width=67 height=67]res://art/icons/legacy_gem.svg[/img] Lifetime Earned: %d[/center]" % _shown_lifetime_earned


## First contact: a new epoch was reached this tick. Show the beat (Main's _process
## guard freezes the economy while it is up). We remember the tier so that when the player
## answers the call (_on_contact_dismissed) we can negotiate the trade deal for that epoch's
## new alien property. (If a single huge tick crossed two epochs, the later contact's beat
## simply replaces this one — vanishingly rare given epochs are ~30× apart.)
func _on_contact_made(new_tier: int) -> void:
	# Swap the play-field backdrop to match the newly reached epoch before the beat plays,
	# so when the first-contact overlay clears the player is looking at the new world.
	_background.texture = load(_background_path_for_tier(new_tier))
	_pending_contact_tier = new_tier
	_first_contact_overlay.show_contact(new_tier)


## The player answered the contact call (the overlay's "ANSWER THE CALL"). If this epoch opened a
## new alien property type, negotiate the trade deal for it (GDD §5.5 site 2): the minigame's
## performance sets a permanent, upside-only bonus on that property (income + cycle-time; the floor
## is always its base income). Epochs with no new property just resume play. Opting out of minigames
## simply forgoes the bonus — the property still unlocks at its base income, and you own none of it.
func _on_contact_dismissed() -> void:
	var tier := _pending_contact_tier
	_pending_contact_tier = 0
	var prop_index := game.economy.get_property_index_for_unlock_tier(tier)
	if prop_index < 0:
		return  # no new business this epoch — nothing more to negotiate

	if not game.ui_minigame_enabled:
		# Opted out: the new property unlocks at base income; no minigame means no bonus. The bonus
		# is upside-only, so opting out costs nothing but the potential upside. Nothing to grant.
		return

	var prop := game.economy.properties[prop_index] as PropertyState
	_minigame_site = MinigameSite.FIRST_CONTACT
	_first_contact_prop_index = prop_index
	_minigame_screen.set_legacy_lifetime(dynasty.upgrades.earned_lifetime)
	# Frame the negotiation around the property's per-unit base income, so the result reads as the
	# opening income you talked your way into rather than an abstract score.
	_minigame_screen.start_game(
		MinigameScreen.first_contact_reward(prop.get_single_unit_income_per_cycle(), prop.config.display_name),
		dynasty.upgrades.minigame_bonus_max()
	)


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


## Snapshot of the bloodline's staff-ladder achievements vs. the dynasty's retained
## levels, for the Estate Office's Household Staff section (GDD §6.3). Retention is
## bought against the highest level ANY generation ever reached (Tim, 2026-07-04) —
## prestige resets the living ladder, not the family's record — so this lists every
## property the bloodline has ever staffed, and it never empties after a succession.
func _build_retention_entries() -> Array:
	var entries: Array = []
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		var retained_levels := dynasty.staff_retention.get_retained_levels(i)
		var best_levels := maxi(prop.staff_level, dynasty.staff_retention.get_ladder_high(i))
		if best_levels < 1 and retained_levels < 1:
			continue
		# One level at a time, up to the bloodline's best; -1 = nothing left to buy.
		var next_level := retained_levels + 1
		var cost := -1
		var can_afford := false
		if next_level <= best_levels:
			cost = dynasty.staff_retention.cost_for_level(i, next_level)
			can_afford = dynasty.upgrades.available >= cost
		# Show the roster's face: the staffer of the deepest block the bloodline has
		# reached, named by that block's absolute epoch on this property's ladder.
		var shown_blocks := prop.staff_block_of_level(maxi(maxi(best_levels, retained_levels), 1))
		entries.append({
			"index": i,
			"property_name": (prop.config as PropertyConfig).display_name,
			"staffer_name": EpochCatalog.staffer_name(prop.staff_block_epoch(shown_blocks), i),
			"best_levels": best_levels,
			"retained_levels": retained_levels,
			"cost": cost,
			"can_afford": can_afford,
		})
	return entries


## Player bought one level of staffer retention in the Estate Office. Spend the Legacy,
## refresh the shop (wallet, upgrade cards, and the staff rows), and persist. The staff
## rows are updated IN PLACE (not rebuilt) so a held RETAIN button survives the refresh —
## rebuilding would free the very button under the player's finger and break the hold.
func _on_retain_requested(property_index: int) -> void:
	if dynasty.buy_staff_retention(property_index):
		_legacy_screen.refresh()
		_legacy_screen.update_retention_entries(_build_retention_entries())
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
		_minigame_screen.set_legacy_lifetime(dynasty.upgrades.earned_lifetime)
		_minigame_screen.start_game(
			MinigameScreen.legacy_reward(dynasty.projected_legacy_gain()),
			dynasty.upgrades.minigame_bonus_max()
		)
	else:
		# Opting out banks the keep floor — skipping is the worst result (GDD §5.5).
		_finalize_succession(tuning.minigame_keep_floor)


## The minigame reported a Legacy-gem bonus (Plans/Legacy_Bonus_System.md): the host already sized
## the grant from the round result and this generation's lifetime Legacy, so we just bank it to the
## spendable wallet (unearned — not added to earned_lifetime), refresh the estate readout, and save.
func _on_legacy_bonus_earned(amount: int) -> void:
	if amount <= 0:
		return
	dynasty.upgrades.grant_bonus(amount)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())


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
		MinigameSite.FIRST_CONTACT:
			_finish_first_contact_minigame(multiplier)
		_:
			# SUCCESSION (and any unexpected NONE) finalize the death with the multiplier.
			_finalize_succession(multiplier)


## Player chose to gamble the overnight pile (the RISK IT button on the welcome screen). The
## base pile is already banked; this round scales it across a fixed 50%–200% range
## (WELCOME_BACK_BONUS_MAX, not the upgrade-driven cap), and _finish_welcome_back_minigame
## credits the +/- delta before re-showing the welcome screen with the final haul.
func _on_welcome_risk_pressed() -> void:
	_minigame_site = MinigameSite.WELCOME_BACK
	_minigame_screen.set_legacy_lifetime(dynasty.upgrades.earned_lifetime)
	_minigame_screen.start_game(
		MinigameScreen.offline_pile_reward(_pending_offline_pile),
		WELCOME_BACK_BONUS_MAX
	)


## The First Contact negotiation produced `multiplier`: map it to a permanent, upside-only bonus on
## the new alien property (GDD §5.5 site 2). The contact narration already played, so there is no
## closing beat — the player drops back into the now-bigger game with the property unlocked (owning
## none) and its bonus set. Save so the bonus survives a crash before the next autosave.
func _finish_first_contact_minigame(multiplier: float) -> void:
	if _first_contact_prop_index >= 0:
		var prop := game.economy.properties[_first_contact_prop_index] as PropertyState
		var bonus := _first_contact_bonus_for(multiplier)
		prop.set_first_contact_bonus(bonus[0], bonus[1])
		SaveManager.save_dict_to_file(dynasty.to_save_dict())
	_first_contact_prop_index = -1


## Map a First Contact minigame multiplier to the permanent property bonus, as
## [income_multiplier, cycle_multiplier]. Reads the ONE shared table (MinigameScreen.FIRST_CONTACT_
## BUCKETS) so the bonus applied here and the bucket the result screen announces can never disagree.
## The floor is always base (1.0 / 1.0 — upside-only, never a penalty); a run into the bonus band is
## sorted low / medium / high (Plans/First_Contact_Property_Reward.md).
func _first_contact_bonus_for(multiplier: float) -> Array:
	var bucket := MinigameScreen.first_contact_bucket(multiplier, dynasty.upgrades.minigame_bonus_max())
	var info: Dictionary = MinigameScreen.FIRST_CONTACT_BUCKETS[bucket]
	return [float(info["income"]), float(info["cycle"])]


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
	_buy_mode_button.text = "BUY: " + _buy_mode_caption(_buy_mode)
	for row in _rows:
		(row as PropertyRow).set_buy_mode(_buy_mode)


func _buy_mode_caption(mode: PropertyRow.BuyMode) -> String:
	match mode:
		PropertyRow.BuyMode.ONE:
			return "×1"
		PropertyRow.BuyMode.TEN:
			return "×10"
		PropertyRow.BuyMode.NEXT_TIER:
			# "NEXT", not "NEXT TIER": the longer caption widened the button and shifted
			# the action row's layout as the modes cycled (Tim, 2026-07-07).
			return "NEXT"
		PropertyRow.BuyMode.MAX:
			return "MAX"
	return "×1"
