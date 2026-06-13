class_name DynastyState

# The dynastic layer that lives ABOVE a single run (Mechanics Spec §9, GDD §3.2).
#
# GameState models exactly one generation — one person's lifetime of earning. A
# DynastyState owns the whole bloodline: it holds the current generation plus the
# things that outlive any individual (total Legacy, the generation counter, the
# predecessor's peak to out-sprint) and performs succession — death, the estate
# waterfall, Legacy conversion, and the birth of a faster heir.
#
# This is headless and scene-tree-free, like the rest of the core, so the
# simulator drives it directly. The M1 Main screen still drives a bare GameState;
# wiring the UI to the dynasty (ceremony screens, Estate Planning tab) is a later
# M2 slice. For now the prestige loop is exercised and verified only in the sim.

var tuning: TuningConfig

# Held so each new generation is built from the same configs the dynasty started with.
var _property_configs: Array
var _title_configs: Array

## Total dynastic Legacy. Accumulates at every death and is never spent down by
## conversion (Legacy *upgrades*, a later slice, are what spend it).
var legacy_total: int = 0

## Which generation is alive, 1-based — the Roman-numeral suffix (Wellington IX).
var generation: int = 1

## Peak net worth of the immediately preceding generation. The current heir's
## sprint multiplier stays active until it surpasses this (Spec §9.4).
var predecessor_peak_net_worth: float = 0.0

## How many Legacy brackets the dynasty has attained — drives the permanent
## residual multiplier after a sprint ends.
var brackets_attained: int = 0

## Lifetime taps across all generations ("Work Ethic"); persists per Spec §5.
var dynastic_taps: int = 0

## The generation alive right now. All active play happens through this.
var current: GameState


func _init(property_configs: Array, titles: Array, p_tuning: TuningConfig) -> void:
	_property_configs = property_configs
	_title_configs = titles
	tuning = p_tuning
	current = _new_generation()


# ---------------------------------------------------------------------------
# Driving the living generation
# ---------------------------------------------------------------------------

## Advance the current generation by `delta` seconds, applying the dynasty's
## Legacy multiplier to property income (never to the wage — Spec §9.4).
func tick(delta: float) -> void:
	current.tick(delta, get_legacy_income_multiplier())


## The Legacy income multiplier in force this instant (property income only).
## While the heir is still poorer than the predecessor's peak, the big catch-up
## SPRINT applies; once it surpasses that peak, the sprint is permanently spent
## and only the smaller RESIDUAL remains. Peak net worth is monotonic, so this
## switch happens exactly once per generation and never flips back.
func get_legacy_income_multiplier() -> float:
	if legacy_total <= 0:
		return 1.0
	if current.peak_net_worth < predecessor_peak_net_worth:
		return EstateWaterfall.sprint_mult(legacy_total, tuning.k_sprint, tuning.beta_sprint)
	return EstateWaterfall.residual_mult(brackets_attained, tuning.k_residual)


# ---------------------------------------------------------------------------
# The draft will and the succession gate (Spec §9.1–9.3)
# ---------------------------------------------------------------------------

## The live estate waterfall for the current generation — what the heir would
## inherit if death happened now. Used by the succession gate below and, later,
## displayed continuously on the Estate Planning tab. Debt is 0 until the
## debt/offers slice lands; the waterfall already accepts it as a parameter.
func get_draft_will() -> Dictionary:
	var estate_gross := current.economy.get_net_worth()
	var outstanding_debt := 0.0  # debt & offers system is a later M2 slice
	var will := EstateWaterfall.compute(
		estate_gross,
		outstanding_debt,
		tuning.estate_exemption_base,
		tuning.estate_tax_rate_base
	)
	will["legacy_gain"] = EstateWaterfall.legacy_gain(
		will["estate_net"], tuning.k_legacy, tuning.alpha_legacy
	)
	return will


## Legacy the current estate would convert to if death happened now.
func projected_legacy_gain() -> int:
	return int(get_draft_will()["legacy_gain"])


## Succession is allowed once dying would actually grow the dynasty — i.e. the
## estate converts to at least 1 Legacy (Spec §9.1, the minimum-estate gate).
func can_perform_succession() -> bool:
	return projected_legacy_gain() >= 1


# ---------------------------------------------------------------------------
# Succession — death, inheritance, rebirth
# ---------------------------------------------------------------------------

## Kill the current generation and raise its heir. Banks the estate's Legacy,
## records the peak the heir must out-sprint, advances the generation counter,
## carries dynastic Work Ethic forward, and replaces `current` with a fresh,
## faster generation. Returns the executed will for ceremony/logging.
func perform_succession() -> Dictionary:
	var will := get_draft_will()

	legacy_total += int(will["legacy_gain"])
	brackets_attained = EstateWaterfall.brackets_for(legacy_total)
	predecessor_peak_net_worth = current.peak_net_worth
	dynastic_taps = current.wage.lifetime_taps
	generation += 1

	current = _new_generation()
	return will


## Build the next generation from scratch. The heir starts with the same opening
## capital as anyone (the origin flow that varies this is a later slice) and
## inherits only Work Ethic; its acceleration advantage comes entirely from the
## Legacy multiplier applied at tick time, not from seeded cash.
func _new_generation() -> GameState:
	var heir := GameState.new(_property_configs, _title_configs, tuning)
	heir.economy.award_cash(tuning.m1_starting_cash)
	heir.wage.lifetime_taps = dynastic_taps
	return heir


# ---------------------------------------------------------------------------
# Save / load (the dynastic block wraps the current generation's save)
# ---------------------------------------------------------------------------

## Everything needed to reconstruct the dynasty: the cross-generation facts plus
## the current generation's own save dict (GameState.to_save_dict).
func to_save_dict() -> Dictionary:
	return {
		"legacy_total": legacy_total,
		"generation": generation,
		"predecessor_peak_net_worth": predecessor_peak_net_worth,
		"brackets_attained": brackets_attained,
		"dynastic_taps": dynastic_taps,
		"current": current.to_save_dict(),
	}


## Restore a dynasty from a save dict. A bare M1 GameState save (no dynastic
## wrapper) reconstructs as a clean generation-1 dynasty, because every dynastic
## field defaults and the whole dict is handed to the current generation to load.
func load_save_dict(data: Dictionary) -> void:
	legacy_total = int(data.get("legacy_total", 0))
	generation = int(data.get("generation", 1))
	predecessor_peak_net_worth = float(data.get("predecessor_peak_net_worth", 0.0))
	brackets_attained = int(data.get("brackets_attained", 0))
	dynastic_taps = int(data.get("dynastic_taps", 0))

	current = GameState.new(_property_configs, _title_configs, tuning)
	var current_data: Variant = data.get("current", data)
	if current_data is Dictionary:
		current.load_save_dict(current_data)
