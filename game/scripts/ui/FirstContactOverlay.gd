class_name FirstContactOverlay
extends ColorRect

# The "First Contact" beat (GDD §6.2 / §10.1 beat 4). When a generation consumes the
# entire current economy, Earth makes contact with the next alien civilization: a larger
# market opens and every property unlocks a new alien-tech staffer tier. This overlay is
# that moment — it names the civilization, its home world and currency, and the deadpan
# narrator line, then hands the player back to the (now bigger) game.
#
# This is meant to LAND as a dramatic event, not a quiet notice (Tim 2026-06-22). The
# reveal is STAGED: the scrim fades in, then each line of the card arrives in sequence
# with short fades and small scale/slide moves, building to the "THE MARKET JUST GREW ×N"
# payoff (which gets a punchy scale-in pop), the narrator line typewrites in, and only
# THEN does the "ANSWER THE CALL" button fade up — so the player takes the moment in
# before they can dismiss it. The economy is frozen by Main while we're visible, so the
# few seconds the sequence takes cost the player nothing.
#
# Drive it from Main: connect EpochState.contact_made to a handler that calls
# show_contact(new_tier).

signal dismissed

var _eyebrow_label: Label
var _headline_label: Label
var _civ_label: Label
var _planet_label: Label
var _flavor_label: Label
var _market_label: Label
var _narration_label: Label
var _proceed_button: Button

# Every element of the card that the reveal sequence fades/scales in, in reveal order.
# Collected so we can reset them all cleanly (alpha 0, default scale) on every show.
var _staged_nodes: Array[Control] = []

## Drives the eyebrow's slow blink so the moment reads as a live, urgent transmission.
var _blink_time := 0.0

## The full narrator line; revealed one character at a time by the typewriter step.
var _narration_full_text := ""

## The single tween that runs the whole reveal. Stored so a re-entrant show_contact()
## can .kill() it before starting over (Godot tweens keep running on their own once
## created — there is no scene node to free, so we must hold the reference to stop it).
var _reveal_tween: Tween = null


func _ready() -> void:
	# Black field framing a cream rounded viewing area — the same full-screen frame the main
	# game and dev panel use (Tim, 2026-06-23), so every full-window screen matches.
	color = Color.BLACK
	visible = false

	var viewing_area := PanelContainer.new()
	UiPalette.apply_screen_bezel(viewing_area)
	viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(viewing_area)

	var center := CenterContainer.new()
	viewing_area.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(760, 0)
	center.add_child(column)

	# Eyebrow: a blinking "incoming transmission" line so the screen reads as a live event
	# breaking in, not a quiet notice (Tim 2026-06-17). Its alpha pulses in _process; the
	# reveal sequence fades the WHOLE label in first, then the blink takes over.
	_eyebrow_label = Label.new()
	_eyebrow_label.text = "◄  INCOMING TRANSMISSION  ►"
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_eyebrow_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_eyebrow_label)

	_headline_label = Label.new()
	_headline_label.text = "FIRST CONTACT"
	_headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Gold: this is a celebratory milestone, like the Legacy reward chrome.
	_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_headline_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_headline_label.add_theme_constant_override("outline_size", 3)
	_headline_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(_headline_label)

	# The civilization Earth has just reached — the big name on the card.
	_civ_label = Label.new()
	_civ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_civ_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_civ_label.custom_minimum_size = Vector2(760, 0)
	_civ_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_civ_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_civ_label.add_theme_constant_override("outline_size", 2)
	_civ_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	column.add_child(_civ_label)

	# Home world + their currency (flavor only — Earth stays on dollars).
	_planet_label = Label.new()
	_planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_planet_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	column.add_child(_planet_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN.darkened(0.2))
	_flavor_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	column.add_child(_flavor_label)

	# The headline payoff: how many times larger the new market is. Big and gold, so the
	# scale jump lands as the reason this is worth celebrating. This is the element the
	# reveal punches hardest (an overshoot scale-in pop).
	_market_label = Label.new()
	_market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_market_label.add_theme_color_override("font_outline_color", UiPalette.MUSTARD_GOLD)
	_market_label.add_theme_constant_override("outline_size", 2)
	_market_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	# Scale the label around its own center so the pop grows from the middle, not the
	# top-left corner (pivot defaults to (0,0)). We set the real pivot once the label has
	# been sized by the layout, in _set_center_pivots().
	column.add_child(_market_label)

	# The narrator's contact line — revealed character by character (typewriter) for drama.
	_narration_label = Label.new()
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.custom_minimum_size = Vector2(760, 0)
	_narration_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_narration_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_narration_label)

	var note := Label.new()
	note.text = "New markets open. Your staff can be upgraded with their technology."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.add_theme_color_override("font_color", UiPalette.NAVY)
	note.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	column.add_child(note)

	_proceed_button = Button.new()
	_proceed_button.text = "ANSWER THE CALL"
	_proceed_button.custom_minimum_size = Vector2(0, 96)
	_proceed_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(_proceed_button, true)
	_proceed_button.pressed.connect(_on_proceed_pressed)
	column.add_child(_proceed_button)

	# The card lines, in the order the reveal walks through them. `note` and the button are
	# handled at the end of the sequence, so they are NOT in this list. Keeping this list is
	# what lets the re-entrancy reset be a simple loop instead of touching each node by hand.
	_staged_nodes = [
		_eyebrow_label,
		_headline_label,
		_civ_label,
		_planet_label,
		_flavor_label,
		_market_label,
		_narration_label,
	]


## Blink the "incoming transmission" eyebrow while the overlay is up. The reveal fades the
## eyebrow's modulate.a up to 1 first; once it is fully visible this pulse takes over. We
## only drive the blink once the eyebrow has finished its reveal fade (alpha near 1) so the
## two don't fight each other on the first beat.
func _process(delta: float) -> void:
	if not visible:
		return
	if _eyebrow_label.modulate.a < 0.95:
		return  # still fading in under the reveal tween — let that finish first
	_blink_time += delta
	_eyebrow_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink_time * TAU * 1.5))


## Show the contact beat for a newly-reached epoch tier (2+), reading its flavor from
## EpochCatalog. Tier 1 (Earth) never triggers this — you begin there. Safe to call again
## while already showing: any running reveal is killed and the card resets cleanly first.
func show_contact(tier: int) -> void:
	var epoch := EpochCatalog.get_epoch(tier)
	if epoch.is_empty():
		return

	# Re-entrancy guard: stop any reveal already in flight before we restage. Without this,
	# a second call would leave two tweens animating the same nodes against each other.
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null

	_civ_label.text = String(epoch["civilization"])
	_planet_label.text = "Home world: %s" % String(epoch["home_planet"])
	_flavor_label.text = "They trade in %s." % String(epoch["currency_flavor"])
	# How many times larger the new market is than the one just consumed (the scale jump
	# between this epoch and the previous one) — the celebratory payoff line.
	var growth := EpochCatalog.economy_scale(tier) / EpochCatalog.economy_scale(tier - 1)
	_market_label.text = "THE MARKET JUST GREW ×%s" % _format_multiplier(growth)

	# The narrator line is held in full and revealed letter by letter during the sequence,
	# so the label starts empty.
	_narration_full_text = EpochCatalog.contact_line(tier)
	_narration_label.text = ""

	_blink_time = 0.0
	visible = true
	_reset_for_reveal()
	_play_reveal()


## Put every staged element back to its hidden start state (transparent, default scale) and
## park the proceed button hidden+disabled, so a fresh reveal always begins from zero — even
## if a previous run was interrupted partway through.
func _reset_for_reveal() -> void:
	for node in _staged_nodes:
		node.modulate.a = 0.0
		node.scale = Vector2.ONE
	# The button is the final payoff; it stays hidden and unclickable until the reveal ends.
	_proceed_button.modulate.a = 0.0
	_proceed_button.disabled = true


## Build and run the staged reveal as one chained Tween. A single tween plays its steps in
## order by default; we use .parallel() only where two effects (fade + move/scale) should
## run together on the same beat. Tween callbacks (tween_callback) let us fire the pivot
## setup, the typewriter, and the final button reveal at the right points in the timeline.
func _play_reveal() -> void:
	_reveal_tween = create_tween()
	# A gentle ease so each line settles rather than snapping; SINE reads as "smooth".
	_reveal_tween.set_ease(Tween.EASE_OUT)
	_reveal_tween.set_trans(Tween.TRANS_SINE)

	# Centers must be measured AFTER layout has sized the labels, so do it on the first
	# tween frame (a 0s callback runs once the tween starts, by which point _ready's layout
	# pass has run for this show).
	_reveal_tween.tween_callback(_set_center_pivots)

	# 1) Eyebrow fades in — the transmission "breaks in" first.
	_fade_in_step(_eyebrow_label, 0.35)

	# 2) Headline pops: fade in while scaling up from small with a slight overshoot (BACK),
	#    so "FIRST CONTACT" punches onto the card.
	_pop_in_step(_headline_label, 0.45, 0.6)

	# 3) Civilization name slides up into place as it fades in.
	_slide_in_step(_civ_label, 0.40, 26.0)

	# 4) Home world and 5) currency flavor arrive as quick quiet fades.
	_fade_in_step(_planet_label, 0.30)
	_fade_in_step(_flavor_label, 0.30)

	# 6) THE PAYOFF: the market-growth line pops hardest — a bigger overshoot from a smaller
	#    start, so the scale jump is the visual climax of the card.
	_pop_in_step(_market_label, 0.55, 0.4)
	# A brief follow-up pulse on the payoff line (up past full, settle back to full) so it
	# reads as a beat that lands rather than a thing that merely appeared.
	_reveal_tween.tween_property(_market_label, "scale", Vector2(1.12, 1.12), 0.12)
	_reveal_tween.tween_property(_market_label, "scale", Vector2.ONE, 0.18)

	# 7) Narrator line: fade the (empty) label in, then typewrite the text across it.
	_fade_in_step(_narration_label, 0.25)
	_reveal_tween.tween_callback(_start_typewriter)
	# Hold the timeline open for the typewriter, which runs on its OWN tween. Time it from
	# the text length at a steady characters-per-second so the button always waits for the
	# line to finish (and there is always an end, so the player is never stuck).
	var typewriter_seconds := _typewriter_duration()
	_reveal_tween.tween_interval(typewriter_seconds)

	# 8) Finally, reveal the "ANSWER THE CALL" button so the player can move on.
	_reveal_tween.tween_callback(_reveal_proceed_button)


## Fade a node from transparent to fully visible over `duration`.
func _fade_in_step(node: Control, duration: float) -> void:
	_reveal_tween.tween_property(node, "modulate:a", 1.0, duration)


## Fade in while scaling up from `start_scale` to full size with a slight overshoot, so the
## element "pops" onto the card. The fade and the scale run together (parallel) on this beat.
func _pop_in_step(node: Control, duration: float, start_scale: float) -> void:
	node.scale = Vector2(start_scale, start_scale)
	# BACK easing overshoots past full size, then settles back — that little bounce is the pop.
	_reveal_tween.tween_property(node, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(node, "modulate:a", 1.0, duration)


## Fade in while sliding up by `rise` pixels (the node starts nudged down and rises into
## place). Position is animated, so we offset and restore the node's position:y.
func _slide_in_step(node: Control, duration: float, rise: float) -> void:
	var settled_y := node.position.y
	node.position.y = settled_y + rise
	_reveal_tween.parallel().tween_property(node, "position:y", settled_y, duration)
	_reveal_tween.parallel().tween_property(node, "modulate:a", 1.0, duration)


## Set the scale pivot of the labels we pop/pulse to their own center, so they grow from the
## middle instead of the top-left corner. Called on the first tween frame, once layout has
## given the labels a real size.
func _set_center_pivots() -> void:
	_headline_label.pivot_offset = _headline_label.size / 2.0
	_market_label.pivot_offset = _market_label.size / 2.0


## How long the typewriter should take, derived from the line length at a steady pace. The
## reveal tween waits exactly this long before showing the button, so the button always
## appears once the line finishes — there is no way to leave the player stuck.
func _typewriter_duration() -> float:
	var characters_per_second := 45.0
	return float(_narration_full_text.length()) / characters_per_second


## Reveal the narrator line one character at a time. Godot's visible_ratio on a Label draws
## only the first `ratio` fraction of the text — so tweening it 0 -> 1 is a clean typewriter
## with no string-slicing. We set the full text now (it was empty during the fade) and let
## the ratio walk it open. This runs on its OWN short-lived tween so it can outlive a single
## step of the main timeline; the main timeline waits for it via _typewriter_duration().
func _start_typewriter() -> void:
	_narration_label.text = _narration_full_text
	_narration_label.visible_ratio = 0.0
	var typer := create_tween()
	typer.tween_property(_narration_label, "visible_ratio", 1.0, _typewriter_duration())


## The reveal is over: fade the button up and enable it. From here the player can answer.
func _reveal_proceed_button() -> void:
	_proceed_button.disabled = false
	var button_fade := create_tween()
	button_fade.tween_property(_proceed_button, "modulate:a", 1.0, 0.35)


## Compact ×N formatting for the market-growth line (1,000 / 1 million / 1 billion …),
## so an order-of-magnitude jump reads cleanly instead of as a wall of zeroes.
func _format_multiplier(value: float) -> String:
	if value >= 1_000_000_000.0:
		return "%g billion" % (value / 1_000_000_000.0)
	if value >= 1_000_000.0:
		return "%g million" % (value / 1_000_000.0)
	# Group the thousands with commas (e.g. 1000 → "1,000").
	var digits := str(int(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return grouped


func _on_proceed_pressed() -> void:
	visible = false
	dismissed.emit()
