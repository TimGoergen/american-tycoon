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

# Click impact: every wage tap (manual click OR auto-tap pulse while held) flashes
# the button between two discrete colors — the gold plate snaps to a brighter gold
# for a brief fixed moment, then snaps straight back. There is no easing or decay
# ramp: the plate is only ever the base gold or the brighter gold, never a shade
# between (Tim's call — a smooth decay read as a pulse). The button never changes
# size. The flash lightens the gold toward white — a brighter shade of the SAME
# gold, not a tint toward a different yellow — and touches only the gold plate, so
# the navy border and label stay put. Held down, it re-arms at the auto-tap
# cadence, i.e. once per income tick.

## How long the brighter-gold flash stays on per tap, in seconds. Short, so it
## reads as a crisp blink rather than a pulse.
const FLASH_DURATION := 0.05

## How far the gold is lightened toward white during a flash (0 = none, 1 = pure
## white). Applied as a single discrete shade, never ramped. Kept subtle — a much
## brighter flash read as a strobe (Tim's call: about a quarter of the old 0.45).
const FLASH_LIGHTEN := 0.11

## Seconds left in the current flash. >0 means show the brighter gold; 0 means show
## the base gold. Counted down in _apply_impact.
var _flash_remaining := 0.0

# The meter's two gold plates — captured so the flash can lighten them in place and
# restore them. Their unflashed colors are remembered in *_base.
var _fill_style: StyleBoxFlat
var _track_style: StyleBoxFlat
var _fill_base: Color
var _track_base: Color

var _wage_meter: ProgressBar
var _wage_button: Button
var _context_label: Label
var _promotion_button: Button


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
		_pulse_impact())
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
	_apply_impact(delta)

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
		_context_label.text = "%s → %s: %d / %d taps + %s tuition" % [
			title.title_name, next.title_name,
			_wage.lifetime_taps, next.tap_threshold,
			Money.of(next.tuition).display()
		]
		_promotion_button.visible = false


## Set the wage meter to `target` (0–1) directly — no easing. Each tap advances
## the bar the instant it happens, in lockstep with that tap's brightness flash,
## so the fill and the flash share one cadence (Tim's call: they must be 1:1).
func _apply_wage_fill(target: float) -> void:
	_wage_meter.value = clampf(target, 0.0, 1.0)


## Fraction of the way from the current title's tap threshold to the next title's
## — the bright-gold fill level. lifetime_taps is dynastic and only grows, so this
## climbs from 0 to 1 across the current rung.
func _promotion_progress(title: TitleRow, next: TitleRow) -> float:
	var span := next.tap_threshold - title.tap_threshold
	if span <= 0:
		return 0.0
	return clampf(float(_wage.lifetime_taps - title.tap_threshold) / float(span), 0.0, 1.0)


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
		_pulse_impact()  # same visual cue as a manual click, once per income tick


## Start a flash: snap the gold to its brighter shade now and arm the countdown
## that _apply_impact uses to snap it back. Re-arming on every tap keeps held-down
## auto-taps blinking at the income cadence.
func _pulse_impact() -> void:
	_flash_remaining = FLASH_DURATION
	_set_flashed(true)


## Count the flash down and snap the gold back to rest the instant it expires.
## There is no interpolation — the plate is only ever the base gold or the brighter
## gold, never a shade between (Tim's call: no transition states).
func _apply_impact(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if _flash_remaining <= 0.0:
		_set_flashed(false)


## Swap both gold plates between their base color and the brighter flashed shade.
## Lightening the SAME gold toward white keeps its hue — a brighter shade, not a
## different yellow. No scale change (the button never resizes).
func _set_flashed(on: bool) -> void:
	if on:
		_fill_style.bg_color = _fill_base.lightened(FLASH_LIGHTEN)
		_track_style.bg_color = _track_base.lightened(FLASH_LIGHTEN)
	else:
		_fill_style.bg_color = _fill_base
		_track_style.bg_color = _track_base
