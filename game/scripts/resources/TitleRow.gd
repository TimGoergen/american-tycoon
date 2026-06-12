class_name TitleRow
extends Resource

# One rung of the wage ladder (Mechanics Spec §5).
# Loaded from res://config/titles/*.tres — never hardcoded.

## Job title shown on the wage button.
@export var title_name: String = ""

## Dollars paid per wage tap at this title.
@export var wage_per_tap: float = 1.0

## Dynastic lifetime wage-taps required before this title can be claimed.
@export var tap_threshold: int = 0

## One-time cost to claim the promotion (the credential gag, Spec §5).
@export var tuition: float = 0.0
