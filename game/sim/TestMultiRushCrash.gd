extends SceneTree

# Script to test multi-rushing on Vashti Deep-Court (Epoch 8)

func _init() -> void:
	print("--- Starting MultiRushCrashTest ---")
	
	# Load Main scene
	var main_scene: PackedScene = load("res://Main.tscn")
	if main_scene == null:
		print("ERROR: Could not load Main.tscn")
		quit(1)
		return
		
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	
	# Wait a bit for ready
	await root.get_tree().process_frame
	
	print("Main initialized. Setting epoch to Vashti Deep-Court (Tier 8)...")
	var game: GameState = main.game
	game.epoch.current_tier = 8
	
	# Give money & unlock properties
	game.economy.award_earned(1e30)
	game.economy.cash = 1e30
	
	# Unlock and buy properties in Epoch 8
	var prop_indices := game.economy.get_property_indices_for_unlock_tier(8)
	print("Epoch 8 property indices: ", prop_indices)
	
	for idx in prop_indices:
		var prop: PropertyState = game.economy.properties[idx]
		prop.buy(10)
	
	# Re-setup rows or switch tab to Epoch 8 (index 7 or 8)
	main._switch_epoch_tab(7) # 0-indexed tab for tier 8
	
	await root.get_tree().process_frame
	
	print("Starting multi-rush on 2 properties...")
	if prop_indices.size() >= 2:
		var p1: int = prop_indices[0]
		var p2: int = prop_indices[1]
		
		print("Multi-rushing property %d and %d..." % [p1, p2])
		
		# Engage overdrive if possible
		game.engage_rush_overdrive()
		
		# Simulate holding rush on both properties for many frames
		for frame in range(600):
			game.hold_rush_property(p1)
			game.hold_rush_property(p2)
			game.notify_rush_pressed(p1)
			game.notify_rush_pressed(p2)
			
			# Tick game and main
			await root.get_tree().process_frame
			
			if frame % 60 == 0:
				print("Frame %d: heat=%.3f, bonus=%.3f, overdrive=%s, locked=%s, vent_open=%s" % [
					frame, game.rush_momentum.heat, game.rush_momentum.bonus,
					game.rush_momentum.is_overdrive_engaged(),
					game.rush_momentum.is_locked_out(),
					game.rush_momentum.is_vent_window_open()
				])
	
	print("--- Finished MultiRushCrashTest successfully without crashing ---")
	quit(0)
