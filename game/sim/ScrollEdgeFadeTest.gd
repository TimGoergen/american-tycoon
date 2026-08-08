extends SceneTree

# Headless verification for ScrollEdgeArrows.apply_edge_fade — the helper that fades list items as
# they slide under a scroll's top/bottom strips.
#
# Usage: godot --headless --path . --script res://sim/ScrollEdgeFadeTest.gd
#
# WHY THIS EXISTS (Tim, 2026-08-08): "when you are playing a challenge mode game and then click done
# to exit, the challenge mode screen shows but the individual games do not become visible without
# touching the screen."
#
# The rows were not missing — they were at alpha 0. Every alpha this helper computes is a fraction of
# the SCROLL'S rect, so when a list is rebuilt inside a hidden subtree and the fade runs before the
# layout settles, `view.size.y` is zero, `above_strip` is negative for every item, and the whole list
# fades to nothing. Touching the screen scrolled, which recomputed the fade against real geometry and
# brought it back — which is exactly why it looked like an input problem rather than a layout one.
#
# The fix is a guard: with no laid-out viewport there is no sensible answer, so leave the alphas
# alone and let the next scroll or resize paint them. This pins that guard, because the failure mode
# is invisible content — the worst kind to ship, since nothing errors and nothing looks broken except
# the screen being empty.
#
# Loads the UI script through an assembled path for the same reason the momentum-bar test does: a
# static class reference from a sim can create a resolution cycle that breaks parsing elsewhere.

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== Scroll edge fade — viewport guard ===\n")

	var script_path := "res://scripts/ui/" + "ScrollEdgeArrows.gd"
	var fade_script: GDScript = load(script_path)
	if fade_script == null:
		print("FAILED to load ScrollEdgeArrows.gd")
		quit(1)
		return

	# A scroll with a real box and three items that comfortably fit inside it.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	root.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var items: Array = []
	for i in range(3):
		var item := ColorRect.new()
		item.custom_minimum_size = Vector2(0, 60)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(item)
		items.append(item)
	await process_frame
	await process_frame

	_check("the scroll laid out with a real height", scroll.size.y > 0.0)
	_check("the items laid out with real heights",
		(items[0] as Control).size.y > 0.0)

	# Everything fits, so nothing should be faded.
	fade_script.apply_edge_fade(scroll, items)
	var all_opaque := true
	for item in items:
		if not is_equal_approx((item as Control).modulate.a, 1.0):
			all_opaque = false
	_check("with the whole list in view, nothing is faded", all_opaque)

	# THE BUG: a scroll that has never been laid out, which is what a list rebuilt inside a hidden
	# subtree is working against.
	#
	# Built DETACHED rather than by shrinking the one above: `custom_minimum_size` clamps a
	# ScrollContainer's height straight back up, so assigning size.y = 0 to the laid-out scroll left
	# it at 300 and the test passed against the unfixed helper — a repro that reproduced nothing.
	var unlaid := ScrollContainer.new()
	var ghosts: Array = []
	for i in range(3):
		var ghost := ColorRect.new()
		ghost.size = Vector2(400, 60)          # real item height, no viewport to measure against
		ghost.position = Vector2(0, i * 60)
		ghosts.append(ghost)
	_check("the detached scroll genuinely has no height", unlaid.get_global_rect().size.y <= 0.0)
	_check("...while its items do have height", (ghosts[0] as Control).size.y > 0.0)

	fade_script.apply_edge_fade(unlaid, ghosts)
	var untouched := true
	for ghost in ghosts:
		if not is_equal_approx((ghost as Control).modulate.a, 1.0):
			untouched = false
	_check("an unlaid-out viewport leaves every alpha ALONE rather than fading the list away",
		untouched)

	for ghost in ghosts:
		(ghost as Control).free()
	unlaid.free()
	scroll.queue_free()

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
