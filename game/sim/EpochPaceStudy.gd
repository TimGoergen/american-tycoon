extends "res://sim/Sim.gd"

# Epoch Pace Study — how long each epoch takes to clear, at different Legacy gem
# stacks (2026-07-26, Tim's "I flew through all the later epochs" report).
#
# The economy is flat by design: economy_scale grows x16807/epoch and both the
# advance threshold and each cohort's earning power scale by that same x16807, so
# every epoch is the same "size." The open question is what a big Legacy stack does
# to the felt pace. This reuses Sim.gd's full-run PLAYOUT (an active heir: wage taps,
# greedy reinvest, frenzy pops, rush on top earners) and prints each epoch's clear
# duration + its ratio vs the previous epoch, for a ladder of gem stacks.
#
# Read the "vs prev" column: ~x1.00 down the ladder == flat (flies through equally);
# ratios climbing above 1 == later epochs genuinely resist more.
#
# Usage: Godot_console.exe --headless --path game --script res://sim/EpochPaceStudy.gd

func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Epoch Pace Study ===")
	print("Active heir (rush top 3, Strong-Arm ~lv10). Each epoch's clear time + ratio")
	print("vs the previous epoch. Flat ratios = the fly-through Tim reported.")
	print("(The final epoch is omitted — reaching it ends the climb, so it has no duration.)")

	# rush_top_n = 3, rush_power = 6 (~Strong-Arm lv10) models an engaged rushing player.
	# Ordered fast-first: high-gem runs clear quickly (few sim-seconds), so their tables
	# stream out before the bare climb (which grinds to the 6h cap) finishes computing.
	_print_playout("66M gems (Tim's device stack)", 66_000_000, _property_configs, 3, 6.0)
	_print_playout("1B gems", 1_000_000_000, _property_configs, 3, 6.0)
	_print_playout("10M gems", 10_000_000, _property_configs, 3, 6.0)
	_print_playout("1M gems", 1_000_000, _property_configs, 3, 6.0)
	_print_playout("BARE heir — 0 gems (first-ever climb)", 0, _property_configs, 3, 6.0)

	quit()
