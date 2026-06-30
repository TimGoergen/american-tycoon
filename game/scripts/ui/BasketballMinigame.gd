class_name BasketballMinigame
extends Minigame

# "Micro Basketball" minigame TYPE (GDD §5.5) — a quick slingshot-to-shoot game. A still hoop
# sits on the board; a SINGLE basketball rests on the floor. The player presses the ball, DRAGS
# it back (away from where they want it to go), and releases — the ball is flung in the OPPOSITE
# direction of the pull, with force proportional to how far it was dragged, like a slingshot.
# The ball then flies purely under gravity, bouncing off the walls, ceiling, floor, and the hoop
# itself (which is a solid obstacle — a ball hitting the rim or coming up from underneath bounces
# off), spinning as it rolls. At ANY time the player can press the ball again — even mid-flight —
# to FREEZE it where it is and re-shoot from that spot. A shot scores only when a falling ball
# drops in through the top of the hoop, exactly like real basketball. Each made basket relocates
# the hoop to a fresh spot in the upper-middle band. Baskets only ever accumulate, so the host's
# spectrum bar climbs as the player sinks shots. It has no natural end — the host's countdown ends it.
#
# Owns only its gameplay; the host owns the countdown / spectrum / result / multiplier.

## Baskets that map to performance 1.0. Tuned for a ~20s round: a skilled player can plausibly
## sink this many, while an average player lands mid-range. FEEL-TUNE: raise to make 1.0x
## harder to reach, lower to make it easier.
const TARGET_BASKETS := 6

## A single basketball is in play (Tim, 2026-06-28). It is never spawned or removed — a thrown
## ball bounces, settles, and becomes throwable again; a scored ball is reset to the floor — so
## the one ball always exists. (Kept as a count so the lay/loop code reads uniformly.)
const BALL_COUNT := 1

## Ball size in pixels — kept generous for thumb play and imperfect vision. (Enlarged 40% from
## the original 38, Tim 2026-06-28.)
const BALL_RADIUS := 53.2          # ~106px diameter

## The hoop is drawn as a wide, short ellipse — the rim seen nearly from the FRONT (more head-on
## than from above), so it reads as a real basketball hoop rather than a flat ring seen from
## overhead. RX is the horizontal (wide) radius; RY the vertical (short) radius. (Enlarged 15%
## from the original 82×30, Tim 2026-06-28.)
const HOOP_RX := 94.3
const HOOP_RY := 34.5
## Half-width of the scoring "mouth" at the top of the rim. Narrower than HOOP_RX so the solid rim
## ENDS (the posts) sit just outside the mouth — a near-miss clips a post and bounces (a rim-out),
## while a clean drop through the gap scores.
const RIM_HALF_WIDTH := HOOP_RX * 0.74
## Radius of each solid rim "post" at the left/right ends of the ellipse — the parts of the hoop a
## ball physically bounces off. (Scaled 15% with the hoop.)
const RIM_POST_RADIUS := 16.1

## Downward acceleration (px/sec^2). Deliberately heavy — a high gravity gives the balls a weighty,
## fast-falling feel with tight arcs and little hang time, rather than floating like balloons.
const GRAVITY := 2400.0

## The slingshot: the throw velocity is the pull vector (ball dragged away from its rest spot),
## reversed, times PULL_POWER. The drag is capped at MAX_PULL so a huge yank can't overpower the
## board; a drag shorter than MIN_PULL on release is not a throw (the ball just snaps back). Power
## is matched up to the heavier gravity so a full pull still comfortably reaches the hoop.
const MAX_PULL := 300.0
const MIN_PULL := 28.0
const PULL_POWER := 9.6
## Hard cap on the resulting throw speed (px/sec).
const MAX_THROW_SPEED := 2900.0

## Fraction of speed KEPT when a ball bounces off a wall, the floor, the ceiling, or the hoop
## (0 = dead stop, 1 = perfectly elastic). Lowered for the heavier feel — a dense ball thuds and
## loses energy quickly rather than springing back.
const RESTITUTION := 0.46
## Extra horizontal slowdown applied each time a ball lands on the floor, so it doesn't skate
## along the ground forever after the bounce height dies out.
const FLOOR_FRICTION := 0.70
## Once an airborne ball is resting on the floor and moving slower than this (px/sec) in both
## axes, it settles: it becomes a still, throwable ball again. Raised with the heavier feel so
## balls come to rest promptly instead of dribbling out a long tail of tiny bounces.
const REST_SPEED := 95.0

## Thickness (px) of the dark-gray outline that frames the board and defines the walls, floor,
## and ceiling the balls bounce against.
const WALL_THICKNESS := 6.0

# Each ball is a Dictionary: { "pos": Vector2, "vel": Vector2, "state": String, "spin": float },
# plus a transient "prev" (its start-of-frame position, written during the motion pass and read by
# the hoop's top-entry test). state is one of "idle" (resting on the floor, throwable), "aiming"
# (held by the finger, frozen, not yet released), or "flight" (airborne under gravity). spin is the
# ball's draw rotation, accumulated from horizontal motion so it visibly rolls.
var _balls: Array = []
var _baskets: int = 0
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _started_balls: bool = false   # one-shot: lay the balls on the floor once the board has a size
var _hoop_placed: bool = false     # one-shot: center the hoop once the board has a size

var _hoop_pos: Vector2 = Vector2.ZERO
var _hoop_flash: float = 0.0       # brief brighten of the rim after a made basket, decays in _process

# --- Celebration juice (polish pass, Tim 2026-06-29) -------------------------------------------
# This pass adds NO difficulty change (Basketball "holds"); it only makes a made basket and a
# near-miss rim clang feel good. All of the state below is purely cosmetic — it never touches
# _baskets or get_performance().

## The aimed ball's draw scale, EASED toward its target each frame (1.0 normal, ~1.12 while held)
## so grabbing a ball blooms smoothly instead of snapping to 1.12x in one frame.
const AIM_SCALE_HELD := 1.12
const AIM_SCALE_EASE := 14.0       # how fast the held-ball scale catches its target (per second)
var _aim_scale: float = 1.0

## Short-lived spray/clang particles: small circles flung from the hoop on a score and from a rim
## post on a near-miss bounce. Each is { "pos", "vel", "life" (1->0), "color", "radius" }.
var _particles: Array = []
const PARTICLE_GRAVITY := 1400.0   # lighter than the ball's gravity — confetti floats a touch more
const PARTICLE_FADE := 1.6         # life drained per second (so a spray lasts ~0.6s)

## Expanding "score ring" pops drawn outward from the hoop on a made basket. Each is { "pos", "life" }.
var _score_rings: Array = []
const SCORE_RING_FADE := 2.2       # life drained per second
const SCORE_RING_MAX_RADIUS := 130.0

## A decaying net "swing": after a ball drops through, the net sways side to side and settles. This
## counts down from NET_SWING_DURATION; _draw_net offsets the net's bottom by a damped sine of it.
var _net_swing_time: float = 0.0
const NET_SWING_DURATION := 0.9
const NET_SWING_FREQ := 22.0       # how quickly the net sways back and forth
const NET_SWING_AMPLITUDE := 18.0  # px the net bottom swings at the peak of a fresh swing

# The ball the player is currently aiming (an index into _balls, or -1 for none) and the rest spot
# it was pulled back from (the slingshot anchor it launches from on release).
var _aim_index: int = -1
var _aim_anchor: Vector2 = Vector2.ZERO

var _play: Control

# Drawn each frame; preloaded so the texture is ready the instant play begins. The hoop is drawn
# with plain shapes (an ellipse rim + a net), so only the ball needs a texture.
const BALL_TEX := preload("res://art/icons/basketball.svg")


func display_name() -> String:
	return "Micro Basketball"


## Slingshot aiming and bouncing shots take a beat longer to line up than the tap-based types, so
## this round runs ~10s longer than the shared default (see Minigame.extra_seconds).
func extra_seconds() -> float:
	return 10.0


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	_baskets = 0
	_started_balls = false
	_hoop_placed = false
	# Clear any carried-over celebration state so a fresh round starts clean.
	_aim_scale = 1.0
	_particles.clear()
	_score_rings.clear()
	_net_swing_time = 0.0
	# Round length is read (not hardcoded) so this type tracks whatever the host sets; only used
	# here for the comment math — performance is baskets/target, which the host samples live.
	var _round_seconds := maxf(0.1, tuning.minigame_duration_seconds)

	var intro := Label.new()
	intro.text = "Pull the ball back and release to sling it through the hoop. Tap it any time — even mid-air — to freeze it and shoot again from there!"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# A single full-size play Control holds the whole scene. Custom _draw (rather than moving
	# TextureRects) is the more readable choice here: every ball and the hoop are positioned by
	# plain math in one place, and the arcing flight, the wall/hoop bounces, and the basket
	# hit-test all read off the same Vector2 positions, so there's no node bookkeeping to sync.
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

	# The board's size isn't known until it's laid out, so the balls and the hoop are positioned
	# here, the first frame the board has a real size, rather than in begin().
	if not _hoop_placed:
		_hoop_pos = Vector2(bounds.x * 0.5, bounds.y * 0.5)  # start in the middle
		_hoop_placed = true
	if not _started_balls:
		_lay_balls_on_floor(bounds)
		_started_balls = true

	_hoop_flash = maxf(0.0, _hoop_flash - delta * 3.0)
	_advance_balls(delta, bounds)
	_advance_celebration(delta)
	_play.queue_redraw()


## Advance the cosmetic celebration state: ease the held-ball scale toward its target, drift/fade the
## spray particles, grow/fade the score rings, and let the net swing decay. None of this affects play.
func _advance_celebration(delta: float) -> void:
	# Ease the aimed ball's bloom toward its target (held vs. not), so a grab is a smooth pop.
	var any_aiming := _aim_index != -1
	var target_scale := AIM_SCALE_HELD if any_aiming else 1.0
	_aim_scale = lerpf(_aim_scale, target_scale, clampf(delta * AIM_SCALE_EASE, 0.0, 1.0))

	# Spray particles fall under a light gravity and fade out; drop the dead ones.
	for particle in _particles:
		particle["vel"].y += PARTICLE_GRAVITY * delta
		particle["pos"] += particle["vel"] * delta
		particle["life"] -= PARTICLE_FADE * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)

	# Score rings just fade (their radius is derived from remaining life in the draw).
	for ring in _score_rings:
		ring["life"] -= SCORE_RING_FADE * delta
	_score_rings = _score_rings.filter(func(r: Dictionary) -> bool: return r["life"] > 0.0)

	# The net swing winds down to rest.
	_net_swing_time = maxf(0.0, _net_swing_time - delta)


## Place the ball resting on the floor (BALL_COUNT == 1 → centered; the spread math still reads
## uniformly if the count is ever raised).
func _lay_balls_on_floor(bounds: Vector2) -> void:
	_balls.clear()
	var floor_y := bounds.y - WALL_THICKNESS - BALL_RADIUS
	for i in range(BALL_COUNT):
		var fraction := (float(i) + 1.0) / (float(BALL_COUNT) + 1.0)
		var x := lerpf(bounds.x * 0.18, bounds.x * 0.82, fraction)
		_balls.append({
			"pos": Vector2(x, floor_y),
			"vel": Vector2.ZERO,
			"state": "idle",
			"spin": 0.0,
		})


## After a made basket, move the still hoop to a fresh spot: vertically somewhere between the
## board's middle and halfway up to the top, horizontally anywhere that keeps the whole ellipse off
## the walls.
func _move_hoop(bounds: Vector2) -> void:
	var margin_x := WALL_THICKNESS + HOOP_RX
	_hoop_pos = Vector2(
		_rng.randf_range(margin_x, bounds.x - margin_x),
		_rng.randf_range(bounds.y * 0.25, bounds.y * 0.5)
	)


## Advance the simulation one frame, in two clear passes:
##   1) integrate gravity + motion for the airborne ball (remembering its start position so the
##      hoop's top-entry test can see the crossing), and spin it from its horizontal motion,
##   2) resolve the airborne ball against the hoop and the board's walls/floor/ceiling.
## The wall pass runs last so a ball can never be left overlapping a wall.
func _advance_balls(delta: float, bounds: Vector2) -> void:
	# Pass 1: gravity + motion, plus rolling spin.
	for ball in _balls:
		if ball["state"] != "flight":
			continue
		ball["prev"] = ball["pos"]  # start-of-frame position, for the hoop crossing test
		ball["vel"].y += GRAVITY * delta
		ball["pos"] += ball["vel"] * delta
		# Spin from horizontal motion (rolling without slipping: angular speed = vx / radius), so the
		# ball visibly rotates as it rolls along the floor or arcs through the air (Tim, 2026-06-28).
		ball["spin"] = float(ball.get("spin", 0.0)) + ball["vel"].x / BALL_RADIUS * delta

	# Pass 2: hoop scoring/bounces, then the board walls.
	for ball in _balls:
		if ball["state"] != "flight":
			continue
		var prev: Vector2 = ball.get("prev", ball["pos"])
		# Resolve the hoop first. If it scored, the ball was reset to the floor and the hoop moved,
		# so skip the wall pass for it this frame.
		if _resolve_hoop(ball, prev, bounds):
			continue
		_resolve_walls(ball, bounds)


## Bounce one airborne ball off the side walls, ceiling, and floor, and let it settle to rest once
## it is barely moving along the floor.
func _resolve_walls(ball: Dictionary, bounds: Vector2) -> void:
	var min_x := WALL_THICKNESS + BALL_RADIUS
	var max_x := bounds.x - WALL_THICKNESS - BALL_RADIUS
	var min_y := WALL_THICKNESS + BALL_RADIUS
	var floor_y := bounds.y - WALL_THICKNESS - BALL_RADIUS

	# Side walls: clamp the center back inside and flip + dampen the horizontal velocity.
	if ball["pos"].x < min_x:
		ball["pos"].x = min_x
		ball["vel"].x = absf(ball["vel"].x) * RESTITUTION
	elif ball["pos"].x > max_x:
		ball["pos"].x = max_x
		ball["vel"].x = -absf(ball["vel"].x) * RESTITUTION

	# Ceiling.
	if ball["pos"].y < min_y:
		ball["pos"].y = min_y
		ball["vel"].y = absf(ball["vel"].y) * RESTITUTION

	# Floor, with extra horizontal friction on each landing.
	elif ball["pos"].y > floor_y:
		ball["pos"].y = floor_y
		ball["vel"].y = -absf(ball["vel"].y) * RESTITUTION
		ball["vel"].x *= FLOOR_FRICTION
		# Once the ball is barely moving along the floor, let it settle into a throwable rest
		# instead of jittering with ever-tinier bounces.
		if absf(ball["vel"].y) < REST_SPEED and absf(ball["vel"].x) < REST_SPEED:
			ball["vel"] = Vector2.ZERO
			ball["state"] = "idle"


## Resolve a flight ball against the hoop. Returns true if it scored (the caller then skips the
## rest of that ball's physics). The hoop is a SOLID obstacle: only a ball falling cleanly through
## the top mouth scores; a ball rising up into the mouth from below is blocked, and a ball that
## clips either rim post bounces off it.
func _resolve_hoop(ball: Dictionary, prev: Vector2, bounds: Vector2) -> bool:
	var rim_y := _hoop_pos.y
	var within_mouth: bool = absf(ball["pos"].x - _hoop_pos.x) <= RIM_HALF_WIDTH

	# Score: the ball is FALLING (vel.y > 0) and drops down across the rim plane within the mouth.
	# Requiring downward motion is what makes a basket count only from the TOP.
	if ball["vel"].y > 0.0 and prev.y <= rim_y and ball["pos"].y >= rim_y and within_mouth:
		_baskets += 1
		_hoop_flash = 1.0
		_celebrate_basket()  # net swing + score-ring pop + a small confetti spray (cosmetic only)
		_rest_ball(ball, bounds)
		_move_hoop(bounds)
		return true

	# Blocked from below: the ball is RISING (vel.y < 0) up through the mouth — the basket's
	# underside is solid, so push it back below the rim and bounce it downward.
	if ball["vel"].y < 0.0 and prev.y >= rim_y and ball["pos"].y <= rim_y and within_mouth:
		ball["pos"].y = rim_y + BALL_RADIUS
		ball["vel"].y = absf(ball["vel"].y) * RESTITUTION

	# Rim posts: the solid left/right ends of the ellipse. A ball overlapping a post is pushed out
	# along the contact normal and its velocity reflected about that normal (a rim bounce).
	for post in [_hoop_pos + Vector2(-HOOP_RX, 0.0), _hoop_pos + Vector2(HOOP_RX, 0.0)]:
		var offset: Vector2 = ball["pos"] - post
		var distance := offset.length()
		var min_distance := BALL_RADIUS + RIM_POST_RADIUS
		if distance < min_distance and distance > 0.01:
			var normal := offset / distance
			ball["pos"] = post + normal * min_distance
			var into_post: float = ball["vel"].dot(normal)
			if into_post < 0.0:  # only reflect if moving toward the post
				ball["vel"] -= normal * into_post * (1.0 + RESTITUTION)
				# A near-miss clang: splash a few gray sparks off the contact point so the rim-out
				# reads as a real impact, not a silent deflection (plan §2.6).
				_spawn_clang(ball["pos"], normal)
	return false


## Reset a ball to a still, throwable rest on the floor (used after it scores).
func _rest_ball(ball: Dictionary, bounds: Vector2) -> void:
	var min_x := WALL_THICKNESS + BALL_RADIUS
	var max_x := bounds.x - WALL_THICKNESS - BALL_RADIUS
	ball["pos"] = Vector2(
		clampf(ball["pos"].x, min_x, max_x),
		bounds.y - WALL_THICKNESS - BALL_RADIUS
	)
	ball["vel"] = Vector2.ZERO
	ball["state"] = "idle"


# ---------------------------------------------------------------------------
# Celebration spawns (cosmetic only — never touch _baskets / performance)
# ---------------------------------------------------------------------------

## A made basket: swing the net, pop an expanding score ring from the rim, and spray a burst of
## warm confetti up and out of the hoop.
func _celebrate_basket() -> void:
	_net_swing_time = NET_SWING_DURATION
	_score_rings.append({"pos": _hoop_pos, "life": 1.0})
	# Confetti: alternating gold/teal sparks flung mostly upward out of the hoop mouth.
	var colors := [UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL, Color.WHITE]
	for i in range(16):
		var angle := _rng.randf_range(-PI * 0.85, -PI * 0.15)  # fan upward (negative y is up)
		var speed := _rng.randf_range(420.0, 820.0)
		_particles.append({
			"pos": _hoop_pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": 1.0,
			"color": colors[i % colors.size()],
			"radius": _rng.randf_range(4.0, 8.0),
		})


## A near-miss rim clang: a few small gray sparks kicked off the post along the bounce normal, so a
## rim-out has a readable little impact.
func _spawn_clang(point: Vector2, normal: Vector2) -> void:
	for i in range(6):
		# Spread the sparks in a fan around the contact normal (away from the post).
		var spread := _rng.randf_range(-PI * 0.5, PI * 0.5)
		var direction := normal.rotated(spread)
		var speed := _rng.randf_range(180.0, 360.0)
		_particles.append({
			"pos": point,
			"vel": direction * speed,
			"life": 1.0,
			"color": UiPalette.LIGHT_GRAY,
			"radius": _rng.randf_range(3.0, 5.0),
		})


func _on_play_input(event: InputEvent) -> void:
	if not _running:
		return
	# Touch is delivered here as emulated mouse events (Godot's default), so handling mouse
	# button + motion covers both finger and mouse without separate touch handling.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim(event.position)
		else:
			_release_sling()
	elif event is InputEventMouseMotion and _aim_index != -1:
		_drag_aim(event.position)


## On press, grab the nearest ball within a generous radius — in ANY state, so a ball caught
## mid-flight FREEZES where it is (Tim, 2026-06-28). Its current position becomes the slingshot
## anchor, so the next shot launches from wherever it was caught rather than from the floor.
func _begin_aim(point: Vector2) -> void:
	var best_index := -1
	var best_distance := BALL_RADIUS * 2.0  # generous radius — also helps catch a moving ball
	for i in range(_balls.size()):
		if _balls[i]["state"] == "aiming":
			continue  # already held
		# Explicit float type: a Dictionary lookup is untyped (Variant), so distance_to() can't be
		# inferred with := here.
		var distance: float = _balls[i]["pos"].distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best_index = i
	if best_index == -1:
		return
	_aim_index = best_index
	_balls[best_index]["vel"] = Vector2.ZERO   # freeze a ball caught mid-flight in place
	_aim_anchor = _balls[best_index]["pos"]    # re-shoot from where it was caught
	_balls[best_index]["state"] = "aiming"


## While dragging, move the ball to the finger to show the slingshot stretch — but cap how far it
## can be pulled from its anchor, so the throw force is bounded.
func _drag_aim(point: Vector2) -> void:
	var pull := point - _aim_anchor
	if pull.length() > MAX_PULL:
		pull = pull.normalized() * MAX_PULL
	_balls[_aim_index]["pos"] = _aim_anchor + pull


## On release, sling the ball from its anchor in the direction OPPOSITE the pull, with speed
## proportional to how far it was dragged. A pull shorter than MIN_PULL is not a throw — the ball
## snaps back to its rest spot.
func _release_sling() -> void:
	if _aim_index == -1:
		return
	var ball: Dictionary = _balls[_aim_index]
	var pull: Vector2 = ball["pos"] - _aim_anchor
	var pull_distance := pull.length()
	# Always launch from the anchor (the ball "returns to the pocket" and shoots off), so it never
	# starts mid-air at the pulled-back position.
	ball["pos"] = _aim_anchor
	if pull_distance < MIN_PULL:
		# A tap with no real drag isn't a throw — let the ball GO and fall under gravity from where
		# it was held (Tim 2026-06-28): a ball frozen mid-air drops; a ball on the floor just
		# settles straight back. Either way it is released, not left hanging, frozen, in the air.
		ball["vel"] = Vector2.ZERO
		ball["state"] = "flight"
	else:
		var throw := -pull * PULL_POWER  # opposite the drag, force ∝ drag distance
		if throw.length() > MAX_THROW_SPEED:
			throw = throw.normalized() * MAX_THROW_SPEED
		ball["vel"] = throw
		ball["state"] = "flight"
	_aim_index = -1


## Draw the board outline, the hoop (net + rim, split so a scoring ball passes through it), every
## ball, and the slingshot aim guide while a ball is being pulled back.
func _draw_play() -> void:
	var bounds := _play.size

	# The hoop is drawn in layers so a falling ball reads as dropping THROUGH it: the net and the
	# back (far) half of the rim go down first, then the balls, then the front (near) half of the
	# rim on top. The flash brightens the rim briefly when a basket is made.
	var rim_color := UiPalette.ORANGE.lerp(UiPalette.MUSTARD_GOLD, _hoop_flash)
	_draw_net()
	_draw_rim_half(rim_color, true)   # back half (top edge of the ellipse)

	for ball in _balls:
		# The aimed ball draws a touch larger so the player can see they're holding it. The scale is
		# EASED (see _advance_celebration) rather than snapped, so the grab blooms smoothly.
		var radius := BALL_RADIUS * (_aim_scale if ball["state"] == "aiming" else 1.0)
		# Rotate the ball around its center by its accumulated spin so it visibly rolls as it moves.
		# draw_set_transform applies to the next draw; we reset it right after.
		_play.draw_set_transform(ball["pos"], float(ball.get("spin", 0.0)), Vector2.ONE)
		_play.draw_texture_rect(BALL_TEX, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false)
	_play.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_rim_half(rim_color, false)  # front half (bottom edge of the ellipse), drawn over the ball

	if _aim_index != -1:
		_draw_aim_guide()

	# The celebration layer (score rings + confetti/clang sparks), drawn over the play field but
	# under the board frame so it never spills past the walls visually.
	_draw_celebration()

	# The dark-gray frame that defines the walls, floor, and ceiling. Drawn last so it reads as a
	# solid boundary in front of a ball pressed right up against it. Inset by half its thickness so
	# the whole outline sits inside the board.
	var frame := Rect2(
		Vector2(WALL_THICKNESS * 0.5, WALL_THICKNESS * 0.5),
		bounds - Vector2(WALL_THICKNESS, WALL_THICKNESS)
	)
	_play.draw_rect(frame, UiPalette.DARK_GRAY, false, WALL_THICKNESS)


## Draw the slingshot feedback: a band from the anchor to the pulled-back ball, plus a gold guide
## ray from the anchor in the direction the ball will fly (opposite the pull), its length growing
## with the pull so the player can read the power before releasing.
func _draw_aim_guide() -> void:
	var ball_pos: Vector2 = _balls[_aim_index]["pos"]
	var pull := ball_pos - _aim_anchor
	# The stretched sling band.
	_play.draw_line(_aim_anchor, ball_pos, Color(UiPalette.NAVY, 0.6), 4.0, true)
	# A marker at the launch point.
	_play.draw_circle(_aim_anchor, 6.0, Color(UiPalette.NAVY, 0.6))
	# The aim ray, opposite the pull, scaled up so it clearly reads as the throw direction.
	if pull.length() >= MIN_PULL:
		var aim_end := _aim_anchor - pull * 1.5
		_play.draw_line(_aim_anchor, aim_end, Color(UiPalette.MUSTARD_GOLD, 0.85), 3.0, true)


## Draw the celebration layer: the expanding/fading score rings from a made basket, then the
## confetti and clang sparks. Pure cosmetics; these read off _score_rings and _particles, which
## _advance_celebration grows and fades.
func _draw_celebration() -> void:
	# Score rings: a thin ring that expands outward from the hoop and fades as its life drains.
	for ring in _score_rings:
		var life: float = ring["life"]
		var radius := SCORE_RING_MAX_RADIUS * (1.0 - life)  # small at spawn (life 1) -> wide as it fades
		var ring_color := UiPalette.MUSTARD_GOLD
		ring_color.a = life  # fade out as it grows
		_play.draw_arc(ring["pos"], radius, 0.0, TAU, 32, ring_color, 4.0, true)

	# Confetti / clang sparks: little solid circles that fade with their life.
	for particle in _particles:
		var spark_color: Color = particle["color"]
		spark_color.a = clampf(particle["life"], 0.0, 1.0)
		_play.draw_circle(particle["pos"], particle["radius"], spark_color)


## Draw half of the rim ellipse. top_half draws the far/top edge (sin < 0); otherwise the
## near/bottom edge (sin > 0). Splitting the rim lets a scoring ball be drawn between the two
## halves so it looks like it falls in front of the near rim and behind the far rim.
func _draw_rim_half(color: Color, top_half: bool) -> void:
	var steps := 28
	var points := PackedVector2Array()
	# Angles: PI..TAU is the top edge (y above center), 0..PI is the bottom edge (y below center).
	var a_start := PI if top_half else 0.0
	var a_end := TAU if top_half else PI
	for i in range(steps + 1):
		var a := lerpf(a_start, a_end, float(i) / float(steps))
		points.append(_hoop_pos + Vector2(cos(a) * HOOP_RX, sin(a) * HOOP_RY))
	_play.draw_polyline(points, color, 6.0, true)


## Draw a simple hanging net below the rim: strands dropping from the rim ellipse to a smaller
## ellipse beneath it, tied together by a couple of horizontal rings. The net is white and gray —
## the vertical strands alternate white / light-gray for a woven look, the tie rings a deeper gray.
func _draw_net() -> void:
	var strand_white := Color.WHITE
	var strand_gray := UiPalette.LIGHT_GRAY
	var ring_gray := UiPalette.MID_GRAY
	var depth := HOOP_RY + 56.0                 # how far the net hangs below the hoop center
	# After a made basket the net sways: a damped sine, strongest right after the ball drops through
	# and settling to zero over NET_SWING_DURATION. Only the net's BOTTOM swings; the rim stays put.
	var swing_x := 0.0
	if _net_swing_time > 0.0:
		var elapsed := NET_SWING_DURATION - _net_swing_time
		var decay := _net_swing_time / NET_SWING_DURATION
		swing_x = sin(elapsed * NET_SWING_FREQ) * NET_SWING_AMPLITUDE * decay
	var bottom_center := _hoop_pos + Vector2(swing_x, depth)
	var bottom_rx := HOOP_RX * 0.42             # the net pinches inward toward the bottom
	var bottom_ry := HOOP_RY * 0.42

	var strands := 8
	for i in range(strands):
		var a := lerpf(0.0, TAU, float(i) / float(strands))
		var top := _hoop_pos + Vector2(cos(a) * HOOP_RX, sin(a) * HOOP_RY)
		var bottom := bottom_center + Vector2(cos(a) * bottom_rx, sin(a) * bottom_ry)
		var strand_color := strand_white if i % 2 == 0 else strand_gray
		_play.draw_line(top, bottom, strand_color, 2.0, true)

	# Two horizontal rings tie the strands together so the mesh reads as a net.
	for ring in [0.45, 0.85]:
		var ring_center := _hoop_pos.lerp(bottom_center, ring)
		var ring_rx := lerpf(HOOP_RX, bottom_rx, ring)
		var ring_ry := lerpf(HOOP_RY, bottom_ry, ring)
		var ring_points := PackedVector2Array()
		for i in range(17):
			var a := lerpf(0.0, TAU, float(i) / 16.0)
			ring_points.append(ring_center + Vector2(cos(a) * ring_rx, sin(a) * ring_ry))
		_play.draw_polyline(ring_points, ring_gray, 2.0, true)
