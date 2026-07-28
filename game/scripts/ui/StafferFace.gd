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
# Blue/White Collar split) draw human faces; alien tiers with a bespoke being draw it, and
# draw_face() returns false for the rest so the caller can fall back to the old headshot icon
# until those treatments are built (currently tiers 13+, the batch-2 civs).

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
## caller then falls back to the gray headshot). Built so far: Vashti Deep-Court (tier 8).
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
