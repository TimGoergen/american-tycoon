class_name WagePanel
extends VBoxContainer

# The wage button (Layer 1, GDD §5) — the only honest money in the game, and it
# is never removed from the screen.
#
# The "clock in" button doubles as a LEVEL-progress meter (UI notes §2): a dark-gold
# plate whose bright-gold bar fills toward the next clock-in level. A ProgressBar draws
# that fill; a transparent Button sits on top to catch taps and show the big (2×-size)
# CLOCK IN label. On the same row, to the right, a compact label shows the current level
# and the one being climbed toward ("<level> / <next>") — see WageState for the level rule
# (10 clicks for the first level, then 20, then 30, …). There is no promotion/claim step:
# leveling up is automatic once the clicks are earned (Tim, 2026-06-24).

signal wage_tapped
signal wage_hold_tapped

var _wage: WageState
var _tuning: TuningConfig
var _frenzy: FrenzyState

## Accumulates held-down time on the clock-in button to pace auto-tap pulses.
var _hold_accumulator := 0.0

# Feedback on the gold plate has TWO distinct modes, never a per-tap strobe
# (Tim's call: the old once-per-auto-tap flash outran the bar and looked like a
# strobe light):
#   • A single manual tap gives one brief, discrete brighter-gold blink across the
#     whole plate — crisp click feedback for a deliberate tap.
#   • Holding the button (auto-tapping) instead shows a soft highlight band that
#     sweeps left → right across the meter and fades out before reaching the fill
#     edge, then repeats from the left (Tim 2026-06-17 — a one-directional shimmer,
#     not the old back-and-forth glide). The band is drawn by a transparent overlay
#     above the gold fill (see _draw_sweep), so the navy border and the label stay
#     put and the button never changes size.

## The level badge's text — a vivid, saturated blue that pops on the dark-blue (INK_NAVY)
## plate (Tim, 2026-06-28).
const LEVEL_TEXT_BLUE := Color("#2E9BFF")

## Level-up blink: when the clock-in level rises, the badge pulses brighter twice, slowly, to
## announce it (Tim, 2026-06-28). BRIGHTNESS multiplies the plate's modulate at each peak;
## HALF is the up (or down) duration of one pulse, so two pulses take 4 × HALF seconds.
const LEVEL_BLINK_BRIGHTNESS := 1.9
const LEVEL_BLINK_HALF := 0.34

## How long the brighter-gold blink stays on for a single manual tap, in seconds.
## Short, so a deliberate tap reads as a crisp blink.
const FLASH_DURATION := 0.05

## How far the gold is lightened toward white at the peak of a tap blink and at the
## core of the gliding highlight band (0 = none, 1 = pure white). High, so the
## held sweep reads as a bright, intense band of light.
const FLASH_LIGHTEN := 0.45

## Seconds for one left→right sweep of the held highlight band (it then repeats from
## the left). Slow on purpose, so the held state reads as a calm shimmer, not a flicker.
const PULSE_PERIOD := 1.6

## Fraction of the sweep at which the band begins fading out, so it disappears before
## reaching the right (fill) edge rather than piling up against it.
const SWEEP_FADE_START := 0.6

## How quickly the held highlight fades in when pressed and out when released, as a
## smoothing time constant in seconds — responsive, but easing out instead of
## snapping off.
const PULSE_RAMP_TAU := 0.18

## Width of the gliding highlight band as a fraction of the GOLD-FILLED width (not
## the whole meter). Tying it to the fill keeps the band small early on — when only a
## sliver is gold — instead of a fixed wide band that swamps the whole fill, and lets
## it grow naturally as progress fills more of the bar.
const SWEEP_WIDTH_FRACTION := 0.3

## Peak opacity of the highlight band at its center (it feathers to 0 at its edges).
## Near-opaque, so the gliding band is bright and intense rather than a faint sheen.
const SWEEP_PEAK_ALPHA := 0.9

## Inset (px) that keeps the highlight band inside the meter's navy frame; matches
## the frame thickness used in UiPalette.style_gold_progress.
const SWEEP_FRAME_INSET := 8.0

## Floating "+income" indicators that rise off the button on each earning tap.
## They originate at the button's vertical center, INCOME_FLOAT_RIGHT_FRACTION of
## the width in from the right edge (± INCOME_FLOAT_ORIGIN_JITTER px of random
## spread), then float up while swaying gently side to side and fading out.
const INCOME_FLOAT_FONT_SIZE := UiPalette.FONT_SUBHEAD
const INCOME_FLOAT_DURATION := 0.9
const INCOME_FLOAT_RISE_FRACTION := 0.7    # how far up it travels (× button height)
const INCOME_FLOAT_RIGHT_FRACTION := 0.15  # origin distance in from the right edge
const INCOME_FLOAT_ORIGIN_JITTER := 5.0    # px of random spread on the origin x
const INCOME_FLOAT_SWAY := 8.0             # px amplitude of the side-to-side wave
const INCOME_FLOAT_WAVES := 1.5            # full side-to-side waves over the rise

## Seconds left in the current manual-tap blink. >0 means the blink is showing.
var _flash_remaining := 0.0

## Phase of the held highlight in seconds, advanced only while the button is held;
## drives the band's side-to-side position. Frozen (not reset) on release so the
## band fades out where it was rather than snapping back to the left.
var _pulse_phase := 0.0

## Fade envelope for the held highlight (0 = hidden, 1 = full), eased toward its
## target each frame so the band ramps in when held and fades out when released.
var _pulse_level := 0.0

# The meter's two gold plates — captured so the tap blink can lighten them in
# place and restore them. Their un-lightened colors are remembered in *_base.
var _fill_style: StyleBoxFlat
var _track_style: StyleBoxFlat
var _fill_base: Color
var _track_base: Color

var _wage_meter: ProgressBar
var _wage_button: Button
## The "<level> / <next>" readout that sits to the right of the clock-in button (15% of the
## row), showing the current clock-in level and the one being climbed toward.
var _level_label: Label
## The dark-blue plate behind the level number — blinked on level-up (modulate is pulsed).
var _level_panel: PanelContainer
## Last level shown, to detect a level-up. -1 until the first refresh so opening at a non-1
## level (a loaded save) does not fire the blink.
var _shown_level := -1
## The running level-up blink tween, held so a fresh level-up can restart it cleanly.
var _level_blink_tween: Tween

# The clock-in button's three-part content laid over the meter (Tim, 2026-06-22): a mail-cart
# icon on the left, "CLOCK IN" centered, and the live per-tap earnings "+$x" on the right.
var _wage_icon: TextureRect
var _wage_title_label: Label
var _wage_amount_label: Label

## Transparent overlay above the gold fill (below the label button) on which the
## gliding highlight band is drawn while the button is held.
var _sweep_overlay: Control


## Call before adding to the tree.
func setup(wage: WageState, tuning: TuningConfig, frenzy: FrenzyState) -> void:
	_wage = wage
	_tuning = tuning
	_frenzy = frenzy


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	# The meter is the button background; its bright-gold fill shows promotion
	# progress. It ignores the mouse so the Button on top handles every tap.
	_wage_meter = ProgressBar.new()
	# Shortened 230 -> 196 to make room for the taller tab bar while staying the big primary
	# tap target (Tim, 2026-06-22).
	_wage_meter.custom_minimum_size = Vector2(0, 196)
	_wage_meter.min_value = 0.0
	_wage_meter.max_value = 1.0
	_wage_meter.show_percentage = false
	_wage_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiPalette.style_gold_progress(_wage_meter)
	# Capture the gold styleboxes so the click-impact flash can lighten them in place.
	_fill_style = _wage_meter.get_theme_stylebox("fill") as StyleBoxFlat
	_track_style = _wage_meter.get_theme_stylebox("background") as StyleBoxFlat
	_fill_base = _fill_style.bg_color
	_track_base = _track_style.bg_color

	# The clock-in button and its level readout share one row (Tim, 2026-06-24): the meter takes
	# ~85% of the width and the "<level> / <next>" label the remaining ~15%. Setting both to
	# EXPAND_FILL with these stretch ratios gives the proportional 85/15 split at any width.
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	add_child(button_row)

	_wage_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wage_meter.size_flags_stretch_ratio = 0.85
	button_row.add_child(_wage_meter)

	# Level readout (the right 15% of the row): the current clock-in level, shown inside a
	# dark-blue plate with the same frame thickness as the clock-in button (Tim, 2026-06-24 /
	# 2026-06-28). The PanelContainer fills the row's height — which the 196px meter sets — so
	# the plate matches the button, and the bright-blue number is centered inside it.
	_level_panel = PanelContainer.new()
	_level_panel.add_theme_stylebox_override("panel", _make_level_plate())
	_level_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_panel.size_flags_stretch_ratio = 0.15
	button_row.add_child(_level_panel)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	_level_label.add_theme_color_override("font_color", LEVEL_TEXT_BLUE)
	_level_panel.add_child(_level_label)

	# Highlight overlay: a transparent, mouse-ignoring layer filling the meter, on
	# which _draw_sweep paints the gliding highlight band while the button is held.
	# Added before the label button so it sits above the gold fill but below the label.
	_sweep_overlay = Control.new()
	_sweep_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sweep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep_overlay.draw.connect(_draw_sweep)
	_wage_meter.add_child(_sweep_overlay)

	# Transparent button overlaying the meter — the gold shows through, only the
	# label and the click belong to the button. Font is 2× the old size (28→56).
	_wage_button = Button.new()
	_wage_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wage_button.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	_wage_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_wage_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_wage_button.add_theme_color_override("font_color", UiPalette.NAVY)
	_wage_button.add_theme_color_override("font_hover_color", UiPalette.NAVY)
	_wage_button.add_theme_color_override("font_pressed_color", UiPalette.INK_NAVY)
	# Fire on press, not release, so the tap and its flash land the instant the
	# button goes down — releasing first makes the feedback feel laggy.
	_wage_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_wage_button.pressed.connect(func() -> void:
		wage_tapped.emit()
		_pulse_impact()
		_spawn_income_float(_current_tap_income()))
	_wage_meter.add_child(_wage_button)

	# The button's content, laid over the meter in three parts (Tim, 2026-06-22). It is added
	# AFTER the button so it draws on top, and ignores the mouse so taps fall through to the
	# button beneath. A Button only draws one centered string, so the icon + two labels live
	# here instead of as button text.
	var content := MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 24)
	content.add_theme_constant_override("margin_right", 24)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wage_meter.add_child(content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)

	# Left: the "office worker pushing a mail cart" icon, tinted navy to match the labels.
	_wage_icon = TextureRect.new()
	_wage_icon.texture = preload("res://art/icons/mail_cart.svg")
	_wage_icon.custom_minimum_size = Vector2(180, 0)
	_wage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wage_icon.modulate = UiPalette.NAVY
	_wage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_wage_icon)

	# Center: the big "CLOCK IN" label, taking the slack between the icon and the amount.
	_wage_title_label = Label.new()
	_wage_title_label.text = "CLOCK IN"
	_wage_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wage_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wage_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wage_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_PAGE_TITLE)
	_wage_title_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_wage_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_wage_title_label)

	# Right: the live per-tap earnings, e.g. "+$4.20" (set each frame in _process).
	_wage_amount_label = Label.new()
	_wage_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wage_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wage_amount_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	_wage_amount_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_wage_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_wage_amount_label)

	# (The old title/next-title context line and the promotion claim button were removed when
	# the wage ladder became a numeric level — Tim, 2026-06-24. The level reads from the
	# "<level> / <next>" label on the clock-in row instead.)


func _process(delta: float) -> void:
	_pump_auto_tap(delta)
	_update_plate_glow(delta)

	# The per-tap rate always reflects BOTH wage Legacy upgrades — Old-Money Connections
	# (wage_multiplier) and the auto-click POWER bonus (auto_tap_power_multiplier) — on top of
	# the live frenzy multiplier (Spec §7). The power bonus used to be folded in only while the
	# button was held, so at rest the amount read as if that Legacy upgrade weren't owned (Tim,
	# 2026-06-22). The clock-in's primary mode is holding it (auto-tapping), so this full
	# held/auto-tap rate is the canonical figure; a single manual tap still pays the base rate.
	var wage_per_tap := _wage.current_wage_per_tap() * _frenzy.get_multiplier() \
			* _wage.wage_multiplier * _wage.auto_tap_power_multiplier
	_wage_amount_label.text = "+%s" % Money.of(wage_per_tap).display()

	# Right-side readout: the current clock-in level (just the number, in its dark-blue plate).
	# A rise in level blinks the plate (skipping the very first frame, _shown_level == -1, so a
	# loaded save that opens at a high level doesn't flash on arrival).
	if _shown_level >= 0 and _wage.level > _shown_level:
		_blink_level_up()
	_shown_level = _wage.level
	_level_label.text = "%d" % _wage.level
	# The gold bar fills with the clicks banked toward the next level-up.
	_apply_wage_fill(_level_progress())


## Set the wage meter to `target` (0–1) directly — no easing. Each tap advances
## the bar the instant it happens, in lockstep with that tap's brightness flash,
## so the fill and the flash share one cadence (Tim's call: they must be 1:1).
func _apply_wage_fill(target: float) -> void:
	_wage_meter.value = clampf(target, 0.0, 1.0)


## Fraction of the way to the next level — the bright-gold fill level. Driven by the clicks
## banked toward the next level-up (which resets at each level-up and starts at 0 for each new
## heir), so the meter shows current-level progress, not the dynasty's lifetime tap count.
func _level_progress() -> float:
	var span := _wage.clicks_required_for_next_level()
	if span <= 0:
		return 0.0
	return clampf(float(_wage.taps_into_level) / float(span), 0.0, 1.0)


## The silver plate behind the level number. A cool metallic gray fill with the project's usual
## navy border and rounded corners, so it reads as a small "level badge" beside the gold meter.
## (No silver lives in UiPalette, so the shade is defined here.)
## The level badge plate: a dark-blue (INK_NAVY) fill with the SAME navy frame thickness as
## the clock-in meter beside it (style_framed_progress uses 8), so the two read as a matched
## pair on the row (Tim, 2026-06-28).
func _make_level_plate() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.INK_NAVY
	style.set_corner_radius_all(10)
	style.border_color = UiPalette.NAVY
	style.set_border_width_all(8)
	style.set_content_margin_all(8)
	return style


## Blink the level badge brighter twice, slowly, to announce a level-up (Tim, 2026-06-28).
## Pulses the panel's modulate up to LEVEL_BLINK_BRIGHTNESS and back, twice. modulate multiplies
## the plate and its text together, so the dark-blue ground and the blue number brighten as one.
func _blink_level_up() -> void:
	if _level_blink_tween != null and _level_blink_tween.is_valid():
		_level_blink_tween.kill()
	_level_panel.modulate = Color.WHITE
	var bright := Color(LEVEL_BLINK_BRIGHTNESS, LEVEL_BLINK_BRIGHTNESS, LEVEL_BLINK_BRIGHTNESS)
	_level_blink_tween = create_tween()
	_level_blink_tween.set_trans(Tween.TRANS_SINE)
	for _i in range(2):
		_level_blink_tween.tween_property(_level_panel, "modulate", bright, LEVEL_BLINK_HALF)
		_level_blink_tween.tween_property(_level_panel, "modulate", Color.WHITE, LEVEL_BLINK_HALF)


## Holding the clock-in button auto-taps the wage at the configured rate — a
## convenience the player can later speed up via Legacy upgrades. Gated behind an
## accumulator so a quick tap accrues no pulse and stays a single manual tap (that
## one still fires on release via the button's pressed signal). Auto-taps go out
## as wage_hold_tapped so GameState can charge frenzy at the reduced hold factor.
func _pump_auto_tap(delta: float) -> void:
	if not _wage_button.button_pressed:
		_hold_accumulator = 0.0
		return
	# The Legacy auto-click SPEED upgrade scales the held auto-tap rate.
	var rate := _tuning.wage_hold_taps_per_second * _wage.auto_tap_speed_multiplier
	if rate <= 0.0:
		return
	_hold_accumulator += delta
	var pulse_interval := 1.0 / rate
	while _hold_accumulator >= pulse_interval:
		_hold_accumulator -= pulse_interval
		wage_hold_tapped.emit()
		# No per-tap blink here: the gliding highlight (see _update_plate_glow) is
		# the held-state cue. But each held pulse still earns income, so it gets the
		# same floating "+income" indicator a manual tap does — including the auto-click
		# POWER bonus, which only held taps receive.
		_spawn_income_float(_current_tap_income() * _wage.auto_tap_power_multiplier)


## Arm a single brief manual-tap blink. The color itself is applied on the plate by
## _update_plate_glow (the held glide is drawn separately by _draw_sweep).
func _pulse_impact() -> void:
	_flash_remaining = FLASH_DURATION


## Each frame: drive the manual-tap blink on the plate, and advance/fade the held
## highlight band that _draw_sweep paints.
func _update_plate_glow(delta: float) -> void:
	# Manual-tap blink: a discrete on/off plate lighten for FLASH_DURATION, no ramp.
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	var blink_amount := FLASH_LIGHTEN if _flash_remaining > 0.0 else 0.0
	_fill_style.bg_color = _fill_base.lightened(blink_amount)
	_track_style.bg_color = _track_base.lightened(blink_amount)

	# Held highlight: advance its glide phase only while held, and ease its fade
	# envelope toward shown/hidden so it ramps in on press and out on release.
	if _wage_button.button_pressed:
		_pulse_phase += delta
	var target := 1.0 if _wage_button.button_pressed else 0.0
	var ramp := 1.0 - exp(-delta / PULSE_RAMP_TAU)
	_pulse_level += (target - _pulse_level) * ramp
	_sweep_overlay.queue_redraw()


## Paint the gliding highlight band onto the overlay. The band's center sweeps
## smoothly left → right → left over one PULSE_PERIOD, and its opacity feathers
## from SWEEP_PEAK_ALPHA at the center to 0 at its edges so it reads as a soft
## moving light rather than a hard bar. Nothing is drawn while the envelope is ~0.
func _draw_sweep() -> void:
	if _pulse_level <= 0.01:
		return
	var rect := _sweep_overlay.size
	# Stay inside the navy frame on all sides.
	var x_min := SWEEP_FRAME_INSET
	var x_full := rect.x - SWEEP_FRAME_INSET
	var top := SWEEP_FRAME_INSET
	var height := rect.y - SWEEP_FRAME_INSET * 2.0
	# Confine the sweep to the gold-FILLED portion only — its right limit is the edge
	# of the current fill, so the highlight never glides over the dark unfilled track.
	# When the meter is empty there is no gold to light, so nothing is drawn.
	var x_max := x_min + (x_full - x_min) * clampf(_wage_meter.value, 0.0, 1.0)
	if x_max <= x_min or height <= 0.0:
		return

	# Band width scales with the gold-filled width, so it starts small and grows as
	# progress fills the bar (x_max is the fill edge, x_min the left inset).
	var band_width := (x_max - x_min) * SWEEP_WIDTH_FRACTION
	# One-directional shimmer (Tim 2026-06-17): travel is a 0→1 sawtooth, so the band's
	# center moves left → right only and then jumps back to the left to repeat. Its
	# opacity fades to 0 over the final stretch (see fade), so it vanishes before the
	# fill edge instead of the old back-and-forth glide that reversed at the end.
	var travel := fmod(_pulse_phase / PULSE_PERIOD, 1.0)
	var center_x := x_min + travel * (x_max - x_min)
	var fade := 1.0
	if travel > SWEEP_FADE_START:
		fade = clampf(1.0 - (travel - SWEEP_FADE_START) / (1.0 - SWEEP_FADE_START), 0.0, 1.0)
	var highlight := _fill_base.lightened(FLASH_LIGHTEN)

	# Draw the band as feathered vertical slices: alpha peaks at the band's center
	# and tapers to 0 at its edges, scaled by the fade envelope.
	var slices := 16
	var slice_w := band_width / float(slices)
	for i in range(slices):
		var t := (float(i) + 0.5) / float(slices)  # 0..1 across the band
		var feather := 0.5 - 0.5 * cos(t * TAU)    # 0 at edges, 1 at the center
		highlight.a = feather * SWEEP_PEAK_ALPHA * _pulse_level * fade
		var x := center_x - band_width * 0.5 + i * slice_w
		# Clip each slice to the inset frame so nothing spills onto the border.
		var x_left := clampf(x, x_min, x_max)
		var x_right := clampf(x + slice_w + 1.0, x_min, x_max)
		if x_right > x_left:
			_sweep_overlay.draw_rect(Rect2(x_left, top, x_right - x_left, height), highlight)


## The dollars one wage tap earns right now — the same figure WageState.tap_wage
## pays (base wage × frenzy × the Old-Money Connections wage multiplier), floored.
## Used to label the floating "+income" indicators.
func _current_tap_income() -> float:
	return floorf(_wage.current_wage_per_tap() * _frenzy.get_multiplier() * _wage.wage_multiplier)


## Spawn a small black "+income" label that rises from a slightly random spot and
## drifts toward the right end of the button while fading out, then frees itself —
## a per-tap progress flourish that fires on manual taps and held auto-taps alike.
func _spawn_income_float(amount: float) -> void:
	if amount <= 0.0:
		return
	var meter_size := _wage_meter.size
	if meter_size.x <= 0.0 or meter_size.y <= 0.0:
		return

	var label := Label.new()
	label.text = "+%s" % Money.of(amount).display()
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", INCOME_FLOAT_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wage_meter.add_child(label)

	# Origin: the button's vertical center, INCOME_FLOAT_RIGHT_FRACTION of the width
	# in from the right edge, with a few px of random spread on x. The label is
	# centered on that point (its `position` is the top-left corner).
	var text_size := ThemeDB.fallback_font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, INCOME_FLOAT_FONT_SIZE
	)
	var origin_x := meter_size.x * (1.0 - INCOME_FLOAT_RIGHT_FRACTION) \
		+ randf_range(-INCOME_FLOAT_ORIGIN_JITTER, INCOME_FLOAT_ORIGIN_JITTER)
	var origin := Vector2(origin_x - text_size.x * 0.5, meter_size.y * 0.5 - text_size.y * 0.5)
	label.position = origin

	# Drive rise + gentle side-to-side sway + fade per frame from a 0→1 tween, then
	# free the label (a sine sway can't be expressed as a plain property tween).
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void: _animate_income_float(label, origin, t),
		0.0, 1.0, INCOME_FLOAT_DURATION
	)
	tween.finished.connect(label.queue_free)


## Per-frame placement for a rising "+income" float; `t` runs 0→1 over its life.
## It floats straight up by INCOME_FLOAT_RISE_FRACTION of the button height while
## swaying gently side to side (a low-amplitude sine) and fading to transparent.
func _animate_income_float(label: Label, origin: Vector2, t: float) -> void:
	var rise := _wage_meter.size.y * INCOME_FLOAT_RISE_FRACTION
	var sway := sin(t * TAU * INCOME_FLOAT_WAVES) * INCOME_FLOAT_SWAY
	label.position = Vector2(origin.x + sway, origin.y - rise * t)
	label.modulate.a = 1.0 - t
