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

## Attempt to swap two adjacent cells.
##  - If the swap produces at least one match (3+ of the same color in a row or
##    column), keep the swap and resolve every match: clear matched cells, collapse
##    columns downward (gravity), refill empties from the top, and repeat for as long
##    as new matches keep appearing (cascades). The total number of gems cleared across
##    ALL cascade steps is added to `score` and returned (always > 0 in this case).
##  - If the swap produces no match, the board is left unchanged and 0 is returned.
##  - If the cells aren't adjacent / in bounds, nothing changes and 0 is returned.
func try_swap(r1: int, c1: int, r2: int, c2: int) -> int:
	if not is_adjacent(r1, c1, r2, c2):
		return 0

	_swap_cells(r1, c1, r2, c2)

	# Only a swap that creates at least one match is legal; otherwise undo it.
	if _find_matched_cells().is_empty():
		_swap_cells(r1, c1, r2, c2)  # swap back — board is exactly as it started
		return 0

	var total_cleared := _resolve_until_stable()
	score += total_cleared
	return total_cleared


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


## Return the set of cells that are part of any current match (3+ same color in a row
## or column), as an Array of [row, col] pairs with no duplicates. Empty if the board
## has no matches. A cell is included once even if it sits at the crossing of both a
## horizontal and a vertical match.
func _find_matched_cells() -> Array:
	# We mark matched cells in a parallel boolean grid first, so a cell counted by both
	# a horizontal and a vertical run is recorded only once, then collect them at the end.
	var matched := []
	for row in range(height):
		var marks: Array = []
		marks.resize(width)
		marks.fill(false)
		matched.append(marks)

	# Horizontal runs: scan each row for stretches of 3+ equal colors.
	for row in range(height):
		var run_start := 0
		while run_start < width:
			var run_end := run_start
			while run_end + 1 < width and grid[row][run_end + 1] == grid[row][run_start]:
				run_end += 1
			if run_end - run_start + 1 >= 3:
				for col in range(run_start, run_end + 1):
					matched[row][col] = true
			run_start = run_end + 1

	# Vertical runs: scan each column for stretches of 3+ equal colors.
	for col in range(width):
		var run_start := 0
		while run_start < height:
			var run_end := run_start
			while run_end + 1 < height and grid[run_end + 1][col] == grid[run_start][col]:
				run_end += 1
			if run_end - run_start + 1 >= 3:
				for row in range(run_start, run_end + 1):
					matched[row][col] = true
			run_start = run_end + 1

	var cells: Array = []
	for row in range(height):
		for col in range(width):
			if matched[row][col]:
				cells.append([row, col])
	return cells


## Resolve the board to a stable state: repeatedly clear all current matches, apply
## gravity, and refill from the top, until no matches remain. Returns the total number
## of gems cleared across every cascade step.
func _resolve_until_stable() -> int:
	var total_cleared := 0
	while true:
		var matched_cells := _find_matched_cells()
		if matched_cells.is_empty():
			break
		total_cleared += matched_cells.size()
		_clear_and_collapse_and_refill(matched_cells)
	return total_cleared


## Clear the given matched cells, collapse each column downward so surviving gems fall
## into the gaps (gravity pulls toward higher row indices), then refill the now-empty
## cells at the TOP of each column with fresh random colors.
func _clear_and_collapse_and_refill(matched_cells: Array) -> void:
	# Step 1: mark every matched cell empty.
	for cell in matched_cells:
		grid[cell[0]][cell[1]] = _EMPTY

	# Steps 2 & 3 happen column by column. For each column we keep the surviving
	# (non-empty) colors in order, then rebuild the column from the bottom up: the
	# survivors sit at the bottom and any remaining top slots get new random colors.
	for col in range(width):
		var survivors: Array = []
		for row in range(height):
			if grid[row][col] != _EMPTY:
				survivors.append(grid[row][col])

		var empty_count := height - survivors.size()

		# Fill the top `empty_count` rows with new random colors...
		for row in range(empty_count):
			grid[row][col] = _rng.randi_range(0, num_colors - 1)
		# ...then drop the survivors into the rows beneath them, preserving their order.
		for i in range(survivors.size()):
			grid[empty_count + i][col] = survivors[i]
