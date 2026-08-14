extends SceneTree

# Headless verification for The Final Dollar and Earth Capture Climax System (GDD §10).
#
# Usage: godot --headless --path game --script res://sim/FinalDollarTest.gd

var _failures := 0


func _initialize() -> void:
	print("=== Final Dollar & Earth Capture — headless verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	var property_configs := ConfigLoader.load_property_configs()
	if tuning == null or property_configs.is_empty():
		print("FAILED to load configs")
		quit(1)
		return

	_test_dynasty_earth_capture_tracking(property_configs, tuning)
	_test_save_load_round_trip(property_configs, tuning)
	_test_family_ledger_rendering()

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


func _test_dynasty_earth_capture_tracking(property_configs: Array, tuning: TuningConfig) -> void:
	print("1. DynastyState Earth capture tracking")
	var dynasty := DynastyState.new(property_configs, tuning)

	_check("starts not captured", not dynasty.is_earth_captured())
	_check("default capture gen is 0", dynasty.earth_capture_generation == 0)

	dynasty.mark_earth_captured(2, 103.6e12)
	_check("is_earth_captured returns true after mark", dynasty.is_earth_captured())
	_check("capture gen recorded", dynasty.earth_capture_generation == 2)
	_check("capture cash recorded", is_equal_approx(dynasty.earth_capture_lifetime_cash, 103.6e12))


func _test_save_load_round_trip(property_configs: Array, tuning: TuningConfig) -> void:
	print("2. Earth capture save/load round-trip")
	var dynasty := DynastyState.new(property_configs, tuning)
	dynasty.mark_earth_captured(4, 103.6e12)

	var saved := dynasty.to_save_dict()
	_check("save dict has earth_captured", saved.has("earth_captured") and saved["earth_captured"] == true)
	_check("save dict has earth_capture_generation", saved.get("earth_capture_generation", 0) == 4)

	var loaded := DynastyState.new(property_configs, tuning)
	loaded.load_save_dict(saved)
	_check("loaded dynasty has is_earth_captured true", loaded.is_earth_captured())
	_check("loaded dynasty has capture gen 4", loaded.earth_capture_generation == 4)
	_check("loaded dynasty has capture cash", is_equal_approx(loaded.earth_capture_lifetime_cash, 103.6e12))


func _test_family_ledger_rendering() -> void:
	print("3. FamilyLedgerScreen refresh with earth capture")
	var ledger_script: GDScript = load("res://scripts/ui/" + "FamilyLedgerScreen.gd")
	_check("FamilyLedgerScreen script loads", ledger_script != null)
	if ledger_script == null:
		return

	var ledger: Control = ledger_script.new() as Control
	ledger.setup()

	# Refresh without capture
	ledger.refresh([], 5000.0, false, 1)
	_check("ledger total label populated", ledger._total_label.text.contains("5K"))

	ledger.free()

	# Create a fresh ledger for earth captured testing
	var ledger_captured: Control = ledger_script.new() as Control
	ledger_captured.setup()
	ledger_captured.refresh([{"name": "Wellington I", "fortune": 103.6e12, "cause": "Retired"}], 103.6e12, true, 2)
	_check("ledger has children when captured", ledger_captured._list.get_child_count() == 2)
	var cert_card: Control = ledger_captured._list.get_child(0) as Control
	_check("first child is panel container certificate", cert_card is PanelContainer)

	ledger_captured.free()

	print("4. FinalDollarScreen script verification")
	var final_screen_script: GDScript = load("res://scripts/ui/" + "FinalDollarScreen.gd")
	_check("final dollar screen script loads", final_screen_script != null)
