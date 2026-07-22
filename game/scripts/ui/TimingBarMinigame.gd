class_name TimingBarMinigame
extends Minigame

# The timing-bar minigame TYPE (GDD §5.5) — a quick precision game, the second entry in the
# library so the host's random draw has variety. A marker sweeps back and forth across a
# bar; the player taps LOCK to catch it inside the gold zone. The zone JUMPS to a new random
# spot after every successful lock and slowly SHRINKS (down to half its width) as locks pile
# up, so it gets harder. A miss just wastes time — the host countdown keeps running (a miss is
# never charged a lock; that yo-yoing count only confused players, Tim 2026-07-11) and scores
# nothing. Each successful lock scores accuracy in [0,1]; landing TARGET_LOCKS locks ends the
# round early, otherwise the host's countdown ends it. The lock count only ever climbs, shown as
# fill-only pips above the bar. Performance = average accuracy over TARGET_LOCKS (a never-made
# lock counts as zero, so you must keep landing them, not just nail one).
#
# Owns only its gameplay; the host owns the countdown / spectrum / result / multiplier.

## How many successful locks make a full game (and the denominator for performance).
## Tuned down from 12 to 10 for the shorter ~20s round: each lock now also pauses for a 0.5s
## freeze-burst (which does NOT count against the countdown), so 10 keeps a full game feasible
## inside ~20s of active play while still demanding a steady streak of good taps.
const TARGET_LOCKS := 10
## How long (seconds) each LOCK press freezes the marker/zone to show a hit-or-miss burst.
## The freeze pauses the host countdown (see is_busy()), so it is never charged to the player.
const FREEZE_TIME := 0.5
## Half-width of the gold "perfect" zone, as a fraction of the bar, at the START of the game.
const ZONE_HALF := 0.12
## Smallest the zone's half-width shrinks to (reached at TARGET_LOCKS).
## UN-PLAYTESTED (polish pass 2026-06-29 "harder" direction): steepened from half the start width
## (0.06) to 0.375× the start (0.045) so the late-game zone is genuinely tight. Confirm on device.
const ZONE_HALF_MIN := ZONE_HALF * 0.375
## Marker sweep speed (bar-fractions per second) and how much it ramps each lock. NORMAL MODE ONLY —
## Challenge Mode uses its own gentle per-lock step (see CHALLENGE_SPEED_* below) so its endless run
## rises slowly and predictably instead of ratcheting up on the normal-mode multiplier.
const BASE_SPEED := 0.9
## UN-PLAYTESTED (polish pass 2026-06-29 "harder" direction): ramp steepened 1.06 -> 1.09 so the
## marker speeds up more noticeably each lock. Paired with the unchanged TARGET_LOCKS of 10 — the
## whole "harder" feel (tighter zone + faster sweep at the same lock count) needs a device check.
const SPEED_RAMP := 1.09
## Seconds a click-feedback line lingers before it has fully faded out.
const CLICK_MARK_FADE := 2.0
## How long (seconds) the fading "previous size" outline lingers after the zone shrinks+jumps, so
## the player can SEE it got smaller (the shrink was invisible until felt before).
const ZONE_GHOST_TIME := 0.5

## --- Challenge Mode: calm, predictable difficulty (Tim playtest 2026-07-21) --------------------------
## The previous pass made Challenge Mode too chaotic — fast oscillating zone-size/speed waves, an
## erratic marker that surged/paused/reversed, and a zone that re-rolled its drift direction at random.
## Tim wants it CALM and PREDICTABLE instead: the marker sweeps at a STEADY speed that only nudges up a
## little after each lock; the zone size drifts SLOWLY between modest bounds; and the zone slides along
## the bar SLOWLY, only reversing when it hits a track edge (a clean bounce, never a random re-roll).
## Everything below is gated on challenge_mode; normal (reward/prestige) play is untouched.
## ALL VALUES FIRST-PASS — DEVICE-TUNE (feel is device-only).

## Marker speed in Challenge Mode: it slowly RISES AND FALLS over many LOCKS (a lock-based wave) across
## the SAME speed range regular mode sweeps — from BASE_SPEED up to its top speed after TARGET_LOCKS of
## SPEED_RAMP (Tim, 2026-07-22: it needs to reach regular mode's fast end, not just creep slowly). The
## range is computed in _challenge_marker_speed. Sampled once per lock, so speed is steady per sweep.
const CHALLENGE_SPEED_PERIOD_LOCKS := 14.0           # locks for one slow fast -> slow -> fast cycle

## Zone half-width in Challenge Mode: a slow grow/shrink between these modest bounds, waving over many
## LOCKS (not seconds). The long lock-period keeps it a gentle drift, never a fast bounce. Sampled once
## per lock (in _move_zone), so the zone holds a steady size through each freeze.
const CHALLENGE_ZONE_WIDE := ZONE_HALF               # widest (easiest) the challenge zone ever gets
const CHALLENGE_ZONE_NARROW := ZONE_HALF * 0.7       # narrowest (hardest) — a modest shrink, not tiny
const CHALLENGE_ZONE_PERIOD_LOCKS := 16.0            # locks for one slow wide -> narrow -> wide cycle

## Zone drift in Challenge Mode: the gold zone glides along the bar. It reverses at the ends (a clean
## edge bounce) AND flips direction every few locks (Tim, 2026-07-21). Its glide SPEED visibly rises
## and falls over SECONDS (Tim, 2026-07-22) — speeding up and slowing as it travels, rather than one
## static rate. Still far slower than the marker in absolute terms. See _challenge_zone_drift_speed.
const CHALLENGE_ZONE_DRIFT_MID := 0.08               # centre glide speed (bar-fractions per second)
const CHALLENGE_ZONE_DRIFT_AMP := 0.045              # rise/fall swing — visible, still gentler than the marker
const CHALLENGE_ZONE_DRIFT_PERIOD_SECONDS := 7.0     # seconds for one slow -> fast -> slow drift cycle
const CHALLENGE_ZONE_FLIP_LOCKS_MIN := 3             # fewest locks before the drift direction flips
const CHALLENGE_ZONE_FLIP_LOCKS_MAX := 5             # most locks before the drift direction flips

## --- Lock-count pips (normal mode) --- One dot per lock, drawn above the bar (see _draw_lock_pips).
const PIP_RADIUS := 9.0        # dot radius
const PIP_GAP := 12.0          # empty space between adjacent dots
const PIP_RIM_WIDTH := 3.0     # navy outline thickness so a dot reads on the light background
const PIP_ROW_HEIGHT := 30.0   # height of the pip row control

var _marker_pos: float = 0.0
var _marker_dir: float = 1.0
var _marker_speed: float = BASE_SPEED
## Challenge Mode: which way the gold zone is currently drifting (+1 right, -1 left). Flips on an edge
## bounce (see _process) AND every few locks (see _on_lock / _locks_until_flip).
var _zone_drift_dir: float = 1.0
## Challenge Mode: successful locks left before the drift direction flips; re-rolled to a random
## CHALLENGE_ZONE_FLIP_LOCKS_MIN..MAX after each flip.
var _locks_until_flip: int = CHALLENGE_ZONE_FLIP_LOCKS_MIN
## Challenge Mode: seconds of active sweeping (pauses during a freeze), the clock the zone's glide-speed
## wave rides so the speed change is visible within a run.
var _challenge_drift_time: float = 0.0
var _locks: int = 0
## Successful locks made this run — Challenge Mode's cumulative high-score metric. Unlike `_locks`
## (which a miss decrements as the normal-mode −1 penalty), this ONLY ever increases, once per good
## lock, so get_score() can report a non-decreasing score the host samples live in Challenge Mode.
var _success_count: int = 0
var _accuracy_sum: float = 0.0
var _running: bool = false
var _flash: float = 0.0       # brief cream highlight after a successful lock, decays in _process
var _miss_flash: float = 0.0  # brief red highlight after a missed click, decays in _process
var _zone_center: float = 0.5  # current center of the gold zone (bar fraction); jumps each lock
## Displayed half-width of the gold zone. Refreshed ONLY in _move_zone (which runs after the freeze),
## never straight from _current_zone_half(), so a hit doesn't visibly shrink the zone mid-freeze — the
## zone holds its pre-hit size through the whole result freeze and only shrinks+jumps once it ends
## (Tim, 2026-07-11). _current_zone_half() is the target size for the live lock count; this is what's
## actually drawn until the next _move_zone applies it.
var _zone_half: float = ZONE_HALF
## Freeze-burst state. While _freeze_left > 0 the marker and zone hold still, a hit/miss burst
## is drawn, and is_busy() is true so the host pauses its countdown for the duration.
var _freeze_left: float = 0.0
var _freeze_success: bool = false  # true -> draw the white/gold "hit" burst; false -> gray "miss" burst
## Set when the FINAL lock lands: we keep running through that lock's freeze so its success burst
## is visible, then emit completed once the freeze ends (see _on_freeze_ended).
var _finish_after_freeze: bool = false
## Click-feedback lines left where each click landed; each is {pos, age, hit} and fades over
## CLICK_MARK_FADE seconds so the player can see exactly where their taps were perceived. `hit`
## colors the line green (a scored lock) or red (a wasted, lock-costing miss).
var _click_marks: Array = []
## Fading "previous size" outline drawn when the zone shrinks+jumps, so the shrink is visible.
## _zone_ghost_half is the OLD (larger) half-width; _zone_ghost_left counts down ZONE_GHOST_TIME.
var _zone_ghost_half: float = 0.0
var _zone_ghost_left: float = 0.0

# --- Legacy gem (Plans/Legacy_Bonus_System.md) -------------------------------
## Chance, per successful lock, that a legacy gem appears in the center of the NEXT target zone
## (from tuning.legacy_gem_chance_timing). Only one gem opportunity is ever active at a time.
var _legacy_gem_chance: float = 0.0
## True while a legacy gem is sitting in the zone waiting to be grabbed. The player's next lock
## consumes it: a hit collects it, a miss loses it (see _on_lock). Drawn at _legacy_gem_center.
var _legacy_gem_active: bool = false
## Bar-fraction center of the pending legacy gem (always the zone center it spawned in).
var _legacy_gem_center: float = 0.5
## Brief gold "you grabbed it" burst after a legacy gem is collected, decays in _process like _flash.
var _legacy_win_flash: float = 0.0
## Brief gray "it slipped away" cue after a gem is LOST to a missed lock, so a lost gem is never
## invisible (Tim, 2026-07-11 — a gem was vanishing with no indication). Decays like _legacy_win_flash.
var _legacy_lost_flash: float = 0.0
## The legacy gem art, drawn centered in the target zone as a "grab this on your next lock" cue.
const LEGACY_GEM_TEXTURE = preload("res://art/icons/legacy_gem.svg")

var _rng := RandomNumberGenerator.new()

var _bar: Control
## Normal mode shows the lock count as fill-only pips above the bar (a dot per lock, filled as you
## land them, never emptied). Challenge Mode is endless with no 10-lock target, so it keeps a plain
## running-count label instead. Exactly one of these is shown, chosen in begin() by the mode.
var _lock_pips: Control
var _locks_label: Label


func display_name() -> String:
	return "Timing Bar"


func how_to_play() -> String:
	return "Tap LOCK as the sweeping marker crosses the gold zone — dead center pays " \
		+ "best, and the zone shrinks after every hit."


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_marker_pos = 0.0
	_marker_dir = 1.0
	_success_count = 0
	# Challenge Mode's sweep speed rides a slow lock-based wave across regular mode's speed range
	# (starts at the wave's centre); normal mode starts at BASE_SPEED and ×SPEED_RAMP per lock.
	_marker_speed = _challenge_marker_speed() if challenge_mode else BASE_SPEED
	_zone_drift_dir = 1.0
	_locks_until_flip = _rng.randi_range(CHALLENGE_ZONE_FLIP_LOCKS_MIN, CHALLENGE_ZONE_FLIP_LOCKS_MAX)
	_challenge_drift_time = 0.0
	_locks = 0
	_accuracy_sum = 0.0
	_running = true
	# Live legacy-gem spawn chance so Balance Tuning edits take effect next round. No gem is
	# active until a successful lock rolls one into the next zone (see _on_freeze_ended).
	_legacy_gem_chance = tuning.legacy_gem_chance_timing
	_legacy_gem_active = false
	_move_zone()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)
	column.add_child(intro)

	# Lock count sits ABOVE the game bar (Tim, 2026-07-10). Normal mode draws it as fill-only pips
	# (one per lock, filled as you land them); Challenge Mode is endless, so it shows a plain running
	# count instead. Only the mode's control is added.
	if challenge_mode:
		_locks_label = Label.new()
		_locks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_locks_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
		_locks_label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
		column.add_child(_locks_label)
	else:
		_lock_pips = Control.new()
		_lock_pips.custom_minimum_size = Vector2(0, PIP_ROW_HEIGHT)
		_lock_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lock_pips.draw.connect(_draw_lock_pips)
		column.add_child(_lock_pips)
	_update_locks_label()

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 96)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)

	var lock_button := Button.new()
	lock_button.text = "LOCK"
	# 50% taller than the old 110px (Tim, 2026-07-10) — the minigame's dedicated action button
	# should be a big, easy target (matches our large-tappable-button guidance).
	lock_button.custom_minimum_size = Vector2(0, 165)
	UiPalette.style_button(lock_button, true)  # red: the act button
	lock_button.pressed.connect(_on_lock)
	column.add_child(lock_button)


func get_performance() -> float:
	return clampf(_accuracy_sum / float(TARGET_LOCKS), 0.0, 1.0)


## Challenge Mode's raw score: how many successful (in-the-gold-zone) locks the player has made this
## run. Non-decreasing — misses don't count and never subtract. The host only reads this in Challenge
## Mode; in normal mode it's harmless to return the same tally.
func get_score() -> int:
	return _success_count


func result_summary() -> String:
	return "Locked %d of %d" % [_locks, TARGET_LOCKS]


## True only during a freeze-burst; the host pauses its countdown so the 0.5s freeze (and its
## animation) is not charged against the player's time.
func is_busy() -> bool:
	return _freeze_left > 0.0


func _process(delta: float) -> void:
	# While frozen: hold the marker and zone exactly where they are, only count the freeze down
	# and redraw so the burst animates. We deliberately do NOT age _flash / _miss_flash / click
	# marks here — they simply pause and resume their decay once the freeze ends, which keeps
	# this branch dead simple.
	if _freeze_left > 0.0:
		_freeze_left = maxf(0.0, _freeze_left - delta)
		if _bar != null:
			_bar.queue_redraw()
		if _freeze_left <= 0.0:
			_on_freeze_ended()
		return
	if not _running:
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	_miss_flash = maxf(0.0, _miss_flash - delta * 4.0)
	_legacy_win_flash = maxf(0.0, _legacy_win_flash - delta * 2.0)  # slower fade so the grab reads
	_legacy_lost_flash = maxf(0.0, _legacy_lost_flash - delta * 2.0)  # same pace so the loss reads too
	# Age the click-feedback lines and drop any that have fully faded — removed in-place,
	# walking backward, instead of filter() rebuilding the array every frame (minigame
	# lag pass, Tim 2026-07-06).
	for i in range(_click_marks.size() - 1, -1, -1):
		var mark: Dictionary = _click_marks[i]
		mark["age"] += delta
		if mark["age"] >= CLICK_MARK_FADE:
			_click_marks.remove_at(i)
	# Fade the "it just shrank" outline.
	_zone_ghost_left = maxf(0.0, _zone_ghost_left - delta)
	# Challenge Mode: advance the size-drift clock and slide the gold zone. Done here (after the freeze
	# guard returned above) so both PAUSE during a freeze-burst, keeping the size phase and the zone
	# position frozen while a hit/miss is shown — exactly like the marker.
	if challenge_mode:
		_challenge_drift_time += delta  # advance the glide-speed wave's clock (pauses during a freeze)
		# Slowly slide the zone, cleanly bouncing off the ends so the whole zone stays on the bar (center
		# kept within one half-width of either edge, the same safe range _move_zone uses when it jumps).
		# The direction only ever flips at an edge — a steady, predictable glide, never a random re-roll.
		_zone_center += _zone_drift_dir * _challenge_zone_drift_speed() * delta
		var min_center := _zone_half
		var max_center := 1.0 - _zone_half
		if _zone_center <= min_center:
			_zone_center = min_center
			_zone_drift_dir = 1.0
		elif _zone_center >= max_center:
			_zone_center = max_center
			_zone_drift_dir = -1.0
		# Keep a pending legacy gem riding the center of the drifting zone, so it never detaches from
		# the target it's meant to sit in. (Hit-scoring for the gem is position-independent — any hit
		# collects it — so this is purely to keep the cue visually attached.)
		if _legacy_gem_active:
			_legacy_gem_center = _zone_center
	# Advance the marker at its steady sweep speed. Both modes hold _marker_speed constant within a
	# sweep; it only changes per lock (normal: ×SPEED_RAMP; challenge: resampled from the speed wave).
	_marker_pos += _marker_dir * _marker_speed * delta
	if _marker_pos >= 1.0:
		_marker_pos = 1.0
		_marker_dir = -1.0
	elif _marker_pos <= 0.0:
		_marker_pos = 0.0
		_marker_dir = 1.0
	if _bar != null:
		_bar.queue_redraw()


func _on_lock() -> void:
	if not _running:
		return
	# Ignore taps during the freeze, or they would reset it and re-score the held marker position
	# (a double count). The player can only lock again once the bar has resumed sweeping.
	if _freeze_left > 0.0:
		return
	# Every LOCK press freezes the bar for a beat so the player can read a hit/miss burst. The
	# success flag (set below, once we know hit vs miss) chooses which burst _draw_bar shows.
	_freeze_left = FREEZE_TIME
	# Judge the tap against the zone AS DISPLAYED (its pre-hit size), not _current_zone_half() for the
	# soon-to-be-incremented lock count — the player aimed at the zone they can see.
	var half := _zone_half
	var distance := absf(_marker_pos - _zone_center)
	var hit := distance <= half
	# Drop a fading line wherever the marker was at the moment of the click — hit or miss — colored
	# green (scored) or red (wasted) so the player gets clear feedback on exactly where, and how
	# well, their tap was perceived.
	_click_marks.append({"pos": _marker_pos, "age": 0.0, "hit": hit})
	# A pending legacy gem is consumed by THIS lock, whichever way it goes: a hit (lock landed in
	# the zone the gem sits in) collects it with a win cue; a miss simply loses it (no penalty).
	var grabbed_gem := false
	if _legacy_gem_active:
		_legacy_gem_active = false
		if hit:
			collect_legacy_gem()
			_legacy_win_flash = 1.0
			grabbed_gem = true  # this lock's success chip becomes the gold "LEGACY GEM!" cue
		else:
			# Lost it. Show it slip away (gray fade at the gem's spot) so the gem never just
			# disappears with no cue — the missed lock already carries its own penalty.
			_legacy_lost_flash = 1.0
	if not hit:
		# Missed the zone. A miss scores nothing and does NOT change the lock count — its only cost
		# is the time it burns, since the host countdown keeps running during play. (This used to
		# subtract a lock, but the count yo-yoing up and down read as a treadmill; Tim, 2026-07-11.)
		_miss_flash = 1.0
		_freeze_success = false  # draw the gray drop-shadow "miss" burst during the freeze
		# Red "MISS!" chip at the marker so a wasted lock reads like every other game's feedback
		# (Tim, 2026-07-11). Red = failure, never a success.
		if _bar != null:
			FloatingChip.spawn(_bar, Vector2(_marker_pos * _bar.size.x, _bar.size.y * 0.5),
					"MISS!", UiPalette.KETCHUP_RED)
		return

	# Hit: accuracy 1.0 dead-center of the zone, falling to 0 at its (current) edges.
	var accuracy := clampf(1.0 - distance / half, 0.0, 1.0)
	_accuracy_sum += accuracy
	_locks += 1
	_success_count += 1
	# Success chip floating up from the marker, so a good lock reads at a glance like Match-3's match
	# chips (Tim, 2026-07-11). A lock that GRABBED a legacy gem shows the gold "LEGACY GEM!" chip so
	# earning the gem is unmistakable on the game itself (Tim, 2026-07-11 — it wasn't reflected before);
	# otherwise the text reflects how clean the lock was — gold "PERFECT!" dead-center, else green.
	if _bar != null:
		var chip_text := "NICE!"
		var chip_color := UiPalette.MONEY_GREEN
		if grabbed_gem:
			chip_text = "LEGACY GEM!"
			chip_color = UiPalette.MUSTARD_GOLD
		elif accuracy >= 0.9:
			chip_text = "PERFECT!"
			chip_color = UiPalette.MUSTARD_GOLD
		elif accuracy >= 0.6:
			chip_text = "GREAT!"
		FloatingChip.spawn(_bar, Vector2(_marker_pos * _bar.size.x, _bar.size.y * 0.5), chip_text, chip_color)
	# Update the sweep speed for the next sweep. Normal mode multiplies by SPEED_RAMP; Challenge Mode
	# resamples its slow speed wave at the new lock count, and every few locks flips the zone's drift
	# direction (on top of the edge bounce).
	if challenge_mode:
		_marker_speed = _challenge_marker_speed()
		_locks_until_flip -= 1
		if _locks_until_flip <= 0:
			_zone_drift_dir = -_zone_drift_dir
			_locks_until_flip = _rng.randi_range(CHALLENGE_ZONE_FLIP_LOCKS_MIN, CHALLENGE_ZONE_FLIP_LOCKS_MAX)
	else:
		_marker_speed *= SPEED_RAMP
	_flash = 1.0
	_freeze_success = true  # draw the white-with-gold-glow "hit" burst during the freeze
	_update_locks_label()
	# Normal mode ends after TARGET_LOCKS successful locks. Challenge Mode ignores the target and
	# runs forever (never emits completed), so we skip this end check entirely when it's on.
	if not challenge_mode and _locks >= TARGET_LOCKS:
		# Final lock: keep _running through the freeze so this success burst is visible, then
		# emit completed once the freeze ends (in _on_freeze_ended). The zone does NOT jump.
		_finish_after_freeze = true
		return
	# The zone holds where it was hit during the freeze, then jumps to a fresh spot once the
	# freeze ends (in _on_freeze_ended), so the burst clearly lands on the gold it just caught.


## Called once when a freeze finishes. Resolves whatever that lock set up: end the round on the
## final lock, or jump the zone after a non-final hit. (A miss leaves the zone where it is.)
func _on_freeze_ended() -> void:
	if _finish_after_freeze:
		_running = false
		completed.emit(get_performance())
	elif _freeze_success:
		_move_zone()
		# After the zone jumps to its fresh spot, roll the small chance to drop a legacy gem into
		# its center for the player to grab on their next lock. Rolled here (not once per round) so
		# the gem always sits in a freshly-placed zone, and only one is ever active at a time. Works
		# unchanged in Challenge Mode's endless loop — the host suppresses the actual grant there.
		# Skip once the bonus is already earned (design rule 3 — no more gems once secured).
		if not _legacy_gem_active and not legacy_bonus_secured() and _rng.randf() < _legacy_gem_chance:
			_legacy_gem_active = true
			_legacy_gem_center = _zone_center


## The zone's current half-width. Normal mode: starts at ZONE_HALF and shrinks linearly to
## ZONE_HALF_MIN as successful locks climb toward TARGET_LOCKS, so the target gets steadily harder.
## Challenge Mode: a slow gentle drift between modest bounds (see _challenge_zone_half), so the
## endless run breathes between slightly-easier and slightly-harder rather than pinning at one size.
func _current_zone_half() -> float:
	if challenge_mode:
		return _challenge_zone_half()
	var progress := clampf(float(_locks) / float(TARGET_LOCKS), 0.0, 1.0)
	return lerpf(ZONE_HALF, ZONE_HALF_MIN, progress)


## Challenge Mode: the sweep speed for the current successful-lock count — a slow wave that rises and
## falls over many locks (period CHALLENGE_SPEED_PERIOD_LOCKS), spanning the SAME range regular mode
## sweeps: from BASE_SPEED (its opening) up to BASE_SPEED × SPEED_RAMP^(TARGET_LOCKS-1) (its top after a
## full run). Sampled once per lock so the speed is steady within each sweep.
func _challenge_marker_speed() -> float:
	var fast := BASE_SPEED * pow(SPEED_RAMP, float(TARGET_LOCKS - 1))
	var mid := (BASE_SPEED + fast) * 0.5
	var amp := (fast - BASE_SPEED) * 0.5
	return mid + amp * sin(TAU * float(_success_count) / CHALLENGE_SPEED_PERIOD_LOCKS)


## Challenge Mode: the zone's current glide speed — a gentle lock-based wave around CHALLENGE_ZONE_DRIFT_MID
## (a much smaller swing than the marker's, per Tim 2026-07-22), so the target speeds up and slows a
## little as it travels rather than gliding at one static rate.
func _challenge_zone_drift_speed() -> float:
	return CHALLENGE_ZONE_DRIFT_MID + CHALLENGE_ZONE_DRIFT_AMP * sin(TAU * _challenge_drift_time / CHALLENGE_ZONE_DRIFT_PERIOD_SECONDS)


## Challenge Mode only: the zone half-width for the current LOCK count — a slow cosine wave between
## CHALLENGE_ZONE_WIDE (the run starts here) and CHALLENGE_ZONE_NARROW at the half-period, over the long
## CHALLENGE_ZONE_PERIOD_LOCKS. Sampled once per lock by _move_zone, so the width is steady through each
## freeze and only nudges between locks — a gentle grow/shrink over many locks, never a fast bounce.
func _challenge_zone_half() -> float:
	var mid := (CHALLENGE_ZONE_WIDE + CHALLENGE_ZONE_NARROW) * 0.5
	var amp := (CHALLENGE_ZONE_WIDE - CHALLENGE_ZONE_NARROW) * 0.5
	return mid + amp * cos(TAU * float(_success_count) / CHALLENGE_ZONE_PERIOD_LOCKS)


## Pick a new random zone center that keeps the whole zone on the bar (center within one
## half-width of either end), so a freshly placed zone is never clipped off the edge.
func _move_zone() -> void:
	# Apply the shrink NOW (after the freeze) by refreshing the displayed half-width from the current
	# lock count. This is the only place _zone_half changes, so the zone stays its pre-hit size for the
	# whole result freeze and shrinks together with the jump below.
	_zone_half = _current_zone_half()
	# Leave a brief fading outline at the PREVIOUS (larger) width at the new spot, so the player sees
	# the zone actually shrank. _move_zone runs after _locks has incremented, so the previous width is
	# the half for (_locks - 1). Skipped at the very first placement (_locks == 0), where nothing has
	# shrunk yet. NORMAL MODE ONLY: Challenge Mode's width oscillates (it doesn't monotonically shrink),
	# so a "it just shrank" cue there would be misleading.
	if not challenge_mode and _locks > 0:
		var prev_progress := clampf(float(_locks - 1) / float(TARGET_LOCKS), 0.0, 1.0)
		_zone_ghost_half = lerpf(ZONE_HALF, ZONE_HALF_MIN, prev_progress)
		_zone_ghost_left = ZONE_GHOST_TIME
	# Normal mode jumps the zone to a fresh random spot each lock. Challenge Mode does NOT jump — the
	# zone TRAVELS by drifting (see _process), so here we only keep it on the bar as its width changes;
	# the drift direction flips on edges and every few locks (see _on_lock).
	if challenge_mode:
		_zone_center = clampf(_zone_center, _zone_half, 1.0 - _zone_half)
	else:
		_zone_center = _rng.randf_range(_zone_half, 1.0 - _zone_half)


func _update_locks_label() -> void:
	# Challenge Mode is endless, so "x / TARGET" is meaningless there — show the running successful-lock
	# score instead. Normal mode redraws its pips to fill one more for the lock just landed.
	if challenge_mode:
		if _locks_label != null:
			_locks_label.text = "Locks: %d" % _success_count
	elif _lock_pips != null:
		_lock_pips.queue_redraw()


## Draw the normal-mode lock pips: TARGET_LOCKS dots centered in a row, the first `_locks` of them
## filled green (locks landed) and the rest empty navy rings (locks to go). Fill-only — a miss never
## empties one — so the row reads as steady progress toward the early finish (Tim, 2026-07-11).
func _draw_lock_pips() -> void:
	if _lock_pips == null:
		return
	var w := _lock_pips.size.x
	var h := _lock_pips.size.y
	if w <= 0.0 or h <= 0.0:
		return
	# Center the whole row of pips: n dots of radius PIP_RADIUS, PIP_GAP between their edges.
	var n := TARGET_LOCKS
	var step := PIP_RADIUS * 2.0 + PIP_GAP  # distance between adjacent pip centers
	var row_width := step * float(n) - PIP_GAP  # last pip has no trailing gap
	var cx := (w - row_width) * 0.5 + PIP_RADIUS
	var cy := h * 0.5
	for i in range(n):
		var center := Vector2(cx + float(i) * step, cy)
		if i < _locks:
			# Landed: a filled green dot with a navy rim so it reads on the light background.
			_lock_pips.draw_circle(center, PIP_RADIUS, UiPalette.MONEY_GREEN)
			_lock_pips.draw_arc(center, PIP_RADIUS, 0.0, TAU, 20, UiPalette.INK_NAVY, PIP_RIM_WIDTH, true)
		else:
			# Still to go: just the navy rim (an empty ring).
			_lock_pips.draw_arc(center, PIP_RADIUS, 0.0, TAU, 20, UiPalette.INK_NAVY, PIP_RIM_WIDTH, true)


## Draw the bar: a navy track, the gold target zone at its current (roving, shrinking) spot,
## and the sweeping marker (flashing cream after a hit, red after a missed click).
func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.INK_NAVY)
	# Shrink cue: a fading outline at the zone's PREVIOUS (larger) size, drawn UNDER the current gold
	# zone so the eye reads "it just got smaller." It is an outline only — never a fill — so it can
	# never be mistaken for the catchable gold area.
	if _zone_ghost_left > 0.0:
		var ghost_life := _zone_ghost_left / ZONE_GHOST_TIME
		var ghost_x := (_zone_center - _zone_ghost_half) * w
		var ghost_w := (_zone_ghost_half * 2.0) * w
		_bar.draw_rect(Rect2(ghost_x, 0, ghost_w, h), Color(UiPalette.MUSTARD_GOLD, 0.45 * ghost_life), false, 4.0)
	# Gold target zone at its current center and displayed width (see _zone_half — holds through the freeze).
	var half := _zone_half
	var zone_x := (_zone_center - half) * w
	var zone_w := (half * 2.0) * w
	_bar.draw_rect(Rect2(zone_x, 0, zone_w, h), UiPalette.MUSTARD_GOLD)
	# Legacy gem: sits in the center of the current zone as a "grab this on your next lock" cue.
	# Drawn over the gold zone (so it reads as sitting ON the target) but under the marker/bursts.
	# The gem art is square, so we size it to the bar height and center it on the zone center.
	if _legacy_gem_active:
		var gem_size := h
		var gem_x := _legacy_gem_center * w - gem_size * 0.5
		_bar.draw_texture_rect(LEGACY_GEM_TEXTURE, Rect2(gem_x, 0, gem_size, gem_size), false)
	# Legacy win burst: a brief gold ring expanding out from where the gem was, so a grabbed gem
	# clearly pays off. Fades with _legacy_win_flash; drawn as an outline so it never hides the bar.
	if _legacy_win_flash > 0.0:
		var burst_grow := 1.0 + (1.0 - _legacy_win_flash) * 1.5  # starts tight, blooms outward
		var burst_half := (h * 0.5) * burst_grow
		var burst_x := _legacy_gem_center * w
		_bar.draw_rect(
				Rect2(burst_x - burst_half, h * 0.5 - burst_half, burst_half * 2.0, burst_half * 2.0),
				Color(UiPalette.MUSTARD_GOLD, _legacy_win_flash), false, 5.0)
	# Legacy LOSS cue: the gem, grayed and shrinking as it fades, drawn where it sat — so a gem
	# missed by the next lock visibly slips away instead of vanishing with no feedback. Drawn as a
	# fading, shrinking, desaturated copy of the same gem art so it clearly reads as "that gem, lost."
	if _legacy_lost_flash > 0.0:
		var lost_size := h * _legacy_lost_flash  # shrinks toward nothing as it fades out
		var lost_x := _legacy_gem_center * w - lost_size * 0.5
		var lost_y := (h - lost_size) * 0.5
		_bar.draw_texture_rect(
				LEGACY_GEM_TEXTURE, Rect2(lost_x, lost_y, lost_size, lost_size), false,
				Color(0.6, 0.6, 0.6, _legacy_lost_flash))
	# Click-feedback lines: a green line for a scored lock, a red line for a wasted miss, at each
	# recorded click, pulsing as it fades over CLICK_MARK_FADE seconds (alpha falls with age; the
	# pulse keeps it lively while visible).
	for mark in _click_marks:
		var life := 1.0 - clampf(float(mark["age"]) / CLICK_MARK_FADE, 0.0, 1.0)
		var pulse := 0.55 + 0.45 * absf(sin(float(mark["age"]) * PI * 3.0))
		var base_color: Color = UiPalette.MONEY_GREEN if mark["hit"] else UiPalette.KETCHUP_RED
		var line_color := Color(base_color, life * pulse)
		var cx := float(mark["pos"]) * w
		_bar.draw_rect(Rect2(cx - 3.0, 0, 6.0, h), line_color)
	var mx := _marker_pos * w
	if _freeze_left > 0.0:
		# Frozen burst: a noticeably THICKER marker line, drawn instead of the normal one.
		if _freeze_success:
			# Hit: a white core wrapped in a layered gold glow — two wider, low-alpha gold
			# rectangles behind the solid white line so the glow fades outward from the core.
			_bar.draw_rect(Rect2(mx - 22.0, 0, 44.0, h), Color(UiPalette.MUSTARD_GOLD, 0.18))
			_bar.draw_rect(Rect2(mx - 13.0, 0, 26.0, h), Color(UiPalette.MUSTARD_GOLD, 0.40))
			_bar.draw_rect(Rect2(mx - 8.0, 0, 16.0, h), Color.WHITE)
		else:
			# Miss: the −1-lock penalty should STING and read. The core SHAKES (a decaying quiver) and
			# GROWS (starts fat, settles), wrapped in a wide red wash so a wasted lock clearly hurts.
			var elapsed := FREEZE_TIME - _freeze_left
			var decay := _freeze_left / FREEZE_TIME          # 1 at the start of the freeze -> 0 at the end
			var shake := sin(elapsed * 42.0) * 12.0 * decay  # a quiver that settles as the freeze ends
			var grow := 1.0 + 0.6 * decay                    # a "thunk" that starts big and shrinks back
			var sx := mx + shake
			_bar.draw_rect(Rect2(sx - 28.0 * grow, 0, 56.0 * grow, h), Color(UiPalette.KETCHUP_RED, 0.30))
			_bar.draw_rect(Rect2(sx - 11.0 * grow, 0, 22.0 * grow, h), Color(UiPalette.KETCHUP_RED, 0.95))
	else:
		# Speed cue: faint streaks trailing BEHIND the marker, more of them the faster it sweeps, so
		# the per-lock speed step is visible and not only felt. Count scales with how far the steady
		# sweep speed has climbed above the base (both modes step _marker_speed up per lock).
		# Both modes hold this steady within a sweep and only step it up per lock.
		# The streaks thicken as the sweep speeds up over a long run; identical logic in both modes.
		# The sweep speed is always positive now (no erratic wobble), so no magnitude guard is needed.
		var speed_ratio := _marker_speed / BASE_SPEED
		var streaks := int(clampf((speed_ratio - 1.0) / 0.09, 0.0, 6.0))
		for s in range(streaks):
			var trail_x := mx - _marker_dir * float(s + 1) * 7.0
			var trail_fade := (1.0 - float(s) / 6.0) * 0.5
			_bar.draw_rect(Rect2(trail_x - 3.0, h * 0.25, 6.0, h * 0.5), Color(UiPalette.CREAM, trail_fade))
		# Normal marker (a thick vertical bar): cream, briefly brightened after a hit or reddened on a miss.
		var marker_color := UiPalette.CREAM.lightened(_flash * 0.6).lerp(UiPalette.KETCHUP_RED, _miss_flash)
		_bar.draw_rect(Rect2(mx - 5.0, 0, 10.0, h), marker_color)
	_bar.draw_rect(Rect2(0, 0, w, h), UiPalette.NAVY, false, 3.0)
