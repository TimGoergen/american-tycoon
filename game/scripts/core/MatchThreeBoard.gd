class_name MatchThreeBoard

# Headless, pure-logic match-3 board. No scene-tree or UI dependencies, so it can
# be unit-tested headlessly the same way PropertyState / CostCurve are.
#
# Grid indexing convention: grid[row][col].
#   - The OUTER array has `height` entries, one per row (top row first, row 0).
#   - Each INNER array has `width` entries, one per column (left column first, col 0).
#   - Each cell holds a color id in 0..num_colors-1.
# "Down" (the direction gravity pulls) means toward higher row indices.

var width: int
var height: int
var num_colors: int

## Total gems cleared across the whole game so far (accumulates over every try_swap).
var score: int = 0

## The board itself, indexed grid[row][col]. See the convention note above.
var grid: Array = []

## Seedable RNG stored on the board so the initial build AND all later refills are
## deterministic when a non-zero seed is supplied (tests rely on this). With seed 0
## we randomize() instead, so production games vary run to run.
var _rng: RandomNumberGenerator


# Sentinel used inside the resolve step to mark a cell as "cleared / empty" before
# gravity and refill run. It is never a valid color id (those are 0..num_colors-1),
# so nothing in a finished board can ever equal it.
const _EMPTY: int = -1


func _init(p_width: int, p_height: int, p_num_colors: int, p_seed: int = 0) -> void:
	width = p_width
	height = p_height
	num_colors = p_num_colors

	_rng = RandomNumberGenerator.new()
	if p_seed != 0:
		_rng.seed = p_seed
	else:
		# Production games: no fixed seed, so each run gets a different board.
		_rng.randomize()

	_build_starting_grid()


# ---------------------------------------------------------------------------
# Public queries
# ---------------------------------------------------------------------------

## Color id at (row, col), or -1 if the cell is out of bounds.
func color_at(row: int, col: int) -> int:
	if not _in_bounds(row, col):
		return -1
	return grid[row][col]


## True if the two cells are orthogonally adjacent (share an edge) and both in bounds.
## Diagonal neighbors, the same cell, and far-apart cells all return false.
func is_adjacent(r1: int, c1: int, r2: int, c2: int) -> bool:
	if not _in_bounds(r1, c1) or not _in_bounds(r2, c2):
		return false
	# Orthogonal adjacency: exactly one of the row/col differs, and by exactly one.
	var row_distance := absi(r1 - r2)
	var col_distance := absi(c1 - c2)
	return (row_distance + col_distance) == 1


# ---------------------------------------------------------------------------
# The swap action
# ---------------------------------------------------------------------------

## Attempt to swap two adjacent cells (the headless convenience form). Returns the
## number of gems cleared (0 if the swap makes no match or the cells aren't adjacent).
## Implemented on top of resolve_swap so there is one resolution path.
func try_swap(r1: int, c1: int, r2: int, c2: int) -> int:
	return int(resolve_swap(r1, c1, r2, c2)["cleared_total"])


## Resolve a swap AND record every cascade as an animation step, so a UI can play the
## resolution out (flash the match, clear it, drop survivors, spawn new gems) instead of
## snapping to the final grid. The board still ends in the final stable state, identical
## to try_swap. Returns:
## {
##   "valid": bool,                  # did the swap create at least one match?
##   "swap": { "a": [r1,c1], "b": [r2,c2] },   # the swapped cells (for the swap tween)
##   "cleared_total": int,           # gems cleared (also added to score); 0 if invalid
##   "steps": Array,                 # [] if invalid; one entry per cascade iteration:
##     {
##       "matches": Array,           #   groups: each an Array of [row,col] forming one
##                                   #     3+ line (lets the UI show match size / shape)
##       "cleared": Array,           #   flat, de-duplicated [row,col] cells removed
##       "falls":   Array,           #   { "col", "from_r", "to_r" } survivors that dropped
##       "spawns":  Array,           #   { "col", "to_r", "color" } new gems filling the top
##     }
## }
## Invariant the UI relies on: applying every step's clear→falls→spawns to the
## post-swap grid reproduces the board's final `grid` exactly.
func resolve_swap(r1: int, c1: int, r2: int, c2: int) -> Dictionary:
	var result := {
		"valid": false,
		"swap": {"a": [r1, c1], "b": [r2, c2]},
		"cleared_total": 0,
		"steps": [],
	}
	if not is_adjacent(r1, c1, r2, c2):
		return result

	_swap_cells(r1, c1, r2, c2)

	# Only a swap that creates at least one match is legal; otherwise undo it.
	if _find_match_groups().is_empty():
		_swap_cells(r1, c1, r2, c2)  # swap back — board is exactly as it started
		return result

	result["valid"] = true
	var steps: Array = []
	var total_cleared := 0
	# Each loop is one cascade: find the matches now on the board, clear+collapse+refill,
	# record what moved. Repeat until no matches remain.
	while true:
		var groups := _find_match_groups()
		if groups.is_empty():
			break
		var cleared := _union_cells(groups)
		total_cleared += cleared.size()
		var moves := _clear_collapse_refill_recorded(cleared)
		steps.append({
			"matches": groups,
			"cleared": cleared,
			"falls": moves["falls"],
			"spawns": moves["spawns"],
		})

	score += total_cleared
	result["steps"] = steps
	result["cleared_total"] = total_cleared
	return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < height and col >= 0 and col < width


## Swap the colors of two cells in place.
func _swap_cells(r1: int, c1: int, r2: int, c2: int) -> void:
	var temp: int = grid[r1][c1]
	grid[r1][c1] = grid[r2][c2]
	grid[r2][c2] = temp


## Fill `grid` with random colors but with NO pre-existing matches: no 3-in-a-row
## horizontally or vertically anywhere in the starting board. We fill top-to-bottom,
## left-to-right, and when choosing each cell's color we reject any choice that would
## complete a run of three with the two cells already placed to its LEFT or ABOVE.
## Because we only ever look backward at already-final cells, one pass is enough.
func _build_starting_grid() -> void:
	grid = []
	for row in range(height):
		var row_cells: Array = []
		for col in range(width):
			row_cells.append(_pick_color_without_match(grid, row_cells, row, col))
		grid.append(row_cells)


## Pick a random color for (row, col) that does not complete a 3-in-a-row with the
## two already-placed cells to its left (same row) or above (same column).
## `placed_grid` holds the finished rows above; `current_row` holds the cells already
## placed to the left in this row (it isn't appended to `placed_grid` until complete).
func _pick_color_without_match(
		placed_grid: Array, current_row: Array, row: int, col: int
) -> int:
	# Color of the two cells immediately to the left (or -1 if off the edge).
	var left1: int = current_row[col - 1] if col >= 1 else -1
	var left2: int = current_row[col - 2] if col >= 2 else -1
	# Color of the two cells immediately above (or -1 if off the edge).
	var up1: int = placed_grid[row - 1][col] if row >= 1 else -1
	var up2: int = placed_grid[row - 2][col] if row >= 2 else -1

	# Try colors until one doesn't extend an existing pair into a triple. With at most
	# two forbidden colors (one horizontal, one vertical) and num_colors >= 3 there is
	# always a valid choice, but we cap the attempts defensively to avoid any chance of
	# an infinite loop on a degenerate (num_colors < 3) configuration.
	for _attempt in range(100):
		var candidate := _rng.randi_range(0, num_colors - 1)
		var makes_horizontal_run: bool = (candidate == left1 and candidate == left2)
		var makes_vertical_run: bool = (candidate == up1 and candidate == up2)
		if not makes_horizontal_run and not makes_vertical_run:
			return candidate

	# Degenerate fallback (should not happen with num_colors >= 3): accept any color.
	return _rng.randi_range(0, num_colors - 1)


## Return every current match as a list of GROUPS, where each group is one maximal line
## (3+ same color, horizontal or vertical) as an Array of [row, col]. A cell at the
## crossing of a horizontal and a vertical match appears in both groups; the caller
## de-duplicates with _union_cells when it needs the flat set of cleared cells. Empty if
## the board has no matches. Keeping groups (not just cells) lets the UI show match size.
func _find_match_groups() -> Array:
	var groups: Array = []

	# Horizontal runs: scan each row for stretches of 3+ equal colors.
	for row in range(height):
		var run_start := 0
		while run_start < width:
			var run_end := run_start
			while run_end + 1 < width and grid[row][run_end + 1] == grid[row][run_start]:
				run_end += 1
			if run_end - run_start + 1 >= 3:
				var group: Array = []
				for col in range(run_start, run_end + 1):
					group.append([row, col])
				groups.append(group)
			run_start = run_end + 1

	# Vertical runs: scan each column for stretches of 3+ equal colors.
	for col in range(width):
		var run_start := 0
		while run_start < height:
			var run_end := run_start
			while run_end + 1 < height and grid[run_end + 1][col] == grid[run_start][col]:
				run_end += 1
			if run_end - run_start + 1 >= 3:
				var group: Array = []
				for row in range(run_start, run_end + 1):
					group.append([row, col])
				groups.append(group)
			run_start = run_end + 1

	return groups


## Flatten match groups into a de-duplicated set of [row, col] cells (a crossing cell
## belongs to two groups but is cleared once).
func _union_cells(groups: Array) -> Array:
	var seen := {}
	var cells: Array = []
	for group in groups:
		for cell in group:
			var key: int = cell[0] * width + cell[1]
			if not seen.has(key):
				seen[key] = true
				cells.append(cell)
	return cells


## Clear the given cells, collapse each column downward (gravity → higher row indices),
## and refill the emptied TOP slots with fresh random colors — recording what moved so a
## UI can animate it. Returns { "falls": [...], "spawns": [...] } where falls lists the
## survivors that changed row and spawns lists the new top gems. The grid ends collapsed.
func _clear_collapse_refill_recorded(cleared: Array) -> Dictionary:
	for cell in cleared:
		grid[cell[0]][cell[1]] = _EMPTY

	var falls: Array = []
	var spawns: Array = []

	for col in range(width):
		# Original rows of the survivors in this column, top to bottom.
		var survivor_rows: Array = []
		for row in range(height):
			if grid[row][col] != _EMPTY:
				survivor_rows.append(row)
		var empty_count := height - survivor_rows.size()

		# Build the column fresh: new gems fill the top `empty_count` rows, survivors drop
		# beneath them keeping order. Write into a temp first so reads of grid stay valid.
		var new_col: Array = []
		new_col.resize(height)
		for row in range(empty_count):
			var color := _rng.randi_range(0, num_colors - 1)
			new_col[row] = color
			spawns.append({"col": col, "to_r": row, "color": color})
		for i in range(survivor_rows.size()):
			var from_r: int = survivor_rows[i]
			var to_r: int = empty_count + i
			new_col[to_r] = grid[from_r][col]
			if from_r != to_r:
				falls.append({"col": col, "from_r": from_r, "to_r": to_r})

		for row in range(height):
			grid[row][col] = new_col[row]

	return {"falls": falls, "spawns": spawns}
