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
# than one template with different hair (Tim, 2026-07-25). Earth's two epochs (tiers 1-2, the
# Blue/White Collar split) draw human faces; every alien tier (3-27) draws its own bespoke being.
# draw_face() still returns false for any tier with no treatment, so a future tier 28+ falls back
# to the old headshot icon rather than drawing nothing.
#
# WITHIN a civ, members must differ by SHAPE, not just palette (Tim, 2026-07-30): each alien draws
# its head half-width and half-height from independent rolls and picks one of three genuinely
# different silhouette constructions, so two staffers of the same civ are told apart at a glance in
# a small disc. Varying only color and a feature count — the batch-1 civs' original approach — read
# as one template recolored.

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
	if tier > 2:
		# Alien epochs (tier 3+ since the Earth split): each civilization has its own bespoke
		# procedural "being" (Phase 2). Tiers without one built yet return false so the caller
		# falls back to the headshot.
		return _draw_alien(canvas, property_index, tier, center, radius)
	# Tiers 1-2 are the Earth split's Blue/White Collar epochs — both human faces. The tier
	# feeds the seed below, so a property's White Collar-era staffer is a DIFFERENT person
	# than its Blue Collar-era one for free.

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
	if rng.randf() < 0.32:                       # most faces clean-shaven
		facial_hair = 1 + rng.randi() % 8        # 1 'stache·2 beard·3 long·4 bushy·5 ducktail·6 goatee·7 van dyke·8 stubble
		if hair_style >= 6 and facial_hair >= 2 and facial_hair <= 5:  # a big beard under curly/mop can look enclosing
			facial_hair = 6                      # → a goatee instead
	var clothing := rng.randi() % 7         # 0 suit·1 lab coat·2 turtleneck·3 open collar·4 bow tie·5 sweater vest·6 crew tee
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
		_draw_facial_hair(canvas, center, radius, facial_hair, hair, skin)
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

## The shoulders: the circular segment of the disc below COLLAR_CUT in the clothing color, then a
## per-style collar detail (suit + tie, lab coat, turtleneck, open collar, bow tie, sweater vest, or
## a crew-neck tee).
static func _draw_collar(canvas: CanvasItem, c: Vector2, r: float, style: int, cloth: Color, tie: Color) -> void:
	var cut_y := c.y + COLLAR_CUT * r
	canvas.draw_colored_polygon(_disc_segment_below(c, r, COLLAR_CUT), cloth)

	# Styles with a SOLID neckline (no shirt V showing).
	if style == 2:
		# Turtleneck: a rounded clothing collar rising to the chin.
		canvas.draw_circle(Vector2(c.x, cut_y), NECK_HW * r * 1.7, cloth)
		return
	if style == 6:
		# Crew-neck tee: a ribbed round neckline arc, no shirt beneath.
		canvas.draw_arc(Vector2(c.x, cut_y - 0.04 * r), 0.24 * r, deg_to_rad(200), deg_to_rad(340),
				16, cloth.darkened(0.20), maxf(2.0, 0.035 * r))
		return

	# The rest open into a V of shirt below the neck.
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
		4:
			# Bow tie: two triangles meeting at a knot, at the base of the neck.
			var by := cut_y + 0.03 * r
			var bw := 0.15 * r
			var bh := 0.08 * r
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, by), Vector2(c.x - bw, by - bh), Vector2(c.x - bw, by + bh)]), tie)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, by), Vector2(c.x + bw, by - bh), Vector2(c.x + bw, by + bh)]), tie)
			canvas.draw_circle(Vector2(c.x, by), 0.04 * r, tie.darkened(0.2))
		5:
			# Sweater vest: a V-neck ribbing over the shirt, plus a tie.
			var rib := cloth.darkened(0.18)
			canvas.draw_line(Vector2(c.x - v_w, v_bottom), v_top, rib, maxf(2.0, 0.045 * r))
			canvas.draw_line(Vector2(c.x + v_w, v_bottom), v_top, rib, maxf(2.0, 0.045 * r))
			var t_w := 0.05 * r
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, cut_y + 0.04 * r),
				Vector2(c.x - t_w, v_bottom), Vector2(c.x + t_w, v_bottom),
			]), tie)


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


static func _draw_facial_hair(canvas: CanvasItem, c: Vector2, r: float, kind: int, hair: Color, skin: Color) -> void:
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r)  # head center
	var my := hc.y + 0.35 * r                                # mouth line
	match kind:
		1:  # thin mustache: a short bar just above the mouth
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 0.13 * r, my - 0.10 * r), Vector2(c.x + 0.13 * r, my - 0.10 * r),
				Vector2(c.x + 0.11 * r, my - 0.02 * r), Vector2(c.x - 0.11 * r, my - 0.02 * r),
			]), hair)
		2:  # full beard: hugs the jaw from sideburn to sideburn (connected to the head, not a
			# floating band). The mouth is drawn on top afterward, so the lips show through.
			canvas.draw_colored_polygon(_pts(hc, r, _beard_points()), hair)
		3:  # long beard: the full beard extended into a longer hang below the chin
			canvas.draw_colored_polygon(_pts(hc, r, _beard_long_points()), hair)
		4:  # bushy beard: wider and fuller, puffing past the jaw with a rounded bottom
			canvas.draw_colored_polygon(_pts(hc, r, _beard_bushy_points()), hair)
		5:  # ducktail beard: full on the sides, tapering to a point at the bottom
			canvas.draw_colored_polygon(_pts(hc, r, _beard_ducktail_points()), hair)
		6:  # goatee: a small tuft on the chin, below the mouth
			_draw_goatee(canvas, c, r, hair)
		7:  # van dyke: a goatee plus a separate mustache
			_draw_goatee(canvas, c, r, hair)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 0.12 * r, my - 0.10 * r), Vector2(c.x + 0.12 * r, my - 0.10 * r),
				Vector2(c.x + 0.10 * r, my - 0.03 * r), Vector2(c.x - 0.10 * r, my - 0.03 * r),
			]), hair)
		8:  # stubble: the beard region in a faint skin-shadow tone (a five-o'clock shadow)
			var stub := skin.darkened(0.34)
			stub.a = 0.5
			canvas.draw_colored_polygon(_pts(hc, r, _beard_points()), stub)


## The jaw-hugging full-beard outline, as head-radius fractions (shared by the full beard and the
## stubble shadow). Down the left jaw to the chin, up the right jaw to the sideburn, then back across
## the upper beard line, which dips just below the nose. The longer/bushier/ducktail beards below
## share that same upper-beard line and only change the outer (lower) silhouette.
static func _beard_points() -> Array:
	return [
		Vector2(-0.50, 0.04), Vector2(-0.45, 0.28), Vector2(-0.36, 0.42), Vector2(-0.22, 0.54),
		Vector2(0.00, 0.60), Vector2(0.22, 0.54), Vector2(0.36, 0.42), Vector2(0.45, 0.28),
		Vector2(0.50, 0.04), Vector2(0.30, 0.20), Vector2(0.12, 0.27), Vector2(0.00, 0.28),
		Vector2(-0.12, 0.27), Vector2(-0.30, 0.20),
	]


## Long beard — the sides run further down and the bottom hangs into a long rounded point below the
## chin (it laps over the top of the collar, as a real long beard would).
static func _beard_long_points() -> Array:
	return [
		Vector2(-0.50, 0.02), Vector2(-0.46, 0.32), Vector2(-0.40, 0.52), Vector2(-0.26, 0.68),
		Vector2(-0.12, 0.80), Vector2(0.00, 0.84), Vector2(0.12, 0.80), Vector2(0.26, 0.68),
		Vector2(0.40, 0.52), Vector2(0.46, 0.32), Vector2(0.50, 0.02),
		Vector2(0.30, 0.18), Vector2(0.12, 0.26), Vector2(0.00, 0.27), Vector2(-0.12, 0.26), Vector2(-0.30, 0.18),
	]


## Bushy beard — wider than the jaw and rounded, the full lumberjack read.
static func _beard_bushy_points() -> Array:
	return [
		Vector2(-0.56, 0.02), Vector2(-0.55, 0.30), Vector2(-0.46, 0.54), Vector2(-0.26, 0.68),
		Vector2(0.00, 0.72), Vector2(0.26, 0.68), Vector2(0.46, 0.54), Vector2(0.55, 0.30),
		Vector2(0.56, 0.02),
		Vector2(0.32, 0.16), Vector2(0.12, 0.24), Vector2(0.00, 0.25), Vector2(-0.12, 0.24), Vector2(-0.32, 0.16),
	]


## Ducktail beard — full on the sides, tapering to a single point at the bottom.
static func _beard_ducktail_points() -> Array:
	return [
		Vector2(-0.48, 0.04), Vector2(-0.44, 0.32), Vector2(-0.34, 0.48), Vector2(-0.16, 0.60),
		Vector2(0.00, 0.84), Vector2(0.16, 0.60), Vector2(0.34, 0.48), Vector2(0.44, 0.32),
		Vector2(0.48, 0.04),
		Vector2(0.30, 0.20), Vector2(0.12, 0.27), Vector2(0.00, 0.28), Vector2(-0.12, 0.27), Vector2(-0.30, 0.20),
	]


static func _draw_goatee(canvas: CanvasItem, c: Vector2, r: float, hair: Color) -> void:
	var hc := Vector2(c.x + HEAD_CX * r, c.y + HEAD_CY * r)
	var my := hc.y + 0.35 * r
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


# --- alien staffers (Phase 2: a bespoke procedural being per civilization) ----------------------

## Dispatch an alien portrait by epoch tier. Each civ has its own hand-tuned design + palette,
## seeded per role so staffers within one civ vary. Returns false for tiers not built yet (the
## caller then falls back to the gray headshot). Every alien tier (3-27) now has one, so the
## fallback is unreachable in normal play — it stays as the safety net for a future tier 28+.
static func _draw_alien(canvas: CanvasItem, property_index: int, tier: int, center: Vector2, radius: float) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(property_index, tier)
	match tier:
		3:
			_draw_luminari(canvas, center, radius, rng)
			return true
		4:
			_draw_geth(canvas, center, radius, rng)
			return true
		5:
			_draw_mycelium(canvas, center, radius, rng)
			return true
		6:
			_draw_quartzite(canvas, center, radius, rng)
			return true
		7:
			_draw_chronophage(canvas, center, radius, rng)
			return true
		8:
			_draw_vashti(canvas, center, radius, rng)
			return true
		9:
			_draw_ssethraki(canvas, center, radius, rng)
			return true
		10:
			_draw_melissar(canvas, center, radius, rng)
			return true
		11:
			_draw_norrvane(canvas, center, radius, rng)
			return true
		12:
			_draw_octave(canvas, center, radius, rng)
			return true
		13:
			_draw_umbrafex(canvas, center, radius, rng)
			return true
		14:
			_draw_karrghan(canvas, center, radius, rng)
			return true
		15:
			_draw_politesse(canvas, center, radius, rng)
			return true
		16:
			_draw_oneiroi(canvas, center, radius, rng)
			return true
		17:
			_draw_glossolalia(canvas, center, radius, rng)
			return true
		18:
			_draw_ferrovore(canvas, center, radius, rng)
			return true
		19:
			_draw_vantablack(canvas, center, radius, rng)
			return true
		20:
			_draw_fortuna(canvas, center, radius, rng)
			return true
		21:
			_draw_mirror(canvas, center, radius, rng)
			return true
		22:
			_draw_ossuary(canvas, center, radius, rng)
			return true
		23:
			_draw_spectacle(canvas, center, radius, rng)
			return true
		24:
			_draw_vektor(canvas, center, radius, rng)
			return true
		25:
			_draw_atlas(canvas, center, radius, rng)
			return true
		26:
			_draw_null_ledger(canvas, center, radius, rng)
			return true
		27:
			_draw_proprietors(canvas, center, radius, rng)
			return true
		_:
			return false


# Vashti Deep-Court (tier 8) — a bioluminescent deep-sea anglerfish being: a dark bulbous body, big
# glowing eyes, a toothy grin, and a glowing lure on a stalk (the signature). Everything is kept
# inside the bounding radius so no glow spills past the disc.
const _VASHTI_BODIES: Array[Color] = [
	Color("#123039"), Color("#14283a"), Color("#183a3a"), Color("#0f2e3e"), Color("#1a323a")]
const _VASHTI_GLOWS: Array[Color] = [
	Color(0.56, 0.93, 0.86), Color(0.5, 0.85, 0.98), Color(0.7, 0.95, 0.6), Color(0.9, 0.8, 0.98)]
const _VASHTI_EYE := Color("#dff6f0")
const _VASHTI_PUPIL := Color("#0a1c22")
const _VASHTI_TEETH := Color("#f2ead2")
const _VASHTI_MOUTH := Color("#07161b")

static func _draw_vashti(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# Per-role variation (fixed pull order).
	var body: Color = _VASHTI_BODIES[rng.randi() % _VASHTI_BODIES.size()]
	var hi := body.lightened(0.22)
	var glow: Color = _VASHTI_GLOWS[rng.randi() % _VASHTI_GLOWS.size()]
	var eye_r := (0.10 + rng.randf() * 0.035) * r
	var teeth_count := 3 + rng.randi() % 3
	var lure_side := -1.0 if rng.randf() < 0.5 else 1.0
	var spots := 2 + rng.randi() % 3
	var spot_seeds: Array[float] = []
	for _i in range(spots):
		spot_seeds.append(rng.randf())
		spot_seeds.append(rng.randf())

	var hc := Vector2(c.x, c.y - 0.05 * r)
	# Body/mantle: the disc's lower segment (hugs the arc, no spill), then the bulbous head.
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.30), body)
	canvas.draw_colored_polygon(_ellipse(hc, 0.54 * r, 0.55 * r, 28), hi)
	# Bioluminescent freckles on the head.
	for i in range(spots):
		var a := spot_seeds[i * 2] * TAU
		var rad := (0.18 + spot_seeds[i * 2 + 1] * 0.20) * r
		canvas.draw_circle(hc + Vector2(cos(a) * rad, sin(a) * rad * 0.9), 0.028 * r,
			glow.lerp(hi, 0.25))
	# Eyes: big, faintly glowing, dark pupils.
	for sx in [-1.0, 1.0]:
		var e := Vector2(hc.x + sx * 0.21 * r, hc.y - 0.02 * r)
		canvas.draw_circle(e, eye_r * 1.3, Color(glow.r, glow.g, glow.b, 0.30))
		canvas.draw_circle(e, eye_r, _VASHTI_EYE)
		canvas.draw_circle(e + Vector2(sx * 0.012 * r, 0.012 * r), eye_r * 0.5, _VASHTI_PUPIL)
	# Toothy grin: a wide dark mouth with cream fangs.
	var my := hc.y + 0.30 * r
	var mw := 0.30 * r
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - mw, my - 0.05 * r), Vector2(c.x + mw, my - 0.05 * r),
		Vector2(c.x + mw * 0.7, my + 0.10 * r), Vector2(c.x - mw * 0.7, my + 0.10 * r)]), _VASHTI_MOUTH)
	var tw := (mw * 2.0) / float(teeth_count)
	for i in range(teeth_count):
		var tx := c.x - mw + tw * (float(i) + 0.5)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(tx - tw * 0.28, my - 0.05 * r), Vector2(tx + tw * 0.28, my - 0.05 * r),
			Vector2(tx, my + 0.06 * r)]), _VASHTI_TEETH)
	# The lure: a stalk curving up-and-forward from the crown to a glowing bulb.
	var base := Vector2(hc.x + lure_side * 0.05 * r, hc.y - 0.50 * r)
	var mid := Vector2(hc.x + lure_side * 0.02 * r, hc.y - 0.66 * r)
	var tip := Vector2(hc.x + lure_side * 0.26 * r, hc.y - 0.70 * r)
	canvas.draw_polyline(PackedVector2Array([base, mid, tip]),
		hi.lerp(glow, 0.35), maxf(2.0, 0.03 * r))
	_glow(canvas, tip, 0.09 * r)


## A soft bioluminescent bulb: a translucent halo, a bright body, a hot core.
static func _glow(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius * 1.7, Color(0.56, 0.93, 0.86, 0.30))
	canvas.draw_circle(center, radius, Color(0.56, 0.93, 0.86, 0.92))
	canvas.draw_circle(center, radius * 0.5, Color(0.93, 1.0, 0.98, 1.0))


# Ssethraki Coil-Banks (tier 9) — a serpent: wedge head, slit-pupil eyes, forked tongue, coils.
const _SSE_SCALES: Array[Color] = [
	Color("#4f7942"), Color("#3f6b6a"), Color("#6a7a3a"), Color("#5a7050"), Color("#7a8a3a")]
const _SSE_EYES: Array[Color] = [Color("#e6c24a"), Color("#d97a2a"), Color("#9ac84a"), Color("#e05a5a")]
const _SSE_TONGUE := Color("#b5402a")
const _SSE_PUPIL := Color("#12200f")

static func _draw_ssethraki(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var scale: Color = _SSE_SCALES[rng.randi() % _SSE_SCALES.size()]
	var hi := scale.lightened(0.22)
	var dark := scale.darkened(0.3)
	var eye_col: Color = _SSE_EYES[rng.randi() % _SSE_EYES.size()]
	var slit_w := (0.018 + rng.randf() * 0.014) * r
	var tongue := (0.12 + rng.randf() * 0.10) * r
	var chevrons := 2 + rng.randi() % 3
	var hc := Vector2(c.x, c.y - 0.06 * r)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), dark)
	for i in range(2):
		canvas.draw_arc(Vector2(c.x, c.y + (0.52 + i * 0.16) * r), (0.40 - i * 0.10) * r,
			PI, TAU, 20, scale, maxf(3.0, 0.055 * r))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x - 0.50 * r, hc.y - 0.30 * r), Vector2(hc.x - 0.38 * r, hc.y - 0.52 * r),
		Vector2(hc.x + 0.38 * r, hc.y - 0.52 * r), Vector2(hc.x + 0.50 * r, hc.y - 0.30 * r),
		Vector2(hc.x + 0.28 * r, hc.y + 0.20 * r), Vector2(hc.x, hc.y + 0.44 * r),
		Vector2(hc.x - 0.28 * r, hc.y + 0.20 * r)]), scale)
	for i in range(chevrons):
		var yy := hc.y - 0.16 * r + i * 0.13 * r
		canvas.draw_polyline(PackedVector2Array([Vector2(hc.x - 0.13 * r, yy),
			Vector2(hc.x, yy + 0.06 * r), Vector2(hc.x + 0.13 * r, yy)]), hi, maxf(2.0, 0.02 * r))
	for sx in [-1.0, 1.0]:
		var e := Vector2(hc.x + sx * 0.26 * r, hc.y - 0.30 * r)
		canvas.draw_colored_polygon(_ellipse(e, 0.09 * r, 0.07 * r, 14), eye_col)
		canvas.draw_rect(Rect2(e.x - slit_w / 2.0, e.y - 0.055 * r, slit_w, 0.11 * r), _SSE_PUPIL)
	var sn := Vector2(hc.x, hc.y + 0.44 * r)
	var f := sn + Vector2(0, tongue * 0.6)
	canvas.draw_line(sn, f, _SSE_TONGUE, maxf(2.0, 0.02 * r))
	canvas.draw_line(f, f + Vector2(-0.05 * r, tongue * 0.4), _SSE_TONGUE, maxf(2.0, 0.02 * r))
	canvas.draw_line(f, f + Vector2(0.05 * r, tongue * 0.4), _SSE_TONGUE, maxf(2.0, 0.02 * r))


# Melissar Hive-Court (tier 10) — a bee: fuzzy striped body, compound eyes, antennae, sometimes a crown.
const _BEE_GOLDS: Array[Color] = [
	Color("#d3a52a"), Color("#c99038"), Color("#d8822a"), Color("#bfa63e"), Color("#caa020")]
const _BEE_DARK := Color("#3a2a0e")
const _BEE_EYE := Color("#1a1408")

static func _draw_melissar(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var gold: Color = _BEE_GOLDS[rng.randi() % _BEE_GOLDS.size()]
	var hi := gold.lightened(0.18)
	var ant_curl := (0.04 + rng.randf() * 0.07) * r
	var eye_h := (0.13 + rng.randf() * 0.05) * r
	var crown := rng.randf() < 0.4
	var hc := Vector2(c.x, c.y - 0.04 * r)
	# striped body via layered disc segments (each hugs the arc — no overflow)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.30), gold)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.44), _BEE_DARK)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.58), gold)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.72), _BEE_DARK)
	# antennae
	for sx in [-1.0, 1.0]:
		var a0 := Vector2(hc.x + sx * 0.12 * r, hc.y - 0.38 * r)
		var a1 := Vector2(hc.x + sx * 0.26 * r + sx * ant_curl, hc.y - 0.62 * r)
		canvas.draw_line(a0, a1, _BEE_DARK, maxf(2.0, 0.025 * r))
		canvas.draw_circle(a1, 0.04 * r, _BEE_DARK)
	# head
	canvas.draw_colored_polygon(_ellipse(hc, 0.42 * r, 0.42 * r, 24), hi)
	# compound eyes
	for sx in [-1.0, 1.0]:
		canvas.draw_colored_polygon(_ellipse(Vector2(hc.x + sx * 0.21 * r, hc.y - 0.02 * r),
			0.11 * r, eye_h, 16), _BEE_EYE)
	canvas.draw_line(Vector2(hc.x - 0.08 * r, hc.y + 0.22 * r),
		Vector2(hc.x + 0.08 * r, hc.y + 0.22 * r), _BEE_DARK, maxf(2.0, 0.03 * r))
	if crown:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x - 0.13 * r, hc.y - 0.40 * r), Vector2(hc.x - 0.13 * r, hc.y - 0.52 * r),
			Vector2(hc.x - 0.06 * r, hc.y - 0.46 * r), Vector2(hc.x, hc.y - 0.56 * r),
			Vector2(hc.x + 0.06 * r, hc.y - 0.46 * r), Vector2(hc.x + 0.13 * r, hc.y - 0.52 * r),
			Vector2(hc.x + 0.13 * r, hc.y - 0.40 * r)]), hi)


# Norrvane Frostholm (tier 11) — an ice giant: broad angular head, glowing cold eyes, an icicle beard.
const _ICE_BODIES: Array[Color] = [
	Color("#bcd8e6"), Color("#a9c6d8"), Color("#c8d2dc"), Color("#9fb8c8"), Color("#aecbe4")]
const _ICE_EYES: Array[Color] = [Color("#9fe8ff"), Color("#c0f0ff"), Color("#8fd0ff"), Color("#b8e0d0")]

static func _draw_norrvane(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var ice: Color = _ICE_BODIES[rng.randi() % _ICE_BODIES.size()]
	var dark := ice.darkened(0.30)
	var hi := ice.lightened(0.15)
	var eye_col: Color = _ICE_EYES[rng.randi() % _ICE_EYES.size()]
	var icicles := 4 + rng.randi() % 4
	var rune := rng.randf() < 0.5
	var eye_r := (0.030 + rng.randf() * 0.014) * r
	var hc := Vector2(c.x, c.y - 0.06 * r)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), dark)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x - 0.46 * r, hc.y - 0.32 * r), Vector2(hc.x - 0.32 * r, hc.y - 0.54 * r),
		Vector2(hc.x + 0.32 * r, hc.y - 0.54 * r), Vector2(hc.x + 0.46 * r, hc.y - 0.32 * r),
		Vector2(hc.x + 0.38 * r, hc.y + 0.14 * r), Vector2(hc.x, hc.y + 0.34 * r),
		Vector2(hc.x - 0.38 * r, hc.y + 0.14 * r)]), ice)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x - 0.40 * r, hc.y - 0.18 * r), Vector2(hc.x + 0.40 * r, hc.y - 0.18 * r),
		Vector2(hc.x + 0.32 * r, hc.y - 0.06 * r), Vector2(hc.x - 0.32 * r, hc.y - 0.06 * r)]), dark)
	for sx in [-1.0, 1.0]:
		var e := Vector2(hc.x + sx * 0.19 * r, hc.y)
		canvas.draw_circle(e, eye_r * 1.8, Color(eye_col.r, eye_col.g, eye_col.b, 0.4))
		canvas.draw_circle(e, eye_r, eye_col)
	var jaw := hc.y + 0.28 * r
	for i in range(icicles):
		var ix := hc.x - 0.26 * r + (0.52 * r) * (float(i) / float(maxi(1, icicles - 1)))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(ix - 0.05 * r, jaw),
			Vector2(ix + 0.05 * r, jaw), Vector2(ix, jaw + (0.12 + 0.06 * float(i % 2)) * r)]), hi)
	if rune:
		canvas.draw_line(Vector2(hc.x, hc.y - 0.44 * r), Vector2(hc.x, hc.y - 0.28 * r), eye_col, maxf(2.0, 0.02 * r))
		canvas.draw_line(Vector2(hc.x, hc.y - 0.40 * r), Vector2(hc.x + 0.06 * r, hc.y - 0.33 * r), eye_col, maxf(2.0, 0.02 * r))


# The Resonant Octave (tier 12) — a living sound-being: soundwave rings, glowing eyes, equalizer voice.
const _OCT_BODIES: Array[Color] = [
	Color("#5a52a8"), Color("#6a4a9e"), Color("#4a5aa8"), Color("#7050a0"), Color("#4e56a4")]
const _OCT_GLOWS: Array[Color] = [Color("#c8c0f5"), Color("#a8dcf0"), Color("#e0b0ec"), Color("#b8f0d0")]

static func _draw_octave(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var body: Color = _OCT_BODIES[rng.randi() % _OCT_BODIES.size()]
	var hi := body.lightened(0.28)
	var glow: Color = _OCT_GLOWS[rng.randi() % _OCT_GLOWS.size()]
	var bars := 4 + rng.randi() % 3
	var rings := 2 + rng.randi() % 2
	var bar_seed: Array[float] = []
	for _i in range(bars):
		bar_seed.append(rng.randf())
	var hc := Vector2(c.x, c.y - 0.04 * r)
	for i in range(rings):
		var rr := (0.52 + float(i) * 0.16) * r
		canvas.draw_arc(hc, rr, deg_to_rad(205), deg_to_rad(335), 24,
			Color(glow.r, glow.g, glow.b, 0.5 - float(i) * 0.14), maxf(2.0, 0.02 * r))
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), body)
	canvas.draw_colored_polygon(_ellipse(hc, 0.44 * r, 0.46 * r, 24), hi)
	for sx in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(hc.x + sx * 0.17 * r, hc.y - 0.08 * r), 0.05 * r, glow)
	var bw := (0.5 * r) / float(bars)
	for i in range(bars):
		var bx := hc.x - 0.25 * r + bw * (float(i) + 0.5)
		var bh := (0.05 + bar_seed[i] * 0.16) * r
		canvas.draw_rect(Rect2(bx - bw * 0.3, hc.y + 0.24 * r - bh, bw * 0.6, bh), glow)


# Luminari Collective (tier 3) — a radiant light-being: an orb head with rays and a bright core.
const _LUM_BODIES: Array[Color] = [Color("#c96a12"), Color("#d97a1a"), Color("#b85c0e"), Color("#e08a22")]
const _LUM_RAY := Color("#ffdf8a")
const _LUM_INK := Color("#3a1e05")

static func _draw_luminari(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var body: Color = _LUM_BODIES[rng.randi() % _LUM_BODIES.size()]
	var rays := 6 + rng.randi() % 7
	var ray_style := rng.randi() % 3          # straight · wavy · spike
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var core := (0.24 + rng.randf() * 0.12) * r
	var ray_col := _LUM_RAY.lerp(body, rng.randf() * 0.3)
	for i in range(rays):
		var a := TAU * float(i) / float(rays)
		var d := Vector2(cos(a), sin(a))
		var perp := Vector2(-d.y, d.x)
		match ray_style:
			0:
				canvas.draw_line(c + d * 0.60 * r, c + d * 0.92 * r, ray_col, maxf(2.0, 0.035 * r))
			1:
				canvas.draw_polyline(PackedVector2Array([c + d * 0.60 * r,
					c + d * 0.76 * r + perp * 0.05 * r, c + d * 0.92 * r]), ray_col, maxf(2.0, 0.03 * r))
			2:
				canvas.draw_colored_polygon(PackedVector2Array([c + d * 0.58 * r + perp * 0.06 * r,
					c + d * 0.58 * r - perp * 0.06 * r, c + d * 0.94 * r]), ray_col)
	canvas.draw_circle(c, 0.66 * r, Color(1.0, 0.94, 0.7, 0.32))
	canvas.draw_circle(c, 0.58 * r, body)
	canvas.draw_circle(c, core, Color(1.0, 0.97, 0.82, 0.45))
	_alien_eyes(canvas, c.x, c.y - 0.06 * r, 0.21 * r, 0.09 * r, Color("#fff2cf"), _LUM_INK, eye_shape)
	_alien_mouth(canvas, c.x, c.y + 0.24 * r, 0.28 * r, _LUM_INK, mouth_shape)


# Geth-Sentinel Grid (tier 4) — a machine: angular metal head, glowing optic(s), status lights.
const _GETH_METAL := Color("#2e3742")
const _GETH_HI := Color("#4a5764")
const _GETH_OPTICS: Array[Color] = [
	Color("#4de8ff"), Color("#ff8a3b"), Color("#ff5b5b"), Color("#8cff6b"), Color("#c77dff")]

static func _draw_geth(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var optic: Color = _GETH_OPTICS[rng.randi() % _GETH_OPTICS.size()]
	var dual := rng.randf() < 0.45              # two eyes vs a single scanning optic
	var scan := (rng.randf() - 0.5) * 0.5 * r
	var dots := 2 + rng.randi() % 4
	var hw := (0.38 + rng.randf() * 0.06) * r    # head width varies
	var ant := rng.randi() % 3                   # antenna style: center / two / none
	var hc := Vector2(c.x, c.y - 0.03 * r)
	if ant == 0:
		canvas.draw_line(Vector2(hc.x, hc.y - 0.44 * r), Vector2(hc.x, hc.y - 0.58 * r), _GETH_HI, maxf(2.0, 0.025 * r))
		canvas.draw_circle(Vector2(hc.x, hc.y - 0.58 * r), 0.04 * r, optic)
	elif ant == 1:
		for sx in [-1.0, 1.0]:
			canvas.draw_line(Vector2(hc.x + sx * 0.20 * r, hc.y - 0.44 * r),
				Vector2(hc.x + sx * 0.28 * r, hc.y - 0.56 * r), _GETH_HI, maxf(2.0, 0.022 * r))
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.32), _GETH_METAL)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x - hw, hc.y - 0.28 * r), Vector2(hc.x - hw + 0.08 * r, hc.y - 0.46 * r),
		Vector2(hc.x + hw - 0.08 * r, hc.y - 0.46 * r), Vector2(hc.x + hw, hc.y - 0.28 * r),
		Vector2(hc.x + hw, hc.y + 0.22 * r), Vector2(hc.x - hw, hc.y + 0.22 * r)]), _GETH_HI)
	canvas.draw_rect(Rect2(hc.x - (hw - 0.02 * r), hc.y - 0.14 * r, (hw - 0.02 * r) * 2.0, 0.20 * r), _GETH_METAL)
	if dual:
		for sx in [-1.0, 1.0]:
			var e := Vector2(hc.x + sx * 0.18 * r, hc.y - 0.04 * r)
			canvas.draw_circle(e, 0.075 * r, Color(optic.r, optic.g, optic.b, 0.4))
			canvas.draw_circle(e, 0.045 * r, optic)
	else:
		var ox := clampf(hc.x + scan, hc.x - 0.30 * r, hc.x + 0.30 * r)
		canvas.draw_circle(Vector2(ox, hc.y - 0.04 * r), 0.09 * r, Color(optic.r, optic.g, optic.b, 0.4))
		canvas.draw_circle(Vector2(ox, hc.y - 0.04 * r), 0.05 * r, optic)
	for i in range(dots):
		canvas.draw_circle(Vector2(hc.x - 0.22 * r + float(i) * 0.14 * r, hc.y + 0.13 * r), 0.02 * r, optic)


# Mycelium Unity (tier 5) — a fungal being: a spotted cap over a pale face, varied eyes, spores.
const _MYC_CAPS: Array[Color] = [
	Color("#a94f38"), Color("#8e6b3f"), Color("#b5723f"), Color("#7a4a6a"), Color("#c0603a")]
const _MYC_SPOT := Color("#ecd9b0")
const _MYC_STALK := Color("#e3d6bb")
const _MYC_INK := Color("#3a2a1a")

static func _draw_mycelium(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var cap_col: Color = _MYC_CAPS[rng.randi() % _MYC_CAPS.size()]
	var cap_h := (0.36 + rng.randf() * 0.12) * r
	var spots := 2 + rng.randi() % 4
	var spot_a: Array[float] = []
	for _i in range(spots):
		spot_a.append(rng.randf())
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var spores := 1 + rng.randi() % 3
	var spore_x: Array[float] = []
	for _i in range(spores):
		spore_x.append(rng.randf())
	var hc := Vector2(c.x, c.y + 0.02 * r)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.30), _MYC_STALK)
	canvas.draw_colored_polygon(_ellipse(hc, 0.34 * r, 0.36 * r, 22), _MYC_STALK)
	var cap := PackedVector2Array()
	for i in range(17):
		var a := PI + PI * float(i) / 16.0
		cap.append(Vector2(hc.x + cos(a) * 0.52 * r, hc.y - 0.06 * r + sin(a) * cap_h))
	canvas.draw_colored_polygon(cap, cap_col)
	for i in range(spots):
		var a := PI + PI * (0.15 + 0.7 * spot_a[i])
		canvas.draw_circle(Vector2(hc.x + cos(a) * 0.32 * r, hc.y - 0.06 * r + sin(a) * cap_h * 0.6), 0.04 * r, _MYC_SPOT)
	_alien_eyes(canvas, hc.x, hc.y + 0.10 * r, 0.13 * r, 0.045 * r, Color("#fffaf0"), _MYC_INK, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + 0.26 * r, 0.14 * r, _MYC_INK, mouth_shape)
	for i in range(spores):
		canvas.draw_circle(Vector2(hc.x + (spore_x[i] - 0.5) * 0.9 * r, hc.y - 0.44 * r), 0.02 * r, _MYC_SPOT)


# Quartzite Conglomerate (tier 6) — a crystalloid: a faceted angular head, gem eyes, glints.
const _QZ_BODIES: Array[Color] = [
	Color("#6f9fd0"), Color("#5fb0a4"), Color("#8a7fc4"), Color("#c081a6"), Color("#7ab0d8")]
const _QZ_EYE := Color("#eef9ff")

static func _draw_quartzite(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var body: Color = _QZ_BODIES[rng.randi() % _QZ_BODIES.size()]
	var facet := body.lightened(0.28)
	var dark := body.darkened(0.22)
	var top := (0.50 + rng.randf() * 0.12) * r      # crown point height varies
	var eye_sz := (0.05 + rng.randf() * 0.025) * r
	var glints := 2 + rng.randi() % 3
	var glint_p: Array[float] = []
	for _i in range(glints * 2):
		glint_p.append(rng.randf())
	var hc := Vector2(c.x, c.y - 0.04 * r)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x, hc.y - top), Vector2(hc.x + 0.44 * r, hc.y - 0.24 * r),
		Vector2(hc.x + 0.36 * r, hc.y + 0.30 * r), Vector2(hc.x, hc.y + 0.52 * r),
		Vector2(hc.x - 0.36 * r, hc.y + 0.30 * r), Vector2(hc.x - 0.44 * r, hc.y - 0.24 * r)]), body)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(hc.x, hc.y - top),
		Vector2(hc.x + 0.44 * r, hc.y - 0.24 * r), Vector2(hc.x, hc.y - 0.05 * r)]), facet)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(hc.x, hc.y - 0.05 * r),
		Vector2(hc.x - 0.44 * r, hc.y - 0.24 * r), Vector2(hc.x, hc.y - top)]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(hc.x, hc.y + 0.52 * r),
		Vector2(hc.x + 0.36 * r, hc.y + 0.30 * r), Vector2(hc.x, hc.y - 0.05 * r)]), dark)
	for sx in [-1.0, 1.0]:
		var e := Vector2(hc.x + sx * 0.15 * r, hc.y - 0.06 * r)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(e.x, e.y - eye_sz * 1.2),
			Vector2(e.x + eye_sz, e.y), Vector2(e.x, e.y + eye_sz * 1.2), Vector2(e.x - eye_sz, e.y)]), _QZ_EYE)
	for i in range(glints):
		var gx := hc.x + (glint_p[i * 2] - 0.5) * 0.6 * r
		var gy := hc.y + (glint_p[i * 2 + 1] - 0.5) * 0.6 * r
		canvas.draw_line(Vector2(gx - 0.03 * r, gy), Vector2(gx + 0.03 * r, gy), _QZ_EYE, maxf(1.5, 0.015 * r))
		canvas.draw_line(Vector2(gx, gy - 0.03 * r), Vector2(gx, gy + 0.03 * r), _QZ_EYE, maxf(1.5, 0.015 * r))


# Chronophage Enclave (tier 7) — a time-eater: a dark head with a glowing clock or hourglass.
const _CHR_BODIES: Array[Color] = [
	Color("#5a2535"), Color("#3f2a4a"), Color("#4a2a2a"), Color("#2f3550"), Color("#43304a")]
const _CHR_GLOWS: Array[Color] = [Color("#e8b04a"), Color("#e8734a"), Color("#c77dff"), Color("#4de8ff")]

static func _draw_chronophage(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var body: Color = _CHR_BODIES[rng.randi() % _CHR_BODIES.size()]
	var hi := body.lightened(0.18)
	var glow: Color = _CHR_GLOWS[rng.randi() % _CHR_GLOWS.size()]
	var eye_shape := rng.randi() % 5
	var hourglass := rng.randf() < 0.4
	var hour := rng.randf() * TAU
	var minute := rng.randf() * TAU
	var hc := Vector2(c.x, c.y - 0.03 * r)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.32), body)
	canvas.draw_colored_polygon(_ellipse(hc, 0.48 * r, 0.50 * r, 24), hi)
	_alien_eyes(canvas, hc.x, hc.y - 0.26 * r, 0.15 * r, 0.045 * r, glow, body.darkened(0.3), eye_shape)
	var cc := Vector2(hc.x, hc.y + 0.12 * r)
	var cr := 0.22 * r
	if hourglass:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cc.x - cr * 0.7, cc.y - cr),
			Vector2(cc.x + cr * 0.7, cc.y - cr), Vector2(cc.x, cc.y)]), glow)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cc.x - cr * 0.7, cc.y + cr),
			Vector2(cc.x + cr * 0.7, cc.y + cr), Vector2(cc.x, cc.y)]), Color(glow.r, glow.g, glow.b, 0.55))
	else:
		canvas.draw_arc(cc, cr, 0.0, TAU, 28, glow, maxf(2.0, 0.025 * r))
		canvas.draw_line(cc, cc + Vector2(cos(hour - PI / 2.0), sin(hour - PI / 2.0)) * cr * 0.5, glow, maxf(2.0, 0.03 * r))
		canvas.draw_line(cc, cc + Vector2(cos(minute - PI / 2.0), sin(minute - PI / 2.0)) * cr * 0.85, glow, maxf(2.0, 0.02 * r))
		canvas.draw_circle(cc, 0.03 * r, glow)



# Umbrafex Syndicate (tier 13) — a deniable shadow being: a barely-there silhouette with glowing
# slit eyes, whose portrait has itself been partially redacted by censor bars.
const _UMB_SHADOWS: Array[Color] = [
	Color("#26222e"), Color("#1e1b26"), Color("#2c2733"), Color("#211f2a"), Color("#302a38")]
const _UMB_GLOWS: Array[Color] = [
	Color("#8fe6d8"), Color("#ffcf6b"), Color("#ff7f9c"), Color("#a9c4ff"), Color("#bda6ff")]
const _UMB_CENSOR := Color("#0d0b12")     # the redaction blocks: darker than any body colour

static func _draw_umbrafex(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so faces stay stable -----------
	var shadow: Color = _UMB_SHADOWS[rng.randi() % _UMB_SHADOWS.size()]
	var glow: Color = _UMB_GLOWS[rng.randi() % _UMB_GLOWS.size()]
	var form := rng.randi() % 3                          # 0 hooded · 1 dissolving · 2 hard-edged block
	# Width and height are sampled INDEPENDENTLY (±25%) so members read stocky / narrow / tall
	# rather than as one silhouette scaled up and down.
	var half_w := (0.34 + (rng.randf() - 0.5) * 0.17) * r
	var half_h := (0.38 + (rng.randf() - 0.5) * 0.19) * r
	var shoulder_cut := 0.26 + rng.randf() * 0.14        # how high the shoulders sit in the disc
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var has_mouth := rng.randf() < 0.55                  # many Umbrafex have no mouth at all
	var bar_count := 1 + rng.randi() % 3                 # censor bars over the portrait
	var bar_rows: Array[float] = []                      # each bar's vertical spot inside the head
	var bar_widths: Array[float] = []
	for _i in range(bar_count):
		bar_rows.append(rng.randf())
		bar_widths.append(0.55 + rng.randf() * 0.45)
	var band_count := 5 + rng.randi() % 4                # form 1 only: dissolve bands
	var band_jitter: Array[float] = []
	for _i in range(band_count):
		band_jitter.append(rng.randf())
	var has_collar := rng.randf() < 0.6                  # signature detail, present or absent
	var head := Vector2(c.x, c.y - 0.10 * r)

	# --- background: a faint halo of the being's own darkness, so it reads as unlit -------------
	canvas.draw_circle(head, 0.72 * r, Color(shadow.r, shadow.g, shadow.b, 0.22))

	# --- body / shoulders: bottom edge hugs the disc arc so nothing spills outside the circle ---
	canvas.draw_colored_polygon(_disc_segment_below(c, r, shoulder_cut), shadow)

	# --- head silhouette: three genuinely different constructions ------------------------------
	var face_center := head
	match form:
		0:  # HOODED — a cowl peak above the head, with the face sunk in shadow inside it
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(head.x, head.y - half_h * 1.45),                     # hood peak
				Vector2(head.x + half_w * 1.20, head.y - half_h * 0.20),
				Vector2(head.x + half_w * 1.05, head.y + half_h * 1.05),     # hood skirt, right
				Vector2(head.x - half_w * 1.05, head.y + half_h * 1.05),
				Vector2(head.x - half_w * 1.20, head.y - half_h * 0.20)]), shadow)
			# The face oval sits slightly low inside the cowl, as if recessed under the hood brim.
			face_center = Vector2(head.x, head.y + half_h * 0.12)
			canvas.draw_colored_polygon(_ellipse(face_center, half_w * 0.72, half_h * 0.66, 20),
				shadow.darkened(0.45))
		1:  # DISSOLVING — stacked horizontal bands that jitter and fade toward the bottom
			for i in range(band_count):
				var t := float(i) / float(band_count)                        # 0 = top of head
				var band_h := (half_h * 2.0) / float(band_count)
				var band_w := half_w * (0.62 + 0.38 * sin(t * PI))           # widest at mid-head
				band_w *= 0.82 + band_jitter[i] * 0.36                       # ragged edges
				canvas.draw_rect(Rect2(head.x - band_w, head.y - half_h + band_h * float(i),
					band_w * 2.0, band_h * 0.92),
					Color(shadow.r, shadow.g, shadow.b, 1.0 - t * 0.55))
			face_center = Vector2(head.x, head.y - half_h * 0.18)            # face rides high, above the fade
		2:  # HARD-EDGED BLOCK — a slab head with clipped corners, like a bar of solid ink
			var clip := minf(half_w, half_h) * 0.30
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - half_w + clip, head.y - half_h),
				Vector2(head.x + half_w - clip, head.y - half_h),
				Vector2(head.x + half_w, head.y - half_h + clip),
				Vector2(head.x + half_w, head.y + half_h - clip),
				Vector2(head.x + half_w - clip, head.y + half_h),
				Vector2(head.x - half_w + clip, head.y + half_h),
				Vector2(head.x - half_w, head.y + half_h - clip),
				Vector2(head.x - half_w, head.y - half_h + clip)]), shadow)

	# --- features: glowing slit eyes, an optional mouth -----------------------------------------
	var eye_y := face_center.y - half_h * 0.18
	for sx in [-1.0, 1.0]:
		# A soft bloom behind each eye so the glow appears to leak out of the dark.
		canvas.draw_circle(Vector2(face_center.x + sx * half_w * 0.42, eye_y), half_h * 0.22,
			Color(glow.r, glow.g, glow.b, 0.20))
	_alien_eyes(canvas, face_center.x, eye_y, half_w * 0.42, half_h * 0.14,
		glow, shadow.darkened(0.6), eye_shape)
	if has_mouth:
		_alien_mouth(canvas, face_center.x, face_center.y + half_h * 0.46, half_w * 0.60,
			Color(glow.r, glow.g, glow.b, 0.75), mouth_shape)

	# --- signature collar: two faint glowing seams where the shoulders meet the neck ------------
	if has_collar:
		var collar_y := c.y + shoulder_cut * r + 0.06 * r
		for sx in [-1.0, 1.0]:
			canvas.draw_line(Vector2(c.x + sx * 0.10 * r, collar_y),
				Vector2(c.x + sx * 0.30 * r, collar_y + 0.07 * r),
				Color(glow.r, glow.g, glow.b, 0.5), maxf(2.0, 0.02 * r))

	# --- overlay: censor bars, drawn last so they redact whatever they land on ------------------
	for i in range(bar_count):
		var bar_w := half_w * 1.9 * bar_widths[i]
		var bar_h := half_h * 0.26
		# Rows are spread across the head from just above the eyes to just below the mouth.
		var bar_y := lerpf(face_center.y - half_h * 0.34, face_center.y + half_h * 0.58, bar_rows[i])
		canvas.draw_rect(Rect2(face_center.x - bar_w * 0.5, bar_y - bar_h * 0.5, bar_w, bar_h), _UMB_CENSOR)


# Karr'ghan Warhoard (tier 14) — a brute warrior-accountant: heavy jaw, tusks and horns, battle
# scars and war paint, plus one small clerical detail (quill, monocle, ledger strap) on a war face.
const _KAR_HIDES: Array[Color] = [
	Color("#8b3a1f"), Color("#9c4a28"), Color("#7a4530"), Color("#6f5a3a"), Color("#8a5535")]
const _KAR_ARMOR := Color("#3a2a20")
const _KAR_METAL := Color("#6b5a48")
const _KAR_BONE := Color("#e8dcc0")
const _KAR_INK := Color("#241611")
const _KAR_PAINTS: Array[Color] = [
	Color("#d9c04a"), Color("#c23a2a"), Color("#2f4f6f"), Color("#171310")]

static func _draw_karrghan(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# Every random value is drawn up front in a fixed order, so adding a feature later does not
	# shift the look of staffers that already exist.
	var hide: Color = _KAR_HIDES[rng.randi() % _KAR_HIDES.size()]
	var paint: Color = _KAR_PAINTS[rng.randi() % _KAR_PAINTS.size()]
	var form := rng.randi() % 3                    # 0 slab brute · 1 tall raider · 2 helmed
	var hw := (0.30 + rng.randf() * 0.12) * r      # head half-width  — sampled independently
	var hh := (0.30 + rng.randf() * 0.12) * r      # head half-height — of the width
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var tusks_per_side := 1 + rng.randi() % 2
	var tusk_reach := 0.30 + rng.randf() * 0.45    # tusk height as a fraction of the face height
	var horn_style := rng.randi() % 3              # 0 swept back · 1 straight up · 2 stubby
	var scars := rng.randi() % 3
	var scar_pos: Array[float] = []
	for _i in range(scars):
		scar_pos.append(rng.randf())
	var paint_style := rng.randi() % 3             # 0 none · 1 band over the eyes · 2 cheek stripes
	var has_quill := rng.randf() < 0.45            # quill tucked behind one ear
	var has_monocle := rng.randf() < 0.40
	var has_strap := rng.randf() < 0.60            # ledger strap across the chest
	var studs := 2 + rng.randi() % 3

	var dark := hide.darkened(0.35)
	var hi := hide.lightened(0.12)
	var hc := Vector2(c.x, c.y - 0.05 * r)         # head sits slightly high, shoulders fill below

	# Per-form silhouette size, plus the face box (fc/fw/fh) that all features are placed against.
	var hwE := hw
	var hhE := hh
	var fc := hc
	var fw := hw
	var fh := hh
	match form:
		0:                                          # wide, slab-jawed: crown narrower than the jaw
			hwE = hw * 1.10
			fw = hwE * 0.90
			fh = hhE
		1:                                          # tall, narrow raider: pointed crown, long face
			hwE = hw * 0.80
			hhE = hh * 1.15
			fc = Vector2(hc.x, hc.y + 0.10 * hhE)
			fw = hwE * 0.90
			fh = hhE * 0.80
		2:                                          # helmed: metal dome swallows the upper head
			hwE = hw * 1.05
			fc = Vector2(hc.x, hc.y + 0.22 * hhE)
			fw = hwE * 0.75
			fh = hhE * 0.60

	# --- shoulders and armour (behind everything) ---
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), _KAR_ARMOR)
	for i in range(studs):
		var stud_x := c.x - 0.30 * r + (0.60 * r) * (float(i) / float(maxi(1, studs - 1)))
		canvas.draw_circle(Vector2(stud_x, c.y + 0.52 * r), 0.035 * r, _KAR_METAL)
	if has_strap:
		canvas.draw_line(Vector2(c.x - 0.42 * r, c.y + 0.42 * r), Vector2(c.x + 0.20 * r, c.y + 0.80 * r),
			_KAR_METAL, maxf(2.0, 0.05 * r))
		canvas.draw_rect(Rect2(c.x - 0.14 * r, c.y + 0.54 * r, 0.09 * r, 0.09 * r), _KAR_BONE)

	# --- horns, drawn before the head so their roots are hidden by it ---
	for sx in [-1.0, 1.0]:
		var root := Vector2(hc.x + sx * 0.90 * hwE, hc.y - 0.35 * hhE)
		match horn_style:
			0:                                      # swept back and up
				canvas.draw_polyline(PackedVector2Array([root,
					Vector2(hc.x + sx * 1.25 * hwE, hc.y - 0.75 * hhE),
					Vector2(hc.x + sx * 1.15 * hwE, hc.y - 1.15 * hhE)]), _KAR_BONE, maxf(2.0, 0.045 * r))
			1:                                      # straight up, tapered spike
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(root.x - sx * 0.10 * hwE, root.y), Vector2(root.x + sx * 0.12 * hwE, root.y),
					Vector2(hc.x + sx * 0.95 * hwE, hc.y - 1.35 * hhE)]), _KAR_BONE)
			2:                                      # short stubby nub
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(root.x, root.y + 0.12 * hhE), Vector2(root.x, root.y - 0.10 * hhE),
					Vector2(hc.x + sx * 1.15 * hwE, hc.y - 0.55 * hhE)]), _KAR_BONE)

	# --- head silhouette ---
	if form == 0:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x - 0.78 * hwE, hc.y - hhE), Vector2(hc.x + 0.78 * hwE, hc.y - hhE),
			Vector2(hc.x + hwE, hc.y - 0.20 * hhE), Vector2(hc.x + hwE, hc.y + 0.55 * hhE),
			Vector2(hc.x + 0.72 * hwE, hc.y + hhE), Vector2(hc.x - 0.72 * hwE, hc.y + hhE),
			Vector2(hc.x - hwE, hc.y + 0.55 * hhE), Vector2(hc.x - hwE, hc.y - 0.20 * hhE)]), hide)
		# heavy brow shelf across the whole width
		canvas.draw_rect(Rect2(hc.x - 0.92 * hwE, hc.y - 0.42 * hhE, 1.84 * hwE, 0.20 * hhE), dark)
	elif form == 1:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x, hc.y - hhE), Vector2(hc.x + 0.75 * hwE, hc.y - 0.55 * hhE),
			Vector2(hc.x + hwE, hc.y), Vector2(hc.x + 0.70 * hwE, hc.y + 0.65 * hhE),
			Vector2(hc.x, hc.y + hhE), Vector2(hc.x - 0.70 * hwE, hc.y + 0.65 * hhE),
			Vector2(hc.x - hwE, hc.y), Vector2(hc.x - 0.75 * hwE, hc.y - 0.55 * hhE)]), hide)
		# topknot spike out of the pointed crown
		canvas.draw_line(Vector2(hc.x, hc.y - 0.85 * hhE), Vector2(hc.x, hc.y - hhE - 0.16 * r),
			_KAR_ARMOR, maxf(2.0, 0.035 * r))
	else:
		# metal dome, then the exposed lower face, then cheek guards down the sides
		canvas.draw_colored_polygon(_ellipse(Vector2(hc.x, hc.y - 0.10 * hhE), hwE, hhE * 0.85, 22), _KAR_METAL)
		canvas.draw_colored_polygon(_ellipse(fc, fw * 1.15, fh * 1.20, 20), hide)
		for sx in [-1.0, 1.0]:
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(hc.x + sx * 0.98 * hwE, hc.y - 0.10 * hhE),
				Vector2(hc.x + sx * 1.02 * hwE, hc.y + 0.55 * hhE),
				Vector2(hc.x + sx * 0.66 * hwE, hc.y + 0.85 * hhE),
				Vector2(hc.x + sx * 0.70 * hwE, hc.y)]), _KAR_METAL)
		# rim above the eyes marks where the helm ends
		canvas.draw_rect(Rect2(hc.x - 0.90 * hwE, hc.y + 0.02 * hhE, 1.80 * hwE, 0.12 * hhE), _KAR_ARMOR)

	# --- face ---
	_alien_eyes(canvas, fc.x, fc.y - 0.15 * fh, 0.48 * fw, 0.20 * fh, _KAR_BONE, _KAR_INK, eye_shape)
	_alien_mouth(canvas, fc.x, fc.y + 0.42 * fh, 0.85 * fw, _KAR_INK, mouth_shape)
	# tusks rise from the jawline, spaced outward from the mouth
	for sx in [-1.0, 1.0]:
		for i in range(tusks_per_side):
			# `sx` comes from an untyped array literal, so the sum is a Variant unless annotated.
			var base_x: float = fc.x + sx * (0.34 + 0.26 * float(i)) * fw
			var base_y := fc.y + 0.58 * fh
			var tip_y := base_y - tusk_reach * fh * (1.0 - 0.25 * float(i))
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(base_x - 0.09 * fw, base_y), Vector2(base_x + 0.09 * fw, base_y),
				Vector2(base_x + sx * 0.03 * fw, tip_y)]), _KAR_BONE)
	if form == 2:
		# nose plate hangs from the helm rim between the eyes
		canvas.draw_rect(Rect2(fc.x - 0.09 * fw, fc.y - 0.30 * fh, 0.18 * fw, 0.55 * fh), _KAR_METAL)

	# --- overlays: paint, scars, clerical details ---
	if paint_style == 1:
		canvas.draw_rect(Rect2(fc.x - 0.80 * fw, fc.y - 0.34 * fh, 1.60 * fw, 0.16 * fh),
			Color(paint.r, paint.g, paint.b, 0.75))
	elif paint_style == 2:
		for i in range(2):
			var stripe_x := fc.x + (0.34 + 0.20 * float(i)) * fw
			canvas.draw_line(Vector2(stripe_x, fc.y - 0.05 * fh), Vector2(stripe_x, fc.y + 0.50 * fh),
				Color(paint.r, paint.g, paint.b, 0.8), maxf(2.0, 0.022 * r))
	for i in range(scars):
		# a diagonal slash placed left or right of centre by its stored roll
		var sx2 := -1.0 if scar_pos[i] < 0.5 else 1.0
		var sy := fc.y - 0.30 * fh + fh * 0.9 * fmod(scar_pos[i] * 2.0, 1.0)
		canvas.draw_line(Vector2(fc.x + sx2 * 0.25 * fw, sy),
			Vector2(fc.x + sx2 * 0.85 * fw, sy + 0.22 * fh), dark, maxf(2.0, 0.018 * r))
	if has_monocle:
		var lens := Vector2(fc.x - 0.48 * fw, fc.y - 0.15 * fh)
		canvas.draw_arc(lens, 0.30 * fw, 0.0, TAU, 18, _KAR_METAL, maxf(2.0, 0.018 * r))
		canvas.draw_line(lens + Vector2(-0.10 * fw, 0.30 * fw), Vector2(lens.x - 0.20 * fw, fc.y + 0.75 * fh),
			_KAR_METAL, maxf(2.0, 0.014 * r))
	if has_quill:
		# tucked behind the right ear, angling up and out past the head edge
		var quill_root := Vector2(hc.x + 0.85 * hwE, hc.y + 0.10 * hhE)
		var quill_tip := Vector2(hc.x + 1.05 * hwE + 0.08 * r, hc.y - hhE - 0.10 * r)
		canvas.draw_line(quill_root, quill_tip, _KAR_BONE, maxf(2.0, 0.022 * r))
		canvas.draw_colored_polygon(_ellipse(quill_tip, 0.05 * r, 0.09 * r, 12), hi)


# The Politesse Ascendancy (tier 15) — an impeccably, menacingly polite aristocrat: a towering lace
# ruff, a powdered wig, a monocle and a tiny apologetic smile.
#
# Design intent:
#   * The WIG carries the silhouette. It is never two round lumps on the crown (that reads as animal
#     ears) — it is a tall swept peruke, a wide low coiffure, or a close cap with a queue, and its
#     texture comes from ROWS of many small curls.
#   * The three forms differ in overall BUILD (head size, head height on the disc, collar mass,
#     shoulder line), not just in which accessory they happen to get.
#   * The face is a mid-tone mauve with a darker outline so it reads as a face against the
#     near-white lace, instead of merging into one pale mass.
const _POL_COATS: Array[Color] = [
	Color("#9e6b8a"), Color("#8a5f7e"), Color("#a87693"), Color("#7e5a76"), Color("#b07f9a")]
# Deliberately mid-tone: the lace and the wig are near-white, so the skin has to sit clearly
# darker than both or the whole portrait flattens out.
const _POL_SKINS: Array[Color] = [
	Color("#c9a0b0"), Color("#b98ea3"), Color("#d2adb4"), Color("#bf94a6"), Color("#c8a595")]
const _POL_LACE: Array[Color] = [
	Color("#fdf6f8"), Color("#f7eef4"), Color("#fbf2e9"), Color("#f4ecf6")]
const _POL_WIGS: Array[Color] = [
	Color("#efe6ec"), Color("#e6dae6"), Color("#f2e7da"), Color("#e9e0ea")]
const _POL_INK := Color("#3d2532")
const _POL_ROUGE := Color("#c4657e", 0.55)
const _POL_GOLD := Color("#d8b25c")


static func _draw_politesse(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so adding features later does not
	# --- reshuffle existing staffers' faces.
	var form := rng.randi() % 3          # 0 = tall peruke · 1 = wide coiffure · 2 = small head, tall ruff
	var coat: Color = _POL_COATS[rng.randi() % _POL_COATS.size()]
	var skin: Color = _POL_SKINS[rng.randi() % _POL_SKINS.size()]
	var lace: Color = _POL_LACE[rng.randi() % _POL_LACE.size()]
	var wig_col: Color = _POL_WIGS[rng.randi() % _POL_WIGS.size()]
	var width_roll := rng.randf()        # small within-form variation of head width
	var height_roll := rng.randf()       # ...and of head height, sampled independently
	var ruff_roll := rng.randf()
	var scallop_count := 7 + rng.randi() % 5
	var wig_roll := rng.randf()
	var curl_row_count := 3 + rng.randi() % 2
	var layer_bonus := rng.randi() % 2   # one extra collar tier on half of them, for silhouette variety
	var monocle_side := 1.0 if rng.randf() < 0.5 else -1.0
	var has_monocle := rng.randf() < 0.8
	var has_beauty_mark := rng.randf() < 0.5
	var eye_roll := rng.randf()
	var mouth_roll := rng.randf()

	# Demure expressions only: half-closed or narrow eyes, and a small smile far more often than not.
	var eye_shape := 3 if eye_roll < 0.45 else (1 if eye_roll < 0.8 else 0)
	var mouth_shape := 0 if mouth_roll < 0.65 else (1 if mouth_roll < 0.88 else 3)

	# --- per-form build ----------------------------------------------------------------------------
	# Each form gets its own head size, head height, collar mass and shoulder line, so two members
	# of different forms have visibly different outlines even as thumbnails.
	var head_hw := 0.0
	var head_hh := 0.0
	var head_y := 0.0
	var ruff_hw := 0.0
	var ruff_hh := 0.0
	var ruff_layers := 0
	var ruff_center_y := 0.0
	var ruff_layer_step := 0.0   # vertical gap between stacked collar layers
	var ruff_taper := 0.0        # how much narrower each layer is than the one below it
	var shoulder_cut := 0.0      # where the coat meets the disc, as a fraction of r below centre
	match form:
		0:  # narrow, long-faced, and topped by a peruke taller than the head itself
			head_hw = (0.22 + width_roll * 0.05) * r
			head_hh = (0.29 + height_roll * 0.06) * r
			head_y = c.y - 0.09 * r
			ruff_hw = (0.44 + ruff_roll * 0.07) * r
			ruff_hh = 0.14 * r
			ruff_layers = 2 + layer_bonus
			ruff_center_y = c.y + 0.36 * r
			ruff_layer_step = 0.06 * r
			ruff_taper = 0.16
			shoulder_cut = 0.42
		1:  # broad and low-slung: wide head, huge collar, high square shoulders
			head_hw = (0.31 + width_roll * 0.06) * r
			head_hh = (0.24 + height_roll * 0.04) * r
			head_y = c.y - 0.11 * r
			ruff_hw = (0.68 + ruff_roll * 0.07) * r
			ruff_hh = 0.19 * r
			ruff_layers = 3 + layer_bonus
			ruff_center_y = c.y + 0.34 * r
			ruff_layer_step = 0.07 * r
			ruff_taper = 0.15
			shoulder_cut = 0.28
		_:  # small head carried high on a tall stack of narrow collar tiers
			head_hw = (0.23 + width_roll * 0.05) * r
			head_hh = (0.25 + height_roll * 0.05) * r
			head_y = c.y - 0.25 * r
			ruff_hw = (0.40 + ruff_roll * 0.06) * r
			ruff_hh = 0.12 * r
			ruff_layers = 4 + layer_bonus
			ruff_center_y = c.y + 0.32 * r
			ruff_layer_step = 0.085 * r
			ruff_taper = 0.09   # four tiers, so they taper gently or the stack becomes a cone
			shoulder_cut = 0.48
	var hc := Vector2(c.x, head_y)
	var head_top := hc.y - head_hh

	# Curls are drawn a shade darker than the wig body so the rows read as texture on the mass.
	var curl_col := wig_col.darkened(0.10)
	# One row of MANY small curls between two x positions. Rows of small curls read as powdered
	# hair; a pair of big lumps would read as ears, which is exactly what this avoids.
	var draw_curl_row := func(row_y: float, x_from: float, x_to: float, count: int, curl_r: float) -> void:
		for i in range(count):
			var t := float(i) / float(maxi(1, count - 1))
			canvas.draw_circle(Vector2(lerpf(x_from, x_to, t), row_y), curl_r, curl_col)

	# --- coat and shoulders ------------------------------------------------------------------------
	canvas.draw_colored_polygon(_disc_segment_below(c, r, shoulder_cut), coat)
	# A darker rim just under the coat's top edge, so the shoulder line still reads where the collar
	# does not cover it. Its half-length is the disc's own chord at that height, so it ends exactly
	# on the disc edge instead of stopping short and looking like a stray line.
	var shoulder_y := c.y + (shoulder_cut + 0.03) * r
	var shoulder_half := sqrt(maxf(0.0, r * r - pow((shoulder_cut + 0.03) * r, 2.0)))
	canvas.draw_line(Vector2(c.x - shoulder_half, shoulder_y), Vector2(c.x + shoulder_half, shoulder_y),
		coat.darkened(0.28), maxf(2.0, 0.03 * r))

	# --- the wig's back mass, drawn BEFORE the head so the head covers its middle and only its
	# --- edges show. That leaves hair framing the cheeks, which is what stops the wig above from
	# --- reading as a hat sitting on a bare head.
	var back_hw := head_hw * (1.34 if form == 0 else (1.62 if form == 1 else 1.18))
	var back_hh := head_hh * (1.10 if form == 0 else (1.16 if form == 1 else 1.05))
	canvas.draw_colored_polygon(_ellipse(Vector2(hc.x, hc.y - head_hh * 0.10), back_hw, back_hh, 30),
		wig_col.darkened(0.12))

	# --- head --------------------------------------------------------------------------------------
	# Built as a point list so the same outline can be filled and then stroked.
	var head_pts := PackedVector2Array()
	if form == 0:
		# long tapered face with a pointed chin
		head_pts = PackedVector2Array([
			Vector2(hc.x - head_hw * 0.88, hc.y - head_hh * 0.62),
			Vector2(hc.x - head_hw * 0.62, hc.y - head_hh),
			Vector2(hc.x + head_hw * 0.62, hc.y - head_hh),
			Vector2(hc.x + head_hw * 0.88, hc.y - head_hh * 0.62),
			Vector2(hc.x + head_hw * 0.66, hc.y + head_hh * 0.42),
			Vector2(hc.x, hc.y + head_hh),
			Vector2(hc.x - head_hw * 0.66, hc.y + head_hh * 0.42)])
	elif form == 1:
		# broad jowly oval, wider than tall
		head_pts = _ellipse(hc, head_hw, head_hh, 28)
	else:
		# small head with a squarish jaw
		head_pts = PackedVector2Array([
			Vector2(hc.x - head_hw * 0.72, hc.y - head_hh),
			Vector2(hc.x + head_hw * 0.72, hc.y - head_hh),
			Vector2(hc.x + head_hw, hc.y - head_hh * 0.35),
			Vector2(hc.x + head_hw * 0.92, hc.y + head_hh * 0.60),
			Vector2(hc.x + head_hw * 0.55, hc.y + head_hh),
			Vector2(hc.x - head_hw * 0.55, hc.y + head_hh),
			Vector2(hc.x - head_hw * 0.92, hc.y + head_hh * 0.60),
			Vector2(hc.x - head_hw, hc.y - head_hh * 0.35)])
	canvas.draw_colored_polygon(head_pts, skin)
	# draw_polyline does not close itself, so repeat the first point to finish the loop.
	var head_outline := head_pts.duplicate()
	head_outline.append(head_pts[0])
	canvas.draw_polyline(head_outline, skin.darkened(0.42), maxf(2.0, 0.016 * r))

	# --- powdered wig: a different silhouette per form ---------------------------------------------
	if form == 0:
		# Tall peruke: a column of powdered hair swept straight UP off the crown, narrower at the
		# base than the head so it reads as height rather than as width. Its top reaches the
		# 0.86 r ceiling on the tallest roll, which is what makes this form the tall one.
		var dome_top := c.y - (0.72 + wig_roll * 0.14) * r
		var dome_hh := (head_top - dome_top) * 0.5
		var dome_c := Vector2(hc.x, head_top - dome_hh)
		canvas.draw_colored_polygon(_ellipse(dome_c, head_hw * 0.86, dome_hh, 26), wig_col)
		# temple rolls: a short wide band where the peruke meets the head, so the join is not a stalk
		canvas.draw_colored_polygon(_ellipse(Vector2(hc.x, head_top + 0.02 * r),
			head_hw * 1.16, 0.075 * r, 22), wig_col)
		# curl rows climb the column, each narrower than the one below
		for row in range(curl_row_count + 1):
			var t := float(row) / float(curl_row_count)
			var row_y := lerpf(head_top - 0.01 * r, dome_top + 0.07 * r, t)
			var half := head_hw * lerpf(0.98, 0.34, t)
			draw_curl_row.call(row_y, hc.x - half, hc.x + half, 4, (0.05 - 0.012 * t) * r)
	elif form == 1:
		# Wide low coiffure: a broad mass that widens the head sideways rather than sprouting from
		# it — the squat, heavy-set build of the three.
		var mass_hh := (0.16 + wig_roll * 0.05) * r
		var mass_hw := head_hw * 1.5
		var mass_c := Vector2(hc.x, head_top - mass_hh * 0.35)
		canvas.draw_colored_polygon(_ellipse(mass_c, mass_hw, mass_hh, 30), wig_col)
		# Three rows of curls across the mass. Each row's half-width follows the ellipse at that
		# height, so the curls sit inside the silhouette instead of poking out of it.
		for row in range(3):
			var t := float(row) / 2.0
			var y_frac := lerpf(0.5, -0.5, t)          # bottom row to top row
			var row_y := mass_c.y + mass_hh * y_frac
			var half := mass_hw * sqrt(maxf(0.05, 1.0 - y_frac * y_frac)) * 0.88
			draw_curl_row.call(row_y, hc.x - half, hc.x + half, 5, 0.05 * r)
	else:
		# Close-fitting powdered crown with two curl ridges over the temples, plus a queue tied
		# with a dark ribbon. A modest wig on a small head: the slight build of the three.
		var crown_hh := (0.15 + wig_roll * 0.04) * r
		# Centred INSIDE the skull so only its domed top shows — an ellipse perched on top of the
		# head would read as a flat-brimmed hat instead of hair.
		var crown_c := Vector2(hc.x, head_top + crown_hh * 0.55)
		canvas.draw_colored_polygon(_ellipse(crown_c, head_hw * 1.04, crown_hh, 24), wig_col)
		draw_curl_row.call(head_top + 0.035 * r, hc.x - head_hw * 0.96, hc.x + head_hw * 0.96, 5, 0.042 * r)
		draw_curl_row.call(head_top - 0.025 * r, hc.x - head_hw * 0.66, hc.x + head_hw * 0.66, 4, 0.036 * r)
		# the queue falls down the side away from the monocle, ending in a ribbon at the collar
		var queue_x := hc.x - monocle_side * head_hw * 1.02
		for i in range(3):
			canvas.draw_circle(Vector2(queue_x, hc.y + (0.04 + 0.07 * float(i)) * r), 0.038 * r, curl_col)
		canvas.draw_circle(Vector2(queue_x, hc.y + 0.24 * r), 0.032 * r, _POL_INK)

	# --- the ruff, drawn over the chin so the jaw sits in front of nothing and the collar reads
	# --- as a separate, brighter mass than the face ------------------------------------------------
	for i in range(ruff_layers):
		var layer_hw := ruff_hw * (1.0 - ruff_taper * float(i))
		var layer_hh := ruff_hh * (1.0 - 0.12 * float(i))
		var layer_y := ruff_center_y - ruff_layer_step * float(i)
		if i == 0:
			# lace scallops hang off the bottom edge of the outermost layer
			for s in range(scallop_count):
				var t := lerpf(-0.8, 0.8, float(s) / float(maxi(1, scallop_count - 1)))
				var scallop_y := layer_y + layer_hh * sqrt(maxf(0.0, 1.0 - t * t))
				canvas.draw_circle(Vector2(c.x + layer_hw * t, scallop_y), 0.05 * r, lace)
		canvas.draw_colored_polygon(_ellipse(Vector2(c.x, layer_y), layer_hw, layer_hh, 28), lace)
		# a faint seam along each layer's midline keeps the stack from looking like one slab
		canvas.draw_line(Vector2(c.x - layer_hw * 0.88, layer_y), Vector2(c.x + layer_hw * 0.88, layer_y),
			lace.darkened(0.14), maxf(2.0, 0.012 * r))

	# --- a gold brooch pinned to the front of the collar: the one warm accent in an otherwise
	# --- pale portrait, and a small piece of visible wealth.
	var brooch := Vector2(c.x, ruff_center_y - ruff_layer_step * float(ruff_layers - 1))
	canvas.draw_circle(brooch, 0.045 * r, _POL_GOLD)
	canvas.draw_circle(brooch, 0.022 * r, _POL_GOLD.darkened(0.35))

	# --- face: positions are fractions of the head, so they follow whichever build was chosen -----
	var eye_y := hc.y - head_hh * 0.12
	# rouged cheeks, just below and outside the eyes
	# kept well inside the jaw line: a rouge spot clipped by the head's edge reads as a stripe
	for cheek_side: float in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(hc.x + cheek_side * head_hw * 0.52, eye_y + head_hh * 0.36),
			head_hw * 0.15, _POL_ROUGE)
	_alien_eyes(canvas, hc.x, eye_y, head_hw * 0.44, head_hh * 0.19, Color("#fdfbfc"), _POL_INK, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + head_hh * 0.46, head_hw * 0.52, _POL_INK, mouth_shape)
	if has_beauty_mark:
		canvas.draw_circle(Vector2(hc.x - head_hw * 0.34, hc.y + head_hh * 0.24), maxf(2.0, 0.014 * r), _POL_INK)

	# --- monocle: a rim around one eye with a chain trailing down to the collar --------------------
	if has_monocle:
		var mono := Vector2(hc.x + monocle_side * head_hw * 0.44, eye_y)
		var mono_r := maxf(head_hh * 0.30, head_hw * 0.34)
		canvas.draw_arc(mono, mono_r, 0.0, TAU, 24, _POL_INK, maxf(2.0, 0.02 * r))
		# The chain leaves the rim sideways and only then drops, so it hangs OUTSIDE the jaw instead
		# of drawing a diagonal scar across the cheek on the smaller heads.
		var chain_x := hc.x + monocle_side * head_hw * 1.22
		canvas.draw_polyline(PackedVector2Array([
			mono + Vector2(monocle_side * mono_r * 0.95, mono_r * 0.25),
			Vector2(chain_x, mono.y + head_hh * 0.35),
			Vector2(chain_x, ruff_center_y - ruff_hh * 0.85)]),
			_POL_INK, maxf(2.0, 0.012 * r))


# Oneiroi Drift (tier 16) — a dream-being that sells dreams on credit.
# Design intent: the being is a SOLID, high-contrast figure so the portrait still reads at row
# size. "Dissolving" is expressed as SHAPE, not as opacity — scalloped notches bitten out of the
# silhouette, a lower body that breaks into separating slabs, and peeling crescents plus shed
# motes in a thin margin just outside the edge. No full-disc haze.
const _ONI_BODIES: Array[Color] = [
	Color("#9b86c4"), Color("#8a76b8"), Color("#af9cd8"), Color("#7d6bad"), Color("#c0b0e2")]
const _ONI_GLOWS: Array[Color] = [
	Color("#e8e0f8"), Color("#d4e4fa"), Color("#f2e6f4"), Color("#dceef6")]
const _ONI_INK := Color("#241b36")
const _ONI_OUTLINE_STEPS := 64      # samples around the eroded silhouette

static func _draw_oneiroi(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so adding a later feature
	# --- does not change the look of existing staffers.
	var body: Color = _ONI_BODIES[rng.randi() % _ONI_BODIES.size()]
	var glow: Color = _ONI_GLOWS[rng.randi() % _ONI_GLOWS.size()]
	var form := rng.randi() % 3                       # 0 dreaming orb · 1 drifting pillar · 2 cloud cluster
	var width_scale := 0.85 + rng.randf() * 0.30      # stocky vs narrow, sampled independently...
	var height_scale := 0.85 + rng.randf() * 0.30     # ...from squat vs tall
	var dissolve_dir := rng.randf() * TAU             # which side of the being is coming apart
	var notch_count := 3 + rng.randi() % 3            # 3-5 bites out of the silhouette
	var notch_spread: Array[float] = []               # where each bite sits, relative to dissolve_dir
	var notch_width: Array[float] = []                # angular half-width of the bite
	var notch_depth: Array[float] = []                # how far it eats inward, as a fraction of radius
	for _i in range(notch_count):
		notch_spread.append(rng.randf())
		notch_width.append(rng.randf())
		notch_depth.append(rng.randf())
	var shoulder_lumps: Array[float] = []             # 4 rolls that make the shoulder line uneven
	for _i in range(4):
		shoulder_lumps.append(rng.randf())
	var mote_count := 4 + rng.randi() % 5             # 4-8 motes shed from the silhouette
	var mote_angle: Array[float] = []
	var mote_reach: Array[float] = []
	var mote_size: Array[float] = []
	for _i in range(mote_count):
		mote_angle.append(rng.randf())
		mote_reach.append(rng.randf())
		mote_size.append(rng.randf())
	var eye_style := rng.randi() % 3                  # 0 pair · 1 single lidded eye · 2 a row of many
	var eye_shape := 3 if rng.randf() < 0.75 else rng.randi() % 5   # heavy bias to shape 3 (closed / asleep)
	var many_eyes := 3 + rng.randi() % 2              # only used by eye_style 2
	var has_mouth := rng.randf() < 0.55               # many of them have no mouth at all
	var mouth_shape := rng.randi() % 4
	var has_sleep_symbol := rng.randf() < 0.45

	# --- silhouette size per form. The three forms differ in PROPORTION as well as construction,
	# --- so members read as different creatures at a glance.
	var head_hw := 0.44 * r
	var head_hh := 0.46 * r
	if form == 1:
		head_hw = 0.30 * r        # pillar: narrow and tall
		head_hh = 0.50 * r
	elif form == 2:
		head_hw = 0.54 * r        # cloud: wide and low
		head_hh = 0.36 * r
	head_hw *= width_scale
	head_hh *= height_scale
	var head_center := Vector2(c.x, c.y - 0.16 * r)
	var dissolve := Vector2(cos(dissolve_dir), sin(dissolve_dir))

	var body_deep := body.darkened(0.40)              # the shaded lower body / shoulders
	var body_lit := body.lightened(0.26)              # the lit dream-core inside the head
	var rim := _ONI_INK                               # a dark rim keeps the figure off the disc

	# --- lower body ------------------------------------------------------------------------------
	# Solid, so the figure has weight. Form 1 breaks it into separating slabs instead.
	if form == 1:
		# Three solid slabs trailing away below the head, narrowing and separating as they fall —
		# the pillar is shedding its own base. Gaps of bare disc between them are the point.
		for i in range(3):
			var fall := float(i)                                          # 0 = closest to the head
			var slab_center := Vector2(c.x, c.y + (0.28 + 0.17 * fall) * r)
			var slab_hw := head_hw * (1.60 - 0.42 * fall)
			canvas.draw_colored_polygon(_ellipse(slab_center, slab_hw, 0.10 * r, 20), body_deep)
	else:
		# A mist bank: the disc segment, plus four lumps riding its top edge so the shoulder line is
		# uneven rather than a hard flat horizon.
		var shoulder_y := c.y + 0.34 * r
		canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), body_deep)
		for i in range(4):
			var slot := (float(i) + 0.5) / 4.0 - 0.5                      # -0.375 .. +0.375
			var lump_pos := Vector2(c.x + slot * 1.30 * r, shoulder_y)
			canvas.draw_circle(lump_pos, (0.07 + shoulder_lumps[i] * 0.08) * r, body_deep)

	# --- the head silhouette ---------------------------------------------------------------------
	# A radial outline: radius dips inside each notch so the edge looks bitten away. The dip uses a
	# cosine falloff, which makes a rounded scallop instead of a spike, and never crosses itself.
	var outline := PackedVector2Array()
	for i in range(_ONI_OUTLINE_STEPS):
		var angle := TAU * float(i) / float(_ONI_OUTLINE_STEPS)
		var pull := 1.0
		for n in range(notch_count):
			var notch_angle: float = dissolve_dir + (notch_spread[n] - 0.5) * 2.4
			var half_width: float = 0.22 + notch_width[n] * 0.28          # 0.22-0.50 rad
			# shortest angular distance between this sample and the notch center
			var gap: float = absf(wrapf(angle - notch_angle, -PI, PI))
			if gap < half_width:
				pull -= (0.16 + notch_depth[n] * 0.24) * 0.5 * (1.0 + cos(PI * gap / half_width))
		outline.append(Vector2(
			head_center.x + cos(angle) * head_hw * pull,
			head_center.y + sin(angle) * head_hh * pull))

	if form == 2:
		# Cloud cluster: three solid lobes under the outline give a lumpy, unmistakably wide profile.
		canvas.draw_circle(Vector2(head_center.x - head_hw * 0.58, head_center.y + head_hh * 0.18),
			head_hh * 0.78, body)
		canvas.draw_circle(Vector2(head_center.x + head_hw * 0.58, head_center.y + head_hh * 0.10),
			head_hh * 0.70, body)
		canvas.draw_circle(Vector2(head_center.x + head_hw * 0.06, head_center.y - head_hh * 0.52),
			head_hh * 0.62, body)
	canvas.draw_colored_polygon(outline, body)

	# Dark rim around the eroded outline (closed by repeating the first point).
	var rim_loop := outline.duplicate()
	rim_loop.append(outline[0])
	canvas.draw_polyline(rim_loop, Color(rim.r, rim.g, rim.b, 0.85), maxf(2.0, 0.018 * r))

	# The lit dream-core: a soft inner ellipse, opposite the dissolving side.
	canvas.draw_colored_polygon(
		_ellipse(head_center - dissolve * head_hw * 0.22, head_hw * 0.58, head_hh * 0.58, 22),
		Color(body_lit.r, body_lit.g, body_lit.b, 0.55))

	# --- the thin dreaming margin ----------------------------------------------------------------
	# Two crescents peeling off the dissolving side. They trace the head's own ELLIPSE (scaled out
	# slightly) rather than a circle — a circular arc would cut across a wide head's face.
	for i in range(2):
		var peel := 1.07 + 0.13 * float(i)
		var crescent := PackedVector2Array()
		for step in range(17):
			var angle := dissolve_dir + lerpf(-0.65, 0.65, float(step) / 16.0)
			crescent.append(Vector2(
				head_center.x + cos(angle) * head_hw * peel,
				head_center.y + sin(angle) * head_hh * peel))
		canvas.draw_polyline(crescent,
			Color(glow.r, glow.g, glow.b, 0.55 - 0.20 * float(i)), maxf(2.0, 0.016 * r))

	# --- sleeping face ---------------------------------------------------------------------------
	var face := head_center + Vector2(0.0, head_hh * 0.06)
	var eye_size := maxf(0.045 * r, head_hw * 0.24)
	match eye_style:
		0:
			_alien_eyes(canvas, face.x, face.y, head_hw * 0.46, eye_size, glow, _ONI_INK, eye_shape)
		1:
			# a single lidded eye: one closed arc across the middle of the face
			canvas.draw_arc(face, eye_size * 1.5, deg_to_rad(200), deg_to_rad(340), 14,
				_ONI_INK, maxf(2.0, 0.034 * r))
		_:
			# a row of small sleeping eyes spread across the face width
			for i in range(many_eyes):
				var slot := float(i) / float(maxi(1, many_eyes - 1)) - 0.5   # -0.5 .. +0.5
				var eye_pos := Vector2(
					face.x + slot * head_hw * 1.00,
					face.y - absf(slot) * head_hh * 0.18)                   # slight upward curve
				canvas.draw_arc(eye_pos, eye_size * 0.70, deg_to_rad(200), deg_to_rad(340), 10,
					_ONI_INK, maxf(2.0, 0.026 * r))

	if has_mouth:
		_alien_mouth(canvas, face.x, face.y + head_hh * 0.52, head_hw * 0.60, _ONI_INK, mouth_shape)

	# --- shed motes ------------------------------------------------------------------------------
	# Bits of the being that have already drifted off, kept bright so they read as sparks, not fog.
	# Orbit is clamped to 0.78r and mote radius peaks at 0.045r, so the outermost edge sits at
	# 0.825r — safely inside the disc.
	for i in range(mote_count):
		var drift_angle: float = dissolve_dir + (mote_angle[i] - 0.5) * 2.0   # motes shed to one side
		var reach := minf(0.54 + mote_reach[i] * 0.24, 0.78) * r
		var mote_r := (0.018 + mote_size[i] * 0.027) * r
		var mote_pos := c + Vector2(cos(drift_angle), sin(drift_angle)) * reach
		canvas.draw_circle(mote_pos, mote_r,
			Color(glow.r, glow.g, glow.b, 0.55 + mote_size[i] * 0.35))

	if has_sleep_symbol:
		# a drifting "z", drawn as a three-stroke polyline up and to the right of the head
		var z := Vector2(c.x + 0.50 * r, c.y - 0.52 * r)
		var zs := 0.09 * r
		canvas.draw_polyline(PackedVector2Array([
			Vector2(z.x - zs, z.y - zs), Vector2(z.x + zs, z.y - zs),
			Vector2(z.x - zs, z.y + zs), Vector2(z.x + zs, z.y + zs)]),
			Color(glow.r, glow.g, glow.b, 0.95), maxf(2.0, 0.024 * r))


# The Glossolalia Lyceum (tier 17) — a language-being whose head is a written-on page: pale
# parchment carrying bold ink-blue marks, and a "chatter band" across the lower face holding
# SEVERAL MOUTHS that all talk at once (the civ's joke, so it has to be the dominant read).
# Two rules were learned the hard way and must be kept:
#   · glyphs stay in a margin ring near the disc edge and in two short lines of "text" above the
#     eyes — nothing crosses the eyes or the mouths, or the portrait reads as CROSSED OUT;
#   · the head is pale on the dark disc, so the silhouette actually separates from the background.
const _GLO_PARCHMENTS: Array[Color] = [
	Color("#e8dcbe"), Color("#f0e6cc"), Color("#ddcfab"), Color("#eee0c0"), Color("#e2d4b4")]
const _GLO_INKS: Array[Color] = [
	Color("#2d5f8a"), Color("#1f3f68"), Color("#3a4f7a"), Color("#24506f")]
const _GLO_EYE_WHITE := Color("#fffaf0")
# Margin glyphs sit on the DARK disc, so they are drawn in this pale chalk tone, not in ink.
const _GLO_MARGIN_CHALK := Color("#c9d6e8")
# Ring radius for the margin glyphs. The widest head reaches ~0.56r and a glyph's own arm reaches
# ~0.09r, so a ring at 0.80r stays clear of the head and still well inside the disc.
const _GLO_GLYPH_RING := 0.80
const _GLO_GLYPH_ARM := 0.085

static func _draw_glossolalia(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so existing faces stay stable ---
	var parchment: Color = _GLO_PARCHMENTS[rng.randi() % _GLO_PARCHMENTS.size()]
	var ink: Color = _GLO_INKS[rng.randi() % _GLO_INKS.size()]
	# randf() is used here rather than randi() % 3 because the property seeds are near-arithmetic
	# and the low bits of an early randi() came out correlated — whole rows drew the same form.
	var form := int(rng.randf() * 3.0)                # 0 wide tablet · 1 scroll column · 2 round seal
	# width and height are sampled INDEPENDENTLY so members read stocky vs narrow vs tall
	var head_hw := (0.40 + (rng.randf() - 0.5) * 0.12) * r
	var head_hh := (0.42 + (rng.randf() - 0.5) * 0.12) * r
	var eye_shape := rng.randi() % 5
	var eye_dx_frac := 0.36 + rng.randf() * 0.12
	var eye_sz := (0.046 + rng.randf() * 0.016) * r
	var mouth_count := 2 + rng.randi() % 3            # ALWAYS several: speaking in tongues is the read
	var mouth_layout := rng.randi() % 4               # 0 column · 1 two columns · 2 zig-zag · 3 chorus
	var mouth_shapes: Array[int] = []
	for _i in range(mouth_count):
		mouth_shapes.append(rng.randi() % 4)          # each mouth says something different
	var glyph_count := 3 + rng.randi() % 3
	# One random per margin glyph: which of three abstract marks it is, plus a little radius jitter.
	var glyph_kinds: Array[int] = []
	var glyph_jitter: Array[float] = []
	for _i in range(glyph_count):
		glyph_kinds.append(rng.randi() % 3)
		glyph_jitter.append(rng.randf())
	var has_lens := rng.randf() < 0.40

	var robe := ink.darkened(0.35)
	var hc := Vector2(c.x, c.y - 0.07 * r)            # head sits slightly high, leaving room for shoulders
	var bold := maxf(2.0, 0.040 * r)                  # margin glyphs; hairlines turn to mush at 40px
	var mark := maxf(2.0, 0.026 * r)                  # markings drawn ON the parchment

	# --- margin glyphs: a ring of separate marks near the disc edge -----------------------------
	# Angles are spread across the TOP arc only (200°..340°); the shoulders own the bottom. Each
	# glyph is a small self-contained mark and none is long enough to reach another, so they cannot
	# combine into a big X across the portrait.
	for i in range(glyph_count):
		var glyph_spread: float = float(i) / float(maxi(1, glyph_count - 1))
		var angle := lerpf(deg_to_rad(200.0), deg_to_rad(340.0), glyph_spread)
		var ring := (_GLO_GLYPH_RING + (glyph_jitter[i] - 0.5) * 0.06) * r
		var outward := Vector2(cos(angle), sin(angle))
		var along := Vector2(-outward.y, outward.x)    # tangent to the ring at this glyph
		var p := c + outward * ring
		var arm := _GLO_GLYPH_ARM * r
		match glyph_kinds[i]:
			0:  # a bar lying along the ring with a dot beside it — a word and its accent
				canvas.draw_line(p - along * arm, p + along * arm, _GLO_MARGIN_CHALK, bold)
				canvas.draw_circle(p + outward * arm * 0.65, bold * 0.6, _GLO_MARGIN_CHALK)
			1:  # a hook: along the ring, then turning outward
				canvas.draw_polyline(PackedVector2Array([
					p - along * arm, p + along * arm * 0.5,
					p + along * arm * 0.5 + outward * arm * 0.85]), _GLO_MARGIN_CHALK, bold)
			2:  # two stacked short bars — a paragraph mark
				canvas.draw_line(p - along * arm * 0.85 - outward * arm * 0.4,
					p + along * arm * 0.85 - outward * arm * 0.4, _GLO_MARGIN_CHALK, bold)
				canvas.draw_line(p - along * arm * 0.5 + outward * arm * 0.4,
					p + along * arm * 0.5 + outward * arm * 0.4, _GLO_MARGIN_CHALK, bold)

	# --- body: scholar's robe ------------------------------------------------------------------
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.34), robe)

	# --- head silhouette: three genuinely different constructions ------------------------------
	# Each form stretches the sampled size toward its own proportion (the tablet is squat and wide,
	# the scroll is narrow and tall, the seal is circular), so the silhouettes differ at a glance.
	# face_* is the area the features are laid out in. The three values after it describe the head's
	# lower body, which the chatter band is fitted into further down: a straight-sided head reports a
	# half-width and a bottom edge, a round head reports a radius instead.
	var face_c := hc
	var face_hw := head_hw
	var face_hh := head_hh
	var body_hw := 0.0                                # half-width of a straight-sided head
	var body_bottom := 0.0                            # y of a straight-sided head's bottom edge
	var round_radius := 0.0                           # > 0 only for the circular seal head
	match form:
		0:  # a wide stone tablet: flat top, chamfered upper corners, straight sides, ink border
			var slab_hw := head_hw * 1.18
			var slab_hh := head_hh * 0.84
			var tablet := PackedVector2Array([
				Vector2(hc.x - slab_hw, hc.y - slab_hh * 0.60),
				Vector2(hc.x - slab_hw * 0.62, hc.y - slab_hh),
				Vector2(hc.x + slab_hw * 0.62, hc.y - slab_hh),
				Vector2(hc.x + slab_hw, hc.y - slab_hh * 0.60),
				Vector2(hc.x + slab_hw, hc.y + slab_hh),
				Vector2(hc.x - slab_hw, hc.y + slab_hh)])
			canvas.draw_colored_polygon(tablet, parchment)
			# repeating the first point closes the polyline, so the border runs all the way round
			var border := tablet.duplicate()
			border.append(tablet[0])
			canvas.draw_polyline(border, ink, mark)
			face_hw = slab_hw * 0.92
			face_hh = slab_hh
			body_hw = slab_hw
			body_bottom = hc.y + slab_hh
		1:  # a scroll column: narrow tall sheet with a fat ink dowel across the top and bottom
			var sheet_hw := head_hw * 0.62
			var sheet_hh := head_hh * 1.10
			canvas.draw_rect(Rect2(hc.x - sheet_hw, hc.y - sheet_hh,
				sheet_hw * 2.0, sheet_hh * 2.0), parchment)
			for dowel_side in [-1.0, 1.0]:
				var dowel := Vector2(hc.x, hc.y + float(dowel_side) * sheet_hh)
				canvas.draw_colored_polygon(_ellipse(dowel, sheet_hw * 1.30, 0.055 * r, 18), ink)
				canvas.draw_colored_polygon(_ellipse(dowel, sheet_hw * 0.20, 0.030 * r, 12), parchment)
			face_hw = sheet_hw
			face_hh = sheet_hh * 0.86                 # keep the features clear of the two dowels
			body_hw = sheet_hw
			body_bottom = hc.y + sheet_hh * 0.90
		2:  # a wax-seal head: a plain round page stamped with a heavy ink ring
			# Deliberately circular (width and height averaged) so its silhouette cannot be
			# confused with the squat slab or the narrow column.
			var seal_r := (head_hw + head_hh) * 0.56
			canvas.draw_circle(hc, seal_r, parchment)
			canvas.draw_arc(hc, seal_r * 0.90, 0.0, TAU, 32, ink, bold)
			face_hw = seal_r * 0.80
			face_hh = seal_r * 0.80
			round_radius = seal_r * 0.90              # keep the band inside the stamped ring

	# --- two short lines of "text" above the eyes: the only writing allowed on the face ---------
	# Ragged right-hand ends (0.56 then 0.30 of the half-width) are what make this read as text
	# rather than as a fringe of hair. Both lines stay well above the eye line.
	for i in range(2):
		var line_y := face_c.y - face_hh * (0.86 - float(i) * 0.17)
		var line_end := face_hw * (0.56 if i == 0 else 0.30)
		canvas.draw_line(Vector2(face_c.x - face_hw * 0.58, line_y),
			Vector2(face_c.x + line_end, line_y), ink, mark)

	# --- eyes sit high, so the whole lower face is free for the mouths --------------------------
	var eye_y := face_c.y - face_hh * 0.36
	_alien_eyes(canvas, face_c.x, eye_y, face_hw * eye_dx_frac, eye_sz,
		_GLO_EYE_WHITE, ink, eye_shape)

	# --- the chatter band: the lower face, tinted and ruled off, holding all of the mouths ------
	# Grouping the mouths inside one marked-off area is what makes several of them read as "this
	# creature has many mouths" instead of as one mouth plus a few stray squiggles.
	var band_top := face_c.y + face_hh * 0.10
	var band_bottom := body_bottom
	var band_hw := body_hw * 0.90
	if round_radius > 0.0:
		# the lower circular segment of the seal head, so the tint never spills past the rim
		canvas.draw_colored_polygon(
			_disc_segment_below(hc, round_radius, (band_top - hc.y) / round_radius),
			parchment.darkened(0.20))
		band_bottom = hc.y + round_radius
		band_hw = round_radius * 0.58                 # narrow enough to stay inside the curve
	else:
		canvas.draw_rect(Rect2(hc.x - band_hw, band_top, band_hw * 2.0, band_bottom - band_top),
			parchment.darkened(0.20))
	var rule_hw := band_hw
	if round_radius > 0.0:
		# half-length of the circle's chord at band_top, so the rule meets the head's outline
		var drop := band_top - hc.y
		rule_hw = sqrt(maxf(0.0, round_radius * round_radius - drop * drop))
	canvas.draw_line(Vector2(hc.x - rule_hw, band_top),
		Vector2(hc.x + rule_hw, band_top), ink, mark)

	# --- the mouths: evenly slotted through the band, sized so they never touch -----------------
	# Four mouths in one vertical stack always nest into a spiral of arcs, so a four-mouth member
	# is sent to the two-column grid instead. The chorus arrangement already spreads sideways.
	if mouth_count >= 4 and mouth_layout != 3:
		mouth_layout = 1
	var band_h := band_bottom - band_top
	var grid_rows := int(ceil(float(mouth_count) / 2.0))   # only the two-column layout uses this
	var row_h := band_h / float(mouth_count)
	# A mouth much wider than the gap to the next row reads as one nested arc pattern rather than
	# as separate mouths, so the width is held to about 1.6 row-heights.
	var mouth_w := minf(band_hw * 1.20, row_h * 1.6)
	match mouth_layout:
		1:  # two columns: each mouth gets half the width and one of the grid's rows
			mouth_w = minf(band_hw * 0.80, band_h / float(grid_rows) * 1.7)
		3:  # chorus: the wide bottom mouth sets the size for all of them
			mouth_w = minf(band_hw * 0.90, band_h * 0.55)
	for i in range(mouth_count):
		# slot walks down the band's rows; the +0.5 centres each mouth inside its own row
		var slot: float = (float(i) + 0.5) / float(mouth_count)
		var mx: float = hc.x
		var my: float = lerpf(band_top, band_bottom, slot)
		match mouth_layout:
			0:  # a single column straight down the middle of the band
				pass
			1:  # two columns of mouths, filling left-right then top-down
				var grid_row: float = float(i / 2)
				mx = hc.x + band_hw * (-0.46 if i % 2 == 0 else 0.46)
				my = band_top + band_h * (grid_row + 0.5) / float(grid_rows)
			2:  # zig-zag: the rows step slightly left and right as they descend
				mx = hc.x + band_hw * (0.24 if i % 2 == 0 else -0.24)
			3:  # chorus: one wide mouth low down, the rest crowding in above it
				if i == 0:
					my = band_top + band_h * 0.76
				else:
					mx = hc.x + band_hw * lerpf(-0.42, 0.42, slot)
					my = band_top + band_h * 0.28
		_alien_mouth(canvas, mx, my, mouth_w, ink, mouth_shapes[i])

	# --- overlay: a reading lens ringed over one eye (the pedant checking your spelling) --------
	if has_lens:
		var lens := Vector2(face_c.x + face_hw * eye_dx_frac, eye_y)
		var lens_r := maxf(eye_sz * 1.6, 0.070 * r)
		canvas.draw_arc(lens, lens_r, 0.0, TAU, 24, ink, mark)
		# a short stem running outward from the rim, toward where a hand would hold it
		canvas.draw_line(lens + Vector2(lens_r, 0.0),
			lens + Vector2(lens_r + 0.055 * r, 0.018 * r), ink, mark)


# Ferrovore Guilds (tier 18) — a rust-eating being: corroded plating bolted onto living flesh, patina
# blooms, an iron jaw with chewed teeth. Three silhouettes (anvil chewer / smelter stack / half-eaten
# head) plus independent width and height sampling, so no two guild members share an outline.
const _FER_PLATES: Array[Color] = [
	Color("#8a4a1c"), Color("#7a3f18"), Color("#9a5a24"), Color("#6e4420"), Color("#a05e28")]
const _FER_FLESH: Array[Color] = [Color("#5b3a24"), Color("#4a3020"), Color("#6a452c")]
const _FER_PATINAS: Array[Color] = [Color("#4f8c78"), Color("#3f7d6c"), Color("#67a58c")]
const _FER_RUST := Color("#c8702a")
const _FER_INGOT := Color("#b9c2c8")
const _FER_INK := Color("#2a1608")

static func _draw_ferrovore(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn here, in a fixed order, so faces stay stable ---
	var plate: Color = _FER_PLATES[rng.randi() % _FER_PLATES.size()]
	var flesh: Color = _FER_FLESH[rng.randi() % _FER_FLESH.size()]
	var patina: Color = _FER_PATINAS[rng.randi() % _FER_PATINAS.size()]
	# Width and height are sampled independently (±25% each) so members read stocky / narrow / tall
	# rather than as one head scaled up and down.
	var hw := 0.34 * (0.75 + rng.randf() * 0.5) * r      # head half-width
	var hh := 0.36 * (0.75 + rng.randf() * 0.5) * r      # head half-height
	var form := rng.randi() % 3                          # 0 anvil · 1 smelter stack · 2 half-eaten
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var rivets := rng.randi() % 5                        # 0-4 bolts along the brow plate
	var patches := 2 + rng.randi() % 4                   # rust / patina blooms
	var has_ingot := rng.randf() < 0.45                  # an ingot clenched in the teeth
	var has_jaw_plate := rng.randf() < 0.6               # bolted-on lower jaw plate with teeth
	var eaten_side := -1.0 if rng.randf() < 0.5 else 1.0 # which side the corrosion has chewed away
	var bite_depth := 0.16 + rng.randf() * 0.20          # how much of that side is gone (form 2)
	var patch_x: Array[float] = []
	var patch_y: Array[float] = []
	var patch_r: Array[float] = []
	for _i in range(patches):
		patch_x.append(rng.randf())
		patch_y.append(rng.randf())
		patch_r.append(rng.randf())

	var hc := Vector2(c.x, c.y - 0.04 * r)               # head center, nudged up to leave room for shoulders
	var stroke := maxf(2.0, 0.022 * r)

	# --- body: corroded shoulders hugging the bottom of the disc ---
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.30), plate.darkened(0.35))
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.46), plate.darkened(0.15))

	# --- head silhouette: three genuinely different outlines ---
	var head := PackedVector2Array()
	if form == 0:
		# Anvil chewer: wide flared brow flange, pinched cheeks, blocky chin — a walking anvil.
		head = PackedVector2Array([
			Vector2(hc.x - hw * 1.28, hc.y - hh), Vector2(hc.x + hw * 1.28, hc.y - hh),
			Vector2(hc.x + hw * 0.95, hc.y - hh * 0.55), Vector2(hc.x + hw * 0.72, hc.y + hh * 0.45),
			Vector2(hc.x + hw * 0.95, hc.y + hh), Vector2(hc.x - hw * 0.95, hc.y + hh),
			Vector2(hc.x - hw * 0.72, hc.y + hh * 0.45), Vector2(hc.x - hw * 0.95, hc.y - hh * 0.55)])
	elif form == 1:
		# Smelter stack: narrow tapering column with a chimney on top that still vents rust smoke.
		var w := hw * 0.74
		head = PackedVector2Array([
			Vector2(hc.x - w, hc.y - hh), Vector2(hc.x + w, hc.y - hh),
			Vector2(hc.x + w * 1.05, hc.y + hh * 0.6), Vector2(hc.x, hc.y + hh),
			Vector2(hc.x - w * 1.05, hc.y + hh * 0.6)])
	else:
		# Half-eaten: a rounded head whose corroded side has been gnawed into a jagged coastline.
		for i in range(20):
			var a := TAU * float(i) / 20.0
			var px := cos(a)
			var py := sin(a)
			# Only the eaten side loses radius, and alternating points make the loss look bitten.
			var chew := 1.0
			if px * eaten_side > 0.0:
				chew = 1.0 - bite_depth * (0.4 + 0.6 * float(i % 2)) * absf(px)
			head.append(Vector2(hc.x + px * hw * chew, hc.y + py * hh * chew))
	canvas.draw_colored_polygon(head, flesh)

	# --- front plating bolted over the flesh: a brow band, and a jaw plate on some members ---
	# The plate tracks the silhouette's own width so it never floats outside the narrow stack form.
	var plate_hw := hw * 0.70 if form == 1 else hw * 0.90
	var brow_top := hc.y - hh * 0.62
	var brow_h := hh * 0.55
	canvas.draw_rect(Rect2(hc.x - plate_hw, brow_top, plate_hw * 2.0, brow_h), plate)
	canvas.draw_line(Vector2(hc.x - plate_hw, brow_top + brow_h), Vector2(hc.x + plate_hw, brow_top + brow_h),
		plate.darkened(0.45), stroke)
	if has_jaw_plate:
		var jaw_y := hc.y + hh * 0.34
		canvas.draw_rect(Rect2(hc.x - plate_hw * 0.88, jaw_y, plate_hw * 1.76, hh * 0.44), plate.darkened(0.20))
		# Chewed edge: triangles bitten out of the top of the jaw plate.
		for i in range(4):
			var tx := hc.x - plate_hw * 0.60 + plate_hw * 0.40 * float(i)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(tx - plate_hw * 0.12, jaw_y), Vector2(tx + plate_hw * 0.12, jaw_y),
				Vector2(tx, jaw_y + hh * 0.20)]), flesh)

	if form == 1:
		# Chimney and two smoke puffs, kept well inside the disc (top reaches about 0.75r).
		canvas.draw_rect(Rect2(hc.x - hw * 0.30, hc.y - hh - 0.16 * r, hw * 0.60, 0.16 * r), plate.darkened(0.25))
		canvas.draw_circle(Vector2(hc.x - hw * 0.10, hc.y - hh - 0.22 * r), 0.05 * r, Color(_FER_RUST.r, _FER_RUST.g, _FER_RUST.b, 0.35))
		canvas.draw_circle(Vector2(hc.x + hw * 0.22, hc.y - hh - 0.28 * r), 0.035 * r, Color(_FER_RUST.r, _FER_RUST.g, _FER_RUST.b, 0.25))

	# --- bolts along the brow plate ---
	for i in range(rivets):
		var bx := hc.x - plate_hw * 0.78 + (plate_hw * 1.56) * (float(i) / float(maxi(1, rivets - 1)))
		canvas.draw_circle(Vector2(bx, brow_top + brow_h * 0.22), maxf(2.0, 0.022 * r), _FER_INGOT.darkened(0.35))

	# --- face ---
	_alien_eyes(canvas, hc.x, hc.y - hh * 0.20, hw * 0.46, hw * 0.22, _FER_RUST.lightened(0.35), _FER_INK, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + hh * 0.62, hw * 0.80, _FER_INK, mouth_shape)
	if has_ingot:
		# A raw ingot clenched sideways in the teeth — lunch, and also this quarter's earnings.
		var iy := hc.y + hh * 0.62
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x - hw * 0.34, iy - hh * 0.08), Vector2(hc.x + hw * 0.34, iy - hh * 0.12),
			Vector2(hc.x + hw * 0.28, iy + hh * 0.12), Vector2(hc.x - hw * 0.28, iy + hh * 0.10)]), _FER_INGOT)

	# --- rust and patina blooms last, so they sit on top of plating and flesh alike ---
	for i in range(patches):
		var pc: Color = patina if i % 2 == 0 else _FER_RUST
		var px2 := hc.x + (patch_x[i] * 2.0 - 1.0) * hw * 0.85
		var py2 := hc.y + (patch_y[i] * 2.0 - 1.0) * hh * 0.85
		canvas.draw_circle(Vector2(px2, py2), (0.04 + patch_r[i] * 0.06) * r, Color(pc.r, pc.g, pc.b, 0.42))
	# A corrosion streak weeping down the eaten side.
	canvas.draw_line(Vector2(hc.x + eaten_side * hw * 0.80, hc.y - hh * 0.30),
		Vector2(hc.x + eaten_side * hw * 0.70, hc.y + hh * 0.85),
		Color(_FER_RUST.r, _FER_RUST.g, _FER_RUST.b, 0.5), stroke)


# The Vantablack Salon (tier 19) — an art-critic void: a near-black silhouette read only by its
# rim light and thin white accessories (beret, monocle or wire spectacles, cigarette holder).
const _VAN_VOID := Color("#1a1a1a")        # very slightly lifted black, so the body reads on the dark UI
const _VAN_RIMS: Array[Color] = [          # cool grays for the rim light — the only "color" allowed
	Color("#4a4f55"), Color("#565c63"), Color("#3f444a"), Color("#61686f")]
const _VAN_LINE := Color("#f2f4f6")        # the bright line-work that carries all recognition
const _VAN_DIM := Color("#8d949b")         # half-strength line, for secondary details

static func _draw_vantablack(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- all randomness drawn up front, in a fixed order (file convention) ---
	var width_scale := 0.76 + rng.randf() * 0.48      # ±24% half-width, sampled...
	var height_scale := 0.76 + rng.randf() * 0.48     # ...independently of half-height
	var form := rng.randi() % 3                       # 0 tall aesthete · 1 low blot · 2 angular wedge
	var rim: Color = _VAN_RIMS[rng.randi() % _VAN_RIMS.size()]
	var eyewear := rng.randi() % 3                    # 0 monocle · 1 wire spectacles · 2 bare
	var has_beret := rng.randf() < 0.6
	var beret_tilt := deg_to_rad(-30.0 + rng.randf() * 60.0)   # kept shallow so the brim stays in the disc
	var has_holder := rng.randf() < 0.55              # long cigarette holder
	var collar := rng.randi() % 3                     # 0 none · 1 low collar · 2 high turtleneck
	var brow_side := 1.0 if rng.randf() < 0.5 else -1.0   # which side the appraising brow lifts
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4

	# --- silhouette dimensions: each form has its own base proportions, then the two scales ---
	var half_w := 0.0
	var half_h := 0.0
	match form:
		0:  # tall narrow aesthete
			half_w = 0.27 * r * width_scale
			half_h = 0.42 * r * height_scale
		1:  # wide low brooding blot
			half_w = 0.40 * r * width_scale
			half_h = 0.31 * r * height_scale
		_:  # angular geometric wedge
			half_w = 0.34 * r * width_scale
			half_h = 0.36 * r * height_scale
	var hc := Vector2(c.x, c.y - 0.06 * r)            # head sits slightly high, leaving room for shoulders

	# --- build the head outline for this form (genuinely different constructions) ---
	var head := PackedVector2Array()
	match form:
		0:  # egg drawn out to a point above: an elongated cranium
			head = PackedVector2Array([
				Vector2(hc.x, hc.y - half_h * 1.10),
				Vector2(hc.x + half_w * 0.62, hc.y - half_h * 0.70),
				Vector2(hc.x + half_w, hc.y - half_h * 0.05),
				Vector2(hc.x + half_w * 0.78, hc.y + half_h * 0.74),
				Vector2(hc.x + half_w * 0.28, hc.y + half_h),
				Vector2(hc.x - half_w * 0.28, hc.y + half_h),
				Vector2(hc.x - half_w * 0.78, hc.y + half_h * 0.74),
				Vector2(hc.x - half_w, hc.y - half_h * 0.05),
				Vector2(hc.x - half_w * 0.62, hc.y - half_h * 0.70)])
		1:  # a squat rounded blot, heavier below the eyes than above
			head = _ellipse(Vector2(hc.x, hc.y + half_h * 0.10), half_w, half_h, 22)
		_:  # a hard-edged wedge: flat top, walls tapering to a narrow chin
			head = PackedVector2Array([
				Vector2(hc.x - half_w * 0.72, hc.y - half_h),
				Vector2(hc.x + half_w * 0.72, hc.y - half_h),
				Vector2(hc.x + half_w, hc.y - half_h * 0.10),
				Vector2(hc.x + half_w * 0.34, hc.y + half_h),
				Vector2(hc.x - half_w * 0.34, hc.y + half_h),
				Vector2(hc.x - half_w, hc.y - half_h * 0.10)])

	# A copy of the outline pushed 5% outward from the head centre, drawn behind as the rim light.
	var head_rim := PackedVector2Array()
	for p: Vector2 in head:
		head_rim.append(hc + (p - hc) * 1.06)

	# --- draw back to front: rim light, silhouette, then bright line-work ---
	var collar_cut := 0.30 * r if collar == 2 else 0.38 * r     # a high turtleneck starts higher up
	canvas.draw_colored_polygon(_disc_segment_below(c, r, (collar_cut - 0.025 * r) / r), rim)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, collar_cut / r), _VAN_VOID)
	canvas.draw_colored_polygon(head_rim, rim)
	canvas.draw_colored_polygon(head, _VAN_VOID)

	if collar > 0:
		# One or two thin ridges along the top of the garment read as knitted turtleneck ribbing.
		canvas.draw_line(Vector2(c.x - 0.52 * r, c.y + collar_cut), Vector2(c.x + 0.52 * r, c.y + collar_cut),
			_VAN_DIM, maxf(2.0, 0.016 * r))
		if collar == 2:
			canvas.draw_line(Vector2(c.x - 0.46 * r, c.y + collar_cut + 0.07 * r),
				Vector2(c.x + 0.46 * r, c.y + collar_cut + 0.07 * r), _VAN_DIM, maxf(2.0, 0.014 * r))

	# --- face: white eyes on the void, a thin mouth, one raised brow ---
	var eye_dx := half_w * 0.44
	var eye_y := hc.y - half_h * 0.12
	var mouth_y := hc.y + half_h * 0.58
	_alien_eyes(canvas, hc.x, eye_y, eye_dx, 0.055 * r, _VAN_LINE, _VAN_VOID, eye_shape)
	_alien_mouth(canvas, hc.x, mouth_y, 0.20 * r, _VAN_LINE, mouth_shape)
	# The appraising brow: a shallow arc lifted well clear of one eye only.
	canvas.draw_arc(Vector2(hc.x + brow_side * eye_dx, eye_y - 0.10 * r), 0.09 * r,
		deg_to_rad(200), deg_to_rad(340), 10, _VAN_LINE, maxf(2.0, 0.016 * r))

	# --- eyewear ---
	var lens_r := 0.13 * r
	if eyewear == 0:
		# Monocle on the brow-raised side, with a chain dropping toward the collar.
		var lens_c := Vector2(hc.x + brow_side * eye_dx, eye_y)
		canvas.draw_arc(lens_c, lens_r, 0.0, TAU, 26, _VAN_LINE, maxf(2.0, 0.018 * r))
		canvas.draw_polyline(PackedVector2Array([
			lens_c + Vector2(brow_side * lens_r, lens_r * 0.6),
			lens_c + Vector2(brow_side * lens_r * 1.5, lens_r * 2.2),
			lens_c + Vector2(brow_side * lens_r * 1.1, lens_r * 3.4)]), _VAN_DIM, maxf(2.0, 0.013 * r))
	elif eyewear == 1:
		# Wire spectacles: two rings, a bridge, and short temple arms toward the head edge.
		for sx in [-1.0, 1.0]:
			var lens := Vector2(hc.x + sx * eye_dx, eye_y)
			canvas.draw_arc(lens, lens_r, 0.0, TAU, 26, _VAN_LINE, maxf(2.0, 0.016 * r))
			canvas.draw_line(lens + Vector2(sx * lens_r, 0.0),
				Vector2(hc.x + sx * half_w * 0.98, eye_y - 0.03 * r), _VAN_DIM, maxf(2.0, 0.013 * r))
		canvas.draw_line(Vector2(hc.x - eye_dx + lens_r, eye_y), Vector2(hc.x + eye_dx - lens_r, eye_y),
			_VAN_LINE, maxf(2.0, 0.014 * r))

	# --- beret: a tilted cap disc with a brim nub, clamped so it never leaves the portrait disc ---
	if has_beret:
		var crown_y := hc.y - half_h * (1.02 if form == 0 else 0.92)
		var beret_c := Vector2(hc.x, maxf(crown_y + 0.05 * r, c.y - 0.62 * r))
		var beret_hw := half_w * 0.98
		var beret_hh := 0.15 * r
		canvas.draw_colored_polygon(_ellipse(beret_c, beret_hw, beret_hh, 20), _VAN_VOID)
		# Trace only the UPPER half of that same ellipse, so the highlight hugs the cap it belongs to.
		var cap_edge := PackedVector2Array()
		for i in range(13):
			var a := lerpf(PI, TAU, float(i) / 12.0)
			cap_edge.append(Vector2(beret_c.x + cos(a) * beret_hw, beret_c.y + sin(a) * beret_hh))
		canvas.draw_polyline(cap_edge, _VAN_LINE, maxf(2.0, 0.017 * r))
		var brim := beret_c + Vector2(cos(beret_tilt), sin(beret_tilt)) * 0.26 * r
		canvas.draw_line(beret_c, brim, _VAN_LINE, maxf(2.0, 0.018 * r))
		canvas.draw_circle(brim, 0.03 * r, _VAN_LINE)

	# --- cigarette holder: a long stem out of the mouth corner, ember at the far tip ---
	if has_holder:
		var stem_start := Vector2(hc.x + half_w * 0.30, mouth_y)
		var stem_end := stem_start + Vector2(0.30 * r, -0.14 * r)
		canvas.draw_line(stem_start, stem_end, _VAN_LINE, maxf(2.0, 0.016 * r))
		canvas.draw_circle(stem_end, 0.028 * r, _VAN_DIM)


# Fortuna Cartel (tier 20) — a gambling-house being: the head is literally casino hardware (a pipped
# die-block, a roulette wheel, or a flat playing card), worn with a dealer's visor over chip stacks.
const _FOR_FELTS: Array[Color] = [
	Color("#1f6e43"), Color("#18583a"), Color("#256b4c"), Color("#14513a"), Color("#2a7a4a")]
const _FOR_IVORY := Color("#f2ece0")        # die body / card stock
const _FOR_INK := Color("#241d18")          # pips, spades, outlines
const _FOR_RED := Color("#b8242c")          # diamonds and red roulette pockets
const _FOR_VISOR := Color("#3fbe78")        # dealer's translucent green visor
const _FOR_GOLD := Color("#d9b64a")
const _FOR_CHIPS: Array[Color] = [
	Color("#b8242c"), Color("#2b5fa8"), Color("#e8e2d4"), Color("#2b2b2b"), Color("#d9b64a")]


static func _draw_fortuna(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so faces stay stable -------------
	var felt: Color = _FOR_FELTS[rng.randi() % _FOR_FELTS.size()]
	var form := rng.randi() % 3                       # 0 = die block · 1 = roulette wheel · 2 = card
	var head_hw := (0.30 + rng.randf() * 0.15) * r    # width and height are sampled INDEPENDENTLY,
	var head_hh := (0.30 + rng.randf() * 0.15) * r    # so members read stocky / narrow / tall
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var pips := 2 + rng.randi() % 4                   # loose pips marking the head
	var has_visor := rng.randf() < 0.6
	var suit_is_spade := rng.randf() < 0.5            # chest marking: spade or diamond
	var spokes := 6 + rng.randi() % 7                 # roulette form only
	var stack_count := rng.randi() % 3                # 0-2 chip stacks on the shoulders
	var chip_heights: Array[int] = []
	var chip_colors: Array[Color] = []
	for _i in range(4):                               # up-front pool, indexed while drawing stacks
		chip_heights.append(2 + rng.randi() % 3)
		chip_colors.append(_FOR_CHIPS[rng.randi() % _FOR_CHIPS.size()])

	# Card heads are deliberately flatter and wider than the other two silhouettes.
	if form == 2:
		head_hw *= 1.18
		head_hh *= 0.82
	var hc := Vector2(c.x, c.y - 0.06 * r)            # head center, lifted to leave room for shoulders
	var stroke := maxf(2.0, 0.022 * r)

	# --- background felt + shoulders ---------------------------------------------------------------
	canvas.draw_circle(c, 0.97 * r, felt.darkened(0.45))
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.40), felt)

	# --- chest suit marking (drawn before the chip stacks so stacks sit in front) ------------------
	var suit := Vector2(c.x, c.y + 0.62 * r)
	var ss := 0.11 * r
	if suit_is_spade:
		# spade = upward triangle + two lobes at its base + a short stem
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(suit.x, suit.y - ss),
			Vector2(suit.x - ss * 0.8, suit.y + ss * 0.25), Vector2(suit.x + ss * 0.8, suit.y + ss * 0.25)]), _FOR_INK)
		canvas.draw_circle(Vector2(suit.x - ss * 0.42, suit.y + ss * 0.22), ss * 0.38, _FOR_INK)
		canvas.draw_circle(Vector2(suit.x + ss * 0.42, suit.y + ss * 0.22), ss * 0.38, _FOR_INK)
		canvas.draw_rect(Rect2(suit.x - ss * 0.10, suit.y + ss * 0.30, ss * 0.20, ss * 0.45), _FOR_INK)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(suit.x, suit.y - ss),
			Vector2(suit.x + ss * 0.7, suit.y), Vector2(suit.x, suit.y + ss), Vector2(suit.x - ss * 0.7, suit.y)]), _FOR_RED)

	# --- chip stacks on the shoulders (mirrored pairs, kept well inside the disc) ------------------
	for i in range(stack_count):
		for sx in [-1.0, 1.0]:
			var base := Vector2(c.x + sx * (0.30 + float(i) * 0.09) * r, c.y + 0.74 * r - float(i) * 0.05 * r)
			for k in range(chip_heights[i]):
				var chip: Color = chip_colors[i] if k % 2 == 0 else chip_colors[i].lightened(0.35)
				canvas.draw_colored_polygon(_ellipse(Vector2(base.x, base.y - float(k) * 0.055 * r),
					0.085 * r, 0.030 * r, 14), chip)

	# --- head silhouette: three genuinely different constructions ---------------------------------
	match form:
		0:  # a blocky die: rounded-corner square, ivory, with loose pips
			var cut := minf(head_hw, head_hh) * 0.28
			var block := PackedVector2Array([
				Vector2(hc.x - head_hw, hc.y - head_hh + cut), Vector2(hc.x - head_hw + cut, hc.y - head_hh),
				Vector2(hc.x + head_hw - cut, hc.y - head_hh), Vector2(hc.x + head_hw, hc.y - head_hh + cut),
				Vector2(hc.x + head_hw, hc.y + head_hh - cut), Vector2(hc.x + head_hw - cut, hc.y + head_hh),
				Vector2(hc.x - head_hw + cut, hc.y + head_hh), Vector2(hc.x - head_hw, hc.y + head_hh - cut)])
			canvas.draw_colored_polygon(block, _FOR_IVORY)
			var loop := block.duplicate()
			loop.append(block[0])                     # close the outline
			canvas.draw_polyline(loop, _FOR_INK, stroke)
		1:  # a roulette wheel: disc, radial spokes, alternating rim pockets, gold hub ring
			canvas.draw_colored_polygon(_ellipse(hc, head_hw, head_hh, 26), _FOR_IVORY.darkened(0.10))
			for i in range(spokes):
				var a := TAU * float(i) / float(spokes)
				canvas.draw_line(hc, Vector2(hc.x + cos(a) * head_hw * 0.92, hc.y + sin(a) * head_hh * 0.92),
					_FOR_INK, maxf(2.0, 0.014 * r))
				var pocket := Vector2(hc.x + cos(a) * head_hw * 0.78, hc.y + sin(a) * head_hh * 0.78)
				canvas.draw_circle(pocket, minf(head_hw, head_hh) * 0.10, _FOR_RED if i % 2 == 0 else _FOR_INK)
			canvas.draw_arc(hc, minf(head_hw, head_hh) * 0.95, 0.0, TAU, 28, _FOR_GOLD, stroke)
		2:  # a playing card: flat wide rectangle with corner suit pips
			var card := PackedVector2Array([
				Vector2(hc.x - head_hw, hc.y - head_hh), Vector2(hc.x + head_hw, hc.y - head_hh),
				Vector2(hc.x + head_hw, hc.y + head_hh), Vector2(hc.x - head_hw, hc.y + head_hh)])
			canvas.draw_colored_polygon(card, _FOR_IVORY)
			var edge := card.duplicate()
			edge.append(card[0])
			canvas.draw_polyline(edge, _FOR_INK, stroke)
			# a tiny diamond in two opposite corners, the way an index pip sits on a real card
			var pip_r := minf(head_hw, head_hh) * 0.16
			for sgn in [-1.0, 1.0]:
				var p := Vector2(hc.x + sgn * head_hw * 0.80, hc.y + sgn * head_hh * 0.72)
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(p.x, p.y - pip_r),
					Vector2(p.x + pip_r * 0.7, p.y), Vector2(p.x, p.y + pip_r), Vector2(p.x - pip_r * 0.7, p.y)]), _FOR_RED)

	# --- dealer's visor: a green brim band sitting just above the eyes -----------------------------
	if has_visor:
		var band_y := hc.y - head_hh * 0.50
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x - head_hw * 0.95, band_y - head_hh * 0.18),
			Vector2(hc.x + head_hw * 0.95, band_y - head_hh * 0.18),
			Vector2(hc.x + head_hw * 0.95, band_y + head_hh * 0.10),
			Vector2(hc.x, band_y + head_hh * 0.22),                    # brim dips lowest at the nose
			Vector2(hc.x - head_hw * 0.95, band_y + head_hh * 0.10)]),
			Color(_FOR_VISOR.r, _FOR_VISOR.g, _FOR_VISOR.b, 0.85))
		canvas.draw_line(Vector2(hc.x - head_hw * 0.95, band_y - head_hh * 0.16),
			Vector2(hc.x + head_hw * 0.95, band_y - head_hh * 0.16), _FOR_GOLD, stroke)

	# --- loose pips: on the forehead when bare, on the chin when a visor covers the brow -----------
	var pip_y := hc.y + head_hh * 0.74 if has_visor else hc.y - head_hh * 0.62
	var pip_span := head_hw * 1.1
	for i in range(pips):
		var t := 0.5 if pips == 1 else float(i) / float(pips - 1)
		canvas.draw_circle(Vector2(hc.x - pip_span * 0.5 + pip_span * t, pip_y),
			minf(head_hw, head_hh) * 0.09, _FOR_INK)

	# --- face ---------------------------------------------------------------------------------------
	var eye_sz := minf(head_hw, head_hh) * 0.22
	_alien_eyes(canvas, hc.x, hc.y - head_hh * 0.05, head_hw * 0.44, eye_sz, _FOR_IVORY, _FOR_INK, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + head_hh * 0.46, head_hw * 0.62, _FOR_INK, mouth_shape)


# Mirror Meridian (tier 21) — a polished mirror-being: a chrome shell with a bright horizon
# "meridian" band and hard specular glints, split by a mirror seam whose two halves never quite
# agree — silhouette, seam tilt, half-mismatch and the doubled "reflection" all vary per staffer.
const _MIR_CHROME: Array[Color] = [
	Color("#8e99a4"), Color("#7f8b99"), Color("#9aa5b0"), Color("#8794a6"), Color("#a2acb6")]
const _MIR_GLINTS: Array[Color] = [
	Color("#eef4fa"), Color("#dbe6f2"), Color("#ffffff"), Color("#cfe0f0")]
const _MIR_INK := Color("#2b323a")

static func _draw_mirror(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so adding features later does not
	# --- reshuffle existing staffers' faces.
	var chrome: Color = _MIR_CHROME[rng.randi() % _MIR_CHROME.size()]
	var glint: Color = _MIR_GLINTS[rng.randi() % _MIR_GLINTS.size()]
	var form := rng.randi() % 3                      # 0 standing oval · 1 wide band mirror · 2 split/mismatched
	var half_w := (0.40 + (rng.randf() - 0.5) * 0.20) * r   # 0.30r .. 0.50r  (sampled independently…)
	var half_h := (0.42 + (rng.randf() - 0.5) * 0.21) * r   # 0.315r .. 0.525r (…of the width)
	var seam_tilt := deg_to_rad((rng.randf() - 0.5) * 26.0) # mirror seam leans up to ~13 degrees
	var mismatch := rng.randf()                      # 0 = halves agree · 1 = badly mismatched
	var band_offset := (rng.randf() - 0.5) * 0.30    # meridian band's height, as a fraction of half_h
	var glint_count := 1 + rng.randi() % 3
	var glint_jitter: Array[float] = []
	for _i in range(glint_count):
		glint_jitter.append(rng.randf())
	var copy_mode := rng.randi() % 3                 # 0 none · 1 inverted copy below · 2 copy off to one side
	var copy_side := -1.0 if rng.randf() < 0.5 else 1.0
	var eyes_split := rng.randf() < 0.55             # do the two halves show different eyes?
	var eye_shape_left := rng.randi() % 4            # 0-3 only: shape 4 offsets its pupil sideways,
	var eye_shape_right := rng.randi() % 4           # which looks wrong when drawn as a single eye
	var eye_shape_pair := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var shoulder_cut := 0.30 + rng.randf() * 0.10

	var dark := chrome.darkened(0.35)
	var light := chrome.lightened(0.30)
	var head_centre := Vector2(c.x, c.y - 0.06 * r)

	# --- per-form silhouette. left_edge / right_edge are the head's half-widths on each side (they
	# --- differ only for the split form); tall is its effective half-height.
	var left_edge := half_w
	var right_edge := half_w
	var tall := half_h
	var head := PackedVector2Array()
	match form:
		0:  # a tall, narrow standing mirror: a plain upright oval
			left_edge = half_w * 0.82
			right_edge = left_edge
			tall = half_h * 1.05
			head = _ellipse(head_centre, left_edge, tall, 28)
		1:  # a wide band mirror: a squat rectangle with cut corners
			left_edge = half_w * 1.10
			right_edge = left_edge
			tall = half_h * 0.75
			var corner := minf(left_edge, tall) * 0.35
			head = PackedVector2Array([
				Vector2(head_centre.x - left_edge + corner, head_centre.y - tall),
				Vector2(head_centre.x + right_edge - corner, head_centre.y - tall),
				Vector2(head_centre.x + right_edge, head_centre.y - tall + corner),
				Vector2(head_centre.x + right_edge, head_centre.y + tall - corner),
				Vector2(head_centre.x + right_edge - corner, head_centre.y + tall),
				Vector2(head_centre.x - left_edge + corner, head_centre.y + tall),
				Vector2(head_centre.x - left_edge, head_centre.y + tall - corner),
				Vector2(head_centre.x - left_edge, head_centre.y - tall + corner)])
		_:  # the botched reflection: a smooth oval left half welded to an angular right half
			right_edge = half_w * (1.0 - 0.35 * mismatch)
			var right_tall := half_h * (1.0 + 0.22 * mismatch)
			# left half: sampled ellipse arc running bottom → left → top
			for i in range(15):
				var a := PI * 0.5 + PI * (float(i) / 14.0)
				head.append(Vector2(head_centre.x + cos(a) * left_edge, head_centre.y + sin(a) * tall))
			# right half: a few hard vertices back down to the bottom, so the two sides disagree
			head.append(Vector2(head_centre.x + right_edge * 0.60, head_centre.y - right_tall * 0.82))
			head.append(Vector2(head_centre.x + right_edge, head_centre.y - right_tall * 0.30))
			head.append(Vector2(head_centre.x + right_edge * 0.92, head_centre.y + right_tall * 0.35))
			head.append(Vector2(head_centre.x + right_edge * 0.45, head_centre.y + right_tall * 0.88))

	# --- shoulders: a chrome plinth whose bottom edge hugs the disc arc
	canvas.draw_colored_polygon(_disc_segment_below(c, r, shoulder_cut), dark)
	canvas.draw_colored_polygon(_disc_segment_below(c, r, shoulder_cut + 0.22), chrome)

	# --- head shell, then a polished rim so the edge reads as metal rather than paint
	canvas.draw_colored_polygon(head, chrome)
	var rim := head.duplicate()
	rim.append(head[0])
	canvas.draw_polyline(rim, light, maxf(2.0, 0.02 * r))

	# --- the meridian: a bright horizon band. Kept to 0.90 of each half-width, and its centre to
	# --- ±0.15 of the half-height, so it always lands inside the shell instead of poking out.
	var band_y := head_centre.y + band_offset * tall
	var band_h := 0.055 * r
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(head_centre.x - left_edge * 0.90, band_y - band_h),
		Vector2(head_centre.x + right_edge * 0.90, band_y - band_h),
		Vector2(head_centre.x + right_edge * 0.90, band_y + band_h),
		Vector2(head_centre.x - left_edge * 0.90, band_y + band_h)]), glint)

	# --- the mirror seam, tilted, running the full height of the head through its centre
	var seam_dir := Vector2(sin(seam_tilt), -cos(seam_tilt))
	canvas.draw_line(head_centre - seam_dir * tall * 0.95, head_centre + seam_dir * tall * 0.95,
		dark, maxf(2.0, 0.022 * r))

	# --- hard specular glints: short diagonal streaks in the upper-left of the shell
	for i in range(glint_count):
		var gx := head_centre.x - left_edge * (0.50 - float(i) * 0.26)
		var gy := head_centre.y - tall * (0.50 - glint_jitter[i] * 0.15)
		canvas.draw_line(Vector2(gx, gy), Vector2(gx + tall * 0.20, gy + tall * 0.34),
			glint, maxf(2.0, 0.026 * r))

	# --- features. When the halves are split each side gets its own eye shape: passing dx = 0 makes
	# --- _alien_eyes stack both of its eyes on one spot, which is how we get a single eye per half.
	var eye_y := head_centre.y - tall * 0.10
	var eye_size := 0.085 * r
	if eyes_split:
		_alien_eyes(canvas, head_centre.x - left_edge * 0.42, eye_y, 0.0, eye_size, glint, _MIR_INK, eye_shape_left)
		_alien_eyes(canvas, head_centre.x + right_edge * 0.42, eye_y, 0.0, eye_size, glint, _MIR_INK, eye_shape_right)
	else:
		_alien_eyes(canvas, head_centre.x, eye_y, half_w * 0.42, eye_size, glint, _MIR_INK, eye_shape_pair)
	_alien_mouth(canvas, head_centre.x, head_centre.y + tall * 0.55, half_w * 0.55, _MIR_INK, mouth_shape)

	# --- the gag: a smaller copy of the being, drawn upside-down (eyes below its band, mouth above),
	# --- either pooled beneath the head or standing off to one side.
	if copy_mode > 0:
		var copy_w := half_w * 0.34
		var copy_h := half_h * 0.34
		var copy_centre := Vector2(c.x, c.y + 0.58 * r)
		if copy_mode == 2:
			copy_centre = Vector2(c.x + copy_side * 0.52 * r, c.y + 0.44 * r)
		canvas.draw_colored_polygon(_ellipse(copy_centre, copy_w, copy_h, 18), chrome)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(copy_centre.x - copy_w * 0.90, copy_centre.y - band_h * 0.5),
			Vector2(copy_centre.x + copy_w * 0.90, copy_centre.y - band_h * 0.5),
			Vector2(copy_centre.x + copy_w * 0.90, copy_centre.y + band_h * 0.5),
			Vector2(copy_centre.x - copy_w * 0.90, copy_centre.y + band_h * 0.5)]), glint)
		for sx in [-1.0, 1.0]:
			canvas.draw_circle(Vector2(copy_centre.x + sx * copy_w * 0.40, copy_centre.y + copy_h * 0.42),
				copy_w * 0.16, _MIR_INK)
		canvas.draw_line(Vector2(copy_centre.x - copy_w * 0.32, copy_centre.y - copy_h * 0.52),
			Vector2(copy_centre.x + copy_w * 0.32, copy_centre.y - copy_h * 0.52), _MIR_INK, maxf(2.0, 0.018 * r))


# Ossuary Compact (tier 22) — a skeletal banker: a bone skull in dusty formalwear, hollow sockets,
# a pince-nez, cobwebs and a wax-sealed deed. Skull width and height are sampled independently and
# one of three skull FORMS is chosen, so members read as different people, not one head rescaled.
const _OSS_BONES: Array[Color] = [
	Color("#e8dfc6"), Color("#dcd2b4"), Color("#f0e8d2"), Color("#cfc4a6"), Color("#e2d6b8")]
const _OSS_CLOTH: Array[Color] = [
	Color("#4a4740"), Color("#3d3a35"), Color("#565049"), Color("#44403a")]
const _OSS_WAXES: Array[Color] = [Color("#7a2b28"), Color("#8c3a30"), Color("#6b2622")]
const _OSS_SOCKET := Color("#241f19")
const _OSS_ACCENT := Color("#7d7259")
const _OSS_WEB := Color("#cfc9b8")

static func _draw_ossuary(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn here, up front, in a fixed order (file convention) ----------
	var bone: Color = _OSS_BONES[rng.randi() % _OSS_BONES.size()]
	var cloth: Color = _OSS_CLOTH[rng.randi() % _OSS_CLOTH.size()]
	var wax: Color = _OSS_WAXES[rng.randi() % _OSS_WAXES.size()]
	var skull_hw := (0.34 + (rng.randf() - 0.5) * 0.17) * r   # half-width  ≈ ±25% of 0.34r
	var skull_hh := (0.38 + (rng.randf() - 0.5) * 0.19) * r   # half-height ≈ ±25% of 0.38r, independent
	var form := rng.randi() % 3                  # 0 broad+short jaw · 1 long narrow · 2 angular, chipped
	var chip_side := 1.0 if rng.randf() < 0.5 else -1.0       # which upper corner form 2 has lost
	var socket_size := 0.30 + rng.randf() * 0.16              # socket radius as a fraction of half-width
	var socket_asym := 0.80 + rng.randf() * 0.40              # right socket is this much of the left one
	var brow_tilt := (rng.randf() - 0.5) * 0.7                # radians; inward = stern, outward = worried
	var teeth := 4 + rng.randi() % 4
	var tooth_roll: Array[float] = []                         # low rolls become missing teeth
	for _i in range(teeth):
		tooth_roll.append(rng.randf())
	var monocle_side := 0.0 if rng.randf() < 0.2 else (1.0 if rng.randf() < 0.5 else -1.0)
	var web_corner := rng.randi() % 3            # 0 none · 1 top-left · 2 top-right
	var has_deed := rng.randf() < 0.6
	var deed_side := 1.0 if rng.randf() < 0.5 else -1.0
	var has_flower := rng.randf() < 0.55
	var cracks := rng.randi() % 3
	var crack_x: Array[float] = []
	for _i in range(cracks):
		crack_x.append(rng.randf())

	var hc := Vector2(c.x, c.y - 0.06 * r)       # skull centre, lifted so the jaw has room below
	var web_line := maxf(2.0, 0.022 * r)         # cobwebs: few strands, deliberately bold

	# --- background: a cobweb strung across one upper corner of the disc -------------------------
	if web_corner != 0:
		var web_dir := Vector2(-0.707, -0.707) if web_corner == 1 else Vector2(0.707, -0.707)
		var anchor := c + web_dir * 0.80 * r     # the web hangs from a point just inside the rim
		var inward := -web_dir
		for i in range(3):
			var spread := deg_to_rad(-32.0 + 32.0 * float(i))
			var spoke := inward.rotated(spread)
			canvas.draw_line(anchor, anchor + spoke * 0.44 * r, _OSS_WEB, web_line)
		# two sagging cross-threads at 45% and 85% out along the spokes
		for frac in [0.45, 0.85]:
			var thread := PackedVector2Array()
			for i in range(3):
				var spread2 := deg_to_rad(-32.0 + 32.0 * float(i))
				thread.append(anchor + inward.rotated(spread2) * (0.44 * r * frac))
			canvas.draw_polyline(thread, _OSS_WEB, web_line)

	# --- formalwear: shoulders hug the disc arc, then a bone-white collar V ----------------------
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.30), cloth)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 0.26 * r, c.y + 0.30 * r), Vector2(c.x + 0.26 * r, c.y + 0.30 * r),
		Vector2(c.x, c.y + 0.66 * r)]), bone.lightened(0.10))
	canvas.draw_line(Vector2(c.x, c.y + 0.34 * r), Vector2(c.x, c.y + 0.62 * r), wax, maxf(2.0, 0.035 * r))
	if has_flower:
		# a dried funeral flower in the lapel, opposite the hanging deed
		var lapel := Vector2(c.x - deed_side * 0.34 * r, c.y + 0.44 * r)
		for i in range(5):
			var a := TAU * float(i) / 5.0
			canvas.draw_circle(lapel + Vector2(cos(a), sin(a)) * 0.045 * r, 0.035 * r, _OSS_ACCENT)
		canvas.draw_circle(lapel, 0.030 * r, wax)
	if has_deed:
		# a deed hanging at the chest with a wax seal pressed onto it
		var deed := Vector2(c.x + deed_side * 0.44 * r, c.y + 0.50 * r)
		canvas.draw_rect(Rect2(deed.x - 0.09 * r, deed.y - 0.13 * r, 0.18 * r, 0.26 * r), _OSS_BONES[2])
		canvas.draw_line(Vector2(deed.x - 0.05 * r, deed.y - 0.05 * r),
			Vector2(deed.x + 0.05 * r, deed.y - 0.05 * r), _OSS_SOCKET, maxf(2.0, 0.012 * r))
		canvas.draw_circle(Vector2(deed.x, deed.y + 0.07 * r), 0.055 * r, wax)

	# --- the skull: three genuinely different outlines, each also setting its own feature heights -
	var socket_y := hc.y - skull_hh * 0.16
	var mouth_y := hc.y + skull_hh * 0.58
	match form:
		0:  # broad round cranium over a short, wide jaw
			canvas.draw_colored_polygon(_ellipse(hc, skull_hw * 1.05, skull_hh * 0.86, 26), bone)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(hc.x - skull_hw * 0.78, hc.y + skull_hh * 0.34),
				Vector2(hc.x + skull_hw * 0.78, hc.y + skull_hh * 0.34),
				Vector2(hc.x + skull_hw * 0.50, hc.y + skull_hh * 0.82),
				Vector2(hc.x - skull_hw * 0.50, hc.y + skull_hh * 0.82)]), bone.darkened(0.06))
			socket_y = hc.y - skull_hh * 0.22
			mouth_y = hc.y + skull_hh * 0.58
		1:  # long narrow cranium with an elongated jaw
			var tall := Vector2(hc.x, hc.y - skull_hh * 0.10)
			canvas.draw_colored_polygon(_ellipse(tall, skull_hw * 0.82, skull_hh * 0.98, 26), bone)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(hc.x - skull_hw * 0.62, hc.y + skull_hh * 0.30),
				Vector2(hc.x + skull_hw * 0.62, hc.y + skull_hh * 0.30),
				Vector2(hc.x + skull_hw * 0.42, hc.y + skull_hh * 1.20),
				Vector2(hc.x - skull_hw * 0.42, hc.y + skull_hh * 1.20)]), bone.darkened(0.06))
			socket_y = hc.y - skull_hh * 0.34
			mouth_y = hc.y + skull_hh * 0.72
		_:  # angular skull with one upper corner sheared away (an old, badly kept skull)
			var pts := PackedVector2Array([
				Vector2(hc.x - skull_hw * 0.72, hc.y - skull_hh * 0.92),
				Vector2(hc.x + skull_hw * 0.72, hc.y - skull_hh * 0.92),
				Vector2(hc.x + skull_hw * 1.00, hc.y - skull_hh * 0.28),
				Vector2(hc.x + skull_hw * 0.60, hc.y + skull_hh * 0.46),
				Vector2(hc.x, hc.y + skull_hh * 0.92),
				Vector2(hc.x - skull_hw * 0.60, hc.y + skull_hh * 0.46),
				Vector2(hc.x - skull_hw * 1.00, hc.y - skull_hh * 0.28)])
			# pull the top and temple vertices in on one side so that corner reads as broken off
			if chip_side < 0.0:
				pts[0] = Vector2(hc.x - skull_hw * 0.24, hc.y - skull_hh * 0.92)
				pts[6] = Vector2(hc.x - skull_hw * 0.86, hc.y - skull_hh * 0.02)
			else:
				pts[1] = Vector2(hc.x + skull_hw * 0.24, hc.y - skull_hh * 0.92)
				pts[2] = Vector2(hc.x + skull_hw * 0.86, hc.y - skull_hh * 0.02)
			canvas.draw_colored_polygon(pts, bone)
			socket_y = hc.y - skull_hh * 0.20
			mouth_y = hc.y + skull_hh * 0.60

	# hairline cracks running down from the crown toward the sockets
	for i in range(cracks):
		var cx := hc.x + (crack_x[i] - 0.5) * skull_hw * 1.3
		canvas.draw_polyline(PackedVector2Array([
			Vector2(cx, hc.y - skull_hh * 0.80),
			Vector2(cx + skull_hw * 0.10, hc.y - skull_hh * 0.50),
			Vector2(cx - skull_hw * 0.06, hc.y - skull_hh * 0.24)]),
			bone.darkened(0.35), maxf(2.0, 0.014 * r))

	# --- hollow sockets (drawn directly, so they read as holes) and brow ridges ------------------
	var socket_dx := skull_hw * 0.44
	var socket_r := skull_hw * socket_size
	for sx in [-1.0, 1.0]:
		var scale := 1.0 if sx < 0.0 else socket_asym      # deliberately mismatched sockets
		var eye := Vector2(hc.x + sx * socket_dx, socket_y)
		canvas.draw_colored_polygon(_ellipse(eye, socket_r * scale, socket_r * 1.15 * scale, 18), _OSS_SOCKET)
		# brow ridge: tilt sets the mood — inner end down = stern, inner end up = worried
		var brow_y := socket_y - socket_r * 1.5 * scale
		canvas.draw_line(
			Vector2(eye.x - socket_r * 1.1, brow_y + sx * brow_tilt * socket_r),
			Vector2(eye.x + socket_r * 1.1, brow_y - sx * brow_tilt * socket_r),
			bone.darkened(0.30), maxf(2.0, 0.018 * r))
	# nasal cavity
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(hc.x, socket_y + socket_r * 1.1),
		Vector2(hc.x + skull_hw * 0.13, mouth_y - skull_hh * 0.10),
		Vector2(hc.x - skull_hw * 0.13, mouth_y - skull_hh * 0.10)]), _OSS_SOCKET)

	# --- teeth: a dark gum line with bone teeth on top, low rolls left as gaps -------------------
	var row_hw := skull_hw * 0.50
	var tooth_w := (row_hw * 2.0) / float(teeth)
	canvas.draw_rect(Rect2(hc.x - row_hw, mouth_y, row_hw * 2.0, tooth_w * 1.1), _OSS_SOCKET)
	for i in range(teeth):
		if tooth_roll[i] < 0.22:
			continue                              # a missing tooth: leave the dark gum showing
		var tx := hc.x - row_hw + tooth_w * float(i)
		canvas.draw_rect(Rect2(tx + tooth_w * 0.12, mouth_y, tooth_w * 0.76, tooth_w * 1.1), bone.lightened(0.12))

	# --- pince-nez / monocle over one socket, with a chain down to the collar --------------------
	if monocle_side != 0.0:
		var lens := Vector2(hc.x + monocle_side * socket_dx, socket_y)
		var lens_r := socket_r * 1.55
		canvas.draw_circle(lens, lens_r, Color(0.85, 0.90, 0.88, 0.20))
		canvas.draw_arc(lens, lens_r, 0.0, TAU, 26, _OSS_ACCENT, maxf(2.0, 0.020 * r))
		canvas.draw_polyline(PackedVector2Array([
			lens + Vector2(monocle_side * lens_r, lens_r * 0.4),
			Vector2(hc.x + monocle_side * skull_hw * 1.05, hc.y + skull_hh * 0.55),
			Vector2(hc.x + monocle_side * skull_hw * 0.85, c.y + 0.34 * r)]),
			_OSS_ACCENT, maxf(2.0, 0.016 * r))


# Spectacle Prime (tier 23) — a species of influencers. Every member poses inside a ring-light
# halo wearing an enormous practiced grin, kitted out for being watched: oversized sunglasses (or a
# lens where a face should be), a clip-on mic, a recording dot, a floating view counter.
# Two of the three forms are CREATURES with visible skin and a huge grin — a wide-jawed presenter
# and a long-necked model — and the third is the odd one out: a member whose head is a camera.
const _SPE_BODIES: Array[Color] = [
	Color("#b03060"), Color("#c23a74"), Color("#96285a"), Color("#d1487f"), Color("#a52e6b")]
const _SPE_LIMELIGHT := Color("#fff4e2")     # the ring light's own warm-white
const _SPE_TEETH := Color("#ffffff")
const _SPE_INK := Color("#2a0d1c")
const _SPE_LENS := Color("#1b1220")          # glass of sunglasses / camera barrel
const _SPE_REC := Color("#ff3b30")           # the recording dot

static func _draw_spectacle(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so adding a feature later does
	# --- not reshuffle the faces of existing staffers.
	#
	# All category picks come from randf(), NOT from `randi() % n`. That matters here: staffer seeds
	# within one civ are structurally close (they differ by a fixed stride), so the LOW bits of
	# randi() correlate badly — a `% 3` collapsed the form choice, with six of eight members drawing
	# the same form. randf() reads the generator's high bits and spreads the three forms evenly.
	var body: Color = _SPE_BODIES[int(rng.randf() * float(_SPE_BODIES.size())) % _SPE_BODIES.size()]
	var form := int(rng.randf() * 3.0)           # 0 wide presenter · 1 long-necked model · 2 camera head
	var width_scale := 0.80 + rng.randf() * 0.40 # head half-width and half-height are sampled
	var height_scale := 0.80 + rng.randf() * 0.40 # independently, so members read stocky vs. tall
	var halo_style := int(rng.randf() * 3.0)     # 0 solid ring · 1 segmented bulbs · 2 twin thin rings
	var halo_segments := 6 + int(rng.randf() * 7.0)
	var halo_radius := (0.66 + rng.randf() * 0.16) * r   # ring + stroke + glow all stay inside 0.95r
	# Eyewear is weighted, not uniform: the oversized sunglasses are the civ's most recognizable
	# accessory, so half of all members wear them and the other two kits split the rest.
	var eye_kit_roll := rng.randf()
	var eye_kit := 0 if eye_kit_roll < 0.50 else (1 if eye_kit_roll < 0.75 else 2)
	var eye_shape := int(rng.randf() * 5.0)
	var grin_reach := rng.randf()                # 0 = a merely wide grin, 1 = ear-to-ear
	var grin_scale := 0.84 + rng.randf() * 0.32  # overall grin size, relative to the face
	var tooth_count := 4 + int(rng.randf() * 4.0)
	var crest_count := 4 + int(rng.randf() * 3.0)        # presenter's swept-back hair tufts
	var neck_length := (0.09 + rng.randf() * 0.11) * r   # only used by the long-necked form
	var mic_side := 1.0 if rng.randf() < 0.5 else -1.0
	var has_mic := rng.randf() < 0.75
	var has_rec_dot := rng.randf() < 0.65
	var rec_side := 1.0 if rng.randf() < 0.5 else -1.0
	var has_counter := rng.randf() < 0.5
	var has_earring := rng.randf() < 0.5

	var skin := body.lightened(0.30)
	var dark := body.darkened(0.35)
	var glow := _SPE_LIMELIGHT

	# --- ring light, behind everything: a soft halo plus the ring itself ------------------------
	canvas.draw_circle(c, halo_radius + 0.03 * r, Color(glow.r, glow.g, glow.b, 0.16))
	var ring_stroke := maxf(2.0, 0.05 * r)
	match halo_style:
		0:
			canvas.draw_arc(c, halo_radius, 0.0, TAU, 48, Color(glow.r, glow.g, glow.b, 0.85), ring_stroke)
		1:
			# discrete bulbs around the ring
			for i in range(halo_segments):
				var bulb_angle := TAU * float(i) / float(halo_segments)
				canvas.draw_circle(c + Vector2(cos(bulb_angle), sin(bulb_angle)) * halo_radius, 0.045 * r,
					Color(glow.r, glow.g, glow.b, 0.9))
		2:
			canvas.draw_arc(c, halo_radius, 0.0, TAU, 48, Color(glow.r, glow.g, glow.b, 0.8), maxf(2.0, 0.022 * r))
			canvas.draw_arc(c, halo_radius - 0.09 * r, 0.0, TAU, 44, Color(glow.r, glow.g, glow.b, 0.45), maxf(2.0, 0.018 * r))

	# --- body / shoulders (segment_below keeps the bottom edge hugging the disc arc) ------------
	var shoulder_top := 0.34 * r
	canvas.draw_colored_polygon(_disc_segment_below(c, r, shoulder_top / r), body)

	# --- head size and placement, decided BEFORE anything is drawn so both clamps below can act --
	var head_hw := 0.32 * width_scale * r
	var head_hh := 0.34 * height_scale * r
	var head_c := Vector2(c.x, c.y - 0.13 * r)
	# How far above head_c the silhouette actually reaches: the presenter's crest adds hair above
	# the crown, the other two forms stop at the crown.
	var crown_reach := head_hh
	match form:
		0:
			head_hw *= 1.20        # broad, cheek-heavy
			head_hh *= 0.94
			crown_reach = head_hh * 1.34
		1:
			head_hw *= 0.74        # tall and narrow, lifted by the neck
			head_hh *= 1.10
			head_c.y -= neck_length
			crown_reach = head_hh
		2:
			head_hw *= 1.05
			crown_reach = head_hh + 0.09 * r   # room for the flash shoe on top of the housing
	# Keep the crown inside the ring light rather than poking through it...
	head_c.y = maxf(head_c.y, c.y - halo_radius + 0.11 * r + crown_reach)
	# ...and keep the chin (and therefore the grin) clear of the shoulders. This clamp is applied
	# second on purpose: if a head is too tall for both limits, a visible grin wins.
	head_c.y = minf(head_c.y, c.y + shoulder_top - 0.04 * r - head_hh)

	# --- head: three genuinely different silhouettes -------------------------------------------
	match form:
		0:
			# Wide-jawed presenter: a broad, cheek-heavy face built for smiling at a camera.
			# Swept-back hair tufts first, so the skull polygon covers their roots.
			var crest_span := head_hw * 0.98
			for i in range(crest_count):
				var t := (float(i) + 0.5) / float(crest_count)
				var root_x := head_c.x - crest_span + 2.0 * crest_span * t
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(root_x - crest_span * 0.30, head_c.y - head_hh * 0.78),
					Vector2(root_x + crest_span * 0.30, head_c.y - head_hh * 0.78),
					Vector2(root_x + crest_span * 0.14, head_c.y - head_hh * 1.30)]), dark)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(head_c.x - 0.60 * head_hw, head_c.y - head_hh),
				Vector2(head_c.x + 0.60 * head_hw, head_c.y - head_hh),
				Vector2(head_c.x + head_hw, head_c.y - 0.15 * head_hh),
				Vector2(head_c.x + head_hw * 0.94, head_c.y + 0.55 * head_hh),
				Vector2(head_c.x + 0.44 * head_hw, head_c.y + head_hh),
				Vector2(head_c.x - 0.44 * head_hw, head_c.y + head_hh),
				Vector2(head_c.x - head_hw * 0.94, head_c.y + 0.55 * head_hh),
				Vector2(head_c.x - head_hw, head_c.y - 0.15 * head_hh)]), skin)
		1:
			# Chic long-necked model: a slim neck lifts a tall narrow head clear of the collar.
			var neck_hw := 0.34 * head_hw
			canvas.draw_rect(Rect2(head_c.x - neck_hw, head_c.y,
				neck_hw * 2.0, head_hh + neck_length + 0.20 * r), skin.darkened(0.16))
			# A dark turtleneck at the base and a limelight choker at the top break the long neck up
			# so it reads as a clothed body rather than a bare stick.
			canvas.draw_rect(Rect2(head_c.x - neck_hw * 1.9, head_c.y + head_hh + neck_length * 0.62,
				neck_hw * 3.8, 0.10 * r), dark)
			canvas.draw_colored_polygon(_ellipse(head_c, head_hw, head_hh, 24), skin)
			# choker sits on the neck just below the jaw, so it is drawn after the head
			canvas.draw_line(Vector2(head_c.x - neck_hw, head_c.y + head_hh + neck_length * 0.22),
				Vector2(head_c.x + neck_hw, head_c.y + head_hh + neck_length * 0.22),
				glow, maxf(2.0, 0.022 * r))
			if has_earring:
				# a single long drop earring, hung on the side away from the mic
				var ear := Vector2(head_c.x - mic_side * head_hw * 0.92, head_c.y + head_hh * 0.18)
				canvas.draw_line(ear, ear + Vector2(0.0, 0.08 * r), glow, maxf(2.0, 0.014 * r))
				canvas.draw_circle(ear + Vector2(0.0, 0.10 * r), 0.032 * r, glow)
		2:
			# The odd one out: the head IS a camera housing — boxy body, a lens barrel where a face
			# should be, a flash shoe on top, and its own little tally light.
			canvas.draw_rect(Rect2(head_c.x - head_hw, head_c.y - head_hh,
				head_hw * 2.0, head_hh * 2.0), skin)
			canvas.draw_rect(Rect2(head_c.x - 0.30 * head_hw, head_c.y - head_hh - 0.09 * r,
				0.60 * head_hw, 0.09 * r), dark)
			canvas.draw_arc(head_c, minf(head_hw, head_hh) * 0.78, 0.0, TAU, 28, dark, maxf(2.0, 0.05 * r))
			canvas.draw_circle(Vector2(head_c.x + head_hw * 0.74, head_c.y - head_hh * 0.76), 0.03 * r, _SPE_REC)

	# Both creature forms get limelight cheek contouring — the ring light catching a face that has
	# been sculpted for exactly this shot.
	if form != 2:
		for cheek_side in [-1.0, 1.0]:
			var cheek := Vector2(head_c.x + float(cheek_side) * head_hw * 0.58, head_c.y + head_hh * 0.16)
			canvas.draw_colored_polygon(_ellipse(cheek, head_hw * 0.26, head_hh * 0.14, 14),
				Color(glow.r, glow.g, glow.b, 0.20))

	# --- face: the camera housing always shows a lens; creatures use the sampled eye kit -------
	var kit := 1 if form == 2 else eye_kit
	var eye_y := head_c.y - 0.26 * head_hh
	match kit:
		0:
			# Oversized sunglasses: two lenses so big they nearly span the face, plus temple arms.
			var lens_hw := head_hw * 0.50
			var lens_hh := head_hh * 0.32
			for glass_side in [-1.0, 1.0]:
				var lens_c := Vector2(head_c.x + float(glass_side) * head_hw * 0.48, eye_y)
				canvas.draw_colored_polygon(_ellipse(lens_c, lens_hw, lens_hh, 18), _SPE_LENS)
				# a single diagonal streak so the glass reads as glossy
				canvas.draw_line(lens_c + Vector2(-lens_hw * 0.40, lens_hh * 0.30),
					lens_c + Vector2(lens_hw * 0.10, -lens_hh * 0.40),
					Color(glow.r, glow.g, glow.b, 0.7), maxf(2.0, 0.016 * r))
				# temple arm running from the outer lens edge back past the side of the head
				canvas.draw_line(lens_c + Vector2(float(glass_side) * lens_hw * 0.9, -lens_hh * 0.2),
					Vector2(head_c.x + float(glass_side) * head_hw * 1.04, eye_y - lens_hh * 0.1),
					_SPE_LENS, maxf(2.0, 0.022 * r))
			canvas.draw_line(Vector2(head_c.x - head_hw * 0.06, eye_y), Vector2(head_c.x + head_hw * 0.06, eye_y),
				_SPE_LENS, maxf(2.0, 0.022 * r))
		1:
			# One big camera lens: concentric barrel rings with a bright catch-light. On a creature
			# this is a single lens EYE, so it sits where the eyes would be rather than mid-face.
			var lens_center := head_c if form == 2 else Vector2(head_c.x, eye_y)
			var lens_r := minf(head_hw, head_hh) * (0.62 if form == 2 else 0.50)
			canvas.draw_circle(lens_center, lens_r, _SPE_LENS)
			canvas.draw_arc(lens_center, lens_r * 0.72, 0.0, TAU, 24, Color(glow.r, glow.g, glow.b, 0.55), maxf(2.0, 0.018 * r))
			canvas.draw_circle(lens_center, lens_r * 0.34, body.lightened(0.45))
			canvas.draw_circle(lens_center + Vector2(-lens_r * 0.30, -lens_r * 0.32), lens_r * 0.16, glow)
		2:
			# Bare eyes, wide open for the camera, under a plucked brow line.
			_alien_eyes(canvas, head_c.x, eye_y, head_hw * 0.48, head_hh * 0.22, glow, _SPE_INK, eye_shape)
			for brow_side in [-1.0, 1.0]:
				var brow_x := head_c.x + float(brow_side) * head_hw * 0.48
				canvas.draw_line(Vector2(brow_x - head_hw * 0.26, eye_y - head_hh * 0.40),
					Vector2(brow_x + head_hw * 0.26, eye_y - head_hh * 0.46),
					_SPE_INK, maxf(2.0, 0.018 * r))

	# --- the practiced grin: the civ's signature, so both creature forms always wear one --------
	if form == 2:
		# The camera housing has no mouth; it gets a thin speaker slot instead.
		canvas.draw_rect(Rect2(head_c.x - head_hw * 0.5, head_c.y + head_hh * 0.72,
			head_hw, maxf(2.0, 0.025 * r)), dark)
	else:
		# The grin is an arc BAND of teeth. Its radius is limited by BOTH head axes so it fits the
		# broad presenter and the narrow model alike.
		var grin_radius := minf(head_hw * 0.62, head_hh * 0.75) * grin_scale
		var band_width := maxf(2.0, grin_radius * 0.58)
		# The grin's LOWEST point is parked just above the chin, which puts the arc's CENTER up near
		# the eyes — only the bottom band of that circle is drawn, and that is what lifts the
		# corners of the mouth into a practiced smile.
		var mouth_bottom := head_c.y + head_hh * 0.80
		var grin_c := Vector2(head_c.x, mouth_bottom - grin_radius - band_width * 0.5)
		# grin_reach opens the arc from a wide smile (22°..158°) out to ear-to-ear (4°..176°).
		var start_angle := deg_to_rad(lerpf(22.0, 4.0, grin_reach))
		var end_angle := PI - start_angle
		canvas.draw_arc(grin_c, grin_radius, start_angle, end_angle, 24, _SPE_TEETH, band_width)
		# vertical separators across the band, so it reads as individual teeth
		for i in range(1, tooth_count):
			var seam_angle := lerpf(start_angle, end_angle, float(i) / float(tooth_count))
			var seam_dir := Vector2(cos(seam_angle), sin(seam_angle))
			canvas.draw_line(grin_c + seam_dir * (grin_radius - band_width * 0.45),
				grin_c + seam_dir * (grin_radius + band_width * 0.45),
				Color(_SPE_INK.r, _SPE_INK.g, _SPE_INK.b, 0.30), maxf(2.0, 0.010 * r))
		# dark lip lines hugging the outside and inside edges of the tooth band
		canvas.draw_arc(grin_c, grin_radius + band_width * 0.5, start_angle, end_angle, 24,
			_SPE_INK, maxf(2.0, 0.016 * r))
		canvas.draw_arc(grin_c, grin_radius - band_width * 0.5, start_angle, end_angle, 24,
			_SPE_INK, maxf(2.0, 0.012 * r))
		# a dimple at each corner of the mouth, where the two lip lines meet
		for corner_angle in [start_angle, end_angle]:
			var corner_dir := Vector2(cos(float(corner_angle)), sin(float(corner_angle)))
			canvas.draw_circle(grin_c + corner_dir * grin_radius, maxf(2.0, 0.018 * r), _SPE_INK)

	# --- accessories, drawn last so they sit on top --------------------------------------------
	if has_mic:
		# clip-on mic on the collar: a short boom with a foam head
		var clip := Vector2(c.x + mic_side * 0.32 * r, c.y + 0.50 * r)
		var foam := clip + Vector2(mic_side * 0.07 * r, -0.09 * r)
		canvas.draw_line(clip, foam, dark, maxf(2.0, 0.022 * r))
		canvas.draw_circle(foam, 0.055 * r, _SPE_INK)
	if has_rec_dot:
		var dot := Vector2(c.x + rec_side * 0.50 * r, c.y - 0.54 * r)
		canvas.draw_circle(dot, 0.055 * r, Color(_SPE_REC.r, _SPE_REC.g, _SPE_REC.b, 0.35))
		canvas.draw_circle(dot, 0.032 * r, _SPE_REC)
	if has_counter:
		# tiny floating view counter opposite the recording dot, so the two never overlap
		var panel := Vector2(c.x - rec_side * 0.52 * r, c.y - 0.26 * r)
		canvas.draw_rect(Rect2(panel.x - 0.10 * r, panel.y - 0.06 * r, 0.20 * r, 0.12 * r), _SPE_INK)
		for i in range(3):
			var tick_y := panel.y - 0.03 * r + float(i) * 0.03 * r
			canvas.draw_line(Vector2(panel.x - 0.07 * r, tick_y), Vector2(panel.x + 0.07 * r, tick_y),
				glow, maxf(2.0, 0.012 * r))


# Vek-Tor Kollektiv (tier 24) — a deathless bureaucrat: a head shaped like a filed form or a rubber
# stamp, perforated edges, red countersign stamps, an eyeshade visor, and a queue ticket.
const _VEK_PAPERS: Array[Color] = [
	Color("#e2cfa4"), Color("#d8c49a"), Color("#eadcbb"), Color("#cdb98e"), Color("#e6d6b2")]
const _VEK_INKS: Array[Color] = [Color("#9e2b25"), Color("#b23a30"), Color("#8a2420"), Color("#a83a34")]
const _VEK_DESK := Color("#5c4a34")          # the desk / uniform the clerk sits behind
const _VEK_VISOR := Color("#3f5d43")         # classic green eyeshade
const _VEK_GRAPHITE := Color("#3a3128")      # pencil marks, eye pupils, mouth

static func _draw_vektor(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so faces stay stable -------------
	var paper: Color = _VEK_PAPERS[rng.randi() % _VEK_PAPERS.size()]
	var ink: Color = _VEK_INKS[rng.randi() % _VEK_INKS.size()]
	var width_scale := 0.75 + rng.randf() * 0.50   # stocky vs narrow, sampled independently...
	var height_scale := 0.75 + rng.randf() * 0.50  # ...from squat vs tall
	var form := rng.randi() % 3                    # 0 landscape form · 1 filing card · 2 rubber stamp
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var stamps := 1 + rng.randi() % 3              # how many countersign marks are on the face
	var stamp_kind: Array[int] = []
	var stamp_angle: Array[float] = []
	var stamp_x: Array[float] = []
	var stamp_y: Array[float] = []
	for _i in range(3):                            # always draw 3 sets of randoms, use the first `stamps`
		stamp_kind.append(rng.randi() % 3)
		stamp_angle.append(rng.randf() * TAU)
		stamp_x.append((rng.randf() - 0.5) * 1.2)  # −0.6..0.6 of the head half-width
		stamp_y.append((rng.randf() - 0.5) * 1.2)
	var perf_edges := rng.randi() % 3              # 0 top+bottom · 1 left+right · 2 all four
	var rule_lines := 2 + rng.randi() % 3          # ruled form-writing under the mouth
	var has_visor := rng.randf() < 0.6
	var has_ticket := rng.randf() < 0.55
	var has_tape := rng.randf() < 0.5

	# Each silhouette biases the base proportions further, so the three forms read differently even
	# before the random width/height scales are applied.
	var half_w := 0.40 * r * width_scale
	var half_h := 0.34 * r * height_scale
	match form:
		0:
			half_w *= 1.15                          # landscape: a form filled out sideways
			half_h *= 0.85
		1:
			half_w *= 0.85                          # portrait: a tall filing card
			half_h *= 1.15
		2:
			half_w *= 1.00                          # blocky rubber stamp
			half_h *= 0.95
	var hc := Vector2(c.x, c.y - 0.10 * r)          # head sits high; body fills the disc below it
	var stroke := maxf(2.0, 0.022 * r)

	# --- background: desk, then the clerk's shoulders --------------------------------------------
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.58), _VEK_DESK.darkened(0.25))
	canvas.draw_colored_polygon(_disc_segment_below(c, r, 0.40), _VEK_DESK)

	# --- head outline ----------------------------------------------------------------------------
	if form == 2:
		# Rubber stamp: a block, a narrowing neck, and a knob handle above it.
		canvas.draw_line(Vector2(hc.x, hc.y - half_h), Vector2(hc.x, hc.y - half_h - 0.13 * r),
			_VEK_DESK, maxf(2.0, 0.06 * r))
		canvas.draw_circle(Vector2(hc.x, hc.y - half_h - 0.19 * r), 0.09 * r, _VEK_DESK.lightened(0.15))
	var outline := PackedVector2Array()
	if form == 0:
		# Landscape form: a sheet with a slight taper, as if pulled from a folder.
		var tab := half_w * 0.18
		outline = PackedVector2Array([
			Vector2(hc.x - half_w + tab, hc.y - half_h), Vector2(hc.x + half_w - tab, hc.y - half_h),
			Vector2(hc.x + half_w, hc.y + half_h), Vector2(hc.x - half_w, hc.y + half_h)])
	elif form == 1:
		# Filing card: tall, with the top-right corner snipped off the way index cards are.
		var cut := minf(half_w, half_h) * 0.45
		outline = PackedVector2Array([
			Vector2(hc.x - half_w, hc.y - half_h), Vector2(hc.x + half_w - cut, hc.y - half_h),
			Vector2(hc.x + half_w, hc.y - half_h + cut), Vector2(hc.x + half_w, hc.y + half_h),
			Vector2(hc.x - half_w, hc.y + half_h)])
	else:
		# Rubber stamp: a plain block face under the handle drawn above.
		outline = PackedVector2Array([
			Vector2(hc.x - half_w, hc.y - half_h), Vector2(hc.x + half_w, hc.y - half_h),
			Vector2(hc.x + half_w, hc.y + half_h), Vector2(hc.x - half_w, hc.y + half_h)])
	canvas.draw_colored_polygon(outline, paper)

	# --- perforated edges: bold dots punched just inside the paper edge ---------------------------
	var perf_r := maxf(2.0, 0.020 * r)
	var perf_across := clampi(int(half_w / (0.085 * r)), 3, 7)
	var perf_down := clampi(int(half_h / (0.085 * r)), 3, 7)
	if perf_edges != 1:
		for i in range(perf_across):
			var px := hc.x - half_w * 0.8 + (half_w * 1.6) * (float(i) / float(maxi(1, perf_across - 1)))
			canvas.draw_circle(Vector2(px, hc.y - half_h + perf_r * 1.4), perf_r, _VEK_DESK)
			canvas.draw_circle(Vector2(px, hc.y + half_h - perf_r * 1.4), perf_r, _VEK_DESK)
	if perf_edges != 0:
		for i in range(perf_down):
			var py := hc.y - half_h * 0.8 + (half_h * 1.6) * (float(i) / float(maxi(1, perf_down - 1)))
			canvas.draw_circle(Vector2(hc.x - half_w + perf_r * 1.4, py), perf_r, _VEK_DESK)
			canvas.draw_circle(Vector2(hc.x + half_w - perf_r * 1.4, py), perf_r, _VEK_DESK)

	# --- eyeshade visor, face, and ruled form-writing ---------------------------------------------
	if has_visor:
		canvas.draw_rect(Rect2(hc.x - half_w * 0.9, hc.y - half_h * 0.62,
			half_w * 1.8, half_h * 0.34), _VEK_VISOR)
		canvas.draw_line(Vector2(hc.x - half_w * 0.9, hc.y - half_h * 0.28),
			Vector2(hc.x + half_w * 0.9, hc.y - half_h * 0.28), _VEK_VISOR.darkened(0.3), stroke)
	_alien_eyes(canvas, hc.x, hc.y - half_h * 0.02, half_w * 0.42, half_h * 0.20,
		Color("#f6ecd6"), _VEK_GRAPHITE, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + half_h * 0.44, half_w * 0.55, _VEK_GRAPHITE, mouth_shape)
	for i in range(rule_lines):
		var ry := hc.y + half_h * (0.62 + 0.11 * float(i))
		canvas.draw_line(Vector2(hc.x - half_w * 0.6, ry), Vector2(hc.x + half_w * 0.6, ry),
			_VEK_GRAPHITE.lightened(0.35), maxf(2.0, 0.015 * r))

	# --- red countersign stamps, each rotated to its own careless angle ---------------------------
	var stamp_size := 0.22 * minf(half_w, half_h)
	for i in range(stamps):
		var sc := Vector2(hc.x + stamp_x[i] * half_w, hc.y + stamp_y[i] * half_h)
		var dir := Vector2(cos(stamp_angle[i]), sin(stamp_angle[i]))
		var perp := Vector2(-dir.y, dir.x)
		match stamp_kind[i]:
			0:  # APPROVED ring
				canvas.draw_arc(sc, stamp_size, 0.0, TAU, 20, ink, stroke)
				canvas.draw_arc(sc, stamp_size * 0.55, 0.0, TAU, 16, ink, maxf(2.0, 0.015 * r))
			1:  # rotated open box
				canvas.draw_polyline(PackedVector2Array([
					sc + dir * stamp_size + perp * stamp_size * 0.6,
					sc - dir * stamp_size + perp * stamp_size * 0.6,
					sc - dir * stamp_size - perp * stamp_size * 0.6,
					sc + dir * stamp_size - perp * stamp_size * 0.6,
					sc + dir * stamp_size + perp * stamp_size * 0.6]), ink, stroke)
			2:  # scrawled signature
				canvas.draw_polyline(PackedVector2Array([
					sc - dir * stamp_size,
					sc - dir * stamp_size * 0.3 + perp * stamp_size * 0.7,
					sc + dir * stamp_size * 0.3 - perp * stamp_size * 0.7,
					sc + dir * stamp_size]), ink, stroke)

	# --- overlays: red tape across a corner, and a queue ticket pinned to the chest ---------------
	if has_tape:
		canvas.draw_line(Vector2(hc.x + half_w * 0.35, hc.y - half_h),
			Vector2(hc.x + half_w, hc.y - half_h * 0.35),
			Color(ink.r, ink.g, ink.b, 0.7), maxf(2.0, 0.05 * r))
	if has_ticket:
		var tc := Vector2(hc.x - half_w * 0.55, hc.y + half_h + 0.16 * r)
		canvas.draw_rect(Rect2(tc.x - 0.10 * r, tc.y - 0.07 * r, 0.20 * r, 0.14 * r), paper)
		canvas.draw_circle(Vector2(tc.x, tc.y - 0.04 * r), maxf(2.0, 0.017 * r), _VEK_DESK)  # punch hole
		canvas.draw_line(Vector2(tc.x - 0.06 * r, tc.y + 0.02 * r),
			Vector2(tc.x + 0.06 * r, tc.y + 0.02 * r), ink, stroke)


# Atlas Concordat (tier 25) — a cartographer-priest: a parchment head ruled with a globe graticule,
# brass compass rose and plumb line, map-blue vestments; the silhouette is a globe, a mitred priest,
# or an unfolded map projection.
const _ATL_ROBES: Array[Color] = [
	Color("#46688c"), Color("#3a5878"), Color("#2f4a68"), Color("#527ba3"), Color("#3f6390")]
const _ATL_PARCHMENTS: Array[Color] = [
	Color("#e8dcb8"), Color("#dfd0a6"), Color("#f0e6c8"), Color("#d6c79c")]
const _ATL_BRASS := Color("#c8a24a")
const _ATL_INK := Color("#1b2a3c")
const _ATL_GRID := Color("#2f5578")

static func _draw_atlas(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn here, in a fixed order, so adding features later doesn't
	# --- reshuffle existing staffers' faces.
	var form := rng.randi() % 3                       # 0 globe head · 1 tall mitred priest · 2 unfolded projection
	var robe: Color = _ATL_ROBES[rng.randi() % _ATL_ROBES.size()]
	var parchment: Color = _ATL_PARCHMENTS[rng.randi() % _ATL_PARCHMENTS.size()]
	var head_hw := (0.32 + rng.randf() * 0.20) * r    # width and height are sampled independently, so
	var head_hh := (0.32 + rng.randf() * 0.20) * r    # members read stocky / narrow / tall, not rescaled
	var grid_tilt := (rng.randf() - 0.5) * 0.9        # whole graticule axis tilts ±~0.45 rad per member
	var lat_count := 2 + rng.randi() % 3              # 2-4 bold parallels (a dense mesh turns to mush)
	var lon_count := 1 + rng.randi() % 3              # 1-3 meridians
	var has_compass := rng.randf() < 0.75
	var compass_on_chest := rng.randf() < 0.5
	var has_mitre := form == 1 or rng.randf() < 0.45  # form 1 is defined by its mitre; others may wear one
	var mitre_h := (0.26 + rng.randf() * 0.24) * r
	var has_plumb := rng.randf() < 0.5
	var has_sextant := rng.randf() < 0.45
	var has_stole := rng.randf() < 0.7
	var body_cut := 0.26 + rng.randf() * 0.12         # how high the vestments rise
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4

	# --- per-form face box. The mitred priest has a narrow face and sits low to leave room for the hat.
	var face_hw := head_hw
	var face_hh := head_hh
	var hc := Vector2(c.x, c.y - 0.04 * r)
	if form == 1:
		face_hw = head_hw * 0.68
		face_hh = head_hh * 0.92
		hc = Vector2(c.x, c.y + 0.10 * r)
	var ink := _ATL_INK
	var grid_col := _ATL_GRID.lerp(ink, 0.15)

	# --- vestments (background-most), with contour lines swept across the chest.
	canvas.draw_colored_polygon(_disc_segment_below(c, r, body_cut), robe)
	for i in range(2):
		canvas.draw_arc(c, (0.62 + float(i) * 0.15) * r, deg_to_rad(35), deg_to_rad(145), 20,
			Color(_ATL_BRASS.r, _ATL_BRASS.g, _ATL_BRASS.b, 0.45), maxf(2.0, 0.018 * r))
	if has_stole:
		for sx in [-1.0, 1.0]:
			canvas.draw_line(Vector2(c.x + sx * 0.13 * r, c.y + body_cut * r),
				Vector2(c.x + sx * 0.19 * r, c.y + 0.82 * r), _ATL_BRASS, maxf(2.0, 0.030 * r))

	# --- head silhouette: three genuinely different outlines.
	if form == 2:
		# An interrupted "unfolded globe" projection: pointed poles, gore seams down the face.
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(hc.x, hc.y - face_hh),
			Vector2(hc.x + face_hw * 0.55, hc.y - face_hh * 0.70),
			Vector2(hc.x + face_hw, hc.y - face_hh * 0.15),
			Vector2(hc.x + face_hw * 0.80, hc.y + face_hh * 0.62),
			Vector2(hc.x, hc.y + face_hh),
			Vector2(hc.x - face_hw * 0.80, hc.y + face_hh * 0.62),
			Vector2(hc.x - face_hw, hc.y - face_hh * 0.15),
			Vector2(hc.x - face_hw * 0.55, hc.y - face_hh * 0.70)]), parchment)
		for sx in [-1.0, 1.0]:
			canvas.draw_polyline(PackedVector2Array([Vector2(hc.x, hc.y - face_hh),
				Vector2(hc.x + sx * face_hw * 0.52, hc.y), Vector2(hc.x, hc.y + face_hh)]),
				grid_col, maxf(2.0, 0.016 * r))
	else:
		canvas.draw_colored_polygon(_ellipse(hc, face_hw, face_hh, 26), parchment)

	# --- graticule. Inscribed in a circle of radius grid_r so that tilting it can never push a line
	# --- outside the head, however wide or tall this member's face happens to be.
	var grid_r := minf(face_hw, face_hh) * 0.80
	var bulge := 0.0 if form == 2 else 1.0            # a flat projection has straight parallels
	var cs := cos(grid_tilt)
	var sn := sin(grid_tilt)
	var grid_w := maxf(2.0, 0.024 * r)
	for i in range(lon_count):
		var k: float = 0.0 if lon_count == 1 else -0.55 + 1.1 * float(i) / float(lon_count - 1)
		var meridian := PackedVector2Array()
		for j in range(9):
			var v := -0.92 + 1.84 * float(j) / 8.0    # normalised latitude along the meridian
			var mx := k * grid_r * lerpf(1.0, sqrt(maxf(0.0, 1.0 - v * v)), bulge)
			var my := v * grid_r
			meridian.append(Vector2(hc.x + mx * cs - my * sn, hc.y + mx * sn + my * cs))
		canvas.draw_polyline(meridian, grid_col, grid_w)
	for i in range(lat_count):
		var frac: float = 0.0 if lat_count == 1 else -0.55 + 1.1 * float(i) / float(lat_count - 1)
		var half := grid_r * lerpf(0.88, sqrt(maxf(0.0, 1.0 - frac * frac)), bulge)
		var parallel := PackedVector2Array()
		for j in range(9):
			var t := -1.0 + 2.0 * float(j) / 8.0
			var lx := t * half
			# on a sphere a parallel's near side dips toward the viewer, so its middle sags away
			# from the pole; bulge = 0 flattens this to a straight ruled line.
			var ly := frac * grid_r - bulge * frac * 0.16 * grid_r * (1.0 - t * t)
			parallel.append(Vector2(hc.x + lx * cs - ly * sn, hc.y + lx * sn + ly * cs))
		canvas.draw_polyline(parallel, grid_col, grid_w)

	# --- brass compass rose, either branded on the forehead or worn as a chest medallion.
	if has_compass:
		var rose := Vector2(c.x, c.y + 0.60 * r) if compass_on_chest else Vector2(hc.x, hc.y - face_hh * 0.58)
		var rose_r := 0.11 * r
		for i in range(4):
			var a := grid_tilt + TAU * float(i) / 4.0
			var d := Vector2(cos(a), sin(a))
			var perp := Vector2(-d.y, d.x)
			canvas.draw_colored_polygon(PackedVector2Array([rose + perp * rose_r * 0.26,
				rose - perp * rose_r * 0.26, rose + d * rose_r]), _ATL_BRASS)
		canvas.draw_circle(rose, rose_r * 0.22, ink)

	# --- face
	_alien_eyes(canvas, hc.x, hc.y - face_hh * 0.08, face_hw * 0.42, face_hh * 0.19, Color("#f6efd8"), ink, eye_shape)
	_alien_mouth(canvas, hc.x, hc.y + face_hh * 0.50, face_hw * 0.60, ink, mouth_shape)

	# --- headpiece: a tall clerical mitre. The apex is clamped to 0.90r from the disc centre so a
	# --- tall face plus a tall mitre can never spill out of the portrait circle.
	if has_mitre:
		var head_top := hc.y - face_hh
		var apex_y := maxf(c.y - 0.90 * r, head_top - mitre_h)
		var base_hw := face_hw * 0.95
		var base_y := head_top + face_hh * 0.12
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(hc.x - base_hw, base_y),
			Vector2(hc.x, apex_y), Vector2(hc.x + base_hw, base_y)]), robe.lightened(0.10))
		canvas.draw_line(Vector2(hc.x - base_hw * 0.92, base_y - face_hh * 0.04),
			Vector2(hc.x + base_hw * 0.92, base_y - face_hh * 0.04), _ATL_BRASS, maxf(2.0, 0.030 * r))

	# --- surveyor's kit: a plumb line hung clear of the head, and a brass sextant arc overhead.
	if has_plumb:
		var px := c.x + 0.58 * r
		canvas.draw_line(Vector2(px, c.y - 0.28 * r), Vector2(px, c.y + 0.38 * r), _ATL_BRASS, maxf(2.0, 0.016 * r))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(px - 0.05 * r, c.y + 0.38 * r),
			Vector2(px + 0.05 * r, c.y + 0.38 * r), Vector2(px, c.y + 0.52 * r)]), _ATL_BRASS)
	if has_sextant:
		canvas.draw_arc(c, 0.86 * r, deg_to_rad(205), deg_to_rad(335), 26, _ATL_BRASS, maxf(2.0, 0.022 * r))


# The Null Ledger (tier 26) — an entropy auditor visibly eroding out of existence: an ash-gray body
# punched through by a void hollow, chunks drifting off into the dark, red write-down marks trending
# down and thinning strike-throughs. A "decay amount" drives how much of the being is still there.
const _NUL_ASHES: Array[Color] = [
	Color("#4e5860"), Color("#5a6169"), Color("#434a50"), Color("#606a72"), Color("#3b4348")]
const _NUL_VOID := Color("#0b0d0f")          # the hole the being is falling into
const _NUL_DUST := Color("#98a1a7")          # lit edge of a broken-off fragment
const _NUL_RED := Color("#b8323c")           # cold accounting red, only for downward marks
const _NUL_EYE := Color("#d2d9dd")

static func _draw_null_ledger(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- all randomness drawn up front, in a fixed order, so adding features later keeps faces stable
	var ash: Color = _NUL_ASHES[rng.randi() % _NUL_ASHES.size()]
	var decay: float = rng.randf()                                  # 0 = nearly whole · 1 = nearly gone
	var form: int = rng.randi() % 3                                  # 0 intact · 1 bitten head · 2 scatter
	# Width and height are sampled INDEPENDENTLY (~±25% each) so members read stocky / narrow / tall.
	var head_hw: float = (0.34 + rng.randf_range(-0.085, 0.085)) * r
	var head_hh: float = (0.36 + rng.randf_range(-0.090, 0.090)) * r
	var eye_shape: int = rng.randi() % 5
	var mouth_shape: int = rng.randi() % 4
	var bite_side: float = 1.0 if rng.randf() < 0.5 else -1.0        # which side the void has eaten
	var body_top: float = 0.30 + rng.randf() * 0.14                  # where the shoulders start, as a frac of r
	var mark_count: int = 2 + rng.randi() % 3                        # red write-down ticks
	var strikes: int = 1 + rng.randi() % 2                           # thinning strike-through lines
	var frag_count: int = 3 + int(round(decay * 9.0))                # more decay, more loose debris
	var frag_angle: Array[float] = []
	var frag_dist: Array[float] = []
	var frag_size: Array[float] = []
	for _i in range(frag_count):
		frag_angle.append(rng.randf())
		frag_dist.append(rng.randf())
		frag_size.append(rng.randf())
	var shard_seed: Array[float] = []                                # form 2's head-shaped ring of shards
	for _i in range(8):
		shard_seed.append(rng.randf())

	var hc := Vector2(c.x, c.y - 0.06 * r)
	var dark := ash.darkened(0.40)
	var fade := 1.0 - decay * 0.40                                   # everything solid dims as it erodes
	var body := Color(ash.r, ash.g, ash.b, fade)
	var thin := maxf(2.0, (0.026 - 0.012 * decay) * r)               # strokes literally thin out with decay
	var one_eyed: bool = decay > 0.68                                # heavy decay costs an eye
	var core_r: float = (0.09 + decay * 0.11) * r                    # the hollow at the being's center

	# --- void backdrop -------------------------------------------------------------------------
	canvas.draw_circle(c, 0.92 * r, Color(_NUL_VOID.r, _NUL_VOID.g, _NUL_VOID.b, 0.55))

	# --- body: shoulders hugging the disc arc, then void bites punched out of their top edge ----
	canvas.draw_colored_polygon(_disc_segment_below(c, r, body_top), body)
	for sx in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(c.x + sx * 0.30 * r, c.y + (body_top + 0.02) * r),
			(0.05 + 0.11 * decay) * r, _NUL_VOID)

	# --- head / silhouette ---------------------------------------------------------------------
	if form == 2:
		# Barely a being: eight chunks still hanging in a head-shaped ring, nothing solid between them.
		for i in range(8):
			var a := TAU * float(i) / 8.0
			var p := Vector2(hc.x + cos(a) * head_hw * 0.95, hc.y + sin(a) * head_hh * 0.95)
			var s := (0.05 + shard_seed[i] * 0.06) * r
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(p.x - s, p.y - s * 0.6), Vector2(p.x + s * 0.8, p.y - s),
				Vector2(p.x + s, p.y + s * 0.7), Vector2(p.x - s * 0.5, p.y + s)]), body)
	else:
		canvas.draw_colored_polygon(_ellipse(hc, head_hw, head_hh, 26), body)
		canvas.draw_arc(hc, maxf(head_hw, head_hh) * 0.98, 0.0, TAU, 30,
			Color(_NUL_DUST.r, _NUL_DUST.g, _NUL_DUST.b, 0.25 * fade), maxf(2.0, 0.018 * r))

	# --- face (only where there is still a head to hold it) ------------------------------------
	var iris := Color(_NUL_EYE.r, _NUL_EYE.g, _NUL_EYE.b, fade)
	var eye_dx := head_hw * 0.46
	var eye_sz := (0.055 + 0.02 * (1.0 - decay)) * r
	if form == 2 or one_eyed:
		# One surviving eye, set off-center on the side the void has not reached.
		var e := Vector2(hc.x - bite_side * eye_dx, hc.y - 0.04 * r)
		canvas.draw_circle(e, eye_sz, iris)
		canvas.draw_circle(e, eye_sz * 0.45, _NUL_VOID)
	else:
		_alien_eyes(canvas, hc.x, hc.y - 0.04 * r, eye_dx, eye_sz, iris, _NUL_VOID, eye_shape)
	if form != 2 and decay < 0.85:
		_alien_mouth(canvas, hc.x, hc.y + head_hh * 0.52, head_hw * 0.62,
			Color(dark.r, dark.g, dark.b, fade), mouth_shape)

	# --- the void core: a hollow ring, sitting in the head or the chest -------------------------
	var core := Vector2(hc.x, hc.y + head_hh * 0.10) if form == 2 else Vector2(c.x, c.y + (body_top + 0.16) * r)
	canvas.draw_circle(core, core_r, _NUL_VOID)
	canvas.draw_arc(core, core_r, 0.0, TAU, 28,
		Color(_NUL_DUST.r, _NUL_DUST.g, _NUL_DUST.b, 0.55), maxf(2.0, 0.02 * r))

	# --- form 1's hard bite: a void disc overlapping one side of the head, eating whatever was there
	if form == 1:
		var bite_c := Vector2(hc.x + bite_side * head_hw * 0.80, hc.y - head_hh * 0.06)
		var bite_r := head_hw * (0.55 + 0.35 * decay)
		canvas.draw_circle(bite_c, bite_r, _NUL_VOID)
		canvas.draw_arc(bite_c, bite_r, 0.0, TAU, 26,
			Color(_NUL_DUST.r, _NUL_DUST.g, _NUL_DUST.b, 0.35), maxf(2.0, 0.018 * r))

	# --- loose fragments drifting off; orbit radius clamped so nothing leaves the disc ----------
	for i in range(frag_count):
		var fa := TAU * frag_angle[i]
		var fd := minf(0.55 + frag_dist[i] * 0.28, 0.83) * r
		var fs := (0.018 + frag_size[i] * 0.032) * r
		var fp := Vector2(c.x + cos(fa) * fd, c.y + sin(fa) * fd)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(fp.x - fs, fp.y), Vector2(fp.x, fp.y - fs * 1.2),
			Vector2(fp.x + fs, fp.y + fs * 0.4), Vector2(fp.x - fs * 0.3, fp.y + fs)]),
			Color(_NUL_DUST.r, _NUL_DUST.g, _NUL_DUST.b, 0.30 + 0.55 * frag_size[i]))

	# --- red write-down marks: short ticks stepping down and to the right, then a down arrow ----
	var mark_y := c.y + 0.16 * r
	for i in range(mark_count):
		var mx := c.x - 0.26 * r + float(i) * 0.19 * r
		var my := mark_y + float(i) * 0.09 * r
		canvas.draw_line(Vector2(mx, my), Vector2(mx + 0.14 * r, my + 0.09 * r), _NUL_RED, maxf(2.0, 0.024 * r))
	var tip := Vector2(c.x - 0.26 * r + float(mark_count - 1) * 0.19 * r + 0.14 * r,
		mark_y + float(mark_count - 1) * 0.09 * r + 0.09 * r)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(tip.x - 0.05 * r, tip.y - 0.03 * r), Vector2(tip.x + 0.03 * r, tip.y - 0.07 * r),
		Vector2(tip.x + 0.02 * r, tip.y + 0.06 * r)]), _NUL_RED)

	# --- strike-throughs ruled across the being; they thin (and dim) as the member decays -------
	for i in range(strikes):
		var sy := hc.y - head_hh * 0.30 + float(i) * head_hh * 0.55
		canvas.draw_line(Vector2(hc.x - head_hw * 1.05, sy), Vector2(hc.x + head_hw * 1.05, sy),
			Color(_NUL_RED.r, _NUL_RED.g, _NUL_RED.b, 0.75 - 0.35 * decay), thin)


# The Proprietors Absolute (tier 27, the FINAL tier) — the owner of ownership: a deed-seal crown,
# wax-seal medallions, a heavy signet ring, and surveyor's claim-lines staking out the whole disc.
# Pose is deliberately frontal and bilaterally symmetric (their authority is absolute), but the
# proportions, silhouette form, crown and regalia all vary widely so members are still individuals.
const _PRO_ROBES: Array[Color] = [
	Color("#3a2e59"), Color("#463461"), Color("#2f2749"), Color("#513a6b"), Color("#342b55")]
const _PRO_GOLDS: Array[Color] = [Color("#e6c15a"), Color("#f0d488"), Color("#d4a63c"), Color("#ffe6a3")]
const _PRO_WAX: Array[Color] = [Color("#8e2b3a"), Color("#a33546"), Color("#7a2230")]
const _PRO_INK := Color("#1a1428")


static func _draw_proprietors(canvas: CanvasItem, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# --- every random value is drawn up front, in a fixed order, so faces stay stable ------------
	var robe: Color = _PRO_ROBES[rng.randi() % _PRO_ROBES.size()]
	var gold: Color = _PRO_GOLDS[rng.randi() % _PRO_GOLDS.size()]
	var wax: Color = _PRO_WAX[rng.randi() % _PRO_WAX.size()]
	var form := rng.randi() % 3                        # 0 broad monarch · 1 tall spire · 2 seal-disc
	# width and height are sampled independently (±25%) so members read stocky / narrow / tall
	var head_hw := (0.34 + (rng.randf() - 0.5) * 0.17) * r
	var head_hh := (0.36 + (rng.randf() - 0.5) * 0.18) * r
	var mantle_cut := 0.20 + rng.randf() * 0.22        # how high the mantle/shoulders sit on the disc
	var crown_points := 3 + rng.randi() % 5            # 3..7 deed-seal spikes
	var crown_h := (0.12 + rng.randf() * 0.13) * r
	var crown_span := 0.72 + rng.randf() * 0.42        # crown width as a multiple of head half-width
	var claim_pairs := 2 + rng.randi() % 4             # mirrored pairs of surveyor's boundary lines
	var claim_spread := deg_to_rad(30.0 + rng.randf() * 55.0)
	var seals := 1 + rng.randi() % 3                   # wax-seal medallions across the chest
	var notches := 8 + 4 * (rng.randi() % 3)           # seal-disc notch count (multiple of 4 = symmetric)
	var eye_shape := rng.randi() % 5
	var mouth_shape := rng.randi() % 4
	var seal_ticks: Array[int] = []                    # per-seal tick count, collected up front
	for _i in range(seals):
		seal_ticks.append(6 + rng.randi() % 7)

	var deep := robe.darkened(0.35)
	var lit := robe.lightened(0.22)
	var head_center := Vector2(c.x, c.y - 0.08 * r)

	# --- back layer: claim-lines radiating outward, staking the disc itself -----------------------
	# Mirrored about vertical and aimed upward/outward; they stop at 0.88r so nothing touches the rim.
	for i in range(claim_pairs):
		var t := 0.0 if claim_pairs == 1 else float(i) / float(claim_pairs - 1)
		var off := lerpf(0.0, claim_spread, t)
		for side in [-1.0, 1.0]:
			var a: float = -PI / 2.0 + side * (deg_to_rad(18.0) + off)
			var dir := Vector2(cos(a), sin(a))
			canvas.draw_line(c + dir * 0.60 * r, c + dir * 0.88 * r,
				Color(gold.r, gold.g, gold.b, 0.45), maxf(2.0, 0.018 * r))
			canvas.draw_circle(c + dir * 0.88 * r, 0.015 * r, Color(gold.r, gold.g, gold.b, 0.55))
	# a surveyed boundary arc tying the claim-lines together
	canvas.draw_arc(c, 0.80 * r, deg_to_rad(200), deg_to_rad(340), 28,
		Color(gold.r, gold.g, gold.b, 0.30), maxf(2.0, 0.014 * r))

	# --- body / regalia: silhouette differs per form ---------------------------------------------
	if form == 0:
		# broad monarch: a heavy mantle that flares wider than the shoulders beneath it
		canvas.draw_colored_polygon(_disc_segment_below(c, r, mantle_cut), deep)
		canvas.draw_colored_polygon(_disc_segment_below(c, r, mantle_cut + 0.16), robe)
		# collar V, pointing down from the mantle line into the chest
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - head_hw * 0.9, c.y + mantle_cut * r),
			Vector2(c.x + head_hw * 0.9, c.y + mantle_cut * r),
			Vector2(c.x, c.y + (mantle_cut + 0.30) * r)]), lit)
	elif form == 1:
		# tall spire: narrow shoulders sitting low, with a slim vertical column of robe
		canvas.draw_colored_polygon(_disc_segment_below(c, r, mantle_cut + 0.26), deep)
		canvas.draw_rect(Rect2(c.x - head_hw * 0.55, c.y + 0.10 * r,
			head_hw * 1.10, 0.80 * r), robe)
		canvas.draw_line(Vector2(c.x, c.y + 0.14 * r), Vector2(c.x, c.y + 0.72 * r),
			Color(gold.r, gold.g, gold.b, 0.55), maxf(2.0, 0.016 * r))
	else:
		# angular authority: hard-edged trapezoid shoulders over the disc segment
		canvas.draw_colored_polygon(_disc_segment_below(c, r, mantle_cut + 0.06), deep)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - head_hw * 1.5, c.y + (mantle_cut + 0.30) * r),
			Vector2(c.x - head_hw * 0.8, c.y + (mantle_cut + 0.06) * r),
			Vector2(c.x + head_hw * 0.8, c.y + (mantle_cut + 0.06) * r),
			Vector2(c.x + head_hw * 1.5, c.y + (mantle_cut + 0.30) * r)]), robe)

	# --- head ------------------------------------------------------------------------------------
	if form == 0:
		canvas.draw_colored_polygon(_ellipse(head_center, head_hw, head_hh, 26), lit)
	elif form == 1:
		# tapered hexagon: narrow crest, widest just above mid, drawn out to a long austere jaw
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(head_center.x - head_hw * 0.45, head_center.y - head_hh),
			Vector2(head_center.x + head_hw * 0.45, head_center.y - head_hh),
			Vector2(head_center.x + head_hw, head_center.y - head_hh * 0.15),
			Vector2(head_center.x + head_hw * 0.55, head_center.y + head_hh),
			Vector2(head_center.x - head_hw * 0.55, head_center.y + head_hh),
			Vector2(head_center.x - head_hw, head_center.y - head_hh * 0.15)]), lit)
	else:
		# the head IS a notched seal-disc: alternating radii around an ellipse
		var seal_head := PackedVector2Array()
		for i in range(notches):
			var a := TAU * float(i) / float(notches)
			var edge := 1.0 if i % 2 == 0 else 0.84   # every other vertex is pulled in to cut a notch
			seal_head.append(Vector2(head_center.x + cos(a) * head_hw * edge,
				head_center.y + sin(a) * head_hh * edge))
		canvas.draw_colored_polygon(seal_head, lit)
		canvas.draw_arc(head_center, minf(head_hw, head_hh) * 0.78, 0.0, TAU, 30, gold, maxf(2.0, 0.016 * r))

	# --- face ------------------------------------------------------------------------------------
	_alien_eyes(canvas, head_center.x, head_center.y - head_hh * 0.14,
		head_hw * 0.46, head_hw * 0.24, gold, _PRO_INK, eye_shape)
	_alien_mouth(canvas, head_center.x, head_center.y + head_hh * 0.52,
		head_hw * 0.75, _PRO_INK, mouth_shape)

	# --- wax-seal medallions on the chest, laid out symmetrically about the centre ----------------
	var seal_y := c.y + (mantle_cut + 0.16) * r
	var seal_r := (0.085 - 0.012 * float(seals)) * r   # more medallions means smaller ones
	for i in range(seals):
		var sx := (float(i) - float(seals - 1) * 0.5) * seal_r * 2.6
		var sc := Vector2(c.x + sx, seal_y)
		canvas.draw_circle(sc, seal_r, wax)
		canvas.draw_arc(sc, seal_r * 0.62, 0.0, TAU, 20, gold, maxf(2.0, 0.012 * r))
		for t in range(seal_ticks[i]):                 # radiating title-marks around the seal rim
			var ta := TAU * float(t) / float(seal_ticks[i])
			var td := Vector2(cos(ta), sin(ta))
			canvas.draw_line(sc + td * seal_r * 0.7, sc + td * seal_r * 0.98, gold, maxf(2.0, 0.008 * r))

	# --- heavy signet ring, worn low and centred so it reads as the seal of office ----------------
	var signet := Vector2(c.x, c.y + (mantle_cut + 0.42) * r)
	if signet.y < c.y + 0.80 * r:                      # only if it still clears the disc rim
		canvas.draw_arc(signet, 0.075 * r, 0.0, TAU, 24, gold, maxf(2.0, 0.030 * r))
		canvas.draw_circle(signet, 0.038 * r, wax)

	# --- crown of deed-seal spikes, drawn last so it sits on top of everything --------------------
	var crown_hw := head_hw * crown_span
	var crown_base := head_center.y - head_hh * 0.82
	var crown := PackedVector2Array([Vector2(head_center.x - crown_hw, crown_base)])
	for i in range(crown_points):
		var x_left := head_center.x - crown_hw + (2.0 * crown_hw) * float(i) / float(crown_points)
		var peak_x := x_left + crown_hw / float(crown_points)
		crown.append(Vector2(x_left, crown_base - crown_h * 0.25))   # shallow valley between spikes
		crown.append(Vector2(peak_x, crown_base - crown_h))
	crown.append(Vector2(head_center.x + crown_hw, crown_base - crown_h * 0.25))
	crown.append(Vector2(head_center.x + crown_hw, crown_base + head_hh * 0.30))
	crown.append(Vector2(head_center.x - crown_hw, crown_base + head_hh * 0.30))
	canvas.draw_colored_polygon(crown, deep)
	# gold band across the crown's base, and a seal-bead capping each spike
	canvas.draw_line(Vector2(head_center.x - crown_hw, crown_base + head_hh * 0.12),
		Vector2(head_center.x + crown_hw, crown_base + head_hh * 0.12), gold, maxf(2.0, 0.024 * r))
	for i in range(crown_points):
		var bead_x := head_center.x - crown_hw + (2.0 * crown_hw) * (float(i) + 0.5) / float(crown_points)
		canvas.draw_circle(Vector2(bead_x, crown_base - crown_h), maxf(2.0, 0.022 * r), gold)

# --- shared alien expression (so staffers within a civ vary) ------------------------------------

## Two eyes with one of several shapes, at (cx±dx, cy). iris = eye fill, pupil = dark center.
static func _alien_eyes(canvas: CanvasItem, cx: float, cy: float, dx: float, sz: float,
		iris: Color, pupil: Color, shape: int) -> void:
	for sx in [-1.0, 1.0]:
		var e := Vector2(cx + sx * dx, cy)
		match shape:
			0:  # round
				canvas.draw_circle(e, sz, iris)
				canvas.draw_circle(e, sz * 0.5, pupil)
			1:  # tall oval
				canvas.draw_colored_polygon(_ellipse(e, sz * 0.8, sz * 1.15, 14), iris)
				canvas.draw_circle(e, sz * 0.45, pupil)
			2:  # wide
				canvas.draw_colored_polygon(_ellipse(e, sz * 1.2, sz * 0.72, 14), iris)
				canvas.draw_circle(e, sz * 0.4, pupil)
			3:  # happy closed (^)
				canvas.draw_arc(e, sz, deg_to_rad(200), deg_to_rad(340), 10, pupil, maxf(2.0, sz * 0.45))
			4:  # surprised (big, offset pupil)
				canvas.draw_circle(e, sz * 1.15, iris)
				canvas.draw_circle(e + Vector2(sx * sz * 0.2, -sz * 0.2), sz * 0.5, pupil)


## A mouth with one of several shapes, centered at (mx, my). w = width scale.
static func _alien_mouth(canvas: CanvasItem, mx: float, my: float, w: float, col: Color, shape: int) -> void:
	match shape:
		0:  # smile
			canvas.draw_arc(Vector2(mx, my - 0.3 * w), 0.5 * w, deg_to_rad(25), deg_to_rad(155), 12, col, maxf(2.0, 0.14 * w))
		1:  # neutral
			canvas.draw_line(Vector2(mx - 0.4 * w, my), Vector2(mx + 0.4 * w, my), col, maxf(2.0, 0.11 * w))
		2:  # small o
			canvas.draw_circle(Vector2(mx, my), 0.22 * w, col)
		3:  # slight frown
			canvas.draw_arc(Vector2(mx, my + 0.32 * w), 0.5 * w, deg_to_rad(205), deg_to_rad(335), 12, col, maxf(2.0, 0.11 * w))


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
