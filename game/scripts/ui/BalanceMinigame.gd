class_name BalanceMinigame
extends Minigame

# "Balance the Books" minigame TYPE (GDD §5.5) — REWORKED 2026-07-08 (Tim's call, work
# item 6): vertical, single-input, in the shape of Stardew Valley's fishing minigame.
# The old horizontal two-button version didn't work and lagged.
#
# One vertical track. HOLD the big button below the track to lift the marker; release
# and gravity pulls it back down. The gold zone drifts up and down the track on its own;
# keep the marker inside it and the score banks every moment it stays in. Performance
# is banked time-in-zone against the FIXED round length, so it only ever rises (see
# get_performance). It has no natural end — the host's countdown ends the round.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.

## Track positions run 0 (bottom) to 1 (top); the drawing flips to screen space.
const ZONE_HALF := 0.11          # half-height of the gold zone (track fraction)
## The single-input physics: holding accelerates the marker UP, gravity pulls it DOWN.
## LIFT beats GRAVITY (or holding forever couldn't climb); the margin between them and
## the damping set the game's tension. All first-pass values — feel-tune on device.
const LIFT_ACCEL := 3.0          # upward push while held (track-fractions / sec^2)
const GRAVITY := 1.9             # downward pull always (track-fractions / sec^2)
const DAMPING := 1.8             # velocity damping per second (keeps it controllable)
## Hitting the track's floor or ceiling bounces the marker back softly rather than
## sticking it there — the Stardew bobber "thunk" that punishes slamming an edge.
const EDGE_BOUNCE := 0.35

# The gold zone wanders: it eases toward a randomly re-rolled target center, so it
# slides smoothly rather than jumping. ZONE_EASE controls how quickly it catches up.
const ZONE_TARGET_CHANGE := 1.3  # seconds between new zone-target re-rolls
const ZONE_EASE := 1.6           # how fast the zone center eases toward its target (per sec)

## The vertical track's on-screen width.
const TRACK_WIDTH := 150.0
## The LIFT button's width. It sits to the RIGHT of the track and fills the play height, so it is a
## tall column (much taller than wide) — a large, easy hold target beside the bar (Tim, 2026-07-10).
const LIFT_BUTTON_WIDTH := 300.0

# --- Legacy gem (Plans/Legacy_Bonus_System.md) --------------------------------
# Full Stardew: a legacy gem may appear pinned to the gold zone. Hold the marker in
# the zone to fill a SEPARATE gem-progress bar; drift out and it drains (slower than
# it fills). Fill it and you keep the gem (collect_legacy_gem). This progress is
# wholly separate from the round score / time-in-zone — it never touches performance.
## Seconds of in-zone holding to fill the gem bar from empty to full.
const GEM_FILL_SECONDS := 2.2
## Seconds to drain a full bar back to empty while OUT of the zone — deliberately
## slower than the fill so a brief slip doesn't erase all your progress (Stardew feel).
const GEM_DRAIN_SECONDS := 4.5
## Wait after the round starts before rolling whether a gem appears, so the player has
## a beat to settle into the zone before the bonus shows up (rolled once per round).
const GEM_ROLL_DELAY := 1.2
## The gem icon's on-screen size where it's pinned beside the gold zone.
const GEM_ICON_SIZE := 52.0

# --- Success feedback chips ---------------------------------------------------
# Tim, 2026-07-11 — every minigame shows context-specific success feedback like Match-3
# does. This game banks time-in-zone continuously, so there is no single "catch complete"
# moment; a per-entry "in the zone" chip was too noisy (Tim, 2026-07-11), so we only pop a
# gold chip as banked performance crosses milestones (the round adding up), each fired once.
## Banked-performance fractions that each earn a one-time gold "banking" chip.
const PERFORMANCE_MILESTONES := [0.25, 0.5, 0.75, 1.0]
## The short label shown for each milestone, matched by index to PERFORMANCE_MILESTONES.
const MILESTONE_LABELS := ["BANKING!", "HALFWAY!", "ALMOST!", "BALANCED!"]

## The legacy gem currency art, drawn beside the zone as the "hold here to collect" cue.
const LEGACY_GEM_TEXTURE := preload("res://art/icons/legacy_gem.svg")

var _pos: float = 0.25           # marker position, 0 = bottom (it starts resting low)
var _vel: float = 0.0
var _held: bool = false
var _time_in_zone: float = 0.0
## Whether the beam was inside the scoring zone last frame, so the crossing cues fire on the EDGE
## rather than every frame it happens to be inside.
var _was_in_zone := false
var _total_round_seconds: float = 1.0  # fixed performance denominator (set in begin)
var _zone_center: float = 0.6          # current center of the gold zone (wanders)
var _zone_target: float = 0.6          # center the zone is currently easing toward
var _zone_timer: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _track: Control
var _lift_button: Button

# A single accumulated phase drives every continuous pulse (the in-zone marker bounce +
# the zone-boundary warning glow) from _draw_track — per the standing rule, continuous
# pulses run off a phase float, not tweens.
var _pulse_phase: float = 0.0
# The marker's position one frame ago, so _draw_track can stretch a short motion trail
# behind it and the marker stays easy to follow as it moves.
var _prev_pos: float = 0.25

# --- Balance physics & geometry tunable fields ---
var _zone_half: float = ZONE_HALF
var _lift_accel: float = LIFT_ACCEL
var _gravity: float = GRAVITY
var _damping: float = DAMPING
var _edge_bounce: float = EDGE_BOUNCE
var _gem_fill_seconds: float = GEM_FILL_SECONDS
var _gem_drain_seconds: float = GEM_DRAIN_SECONDS

# --- Challenge-mode knobs (captured from tuning in begin(); USED ONLY in challenge mode) ------
# The prestige/reward round keeps the module constants above (ZONE_TARGET_CHANGE / ZONE_EASE, one
# point per whole second); these live-tunable values shape only the CHALLENGE round's feel, so the
# reward round stays byte-for-byte unchanged. Defaults mirror the constants / tuning.tres.
## In-zone seconds to earn one challenge point (get_score = time-in-zone / this).
var _challenge_seconds_per_point: float = 1.0
## Seconds between the gold zone re-rolling a new target center (challenge mode).
var _challenge_zone_reroll_seconds: float = ZONE_TARGET_CHANGE
## How fast the gold zone eases toward its target center, per second (challenge mode).
var _challenge_zone_ease: float = ZONE_EASE

# --- Legacy gem state ---------------------------------------------------------
## The spawn chance captured from tuning in begin() (0..1). Rolled once per round.
var _gem_chance: float = 0.0
## Counts down GEM_ROLL_DELAY at round start, then we roll _gem_active once. -1 = rolled.
var _gem_roll_timer: float = 0.0
## True while a legacy gem exists on the zone waiting to be collected.
var _gem_active: bool = false
## Gem-progress in [0,1] — fills while in-zone, drains while out. SEPARATE from the score.
var _gem_progress: float = 0.0
## Set for a short cue after the bar fills and the gem is collected, so the win reads.
var _gem_won_flash: float = 0.0

# --- Success feedback state ---------------------------------------------------
## How many performance milestones we've already celebrated, so each fires exactly once.
var _milestones_shown: int = 0


func display_name() -> String:
	return "Balance the Books"


func how_to_play() -> String:
	return "Hold the LIFT button to raise the marker; let go and it falls. Keep it " \
		+ "inside the drifting gold zone — the books balance every moment it stays in."


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	_pos = 0.25
	_prev_pos = _pos
	_pulse_phase = 0.0
	# Bank time-in-zone against the whole round, so the host's spectrum bar starts empty
	# and only climbs while the marker is in the zone (it never falls back).
	_total_round_seconds = maxf(0.1, tuning.minigame_duration_seconds) if tuning != null else 25.0

	if tuning != null:
		_zone_half = clampf(tuning.balance_zone_half, 0.02, 0.5)
		_lift_accel = maxf(0.1, tuning.balance_lift_accel)
		_gravity = maxf(0.1, tuning.balance_gravity)
		_damping = maxf(0.0, tuning.balance_damping)
		_edge_bounce = clampf(tuning.balance_edge_bounce, 0.0, 1.0)
		_gem_fill_seconds = maxf(0.1, tuning.balance_gem_fill_seconds)
		_gem_drain_seconds = maxf(0.1, tuning.balance_gem_drain_seconds)
		_gem_chance = clampf(tuning.legacy_gem_chance_balance, 0.0, 1.0)
		_challenge_seconds_per_point = maxf(0.01, tuning.balance_seconds_per_point)
		_challenge_zone_reroll_seconds = tuning.balance_zone_reroll_seconds
		_challenge_zone_ease = tuning.balance_zone_ease

	_gem_roll_timer = GEM_ROLL_DELAY
	_gem_active = false
	_gem_progress = 0.0
	_gem_won_flash = 0.0
	_milestones_shown = 0

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# AUTOWRAP is load-bearing (see CatchMoneyMinigame): without it the label's min
	# width propagates up and widens the whole card past the screen.
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The vertical track, centered horizontally, taking all the leftover height.
	_track = Control.new()
	_track.custom_minimum_size = Vector2(TRACK_WIDTH, 0)
	_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)

	# The single input: one big hold button to the RIGHT of the track, matching how every other
	# minigame takes input through a dedicated control. It fills the play height (EXPAND_FILL), so it
	# is a tall column — taller than wide — giving a large, easy hold target beside the bar (Tim,
	# 2026-07-10). button_down/button_up (not pressed) because "held" is the state that matters.
	_lift_button = Button.new()
	_lift_button.text = "HOLD TO LIFT"
	_lift_button.custom_minimum_size = Vector2(LIFT_BUTTON_WIDTH, 0)
	_lift_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lift_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lift_button.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_lift_button.focus_mode = Control.FOCUS_NONE
	UiPalette.style_button(_lift_button, true)
	_lift_button.button_down.connect(_on_lift_button_down)
	_lift_button.button_up.connect(_on_lift_button_up)

	# Track on the LEFT, the tall LIFT button to its RIGHT, centered as a pair (Tim, 2026-07-10).
	var play_row := HBoxContainer.new()
	play_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 28)
	play_row.add_child(_track)
	play_row.add_child(_lift_button)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	column.add_child(intro)
	column.add_child(play_row)
	add_child(column)


func _on_lift_button_down() -> void:
	Audio.play(&"bal_lift")
	_held = true


func _on_lift_button_up() -> void:
	_held = false


func get_performance() -> float:
	# Fixed denominator (the round length), not elapsed time, so the meter rises
	# monotonically from empty. Staying in the zone the whole round reaches ~1.0.
	# NOTE: this is the NORMAL-mode reward metric; Challenge Mode uses get_score().
	return clampf(_time_in_zone / _total_round_seconds, 0.0, 1.0)


func get_score() -> int:
	# Challenge Mode's raw score: one point per _challenge_seconds_per_point whole seconds spent IN the
	# gold zone this run (the knob lets Tim slow or speed the point rate on device). _time_in_zone only
	# ever grows, so this is cumulative and non-decreasing as the host samples it live. Reward mode never
	# reads get_score(), but keep it on the plain 1-point-per-second form there so nothing changes.
	if challenge_mode:
		return int(_time_in_zone / _challenge_seconds_per_point)
	return int(_time_in_zone)


func result_summary() -> String:
	return "Balanced %d%% of the time" % int(round(get_performance() * 100.0))


func _process(delta: float) -> void:
	if not _running:
		return

	# Advance the shared pulse clock (in-zone bounce + boundary warning glow).
	_pulse_phase += delta

	# Slide the gold zone: re-roll a new target center now and then, and ease the live
	# center toward it each frame so the zone glides smoothly instead of snapping.
	# Targets stay fully on the track so the whole zone is always reachable.
	# Challenge mode uses the live-tuned wander (reroll cadence + ease); reward mode keeps the module
	# constants, so the prestige round is unchanged.
	var reroll_seconds := _challenge_zone_reroll_seconds if challenge_mode else ZONE_TARGET_CHANGE
	var zone_ease := _challenge_zone_ease if challenge_mode else ZONE_EASE
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_target = _rng.randf_range(_zone_half, 1.0 - _zone_half)
		_zone_timer = reroll_seconds
	_zone_center += (_zone_target - _zone_center) * minf(1.0, zone_ease * delta)
	_zone_center = clampf(_zone_center, _zone_half, 1.0 - _zone_half)

	# The bobber physics: lift while held, gravity always, damped so it stays readable.
	var accel := (_lift_accel if _held else 0.0) - _gravity
	_vel += accel * delta
	_vel *= maxf(0.0, 1.0 - _damping * delta)
	_prev_pos = _pos
	_pos += _vel * delta
	# Soft bounce off the floor and ceiling — slamming an edge costs the momentum.
	if _pos <= 0.0:
		_pos = 0.0
		_vel = absf(_vel) * _edge_bounce
	elif _pos >= 1.0:
		_pos = 1.0
		_vel = -absf(_vel) * _edge_bounce

	var in_zone := absf(_pos - _zone_center) <= _zone_half
	if in_zone != _was_in_zone:
		Audio.play(&"bal_enter" if in_zone else &"bal_leave")
		_was_in_zone = in_zone
	if in_zone:
		_time_in_zone += delta

	_update_legacy_gem(delta, in_zone)

	_update_success_chips()

	if _track != null:
		_track.queue_redraw()


## Pop a gold "banking" chip the first time banked performance crosses each milestone.
func _update_success_chips() -> void:
	if _track == null:
		return

	var performance := get_performance()
	while (_milestones_shown < PERFORMANCE_MILESTONES.size()
			and performance >= PERFORMANCE_MILESTONES[_milestones_shown]):
		var zone_spot := Vector2(_track.size.x * 0.5, _to_screen_y(_zone_center))
		FloatingChip.spawn(_track, zone_spot, MILESTONE_LABELS[_milestones_shown],
				UiPalette.MUSTARD_GOLD)
		_milestones_shown += 1


func _update_legacy_gem(delta: float, in_zone: bool) -> void:
	if _gem_won_flash > 0.0:
		_gem_won_flash = maxf(0.0, _gem_won_flash - delta)

	if _gem_roll_timer >= 0.0:
		_gem_roll_timer -= delta
		if _gem_roll_timer < 0.0:
			_gem_active = not legacy_bonus_secured() and _rng.randf() < _gem_chance
		return

	if not _gem_active:
		return

	if in_zone:
		_gem_progress = minf(1.0, _gem_progress + delta / _gem_fill_seconds)
	else:
		_gem_progress = maxf(0.0, _gem_progress - delta / _gem_drain_seconds)

	if _gem_progress >= 1.0:
		# Bar full — bank the gem (host gates/grants it), clear it, and flash a win cue.
		collect_legacy_gem()
		Audio.play(&"bal_gem")
		_gem_active = false
		_gem_progress = 0.0
		_gem_won_flash = 0.9


## Track-space (0 bottom … 1 top) to screen y within the track control.
func _to_screen_y(track_value: float) -> float:
	return (1.0 - track_value) * _track.size.y


func _draw_track() -> void:
	var w := _track.size.x
	var h := _track.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_track.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)

	# How close the marker sits to the edge of the gold zone: 0 = dead center, 1 = at
	# the edge. Drives the boundary warning glow so the zone "lights up" before the
	# marker actually falls out.
	var edge_proximity := clampf(absf(_pos - _zone_center) / ZONE_HALF, 0.0, 1.0)
	var in_zone := edge_proximity < 1.0

	# The gold zone body, drawn at its live (wandering) center so it always matches the
	# _process hit test. Screen y comes from the zone's TOP edge (center + half, flipped).
	var zone_y := _to_screen_y(_zone_center + ZONE_HALF)
	var zone_h := (ZONE_HALF * 2.0) * h
	_track.draw_rect(Rect2(0, zone_y, w, zone_h), UiPalette.MUSTARD_GOLD)

	# CHALLENGE MODE: the "charge to the next point" gauge, drawn INSIDE the gold zone so the player
	# reads it right where they hold the marker (Tim, 2026-07-22). get_score() banks one point per whole
	# second in-zone, so the fraction toward the next second fills the band left→right. It advances ONLY
	# while in-zone (_time_in_zone pauses out of zone) and never drains — a truthful "this much more
	# in-zone time to the next point," matching the monotonic score. Drawn before the edges/marker so
	# they stay on top.
	if challenge_mode:
		# Fraction toward the next point: get_score() banks one point per _challenge_seconds_per_point
		# in-zone seconds, so the gauge fills over that same span (frac of time_in_zone / seconds_per_point).
		var scaled_progress: float = _time_in_zone / _challenge_seconds_per_point
		var point_progress: float = scaled_progress - floorf(scaled_progress)
		var charge_w := w * point_progress
		# A THIN gauge inside the zone — ~20% of the zone height, sitting ~20% up from the zone's bottom
		# (Tim, 2026-07-22) — so it reads without covering the whole target.
		var gauge_h := zone_h * 0.2
		var gauge_y := zone_y + zone_h * 0.6
		_track.draw_rect(Rect2(0, gauge_y, charge_w, gauge_h), UiPalette.CREAM)
		if charge_w >= 2.0:
			# A bright leading edge so the charging front is easy to track as it sweeps toward the point.
			_track.draw_rect(Rect2(charge_w - 3.0, gauge_y, 3.0, gauge_h), Color.WHITE)

	# Boundary warning: the zone's top/bottom edges brighten toward white (and thicken)
	# as the marker nears them, pulsing on the shared phase — an early "about to fall
	# out" cue rather than only the marker flipping red at the last instant.
	var pulse := 0.5 + 0.5 * sin(_pulse_phase * 9.0)
	var edge_glow := edge_proximity * (0.55 + 0.45 * pulse)
	var edge_color := UiPalette.MUSTARD_GOLD.lerp(Color.WHITE, edge_glow)
	var edge_thickness := 3.0 + 6.0 * edge_proximity
	_track.draw_rect(Rect2(0, zone_y, w, edge_thickness), edge_color)
	_track.draw_rect(Rect2(0, zone_y + zone_h - edge_thickness, w, edge_thickness), edge_color)

	# Legacy gem: when one is active, pin its icon at the zone center as a "hold here to
	# collect it" cue, with a thin vertical progress bar beside it that fills in-zone and
	# drains out. Drawn under the marker so the marker still reads on top. Separate from
	# the round score entirely — this only visualizes _gem_progress.
	if _gem_active:
		var gem_cy := _to_screen_y(_zone_center)
		# The gem icon, centered on the zone. A gentle in-zone shimmer nudges the player to
		# stay put; a steady icon when out. Sits slightly left so the bar has room on the right.
		var gem_shimmer := (0.5 + 0.5 * sin(_pulse_phase * 6.0)) if in_zone else 0.0
		var gem_size := GEM_ICON_SIZE * (1.0 + 0.10 * gem_shimmer)
		var gem_x := w * 0.5 - gem_size * 0.5 - 14.0
		_track.draw_texture_rect(
			LEGACY_GEM_TEXTURE,
			Rect2(gem_x, gem_cy - gem_size * 0.5, gem_size, gem_size),
			false)

		# The gem-progress bar: a vertical track to the right of the icon that fills from the
		# bottom up. White fill over a dark trough so the fill/drain is unmistakable.
		var bar_w := 16.0
		var bar_h := GEM_ICON_SIZE * 1.4
		var bar_x := gem_x + gem_size + 10.0
		var bar_y := gem_cy - bar_h * 0.5
		_track.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0, 0, 0, 0.5))
		var fill_h := bar_h * clampf(_gem_progress, 0.0, 1.0)
		_track.draw_rect(Rect2(bar_x, bar_y + bar_h - fill_h, bar_w, fill_h), Color.WHITE)
		_track.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), UiPalette.MUSTARD_GOLD, false, 2.0)

	# A brief bright wash across the whole track right after the gem is collected, so the
	# win reads even though the icon has already cleared.
	if _gem_won_flash > 0.0:
		_track.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.5 * _gem_won_flash))

	# Marker: a horizontal band — green in-zone, red out — with a drop shadow + motion
	# trail so it tracks easily, gently bouncing (size pulse) while safely in the zone.
	# Out of the zone it holds steady red so "you're out" reads as a hard state.
	var marker_color := UiPalette.MONEY_GREEN if in_zone else UiPalette.KETCHUP_RED
	var bounce := (0.5 + 0.5 * sin(_pulse_phase * 7.0)) if in_zone else 0.0
	var marker_h := 24.0 * (1.0 + 0.18 * bounce)
	var marker_w := w * (0.86 + 0.14 * bounce)
	var marker_y := _to_screen_y(_pos)
	var marker_left := (w - marker_w) * 0.5

	# Motion trail: a translucent band stretched from the marker's previous spot to its
	# current one, so a fast rise or fall leaves a readable streak.
	var trail_color := marker_color
	trail_color.a = 0.35
	var trail_top := minf(_to_screen_y(_prev_pos), marker_y) - marker_h * 0.5
	var trail_bottom := maxf(_to_screen_y(_prev_pos), marker_y) + marker_h * 0.5
	_track.draw_rect(Rect2(marker_left, trail_top, marker_w, trail_bottom - trail_top), trail_color)

	# Drop shadow, offset down-right, then the body and a bright center line so the
	# marker reads crisp and high-contrast at arm's length.
	_track.draw_rect(Rect2(marker_left + 3.0, marker_y - marker_h * 0.5 + 3.0, marker_w, marker_h), Color(0, 0, 0, 0.35))
	_track.draw_rect(Rect2(marker_left, marker_y - marker_h * 0.5, marker_w, marker_h), marker_color)
	_track.draw_rect(Rect2(marker_left, marker_y - 2.0, marker_w, 4.0), marker_color.lerp(Color.WHITE, 0.6))

	_track.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
