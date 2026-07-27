extends "res://sim/Sim.gd"

# Epoch Cadence Study — can a per-epoch income-per-dollar DECAY create the Idle Slayer
# "push until you stall, then prestige to push further" cadence Tim wants? (2026-07-26)
#
# EpochPaceStudy proved the economy is flat and a big Legacy stack flies through it, and
# that a per-epoch EARNING-GATE ramp is inert (income compounds within an epoch faster
# than any gate grows). This studies the other lever: make each deeper epoch pay a little
# LESS income per dollar of cohort cost, so the build-out — the thing a wealthy heir's
# income must actually chew through — takes progressively longer, until a single run
# stalls. A prestige then raises the whole income floor, so you stall a couple epochs
# deeper next time. That climbing stall-point IS the cadence.
#
# The knob is a decay d in (0,1]: property income_per_unit is scaled by d^(unlock_tier-1),
# so Earth (tier 1) is untouched and each deeper epoch earns d× less per dollar than a flat
# economy. d = 1.0 is today exactly. This is applied to CLONED configs — no game-code change.
#
# Read: at d < 1 the per-epoch durations should RAMP (not plateau) even at 66M gems, and
# the depth a run reaches before the ramp explodes should grow with the Legacy stack.
#
# Usage: Godot_console.exe --headless --path game --script res://sim/EpochCadenceStudy.gd

# (stack_gems, decay) pairs. Kept modest so stalled runs don't grind to the 6h cap.
const RUNS := [
	{"gems": 66_000_000, "decay": 1.0},
	{"gems": 66_000_000, "decay": 0.85},
	{"gems": 66_000_000, "decay": 0.70},
	{"gems": 10_000_000, "decay": 0.85},
	{"gems": 1_000_000, "decay": 0.85},
]

func _initialize() -> void:
	if not _load_configs():
		quit(1)
		return
	print("=== American Tycoon — Epoch Cadence Study ===")
	print("Income-per-dollar decay d: property income x d^(tier-1). d=1.0 is today's flat")
	print("economy. Lower d = deeper epochs pay less per dollar, so build-out ramps and stalls.")
	print("Want: durations RAMP (not plateau) even at 66M, and a bigger stack reaches deeper.")

	for run in RUNS:
		var decay := float(run["decay"])
		var gems := int(run["gems"])
		var configs := _configs_with_income_decay(decay)
		_print_playout("%dM gems, decay d=%.2f" % [gems / 1_000_000, decay],
			gems, configs, 3, 6.0)

	quit()


## A clone of the property configs with each property's income scaled by decay^(unlock_tier-1).
## Earth (tier 1) is untouched (decay^0 = 1); each deeper epoch earns progressively less per
## dollar of its (unchanged) cost. Cloned so the live configs are never mutated.
func _configs_with_income_decay(decay: float) -> Array:
	var out: Array = []
	for config_variant in _property_configs:
		var config := config_variant as PropertyConfig
		var clone := config.duplicate(true) as PropertyConfig
		clone.base_income_per_unit = config.base_income_per_unit * pow(decay, config.unlock_tier - 1)
		out.append(clone)
	return out
