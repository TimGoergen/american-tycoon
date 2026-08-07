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

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


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

	var bar: Control = await _mount_bar(bar_script, tuning, true, true, true)
	var button: Button = bar.get_auto_purchase_button()
	if button == null:
		_check("the owned button exists (pulse cannot be tested without it)", false)
		bar.queue_free()
		return

	_check("the button starts at rest (plain white modulate)", button.modulate.is_equal_approx(
		Color.WHITE))

	bar.flash_auto_purchase()
	bar._process(0.0)  # apply the pulse without advancing it
	_check("a purchase brightens the button", button.modulate.r > 1.0)

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

	bar.queue_free()

	# A hidden button (desk unowned) must never pulse: it cannot have bought anything.
	var hidden: Control = await _mount_bar(bar_script, tuning, false, false, false)
	var hidden_button: Button = hidden.get_auto_purchase_button()
	hidden.flash_auto_purchase()
	hidden._process(0.0)
	_check("an unowned desk's hidden button never flares",
		hidden_button != null and hidden_button.modulate.is_equal_approx(Color.WHITE))
	hidden.queue_free()
