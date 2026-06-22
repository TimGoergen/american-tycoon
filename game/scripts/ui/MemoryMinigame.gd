class_name MemoryMinigame
extends Minigame

# "Memory" minigame TYPE (GDD §5.5) — a Simon-style recall game. The board flashes a
# growing sequence across four pads; the player repeats it. Each correct round adds one
# step; a wrong tap ends the game. Performance = rounds completed / TARGET_ROUNDS.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

## Rounds (sequence length) that make a full game (also the performance denominator).
const TARGET_ROUNDS := 8
const PAD_COLORS := [
	UiPalette.KETCHUP_RED, UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL, UiPalette.MONEY_GREEN,
]
const FLASH_ON := 0.42   # seconds a pad stays lit during playback
const FLASH_GAP := 0.18  # gap between flashes

var _sequence: Array = []
var _input_index: int = 0
var _rounds_done: int = 0
var _accepting_input: bool = false
var _running: bool = false
var _rng := RandomNumberGenerator.new()

var _pads: Array = []  # the four pad Panels (index = pad id)
var _status_label: Label


func begin(_tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true

	var intro := Label.new()
	intro.text = "Watch the sequence, then tap it back."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	# 2x2 grid of big pads.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in range(4):
		var pad := Panel.new()
		pad.custom_minimum_size = Vector2(240, 240)
		pad.mouse_filter = Control.MOUSE_FILTER_STOP
		pad.gui_input.connect(_on_pad_input.bind(i))
		_style_pad(pad, i, false)
		grid.add_child(pad)
		_pads.append(pad)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_center.add_child(grid)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_status_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(grid_center)
	column.add_child(_status_label)
	add_child(column)

	_start_round()


func get_performance() -> float:
	return clampf(float(_rounds_done) / float(TARGET_ROUNDS), 0.0, 1.0)


func _style_pad(pad: Panel, pad_id: int, lit: bool) -> void:
	var box := StyleBoxFlat.new()
	var base: Color = PAD_COLORS[pad_id]
	box.bg_color = base.lightened(0.45) if lit else base
	box.border_color = UiPalette.CREAM if lit else UiPalette.INK_NAVY
	box.set_border_width_all(6 if lit else 3)
	box.set_corner_radius_all(16)
	pad.add_theme_stylebox_override("panel", box)


## Begin a round: extend the sequence by one and play it back (input is locked meanwhile).
func _start_round() -> void:
	_sequence.append(_rng.randi_range(0, 3))
	_input_index = 0
	_status_label.text = "Watch…"
	await _play_sequence()
	if not _running:
		return
	_accepting_input = true
	_status_label.text = "Your turn — %d to repeat" % _sequence.size()


func _play_sequence() -> void:
	_accepting_input = false
	# Guard get_tree() at every step: if this minigame is freed mid-playback (e.g. the host
	# tears it down), the awaited coroutine must bail rather than touch a detached node.
	if not is_inside_tree():
		return
	# A small lead-in so the first flash isn't instant.
	await get_tree().create_timer(0.4).timeout
	for pad_id in _sequence:
		if not _running or not is_inside_tree():
			return
		_style_pad(_pads[pad_id], pad_id, true)
		await get_tree().create_timer(FLASH_ON).timeout
		if not _running or not is_inside_tree():
			return
		_style_pad(_pads[pad_id], pad_id, false)
		await get_tree().create_timer(FLASH_GAP).timeout


func _on_pad_input(event: InputEvent, pad_id: int) -> void:
	if not _accepting_input or not _running:
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Quick press feedback (only schedule the un-flash if we're still in the tree).
	_style_pad(_pads[pad_id], pad_id, true)
	if is_inside_tree():
		get_tree().create_timer(0.15).timeout.connect(
			func() -> void:
				if is_instance_valid(_pads[pad_id]):
					_style_pad(_pads[pad_id], pad_id, false)
		)

	if pad_id != _sequence[_input_index]:
		# Wrong — the game ends here with whatever rounds were banked.
		_running = false
		_accepting_input = false
		completed.emit(get_performance())
		return

	_input_index += 1
	if _input_index >= _sequence.size():
		# Whole sequence repeated — round complete.
		_rounds_done += 1
		_accepting_input = false
		if _rounds_done >= TARGET_ROUNDS:
			_running = false
			completed.emit(get_performance())
		else:
			_start_round()
