class_name DevTuningPanel
extends ColorRect

# The dev-facing balance tuning panel (GDD §13 "Balance config screen") — a
# developer tool, not a player screen. It lists every numeric constant in
# TuningConfig and lets them be edited on-device, so balance can be felt on real
# hardware instead of only in the headless simulator.
#
# How a change takes effect: the panel does not mutate the running game live —
# many constants are read once at startup, so a half-applied change would be
# inconsistent. Instead Apply writes the changed constants to the user:// override
# file (see TuningOverrides) and asks Main to reload the scene, which re-runs the
# normal startup path with the new numbers layered over the baked defaults. The
# current save is preserved across the reload, so only the tuning changes.
#
# It is built generically from reflection (every TYPE_INT / TYPE_FLOAT exported
# var on TuningConfig), so new constants appear here automatically with no UI work.
#
# Drive it from Main.gd:
#   1. setup()                          once, to build the static chrome
#   2. open(effective_tuning, baked)    to (re)populate rows and show the panel
#   3. listen for the signals below

## Close without applying anything.
signal closed

## Apply the given { constant_name: number } overrides and reload. Only constants
## that differ from the baked default are included; an empty dict clears overrides.
signal apply_requested(overrides: Dictionary)

## Discard every override and return to the baked defaults (then reload).
signal defaults_requested

## Wipe the save and start a brand-new dynasty from generation 1 (the folded-in
## reset). Destructive — the panel two-taps to confirm before emitting this.
signal reset_dynasty_requested


# Large, legible type for phone reading (UI notes §1), but denser than the
# ceremony screens since this is a long developer list, not a player moment.
const TITLE_SIZE := 56
const SUBTITLE_SIZE := 28
const ROW_LABEL_SIZE := 30
const ROW_VALUE_SIZE := 30
const BUTTON_SIZE := 30

## Top inset (in the 1080×1920 design space) clearing the phone camera cut-out,
## matching the other full-screen overlays.
const CAMERA_CUTOUT_INSET := 130

## Fixed width (px) of the value editor column, so the constant names line up.
const VALUE_COLUMN_WIDTH := 360
const ROW_HEIGHT := 64


# One LineEdit per constant, keyed by constant name, read back on Apply.
var _value_edits: Dictionary = {}
# The constant's declared type (TYPE_INT / TYPE_FLOAT), keyed by name.
var _types: Dictionary = {}
# The baked default for each constant, keyed by name — Apply only stores values
# that differ from this, and rows that differ are flagged as overridden.
var _baked: Dictionary = {}

var _list: VBoxContainer
var _reset_dynasty_button: Button
# Two-tap guard on the destructive wipe: armed by the first tap, fires on the second.
var _reset_armed := false


## Build the static chrome once (header, scroll frame, footer buttons).
func setup() -> void:
	_build_chrome()


func _ready() -> void:
	# Opaque cream sheet over the whole screen; Main freezes the economy while it
	# is visible (same convention as the other full-page overlays).
	color = UiPalette.CREAM
	visible = false


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", CAMERA_CUTOUT_INSET)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Dev Tuning"
	title.add_theme_color_override("font_color", UiPalette.NAVY)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Edit a value, then Apply & Reload. Gold = overridden."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", UiPalette.NAVY)
	subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	column.add_child(subtitle)

	# ── Scrollable list of constant rows ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# ── Footer: two button rows ──
	var top_buttons := HBoxContainer.new()
	top_buttons.add_theme_constant_override("separation", 12)
	column.add_child(top_buttons)

	# Mustard (not red): Apply is the routine confirm, so red stays reserved for
	# the one truly destructive control below (the dynasty wipe).
	var apply_button := _make_button("APPLY & RELOAD", false)
	apply_button.pressed.connect(_on_apply_pressed)
	top_buttons.add_child(apply_button)

	var defaults_button := _make_button("RESET TO DEFAULTS", false)
	defaults_button.pressed.connect(_on_defaults_pressed)
	top_buttons.add_child(defaults_button)

	var bottom_buttons := HBoxContainer.new()
	bottom_buttons.add_theme_constant_override("separation", 12)
	column.add_child(bottom_buttons)

	# Red because it wipes the save — the one destructive action on this panel.
	_reset_dynasty_button = _make_button("RESET DYNASTY", true)
	_reset_dynasty_button.pressed.connect(_on_reset_dynasty_pressed)
	bottom_buttons.add_child(_reset_dynasty_button)

	var close_button := _make_button("CLOSE", false)
	close_button.pressed.connect(_on_close_pressed)
	bottom_buttons.add_child(close_button)


## A footer button sized for thumbs (UI notes §1), expanding to share its row.
func _make_button(text: String, is_action: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 96)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	UiPalette.style_button(button, is_action)
	return button


# ---------------------------------------------------------------------------
# Showing / populating
# ---------------------------------------------------------------------------

## (Re)build the constant rows and show the panel. `effective_tuning` is the live
## config (baked defaults with any overrides already applied) whose values seed the
## editors; `baked_tuning` is a pristine baked copy used to tell which constants are
## currently overridden and, on Apply, which edited values to store.
func open(effective_tuning: TuningConfig, baked_tuning: TuningConfig) -> void:
	_disarm_reset()
	_value_edits.clear()
	_types.clear()
	_baked.clear()
	for child in _list.get_children():
		child.queue_free()

	# Reflection: every exported int/float on TuningConfig, in declaration order
	# (so related constants stay grouped exactly as they read in the source file).
	for prop in effective_tuning.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var type: int = prop["type"]
		if type != TYPE_INT and type != TYPE_FLOAT:
			continue
		var name: String = prop["name"]
		_add_constant_row(name, type, effective_tuning.get(name), baked_tuning.get(name))

	visible = true


## One constant row: name on the left, an editable value on the right. A row whose
## current value differs from the baked default is tinted gold and marked, so an
## active override is obvious at a glance.
func _add_constant_row(name: String, type: int, current_value: Variant, baked_value: Variant) -> void:
	_types[name] = type
	_baked[name] = baked_value
	var is_overridden: bool = current_value != baked_value

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_list.add_child(row)

	var label := Label.new()
	label.text = ("● " if is_overridden else "") + name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(
		"font_color", UiPalette.MUSTARD_GOLD if is_overridden else UiPalette.NAVY)
	label.add_theme_font_size_override("font_size", ROW_LABEL_SIZE)
	row.add_child(label)

	var edit := LineEdit.new()
	edit.text = _format_value(current_value)
	edit.custom_minimum_size = Vector2(VALUE_COLUMN_WIDTH, ROW_HEIGHT)
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.add_theme_font_size_override("font_size", ROW_VALUE_SIZE)
	# Decimal numeric keypad on the phone — every tuning constant is a number.
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	row.add_child(edit)

	_value_edits[name] = edit


## Compact string for a constant's value. Godot's str() already renders these
## cleanly (0.005, 1.15, 103600000000000), so no custom formatting is needed.
func _format_value(value: Variant) -> String:
	return str(value)


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

## Collect every edited value, keep only the ones that differ from the baked
## default, and hand them to Main to persist + reload. Invalid (non-numeric) entries
## are skipped, so they simply revert to the baked value on reload.
func _on_apply_pressed() -> void:
	var overrides: Dictionary = {}
	for name in _value_edits.keys():
		var text: String = (_value_edits[name] as LineEdit).text.strip_edges()
		if not text.is_valid_float():
			push_warning("DevTuningPanel: '%s' = '%s' is not a number, skipping" % [name, text])
			continue
		var value: Variant
		if _types[name] == TYPE_INT:
			value = int(round(text.to_float()))
		else:
			value = text.to_float()
		# Store only genuine changes — typing the default back removes the override.
		if value != _baked[name]:
			overrides[name] = value
	visible = false
	apply_requested.emit(overrides)


func _on_defaults_pressed() -> void:
	visible = false
	defaults_requested.emit()


## First tap arms the wipe (turns the button into a confirm); second tap fires it.
## Any other exit (Close) disarms it again — see _disarm_reset.
func _on_reset_dynasty_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_dynasty_button.text = "TAP AGAIN TO WIPE"
		return
	visible = false
	reset_dynasty_requested.emit()


func _on_close_pressed() -> void:
	_disarm_reset()
	visible = false
	closed.emit()


func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_dynasty_button != null:
		_reset_dynasty_button.text = "RESET DYNASTY"
