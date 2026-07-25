class_name StafferFace

# Procedural staffer portraits — the faces that fill a STAFFED property's ManagerCircle, replacing
# the single gray headshot placeholder (Plans/Layered_Staffer_Portrait_Generator.md; GDD §6.5).
#
# Every face is drawn from a SEED so a given role always looks the same wherever it appears (the
# row, and later the Will screen / obituary) and for the run's life. The seed folds in the current
# GENERATION, so each new dynasty's staff looks fresh while a manager stays stable within one run
# (Tim's call, 2026-07-25).
#
# The faces are VECTOR shapes drawn with the canvas's own draw_* primitives, not baked textures.
# That is deliberate: a dozen cheap shapes cost the same as the disc/ring/icon the circle already
# redraws every frame, so there is nothing to pre-bake or cache — and the face stays crisp at any
# size (the row disc, or a larger Will-screen portrait) with no rescaling.
#
# Only Earth (tier 1, human) faces exist so far. draw_face() returns false for any other tier, so
# the caller can fall back to the old headshot icon until the abstract alien treatments are built
# (the plan's phase 2).

## The living generation, pushed here by Main every frame (a plain assignment; no work when
## unchanged). Folded into every seed so faces refresh per dynasty. 1-based, like DynastyState.
static var generation: int = 1

# --- Curated palettes (content, kept on-style) --------------------------------------------------
# Skin and hair tones are natural ranges; clothing draws from the game's own UiPalette so staffers
# never introduce off-palette hues (plan §8, palette discipline).

const SKIN_TONES: Array[Color] = [
	Color("#F3D2B3"), Color("#E8B98F"), Color("#D69C6E"),
	Color("#B87A4F"), Color("#8D5A34"), Color("#5E3A22"),
]
const HAIR_TONES: Array[Color] = [
	Color("#241C15"), Color("#3E2A1A"), Color("#6B4A2A"),
	Color("#A9702F"), Color("#C9A24B"), Color("#8A8378"), Color("#7A2E1A"),
]

## Head + shoulders geometry, all as fractions of the face's bounding radius R. Tuned so every
## element stays inside the inscribed circle (no clipping needed): the collar's bottom edge is the
## disc arc itself, and the head/hair sit within R.
const HEAD_CX := 0.0
const HEAD_CY := -0.06     # head sits a touch above center to leave room for the collar
const HEAD_HW := 0.50      # head half-width
const HEAD_HH := 0.60      # head half-height
const COLLAR_CUT := 0.40   # everything below this y (× R) is shoulders/clothing
const NECK_HW := 0.15


## Draw the seeded face for `property_index` at epoch `tier` onto `canvas`, centered at `center`
## and sized to bounding radius `radius`. Returns true if a face was drawn, false if this tier has
## no face yet (caller should fall back to the headshot icon).
static func draw_face(canvas: CanvasItem, property_index: int, tier: int, center: Vector2, radius: float) -> bool:
	if tier != 1:
		return false  # only Earth humans exist yet; alien tiers fall back to the headshot

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(property_index, tier)

	# Pull every variant up front, in a FIXED order, so adding a future layer appends new draws
	# from the seed without shifting the ones already chosen (faces stay stable across updates).
	var skin: Color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	var hair: Color = HAIR_TONES[rng.randi() % HAIR_TONES.size()]
	var hair_style := rng.randi() % 5          # 0 bald · 1 short · 2 side-part · 3 swept · 4 bob
	var brow := rng.randi() % 2                 # 0 flat · 1 raised
	var facial_hair := 0
	if rng.randf() < 0.28:                       # most faces are clean-shaven
		facial_hair = 1 + rng.randi() % 2       # 1 mustache · 2 short beard
	if hair_style == 4:
		facial_hair = 0                          # keep the "bob" read feminine-neutral, no beard
	var clothing := rng.randi() % 3             # 0 suit+tie · 1 lab coat · 2 turtleneck
	var cloth_color: Color = _CLOTH_COLORS[rng.randi() % _CLOTH_COLORS.size()]
	var tie_color: Color = _TIE_COLORS[rng.randi() % _TIE_COLORS.size()]
	var glasses := rng.randf() < 0.33

	# --- draw back-to-front ---------------------------------------------------------------------
	_draw_collar(canvas, center, radius, clothing, cloth_color, tie_color, skin)
	_draw_neck(canvas, center, radius, skin)
	if hair_style == 4:
		_draw_back_hair(canvas, center, radius, hair)   # the bob frames the face, so it goes behind
	_draw_head(canvas, center, radius, skin)
	_draw_ears(canvas, center, radius, skin)
	if hair_style != 0:
		_draw_top_hair(canvas, center, radius, hair, hair_style)
	_draw_features(canvas, center, radius, brow, hair)
	if facial_hair != 0:
		_draw_facial_hair(canvas, center, radius, facial_hair, hair)
	if glasses:
		_draw_glasses(canvas, center, radius)
	return true


## The role's stable seed: property + tier + generation, combined with the classic large-prime
## spatial hash so nearby roles don't produce lookalike faces.
static func seed_for(property_index: int, tier: int) -> int:
	return (property_index * 73856093) ^ (tier * 19349663) ^ (generation * 83492791)


# --- clothing palettes (game colors only) -------------------------------------------------------
const _CLOTH_COLORS: Array[Color] = [
	UiPalette.NAVY, UiPalette.KETCHUP_RED, UiPalette.DARK_MONEY_GREEN,
	UiPalette.DARK_GOLD, UiPalette.BRICK, UiPalette.INK_NAVY,
]
const _TIE_COLORS: Array[Color] = [
	UiPalette.MUSTARD_GOLD, UiPalette.KETCHUP_RED, UiPalette.ATOMIC_TEAL, UiPalette.CREAM,
]


# --- layer draws --------------------------------------------------------------------------------

## The shoulders: the circular segment of the disc below COLLAR_CUT, filled in the clothing color,
## then a per-style collar detail (a shirt V + optional tie, a lab-coat lapel, or a plain turtle).
static func _draw_collar(canvas: CanvasItem, c: Vector2, r: float, style: int, cloth: Color, tie: Color, skin: Color) -> void:
	var cut_y := c.y + COLLAR_CUT * r
	canvas.draw_colored_polygon(_disc_segment_below(c, r, COLLAR_CUT), cloth)

	if style == 2:
		# Turtleneck: a rounded clothing collar rising to the chin — just a filled circle cap.
		canvas.draw_circle(Vector2(c.x, cut_y), NECK_HW * r * 1.7, cloth)
		return

	# Suit / lab coat both open into a V of shirt below the neck.
	var v_top := Vector2(c.x, cut_y - 0.02 * r)
	var v_w := 0.20 * r
	var v_bottom := c.y + 0.9 * r
	var shirt := UiPalette.CREAM
	canvas.draw_colored_polygon(PackedVector2Array([
		v_top, Vector2(c.x - v_w, v_bottom), Vector2(c.x + v_w, v_bottom),
	]), shirt)

	if style == 0:
		# Suit: a tie stripe down the shirt V.
		var t_w := 0.06 * r
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x, cut_y + 0.04 * r),
			Vector2(c.x - t_w, v_bottom), Vector2(c.x + t_w, v_bottom),
		]), tie)
	else:
		# Lab coat: a thin collar line where the coat meets the shirt.
		canvas.draw_line(Vector2(c.x - 0.30 * r, cut_y), v_top, cloth.darkened(0.15), maxf(1.5, 0.03 * r))
		canvas.draw_line(Vector2(c.x + 0.30 * r, cut_y), v_top, cloth.darkened(0.15), maxf(1.5, 0.03 * r))


static func _draw_neck(canvas: CanvasItem, c: Vector2, r: float, skin: Color) -> void:
	var top := c.y + 0.10 * r
	var bottom := c.y + COLLAR_CUT * r + 0.04 * r
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - NECK_HW * r, top), Vector2(c.x + NECK_HW * r, top),
		Vector2(c.x + NECK_HW * r, bottom), Vector2(c.x - NECK_HW * r, bottom),
	]), skin.darkened(0.06))  # a hair darker than the face — the jaw's shadow


static func _draw_head(canvas: CanvasItem, c: Vector2, r: float, skin: Color) -> void:
	canvas.draw_colored_polygon(
		_ellipse(Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r), HEAD_HW * r, HEAD_HH * r, 28), skin)


static func _draw_ears(canvas: CanvasItem, c: Vector2, r: float, skin: Color) -> void:
	var ey := c.y + HEAD_CY * r + 0.04 * r
	canvas.draw_circle(Vector2(c.x - HEAD_HW * r, ey), 0.09 * r, skin)
	canvas.draw_circle(Vector2(c.x + HEAD_HW * r, ey), 0.09 * r, skin)


## The crown/hairline cap over the top of the head. The hairline shape sets the style.
static func _draw_top_hair(canvas: CanvasItem, c: Vector2, r: float, hair: Color, style: int) -> void:
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r)
	# A hair cap slightly larger than the head, clipped to a hairline that varies by style.
	var cap_hw := HEAD_HW * r * 1.06
	var cap_hh := HEAD_HH * r * 1.06
	var top := _ellipse(hc, cap_hw, cap_hh, 28)

	# Hairline y (below hc.y): how far down the forehead the hair reaches. Higher style index → more.
	var line_y := hc.y - 0.30 * r
	match style:
		1: line_y = hc.y - 0.30 * r   # short
		2: line_y = hc.y - 0.32 * r   # side part (with a notch, below)
		3: line_y = hc.y - 0.26 * r   # swept, a little lower
		4: line_y = hc.y - 0.10 * r   # bob, frames further down
	# Build the cap: the upper ellipse arc down to the hairline, closed by the hairline edge.
	var pts := PackedVector2Array()
	for p in top:
		if p.y <= line_y:
			pts.append(p)
	if pts.size() < 3:
		return
	# Close along the hairline. A side part lifts the hairline on one side for a parted look.
	var right_x := hc.x + cap_hw
	var left_x := hc.x - cap_hw
	if style == 2:
		pts.append(Vector2(right_x, line_y))
		pts.append(Vector2(hc.x + 0.10 * r, line_y - 0.05 * r))  # the part notch
		pts.append(Vector2(left_x, line_y - 0.02 * r))
	else:
		pts.append(Vector2(right_x, line_y))
		pts.append(Vector2(left_x, line_y))
	canvas.draw_colored_polygon(pts, hair)


## Hair that frames the face from behind (the bob) — a wider, taller ellipse drawn before the head.
static func _draw_back_hair(canvas: CanvasItem, c: Vector2, r: float, hair: Color) -> void:
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r + 0.05 * r)
	canvas.draw_colored_polygon(_ellipse(hc, HEAD_HW * r * 1.20, HEAD_HH * r * 1.14, 28), hair)


static func _draw_features(canvas: CanvasItem, c: Vector2, r: float, brow: int, hair: Color) -> void:
	var eye_y := c.y + HEAD_CY * r + 0.10 * r
	var eye_dx := 0.19 * r
	var eye_r := 0.052 * r
	var ink := UiPalette.INK_NAVY
	# Eyes: a dark oval each (a hair taller than wide reads more like an eye than a dot).
	for sx in [-1.0, 1.0]:
		canvas.draw_colored_polygon(_ellipse(Vector2(c.x + sx * eye_dx, eye_y), eye_r, eye_r * 1.25, 12), ink)
	# Brows: short strokes above the eyes, in the hair color. "Raised" tilts the inner ends up.
	var brow_y := eye_y - 0.13 * r
	var bw := 0.10 * r
	var tilt := (0.03 * r) if brow == 1 else 0.0
	var thick := maxf(2.0, 0.035 * r)
	for sx in [-1.0, 1.0]:
		var inner := Vector2(c.x + sx * (eye_dx - bw), brow_y - tilt)
		var outer := Vector2(c.x + sx * (eye_dx + bw), brow_y)
		canvas.draw_line(inner, outer, hair.darkened(0.1), thick)
	# Nose: a soft shadow line down to a small base.
	var nose_top := Vector2(c.x, eye_y + 0.05 * r)
	var nose_bot := Vector2(c.x + 0.03 * r, eye_y + 0.20 * r)
	canvas.draw_line(nose_top, nose_bot, UiPalette.INK_NAVY.lerp(Color.TRANSPARENT, 0.55), maxf(1.5, 0.025 * r))
	# Mouth: a short, calm line.
	var mouth_y := c.y + HEAD_CY * r + 0.36 * r
	canvas.draw_line(Vector2(c.x - 0.10 * r, mouth_y), Vector2(c.x + 0.10 * r, mouth_y),
		Color("#8A4A3A"), maxf(2.0, 0.035 * r))


static func _draw_facial_hair(canvas: CanvasItem, c: Vector2, r: float, kind: int, hair: Color) -> void:
	var mouth_y := c.y + HEAD_CY * r + 0.36 * r
	if kind == 1:
		# Mustache: a short bar just above the mouth.
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - 0.13 * r, mouth_y - 0.09 * r), Vector2(c.x + 0.13 * r, mouth_y - 0.09 * r),
			Vector2(c.x + 0.11 * r, mouth_y - 0.02 * r), Vector2(c.x - 0.11 * r, mouth_y - 0.02 * r),
		]), hair)
	else:
		# Short beard: a band hugging the jawline below the mouth.
		var jaw := c.y + HEAD_CY * r + HEAD_HH * r
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - 0.34 * r, mouth_y - 0.02 * r), Vector2(c.x + 0.34 * r, mouth_y - 0.02 * r),
			Vector2(c.x + 0.20 * r, jaw), Vector2(c.x - 0.20 * r, jaw),
		]), hair)


static func _draw_glasses(canvas: CanvasItem, c: Vector2, r: float) -> void:
	var eye_y := c.y + HEAD_CY * r + 0.10 * r
	var eye_dx := 0.19 * r
	var lens := 0.13 * r
	var frame := UiPalette.INK_NAVY
	var w := maxf(2.0, 0.03 * r)
	for sx in [-1.0, 1.0]:
		canvas.draw_arc(Vector2(c.x + sx * eye_dx, eye_y), lens, 0.0, TAU, 20, frame, w)
	# Bridge between the lenses.
	canvas.draw_line(Vector2(c.x - eye_dx + lens, eye_y), Vector2(c.x + eye_dx - lens, eye_y), frame, w)


# --- geometry helpers ---------------------------------------------------------------------------

## Points around an axis-aligned ellipse, for draw_colored_polygon.
static func _ellipse(center: Vector2, hw: float, hh: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		pts.append(Vector2(center.x + cos(a) * hw, center.y + sin(a) * hh))
	return pts


## The polygon of the disc's circular segment BELOW y = center.y + y_frac × radius — used for the
## shoulders so their bottom edge hugs the disc arc and nothing spills outside the circle.
static func _disc_segment_below(center: Vector2, radius: float, y_frac: float, samples := 24) -> PackedVector2Array:
	var cut := center.y + y_frac * radius
	# Angle where the horizontal cut meets the circle (measuring from the +x axis, y-down).
	var s := clampf(y_frac, -1.0, 1.0)
	var a0 := asin(s)                     # right-side intersection
	var a1 := PI - a0                     # left-side intersection
	var pts := PackedVector2Array([Vector2(center.x + cos(a0) * radius, cut)])
	for i in range(1, samples):
		var a := lerpf(a0, a1, float(i) / float(samples))
		pts.append(Vector2(center.x + cos(a) * radius, center.y + sin(a) * radius))
	pts.append(Vector2(center.x + cos(a1) * radius, cut))
	return pts
