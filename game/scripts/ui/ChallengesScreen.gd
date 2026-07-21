class_name ChallengesScreen
extends ColorRect

# The player-facing CHALLENGES screen (Plans/Challenge_Mode.md §3.4, Phase 3): the real home for
# Challenge Mode, opened from a CHALLENGES button on the Settings tab (the dev mode-toggle inside
# Minigame Tuning stays only as a developer shortcut). A full-screen modal built on the same
# black-bezel frame + top-left ◀ BACK pattern as AboutScreen and StatsScreen.
#
# It lists the six minigames; each row shows the highest tier the bloodline has cleared, that tier's
# earned contribution to BOTH reward tracks (income + Legacy), and the next payout goal to reach.
# Tapping a game's PLAY button launches a keep-alive CHALLENGE run (the clock drains, scoring tops it
# up, and the best tier reached is banked when it hits zero).
#
# Like MinigameReviewScreen, this screen owns its OWN MinigameScreen host (_player) so a challenge
# run never touches the real prestige flow. When a run ends, _player emits challenge_finished; we
# bubble it up to Main (which holds the dynasty, credits the tier, saves, and hands feedback back
# via show_challenge_credit). All display numbers are read LIVE from the dynasty + ChallengeGoals
# on every open() and after every credited run, so returning from a run shows the new tier at once.

## Emitted when the player closes the whole screen (◀ BACK). Main hides it (the game runs behind it).
signal closed

## Re-emitted from our own MinigameScreen host (_player) when a CHALLENGE run ends — same bubbling
## MinigameReviewScreen does. Carries the game's key (its display_name()) and its final score,
## unchanged. Main connects here to credit the tier and hand feedback back (show_challenge_credit).
signal challenge_finished(game_key: String, final_score: int)

## The bloodline whose cleared tiers + income bonus are shown. Threaded in from Main (setup) before
## the first open(); read fresh on every refresh so the screen is never stale.
var _dynasty: DynastyState

## The six minigame type scripts (MinigameScreen.MINIGAME_TYPES), passed in from Main. Each row is
## matched to its ChallengeGoals key by the type's display_name() — the same string ChallengeGoals
## and DynastyState key challenges by.
var _type_scripts: Array = []

## Our own minigame host for challenge play (mirrors MinigameReviewScreen's _player) — added as a
## child so a run never interferes with Main's prestige host. Built in setup (it needs the tuning).
var _player: MinigameScreen

## The prominent total-bonus readout in the header, refreshed with the rows so it always matches.
var _total_bonus_label: Label

## The column the per-game rows live in — cleared and rebuilt on each refresh so every tier/bonus
## is current (the same rebuild-the-value-column idiom StatsScreen uses).
var _rows_column: VBoxContainer

## The whole list frame (title + header + rows). Hidden while a challenge run is up and shown again
## on return, so the covered list doesn't keep drawing behind the opaque player (as in the review screen).
var _list_view: Control


## Hand the screen its data. Called once by Main at build time, after add_child (so _ready has built
## the frame). Also builds the minigame host, which needs the shared tuning to run a challenge.
func setup(dynasty: DynastyState, type_scripts: Array, tuning: TuningConfig) -> void:
	_dynasty = dynasty
	_type_scripts = type_scripts

	# Our own minigame host, set up exactly like MinigameReviewScreen's: added after the frame so it
	# draws on top when a game is open; we toggle the frame's visibility to swap between them.
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

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)
	_list_view = viewing_area

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	viewing_area.add_child(column)

	# Back button, pinned top-left with a generous margin (matches every other modal's Back).
	var back_margin := MarginContainer.new()
	back_margin.add_theme_constant_override("margin_top", 28)
	back_margin.add_theme_constant_override("margin_left", 28)
	column.add_child(back_margin)
	var back_row := HBoxContainer.new()
	back_margin.add_child(back_row)
	var back := Button.new()
	back.text = "◀  BACK"
	back.custom_minimum_size = Vector2(340, 108)
	back.add_theme_font_size_override("font_size", int(UiPalette.FONT_BUTTON * 1.5))
	back.add_theme_font_override("font", UiPalette.make_bold_font())
	back.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(back, false)
	back.pressed.connect(_on_back_pressed)
	back_row.add_child(back)
	var back_spacer := Control.new()
	back_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer)

	# --- Header: title, the running total bonus, and a one-line explainer of the mode. ---
	column.add_child(UiPalette.make_tab_title("CHALLENGES"))

	# The prominent running-totals readout — BOTH reward tracks, on two lines (e.g.
	# "INCOME  +3.2%" / "LEGACY  +2.0%"), large and gold so they read as the headline reward.
	# Filled in _refresh.
	_total_bonus_label = Label.new()
	_total_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_bonus_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_total_bonus_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_total_bonus_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	column.add_child(_total_bonus_label)

	var explainer := Label.new()
	explainer.text = "Beat your best in each game to climb its tier ladder. Every 5th tier pays a permanent bonus — income or Legacy."
	explainer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explainer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explainer.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	explainer.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(explainer)

	# --- The scrollable list of the six games. Six rows fit most screens, but scroll so the tall
	# rows can never overflow the frame on a shorter device. The rows column is rebuilt on refresh. ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_rows_column = VBoxContainer.new()
	_rows_column.add_theme_constant_override("separation", 18)
	_rows_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_column)


## Open the screen on its list (called by Main when the Settings CHALLENGES button is tapped).
## Refreshes first so the tiers/bonus are current, then shows the list (not the player).
func open() -> void:
	_refresh()
	if _player != null:
		_player.visible = false
	_list_view.visible = true
	visible = true


## Forward Main's tier-credit report to the challenge host so its end view shows the "NEW TIER"
## feedback (see MinigameScreen.show_challenge_credit), AND refresh the rows + total so the new
## tier/bonus is already showing when the player taps Back to return to the list.
func show_challenge_credit(result: Dictionary) -> void:
	if _player != null:
		_player.show_challenge_credit(result)
	_refresh()


# ---------------------------------------------------------------------------
# The per-game list
# ---------------------------------------------------------------------------

## Rebuild the total-bonus header and every game row from the dynasty's current cleared tiers. All
## numbers are read live here — no cached copies — so open() and post-run refreshes are always true.
func _refresh() -> void:
	if _dynasty == null:
		return

	# Both running totals, one per track, on two lines so each reward is legible on its own.
	var income_pct := _dynasty.get_challenge_income_bonus() * 100.0
	var legacy_pct := _dynasty.get_challenge_legacy_bonus() * 100.0
	_total_bonus_label.text = "INCOME  +%.1f%%\nLEGACY  +%.1f%%" % [income_pct, legacy_pct]

	for child in _rows_column.get_children():
		child.queue_free()

	# One row per game, keyed by the type's display_name() — the exact string ChallengeGoals and
	# DynastyState use, so the row's tier/bonus lookups line up with the catalog and the save.
	for type_script in _type_scripts:
		var probe := type_script.new() as Minigame
		var game_key := probe.display_name()
		probe.free()
		_rows_column.add_child(_make_game_row(game_key, type_script))


## Build one large, tappable game row: the game name and its earned tier/bonus on the left, the next
## goal beneath, and a big PLAY button on the right that launches this game's challenge run.
func _make_game_row(game_key: String, type_script: Script) -> Control:
	# The bloodline's cleared tier for this game, and its earned contribution to EACH reward track.
	var cleared_tier := int(_dynasty.challenge_highest_tiers.get(game_key, 0))
	var earned_income := ChallengeGoals.income_bonus_for(cleared_tier) * 100.0
	var earned_legacy := ChallengeGoals.legacy_bonus_for(cleared_tier) * 100.0

	# "Tier N cleared" plus whichever track contributions are nonzero (a fresh game shows tier 0 alone).
	var earned_text := "Tier %d cleared" % cleared_tier
	var earned_parts: Array = []
	if earned_income > 0.001:
		earned_parts.append("+%.1f%% income" % earned_income)
	if earned_legacy > 0.001:
		earned_parts.append("+%.1f%% legacy" % earned_legacy)
	if not earned_parts.is_empty():
		earned_text += "   " + "  ·  ".join(earned_parts)

	# The next reward: the next tier that actually pays out (every 5th), the score to reach it, and
	# which track it pays. -1 once the ladder is mastered (all six payouts earned).
	var next_tier := ChallengeGoals.next_payout_tier(cleared_tier)
	var next_text := ""
	var mastered := next_tier == -1
	if mastered:
		next_text = "MASTERED — all rewards earned"
	else:
		var payout := ChallengeGoals.payout_at_tier(next_tier)
		var reach := int(round(ChallengeGoals.score_step(game_key) * float(next_tier)))
		var track := String(payout.get("type", "")).to_upper()
		var pct := float(payout.get("pct", 0.0))
		next_text = "Next: reach %s (tier %d)  →  +%d%% %s" % [_round_score(reach), next_tier, int(round(pct)), track]

	# The row sits on the cream card plate so it reads as a distinct, tappable block on the frame.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MinigameScreen.make_card_style())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)

	# Left: the game's name, its cleared tier + earned contribution, and the next goal. In its own
	# EXPAND_FILL column so the PLAY button is pushed to the right edge.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	info.add_child(_make_info_label(game_key, UiPalette.FONT_SUBHEAD, UiPalette.NAVY, true))
	info.add_child(_make_info_label(earned_text, UiPalette.FONT_BODY, UiPalette.DARK_GOLD, false))
	# The next-reward line reads as an earned summit when mastered (green, bold), a goal otherwise.
	if mastered:
		info.add_child(_make_info_label(next_text, UiPalette.FONT_LABEL, UiPalette.DARK_MONEY_GREEN, true))
	else:
		info.add_child(_make_info_label(next_text, UiPalette.FONT_LABEL, UiPalette.NAVY, false))

	# Right: a big PLAY button. Large tappable target (Tim's low-vision rule).
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(240, UiPalette.STANDARD_BUTTON_HEIGHT)
	play.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	play.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(play, true)  # gold action button: start a run
	play.pressed.connect(_on_play_pressed.bind(type_script))
	var play_center := CenterContainer.new()  # keep PLAY vertically centered against the info stack
	play_center.add_child(play)
	row.add_child(play_center)

	return card


## Format a whole score with thousands separators ("30,000"), so the higher-scale games (Match Three
## reaches into the tens of thousands) read cleanly in the "Next: reach …" line.
func _round_score(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped


## One text line inside a game row. `emphasize` faux-bolds it (used for the game name).
func _make_info_label(text: String, font_size: int, color: Color, emphasize: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if emphasize:
		label.add_theme_font_override("font", UiPalette.make_bold_font())
	return label


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## PLAY tapped for a game: hide the list and launch its endless challenge run on our own host.
func _on_play_pressed(type_script: Script) -> void:
	_list_view.visible = false  # stop the covered list drawing behind the opaque player
	_player.start_challenge(type_script)


## The challenge host's Back/Continue returned control here. Show the list again and refresh so a
## newly-cleared tier is already reflected (show_challenge_credit also refreshed, but a run that
## improved nothing still returns through here).
func _return_to_list() -> void:
	if _player != null:
		_player.visible = false
	_refresh()
	_list_view.visible = true
	visible = true


func _on_back_pressed() -> void:
	visible = false
	closed.emit()
