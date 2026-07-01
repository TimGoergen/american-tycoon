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
## The large mode toggle button, the subtitle line, and the per-type buttons (each {type, button,
## name}) — kept so the toggle can restyle itself and re-label every game button (name only, or name
## + saved high score in Challenge Mode).
var _mode_button: Button
var _subtitle_label: Label
var _type_buttons: Array = []


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

	# The list of buttons is centered within that card.
	var center := CenterContainer.new()
	card.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var heading := Label.new()
	heading.text = "MINIGAME TUNING"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	heading.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(heading)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_subtitle_label.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(_subtitle_label)

	# The large Challenge Mode toggle (Tim, 2026-06-30): switches every game launch below between
	# normal Minigame Mode and endless Challenge Mode. Its label + style show the CURRENT mode; it is
	# taller than the game buttons so it reads as the mode switch, not just another entry.
	_mode_button = Button.new()
	_mode_button.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 1.4))
	_mode_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	_mode_button.pressed.connect(_toggle_mode)
	column.add_child(_mode_button)

	# One button per type in the library. We read each type's display name by briefly
	# instantiating it — a bare Minigame node is cheap and display_name() is safe to call
	# before begin(); we free the probe immediately since it's never added to the tree.
	_type_buttons.clear()
	for type_script in MinigameScreen.MINIGAME_TYPES:
		var probe := type_script.new() as Minigame
		var type_name := probe.display_name()
		probe.free()

		var button := Button.new()
		button.custom_minimum_size = Vector2(420, UiPalette.STANDARD_BUTTON_HEIGHT)
		button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
		UiPalette.style_button(button, false)
		button.pressed.connect(_on_type_pressed.bind(type_script))
		column.add_child(button)
		_type_buttons.append({"type": type_script, "button": button, "name": type_name})

	# Set the toggle, subtitle, and game-button labels for the starting mode (Minigame).
	_refresh_mode_ui()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	close_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(close_button, true)  # red: leaving the screen
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)

	return card


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## Restyle the toggle + relabel everything for the current mode. In Challenge Mode each game button
## also shows its saved high score, and the toggle turns red (the "hot" mode) to read as active.
func _refresh_mode_ui() -> void:
	if _challenge_selected:
		_mode_button.text = "CHALLENGE MODE — tap for Minigame"
		UiPalette.style_button(_mode_button, true)   # red action styling marks the active mode
		_subtitle_label.text = "Free play — no timer, no win/loss. Beat your best score!"
	else:
		_mode_button.text = "MINIGAME MODE — tap for Challenge"
		UiPalette.style_button(_mode_button, false)
		_subtitle_label.text = "Open any minigame to review it."
	for entry in _type_buttons:
		var type_name: String = entry["name"]
		var button: Button = entry["button"]
		if _challenge_selected:
			button.text = "%s — Best: %d" % [type_name, ChallengeScores.get_high_score(type_name)]
		else:
			button.text = type_name


## Flip between Minigame Mode and Challenge Mode (the toggle button).
func _toggle_mode() -> void:
	_challenge_selected = not _challenge_selected
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
