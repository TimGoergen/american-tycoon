class_name FinalDollarScreen
extends ColorRect

# "The Final Dollar" — the Earth capture climax sequence (GDD §10).
#
# Triggered when a dynasty captures 100% of Earth's broad money supply ($103.6T) at the
# exit of Earth White Collar (Tier 2) into Alien First Contact (Tier 3).
#
# Four staged beats (GDD §10.1):
#   Beat 1: The Parade — Counter rolls to 100.000000%, ticker tape / confetti shower,
#           fanfare audio, and sincere 50s-Americana narrator line.
#   Beat 2: The Commemorative Ledger — Award certificate of Total Market Saturation:
#           Dollars in circulation: $103.6T; Yours: $103.6T; Everyone else's: $0.00.
#   Beat 3: The Engine Stops — Income drops to $0.00/s, music winds down to eerie stillness.
#   Beat 4: Cosmic Transmission — Incoming transmission alert from the Luminari Collective
#           breaks the silence and hands off to First Contact.

signal finished

enum Beat {
	PARADE,
	LEDGER,
	ENGINE_STOPS,
	TRANSMISSION,
}

var _current_beat: Beat = Beat.PARADE

# ── Container references ──────────────────────────────────────────────────────
var _viewing_area: PanelContainer
var _outer_column: VBoxContainer
var _confetti_node: Control

var _phase1_parade: VBoxContainer
var _phase2_ledger: VBoxContainer
var _phase3_engine_stops: VBoxContainer
var _phase4_transmission: VBoxContainer

# ── Beat 1: Parade elements ───────────────────────────────────────────────────
var _parade_counter_label: Label
var _parade_headline_label: Label
var _parade_narrator_label: Label
var _parade_proceed_button: Button

# ── Beat 2: Ledger elements ───────────────────────────────────────────────────
var _ledger_certificate_panel: PanelContainer
var _ledger_circ_val: Label
var _ledger_yours_val: Label
var _ledger_others_val: Label
var _ledger_gen_val: Label
var _ledger_proceed_button: Button

# ── Beat 3: Engine Stops elements ─────────────────────────────────────────────
var _engine_income_label: Label
var _engine_subtitle_label: Label

# ── Beat 4: Transmission elements ─────────────────────────────────────────────
var _trans_eyebrow_label: Label
var _trans_civ_label: Label
var _trans_body_label: Label
var _trans_proceed_button: Button

# ── Confetti particle state ───────────────────────────────────────────────────
var _confetti_particles: Array[Dictionary] = []
const CONFETTI_COUNT := 70
var _confetti_active := false

var _generation_recorded := 1
var _cash_recorded := 103.6e12
var _roll_tween: Tween = null
var _blink_time := 0.0


func _ready() -> void:
	color = Color.BLACK
	visible = false

	_viewing_area = PanelContainer.new()
	UiPalette.apply_screen_bezel(_viewing_area)
	_viewing_area.add_theme_stylebox_override("panel", UiPalette.make_screen_panel_style())
	add_child(_viewing_area)

	# Confetti overlay behind text content but inside screen bezel
	_confetti_node = Control.new()
	_confetti_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confetti_node.draw.connect(_on_confetti_draw)
	_viewing_area.add_child(_confetti_node)

	var center := CenterContainer.new()
	_viewing_area.add_child(center)

	_outer_column = VBoxContainer.new()
	_outer_column.add_theme_constant_override("separation", 0)
	_outer_column.custom_minimum_size = Vector2(740, 0)
	center.add_child(_outer_column)

	_build_beat1_parade(_outer_column)
	_build_beat2_ledger(_outer_column)
	_build_beat3_engine_stops(_outer_column)
	_build_beat4_transmission(_outer_column)

	_hide_all_beats()


func _process(delta: float) -> void:
	if not visible:
		return

	if _confetti_active:
		_update_confetti(delta)
		_confetti_node.queue_redraw()

	if _current_beat == Beat.TRANSMISSION and _trans_eyebrow_label != null:
		_blink_time += delta
		var alpha := 0.4 + 0.6 * (0.5 + 0.5 * sin(_blink_time * TAU * 2.0))
		_trans_eyebrow_label.modulate.a = alpha


# ---------------------------------------------------------------------------
# Public Show API
# ---------------------------------------------------------------------------

func show_climax(generation: int, cash_earned: float) -> void:
	_generation_recorded = generation
	_cash_recorded = cash_earned
	visible = true

	# Start Beat 1: The Parade
	_show_beat1_parade()


# ---------------------------------------------------------------------------
# Beat 1 — The Parade
# ---------------------------------------------------------------------------

func _build_beat1_parade(parent: VBoxContainer) -> void:
	_phase1_parade = VBoxContainer.new()
	_phase1_parade.add_theme_constant_override("separation", 24)
	parent.add_child(_phase1_parade)

	var eyebrow := Label.new()
	eyebrow.text = "◄  THE AMERICAN DREAM ACHIEVED  ►"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
	eyebrow.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_phase1_parade.add_child(eyebrow)

	_parade_headline_label = Label.new()
	_parade_headline_label.text = "THE FINAL DOLLAR"
	_parade_headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parade_headline_label.add_theme_color_override("font_color", UiPalette.MUSTARD_GOLD)
	_parade_headline_label.add_theme_color_override("font_outline_color", UiPalette.NAVY)
	_parade_headline_label.add_theme_constant_override("outline_size", 6)
	_parade_headline_label.add_theme_font_size_override("font_size", UiPalette.FONT_PAGE_TITLE)
	_phase1_parade.add_child(_parade_headline_label)

	# Roll-up percentage ticker box
	var ticker_card := PanelContainer.new()
	var ticker_style := StyleBoxFlat.new()
	ticker_style.bg_color = UiPalette.NAVY
	ticker_style.set_corner_radius_all(14)
	ticker_style.set_content_margin_all(18)
	ticker_card.add_theme_stylebox_override("panel", ticker_style)
	_phase1_parade.add_child(ticker_card)

	var ticker_vbox := VBoxContainer.new()
	ticker_vbox.add_theme_constant_override("separation", 6)
	ticker_card.add_child(ticker_vbox)

	var ticker_caption := Label.new()
	ticker_caption.text = "GLOBAL BROAD MONEY CONVERTED"
	ticker_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker_caption.add_theme_color_override("font_color", UiPalette.PALE_GOLD)
	ticker_caption.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	ticker_vbox.add_child(ticker_caption)

	_parade_counter_label = Label.new()
	_parade_counter_label.text = "100.000000%"
	_parade_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parade_counter_label.add_theme_color_override("font_color", UiPalette.MONEY_GREEN)
	_parade_counter_label.add_theme_font_size_override("font_size", UiPalette.FONT_PAGE_TITLE)
	ticker_vbox.add_child(_parade_counter_label)

	# Narrator sincere praise
	_parade_narrator_label = Label.new()
	_parade_narrator_label.text = "\"Through grit, gumption, and good old-fashioned elbow grease, you've earned every last dollar on Earth!\""
	_parade_narrator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parade_narrator_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parade_narrator_label.custom_minimum_size = Vector2(680, 0)
	_parade_narrator_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_parade_narrator_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_phase1_parade.add_child(_parade_narrator_label)

	_parade_proceed_button = Button.new()
	_parade_proceed_button.text = "CLAIM THE EARTH"
	_parade_proceed_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	UiPalette.style_button(_parade_proceed_button, false)
	_parade_proceed_button.pressed.connect(_show_beat2_ledger)
	_phase1_parade.add_child(_parade_proceed_button)


func _show_beat1_parade() -> void:
	_current_beat = Beat.PARADE
	_hide_all_beats()
	_phase1_parade.visible = true

	# Start confetti
	_init_confetti()
	_confetti_active = true

	# Play fanfare stinger
	Audio.play(&"ceremony_fanfare")
	Haptics.pulse(60.0)

	# Roll-up ticker animation from 99.8% to 100.000000%
	_parade_proceed_button.modulate.a = 0.0
	_parade_narrator_label.modulate.a = 0.0

	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()

	_roll_tween = create_tween()
	_roll_tween.tween_method(func(val: float) -> void:
		_parade_counter_label.text = "%.6f%%" % val
	, 99.854120, 100.000000, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_roll_tween.tween_callback(func() -> void:
		Haptics.pulse(60.0)
	)

	_roll_tween.tween_property(_parade_narrator_label, "modulate:a", 1.0, 0.6)
	_roll_tween.tween_property(_parade_proceed_button, "modulate:a", 1.0, 0.4)


# ---------------------------------------------------------------------------
# Beat 2 — The Commemorative Ledger (Award Certificate)
# ---------------------------------------------------------------------------

func _build_beat2_ledger(parent: VBoxContainer) -> void:
	_phase2_ledger = VBoxContainer.new()
	_phase2_ledger.add_theme_constant_override("separation", 18)
	parent.add_child(_phase2_ledger)

	var cert_card := PanelContainer.new()
	var cert_style := StyleBoxFlat.new()
	cert_style.bg_color = UiPalette.CREAM
	cert_style.border_color = UiPalette.MUSTARD_GOLD
	cert_style.set_border_width_all(6)
	cert_style.set_corner_radius_all(16)
	cert_style.set_content_margin_all(24)
	cert_card.add_theme_stylebox_override("panel", cert_style)
	_phase2_ledger.add_child(cert_card)

	var cert_vbox := VBoxContainer.new()
	cert_vbox.add_theme_constant_override("separation", 14)
	cert_card.add_child(cert_vbox)

	var dept_label := Label.new()
	dept_label.text = "UNITED STATES DEPARTMENT OF COMMERCE\n& MONETARY ACQUISITION"
	dept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dept_label.add_theme_color_override("font_color", UiPalette.NAVY)
	dept_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	cert_vbox.add_child(dept_label)

	var title_label := Label.new()
	title_label.text = "COMMENDATION OF TOTAL SATURATION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", UiPalette.DARK_GOLD)
	title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	cert_vbox.add_child(title_label)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 3)
	div.color = UiPalette.MUSTARD_GOLD
	cert_vbox.add_child(div)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 10)
	cert_vbox.add_child(stats_grid)

	_add_cert_row(stats_grid, "Dollars in Circulation:", "$103,600,000,000,000.00", UiPalette.NAVY)
	_ledger_yours_val = _add_cert_row(stats_grid, "Your Fortune:", "$103,600,000,000,000.00", UiPalette.DARK_MONEY_GREEN)
	_ledger_others_val = _add_cert_row(stats_grid, "Everyone Else's:", "$0.00", UiPalette.DARK_GOLD)
	_ledger_gen_val = _add_cert_row(stats_grid, "Generations Taken:", "Generation 1", UiPalette.NAVY)
	_add_cert_row(stats_grid, "Global Market Share:", "100.000000%", UiPalette.KETCHUP_RED)

	var seal_card := PanelContainer.new()
	var seal_style := StyleBoxFlat.new()
	seal_style.bg_color = UiPalette.MUSTARD_GOLD
	seal_style.set_corner_radius_all(10)
	seal_style.set_content_margin_all(8)
	seal_card.add_theme_stylebox_override("panel", seal_style)
	cert_vbox.add_child(seal_card)

	var seal_label := Label.new()
	seal_label.text = "★ 100% CERTIFIED MONOPOLY — ALL DOLLARS ACCOUNTED FOR ★"
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	seal_label.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
	seal_card.add_child(seal_label)

	_ledger_proceed_button = Button.new()
	_ledger_proceed_button.text = "ACCEPT COMMENDATION"
	_ledger_proceed_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	UiPalette.style_button(_ledger_proceed_button, false)
	_ledger_proceed_button.pressed.connect(_show_beat3_engine_stops)
	_phase2_ledger.add_child(_ledger_proceed_button)


func _add_cert_row(grid: GridContainer, label_text: String, val_text: String, val_color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", UiPalette.NAVY)
	lbl.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	grid.add_child(lbl)

	var val := Label.new()
	val.text = val_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_color_override("font_color", val_color)
	val.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	grid.add_child(val)
	return val


func _show_beat2_ledger() -> void:
	_current_beat = Beat.LEDGER
	_hide_all_beats()
	_phase2_ledger.visible = true

	_ledger_gen_val.text = "Generation %d" % _generation_recorded
	Audio.play(&"ceremony_heir")
	Haptics.pulse(30.0)


# ---------------------------------------------------------------------------
# Beat 3 — The Engine Stops (Total Victory & Total Stagnation)
# ---------------------------------------------------------------------------

func _build_beat3_engine_stops(parent: VBoxContainer) -> void:
	_phase3_engine_stops = VBoxContainer.new()
	_phase3_engine_stops.add_theme_constant_override("separation", 24)
	parent.add_child(_phase3_engine_stops)

	var engine_card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UiPalette.INK_NAVY
	card_style.set_corner_radius_all(16)
	card_style.set_content_margin_all(32)
	engine_card.add_theme_stylebox_override("panel", card_style)
	_phase3_engine_stops.add_child(engine_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	engine_card.add_child(vbox)

	var headline := Label.new()
	headline.text = "CURRENT INCOME RATE"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", UiPalette.MID_GRAY)
	headline.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	vbox.add_child(headline)

	_engine_income_label = Label.new()
	_engine_income_label.text = "$0.00 / s"
	_engine_income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_engine_income_label.add_theme_color_override("font_color", UiPalette.CREAM)
	_engine_income_label.add_theme_font_size_override("font_size", UiPalette.FONT_PAGE_TITLE)
	vbox.add_child(_engine_income_label)

	_engine_subtitle_label = Label.new()
	_engine_subtitle_label.text = "There is no one left on Earth to pay you."
	_engine_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_engine_subtitle_label.add_theme_color_override("font_color", UiPalette.LIGHT_GRAY)
	_engine_subtitle_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	vbox.add_child(_engine_subtitle_label)


func _show_beat3_engine_stops() -> void:
	_current_beat = Beat.ENGINE_STOPS
	_hide_all_beats()
	_phase3_engine_stops.visible = true
	_confetti_active = false
	_confetti_particles.clear()
	_confetti_node.queue_redraw()

	# Wind down the music / play power down
	Audio.wind_down_music(2.2)
	Audio.play(&"ceremony_power_down")
	Haptics.pulse(60.0)

	# Quiet beat: wait 2.4s in stillness, then advance automatically to Cosmic Transmission
	var timer := get_tree().create_timer(2.4)
	timer.timeout.connect(_show_beat4_transmission)


# ---------------------------------------------------------------------------
# Beat 4 — Cosmic Interruption (Transmission from Luminari)
# ---------------------------------------------------------------------------

func _build_beat4_transmission(parent: VBoxContainer) -> void:
	_phase4_transmission = VBoxContainer.new()
	_phase4_transmission.add_theme_constant_override("separation", 20)
	parent.add_child(_phase4_transmission)

	_trans_eyebrow_label = Label.new()
	_trans_eyebrow_label.text = "◄  INCOMING INTERSTELLAR TRANSMISSION  ►"
	_trans_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trans_eyebrow_label.add_theme_color_override("font_color", UiPalette.ACTIVE_BLUE)
	_trans_eyebrow_label.add_theme_font_size_override("font_size", UiPalette.FONT_SUBHEAD)
	_phase4_transmission.add_child(_trans_eyebrow_label)

	_trans_civ_label = Label.new()
	_trans_civ_label.text = "LUMINARI COLLECTIVE"
	_trans_civ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trans_civ_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_trans_civ_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_phase4_transmission.add_child(_trans_civ_label)

	var trans_card := PanelContainer.new()
	var trans_style := StyleBoxFlat.new()
	trans_style.bg_color = UiPalette.CREAM
	trans_style.border_color = UiPalette.ACTIVE_BLUE
	trans_style.set_border_width_all(4)
	trans_style.set_corner_radius_all(14)
	trans_style.set_content_margin_all(20)
	trans_card.add_theme_stylebox_override("panel", trans_style)
	_phase4_transmission.add_child(trans_card)

	_trans_body_label = Label.new()
	_trans_body_label.text = "\"Earth Market Status: SATURATED. Congratulations!\n\nAn exciting expansion opportunity awaits the discerning dynasty across the stars...\""
	_trans_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trans_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trans_body_label.custom_minimum_size = Vector2(660, 0)
	_trans_body_label.add_theme_color_override("font_color", UiPalette.ACTIVE_BLUE)
	_trans_body_label.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	trans_card.add_child(_trans_body_label)

	_trans_proceed_button = Button.new()
	_trans_proceed_button.text = "ESTABLISH FIRST CONTACT"
	_trans_proceed_button.custom_minimum_size = Vector2(0, UiPalette.STANDARD_BUTTON_HEIGHT)
	UiPalette.style_button(_trans_proceed_button, false)
	_trans_proceed_button.pressed.connect(_on_finish_pressed)
	_phase4_transmission.add_child(_trans_proceed_button)


func _show_beat4_transmission() -> void:
	_current_beat = Beat.TRANSMISSION
	_hide_all_beats()
	_phase4_transmission.visible = true

	Audio.play(&"ceremony_contact")
	Haptics.pulse(30.0)


func _on_finish_pressed() -> void:
	visible = false
	finished.emit()


# ---------------------------------------------------------------------------
# Helpers & Confetti Simulation
# ---------------------------------------------------------------------------

func _hide_all_beats() -> void:
	_phase1_parade.visible = false
	_phase2_ledger.visible = false
	_phase3_engine_stops.visible = false
	_phase4_transmission.visible = false


func _init_confetti() -> void:
	_confetti_particles.clear()
	var screen_w := _viewing_area.size.x if _viewing_area.size.x > 0 else 800.0
	var screen_h := _viewing_area.size.y if _viewing_area.size.y > 0 else 1400.0

	var colors := [
		UiPalette.KETCHUP_RED,
		UiPalette.MUSTARD_GOLD,
		UiPalette.MONEY_GREEN,
		UiPalette.NAVY,
		UiPalette.ATOMIC_TEAL,
		UiPalette.PALE_GOLD,
	]

	for i in range(CONFETTI_COUNT):
		_confetti_particles.append({
			"pos": Vector2(randf_range(0, screen_w), randf_range(-screen_h * 0.5, screen_h * 0.8)),
			"vel": Vector2(randf_range(-30, 30), randf_range(120, 280)),
			"size": Vector2(randf_range(10, 20), randf_range(6, 12)),
			"rot": randf_range(0, TAU),
			"rot_speed": randf_range(-4.0, 4.0),
			"color": colors[randi() % colors.size()],
		})


func _update_confetti(delta: float) -> void:
	var screen_w := _viewing_area.size.x if _viewing_area.size.x > 0 else 800.0
	var screen_h := _viewing_area.size.y if _viewing_area.size.y > 0 else 1400.0

	for p in _confetti_particles:
		p["pos"] += p["vel"] * delta
		p["rot"] += p["rot_speed"] * delta
		p["pos"].x += sin(p["rot"] * 2.0) * 20.0 * delta

		if p["pos"].y > screen_h + 20.0:
			p["pos"].y = randf_range(-40.0, -10.0)
			p["pos"].x = randf_range(0, screen_w)


func _on_confetti_draw() -> void:
	for p in _confetti_particles:
		var transform := Transform2D(p["rot"], p["pos"])
		var rect := Rect2(-p["size"] / 2.0, p["size"])
		_confetti_node.draw_set_transform_matrix(transform)
		_confetti_node.draw_rect(rect, p["color"])

	_confetti_node.draw_set_transform_matrix(Transform2D.IDENTITY)
