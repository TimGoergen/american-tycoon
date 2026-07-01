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

	var subtitle := Label.new()
	subtitle.text = "Open any minigame to review it."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	subtitle.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(subtitle)

	# One button per type in the library. We read each type's display name by briefly
	# instantiating it — a bare Minigame node is cheap and display_name() is safe to call
	# before begin(); we free the probe immediately since it's never added to the tree.
	for type_script in MinigameScreen.MINIGAME_TYPES:
		var probe := type_script.new() as Minigame
		var label := probe.display_name()
		probe.free()

		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(420, UiPalette.STANDARD_BUTTON_HEIGHT)
		button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
		UiPalette.style_button(button, false)
		button.pressed.connect(_on_type_pressed.bind(type_script))
		column.add_child(button)

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

func _on_type_pressed(type_script: Script) -> void:
	_list_view.visible = false
	# Review play always shows the prestige/Legacy framing with sample numbers; it never
	# banks anything, so the reward context is purely cosmetic here.
	_player.start_game(
		MinigameScreen.legacy_reward(SAMPLE_BASE_LEGACY), SAMPLE_BONUS_MAX, type_script, true
	)


func _return_to_list() -> void:
	_player.visible = false
	_list_view.visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
