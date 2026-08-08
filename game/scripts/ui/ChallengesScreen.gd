class_name ChallengesScreen
extends ColorRect

# The player-facing CHALLENGES screen (Plans/Challenge_Mode.md §3.4, Phase 3): the real home for
# Challenge Mode, opened from a CHALLENGES button on the Settings tab (the dev mode-toggle inside
# Minigame Tuning stays only as a developer shortcut).
#
# Styled like the Minigame Tuning screen (Tim, 2026-07-22): the themed minigame backdrop fills the
# black-bezel frame, and all content sits on a SMALLER centered 70%-translucent cream card, so the
# backdrop reads around it. It lists the six minigames; each game is one big tappable PANEL (there is
# no separate PLAY button — the whole panel is the button) showing the highest tier the bloodline has
# cleared, that tier's earned contribution to BOTH reward tracks (income + Legacy), and the next
# payout goal. Each panel wears the green minigame_button plate and carries the game's own icon on the
# left. Tapping a panel launches a keep-alive CHALLENGE run.
#
# Like MinigameReviewScreen, this screen owns its OWN MinigameScreen host (_player) so a challenge run
# never touches the real prestige flow. When a run ends, _player emits challenge_finished; we bubble
# it up to Main (which holds the dynasty, credits the tier, saves, and hands feedback back via
# show_challenge_credit). All display numbers are read LIVE from the dynasty + ChallengeGoals on every
# open() and after every credited run, so returning from a run shows the new tier at once.
#
# Only games the bloodline has actually MET at a transition can be played here (Plans/
# Challenge_Mode_Gating.md Part B). A game you have not met still gets its row — grayed in place,
# with the reason on it — so the list keeps reading as a trophy case rather than a shrinking menu.

## Emitted when the player closes the whole screen (◀ BACK). Main hides it (the game runs behind it).
signal closed

## Re-emitted from our own MinigameScreen host (_player) when a CHALLENGE run ends — same bubbling
## MinigameReviewScreen does. Carries the game's key (its display_name()) and its final score,
## unchanged. Main connects here to credit the tier and hand feedback back (show_challenge_credit).
signal challenge_finished(game_key: String, final_score: int)

# --- Per-game icons. basketball / green gem reuse the games' own art; the other four are dedicated
# Challenge icons (Tim, 2026-07-22). ---
const ICON_BASKETBALL := preload("res://art/icons/basketball.svg")
const ICON_MATCH_THREE := preload("res://art/icons/gem_green.svg")
const ICON_CATCH := preload("res://art/icons/coin.svg")
const ICON_MEMORY := preload("res://art/icons/memory_pads.svg")
const ICON_BALANCE := preload("res://art/icons/book.svg")
const ICON_TIMING := preload("res://art/icons/lock.svg")

## Height reserved for one game panel. Tall enough for the name + tier line beside the icon with
## breathing room (low-vision rule). Six of these scroll if the card is short.
const PANEL_HEIGHT := 180

## The game icon's square size on the left of each panel (was 132; 15% smaller per Tim, 2026-07-22).
const ICON_SIZE := 112

## The panel look (Tim, 2026-07-22): a rounded rectangle with a thick bright-gold outline over a deep
## green fill (darkened from the old money-plate green per Tim). The pressed fill darkens further on tap.
const PANEL_GREEN := Color("#3F8A37")
const PANEL_GREEN_PRESSED := Color("#33702C")
const PANEL_BORDER_WIDTH := 8
const PANEL_CORNER_RADIUS := 26

## The LOCKED plate (a game the bloodline has not met yet). Same shape as the live plate — same
## corner radius, same border width — so only the COLOUR changes and the row keeps its place in the
## list. The colours are the project's standing locked-control language, borrowed from the locked
## tab treatment in Main.gd (LIGHT_GRAY fill, MID_GRAY border), so a locked challenge reads the same
## way a locked tab does. A disabled Button draws ONLY its `disabled` stylebox, so without this the
## panel would keep the live green plate while refusing taps — an unresponsive live-looking control,
## which reads as a bug.
const PANEL_LOCKED_FILL := UiPalette.LIGHT_GRAY
const PANEL_LOCKED_BORDER := UiPalette.MID_GRAY

## The reason shown on a locked row's third text line. Kept at body size (not fine print) — see
## _make_game_panel for the height arithmetic that proves three lines still fit the 180px row.
const LOCKED_REASON_TEXT := "MEET THIS GAME AT A TRANSITION"

## How far a locked game's icon fades toward its gray plate. The Button's disabled state dims only
## the Button's OWN icon/text; our icon is a separate child TextureRect, so it must be dimmed here.
const LOCKED_ICON_ALPHA := 0.45

## Inner padding between the gold border and the panel content, so nothing touches the outline.
const CONTENT_PAD_SIDE := 34
const CONTENT_PAD_VERTICAL := 22

## How far a finger must travel before a press on a game panel counts as a SCROLL rather than a TAP
## (see the drag-to-scroll section at the bottom of this file). Matched to DevTuningPanel's own
## threshold so the two button-tiled lists in the game feel the same under the thumb.
const DRAG_SCROLL_THRESHOLD := 12.0

## The bloodline whose cleared tiers + income bonus are shown. Threaded in from Main (setup) before
## the first open(); read fresh on every refresh so the screen is never stale.
var _dynasty: DynastyState

## The six minigame type scripts (MinigameScreen.MINIGAME_TYPES), passed in from Main. Each row is
## matched to its ChallengeGoals key by the type's display_name() — the same string ChallengeGoals
## and DynastyState key challenges by.
var _type_scripts: Array = []

## The balance-tuning knobs, kept so the list can read the `challenge_show_all_games` dev override
## (see _show_all_games_override). Threaded in from Main via setup, like _dynasty. May be null if
## anything ever builds this screen without calling setup, so every read goes through the helper.
var _tuning: TuningConfig

## Drag-to-scroll bookkeeping for the current press gesture (see the section at the bottom of this
## file). _drag_accum is the total vertical travel so far; _drag_moved latches once that travel
## passes DRAG_SCROLL_THRESHOLD, which is what tells _on_play_pressed the gesture was a scroll and
## not a tap. Reset on every fresh press, including presses on LOCKED rows.
var _drag_accum := 0.0
var _drag_moved := false

## Our own minigame host for challenge play (mirrors MinigameReviewScreen's _player) — added as a
## child so a run never interferes with Main's prestige host. Built in setup (it needs the tuning).
var _player: MinigameScreen

## The themed minigame backdrop behind the card, with CPU-baked rounded corners (shared with
## MinigameScreen), exactly as MinigameReviewScreen does it.
var _backdrop: TextureRect
var _baked_backdrop_size: Vector2 = Vector2.ZERO

## The prominent total-bonus readout in the header, refreshed with the rows so it always matches.
var _total_bonus_label: Label

## The scroll holding the game panels, and the column inside it (rebuilt on each refresh so every
## tier/bonus is current). The scroll is kept so the edge fade can measure what it is clipping.
var _scroll: ScrollContainer
var _rows_column: VBoxContainer

## The whole centered card (backdrop stays behind it). Hidden while a challenge run is up and shown
## again on return, so the covered list doesn't keep drawing behind the opaque player.
var _list_view: Control


## Hand the screen its data. Called once by Main at build time. Main calls this BEFORE add_child, so
## _player is added to this node before _ready runs and adds the backdrop + card — i.e. _player is NOT
## guaranteed to be the topmost child. We therefore never rely on draw order: play mode hides the
## backdrop AND the card (see _show_list_chrome), leaving the player as the only visible layer.
func setup(dynasty: DynastyState, type_scripts: Array, tuning: TuningConfig) -> void:
	_dynasty = dynasty
	_type_scripts = type_scripts
	_tuning = tuning

	# Our own minigame host, set up exactly like MinigameReviewScreen's. Whether it lands above or
	# below the backdrop/card depends on setup-vs-_ready ordering, so we swap by visibility, not z-order.
	_player = MinigameScreen.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.setup(tuning)
	_player.back_pressed.connect(_return_to_list)
	# In challenge play the result multiplier is ignored — Continue/Skip/Back just return to the list.
	_player.finished.connect(func(_multiplier: float, _opt_out: bool) -> void: _return_to_list())
	# Bubble a finished CHALLENGE run up to Main (which holds the dynasty and does the crediting).
	_player.challenge_finished.connect(func(game_key: String, final_score: int) -> void:
		challenge_finished.emit(game_key, final_score))
	_player.visible = false
	add_child(_player)


func _ready() -> void:
	color = Color.BLACK
	visible = false

	# The same themed backdrop the live minigame + tuning screens use, drawn full-bleed inside the
	# black bezel BEHIND the card, so the 70%-alpha cream card reads over it. CPU-baked with rounded
	# corners (shared with MinigameScreen) so the bright bottom-corner art doesn't square off past the
	# rounded frame (see MinigameReviewScreen for the full note).
	_backdrop = TextureRect.new()
	UiPalette.apply_screen_bezel(_backdrop)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.resized.connect(_rebake_backdrop)
	_rebake_backdrop.call_deferred()

	_list_view = _build_card()
	add_child(_list_view)


## Open the screen on its list (called by Main when the Settings CHALLENGES button is tapped).
## Refreshes first so the tiers/bonus are current, then shows the card (not the player).
func open() -> void:
	if _player != null:
		_player.visible = false
	# Same order as _return_to_list, and for the same reason: visible first, rows second, so the
	# edge fade is computed against a laid-out ScrollContainer rather than a hidden one.
	_show_list_chrome(true)
	visible = true
	_refresh()


## Show or hide the list-mode layers (the themed backdrop AND the card) together. Both are hidden
## while a challenge run is up so the player host — which may sit below them in child order (see
## setup) — is the only visible layer and is never covered by the always-on backdrop.
func _show_list_chrome(show_it: bool) -> void:
	if _backdrop != null:
		_backdrop.visible = show_it
	if _list_view != null:
		_list_view.visible = show_it


## Forward Main's tier-credit report to the challenge host so its end view shows the "NEW TIER"
## feedback (see MinigameScreen.show_challenge_credit), AND refresh the rows + total so the new
## tier/bonus is already showing when the player taps Back to return to the list.
func show_challenge_credit(result: Dictionary) -> void:
	if _player != null:
		_player.show_challenge_credit(result)
	_refresh()


## Bake the backdrop to its current size with rounded corners (shared with MinigameScreen). Re-runs
## only on a real size change.
func _rebake_backdrop() -> void:
	if _backdrop == null:
		return
	var target := Vector2i(int(_backdrop.size.x), int(_backdrop.size.y))
	if target.x < 1 or target.y < 1 or _baked_backdrop_size == _backdrop.size:
		return
	_baked_backdrop_size = _backdrop.size
	var texture := MinigameScreen.bake_rounded_backdrop(target, UiPalette.SCREEN_CORNER_RADIUS)
	if texture != null:
		_backdrop.texture = texture


# ---------------------------------------------------------------------------
# The centered card + header
# ---------------------------------------------------------------------------

## Build the centered translucent card and everything on it: Back, the title/total/explainer header,
## and the scrolling list of game panels. Matches the Tuning screen's card size + 70%-cream plate.
func _build_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MinigameScreen.make_card_style())
	var half_w := MinigameScreen.PANEL_WIDTH_FRACTION / 2.0
	var half_h := MinigameScreen.PANEL_HEIGHT_FRACTION / 2.0
	card.anchor_left = 0.5 - half_w
	card.anchor_right = 0.5 + half_w
	card.anchor_top = 0.5 - half_h
	card.anchor_bottom = 0.5 + half_h
	card.offset_left = 0.0
	card.offset_right = 0.0
	card.offset_top = 0.0
	card.offset_bottom = 0.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	# Back button, pinned top-left inside the card (matches every other modal's Back).
	var back_row := HBoxContainer.new()
	column.add_child(back_row)
	var back := Button.new()
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(300, 96)
	back.add_theme_font_size_override("font_size", int(UiPalette.FONT_BUTTON * 1.4))
	back.add_theme_font_override("font", UiPalette.make_bold_font())
	back.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(back, false)
	back.pressed.connect(_on_back_pressed)
	back_row.add_child(back)
	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer)

	# --- Header: title, the running total bonus, and a one-line explainer of the mode. These sit on
	# the cream card, so they keep the dark (navy/gold) text that reads on cream. ---
	column.add_child(UiPalette.make_tab_title("CHALLENGES"))

	# The prominent running-totals readout — BOTH reward tracks, on two lines (e.g.
	# "INCOME  +3.2%" / "LEGACY  +2.0%"), large and gold so they read as the headline reward.
	_total_bonus_label = Label.new()
	_total_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_bonus_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_total_bonus_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_total_bonus_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	column.add_child(_total_bonus_label)

	var explainer := Label.new()
	explainer.text = "Tap a game to play. Beat your best to climb its tier ladder — every 5th tier pays a permanent bonus, income or Legacy."
	explainer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explainer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explainer.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	explainer.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(explainer)

	# --- The scrollable list of the six game panels. Six fit most screens, but the list scrolls so
	# the tall panels can never overflow the card on a shorter device. The full property-ladder
	# treatment (Tim, 2026-07-27 — one "more content this way" vocabulary everywhere): tappable
	# ScrollEdgeArrows strips overlay the edges, and a panel the scroll is clipping fades by its
	# visible fraction against the strip's inner edge (ScrollEdgeArrows.apply_edge_fade). The
	# strips need a plain Control host over the scroll (see ScrollEdgeArrows' usage note). ---
	var scroll_host := Control.new()
	scroll_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll_host)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_edge_fade())
	_scroll.resized.connect(_update_edge_fade)
	scroll_host.add_child(_scroll)
	var arrows := ScrollEdgeArrows.new()
	arrows.setup(_scroll)
	scroll_host.add_child(arrows)

	_rows_column = VBoxContainer.new()
	_rows_column.add_theme_constant_override("separation", 18)
	_rows_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# RECOMPUTE THE FADE WHENEVER THE LIST ACTUALLY LAYS OUT, rather than guessing when that will
	# be. `sort_children` fires the instant this VBox has positioned its children — which is the
	# only moment the fade's arithmetic has valid geometry to work from.
	#
	# This replaces a deferred call that was a guess and got it wrong twice: rebuilt rows sit at
	# position 0 until the container sorts, so a fade computed before that reads every row as being
	# in the same place and hands out nonsense alphas (Tim, 2026-08-08 — the list came back empty
	# after a run, then again after leaving and re-entering the screen).
	_rows_column.sort_children.connect(_update_edge_fade)
	_scroll.add_child(_rows_column)

	return card


# ---------------------------------------------------------------------------
# The per-game list
# ---------------------------------------------------------------------------

## Rebuild the total-bonus header and every game panel from the dynasty's current cleared tiers. All
## numbers are read live here — no cached copies — so open() and post-run refreshes are always true.
func _refresh() -> void:
	if _dynasty == null:
		return

	# Both running totals, one per track, on two lines so each reward is legible on its own.
	var income_pct := _dynasty.get_challenge_income_bonus() * 100.0
	var legacy_pct := _dynasty.get_challenge_legacy_bonus() * 100.0
	_total_bonus_label.text = "INCOME  +%.1f%%\nLEGACY  +%.1f%%" % [income_pct, legacy_pct]

	for child in _rows_column.get_children():
		# REMOVED IMMEDIATELY, not just queued. queue_free() leaves the old rows in the tree until
		# the end of the frame, so the container sorts the OLD and NEW sets together and the fade
		# fires against a list that is briefly twice as long as it should be. Orphaning them first
		# makes the rebuild atomic; queue_free still does the actual freeing.
		_rows_column.remove_child(child)
		child.queue_free()

	# A rebuilt list starts at the top. Without this the scroll keeps whatever offset the player
	# left behind — which can be past the end of a shorter list, leaving them looking at blank space
	# and concluding the games are missing.
	if _scroll != null:
		_scroll.scroll_vertical = 0

	# One panel per game, keyed by the type's display_name() — the exact string ChallengeGoals and
	# DynastyState use, so the panel's tier/bonus lookups line up with the catalog and the save.
	for type_script in _type_scripts:
		var probe := type_script.new() as Minigame
		var game_key := probe.display_name()
		probe.free()
		_rows_column.add_child(_make_game_panel(game_key, type_script))

	# Positions aren't known until the list lays out, so update the edge fade on the next frame.
	_update_edge_fade.call_deferred()


## Build one large, tappable game PANEL: the whole panel is the button (no separate PLAY). It wears the
## green plate, carries the game's icon on the left, and shows the name + earned tier/bonus + next goal.
func _make_game_panel(game_key: String, type_script: Script) -> Control:
	# The bloodline's cleared tier for this game. "MAX TIER" once there is no higher tier to reach;
	# otherwise "TIER N" (Tim, 2026-07-22). The running income/Legacy totals live in the header, so the
	# panel just names the tier — no per-game bonus breakdown or next-goal line.
	var cleared_tier := int(_dynasty.challenge_highest_tiers.get(game_key, 0))
	var tier_text := "MAX TIER" if cleared_tier >= ChallengeGoals.MAX_TIER else "TIER %d" % cleared_tier

	# Only games the bloodline has actually MET at a transition are playable here (Plans/
	# Challenge_Mode_Gating.md Part B). An unmet game is never hidden — it stays in place, grayed,
	# with the reason on its own line — so the list still reads as a trophy case of what is left to
	# find. The dev override unlocks the ROW ONLY; it deliberately writes nothing back (see
	# _show_all_games_override).
	var locked := not _show_all_games_override() and not _dynasty.has_met_minigame(game_key)

	# The whole panel is one Button (Tim, 2026-07-22 — no separate PLAY). Its content is overlaid as
	# mouse-ignoring children so every tap on the panel lands on the button.
	var panel := Button.new()
	panel.focus_mode = Control.FOCUS_NONE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, PANEL_HEIGHT)
	panel.add_theme_stylebox_override("normal", _make_plate_style(false))
	panel.add_theme_stylebox_override("hover", _make_plate_style(false))
	panel.add_theme_stylebox_override("focus", _make_plate_style(false))
	panel.add_theme_stylebox_override("disabled", _make_locked_plate_style())
	panel.add_theme_stylebox_override("pressed", _make_plate_style(true))  # a touch darker on press
	# Two independent locks, because one unresponsive-but-live-looking panel is worse than none:
	# `disabled` stops the Button emitting `pressed` at all, and a locked row never connects the
	# handler in the first place. (`_on_play_pressed` has exactly one caller — this line.)
	panel.disabled = locked
	if not locked:
		panel.pressed.connect(_on_play_pressed.bind(type_script))

	# Drag-to-scroll. Connected for EVERY row, locked ones included: a disabled Button still swallows
	# the touch (disabling changes the press logic, not the mouse filter), so a locked row left
	# unwired would be a dead patch of list you cannot scroll from. See the section at the bottom.
	panel.gui_input.connect(_on_panel_gui_input)

	# Content overlay: a full-rect margin (clearing the gold frame) holding the icon + text row. All
	# of it ignores the mouse so the underlying button receives every tap.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", CONTENT_PAD_SIDE)
	pad.add_theme_constant_override("margin_right", CONTENT_PAD_SIDE)
	pad.add_theme_constant_override("margin_top", CONTENT_PAD_VERTICAL)
	pad.add_theme_constant_override("margin_bottom", CONTENT_PAD_VERTICAL)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)

	# Left: the game's own icon, a fixed square, vertically centered against the text.
	var icon := TextureRect.new()
	icon.texture = _icon_for(game_key)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon.modulate.a = LOCKED_ICON_ALPHA
	row.add_child(icon)

	# Right: name, cleared tier + earned contribution, and the next goal. In its own EXPAND_FILL column
	# so the text fills the panel width beside the icon. Colors are cream/gold with a dark outline so
	# they read over the green plate (Tim, 2026-07-22 contrast).
	# A locked row carries a third line, so its lines sit 4px apart instead of 6 to keep the column
	# comfortably inside the plate. The height arithmetic, using this project's font (measured line
	# boxes: 57px at FONT_SUBHEAD 41, 45px at FONT_BODY 32):
	#   unlocked, 2 lines: 57 + 45 + 6        = 108px
	#   locked,   3 lines: 57 + 45 + 45 + 4+4 = 155px
	# Both fit the 164px of clear plate inside the 8px border, so the third line never reaches the
	# frame. The ROW height itself cannot move either way: it is pinned by the Button's
	# custom_minimum_size of PANEL_HEIGHT, and a Button is not a Container — these overlay children
	# are positioned by anchors and contribute nothing to the Button's minimum size.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4 if locked else 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	# Text colours flip with the plate: cream/gold outlined in navy reads over the green plate, while
	# dark navy outlined in cream reads over the pale gray locked plate. Both keep a full-size outline
	# so the text stays crisp against the plate (low-vision rule).
	if locked:
		info.add_child(_make_info_label(
			game_key, UiPalette.FONT_SUBHEAD, UiPalette.INK_NAVY, true, UiPalette.CREAM))
		info.add_child(_make_info_label(
			tier_text, UiPalette.FONT_BODY, UiPalette.NAVY, true, UiPalette.CREAM))
		# The reason, at full body size — a locked row must say WHY, legibly, not in fine print.
		info.add_child(_make_info_label(
			LOCKED_REASON_TEXT, UiPalette.FONT_BODY, UiPalette.INK_NAVY, true, UiPalette.CREAM))
	else:
		info.add_child(_make_info_label(game_key, UiPalette.FONT_SUBHEAD, UiPalette.CREAM, true))
		info.add_child(_make_info_label(tier_text, UiPalette.FONT_BODY, UiPalette.MUSTARD_GOLD, true))

	return panel


## The panel look: a rounded rectangle with a thick bright-gold outline over a light green fill.
## `pressed` darkens the green slightly for tap feedback.
func _make_plate_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN_PRESSED if pressed else PANEL_GREEN
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.border_color = UiPalette.MUSTARD_GOLD
	return style


## The LOCKED panel look, drawn for a game the bloodline has not met. Built by copying the live plate
## and recolouring it, so the two can never drift apart in shape — identical corner radius and border
## width, gray fill and gray border instead of green and gold. Same duplicate-and-recolour idiom the
## locked tabs use (Main.gd).
func _make_locked_plate_style() -> StyleBoxFlat:
	var style := _make_plate_style(false)
	style.bg_color = PANEL_LOCKED_FILL
	style.border_color = PANEL_LOCKED_BORDER
	return style


## The developer's "show every game" knob from Balance Tuning, a 0/1 float read as `> 0.5` (the house
## idiom for a boolean knob — see PropertyRow.gd). It exists because with six games dealt at random,
## testing one specific game would otherwise mean replaying transitions until it comes up.
##
## THIS IS A DISPLAY OVERRIDE ONLY. It unlocks the ROWS on this screen and nothing else: it must never
## cause a game to be recorded as met, or one testing session would permanently unlock everything and
## the gate could never be seen again. This screen only ever READS the encounter set, so please keep
## it that way — do not add a write here.
##
## _tuning is null if the screen was somehow built without setup(), in which case there is no knob to
## read and the honest answer is "no override".
func _show_all_games_override() -> bool:
	if _tuning == null:
		return false
	return _tuning.challenge_show_all_games > 0.5


## Map a game's display_name() key to its Challenge icon. Basketball and Match Three reuse the games'
## own art; the other four are the dedicated Challenge icons.
func _icon_for(game_key: String) -> Texture2D:
	match game_key:
		"Micro Basketball":
			return ICON_BASKETBALL
		"Match Three":
			return ICON_MATCH_THREE
		"Catch the Money":
			return ICON_CATCH
		"Memory Match":
			return ICON_MEMORY
		"Balance the Books":
			return ICON_BALANCE
		"Timing Bar":
			return ICON_TIMING
	return null


## The shared property-ladder edge treatment (ScrollEdgeArrows.apply_edge_fade): each game
## panel the scroll is clipping fades by its visible fraction against the arrow strips.
## Called on scroll, on resize, and after a refresh once the panels have laid out.
func _update_edge_fade() -> void:
	if _scroll == null:
		return
	ScrollEdgeArrows.apply_edge_fade(_scroll, _rows_column.get_children())


## One text line inside a game panel. `emphasize` faux-bolds it (used for the game name). An outline is
## always applied so the text reads over the plate behind it (low-vision rule); it defaults to dark navy
## for the light text on the green plate, and a locked row passes CREAM instead for its dark text on the
## pale gray plate.
func _make_info_label(
		text: String,
		font_size: int,
		color: Color,
		emphasize: bool,
		outline_color: Color = UiPalette.INK_NAVY) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", 5)
	if emphasize:
		label.add_theme_font_override("font", UiPalette.make_bold_font())
	return label


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## A game panel tapped: hide the list and launch its endless challenge run on our own host.
func _on_play_pressed(type_script: Script) -> void:
	# The player was scrolling, not choosing. Godot fires `pressed` whenever the finger comes up
	# inside a Button, and after a flick the finger is almost always still over SOME row — so
	# without this guard, every scroll would launch whichever challenge happened to end up under
	# the thumb. This is the whole reason the gesture's travel is tracked.
	if _drag_moved:
		return

	# Hide BOTH list-mode layers (backdrop + card). The backdrop is always-on and can sit ABOVE the
	# player in child order, so leaving it visible covered the whole run with just the background
	# image (Tim, 2026-07-22). With both hidden, the player host is the only visible layer.
	_show_list_chrome(false)
	_player.visible = true
	_player.start_challenge(type_script)


## The challenge host's Back/Continue returned control here. Show the list again and refresh so a
## newly-cleared tier is already reflected (show_challenge_credit also refreshed, but a run that
## improved nothing still returns through here).
func _return_to_list() -> void:
	if _player != null:
		_player.visible = false
	# SHOW FIRST, REBUILD SECOND. _refresh tears down and re-adds every row and then schedules the
	# edge fade; doing that while the card is still hidden meant the fade ran against an unlaid-out
	# ScrollContainer (Tim, 2026-08-08 — the list came back empty until the screen was touched).
	# apply_edge_fade now refuses that case outright, but building into a visible tree is the more
	# honest fix: the rows are measured against the box they will actually occupy.
	_show_list_chrome(true)
	visible = true
	_refresh()


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------------------
# Drag-to-scroll (Tim reported 2026-08-06: "the buttons block swipe scrolling")
# ---------------------------------------------------------------------------
# Every game row is one full-width Button (Tim, 2026-07-22 — no separate PLAY), and the rows tile the
# whole list with only an 18px gap between them. So there is nowhere neutral to grab: a Button's
# default MOUSE_FILTER_STOP swallows the touch before the ScrollContainer ever sees a drag, and the
# list cannot be swiped at all.
#
# MOUSE_FILTER_PASS is NOT the fix here. UiPalette.allow_scroll_drag_through() deliberately skips
# BaseButtons — a PASS button would forward its taps to the parent as well as acting on them — which
# is why the property ladder still scrolls (its rows are mostly non-button surface) while this screen
# cannot. Instead we pan the scroll ourselves, exactly as DevTuningPanel does for its collapsed
# section headers, which hit this same wall on 2026-07-22.
#
# A short press still plays the game; once a gesture's travel passes DRAG_SCROLL_THRESHOLD it counts
# as a scroll and that row's tap is suppressed in _on_play_pressed.


## Route one row's input: a fresh press starts a new gesture, anything else may be a drag.
##
## The press reset lives HERE rather than on the Button's `button_down` signal (DevTuningPanel's
## wiring) for one reason: locked rows are DISABLED Buttons, and a disabled Button emits no
## button_down at all. Reading the press off the raw event instead keeps locked rows scrollable.
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_drag_gesture()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag_gesture()
		return
	_pan_scroll_on_drag(event)


## Start tracking a fresh press gesture, before any travel.
func _begin_drag_gesture() -> void:
	_drag_accum = 0.0
	_drag_moved = false


## Pan the list when a press over a row turns into a drag. Never consumes the event, so a genuine
## tap still reaches the Button's own `pressed` signal.
func _pan_scroll_on_drag(event: InputEvent) -> void:
	var delta_y := 0.0
	if event is InputEventScreenDrag:
		delta_y = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# Desktop only. Godot's emulate_mouse_from_touch (on by default) also synthesises a mouse
		# motion for every InputEventScreenDrag, so counting both on a phone would scroll the list
		# at twice the speed of the finger. On mobile the ScreenDrag branch above is the real one.
		if OS.has_feature("mobile"):
			return
		delta_y = event.relative.y
	else:
		return

	# Finger down the screen (delta_y > 0) reveals EARLIER rows, so scroll_vertical decreases.
	_scroll.scroll_vertical -= int(delta_y)
	_drag_accum += absf(delta_y)
	if _drag_accum >= DRAG_SCROLL_THRESHOLD:
		_drag_moved = true
