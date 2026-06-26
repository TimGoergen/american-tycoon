class_name BasketballMinigame
extends Minigame

# "Micro Basketball" minigame TYPE (GDD §5.5) — a quick swipe-to-shoot game. A hoop drifts
# around the play area while a few basketballs sit waiting to be thrown. The player presses a
# ball, swipes, and releases to fling it; the ball arcs under gravity and scores a basket if it
# passes through the moving hoop. Baskets only ever accumulate, so the host's spectrum bar
# climbs as the player sinks shots (matching the other types). It has no natural end — the
# host's countdown ends the round.
#
# Owns only its gameplay; the host owns the countdown / spectrum / result / multiplier.

## Baskets that map to performance 1.0. Tuned for a ~20s round: a skilled player can plausibly
## sink this many, while an average player lands mid-range. FEEL-TUNE: raise to make 1.0x
## harder to reach, lower to make it easier.
const TARGET_BASKETS := 7

## How many grabbable balls to keep on the board at once (plus any currently in flight).
const MAX_BALLS := 3

## Ball and hoop sizes in pixels — kept generous for thumb play and imperfect vision.
const BALL_RADIUS := 40.0          # 80px diameter
const HOOP_RADIUS := 60.0          # 120px diameter (the drawn image)
## How close a flying ball's center must get to the hoop center to count as a basket. A bit
## smaller than the hoop image so it reads as "through the rim", but forgiving for easy play.
const BASKET_CATCH_RADIUS := 46.0

## Downward acceleration on a thrown ball (px/sec^2) — gives the throw a visible arc.
const GRAVITY := 900.0
## Cap on throw speed (px/sec) so a frantic swipe can't fling a ball uselessly fast.
const MAX_THROW_SPEED := 2200.0
## A swipe slower than this (px/sec) on release just drops the ball back down — not a throw.
const MIN_THROW_SPEED := 250.0

## How the drifting hoop wanders: it eases toward a randomly re-rolled target point, like the
## balance minigame's gold zone, so it glides smoothly instead of snapping.
const HOOP_TARGET_CHANGE := 1.6    # seconds between new hoop-target re-rolls
const HOOP_EASE := 1.2             # how fast the hoop eases toward its target (per second)

# Each ball is a Dictionary: { "pos": Vector2, "vel": Vector2, "state": String }.
# state is one of "idle" (sitting, grabbable), "grabbed" (following the finger),
# or "flight" (thrown, moving under gravity).
var _balls: Array = []
var _baskets: int = 0
var _running: bool = false
var _rng := RandomNumberGenerator.new()

var _hoop_pos: Vector2 = Vector2.ZERO
var _hoop_target: Vector2 = Vector2.ZERO
var _hoop_timer: float = 0.0
var _hoop_flash: float = 0.0       # brief brighten of the hoop after a made basket, decays in _process

# The ball the player is currently dragging (an index into _balls, or -1 for none), plus the
# samples used to estimate swipe velocity at the moment of release.
var _grabbed_index: int = -1
var _drag_velocity: Vector2 = Vector2.ZERO
var _drag_last_pos: Vector2 = Vector2.ZERO
var _drag_last_usec: int = 0

var _play: Control

# Drawn each frame; preloaded so the textures are ready the instant play begins.
const BALL_TEX := preload("res://art/icons/basketball.svg")
const HOOP_TEX := preload("res://art/icons/basket_hoop.svg")


func display_name() -> String:
	return "Micro Basketball"


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	_baskets = 0
	# Round length is read (not hardcoded) so this type tracks whatever the host sets; only used
	# here for the comment math — performance is baskets/target, which the host samples live.
	var _round_seconds := maxf(0.1, tuning.minigame_duration_seconds)

	var intro := Label.new()
	intro.text = "Press a ball, swipe, and let go to shoot it through the hoop."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# A single full-size play Control holds the whole scene. Custom _draw (rather than moving
	# TextureRects) is the more readable choice here: every ball and the hoop are positioned by
	# plain math in one place, and the arcing flight + the hit test all read off the same Vector2
	# positions, so there's no node bookkeeping to keep in sync.
	_play = Control.new()
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play.draw.connect(_draw_play)
	_play.gui_input.connect(_on_play_input)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(_play)
	add_child(column)


func get_performance() -> float:
	# Fixed denominator (TARGET_BASKETS), so the meter rises monotonically as baskets are sunk
	# and never falls back — matching the other types' climbing spectrum.
	return clampf(float(_baskets) / float(TARGET_BASKETS), 0.0, 1.0)


func result_summary() -> String:
	return "Sank %d baskets" % _baskets


func _process(delta: float) -> void:
	if not _running or _play == null:
		return
	var bounds := _play.size
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		return

	_hoop_flash = maxf(0.0, _hoop_flash - delta * 3.0)
	_drift_hoop(delta, bounds)
	_advance_balls(delta, bounds)
	_refill_balls(bounds)
	_play.queue_redraw()


## Ease the hoop toward a randomly re-rolled target point, keeping the whole hoop on the board.
func _drift_hoop(delta: float, bounds: Vector2) -> void:
	if _hoop_target == Vector2.ZERO:
		_hoop_pos = Vector2(bounds.x * 0.5, bounds.y * 0.35)
		_hoop_target = _hoop_pos
	_hoop_timer -= delta
	if _hoop_timer <= 0.0:
		# Keep the hoop in the upper ~60% of the board so balls (which spawn low) have room to
		# arc up toward it, and so it never sits on top of the resting balls.
		_hoop_target = Vector2(
			_rng.randf_range(HOOP_RADIUS, bounds.x - HOOP_RADIUS),
			_rng.randf_range(HOOP_RADIUS, bounds.y * 0.6)
		)
		_hoop_timer = HOOP_TARGET_CHANGE
	_hoop_pos += (_hoop_target - _hoop_pos) * minf(1.0, HOOP_EASE * delta)


## Move every in-flight ball under gravity, score baskets, and drop balls that leave the board.
func _advance_balls(delta: float, bounds: Vector2) -> void:
	var survivors: Array = []
	for i in range(_balls.size()):
		var ball: Dictionary = _balls[i]
		if ball["state"] == "flight":
			ball["vel"].y += GRAVITY * delta
			ball["pos"] += ball["vel"] * delta
			# Basket: a forgiving center-distance check against the moving hoop.
			if ball["pos"].distance_to(_hoop_pos) <= BASKET_CATCH_RADIUS:
				_baskets += 1
				_hoop_flash = 1.0
				continue  # remove the scored ball (do not add to survivors)
			# Drop balls that have flown well off any edge; a margin keeps near-misses alive.
			var margin := BALL_RADIUS * 3.0
			if ball["pos"].x < -margin or ball["pos"].x > bounds.x + margin \
					or ball["pos"].y > bounds.y + margin:
				continue
		survivors.append(ball)
	_balls = survivors
	# The grabbed ball may have been re-indexed by the rebuild; re-find it by state so the drag
	# keeps tracking the right ball.
	_grabbed_index = -1
	for i in range(_balls.size()):
		if _balls[i]["state"] == "grabbed":
			_grabbed_index = i
			break


## Keep MAX_BALLS grabbable (idle or grabbed) balls on the board, spawning fresh ones low down.
func _refill_balls(bounds: Vector2) -> void:
	var grabbable := 0
	for ball in _balls:
		if ball["state"] != "flight":
			grabbable += 1
	while grabbable < MAX_BALLS:
		_balls.append({
			"pos": Vector2(
				_rng.randf_range(BALL_RADIUS, bounds.x - BALL_RADIUS),
				_rng.randf_range(bounds.y * 0.72, bounds.y - BALL_RADIUS)
			),
			"vel": Vector2.ZERO,
			"state": "idle",
		})
		grabbable += 1


func _on_play_input(event: InputEvent) -> void:
	if not _running:
		return
	# Touch is delivered here as emulated mouse events (Godot's default), so handling mouse
	# button + motion covers both finger and mouse without separate touch handling.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		else:
			_release_throw()
	elif event is InputEventMouseMotion and _grabbed_index != -1:
		_drag_to(event.position)


## On press, grab the nearest idle ball within a generous radius of the touch point.
func _try_grab(point: Vector2) -> void:
	var best_index := -1
	var best_distance := BALL_RADIUS * 1.4  # generous grab radius for thumb play
	for i in range(_balls.size()):
		if _balls[i]["state"] != "idle":
			continue
		# Explicit float type: a Dictionary lookup is untyped (Variant), so distance_to() can't be
		# inferred with := here.
		var distance: float = _balls[i]["pos"].distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best_index = i
	if best_index == -1:
		return
	_grabbed_index = best_index
	_balls[best_index]["state"] = "grabbed"
	_balls[best_index]["vel"] = Vector2.ZERO
	# Start the swipe-velocity samples from this press.
	_drag_velocity = Vector2.ZERO
	_drag_last_pos = point
	_drag_last_usec = Time.get_ticks_usec()


## While dragging, move the ball to the finger and keep a smoothed estimate of swipe velocity.
func _drag_to(point: Vector2) -> void:
	_balls[_grabbed_index]["pos"] = point
	var now := Time.get_ticks_usec()
	var dt := float(now - _drag_last_usec) / 1_000_000.0
	if dt > 0.0:
		var instant := (point - _drag_last_pos) / dt
		# Smooth toward the latest sample so a single jittery frame doesn't define the throw.
		_drag_velocity = _drag_velocity.lerp(instant, 0.5)
	_drag_last_pos = point
	_drag_last_usec = now


## On release, fling the grabbed ball along the swipe — or, if the swipe was too gentle, just
## let the ball fall (it becomes a flight ball with near-zero speed and drops off the board).
func _release_throw() -> void:
	if _grabbed_index == -1:
		return
	var ball: Dictionary = _balls[_grabbed_index]
	var speed := _drag_velocity.length()
	if speed < MIN_THROW_SPEED:
		ball["vel"] = Vector2.ZERO
	elif speed > MAX_THROW_SPEED:
		ball["vel"] = _drag_velocity.normalized() * MAX_THROW_SPEED
	else:
		ball["vel"] = _drag_velocity
	ball["state"] = "flight"
	_grabbed_index = -1


## Draw the hoop and every ball. The hoop is drawn first so a scoring ball passes in front of
## the rim; the flash brightens the rim briefly when a basket is made.
func _draw_play() -> void:
	var hoop_rect := Rect2(_hoop_pos - Vector2(HOOP_RADIUS, HOOP_RADIUS), Vector2(HOOP_RADIUS * 2.0, HOOP_RADIUS * 2.0))
	var hoop_tint := Color.WHITE.lerp(UiPalette.MUSTARD_GOLD, _hoop_flash)
	_play.draw_texture_rect(HOOP_TEX, hoop_rect, false, hoop_tint)

	for ball in _balls:
		# The grabbed ball draws a touch larger so the player can see what they're holding.
		var radius := BALL_RADIUS * (1.12 if ball["state"] == "grabbed" else 1.0)
		var ball_rect := Rect2(ball["pos"] - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		_play.draw_texture_rect(BALL_TEX, ball_rect, false)
