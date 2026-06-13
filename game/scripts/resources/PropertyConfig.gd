class_name PropertyConfig
extends Resource

# Immutable config for one property type (ATM, Money Tree, etc.).
# Values come from res://config/properties/*.tres — never hardcoded.

## Numeric id matching the GDD §4 table row (1–12).
@export var property_id: int = 0

## Display name shown to the player.
@export var display_name: String = ""

## Base cost of the first unit, in dollars.
@export var base_cost: float = 0.0

## Per-unit cost ratio at band 0 (~1.05–1.10). Steepens with each milestone band.
## See CostCurve.gd and Mechanics Spec §3.2.
@export var r0: float = 1.07

## Income earned per completed cycle, for a single unit owned (before milestone multipliers).
@export var base_income_per_unit: float = 0.0

## Duration of one income cycle in seconds (before milestone speed-ups).
@export var base_cycle_length: float = 1.0

## Name of the staffer card shown when this property is hired out (M3).
@export var staffer_name: String = ""

## Round head-shot of the property manager, shown in the row's portrait circle
## once the property is staffed. Authored as a circular PNG (transparent corners).
## Null until art lands in M3 — the circle then falls back to a lettered placeholder.
@export var manager_portrait: Texture2D = null
