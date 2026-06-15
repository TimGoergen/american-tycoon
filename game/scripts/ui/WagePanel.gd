class_name WagePanel
extends VBoxContainer

# The wage button (Layer 1, GDD §5) — the only honest money in the game, and it
# is never removed from the screen.
#
# The "clock in" button doubles as a promotion-progress meter (UI notes §2): a
# dark-gold plate whose bright-gold bar fills toward the next title. A
# ProgressBar draws that fill; a transparent Button sits on top to catch taps and
# show the big (2×-size) CLOCK IN label. A compact context line below keeps the
# title/next-title detail without crowding the big button. When the tap threshold
# is met, the claim button appears.

signal wage_tapped
signal wage_hold_tapped
signal promotion_requested

var _wage: WageState
var _economy: EconomyState
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
#     glides smoothly side to side across the meter the whole time it is held,
#     signalling "this is active" with motion rather than any blinking. The band
#     is drawn by a transparent overlay above the gold fill (see _draw_sweep), so
#     the navy border and the label stay put and the button never changes size.

## How long the brighter-gold blink stays on for a single manual tap, in seconds.
## Short, so a deliberate tap reads as a crisp blink.
const FLASH_DURATION := 0.05

## How far the gold is lightened toward white at the peak of a tap blink and at the
## core of the gliding highlight band (0 = none, 1 = pure white). High, so the
## held sweep reads as a bright, intense band of light.
const FLASH_LIGHTEN := 0.45

## Seconds for one full left→right→left glide of the held highlight band. Slow on
## purpose, so the held state reads as a calm sweep rather than a flicker.
const PULSE_PERIOD := 2.0

## How quickly the held highlight fades in when pressed and out when released, as a
## smoothing time constant in seconds — responsive, but easing out instead of
## snapping off.
const PULSE_RAMP_TAU := 0.18

## Width of the gliding highlight band as a fraction of the meter's width.
const SWEEP_WIDTH_FRACTION := 0.4

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
const INCOME_FLOAT_FONT_SIZE := 40
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
var _context_label: Label
var _promotion_button: Button

## Transparent overlay above the gold fill (below the label button) on which the
## gliding highlight band is drawn while the button is held.
var _sweep_overlay: Control


## Call before adding to the tree.
func setup(wage: WageState, economy: EconomyState, tuning: TuningConfig, frenzy: FrenzyState) -> void:
	_wage = wage
	_economy = economy
	_tuning = tuning
	_frenzy = frenzy


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	# The meter is the button background; its bright-gold fill shows promotion
	# progress. It ignores the mouse so the Button on top handles every tap.
	_wage_meter = ProgressBar.new()
	_wage_meter.custom_minimum_size = Vector2(0, 170)  # tall: the primary tap target
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
	add_child(_wage_meter)

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
	_wage_button.add_theme_font_size_override("font_size", 56)
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

	# Compact context line (not enlarged): which title you hold and what's next.
	_context_label = Label.new()
	_context_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_context_label.add_theme_font_size_override("font_size", 20)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_context_label)

	_promotion_button = Button.new()
	_promotion_button.add_theme_font_size_override("font_size", 22)
	UiPalette.style_button(_promotion_button, true)  # tuition is a spend action
	_promotion_button.pressed.connect(func() -> void: promotion_requested.emit())
	add_child(_promotion_button)


func _process(delta: float) -> void:
	_pump_auto_tap(delta)
	_update_plate_glow(delta)

	# The wage is paid wage_per_tap × frenzy multiplier at point of payment
	# (Spec §7), so reflect the boosted per-tap value during a burn (1.0 otherwise).
	var title := _wage.get_current_title()
	var wage_per_tap := title.wage_per_tap * _frenzy.get_multiplier()
	_wage_button.text = "CLOCK IN\n%s / tap" % Money.of(wage_per_tap).display()

	var next := _wage.get_next_title()
	if next == null:
		# Top of the placeholder ladder (the full title table arrives in M2).
		_apply_wage_fill(1.0)
		_context_label.text = "%s — top of the ladder (for now)" % title.title_name
		_promotion_button.visible = false
		return

	if _wage.is_promotion_unlocked():
		# Threshold met — the claim is now just a purchase (the credential gag).
		_apply_wage_fill(1.0)
		_context_label.text = "%s — promotion earned, claim it below" % title.title_name
		_promotion_button.visible = true
		_promotion_button.text = "CLAIM PROMOTION: %s — tuition %s" % [
			next.title_name, Money.of(next.tuition).display()
		]
		_promotion_button.disabled = _economy.cash < next.tuition
	else:
		_apply_wage_fill(_promotion_progress(title, next))
		# Show taps earned within THIS title, not the dynastic lifetime total, so the
		# number matches the meter (and an heir starts each rung at 0 / span).
		_context_label.text = "%s → %s: %d / %d taps + %s tuition" % [
			title.title_name, next.title_name,
			_wage.taps_in_current_title(), _wage.taps_required_for_promotion(),
			Money.of(next.tuition).display()
		]
		_promotion_button.visible = false


## Set the wage meter to `target` (0–1) directly — no easing. Each tap advances
## the bar the instant it happens, in lockstep with that tap's brightness flash,
## so the fill and the flash share one cadence (Tim's call: they must be 1:1).
func _apply_wage_fill(target: float) -> void:
	_wage_meter.value = clampf(target, 0.0, 1.0)


## Fraction of the way through the current rung — the bright-gold fill level. Driven
## by taps earned WITHIN the current title (which resets to 0 on each promotion and
## for each new heir), so the meter shows current-title progress rather than the
## dynasty's ever-growing lifetime tap count.
func _promotion_progress(_title: TitleRow, _next: TitleRow) -> float:
	var span := _wage.taps_required_for_promotion()
	if span <= 0:
		return 0.0
	return clampf(float(_wage.taps_in_current_title()) / float(span), 0.0, 1.0)


## Holding the clock-in button auto-taps the wage at the configured rate — a
## convenience the player can later speed up via Legacy upgrades. Gated behind an
## accumulator so a quick tap accrues no pulse and stays a single manual tap (that
## one still fires on release via the button's pressed signal). Auto-taps go out
## as wage_hold_tapped so GameState can charge frenzy at the reduced hold factor.
func _pump_auto_tap(delta: float) -> void:
	if not _wage_button.button_pressed:
		_hold_accumulator = 0.0
		return
	var rate := _tuning.wage_hold_taps_per_second
	if rate <= 0.0:
		return
	_hold_accumulator += delta
	var pulse_interval := 1.0 / rate
	while _hold_accumulator >= pulse_interval:
		_hold_accumulator -= pulse_interval
		wage_hold_tapped.emit()
		# No per-tap blink here: the gliding highlight (see _update_plate_glow) is
		# the held-state cue. But each held pulse still earns income, so it gets the
		# same floating "+income" indicator a manual tap does.
		_spawn_income_float(_current_tap_income())


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

	# Sweep the band's center across the inset width: 0.5 − 0.5·cos gives 0→1→0.
	var travel := 0.5 - 0.5 * cos(TAU * _pulse_phase / PULSE_PERIOD)
	var center_x := x_min + travel * (x_max - x_min)
	var band_width := rect.x * SWEEP_WIDTH_FRACTION
	var highlight := _fill_base.lightened(FLASH_LIGHTEN)

	# Draw the band as feathered vertical slices: alpha peaks at the band's center
	# and tapers to 0 at its edges, scaled by the fade envelope.
	var slices := 16
	var slice_w := band_width / float(slices)
	for i in range(slices):
		var t := (float(i) + 0.5) / float(slices)  # 0..1 across the band
		var feather := 0.5 - 0.5 * cos(t * TAU)    # 0 at edges, 1 at the center
		highlight.a = feather * SWEEP_PEAK_ALPHA * _pulse_level
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
	var title := _wage.get_current_title()
	return floorf(title.wage_per_tap * _frenzy.get_multiplier() * _wage.wage_multiplier)


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
