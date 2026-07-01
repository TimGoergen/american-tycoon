class_name MinigameScreen
extends ColorRect

# The minigame HOST (GDD §5.5). It picks a random minigame TYPE from the library, runs it,
# and converts its performance (0..1) into the universal outcome multiplier shared by every
# minigame: 0.5x (keep floor / skip) -> 1.0x (full) -> up to 1.0 + bonus_max (extra-high,
# bonus cap from the Family Reputation upgrade). The host owns everything common — the
# countdown, the live "kept" spectrum bar, the result, and the skip/opt-out — so all
# types behave identically; a type owns only its gameplay (see Minigame).
#
# The host is REWARD-AGNOSTIC: it only produces a multiplier (see `finished`) and shows a
# configurable reward noun, so the same minigames scale Legacy at the prestige site and the
# cash pile at the welcome-back site. The caller describes the reward via a context built by
# `legacy_reward` / `offline_pile_reward` (or `make_reward`) and passed to `start_game`.

## Emitted when the round ends (Continue or Skip). `multiplier` is the universal outcome
## multiplier (~0.5x .. 1.25x); the CALLER decides what it scales (the run's Legacy at
## prestige, the offline pile at welcome-back). `opt_out` true if the player asked to
## auto-skip future minigames.
signal finished(multiplier: float, opt_out: bool)

## Emitted only in review mode (Settings → Minigame Tuning) when the player taps the Back
## button to abandon the round and return to the review list. Carries no result — review
## play never affects the run's Legacy.
signal back_pressed

# The minigame library — the host draws one at random each round so the player doesn't know
# which they'll get. Add new types here (Phase 2).
const MINIGAME_TYPES := [
	preload("res://scripts/ui/MatchThreeMinigame.gd"),
	preload("res://scripts/ui/TimingBarMinigame.gd"),
	preload("res://scripts/ui/CatchMoneyMinigame.gd"),
	preload("res://scripts/ui/MemoryMinigame.gd"),
	preload("res://scripts/ui/BalanceMinigame.gd"),
	preload("res://scripts/ui/BasketballMinigame.gd"),
]

## The default purpose blurb shown in the play view's top section outside review mode. Each
## site passes its own line through its reward context (see `make_reward`); this is the
## prestige default, used when a reward omits a purpose.
const DEFAULT_PURPOSE := "Grow the inheritance"

## The full-bleed themed backdrop shown behind the card (Tim, 2026-06-29): a casino/library
## "Riches & Rolls" scene with an ornate empty frame in its center that the (now semi-transparent)
## card floats over. Sits inside the black screen bezel like every other screen's background.
const BACKGROUND_IMAGE := "res://art/backgrounds/minigame_background.png"

## The centered panel that frames every minigame, as anchor fractions of the full-screen scrim, so
## it stays centered and scales with the screen. Shrunk 2026-06-29 (Tim): 20% shorter and 10%
## narrower than the original 0.84 tall / 0.95 wide, so more of the backdrop shows around it.
const PANEL_WIDTH_FRACTION := 0.855   # 0.95 * 0.90  (10% narrower)
const PANEL_HEIGHT_FRACTION := 0.672  # 0.84 * 0.80  (20% shorter)
## Thickness of that black outline. It is the ONLY thing setting the card apart from the cream
## background behind it (same fill), so it is deliberately thick and well above the 2px screen
## bezel frame.
const PANEL_BORDER_WIDTH := 8

## How fast the spectrum bar's fill glides toward its true value (per-second lerp weight). The
## bar tracks a smoothed `_display_mult` rather than the raw live multiplier so it reads as a
## sweep, not a jitter — the single most-visible shared element, smoothed once here for all six
## games (plan §1 juice).
const KEEP_BAR_LERP_SPEED := 8.0
## Time-pressure thresholds (seconds left) where the shared timer escalates its warning: a slow
## amber pulse under WARN, a fast gold blink + scale under CRITICAL. Shared by every game for
## free (plan §1 juice).
const TIMER_WARN_SECONDS := 10.0
const TIMER_CRITICAL_SECONDS := 3.0

var _tuning: TuningConfig
## The pre-minigame base reward being scaled (Legacy count at prestige, cash pile at
## welcome-back). Kept as a float so it can hold either a small Legacy count or a large
## cash pile; the display formats it per `_format_as_money`.
var _base_amount: float = 0.0
## How the host words the reward: the singular noun (e.g. "Legacy") for plain counts, the
## result-screen heading, and whether amounts are formatted as dollars instead of a count.
var _reward_noun: String = "Legacy"
var _result_heading: String = "THE INHERITANCE"
var _format_as_money: bool = false
var _bonus_max: float = 0.25
var _seconds_left: float = 0.0
var _playing: bool = false
var _opt_out: bool = false
var _active_minigame: Minigame
var _purpose: String = DEFAULT_PURPOSE

## Review mode (Settings → Minigame Tuning): a Back button is shown so a tester can bail
## out at any time. False for the real prestige round, where there is no Back.
var _review_mode: bool = false
## The Back buttons (one per view), shown only in review mode. Tracked so start_game can
## flip their visibility for the chosen mode.
var _back_buttons: Array = []
## The play view's centered "purpose" blurb (e.g. "Grow the inheritance"), shown ONLY outside
## review mode — in the tuner the top section is just the Back button instead.
var _purpose_label: Label

var _play_view: Control
var _result_view: Control
var _timer_label: Label
## The spectrum bar communicates by fill + color ONLY — no numeric "kept" readout (plan §1,
## decision 2026-06-29). What you'd keep on a skip is made legible on the SKIP button instead.
var _keep_bar: Control
## The skip control, kept as a field so start_game can label it with the concrete reward a skip
## banks (the keep floor), now that the spectrum bar shows no numbers.
var _skip_button: Button
## The smoothed multiplier the spectrum bar actually draws — lerped toward the live multiplier
## each frame so the fill glides (see KEEP_BAR_LERP_SPEED).
var _display_mult: float = 0.5
## Tracks whether the smoothed fill has reached the "full" (1.0x) line, so the host can fire a
## one-shot flash the moment it first crosses (plan §1: the warm→green jump made loud).
var _was_at_least_full: bool = false
## A decaying [0,1] flash intensity drawn over the whole bar when the fill crosses into "full".
var _full_flash: float = 0.0
## Accumulates while a round runs; drives the timer's warning pulse/blink oscillation without
## needing a wall-clock (it is reset each round).
var _warn_phase: float = 0.0
var _play_area: Control
var _result_heading_label: Label
var _result_mult_label: Label
var _result_amount_label: Label
## A type-specific line on the result screen ("Scored 1,240 points", "Caught 14 of 18"), so the
## paused result clearly reflects the game just played. Hidden when the type provides none.
var _result_summary_label: Label
var _opt_out_check: CheckBox

## The "Get Ready / BEGIN" gate shown over the card at the start of every round. The clock and the
## chosen type both stay frozen until the player presses Begin, so no round ever starts the instant
## the screen appears (Tim, 2026-06-26). `_begin_title` names the drawn type on that gate.
var _begin_overlay: Control
var _begin_title: Label
## The "how to play" goal line on the Get Ready gate — the active type's own one-liner (set per
## round in start_game), so the player learns the goal BEFORE the clock starts (Tim, 2026-06-29).
var _begin_howto: Label

## The full-bleed themed backdrop. Its rounded corners are CPU-BAKED at the displayed size (see
## _rebake_backdrop) so the bright bottom-corner art doesn't poke past the screen's rounded frame —
## clip_children can't do it here (the project supports only one clip stencil, and Main owns it).
var _backdrop: TextureRect
## The size the backdrop was last baked for, so we only re-bake when it actually changes.
var _baked_backdrop_size: Vector2 = Vector2.ZERO

## Challenge Mode (Tim, 2026-06-30): a free-play arcade mode launched from the Minigame Tuning
## screen. No time limit, no win/loss reward — the chosen type runs endlessly and we track the raw
## score, saving a per-type high score. When true the host hides the timer/spectrum/skip reward
## chrome and shows a live score + best readout, and DONE ends the run (saving the high score).
var _challenge_mode: bool = false
var _score_label: Label
var _highscore_label: Label
## The best score to beat this run — starts at the saved high score and rises live as the player
## passes it, so the "Best" readout ticks up in real time.
var _challenge_high: int = 0
## The active type's display name — the key under which its Challenge high score is saved.
var _active_type_key: String = ""

## The Get Ready gate's stakes and hint lines, kept as fields so start_game / start_challenge can
## set the wording per mode (reward stakes vs. "play as long as you like").
var _begin_stakes: Label
var _begin_hint: Label


func setup(tuning: TuningConfig) -> void:
	_tuning = tuning


func _ready() -> void:
	# A black field hugs the screen edge and frames the viewing area — the same bezel every other
	# full-screen screen uses. Behind the card now sits a full-bleed themed backdrop (Tim,
	# 2026-06-29); the card itself is semi-transparent so the backdrop reads through it.
	color = Color.BLACK
	visible = false

	# The full-bleed backdrop image, inset inside the black bezel like every other screen's
	# background. Its texture is CPU-baked (see _rebake_backdrop): the source image is scaled to
	# cover this rect and its four corners are rounded to match the screen frame, so the bright
	# bottom-corner art (chips/gold) doesn't poke past the rounded border. We bake instead of using
	# clip_children because the project supports only one clip stencil and Main already owns one — a
	# second would render empty (the documented 2026-06-26 render bug). STRETCH_SCALE because the
	# baked image is already sized to this rect.
	_backdrop = TextureRect.new()
	UiPalette.apply_screen_bezel(_backdrop)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	# Bake once the backdrop has been laid out (its size is known), and again if that size changes.
	_backdrop.resized.connect(_rebake_backdrop)
	_rebake_backdrop.call_deferred()

	# The shared rounded screen frame over the backdrop edges: transparent fill (so the image
	# shows through), thin black rounded border, universal inner margin — the same frame every
	# screen uses, kept for visual consistency with the rest of the game.
	var frame := PanelContainer.new()
	UiPalette.apply_screen_bezel(frame)
	frame.add_theme_stylebox_override("panel", UiPalette.make_screen_frame_style())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# The game card itself, centered on top of that background with its own thick outline.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_card_style())
	# Center the panel by anchor fractions so it scales with the screen and stays centered.
	var half_w := PANEL_WIDTH_FRACTION / 2.0
	var half_h := PANEL_HEIGHT_FRACTION / 2.0
	panel.anchor_left = 0.5 - half_w
	panel.anchor_right = 0.5 + half_w
	panel.anchor_top = 0.5 - half_h
	panel.anchor_bottom = 0.5 + half_h
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	add_child(panel)

	# The two views (play / result) share one slot that fills the panel, so the play area
	# stretches to fill the card.
	var slot := MarginContainer.new()
	panel.add_child(slot)
	_play_view = _build_play_view()
	slot.add_child(_play_view)
	_result_view = _build_result_view()
	slot.add_child(_result_view)

	# The Begin gate floats on top of the card, covering the play/result views until the player
	# presses Begin. Added to the panel after the slot so it draws over everything inside the card.
	_begin_overlay = _build_begin_overlay()
	panel.add_child(_begin_overlay)


## The cream card that frames every minigame — and, shared, the Minigame Tuning list, so the two
## match exactly: cream fill at 70% alpha (so the themed backdrop reads through), a moderately thick
## black outline, and the universal inner content margin. Static so the review screen builds the
## identical card via this + PANEL_WIDTH_FRACTION / PANEL_HEIGHT_FRACTION.
static func make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# 70% alpha (Tim, 2026-06-30) so the themed backdrop reads through the card.
	style.bg_color = Color(UiPalette.CREAM, 0.7)
	style.set_corner_radius_all(24)
	style.border_color = Color.BLACK
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_content_margin_all(UiPalette.UNIVERSAL_CONTENT_MARGIN)
	return style


## Bake this screen's backdrop to fit its current on-screen size with ROUNDED corners, so the
## bright bottom-corner art doesn't square off past the screen's rounded frame. Re-runs only when
## the size actually changes. The Minigame Tuning screen shares the baking via the static helper.
func _rebake_backdrop() -> void:
	if _backdrop == null:
		return
	var target := Vector2i(int(_backdrop.size.x), int(_backdrop.size.y))
	if target.x < 1 or target.y < 1 or _baked_backdrop_size == _backdrop.size:
		return
	_baked_backdrop_size = _backdrop.size
	var texture := bake_rounded_backdrop(target, UiPalette.SCREEN_CORNER_RADIUS)
	if texture != null:
		_backdrop.texture = texture


## Load the shared backdrop image, scale it to COVER `size` (cropping the overflow, like
## STRETCH_KEEP_ASPECT_COVERED), and round its four corners to `radius`. Returns a ready-to-assign
## texture, or null if the image can't be loaded. Static + shared so the minigame screen and the
## Minigame Tuning screen produce the identical rounded backdrop from one place.
static func bake_rounded_backdrop(size: Vector2i, radius: int) -> ImageTexture:
	if size.x < 1 or size.y < 1:
		return null
	var source: Texture2D = load(BACKGROUND_IMAGE)
	if source == null:
		return null
	var image := source.get_image()
	# Editing pixels needs an uncompressed RGBA image (the source PNG imports as RGB / possibly VRAM
	# compressed); convert so we can crop, resize, and write transparent corners.
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)

	# Scale to COVER the target rect (fill fully, crop the overflow), then center-crop to size.
	var cover := maxf(float(size.x) / image.get_width(), float(size.y) / image.get_height())
	image.resize(
		int(ceil(image.get_width() * cover)), int(ceil(image.get_height() * cover)),
		Image.INTERPOLATE_BILINEAR
	)
	var crop_offset := Vector2i((image.get_width() - size.x) / 2, (image.get_height() - size.y) / 2)
	var fitted := image.get_region(Rect2i(crop_offset, size))

	_clear_image_corners(fitted, radius)
	return ImageTexture.create_from_image(fitted)


## Make the four corners of `image` transparent to a quarter-circle of the given radius, so the
## image reads with rounded corners (same technique HeroStat uses for its globe watermark).
static func _clear_image_corners(image: Image, radius: int) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corners := [
		{"center": Vector2i(radius, radius), "dir": Vector2i(-1, -1)},           # top-left
		{"center": Vector2i(w - radius, radius), "dir": Vector2i(1, -1)},        # top-right
		{"center": Vector2i(radius, h - radius), "dir": Vector2i(-1, 1)},        # bottom-left
		{"center": Vector2i(w - radius, h - radius), "dir": Vector2i(1, 1)},     # bottom-right
	]
	for corner in corners:
		var center: Vector2i = corner["center"]
		var dir: Vector2i = corner["dir"]
		for offset_y in range(radius):
			for offset_x in range(radius):
				# A pixel in the outward corner quadrant, beyond the radius from the arc centre, is
				# outside the rounded edge — clear it.
				if Vector2(offset_x, offset_y).length() <= radius:
					continue
				var pixel := center + Vector2i(dir.x * offset_x, dir.y * offset_y)
				if pixel.x < 0 or pixel.y < 0 or pixel.x >= w or pixel.y >= h:
					continue
				var color := image.get_pixel(pixel.x, pixel.y)
				color.a = 0.0
				image.set_pixel(pixel.x, pixel.y, color)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_play_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)

	# The top section is context-dependent: in the tuner it is a left-aligned Back button; in a
	# live round it is a centered blurb naming the minigame's purpose. start_game toggles which.
	_add_back_button(column)
	_purpose_label = _make_label(_purpose, UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	_purpose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purpose_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_purpose_label)

	# The timer is the round's focal point (plan §1): big, centered, faux-bold, so time pressure
	# reads at a glance. Its color/scale escalate as time runs low (see _refresh_timer).
	_timer_label = _make_label("0:30", UiPalette.FONT_DISPLAY, UiPalette.KETCHUP_RED)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_override("font", UiPalette.make_bold_font())
	column.add_child(_timer_label)

	# Challenge Mode readouts (hidden in normal reward rounds): the live score, big and central like
	# the timer it replaces, with the best-to-beat under it. start_challenge shows them; start_game
	# hides them.
	_score_label = _make_label("", UiPalette.FONT_DISPLAY, UiPalette.MONEY_GREEN)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_score_label.visible = false
	column.add_child(_score_label)

	_highscore_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.DARK_GOLD)
	_highscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_highscore_label.visible = false
	column.add_child(_highscore_label)

	# The universal spectrum bar — identical for every minigame type; it reads the active type's
	# live performance. It carries meaning by fill + color ONLY (no numbers): warm red→gold below
	# the "full" line, green→blue into the extra-high bonus band.
	_keep_bar = Control.new()
	_keep_bar.custom_minimum_size = Vector2(0, 34)
	_keep_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_bar.draw.connect(_draw_keep_bar)
	column.add_child(_keep_bar)

	# The chosen minigame TYPE fills this area each round. A modest minimum keeps it from
	# collapsing; the expand flags make it take all the room left inside the centered panel
	# after the top section, timer, spectrum bar, and skip controls.
	_play_area = Control.new()
	_play_area.custom_minimum_size = Vector2(0, 400)
	_play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_play_area)

	# SKIP banks the keep floor immediately. Now that the spectrum bar shows no numbers, this
	# button is the one place "what you'd keep" is made legible: start_game labels it with the
	# concrete keep-floor reward (plan §1, decision 2026-06-29).
	_skip_button = Button.new()
	_skip_button.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(_skip_button, false)
	_skip_button.text = "SKIP"
	_skip_button.pressed.connect(_on_skip_pressed)
	column.add_child(_skip_button)

	_opt_out_check = CheckBox.new()
	_opt_out_check.text = "Skip minigames from now on"
	_opt_out_check.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	for state in ["font_color", "font_pressed_color", "font_hover_color",
			"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		_opt_out_check.add_theme_color_override(state, UiPalette.NAVY)
	_opt_out_check.toggled.connect(func(on: bool) -> void: _opt_out = on)
	column.add_child(_opt_out_check)

	return column


func _build_result_view() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.visible = false

	_add_back_button(column)

	# The heading names what was won ("THE INHERITANCE" / "THE OVERNIGHT HAUL"); start_game
	# sets it per site from the reward context.
	_result_heading_label = _make_label("THE INHERITANCE", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	_result_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_heading_label)

	_result_mult_label = _make_label("", UiPalette.FONT_DISPLAY, UiPalette.MUSTARD_GOLD)
	_result_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_mult_label)

	_result_amount_label = _make_label("", UiPalette.FONT_SUBHEAD, UiPalette.MONEY_GREEN)
	_result_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_amount_label)

	# How the player did at the game itself (set per round from the type's result_summary).
	_result_summary_label = _make_label("", UiPalette.FONT_LABEL, UiPalette.NAVY)
	_result_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_result_summary_label)

	var continue_button := Button.new()
	continue_button.custom_minimum_size = Vector2(0, 80)
	UiPalette.style_button(continue_button, true)
	continue_button.text = "CONTINUE"
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)

	return column


## The "Get Ready" gate over the card: the drawn type's name, goal, stakes, and a big BEGIN button.
## No opaque scrim — the gate lets the 70%-translucent card (and the backdrop through it) show, so
## Get Ready reads at the same 70% as the rest of the panel (Tim, 2026-06-30). The not-yet-started
## game is hidden instead by keeping _play_view invisible until Begin (see start_game /
## _start_active_round). start_game shows the gate; _on_begin_pressed fades it and starts the round.
func _build_begin_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	# Constrain the column width (design space is 1080 wide) so the longer goal lines wrap inside
	# the card instead of running off it — the CenterContainer otherwise shrinks the box to its
	# widest single line.
	box.custom_minimum_size = Vector2(720, 0)
	center.add_child(box)

	var ready := _make_label("GET READY", UiPalette.FONT_HEADLINE, UiPalette.NAVY)
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ready)

	# Names the randomly drawn type so the player knows what they're about to play.
	_begin_title = _make_label("", UiPalette.FONT_DISPLAY, UiPalette.MUSTARD_GOLD)
	_begin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_title)

	# The goal of THIS game (set per round from the type's how_to_play), so the player knows the
	# objective before the clock starts rather than only once play begins (Tim, 2026-06-29).
	_begin_howto = _make_label("", UiPalette.FONT_CARD_BODY, UiPalette.NAVY)
	_begin_howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_howto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_howto)

	# The stakes line — reward win/lose in a normal round, "play as long as you like" in Challenge
	# Mode. Set per mode by start_game / start_challenge (kept as a field for that).
	_begin_stakes = _make_label("", UiPalette.FONT_LABEL, UiPalette.DARK_GOLD)
	_begin_stakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_stakes)

	# The closing hint ("The clock starts…" normally; hidden in Challenge Mode). Also a field.
	_begin_hint = _make_label("The clock starts when you press Begin.", UiPalette.FONT_LABEL, UiPalette.NAVY)
	_begin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_begin_hint)

	var begin_button := Button.new()
	begin_button.custom_minimum_size = Vector2(360, 110)
	UiPalette.style_button(begin_button, true)  # the action (red) button — this is the "go" control
	begin_button.text = "BEGIN"
	begin_button.pressed.connect(_on_begin_pressed)
	box.add_child(begin_button)

	return overlay


## Add a left-aligned Back button to the top of a view's column. Hidden by default; only
## review mode (start_game's review_mode flag) makes it visible. A short HBox keeps it from
## stretching the full width — it sits in the top-left like a typical "back" affordance.
func _add_back_button(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(back, false)
	back.visible = false
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)
	# A spacer eats the rest of the row so the button keeps its natural width on the left.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_back_buttons.append(back)
	column.add_child(row)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

## Describe a round's reward for the host's DISPLAY only. The outcome math (the multiplier)
## is universal; these fields just control wording/formatting so the same minigames can scale
## Legacy at prestige and the cash pile at welcome-back. `base` is the pre-minigame amount,
## `noun` the singular reward word for plain counts ("Legacy"), `heading` the result-screen
## title, `purpose` the play-view blurb, and `format_as_money` formats amounts as dollars.
static func make_reward(
		base: float, noun: String, heading: String, purpose: String, format_as_money: bool
) -> Dictionary:
	return {
		"base": base, "noun": noun, "heading": heading,
		"purpose": purpose, "as_money": format_as_money,
	}


## The prestige/succession round: scales the heir's Legacy (a plain count).
static func legacy_reward(base_legacy: int) -> Dictionary:
	return make_reward(float(base_legacy), "Legacy", "THE INHERITANCE", DEFAULT_PURPOSE, false)


## The welcome-back round (GDD §5.5 site 3): scales the overnight cash pile (money).
static func offline_pile_reward(pile: float) -> Dictionary:
	return make_reward(
		pile, "", "THE OVERNIGHT HAUL", "Make the most of your time away", true
	)


## The First Contact round (GDD §5.5 site 2): the alien trade negotiation. Unlike the other
## two sites it does NOT scale money or Legacy — it scales the player's HEAD START on the new
## alien property, a count of free starting units. `cap` is what a full negotiation grants;
## `property_name` is the business being opened (shown as the result heading).
static func first_contact_reward(cap: int, property_name: String) -> Dictionary:
	return make_reward(
		float(cap), "units", property_name.to_upper(),
		"Negotiate your opening stake in %s" % property_name, false
	)


## Start a round. `reward` is a context from `make_reward` (or one of the named builders)
## describing what is being scaled and how to show it; `bonus_max` is the max extra-high
## bonus fraction (Family Reputation). Normally picks a random minigame type; the review
## screen passes a specific `forced_type` and sets `review_mode` so a Back button appears.
## Live play leaves both at their defaults (random type, no Back).
func start_game(
		reward: Dictionary, bonus_max: float, forced_type: Script = null, review_mode: bool = false
) -> void:
	# A normal reward round: make sure the reward chrome (timer/spectrum/skip/opt-out) is shown and
	# the Challenge chrome hidden, in case the previous round was a Challenge run.
	_challenge_mode = false
	_set_challenge_chrome(false)
	_base_amount = float(reward.get("base", 0.0))
	_reward_noun = String(reward.get("noun", "Legacy"))
	_result_heading = String(reward.get("heading", "THE INHERITANCE"))
	_format_as_money = bool(reward.get("as_money", false))
	var purpose := String(reward.get("purpose", DEFAULT_PURPOSE))

	_bonus_max = maxf(0.0, bonus_max)
	_seconds_left = _tuning.minigame_duration_seconds
	_opt_out = false
	if _opt_out_check != null:
		_opt_out_check.button_pressed = false

	# The result heading names what was won; set it before the round so the result view is
	# already correct when it appears.
	if _result_heading_label != null:
		_result_heading_label.text = _result_heading

	_review_mode = review_mode
	# Top section: the Back button in the tuner, the purpose blurb in a live round — never both.
	for back in _back_buttons:
		(back as Button).visible = review_mode
	if _purpose_label != null:
		_purpose = purpose
		_purpose_label.text = purpose
		_purpose_label.visible = not review_mode

	for child in _play_area.get_children():
		child.queue_free()
	var type_script: Script = forced_type if forced_type != null \
			else MINIGAME_TYPES[randi() % MINIGAME_TYPES.size()]
	_active_minigame = type_script.new()
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tell the type where this round's outcome curve sits (floor + bonus cap) BEFORE it begins, so
	# a type that aligns its scoring to the shared "full" line (match-3) can read it. See Minigame.
	_active_minigame.outcome_keep_floor = _tuning.minigame_keep_floor
	_active_minigame.outcome_bonus_max = _bonus_max
	_play_area.add_child(_active_minigame)
	_active_minigame.completed.connect(_on_minigame_completed)
	# Most types run for the shared default; a type may ask for more time on top of it (basketball).
	_seconds_left = _tuning.minigame_duration_seconds + maxf(0.0, _active_minigame.extra_seconds())

	# The round does NOT start yet: the type stays un-begun and the clock paused behind the Begin
	# gate, so the player is never caught off guard. _on_begin_pressed starts it for real.
	# The play view stays hidden behind the (now scrim-less) Get Ready gate, so the not-yet-started
	# game doesn't show through the translucent card; _start_active_round reveals it on Begin.
	_play_view.visible = false
	_play_view.modulate = Color.WHITE
	_result_view.visible = false
	_playing = false
	_timer_label.text = "0:%02d" % int(ceil(_seconds_left))
	_timer_label.scale = Vector2.ONE

	# Reset the shared juice state so a new round starts at the keep floor with no carried-over
	# flash, pulse, or smoothing from the previous round.
	_display_mult = _tuning.minigame_keep_floor
	_was_at_least_full = false
	_full_flash = 0.0
	_warn_phase = 0.0
	_keep_bar.queue_redraw()

	# Label SKIP with what skipping actually banks (the keep floor) — the one place the floor is
	# made legible now that the spectrum bar carries no numbers.
	var skip_amount := _base_amount * _tuning.minigame_keep_floor
	_skip_button.text = "SKIP · keep %s" % _format_amount(skip_amount)

	_begin_title.text = _active_minigame.display_name()
	_begin_howto.text = _active_minigame.how_to_play()
	# Reward stakes on the gate (Challenge Mode replaces this in start_challenge).
	_begin_stakes.text = "Play well to keep MORE — a great round earns a bonus on top. A weak round or Skip keeps only the minimum."
	_begin_stakes.visible = true
	_begin_hint.text = "The clock starts when you press Begin."
	_begin_hint.visible = true

	_begin_overlay.modulate = Color.WHITE
	_begin_overlay.visible = true
	visible = true


## Start a CHALLENGE MODE run (Tim, 2026-06-30): the given type runs ENDLESSLY — no timer, no
## win/loss — and the host tracks its raw score, shown live with the saved high score to beat.
## Launched from the Minigame Tuning screen, so review_mode is on (a Back button appears). Tapping
## DONE (or Back) saves the high score and returns to the list.
func start_challenge(type_script: Script) -> void:
	_challenge_mode = true
	_review_mode = true
	_set_challenge_chrome(true)

	# Back button visible (review context); the purpose blurb is hidden — the score readouts take
	# the top slot instead.
	for back in _back_buttons:
		(back as Button).visible = true
	if _purpose_label != null:
		_purpose_label.visible = false

	for child in _play_area.get_children():
		child.queue_free()
	_active_minigame = type_script.new()
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tell the type to run endlessly BEFORE begin() (see Minigame.challenge_mode).
	_active_minigame.challenge_mode = true
	_play_area.add_child(_active_minigame)
	# A type shouldn't self-complete in Challenge Mode, but connect anyway — a stray completion is
	# simply ignored (see _on_minigame_completed).
	_active_minigame.completed.connect(_on_minigame_completed)

	_active_type_key = _active_minigame.display_name()
	_challenge_high = ChallengeScores.get_high_score(_active_type_key)
	_score_label.text = "Score: 0"
	_highscore_label.text = "Best: %s" % _group_thousands(_challenge_high)
	# The skip control becomes the "I'm done" control in Challenge Mode.
	_skip_button.text = "DONE"

	_play_view.visible = false
	_play_view.modulate = Color.WHITE
	_result_view.visible = false
	_playing = false

	_begin_title.text = _active_minigame.display_name()
	_begin_howto.text = _active_minigame.how_to_play()
	_begin_stakes.text = "Challenge Mode — no timer, play as long as you like. Beat your best score!"
	_begin_stakes.visible = true
	_begin_hint.visible = false

	_begin_overlay.modulate = Color.WHITE
	_begin_overlay.visible = true
	visible = true


## Swap the reward chrome for the Challenge chrome. Reward mode (on=false): the timer, spectrum
## bar, and opt-out show. Challenge mode (on=true): the live score + best-to-beat show instead.
func _set_challenge_chrome(on: bool) -> void:
	_timer_label.visible = not on
	_keep_bar.visible = not on
	_opt_out_check.visible = not on
	_score_label.visible = on
	_highscore_label.visible = on


## Begin pressed on the Get Ready gate: hide it, start the chosen type, and unpause the clock — the
## one and only point where a round actually goes live.
func _on_begin_pressed() -> void:
	if _active_minigame == null:
		return
	# Fade the cream gate off to unmask the game (plan §1), THEN start the round — so the clock
	# doesn't run during the fade. The actual go-live happens in _start_active_round when the
	# fade completes.
	var fade := create_tween()
	fade.tween_property(_begin_overlay, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_start_active_round)


## The one and only point where a round actually goes live: hide the (now-invisible) gate, start
## the chosen type, and unpause the clock. Called by _on_begin_pressed's fade-out tween.
func _start_active_round() -> void:
	if _active_minigame == null:
		return
	_begin_overlay.visible = false
	_play_view.visible = true  # reveal the game now that the gate is gone and the round goes live
	_active_minigame.begin(_tuning)
	_playing = true


func _process(delta: float) -> void:
	if not _playing:
		return
	# Challenge Mode has no countdown and no win/loss — just keep the live score readout current.
	if _challenge_mode:
		_update_challenge_score()
		return
	# Pause the countdown while a type is mid-animation (e.g. match-3 cascades) so animation time
	# isn't charged to the player — but keep the spectrum bar gliding and show a "held" cue on the
	# timer so a stalled countdown doesn't read as a bug (plan §1).
	var busy := _active_minigame != null and _active_minigame.is_busy()
	if not busy:
		_seconds_left = maxf(0.0, _seconds_left - delta)
	_refresh_timer(delta, busy)
	_refresh_keep_bar(delta)
	if not busy and _seconds_left <= 0.0:
		_end_round()


## Refresh the Challenge Mode readouts: the live score, and the best-to-beat (which ticks up in real
## time once the current score passes the saved high, so a new record is visible as it happens).
func _update_challenge_score() -> void:
	var score := _active_minigame.get_score() if _active_minigame != null else 0
	_score_label.text = "Score: %s" % _group_thousands(score)
	if score > _challenge_high:
		_challenge_high = score
	_highscore_label.text = "Best: %s" % _group_thousands(_challenge_high)


## A type finished on its own (e.g. the timing bar's last lock) — end with its result. Ignored in
## Challenge Mode, which never ends on its own (the player taps DONE).
func _on_minigame_completed(_performance: float) -> void:
	if _playing and not _challenge_mode:
		_end_round()


## Format an integer with thousands separators ("1,240"), for the Challenge score readouts.
func _group_thousands(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return ("-" if value < 0 else "") + grouped


## End a Challenge run: record the final score (updates the saved high score if beaten) and return
## to the Minigame Tuning list. Called by DONE and by Back.
func _end_challenge() -> void:
	_playing = false
	var score := _active_minigame.get_score() if _active_minigame != null else 0
	ChallengeScores.record_score(_active_type_key, score)
	_challenge_mode = false
	visible = false
	back_pressed.emit()


# ---------------------------------------------------------------------------
# The universal "Legacy kept" indicator
# ---------------------------------------------------------------------------

## Performance (0..1) -> kept multiplier: keep_floor at 0, 1.0 ("full") partway up, and the
## extra-high bonus (1.0 + bonus_max) at performance 1.0. One curve for every minigame type.
func _multiplier_for_performance(performance: float) -> float:
	var floor_mult := _tuning.minigame_keep_floor
	var span := (1.0 - floor_mult) + _bonus_max
	return floor_mult + clampf(performance, 0.0, 1.0) * span


func _current_performance() -> float:
	return _active_minigame.get_performance() if _active_minigame != null else 0.0


func _keep_color(mult: float) -> Color:
	# Below the "full" line the bar heats up red -> orange -> yellow as you approach 100%; at and
	# above full it cools the other way, green -> blue, as you climb into the extra-high bonus band
	# (Tim, 2026-06-25). The deliberate red/yellow -> green jump at exactly 100% marks the moment
	# you stop losing Legacy and start banking the full inheritance.
	if mult < 1.0:
		var floor_mult := _tuning.minigame_keep_floor
		var t := clampf((mult - floor_mult) / maxf(0.0001, 1.0 - floor_mult), 0.0, 1.0)
		# Two warm segments: red -> orange in the first half, orange -> yellow in the second.
		if t < 0.5:
			return UiPalette.KETCHUP_RED.lerp(UiPalette.ORANGE, t / 0.5)
		return UiPalette.ORANGE.lerp(UiPalette.MUSTARD_GOLD, (t - 0.5) / 0.5)
	var into_extra := clampf((mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)
	return UiPalette.MONEY_GREEN.lerp(UiPalette.CYCLE_BLUE, into_extra)


## Format an amount the way this round's reward wants it: as dollars (the cash pile) or as a
## plain count of the reward noun (e.g. "12 Legacy"). Counts floor to whole units.
func _format_amount(amount: float) -> String:
	if _format_as_money:
		return Money.of(amount).display()
	return "%d %s" % [int(floor(amount)), _reward_noun]


## Update the focal timer each frame: a slow amber pulse under TIMER_WARN_SECONDS, a fast gold
## blink + scale under TIMER_CRITICAL_SECONDS, and a "held" cue (muted color + pause glyph) while
## the type is mid-animation so the paused countdown doesn't read as a bug. (plan §1 juice.)
func _refresh_timer(delta: float, busy: bool) -> void:
	var secs := int(ceil(_seconds_left))
	if busy:
		_timer_label.text = "0:%02d  ⏸" % secs
		_timer_label.add_theme_color_override("font_color", UiPalette.NAVY)
		_set_timer_scale(1.0)
		return

	_warn_phase += delta
	_timer_label.text = "0:%02d" % secs
	var color := UiPalette.KETCHUP_RED
	var pulse := 1.0
	if _seconds_left <= TIMER_CRITICAL_SECONDS and _seconds_left > 0.0:
		# A fast 0..1 oscillation drives a blink toward gold plus a gentle grow, for real urgency.
		var beat := 0.5 + 0.5 * sin(_warn_phase * 18.0)
		color = UiPalette.KETCHUP_RED.lerp(UiPalette.MUSTARD_GOLD, beat)
		pulse = 1.0 + 0.14 * beat
	elif _seconds_left <= TIMER_WARN_SECONDS:
		var beat := 0.5 + 0.5 * sin(_warn_phase * 8.0)
		color = UiPalette.KETCHUP_RED.lerp(UiPalette.MUSTARD_GOLD, beat * 0.5)
		pulse = 1.0 + 0.05 * beat
	_timer_label.add_theme_color_override("font_color", color)
	_set_timer_scale(pulse)


## Scale the timer label about its own center (a Label scales from its top-left by default, which
## would drift the centered text sideways as it pulses).
func _set_timer_scale(factor: float) -> void:
	_timer_label.pivot_offset = _timer_label.size / 2.0
	_timer_label.scale = Vector2(factor, factor)


## Glide the spectrum bar toward the live multiplier and fire a one-shot flash when it first
## crosses into "full". The smoothed value `_display_mult` is what _draw_keep_bar paints.
func _refresh_keep_bar(delta: float) -> void:
	var target := _multiplier_for_performance(_current_performance())
	var weight := clampf(delta * KEEP_BAR_LERP_SPEED, 0.0, 1.0)
	_display_mult = lerpf(_display_mult, target, weight)

	# Flash the moment the smoothed fill first reaches the "full" line (and re-arm if it drops
	# back below), so the warm→green color jump lands with a visible pop instead of silently.
	if not _was_at_least_full and _display_mult >= 1.0:
		_was_at_least_full = true
		_full_flash = 1.0
	elif _was_at_least_full and _display_mult < 1.0:
		_was_at_least_full = false
	_full_flash = maxf(0.0, _full_flash - delta * 2.5)
	_keep_bar.queue_redraw()


func _draw_keep_bar() -> void:
	var w := _keep_bar.size.x
	var h := _keep_bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var floor_mult := _tuning.minigame_keep_floor
	var span := maxf(0.0001, (1.0 + _bonus_max) - floor_mult)
	# Draw the SMOOTHED multiplier so the fill glides rather than jumps (see _refresh_keep_bar).
	var mult := _display_mult
	var fill_frac := clampf((mult - floor_mult) / span, 0.0, 1.0)

	_keep_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	_keep_bar.draw_rect(Rect2(0, 0, fill_frac * w, h), _keep_color(mult))

	# A soft bright cap rides the leading edge of the fill, brightening as performance climbs into
	# the extra-high bonus band (plan §1) — a small reward for pushing past "full".
	var into_bonus := clampf((mult - 1.0) / maxf(0.0001, _bonus_max), 0.0, 1.0)
	var edge_x := fill_frac * w
	var cap_w := 10.0
	var cap_color := _keep_color(mult).lerp(Color.WHITE, 0.4 + 0.5 * into_bonus)
	cap_color.a = 0.35 + 0.55 * into_bonus
	_keep_bar.draw_rect(Rect2(edge_x - cap_w, 0, cap_w, h), cap_color)

	# A one-shot white wash across the whole bar the instant the fill first reaches "full"
	# (decays in _refresh_keep_bar) so the warm→green color jump lands with a pop, not silently.
	if _full_flash > 0.0:
		_keep_bar.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, _full_flash * 0.5))

	# No "full" divider line (Tim, 2026-06-25): the deliberate warm→green color jump at exactly
	# 100% already marks where you stop losing Legacy and start banking bonus, so the line is
	# redundant. The color change alone carries the meaning.
	_keep_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 2.0)


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------

func _end_round() -> void:
	_playing = false
	_show_result(_multiplier_for_performance(_current_performance()))


func _show_result(mult: float) -> void:
	var kept := _base_amount * mult
	if mult > 1.0:
		_result_mult_label.text = "+%d%% BONUS" % int(round((mult - 1.0) * 100.0))
		_result_mult_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
		_result_amount_label.text = "+%s  (%s +%s bonus)" % \
				[_format_amount(kept), _format_amount(_base_amount), _format_amount(kept - _base_amount)]
	elif mult >= 1.0:
		_result_mult_label.text = "FULL"
		_result_mult_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
		_result_amount_label.text = "+%s" % _format_amount(kept)
	else:
		_result_mult_label.text = "KEPT %d%%" % int(round(mult * 100.0))
		_result_mult_label.add_theme_color_override("font_color", _keep_color(mult))
		_result_amount_label.text = "+%s  (of %s)" % [_format_amount(kept), _format_amount(_base_amount)]

	# The type's own summary of how the round was played (empty for types that provide none).
	var summary := _active_minigame.result_summary() if _active_minigame != null else ""
	_result_summary_label.text = summary
	_result_summary_label.visible = summary != ""

	_play_view.visible = false
	_result_view.visible = true
	visible = true
	_animate_result()


## The payoff beat (plan §1): fade the result view in, then bloom the multiplier and amount with a
## brief scale pop and a flash to white, so the reveal reads as a reward rather than an instant cut.
func _animate_result() -> void:
	_result_view.modulate = Color(1, 1, 1, 0)
	var reveal := create_tween()
	reveal.tween_property(_result_view, "modulate:a", 1.0, 0.25)

	for label in [_result_mult_label, _result_amount_label]:
		# Capture each label's settled color so the white flash can resolve back to it.
		var final_color: Color = label.get_theme_color("font_color")
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(0.7, 0.7)
		label.add_theme_color_override("font_color", Color.WHITE)
		var bloom := create_tween()
		bloom.set_parallel(true)
		bloom.tween_property(label, "scale", Vector2.ONE, 0.4) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bloom.tween_property(label, "modulate", Color.WHITE, 0.0)  # ensure full opacity for the bloom
		bloom.tween_method(
				func(c: Color) -> void: label.add_theme_color_override("font_color", c),
				Color.WHITE, final_color, 0.45)


## Back (review mode only): abandon the round and return to the review list. No result is
## emitted — reviewing a minigame never touches the run's Legacy. In a Challenge run it saves the
## high score on the way out (same as DONE).
func _on_back_pressed() -> void:
	if _challenge_mode:
		_end_challenge()
		return
	_playing = false
	visible = false
	back_pressed.emit()


## Skip (reward round): bank the keep floor (the worst result) and leave. In Challenge Mode this is
## the DONE button — it saves the high score and returns to the list instead.
func _on_skip_pressed() -> void:
	if _challenge_mode:
		_end_challenge()
		return
	_playing = false
	visible = false
	finished.emit(_tuning.minigame_keep_floor, _opt_out)


func _on_continue_pressed() -> void:
	visible = false
	finished.emit(_multiplier_for_performance(_current_performance()), _opt_out)
