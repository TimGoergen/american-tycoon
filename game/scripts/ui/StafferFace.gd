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
# EACH facial feature has its own small set of variants (eye shapes, brows, noses, mouths,
# hairstyles), picked independently from the seed, so faces read as distinct individuals rather
# than one template with different hair (Tim, 2026-07-25). Only Earth (tier 1, human) faces exist
# so far; draw_face() returns false for any other tier so the caller can fall back to the old
# headshot icon until the abstract alien treatments are built (the plan's phase 2).

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

const EYE_DX := 0.205      # eye spacing from center (× R)
const EYE_DY := 0.06       # eye line, below the head center (× R)
const INK := Color("#1B2436")


## Draw the seeded face for `property_index` at epoch `tier` onto `canvas`, centered at `center`
## and sized to bounding radius `radius`. Returns true if a face was drawn, false if this tier has
## no face yet (caller should fall back to the headshot icon).
static func draw_face(canvas: CanvasItem, property_index: int, tier: int, center: Vector2, radius: float) -> bool:
	if tier != 1:
		return false  # only Earth humans exist yet; alien tiers fall back to the headshot

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(property_index, tier)

	# Pull every variant up front, in a FIXED order, so adding a future feature appends new draws
	# from the seed without shifting the ones already chosen (faces stay stable across updates).
	var skin: Color = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	var hair: Color = HAIR_TONES[rng.randi() % HAIR_TONES.size()]
	var hair_style := rng.randi() % 8      # 0 bald·1 short·2 side-sweep·3 pompadour·4 flat-top·5 spiky·6 curly·7 mop
	var eye_shape := rng.randi() % 5        # 0 round·1 oval·2 almond·3 highlight·4 sleepy
	var brow_style := rng.randi() % 4       # 0 flat·1 raised·2 stern·3 arched
	var nose_style := rng.randi() % 4       # 0 soft·1 button·2 side·3 triangle
	var mouth_style := rng.randi() % 4      # 0 neutral·1 smile·2 slight frown·3 small
	var facial_hair := 0
	if rng.randf() < 0.26 and hair_style < 6:    # most clean-shaven; no beard under the big curly/mop
		facial_hair = 1 + rng.randi() % 3        # 1 mustache·2 beard·3 goatee
	var clothing := rng.randi() % 4         # 0 suit+tie·1 lab coat·2 turtleneck·3 open collar
	var cloth_color: Color = _CLOTH_COLORS[rng.randi() % _CLOTH_COLORS.size()]
	var tie_color: Color = _TIE_COLORS[rng.randi() % _TIE_COLORS.size()]
	var glasses := rng.randf() < 0.33
	var glasses_square := rng.randi() % 2 == 0

	# --- draw back-to-front ---------------------------------------------------------------------
	_draw_collar(canvas, center, radius, clothing, cloth_color, tie_color)
	_draw_neck(canvas, center, radius, skin)
	_draw_head(canvas, center, radius, skin)
	_draw_ears(canvas, center, radius, skin)
	_draw_hair(canvas, center, radius, hair, hair_style)
	_draw_brows(canvas, center, radius, brow_style, hair)
	_draw_eyes(canvas, center, radius, eye_shape)
	_draw_nose(canvas, center, radius, nose_style, skin)
	# Facial hair goes on BEFORE the mouth so the mouth/lips draw on top of a beard (a beard that
	# hides the mouth reads as a mask over the lower face, not as hair — Tim, 2026-07-25).
	if facial_hair != 0:
		_draw_facial_hair(canvas, center, radius, facial_hair, hair)
	_draw_mouth(canvas, center, radius, mouth_style)
	if glasses:
		_draw_glasses(canvas, center, radius, glasses_square)
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


# --- clothing / head layers ---------------------------------------------------------------------

## The shoulders: the circular segment of the disc below COLLAR_CUT, filled in the clothing color,
## then a per-style collar detail (suit + tie, lab-coat lapels, turtleneck, or an open collar).
static func _draw_collar(canvas: CanvasItem, c: Vector2, r: float, style: int, cloth: Color, tie: Color) -> void:
	var cut_y := c.y + COLLAR_CUT * r
	canvas.draw_colored_polygon(_disc_segment_below(c, r, COLLAR_CUT), cloth)

	if style == 2:
		# Turtleneck: a rounded clothing collar rising to the chin — just a filled circle cap.
		canvas.draw_circle(Vector2(c.x, cut_y), NECK_HW * r * 1.7, cloth)
		return

	# Suit / lab coat / open collar all open into a V of shirt below the neck.
	var v_top := Vector2(c.x, cut_y - 0.02 * r)
	var v_w := 0.20 * r
	var v_bottom := c.y + 0.9 * r
	canvas.draw_colored_polygon(PackedVector2Array([
		v_top, Vector2(c.x - v_w, v_bottom), Vector2(c.x + v_w, v_bottom),
	]), UiPalette.CREAM)

	match style:
		0:
			# Suit: a tie stripe down the shirt V.
			var t_w := 0.06 * r
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, cut_y + 0.04 * r),
				Vector2(c.x - t_w, v_bottom), Vector2(c.x + t_w, v_bottom),
			]), tie)
		1:
			# Lab coat: thin collar lines where the coat meets the shirt.
			var edge := cloth.darkened(0.15)
			canvas.draw_line(Vector2(c.x - 0.30 * r, cut_y), v_top, edge, maxf(1.5, 0.03 * r))
			canvas.draw_line(Vector2(c.x + 0.30 * r, cut_y), v_top, edge, maxf(1.5, 0.03 * r))
		3:
			# Open collar: two shirt-colored lapels flaring off the V.
			canvas.draw_colored_polygon(PackedVector2Array([
				v_top, Vector2(c.x - 0.14 * r, cut_y + 0.02 * r), Vector2(c.x - 0.02 * r, v_top.y + 0.16 * r),
			]), UiPalette.CREAM.darkened(0.06))
			canvas.draw_colored_polygon(PackedVector2Array([
				v_top, Vector2(c.x + 0.14 * r, cut_y + 0.02 * r), Vector2(c.x + 0.02 * r, v_top.y + 0.16 * r),
			]), UiPalette.CREAM.darkened(0.06))


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


# --- hair -------------------------------------------------------------------------------------

## Hair as a distinct CARTOON SHAPE with its own silhouette — not a dome clipped to the skull. Some
## styles rise well above the head (pompadour, flat-top, spiky), one is a wide puff (curly), one is
## a mop with real volume down to ear level. The one hard rule learned the hard way: hair must not
## trace the face all the way to the jaw, or it reads as a hood/mask (Tim, 2026-07-25). All shapes
## stop at or above ear level, so the cheeks and jaw stay skin. Points are head-radius fractions.
static func _draw_hair(canvas: CanvasItem, c: Vector2, r: float, hair: Color, style: int) -> void:
	if style == 0:
		return  # bald
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r)
	var shine := hair.lightened(0.18)  # a soft cartoon sheen streak on the crown
	match style:
		1:  # short back-and-sides with a small forehead dip and sideburns
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.49, -0.02), Vector2(-0.52, -0.38), Vector2(-0.30, -0.62), Vector2(0, -0.68),
				Vector2(0.30, -0.62), Vector2(0.52, -0.38), Vector2(0.49, -0.02),
				Vector2(0.30, -0.30), Vector2(0, -0.36), Vector2(-0.30, -0.30)]), hair)
			_hair_shine(canvas, hc, r, shine, -0.22, -0.46)
		2:  # side sweep: piled higher on the left, a diagonal fringe across the brow
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.50, -0.06), Vector2(-0.54, -0.46), Vector2(-0.22, -0.74), Vector2(0.22, -0.66),
				Vector2(0.50, -0.42), Vector2(0.47, -0.12),
				Vector2(0.34, -0.36), Vector2(-0.05, -0.26), Vector2(-0.30, -0.40), Vector2(-0.46, -0.30)]), hair)
			_hair_shine(canvas, hc, r, shine, -0.18, -0.52)
		3:  # pompadour: a tall rounded wave rising above the front of the head
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.46, -0.06), Vector2(-0.50, -0.40), Vector2(-0.30, -0.74), Vector2(-0.02, -0.92),
				Vector2(0.24, -0.84), Vector2(0.44, -0.56), Vector2(0.45, -0.06),
				Vector2(0.30, -0.34), Vector2(0, -0.40), Vector2(-0.28, -0.36)]), hair)
			_hair_shine(canvas, hc, r, shine, -0.10, -0.66)
		4:  # flat top: a boxy, squared-off crown
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.45, -0.04), Vector2(-0.47, -0.72), Vector2(-0.34, -0.80), Vector2(0.34, -0.80),
				Vector2(0.47, -0.72), Vector2(0.45, -0.04),
				Vector2(0.30, -0.32), Vector2(0, -0.34), Vector2(-0.30, -0.32)]), hair)
			_hair_shine(canvas, hc, r, shine, -0.22, -0.66)
		5:  # spiky: alternating tall/short points across the crown
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.48, -0.04), Vector2(-0.50, -0.36),
				Vector2(-0.44, -0.80), Vector2(-0.30, -0.46), Vector2(-0.16, -0.88), Vector2(-0.02, -0.50),
				Vector2(0.14, -0.90), Vector2(0.28, -0.48), Vector2(0.44, -0.80),
				Vector2(0.50, -0.36), Vector2(0.48, -0.04),
				Vector2(0.30, -0.32), Vector2(0, -0.34), Vector2(-0.30, -0.32)]), hair)
		6:  # curly / afro: a wide puff built from overlapping lobes
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.52, -0.04), Vector2(-0.56, -0.42), Vector2(0, -0.72), Vector2(0.56, -0.42),
				Vector2(0.52, -0.04), Vector2(0.30, -0.24), Vector2(0, -0.28), Vector2(-0.30, -0.24)]), hair)
			for lobe in [Vector2(0, -0.66), Vector2(-0.32, -0.60), Vector2(0.32, -0.60),
					Vector2(-0.52, -0.34), Vector2(0.52, -0.34), Vector2(-0.48, -0.04), Vector2(0.48, -0.04)]:
				canvas.draw_circle(Vector2(hc.x + lobe.x * r, hc.y + lobe.y * r), 0.20 * r, hair)
		7:  # mop / bowl: full, rounded, wider than the skull, ending in a bowl line at the brow
			canvas.draw_colored_polygon(_pts(hc, r, [
				Vector2(-0.52, 0.00), Vector2(-0.56, -0.42), Vector2(-0.28, -0.68), Vector2(0, -0.72),
				Vector2(0.28, -0.68), Vector2(0.56, -0.42), Vector2(0.52, 0.00),
				Vector2(0.34, -0.16), Vector2(0.12, -0.24), Vector2(-0.12, -0.24), Vector2(-0.34, -0.16)]), hair)
			_hair_shine(canvas, hc, r, shine, -0.20, -0.52)


## Map an array of head-radius-fraction points to canvas coordinates for a hair polygon.
static func _pts(hc: Vector2, r: float, local: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in local:
		out.append(Vector2(hc.x + v.x * r, hc.y + v.y * r))
	return out


## A small soft highlight streak on the crown, centered at the given fraction offset — the flat
## cartoon "sheen" that keeps the hair from reading as one solid blob.
static func _hair_shine(canvas: CanvasItem, hc: Vector2, r: float, color: Color, fx: float, fy: float) -> void:
	canvas.draw_colored_polygon(_ellipse(Vector2(hc.x + fx * r, hc.y + fy * r), 0.16 * r, 0.07 * r, 14), color)


# --- facial features (each with variants so faces read as individuals) --------------------------

static func _draw_eyes(canvas: CanvasItem, c: Vector2, r: float, shape: int) -> void:
	var eye_y := c.y + HEAD_CY * r + EYE_DY * r
	for sx in [-1.0, 1.0]:
		var e := Vector2(c.x + sx * EYE_DX * r, eye_y)
		match shape:
			0:  # round
				canvas.draw_circle(e, 0.088 * r, INK)
			1:  # tall oval
				canvas.draw_colored_polygon(_ellipse(e, 0.072 * r, 0.10 * r, 16), INK)
			2:  # wide almond
				canvas.draw_colored_polygon(_ellipse(e, 0.10 * r, 0.072 * r, 16), INK)
			3:  # round with a catch-light
				canvas.draw_circle(e, 0.092 * r, INK)
				canvas.draw_circle(e + Vector2(0.03 * r, -0.03 * r), 0.028 * r, UiPalette.CREAM)
			4:  # sleepy: a thick relaxed lid line
				canvas.draw_line(e - Vector2(0.085 * r, 0), e + Vector2(0.085 * r, 0), INK, maxf(3.0, 0.055 * r))


static func _draw_brows(canvas: CanvasItem, c: Vector2, r: float, style: int, hair: Color) -> void:
	var by := c.y + HEAD_CY * r + (EYE_DY - 0.15) * r
	var col := hair.darkened(0.12)
	var th := maxf(2.5, 0.042 * r)
	var half := 0.085 * r
	for sx in [-1.0, 1.0]:
		var inner := Vector2(c.x + sx * (EYE_DX * r - half), by)
		var outer := Vector2(c.x + sx * (EYE_DX * r + half), by)
		match style:
			0:  # flat
				canvas.draw_line(inner, outer, col, th)
			1:  # raised: inner ends lifted
				canvas.draw_line(inner - Vector2(0, 0.04 * r), outer, col, th)
			2:  # stern: inner ends dropped
				canvas.draw_line(inner + Vector2(0, 0.035 * r), outer, col, th)
			3:  # arched: a shallow curve over the eye
				var mid := Vector2((inner.x + outer.x) / 2.0, by - 0.045 * r)
				canvas.draw_polyline(PackedVector2Array([inner, mid, outer]), col, th)


static func _draw_nose(canvas: CanvasItem, c: Vector2, r: float, style: int, skin: Color) -> void:
	var nx := c.x
	var ny := c.y + HEAD_CY * r + EYE_DY * r
	var col := skin.darkened(0.18)
	match style:
		0:  # soft: a short shadow under the tip
			canvas.draw_line(Vector2(nx - 0.035 * r, ny + 0.15 * r), Vector2(nx + 0.035 * r, ny + 0.15 * r), col, maxf(2.0, 0.03 * r))
		1:  # button: a small rounded tip
			canvas.draw_circle(Vector2(nx, ny + 0.13 * r), 0.034 * r, col)
		2:  # side line: a short bridge line, one side
			canvas.draw_line(Vector2(nx + 0.015 * r, ny + 0.02 * r), Vector2(nx + 0.02 * r, ny + 0.15 * r), col, maxf(2.0, 0.028 * r))
		3:  # small triangle
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(nx - 0.035 * r, ny + 0.14 * r), Vector2(nx + 0.035 * r, ny + 0.14 * r), Vector2(nx, ny + 0.19 * r),
			]), col)


static func _draw_mouth(canvas: CanvasItem, c: Vector2, r: float, style: int) -> void:
	var mx := c.x
	var my := c.y + HEAD_CY * r + 0.35 * r
	var col := Color("#8A4A3A")
	var th := maxf(2.5, 0.042 * r)
	match style:
		0:  # neutral line
			canvas.draw_line(Vector2(mx - 0.10 * r, my), Vector2(mx + 0.10 * r, my), col, th)
		1:  # smile: the lower arc of a circle centered just above
			canvas.draw_arc(Vector2(mx, my - 0.05 * r), 0.12 * r, deg_to_rad(25), deg_to_rad(155), 14, col, th)
		2:  # slight frown: the upper arc of a circle centered just below
			canvas.draw_arc(Vector2(mx, my + 0.07 * r), 0.11 * r, deg_to_rad(205), deg_to_rad(335), 14, col, th)
		3:  # small: a short, softer mark
			canvas.draw_line(Vector2(mx - 0.055 * r, my), Vector2(mx + 0.055 * r, my), col, maxf(3.0, 0.05 * r))


static func _draw_facial_hair(canvas: CanvasItem, c: Vector2, r: float, kind: int, hair: Color) -> void:
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r)  # head center
	var my := hc.y + 0.35 * r                                # mouth line
	match kind:
		1:  # mustache: a short bar just above the mouth
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 0.13 * r, my - 0.10 * r), Vector2(c.x + 0.13 * r, my - 0.10 * r),
				Vector2(c.x + 0.11 * r, my - 0.02 * r), Vector2(c.x - 0.11 * r, my - 0.02 * r),
			]), hair)
		2:
			# Full beard: hugs the jaw from sideburn to sideburn (so it reads as facial hair CONNECTED
			# to the head, not a floating band) with a top edge that follows below the nose. The mouth
			# is drawn on top afterward, so the lips show through. Points: down the left jaw to the
			# chin, up the right jaw to the right sideburn, then back across the upper beard line.
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(hc.x - 0.50 * r, hc.y + 0.04 * r),  # left sideburn (at the ear)
				Vector2(hc.x - 0.45 * r, hc.y + 0.28 * r),  # left cheek
				Vector2(hc.x - 0.36 * r, hc.y + 0.42 * r),  # left jaw
				Vector2(hc.x - 0.22 * r, hc.y + 0.54 * r),
				Vector2(hc.x + 0.00 * r, hc.y + 0.60 * r),  # chin
				Vector2(hc.x + 0.22 * r, hc.y + 0.54 * r),
				Vector2(hc.x + 0.36 * r, hc.y + 0.42 * r),  # right jaw
				Vector2(hc.x + 0.45 * r, hc.y + 0.28 * r),  # right cheek
				Vector2(hc.x + 0.50 * r, hc.y + 0.04 * r),  # right sideburn
				Vector2(hc.x + 0.30 * r, hc.y + 0.20 * r),  # upper beard line, back across
				Vector2(hc.x + 0.12 * r, hc.y + 0.27 * r),
				Vector2(hc.x + 0.00 * r, hc.y + 0.28 * r),  # dips just below the nose
				Vector2(hc.x - 0.12 * r, hc.y + 0.27 * r),
				Vector2(hc.x - 0.30 * r, hc.y + 0.20 * r),
			]), hair)
		3:  # goatee: a small tuft on the chin, below the mouth
			var chin := hc.y + HEAD_HH * r
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 0.09 * r, my + 0.04 * r), Vector2(c.x + 0.09 * r, my + 0.04 * r),
				Vector2(c.x + 0.05 * r, chin), Vector2(c.x - 0.05 * r, chin),
			]), hair)


static func _draw_glasses(canvas: CanvasItem, c: Vector2, r: float, square: bool) -> void:
	var eye_y := c.y + HEAD_CY * r + EYE_DY * r
	var lens := 0.135 * r
	var w := maxf(2.0, 0.03 * r)
	for sx in [-1.0, 1.0]:
		var e := Vector2(c.x + sx * EYE_DX * r, eye_y)
		if square:
			var box := Rect2(e - Vector2(lens, lens * 0.85), Vector2(lens * 2.0, lens * 1.7))
			canvas.draw_rect(box, INK, false, w)
		else:
			canvas.draw_arc(e, lens, 0.0, TAU, 22, INK, w)
	canvas.draw_line(Vector2(c.x - EYE_DX * r + lens, eye_y), Vector2(c.x + EYE_DX * r - lens, eye_y), INK, w)


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
	var s := clampf(y_frac, -1.0, 1.0)
	var a0 := asin(s)                     # right-side intersection
	var a1 := PI - a0                     # left-side intersection
	var pts := PackedVector2Array([Vector2(center.x + cos(a0) * radius, cut)])
	for i in range(1, samples):
		var a := lerpf(a0, a1, float(i) / float(samples))
		pts.append(Vector2(center.x + cos(a) * radius, center.y + sin(a) * radius))
	pts.append(Vector2(center.x + cos(a1) * radius, cut))
	return pts
