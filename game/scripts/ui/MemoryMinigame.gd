class_name MemoryMinigame
extends Minigame

# "Memory" minigame TYPE (GDD §5.5) — a Simon-style recall game. The board flashes a
# growing sequence across four pads; the player repeats it. Each correct round adds one
# step; a wrong tap ends the game. Performance = rounds completed / TARGET_ROUNDS.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.
#
# Polish pass (2026-06-29): direction is "clearer / confirm", NOT harder. A lit pad now scales
# and bounces so the playback reads at a glance; the status line pops in when it changes; a wrong
# tap plays a red game-over beat and a full sequence a green round-clear celebration before the
# result. The host countdown is held (is_busy) only during those end beats so they're seen — the
# watch/play timing is unchanged, so difficulty is unchanged.

## Rounds (sequence length) that make a full game (also the performance denominator).
const TARGET_ROUNDS := 8
const PAD_COLORS := [
	UiPalette.KETCHUP_RED, UiPalette.MUSTARD_GOLD, UiPalette.ATOMIC_TEAL, UiPalette.MONEY_GREEN,
]
## Playback timing. Left first-pass on purpose (plan §2.4 = "confirm the speed feels fair on
## hardware", not change it): FLASH_ON is long enough to read each pad, FLASH_GAP short enough to
## feel like one phrase. UN-PLAYTESTED — confirm followable on-device.
const FLASH_ON := 0.42   # seconds a pad stays lit during playback
const FLASH_GAP := 0.18  # gap between flashes

## How much a pad grows while lit, both during playback and on a player tap, so a flash pops out
## instead of just changing color (the readability win of this pass).
const PAD_FLASH_SCALE := 1.14

var _sequence: Array = []
var _input_index: int = 0
var _rounds_done: int = 0
var _accepting_input: bool = false
var _running: bool = false
## True only while an end beat (game-over flash / round-clear celebration) is playing. The host
## holds its countdown while this is set (see is_busy) so the beat is actually seen before the
## result screen appears. It does NOT cover normal watch/play, so round difficulty is unchanged.
var _beat_playing: bool = false
var _rng := RandomNumberGenerator.new()

var _pads: Array = []  # the four pad Panels (index = pad id)
var _status_label: Label


func display_name() -> String:
	return "Memory Match"


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


func result_summary() -> String:
	return "Recalled %d of %d rounds" % [_rounds_done, TARGET_ROUNDS]


## Hold the host's countdown only while an end beat is playing, so the game-over / round-clear
## celebration is seen before the result screen takes over (the host pauses on is_busy by design).
func is_busy() -> bool:
	return _beat_playing


func _style_pad(pad: Panel, pad_id: int, lit: bool) -> void:
	var box := StyleBoxFlat.new()
	var base: Color = PAD_COLORS[pad_id]
	box.bg_color = base.lightened(0.45) if lit else base
	box.border_color = UiPalette.CREAM if lit else UiPalette.INK_NAVY
	box.set_border_width_all(6 if lit else 3)
	box.set_corner_radius_all(16)
	pad.add_theme_stylebox_override("panel", box)


## Light a pad AND bounce it (color + scale together), so a flash pops out at a glance. `lit`
## false restores the resting look and eases the scale back to normal.
func _flash_pad(pad_id: int, lit: bool) -> void:
	var pad: Panel = _pads[pad_id]
	_style_pad(pad, pad_id, lit)
	pad.pivot_offset = pad.size / 2.0  # scale about the pad's center, not its corner
	var target := Vector2(PAD_FLASH_SCALE, PAD_FLASH_SCALE) if lit else Vector2.ONE
	var bounce := create_tween()
	bounce.tween_property(pad, "scale", target, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Set the status line and pop it in (a small grow + fade), so a change of phase ("Watch…" /
## "Your turn…") announces itself instead of silently swapping text.
func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_status_label.pivot_offset = _status_label.size / 2.0
	_status_label.scale = Vector2(0.85, 0.85)
	_status_label.modulate.a = 0.0
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(_status_label, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_status_label, "modulate:a", 1.0, 0.2)


## Begin a round: extend the sequence by one and play it back (input is locked meanwhile).
func _start_round() -> void:
	_sequence.append(_rng.randi_range(0, 3))
	_input_index = 0
	_set_status("Watch…", UiPalette.MUSTARD_GOLD)
	await _play_sequence()
	if not _running:
		return
	_accepting_input = true
	_set_status("Your turn — %d to repeat" % _sequence.size(), UiPalette.MONEY_GREEN)


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
		_flash_pad(pad_id, true)
		await get_tree().create_timer(FLASH_ON).timeout
		if not _running or not is_inside_tree():
			return
		_flash_pad(pad_id, false)
		await get_tree().create_timer(FLASH_GAP).timeout


func _on_pad_input(event: InputEvent, pad_id: int) -> void:
	if not _accepting_input or not _running:
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Quick press feedback: light + bounce the pad, then un-flash shortly after (only schedule the
	# un-flash if we're still in the tree).
	_flash_pad(pad_id, true)
	if is_inside_tree():
		get_tree().create_timer(0.15).timeout.connect(
			func() -> void:
				if is_instance_valid(_pads[pad_id]):
					_flash_pad(pad_id, false)
		)

	if pad_id != _sequence[_input_index]:
		# Wrong — the game ends here with whatever rounds were banked, after a red game-over beat.
		_running = false
		_accepting_input = false
		_play_game_over_beat(pad_id)
		return

	_input_index += 1
	if _input_index >= _sequence.size():
		# Whole sequence repeated — round complete.
		_rounds_done += 1
		_accepting_input = false
		if _rounds_done >= TARGET_ROUNDS:
			# Full game — celebrate before handing off to the result screen.
			_running = false
			_play_round_clear_celebration()
		else:
			_set_status("Nice!", UiPalette.MONEY_GREEN)
			_start_round()


## Red game-over beat: shake the board and flash the mistaken pad red, then emit the result. The
## beat holds the host countdown (is_busy) so it is actually seen before the result appears.
func _play_game_over_beat(wrong_pad_id: int) -> void:
	_beat_playing = true
	_set_status("Missed!", UiPalette.KETCHUP_RED)

	var pad: Panel = _pads[wrong_pad_id]
	var red_box := StyleBoxFlat.new()
	red_box.bg_color = UiPalette.KETCHUP_RED
	red_box.border_color = UiPalette.INK_NAVY
	red_box.set_border_width_all(6)
	red_box.set_corner_radius_all(16)
	pad.add_theme_stylebox_override("panel", red_box)

	# A quick left-right shake reads as a buzzer "no". Shake the minigame root rather than a
	# container-managed child: the host adds us to a plain Control with full-rect anchors, so our
	# position isn't re-sorted each frame and the transient offset actually renders.
	var rest := position
	var shake := create_tween()
	for offset in [18.0, -18.0, 12.0, -12.0, 0.0]:
		shake.tween_property(self, "position:x", rest.x + offset, 0.05)

	# Hold ~0.6s so the beat lands, then release the countdown and report the result.
	await get_tree().create_timer(0.6).timeout
	_beat_playing = false
	if is_inside_tree():
		completed.emit(get_performance())


## Round-clear celebration: a green/white flash rippling across all four pads, then emit the
## result. Also holds the host countdown (is_busy) so the win beat is seen.
func _play_round_clear_celebration() -> void:
	_beat_playing = true
	_set_status("You did it!", UiPalette.MONEY_GREEN)

	# Flash each pad bright in turn for a celebratory ripple.
	for pad_id in range(_pads.size()):
		if not is_inside_tree():
			break
		_flash_pad(pad_id, true)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.3).timeout
	for pad_id in range(_pads.size()):
		if is_instance_valid(_pads[pad_id]):
			_flash_pad(pad_id, false)

	_beat_playing = false
	if is_inside_tree():
		completed.emit(get_performance())
