class_name MinigameReviewScreen
extends ColorRect

# A full-screen developer/review tool (Settings → Minigame Tuning). It lists every minigame
# type in the library and lets the tester open each one in isolation — presenting the exact
# screen the player sees mid-prestige, but with a Back button at the top so they can flip
# through and check each minigame's functionality and design quickly.
#
# It owns its OWN MinigameScreen instance (separate from Main's prestige one) so review play
# can never apply Legacy or interfere with the real succession flow. The MinigameScreen is
# started in "review mode" with a forced type and sample numbers; its Back button and its
# normal Continue/Skip all just return here to the list.

## Emitted when the player closes the whole review screen (Close button). Main hides it and
## unfreezes the economy.
signal closed

# Sample values fed to the reviewed minigame so its live "Legacy kept" readout shows
# meaningful numbers. They are display-only — review play never banks anything.
const SAMPLE_BASE_LEGACY := 100
const SAMPLE_BONUS_MAX := 0.25

var _tuning: TuningConfig
var _list_view: Control
var _player: MinigameScreen
## The themed backdrop behind the list, with CPU-baked rounded corners (shared with MinigameScreen).
var _backdrop: TextureRect
var _baked_backdrop_size: Vector2 = Vector2.ZERO

## Challenge Mode toggle state (Tim, 2026-06-30): false = Minigame Mode (normal review play with a
## timer + win/loss), true = Challenge Mode (endless free play, high scores). Defaults to Minigame.
var _challenge_selected: bool = false
## The two side-by-side mode toggles (Tim, 2026-07-01, replacing the old single flip button): the
## selected one is lit, the other dimmed. Kept, along with the subtitle line and the per-type buttons
## (each {type, button, name}), so selecting a mode can restyle both toggles and re-label every game
## button (name only, or name + saved high score in Challenge Mode).
var _minigame_mode_button: Button
var _challenge_mode_button: Button
var _subtitle_label: Label
var _type_buttons: Array = []

## Fixed height reserved for the two-line subtitle so the buttons beneath it never shift when the
## mode's blurb wraps to a different number of lines (Tim, 2026-07-01: buttons must not move when
## the mode changes). Two lines of FONT_BODY plus a little breathing room.
const SUBTITLE_RESERVED_HEIGHT := 96

## Opacity of the UNSELECTED mode toggle, so it reads as the inactive choice while staying tappable.
const DIM_MODE_ALPHA := 0.4


func setup(tuning: TuningConfig) -> void:
	_tuning = tuning


func _ready() -> void:
	# Black field framing the rounded viewing area, matching the main game (Tim, 2026-06-23).
	# The reviewed minigame (_player) draws its own identical frame on top.
	color = Color.BLACK
	visible = false

	# The same themed backdrop the live minigame screen uses (Tim, 2026-06-29), drawn full-bleed
	# inside the black bezel BEHIND the list, so the 50%-alpha cream list plate reads over it. Its
	# texture is CPU-baked with rounded corners (shared with MinigameScreen) so the bright
	# bottom-corner art doesn't square off past the rounded frame — clip_children can't do it here
	# (only one clip stencil works at a time; see MinigameScreen for the full note).
	_backdrop = TextureRect.new()
	UiPalette.apply_screen_bezel(_backdrop)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.resized.connect(_rebake_backdrop)
	_rebake_backdrop.call_deferred()

	_list_view = _build_list_view()
	add_child(_list_view)

	# Our own minigame host, used only for review. Added after the list so it draws on top
	# when a minigame is open; we toggle the list's visibility to swap between them.
	_player = MinigameScreen.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.setup(_tuning)
	_player.back_pressed.connect(_return_to_list)
	# In review the result multiplier is ignored — Continue/Skip just return to the list.
	_player.finished.connect(func(_multiplier: float, _opt_out: bool) -> void: _return_to_list())
	add_child(_player)


## Open the review screen on its list (called by Main when the Settings button is tapped).
func open() -> void:
	_player.visible = false
	_list_view.visible = true
	visible = true


## Bake the backdrop to its current size with rounded corners (shared with MinigameScreen), so the
## bright bottom-corner art doesn't square off past the rounded frame. Re-runs only on size change.
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
# The list of minigames
# ---------------------------------------------------------------------------

func _build_list_view() -> Control:
	# A centered card matching the minigame screen's Get Ready panel — the SAME size, shape, and
	# 70%-alpha cream (Tim, 2026-06-30) — so the Tuning list sits on the identical plate the games
	# use, with the themed backdrop showing around it.
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

	# One column filling the whole card. Every button below stretches to the card's full width
	# (size_flags_horizontal EXPAND_FILL), so the layout is anchored to the fixed card width and NO
	# button ever shifts sideways when a label's text length changes with the mode (Tim, 2026-07-01).
	# A vertical spacer between the game list and the Close button pushes Close to the very bottom.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	# The title now uses the shared tab-title format (make_tab_title) so it matches the tab
	# headings on the game screen exactly — large, faux-bold, navy, centered (Tim, 2026-07-01).
	column.add_child(UiPalette.make_tab_title("MINIGAME TUNING"))

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A fixed reserved height so a one- vs two-line blurb doesn't push the buttons below it up or down.
	_subtitle_label.custom_minimum_size = Vector2(0, SUBTITLE_RESERVED_HEIGHT)
	_subtitle_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_subtitle_label.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(_subtitle_label)

	# Two side-by-side mode toggles (Tim, 2026-07-01, replacing the single flip button): tap a mode
	# to select it. Both have fixed labels, so this row never changes size. The selected one is lit
	# (mustard); the other is dimmed — see _apply_mode_selection.
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	column.add_child(mode_row)

	_minigame_mode_button = _make_mode_button("MINIGAME MODE", false)
	mode_row.add_child(_minigame_mode_button)
	_challenge_mode_button = _make_mode_button("CHALLENGE MODE", true)
	mode_row.add_child(_challenge_mode_button)

	# One button per type in the library. We read each type's display name by briefly
	# instantiating it — a bare Minigame node is cheap and display_name() is safe to call
	# before begin(); we free the probe immediately since it's never added to the tree.
	_type_buttons.clear()
	for type_script in MinigameScreen.MINIGAME_TYPES:
		var probe := type_script.new() as Minigame
		var type_name := probe.display_name()
		probe.free()

		var button := Button.new()
		# Height fixed; width stretches to the card so the Challenge-mode "— Best: N" suffix
		# can't widen the button and shove the layout around.
		button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
		UiPalette.style_button(button, false)
		button.pressed.connect(_on_type_pressed.bind(type_script))
		column.add_child(button)
		_type_buttons.append({"type": type_script, "button": button, "name": type_name})

	# Set both toggles', the subtitle's, and the game-button labels for the starting mode (Minigame).
	_refresh_mode_ui()

	# Expanding spacer: eats the leftover height so the Close button sits at the bottom of the
	# card, clearly separated from the list of minigames above rather than reading as one of them.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(close_button, true)  # red: leaving the screen
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)

	return card


## Build one of the two side-by-side mode toggles. `selects_challenge` marks which mode tapping it
## chooses. Both stretch equally to fill the row (EXPAND_FILL) so the split is a fixed 50/50 and the
## row never reflows; the lit/dimmed look is set by _apply_mode_selection.
func _make_mode_button(label: String, selects_challenge: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(button, false)
	button.pressed.connect(_select_mode.bind(selects_challenge))
	return button


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## Light the selected mode toggle, dim the other, refresh the subtitle, and relabel every game
## button for the current mode. In Challenge Mode each game button also shows its saved high score.
func _refresh_mode_ui() -> void:
	_apply_mode_selection()
	if _challenge_selected:
		_subtitle_label.text = "Free play — no timer, no win/loss. Beat your best score!"
	else:
		_subtitle_label.text = "Open any minigame to review it."
	for entry in _type_buttons:
		var type_name: String = entry["name"]
		var button: Button = entry["button"]
		if _challenge_selected:
			button.text = "%s — Best: %d" % [type_name, ChallengeScores.get_high_score(type_name)]
		else:
			button.text = type_name


## Light the selected mode's toggle (full mustard) and dim the other (faded), so the two side-by-side
## buttons read as a segmented control — the lit one is the active mode.
func _apply_mode_selection() -> void:
	_minigame_mode_button.modulate.a = DIM_MODE_ALPHA if _challenge_selected else 1.0
	_challenge_mode_button.modulate.a = 1.0 if _challenge_selected else DIM_MODE_ALPHA


## Select a mode from the two side-by-side toggles. Re-tapping the current mode simply re-refreshes.
func _select_mode(challenge: bool) -> void:
	_challenge_selected = challenge
	_refresh_mode_ui()


func _on_type_pressed(type_script: Script) -> void:
	_list_view.visible = false
	if _challenge_selected:
		# Endless free play with high-score tracking.
		_player.start_challenge(type_script)
	else:
		# Review play shows the prestige/Legacy framing with sample numbers; it never banks
		# anything, so the reward context is purely cosmetic here.
		_player.start_game(
			MinigameScreen.legacy_reward(SAMPLE_BASE_LEGACY), SAMPLE_BONUS_MAX, type_script, true
		)


func _return_to_list() -> void:
	_player.visible = false
	_list_view.visible = true
	# A Challenge run may have set a new high score — re-read so the buttons show it immediately.
	_refresh_mode_ui()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
