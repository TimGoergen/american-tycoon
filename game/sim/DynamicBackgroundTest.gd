class_name DynamicBackgroundTest
extends SceneTree

## Headless test gate verifying DynamicBackground progression, column selection,
## vertical viewport calculation, and wrap-around cycle logic across epochs.

func _init() -> void:
	print("Running DynamicBackgroundTest...")
	test_column_progression()
	test_vertical_progress_steps()
	test_src_rect_calculation()
	test_asset_availability()
	print("ALL CHECKS PASSED: DynamicBackgroundTest")
	quit(0)


func test_column_progression() -> void:
	# Tier 1..10 -> Column 0 (Earth & Sky)
	for t in range(1, 11):
		var col := DynamicBackground.get_column_index_for_tier(t)
		assert(col == 0, "Tier %d should be in Column 0 (Earth), got %d" % [t, col])
		assert(DynamicBackground.get_panel_name_for_tier(t) == "Earth & Sky", "Tier %d should be Earth & Sky" % t)
	
	# Tier 11..20 -> Column 1 (Near Space)
	for t in range(11, 21):
		var col := DynamicBackground.get_column_index_for_tier(t)
		assert(col == 1, "Tier %d should be in Column 1 (Near Space), got %d" % [t, col])
		assert(DynamicBackground.get_panel_name_for_tier(t) == "Near Space", "Tier %d should be Near Space" % t)
	
	# Tier 21..30 -> Column 2 (Deep Space)
	for t in range(21, 31):
		var col := DynamicBackground.get_column_index_for_tier(t)
		assert(col == 2, "Tier %d should be in Column 2 (Deep Space), got %d" % [t, col])
		assert(DynamicBackground.get_panel_name_for_tier(t) == "Deep Space", "Tier %d should be Deep Space" % t)
	
	# Tier 31 wraps back to Column 0 (Cycle 1)
	assert(DynamicBackground.get_column_index_for_tier(31) == 0, "Tier 31 should wrap to Column 0")
	assert(DynamicBackground.get_cycle_for_tier(1) == 0, "Tier 1 should be Cycle 0")
	assert(DynamicBackground.get_cycle_for_tier(30) == 0, "Tier 30 should be Cycle 0")
	assert(DynamicBackground.get_cycle_for_tier(31) == 1, "Tier 31 should be Cycle 1")


func test_vertical_progress_steps() -> void:
	# Check 10% steps in Column 0
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(1), 0.0), "Tier 1 progress should be 0.0")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(2), 0.10), "Tier 2 progress should be 0.10")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(3), 0.20), "Tier 3 progress should be 0.20")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(10), 0.90), "Tier 10 progress should be 0.90")
	
	# Transition to Column 1: resets to bottom (0.0)
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(11), 0.0), "Tier 11 progress should reset to 0.0")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(12), 0.10), "Tier 12 progress should be 0.10")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(20), 0.90), "Tier 20 progress should be 0.90")
	
	# Transition to Column 2: resets to bottom (0.0)
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(21), 0.0), "Tier 21 progress should reset to 0.0")
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(30), 0.90), "Tier 30 progress should be 0.90")
	
	# Cycle wrap: resets to bottom (0.0)
	assert(is_equal_approx(DynamicBackground.get_vertical_progress_for_tier(31), 0.0), "Tier 31 progress should reset to 0.0")


func test_src_rect_calculation() -> void:
	var tex_size := Vector2(887, 1774)
	var viewport_size := Vector2(1080, 2400)
	var col_bounds := DynamicBackground.COL_BOUNDS_A
	
	# Tier 1 (Earth, bottom):
	var rect1 := DynamicBackground.calculate_src_rect(1, tex_size, col_bounds, viewport_size)
	assert(rect1.position.x == 0, "Col 0 X should be 0")
	assert(rect1.size.x == 293, "Col 0 width should be 293")
	
	# Bottom of viewport should hit bottom of texture (1774)
	var bottom_y := rect1.position.y + rect1.size.y
	assert(is_equal_approx(bottom_y, 1774.0), "Tier 1 viewport bottom should match texture bottom: got %f" % bottom_y)
	
	# Tier 2 (Earth, +10% upward):
	var rect2 := DynamicBackground.calculate_src_rect(2, tex_size, col_bounds, viewport_size)
	assert(rect2.position.y < rect1.position.y, "Tier 2 y_top should be higher (smaller Y) than Tier 1")
	var expected_delta := (1774.0 - rect1.size.y) * 0.10
	assert(is_equal_approx(rect1.position.y - rect2.position.y, expected_delta), "Tier 2 should move up by 10% of travel distance")
	
	# Tier 11 (Near Space, bottom):
	var rect11 := DynamicBackground.calculate_src_rect(11, tex_size, col_bounds, viewport_size)
	assert(rect11.position.x == 300, "Col 1 X should be 300")
	assert(rect11.size.x == 286, "Col 1 width should be 286")
	var bottom_y11 := rect11.position.y + rect11.size.y
	assert(is_equal_approx(bottom_y11, 1774.0), "Tier 11 viewport bottom should match texture bottom")
	
	# Tier 21 (Deep Space, bottom):
	var rect21 := DynamicBackground.calculate_src_rect(21, tex_size, col_bounds, viewport_size)
	assert(rect21.position.x == 593, "Col 2 X should be 593")
	assert(rect21.size.x == 294, "Col 2 width should be 294")


func test_asset_availability() -> void:
	assert(ResourceLoader.exists(DynamicBackground.SET_A_PATH), "ScrollBackground_SetA.png must exist")
	assert(ResourceLoader.exists(DynamicBackground.SET_B_PATH), "ScrollBackground_SetB.png must exist")
	var tex_a: Texture2D = load(DynamicBackground.SET_A_PATH)
	var tex_b: Texture2D = load(DynamicBackground.SET_B_PATH)
	assert(tex_a != null, "Set A must load")
	assert(tex_b != null, "Set B must load")
	assert(tex_a.get_width() > 0 and tex_a.get_height() > 0, "Set A must have valid dimensions")
	assert(tex_b.get_width() > 0 and tex_b.get_height() > 0, "Set B must have valid dimensions")
