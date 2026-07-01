class_name MatchThreeMinigame
extends Minigame

# The match-3 minigame TYPE (GDD §5.5) — the first entry in the minigame library. Drag a
# gem toward a neighbor to swap; matches flash with a size badge, clear, and survivors +
# new gems fall into the gaps (resolution steps replayed from MatchThreeBoard, which a
# board test proves can't desync).
#
# Scoring (Tim's minigame v4, 2026-06-25) — you can never LOSE points, only earn them, and
# the skill is in choosing WHICH matches to make:
#   * Every match scores. A bigger match scores more PER gem (a 4- or 5-line is worth more
#     than a plain 3), so going for longer lines pays off.
#   * A single swap that cascades (one match drops gems into another) earns a rising COMBO
#     multiplier on each successive cascade step.
#   * Each round ONE gem type is flagged as the AVOID gem. A match group that does NOT contain
#     the avoid gem earns a +15% bonus (×1.15); a match group that DOES contain it is docked
#     −60% (×0.40). So the avoid gem is a gem to steer AROUND — clean matches pay far more.
#   * Calibration (Tim): a whole 20-second round of ordinary clean matching lands you at ~100%
#     (the host's "full" line, keep all your Legacy). Strong cascade / large-match play climbs
#     up into the extra-high bonus band toward the maximum. See get_performance, which maps the
#     running score onto the host's curve so this holds at any bonus cap.
#
# This control owns ONLY the board gameplay. The host (MinigameScreen) owns the countdown,
# the spectrum bar, the result, and the multiplier — see Minigame for the contract.

const Board = preload("res://scripts/core/MatchThreeBoard.gd")

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const GEM_COLORS := 4

# --- Match scoring (Tim's minigame v4) ---------------------------------------
# UN-PLAYTESTED (polish pass 2026-06-29): the three score constants below were RE-ANCHORED
# together so they read as one coherent set instead of a trimmed odd value (9.5) sitting next
# to round thresholds. POINTS_PER_GEM went back to a clean 10.0 and SCORE_FULL nudged 300 -> 320
# to hold the SAME "full" difficulty (full ≈ 32 gem-units either way), so this is a tidy-up, NOT
# a difficulty crank (per the locked "Match Three = hold difficulty" decision). Confirm on device.
## Base points for each gem in a match. Every match's score derives from this multiplicatively,
## so this single value scales the whole point economy. Restored to the clean 10.0 basis (was 9.5).
const POINTS_PER_GEM := 10.0
## Larger matches pay more PER gem: a group of n gems is worth POINTS_PER_GEM × n × (1 + this ×
## (n - 3)). So a 3-line is ×1, a 4-line ×1.5, a 5-line ×2 — bigger lines are worth chasing.
const SIZE_BONUS := 0.5
## Combo: each successive cascade step in ONE swap multiplies that step's points by
## 1 + COMBO_BONUS × step_index (step 0 = ×1, step 1 = ×2, step 2 = ×3 …). Rewards chain setups.
## DESIRABILITY (polish pass, Tim's "decide and comment"): this combo is left DELIBERATELY
## UNBOUNDED. A long lucky cascade can spike the score straight to SCORE_MAX and end the round —
## but because you can only ever EARN points (never lose them), that is a pure positive surprise,
## never a punishment. A big chain "winning" the round outright is a good feeling, so we keep it
## uncapped. (If device play shows it ending rounds too abruptly, cap it then.)
const COMBO_BONUS := 1.0
## A match group that AVOIDS the avoid gem earns this bonus (+15%).
const CLEAN_MATCH_FACTOR := 1.15
## A match group that INCLUDES the avoid gem is docked this much (−60%).
const AVOID_MATCH_FACTOR := 0.40

## Score that maps to the host's "full" (1.0x) line — roughly a whole ~20-second round of
## ordinary clean matching (Tim: "regular clean play = ~100%"). Nudged 300 -> 320 alongside the
## POINTS_PER_GEM restore so the "full" difficulty is held (see the re-anchor note above).
const SCORE_FULL := 320.0
## Score that maps to performance 1.0 (the host's max extra-high bonus) — roughly a whole round
## of strong cascade / large-match play. Feel-tune estimate (same v4 / 20-second basis).
const SCORE_MAX := 1000.0

## A square cell, generously sized for thumb taps and low-vision readability (§1b),
## plus the gap between cells. PITCH is the cell-to-cell pixel stride.
const CELL_SIZE := 96
const GAP := 8
const PITCH := CELL_SIZE + GAP

## The bonus banner's gem tile — deliberately much larger than a board cell so this round's
## AVOID gem stands out as a prominent "steer around this" cue pinned above the grid.
const BONUS_ICON_SIZE := 198

## How far a press must move before it counts as a drag-swap (rather than a stray tap).
const DRAG_THRESHOLD := CELL_SIZE * 0.4

# Animation durations (seconds).
const SWAP_TIME := 0.16
const FLASH_TIME := 0.14
const CLEAR_TIME := 0.18
const FALL_TIME := 0.30

# Each gem id 0..3 gets a distinct, hand-drawn SVG with its own COLOR and SHAPE (round,
# diamond, hexagon, teardrop) so they read at a glance for colour-blind / low-vision players.
# The SVGs live in art/icons/ so Tim can restyle a gem by editing one file.
const GEM_TEXTURE := [
	preload("res://art/icons/gem_red.svg"),
	preload("res://art/icons/gem_gold.svg"),
	preload("res://art/icons/gem_teal.svg"),
	preload("res://art/icons/gem_green.svg"),
]

var _board
var _animating: bool = false
var _rng := RandomNumberGenerator.new()

# Avoid-gem scoring state.
## The single AVOID gem type this round (a color id). Matching a group that contains this gem
## is docked −60%; matching only clean gems earns +15%.
var _avoid_type: int = 0
## Total points earned so far (only ever rises — there is no way to lose points).
var _score: float = 0.0
## Whether the player ever matched a group containing the avoid gem — used in the result summary.
var _matched_avoid_gem: bool = false
## Set once the score reaches SCORE_MAX (performance 1.0, the host's max bonus). Because the score
## only ever rises, the outcome can no longer change, so we end the round early and stop accepting
## input. Guards against emitting `completed` more than once.
var _finished: bool = false
## The live "Score: N" readout above the grid.
var _score_label: Label

# Drag-to-swap state.
var _dragging: bool = false
var _drag_row: int = -1
var _drag_col: int = -1
var _drag_press_pos: Vector2 = Vector2.ZERO

var _board_area: Control
## _gem_nodes[row][col] -> the gem Control currently at that cell (or null mid-clear).
var _gem_nodes: Array = []

# --- Polish-pass juice state -------------------------------------------------
## A bright rounded ring shown around the gem the player is currently dragging, so "selected"
## reads loudly on the cream board (the old modulate/scale alone was too subtle). Pulses while
## visible, driven from _process by _pulse_phase. Hidden whenever no gem is grabbed.
var _select_ring: Panel
## The big AVOID gem tile from the banner, kept so we can pop it in on round start and give it a
## gentle continuous pulse (it is the round's "steer around this" cue, so it should draw the eye).
var _banner_icon: Control
## True once the banner's intro pop has finished, so the idle pulse doesn't fight the intro tween.
var _banner_ready: bool = false
## Free-running phase (seconds) accumulated in _process, driving the idle pulses of the selection
## ring and the AVOID banner. A single accumulated float so we never leak idle-pulse tweens.
var _pulse_phase: float = 0.0


func display_name() -> String:
	return "Match Three"


func how_to_play() -> String:
	return "Match gems to score. Clean matches pay MORE — AVOID matching the marked gem!"


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_board = Board.new(GRID_WIDTH, GRID_HEIGHT, GEM_COLORS)
	_choose_avoid_type()

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# A live running score readout, on its own line under the intro.
	var score_row := _build_score_row()

	# The banner and the framed board travel together as one group, vertically centered in the
	# space below the intro/score lines. A small separation keeps the AVOID banner pinned right
	# above the board.
	var bonus_banner := _build_bonus_banner()
	var board_frame := _build_board_frame()

	var board_group := VBoxContainer.new()
	board_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_group.alignment = BoxContainer.ALIGNMENT_CENTER
	board_group.add_theme_constant_override("separation", 8)
	board_group.add_child(bonus_banner)
	board_group.add_child(board_frame)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(score_row)
	column.add_child(board_group)
	add_child(column)

	_build_initial_gems()
	_build_select_ring()
	# Pop the AVOID banner in once layout has run (its size — needed to pivot the pop about its
	# center — is only known after the first layout pass), so the round opens by calling out the
	# gem to steer around.
	call_deferred("_animate_banner_intro")


## Pick the single AVOID gem type for this round (one random color id).
func _choose_avoid_type() -> void:
	_avoid_type = _rng.randi_range(0, GEM_COLORS - 1)


## The live running score readout (refreshed as cascades resolve by _update_score_display), on
## its own centered line under the intro.
func _build_score_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_score_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	row.add_child(_score_label)
	_update_score_display()

	return row


## Build the AVOID banner pinned directly above the grid: an "AVOID" tag next to this round's
## avoid gem, shown large inside a gold-framed panel so the player can see at a glance which gem
## to steer around (matching it is docked −60%; clean matches earn +15%).
func _build_bonus_banner() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	var avoid_tag := Label.new()
	avoid_tag.text = "AVOID"
	avoid_tag.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	avoid_tag.add_theme_color_override("font_color", UiPalette.NAVY)
	avoid_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(avoid_tag)

	_banner_icon = _make_bonus_icon(_avoid_type)
	row.add_child(_banner_icon)

	return row


## A single large AVOID gem tile for the banner: the gem texture centered inside a rounded panel
## with a thick MUSTARD_GOLD border over a dark-gold background, so it reads as a prominent,
## non-interactive "look out for this gem" cue.
func _make_bonus_icon(color_id: int) -> Control:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(BONUS_ICON_SIZE, BONUS_ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	# Dark-gold background derived from the gold border so the panel reads as one gold object.
	box.bg_color = UiPalette.MUSTARD_GOLD.darkened(0.55)
	box.set_corner_radius_all(20)
	box.border_color = UiPalette.MUSTARD_GOLD
	box.set_border_width_all(9)
	icon.add_theme_stylebox_override("panel", box)

	# The gem texture, centered with padding so it sits well inside the gold frame.
	var tex := TextureRect.new()
	tex.texture = GEM_TEXTURE[color_id]
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 24
	tex.offset_top = 24
	tex.offset_right = -24
	tex.offset_bottom = -24
	icon.add_child(tex)

	return icon


## Wrap the playable grid in a thick, dark-gold, rounded frame so the board reads as a framed
## "table" the gems sit on. The grid (_board_area) keeps its own local coordinate space, so the
## drag/swap PITCH math in _on_board_input is unaffected by this wrapper.
func _build_board_frame() -> Control:
	_board_area = Control.new()
	_board_area.custom_minimum_size = Vector2(GRID_WIDTH * PITCH - GAP, GRID_HEIGHT * PITCH - GAP)
	_board_area.clip_contents = true
	_board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_area.gui_input.connect(_on_board_input)

	var frame := PanelContainer.new()
	# Shrink-center so the frame hugs the board's size instead of stretching across the column.
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CREAM
	box.border_color = UiPalette.MUSTARD_GOLD.darkened(0.5)
	box.set_border_width_all(10)
	box.set_corner_radius_all(24)
	# Content margin keeps gems off the border so the rounded corners read cleanly.
	box.content_margin_left = 12
	box.content_margin_top = 12
	box.content_margin_right = 12
	box.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", box)

	frame.add_child(_board_area)
	return frame


## Challenge Mode's high-score metric (see Minigame.get_score): the raw cumulative points scored
## this round, floored to int. Distinct from get_performance()'s normalized [0,1] reward value —
## this just keeps rising as you match, with no cap. `_score` only ever increases, so this is
## naturally cumulative and non-decreasing across a run (the host samples it live each frame).
## Safe to return in both modes; the host only reads it in Challenge Mode.
func get_score() -> int:
	return int(_score)


func get_performance() -> float:
	if _board == null:
		return 0.0
	# Map the running score onto the host's outcome curve with a two-segment curve so Tim's
	# calibration holds at ANY bonus cap:
	#   * 0 .. SCORE_FULL  -> performance 0 .. the host's "full" line (a whole round of ordinary
	#                         clean matching lands right at full = keep 100%).
	#   * SCORE_FULL .. SCORE_MAX -> the full line .. performance 1.0 (strong cascade / large-match
	#                         play climbs into the extra-high band toward the maximum).
	var full_line := _full_line_performance()
	if _score <= SCORE_FULL:
		return full_line * clampf(_score / SCORE_FULL, 0.0, 1.0)
	var into_bonus := clampf((_score - SCORE_FULL) / (SCORE_MAX - SCORE_FULL), 0.0, 1.0)
	return full_line + (1.0 - full_line) * into_bonus


## The performance value at which the host's curve hits exactly 1.0x ("full"), derived from the
## outcome curve the host set before begin(). Anchoring our score-to-performance mapping here is
## what makes "regular clean play = full" true whether the site's bonus cap is 0.25 or 1.0.
func _full_line_performance() -> float:
	var span := (1.0 - outcome_keep_floor) + outcome_bonus_max
	if span <= 0.0:
		return 1.0
	return (1.0 - outcome_keep_floor) / span


## Refresh the live score readout.
func _update_score_display() -> void:
	if _score_label != null:
		_score_label.text = "Score: %d" % int(round(_score))


func is_busy() -> bool:
	return _animating


# ---------------------------------------------------------------------------
# Gem nodes
# ---------------------------------------------------------------------------

func _cell_pos(row: int, col: int) -> Vector2:
	return Vector2(col * PITCH, row * PITCH)


func _make_gem(color_id: int) -> Control:
	# A gem is now its own SVG texture (not a styled panel + symbol). We size the TextureRect to a
	# full cell and center the artwork inside it, keeping aspect so the shapes never distort.
	var gem := TextureRect.new()
	gem.texture = GEM_TEXTURE[color_id]
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.size = Vector2(CELL_SIZE, CELL_SIZE)
	gem.pivot_offset = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.set_meta("color", color_id)

	_style_gem(gem, false)
	return gem


## Show a gem as selected/active during a drag. With textured gems there is no panel stylebox to
## restyle, so we brighten (modulate) and ENLARGE the gem, AND raise its z_index so it lifts above
## its neighbors — the old subtle 1.35×/1.08× alone read weakly on cream (polish pass). The bright
## roving selection RING (see _begin_drag) does most of the "this one is grabbed" work; this just
## makes the grabbed gem itself pop. Alpha stays 1 so we never disturb the clear-fade animation.
func _style_gem(gem: Control, active: bool) -> void:
	if active:
		gem.modulate = Color(1.5, 1.5, 1.5, 1.0)
		gem.scale = Vector2(1.18, 1.18)
		gem.z_index = 2  # above the ring (z 1) and the plain gems (z 0)
	else:
		gem.modulate = Color.WHITE
		gem.scale = Vector2.ONE
		gem.z_index = 0


## Build the roving "selected" ring once: a transparent, thick-bordered rounded square a little
## larger than a cell, hidden until a drag begins. It is positioned over the grabbed gem and
## pulses (in _process) so the selection is unmistakable on the cream board. Kept as a single
## reusable node we move around rather than one ring per cell.
func _build_select_ring() -> void:
	_select_ring = Panel.new()
	var pad := 14.0  # how far the ring sits outside the cell, so it reads as a halo around the gem
	_select_ring.custom_minimum_size = Vector2(CELL_SIZE + pad * 2.0, CELL_SIZE + pad * 2.0)
	_select_ring.size = _select_ring.custom_minimum_size
	_select_ring.pivot_offset = _select_ring.size / 2.0
	_select_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_ring.visible = false

	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = UiPalette.MUSTARD_GOLD
	box.set_border_width_all(7)
	box.set_corner_radius_all(18)
	_select_ring.add_theme_stylebox_override("panel", box)
	_board_area.add_child(_select_ring)


## Place and show the selection ring over the cell at (row, col).
func _show_select_ring(row: int, col: int) -> void:
	if _select_ring == null:
		return
	var pad := 14.0
	_select_ring.position = _cell_pos(row, col) - Vector2(pad, pad)
	_select_ring.z_index = 1  # above plain gems, below the lifted grabbed gem (z 2)
	_select_ring.visible = true


func _hide_select_ring() -> void:
	if _select_ring != null:
		_select_ring.visible = false


## Drive the idle pulses (selection ring + AVOID banner) from one accumulated phase, so we never
## leak a per-frame tween for a continuous effect (polish-pass rule). Guarded so it is a no-op
## before begin() builds these nodes.
func _process(delta: float) -> void:
	_pulse_phase += delta
	if _select_ring != null and _select_ring.visible:
		# A gentle breathing pulse so the grabbed cell clearly "lives".
		var ring_pulse := 1.0 + 0.07 * sin(_pulse_phase * 6.0)
		_select_ring.pivot_offset = _select_ring.size / 2.0
		_select_ring.scale = Vector2(ring_pulse, ring_pulse)
	if _banner_icon != null and _banner_ready:
		# A small continuous pulse keeps the "steer around this" gem drawing the eye.
		var banner_pulse := 1.0 + 0.04 * sin(_pulse_phase * 2.5)
		_banner_icon.pivot_offset = _banner_icon.size / 2.0
		_banner_icon.scale = Vector2(banner_pulse, banner_pulse)


## Pop the AVOID banner in on round start: a scale bloom from small + a brief white-to-normal flash,
## so the round opens by announcing the gem to avoid. Sets _banner_ready when done so the idle
## pulse takes over without fighting this tween.
func _animate_banner_intro() -> void:
	if _banner_icon == null:
		return
	_banner_icon.pivot_offset = _banner_icon.size / 2.0
	_banner_icon.scale = Vector2(0.5, 0.5)
	_banner_icon.modulate = Color(1.6, 1.6, 1.6, 1.0)  # a bright flash that settles to normal
	var intro := create_tween().set_parallel(true)
	intro.tween_property(_banner_icon, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_banner_icon, "modulate", Color.WHITE, 0.45)
	intro.chain().tween_callback(func() -> void: _banner_ready = true)


func _build_initial_gems() -> void:
	_gem_nodes = []
	for row in range(GRID_HEIGHT):
		var row_nodes: Array = []
		for col in range(GRID_WIDTH):
			var gem := _make_gem(_board.color_at(row, col))
			gem.position = _cell_pos(row, col)
			_board_area.add_child(gem)
			row_nodes.append(gem)
		_gem_nodes.append(row_nodes)


# ---------------------------------------------------------------------------
# Input — drag a gem toward a neighbor to swap them
# ---------------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	if _animating or _finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_cancel_drag()
	elif event is InputEventMouseMotion and _dragging:
		_continue_drag(event.position)


func _begin_drag(local: Vector2) -> void:
	var col := int(local.x / PITCH)
	var row := int(local.y / PITCH)
	if row < 0 or row >= GRID_HEIGHT or col < 0 or col >= GRID_WIDTH:
		return
	_dragging = true
	_drag_row = row
	_drag_col = col
	_drag_press_pos = local
	_style_gem(_gem_nodes[row][col], true)
	_show_select_ring(row, col)


func _continue_drag(local: Vector2) -> void:
	var delta := local - _drag_press_pos
	if delta.length() < DRAG_THRESHOLD:
		return
	var d_col := 0
	var d_row := 0
	if absf(delta.x) > absf(delta.y):
		d_col = 1 if delta.x > 0.0 else -1
	else:
		d_row = 1 if delta.y > 0.0 else -1
	var target_row := _drag_row + d_row
	var target_col := _drag_col + d_col

	_style_gem(_gem_nodes[_drag_row][_drag_col], false)
	_hide_select_ring()
	var from_row := _drag_row
	var from_col := _drag_col
	_dragging = false
	_drag_row = -1
	_drag_col = -1

	if target_row < 0 or target_row >= GRID_HEIGHT or target_col < 0 or target_col >= GRID_WIDTH:
		return
	var result: Dictionary = _board.resolve_swap(from_row, from_col, target_row, target_col)
	_play_resolution(result)


func _cancel_drag() -> void:
	if _dragging and _drag_row >= 0:
		_style_gem(_gem_nodes[_drag_row][_drag_col], false)
	_hide_select_ring()
	_dragging = false
	_drag_row = -1
	_drag_col = -1


# ---------------------------------------------------------------------------
# Animation — replay the board's recorded resolution steps
# ---------------------------------------------------------------------------

func _play_resolution(result: Dictionary) -> void:
	_animating = true

	var a: Array = result["swap"]["a"]
	var b: Array = result["swap"]["b"]
	var node_a: Control = _gem_nodes[a[0]][a[1]]
	var node_b: Control = _gem_nodes[b[0]][b[1]]

	var swap_tween := create_tween().set_parallel(true)
	swap_tween.tween_property(node_a, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
	swap_tween.tween_property(node_b, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
	await swap_tween.finished

	if not result["valid"]:
		var undo := create_tween().set_parallel(true)
		undo.tween_property(node_a, "position", _cell_pos(a[0], a[1]), SWAP_TIME)
		undo.tween_property(node_b, "position", _cell_pos(b[0], b[1]), SWAP_TIME)
		await undo.finished
		_animating = false
		return

	_gem_nodes[a[0]][a[1]] = node_b
	_gem_nodes[b[0]][b[1]] = node_a

	# Score the whole swap up front from the recorded steps (deterministic), but AWARD it step by
	# step as each cascade clears on screen — so the score readout and the host's spectrum bar
	# climb in time with the animation.
	var scoring := _score_swap(result)
	var step_points: Array = scoring["step_points"]
	if scoring["matched_avoid"]:
		_matched_avoid_gem = true

	for i in range(result["steps"].size()):
		await _animate_step(result["steps"][i], float(step_points[i]), i)

	# Celebrate hitting the max-bonus line BEFORE clearing _animating, so is_busy() keeps the host's
	# countdown paused through the celebration (otherwise the host would end the round mid-burst).
	# Challenge Mode has NO max-bonus line and never ends on score, so we skip the celebration there —
	# otherwise it would fire on every swap once the score passed SCORE_MAX. The board keeps
	# cascading and refilling endlessly; only the player tapping DONE stops it.
	if not challenge_mode and not _finished and _score >= SCORE_MAX:
		await _celebrate_max()

	_animating = false
	_maybe_finish_early()


## End the round the instant the score reaches the max-bonus line (SCORE_MAX -> performance 1.0).
## Since the score can only rise, no further play could change the outcome, so there's no reason to
## keep the player matching — we emit `completed` with the final performance and the host ends the
## round (its countdown would otherwise be the only thing stopping play). Called after a swap fully
## resolves, so the score readout and spectrum bar have already climbed to the top on screen.
func _maybe_finish_early() -> void:
	# Challenge Mode runs ENDLESSLY: never self-complete, ignore the SCORE_MAX end condition, and let
	# the board keep matching/cascading/refilling forever. Mistakes don't stop play (a miss just
	# doesn't score). The player plays until they tap DONE, so we return before ever emitting.
	if challenge_mode:
		return
	if _finished:
		return
	if _score >= SCORE_MAX:
		_finished = true
		completed.emit(get_performance())


## Compute a swap's earnings from the board's recorded resolution steps. Returns the points to
## award for each cascade step plus whether the swap matched the avoid gem anywhere:
##   { "step_points": Array[float], "matched_avoid": bool }
## Each match GROUP is scored on its own: a clean group (no avoid gem) earns +15%, a group that
## contains the avoid gem is docked −60%. The groups' points are summed per step, then the step's
## rising COMBO multiplier is applied.
func _score_swap(result: Dictionary) -> Dictionary:
	var steps: Array = result["steps"]
	var matched_avoid := false
	var step_points: Array = []

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		# Build a quick cell -> color lookup for this step so we can tell each group's color. Every
		# cell in a match GROUP is the same color (a group is one straight line), so one lookup per
		# group is enough. cleared_colors is aligned with cleared (same order) by the board.
		var color_of_cell := {}
		var cleared: Array = step["cleared"]
		var cleared_colors: Array = step["cleared_colors"]
		for j in range(cleared.size()):
			var cell: Array = cleared[j]
			color_of_cell[cell[0] * GRID_WIDTH + cell[1]] = cleared_colors[j]

		# Combo: each successive cascade step in this swap multiplies its points (step 0 = ×1).
		var combo_multiplier := 1.0 + COMBO_BONUS * float(i)
		var step_raw := 0.0
		for group in step["matches"]:
			var cells: Array = group
			var n: int = cells.size()
			# Bigger lines score more per gem (see SIZE_BONUS).
			var group_points := POINTS_PER_GEM * float(n) * (1.0 + SIZE_BONUS * float(n - 3))
			# Find this group's color from any of its cells, then apply the clean/avoid factor.
			var first_cell: Array = cells[0]
			var group_color: int = color_of_cell[first_cell[0] * GRID_WIDTH + first_cell[1]]
			if group_color == _avoid_type:
				group_points *= AVOID_MATCH_FACTOR
				matched_avoid = true
			else:
				group_points *= CLEAN_MATCH_FACTOR
			step_raw += group_points
		step_points.append(step_raw * combo_multiplier)

	return {"step_points": step_points, "matched_avoid": matched_avoid}


func _animate_step(step: Dictionary, points: float, step_index: int) -> void:
	for group in step["matches"]:
		_spawn_match_badge(group)
	# A cascade step (step_index >= 1) is a chain reaction off the same swap — call it out with a
	# rising "COMBO ×N" flourish so the player SEES the chain paying off (the combo was invisible
	# before). step_index 0 is the initial match, so the first cascade is ×2.
	if step_index >= 1:
		_spawn_combo_flourish(step, step_index)
	# Cascades also flash BIGGER, so a deep chain reads as more energetic as it climbs.
	var flash_scale := 1.25 + 0.08 * float(step_index)
	var flash := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			flash.tween_property(gem, "scale", Vector2(flash_scale, flash_scale), FLASH_TIME)
	await flash.finished

	var clear := create_tween().set_parallel(true)
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			clear.tween_property(gem, "scale", Vector2.ZERO, CLEAR_TIME)
			clear.tween_property(gem, "modulate:a", 0.0, CLEAR_TIME)
	await clear.finished
	# Free the cleared gems and award this cascade step's points NOW, as the gems vanish — so the
	# score (and the host's spectrum bar) climbs step by step through a cascade.
	for cell in step["cleared"]:
		var gem: Control = _gem_nodes[cell[0]][cell[1]]
		if gem != null:
			gem.queue_free()
		_gem_nodes[cell[0]][cell[1]] = null
	_score += points
	_update_score_display()

	var drop := create_tween().set_parallel(true)
	_apply_falls(step["falls"], drop)
	_apply_spawns(step["spawns"], drop)
	await drop.finished


func _apply_falls(falls: Array, drop: Tween) -> void:
	var captured: Array = []  # [target_row, col, node]
	for fall in falls:
		var col: int = fall["col"]
		captured.append([fall["to_r"], col, _gem_nodes[fall["from_r"]][col]])
	for fall in falls:
		_gem_nodes[fall["from_r"]][fall["col"]] = null
	for entry in captured:
		var to_r: int = entry[0]
		var col: int = entry[1]
		var node: Control = entry[2]
		_gem_nodes[to_r][col] = node
		drop.tween_property(node, "position", _cell_pos(to_r, col), FALL_TIME)


func _apply_spawns(spawns: Array, drop: Tween) -> void:
	var per_col: Dictionary = {}
	for spawn in spawns:
		var col: int = spawn["col"]
		per_col[col] = int(per_col.get(col, 0)) + 1
	for spawn in spawns:
		var col: int = spawn["col"]
		var to_r: int = spawn["to_r"]
		var gem := _make_gem(spawn["color"])
		gem.position = _cell_pos(to_r - int(per_col[col]), col)
		_board_area.add_child(gem)
		_gem_nodes[to_r][col] = gem
		drop.tween_property(gem, "position", _cell_pos(to_r, col), FALL_TIME)


func _spawn_match_badge(group: Array) -> void:
	if group.is_empty():
		return
	var sum := Vector2.ZERO
	for cell in group:
		sum += _cell_pos(cell[0], cell[1])
	var center: Vector2 = sum / float(group.size()) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0

	var badge := Label.new()
	badge.text = str(group.size())
	badge.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	badge.add_theme_color_override("font_color", UiPalette.CREAM)
	badge.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	badge.add_theme_constant_override("outline_size", 6)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = center - Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	badge.size = Vector2(CELL_SIZE, CELL_SIZE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_area.add_child(badge)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(badge, "position:y", badge.position.y - 36.0, FLASH_TIME + CLEAR_TIME)
	tween.tween_property(badge, "modulate:a", 0.0, FLASH_TIME + CLEAR_TIME)
	tween.chain().tween_callback(badge.queue_free)


## A cascade chain signal: a teal "COMBO ×N" label that blooms up and fades over the cells a
## cascade step just cleared, so a chain reaction reads as a building combo rather than gems quietly
## vanishing. N is the step's combo multiplier (step_index 1 -> ×2, etc.), matching _score_swap.
func _spawn_combo_flourish(step: Dictionary, step_index: int) -> void:
	var cleared: Array = step["cleared"]
	if cleared.is_empty():
		return
	# Center the flourish on the average of the cleared cells, in board-local coordinates.
	var sum := Vector2.ZERO
	for cell in cleared:
		sum += _cell_pos(cell[0], cell[1])
	var center: Vector2 = sum / float(cleared.size()) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0

	var label := Label.new()
	label.text = "COMBO ×%d" % (step_index + 1)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
	label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(CELL_SIZE * 3.0, CELL_SIZE)
	label.position = center - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	label.z_index = 3  # above gems and the selection ring
	label.scale = Vector2(0.6, 0.6)
	_board_area.add_child(label)

	var bloom := create_tween().set_parallel(true)
	bloom.tween_property(label, "scale", Vector2(1.15, 1.15), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bloom.tween_property(label, "position:y", label.position.y - 48.0, 0.55)
	bloom.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	bloom.chain().tween_callback(label.queue_free)


## The max-bonus celebration: when the score reaches SCORE_MAX (performance 1.0, the best possible
## result) the round used to just end. Now it pays off — a white wash sweeps the board and a big
## "MAXED OUT!" label blooms — before the host shows the result. Kept brief; the caller holds
## is_busy() true across this await so the countdown stays paused.
func _celebrate_max() -> void:
	# A white flash over the whole board.
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 4
	_board_area.add_child(flash)

	var banner := Label.new()
	banner.text = "MAXED OUT!"
	banner.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	banner.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	banner.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	banner.add_theme_constant_override("outline_size", 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.size = _board_area.size
	banner.pivot_offset = banner.size / 2.0
	banner.z_index = 5
	banner.scale = Vector2(0.5, 0.5)
	_board_area.add_child(banner)

	var celebrate := create_tween().set_parallel(true)
	celebrate.tween_property(flash, "color", Color(1, 1, 1, 0.7), 0.12)
	celebrate.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.45).set_delay(0.12)
	celebrate.tween_property(banner, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	celebrate.tween_property(banner, "modulate:a", 0.0, 0.3).set_delay(0.4)
	await celebrate.finished
	flash.queue_free()
	banner.queue_free()


func result_summary() -> String:
	var line := "Scored %d points" % int(round(_score))
	if _matched_avoid_gem:
		line += " — watch out for the AVOID gem next time!"
	else:
		line += " — clean matching, nicely done!"
	return line
