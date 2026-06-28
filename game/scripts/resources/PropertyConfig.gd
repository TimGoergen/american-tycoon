class_name PropertyConfig
extends Resource

# Immutable config for one property type (ATM, Money Tree, etc.).
# Values come from res://config/properties/*.tres — never hardcoded.

## Numeric id matching the GDD §4 table row (1–12).
@export var property_id: int = 0

## Display name shown to the player.
@export var display_name: String = ""

## The epoch tier (EpochCatalog, 1-based) at which this property becomes available to
## buy. The 12 Earth properties are tier 1 — available from the start, so this defaults
## to 1 and their .tres files need not set it. Alien property types added at First Contact
## (GDD §5.5 site 2) carry a higher tier: they stay hidden and unbuyable until the run has
## reached that epoch, then the trade-deal minigame grants the player a head start on them.
@export var unlock_tier: int = 1

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

## Accent color for this property — the background tint shown behind the staffer's
## portrait once the property is staffed (a per-property color, GDD §5.5 / Tim 2026-06-22).
## A deliberate, sanctioned extension beyond the Art Style Guide's 9-color palette: with
## 12 properties there are not enough palette colors to give each a unique hue, so this
## 12-color property palette is its own small, documented exception.
@export var accent_color: Color = Color("#7DA87B")
