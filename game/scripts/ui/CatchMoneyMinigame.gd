class_name CatchMoneyMinigame
extends Minigame

# "Catch the Money" minigame TYPE (GDD §5.5) — a reaction game. Coins fall from the top;
# tap one to catch it. Performance = net score / TARGET_COINS, where a catch is +1 and a coin
# that falls past the bottom is -MISS_PENALTY (so misses actively cost you). Ends when all
# TARGET_COINS have dropped.
#
# Owns only its gameplay; the host owns countdown / spectrum / result / multiplier.
#
# Polish pass (2026-06-29): this was the least-juiced game — bare "$" buttons, no catch or miss
# feedback at all. It now reads clearly (round coins with a navy rim and a living glint, a spawn
# pop) and reacts to play (a green "+1" pop and white bloom on a catch; a red puff plus a bottom
# edge flash on a miss). It also escalates: the spawn interval ramps toward a late-round rush.

## Coins that make a full game (also the performance denominator).
const TARGET_COINS := 18
## Seconds between coin spawns: starts at SPAWN_INTERVAL_START and ramps DOWN toward
## SPAWN_INTERVAL_END across the batch, so the round builds to a late "rush" instead of staying
## flat (plan §2.3, "Harder"). Both values are first-pass and UN-PLAYTESTED — confirm on-device.
const SPAWN_INTERVAL_START := 0.55
const SPAWN_INTERVAL_END := 0.38
## Challenge Mode uses a slower, fixed spawn interval than the reward-round rush, so the board isn't
## crowded — challenge difficulty comes from coin speed + the keep-alive timer, not clutter (Tim,
## 2026-07-22: "too many coins on screen").
const CHALLENGE_SPAWN_INTERVAL := 0.66
## How fast a coin falls (px/sec in the 1080-wide space).
const FALL_SPEED := 340.0
const COIN_SIZE := 96
## Coins start half-again as big as the base size, then shrink as the player catches them.
const START_COIN_SIZE := COIN_SIZE * 1.5
## Each catch makes every future coin this fraction of the last one's size (5% smaller).
const SHRINK_FACTOR := 0.95
## Floor on the spawn size so coins never become untappably tiny for low-vision players (§1b).
const MIN_COIN_SIZE := COIN_SIZE * 0.5
## A coin that falls past the bottom costs this fraction of a catch. Bumped 0.5 -> 0.75 in the
## polish pass to make the round less lenient (plan §2.3, "Harder"). First-pass and UN-PLAYTESTED.
const MISS_PENALTY := 0.75

## Idle-glint pulse: how fast the highlight on every live coin breathes, and how much of its
## alpha swings, so coins look minted and shiny rather than flat. Driven from _process by an
## accumulated phase (not per-coin tweens) so nothing leaks as coins come and go.
const GLINT_PULSE_SPEED := 4.0
const GLINT_PULSE_AMOUNT := 0.25

## The Legacy gem texture, overlaid on a "legacy coin" (see _spawn_coin) so the player can see it
## carries a bonus gem worth catching. Same art used for the currency everywhere else, so it reads
## instantly (Plans/Legacy_Bonus_System.md — "catch that coin earns the gem in addition").
const LEGACY_GEM_TEXTURE := preload("res://art/icons/legacy_gem.svg")

# --- CHALLENGE MODE difficulty waves (Tim playtest, 2026-07-20) --------------------------------
# In CHALLENGE mode only, difficulty does NOT ramp once to max-speed/min-size and then flatline
# (the old grind of chasing tiny fast coins forever). Instead coin SIZE and FALL SPEED breathe in
# slow WAVES: stretches of bigger/slower coins, then smaller/faster, then back. The wave is driven
# off a sine of accumulated challenge time (_challenge_time), NOT randomness, so it's smooth and
# repeatable. All values here are FIRST-PASS and UN-PLAYTESTED — device-tune.
#
# One easy->hard->easy cycle takes this many seconds. Longer = the round changes texture more slowly.
const CHALLENGE_WAVE_PERIOD := 9.0
# The wave's easy and hard extremes. At the easy trough coins are big and slow; at the hard crest
# they are small and fast. SIZE and SPEED move together (in phase), so "hard" means small AND fast.
const CHALLENGE_SIZE_EASY := COIN_SIZE * 1.35
const CHALLENGE_SIZE_HARD := COIN_SIZE * 0.60
const CHALLENGE_SPEED_SLOW := FALL_SPEED * 0.96     # Tim 2026-07-22: raised ~20% so no coin is too slow
const CHALLENGE_SPEED_FAST := FALL_SPEED * 1.65

# --- CHALLENGE MODE coin archetypes -----------------------------------------------------------
# Alongside the wave baseline, each challenge coin also picks an archetype so a MIX falls together:
# ordinary, a bigger/slower "lob", or a smaller/faster "dart". These multiply the wave's size/speed.
const ARCHETYPE_BIG_SIZE_MULT := 1.25
const ARCHETYPE_BIG_SPEED_MULT := 0.75
const ARCHETYPE_SMALL_SIZE_MULT := 0.70
const ARCHETYPE_SMALL_SPEED_MULT := 1.45
# Roughly one third ordinary / big / small. Rolls below BIG_CHANCE are big-slow; below
# BIG_CHANCE+SMALL_CHANCE are small-fast; the rest are ordinary.
const ARCHETYPE_BIG_CHANCE := 0.30
const ARCHETYPE_SMALL_CHANCE := 0.30

# A PREMIUM coin: rarer, visually distinct (emerald with a gold rim, labelled with its worth), and
# worth PREMIUM_SCORE_VALUE catches instead of 1 toward the cumulative challenge score. Premium
# coins are never legacy coins (kept visually separate to avoid clutter). First-pass; device-tune.
const PREMIUM_COIN_CHANCE := 0.06     # Tim 2026-07-22: halved — green premium coins were too common
const PREMIUM_SCORE_VALUE := 3

# --- CHALLENGE MODE curving falls -------------------------------------------------------------
# Challenge coins drift horizontally as they fall (a left-right sway) instead of dropping straight
# down, so catching them takes tracking. Each coin sways around its own spawn column (base_x) with a
# random phase, off the shared _challenge_time clock. Reward-mode coins never sway.
const CHALLENGE_SWAY_AMPLITUDE := 45.0  # peak horizontal drift, px, to each side (Tim 2026-07-22: halved)
## Each coin sways at its OWN random speed (period drawn per coin from this range), so the drifts no
## longer share one rhythm (Tim, 2026-07-22).
const CHALLENGE_SWAY_PERIOD_MIN := 1.0  # seconds for one full left-right sway — fastest sway
const CHALLENGE_SWAY_PERIOD_MAX := 2.8  # slowest sway
## Per-coin random multiplier on the wave/archetype fall speed, so no two coins fall at quite the same
## rate (Tim, 2026-07-22).
const CHALLENGE_FALL_JITTER_MIN := 0.75
const CHALLENGE_FALL_JITTER_MAX := 1.35

var _caught: int = 0
var _missed: int = 0
var _spawned: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _coins: Array = []  # live coin Buttons
## Current spawn size: starts large and shrinks 5% per catch (compounding). Coins already
## in flight keep the size they spawned at; only this next-spawn value changes.
var _spawn_size: float = START_COIN_SIZE
## Accumulated time driving the shared coin-glint pulse (see GLINT_PULSE_SPEED).
var _shine_phase: float = 0.0
## Accumulated CHALLENGE-mode play time. Drives both the difficulty wave (size/speed) and the
## horizontal sway of curving falls. Only advances in challenge mode; unused in reward mode.
var _challenge_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _area: Control
## Chance any single spawned coin is a "legacy coin" carrying a bonus Legacy gem (from
## tuning.legacy_gem_chance_catch). Catching it collects the gem on top of the normal catch; a
## missed legacy coin just falls away like any other. Captured live in begin() so Balance Tuning
## edits take effect next round.
var _legacy_coin_chance: float = 0.0


func display_name() -> String:
	return "Catch the Money"


func how_to_play() -> String:
	return "Tap every falling coin before it hits the floor. Catches score, " \
		+ "misses cost — and they fall faster as you go."


func begin(tuning: TuningConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_running = true
	# Capture the live spawn chance so Balance Tuning edits take effect next round.
	_legacy_coin_chance = tuning.legacy_gem_chance_catch

	var intro := Label.new()
	intro.text = how_to_play()
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# AUTOWRAP is load-bearing: without it the label's MIN WIDTH is the full text width,
	# which propagates up the containers — the text ran off the screen edge AND the play
	# area widened past the visible card, so coins spawned off-screen (Tim, 2026-07-08,
	# after the guidance lines grew).
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	intro.add_theme_color_override("font_color", UiPalette.NAVY)

	_area = Control.new()
	_area.clip_contents = true
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	column.add_child(intro)
	column.add_child(_area)
	add_child(column)


func get_performance() -> float:
	# Net score = catches minus the miss penalty per coin that slipped past the bottom.
	var net := float(_caught) - MISS_PENALTY * float(_missed)
	return clampf(net / float(TARGET_COINS), 0.0, 1.0)


## Challenge Mode's running high score = coins CAUGHT this run. MONOTONIC — a miss never subtracts here,
## so the host can sample it live for a non-decreasing high-score bar. A missed coin's time cost is
## delivered separately through the host's challenge_time_penalty channel (see _process), NOT by dropping
## the score.
func get_score() -> int:
	return _caught


func result_summary() -> String:
	return "Caught %d of %d" % [_caught, TARGET_COINS]


## Seconds to wait before the next spawn, ramping from START down to END as the batch empties so
## the round speeds up toward the end (the late-round "rush").
func _current_spawn_interval() -> float:
	if challenge_mode:
		return CHALLENGE_SPAWN_INTERVAL
	var progress := float(_spawned) / float(TARGET_COINS)
	return lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, clampf(progress, 0.0, 1.0))


func _process(delta: float) -> void:
	if not _running or _area == null:
		return
	var area_size := _area.size
	if area_size.x <= 0.0:
		return

	# Drive the living glint on every coin from one shared phase (no per-coin tweens to leak).
	_shine_phase += delta
	var glint_alpha := 0.55 + GLINT_PULSE_AMOUNT * sin(_shine_phase * GLINT_PULSE_SPEED)
	for coin in _coins:
		var glint: Panel = coin.get_meta("glint")
		if is_instance_valid(glint):
			glint.modulate.a = glint_alpha

	# Spawn coins at the current (ramping) interval. Normal mode drops one fixed batch of
	# TARGET_COINS; Challenge Mode ignores that limit and spawns FOREVER. The ramp self-caps at
	# SPAWN_INTERVAL_END because _current_spawn_interval() clamps its progress to 1.0, so the
	# late-round "rush" speed becomes the sustained speed rather than accelerating without bound —
	# fast but still playable indefinitely.
	# Advance the challenge clock that drives the difficulty wave and the curving-fall sway.
	if challenge_mode:
		_challenge_time += delta

	if challenge_mode or _spawned < TARGET_COINS:
		_spawn_timer += delta
		if _spawn_timer >= _current_spawn_interval():
			_spawn_timer = 0.0
			_spawn_coin(area_size.x)

	# Fall; a coin past the bottom is a miss — it costs points (see get_performance), shows the
	# miss cue, and is freed. Walked backward so remove_at can't skip the next coin —
	# this loop used to iterate a duplicate() of the array, a fresh copy every frame
	# (minigame lag pass, Tim 2026-07-06).
	for i in range(_coins.size() - 1, -1, -1):
		var coin: Control = _coins[i]
		# Each coin falls at its OWN speed (reward-mode coins all carry FALL_SPEED, so their motion is
		# unchanged; challenge coins carry a wave/archetype speed set at spawn).
		var fall_speed: float = coin.get_meta("fall_speed", FALL_SPEED)
		coin.position.y += fall_speed * delta
		# Challenge coins also sway horizontally around their spawn column (curving falls). A coin with
		# zero sway amplitude — every reward-mode coin — keeps its straight-down x, so reward play is
		# untouched.
		var sway_amp: float = coin.get_meta("sway_amp", 0.0)
		if sway_amp > 0.0:
			var base_x: float = coin.get_meta("base_x", coin.position.x)
			var sway_phase: float = coin.get_meta("sway_phase", 0.0)
			var sway_period: float = coin.get_meta("sway_period", CHALLENGE_SWAY_PERIOD_MAX)
			coin.position.x = base_x + sway_amp * sin(_challenge_time * TAU / sway_period + sway_phase)
		if coin.position.y > area_size.y:
			_missed += 1
			# CHALLENGE mode only: a dropped coin costs keep-alive time proportional to what catching it
			# would have added. Emit the coin's OWN value (a premium coin is worth 3), so missing a premium
			# costs proportionally more — exactly miss_penalty_ratio x that value at the host. Reward mode
			# never emits, so its scoring/timing is unchanged.
			if challenge_mode:
				var dropped_value := int(coin.get_meta("value", 1))
				challenge_time_penalty.emit(float(dropped_value))
			var drop_center := Vector2(coin.position.x + coin.size.x / 2.0, area_size.y)
			_coins.remove_at(i)
			coin.queue_free()
			_spawn_miss_effect(drop_center)

	# All spawned and none left on screen -> the round is over. Challenge Mode never self-completes
	# (it keeps spawning above), so this end check applies to normal (reward) mode only.
	if not challenge_mode and _spawned >= TARGET_COINS and _coins.is_empty():
		_running = false
		completed.emit(get_performance())


## CHALLENGE-mode wave difficulty, 0 (easiest: big + slow) to 1 (hardest: small + fast). A cosine
## remapped to [0,1] so the round OPENS at the easy trough (t=0 -> 0) and breathes up and down from
## there — this is what gives the round its changing texture instead of a one-way ramp.
func _challenge_difficulty() -> float:
	return 0.5 - 0.5 * cos(_challenge_time * TAU / CHALLENGE_WAVE_PERIOD)


## The size / fall speed / worth / premium flag for the NEXT challenge coin, combining the current
## wave difficulty with a per-coin archetype (ordinary, big-slow, small-fast) and a premium roll.
## Returns a dictionary so the spawn code stays readable. Challenge mode only.
func _challenge_coin_params() -> Dictionary:
	var difficulty := _challenge_difficulty()
	var size := lerpf(CHALLENGE_SIZE_EASY, CHALLENGE_SIZE_HARD, difficulty)
	var speed := lerpf(CHALLENGE_SPEED_SLOW, CHALLENGE_SPEED_FAST, difficulty)

	# A premium coin ignores the archetype tweaks (it stays a clean, ordinary-shaped target) but is
	# worth several catches. Never also a legacy coin — we keep the two special coins visually apart.
	var is_premium := _rng.randf() < PREMIUM_COIN_CHANCE
	if not is_premium:
		var roll := _rng.randf()
		if roll < ARCHETYPE_BIG_CHANCE:
			size *= ARCHETYPE_BIG_SIZE_MULT
			speed *= ARCHETYPE_BIG_SPEED_MULT
		elif roll < ARCHETYPE_BIG_CHANCE + ARCHETYPE_SMALL_CHANCE:
			size *= ARCHETYPE_SMALL_SIZE_MULT
			speed *= ARCHETYPE_SMALL_SPEED_MULT

	# A per-coin random jitter on the fall speed so coins don't fall in lockstep (Tim, 2026-07-22).
	speed *= _rng.randf_range(CHALLENGE_FALL_JITTER_MIN, CHALLENGE_FALL_JITTER_MAX)

	# Keep the size within the readable floor (low-vision, §1b) and a sane ceiling.
	size = clampf(size, MIN_COIN_SIZE, START_COIN_SIZE)
	return {
		"size": size,
		"fall_speed": speed,
		"is_premium": is_premium,
		"value": PREMIUM_SCORE_VALUE if is_premium else 1,
	}


## The round coin: a mustard disc with a thick navy rim (so it reads against the cream card) and a
## white glint in the upper-left (so it looks like a shiny coin, not a flat button).
##
## In CHALLENGE mode the size/speed come from the difficulty wave + archetype (see
## _challenge_coin_params), the coin sways as it falls, and some coins are premium (worth more). In
## REWARD mode none of that applies: the coin uses the shrinking _spawn_size, FALL_SPEED, no sway,
## and is worth 1 — exactly as before.
func _spawn_coin(area_width: float) -> void:
	_spawned += 1

	var size := _spawn_size
	var fall_speed := FALL_SPEED
	var sway_amp := 0.0
	var sway_period := 0.0
	var value := 1
	var is_premium := false
	if challenge_mode:
		var params := _challenge_coin_params()
		size = float(params["size"])
		fall_speed = float(params["fall_speed"])
		is_premium = bool(params["is_premium"])
		value = int(params["value"])
		# A gentle per-coin variation in sway width so the drifts don't all look identical.
		sway_amp = CHALLENGE_SWAY_AMPLITUDE * _rng.randf_range(0.6, 1.0)
		sway_period = _rng.randf_range(CHALLENGE_SWAY_PERIOD_MIN, CHALLENGE_SWAY_PERIOD_MAX)

	var coin := Button.new()
	coin.text = "$"
	coin.custom_minimum_size = Vector2(size, size)
	coin.size = Vector2(size, size)
	# Scale the glyph with the coin so the "$" keeps filling it as the coin shrinks.
	coin.add_theme_font_size_override("font_size", int(UiPalette.FONT_HEADLINE * size / COIN_SIZE))
	coin.set_meta("fall_speed", fall_speed)
	coin.set_meta("value", value)
	_style_coin(coin, size, is_premium)

	# A small white highlight, ignored by the mouse so it never eats a tap. _process pulses its
	# alpha for the living-glint shine.
	var glint := Panel.new()
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.size = Vector2(size * 0.30, size * 0.22)
	glint.position = Vector2(size * 0.22, size * 0.18)
	var glint_style := StyleBoxFlat.new()
	glint_style.bg_color = Color(1, 1, 1, 0.7)
	glint_style.set_corner_radius_all(int(size * 0.22))  # round the highlight into an oval
	glint.add_theme_stylebox_override("panel", glint_style)
	coin.add_child(glint)
	coin.set_meta("glint", glint)

	# A premium coin shows its worth ("x3") in a bold gold badge so the player reads instantly that
	# it's worth chasing. Premium coins are never legacy coins (see _challenge_coin_params).
	if is_premium:
		var badge := Label.new()
		badge.text = "x%d" % value
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.size = Vector2(size, size * 0.5)
		badge.position = Vector2(0.0, size * 0.5)
		badge.add_theme_font_size_override("font_size", int(UiPalette.FONT_LABEL * size / COIN_SIZE))
		badge.add_theme_font_override("font", UiPalette.make_bold_font())
		badge.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
		badge.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
		badge.add_theme_constant_override("outline_size", 4)
		coin.add_child(badge)

	# With a small chance this is a "legacy coin": catching it collects a bonus Legacy gem on top of
	# the normal catch. We flag it (read in _on_coin_caught) and overlay the gem art so it stands out
	# as special and worth catching. A missed legacy coin just falls away like any other coin.
	# Stop spawning legacy coins once the bonus is already earned (design rule 3 — no noise). A
	# premium coin is never also a legacy coin, so the two special looks never collide.
	var is_legacy := not is_premium and not legacy_bonus_secured() and _rng.randf() < _legacy_coin_chance
	coin.set_meta("legacy", is_legacy)
	if is_legacy:
		# The gem sits centered on the coin (mouse-ignored so it never eats the tap), sized to a
		# chunk of the coin so the "$" still reads underneath it.
		var gem := TextureRect.new()
		gem.texture = LEGACY_GEM_TEXTURE
		gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.size = Vector2(size * 0.62, size * 0.62)
		gem.position = (Vector2(size, size) - gem.size) / 2.0
		coin.add_child(gem)

	# The spawn column. In challenge mode we inset it by the sway amplitude and record it as base_x
	# so the coin sways left/right around it (see _process) without drifting off the card edges.
	var spawn_x: float
	if sway_amp > 0.0:
		var lo: float = sway_amp
		var hi: float = maxf(lo, area_width - size - sway_amp)
		spawn_x = _rng.randf_range(lo, hi)
		coin.set_meta("sway_amp", sway_amp)
		coin.set_meta("base_x", spawn_x)
		coin.set_meta("sway_phase", _rng.randf_range(0.0, TAU))
		coin.set_meta("sway_period", sway_period)
	else:
		var max_x: float = maxf(0.0, area_width - size)
		spawn_x = _rng.randf_range(0.0, max_x)
	coin.position = Vector2(spawn_x, -size)
	coin.pressed.connect(_on_coin_caught.bind(coin))
	_area.add_child(coin)
	_coins.append(coin)

	# Spawn entrance: pop the coin up from small as it enters, so a new coin announces itself.
	coin.pivot_offset = Vector2(size / 2.0, size / 2.0)
	coin.scale = Vector2(0.3, 0.3)
	var entrance := create_tween()
	entrance.tween_property(coin, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A coin's look in every interaction state (catches free the coin instantly, so the pressed look
## barely shows — but keeping all states identical means a tap never flips it to a button skin).
## A PREMIUM coin (challenge mode only) reverses the palette — an emerald face with a bold gold rim
## — so it reads at a glance as the special, higher-value coin. Ordinary coins are unchanged.
func _style_coin(coin: Button, size: float, is_premium: bool = false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.MONEY_GREEN if is_premium else UiPalette.MUSTARD_GOLD
	style.border_color = UiPalette.MUSTARD_GOLD if is_premium else UiPalette.INK_NAVY
	style.set_border_width_all(int(maxf(4.0, size * (0.10 if is_premium else 0.07))))
	style.set_corner_radius_all(int(size / 2.0))  # full radius = a round coin
	for state in ["normal", "hover", "pressed", "focus"]:
		coin.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		coin.add_theme_color_override(state, UiPalette.NAVY)


func _on_coin_caught(coin: Button) -> void:
	if not _running or not _coins.has(coin):
		return
	# A premium challenge coin is worth several catches toward the cumulative score; every other coin
	# is worth 1 (reward-mode coins always carry value 1, so scoring there is unchanged).
	var value := int(coin.get_meta("value", 1))
	_caught += value
	# REWARD mode only: every catch makes the NEXT spawn 5% smaller (compounding), down to the
	# readable floor. Challenge mode drives coin size from the difficulty wave instead, so it must NOT
	# shrink here — that per-catch shrink was exactly the old "race to tiny and flatline" grind.
	if not challenge_mode:
		_spawn_size = maxf(MIN_COIN_SIZE, _spawn_size * SHRINK_FACTOR)
	var center := coin.position + coin.size / 2.0
	# A legacy coin collects a bonus Legacy gem in addition to the normal catch (scoring below is
	# unchanged). The host gates the actual payout by the round result; in Challenge Mode it just
	# won't grant. We give an extra gem-earned cue on top of the normal catch juice.
	var was_legacy := bool(coin.get_meta("legacy", false))
	var was_premium := value > 1
	_coins.erase(coin)
	coin.queue_free()
	_spawn_catch_effect(center, coin.size.x, value)
	# A context-specific result chip on every catch, matching how Match-3 badges a good action
	# (Tim, 2026-07-11 — every minigame shows success feedback like Match-3). A legacy coin is the
	# exceptional/bonus catch, so it gets a gold "JACKPOT!" chip; a premium coin gets a green
	# "+N PREMIUM!"; an ordinary catch gets a green "CAUGHT!". This stacks on top of the "+N" pop
	# (and, for legacy, the gem cue) by design.
	if was_legacy:
		FloatingChip.spawn(_area, center, "JACKPOT!", UiPalette.MUSTARD_GOLD)
		collect_legacy_gem()
		_spawn_legacy_catch_effect(center, coin.size.x)
	elif was_premium:
		FloatingChip.spawn(_area, center, "+%d PREMIUM!" % value, UiPalette.MONEY_GREEN)
	else:
		FloatingChip.spawn(_area, center, "CAUGHT!", UiPalette.MONEY_GREEN)


## Catch reward: a white bloom that swells and fades where the coin was, plus a green "+1" that
## floats up — the host's juice vocabulary (white-flash + pop) applied to a catch.
func _spawn_catch_effect(center: Vector2, coin_size: float, value: int = 1) -> void:
	var bloom := Panel.new()
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloom.size = Vector2(coin_size, coin_size)
	bloom.position = center - bloom.size / 2.0
	bloom.pivot_offset = bloom.size / 2.0
	var bloom_style := StyleBoxFlat.new()
	bloom_style.bg_color = Color(1, 1, 1, 0.7)
	bloom_style.set_corner_radius_all(int(coin_size / 2.0))
	bloom.add_theme_stylebox_override("panel", bloom_style)
	_area.add_child(bloom)
	var bloom_tween := create_tween()
	bloom_tween.set_parallel(true)
	bloom_tween.tween_property(bloom, "scale", Vector2(1.8, 1.8), 0.3)
	bloom_tween.tween_property(bloom, "modulate:a", 0.0, 0.3)
	bloom_tween.chain().tween_callback(bloom.queue_free)

	var pop := Label.new()
	# Shows how many catches this coin was worth ("+1" for an ordinary coin, "+3" for a premium).
	pop.text = "+%d" % value
	pop.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	pop.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	pop.add_theme_font_override("font", UiPalette.make_bold_font())
	pop.position = Vector2(center.x, center.y - coin_size * 0.4)
	_area.add_child(pop)
	var pop_tween := create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(pop, "position:y", pop.position.y - 70.0, 0.5)
	pop_tween.tween_property(pop, "modulate:a", 0.0, 0.5)
	pop_tween.chain().tween_callback(pop.queue_free)


## Bonus cue for catching a LEGACY coin, layered on top of the normal catch juice: the gem art
## blooms and rises where the coin was, with a gold "LEGACY!" label, so earning the bonus gem reads
## clearly as something extra and special.
func _spawn_legacy_catch_effect(center: Vector2, coin_size: float) -> void:
	var gem := TextureRect.new()
	gem.texture = LEGACY_GEM_TEXTURE
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size = Vector2(coin_size, coin_size)
	gem.position = center - gem.size / 2.0
	gem.pivot_offset = gem.size / 2.0
	gem.scale = Vector2(0.5, 0.5)
	_area.add_child(gem)
	var gem_tween := create_tween()
	gem_tween.set_parallel(true)
	gem_tween.tween_property(gem, "scale", Vector2(1.4, 1.4), 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gem_tween.tween_property(gem, "position:y", gem.position.y - 60.0, 0.5)
	gem_tween.tween_property(gem, "modulate:a", 0.0, 0.5).set_delay(0.2)
	gem_tween.chain().tween_callback(gem.queue_free)

	var pop := Label.new()
	pop.text = "LEGACY!"
	pop.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	pop.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	pop.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	pop.add_theme_constant_override("outline_size", 5)
	pop.add_theme_font_override("font", UiPalette.make_bold_font())
	pop.position = Vector2(center.x - coin_size * 0.4, center.y + coin_size * 0.3)
	_area.add_child(pop)
	var pop_tween := create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(pop, "position:y", pop.position.y - 70.0, 0.6)
	pop_tween.tween_property(pop, "modulate:a", 0.0, 0.6).set_delay(0.2)
	pop_tween.chain().tween_callback(pop.queue_free)


## Miss cue: a red puff where the coin slipped off the bottom, plus a brief red flash along the
## bottom edge, so a dropped coin reads clearly as a loss (it was previously silent).
func _spawn_miss_effect(drop_center: Vector2) -> void:
	var puff := Panel.new()
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.size = Vector2(COIN_SIZE, COIN_SIZE)
	puff.position = drop_center - Vector2(puff.size.x / 2.0, puff.size.y)
	puff.pivot_offset = puff.size / 2.0
	var puff_style := StyleBoxFlat.new()
	puff_style.bg_color = Color(UiPalette.KETCHUP_RED, 0.6)
	puff_style.set_corner_radius_all(int(COIN_SIZE / 2.0))
	puff.add_theme_stylebox_override("panel", puff_style)
	_area.add_child(puff)
	var puff_tween := create_tween()
	puff_tween.set_parallel(true)
	puff_tween.tween_property(puff, "scale", Vector2(1.7, 1.7), 0.35)
	puff_tween.tween_property(puff, "modulate:a", 0.0, 0.35)
	puff_tween.chain().tween_callback(puff.queue_free)

	# A thin red bar flashing along the bottom edge makes the "it got past you" line unmistakable.
	var edge := ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.color = UiPalette.KETCHUP_RED
	edge.size = Vector2(_area.size.x, 8.0)
	edge.position = Vector2(0.0, _area.size.y - 8.0)
	_area.add_child(edge)
	var edge_tween := create_tween()
	edge_tween.tween_property(edge, "modulate:a", 0.0, 0.35)
	edge_tween.tween_callback(edge.queue_free)
