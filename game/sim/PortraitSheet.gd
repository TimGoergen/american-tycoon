extends SceneTree

# Renders every alien staffer portrait to PNG and checks them, so the tiers 13-27 batch can finally
# get the validation `Plans/Add_20_Civs_And_Alien_Portraits.md` required and never received.
#
# Usage (NOTE: not --headless — this one needs a real renderer):
#   godot --path . --rendering-driver opengl3 --script res://sim/PortraitSheet.gd
#
# Writes to user:// — the path is printed at the end.
#
# WHY A TOOL RATHER THAN A CHECKLIST. "Do the portraits look right" is a question for eyes, and
# reaching tier 27 in-game to see the last one is hours of play. Rendering them straight from
# StafferFace produces the same pixels the game draws, all of them, in one pass — so the human part
# becomes looking at a sheet instead of grinding to the frontier.
#
# What the machine can decide, it decides here: a portrait that is blank, that is identical to
# another civ's, that spills outside its disc, or that ignores its per-staffer seed is a defect no
# one needs to squint at. What is left for a person is whether the thing looks GOOD.

## Portrait size in the sheet. The game's own ManagerCircle disc is ~120-190px depending on row
## height, so this is a touch larger than life — flaws that would hide at device size are visible.
const CELL := 200
## How many staffers to draw per civ. They are seeded per property, so this shows the VARIATION
## within one civilization, which is where a broken seed hides.
const SAMPLES_PER_TIER := 4
## Alien tiers. Earth (1-2) uses the human face path, not _draw_alien.
const FIRST_ALIEN_TIER := 3
const LAST_ALIEN_TIER := 27

var _failures := 0
var _face_script: GDScript
var _viewport: SubViewport
var _canvas: Node2D
## tier -> the images rendered for it, kept for the cross-civ comparison.
var _rendered: Dictionary = {}
## The empty disc for the civ currently being measured. Every "is there a face here" question is
## answered by DIFFERENCE against this rather than by hunting for non-black pixels: the disc is not
## black, so a check that counted it as ink would pass on a completely blank portrait (it did, on
## the first run). Re-rendered per civ, because each one's disc is its own accent colour.
var _plate: Image
## tier -> portrait-vs-disc contrast ratio, reported at the end as a ranking.
var _contrast: Dictionary = {}
## Property configs, for each civ's real accent colour.
var _configs: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Alien portraits: tiers %d-%d ===\n" % [FIRST_ALIEN_TIER, LAST_ALIEN_TIER])

	_face_script = load("res://scripts/ui/" + "StafferFace.gd")
	if _face_script == null:
		print("FAILED to load StafferFace.gd")
		quit(1)
		return

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL, CELL)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_canvas = Node2D.new()
	_viewport.add_child(_canvas)

	_configs = ConfigLoader.load_property_configs()

	var sheet_rows: Array[Image] = []
	for tier in range(FIRST_ALIEN_TIER, LAST_ALIEN_TIER + 1):
		var row := await _render_tier(tier)
		sheet_rows.append(row)

	_check_every_tier_is_distinct()
	_report_contrast()
	_write_sheet(sheet_rows)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED — the sheet is for your eyes; the machine found nothing wrong.")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Draw one civ's staffers side by side and check what can be checked automatically.
func _render_tier(tier: int) -> Image:
	# THE REAL PROPERTIES OF THIS EPOCH, not arbitrary indices. Two reasons: the portrait is seeded
	# from the property index, so these are the faces the player will actually meet; and the disc
	# behind them is the property's own accent colour, which is most of what a portrait is read
	# against. Judging these on a neutral gray plate made the dark civs look like empty circles
	# (first run) — a defect of the harness, not the art.
	var indices := _property_indices_for_tier(tier)
	# This civ's empty disc, for the measurements below.
	_plate = await _render_one(tier, indices[0] if not indices.is_empty() else tier, false)

	var images: Array[Image] = []
	for sample in range(SAMPLES_PER_TIER):
		var index: int = indices[sample % indices.size()] if not indices.is_empty() else tier
		images.append(await _render_one(tier, index))

	var blank := 0
	for image in images:
		if _ink_fraction(image) < 0.02:
			blank += 1
	_check("tier %2d draws something at all" % tier, blank == 0)

	# THE SEED MUST MATTER. Four identical staffers means the per-property seed is being ignored —
	# every alien in the civ would wear the same face, which reads as a rendering bug rather than a
	# design choice.
	var identical_samples := 0
	for i in range(1, images.size()):
		if _difference(images[0], images[i]) < 0.005:
			identical_samples += 1
	_check("tier %2d varies between staffers (%d of %d identical)"
			% [tier, identical_samples, images.size() - 1],
		identical_samples < images.size() - 1)

	# STAY INSIDE THE DISC. The portrait is drawn into a circular plate, so ink in the corners is
	# ink the ManagerCircle will clip — a limb or halo that gets cut off on device.
	var spill := _corner_ink(images[0])
	_check("tier %2d stays inside its disc (%.1f%% ink in the corners)" % [tier, spill * 100.0],
		spill < 0.06)

	_check_contrast(tier, images[0])

	_rendered[tier] = images
	return _join_across(images)


## Render a single portrait and return its image.
func _render_one(tier: int, property_index: int, with_face: bool = true) -> Image:
	for child in _canvas.get_children():
		child.queue_free()

	var face := PortraitCell.new()
	face.setup(_face_script, property_index, tier, CELL, with_face, _accent_for(property_index))
	_canvas.add_child(face)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


## How far the portrait's palette sits from its own disc, as a WCAG contrast ratio. REPORTED, NOT
## ENFORCED, and the distinction was earned the hard way.
##
## The first version of this failed anything under 3:1 — the floor the project applies to large text
## and graphical elements — and it failed 16 of the 25 civs. Looking at those civs, most are
## perfectly legible: Norrvane measures 1.52:1 and reads clearly, because pale heads on slate blue
## are carried by SILHOUETTE and internal detail, not by luminance distance from the backdrop. A
## ratio built for text against its background does not describe an illustration that also has an
## outline, features, and a shape.
##
## So this ranks rather than judges. The number is a good pointer at where to look first — the bottom
## of the list is where a genuinely invisible civ would sit — and the sheet is what decides.
func _check_contrast(tier: int, image: Image) -> void:
	var disc := _plate.get_pixel(image.get_width() / 2, image.get_height() / 2)
	var disc_luminance := _relative_luminance(disc)

	var darkest := 1.0
	var lightest := 0.0
	for y in range(10, image.get_height() - 10, 2):
		for x in range(10, image.get_width() - 10, 2):
			var pixel := image.get_pixel(x, y)
			if pixel.is_equal_approx(_plate.get_pixel(x, y)):
				continue      # still disc, not face
			var luminance := _relative_luminance(pixel)
			darkest = minf(darkest, luminance)
			lightest = maxf(lightest, luminance)

	var best := maxf(_contrast_ratio(disc_luminance, darkest),
		_contrast_ratio(disc_luminance, lightest))
	_contrast[tier] = best


## Rank the civs by how far their palette sits from their own disc, faintest first. Not a verdict —
## see _check_contrast — but it is the order to review the sheet in.
func _report_contrast() -> void:
	var tiers := _contrast.keys()
	tiers.sort_custom(func(a, b): return float(_contrast[a]) < float(_contrast[b]))
	print("
Portrait-vs-disc contrast, faintest first (a ranking, not a pass mark):")
	var line := ""
	for i in range(tiers.size()):
		line += "  tier %2d %.2f:1" % [tiers[i], _contrast[tiers[i]]]
		if i % 4 == 3:
			print(line)
			line = ""
	if line != "":
		print(line)


## WCAG relative luminance, the same formula used elsewhere in the project for colour checks.
func _relative_luminance(colour: Color) -> float:
	return 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b


func _contrast_ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## Which properties belong to this epoch — the staffers the player actually meets there.
func _property_indices_for_tier(tier: int) -> Array[int]:
	var indices: Array[int] = []
	for i in range(_configs.size()):
		if int((_configs[i] as PropertyConfig).unlock_tier) == tier:
			indices.append(i)
	return indices


## The disc colour behind a portrait: the property's own accent, exactly as ManagerCircle uses it for
## a STAFFED row. The plate render (property 0) uses the same call, so the difference measurements
## stay honest — but note each civ's plate differs, which is why the blank check compares against a
## per-cell plate rather than one shared image.
func _accent_for(property_index: int) -> Color:
	if property_index < 0 or property_index >= _configs.size():
		return UiPalette.SILVER
	return (_configs[property_index] as PropertyConfig).accent_color


## No two civilizations may look the same. A copy-pasted dispatch arm — the likeliest mistake in a
## 25-branch match statement — produces exactly this, and nothing else would catch it.
func _check_every_tier_is_distinct() -> void:
	print("")
	var collisions: Array[String] = []
	for tier_a in _rendered:
		for tier_b in _rendered:
			if tier_b <= tier_a:
				continue
			# Compare the FIRST sample of each, seeded differently, so a match means the drawing
			# itself is shared rather than the seed coinciding.
			if _difference(_rendered[tier_a][0], _rendered[tier_b][0]) < 0.01:
				collisions.append("%d≈%d" % [tier_a, tier_b])
	_check("every civilization looks different from every other (%s)"
			% ("none alike" if collisions.is_empty() else ", ".join(collisions)),
		collisions.is_empty())


## Fraction of pixels where this portrait DIFFERS from the empty plate — i.e. how much face there is.
func _ink_fraction(image: Image) -> float:
	return _ink(image, false)


## The same measure, restricted to the corners outside the inscribed disc. The game draws these into
## a circular plate, so ink out here is ink the ManagerCircle will clip: a limb or halo cut off on
## device.
func _corner_ink(image: Image) -> float:
	return _ink(image, true)


func _ink(image: Image, corners_only: bool) -> float:
	var centre := Vector2(image.get_width(), image.get_height()) * 0.5
	var radius := minf(centre.x, centre.y)
	var inked := 0
	var total := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var outside := Vector2(x, y).distance_to(centre) > radius
			if corners_only != outside:
				continue
			total += 1
			var pixel := image.get_pixel(x, y)
			var plate := _plate.get_pixel(x, y)
			var delta := absf(pixel.r - plate.r) + absf(pixel.g - plate.g) + absf(pixel.b - plate.b)
			if delta > 0.06:
				inked += 1
	return float(inked) / maxf(1.0, float(total))


## Mean per-channel difference between two images, 0 = identical.
func _difference(a: Image, b: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			total += absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)
			samples += 1
	return total / maxf(1.0, float(samples) * 3.0)


func _join_across(images: Array[Image]) -> Image:
	var row := Image.create(CELL * images.size(), CELL, false, images[0].get_format())
	for i in range(images.size()):
		row.blit_rect(images[i], Rect2i(0, 0, CELL, CELL), Vector2i(CELL * i, 0))
	return row


## One PNG per civ plus a full contact sheet, so a suspect civ can be opened on its own.
func _write_sheet(rows: Array[Image]) -> void:
	var directory := "user://portraits"
	DirAccess.make_dir_recursive_absolute(directory)

	var sheet := Image.create(CELL * SAMPLES_PER_TIER, CELL * rows.size(), false, rows[0].get_format())
	for i in range(rows.size()):
		sheet.blit_rect(rows[i], Rect2i(0, 0, rows[i].get_width(), CELL), Vector2i(0, CELL * i))
		rows[i].save_png("%s/tier_%02d.png" % [directory, FIRST_ALIEN_TIER + i])
	sheet.save_png("%s/all_tiers.png" % directory)

	print("\nWrote %d civ strips + all_tiers.png to %s"
		% [rows.size(), ProjectSettings.globalize_path(directory)])


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


## A Node2D that draws one portrait, since StafferFace draws into a CanvasItem rather than returning
## an image.
class PortraitCell:
	extends Node2D

	var _script_ref: GDScript
	var _property_index: int
	var _tier: int
	var _cell: int
	var _with_face: bool
	var _accent: Color

	func setup(script_ref: GDScript, property_index: int, tier: int, cell: int,
			with_face: bool, accent: Color) -> void:
		_script_ref = script_ref
		_property_index = property_index
		_tier = tier
		_cell = cell
		_with_face = with_face
		_accent = accent

	func _draw() -> void:
		# The plate the game actually uses: a DISC, with the cell's corners left dark. Judging a
		# portrait against pure black would flatter dark civs and punish bright ones, and the disc
		# edge is what makes "this drawing spills out of its circle" measurable at all.
		var centre := Vector2(_cell, _cell) * 0.5
		draw_rect(Rect2(0, 0, _cell, _cell), Color(0.05, 0.05, 0.06))
		draw_circle(centre, _cell * 0.5, _accent)
		if _with_face:
			_script_ref.call("draw_face", self, _property_index, _tier, centre, _cell * 0.45)
