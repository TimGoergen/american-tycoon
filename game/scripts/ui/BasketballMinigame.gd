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

## The slingshot: the throw is aimed OPPOSITE the pull (ball dragged away from its rest spot), and
## its SPEED is a NON-LINEAR function of the drag distance — the drag fraction over the launch-max
## drag, raised to the launch-curve exponent. The old map was linear (distance × a fixed power) and
## "ramped too strong too fast" (Tim, 2026-07-07): a short pull already maxed out, leaving no fine
## control. The curve now eases the low end so small/medium pulls are gentle and full power needs a
## long drag. MAX_PULL caps how far the ball can visually stretch; a drag shorter than MIN_PULL is
## not a throw (the ball just snaps back).
const MAX_PULL := 300.0
const MIN_PULL := 28.0

# The three launch-curve values are now TUNING KNOBS (Tim, 2026-07-10) so the throw feel can be
# dialed on device via Balance Tuning without a rebuild. Read from TuningConfig in begin(); the
# defaults below match the previous constants.
## Drag distance (px) at which the throw reaches max speed — longer drags add no more force.
var _launch_max_drag: float = 200.0
## Launch response exponent. 1.0 = a linear ramp; >1 eases the low end (small pulls gentle, force
## building toward the end of the drag) for finer aim control at low power.
var _launch_curve_exp: float = 1.7
## Hard cap on the resulting throw speed (px/sec).
var _max_throw_speed: float = 2900.0

## Aim-guide force colors (Tim, 2026-06-30; extended to four stops 2026-07-01 for readability): the
## force wedge is a SINGLE color that CHANGES with the current pull's force, climbing through a wider
## ramp — green (low) → blue → purple → bright red (high/maxed) — so the power reads clearly before
## release. Green, blue, and purple are deliberate one-off exceptions to the §1 palette for this
## force gauge (the same way ORANGE was added for the spectrum bar). The stops are lerped in order
## across the [0,1] force range by _force_color; add or reorder entries here to reshape the ramp.
const FORCE_COLOR_RAMP := [
	Color("#33B24D"),   # green — low force
	Color("#3A78D0"),   # blue  — low-to-medium
	Color("#8244C0"),   # purple — medium-to-high
	Color("#E23B2C"),   # bright red — high / maxed force
]
## The force wedge is a filled triangle with its POINT at the ball's launch location, FANNING OUT
## to a wide far end in the DIRECTION OF TRAVEL (opposite the pull) — like a beam showing where the
## ball will go (Tim, 2026-06-30). The wide end's width grows with force; the wedge's length grows
## with the pull distance.
const AIM_WEDGE_BASE_MIN := 10.0    # wide-end width at near-zero force
const AIM_WEDGE_BASE_MAX := 40.0    # wide-end width at maxed force
const AIM_WEDGE_LENGTH_SCALE := 1.6 # wedge length = pull distance × this

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

## Thickness (px) of the outline that frames the board and defines the walls, floor, and ceiling
## the balls bounce against. Doubled 6 -> 12 and recolored to BLACK with rounded corners (Tim,
## 2026-06-30) — the physics wall inset uses the same value, so the ball bounces at the inner edge
## of the drawn border.
const WALL_THICKNESS := 12.0
## Corner radius (px) of the board's rounded outline + its background image's rounded corners.
const BOARD_CORNER_RADIUS := 28
## Empty space (px) between the board and the surrounding card, on every side. Provided by a
## MarginContainer around the play field (Tim, 2026-06-30: "3× as much space around the edge").
const BOARD_MARGIN := 48
## The gym backdrop shown inside the board's rounded outline (Tim, 2026-06-30).
const BOARD_IMAGE := "res://art/backgrounds/basketball_court.png"

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

# --- Legacy gem state (see the LEGACY_GEM constants above) -------------------------------------
## Chance (0..1) that a legacy gem appears this round, captured from tuning in begin().
var _legacy_gem_chance: float = 0.0
## True while a legacy gem is on the board waiting to be earned. Only ever one at a time.
var _legacy_gem_active: bool = false
## Where the active gem floats (board-local), placed once the board has a real size.
var _legacy_gem_pos: Vector2 = Vector2.ZERO
## One-shot: place the gem once the board is laid out (like the hoop/balls), if this round rolled one.
var _legacy_gem_placed: bool = false
## Whether the CURRENT shot's flight has already passed through the gem. Reset at the start of each
## shot (in _release_sling); if it's true when that same shot scores, the gem is collected.
var _passed_through_gem_this_shot: bool = false
## A short "you got it!" pop after collecting: a decaying pulse the draw reads to flash the spot.
var _legacy_gem_win_cue: float = 0.0
const LEGACY_GEM_WIN_CUE_FADE := 1.4  # life drained per second (so the cue lasts ~0.7s)
## Free-running phase (seconds) driving the idle bob/shimmer of the waiting gem so it looks alive.
var _legacy_gem_phase: float = 0.0

# --- Celebration juice (polish pass, Tim 2026-06-29) -------------------------------------------
# This pass adds NO difficulty change (Basketball "holds"); it only makes a made basket feel good.
# All of the state below is purely cosmetic — it never touches _baskets or get_performance().

## The aimed ball's draw scale, EASED toward its target each frame (1.0 normal, ~1.12 while held)
## so grabbing a ball blooms smoothly instead of snapping to 1.12x in one frame.
const AIM_SCALE_HELD := 1.12
const AIM_SCALE_EASE := 14.0       # how fast the held-ball scale catches its target (per second)
var _aim_scale: float = 1.0

## Short-lived spray particles flung from the hoop when a basket is made (Tim, 2026-07-01: sparks
## are reserved for a score — a rim touch no longer sprays). Each is { "pos", "vel", "life" (1->0),
## "color", "radius" }.
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
## The gym backdrop, CPU-baked to the board size with rounded corners (so it nests inside the
## rounded outline) and cached; re-baked only when the board's WHOLE-PIXEL size changes.
## The cache key is integer pixels, NOT the float size (Tim, 2026-07-07): sub-pixel layout
## jitter — e.g. Challenge Mode's per-frame score label re-layout nudging ancestors by
## fractions — defeated an exact float compare and re-ran this very expensive bake every
## frame, dragging the whole game down (and the huge frame deltas then tunneled the ball
## through the rim).
var _board_bg: ImageTexture
var _board_bg_px: Vector2i = Vector2i.ZERO
## The gym image decompressed once — rebakes duplicate this instead of re-loading.
var _board_source: Image = null
## The board's black rounded outline, built once and reused — it was being allocated
## fresh inside the draw pass every frame (minigame lag pass, Tim 2026-07-06).
var _board_border: StyleBoxFlat

# Drawn each frame; preloaded so the texture is ready the instant play begins. The hoop is drawn
# with plain shapes (an ellipse rim + a net), so only the ball needs a texture.
const BALL_TEX := preload("res://art/icons/basketball.svg")

# --- Legacy Bonus (Plans/Legacy_Bonus_System.md) ----------------------------------------------
# Basketball's legacy mechanic: with a small chance one legacy gem appears floating in the play
# area between the launch floor and the hoop. It is earned ONLY if a single shot passes THROUGH
# the gem (the ball's center comes within LEGACY_GEM_GRAB_RADIUS of it at any point during that
# shot's flight) AND that SAME shot then scores. Pass through but miss the basket and the gem is
# NOT collected — it clears when the ball comes to rest, so each gem is worth one honest attempt
# (chosen over "stays forever" so a lucky pass-through can't be re-tried until it happens to score).

## The legacy gem icon — the same currency art used everywhere else, so the player recognizes it.
const LEGACY_GEM_TEX := preload("res://art/icons/legacy_gem.svg")
## Half the on-screen size (px) the gem is drawn at. Generous so it reads as a grabbable target.
const LEGACY_GEM_RADIUS := 44.0
## How close the ball's CENTER must come to the gem's center to count as "through" it. The ball is
## big (BALL_RADIUS), so this is comfortably larger than the drawn gem — brushing it counts.
const LEGACY_GEM_GRAB_RADIUS := BALL_RADIUS + LEGACY_GEM_RADIUS


func display_name() -> String:
	return "Micro Basketball"


func how_to_play() -> String:
	return "Pull the ball back and release to sling it through the hoop — the hoop " \
		+ "moves after every basket. Tap the ball any time, even mid-air, to freeze " \
		+ "it and shoot again from there."


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
	# Legacy gem: capture the spawn chance and reset the per-round gem state. Whether a gem actually
	# appears is rolled once the board has a size (in _process), so we know where the play area is.
	_legacy_gem_chance = clampf(tuning.legacy_gem_chance_basketball, 0.0, 1.0)
	# Launch-curve knobs (device-tunable). Guarded so a zeroed knob can't divide by zero / kill power.
	_launch_max_drag = maxf(1.0, tuning.basketball_launch_max_drag)
	_launch_curve_exp = maxf(0.1, tuning.basketball_launch_curve_exp)
	_max_throw_speed = maxf(1.0, tuning.basketball_max_throw_speed)
	_legacy_gem_active = false
	_legacy_gem_placed = false
	_passed_through_gem_this_shot = false
	_legacy_gem_win_cue = 0.0
	# Round length is read (not hardcoded) so this type tracks whatever the host sets; only used
	# here for the comment math — performance is baskets/target, which the host samples live.
	var _round_seconds := maxf(0.1, tuning.minigame_duration_seconds)

	var intro := Label.new()
	intro.text = how_to_play()
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

	# A margin around the board so it doesn't crowd the card edges (Tim, 2026-06-30). Wrapping the
	# play field in a MarginContainer keeps the board's own coordinate space at 0..size, so all the
	# physics/aim math below is unchanged — the space is provided entirely by the container.
	var board_margin := MarginContainer.new()
	board_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, BOARD_MARGIN)
	board_margin.add_child(_play)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(board_margin)
	add_child(column)


func get_performance() -> float:
	# Fixed denominator (TARGET_BASKETS), so the meter rises monotonically as baskets are sunk
	# and never falls back — matching the other types' climbing spectrum.
	return clampf(float(_baskets) / float(TARGET_BASKETS), 0.0, 1.0)


## Challenge Mode score = total baskets made this run (Tim, 2026-06-30). Cumulative and
## non-decreasing (see _baskets: it only ever counts up), so the host can sample it live for the
## high-score readout. Micro Basketball is ALREADY endless — it never emits `completed`, has no
## end condition (TARGET_BASKETS is only get_performance()'s denominator, not a stop), and a miss
## simply doesn't score — so Challenge Mode needs no other behavior change; the flag is honored by
## there being nothing to suppress. Returned in both modes; the host only reads it in Challenge Mode.
func get_score() -> int:
	return _baskets


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
	if not _legacy_gem_placed:
		# Roll for the gem once, now that we know the board size (so we can place it between the
		# launch floor and the hoop region). If it doesn't spawn, it simply never appears this round.
		_maybe_spawn_legacy_gem(bounds)
		_legacy_gem_placed = true

	_hoop_flash = maxf(0.0, _hoop_flash - delta * 3.0)
	# Advance the gem's idle animation and its post-collect win cue (both purely cosmetic).
	_legacy_gem_phase += delta
	_legacy_gem_win_cue = maxf(0.0, _legacy_gem_win_cue - delta * LEGACY_GEM_WIN_CUE_FADE)
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
	# Dead entries are removed in-place, walking backward so removal doesn't skip the
	# next entry — filter() rebuilt the whole array every frame (minigame lag pass,
	# Tim 2026-07-06).
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle["vel"].y += PARTICLE_GRAVITY * delta
		particle["pos"] += particle["vel"] * delta
		particle["life"] -= PARTICLE_FADE * delta
		if particle["life"] <= 0.0:
			_particles.remove_at(i)

	# Score rings just fade (their radius is derived from remaining life in the draw).
	for i in range(_score_rings.size() - 1, -1, -1):
		var ring: Dictionary = _score_rings[i]
		ring["life"] -= SCORE_RING_FADE * delta
		if ring["life"] <= 0.0:
			_score_rings.remove_at(i)

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


## With probability _legacy_gem_chance, spawn ONE legacy gem floating in the play area between the
## launch floor and the hoop region — a spot a shot's arc naturally passes through on the way up to
## the hoop. Placed clear of the walls so the whole icon is visible and grabbable.
func _maybe_spawn_legacy_gem(bounds: Vector2) -> void:
	# Don't spawn once the bonus is already earned (design rule 3 — no noise once secured).
	if legacy_bonus_secured():
		return
	if _rng.randf() >= _legacy_gem_chance:
		return
	# Keep the gem off the side walls, and vertically in the mid-band: below the hoop's spawn zone
	# (which sits in the upper 25–50%) yet above the resting balls, so a launched ball flies through
	# it en route to the rim rather than it sitting on the floor or overlapping the hoop.
	var margin_x := WALL_THICKNESS + LEGACY_GEM_RADIUS
	_legacy_gem_pos = Vector2(
		_rng.randf_range(margin_x, bounds.x - margin_x),
		_rng.randf_range(bounds.y * 0.55, bounds.y * 0.78)
	)
	_legacy_gem_active = true


## True if the ball's travel this substep (the segment from `from` to `to`) came within
## LEGACY_GEM_GRAB_RADIUS of the active gem. Testing the whole segment — not just the endpoint —
## is what stops a fast ball tunneling THROUGH the gem between two sampled positions.
func _segment_hits_gem(from: Vector2, to: Vector2) -> bool:
	# Closest point on segment [from, to] to the gem, via the standard projection clamped to [0,1].
	var seg := to - from
	var seg_len_sq := seg.length_squared()
	var closest: Vector2 = from
	if seg_len_sq > 0.0001:
		var t := clampf((_legacy_gem_pos - from).dot(seg) / seg_len_sq, 0.0, 1.0)
		closest = from + seg * t
	return closest.distance_to(_legacy_gem_pos) <= LEGACY_GEM_GRAB_RADIUS


## After a made basket, move the still hoop to a fresh spot: vertically somewhere between the
## board's middle and halfway up to the top, horizontally anywhere that keeps the whole ellipse off
## the walls.
func _move_hoop(bounds: Vector2) -> void:
	var margin_x := WALL_THICKNESS + HOOP_RX
	_hoop_pos = Vector2(
		_rng.randf_range(margin_x, bounds.x - margin_x),
		_rng.randf_range(bounds.y * 0.25, bounds.y * 0.5)
	)


## A flight ball may move at most this many pixels per physics pass — the substep rule
## below splits a frame into passes to honor it. Comfortably under the rim posts'
## contact distance, so a fast ball can never step OVER a post between two checks
## ("tunneling"): with big laggy frame deltas the ball visibly passed through the rim,
## while the score test (a crossing test) still caught it (Tim, 2026-07-07).
const MAX_STEP_PX := 24.0
## Substep ceiling, so one catastrophically long frame can't spiral into doing the
## whole simulation dozens of times (which would make the lag worse, not better).
const MAX_PHYSICS_SUBSTEPS := 8


## Advance the simulation one frame — split into substeps so no ball moves more than
## MAX_STEP_PX per collision pass regardless of the frame's delta (see MAX_STEP_PX).
func _advance_balls(delta: float, bounds: Vector2) -> void:
	var top_speed := 0.0
	for ball in _balls:
		if ball["state"] == "flight":
			top_speed = maxf(top_speed, (ball["vel"] as Vector2).length() + GRAVITY * delta)
	var steps := clampi(int(ceil(top_speed * delta / MAX_STEP_PX)), 1, MAX_PHYSICS_SUBSTEPS)
	var sub_delta := delta / float(steps)
	for _step in range(steps):
		_advance_balls_step(sub_delta, bounds)


## One physics pass, in two stages:
##   1) integrate gravity + motion for the airborne ball (remembering its start position so the
##      hoop's top-entry test can see the crossing), and spin it from its horizontal motion,
##   2) resolve the airborne ball against the hoop and the board's walls/floor/ceiling.
## The wall pass runs last so a ball can never be left overlapping a wall.
func _advance_balls_step(delta: float, bounds: Vector2) -> void:
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
		# Legacy gem "through" test, sampled EVERY physics substep (not once per frame) so a fast
		# ball can't step past the gem between checks — same tunneling concern as the rim. We test
		# the segment prev→pos, not just the endpoint, so even at MAX_STEP_PX a grazing pass counts.
		if _legacy_gem_active and not _passed_through_gem_this_shot:
			if _segment_hits_gem(ball["prev"], ball["pos"]):
				_passed_through_gem_this_shot = true

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
			# The shot has ended without scoring (a made basket returns earlier, in _resolve_hoop).
			# If it passed through the gem but missed, that gem is spent: clear it so a lucky
			# pass-through can't be retried until it finally scores (design: one honest attempt).
			if _legacy_gem_active and _passed_through_gem_this_shot:
				_legacy_gem_active = false
			_passed_through_gem_this_shot = false


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
		# Legacy gem: earned only if THIS shot also passed through the gem (both in one shot). The
		# host gates the actual payout by the round result; here we just record the collection.
		if _legacy_gem_active and _passed_through_gem_this_shot:
			collect_legacy_gem()
			_legacy_gem_win_cue = 1.0     # a brief pop at the gem's spot
			_legacy_gem_active = false    # consumed — one gem per appearance
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
				# No particles on a rim touch (Tim, 2026-07-01): the ball still bounces off the post,
				# but sparks are reserved for a MADE basket only, so a spray always means "score".
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
	# A new shot begins: reset the "passed through the gem" flag so through-gem credit is per-shot
	# (the gem must be crossed AND the basket made within this SAME shot).
	_passed_through_gem_this_shot = false
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
		# Aim OPPOSITE the pull; speed comes from the non-linear launch curve (see _throw_fraction).
		var speed := _throw_fraction(pull_distance) * _max_throw_speed
		ball["vel"] = (-pull / pull_distance) * speed
		ball["state"] = "flight"
	_aim_index = -1


## The normalized throw force [0,1] for a pull distance, under the non-linear launch curve (see the
## MAX_PULL / LAUNCH_* constants). Shared by the release (actual speed) and the aim guide (wedge size
## + color) so what the player SEES matches what they GET.
func _throw_fraction(pull_distance: float) -> float:
	var frac := clampf(pull_distance / _launch_max_drag, 0.0, 1.0)
	return pow(frac, _launch_curve_exp)


## Draw the board outline, the hoop (net + rim, split so a scoring ball passes through it), every
## ball, and the slingshot aim guide while a ball is being pulled back.
func _draw_play() -> void:
	var bounds := _play.size

	# The gym backdrop fills the board, behind all the gameplay, with rounded corners baked in so it
	# nests inside the rounded outline drawn last (Tim, 2026-06-30).
	_ensure_board_bg(bounds)
	if _board_bg != null:
		_play.draw_texture_rect(_board_bg, Rect2(Vector2.ZERO, bounds), false)

	# The backboard sits behind the hoop, drawn before the net/rim so those mount in front of it.
	_draw_backboard()

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

	# The waiting legacy gem (and its brief post-collect win cue) sit above the play field so the
	# player sees the target to shoot through.
	_draw_legacy_gem()

	# The celebration layer (score rings + basket confetti), drawn over the play field but
	# under the board frame so it never spills past the walls visually.
	_draw_celebration()

	# The board outline: a thick BLACK, ROUNDED-corner border drawn last so it reads as a solid
	# boundary in front of a ball pressed against it (Tim, 2026-06-30). A StyleBoxFlat gives the
	# rounded corners a plain draw_rect can't; its border grows inward from the board rect, matching
	# the WALL_THICKNESS the physics uses for the wall inset. Built lazily ONCE (its
	# settings never change) — see _board_border.
	if _board_border == null:
		_board_border = StyleBoxFlat.new()
		_board_border.bg_color = Color.TRANSPARENT
		_board_border.border_color = Color.BLACK
		_board_border.set_border_width_all(int(WALL_THICKNESS))
		_board_border.set_corner_radius_all(BOARD_CORNER_RADIUS)
	_play.draw_style_box(_board_border, Rect2(Vector2.ZERO, bounds))


## Bake the gym backdrop to the current board size with rounded corners, cached until the size
## changes. We CPU-bake (rather than clip_children) because the project supports only one clip
## stencil at a time and Main already owns it (see MinigameScreen for the full note).
func _ensure_board_bg(size: Vector2) -> void:
	var target := Vector2i(roundi(size.x), roundi(size.y))
	if target.x < 1 or target.y < 1:
		return
	# TOLERANCE, not equality — see _board_bg_px. The first integer-key fix still
	# thrashed when float jitter wobbled the size ACROSS an integer boundary
	# (719.999 ↔ 720.001 alternates the key every frame): basketball lagged again
	# (Tim, 2026-07-08). A ≤1px mismatch is invisible — the texture is drawn
	# stretched to the board rect regardless.
	if _board_bg != null \
			and absi(target.x - _board_bg_px.x) <= 1 and absi(target.y - _board_bg_px.y) <= 1:
		return
	_board_bg_px = target
	# The decompressed source is cached after the first bake — load + decompress +
	# convert never changes, so a legitimate rebake only pays for resize + crop.
	if _board_source == null:
		var source: Texture2D = load(BOARD_IMAGE)
		if source == null:
			return
		_board_source = source.get_image()
		if _board_source.is_compressed():
			_board_source.decompress()
		_board_source.convert(Image.FORMAT_RGBA8)
	var image := _board_source.duplicate() as Image
	# Scale to COVER the board (fill fully, crop the overflow), then center-crop to size.
	var cover := maxf(float(target.x) / image.get_width(), float(target.y) / image.get_height())
	image.resize(
		int(ceil(image.get_width() * cover)), int(ceil(image.get_height() * cover)),
		Image.INTERPOLATE_BILINEAR
	)
	var crop_offset := Vector2i((image.get_width() - target.x) / 2, (image.get_height() - target.y) / 2)
	var fitted := image.get_region(Rect2i(crop_offset, target))
	_round_image_corners(fitted, BOARD_CORNER_RADIUS)
	_board_bg = ImageTexture.create_from_image(fitted)


## Make the four corners of `image` transparent to a quarter-circle of `radius`, so the backdrop
## reads with rounded corners that match the board outline.
func _round_image_corners(image: Image, radius: int) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corners := [
		{"center": Vector2i(radius, radius), "dir": Vector2i(-1, -1)},
		{"center": Vector2i(w - radius, radius), "dir": Vector2i(1, -1)},
		{"center": Vector2i(radius, h - radius), "dir": Vector2i(-1, 1)},
		{"center": Vector2i(w - radius, h - radius), "dir": Vector2i(1, 1)},
	]
	for corner in corners:
		var center: Vector2i = corner["center"]
		var dir: Vector2i = corner["dir"]
		for offset_y in range(radius):
			for offset_x in range(radius):
				if Vector2(offset_x, offset_y).length() <= radius:
					continue
				var pixel := center + Vector2i(dir.x * offset_x, dir.y * offset_y)
				if pixel.x < 0 or pixel.y < 0 or pixel.x >= w or pixel.y >= h:
					continue
				var color := image.get_pixel(pixel.x, pixel.y)
				color.a = 0.0
				image.set_pixel(pixel.x, pixel.y, color)


## Draw the slingshot feedback: a thin connector from the launch point to the held ball, plus the
## FORCE WEDGE — a filled triangle with its POINT at the ball's launch location, fanning out to a
## WIDE far end in the DIRECTION OF TRAVEL (opposite the pull), like a beam showing where the ball
## will go. The wide end's width and the wedge's length grow with the pull's force, and its single
## color CHANGES with force (green → blue → purple → bright red), so the player reads both power and
## aim direction at a glance (Tim, 2026-06-30).
func _draw_aim_guide() -> void:
	var ball_pos: Vector2 = _balls[_aim_index]["pos"]
	var pull := ball_pos - _aim_anchor
	var pull_distance := pull.length()

	# A thin connector from the launch point to the held ball, so the pull itself is still visible.
	_play.draw_line(_aim_anchor, ball_pos, Color(UiPalette.NAVY, 0.5), 3.0, true)
	# A marker at the launch point — the ball's original spot, where it shoots from.
	_play.draw_circle(_aim_anchor, 6.0, Color(UiPalette.NAVY, 0.6))

	if pull_distance < MIN_PULL:
		return  # too short to be a throw — no force wedge yet

	# The force this pull will produce under the non-linear launch curve, so the wedge grows exactly
	# as the actual throw speed does (and maxes out when more pull would add nothing).
	var force := _throw_fraction(pull_distance)
	var travel_dir := -pull / pull_distance               # the ball flies OPPOSITE the pull
	var perp := Vector2(-travel_dir.y, travel_dir.x)       # wide-end spread, across the travel direction
	var wide_half := lerpf(AIM_WEDGE_BASE_MIN, AIM_WEDGE_BASE_MAX, force) * 0.5
	var wide_center := _aim_anchor + travel_dir * (pull_distance * AIM_WEDGE_LENGTH_SCALE)
	var wedge := PackedVector2Array([
		_aim_anchor,                          # POINT — at the ball's launch location
		wide_center + perp * wide_half,       # wide end, fanned out in the direction of travel
		wide_center - perp * wide_half,
	])
	_play.draw_colored_polygon(wedge, _force_color(force))


## Map a force fraction (0 = none, 1 = maxed) to the aim band's color ramp by walking the ordered
## FORCE_COLOR_RAMP stops: green → blue → purple → bright red across [0,1]. The ramp is split into
## equal segments (one per gap between stops), and the fraction is lerped within its segment.
func _force_color(fraction: float) -> Color:
	var stops := FORCE_COLOR_RAMP
	var segments := stops.size() - 1                       # gaps between the color stops
	var scaled := clampf(fraction, 0.0, 1.0) * float(segments)
	var index := mini(int(scaled), segments - 1)           # which segment we're in (clamped off the end)
	var local := scaled - float(index)                     # position within that segment, 0..1
	return (stops[index] as Color).lerp(stops[index + 1] as Color, local)


## Draw the celebration layer: the expanding/fading score rings from a made basket, then the basket
## confetti. Pure cosmetics; these read off _score_rings and _particles, which _advance_celebration
## grows and fades.
func _draw_celebration() -> void:
	# Score rings: a thin ring that expands outward from the hoop and fades as its life drains.
	for ring in _score_rings:
		var life: float = ring["life"]
		var radius := SCORE_RING_MAX_RADIUS * (1.0 - life)  # small at spawn (life 1) -> wide as it fades
		var ring_color := UiPalette.MUSTARD_GOLD
		ring_color.a = life  # fade out as it grows
		_play.draw_arc(ring["pos"], radius, 0.0, TAU, 32, ring_color, 4.0, true)

	# Basket confetti: little solid circles that fade with their life.
	for particle in _particles:
		var spark_color: Color = particle["color"]
		spark_color.a = clampf(particle["life"], 0.0, 1.0)
		_play.draw_circle(particle["pos"], particle["radius"], spark_color)


## Draw the waiting legacy gem (a gently bobbing, shimmering icon with a soft halo so it reads as a
## grabbable target), plus a brief expanding "win" ring at the spot right after one is collected.
func _draw_legacy_gem() -> void:
	if _legacy_gem_active:
		# A gentle vertical bob + a pulsing halo so the gem looks alive and invites a shot through it.
		var bob := sin(_legacy_gem_phase * 2.4) * 6.0
		var center := _legacy_gem_pos + Vector2(0.0, bob)
		var halo_pulse := 1.0 + 0.12 * sin(_legacy_gem_phase * 4.0)
		var halo := UiPalette.MUSTARD_GOLD
		halo.a = 0.28
		_play.draw_circle(center, LEGACY_GEM_RADIUS * 1.35 * halo_pulse, halo)
		# The gem icon itself, centered on the (bobbing) spot.
		var rect := Rect2(
			center - Vector2(LEGACY_GEM_RADIUS, LEGACY_GEM_RADIUS),
			Vector2(LEGACY_GEM_RADIUS * 2.0, LEGACY_GEM_RADIUS * 2.0)
		)
		_play.draw_texture_rect(LEGACY_GEM_TEX, rect, false)

	# The collect cue: a bright ring bursting outward from where the gem was, fading as it grows.
	if _legacy_gem_win_cue > 0.0:
		var life := _legacy_gem_win_cue
		var radius := LEGACY_GEM_RADIUS + (1.0 - life) * 90.0  # small at collect (life 1) -> wide as it fades
		var cue_color := UiPalette.MUSTARD_GOLD
		cue_color.a = life
		_play.draw_arc(_legacy_gem_pos, radius, 0.0, TAU, 28, cue_color, 5.0, true)


## Draw a simple backboard behind the hoop (Tim, 2026-07-07 request): a translucent white board with
## a dark frame and the classic shooter's square just above the rim. It tracks the drifting hoop
## (drawn relative to _hoop_pos). Purely cosmetic — the ball is NOT bounced off it; a shot still
## scores only by dropping through the rim (bank-shot collision could be a later addition).
func _draw_backboard() -> void:
	var width := HOOP_RX * 2.8
	var height := HOOP_RX * 1.6
	var bottom_y := _hoop_pos.y - HOOP_RY * 0.2   # just above the rim's back edge
	var board := Rect2(Vector2(_hoop_pos.x - width * 0.5, bottom_y - height), Vector2(width, height))
	_play.draw_rect(board, Color(1.0, 1.0, 1.0, 0.82), true)   # translucent white face
	_play.draw_rect(board, UiPalette.INK_NAVY, false, 4.0)     # dark frame
	# The shooter's square, centered horizontally, sitting just above the rim (rim-colored outline).
	var sq_w := HOOP_RX * 1.05
	var sq_h := HOOP_RX * 0.62
	var square := Rect2(Vector2(_hoop_pos.x - sq_w * 0.5, bottom_y - 10.0 - sq_h), Vector2(sq_w, sq_h))
	_play.draw_rect(square, UiPalette.ORANGE, false, 4.0)


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
