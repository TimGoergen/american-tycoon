extends SceneTree

# Throwaway probe: what rect does a GoldBubbles child actually get on a ProgressBar?

func _initialize() -> void:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.5
	root.add_child(bar)
	bar.size = Vector2(400, 30)
	var bubbles := GoldBubbles.new()
	bar.add_child(bubbles)
	await process_frame
	await process_frame
	print("bar size: ", bar.size, " bubbles pos: ", bubbles.position, " bubbles size: ", bubbles.size)
	# Also probe the hand-positioned case (HeroStat's economy bar pattern).
	bar.size = Vector2(900, 26)
	await process_frame
	print("after resize -> bubbles size: ", bubbles.size)
	quit()
