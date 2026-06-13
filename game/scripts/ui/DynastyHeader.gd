# DynastyHeader — a slim header strip pinned at the top of the Main screen.
#
# Displays the player's current dynastic identity at a glance:
#   • LEFT:  the heir's full name in UPPERCASE (e.g. "WELLINGTON PEMBERTON IX").
#            The Roman numeral suffix is the generation counter — how many heirs
#            the dynasty has cycled through (GDD §13).
#   • RIGHT: total accumulated Legacy points, the dynasty's prestige currency
#            (GDD §13). Given gold treatment (MUSTARD_GOLD) because Legacy is
#            the long-arc score — it never resets and never decreases.
#
# This node is display-only. Main.gd drives it by calling set_dynasty().
# Style follows the project's "ticket plate" aesthetic: cream plate, navy border,
# faux-bold via a matching-color outline (no bold font asset exists until M3).

class_name DynastyHeader
extends PanelContainer

# Type sizes — art direction for at-a-glance reading on a phone screen.
# Tim is 49 with imperfect vision; err large (UI notes §1).
const HEIR_FONT_SIZE  := 34  # the name is the primary identity marker
const LEGACY_FONT_SIZE := 28  # legacy is secondary; smaller but still prominent
const FAUX_BOLD_OUTLINE := 2  # outline size that fakes bold weight until M3 fonts

# The two live labels — kept as members so set_dynasty() can update them.
var _name_label:   Label
var _legacy_label: Label


func _ready() -> void:
	# Apply the standard cream ticket plate (navy border) from the palette.
	add_theme_stylebox_override("panel", UiPalette.make_panel_style())

	# A single HBoxContainer fills the plate: name | spacer | legacy.
	var row := HBoxContainer.new()
	# Vertical center-align so both labels sit on the same baseline.
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	# LEFT: heir name — navy, large, faux-bold.
	_name_label = _make_label(UiPalette.NAVY, HEIR_FONT_SIZE, FAUX_BOLD_OUTLINE)
	row.add_child(_name_label)

	# SPACER: pushes the legacy label to the right edge.
	# SIZE_EXPAND_FILL tells the HBox to give all leftover horizontal space to this
	# invisible node — a common Godot pattern for "push the next child to the far end".
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# RIGHT: legacy total — MUSTARD_GOLD (prestige currency gets the gold treatment).
	_legacy_label = _make_label(UiPalette.MUSTARD_GOLD, LEGACY_FONT_SIZE, FAUX_BOLD_OUTLINE)
	row.add_child(_legacy_label)


## Build a label styled for the ticket-plate aesthetic: a given color, a given
## font size, and a same-color outline that fakes bold weight (see class header).
## This replicates HeroStat._make_label exactly — the pattern is project-wide.
func _make_label(color: Color, font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	# The outline is the same color as the text — it thickens the glyphs without
	# changing the hue, producing a convincing faux-bold at small outline sizes.
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", outline)
	return label


## Update the displayed dynasty identity.
## `dynasty_name` is the full name string, e.g. "Wellington Pemberton IX".
## `legacy_total` is the integer Legacy points accumulated across all generations.
func set_dynasty(dynasty_name: String, legacy_total: int) -> void:
	# Always show the name in UPPERCASE — ticket-plate style convention,
	# and the Roman numeral reads more clearly in all-caps.
	_name_label.text = dynasty_name.to_upper()
	_legacy_label.text = "LEGACY: " + str(legacy_total)
