extends SceneTree

# Vent Bonus Study — what does the overdrive reward ladder actually compound to?
#
# Usage: godot --headless --path . --script res://sim/VentBonusStudy.gd
#
# A STUDY, not a gate: it prints numbers and answers a question. It asserts nothing.
#
# WHY IT EXISTS. The reward ladder is endless by design (Tim, 2026-07-18, superseding a 4-tier cap):
# the overdrive span's peak starts at `bonus_peak` and every successful vent adds `vent_bonus_step`
# with NO ceiling. The DIFFICULTY CURVE is meant to be the ending instead — the window decays
# geometrically toward a floor and the demanded lifts step up 1 → 2 → 3.
#
# That trade has never been measured. It is the most-played mechanic in the game and the least
# modelled, and "no cap, the difficulty stops you" is a claim about a race between two curves: the
# reward growing linearly, and the window shrinking geometrically. This computes both and reports
# where they cross — which is the only honest way to say whether the ladder is self-limiting or
# whether a skilled player can ride it somewhere the economy did not expect.
#
# What it CANNOT tell you: whether a human can actually hit a 0.45s window demanding three lifts.
# That is a device question. This gives the shape the device test is judging.

const REPORT_TIERS := 40


func _initialize() -> void:
	_run()


func _run() -> void:
	var tuning: TuningConfig = load("res://config/tuning.tres")
	if tuning == null:
		print("FAILED to load tuning")
		quit(1)
		return

	var peak: float = tuning.rush_momentum_bonus_peak
	var step: float = tuning.rush_momentum_vent_bonus_step
	var window: float = tuning.rush_momentum_vent_window_duration
	var decay: float = tuning.rush_momentum_vent_duration_decay
	var floor_seconds: float = tuning.rush_momentum_vent_duration_floor
	var lift_step: int = maxi(tuning.rush_momentum_vent_lifts_step_tiers, 1)
	var max_lifts := 3          # RushMomentumState.MAX_VENT_LIFTS
	var gap_max: float = tuning.rush_momentum_vent_gap_max
	var tap_max: float = tuning.rush_momentum_vent_tap_max

	print("=== Vent bonus ladder vs the difficulty curve ===\n")
	print("base peak %.0f%%   step +%.0f%% per vent   window %.2fs decaying x%.3f to a %.2fs floor"
		% [peak * 100.0, step * 100.0, window, decay, floor_seconds])
	print("lifts step up every %d tiers, capped at %d; one lift costs up to %.2fs off + %.2fs tap\n"
		% [lift_step, max_lifts, gap_max, tap_max])

	# HOW FAST IS THE PLAYER? This is the whole question, and the first version of this study got it
	# wrong by assuming the tuning maxima WERE the gesture cost. They are not: gap_max and tap_max are
	# the SLOWEST a beat may be before it counts as a fumble. A quick player is far under them.
	#
	# So the ladder's ceiling is not a property of the tuning alone — it is a property of the tuning
	# AND the hands holding the phone. Three profiles, each a per-lift cost in seconds:
	var profiles := [
		{"name": "at the legal limit", "cost": gap_max + tap_max},
		{"name": "unhurried", "cost": 0.30},
		{"name": "quick", "cost": 0.18},
		{"name": "expert", "cost": 0.12},
	]

	print("tier   peak bonus   window   lifts")
	for tier in [0, 3, 6, 10, 20, 30, 40]:
		var bonus := peak + float(tier) * step
		var duration := maxf(window * pow(decay, float(tier)), floor_seconds)
		var lifts := mini(1 + tier / lift_step, max_lifts)
		print("%4d   %8.0f%%   %6.2fs   %5d" % [tier, bonus * 100.0, duration, lifts])

	print("
Where each player runs out of room:
")
	print("player               per lift   last tier   peak bonus there   x on rushed income")
	for profile in profiles:
		var cost: float = profile["cost"]
		var last := -1
		for tier in range(0, 200):
			var duration := maxf(window * pow(decay, float(tier)), floor_seconds)
			var lifts := mini(1 + tier / lift_step, max_lifts)
			if float(lifts) * cost <= duration:
				last = tier
			else:
				break
		if last < 0:
			print("%-20s %7.2fs   cannot clear even the first window" % [profile["name"], cost])
			continue
		var bonus := peak + float(last) * step
		print("%-20s %7.2fs   %9d   %14.0f%%   %16.1f"
			% [profile["name"], cost, last, bonus * 100.0, 1.0 + bonus])

	print("")
	print("READING THIS. The window floors at %.2fs and the lift demand caps at %d, so the difficulty"
		% [floor_seconds, max_lifts])
	print("curve stops getting harder — it asymptotes at %.2fs of gesture room. Any player whose three"
		% floor_seconds)
	print("lifts fit inside that floor is NOT limited by the mechanic at all; the ladder is then bounded")
	print("only by stamina and by the heat curve's own lockouts, and the bonus grows +%.0f%% per vent"
		% (step * 100.0))
	print("without limit.")
	print("")
	print("That is the design's own claim under test: 'the difficulty curve replaces the cap as the")
	print("run's ending'. It holds for slower hands and stops holding somewhere around %.2fs per lift."
		% (floor_seconds / float(max_lifts)))
	print("Whether that matters is a judgement about how fast a real player is, and about how much")
	print("multiplier the economy can absorb — both device questions. The maths only says where the")
	print("boundary sits.")

	quit(0)
