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
#
# Challenge Mode (Wave B, 2026-07-21): when the host sets `challenge_mode` true before begin(), this is
# a self-ending Simon run (challenge_self_ends() -> true, so the host runs NO keep-alive timer for it —
# the game owns its ending). The sequence CLIMBS 1,2,3,4,5,6 (one pad longer each round); recalling the
# TARGET_ROUNDS-length round finishes one full CLIMB, after which the sequence RESETS to length 1 and
# the player climbs again — endless. A WRONG TAP ends the run (classic Simon fail): the shared game-over
# beat fires and emits `completed`, which the host routes to record + credit + end the view. The
# challenge SCORE is the number of completed climbs (get_score below), so one climb clears one payout
# tier and six climbs master the ladder (ChallengeGoals STEP = 0.2). Normal (reward) mode is unchanged:
# every new behavior below is guarded on `challenge_mode`.
#
# Legacy Bonus (2026-07-10, Plans/Legacy_Bonus_System.md): after clearing ALL rounds (mastering the
# main game), there is a chance-gated BONUS ROUND. In it the four pads are made IDENTICAL — each
# wears the Legacy-gem image, so color can no longer be used to remember the sequence and the player
# must recall by pure POSITION — and the sequence is longer (memory_gem_sequence_length). Recall it
# to collect one Legacy gem. It is independent of the main reward (already banked at a full clear):
# miss it and you simply don't get the gem. The chance and the length are both tuning knobs, and the
# round is offered only on a REAL run (never Challenge Mode).

## Rounds (sequence length) that make a full game (also the performance denominator). Reduced 8->6
## (Tim, 2026-07-10): the gem bonus round is the new deep-recall test, so the base game can be shorter.
const TARGET_ROUNDS := 6

## The Legacy-gem image worn by every pad during the bonus round — the same gem used for the currency
## everywhere else, so the player instantly recognizes what is at stake.
const GEM_IMAGE := preload("res://art/icons/legacy_gem.svg")
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
var _climbs_done: int = 0
var _accepting_input: bool = false
var _running: bool = false
var _beat_playing: bool = false
var _rng := RandomNumberGenerator.new()

# --- Live tunable parameters ---
var _target_rounds: int = TARGET_ROUNDS
var _flash_on: float = FLASH_ON
var _flash_gap: float = FLASH_GAP
var _pad_flash_scale: float = PAD_FLASH_SCALE

var _pads: Array = []  # the four pad Panels (index = pad id)
var _status_label: Label

## --- Legacy bonus round ---
var _gem_round_available: bool = false
var _gem_round_active: bool = false
var _gem_sequence: Array = []
var _gem_input_index: int = 0
var _gem_accepting_input: bool = false
var _gem_length: int = 5


func display_name() -> String:
	return "Memory Match"


func how_to_play() -> String:
	return "Watch the tiles light up, then tap them back in the same order. " \
		+ "Each round adds a step — the deeper you go, the more it pays."


func uses_timer() -> bool:
	return false


func challenge_self_ends() -> bool:
	return true


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true

	if tuning != null:
		_gem_length = maxi(1, tuning.memory_gem_sequence_length)
		_target_rounds = tuning.memory_target_rounds if tuning.memory_target_rounds > 0 else TARGET_ROUNDS
		_flash_on = maxf(0.05, tuning.memory_flash_on)
		_flash_gap = maxf(0.01, tuning.memory_flash_gap)
		_pad_flash_scale = maxf(1.0, tuning.memory_pad_flash_scale)
		if not challenge_mode:
			_gem_round_available = _rng.randf() < tuning.legacy_gem_chance_memory
	else:
		_gem_length = 5
		_target_rounds = TARGET_ROUNDS
		_flash_on = FLASH_ON
		_flash_gap = FLASH_GAP
		_pad_flash_scale = PAD_FLASH_SCALE
		if not challenge_mode:
			_gem_round_available = false

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# AUTOWRAP is load-bearing: without it the label's MIN WIDTH is the full text width,
	# which propagates up the containers and widens the whole card past the screen
	# (see CatchMoneyMinigame — the same bug put its coins off-screen, Tim 2026-07-08).
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	return clampf(float(_rounds_done) / float(_target_rounds), 0.0, 1.0)


func get_score() -> int:
	if challenge_mode:
		return _climbs_done
	return _rounds_done


func result_summary() -> String:
	return "Recalled %d of %d rounds" % [_rounds_done, _target_rounds]


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


const MEM_PAD_SEMITONES := [0, 4, 7, 12]


func _flash_pad(pad_id: int, lit: bool) -> void:
	if lit:
		Audio.play_pitched(&"mem_pad",
			pow(2.0, float(MEM_PAD_SEMITONES[pad_id % MEM_PAD_SEMITONES.size()]) / 12.0))
	var pad: Panel = _pads[pad_id]
	_style_pad(pad, pad_id, lit)
	pad.pivot_offset = pad.size / 2.0
	var target := Vector2(_pad_flash_scale, _pad_flash_scale) if lit else Vector2.ONE
	var bounce := create_tween()
	bounce.tween_property(pad, "scale", target, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The on-screen center of the pad board, in THIS minigame root's local coordinates — where a
## success chip should pop. The pads live in a GridContainer, so we read that grid's global rect
## and convert it into our own local space (we're the full-rect root the host adds us to).
## Falls back to our own center if the grid isn't laid out yet.
func _board_center() -> Vector2:
	if _pads.is_empty() or not is_instance_valid(_pads[0]):
		return size / 2.0
	var grid: Control = _pads[0].get_parent()
	var grid_global_center := grid.get_global_rect().get_center()
	return grid_global_center - get_global_rect().position


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
	await _playback_then_enable("Watch…")


## Shared tail for a round start (a fresh round, or the first round of a new Challenge climb after a
## reset): reset the input cursor, play the sequence back with input locked, then (if still running)
## hand the turn to the player.
func _playback_then_enable(watch_text: String) -> void:
	_input_index = 0
	_set_status(watch_text, UiPalette.MUSTARD_GOLD)
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
		await get_tree().create_timer(_flash_on).timeout
		if not _running or not is_inside_tree():
			return
		_flash_pad(pad_id, false)
		await get_tree().create_timer(_flash_gap).timeout


func _on_pad_input(event: InputEvent, pad_id: int) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _gem_round_active:
		_on_gem_pad_input(pad_id)
		return
	if not _accepting_input or not _running:
		return

	_flash_pad(pad_id, true)
	if is_inside_tree():
		get_tree().create_timer(0.15).timeout.connect(
			func() -> void:
				if is_instance_valid(_pads[pad_id]):
					_flash_pad(pad_id, false)
		)

	if pad_id != _sequence[_input_index]:
		_running = false
		_accepting_input = false
		_play_game_over_beat(pad_id)
		return

	_input_index += 1
	if _input_index >= _sequence.size():
		_rounds_done += 1
		_accepting_input = false
		if challenge_mode:
			if _sequence.size() >= _target_rounds:
				_climbs_done += 1
				_sequence.clear()
				_set_status("Climb %d complete — again!" % _climbs_done, UiPalette.MONEY_GREEN)
				FloatingChip.spawn(self, _board_center(), "CLIMB %d!" % _climbs_done, UiPalette.MUSTARD_GOLD)
			else:
				_set_status("Round %d cleared!" % _sequence.size(), UiPalette.MONEY_GREEN)
				FloatingChip.spawn(self, _board_center(), "CLEARED!", UiPalette.MONEY_GREEN)
			_start_round()
		elif _rounds_done >= _target_rounds:
			_running = false
			if _gem_round_available:
				banner_requested.emit("GEM ROUND", UiPalette.MUSTARD_GOLD, _begin_gem_round)
			else:
				_play_round_clear_celebration()
		else:
			Audio.play(&"mem_round")
			_set_status("Nice!", UiPalette.MONEY_GREEN)
			# Floating success chip over the board, matching Match-3's per-success feedback
			# (Tim, 2026-07-11 — every minigame shows success feedback like Match-3). A round
			# clear is a discrete event, so this can't spam like a per-tap chip would.
			FloatingChip.spawn(self, _board_center(), "ROUND CLEAR!", UiPalette.MONEY_GREEN)
			_start_round()


## Red game-over beat: shake the board and flash the mistaken pad red, then emit the result. The
## beat holds the host countdown (is_busy) so it is actually seen before the result appears.
func _play_game_over_beat(wrong_pad_id: int) -> void:
	_beat_playing = true
	Audio.play(&"mem_wrong")
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
	# Clearing every round is the exceptional success, so a GOLD chip (not the plain green round
	# chip) marks it — matching Match-3's bonus-gold cue (Tim, 2026-07-11 — every minigame shows
	# success feedback like Match-3).
	FloatingChip.spawn(self, _board_center(), "PERFECT!", UiPalette.MUSTARD_GOLD)

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


# ---------------------------------------------------------------------------
# Legacy bonus round (Plans/Legacy_Bonus_System.md)
# ---------------------------------------------------------------------------

## Begin the bonus round: make all four pads identical Legacy-gem tiles (so only POSITION can be
## recalled — no color crutch), build a longer random sequence, play it back, then hand the turn to
## the player. Reached only after a full clear on a run that rolled the gem chance in begin().
func _begin_gem_round() -> void:
	_gem_round_active = true
	for pad_id in range(_pads.size()):
		_make_gem_pad(_pads[pad_id])
	_gem_sequence.clear()
	for _i in range(_gem_length):
		_gem_sequence.append(_rng.randi_range(0, 3))
	_gem_input_index = 0
	await _play_gem_sequence()
	if not _gem_round_active or not is_inside_tree():
		return
	_gem_accepting_input = true
	_set_status("Your turn — %d taps for the gem" % _gem_sequence.size(), UiPalette.MUSTARD_GOLD)


## Dress a pad as a Legacy-gem tile: a cream face with a gold border wearing the gem image, added
## once. All four look the same, which is the whole point — the sequence must be held by position.
func _make_gem_pad(pad: Panel) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CREAM
	box.border_color = UiPalette.DARK_GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	pad.add_theme_stylebox_override("panel", box)
	if pad.get_node_or_null("GemIcon") == null:
		var icon := TextureRect.new()
		icon.name = "GemIcon"
		icon.texture = GEM_IMAGE
		# IGNORE_SIZE so the node's minimum size is NOT the SVG's (large) native pixel size — otherwise
		# that minimum overrides the anchor rect and the gem renders far bigger than the 240px pad. With
		# it 0, the anchors/offsets below control the rect and KEEP_ASPECT_CENTERED fits the gem inside.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps still reach the pad beneath
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Inset the gem inside the pad so a border of tile shows around it.
		icon.offset_left = 40.0
		icon.offset_top = 40.0
		icon.offset_right = -40.0
		icon.offset_bottom = -40.0
		pad.add_child(icon)


## Light a gem pad (brighter face + gold border) and bounce it, then restore on `lit` false — the
## gem-round equivalent of _flash_pad, which would otherwise repaint the pad its old solid color.
func _flash_gem_pad(pad_id: int, lit: bool) -> void:
	var pad: Panel = _pads[pad_id]
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CREAM.lightened(0.35) if lit else UiPalette.CREAM
	box.border_color = UiPalette.MUSTARD_GOLD if lit else UiPalette.DARK_GOLD
	box.set_border_width_all(8 if lit else 3)
	box.set_corner_radius_all(16)
	pad.add_theme_stylebox_override("panel", box)
	pad.pivot_offset = pad.size / 2.0
	var target := Vector2(PAD_FLASH_SCALE, PAD_FLASH_SCALE) if lit else Vector2.ONE
	var bounce := create_tween()
	bounce.tween_property(pad, "scale", target, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Play the bonus sequence back with input locked (mirrors _play_sequence, but over the gem pads and
## guarded on _gem_round_active). A slightly longer lead-in — this is the hard, deliberate one.
func _play_gem_sequence() -> void:
	_gem_accepting_input = false
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.5).timeout
	for pad_id in _gem_sequence:
		if not _gem_round_active or not is_inside_tree():
			return
		_flash_gem_pad(pad_id, true)
		await get_tree().create_timer(FLASH_ON).timeout
		if not _gem_round_active or not is_inside_tree():
			return
		_flash_gem_pad(pad_id, false)
		await get_tree().create_timer(FLASH_GAP).timeout


## A tap during the bonus round: give press feedback, then check it against the gem sequence. A wrong
## tap forfeits the gem (the main reward is already banked); completing the whole sequence collects it.
func _on_gem_pad_input(pad_id: int) -> void:
	if not _gem_accepting_input:
		return

	_flash_gem_pad(pad_id, true)
	if is_inside_tree():
		get_tree().create_timer(0.15).timeout.connect(
			func() -> void:
				if is_instance_valid(_pads[pad_id]) and _gem_round_active:
					_flash_gem_pad(pad_id, false)
		)

	if pad_id != _gem_sequence[_gem_input_index]:
		_gem_accepting_input = false
		_gem_round_active = false
		_play_gem_fail_beat()
		return

	_gem_input_index += 1
	if _gem_input_index >= _gem_sequence.size():
		# Whole bonus sequence recalled — the gem is earned (the host gates and grants the amount).
		_gem_accepting_input = false
		_gem_round_active = false
		collect_legacy_gem()
		Audio.play(&"mem_gem")
		_play_gem_success_celebration()


## Win beat: a gold ripple across the gem pads, then finish. Holds is_busy so the beat is seen even
## though the host has no countdown for this game (harmless there, correct if it ever gained one).
func _play_gem_success_celebration() -> void:
	_beat_playing = true
	_set_status("LEGACY GEM WON!", UiPalette.MUSTARD_GOLD)
	for pad_id in range(_pads.size()):
		if not is_inside_tree():
			break
		_flash_gem_pad(pad_id, true)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.4).timeout
	_beat_playing = false
	if is_inside_tree():
		completed.emit(get_performance())


## Miss beat: a brief "no gem" message, then finish. No penalty — the main reward was already banked
## on the full clear; the player simply doesn't get the bonus gem.
func _play_gem_fail_beat() -> void:
	_beat_playing = true
	_set_status("So close — no gem this time.", UiPalette.KETCHUP_RED)
	await get_tree().create_timer(0.7).timeout
	_beat_playing = false
	if is_inside_tree():
		completed.emit(get_performance())


## End-of-round wipe: the 4 board panels spin as a group and grow to fill the screen (Plans/Minigame_Polish_Pass.md §6.2).
func play_wipe(on_covered: Callable, on_complete: Callable) -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.z_index = 20
	add_child(container)

	var center := size / 2.0
	var spinner := Control.new()
	spinner.size = Vector2(300, 300)
	spinner.pivot_offset = spinner.size / 2.0
	spinner.position = center - spinner.size / 2.0
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(spinner)

	# Build 4 color quadrant pads (Red, Gold, Teal, Green)
	var half := 145.0
	var offsets := [
		Vector2(0, 0),
		Vector2(155, 0),
		Vector2(0, 155),
		Vector2(155, 155)
	]
	for i in range(4):
		var p := Panel.new()
		p.position = offsets[i]
		p.size = Vector2(half, half)
		var style := StyleBoxFlat.new()
		style.bg_color = PAD_COLORS[i]
		style.border_color = UiPalette.INK_NAVY
		style.set_border_width_all(6)
		style.set_corner_radius_all(16)
		p.add_theme_stylebox_override("panel", style)
		spinner.add_child(p)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(spinner, "scale", Vector2(10.0, 10.0), 0.38) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(spinner, "rotation", TAU, 0.38) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
	if on_covered.is_valid():
		on_covered.call()

	var fade := create_tween().set_parallel(true)
	fade.tween_property(spinner, "modulate:a", 0.0, 0.25)
	fade.tween_property(spinner, "scale", Vector2(14.0, 14.0), 0.25)
	await fade.finished
	container.queue_free()

	if on_complete.is_valid():
		on_complete.call()

