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
var _momentum_bar: MomentumBar
var _wage_panel: WagePanel
var _welcome_overlay: WelcomeBackOverlay
var _about_screen: AboutScreen
var _stats_screen: StatsScreen
var _help_screen: HelpScreen
var _will_screen: WillScreen
var _legacy_screen: LegacyScreen
var _ledger_screen: FamilyLedgerScreen
var _dev_panel: DevTuningPanel
var _minigame_screen: MinigameScreen
var _minigame_review_screen: MinigameReviewScreen
var _challenges_screen: ChallengesScreen
## The tutorial coach card (Plans/Tutorial_Onboarding_Plan.md) — one instance, fired by
## _maybe_show_tip the first time a system becomes relevant, anchored near the relevant control.
var _tutorial_tip: TutorialTip
## Poll-driven tutorial tips {tip_id -> armed}: tips that can't hang off a single verb (TURBO
## becoming poppable, reaching a new epoch, having played a minigame) are watched each frame in
## _process. Armed once at build (a disk read) so the per-frame check only touches memory.
var _tip_armed := {}
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

# Epoch PAGER (Tim 2026-07-11): the property ladder is split into epoch "tabs" — one per
# epoch, tab = tier − 1 (the Earth split made Blue and White Collar full epochs, tiers 1-2).
# The pager shows ONE tab at a time (big label + ‹ › arrows + dots + swipe), so only that
# tab's rows ever draw (the CPU win at 326 properties).
var _epoch_tab := 0
var _epoch_pager_label: Label       # the big civilization / "EARTH" name
var _epoch_pager_sub: Label         # the "Blue Collar" / "White Collar" subtitle (blank for aliens)
var _epoch_prev_button: Button
var _epoch_next_button: Button
## Red dot on the pager's NEXT button, shown when the player has earned enough to advance but hasn't
## bought all of the current era's properties (the ownership gate is blocking; Tim, 2026-07-23).
var _epoch_next_badge: Panel
var _epoch_pager_dots: EpochPagerDots
var _epoch_pager_box: Control       # the pager header (label + arrows + dots + MAKE CONTACT)
## MAKE CONTACT (Plans/Epoch_Advance_Rework.md §2): the epoch no longer advances by itself —
## _create_game turns EpochState.auto_advance off — so leaving an era is this button's tap.
## Always present, gray + disabled until game.epoch.contact_ready (the standing no-moving-UI rule).
var _make_contact_button: Button
## The button's caption, held separately so the ready pulse can scale it (see _set_contact_caption).
var _contact_label: Label
## Which colour the caption is currently wearing, so the override is only re-applied on a flip.
## Starts TRUE against an initial not-ready state, which forces the first refresh to paint the
## disabled colour — without that the caption would sit pale gold on a grayed plate until the
## epoch first became ready.
var _contact_caption_ready := true
## Drives the ready-state brightness pulse below; reset to 0 whenever the button is not pressable.
var _contact_pulse_time := 0.0
## How the READY state shouts. Missing this button stalls the whole run (epoch advance is the
## progression spine), so a static enabled plate is not enough — it breathes brighter on the beat.
const CONTACT_PULSE_HZ := 1.2
const CONTACT_PULSE_BRIGHTNESS := 0.35
## How much the caption grows at the top of the pulse (0.12 = +12%). Kept modest on purpose:
## the plate does not move, so a large swing would read as the text sliding around inside a
## fixed box rather than as a heartbeat.
const CONTACT_PULSE_SCALE := 0.12
var _ladder_area: Control           # the property-list region; swipes over either change tabs
var _swipe_tracking := false        # a touch is down on the ladder, tracking for a horizontal swipe
var _swipe_start := Vector2.ZERO
var _swipe_delta := Vector2.ZERO
var _swipe_hold_seen := false       # a held action (rush/buy/hire) was engaged at some point this
									# gesture — if so, this gesture can NEVER become a tab swipe
var _swipe_start_scroll := 0        # the ladder scroll when this gesture began — restored before a
									# swipe switches tabs, so the swipe's own drag doesn't corrupt
									# the leaving tab's remembered scroll position
const EPOCH_SWIPE_THRESHOLD := 60.0  # px of horizontal travel to count as a tab swipe

# "New ventures" nudge: pop a modal the first time a tab the player hasn't opened has a property
# they can afford, so the pager's hidden tabs stay discoverable (Tim 2026-07-11).
var _venture_overlay: NewVenturesOverlay
var _tab_unlocked: Array = []         # tabs the player can open yet (persisted once true)
var _tab_seen: Array = []             # tabs the player has viewed — a seen tab is never nudged
var _tab_nudged: Array = []           # tabs already nudged — fire at most once each
var _tab_scroll: Array = []           # each tab's last scroll offset (0 = first visit / top)
var _pending_venture_tab := -1        # the tab the live nudge points at (for its "SHOW ME")
var _venture_check_timer := 0.0
const VENTURE_CHECK_INTERVAL := 0.5   # how often to scan for a newly-affordable unopened tab

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
# Each tab has two art versions (Plans/Tab_Bar_Icon_Treatment.md): a black-and-white
# silhouette for the INACTIVE state and a full-color version for the ACTIVE ("you are
# here") state. Same outline/size/anchor in both, so the swap reads as the icon lighting
# up, not a replacement. Cached once at build; the live swap happens in _style_tab_button.
var _tab_icon_inactive: Array = []  # silhouette Textures, indexed by TAB_*
var _tab_icon_active: Array = []    # full-color Textures, indexed by TAB_*
# The active-tab icon CROSS-FADES in rather than hard-swapping: each button keeps its silhouette
# as its always-on icon, and a full-color TextureRect overlays it and fades its opacity 0<->1 when
# the tab gains/loses focus (Plans/Tab_Bar_Icon_Treatment.md). One overlay + one live Tween per tab.
var _tab_icon_overlay: Array = []   # full-color overlay TextureRects, indexed by TAB_*
var _tab_icon_tween: Array = []     # the in-flight fade Tween per tab (killed on re-trigger)
var _active_tab: int = TAB_PROPERTY
var _minigame_check: CheckBox  # the Settings-tab "play the minigame" toggle
var _tutorial_check: CheckBox  # the Settings-tab "show tutorial tips" toggle
## The Settings tab's three number-format rows, INDEXED BY Money.Format (so
## _currency_format_rows[Money.Format.ALPHABET] is the ALPHABET row). One always-visible row
## per mode; the active one is restyled, never hidden or moved.
var _currency_format_rows: Array[Button] = []
## The fixed-width "●" marker Label at the left of each row above, same indexing. Its glyph is
## the non-color half of the active cue; the width is fixed so the mode name never shifts.
var _currency_format_markers: Array[Label] = []
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
## First Contact (GDD §5.5 site 2): the epoch tier the running negotiation minigame is
## for. Set when the contact beat is dismissed into the minigame; consumed when the
## minigame finishes and the negotiated bonus is applied to that epoch's WHOLE COHORT
## (Phase 2: the terms cover every venture in the civilization's market). 0 = none.
var _first_contact_bonus_tier: int = 0
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
	# Keep procedural staffer faces seeded to the living generation — a plain assignment that does
	# no work when unchanged, so each new dynasty's staff looks fresh (StafferFace).
	StafferFace.generation = dynasty.generation

	var modal_up := _will_screen.visible or _first_contact_overlay.visible \
			or _minigame_screen.visible or _minigame_review_screen.visible \
			or _challenges_screen.visible or _venture_overlay.visible
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

	# Poll-driven tutorial tips: fire the first time each condition is met. This runs only AFTER
	# the modal-freeze return above, so a card never lands on top of a full-screen beat.
	# The opening beat: on a fresh run the only action is Clock In, and nothing else fires until a
	# property is owned. Wait for the welcome screen to clear (it is NOT in modal_up, so guard it
	# explicitly) and only while the player still owns nothing, then point at the wage button.
	if _tip_armed.get("getting_started", false) and not _welcome_overlay.visible \
			and not _owns_any_property():
		_fire_polled_tip("getting_started", _wage_panel)
	# First business becomes affordable — direct the buy BEFORE they have to discover it. Points at
	# the buy button itself, not the whole row.
	if _tip_armed.get("first_property", false) and not _welcome_overlay.visible \
			and not _owns_any_property() \
			and game.economy.properties[0].get_next_cost() <= game.economy.cash:
		_fire_polled_tip("first_property", _buy_control_of(_row_for_index(0)))
	# Owning a business makes rushing possible — point at the portrait/rush control now, not after.
	if _tip_armed.get("first_rush", false) and _owns_any_property():
		_fire_polled_tip("first_rush", _rush_control_of(_first_owned_row()))
	# Stacking up units is when the bulk-buy modes start to matter.
	if _tip_armed.get("buy_mode", false) and _owns_multiple_units():
		_fire_polled_tip("buy_mode", _buy_mode_button)
	# A staffer is affordable somewhere — direct the hire before they stumble on it.
	if _tip_armed.get("first_hire", false):
		var hireable := _first_hireable_row()
		if hireable != null:
			_fire_polled_tip("first_hire", _hire_control_of(hireable))
	if _tip_armed.get("turbo_ready", false) and game.frenzy.can_pop():
		_fire_polled_tip("turbo_ready", _frenzy_bar)
	# Reaching cruise enables the OVERDRIVE button — teach it the first frame it lights up.
	if _tip_armed.get("overdrive", false) and not _momentum_bar.get_overdrive_button().disabled:
		_fire_polled_tip("overdrive", _momentum_bar.get_overdrive_button())
	# Tier 3+ = the first ALIEN contact: tier 2 is the Earth split's White Collar promotion,
	# and this card's "a new civilization opens a market" copy belongs to the alien beat.
	if _tip_armed.get("epochs", false) and game.epoch.current_tier >= 3:
		_fire_polled_tip("epochs", _epoch_pager_box)
	# Epoch progress gate (Tim, 2026-07-23): when the player has earned enough to advance but hasn't
	# bought all of the era's properties, (1) show a red dot on the pager's NEXT button, and (2) once,
	# a card pointing at the lowest still-missing property. Both key off the same blocking property.
	var blocking_prop := _property_blocking_epoch_progress()
	if _epoch_next_badge != null:
		_epoch_next_badge.visible = blocking_prop >= 0
	if blocking_prop >= 0 and _tip_armed.get("epoch_blocked", false) \
			and not _tutorial_tip.visible and not _any_fullscreen_overlay_visible():
		# Switch to the blocking property's tab so the card's anchor is visible, then teach the rule.
		if _epoch_tab != _epoch_tab_of(blocking_prop):
			_set_epoch_tab(_epoch_tab_of(blocking_prop))
		_fire_polled_tip("epoch_blocked", _row_for_index(blocking_prop),
				_epoch_blocked_body(blocking_prop))

	# MAKE CONTACT just lit up. Fired on AVAILABILITY like every other tip, and this one matters
	# most: the epoch will never advance on its own, so a player who does not find this button
	# stalls for good.
	if _tip_armed.get("make_contact", false) and game.epoch.contact_ready:
		_fire_polled_tip("make_contact", _make_contact_button)

	# The first time the player is viewing Earth White Collar (the second pager tab), point out the
	# LEFT arrow so they learn the pager pages back and forth between eras (Tim, 2026-07-25).
	# _maybe_show_tip already holds the card until no overlay is up, so it lands on the game screen.
	if _tip_armed.get("epoch_navigation", false) and _epoch_tab == 1:
		_fire_polled_tip("epoch_navigation", _epoch_prev_button)

	# Progressive tab unlocking (Plans/Tutorial_Onboarding_Plan.md §9): the Estate tab unlocks when
	# the player can FIRST prestige (you prestige FROM that tab, so it must open before the first
	# prestige, not after); the Family Ledger after the first prestige (it has ancestors to show
	# only then). Keep the locked/enabled state fresh, and fire an attention card at each tab the
	# frame it goes live.
	_refresh_locked_tabs()
	if _tip_armed.get("prestige", false) and _estate_unlocked():
		_fire_polled_tip("prestige", _tab_buttons[TAB_ESTATE])
	if _tip_armed.get("family_ledger", false) and _ledger_unlocked():
		_fire_polled_tip("family_ledger", _tab_buttons[TAB_LEDGER])

	# Nudge the player toward an unopened tab the moment its first venture becomes affordable.
	_venture_check_timer += delta
	if _venture_check_timer >= VENTURE_CHECK_INTERVAL:
		_venture_check_timer = 0.0
		_update_tab_unlocks()
		_check_new_ventures()

	# The hero stat's planet watermark follows the epoch pager's ACTIVE TAB, not the reached
	# epoch (Tim 2026-07-15) — page back to Earth and the header shows Earth. Tab = tier − 1
	# since the Earth split; both Earth tiers map to the Earth image in HeroStat's table. (The
	# civilization NAME moved to the pager itself — it was duplicative here.) The prestige-exit
	# button and the Estate Office button (with its Legacy balance) reflect the live state.
	_hero_stat.set_planet_tier(_epoch_tab + 1)
	_refresh_contact_progress()
	_refresh_make_contact_button(delta)
	_update_plan_button()
	_update_estate_badge()
	_update_ladder_edge_fade()


## Apply the ladder's edge fade — the shared "partial transparency = the list continues"
## treatment (ScrollEdgeArrows.apply_edge_fade; also worn by Balance Tuning + Challenges).
func _update_ladder_edge_fade() -> void:
	if _active_tab != TAB_PROPERTY:
		return
	ScrollEdgeArrows.apply_edge_fade(_ladder_scroll, _rows)


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
	# ALIEN eras advance on FLAGSHIP UNITS, not money (EpochState._may_leave), and the money
	# threshold there is crossed minutes before the real gate opens — so a money bar would pin at
	# 100% while the player was still blocked. Track the requirement that actually gates them, and
	# the bar fills exactly as MAKE CONTACT lights up. A zero `required` means the rule does not
	# apply (Earth eras, or the knob at its no-op default) and we fall through to the money bar.
	# Owned is clamped for display: nothing stops a player lingering past the requirement, and
	# "FLAGSHIP 41 / 35" would read as broken rather than as "done".
	var flagship := game.get_flagship_progress(tier)
	if flagship.y > 0:
		# Name the property rather than saying "FLAGSHIP" (Tim, 2026-07-31): the player has to go
		# buy a specific row, and the era's own business name says which one. Falls back to the
		# generic word only if the lookup somehow fails, so the bar can never read "  21 / 35".
		var flagship_index := game.get_flagship_index(tier)
		var flagship_name := "FLAGSHIP"
		if flagship_index >= 0:
			var flagship_prop := game.economy.properties[flagship_index] as PropertyState
			flagship_name = (flagship_prop.config as PropertyConfig).display_name
		# Name and counts are passed SEPARATELY so HeroStat can set the property icon between
		# them; it renders as "<name>   [icon] 21 / 35".
		_hero_stat.set_epoch_progress(float(flagship.x), float(flagship.y), flagship_name,
				"%d / %d" % [mini(flagship.x, flagship.y), flagship.y])
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
	# Push the carbonation speed-tier ladder into GoldBubbles' shared static table (Tim, 2026-07-10):
	# every bubble crowd reads the same tier speeds, so setting it once here (re-run on a scene reload
	# after a Balance Tuning Apply) lets the ladder be tuned live without threading tuning per-bar.
	GoldBubbles.tier_speed_px = [
		tuning.carb_tier_idle_px, tuning.carb_tier_flowing_px,
		tuning.carb_tier_rushed_px, tuning.carb_tier_frenzy_px,
	]
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

	# In the PLAYED game, reaching an epoch's requirements does not advance it — the player
	# presses MAKE CONTACT when they are ready (Plans/Epoch_Advance_Rework.md §2). The headless
	# sims leave auto_advance TRUE so their playouts still climb by themselves.
	#
	# This is set here rather than at first boot because a NEW GameState is built on every path
	# into the game — fresh run, loaded save, and the scene reload that follows a succession or a
	# Balance Tuning apply — and _create_game is the one funnel all of them pass through.
	game.epoch.auto_advance = false

	# Restore the saved buy-mode preference (defaults to ×1 for a fresh game).
	_buy_mode = game.ui_buy_mode as PropertyRow.BuyMode

	# Restore the saved number-format preference the same way, and push it into the formatter
	# BEFORE any screen is built — Money.format_mode is a static every readout reads, so setting
	# it here means the very first frame already renders in the chosen format.
	Money.format_mode = game.ui_currency_format


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
	# Hide the ENTIRE game view (hero stat + property ladder + all their carbonation bars) while a
	# full-screen modal is up (see _process): a covered Control is not culled — it keeps drawing every
	# frame under the opaque overlay, and the ladder's bubble bars are a real per-frame GPU spend that
	# showed up as minigame lag. This list was declared long ago but never populated (Tim, 2026-07-11).
	_covered_game_layers.append(viewing_area)

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

	# The Help / Glossary modal (Settings → Help): a reference of every tutorial concept plus a
	# "Replay tutorial" action that re-arms the one-time cards.
	_help_screen = HelpScreen.new()
	_help_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help_screen.replay_requested.connect(_on_replay_tutorial)
	add_child(_help_screen)

	# The Statistics modal (Settings → Stats), hidden until opened. Reads the bloodline for its
	# stat rows; its own Back button closes it (nothing to restore — the game runs behind it).
	_stats_screen = StatsScreen.new()
	_stats_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_screen.set_dynasty(dynasty)
	_stats_screen.closed.connect(_on_stats_closed)
	add_child(_stats_screen)

	# The "new ventures" nudge (epoch pager discoverability), hidden until a next tab first
	# becomes affordable. SHOW ME jumps to it; NOT NOW closes.
	_venture_overlay = NewVenturesOverlay.new()
	_venture_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_venture_overlay.show_requested.connect(_on_venture_show_requested)
	add_child(_venture_overlay)

	# The first-contact overlay (GDD §6.2): shown when a generation consumes the current
	# economy and reaches the next alien epoch. Main freezes the economy while it is up so
	# the beat lands. EpochState.contact_made fires it; it is rebuilt with the generation
	# on each scene reload, so its connection always points at the living epoch state.
	_first_contact_overlay = FirstContactOverlay.new()
	_first_contact_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_first_contact_overlay)

	# The tutorial coach card sits on top of everything (added last), hidden until a first-time
	# tip fires. It is non-blocking — taps outside the card pass through to the game.
	_tutorial_tip = TutorialTip.new()
	add_child(_tutorial_tip)
	# Arm the poll-driven tips once (disk read here; the per-frame poll then only reads memory).
	# Armed only when tips are ON, so a disabled tutorial does zero per-frame disk work. These fire
	# on AVAILABILITY (the action just became possible) so they DIRECT the player, rather than after
	# the fact (Tim, 2026-07-23).
	var tips_on := TutorialProgress.is_enabled()
	for tip_id in ["getting_started", "first_property", "first_rush", "buy_mode", "first_hire",
			"turbo_ready", "overdrive", "epochs", "epoch_blocked", "make_contact",
			"epoch_navigation", "prestige", "family_ledger"]:
		_tip_armed[tip_id] = tips_on and not TutorialProgress.has_seen(tip_id)
	# Signal-driven tip: the vent gesture, fired during an overdrive rush. (The offline-earnings
	# concept is NOT a card — it is taught as a permanent line ON the welcome-back screen itself,
	# see WelcomeBackOverlay: a fresh launch has no "out", and that screen is the natural home for
	# the explanation. Tim, 2026-07-23.)
	game.rush_momentum.vent_window_opened.connect(_on_vent_window_opened)
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
	# A finished CHALLENGE run reports here so the dynasty can bank any newly-cleared tier
	# (Plans/Challenge_Mode.md §5 step 2). The challenge runs on the review screen's own host, so the
	# result bubbles up through it — Main holds the dynasty, credits, saves, and hands feedback back.
	# BOTH the review screen (dev shortcut) and the player-facing ChallengesScreen host challenge runs,
	# so we bind the source screen onto each connection: _on_challenge_finished renders the credit
	# feedback back to whichever screen launched the run (see that handler).
	_minigame_review_screen.challenge_finished.connect(
		_on_challenge_finished.bind(_minigame_review_screen))
	add_child(_minigame_review_screen)

	# The player-facing CHALLENGES screen (Plans/Challenge_Mode.md §3.4, Phase 3): the real home for
	# Challenge Mode, opened from the Settings CHALLENGES button. Like the review screen it owns its
	# own minigame host and freezes the economy while up; its finished runs credit through the same
	# source-bound handler so its own end view + row list refresh (not the review screen's).
	_challenges_screen = ChallengesScreen.new()
	_challenges_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenges_screen.setup(dynasty, MinigameScreen.MINIGAME_TYPES, tuning)
	_challenges_screen.challenge_finished.connect(
		_on_challenge_finished.bind(_challenges_screen))
	_challenges_screen.closed.connect(_on_challenges_closed)
	add_child(_challenges_screen)

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

	# Rush Momentum meter: fills as sustained rushing builds the income bonus, drains when the player
	# stops. Sits directly above the frenzy/TURBO row so the two reward meters read as a pair. It
	# updates itself (its own _process reads game.rush_momentum); the one verb it emits is the
	# OVERDRIVE tap (Plans/Rush_Cruise_Control.md), routed to GameState here — the same seam as
	# the frenzy bar's pop_requested below.
	_momentum_bar = MomentumBar.new()
	_momentum_bar.setup(game.rush_momentum, tuning)
	# The dynasty is read only for the overheat death chip's all-time best streak (Tim 2026-07-20).
	_momentum_bar.set_dynasty(dynasty)
	_momentum_bar.overdrive_requested.connect(_on_overdrive_requested)
	v.add_child(_momentum_bar)

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

	# Epoch pager header: the big epoch label + ‹ › arrows + position dots, above the ladder.
	# Only the active epoch's rows are drawn (PropertyRow.set_tab_active), so the property
	# count on screen stays ~6 no matter how deep the run is (Tim 2026-07-11).
	_epoch_pager_box = _build_epoch_pager()
	v.add_child(_epoch_pager_box)

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

	# Horizontal swipes over this region change epoch tabs — detected in _input (which never
	# consumes the event), so the row buttons and vertical scroll keep working. (An earlier
	# MOUSE_FILTER_PASS overlay here swallowed the buy-button taps: a PASS control forwards to
	# its PARENT, not to the buttons it covers.)
	_ladder_area = ladder_area

	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 10)
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ladder)

	# Ladder DISPLAY order: ascending base cost. A property's INDEX (its save identity)
	# is ConfigLoader.PROPERTY_PATHS order, where cohort siblings are APPENDED so old
	# saves' indices stay stable — the on-screen order is derived here instead. Cost
	# sorting interleaves the cohorts correctly (each sibling is ×3 its predecessor and
	# each next flagship ×30, so a cohort always finishes before the next epoch starts).
	var ladder_order: Array = range(game.economy.properties.size())
	ladder_order.sort_custom(func(a: int, b: int) -> bool:
		var cost_a: float = (game.economy.properties[a] as PropertyState).config.base_cost
		var cost_b: float = (game.economy.properties[b] as PropertyState).config.base_cost
		return cost_a < cost_b)
	for i in ladder_order:
		var row := PropertyRow.new()
		# game.rush_momentum is passed so the row can present the rush control as disabled while
		# rushing is locked out after an overheat (Rush Overheat, Tim 2026-07-15) — read-only.
		row.setup(i, game.economy.properties[i] as PropertyState, game.economy, game.frenzy,
				game.epoch, game.rush_momentum)
		row.buy_requested.connect(_on_buy_requested)
		row.tap_requested.connect(_on_tap_requested)
		row.hold_rush_requested.connect(_on_hold_rush_requested)
		row.rush_hold_released.connect(_on_rush_hold_released)
		row.rush_pressed.connect(_on_rush_pressed)
		row.rush_released.connect(_on_rush_released)
		row.hire_requested.connect(_on_hire_requested)
		row.set_buy_mode(_buy_mode)
		ladder.add_child(row)
		_rows.append(row)

	# Tab gating + the "new ventures" nudge trackers. Blue Collar (tab 0) always starts open;
	# _update_tab_unlocks() then opens any tab the current save already qualifies for.
	_tab_unlocked.resize(_epoch_tab_count())
	_tab_unlocked.fill(false)
	_tab_unlocked[0] = true
	_tab_seen.resize(_epoch_tab_count())
	_tab_seen.fill(false)
	_tab_nudged.resize(_epoch_tab_count())
	_tab_nudged.fill(false)
	# Each tab remembers its own scroll offset; 0 means never-visited (opens at the top).
	_tab_scroll.resize(_epoch_tab_count())
	_tab_scroll.fill(0)
	_update_tab_unlocks()
	# Open on the deepest UNLOCKED tab (where the player is actively buying) and paint the pager.
	_set_epoch_tab(_epoch_default_tab())

	_wage_panel = WagePanel.new()
	_wage_panel.setup(game.wage, tuning, game.frenzy)
	_wage_panel.wage_tapped.connect(_on_wage_tapped)
	_wage_panel.wage_hold_tapped.connect(_on_wage_hold_tapped)
	v.add_child(_wage_panel)

	return v


# ---------------------------------------------------------------------------
# Epoch pager — the property ladder's per-epoch tabs (Tim 2026-07-11)
# ---------------------------------------------------------------------------

## Number of pager tabs: one per epoch, since the Earth split (Plans/Earth_Split_Epochs.md)
## made Blue Collar and White Collar full epochs. Tab = tier − 1, uniformly.
func _epoch_tab_count() -> int:
	return EpochCatalog.tier_count()


## Which tab a property index belongs to: its epoch's tab. Blue Collar (unlock_tier 1) is
## tab 0, White Collar (tier 2) tab 1, then one tab per alien epoch — tab = tier − 1.
func _epoch_tab_of(prop_index: int) -> int:
	var prop := game.economy.properties[prop_index] as PropertyState
	return (prop.config as PropertyConfig).unlock_tier - 1


## The highest tab the player can currently open (the navigation upper bound) — the deepest
## UNLOCKED tab. Tabs unlock in order (each opens at its epoch's arrival), so the deepest
## unlocked index is also the count of open tabs. See _update_tab_unlocks().
func _epoch_tab_max() -> int:
	var highest := 0
	for tab in range(_tab_unlocked.size()):
		if bool(_tab_unlocked[tab]):
			highest = tab
	return highest


## The tab to open on load: the deepest unlocked tab — where the player is actively buying.
func _epoch_default_tab() -> int:
	return _epoch_tab_max()


## Open any still-locked tab that now qualifies (persisted once open). Blue Collar (tab 0) is
## always open; every other tab opens at its epoch's ARRIVAL — White Collar at the promotion
## beat, alien tabs at First Contact. One rule since the Earth split: the epoch gate itself
## (earned the threshold + own all of the previous cohort) is what opens a tab. Repaints the
## pager when something opens so the new dot lights up. Idempotent — an open tab never re-locks.
func _update_tab_unlocks() -> void:
	if _tab_unlocked.is_empty():
		return
	var changed := false
	for tab in range(_tab_unlocked.size()):
		if bool(_tab_unlocked[tab]):
			continue
		if tab == 0 or game.epoch.current_tier >= tab + 1:
			_tab_unlocked[tab] = true
			changed = true
	if changed:
		_update_epoch_pager()


## The property the player must still buy before they can progress past the current era, or -1 if
## nothing is blocking them. Drives the epoch-blocked card AND the pager's red-dot indicator
## (Tim, 2026-07-23). Two things can block, in this order:
##   1. a business in this era they own none of (the roster half of the gate), or
##   2. on an ALIEN era, too few UNITS of the era's flagship — every business is owned and what
##      is missing is a quantity, so we point at the flagship's own row
##      (Plans/Epoch_Advance_Rework.md §4).
##
## The money threshold still decides WHEN we start pointing any of this out, even on alien eras
## where it no longer gates the advance: it is the honest "you have earned this era's whole
## economy" line, and before it the player is simply still playing the era — nothing is blocking
## them yet, so a red dot would just nag for the entire epoch.
func _property_blocking_epoch_progress() -> int:
	var tier := game.epoch.current_tier
	if tier >= EpochCatalog.tier_count():
		return -1  # final civilization — there is nothing further to be blocked from
	if game.economy.cash_earned_this_gen \
			< EpochCatalog.consume_threshold(tier, tuning.earth_economy_target):
		return -1
	for i in game.economy.get_property_indices_for_unlock_tier(tier):
		if (game.economy.properties[i] as PropertyState).units_owned <= 0:
			return i
	# Roster complete. A zero `required` means the flagship-units rule does not apply here
	# (Earth, or the knob at its no-op default), which leaves nothing blocking.
	var flagship := game.get_flagship_progress(tier)
	if flagship.y > 0 and flagship.x < flagship.y:
		return game.get_flagship_index(tier)
	return -1


## The epoch-blocked card's body for whichever requirement is actually holding the player back.
## Returns "" for the roster case, meaning "use the catalog's own copy" — only the flagship case
## needs copy built at fire time, because it has to name the count they are short of.
func _epoch_blocked_body(blocking_prop: int) -> String:
	var tier := game.epoch.current_tier
	var flagship := game.get_flagship_progress(tier)
	if flagship.y <= 0 or blocking_prop != game.get_flagship_index(tier):
		return ""
	var prop := game.economy.properties[blocking_prop] as PropertyState
	return TutorialCatalog.epoch_blocked_flagship_body(
			prop.config.display_name, flagship.x, flagship.y)


## The big label for a tab: the tab's civilization name — "EARTH" for both Earth tabs
## (their dicts share the civ), the alien race for the rest. Tab = tier − 1.
func _epoch_tab_name(tab: int) -> String:
	return EpochCatalog.civilization(tab + 1).to_upper()


## The subtitle under the name: the collar for Earth, blank for aliens (the civ name stands alone).
func _epoch_tab_sub(tab: int) -> String:
	if tab == 0:
		return "BLUE COLLAR"
	if tab == 1:
		return "WHITE COLLAR"
	return ""


func _build_epoch_pager() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	_epoch_prev_button = _make_pager_arrow("‹")
	_epoch_prev_button.pressed.connect(func() -> void: _step_epoch_tab(-1))
	row.add_child(_epoch_prev_button)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	row.add_child(center)

	_epoch_pager_label = Label.new()
	_epoch_pager_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epoch_pager_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_epoch_pager_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	_epoch_pager_label.add_theme_color_override("font_color", UiPalette.NAVY)
	# Fill the space between the arrows and WRAP a long civilization name onto a second line rather
	# than forcing the whole tab column wider than the screen (Tim, 2026-07-13: "QUARTZITE
	# CONGLOMERATE" pushed everything off the right edge). Autowrap alone does the job — do NOT add
	# text_overrun_behavior trimming on top of it: trimming tells the layout the text is disposable,
	# which collapses the label's minimum height to ~0 and it renders as nothing (Tim hit this on
	# device 2026-07-15: the pager showed no names at all).
	_epoch_pager_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epoch_pager_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	center.add_child(_epoch_pager_label)

	_epoch_pager_sub = Label.new()
	_epoch_pager_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epoch_pager_sub.add_theme_font_override("font", UiPalette.make_bold_font())
	_epoch_pager_sub.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_epoch_pager_sub.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	_epoch_pager_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epoch_pager_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	center.add_child(_epoch_pager_sub)

	_epoch_next_button = _make_pager_arrow("›")
	_epoch_next_button.pressed.connect(func() -> void: _step_epoch_tab(1))
	row.add_child(_epoch_next_button)
	# Red-dot badge (same style as the Estate tab's): lit while the ownership gate blocks epoch
	# progress, driven each frame from _property_blocking_epoch_progress in _process.
	_epoch_next_badge = _make_estate_badge(_epoch_next_button)

	_epoch_pager_dots = EpochPagerDots.new()
	box.add_child(_epoch_pager_dots)

	# MAKE CONTACT lives here, at the bottom of the epoch header, because this pager is the one
	# place on screen that is ABOUT the current era: it names the civilization the button would
	# leave, and it already carries the red dot that says "something is holding you back". The
	# button sits directly above the property ladder the requirement is bought from, so the
	# requirement, the reason, and the way out all read as one block.
	_make_contact_button = Button.new()
	# The caption is a CHILD Label, not the Button's own text, so the ready pulse can scale it
	# (Tim, 2026-07-31: the text should pulse in size, not only brightness). Scaling a child
	# Control is a pure transform — it cannot grow the plate or reflow the pager, which is what
	# pulsing a font_size override would do, since a Button's minimum size follows its font.
	# Full width and a standard-height plate: this is the single most important tap in the run,
	# so it gets the largest, easiest target the row can give it.
	_make_contact_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	_make_contact_button.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_make_contact_button.add_theme_font_override("font", UiPalette.make_bold_font())
	# Red "act" plate (Style Guide §8: red = spend/act) — pressing it spends the era, the same
	# class of deliberate, irreversible act as OVERDRIVE and PASS THE TORCH.
	UiPalette.style_button(_make_contact_button, true)
	# While contact is not yet possible the button grays its OUTLINE too, exactly like the TURBO
	# pop button and OVR: "not yet" has to read at a glance (Tim 2026-07-15).
	var disabled_plate := StyleBoxFlat.new()
	disabled_plate.bg_color = UiPalette.CREAM
	disabled_plate.border_color = UiPalette.MID_GRAY
	disabled_plate.set_border_width_all(3)
	disabled_plate.set_corner_radius_all(4)
	disabled_plate.set_content_margin_all(12)
	_make_contact_button.add_theme_stylebox_override("disabled", disabled_plate)
	_make_contact_button.pressed.connect(_on_make_contact_pressed)
	# A second finger can make contact while the first holds a rush (the same reason the buy-mode
	# and TURBO buttons carry this).
	_make_contact_button.add_child(SecondaryTapButton.new())
	_make_contact_button.disabled = true  # _refresh_make_contact_button enables it when ready

	# The caption itself. Centered over the whole plate and ignoring input, so a tap anywhere on
	# the button still presses it. Its colour is driven by _refresh_make_contact_button, because
	# the Button's own font_color overrides no longer apply to text it does not own.
	_contact_label = Label.new()
	_contact_label.text = "MAKE CONTACT"
	_contact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contact_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_contact_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_contact_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_make_contact_button.add_child(_contact_label)

	box.add_child(_make_contact_button)
	return box


## MAKE CONTACT pressed: leave this era now. advance() does nothing unless the requirements are
## currently met (so a stale tap can never skip an epoch) and emits contact_made on success, so
## the First Contact beat and the trade-deal minigame play exactly as they always have.
func _on_make_contact_pressed() -> void:
	game.epoch.advance()


## Keep MAKE CONTACT honest every frame: pressable only while the epoch's requirements are met
## and the player has not left yet. The ready state also pulses brighter — a plain enabled plate
## is easy to scroll past, and a player who never notices this button never advances again.
## The pulse multiplies brightness rather than changing color, so the red plate stays red (the
## same "flash of light, not a recolor" treatment the hero stat uses for a purchase).
func _refresh_make_contact_button(delta: float) -> void:
	if _make_contact_button == null:
		return
	var ready := game.epoch.contact_ready
	_make_contact_button.disabled = not ready
	if ready:
		_contact_pulse_time += delta
		# One 0..1 wave drives both channels, so the caption is biggest exactly when it is
		# brightest — two cues on one beat read as one emphasis, not two competing ones.
		var pulse := 0.5 + 0.5 * sin(_contact_pulse_time * TAU * CONTACT_PULSE_HZ)
		var brightness := 1.0 + CONTACT_PULSE_BRIGHTNESS * pulse
		_make_contact_button.modulate = Color(brightness, brightness, brightness)
		_set_contact_caption(true, 1.0 + CONTACT_PULSE_SCALE * pulse)
	else:
		# Reset unconditionally rather than only on a detected change: on the very first frame
		# modulate and scale already sit at their defaults, so a change test would skip this and
		# leave the caption unpainted. _set_contact_caption only touches the colour override when
		# the ready state actually flips, so running it every frame costs two property writes.
		_contact_pulse_time = 0.0
		_make_contact_button.modulate = Color.WHITE
		_set_contact_caption(false, 1.0)


## Dress the MAKE CONTACT caption: `scale` about its own centre, and the ready/not-ready colour.
## Scaling the Label rather than the Button keeps this a transform on a child — the plate holds
## its size and nothing in the pager moves, which the no-moving-UI rule requires. The colour
## override is only re-applied when the ready state actually flips, not every frame.
func _set_contact_caption(ready: bool, scale_factor: float) -> void:
	if _contact_label == null:
		return
	# pivot_offset is refreshed from the live size so the text grows from its middle even after
	# a resize (the button is full-width, so its size changes with the pager).
	_contact_label.pivot_offset = _contact_label.size * 0.5
	_contact_label.scale = Vector2(scale_factor, scale_factor)
	if ready != _contact_caption_ready:
		_contact_caption_ready = ready
		# Matches UiPalette.style_button's own colours for an action plate: pale gold when live,
		# the dimmed navy it uses for font_disabled_color when not.
		_contact_label.add_theme_color_override(
			"font_color", UiPalette.PALE_GOLD if ready else Color(UiPalette.NAVY, 0.45))


## A large, readable ‹ / › stepper button for the pager.
func _make_pager_arrow(glyph: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(96, UiPalette.STANDARD_BUTTON_HEIGHT)
	b.add_theme_font_override("font", UiPalette.make_bold_font())
	b.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	UiPalette.style_button(b, false)
	return b


## Move the pager by `delta` tabs, clamped to [0, deepest reached epoch] so you can't page into
## an epoch you haven't opened yet.
func _step_epoch_tab(delta: int) -> void:
	_set_epoch_tab(_epoch_tab + delta)


## Switch to a tab: gate every row's liveness to it (only this tab refreshes + draws), then
## repaint the pager. Safe to call before the rows exist (used from _on_contact_made too).
func _set_epoch_tab(tab: int) -> void:
	# Remember where the player left the tab we're leaving, so returning to it restores that spot.
	if _ladder_scroll != null and _epoch_tab >= 0 and _epoch_tab < _tab_scroll.size():
		_tab_scroll[_epoch_tab] = _ladder_scroll.scroll_vertical
	_epoch_tab = clampi(tab, 0, _epoch_tab_max())
	# Viewing a tab marks it seen, so it never triggers the "new ventures" nudge afterward.
	if _epoch_tab < _tab_seen.size():
		_tab_seen[_epoch_tab] = true
	for row_variant in _rows:
		var row := row_variant as PropertyRow
		row.set_tab_active(_epoch_tab_of(row.prop_index) == _epoch_tab)
	# Restore THIS tab's own last scroll offset (0 the first time it is opened, so a never-visited
	# tab starts at the top — Tim, 2026-07-13). Deferred as well, so it also wins after the row-
	# visibility change re-lays-out the list (an immediate set can be clamped by the stale height).
	if _ladder_scroll != null:
		var target: int = int(_tab_scroll[_epoch_tab]) if _epoch_tab < _tab_scroll.size() else 0
		_ladder_scroll.scroll_vertical = target
		_ladder_scroll.set_deferred("scroll_vertical", target)
	_update_epoch_pager()


## Repaint the pager label/subtitle, arrow enabled-state, and dots for the current tab.
func _update_epoch_pager() -> void:
	if _epoch_pager_label == null:
		return
	_epoch_pager_label.text = _epoch_tab_name(_epoch_tab)
	var sub := _epoch_tab_sub(_epoch_tab)
	_epoch_pager_sub.text = sub
	_epoch_pager_sub.visible = sub != ""
	var last := _epoch_tab_max()
	_epoch_prev_button.disabled = _epoch_tab <= 0
	_epoch_next_button.disabled = _epoch_tab >= last
	# One dot per UNLOCKED tab (0..last are open, contiguous). Hide the row entirely while only
	# one tab is open — a lone dot indicates nothing, and the arrows already read as disabled.
	var unlocked_count := last + 1
	_epoch_pager_dots.visible = unlocked_count > 1
	_epoch_pager_dots.set_state(unlocked_count, _epoch_tab)


## Read horizontal swipes over the ladder to change tabs. Handled in _input WITHOUT consuming the
## event, so the row buttons still get their taps and the ScrollContainer still scrolls vertically:
## a tap moves ~0px (no tab change), a big horizontal drag turns the page (and naturally cancels
## any button press it started on). Only gestures that BEGIN on the "page" — the pager title strip
## or the property list — count, so swipes over the income panel / wage button / bottom bar are ignored.
func _input(event: InputEvent) -> void:
	if _ladder_area == null or _epoch_pager_box == null:
		return
	# NO swiping while a full-screen overlay is up. This raw handler sees every touch, and a
	# hidden Control's get_global_rect() still reports its rect — so a horizontal drag INSIDE
	# a transition minigame (Catch Money, Balance…) or the welcome screen was registering as
	# an epoch swipe on the covered pager, and the player came back to the game on the wrong
	# tab (Tim, 2026-07-29 — "returned to the game screen but not on the newest tab").
	if _any_fullscreen_overlay_visible():
		_swipe_tracking = false
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Swipe anywhere on the "page" — the pager title strip OR the property list below it.
			var region := _epoch_pager_box.get_global_rect().merge(_ladder_area.get_global_rect())
			_swipe_tracking = region.has_point(event.position)
			_swipe_start = event.position
			_swipe_delta = Vector2.ZERO
			_swipe_hold_seen = false
			_swipe_start_scroll = _ladder_scroll.scroll_vertical if _ladder_scroll != null else 0
		elif _swipe_tracking:
			_swipe_tracking = false
			# A press held long enough to trigger a hold (auto-rush / hold-to-buy / hold-to-hire)
			# owns the finger — don't also flip the tab if it drifted sideways (Tim 2026-07-11). We
			# LATCH this across the whole gesture (_swipe_hold_seen), so once a continuous state has
			# started the swipe is dead until the player lifts and swipes again — even if the hold
			# lapses before release, e.g. the finger drifts off the portrait (Tim 2026-07-13).
			if _swipe_hold_seen or _any_row_holding():
				return
			# Swipe LEFT (negative x) advances to the next epoch, like turning a page forward.
			if absf(_swipe_delta.x) >= EPOCH_SWIPE_THRESHOLD and absf(_swipe_delta.x) > absf(_swipe_delta.y):
				# The swipe's drag nudged this tab's vertical scroll; undo that first, so the tab we
				# leave saves where the player actually left it — not where the swipe dragged it to
				# (Tim 2026-07-13: swipes lost the per-tab scroll that the pager buttons preserved).
				if _ladder_scroll != null:
					_ladder_scroll.scroll_vertical = _swipe_start_scroll
				_step_epoch_tab(1 if _swipe_delta.x < 0.0 else -1)
	elif event is InputEventScreenDrag and _swipe_tracking:
		_swipe_delta = event.position - _swipe_start
		# Latch the moment a held action is engaged, so the rest of this gesture can't become a swipe.
		if _any_row_holding():
			_swipe_hold_seen = true


## True if any property row currently has a held action engaged (so a sideways drift during a
## hold shouldn't be read as an epoch swipe). Only the active tab's rows can be held.
func _any_row_holding() -> bool:
	for row_variant in _rows:
		if (row_variant as PropertyRow).is_hold_active():
			return true
	return false


## Nudge the player toward the lowest UNOPENED, reachable tab whose cheapest venture they can now
## afford (and own none of) — a one-time pointer so the pager's hidden tabs stay discoverable.
func _check_new_ventures() -> void:
	if _tab_seen.is_empty() or _venture_overlay.visible:
		return
	for tab in range(_epoch_tab_count()):
		if tab == _epoch_tab or not bool(_tab_unlocked[tab]):
			continue  # the tab you're already on, or one not open yet
		if bool(_tab_seen[tab]) or bool(_tab_nudged[tab]):
			continue
		if _tab_is_new_and_affordable(tab):
			_tab_nudged[tab] = true
			_pending_venture_tab = tab
			_venture_overlay.show_for(_epoch_tab_name(tab), _epoch_tab_sub(tab))
			return  # one nudge at a time


## True when the player owns NOTHING in `tab` yet and can afford its cheapest property — i.e. the
## tab has just become a place worth visiting.
func _tab_is_new_and_affordable(tab: int) -> bool:
	var cheapest := INF
	var found := false
	for i in range(game.economy.properties.size()):
		if _epoch_tab_of(i) != tab:
			continue
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0:
			return false  # already engaged with this tab — not "new"
		cheapest = minf(cheapest, prop.get_bulk_cost(1))
		found = true
	return found and game.economy.cash >= cheapest


## "SHOW ME" on the nudge — page the player to the tab it pointed at.
func _on_venture_show_requested() -> void:
	if _pending_venture_tab >= 0:
		_set_epoch_tab(_pending_venture_tab)
		_pending_venture_tab = -1


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

	# Tutorial-tips toggle — the master on/off for the one-time coach cards. Persisted in
	# TutorialProgress (its own user:// file), so the choice survives prestige and restarts. Styled
	# to match the minigame checkbox above (large navy label + big custom check glyphs).
	_tutorial_check = CheckBox.new()
	_tutorial_check.text = "Show tutorial tips"
	_tutorial_check.add_theme_font_size_override("font_size", 45)
	for state in ["font_color", "font_pressed_color", "font_hover_color",
			"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		_tutorial_check.add_theme_color_override(state, UiPalette.NAVY)
	_tutorial_check.add_theme_icon_override("checked", load("res://art/icons/checkbox_checked.svg"))
	_tutorial_check.add_theme_icon_override("unchecked", load("res://art/icons/checkbox_unchecked.svg"))
	_tutorial_check.button_pressed = TutorialProgress.is_enabled()
	_tutorial_check.toggled.connect(func(on: bool) -> void: TutorialProgress.set_enabled(on))
	v.add_child(_tutorial_check)

	# Number format (Plans/Currency_Format_Setting.md): THREE always-visible rows, one per mode,
	# rather than one cycling button. Tim, 2026-08-05: "I don't like having a single button that is
	# not clear what will happen when you click it." A cycler hides its own behaviour — you cannot
	# see what you are about to get until you have already changed it. Three rows show every
	# option, each with a live example of that mode's output, and tapping one selects it directly.
	var format_heading := Label.new()
	format_heading.text = "Number format"
	format_heading.add_theme_font_size_override("font_size", 45)  # matches the toggles above
	format_heading.add_theme_color_override("font_color", UiPalette.NAVY)
	v.add_child(format_heading)

	var format_rows := VBoxContainer.new()
	format_rows.add_theme_constant_override("separation", 12)
	v.add_child(format_rows)

	_currency_format_rows = []
	_currency_format_markers = []
	for mode in Money.Format.size():
		var row := _build_currency_format_row(mode)
		format_rows.add_child(row)
	_style_currency_format_rows()

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

	# Stats: opens the Statistics modal (Best Vent Streak and other bloodline numbers; Tim 2026-07-20).
	var stats_button := Button.new()
	stats_button.custom_minimum_size = Vector2(0, tuning_button_height)
	stats_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(stats_button, false)
	stats_button.text = "STATS"
	stats_button.pressed.connect(_on_stats_pressed)
	bottom_buttons.add_child(stats_button)

	# Challenges: opens the player-facing CHALLENGES screen (Plans/Challenge_Mode.md §3.4) — beat your
	# best in each minigame for a permanent global income bonus. This is the real home for Challenge
	# Mode; the CHALLENGE toggle under Minigame Tuning above is now only a developer shortcut.
	var challenges_button := Button.new()
	challenges_button.custom_minimum_size = Vector2(0, tuning_button_height)
	challenges_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(challenges_button, false)
	challenges_button.text = "CHALLENGES"
	challenges_button.pressed.connect(_on_challenges_pressed)
	bottom_buttons.add_child(challenges_button)

	# About: opens the modal with the logo, name, version, and credits (Tim, 2026-07-09).
	var about_button := Button.new()
	about_button.custom_minimum_size = Vector2(0, tuning_button_height)
	about_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(about_button, false)
	about_button.text = "ABOUT"
	about_button.pressed.connect(_on_about_pressed)
	bottom_buttons.add_child(about_button)

	# Help: opens the tutorial glossary + Replay action (Plans/Tutorial_Onboarding_Plan.md).
	var help_button := Button.new()
	help_button.custom_minimum_size = Vector2(0, tuning_button_height)
	help_button.add_theme_font_size_override("font_size", TUNING_BUTTON_FONT)
	UiPalette.style_button(help_button, false)
	help_button.text = "HELP"
	help_button.pressed.connect(_on_help_pressed)
	bottom_buttons.add_child(help_button)

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
	_dev_panel.jump_epoch_requested.connect(_on_dev_jump_epoch)
	_dev_panel.grant_legacy_requested.connect(_on_dev_grant_legacy)
	_dev_panel.grant_cash_requested.connect(_on_dev_grant_cash)
	_dev_panel.closed.connect(_on_dev_closed)
	stack.add_child(_dev_panel)

	return stack


## Build the bottom tab bar: four equal icon buttons pinned along the bottom.
func _build_tab_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)

	# Inactive (silhouette) and active (full-color) art for each tab, in TAB_* order. The
	# Estate tab's active icon is the legacy gem — the same art as the wallet and the
	# Pass-the-Torch button (Tim, 2026-07-08) — with a silhouette gem for its inactive state.
	var inactive_icons := [
		"res://art/icons/tab_property_inactive.svg",
		"res://art/icons/legacy_gem_inactive.svg",
		"res://art/icons/tab_ledger_inactive.svg",
		"res://art/icons/tab_settings_inactive.svg",
	]
	var active_icons := [
		"res://art/icons/tab_property_active.svg",
		"res://art/icons/legacy_gem.svg",
		"res://art/icons/tab_ledger_active.svg",
		"res://art/icons/tab_settings_active.svg",
	]
	_tab_buttons = []
	_tab_icon_inactive = []
	_tab_icon_active = []
	_tab_icon_overlay = []
	_tab_icon_tween = []
	for i in range(inactive_icons.size()):
		_tab_icon_inactive.append(load(inactive_icons[i]))
		_tab_icon_active.append(load(active_icons[i]))
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 185)  # 25% taller again (148 -> 185, Tim 2026-06-23)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = _tab_icon_inactive[i]  # start inactive; _style_tab_button lights up the active tab
		# Let the icon scale up from its 81px native size and cap it at TAB_ICON_SIZE (40%
		# larger). expand_icon grows it to fill the button; icon_max_width holds it at the target.
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", TAB_ICON_SIZE)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# The full-color active icons are high-res art that DOWNSCALES into the 113px slot, so
		# every tab needs the mipmapped filter to avoid aliasing — the fix the gem already used.
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.pressed.connect(_show_tab.bind(i))
		bar.add_child(b)
		_tab_buttons.append(b)
		# The full-color overlay that fades in when this tab is active (see _make_tab_icon_overlay).
		_tab_icon_overlay.append(_make_tab_icon_overlay(b, _tab_icon_active[i]))
		_tab_icon_tween.append(null)
		# The Estate tab carries the "you have Legacy to claim" red-dot badge. It is added AFTER the
		# overlay so the dot renders on top of the icon.
		if i == TAB_ESTATE:
			_estate_badge = _make_estate_badge(b)


## Build the full-color icon overlay for one tab, layered exactly over the button's silhouette
## icon and starting fully transparent. _crossfade_tab_icon fades it in when the tab becomes active
## and out when it leaves, so the icon appears to "light up" instead of hard-swapping. A
## CenterContainer fills the button and centers a fixed TAB_ICON_SIZE box — the same size and
## center as the Button's own expand_icon — so the color icon sits precisely on the silhouette.
func _make_tab_icon_overlay(button: Button, active_texture: Texture2D) -> TextureRect:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps must reach the button beneath
	var overlay := TextureRect.new()
	overlay.texture = active_texture
	overlay.custom_minimum_size = Vector2(TAB_ICON_SIZE, TAB_ICON_SIZE)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0  # transparent until this tab is the active one
	center.add_child(overlay)
	button.add_child(center)
	return overlay


## Fade tab `index`'s color overlay toward opaque (active) or transparent (inactive) over a short
## beat (~120 ms). Any in-flight fade is killed first so rapid tab-switching can't strand an icon
## half-lit. The button's silhouette icon stays put underneath the whole time.
func _crossfade_tab_icon(index: int, active: bool) -> void:
	if index >= _tab_icon_overlay.size():
		return
	var overlay := _tab_icon_overlay[index] as TextureRect
	var running := _tab_icon_tween[index] as Tween
	if running != null and running.is_valid():
		running.kill()
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0 if active else 0.0, 0.12)
	_tab_icon_tween[index] = fade


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
		if _tutorial_check != null:
			_tutorial_check.button_pressed = TutorialProgress.is_enabled()
		# Resync which number-format row is marked active on entry, the same way the toggles above
		# resync — so it can never mark a mode the formatter isn't actually in.
		if not _currency_format_rows.is_empty():
			_style_currency_format_rows()


## The active tab button reads as a mustard plate; the rest as plain cream plates. The
## leftmost and rightmost tabs round their OUTER bottom corner to nest inside the phone's
## bottom screen corners (the Property tab's bottom-left, the Settings tab's bottom-right).
func _style_tab_button(button: Button, active: bool, index: int) -> void:
	# Light up the active tab's icon (full color) and fade the rest back to silhouette — a short
	# cross-fade rather than a hard swap. Icon color means "you are here" and nothing else; the red
	# dot alone signals "something new" (Plans/Tab_Bar_Icon_Treatment.md, signal separation).
	_crossfade_tab_icon(index, active)
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
	# A locked tab (Estate before you can prestige, Ledger before your first prestige) reads as an
	# intentional grayed plate — not the default theme gray — keeping the same 12px frame + corners.
	# Its icon auto-dims via the Button's disabled state. Progressive disclosure (Plans §9); the tab
	# stays in place (no reflow), honoring the no-moving-UI rule.
	var locked_box := box.duplicate() as StyleBoxFlat
	locked_box.bg_color = UiPalette.LIGHT_GRAY
	locked_box.border_color = UiPalette.MID_GRAY
	button.add_theme_stylebox_override("disabled", locked_box)


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

	var band_before := prop.get_milestone_band()
	if game.try_buy(prop_index, count):
		_hero_stat.flash_purchase()
		# Milestone reward: fire on the crossing (not before) — a milestone is an automatic reward,
		# not an action to direct, so a just-happened notification is the right shape.
		if prop.get_milestone_band() > band_before:
			_maybe_show_tip("first_milestone", _row_for_index(prop_index))


## Show the one-time tutorial card for `tip_id`, anchored near `target` (null = screen-centered),
## unless tips are turned off or this one has already been seen. Marking it seen persists
## immediately so it never repeats (TutorialProgress lives outside the dynasty save).
##
## `body_override` replaces the catalog's body for THIS showing only, for the one tip whose copy
## has to carry live numbers (epoch_blocked's flagship case). The catalog keeps the generic
## wording, so the Help glossary still reads correctly.
func _maybe_show_tip(tip_id: String, target: Control, body_override: String = "") -> bool:
	# Never stack cards: if one is already up, decline. A poll-driven tip stays armed and retries a
	# later frame; a verb-driven tip simply skips. Checked FIRST so nothing below (including the
	# disk reads) runs while a card is visible.
	if _tutorial_tip.visible:
		return false
	# Never fire over a full-screen overlay — a card belongs on the MAIN game screen, not on top of
	# the welcome/launch screen, the succession ceremony, a minigame, or a Settings modal. The polls
	# already skip the MODAL overlays (the _process freeze-return), but the welcome/launch screen and
	# the Settings modals are NOT modal, so guard them here too (Tim, 2026-07-23: the family_ledger
	# card popped over the post-prestige welcome screen). Checked before the disk reads below.
	if _any_fullscreen_overlay_visible():
		return false
	if not TutorialProgress.is_enabled() or TutorialProgress.has_seen(tip_id):
		return false
	var tip := TutorialCatalog.get_tip(tip_id)
	if tip.is_empty():
		return false
	TutorialProgress.mark_seen(tip_id)
	var body: String = tip["body"]
	if body_override != "":
		body = body_override
	_tutorial_tip.show_tip(tip["title"], body, target)
	return true


## True while any full-screen overlay is up (the welcome/launch screen, the succession ceremony, a
## minigame, the epoch nudge, or a Settings modal). Tutorial cards suppress themselves while one is
## showing, so a card never lands on a beat instead of the main game screen.
func _any_fullscreen_overlay_visible() -> bool:
	return _welcome_overlay.visible or _will_screen.visible or _first_contact_overlay.visible \
			or _minigame_screen.visible or _minigame_review_screen.visible \
			or _challenges_screen.visible or _about_screen.visible or _stats_screen.visible \
			or _help_screen.visible or _venture_overlay.visible


## Fire a poll-driven availability tip. Disarms ONLY once the card actually shows, so a tip whose
## turn is blocked by another card still on screen stays armed and retries on a later frame (the
## natural queue for availability tips that come due together).
func _fire_polled_tip(tip_id: String, target: Control, body_override: String = "") -> void:
	if _maybe_show_tip(tip_id, target, body_override):
		_tip_armed[tip_id] = false


## A vent window opened during an overdrive rush — teach the vent gesture, anchored to the Rush
## Momentum bar (fired from RushMomentumState.vent_window_opened).
func _on_vent_window_opened() -> void:
	_maybe_show_tip("vent_window", _momentum_bar)


## Settings → Help: open the glossary modal.
func _on_help_pressed() -> void:
	_help_screen.open()


## Replay the tutorial (from the Help screen's REPLAY button): clear the seen-tips record and
## re-arm every poll tip, so the cards fire again as their moments recur. clear() also resets the
## on/off flag to its default (ON) — replaying implies the player wants to see the tips again.
func _on_replay_tutorial() -> void:
	TutorialProgress.clear()
	var tips_on := TutorialProgress.is_enabled()
	for tip_id in _tip_armed.keys():
		_tip_armed[tip_id] = tips_on and not TutorialProgress.has_seen(tip_id)
	if _tutorial_check != null:
		_tutorial_check.button_pressed = tips_on


## The visible PropertyRow for a property index, or null if that rung isn't currently on screen
## (the epoch pager only builds the current tab's rows). Used to anchor a tip to the right row.
func _row_for_index(prop_index: int) -> PropertyRow:
	for row in _rows:
		if (row as PropertyRow).prop_index == prop_index:
			return row as PropertyRow
	return null


## True once the player owns at least one unit of any property. Drives the opening tips
## (Clock In / buy first business) which only make sense before anything is owned.
func _owns_any_property() -> bool:
	for prop in game.economy.properties:
		if (prop as PropertyState).units_owned > 0:
			return true
	return false


## The on-screen row of the first property the player owns any of (or null if none is on screen).
func _first_owned_row() -> PropertyRow:
	for i in range(game.economy.properties.size()):
		if (game.economy.properties[i] as PropertyState).units_owned > 0:
			return _row_for_index(i)
	return null


## True once any property has enough units that the bulk-buy modes are worth explaining.
func _owns_multiple_units() -> bool:
	for prop in game.economy.properties:
		if (prop as PropertyState).units_owned >= 3:
			return true
	return false


## The on-screen row of the first property where hiring a manager is affordable and not yet done
## (or null). Used to direct the first hire the moment it becomes possible, not after it's done.
func _first_hireable_row() -> PropertyRow:
	for i in range(game.economy.properties.size()):
		var prop := game.economy.properties[i] as PropertyState
		if prop.units_owned > 0 and not prop.is_staffed and prop.get_staff_cost() <= game.economy.cash:
			return _row_for_index(i)
	return null


## The specific control on a row that a tutorial card should anchor to (or null if the row isn't
## on screen), so the pointer arrow + highlight land on the exact button, not the whole row.
func _buy_control_of(row: PropertyRow) -> Control:
	return row.get_buy_button() if row != null else null


func _rush_control_of(row: PropertyRow) -> Control:
	return row.get_rush_control() if row != null else null


func _hire_control_of(row: PropertyRow) -> Control:
	return row.get_hire_button() if row != null else null


## Keep the two gated nav tabs enabled/disabled to match their unlock state. Disabling a tab button
## grays it (the locked stylebox) and blocks clicks — the tab stays in place, no reflow.
func _refresh_locked_tabs() -> void:
	_tab_buttons[TAB_ESTATE].disabled = not _estate_unlocked()
	_tab_buttons[TAB_LEDGER].disabled = not _ledger_unlocked()


## The Estate tab is available once the player can prestige (so "Plan the Estate", which lives in
## that tab, is reachable) — or has ever prestiged (keeps it open forever after). Both are
## effectively monotonic, so the tab never re-locks once shown.
func _estate_unlocked() -> bool:
	return dynasty.can_perform_succession() or dynasty.upgrades.earned_lifetime > 0


## The Family Ledger is available once the first prestige has produced an ancestor to show.
func _ledger_unlocked() -> bool:
	return dynasty.ancestors.size() > 0


func _on_tap_requested(prop_index: int) -> void:
	game.tap_property(prop_index)


func _on_hold_rush_requested(prop_index: int) -> void:
	game.hold_rush_property(prop_index)


## A rush hold ended: stop Rush Momentum building right away rather than letting the
## pulse-bridging grace ride for another half second after the finger lifts (Tim 2026-07-15).
func _on_rush_hold_released(prop_index: int) -> void:
	game.release_rush(prop_index)


## Raw finger-down/finger-up edges on a row's rush control, forwarded verbatim for the
## Overdrive Vent Window gesture reader (Plans/Overdrive_Vent_Windows.md). GameState routes
## them to RushMomentumState, which only interprets them while a vent window is open on the
## overdriven property — outside a window they are inert, so plain rush taps stay plain.
func _on_rush_pressed(prop_index: int) -> void:
	game.notify_rush_pressed(prop_index)


func _on_rush_released(prop_index: int) -> void:
	game.notify_rush_released(prop_index)


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


## OVERDRIVE tapped on the momentum bar: opt in to the danger bands for this excursion
## (Plans/Rush_Cruise_Control.md). GameState gates the verb on can_rush(), so a stray tap
## racing a lockout is refused there rather than here.
func _on_overdrive_requested() -> void:
	game.engage_rush_overdrive()


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


## Stats pressed: show the Statistics modal. It reads the bloodline's current numbers on open;
## its own Back button hides it again (the game keeps running behind it).
func _on_stats_pressed() -> void:
	_stats_screen.open()


## The Statistics modal's Back button was pressed. Nothing to restore — the modal self-hides.
func _on_stats_closed() -> void:
	pass


## Challenges pressed: open the player-facing CHALLENGES screen. It reads the bloodline's cleared
## tiers on open; the economy freezes while it (or a challenge run inside it) is up — see _process.
func _on_challenges_pressed() -> void:
	_challenges_screen.open()


## The CHALLENGES screen's Back button was pressed. Nothing to restore — the screen self-hides and
## the economy resumes (it was frozen only while the screen was up).
func _on_challenges_closed() -> void:
	pass


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
	# Challenge Mode high scores (highest tier) live in their own user:// file, not the dynasty save,
	# so wipe them too or they survive the reset (Tim, 2026-07-22).
	ChallengeScores.clear()
	# Tutorial progress also lives in its own user:// file (prestige-independent), so wipe it too
	# to make onboarding re-testable from a clean state (Tim, 2026-07-23).
	TutorialProgress.clear()
	get_tree().reload_current_scene()


## Playtest: teleport this generation to `tier`. Set lifetime-earned to that epoch's ENTRY threshold
## (so the epoch state is coherent and won't immediately re-advance) and hand over the same amount as
## spending cash to build the new cohort. restore() sets the tier directly, skipping the First Contact
## beats — a clean teleport. Save + reload so the pager, unlocked rows, and staff caps rebuild.
func _on_dev_jump_epoch(tier: int) -> void:
	var entry_earned := 0.0
	if tier > 1:
		entry_earned = EpochCatalog.consume_threshold(tier - 1, tuning.earth_economy_target)
	game.economy.cash_earned_this_gen = entry_earned
	game.economy.cash = entry_earned
	game.epoch.restore(tier)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	get_tree().reload_current_scene()


## Playtest: grant Legacy to spend in the Estate Office (to feel a prestiged heir). Save + reload.
func _on_dev_grant_legacy(amount: int) -> void:
	dynasty.upgrades.award(amount)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
	get_tree().reload_current_scene()


## Playtest: grant spending cash as a multiple of the current epoch's clear target — always a
## meaningful amount whatever the scale. award_cash never touches lifetime-earned, so it can't
## advance the epoch or inflate the estate; it is pure buying power. Save + reload.
func _on_dev_grant_cash(epoch_target_multiplier: float) -> void:
	var target := EpochCatalog.consume_threshold(game.epoch.current_tier, tuning.earth_economy_target)
	game.economy.award_cash(target * epoch_target_multiplier)
	SaveManager.save_dict_to_file(dynasty.to_save_dict())
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
		_plan_label.text = "[center]PASS THE TORCH\n+%s [img width=70 height=70]res://art/icons/legacy_gem.svg[/img][/center]" % Money.abbrev(dynasty.projected_legacy_gain())
	else:
		_plan_label.text = "[center]PASS THE TORCH[/center]"

	# The lifetime-earned line above the button (Tim, 2026-07-05). Repainted only when the
	# value actually changes — rebuilding rich text every frame would be wasted parsing.
	if dynasty.upgrades.earned_lifetime != _shown_lifetime_earned:
		_shown_lifetime_earned = dynasty.upgrades.earned_lifetime
		# Gem image scaled with the 66px text so the pair keeps its proportions.
		_lifetime_earned_label.text = "[center][img width=67 height=67]res://art/icons/legacy_gem.svg[/img] Lifetime Earned: %s[/center]" % Money.abbrev(_shown_lifetime_earned)


## First contact: a new epoch was reached this tick. Show the beat (Main's _process
## guard freezes the economy while it is up). We remember the tier so that when the player
## answers the call (_on_contact_dismissed) we can negotiate the trade deal for that epoch's
## new alien property. (If a single huge tick crossed two epochs, the later contact's beat
## simply replaces this one — vanishingly rare given epochs are ~30× apart.)
func _on_contact_made(new_tier: int) -> void:
	# Swap the play-field backdrop to match the newly reached epoch before the beat plays,
	# so when the first-contact overlay clears the player is looking at the new world.
	_background.texture = load(_background_path_for_tier(new_tier))
	# The new epoch just opened its pager tab — unlock it, then jump to it so that when the contact
	# beat (and any trade-deal minigame) clears, the player is looking at the new civ's properties.
	_update_tab_unlocks()
	_set_epoch_tab(new_tier - 1)  # tab = tier − 1 since the Earth split
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
	# The Earth→Earth promotion beat (White Collar, tier 2) is a quiet card only for now —
	# no trade-deal minigame (Tim, 2026-07-27). SEAM: when the promotion minigame gets its
	# own moving-up copy (planned follow-up, Plans/Earth_Split_Epochs.md), remove this guard.
	if EpochCatalog.civilization(tier) == "Earth":
		return
	var prop_index := game.economy.get_property_index_for_unlock_tier(tier)
	if prop_index < 0:
		return  # no new business this epoch — nothing more to negotiate

	if not game.ui_minigame_enabled:
		# Opted out: the new property unlocks at base income; no minigame means no bonus. The bonus
		# is upside-only, so opting out costs nothing but the potential upside. Nothing to grant.
		return

	var prop := game.economy.properties[prop_index] as PropertyState
	_minigame_site = MinigameSite.FIRST_CONTACT
	_first_contact_bonus_tier = tier
	# Set the dynasty's lifetime Legacy so a Legacy gem collected during this negotiation can be
	# sized/granted (the Legacy Bonus system now reaches the First Contact site too), then boost it:
	# an epoch transition is a milestone, so its gem pays much more than a routine gem (Tim 2026-07-12).
	_minigame_screen.set_legacy_lifetime(dynasty.upgrades.earned_lifetime)
	_minigame_screen.set_legacy_bonus_multiplier(tuning.legacy_bonus_first_contact_multiplier)
	# Frame the negotiation around the FLAGSHIP's per-unit base income (the concrete
	# number being talked up), but pitched at the civilization: the terms struck here
	# apply to the epoch's whole cohort (Phase 2).
	_minigame_screen.start_game(
		MinigameScreen.first_contact_reward(
			prop.get_single_unit_income_per_cycle(), prop.config.display_name,
			EpochCatalog.civilization(tier)
		),
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
## on load and to swap it the moment a contact advances the epoch. Earth spans tiers 1-2
## since the Earth split, so only ALIEN contacts (tier 3+) leave the prairie behind.
func _background_path_for_tier(tier: int) -> String:
	var alien_contacts_made := tier - 2
	if alien_contacts_made >= 10:
		return BACKGROUND_SPACE_CENTERED
	if alien_contacts_made >= 1:
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
		# Gems already spent retaining this staffer — the sum of every retained level's cost.
		# Lets the Estate Office show the Household Staff category's total invested (Tim 2026-07-13).
		var gems_spent := 0
		for level in range(1, retained_levels + 1):
			gems_spent += dynasty.staff_retention.cost_for_level(i, level)
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
			"gems_spent": gems_spent,
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
		_maybe_show_tip("staff_retention", null)


## An upgrade was just bought in the shop. Apply its effect to the living
## generation immediately (faster cycles / cheaper staff / fatter wage take hold
## mid-life) and persist, so a purchase is never lost to a crash before autosave.
func _on_upgrade_purchased(_upgrade_id: String) -> void:
	dynasty.refresh_current_generation_effects()
	# The purchase just drained the shared Legacy wallet, and the Household Staff rows carry
	# can_afford SNAPSHOTS — without a rebuild they keep advertising affordability the wallet
	# no longer has (enabled RETAIN buttons + a wrong "+x affordable" badge; Tim's device
	# report 2026-07-18). In-place update, same as _on_retain_requested, so a held button
	# under the player's finger survives.
	_legacy_screen.update_retention_entries(_build_retention_entries())
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


## A CHALLENGE run finished (Plans/Challenge_Mode.md §5 step 2). Credit the score into the dynasty:
## if it cleared a higher tier than the bloodline had banked, the tier is recorded and the living
## generation's global income bonus is refreshed immediately (inside credit_challenge_score). Persist
## only when something actually changed, then hand the credit report back to the screen that LAUNCHED
## the run so it can show the "NEW TIER" feedback on its end view (and, for the CHALLENGES screen,
## refresh its row list). `screen` is bound onto the connection (see _build_ui) — either the dev
## MinigameReviewScreen or the player-facing ChallengesScreen; both expose show_challenge_credit.
func _on_challenge_finished(game_key: String, final_score: int, screen: Object) -> void:
	var result := dynasty.credit_challenge_score(game_key, float(final_score))
	if result["improved"]:
		SaveManager.save_dict_to_file(dynasty.to_save_dict())
	screen.show_challenge_credit(result)


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
	if _first_contact_bonus_tier > 0:
		var bonus := _first_contact_bonus_for(multiplier)
		# The negotiated terms cover the epoch's WHOLE COHORT (Phase 2, Tim's call) —
		# every property gated to this tier gets the same income/cycle bonus.
		for prop_index in game.economy.get_property_indices_for_unlock_tier(_first_contact_bonus_tier):
			var prop := game.economy.properties[prop_index] as PropertyState
			prop.set_first_contact_bonus(bonus[0], bonus[1])
		SaveManager.save_dict_to_file(dynasty.to_save_dict())
	_first_contact_bonus_tier = 0


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


## The value shown as the live sample beside the number-format setting. Deliberately DEEP
## ($4.2 quattuordecillion, ~epoch 12+): down here the abbreviated suffix ("Qad") is the
## opaque one the setting exists to escape, so the three samples actually read differently.
const CURRENCY_FORMAT_SAMPLE := 4.2e45


## Build one number-format row: a full-width plate carrying an active marker, the mode's name,
## and a live example of THAT mode's output. Registers itself in _currency_format_rows /
## _currency_format_markers at index `mode`, so the restyler can find it by mode later.
##
## The row is a Button used purely as the plate; its own `text` stays empty and the three pieces
## of content are Labels anchored inside it. That is what makes the row un-resizable: a Button
## sizes itself to its own text, and an anchored (non-container-managed) child cannot push on
## its parent — so SCIENTIFIC's shorter example and ALPHABET's longer one all yield the exact
## same row box. Standing no-moving-UI rule: nothing here hides, resizes, or reflows on select.
func _build_currency_format_row(mode: int) -> Button:
	var row := Button.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	row.pressed.connect(_on_currency_format_selected.bind(mode))

	# One horizontal strip pinned to the row's full rect, inset so the text clears the plate's
	# border. MOUSE_FILTER_IGNORE throughout so taps land on the Button underneath, not the Labels.
	var content := MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		content.add_theme_constant_override(side, 24)
	row.add_child(content)

	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_constant_override("separation", 16)
	content.add_child(strip)

	# Marker column: fixed width, so the mode name sits at the same x on every row whether or not
	# that row is the active one. (An inline bullet in the name would shift the text instead.)
	var marker := Label.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(36, 0)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	strip.add_child(marker)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = _currency_format_name(mode)
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	name_label.add_theme_font_override("font", UiPalette.make_bold_font())
	name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	strip.add_child(name_label)

	# The example, right-aligned and given all the leftover width. It is rendered through Money in
	# THIS row's mode (see _currency_format_sample), so it can never disagree with what the game
	# actually prints. clip_text keeps a long example from claiming more width than the row has.
	var example := Label.new()
	example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	example.text = _currency_format_sample(mode)
	example.clip_text = true
	example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	example.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	example.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	example.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	example.add_theme_color_override("font_color", UiPalette.NAVY)
	strip.add_child(example)

	_currency_format_rows.append(row)
	_currency_format_markers.append(marker)
	return row


## Mark whichever row matches Money.format_mode as the active one, and the other two as
## selectable-but-not-current. This reuses the tab bar's "you are here" language (_style_tab_button
## above): the active plate is MUSTARD_GOLD, the inactive plates are CREAM, both with the same navy
## border — plus a "●" marker so the cue is not carried by color alone (Tim's eyesight).
func _style_currency_format_rows() -> void:
	for mode in _currency_format_rows.size():
		var row: Button = _currency_format_rows[mode]
		var active: bool = (mode == Money.format_mode)
		var plate := StyleBoxFlat.new()
		plate.bg_color = UiPalette.MUSTARD_GOLD if active else UiPalette.CREAM
		plate.border_color = UiPalette.NAVY
		plate.set_border_width_all(6 if active else 3)
		plate.set_corner_radius_all(8)
		# One plate for every interactive state: the row must not flash a different color on
		# hover/press, which would read as "this is now selected" before it actually is.
		for state in ["normal", "hover", "pressed", "focus"]:
			row.add_theme_stylebox_override(state, plate)
		(_currency_format_markers[mode] as Label).text = "●" if active else ""


## Select a number format outright (no cycling — each row picks its own mode).
## Presentation only — nothing but the formatting of already-computed numbers changes.
func _on_currency_format_selected(mode: int) -> void:
	Money.format_mode = mode
	game.ui_currency_format = mode  # persisted on the next autosave / on background
	_style_currency_format_rows()

	# REPAINT. Nearly every number on screen is rebuilt from live state each frame (the property
	# rows, the hero cash/income, the wage panel) or on tab entry (Estate, Family Ledger — see
	# _show_tab), so they pick the new format up on their own. The ONE exception is the
	# lifetime-earned line, which is only repainted when its value changes; clearing the cache
	# forces _update_plan_button to rebuild it on the next frame instead of leaving it stale.
	_shown_lifetime_earned = -1


## The sample value as `mode` would render it — e.g. "$4.2 Qad" / "$4.2 ao" / "$4.2e45" — always
## produced by Money itself, so no row's example can drift from real output.
##
## Money.format_mode is a STATIC shared by the whole game, so rendering a sample in a mode the
## player has NOT selected means borrowing it for one call. The restore is guaranteed structurally:
## this function is straight-line — no branch, no loop, no early return, and nothing between the
## two assignments but one pure formatter call — so there is no path that reaches the end without
## putting the previous mode back. Deliberately the ONLY place that touches the static this way.
func _currency_format_sample(mode: int) -> String:
	var previous_mode: int = Money.format_mode
	Money.format_mode = mode
	var sample := Money.of(CURRENCY_FORMAT_SAMPLE).display_cash()
	Money.format_mode = previous_mode
	return sample


func _currency_format_name(mode: int) -> String:
	match mode:
		Money.Format.ABBREVIATED:
			return "ABBREVIATED"
		Money.Format.ALPHABET:
			return "ALPHABET"
		Money.Format.SCIENTIFIC:
			return "SCIENTIFIC"
	return "ABBREVIATED"


# ---------------------------------------------------------------------------
# Epoch pager position dots
# ---------------------------------------------------------------------------

## The pager's position indicator: one dot per UNLOCKED tab only (locked/undiscovered tabs get no
## dot at all — Tim 2026-07-12), so the row grows as tabs open. The current tab is a large gold dot;
## the other open tabs are smaller navy dots. Purely an indicator (navigation is the arrows/swipe).
class EpochPagerDots extends Control:
	var _count := 0
	var _current := 0
	const DOT_SPACING := 36.0
	const DOT_RADIUS := 10.0

	func set_state(count: int, current: int) -> void:
		_count = count
		_current = current
		custom_minimum_size = Vector2(0, DOT_RADIUS * 2.0 + 14.0)
		queue_redraw()

	func _draw() -> void:
		if _count <= 0:
			return
		# Auto-fit: with many epochs the default spacing would overflow the pager, so shrink the
		# gap (and, once tight, the dots) to fit the available width. Keeps the whole strip on
		# screen through the first batch and degrades gracefully toward the full 26 epochs; a
		# dedicated compact/windowed indicator is a follow-on for the full rollout.
		var spacing := DOT_SPACING
		if _count > 1 and size.x > 0.0:
			var usable := size.x - DOT_RADIUS * 2.0
			spacing = minf(DOT_SPACING, usable / float(_count - 1))
		var dot_r := minf(DOT_RADIUS, spacing * 0.42)
		var span := float(_count - 1) * spacing
		var start_x := (size.x - span) * 0.5
		var y := size.y * 0.5
		for i in range(_count):
			var pos := Vector2(start_x + float(i) * spacing, y)
			if i == _current:
				draw_circle(pos, dot_r, UiPalette.MUSTARD_GOLD)
			else:
				draw_circle(pos, dot_r * 0.6, UiPalette.INK_NAVY)
