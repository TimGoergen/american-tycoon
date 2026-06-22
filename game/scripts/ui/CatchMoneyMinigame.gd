class_name CatchMoneyMinigame
extends Minigame

# "Catch the Money" minigame TYPE (GDD §5.5) — a reaction game. Coins fall from the top;
# tap one to catch it. Performance = coins caught / TARGET_COINS (missed coins fall past),
# so you must keep catching. Ends when all TARGET_COINS have dropped.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

## Coins that make a full game (also the performance denominator).
const TARGET_COINS := 18
## Seconds between coin spawns, and how fast a coin falls (px/sec in the 1080-wide space).
const SPAWN_INTERVAL := 0.55
const FALL_SPEED := 340.0
const COIN_SIZE := 96

var _caught: int = 0
var _spawned: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _coins: Array = []  # live coin Buttons
var _rng := RandomNumberGenerator.new()
var _area: Control


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
	return clampf(float(_caught) / float(TARGET_COINS), 0.0, 1.0)


func _process(delta: float) -> void:
	if not _running or _area == null:
		return
	var area_size := _area.size
	if area_size.x <= 0.0:
		return

	# Spawn until we've dropped the whole batch.
	if _spawned < TARGET_COINS:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn_coin(area_size.x)

	# Fall; a coin past the bottom is a miss (freed, but it still counted as spawned).
	for coin in _coins.duplicate():
		coin.position.y += FALL_SPEED * delta
		if coin.position.y > area_size.y:
			_coins.erase(coin)
			coin.queue_free()

	# All spawned and none left on screen -> the round is over.
	if _spawned >= TARGET_COINS and _coins.is_empty():
		_running = false
		completed.emit(get_performance())


func _spawn_coin(area_width: float) -> void:
	_spawned += 1
	var coin := Button.new()
	coin.text = "$"
	coin.custom_minimum_size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	UiPalette.style_button(coin, false)  # mustard coin
	var max_x: float = maxf(0.0, area_width - COIN_SIZE)
	coin.position = Vector2(_rng.randf_range(0.0, max_x), -COIN_SIZE)
	coin.pressed.connect(_on_coin_caught.bind(coin))
	_area.add_child(coin)
	_coins.append(coin)


func _on_coin_caught(coin: Button) -> void:
	if not _running or not _coins.has(coin):
		return
	_caught += 1
	_coins.erase(coin)
	coin.queue_free()
