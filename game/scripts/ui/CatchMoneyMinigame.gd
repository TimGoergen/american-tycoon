class_name CatchMoneyMinigame
extends Minigame

# "Catch the Money" minigame TYPE (GDD §5.5) — a reaction game. Coins fall from the top;
# tap one to catch it. Performance = net score / TARGET_COINS, where a catch is +1 and a coin
# that falls past the bottom is -MISS_PENALTY (so misses actively cost you). Ends when all
# TARGET_COINS have dropped.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.
#
# Polish pass (2026-06-29): this was the least-juiced game — bare "$" buttons, no catch or miss
# feedback at all. It now reads clearly (round coins with a navy rim and a living glint, a spawn
# pop) and reacts to play (a green "+1" pop and white bloom on a catch; a red puff plus a bottom
# edge flash on a miss). It also escalates: the spawn interval ramps toward a late-round rush.

## Coins that make a full game (also the performance denominator).
const TARGET_COINS := 18
## Seconds between coin spawns: starts at SPAWN_INTERVAL_START and ramps DOWN toward
## SPAWN_INTERVAL_END across the batch, so the round builds to a late "rush" instead of staying
## flat (plan §2.3, "Harder"). Both values are first-pass and UN-PLAYTESTED — confirm on-device.
const SPAWN_INTERVAL_START := 0.55
const SPAWN_INTERVAL_END := 0.38
## How fast a coin falls (px/sec in the 1080-wide space).
const FALL_SPEED := 340.0
const COIN_SIZE := 96
## Coins start half-again as big as the base size, then shrink as the player catches them.
const START_COIN_SIZE := COIN_SIZE * 1.5
## Each catch makes every future coin this fraction of the last one's size (5% smaller).
const SHRINK_FACTOR := 0.95
## Floor on the spawn size so coins never become untappably tiny for low-vision players (§1b).
const MIN_COIN_SIZE := COIN_SIZE * 0.5
## A coin that falls past the bottom costs this fraction of a catch. Bumped 0.5 -> 0.75 in the
## polish pass to make the round less lenient (plan §2.3, "Harder"). First-pass and UN-PLAYTESTED.
const MISS_PENALTY := 0.75

## Idle-glint pulse: how fast the highlight on every live coin breathes, and how much of its
## alpha swings, so coins look minted and shiny rather than flat. Driven from _process by an
## accumulated phase (not per-coin tweens) so nothing leaks as coins come and go.
const GLINT_PULSE_SPEED := 4.0
const GLINT_PULSE_AMOUNT := 0.25

var _caught: int = 0
var _missed: int = 0
var _spawned: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _coins: Array = []  # live coin Buttons
## Current spawn size: starts large and shrinks 5% per catch (compounding). Coins already
## in flight keep the size they spawned at; only this next-spawn value changes.
var _spawn_size: float = START_COIN_SIZE
## Accumulated time driving the shared coin-glint pulse (see GLINT_PULSE_SPEED).
var _shine_phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _area: Control


func display_name() -> String:
	return "Catch the Money"


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true

	var intro := Label.new()
	intro.text = "Tap the falling money to catch it!"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	_area = Control.new()
	_area.clip_contents = true
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(_area)
	add_child(column)


func get_performance() -> float:
	# Net score = catches minus the miss penalty per coin that slipped past the bottom.
	var net := float(_caught) - MISS_PENALTY * float(_missed)
	return clampf(net / float(TARGET_COINS), 0.0, 1.0)


func result_summary() -> String:
	return "Caught %d of %d" % [_caught, TARGET_COINS]


## Seconds to wait before the next spawn, ramping from START down to END as the batch empties so
## the round speeds up toward the end (the late-round "rush").
func _current_spawn_interval() -> float:
	var progress := float(_spawned) / float(TARGET_COINS)
	return lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, clampf(progress, 0.0, 1.0))


func _process(delta: float) -> void:
	if not _running or _area == null:
		return
	var area_size := _area.size
	if area_size.x <= 0.0:
		return

	# Drive the living glint on every coin from one shared phase (no per-coin tweens to leak).
	_shine_phase += delta
	var glint_alpha := 0.55 + GLINT_PULSE_AMOUNT * sin(_shine_phase * GLINT_PULSE_SPEED)
	for coin in _coins:
		var glint: Panel = coin.get_meta("glint")
		if is_instance_valid(glint):
			glint.modulate.a = glint_alpha

	# Spawn until we've dropped the whole batch, at the current (ramping) interval.
	if _spawned < TARGET_COINS:
		_spawn_timer += delta
		if _spawn_timer >= _current_spawn_interval():
			_spawn_timer = 0.0
			_spawn_coin(area_size.x)

	# Fall; a coin past the bottom is a miss — it costs points (see get_performance), shows the
	# miss cue, and is freed.
	for coin in _coins.duplicate():
		coin.position.y += FALL_SPEED * delta
		if coin.position.y > area_size.y:
			_missed += 1
			var drop_center := Vector2(coin.position.x + coin.size.x / 2.0, area_size.y)
			_coins.erase(coin)
			coin.queue_free()
			_spawn_miss_effect(drop_center)

	# All spawned and none left on screen -> the round is over.
	if _spawned >= TARGET_COINS and _coins.is_empty():
		_running = false
		completed.emit(get_performance())


## The round coin: a mustard disc with a thick navy rim (so it reads against the cream card) and a
## white glint in the upper-left (so it looks like a shiny coin, not a flat button).
func _spawn_coin(area_width: float) -> void:
	_spawned += 1
	var coin := Button.new()
	coin.text = "$"
	coin.custom_minimum_size = Vector2(_spawn_size, _spawn_size)
	coin.size = Vector2(_spawn_size, _spawn_size)
	# Scale the glyph with the coin so the "$" keeps filling it as the coin shrinks.
	coin.add_theme_font_size_override("font_size", int(UiPalette.FONT_HEADLINE * _spawn_size / COIN_SIZE))
	_style_coin(coin, _spawn_size)

	# A small white highlight, ignored by the mouse so it never eats a tap. _process pulses its
	# alpha for the living-glint shine.
	var glint := Panel.new()
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.size = Vector2(_spawn_size * 0.30, _spawn_size * 0.22)
	glint.position = Vector2(_spawn_size * 0.22, _spawn_size * 0.18)
	var glint_style := StyleBoxFlat.new()
	glint_style.bg_color = Color(1, 1, 1, 0.7)
	glint_style.set_corner_radius_all(int(_spawn_size * 0.22))  # round the highlight into an oval
	glint.add_theme_stylebox_override("panel", glint_style)
	coin.add_child(glint)
	coin.set_meta("glint", glint)

	var max_x: float = maxf(0.0, area_width - _spawn_size)
	coin.position = Vector2(_rng.randf_range(0.0, max_x), -_spawn_size)
	coin.pressed.connect(_on_coin_caught.bind(coin))
	_area.add_child(coin)
	_coins.append(coin)

	# Spawn entrance: pop the coin up from small as it enters, so a new coin announces itself.
	coin.pivot_offset = Vector2(_spawn_size / 2.0, _spawn_size / 2.0)
	coin.scale = Vector2(0.3, 0.3)
	var entrance := create_tween()
	entrance.tween_property(coin, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A coin's look in every interaction state (catches free the coin instantly, so the pressed look
## barely shows — but keeping all states identical means a tap never flips it to a button skin).
func _style_coin(coin: Button, size: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.MUSTARD_GOLD
	style.border_color = UiPalette.INK_NAVY
	style.set_border_width_all(int(maxf(4.0, size * 0.07)))
	style.set_corner_radius_all(int(size / 2.0))  # full radius = a round coin
	for state in ["normal", "hover", "pressed", "focus"]:
		coin.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		coin.add_theme_color_override(state, UiPalette.NAVY)


func _on_coin_caught(coin: Button) -> void:
	if not _running or not _coins.has(coin):
		return
	_caught += 1
	# Every catch makes the NEXT spawn 5% smaller (compounding), down to the readable floor.
	_spawn_size = maxf(MIN_COIN_SIZE, _spawn_size * SHRINK_FACTOR)
	var center := coin.position + coin.size / 2.0
	_coins.erase(coin)
	coin.queue_free()
	_spawn_catch_effect(center, coin.size.x)


## Catch reward: a white bloom that swells and fades where the coin was, plus a green "+1" that
## floats up — the host's juice vocabulary (white-flash + pop) applied to a catch.
func _spawn_catch_effect(center: Vector2, coin_size: float) -> void:
	var bloom := Panel.new()
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloom.size = Vector2(coin_size, coin_size)
	bloom.position = center - bloom.size / 2.0
	bloom.pivot_offset = bloom.size / 2.0
	var bloom_style := StyleBoxFlat.new()
	bloom_style.bg_color = Color(1, 1, 1, 0.7)
	bloom_style.set_corner_radius_all(int(coin_size / 2.0))
	bloom.add_theme_stylebox_override("panel", bloom_style)
	_area.add_child(bloom)
	var bloom_tween := create_tween()
	bloom_tween.set_parallel(true)
	bloom_tween.tween_property(bloom, "scale", Vector2(1.8, 1.8), 0.3)
	bloom_tween.tween_property(bloom, "modulate:a", 0.0, 0.3)
	bloom_tween.chain().tween_callback(bloom.queue_free)

	var pop := Label.new()
	pop.text = "+1"
	pop.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	pop.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	pop.add_theme_font_override("font", UiPalette.make_bold_font())
	pop.position = Vector2(center.x, center.y - coin_size * 0.4)
	_area.add_child(pop)
	var pop_tween := create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(pop, "position:y", pop.position.y - 70.0, 0.5)
	pop_tween.tween_property(pop, "modulate:a", 0.0, 0.5)
	pop_tween.chain().tween_callback(pop.queue_free)


## Miss cue: a red puff where the coin slipped off the bottom, plus a brief red flash along the
## bottom edge, so a dropped coin reads clearly as a loss (it was previously silent).
func _spawn_miss_effect(drop_center: Vector2) -> void:
	var puff := Panel.new()
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.size = Vector2(COIN_SIZE, COIN_SIZE)
	puff.position = drop_center - Vector2(puff.size.x / 2.0, puff.size.y)
	puff.pivot_offset = puff.size / 2.0
	var puff_style := StyleBoxFlat.new()
	puff_style.bg_color = Color(UiPalette.KETCHUP_RED, 0.6)
	puff_style.set_corner_radius_all(int(COIN_SIZE / 2.0))
	puff.add_theme_stylebox_override("panel", puff_style)
	_area.add_child(puff)
	var puff_tween := create_tween()
	puff_tween.set_parallel(true)
	puff_tween.tween_property(puff, "scale", Vector2(1.7, 1.7), 0.35)
	puff_tween.tween_property(puff, "modulate:a", 0.0, 0.35)
	puff_tween.chain().tween_callback(puff.queue_free)

	# A thin red bar flashing along the bottom edge makes the "it got past you" line unmistakable.
	var edge := ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.color = UiPalette.KETCHUP_RED
	edge.size = Vector2(_area.size.x, 8.0)
	edge.position = Vector2(0.0, _area.size.y - 8.0)
	_area.add_child(edge)
	var edge_tween := create_tween()
	edge_tween.tween_property(edge, "modulate:a", 0.0, 0.35)
	edge_tween.tween_callback(edge.queue_free)
