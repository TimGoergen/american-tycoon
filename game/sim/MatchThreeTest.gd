extends SceneTree

# Headless verification for MatchThreeBoard (pure-logic match-3 board).
#
# Usage: godot --headless --script res://sim/MatchThreeTest.gd
#
# We load the board by PATH via preload rather than by its global class_name. A
# freshly-created class_name isn't in Godot's global class cache until a full editor
# import (which we deliberately avoid, since that rewrites project.godot); preload
# resolves by path and works in a bare headless run.
const Board = preload("res://scripts/core/MatchThreeBoard.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	print("=== MatchThreeBoard — headless verification ===\n")

	_test_no_initial_matches()
	_test_color_at_bounds()
	_test_is_adjacent()
	_test_swap_no_match_unchanged()
	_test_known_swap_scores()
	_test_grid_stays_valid_after_random_swaps()
	_test_resolve_swap_steps_reproduce_grid()
	_test_special_color()
	_test_match_group_merge()

	print("")
	if _failures == 0:
		print("ALL TESTS PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("FAILURES: %d of %d checks failed" % [_failures, _checks])
		quit(1)


# ---------------------------------------------------------------------------
# Tiny assertion helpers
# ---------------------------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		print("  FAIL: %s" % label)


# Return true if the board currently has any 3+ in-a-row match (used to assert a
# freshly built board starts clean). Mirrors the board's own match rule.
func _board_has_any_match(board) -> bool:
	for row in range(board.height):
		for col in range(board.width):
			var color: int = board.color_at(row, col)
			# Horizontal triple starting here.
			if col + 2 < board.width:
				if board.color_at(row, col + 1) == color and board.color_at(row, col + 2) == color:
					return true
			# Vertical triple starting here.
			if row + 2 < board.height:
				if board.color_at(row + 1, col) == color and board.color_at(row + 2, col) == color:
					return true
	return false


# ---------------------------------------------------------------------------
# (a) A freshly built (seeded) board has NO initial matches.
# ---------------------------------------------------------------------------

func _test_no_initial_matches() -> void:
	print("[a] No initial matches on a freshly built board")
	# Several seeds and sizes, so we aren't trusting a single lucky build.
	for seed_value in [1, 42, 1337, 99999]:
		var board = Board.new(8, 8, 5, seed_value)
		_check(not _board_has_any_match(board), "seed %d builds with no pre-existing match" % seed_value)


# ---------------------------------------------------------------------------
# (b) color_at out of bounds returns -1.
# ---------------------------------------------------------------------------

func _test_color_at_bounds() -> void:
	print("[b] color_at out-of-bounds returns -1")
	var board = Board.new(6, 6, 5, 7)
	_check(board.color_at(-1, 0) == -1, "negative row -> -1")
	_check(board.color_at(0, -1) == -1, "negative col -> -1")
	_check(board.color_at(6, 0) == -1, "row == height -> -1")
	_check(board.color_at(0, 6) == -1, "col == width -> -1")
	var in_range_color := board.color_at(0, 0)
	_check(in_range_color >= 0 and in_range_color < board.num_colors, "in-bounds returns a valid color")


# ---------------------------------------------------------------------------
# (c) is_adjacent correctness.
# ---------------------------------------------------------------------------

func _test_is_adjacent() -> void:
	print("[c] is_adjacent correctness")
	var board = Board.new(6, 6, 5, 7)
	_check(board.is_adjacent(2, 2, 2, 3), "horizontal neighbor is adjacent")
	_check(board.is_adjacent(2, 2, 3, 2), "vertical neighbor is adjacent")
	_check(not board.is_adjacent(2, 2, 3, 3), "diagonal is NOT adjacent")
	_check(not board.is_adjacent(2, 2, 2, 2), "same cell is NOT adjacent")
	_check(not board.is_adjacent(0, 0, 5, 5), "far cells are NOT adjacent")
	_check(not board.is_adjacent(0, 0, 0, -1), "out-of-bounds neighbor is NOT adjacent")


# ---------------------------------------------------------------------------
# (d) A swap that makes no match returns 0 and leaves the grid identical.
# ---------------------------------------------------------------------------

func _test_swap_no_match_unchanged() -> void:
	print("[d] Swap with no resulting match returns 0 and leaves grid unchanged")
	var board = Board.new(6, 6, 5, 7)

	# Hand-build a tiny region we KNOW won't form a match when two cells swap. With
	# distinct colors arranged so no triple appears either way, the swap must be rejected.
	# We overwrite the whole grid with a checkerboard of two colors offset so swapping
	# any single adjacent pair never makes three-in-a-row.
	for row in range(board.height):
		for col in range(board.width):
			# Three-color diagonal stripe: color = (row + col) % 3. No two orthogonal
			# neighbors share a color, so no swap of adjacent cells can build a triple.
			board.grid[row][col] = (row + col) % 3

	var snapshot := _copy_grid(board.grid)
	var score_before: int = board.score
	var result: int = board.try_swap(2, 2, 2, 3)

	_check(result == 0, "no-match swap returns 0")
	_check(board.score == score_before, "score unchanged after no-match swap")
	_check(_grids_equal(board.grid, snapshot), "grid identical after no-match swap")

	# Non-adjacent swap also returns 0 and changes nothing.
	var result_far: int = board.try_swap(0, 0, 5, 5)
	_check(result_far == 0, "non-adjacent swap returns 0")
	_check(_grids_equal(board.grid, snapshot), "grid identical after non-adjacent swap")


# ---------------------------------------------------------------------------
# (e) A known small board guarantees a match on a specific swap.
# ---------------------------------------------------------------------------

func _test_known_swap_scores() -> void:
	print("[e] Known board state: a specific swap scores and raises score")
	var board = Board.new(5, 5, 5, 7)

	# Verified-by-hand layout with NO pre-existing match. Two 0s sit stacked in column 0
	# (rows 2 and 3) and a third 0 sits one cell away at (4,1). Swapping (4,0) and (4,1)
	# drops that 0 into column 0, making rows 2,3,4 all color 0 (a vertical triple), so
	# the swap is legal and must score.
	#
	#   col:    0  1  2  3  4
	#   row 0:  1  2  1  2  1
	#   row 1:  2  1  2  1  2
	#   row 2:  0  1  2  1  2
	#   row 3:  0  2  1  2  1
	#   row 4:  1  0  2  1  2   (after swap, column 0 reads 1,2,0,0,0)
	var layout := [
		[1, 2, 1, 2, 1],
		[2, 1, 2, 1, 2],
		[0, 1, 2, 1, 2],
		[0, 2, 1, 2, 1],
		[1, 0, 2, 1, 2],
	]

	_apply_layout(board, layout)
	_check(not _board_has_any_match(board), "[e] planted layout has no pre-existing match")

	var score_before: int = board.score
	var cleared: int = board.try_swap(4, 0, 4, 1)
	_check(cleared > 0, "match-making swap returns > 0 (got %d)" % cleared)
	_check(board.score == score_before + cleared, "score increases by exactly the cleared count")
	# Board must be stable (no leftover matches) after resolution.
	_check(not _board_has_any_match(board), "board is stable (no matches) after resolution")
	# Grid dimensions intact and all colors valid after the cascade.
	_check(_grid_is_valid(board), "grid remains valid after resolution")


# ---------------------------------------------------------------------------
# (f) After many random try_swap calls, the grid stays valid.
# ---------------------------------------------------------------------------

func _test_grid_stays_valid_after_random_swaps() -> void:
	print("[f] Grid stays valid after many random swaps")
	var board = Board.new(8, 8, 6, 2024)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555

	var total_returned := 0
	for _i in range(500):
		var row := rng.randi_range(0, board.height - 1)
		var col := rng.randi_range(0, board.width - 1)
		# Pick a random orthogonal direction for the partner cell.
		var directions := [[0, 1], [0, -1], [1, 0], [-1, 0]]
		var dir = directions[rng.randi_range(0, 3)]
		total_returned += board.try_swap(row, col, row + dir[0], col + dir[1])

	_check(_grid_is_valid(board), "all colors in range and dimensions intact after 500 swaps")
	_check(board.score == total_returned, "score equals the sum of all try_swap returns")
	_check(not _board_has_any_match(board), "board is stable after the random-swap run")


# ---------------------------------------------------------------------------
# Shared helpers for tests
# ---------------------------------------------------------------------------

# Overwrite a board's grid with an explicit layout[row][col].
func _apply_layout(board, layout: Array) -> void:
	for row in range(board.height):
		for col in range(board.width):
			board.grid[row][col] = layout[row][col]


func _copy_grid(source: Array) -> Array:
	var copy: Array = []
	for row in source:
		copy.append(row.duplicate())
	return copy


func _grids_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for row in range(a.size()):
		if a[row].size() != b[row].size():
			return false
		for col in range(a[row].size()):
			if a[row][col] != b[row][col]:
				return false
	return true


# True if the board has its declared dimensions and every cell holds a valid color.
func _grid_is_valid(board) -> bool:
	if board.grid.size() != board.height:
		return false
	for row in range(board.height):
		if board.grid[row].size() != board.width:
			return false
		for col in range(board.width):
			var color: int = board.grid[row][col]
			if color < 0 or color >= board.num_colors:
				return false
	return true


## The animation contract: applying a resolve_swap result's recorded steps
## (clear → falls → spawns) to the post-swap grid must reproduce the board's final grid
## exactly. If this holds, the animated screen and the headless board can never desync.
func _test_resolve_swap_steps_reproduce_grid() -> void:
	var w := 6
	var h := 6
	var colors := 5
	var base := Board.new(w, h, colors, 4242)
	var original: Array = base.grid.duplicate(true)

	# Find an adjacent pair whose swap is valid (creates a match), probing on throwaway
	# copies so the search itself doesn't disturb the board we measure.
	var found := false
	var pa := [0, 0]
	var pb := [0, 0]
	for r in range(h):
		for c in range(w):
			for nb in [[r, c + 1], [r + 1, c]]:
				if nb[0] >= h or nb[1] >= w:
					continue
				var probe := Board.new(w, h, colors, 1)
				probe.grid = original.duplicate(true)
				if probe.try_swap(r, c, nb[0], nb[1]) > 0:
					pa = [r, c]
					pb = nb
					found = true
					break
			if found:
				break
		if found:
			break
	_check(found, "found a valid swap to resolve")
	if not found:
		return

	var real := Board.new(w, h, colors, 7)
	real.grid = original.duplicate(true)

	# Reconstruct the resolution by hand on `sim`, starting from the post-swap grid.
	var sim: Array = original.duplicate(true)
	var tmp: int = sim[pa[0]][pa[1]]
	sim[pa[0]][pa[1]] = sim[pb[0]][pb[1]]
	sim[pb[0]][pb[1]] = tmp

	var result: Dictionary = real.resolve_swap(pa[0], pa[1], pb[0], pb[1])
	_check(result["valid"], "resolve_swap reports valid")

	var sum_cleared := 0
	var colors_ok := true
	for step in result["steps"]:
		# cleared_colors must run parallel to cleared (same length) and hold the color that each
		# cleared cell had at clear time — a scoring UI relies on this pairing.
		if step["cleared_colors"].size() != step["cleared"].size():
			colors_ok = false
		for i in range(step["cleared"].size()):
			var cell: Array = step["cleared"][i]
			if step["cleared_colors"][i] != sim[cell[0]][cell[1]]:
				colors_ok = false
		for cell in step["cleared"]:
			sim[cell[0]][cell[1]] = -1
		sum_cleared += step["cleared"].size()
		# Falls: capture every source first, then write targets (handles fall-into-vacated).
		var captured: Array = []
		for f in step["falls"]:
			captured.append([f["to_r"], f["col"], sim[f["from_r"]][f["col"]]])
		for f in step["falls"]:
			sim[f["from_r"]][f["col"]] = -1
		for e in captured:
			sim[e[0]][e[1]] = e[2]
		for s in step["spawns"]:
			sim[s["to_r"]][s["col"]] = s["color"]

	var reproduced := true
	for r in range(h):
		for c in range(w):
			if sim[r][c] != real.grid[r][c]:
				reproduced = false
	_check(reproduced, "applying recorded steps reproduces the final grid")
	_check(sum_cleared == int(result["cleared_total"]), "step clears sum to cleared_total")
	_check(colors_ok, "cleared_colors run parallel to cleared and match the pre-clear grid")


# ---------------------------------------------------------------------------
# (g) Special (Legacy) color: never in the starting grid, spawns only at its weight, and a big
#     match force-spawns exactly one (via the refill's force_special count). Covers the Legacy mechanic.
# ---------------------------------------------------------------------------

func _test_special_color() -> void:
	print("[g] Special (Legacy) color spawn rules")
	# num_colors 5, special = id 4. The special color never seeds the starting grid AND never appears
	# in an ordinary refill — it is created only by a 5+ match. Check the starting grid across seeds,
	# then run many random swaps and confirm the only special gems on the board came from 5+ matches
	# (i.e. via a recorded legacy_placement, exercised in the placement tests below).
	var special := 4
	var starting_clean := true
	for seed_value in [1, 7, 42, 1000, 54321]:
		var board = Board.new(7, 6, 5, seed_value, special)
		for row in range(board.height):
			for col in range(board.width):
				if board.color_at(row, col) == special:
					starting_clean = false
	_check(starting_clean, "special color never seeds the starting grid")

	# Ordinary refills never produce the special color: _regular_color (used by every refill) skips it.
	var refill_board = Board.new(8, 8, 5, 123, special)
	var saw_special := false
	for _i in range(3000):
		if refill_board._regular_color() == special:
			saw_special = true
	_check(not saw_special, "ordinary refills never produce the special color")

	# A match of 5+ places a Legacy gem at the swap TARGET cell (r2,c2); a match of exactly 4 does
	# NOT, and neither does a 5+ match of the AVOID color (Tim, 2026-07-09). Build a checkerboard (no
	# pre-existing matches, colors 0/1) with two pairs of color 2 straddling a gap, then swap a 2 up
	# into the gap to complete a straight run.
	var five = Board.new(6, 6, 5, 55, special)
	_fill_checkerboard(five)
	# [2,2,_,2,2] across row 2 → the swap makes a run of FIVE.
	five.grid[2][0] = 2; five.grid[2][1] = 2; five.grid[2][3] = 2; five.grid[2][4] = 2
	five.grid[3][2] = 2  # the gem swapped up into (2,2)
	var five_res: Dictionary = five.resolve_swap(2, 2, 3, 2)
	_check(five_res["valid"] and five_res.has("legacy_placement")
			and five_res["legacy_placement"] == [3, 2] and five.color_at(3, 2) == special,
			"a 5-match places a Legacy gem at the target cell")

	var four = Board.new(6, 6, 5, 55, special)
	_fill_checkerboard(four)
	# [2,2,_,2] across row 2 → the swap makes a run of exactly FOUR (col 4 stays a checkerboard gem).
	four.grid[2][0] = 2; four.grid[2][1] = 2; four.grid[2][3] = 2
	four.grid[3][2] = 2
	var four_res: Dictionary = four.resolve_swap(2, 2, 3, 2)
	_check(four_res["valid"] and not four_res.has("legacy_placement"),
			"a 4-match does NOT place a Legacy gem (default match size 5)")

	# The match size is tunable: drop it to 4 and the same 4-match now DOES place a Legacy gem.
	var four_lowered = Board.new(6, 6, 5, 55, special)
	_fill_checkerboard(four_lowered)
	four_lowered.special_match_size = 4
	four_lowered.grid[2][0] = 2; four_lowered.grid[2][1] = 2; four_lowered.grid[2][3] = 2
	four_lowered.grid[3][2] = 2
	var fl_res: Dictionary = four_lowered.resolve_swap(2, 2, 3, 2)
	_check(fl_res["valid"] and fl_res.has("legacy_placement") and fl_res["legacy_placement"] == [3, 2],
			"with match size 4, a 4-match DOES place a Legacy gem")

	# A 5+ match of the EXCLUDED color (the AVOID gem) must NOT qualify for a Legacy gem. We check the
	# qualifying rule directly on _find_match_groups (rather than via resolve_swap, whose refill
	# cascade could form an unrelated qualifying merge and confuse the assertion): the excluded run is
	# present as a size-5 group, but its color equals special_exclude_color, so it does not qualify.
	var avoidb = Board.new(6, 6, 5, 55, special)
	_fill_checkerboard(avoidb)
	avoidb.special_exclude_color = 2
	avoidb.grid[2][0] = 2; avoidb.grid[2][1] = 2; avoidb.grid[2][2] = 2; avoidb.grid[2][3] = 2; avoidb.grid[2][4] = 2
	var avoid_groups: Array = avoidb._find_match_groups()
	var any_qualifies := false
	for g in avoid_groups:
		var gc: int = avoidb.color_at(g[0][0], g[0][1])
		if (g as Array).size() >= 5 and gc != special and gc != avoidb.special_exclude_color:
			any_qualifies = true
	_check(avoid_groups.size() == 1 and not any_qualifies,
			"a 5-match of the avoid color does NOT qualify for a Legacy gem")


# ---------------------------------------------------------------------------
# (h) Intersecting same-color runs merge into ONE group; non-touching runs stay separate.
# ---------------------------------------------------------------------------

func _test_match_group_merge() -> void:
	print("[h] Intersecting same-color runs merge into one group")
	# An L of color 2: horizontal (2,0..2) + vertical (2,2),(3,2),(4,2), sharing (2,2) → 5 cells, one group.
	var b = Board.new(6, 6, 4, 11)
	_fill_checkerboard(b)
	b.grid[2][0] = 2; b.grid[2][1] = 2; b.grid[2][2] = 2
	b.grid[3][2] = 2; b.grid[4][2] = 2
	var groups: Array = b._find_match_groups()
	_check(groups.size() == 1, "an L-shape is ONE merged group")
	_check(groups.size() == 1 and (groups[0] as Array).size() == 5, "the merged L group holds all 5 gems")

	# Two 3-runs of the same color that don't touch stay as two separate groups.
	var b2 = Board.new(6, 6, 4, 12)
	_fill_checkerboard(b2)
	b2.grid[0][0] = 2; b2.grid[0][1] = 2; b2.grid[0][2] = 2
	b2.grid[4][0] = 2; b2.grid[4][1] = 2; b2.grid[4][2] = 2
	var groups2: Array = b2._find_match_groups()
	_check(groups2.size() == 2, "two non-touching 3-runs stay as two groups")


## Fill a board with a 0/1 checkerboard — no 3-in-a-row anywhere, so tests can place their own
## setup on top without fighting pre-existing matches.
func _fill_checkerboard(board) -> void:
	for row in range(board.height):
		for col in range(board.width):
			board.grid[row][col] = (row + col) % 2
