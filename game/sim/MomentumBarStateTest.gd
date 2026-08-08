extends SceneTree

# Headless verification that the momentum bar paints the state Main pushed it, REGARDLESS of
# whether that push arrives before or after the bar enters the scene tree.
#
# Usage: godot --headless --path . --script res://sim/MomentumBarStateTest.gd
#
# WHY THIS EXISTS (Tim, 2026-08-06): "auto-buy is purchased in the estate tab, but the button is
# not visible on the game tab after prestige."
#
# Main._build_property_tab() builds the momentum bar into a DETACHED VBoxContainer and pushes the
# auto-purchase state immediately. A node only runs _ready() when it enters the tree, which happens
# later when the tab is mounted — so that first push routinely lands while the button does not yet
# exist. The bar used to drop the push on the floor and then paint itself locked-and-off in _ready,
# hiding a button the player had paid for. Main memoises what it has pushed, so it never noticed
# and never corrected it.
#
# The bug hid on a fresh dynasty: the desk is unowned at build time there, so BUYING it later
# flipped unlocked false -> true and repainted correctly. Only a post-prestige launch — desk
# already owned when the bar is built — could show it. This test reproduces that exact order, and
# fails (button hidden) against the pre-fix MomentumBar.
#
# TWO THINGS THIS FILE HAS TO DO DIFFERENTLY FROM THE OTHER SIMS, both learned the hard way:
#
#   1. THE SCRIPT PATH IS ASSEMBLED, NOT A LITERAL. Naming `MomentumBar` statically — or handing
#      load() a constant string it can fold — creates a class-resolution cycle that makes unrelated
#      core members (GameState.auto_purchase) unresolvable and breaks parsing of the WHOLE file,
#      with errors pointing at innocent lines. This is also why the test lives here rather than in
#      AutoPurchaseTest.gd: that harness is core-only and must stay that way.
#
#   2. IT AWAITS A FRAME. During SceneTree._initialize() the root is not yet inside the tree, so
#      add_child() does NOT run _ready() and every node stays unbuilt. Without the await, all the
#      assertions below fail identically whether the bug is present or not — a test that always
#      fails proves as little as one that always passes.
#
# Exits 0 only if every check passes.

var _failures := 0

## Mirrors MomentumBar.AUTO_PURCHASE_IDLE_DOT_SECONDS. Duplicated rather than read off the script,
## because the whole point of the ellipsis assertions is to step the clock by one dwell — if this
## drifts from the bar's own value the test starts checking nothing, so a mismatch here should be
## noticed. Bump both together.
const AUTO_PURCHASE_IDLE_DOT_SECONDS_FOR_TEST := 0.45


func _initialize() -> void:
	# _initialize cannot itself await, so the body runs as a coroutine off it.
	_run()


func _run() -> void:
	print("=== Momentum bar — pushed-state verification ===\n")

	var tuning := ConfigLoader.load_tuning(false)
	if tuning == null:
		print("FAILED to load tuning")
		quit(1)
		return

	# Assembled, not a literal — see note 1 in the file header.
	var script_path := "res://scripts/ui/" + "MomentumBar.gd"
	var bar_script: GDScript = load(script_path)
	if bar_script == null:
		print("FAILED to load MomentumBar.gd")
		quit(1)
		return

	await _test_owned_push_before_ready_shows_button(bar_script, tuning)
	await _test_untold_bar_starts_hidden(bar_script, tuning)
	await _test_purchase_pulse(bar_script, tuning)
	await _test_expands_while_running(bar_script, tuning)
	await _test_cycle_wave(bar_script, tuning)
	await _test_overdrive_availability_pulse(bar_script, tuning)

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


## Find the text of the first VISIBLE Label anywhere under `root_node` whose text starts with
## `prefix`. The rate readout is an internal part of the AUTO-BUY button's face rather than part of
## the bar's public surface, so the test reaches for it by shape instead of widening the API just to
## be observable.
func _find_label_text_containing(root_node: Node, prefix: String) -> String:
	for child in root_node.get_children():
		var label := child as Label
		if label != null and label.visible and label.text.begins_with(prefix):
			return label.text
		var found := _find_label_text_containing(child, prefix)
		if found != "":
			return found
	return ""


## The AUTO-BUY chevron's current texture. It is the first TextureRect under the button whose box is
## square — the caption's two glyphs are square too, but they live under a hidden container while the
## button is expanded, and this is only ever asked while expanded or collapsed with the caption
## present, so the arrow's own container being visible is what distinguishes it.
func _find_arrow_texture(bar: Control) -> Texture2D:
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		return null
	return _first_visible_texture(button)


## The chevron's TextureRect itself, for measuring where it ends.
func _find_arrow_rect(bar: Control) -> TextureRect:
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		return null
	for child in button.get_children():
		for grandchild in (child as Node).get_children():
			var rect := grandchild as TextureRect
			# Skip the cycle wave: it is a TextureRect too, it is the button's FIRST child, and it
			# is painted from a GradientTexture2D rather than an art asset. Without this the arrow
			# assertions silently began measuring the wave instead.
			if rect == null or not rect.is_visible_in_tree():
				continue
			if rect.texture is GradientTexture2D:
				continue  # the cycle wave, not the chevron
			return rect
	return null




## The Label node (not just its text) whose text starts with `prefix`, for measuring where it starts.
func _find_label_node(node: Node, prefix: String) -> Label:
	for child in node.get_children():
		var label := child as Label
		if label != null and label.is_visible_in_tree() and label.text.begins_with(prefix):
			return label
		var found := _find_label_node(child, prefix)
		if found != null:
			return found
	return null


func _first_visible_texture(node: Node) -> Texture2D:
	for child in node.get_children():
		var rect := child as TextureRect
		if rect != null and rect.is_visible_in_tree() and not (rect.texture is GradientTexture2D):
			return rect.texture
		var found := _first_visible_texture(child)
		if found != null:
			return found
	return null


## Assert helper: prints a pass/fail line and counts failures.
func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


## Build a bar, optionally tell it the desk state BEFORE mounting, then mount and let it build.
## Returns the bar once its _ready has run.
func _mount_bar(bar_script: GDScript, tuning: TuningConfig, push: bool,
		unlocked: bool, enabled: bool) -> Control:
	var bar: Control = bar_script.new()
	bar.setup(RushMomentumState.new(tuning), tuning)
	if push:
		bar.set_auto_purchase_state(unlocked, enabled)
	root.add_child(bar)
	await process_frame  # see note 2 in the file header — without this, _ready never runs
	return bar


## THE POST-PRESTIGE ORDER: tell a detached bar the desk is owned, THEN mount it.
func _test_owned_push_before_ready_shows_button(
		bar_script: GDScript, tuning: TuningConfig) -> void:
	print("1. A desk owned before the bar is mounted still shows its button")

	# Prove the precondition on a bar we hold back deliberately: at push time there is no tree
	# and no button, which is exactly the situation that used to swallow the state.
	var detached: Control = bar_script.new()
	detached.setup(RushMomentumState.new(tuning), tuning)
	_check("the bar is not in the tree yet (the condition that caused the bug)",
		not detached.is_inside_tree())
	detached.set_auto_purchase_state(true, false)
	_check("...and its button genuinely does not exist yet",
		detached.get_auto_purchase_button() == null)
	detached.queue_free()

	var bar: Control = await _mount_bar(bar_script, tuning, true, true, false)
	var button: Button = bar.get_auto_purchase_button()
	_check("mounting the bar builds the button", button != null)
	if button != null:
		_check("the owned button is VISIBLE despite the push arriving first", button.visible)
		_check("...and is tappable (disabled tracks visible)", not button.disabled)
	bar.queue_free()

	# The ON look must survive the same ordering too. Auto-purchase is deliberately not carried
	# across succession, but the bar must not depend on that policy to paint itself correctly.
	var lit: Control = await _mount_bar(bar_script, tuning, true, true, true)
	var lit_button: Button = lit.get_auto_purchase_button()
	_check("an owned AND enabled desk also survives the early push",
		lit_button != null and lit_button.visible)
	lit.queue_free()


## The reverse must still hold: a bar nobody told anything starts hidden, so an unowned desk
## never leaks a button the player has not bought.
func _test_untold_bar_starts_hidden(bar_script: GDScript, tuning: TuningConfig) -> void:
	print("\n2. A bar that was never told anything starts hidden")

	var fresh: Control = await _mount_bar(bar_script, tuning, false, false, false)
	var button: Button = fresh.get_auto_purchase_button()
	_check("the button exists after mounting", button != null)
	if button != null:
		_check("an unowned desk keeps its button hidden", not button.visible)
		_check("...and untappable", button.disabled)

		# And an explicit "not owned" push after mounting must keep it hidden.
		fresh.set_auto_purchase_state(false, false)
		_check("an explicit unowned push leaves it hidden", not button.visible)
	fresh.queue_free()


## The purchase pulse (Tim, 2026-08-07): the button flares when the desk actually buys.
##
## Decay is driven by calling _process with an explicit delta rather than awaiting real frames —
## a frame is ~16ms against a 0.35s pulse, so waiting it out would take twenty-odd awaits and make
## the test depend on wall-clock timing. One synthetic second is deterministic.
func _test_purchase_pulse(bar_script: GDScript, tuning: TuningConfig) -> void:
	print("\n3. The AUTO-BUY button flares on a purchase and returns to rest")

	# Mounted OWNED but SWITCHED OFF, so the button is at its collapsed, declared width. Switched on
	# it expands to fill the row (SIZE_EXPAND_FILL), and its width becomes whatever the layout
	# hands it — which would make the "scale, not size" assertion below meaningless. The pulse
	# itself does not care: flash_auto_purchase only requires the button to be VISIBLE, and an
	# owned desk's button is visible whether the mode is running or not.
	var bar: Control = await _mount_bar(bar_script, tuning, true, true, false)
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		_check("the owned button exists (pulse cannot be tested without it)", false)
		bar.queue_free()
		return

	_check("the button starts at rest (plain white modulate)", button.modulate.is_equal_approx(
		Color.WHITE))
	_check("...and at rest scale", button.scale.is_equal_approx(Vector2.ONE))

	bar.flash_auto_purchase()
	bar._process(0.0)  # apply the pulse without advancing it
	_check("a purchase brightens the button", button.modulate.r > 1.0)
	_check("a purchase also swells the button", button.scale.x > 1.0)
	# The swell must be SCALE, never size: this button shares an HBoxContainer with the meter, so a
	# real size change would re-run the layout and shove the meter sideways on every purchase.
	#
	# Compared against the bar's OWN declared width rather than a literal. This assertion used to
	# hardcode 210 and failed the day the button was widened to 244 — a true statement about a
	# stale number, which is the least useful kind of test failure.
	var declared_width: float = float(bar_script.get_script_constant_map()["AUTO_PURCHASE_WIDTH"])
	_check("the swell leaves the layout box untouched (scale, not size)",
		is_equal_approx(button.size.x, declared_width))
	# Growing about the centre, not the top-left corner.
	_check("it grows about its centre", button.pivot_offset.is_equal_approx(button.size * 0.5))

	# Mid-pulse it must be dimmer than the peak but still brighter than rest — i.e. actually
	# decaying, not latched at full brightness until it snaps off.
	var peak := button.modulate.r
	bar._process(0.2)
	_check("the flare decays rather than latching",
		button.modulate.r < peak and button.modulate.r > 1.0)

	# Retriggering mid-pulse restarts it rather than stacking into something brighter.
	bar.flash_auto_purchase()
	bar._process(0.0)
	_check("a second purchase mid-pulse restarts it (never stacks past the peak)",
		is_equal_approx(button.modulate.r, peak))

	# Well past the pulse length, the button must be EXACTLY white again — a residual tint here
	# would leave the control permanently discoloured.
	bar._process(1.0)
	_check("the button returns to exactly plain white", button.modulate.is_equal_approx(
		Color.WHITE))
	_check("...and to exactly rest scale", button.scale.is_equal_approx(Vector2.ONE))

	bar.queue_free()

	# A hidden button (desk unowned) must never pulse: it cannot have bought anything.
	var hidden: Control = await _mount_bar(bar_script, tuning, false, false, false)
	var hidden_button: Button = hidden.get_auto_purchase_button()
	hidden.flash_auto_purchase()
	hidden._process(0.0)
	_check("an unowned desk's hidden button never flares",
		hidden_button != null and hidden_button.modulate.is_equal_approx(Color.WHITE))
	_check("...and never swells",
		hidden_button != null and hidden_button.scale.is_equal_approx(Vector2.ONE))
	hidden.queue_free()


## The AUTO-BUY button takes over the row while the mode runs (Tim, 2026-08-07), covering the rush
## instrument — honest, because the core refuses every rush while the desk is on, so what it covers
## is dead space.
##
## Asserted on the LAYOUT CONTRACT (size flags, declared minimum, icon, face text) rather than on
## pixel widths: this bar is mounted bare on the root with no parent sizing it, so measured widths
## would describe the harness rather than the design.
func _test_expands_while_running(bar_script: GDScript, tuning: TuningConfig) -> void:
	print("\n4. The button expands across the row while the mode runs")

	var declared_width: float = float(bar_script.get_script_constant_map()["AUTO_PURCHASE_WIDTH"])
	var bar: Control = await _mount_bar(bar_script, tuning, true, true, false)
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		_check("the owned button exists", false)
		bar.queue_free()
		return

	# Collapsed: fixed width, left chevron, and it names itself.
	_check("switched OFF it holds its declared width",
		is_equal_approx(button.custom_minimum_size.x, declared_width))
	_check("...does not compete for row space",
		button.size_flags_horizontal == Control.SIZE_FILL)
	# Collapsed the face is the ICON caption ("+ ∞ <property>"), so the Button's own string is empty
	# — a Button renders one string and one icon, and the icon slot is spent on the edge chevron, so
	# the caption is an overlay and the two faces take turns.
	_check("...and carries no text, leaving the icon caption to speak", button.text == "")
	# The chevron is an OVERLAY TextureRect, not the Button's `icon` — it was moved off the Button so
	# its box could be trusted to stay the size it was told (the icon grew past its cap and drew over
	# the rate readout). Found by shape for the same reason the rate label is.
	var collapsed_icon := _find_arrow_texture(bar)

	# Switched on with a known purchase count: it takes the row and reports what it is doing.
	bar.set_auto_purchase_state(true, true, false, 5)
	_check("switched ON it claims the leftover row width",
		button.size_flags_horizontal == Control.SIZE_EXPAND_FILL)
	_check("...and drops its fixed minimum so the meter can collapse",
		is_equal_approx(button.custom_minimum_size.x, 0.0))
	_check("...flips the chevron to point the other way",
		_find_arrow_texture(bar) != collapsed_icon)
	_check("...and reports the live purchase count", button.text == "BUYING ×5")

	# Running but broke: the count gives way to a redrawing ellipsis — the desk is not broken and
	# not finished, it is waiting for money.
	bar.set_auto_purchase_state(true, true, true, 5)
	_check("running but unable to afford anything shows an ellipsis, starting at one dot",
		button.text == ".")
	# It must actually ANIMATE. Driven from _process, so stepping the clock past a dot's dwell time
	# has to change the face; a static "..." would pass a "shows dots" check and still be wrong.
	bar._process(AUTO_PURCHASE_IDLE_DOT_SECONDS_FOR_TEST)
	_check("...and redraws itself as time passes", button.text == "..")
	bar._process(AUTO_PURCHASE_IDLE_DOT_SECONDS_FOR_TEST)
	_check("...through to three dots", button.text == "...")
	bar._process(AUTO_PURCHASE_IDLE_DOT_SECONDS_FOR_TEST)
	_check("...then cycles back to one", button.text == ".")

	# The expanded face also carries a rate readout on its LEFT, opposite the status text: what it
	# buys per round and how often. Found by type rather than by a getter, since it is an internal
	# piece of the button's face rather than part of the bar's API.
	bar.set_auto_purchase_state(true, true, false, 5, 2.5)
	var rate_text := _find_label_text_containing(bar, "AUTO-BUY 5/")
	_check("the expanded face reports its rate as AUTO-BUY 5/2.5s", rate_text == "AUTO-BUY 5/2.5s")

	# Before Main has pushed numbers it must not read "AUTO-BUY 0/0s".
	bar.set_auto_purchase_state(true, true, false, 0, 0.0)
	_check("with no numbers yet it falls back to the bare name",
		_find_label_text_containing(bar, "AUTO-BUY") == "AUTO-BUY")

	# GEOMETRY: the rate readout must start past the chevron, not under it. This failed twice —
	# first because the readout was inset like the caption and drew through the arrow, then because
	# the arrow was the Button's own icon and `expand_icon` grew it past the cap it was given, back
	# over the text. Measured rather than reasoned about, because both times the code READ correct.
	bar.custom_minimum_size = Vector2(1000, 99)
	bar.set_auto_purchase_state(true, true, false, 5, 2.5)
	await process_frame
	await process_frame
	var arrow := _find_arrow_rect(bar)
	var rate := _find_label_node(bar, "AUTO-BUY 5/")
	if arrow == null or rate == null:
		_check("the chevron and the rate readout are both present to measure", false)
	else:
		var arrow_right := arrow.global_position.x + arrow.size.x
		_check("the rate readout starts past the chevron's right edge (arrow ends %.0f, text starts %.0f)"
			% [arrow_right, rate.global_position.x], rate.global_position.x >= arrow_right)

	# And switching off puts the row back exactly as it was.
	bar.set_auto_purchase_state(true, false, false, 5)
	_check("switched off again it collapses back",
		button.size_flags_horizontal == Control.SIZE_FILL
			and is_equal_approx(button.custom_minimum_size.x, declared_width))
	_check("...restores the original chevron", _find_arrow_texture(bar) == collapsed_icon)
	_check("...and hands the face back to the icon caption", button.text == "")

	bar.queue_free()


## The cycle wave: a bright band crossing the button once per purchase cycle, so the cadence upgrade
## is something the player can watch rather than only read (Tim, 2026-08-07).
##
## Asserted on MOVEMENT and TIMING, not on appearance. A band that never moved, or moved while the
## mode was off, or took the wrong time to cross, would all look entirely reasonable in the source.
func _test_cycle_wave(bar_script: GDScript, tuning: TuningConfig) -> void:
	print("\n5. A bright wave crosses the button once per purchase cycle")

	var bar: Control = await _mount_bar(bar_script, tuning, true, true, false)
	bar.custom_minimum_size = Vector2(1000, 99)
	await process_frame

	# Switched OFF, there must be no wave at all — it is the sign the desk is running.
	bar._process(0.1)
	var host := _find_wave_host(bar)
	_check("the wave host exists", host != null)
	if host == null:
		bar.queue_free()
		return
	_check("switched OFF the wave is hidden", not host.visible)

	# Switched on at a two-second cadence: it appears and it travels.
	bar.set_auto_purchase_state(true, true, false, 5, 2.0)
	await process_frame
	await process_frame
	bar._process(0.0)
	_check("switched ON the wave shows", host.visible)

	var band := _find_wave_band(bar)
	_check("the band exists", band != null)
	if band == null:
		bar.queue_free()
		return

	var start_x := band.position.x
	bar._process(0.5)   # a quarter of the 2s cycle
	var quarter_x := band.position.x
	_check("the band moves left to right as the cycle runs", quarter_x > start_x)

	bar._process(0.5)   # halfway
	_check("...and keeps travelling", band.position.x > quarter_x)

	# A full period returns it to where it began: one pass per cycle, not a drift.
	# ONE FULL PERIOD RETURNS TO THE SAME PLACE. Compared against a fresh reading rather than the
	# `start_x` taken earlier, for two reasons: the button's width settles over a few frames after
	# it expands (so an older x can be stale by a band-width), and the awaited frames have already
	# advanced the sweep, so the phase at capture was never zero to begin with. Taken back-to-back
	# with no frame between, the only thing that can move the band is the period itself.
	var before_period := band.position.x
	bar._process(2.0)
	_check("one full cadence returns it to the same point in the sweep",
		is_equal_approx(band.position.x, before_period))

	# A purchase re-aligns the sweep, so the wave cannot drift against what the desk is doing.
	bar._process(0.7)
	_check("mid-sweep it has moved off the start",
		not is_equal_approx(band.position.x, -band.size.x))
	bar.flash_auto_purchase()
	bar._process(0.0)
	_check("a purchase resets the sweep to its start",
		is_equal_approx(band.position.x, -band.size.x))

	bar.queue_free()


## The wave's clipping host — the first invisible-when-off Control added to the button.
func _find_wave_host(bar: Control) -> Control:
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		return null
	for child in button.get_children():
		var ctrl := child as Control
		if ctrl != null and ctrl.clip_contents:
			return ctrl
	return null


## The sliding band inside that host.
func _find_wave_band(bar: Control) -> TextureRect:
	var host := _find_wave_host(bar)
	if host == null:
		return null
	for child in host.get_children():
		var rect := child as TextureRect
		if rect != null:
			return rect
	return null


## The OVR availability pulse: the plate breathes only while overdrive can actually be engaged
## (Tim, 2026-08-07). That window is narrow — cruising, at the clamp, not locked out — and a button
## that merely stopped being grey was easy to miss.
##
## Asserted on the plate's own colours, because that is the whole feature. A pulse that ran while
## the button was disabled, or that froze mid-breath when the window closed, would both look
## perfectly reasonable in the source.
func _test_overdrive_availability_pulse(bar_script: GDScript, tuning: TuningConfig) -> void:
	print("\n6. The OVR plate breathes only while overdrive is available")

	var bar: Control = await _mount_bar(bar_script, tuning, true, true, false)
	var ovr: Button = bar.get_overdrive_button()
	_check("the OVR button exists", ovr != null)
	if ovr == null:
		bar.queue_free()
		return

	# A fresh bar is not cruising, so the button starts disabled and the plate must sit at rest.
	var plate := ovr.get_theme_stylebox("normal") as StyleBoxFlat
	_check("its plate is a StyleBoxFlat we can read", plate != null)
	if plate == null:
		bar.queue_free()
		return

	_check("the button starts unavailable", ovr.disabled)
	var rest_bg := plate.bg_color
	var rest_border := plate.border_color
	bar._process(0.4)
	bar._process(0.4)
	_check("while unavailable the plate does not move",
		plate.bg_color.is_equal_approx(rest_bg)
			and plate.border_color.is_equal_approx(rest_border))

	# Force the availability the real game reaches by cruising at the clamp. Reaching it honestly
	# would mean simulating a rush hold; the pulse only cares that the button is enabled.
	ovr.disabled = false
	bar._pulse_overdrive_availability(0.0)
	_check("at the start of a breath it is still at rest",
		plate.bg_color.is_equal_approx(rest_bg))

	bar._pulse_overdrive_availability(0.55)   # half of the 1.1s period — the top of the breath
	var lit_bg := plate.bg_color
	var lit_border := plate.border_color
	_check("mid-breath the fill has lightened", lit_bg != rest_bg)
	_check("...and the outline has moved toward gold", lit_border != rest_border)

	bar._pulse_overdrive_availability(0.55)   # back to the bottom
	_check("a full period returns it to rest",
		plate.bg_color.is_equal_approx(rest_bg)
			and plate.border_color.is_equal_approx(rest_border))

	# Closing the window must PARK it, not freeze it wherever the breath happened to be.
	bar._pulse_overdrive_availability(0.55)
	_check("mid-breath again before disabling", plate.bg_color != rest_bg)
	ovr.disabled = true
	bar._pulse_overdrive_availability(0.0)
	_check("losing availability parks the plate back at rest, not mid-breath",
		plate.bg_color.is_equal_approx(rest_bg)
			and plate.border_color.is_equal_approx(rest_border))

	bar.queue_free()
