class_name CatchMoneyMinigame
extends Minigame

# "Catch the Money" minigame TYPE (GDD §5.5) — a reaction game. Coins fall from the top;
# tap one to catch it. Performance = net score / TARGET_COINS, where a catch is +1 and a coin
# that falls past the bottom is -0.5 (so misses actively cost you). Ends when all TARGET_COINS
# have dropped.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

## Coins that make a full game (also the performance denominator).
const TARGET_COINS := 18
## Seconds between coin spawns, and how fast a coin falls (px/sec in the 1080-wide space).
const SPAWN_INTERVAL := 0.55
const FALL_SPEED := 340.0
const COIN_SIZE := 96
## Coins start half-again as big as the base size, then shrink as the player catches them.
const START_COIN_SIZE := COIN_SIZE * 1.5
## Each catch makes every future coin this fraction of the last one's size (5% smaller).
const SHRINK_FACTOR := 0.95
## Floor on the spawn size so coins never become untappably tiny for low-vision players (§1b).
const MIN_COIN_SIZE := COIN_SIZE * 0.5
## A coin that falls past the bottom costs this fraction of a catch (Tim: "half as many points").
const MISS_PENALTY := 0.5

var _caught: int = 0
var _missed: int = 0
var _spawned: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _coins: Array = []  # live coin Buttons
## Current spawn size: starts large and shrinks 5% per catch (compounding). Coins already
## in flight keep the size they spawned at; only this next-spawn value changes.
var _spawn_size: float = START_COIN_SIZE
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
	# Net score = catches minus half a point per coin that slipped past the bottom.
	var net := float(_caught) - MISS_PENALTY * float(_missed)
	return clampf(net / float(TARGET_COINS), 0.0, 1.0)


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

	# Fall; a coin past the bottom is a miss — it costs points (see get_performance) and is freed.
	for coin in _coins.duplicate():
		coin.position.y += FALL_SPEED * delta
		if coin.position.y > area_size.y:
			_missed += 1
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
	coin.custom_minimum_size = Vector2(_spawn_size, _spawn_size)
	coin.size = Vector2(_spawn_size, _spawn_size)
	# Scale the glyph with the coin so the "$" keeps filling it as the coin shrinks.
	coin.add_theme_font_size_override("font_size", int(UiPalette.FONT_HEADLINE * _spawn_size / COIN_SIZE))
	UiPalette.style_button(coin, false)  # mustard coin
	var max_x: float = maxf(0.0, area_width - _spawn_size)
	coin.position = Vector2(_rng.randf_range(0.0, max_x), -_spawn_size)
	coin.pressed.connect(_on_coin_caught.bind(coin))
	_area.add_child(coin)
	_coins.append(coin)


func _on_coin_caught(coin: Button) -> void:
	if not _running or not _coins.has(coin):
		return
	_caught += 1
	# Every catch makes the NEXT spawn 5% smaller (compounding), down to the readable floor.
	_spawn_size = maxf(MIN_COIN_SIZE, _spawn_size * SHRINK_FACTOR)
	_coins.erase(coin)
	coin.queue_free()
