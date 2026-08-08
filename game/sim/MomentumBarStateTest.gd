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
			if rect != null and rect.is_visible_in_tree():
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
		if rect != null and rect.is_visible_in_tree():
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
