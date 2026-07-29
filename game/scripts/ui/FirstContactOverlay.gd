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

# Fixed-chrome text, per beat flavor. The overlay serves TWO kinds of arrival since the
# Earth split (Plans/Earth_Split_Epochs.md): the alien First Contact, and the Earth→Earth
# PROMOTION into White Collar (tier 2) — same staged reveal, different voice. show_contact
# picks a set by the epoch's civilization ("Earth" = promotion).
const EYEBROW_ALIEN := "◄  INCOMING TRANSMISSION  ►"
const HEADLINE_ALIEN := "FIRST CONTACT"
const NOTE_ALIEN := "A new kind of business opens in their market. Your staff can be upgraded with their technology, too."
const BUTTON_ALIEN := "ANSWER THE CALL"
const EYEBROW_PROMOTION := "◄  MEMO FROM UPSTAIRS  ►"
const HEADLINE_PROMOTION := "MOVING UP"
const NOTE_PROMOTION := "A new kind of business opens uptown. Your blue-collar crews can take on a second tier of staff, too."
const BUTTON_PROMOTION := "TAKE THE PROMOTION"

var _eyebrow_label: Label
var _headline_label: Label
var _civ_label: Label
var _planet_label: Label
var _flavor_label: Label
var _note_label: Label
## The civilization's own first words (EpochCatalog.hail) — the actual transmission,
## typewritten in the civ's accent color so every contact sounds and looks different
## (Tim, 2026-07-07: the contacts read samey).
var _hail_label: Label
var _market_label: Label
var _narration_label: Label
var _proceed_button: Button

# Every element of the card that the reveal sequence fades/scales in, in reveal order.
# Collected so we can reset them all cleanly (alpha 0, default scale) on every show.
var _staged_nodes: Array[Control] = []

## Drives the eyebrow's slow blink so the moment reads as a live, urgent transmission.
var _blink_time := 0.0

## The full hail (the civilization's words); revealed one character at a time by the
## typewriter step — it IS the incoming transmission the eyebrow promises. The
## narrator's capper fades in afterward as plain text.
var _hail_full_text := ""

## The single tween that runs the whole reveal. Stored so a re-entrant show_contact()
## can .kill() it before starting over (Godot tweens keep running on their own once
## created — there is no scene node to free, so we must hold the reference to stop it).
var _reveal_tween: Tween = null

## The hail's typewriter runs on its own short tween; held so a tap-to-skip can .kill() it (like
## _reveal_tween, a tween has no scene node to free, so we must keep the handle to stop it).
var _typewriter_tween: Tween = null


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
	# Epoch-transition type is LARGE and HIGH-CONTRAST (Tim, 2026-07-03: these screens'
	# fonts were too small and too low-contrast to read comfortably): every line stepped
	# up a size, and the gold lines carry a NAVY outline — gold-on-gold outlines vanished
	# into the cream plate, navy makes the gold pop off it.
	_eyebrow_label = Label.new()
	_eyebrow_label.text = EYEBROW_ALIEN
	_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	_eyebrow_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	column.add_child(_eyebrow_label)

	_headline_label = Label.new()
	_headline_label.text = HEADLINE_ALIEN
	_headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Gold: this is a celebratory milestone, like the Legacy reward chrome.
	_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_headline_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_headline_label.add_theme_constant_override("outline_size", 5)
	_headline_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	column.add_child(_headline_label)

	# The civilization Earth has just reached — the big name on the card.
	_civ_label = Label.new()
	_civ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_civ_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_civ_label.custom_minimum_size = Vector2(760, 0)
	_civ_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_civ_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_civ_label.add_theme_constant_override("outline_size", 3)
	_civ_label.add_theme_font_size_override("font_size", UiPalette.FONT_DISPLAY)
	column.add_child(_civ_label)

	# Home world + their currency (flavor only — Earth stays on dollars). Both wrap for
	# the same reason as the market line: per-beat copy varies in length, and an
	# unwrapped line longer than the card would widen it off-screen.
	_planet_label = Label.new()
	_planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_planet_label.custom_minimum_size = Vector2(760, 0)
	_planet_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_planet_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_planet_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.custom_minimum_size = Vector2(760, 0)
	# Darkened harder than the palette green so it holds contrast on the cream plate.
	_flavor_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN.darkened(0.35))
	_flavor_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_flavor_label)

	# The civilization's OWN first words — the transmission itself, typewritten in the
	# civ's accent color (set per show_contact). Quoted so it clearly reads as them
	# speaking, distinct from the narrator's capper below the market line.
	_hail_label = Label.new()
	_hail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hail_label.custom_minimum_size = Vector2(760, 0)
	_hail_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	column.add_child(_hail_label)

	# The headline payoff: how many times larger the new market is. Big and gold, so the
	# scale jump lands as the reason this is worth celebrating. This is the element the
	# reveal punches hardest (an overshoot scale-in pop).
	_market_label = Label.new()
	_market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wraps like the civ/hail lines: the alien ratios are short ("×16,807"), but the
	# promotion beat's "×1.38 million" at this headline size is wider than a portrait
	# screen — an unwrapped Label's minimum width forces the whole card column past the
	# right edge (Tim's report, 2026-07-29). Wrapping caps the card at its 760px design.
	_market_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_market_label.custom_minimum_size = Vector2(760, 0)
	_market_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_market_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_market_label.add_theme_constant_override("outline_size", 5)
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
	_narration_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	column.add_child(_narration_label)

	_note_label = Label.new()
	# Foreshadows both rewards of contact: a brand-new kind of business opens in the alien
	# market (negotiated via the trade-deal minigame on "Answer the Call"), and every existing
	# property's staffer can now be upgraded to this civilization's technology tier.
	# (Text is swapped per show_contact — the Earth→Earth promotion beat has its own copy.)
	_note_label.text = NOTE_ALIEN
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(760, 0)
	_note_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_note_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	column.add_child(_note_label)

	_proceed_button = Button.new()
	_proceed_button.text = BUTTON_ALIEN
	_proceed_button.custom_minimum_size = Vector2(0, 96)
	_proceed_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	UiPalette.style_button(_proceed_button, true)
	_proceed_button.pressed.connect(_on_proceed_pressed)
	column.add_child(_proceed_button)

	# Push every line LARGER and BOLDER (Tim, 2026-07-11): the epoch-transition screens still read
	# too small/soft after the earlier pass. Bump each label ~20% and faux-bold it — bold also lifts
	# contrast on the cream plate. One loop so there are no per-line edits; the button keeps its own
	# styling. Done after all lines are built so it catches every one.
	for child in column.get_children():
		if child is Label:
			var label := child as Label
			var current := label.get_theme_font_size("font_size")
			label.add_theme_font_size_override("font_size", int(round(current * 1.2)))
			label.add_theme_font_override("font", UiPalette.make_bold_font())

	# The card lines, in the order the reveal walks through them. `note` and the button are
	# handled at the end of the sequence, so they are NOT in this list. Keeping this list is
	# what lets the re-entrancy reset be a simple loop instead of touching each node by hand.
	_staged_nodes = [
		_eyebrow_label,
		_headline_label,
		_civ_label,
		_planet_label,
		_flavor_label,
		_hail_label,
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

	# The Earth→Earth PROMOTION beat (White Collar, tier 2 — the Earth split) reuses this
	# staged reveal with its own voice: no alien transmission framing, and the big name on
	# the card is the new ERA ("WHITE COLLAR"), since the civilization is still Earth.
	var is_promotion := String(epoch["civilization"]) == "Earth"
	_eyebrow_label.text = EYEBROW_PROMOTION if is_promotion else EYEBROW_ALIEN
	_headline_label.text = HEADLINE_PROMOTION if is_promotion else HEADLINE_ALIEN
	_note_label.text = NOTE_PROMOTION if is_promotion else NOTE_ALIEN
	_proceed_button.text = BUTTON_PROMOTION if is_promotion else BUTTON_ALIEN
	if is_promotion:
		_civ_label.text = "WHITE COLLAR"
		_planet_label.text = "Same planet — higher floors."
	else:
		_civ_label.text = String(epoch["civilization"])
		_planet_label.text = "Home world: %s" % String(epoch["home_planet"])
	_flavor_label.text = "They trade in %s." % String(epoch["currency_flavor"])
	# The civ's accent color tints its name and its words, so each contact is visually
	# distinct as well as verbally (Tim, 2026-07-07).
	var accent := EpochCatalog.accent_color(tier)
	_civ_label.add_theme_color_override("font_color", accent)
	_hail_label.add_theme_color_override("font_color", accent)
	# How many times larger the new market is than the one just consumed (the scale jump
	# between this epoch and the previous one) — the celebratory payoff line.
	var growth := EpochCatalog.economy_scale(tier) / EpochCatalog.economy_scale(tier - 1)
	_market_label.text = "THE MARKET JUST GREW ×%s" % _format_multiplier(growth)

	# The hail (their words) is held in full and revealed letter by letter during the
	# sequence, so its label starts empty; the narrator's capper is plain text that
	# simply fades in near the end.
	_hail_full_text = "“%s”" % EpochCatalog.hail(tier)
	# Give the hail its FULL text now and let the layout size it at FULL height; _set_center_pivots
	# (which runs after layout) then PINS that height and hides the characters (visible_ratio 0). The
	# typewriter reveals them IN PLACE without the label growing, so nothing below it moves — printed
	# text never shifts as later lines appear (Tim, 2026-07-11). visible_ratio alone can't reserve the
	# space: in this Godot version an autowrapped label's height tracks only the VISIBLE lines, so the
	# height must be pinned. custom_minimum_size resets to height 0 so THIS hail recomputes its own.
	_hail_label.text = _hail_full_text
	_hail_label.custom_minimum_size = Vector2(760, 0)
	_hail_label.visible_ratio = 1.0
	_narration_label.text = EpochCatalog.contact_line(tier)

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

	# 3) Civilization name pops in gently (a mild scale-up + fade). This used to be a
	#    slide (animating position.y), but a VBoxContainer owns its children's positions:
	#    the slide captured the label's y from a layout computed BEFORE the new civ text
	#    resized it, so the tween could park the name too low, overlapping the line below
	#    (the render bug Tim hit at the end of Earth, 2026-07-03). Scale doesn't touch
	#    layout, so the pop can never fight the container.
	_pop_in_step(_civ_label, 0.40, 0.85)

	# 4) Home world and 5) currency flavor arrive as quick quiet fades.
	_fade_in_step(_planet_label, 0.30)
	_fade_in_step(_flavor_label, 0.30)

	# 6) THE TRANSMISSION: the civilization's own first words typewrite in, in their
	#    accent color — this is the payoff the blinking "INCOMING TRANSMISSION" eyebrow
	#    promised (it used to typewrite the narrator's commentary instead).
	_fade_in_step(_hail_label, 0.25)
	_reveal_tween.tween_callback(_start_typewriter)
	# Hold the timeline open for the typewriter, which runs on its OWN tween. Time it from
	# the text length at a steady characters-per-second so the next beat always waits for
	# the line to finish (and there is always an end, so the player is never stuck).
	var typewriter_seconds := _typewriter_duration()
	_reveal_tween.tween_interval(typewriter_seconds)

	# 7) THE PAYOFF: the market-growth line pops hardest — a bigger overshoot from a smaller
	#    start, so the scale jump is the visual climax of the card.
	_pop_in_step(_market_label, 0.55, 0.4)
	# A brief follow-up pulse on the payoff line (up past full, settle back to full) so it
	# reads as a beat that lands rather than a thing that merely appeared.
	_reveal_tween.tween_property(_market_label, "scale", Vector2(1.12, 1.12), 0.12)
	_reveal_tween.tween_property(_market_label, "scale", Vector2.ONE, 0.18)

	# 8) The narrator's deadpan capper fades in under the payoff.
	_fade_in_step(_narration_label, 0.30)

	# 9) Finally, reveal the "ANSWER THE CALL" button so the player can move on.
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


## Set the scale pivot of the labels we pop/pulse to their own center, so they grow from the
## middle instead of the top-left corner. Called on the first tween frame, once layout has
## given the labels a real size.
func _set_center_pivots() -> void:
	_headline_label.pivot_offset = _headline_label.size / 2.0
	_civ_label.pivot_offset = _civ_label.size / 2.0
	_market_label.pivot_offset = _market_label.size / 2.0
	# Pin the hail to its full-text height now that layout has sized it, THEN hide the characters — so
	# the typewriter (visible_ratio 0->1) can't shrink/grow the label and shove the card around.
	_hail_label.custom_minimum_size.y = _hail_label.size.y
	_hail_label.visible_ratio = 0.0


## How long the typewriter should take, derived from the hail's length at a steady pace.
## The reveal tween waits exactly this long before the next beat, so the sequence always
## resumes once the line finishes — there is no way to leave the player stuck.
func _typewriter_duration() -> float:
	var characters_per_second := 45.0
	return float(_hail_full_text.length()) / characters_per_second


## Reveal the hail one character at a time. Godot's visible_ratio on a Label draws
## only the first `ratio` fraction of the text — so tweening it 0 -> 1 is a clean typewriter
## with no string-slicing. We set the full text now (it was empty during the fade) and let
## the ratio walk it open. This runs on its OWN short-lived tween so it can outlive a single
## step of the main timeline; the main timeline waits for it via _typewriter_duration().
func _start_typewriter() -> void:
	# The full text + visible_ratio 0 were set up front (see show_contact) so the layout is already
	# stable and reserved; just walk the ratio open in place — no size change, nothing below moves.
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(_hail_label, "visible_ratio", 1.0, _typewriter_duration())


## The reveal is over: fade the button up and enable it. From here the player can answer.
func _reveal_proceed_button() -> void:
	_proceed_button.disabled = false
	var button_fade := create_tween()
	button_fade.tween_property(_proceed_button, "modulate:a", 1.0, 0.35)


## Compact ×N formatting for the market-growth line (1,000 / 1 million / 1 billion …),
## so an order-of-magnitude jump reads cleanly instead of as a wall of zeroes.
func _format_multiplier(value: float) -> String:
	# 3 significant figures: the promotion beat's ratio is a messy 1.38139... million
	# (Earth total ÷ the $75M Blue Collar slice), and "×1.38 million" reads as a number
	# while "×1.38139 million" reads as a defect. Alien steps are exact and unaffected.
	if value >= 1_000_000_000.0:
		return "%.3g billion" % (value / 1_000_000_000.0)
	if value >= 1_000_000.0:
		return "%.3g million" % (value / 1_000_000.0)
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


## Tap-to-skip: a press anywhere WHILE the staged reveal is still running snaps the whole card to
## its finished state and lights the ANSWER THE CALL button, so a player who doesn't want to wait
## out the animation isn't forced to (Tim 2026-07-11). Once the reveal is done (button live), taps
## fall through normally so the button handles them. The event is consumed so this same tap doesn't
## also press the just-revealed button (which would skip AND dismiss in one touch).
func _input(event: InputEvent) -> void:
	if not visible or not _proceed_button.disabled:
		return
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if pressed:
		_skip_reveal()
		get_viewport().set_input_as_handled()


## Snap every staged line to fully visible, complete the typewriter, and reveal the button — the
## finished state of the reveal — killing the running tweens so they can't animate over it.
func _skip_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_typewriter_tween = null
	for node in _staged_nodes:
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
	_hail_label.visible_ratio = 1.0
	_proceed_button.modulate.a = 1.0
	_proceed_button.disabled = false


func _on_proceed_pressed() -> void:
	visible = false
	dismissed.emit()
