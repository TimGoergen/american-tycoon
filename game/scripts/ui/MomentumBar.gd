class_name MomentumBar
extends HBoxContainer

# The Rush Momentum / Heat control (Tim 2026-07-12; Rush Overheat rework Tim 2026-07-15;
# Cruise Control amendment Tim 2026-07-16): the OVERDRIVE button beside a display-only meter —
# the same square-button-plus-meter shape as the frenzy TURBO control (FrenzyBar). Momentum is
# earned by rushing the PROPERTIES, so the meter itself is still not a button; the OVR button
# is the ONE tappable piece, enabled only mid-hold (see _process).
#
# APPROACH-BAR REWORK (Plans/Overdrive_Vent_Windows.md, Tim 2026-07-19): the meter is now TWO
# different instruments sharing one frame, keyed on whether overdrive is engaged:
#
#   • CRUISE/BUILD mode (overdrive NOT engaged, not locked out): the whole bar spans
#     0 → the cruise clamp — FILLING THE BAR IS REACHING CRUISE (Tim: clean and safe-reading).
#     Purple fill, gold-family bubbles, no hazard wash, no stripes, no blink. The old teal
#     cruise-bar marker is gone in this mode: the bar's own right edge IS the cruise point now,
#     so a marker for it would be redundant. The "CRUISE +25%" readout stays.
#
#   • OVERDRIVE mode (engage_overdrive → until disengage/overheat): the bar repurposes into
#     the vent-minigame instrument. A fixed gold TARGET BAR sits ~1/3 from the left; each
#     scheduled vent event enters as a bright red EVENT BAR at the right edge and travels left
#     (the player SEES IT COMING — this replaces the old held-open gold "VENT!" chip); the
#     event reaching the target IS the window opening. While a window is open, the whole
#     region right of the target renders the gesture pips and the countdown at full bar
#     scale (see OverdriveInstrumentOverlay). The ProgressBar fill is PINNED FULL and its
#     color carries the depth urgency: purple → amber with overdrive depth, the red warning
#     blink ramping on top — so between events the bar still FEELS hotter the deeper you
#     ride, even though it no longer plots heat's position. (Pinned-full was chosen over
#     repurposing the fill as the countdown: the overlay's timer strip already tells the
#     countdown story, and a second moving edge underneath it would just be noise — the fill's
#     job in this mode is to be the urgency-colored stage the minigame plays on.)
#
#   • OVERHEAT lockout: the fill shows heat / hard_ceiling visibly draining (the drain IS the
#     cooldown display), label swaps OVERHEATED → COOLING…, then the READY flash. The
#     instrument overlay paints the DEAD-BAR GRAY behind it (Tim 2026-07-18 night): the track
#     the draining fill reveals is dark gray, and once the drain finishes the gray itself
#     drains from the right in proportion to the re-arm countdown — the gray's movement IS the
#     re-arm timer, and the READY flash lands on a fully normal-looking bar.
#
#   • AUTO-BUY lockout (Plans/Auto_Purchase_And_Bulk_Hire.md §A5): while the Acquisitions Desk
#     mode is on, the core refuses the rush verb entirely — that trade-off is what stops the mode
#     being strictly dominant. This bar is where the player is told WHY: the readout reads
#     NO RUSH, the OVR button wears its existing gray "can't trigger" plate, and the bubbles
#     and streaks (both of which claim an active rush) go quiet. Deliberately NOT a per-row
#     banner: a global rush shutdown that painted all 14 property rows read as the whole property
#     tab being dead (Overdrive_Vent_Windows.md:375-391).
#
#     THE TOGGLE ITSELF LIVES HERE TOO (Tim 2026-07-31), pinned to the bar's RIGHT end so the row
#     reads [OVR][meter][AUTO-BUY] — the switch that costs you rush sits on the rush instrument,
#     mirroring OVR across the meter. It used to be a button on its own row in Main; that row is
#     gone. The lit button is the ONLY on-screen indicator that the mode is running (Tim declined a
#     separate one), which is why its ON state is a full contrast flip rather than a subtle tint.
#
#     The readout says NO RUSH, not "AUTO-BUY ON" (Tim 2026-07-31): the lit button one inch to the
#     right already says what is ON, so repeating it would spend the meter's biggest text on a fact
#     the player can already see. What the button CANNOT say is what the mode costs — so the label
#     says that instead, and the two halves of the trade sit side by side.
#
#     There is NO frozen/idle heat state here and there must never be one. Turning the mode on
#     simply is "the player let go", so heat decays on the ordinary spin-down path and the
#     ordinary cruise/build fill plots that tail — the bar keeps showing exactly what is still
#     being earned, right down to zero. The lockout is a change of EXPLANATION, not of arithmetic.
#
# Vent resolutions still land as timed chips ABOVE the bar: green "VENTED — PEAK +X%!" plus
# the white flash on success; red "VENT MISSED!" with the unfinished pips strobing on a miss.
# The miss chip KEEPS its own pip row (VentPipRow) even though the bar now draws pips too:
# a miss immediately flips the bar into the OVERHEAT display, which wipes the in-bar pips —
# the chip is the only place the blown beat can stay visible long enough to learn from
# (the plan's rule: miss-feedback is what makes a skill mechanic learnable).
#
# THE RELEASE TAIL (Tim 2026-07-20): letting go no longer collapses the bonus — it spins down as
# the heat bleeds, while an overheat still zeroes it on the spot. That difference is invisible in
# the "+X%" readout alone — both cases just show a number — so a teal "SPINNING DOWN +X%" chip
# rides above the bar for the whole tail. An overheat shows no such chip, so the two outcomes are
# told apart by the chip's PRESENCE, which is the only way a player ever discovers that bailing is
# a real option. Both chips share one upward-growing stack above the bar so they can never overlap.
#
# The FILL needs no special case for it: the bonus is a pure function of heat now, and the bar
# already plots heat, so the ordinary fill IS the tail draining. Bar, chip and income run on the
# one clock by construction rather than by three displays being kept in sync (an earlier build
# banked a separate decaying number and had to special-case the fill to chase it — that is the
# inconsistency this design removed).
#
# Cruise Control (Plans/Rush_Cruise_Control.md) rules still apply: the OVR button is ALWAYS
# visible (Tim 2026-07-16: moving UI elements are annoying) but ENABLED only once the hold has
# REACHED the cruise clamp; any other time it wears the gray-outlined "can't trigger" plate.

## The player tapped OVERDRIVE: release the cruise clamp for this excursion. Main routes this
## to GameState.engage_rush_overdrive() — the same seam as FrenzyBar.pop_requested.
signal overdrive_requested

## The player tapped AUTO-BUY: flip the Acquisitions Desk mode. The bar is a DISPLAY — it changes
## no game state on this press. Main owns the flag, flips it, and pushes the result back through
## set_auto_purchase_state, so the button's look can never disagree with the mode that is actually
## running (the same request/paint split as overdrive_requested above).
signal auto_purchase_toggle_requested

var _rush_momentum: RushMomentumState
var _tuning: TuningConfig

## The bloodline, read only for its all-time best vent streak on the death chip (Tim 2026-07-20).
## Threaded in from Main via set_dynasty (like setup() threads the rush state) rather than reached
## through the scene tree, so this UI-only dependency stays an explicit hand-off, not a lookup.
var _dynasty: DynastyState

## True while the Acquisitions Desk (auto-purchase) mode is switched on AND owned, which is exactly
## when the core refuses the rush verb (Plans/Auto_Purchase_And_Bulk_Hire.md §A5). Pushed in by Main
## via set_auto_purchase_state rather than read off the core, because it is a UI-mode fact
## (a toggle the player flipped), not part of the heat instrument — the same hand-off shape as
## set_dynasty above.
##
## This flag changes NOTHING about the fill math. Auto-buy on simply IS "the player let go", so
## heat bleeds away on the ordinary spin-down path and the ordinary cruise/build fill already
## plots that tail — which keeps this bar's binding invariant intact: whatever the bar shows IS
## what the player earns. All this flag does is explain WHY rush is unavailable.
var _auto_purchase_locked := false

## The last state Main pushed, remembered verbatim so the button can be painted correctly no matter
## which order the push and this node's _ready() happen in.
##
## They genuinely race: _build_property_tab() builds this bar into a DETACHED VBoxContainer and
## Main pushes the state immediately (Main.gd, right after the bar is added), but a node only runs
## _ready() once it actually enters the tree — which is later, when the tab is mounted. So the first
## push regularly lands while _auto_purchase_button is still null. Keeping the values here lets
## _build_auto_purchase_button re-apply them instead of assuming locked-and-off.
var _auto_purchase_unlocked := false
var _auto_purchase_enabled := false

## True while the mode is RUNNING but cannot afford anything in the current epoch, so it is sitting
## there buying nothing (Tim, 2026-08-07: "the auto buy feature showed that it was on, but no
## longer was auto buying anything").
##
## This state is normal and often transient — the desk waits for cash like the player does — but it
## was completely silent, and a lit button with no purchases and no explanation is indistinguishable
## from a broken feature. It matters more since the mode became CURRENT-EPOCH-ONLY: on a deep run
## the frontier cohort can sit far above the player's cash for a long time, where the old
## last-viewed-tab targeting would have been quietly buying cheap rungs somewhere else.
var _auto_purchase_idle := false

## Purchases the desk makes per round, pushed in by Main. Shown on the expanded button ("BUYING ×5")
## so the mode reports what it is actually doing rather than merely that it is on.
var _auto_purchase_quantity := 0

## The collapsed face's icon caption ("+ ∞ <property>"), and the parts that need re-tinting when the
## plate flips. Shown only while COLLAPSED: expanded, the button reports its status as text instead,
## and a Button can only render one string — so the two faces take turns rather than share.
var _auto_purchase_caption: HBoxContainer
var _auto_purchase_caption_plus: Label
var _auto_purchase_caption_icons: Array = []

## The expanded face's rate readout ("AUTO-BUY 5/2.5s"). Shown only while expanded, left-aligned
## opposite the right-aligned status text.
var _auto_purchase_rate_label: Label

## Seconds between purchase rounds, pushed in by Main — the only place that knows it, since the
## cadence is the tuned base less the upgrade's shave, clamped to a tuned floor.
var _auto_purchase_cadence := 0.0

## Seconds left in the "the desk just bought something" pulse (0 = not pulsing). Counted down in
## _process, exactly the way PropertyRow fades its auto-purchase row marker — a countdown rather
## than a Tween so a purchase landing mid-pulse simply retriggers it, with no tween to kill and
## no way to strand the button at half brightness.
var _auto_purchase_pulse_seconds := 0.0

## The OVR button, pinned left of the meter (the FrenzyBar layout). Always visible; enabled
## only while cruising — see _process.
var _overdrive_button: Button

## The AUTO-BUY toggle, pinned right of the meter — OVR's mirror image across the bar (Tim
## 2026-07-31). ABSENT until the Acquisitions Desk track is bought, then a permanent fixture whose
## size never changes and whose plate is the only thing that flips. The hide-until-unlocked part is
## a deliberate, Tim-approved exception to the no-moving-UI rule — see _apply_auto_purchase_look
## for the full reasoning before changing it.
var _auto_purchase_button: Button

## The AUTO-BUY button's two "unlocked" plates, built once in _ready and swapped in whole when the
## mode flips. Kept as fields rather than rebuilt per call because set_auto_purchase_state is
## idempotent and Main is free to call it on every toggle/load without churning allocations.
var _auto_plate_off: StyleBoxFlat
var _auto_plate_on: StyleBoxFlat

## The display-only meter. All the overlays below live inside it.
var _meter: ProgressBar

## The big bonus readout ("+42%"), right-aligned; the caption on the left names the meter.
var _label: Label

## Carbonation in the fill; hidden while overheated (a locked meter is not accruing anything).
var _bubbles: GoldBubbles

## Fast neon-salmon streaks shown while overdrive is engaged — "you are riding the danger
## zone". With the fill pinned full in overdrive mode, the streaks are also the motion cue
## that the bar has switched instruments.
var _streaks: MomentumStreaks

## The custom-drawn overdrive instrument: target bar, traveling event bar with its trailing
## event backdrop, in-bar pips and the window's timer strip — plus the lockout's dead-bar gray
## (its one non-overdrive job). Draws NOTHING in cruise/build mode (the cruise bar is a clean,
## plain meter now). Formerly BandZoneOverlay — the hazard wash/stripes it painted moved into
## the fill's own depth coloring when the bar stopped plotting heat position.
var _instrument: OverdriveInstrumentOverlay

## The chip shown above the meter: the short-lived vent success/miss resolution plates.
## (The old HELD-OPEN gold "VENT!" telegraph chip is retired — the approaching red event bar
## is the telegraph now, with ~2 s of warning instead of a plate popping in.)
var _tier_chip: PanelContainer
var _tier_chip_label: Label
var _tier_chip_tween: Tween

## The column the chips live in, anchored above the meter (see _ready). Chips are stacked
## top-to-bottom so the one nearest the bar is the LAST child.
var _chip_stack: VBoxContainer

## The spin-down chip: shown for as long as a released hold is still paying a decaying bonus,
## so the player can tell a bail (it spins down) from an overheat (it is gone now).
var _spindown_chip: PanelContainer
var _spindown_chip_label: Label

## The miss-feedback pips inside the chip (see VentPipRow at the bottom of this file).
## Visible only on the "VENT MISSED!" chip — see the class comment for why the chip keeps
## its own pips alongside the in-bar ones.
var _vent_pips: VentPipRow

## The open window's telegraphed duration (s), for the in-bar countdown fraction. Taken from
## the vent_window_opened signal rather than the tuning knob, because the core SHRINKS windows
## per achieved tier (the escalation's speed axis) — the countdown must drain over the
## window's REAL length.
var _vent_window_duration := 1.0

## The in-flight event's total approach time (s), from the vent_incoming signal — the divisor
## that turns vent_approach_remaining() into the event bar's 0..1 travel fraction.
var _vent_approach_seconds := 1.0

## Lifts landed in the OPEN window, from vent_lift_registered (the core exposes the demanded
## count via vent_required_lifts() but not the landed count, so the UI keeps this one tally).
## Reset when a window opens; meaningless while none is open.
var _window_lifts_done := 0

# Frame-rate display clocks for the two moving vent elements (Tim 2026-07-19: "the vent event bar
# movement is jerky, both the incoming event as well as the event timer"). The core owns both
# times, but it only republishes them on the 10 Hz LOGIC tick, while this bar redraws every frame
# — so reading them raw made the event bar and the timer strip step ~10 times a second. An event
# crosses its whole runway in ~1.2 s, which is only about a dozen steps: very visibly chunky.
#
# These local copies run down on the FRAME delta and stay pinned to the core's authoritative value
# (see _predict_clock). Deliberately NOT BarSmoothing: an eased follow would LAG, and these two
# elements make promises the core keeps exactly — the bar reaching the target IS the window
# opening, and the strip emptying IS the miss. Prediction keeps them frame-smooth AND on time.
var _approach_display := 0.0
var _approach_core_seen := 0.0
var _window_display := 0.0
var _window_core_seen := 0.0

## The re-arm gray's receding edge has the same 10 Hz source, but it is a cooldown readout rather
## than a promise the player acts on, so it takes the cheaper cure: the standard eased follow the
## fill already uses. A few ms of lag on "the bar is coming back" costs nothing.
var _rearm_display := 0.0

## Full-rect white flash played when rush re-arms — re-availability must be unmissable
## (Tim 2026-07-15), so the whole meter blinks bright once alongside the label reverting.
var _ready_flash: ColorRect

## Eased fill: heat is driven by the 10 Hz logic tick, so we glide the shown fill toward it each
## frame instead of copying it raw — otherwise the bar visibly steps ~10 times a second (the same
## smoothing the frenzy meter uses; see BarSmoothing).
var _displayed_fill := 0.0

## The fill StyleBoxFlat, kept so _process can recolor the fill per mode/depth (and drive the
## warning blink) by mutating bg_color — far cheaper than rebuilding the stylebox every frame.
var _fill_style: StyleBoxFlat

## Blink phase accumulator (radians). Advanced by the CURRENT blink frequency each frame, so the
## frequency can ramp with heat depth without the sine jumping discontinuously.
var _blink_phase := 0.0

## Which label state is currently applied (see _LabelState), so the color/outline overrides are
## only rebuilt when the state flips, not every frame.
enum _LabelState { NORMAL, CRUISING, OVERHEATED, COOLING, AUTO_BUY }

## How much larger the CRUISE readout draws than the label's resting size (Tim, 2026-08-07 —
## "about 40% larger"). Applied in _apply_label_state; every other state keeps the base size.
const CRUISE_LABEL_SCALE := 1.4
var _label_state_applied: int = -1

## Where the fixed vent target bar sits, as a fraction of the bar's width (~1/3 from the left,
## Tim 2026-07-19). The region right of it is the event runway: events enter at the right edge
## and travel left across two-thirds of the bar, so the approach is long enough to read.
const TARGET_FRAC := 0.33

## Blink ramp (overdrive mode): the red warning blink keys CONTINUOUSLY on overdrive depth —
## heat's position within [cruise point .. hard ceiling]. Frequency runs BLINK_HZ_MIN →
## BLINK_HZ_MAX across that span; strength runs 0 → BLINK_STRENGTH_MAX. There is deliberately
## no strength floor: a floor would snap the blink on at some depth, re-creating the very band
## edge the depth-hazard rework removed (see _update_fill_color).
const BLINK_HZ_MIN := 2.5
const BLINK_HZ_MAX := 7.0
const BLINK_STRENGTH_MAX := 0.85

## How long the tier chip holds fully visible before fading (seconds).
const TIER_CHIP_HOLD_SEC := 1.0
## Pixels between the meter's top edge and the chip's bottom edge (Tim 2026-07-18: the chip
## must not cover the bar).
const TIER_CHIP_GAP_ABOVE_BAR := 8.0
## Vertical gap between stacked chips when more than one is up.
const CHIP_STACK_SEPARATION := 6.0
const TIER_CHIP_FADE_IN_SEC := 0.12
const TIER_CHIP_FADE_OUT_SEC := 0.4

## The AUTO-BUY button's "it just bought something" pulse (Tim, 2026-08-07). The button's plate
## says the mode is ON, but a mode that is on and a mode that is actually spending look identical —
## this is the difference.
##
## 0.35s, comfortably shorter than the desk's fastest cadence (1.0s at a maxed Acquisitions Desk),
## so even at full speed the button returns to rest between purchases and reads as a slow blink
## rather than a flicker. An unaffordable tick buys nothing and pulses nothing, which makes the
## button honest about "running" versus "running dry".
const AUTO_PURCHASE_PULSE_SECONDS := 0.35

## Peak brightness multiplier at the top of the pulse. `modulate` MULTIPLIES, so a modest number
## barely moves the lit plate's dark navy field — 1.8 was tried first and Tim's verdict was "too
## faint to draw attention" (2026-08-07). At 3.0 the mustard frame and label saturate to white and
## the navy field itself lifts to a bright blue, so the whole control flashes rather than just its
## outline.
const AUTO_PURCHASE_PULSE_PEAK := 3.0

## How much the button swells at the top of the pulse (Tim, 2026-08-07). Applied as `scale`, NOT by
## touching size: this button sits in an HBoxContainer beside the meter, so a real size change would
## re-run the layout and shove the meter sideways on every purchase. `scale` is a draw transform —
## the container still sees the same 210px box, and nothing moves.
##
## 6% on a 210px button is about 6px of growth per side, which reads at a glance without the button
## colliding with the meter across the row's 8px separation.
##
## Hit-testing is unaffected in the SAFE direction: SecondaryTapButton checks get_global_rect(),
## which ignores scale, so the tap target stays the button's true 210px box. Mid-pulse the art is a
## few px larger than the target rather than the other way round — no phantom taps land outside the
## button, you simply cannot hit the transient halo.
const AUTO_PURCHASE_PULSE_SCALE := 1.06

## The OVR button's steam-burst glyph, replacing the word "OVR" (Tim, 2026-08-07). Drawn at 62 in a
## 99px square button: comfortably inside the plate's 12px content margins, and below the art's
## 128px native size so it downscales rather than blurring up.
const OVERDRIVE_ICON := preload("res://art/icons/steam_burst.svg")
const OVERDRIVE_ICON_SIZE := 62

## The AUTO-BUY button's edge chevrons. LEFT while collapsed ("this expands leftwards"), RIGHT once
## expanded ("this collapses back"). Same weight and size, so it reads as one control changing
## direction rather than two different icons.
const AUTO_PURCHASE_ARROW_COLLAPSED := preload("res://art/icons/arrow_left.svg")
const AUTO_PURCHASE_ARROW_EXPANDED := preload("res://art/icons/arrow_right.svg")
## 40 → 56, a 40% increase (Tim, 2026-08-07). Still well inside the 99px row height, and still a
## downscale from the 128px art so it stays crisp.
const AUTO_PURCHASE_ARROW_SIZE := 56

## The AUTO-BUY button's resting width — slightly wider than the old 210 to carry the chevron
## alongside its label (Tim, 2026-08-07).
const AUTO_PURCHASE_WIDTH := 244

## The collapsed face: "+ ∞ <property>" (Tim, 2026-08-07) — what the mode does, in the same grammar
## the BUY/HIRE toggles use, instead of the word AUTO-BUY.
const AUTO_PURCHASE_INFINITY_ICON := preload("res://art/icons/infinity.svg")
const AUTO_PURCHASE_PROPERTY_ICON := preload("res://art/icons/tab_property_inactive.svg")

## The caption's reference VISIBLE height, and the per-glyph multipliers Tim set on 2026-08-07 once
## he saw them together: the infinity at 60% of it, the property icon 20% above it. They are no
## longer the same size on purpose — matched optical height made the infinity read as the loud part
## of the pair, when the building is the noun and the infinity is the modifier.
const AUTO_PURCHASE_CAPTION_ICON_HEIGHT := 40.0
const AUTO_PURCHASE_INFINITY_SCALE := 0.6
const AUTO_PURCHASE_PROPERTY_SCALE := 1.2

## The boxes that achieve those heights, derived from MEASURED art rather than canvas size:
## infinity's glyph fills 40 of its 96px canvas (0.417) and the property icon 279 of its 324
## (0.861). Dividing each wanted height by its own fraction is what makes the pair land where it is
## meant to — equal boxes would draw the infinity at less than half the building's height.
const AUTO_PURCHASE_INFINITY_BOX := int(
	AUTO_PURCHASE_CAPTION_ICON_HEIGHT * AUTO_PURCHASE_INFINITY_SCALE * 96.0 / 40.0)    # 57
const AUTO_PURCHASE_PROPERTY_BOX := int(
	AUTO_PURCHASE_CAPTION_ICON_HEIGHT * AUTO_PURCHASE_PROPERTY_SCALE * 324.0 / 279.0)  # 55

## Gap between the caption's three parts, and how far it is held off the plate's frame.
const AUTO_PURCHASE_CAPTION_GAP := 4
const AUTO_PURCHASE_CAPTION_INSET := 14

## The READY flash's peak alpha and fade time.
const READY_FLASH_ALPHA := 0.75
const READY_FLASH_FADE_SEC := 0.5

# Haptic pulse lengths moved from constants to live Balance Tuning knobs (tuning
# rush_momentum_haptic_*_ms) so the device pass can dial them on the phone — see _vibrate.


## Call before adding to the tree.
func setup(rush_momentum: RushMomentumState, tuning: TuningConfig) -> void:
	_rush_momentum = rush_momentum
	_tuning = tuning


## Hand the bar the bloodline so the death chip can quote the all-time best streak. Kept apart
## from setup() because the dynasty is a UI-display concern, not part of the heat instrument.
func set_dynasty(dynasty: DynastyState) -> void:
	_dynasty = dynasty


## Paint the AUTO-BUY button and the bar's lockout presentation in one call.
## `unlocked` — the player owns the Acquisitions Desk legacy track (level >= 1).
## `enabled`  — the mode is currently switched ON.
##
## One call rather than two setters because the two facts are never independent on screen: the
## button's three looks and the bar's lockout narration are all read off this same pair, and a bar
## that had been told only half of it would paint a state that does not exist (an "on" mode the
## player does not own).
##
## The bar does not go looking for either fact itself: the core has no "auto-buy" concept — it just
## stops being fed `rushing = true` — so the reason has to be handed down from the screen that owns
## the toggle. Idempotent; calling it every frame with the same values is harmless.
## `idle` and `quantity` are optional so existing callers and the sims keep working; only Main knows
## the economy and the upgrade levels well enough to answer them.
func set_auto_purchase_state(unlocked: bool, enabled: bool, idle: bool = false,
		quantity: int = 0, cadence: float = 0.0) -> void:
	_auto_purchase_idle = idle
	_auto_purchase_quantity = quantity
	_auto_purchase_cadence = cadence
	_set_auto_purchase_state_inner(unlocked, enabled)


func _set_auto_purchase_state_inner(unlocked: bool, enabled: bool) -> void:
	# The rush lockout is exactly "owned AND switched on". An unowned track can have a stale
	# `enabled` left over from a prestige that reset the legacy levels, and that must not lock rush.
	_auto_purchase_locked = unlocked and enabled
	# Remembered BEFORE applying, because the apply is a no-op until _ready has built the button —
	# this is what lets _ready pick the state back up. See the fields' comment.
	_auto_purchase_unlocked = unlocked
	_auto_purchase_enabled = enabled
	_apply_auto_purchase_look(unlocked, enabled)


## The Acquisitions Desk just bought something — flare the button (Tim, 2026-08-07).
##
## Called by Main only on a tick that actually acquired units, so a tick that could not afford
## anything stays dark. That distinction is the whole value of the pulse: "on" and "on and
## spending" otherwise look the same.
##
## Retriggering mid-pulse simply restarts the countdown; there is no tween to collide with.
func flash_auto_purchase() -> void:
	# Nothing to paint before _ready, and a hidden button (desk unowned) must never flash — it
	# cannot have bought anything, and modulating a hidden control would be pure waste.
	if _auto_purchase_button == null or not _auto_purchase_button.visible:
		return
	_auto_purchase_pulse_seconds = AUTO_PURCHASE_PULSE_SECONDS


## Ease the AUTO-BUY pulse back to rest. Called once per frame from _process; free on the
## overwhelming majority of frames, when nothing is pulsing.
##
## Mirrors PropertyRow._fade_auto_purchase_marker: linear decay off a countdown, and an explicit
## reset to plain white on the final frame so the button can never be left tinted.
func _fade_auto_purchase_pulse(delta: float) -> void:
	if _auto_purchase_pulse_seconds <= 0.0:
		return
	if _auto_purchase_button == null:
		_auto_purchase_pulse_seconds = 0.0
		return
	_auto_purchase_pulse_seconds = maxf(0.0, _auto_purchase_pulse_seconds - delta)
	if _auto_purchase_pulse_seconds <= 0.0:
		_auto_purchase_button.modulate = Color.WHITE
		_auto_purchase_button.scale = Vector2.ONE
		return
	var strength := _auto_purchase_pulse_seconds / AUTO_PURCHASE_PULSE_SECONDS
	var brightness := 1.0 + (AUTO_PURCHASE_PULSE_PEAK - 1.0) * strength
	_auto_purchase_button.modulate = Color(brightness, brightness, brightness)
	# Grow about the button's CENTRE. The pivot is refreshed every pulsing frame rather than set
	# once, because the button's height is SIZE_FILL — it follows the meter row, so a layout change
	# would otherwise leave the pivot stale and make the swell drift off-centre.
	_auto_purchase_button.pivot_offset = _auto_purchase_button.size * 0.5
	var swell := 1.0 + (AUTO_PURCHASE_PULSE_SCALE - 1.0) * strength
	_auto_purchase_button.scale = Vector2(swell, swell)


## The OVERDRIVE (OVR) button, so a tutorial card can anchor to it. It stays disabled until the
## player reaches the cruise clamp, so `not get_overdrive_button().disabled` is exactly the
## "rush has met cruise control" moment the overdrive tip fires on.
##
## CAUTION for tutorial callers: the button is ALSO force-disabled for the whole time auto-purchase
## mode is on, so a player who leaves that mode on would never satisfy `not disabled` and would
## never be shown the overdrive tip. Anything gating a one-time tip on this button must treat the
## auto-buy lockout as "not yet", not as "never" (Plans/Auto_Purchase_And_Bulk_Hire.md §A5).
func get_overdrive_button() -> Button:
	return _overdrive_button


## The AUTO-BUY toggle, so a tutorial card can anchor to it (the same role get_overdrive_button
## plays for OVR).
##
## CAUTION for tutorial callers: this button is HIDDEN, not merely grayed, until the Acquisitions
## Desk is owned (see _apply_auto_purchase_look). Any tip anchored here must gate on
## `get_auto_purchase_button().visible`, or the card will point at a node that occupies no space.
## No tip currently anchors to it.
func get_auto_purchase_button() -> Button:
	return _auto_purchase_button


func _ready() -> void:
	add_theme_constant_override("separation", 8)  # match the TURBO row's button/meter gap

	# The OVR button, left of the meter like FrenzyBar's TURBO button. ALWAYS visible — it began
	# life appearing only mid-hold, but a control that pops in and out is annoying (Tim
	# 2026-07-16); a permanent fixture also earns the short "OVR" label, since it is learned
	# once rather than having to explain itself the instant it appears. The red action plate
	# (§8: red = spend/act) marks it as the opt-in gamble, apart from gold TURBO.
	_overdrive_button = Button.new()
	# A STEAM BURST, not the letters "OVR" (Tim, 2026-08-07). The row reads faster as pictures:
	# this button and TURBO beside it are now both square icon buttons of identical size, so the
	# two "act" controls are a matched pair instead of one word and one glyph.
	#
	# `expand_icon` + `icon_max_width` is the same treatment the tab bar uses — a Button draws its
	# icon at native size otherwise, with no way to scale it up.
	_overdrive_button.icon = OVERDRIVE_ICON
	_overdrive_button.expand_icon = true
	_overdrive_button.add_theme_constant_override("icon_max_width", OVERDRIVE_ICON_SIZE)
	_overdrive_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Mipmapped: the art is 128px native and draws around 62, and an unfiltered 2x downscale
	# aliases (the rule the tab icons and the gamepad already follow).
	_overdrive_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	UiPalette.style_button(_overdrive_button, true)
	# When overdrive can't engage (no live rush hold, or locked out) the button grays its
	# OUTLINE too, exactly like the frenzy pop button — "can't trigger" must read at a glance
	# (Tim 2026-07-15). The standard disabled plate keeps the navy frame; swap ours for gray.
	var disabled_plate := StyleBoxFlat.new()
	disabled_plate.bg_color = UiPalette.CREAM
	disabled_plate.border_color = UiPalette.MID_GRAY
	disabled_plate.set_border_width_all(3)
	disabled_plate.set_corner_radius_all(4)
	disabled_plate.set_content_margin_all(12)
	_overdrive_button.add_theme_stylebox_override("disabled", disabled_plate)
	# SQUARE, and identical to the TURBO pop button beside it (both STANDARD_BUTTON_HEIGHT wide) —
	# Tim's "as narrow as possible while still fully containing all labels and icons". For an
	# icon-only button that floor IS its own height, so square is the answer and the two act
	# buttons match by construction rather than by a number kept in step by hand.
	_overdrive_button.custom_minimum_size = Vector2(UiPalette.STANDARD_BUTTON_HEIGHT, 0)
	_overdrive_button.size_flags_vertical = Control.SIZE_FILL
	_overdrive_button.pressed.connect(func() -> void: overdrive_requested.emit())
	# ESSENTIAL, not just convenient: the button is only ENABLED while a rush hold is live, so
	# the tap that presses it is ALWAYS a second finger — without this node it could never fire
	# on a phone (Godot only emulates the mouse from the gesture's first finger).
	_overdrive_button.add_child(SecondaryTapButton.new())
	_overdrive_button.disabled = true  # _process enables it only while cruising
	add_child(_overdrive_button)

	# The meter itself — display only, so it ignores the mouse entirely (FrenzyBar's meter
	# does the same); the button above is this control's one tappable piece.
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	# A touch shorter than a full action button — it is a secondary read-out, not a tap target,
	# but still tall enough to read at a glance. Raised 0.7 → 0.85 (Tim 2026-07-20: the in-bar
	# vent pips read as "readable but small"). The pips are sized off this inner height, and
	# at 0.7 there was no vertical room left to grow them once the timer strip along the
	# bottom edge is reserved. 0.85 also brings this meter CLOSER to the frenzy meter below
	# it, which is a full button tall.
	_meter.custom_minimum_size = Vector2(0, int(UiPalette.STANDARD_BUTTON_HEIGHT * 0.85))
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# DARK_PURPLE fill: a distinct hue from the frenzy meter's warm gold/red sitting just below it,
	# so the two reward meters never read as the same thing. Darkened from the lighter PURPLE
	# (Tim 2026-07-15) so the bright bubbles and white text pop against it.
	UiPalette.style_framed_progress(_meter, UiPalette.DARK_PURPLE, UiPalette.PROGRESS_TRACK_GRAY)
	add_child(_meter)
	# Keep a handle on the fill stylebox so the mode/depth coloring can mutate its bg_color
	# per frame instead of rebuilding styleboxes (see _process).
	_fill_style = _meter.get_theme_stylebox("fill") as StyleBoxFlat

	_build_auto_purchase_button()

	# The overdrive instrument overlay, custom-drawn (the same approach as MomentumStreaks).
	# Added FIRST among the meter's overlays so the bubbles, streaks, and text labels all draw
	# over its plates and bars.
	_instrument = OverdriveInstrumentOverlay.new()
	_meter.add_child(_instrument)

	# Carbonation in the fill, the same "value accruing automatically" cue the frenzy meter and the
	# property/economy bars carry: heat builds on its own while you rush. BRIGHT_PURPLE bubbles
	# glowing against the dark fill (flipped from dark-on-light, Tim 2026-07-15 — the same pairing
	# the maxed-momentum property bars use). Added BEFORE the label overlay so the readout draws
	# over the bubbles.
	_bubbles = GoldBubbles.new()
	_bubbles.edge_inset = 3.0  # match the framed fill's 3px inset (style_framed_progress)
	_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
	_bubbles.tier = GoldBubbles.Tier.FLOWING  # steady automatic accrual, like TURBO charging
	_meter.add_child(_bubbles)

	# Neon-salmon streaks over the fill, shown while overdrive is engaged (see _process).
	# Added over the gold bubbles but under the label overlay, so the "+XX%" still draws on top.
	_streaks = MomentumStreaks.new()
	_streaks.color = UiPalette.NEON_SALMON
	_streaks.visible = false
	_meter.add_child(_streaks)

	# READY flash: a full-rect white wash, normally invisible; _on_rush_ready tweens it bright and
	# back so the re-armed meter is unmissable even in peripheral vision (Tim's vision, §1b).
	_ready_flash = ColorRect.new()
	_ready_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ready_flash.color = Color(1, 1, 1, 0)
	_ready_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_ready_flash)

	# Overlay: a left caption and the big "+XX%" readout on the right. It ignores the mouse so it
	# never eats a tap meant for the rows or buttons around it.
	var text_overlay := MarginContainer.new()
	text_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_overlay.add_theme_constant_override("margin_left", 16)
	text_overlay.add_theme_constant_override("margin_right", 16)
	text_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(text_overlay)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_overlay.add_child(row)

	# Left: the meter's name. White (Tim 2026-07-15) so it reads over the dark purple fill (the
	# caption sits at the left edge, filled first as heat climbs).
	var caption := Label.new()
	# "RUSH", not "RUSH MOMENTUM", and a size up (Tim, 2026-08-07). The bar is what it is called;
	# the second word was doing no work and was crowding the readout beside it. Growing the NAME
	# while shrinking the NUMBER below is deliberate — it reverses the old hierarchy, which shouted
	# a percentage at the player and whispered what the percentage was for.
	caption.text = "RUSH"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", UiPalette.FONT_CARD_BODY)
	caption.add_theme_font_override("font", UiPalette.make_bold_font())
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)

	# Right: the live bonus. Takes the remaining width and right-aligns so it hugs the frame's right
	# edge — which is exactly where the AUTO-BUY button begins — while the caption stays pinned left.
	#
	# FONT_LABEL (28), down from FONT_HEADLINE (52), at Tim's request: "almost as small as the
	# status text". NOTE this slot is shared — the same label carries OVERHEATED, COOLING and the
	# cruise readout. That is the intended trade: the row now reads as a named bar with a small
	# figure on it, rather than a giant number with a caption attached.
	#
	# The size set here is only the RESTING one. _apply_label_state owns it per state and re-applies
	# it on every change — CRUISE draws 40% larger (see CRUISE_LABEL_SCALE), everything else at this
	# size. Change it there, not here, or the two will disagree.
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", UiPalette.FONT_LABEL)
	_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_apply_label_state(_LabelState.NORMAL)

	# The CHIP STACK: the column of plates that live ABOVE the meter, never over it (Tim
	# 2026-07-18: a chip covering the bar hid the fill exactly when the player most needs to read
	# it mid-vent). Anchored to the meter's top-center and growing UPWARD, so however tall its
	# chips get, the bottom chip's lower edge stays a fixed gap above the bar. Chips are listed
	# top-to-bottom, so the LAST child is the one nearest the bar. z_index lifts the whole stack
	# above the siblings drawn after this bar.
	#
	# A container (rather than two separately anchored chips) exists because there are now two
	# kinds of chip — the timed vent resolutions and the persistent spin-down readout — and
	# they must never share pixels when both are up.
	_chip_stack = VBoxContainer.new()
	_chip_stack.anchor_left = 0.5
	_chip_stack.anchor_right = 0.5
	_chip_stack.anchor_top = 0.0
	_chip_stack.anchor_bottom = 0.0
	_chip_stack.offset_bottom = -TIER_CHIP_GAP_ABOVE_BAR
	_chip_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chip_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chip_stack.add_theme_constant_override("separation", int(CHIP_STACK_SEPARATION))
	_chip_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_stack.z_index = 10
	_meter.add_child(_chip_stack)

	# The tier chip: a large bold plate for the vent resolutions — chips ease in, hold ~1 s,
	# then fade (see _show_tier_chip). Sits at the TOP of the stack, so a spin-down chip below it
	# never pushes it over the bar.
	_tier_chip = PanelContainer.new()
	_tier_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tier_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.visible = false
	_chip_stack.add_child(_tier_chip)

	# The chip's content column: the big text line, with the miss-feedback pips beneath it.
	# The pip row only shows on the miss chip; every other chip keeps it hidden, so those
	# chips collapse to exactly the text-only shape.
	var chip_column := VBoxContainer.new()
	chip_column.add_theme_constant_override("separation", 10)
	chip_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_chip.add_child(chip_column)

	_tier_chip_label = Label.new()
	_tier_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# FONT_HEADLINE bold — the chip is the payoff/failure moment and must land at a glance
	# (Tim's vision, §1b: large text, unmissable signals).
	_tier_chip_label.add_theme_font_size_override("font_size", UiPalette.FONT_HEADLINE)
	_tier_chip_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_tier_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_column.add_child(_tier_chip_label)

	_vent_pips = VentPipRow.new()
	_vent_pips.visible = false
	chip_column.add_child(_vent_pips)

	# The SPINNING DOWN chip: the release-tail readout. Unlike the tier chip this one is not a
	# timed celebration — it is shown for as long as a released hold is still paying a decaying
	# bonus, and it is the ONLY place the player can learn that bailing pays at all (Tim
	# 2026-07-20: "yes, and say so in the UI"). Without it, bailing and overheating look identical
	# from the outside and the whole cash-out half of the loop stays invisible.
	#
	# Sits at the BOTTOM of the stack, nearest the bar, because it annotates the bar's own "+X%"
	# readout: it is saying "that number you are reading is easing off, not blowing up".
	_spindown_chip = PanelContainer.new()
	_spindown_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spindown_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spindown_chip.visible = false
	_chip_stack.add_child(_spindown_chip)

	# ATOMIC_TEAL on NAVY: teal is already this bar's "safe / settled" color (the CRUISE readout
	# uses it), which is exactly what a spinning-down bonus is — deliberately nothing like the gold
	# act-now family or the red failure family. An overheat shows no chip at all and the number
	# simply goes, so the two outcomes are told apart by presence, not by shades of a plate.
	_spindown_chip_label = Label.new()
	_spindown_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spindown_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spindown_chip_label.add_theme_font_size_override("font_size", UiPalette.FONT_BODY)
	_spindown_chip_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_spindown_chip_label.add_theme_color_override("font_color", UiPalette.INK_NAVY)
	_spindown_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spindown_chip.add_child(_spindown_chip_label)

	var spindown_plate := StyleBoxFlat.new()
	spindown_plate.bg_color = UiPalette.ATOMIC_TEAL
	spindown_plate.border_color = UiPalette.NAVY
	spindown_plate.set_border_width_all(3)
	spindown_plate.set_corner_radius_all(8)
	spindown_plate.set_content_margin_all(10)
	_spindown_chip.add_theme_stylebox_override("panel", spindown_plate)

	# Overheat/re-arm swap the whole meter's presentation. (Deliberately NO band_entered
	# connection: the depth-hazard rework retired the Critical band and its crossing chip —
	# the vent events are the escalation drama now; Tim 2026-07-18.)
	_rush_momentum.overheated.connect(_on_overheated)
	_rush_momentum.rush_ready.connect(_on_rush_ready)
	# Vent Windows: the approach telegraph, the in-window progress, and the two resolutions
	# (Plans/Overdrive_Vent_Windows.md, approach-bar rework).
	_rush_momentum.vent_incoming.connect(_on_vent_incoming)
	_rush_momentum.vent_window_opened.connect(_on_vent_window_opened)
	_rush_momentum.vent_lift_registered.connect(_on_vent_lift_registered)
	_rush_momentum.vent_succeeded.connect(_on_vent_succeeded)
	_rush_momentum.vent_missed.connect(_on_vent_missed)


## Build the AUTO-BUY toggle at the bar's RIGHT end, mirroring the OVR button on the left
## (Tim 2026-07-31). Called from _ready AFTER the meter has been added, because HBoxContainer lays
## its children out in child order and the row must read [OVR][meter][AUTO-BUY].
func _build_auto_purchase_button() -> void:
	_auto_purchase_button = Button.new()
	_auto_purchase_button.text = "AUTO-BUY"
	# Chevron pinned to the LEFT edge, label right-aligned against the opposite edge (Tim,
	# 2026-08-07). The gap between them is the point: it is what makes the button look like a panel
	# that can open, rather than a label with a picture next to it.
	_auto_purchase_button.icon = AUTO_PURCHASE_ARROW_COLLAPSED
	_auto_purchase_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_auto_purchase_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_auto_purchase_button.expand_icon = true
	_auto_purchase_button.add_theme_constant_override("icon_max_width", AUTO_PURCHASE_ARROW_SIZE)
	_auto_purchase_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# FONT_BUTTON, not OVR's FONT_HEADLINE: three letters can afford to be huge, eight cannot
	# without either shrinking the meter or wrapping. This is still the standard action-button size,
	# well above the readability floor (§1b).
	_auto_purchase_button.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	_auto_purchase_button.add_theme_font_override("font", UiPalette.make_bold_font())
	# The STANDARD (gold) plate, not OVR's red action plate: red is reserved for spend/act (§8) and
	# this button spends nothing — it flips a mode. Keeping the two neighbors different colors also
	# stops the row reading as a pair of matching triggers.
	UiPalette.style_button(_auto_purchase_button, false)

	# The unlocked pair of plates, swapped whole by _apply_auto_purchase_look.
	_auto_plate_off = _make_auto_plate(UiPalette.MUSTARD_GOLD, UiPalette.NAVY, 3)
	# LIT: the plate INVERTS — navy field, thick mustard frame, mustard text. A contrast flip (rather
	# than a brighter shade of the off-state) is what makes "the mode is running" legible from across
	# the room, which matters more here than anywhere else on the screen: since the separate
	# indicator was declined, this button is the only thing telling the player the mode is on.
	_auto_plate_on = _make_auto_plate(UiPalette.NAVY, UiPalette.MUSTARD_GOLD, 5)

	# The gray "can't tap" plate, exactly the OVR treatment. Kept even though the locked button is now
	# HIDDEN rather than grayed (see _apply_auto_purchase_look): `disabled` still tracks `visible`, so
	# this plate is what a hidden button would wear, and it costs one stylebox to keep the two states
	# from ever disagreeing if the button is shown while still locked.
	_auto_purchase_button.add_theme_stylebox_override(
			"disabled", _make_auto_plate(UiPalette.CREAM, UiPalette.MID_GRAY, 3))

	# Fixed width so the button NEVER resizes between its ON and OFF states and never expands into
	# the meter: 210px comfortably fits "AUTO-BUY" at FONT_BUTTON bold plus the plate's 12px content
	# margins, with slack for the font's hinting. Height fills the row like OVR does.
	_auto_purchase_button.custom_minimum_size = Vector2(AUTO_PURCHASE_WIDTH, 0)
	_auto_purchase_button.size_flags_vertical = Control.SIZE_FILL
	_auto_purchase_button.pressed.connect(
			func() -> void: auto_purchase_toggle_requested.emit())
	# Same reason OVR needs one: the player may well flip this mid-rush-hold, and on a phone that
	# tap is a SECOND finger — which Godot never turns into a mouse click on its own.
	_auto_purchase_button.add_child(SecondaryTapButton.new())
	_build_auto_purchase_caption()
	add_child(_auto_purchase_button)

	# Paint whatever Main last pushed — NOT a hardcoded locked-and-off.
	#
	# This line used to read `_apply_auto_purchase_look(false, false)`, which hid the button after
	# every prestige (Tim, 2026-08-06: "auto-buy is purchased in the estate tab, but the button is
	# not visible on the game tab after prestige"). Main pushes the state while this bar is still
	# detached, so that push found no button and did nothing — and then this line overwrote the
	# truth with "locked". Because Main memoises what it has pushed, and `unlocked` never changed
	# again, it never re-pushed and the button stayed hidden for the rest of the run.
	#
	# It only showed up after a prestige because on a fresh dynasty the desk is unowned at build
	# time, so BUYING it later flipped unlocked false -> true and repainted. Post-prestige the desk
	# is already owned when the bar is built, so that flip never comes.
	#
	# The fields default to false, so a genuinely fresh bar still starts locked-and-off.
	_apply_auto_purchase_look(_auto_purchase_unlocked, _auto_purchase_enabled)


## One plate for the AUTO-BUY button, matching UiPalette's button geometry (3px/4px/12px) so it
## sits flush with every other button in the game. Border width is a parameter only so the LIT
## state can wear a heavier frame.
func _make_auto_plate(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = bg
	plate.border_color = border
	plate.set_border_width_all(border_width)
	plate.set_corner_radius_all(4)
	plate.set_content_margin_all(12)
	return plate


## Paint the AUTO-BUY button.
##
## IT NOW CHANGES SIZE (Tim, 2026-08-07). Switched ON, the button takes the whole row apart from the
## OVR square, covering the meter; switched OFF it collapses back to its own width. That is a
## deliberate, requested piece of moving UI, and it is honest rather than decorative: while the mode
## runs the core refuses every rush, so the rush instrument underneath is dead space. The button
## covering it says so more plainly than any label could.
##
## Mechanically the growth is a SIZE-FLAG swap, not an animation or a computed width: expanded, the
## button takes SIZE_EXPAND_FILL and the meter drops to SIZE_FILL at zero minimum, so the HBox hands
## the button everything the OVR square and the two 8px separations do not need. That lands at ~88%
## of the row, and it cannot overflow the way a hardcoded "90% of width" could.
##
## DELIBERATE EXCEPTION TO THE NO-MOVING-UI RULE (Tim, decided 2026-08-01, having been shown that
## it breaks his own standing "never hide/show controls — gray them in place" rule; see
## scripts/ui/CLAUDE.md). Until the Acquisitions Desk is bought the button is ABSENT, not grayed.
##
## Why Tim overruled the rule here: a grayed control has to explain itself somewhere, and the only
## place left on this button was `tooltip_text` — the face is full at a legible size and shrinking it
## would break the low-vision floor. TOOLTIPS NEVER APPEAR ON TOUCH. So on the device the grayed
## button said "not yet" and could never say why, which is the exact failure the no-moving-UI rule
## exists to prevent, arriving by a different road. An absent control is more honest than a dead one
## that cannot state its own reason.
##
## DO NOT "fix" this back to a grayed-in-place button. Doing so would restore an unexplainable
## control on a phone. If it is ever restored, the reason must move somewhere touch can read it.
func _apply_auto_purchase_look(unlocked: bool, enabled: bool) -> void:
	if _auto_purchase_button == null:
		return  # set_auto_purchase_state can legitimately arrive before _ready

	# The bar is an HBoxContainer and the meter is SIZE_EXPAND_FILL, so a hidden button simply
	# hands its 210px to the meter: the row reads [OVR][meter] until the track is bought, then
	# [OVR][meter][AUTO-BUY] permanently. Nothing here or in Main indexes this bar's children.
	_auto_purchase_button.visible = unlocked
	# Kept in step with `visible` so a stray tap can never reach a hidden-but-live button.
	_auto_purchase_button.disabled = not unlocked
	if not unlocked:
		return

	_apply_auto_purchase_expansion(enabled)

	var plate := _auto_plate_on if enabled else _auto_plate_off
	var label_color := UiPalette.MUSTARD_GOLD if enabled else UiPalette.NAVY
	# All three interactive plates share the one look: this is a state indicator first and a button
	# second, so a hover or a held press must not momentarily read as the other mode.
	for state in ["normal", "hover", "pressed"]:
		_auto_purchase_button.add_theme_stylebox_override(state, plate)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		_auto_purchase_button.add_theme_color_override(state, label_color)

	# THE ARROW IS TINTED, NOT RECOLOURED IN THE ART. Both chevrons ship pure white, and the button
	# multiplies them to whatever the current plate needs: navy on the gold OFF plate, white on the
	# navy ON plate. Shipping them navy is what made the ON arrow invisible — navy on navy (Tim,
	# 2026-08-07: "there is no arrow showing on the left edge of the button at all").
	#
	# White for ON is Tim's call rather than matching the mustard label: the arrow is a direction
	# marker, not a second label, and full white separates it from the text sharing the plate.
	# The icon caption is tinted with the LABEL colour, not the arrow's: it is the face's text, just
	# drawn as pictures, so it should read as the label does on either plate.
	_tint_auto_purchase_caption(label_color)

	var arrow_color := Color.WHITE if enabled else UiPalette.NAVY
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_focus_color", "icon_hover_pressed_color"]:
		_auto_purchase_button.add_theme_color_override(state, arrow_color)

	_auto_purchase_button.tooltip_text = \
			"Auto-buy is ON — properties buy themselves, but rush is unavailable." if enabled \
			else "Auto-buy is OFF — tap to let properties buy themselves (rush turns off)."


## Build the collapsed face: "+ ∞ 🏠" — plus, infinity, property (Tim, 2026-08-07), replacing the
## word AUTO-BUY. It states what the mode DOES rather than what it is called, in the same
## "+ <icon> <rate>" grammar the BUY and HIRE toggles below it already use.
##
## An overlay rather than the Button's own `text`, because a Button can render one string and one
## icon — and that icon slot is already spent on the edge chevron. The overlay is mouse-ignoring, so
## every tap still reaches the button underneath.
##
## Right-aligned to sit opposite the chevron, matching where the status text lands when expanded.
func _build_auto_purchase_caption() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Clear the plate's own 12px content margin so the caption never touches the frame.
	margin.add_theme_constant_override("margin_right", AUTO_PURCHASE_CAPTION_INSET)
	margin.add_theme_constant_override("margin_left", AUTO_PURCHASE_CAPTION_INSET)
	_auto_purchase_button.add_child(margin)

	_auto_purchase_caption = HBoxContainer.new()
	_auto_purchase_caption.alignment = BoxContainer.ALIGNMENT_END
	_auto_purchase_caption.add_theme_constant_override("separation", AUTO_PURCHASE_CAPTION_GAP)
	_auto_purchase_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_auto_purchase_caption)

	var plus := Label.new()
	plus.text = "+"
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	plus.add_theme_font_override("font", UiPalette.make_bold_font())
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_purchase_caption.add_child(plus)
	_auto_purchase_caption_plus = plus

	# Both boxes are sized from MEASURED art, not from the canvas: infinity's visible glyph fills
	# only 41.7% of its 96px canvas (it is wide and short) while the property icon fills 86.1% of
	# its 324px one. Dividing the wanted visible height by each fraction is what lands the two at the
	# SAME optical size — using the raw canvas would draw the infinity less than half the height of
	# the building. Same correction the BUY/HIRE captions make (Main.MODE_ICON_VISIBLE_HEIGHT).
	_auto_purchase_caption.add_child(_make_caption_icon(
		AUTO_PURCHASE_INFINITY_ICON, AUTO_PURCHASE_INFINITY_BOX))
	_auto_purchase_caption.add_child(_make_caption_icon(
		AUTO_PURCHASE_PROPERTY_ICON, AUTO_PURCHASE_PROPERTY_BOX))

	# The EXPANDED face's rate readout — "AUTO-BUY 5/2.5s": what it buys per round, and how often
	# (Tim, 2026-08-07). Left-aligned, so it sits well left of centre with the status text holding
	# the right edge and the chevron the left; the expanded button is wide enough that three things
	# can share it without crowding.
	#
	# A sibling of the caption inside the SAME MarginContainer, which hands every child the identical
	# rect — so this one aligns itself left while the caption aligns right, and neither needs to know
	# the other exists. Only one of the two is ever visible anyway.
	_auto_purchase_rate_label = Label.new()
	_auto_purchase_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_auto_purchase_rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_auto_purchase_rate_label.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
	_auto_purchase_rate_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_auto_purchase_rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_purchase_rate_label.visible = false
	margin.add_child(_auto_purchase_rate_label)


## One icon in the AUTO-BUY caption, fitted into a square box and vertically centred.
func _make_caption_icon(texture: Texture2D, box: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(box, box)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_purchase_caption_icons.append(icon)
	return icon


## Tint the caption to match whichever plate is showing, exactly as the label colour does.
func _tint_auto_purchase_caption(color: Color) -> void:
	if _auto_purchase_caption_plus != null:
		_auto_purchase_caption_plus.add_theme_color_override("font_color", color)
	for icon in _auto_purchase_caption_icons:
		(icon as TextureRect).modulate = color
	# The rate readout is the same face, just the expanded one — it takes the same colour so the
	# button never shows two different "label" tints at once.
	if _auto_purchase_rate_label != null:
		_auto_purchase_rate_label.add_theme_color_override("font_color", color)


## Grow the button across the row while the mode runs, and collapse it back when it stops.
##
## The meter is left VISIBLE with a zero minimum rather than hidden: an HBoxContainer gives a hidden
## child no space at all, but it also stops laying it out, and the chip stack is anchored to the
## meter. Squeezing it to zero keeps that anchoring valid and means one flag flips back and the row
## is exactly as it was.
func _apply_auto_purchase_expansion(expanded: bool) -> void:
	if _auto_purchase_button == null or _meter == null:
		return
	if expanded:
		_meter.size_flags_horizontal = Control.SIZE_FILL
		_meter.custom_minimum_size.x = 0.0
		_auto_purchase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_auto_purchase_button.custom_minimum_size.x = 0.0
		_auto_purchase_button.icon = AUTO_PURCHASE_ARROW_EXPANDED
	else:
		_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_auto_purchase_button.size_flags_horizontal = Control.SIZE_FILL
		_auto_purchase_button.custom_minimum_size.x = AUTO_PURCHASE_WIDTH
		_auto_purchase_button.icon = AUTO_PURCHASE_ARROW_COLLAPSED
	# The two faces take turns: icons while collapsed, status text once expanded. Both are
	# right-aligned, so the swap happens in place with the chevron holding the other edge.
	if _auto_purchase_caption != null:
		_auto_purchase_caption.visible = not expanded
	if _auto_purchase_rate_label != null:
		_auto_purchase_rate_label.visible = expanded
		_auto_purchase_rate_label.text = _auto_purchase_rate_text()
	_auto_purchase_button.text = _auto_purchase_face_text(expanded)


## What the button says. Collapsed it names itself; expanded it reports what the desk is DOING —
## the count it buys per round, or that it cannot buy at all. The expanded button has the width to
## carry a sentence, and a mode that spends money on its own should say what it is spending.
## The expanded face's rate readout: "AUTO-BUY 5/2.5s" — five holdings every two and a half seconds.
##
## Both halves are the upgrade tracks made visible, which is the point: the player buys Buying Power
## and Standing Orders separately, and this is the one place the two show up as a single sentence
## about what the desk is actually doing.
##
## Falls back to the bare name if Main has not pushed numbers yet, so the button never reads
## "AUTO-BUY 0/0s" during the frame before the first push lands.
func _auto_purchase_rate_text() -> String:
	if _auto_purchase_quantity <= 0 or _auto_purchase_cadence <= 0.0:
		return "AUTO-BUY"
	return "AUTO-BUY %d/%ss" % [_auto_purchase_quantity, Money.trim(_auto_purchase_cadence, 2)]


func _auto_purchase_face_text(expanded: bool) -> String:
	if not expanded:
		return ""  # collapsed shows the icon caption instead (see _build_auto_purchase_caption)
	if _auto_purchase_idle:
		return "NOTHING TO BUY"
	if _auto_purchase_quantity > 0:
		return "BUYING ×%d" % _auto_purchase_quantity
	return "AUTO-BUY ON"


func _process(delta: float) -> void:
	_fade_auto_purchase_pulse(delta)
	var locked_out := _rush_momentum.is_locked_out()
	var cruising := _rush_momentum.is_cruising()
	# Overdrive DISPLAY mode: the engaged flag, not heat position — the instant the player opts
	# in the bar becomes the minigame instrument, and the instant the ride ends (release,
	# overheat) it stops being one. Lockout is checked too so the overheat drain always wins.
	var overdrive := _rush_momentum.is_overdrive_engaged() and not locked_out

	# The fill target per display mode. Every mode boundary is CONTINUOUS by construction, so
	# the eased fill never visibly jumps on a transition:
	#   • cruise → overdrive: engaging requires heat AT the cruise clamp, i.e. a full bar,
	#     which is exactly overdrive's pinned 1.0;
	#   • overdrive → spin-down (bail): see the spin-down branch — both sides are 1.0;
	#   • overdrive → lockout (overheat): heat is at/near the hard ceiling, so heat/ceiling
	#     starts ≈ 1.0 and the drain animates down from there;
	#   • lockout → cruise (re-arm): heat drained to 0, and 0/cruise is 0.
	# A First Contact reset mid-anything is the one hard cut (heat snaps to 0) — the eased
	# fill glides down, which reads as the meter powering off, and is fine.
	var target_fill: float
	if locked_out:
		# OVERHEAT: the full-heat drain display, unchanged — fill = heat / hard_ceiling so the
		# visible drain IS the cooldown. Guard the knob so a 0 can't divide by zero.
		# (An overheat zeroes the bank on the spot and is_spinning_down() is false throughout a
		# lockout, so the spin-down fill below can never leak into this display.)
		var hard_ceiling: float = maxf(_tuning.rush_momentum_hard_ceiling, 0.0001)
		target_fill = clampf(_rush_momentum.heat / hard_ceiling, 0.0, 1.0)
	elif overdrive:
		# OVERDRIVE: pinned full — the bar is the minigame stage, not a heat plot (see the
		# class comment for why pinned-full beat fill-as-countdown). Checked BEFORE the
		# spin-down because re-engaging during a spin-down starts a fresh ride (the bank keeps
		# decaying underneath as a cushion): the player is back in the minigame, and the
		# instrument needs its full stage. The spin-down chip keeps narrating the tail.
		target_fill = 1.0
	else:
		# CRUISE/BUILD: the whole bar spans 0 → the cruise clamp, so filling the bar IS
		# reaching cruise (Tim 2026-07-19). Legacy Cooling Systems moves the clamp; the
		# guard covers a hand-poked zero cruise bonus.
		var cruise: float = maxf(_rush_momentum.cruise_heat(), 0.0001)
		target_fill = clampf(_rush_momentum.heat / cruise, 0.0, 1.0)
		# A RELEASE TAIL needs nothing extra here (Tim 2026-07-20). The bonus follows heat down
		# the whole way, so this same heat fill is already the tail's remaining length: it starts
		# pinned full (heat sits at or above the clamp right after any ride) and reaches zero on
		# the exact tick the bonus does. An earlier build banked a separate number on its own
		# rate and had to special-case the fill to chase it; heat being the one clock is what
		# retired that special case.

	# Smoothing category for the tail's fill: EASED, like every other fill mode, and
	# deliberately NOT the frame-rate PREDICTION the approach bar and timer strip use. Those two
	# are reaction beats — the bar touching the target IS the window opening, the strip emptying
	# IS the miss — so a display that lagged would lie about a moment the player must hit, and
	# they earn the extra machinery. A spin-down is a readout: there is no input to time against
	# it, only money quietly running out. The ease costs well under a tenth of a second of lag on
	# an ending that is seconds long, and using the SAME pipeline as the other fill modes is what
	# keeps the bail transition seamless — a predicted fill handed off to an eased one would put a
	# visible seam at exactly the moment this fix exists to smooth.
	_displayed_fill = BarSmoothing.approach(_displayed_fill, target_fill, delta)
	_meter.value = _displayed_fill

	# Feed the overdrive instrument. Everything it shows is DERIVED FRESH each frame from the
	# core's live getters — that per-frame derivation IS the orphan watchdog: an approach or
	# window the core silently tore down (release-disengage, overheat, First Contact reset)
	# simply stops appearing on the very next frame, so a stale red bar or stale pips cannot
	# exist. (The old held-open "VENT!" chip needed an explicit watchdog for exactly this;
	# deriving instead of retaining removes the failure mode outright.)
	if overdrive:
		# The event bar's travel fraction: 1.0 at the right edge when the event spawns, 0.0 at
		# the target bar when the window opens — remaining / total, so a frenzy freeze (which
		# pauses the core's approach clock) visibly halts the bar mid-flight.
		var event_frac := -1.0  # negative = no event bar drawn
		if _rush_momentum.is_vent_approaching() and _vent_approach_seconds > 0.0:
			var approach_core := _rush_momentum.vent_approach_remaining()
			_approach_display = _predict_clock(
					_approach_display, approach_core, _approach_core_seen, delta)
			_approach_core_seen = approach_core
			event_frac = clampf(_approach_display / _vent_approach_seconds, 0.0, 1.0)
		var window_open := _rush_momentum.is_vent_window_open()
		var countdown_frac := 0.0
		if window_open:
			var window_core := _rush_momentum.vent_window_remaining()
			_window_display = _predict_clock(_window_display, window_core, _window_core_seen, delta)
			_window_core_seen = window_core
			countdown_frac = clampf(_window_display / _vent_window_duration, 0.0, 1.0)
		_instrument.update_overdrive(TARGET_FRAC, event_frac, window_open, countdown_frac,
				_rush_momentum.vent_required_lifts(), _window_lifts_done)
	elif locked_out:
		# The lockout paint: during the drain the overlay draws BOTH the red heat fill and the
		# dead-bar gray behind it from the shown (eased) _displayed_fill edge, one renderer sharing
		# one pixel edge so no track color can peek between red and gray (see _draw_lockout);
		# and during the re-arm it recedes on the core's real countdown fraction.
		# Snap UP, ease DOWN. The fraction jumps 0 → 1 the instant the drain ends and the re-arm
		# begins; easing INTO that would draw a zero-width gray on the transition frame and grow
		# it, flashing the dead bar back to life for a moment before it recedes. Only the recede
		# needs smoothing.
		var rearm_core := _rush_momentum.rearm_remaining_fraction()
		_rearm_display = rearm_core if rearm_core > _rearm_display \
				else BarSmoothing.approach(_rearm_display, rearm_core, delta)
		_instrument.update_lockout(_displayed_fill, _rearm_display)
	else:
		_instrument.update_idle()

	# The OVR button is a permanent fixture (Tim 2026-07-16: moving UI elements are annoying);
	# it ENABLES only once the hold has actually REACHED the cruise clamp (Tim 2026-07-16) —
	# cruising during the climb toward it stays gray — and shows the gray "can't trigger"
	# plate any other time. The >= (not ==) covers the re-press-while-still-hot case: heat
	# bleeding DOWN toward the clamp is already at cruise depth, so the gamble is available
	# immediately rather than after the cooldown dips below and climbs back.
	# Auto-purchase mode forces it gray on top of all that: the core refuses engage_rush_overdrive
	# outright while the mode is on, and a live-looking button whose taps are quietly ignored reads
	# as a bug (Plans/Rush_Overheat.md:61-62). It grays IN PLACE using the disabled plate built in
	# _ready — no new look, and nothing hides or moves.
	var at_cruise_depth: bool = _rush_momentum.heat >= _rush_momentum.cruise_heat() \
			or is_equal_approx(_rush_momentum.heat, _rush_momentum.cruise_heat())
	_overdrive_button.disabled = _auto_purchase_locked or not (cruising and at_cruise_depth)

	# The label: the live bonus normally; "CRUISE +X%" while the clamp is holding steady; the
	# lockout narration while shut down; "NO RUSH" while the Acquisitions Desk has rush
	# switched off. is_rearming is checked FIRST — it is a sub-state of is_locked_out (both true
	# during the re-arm delay).
	#
	# PRECEDENCE — the overheat states OUTRANK the auto-buy state, deliberately (both can be true
	# at once: an overheat that is already draining when the player flips auto-buy on, or a miss
	# landing on a hold that was live at the flip). The rule is "the state with a running clock
	# wins", because only that state can LIE:
	#   • OVERHEATED/COOLING is a bounded countdown that keeps running regardless of auto-buy —
	#     the drain drains, the re-arm re-arms, rush_ready still fires. Hiding it behind NO RUSH
	#     would strand the player with no idea how long the shutdown lasts.
	#   • The reverse would be worse still if we ranked auto-buy first and it happened to also
	#     show a countdown: a timer that is not counting down is a lie, and that is the exact
	#     failure this ordering exists to avoid.
	#   • NO RUSH has no clock to falsify. Deferring it costs only the couple of seconds the
	#     lockout takes, and it is still true — and still shown — the instant the lockout clears.
	# So a shutdown that happens during auto-buy narrates itself to completion, lands its READY
	# flash, and then falls through to NO RUSH, which is the honest reason from then on.
	# (Nothing is lost by deferring it: the lit AUTO-BUY button at the end of this row keeps saying
	# the mode is on for the whole lockout, so the player is never left guessing about the mode —
	# only about which of the two reasons rush is currently unavailable, and the timed one wins.)
	if _rush_momentum.is_rearming():
		_label.text = "COOLING…"
		_apply_label_state(_LabelState.COOLING)
	elif locked_out:
		_label.text = "OVERHEATED"
		_apply_label_state(_LabelState.OVERHEATED)
	elif _auto_purchase_locked:
		# The REASON, not the symptom: "rush is off because you turned auto-buy on". A control that
		# states a fact without explaining it already failed a device review once (the frozen-row
		# verdict, Plans/Overdrive_Vent_Windows.md:493-500), and "+0%" alone would be exactly that.
		#
		# This branch owns the readout for the whole spin-down too, which is on purpose: the bonus
		# is still being PAID while the tail bleeds out, and the fill below still plots it honestly,
		# but the one thing the player needs explained here is why the meter will not climb back.
		# Which fact this slot spends its pixels on depends on what the player most needs.
		# Normally it is the mode's COST — the lit button already says what is ON, so the label
		# says what that costs. But when the desk is running and cannot afford anything, the
		# urgent question stops being "why can't I rush" and becomes "why is nothing happening",
		# and a silent lit button reads as a broken feature. So the readout answers that instead.
		_label.text = "NOTHING TO BUY" if _auto_purchase_idle else "NO RUSH"
		_apply_label_state(_LabelState.AUTO_BUY)
	elif cruising and is_equal_approx(_rush_momentum.heat, _rush_momentum.cruise_heat()):
		# Sitting exactly on the clamp: the steady, content cruise state. The bonus quotes
		# effective_cruise_bonus() (base +25% plus Cooling Systems levels), never a hardcoded
		# number. While still CLIMBING toward the clamp the normal "+X%" branch below narrates
		# the climb, exactly as before.
		#
		# This branch can no longer contradict what is being paid, and the guard an earlier build
		# needed here is gone with the bank that caused it. Two independent reasons: a tail only
		# exists while NOT rushing (is_cruising() requires the opposite), and the bonus is a pure
		# function of heat, so sitting exactly ON the clamp pays exactly the cruise constant. A
		# re-press after a deep ride settles onto the clamp only after heat has bled down to it,
		# and the "+X%" branch below narrates every richer moment on the way.
		_label.text = "CRUISE +%d%%" % int(round(_rush_momentum.effective_cruise_bonus() * 100.0))
		_apply_label_state(_LabelState.CRUISING)
	else:
		_label.text = "+%d%%" % int(round(_rush_momentum.bonus * 100.0))
		_apply_label_state(_LabelState.NORMAL)

	# A locked meter is not accruing anything: hide the carbonation while it drains/re-arms so the
	# shutdown reads as dead air, not business as usual. Auto-buy mode gets the same treatment for
	# the same reason — the bubbles are the "value building automatically" cue, and with rush
	# refused the meter can only go DOWN. Bubbling over a bleeding-out tail would say the opposite
	# of what the fill is doing.
	_bubbles.visible = not locked_out and not _auto_purchase_locked

	# The SPINNING DOWN chip: up for exactly as long as a released hold is still paying a
	# decaying bonus. This is the ONLY signal that bailing is different from blowing up (Tim
	# 2026-07-20: "yes, and say so in the UI") — an overheat zeroes the bonus instantly, so it
	# simply never shows this chip, and the contrast between a live spin-down and nothing at all
	# is what teaches the choice.
	#
	# It quotes the LIVE effective bonus, which is the same number the "+X%" readout beside it
	# shows: the chip's job is not to add a figure but to say WHY that figure is falling — the
	# machine is easing off, not blowing up. Hidden during a lockout regardless, so a stale chip
	# can never sit over the overheat display.
	#
	# It is deliberately NOT suppressed by the auto-buy lockout, even though the bubbles and
	# streaks are. Those two imply an ACTIVE rush and would be false; this chip states that a
	# real, decaying bonus is still being paid, which is exactly what is happening — switching
	# auto-buy on IS letting go, and the tail pays out to zero as usual. It also becomes the only
	# place the tail's NUMBER appears, since the readout beside it is spending those pixels on the
	# cost ("NO RUSH") — so the two divide the work cleanly: chip quotes what is still being
	# paid, label says why it will not climb back.
	var spinning_down: bool = _rush_momentum.is_spinning_down() and not locked_out
	_spindown_chip.visible = spinning_down
	if spinning_down:
		_spindown_chip_label.text = "SPINNING DOWN +%d%%" \
				% int(round(_rush_momentum.bonus * 100.0))

	# The salmon streaks mark the overdrive ride itself now: with the fill pinned full, they are
	# the motion cue that the bar has switched into its minigame instrument. Never while merely
	# cruising or locked out — and never while auto-buy has rush switched off, where a "you are
	# riding the danger zone" cue would be plainly false. (The core refuses engage_rush_overdrive
	# while the mode is on, so this should already be false; the belt-and-braces term guarantees
	# it rather than trusting a second system's ordering.)
	_streaks.visible = overdrive and not _auto_purchase_locked

	_update_fill_color(delta, locked_out, overdrive)


## Recolor the fill AND its bubbles for the current display mode. Cruise/build mode is the calm
## instrument: always DARK_PURPLE, no wash, no blink (Tim 2026-07-19: clean and safe-reading).
## In OVERDRIVE mode the fill is pinned full and its COLOR carries the depth urgency instead:
## Advance one frame-rate display clock (see the _approach_display fields for why these exist).
##
## `core_value` is the core's authoritative seconds-remaining, republished only on the 10 Hz logic
## tick; `core_seen` is what it read LAST frame. The rules:
##   • The core's value going UP means a brand-new event or window — prediction can never do that,
##     so take it exactly. (Comparing against core_seen, not against the display: between ticks the
##     display legitimately falls BELOW a held core value, and treating that as a jump would snap
##     the bar back every frame — the very stutter this fixes.)
##   • Otherwise run down on the frame delta, clamped to stay within one logic tick of the truth.
##     The display leaves each tick equal to the core and arrives at the next exactly a tick lower,
##     so it glides continuously while never drifting more than one tick out of step.
func _predict_clock(display: float, core_value: float, core_seen: float, delta: float) -> float:
	if core_value > core_seen:
		return core_value
	var tick_seconds := 1.0 / maxf(float(_tuning.logic_hz), 1.0)
	return clampf(display - delta, maxf(core_value - tick_seconds, 0.0), core_value)


## purple → amber sliding with overdrive depth — heat's position within [cruise point .. hard
## ceiling], the same fraction the core's hazard rate interpolates on, so the bar's urgency and
## the actual vent-check danger climb together — with the red warning blink ramping in strength
## and frequency on that same depth. The blink's strength ramp starts at ZERO, so shallow riding
## barely shimmers and there is no depth at which it snaps on (no re-created band edge).
## Mutates the cached fill stylebox's bg_color, so no styleboxes are rebuilt.
func _update_fill_color(delta: float, locked_out: bool, overdrive: bool) -> void:
	if locked_out:
		# Draining after an overheat: a flat dark red — the punishment color, no blink (the
		# urgency is over; the player is just watching the cooldown empty out).
		# The OVERLAY paints the drain now; make the ProgressBar's own fill transparent so it
		# never draws a second, pixel-misaligned red edge underneath the overlay's — that double
		# edge was the source of the shimmering white sliver (Tim 2026-07-20; see _draw_lockout).
		# Every other mode below restores an opaque fill color, so this only holds while locked out.
		_fill_style.bg_color = Color(UiPalette.BRICK, 0.0)
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		return

	if not overdrive:
		# Cruise/build: the steady, CONTENT look, whatever heat is doing (including bleeding
		# back down after a bailed ride — the bar left the danger business when overdrive
		# disengaged, so no danger color may linger).
		_fill_style.bg_color = UiPalette.DARK_PURPLE
		_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE
		_blink_phase = 0.0
		return

	# Overdrive depth: how far into [cruise point .. hard ceiling] heat is riding.
	var heat: float = _rush_momentum.heat
	var cruise_heat: float = _rush_momentum.cruise_heat()
	var hard_ceiling: float = maxf(_tuning.rush_momentum_hard_ceiling, 0.0001)
	var depth_span: float = maxf(hard_ceiling - cruise_heat, 0.0001)
	var depth_frac: float = clampf((heat - cruise_heat) / depth_span, 0.0, 1.0)

	# Base color: fill and bubbles slide purple → amber across the whole overdrive span.
	var base_fill: Color = UiPalette.DARK_PURPLE.lerp(UiPalette.MUSTARD_GOLD, depth_frac)
	_bubbles.bubble_color = UiPalette.BRIGHT_PURPLE.lerp(UiPalette.PALE_GOLD, depth_frac)

	# The red warning blink, pulsing the base color toward KETCHUP_RED. Phase accumulates at
	# the CURRENT frequency so the ramping frequency never makes the sine jump. Strength
	# scales straight off depth_frac (zero at the cruise point): shallow overdrive barely
	# shimmers, riding just under the backstop flashes hard and fast.
	var blink_hz: float = lerpf(BLINK_HZ_MIN, BLINK_HZ_MAX, depth_frac)
	var strength: float = BLINK_STRENGTH_MAX * depth_frac
	_blink_phase += delta * blink_hz * TAU
	var pulse: float = (sin(_blink_phase) * 0.5 + 0.5) * strength
	_fill_style.bg_color = base_fill.lerp(UiPalette.KETCHUP_RED, pulse)


## Swap the readout label's look per state. Only rebuilds the overrides on a change.
## OVERHEATED reads in red with a cream outline — the fill behind it is dark red while draining,
## so the outline carries the contrast (§1b: the failure state must be readable, not subtle).
func _apply_label_state(state: int) -> void:
	if state == _label_state_applied:
		return
	_label_state_applied = state

	# SIZE IS PART OF THE STATE, not a fixed property of the label (Tim, 2026-08-07: the cruise
	# readout should be about 40% larger). The readout was shrunk to FONT_LABEL earlier the same day
	# so the bar reads as a named bar with a small figure on it — but CRUISE is the one state that is
	# an achievement rather than a status line, and at the small size it disappeared into the row.
	#
	# Derived from the base rather than written as a literal, so the 40% survives any future change
	# to the resting size. It lands off the UiPalette scale by a couple of points, which is the
	# deliberate cost of honouring the ratio.
	_label.add_theme_font_size_override("font_size",
		int(round(float(UiPalette.FONT_LABEL) * CRUISE_LABEL_SCALE)) if state == _LabelState.CRUISING
			else UiPalette.FONT_LABEL)

	match state:
		_LabelState.CRUISING:
			# Calm teal: the "settled in, safe forever" color — deliberately nothing like the
			# amber/red danger escalation. The navy outline keeps it readable over both the
			# dark purple fill and the pale track.
			_label.add_theme_color_override("font_color", UiPalette.ATOMIC_TEAL)
			_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
			_label.add_theme_constant_override("outline_size", 6)
		_LabelState.OVERHEATED:
			_label.add_theme_color_override("font_color", UiPalette.KETCHUP_RED)
			_label.add_theme_color_override("font_outline_color", UiPalette.CREAM)
			_label.add_theme_constant_override("outline_size", 8)
		_LabelState.COOLING:
			# Calm near-white gold: "almost back" — distinct from both the red failure text and
			# the plain white live readout.
			_label.add_theme_color_override("font_color", UiPalette.PALE_GOLD)
			_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
			_label.add_theme_constant_override("outline_size", 6)
		_LabelState.AUTO_BUY:
			# CREAM on a heavy INK_NAVY outline — the same "readable over anything" treatment the
			# OVERHEATED state gets, because this text has to survive the identical range of
			# backgrounds: the dark purple fill while the tail is still high, and the pale track
			# once it has bled to nothing.
			#
			# Cream (not red, not gold, not teal) on purpose: this is neither a failure, an
			# act-now prompt, nor a reward — it is the machine standing down because the player
			# chose it. Cream is the panel/paper color, the most neutral voice in the palette, and
			# it is the same "inert" family as the disabled OVR plate this state also lights up.
			_label.add_theme_color_override("font_color", UiPalette.CREAM)
			_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
			_label.add_theme_constant_override("outline_size", 8)
		_:
			_label.add_theme_color_override("font_color", Color.WHITE)
			_label.remove_theme_color_override("font_outline_color")
			_label.add_theme_constant_override("outline_size", 0)


## Heat hit the hard ceiling, or a vent window was missed: the shutdown moment. The
## label/fill/instrument changes are all per-frame state reads (see _process — the instrument
## clears itself the moment the mode flips, so there is no telegraph to dismiss here any more);
## this handler only adds the long haptic thump so the failure lands physically as well as
## visually.
func _on_overheated(ended_vent_tier: int) -> void:
	_vibrate(_tuning.rush_momentum_haptic_overheat_ms)
	# The death chip: how high this run got, and the bloodline best it is measured against (Tim
	# 2026-07-20). Reuses the vent-success chip's shape (see _on_vent_succeeded) in a hot ketchup
	# red so it reads as the shutdown, not a payoff. best = max(this run, the stored record): both
	# DynastyState and this bar listen to `overheated`, and DynastyState connects first (it hooks
	# the generation before Main builds this bar), so the record is already updated — but taking the
	# max makes the chip correct regardless of listener order rather than depending on it.
	var best := ended_vent_tier
	if _dynasty != null:
		best = maxi(ended_vent_tier, _dynasty.get_best_vent_streak())
	_show_tier_chip(
			"TIER %d — BEST %d" % [ended_vent_tier, best],
			UiPalette.KETCHUP_RED, UiPalette.PALE_GOLD)


## The re-arm delay finished: rush is available again. Flash the whole meter bright once (plus a
## short haptic tick) so re-availability is unmissable — the label reverts to "+0%" on its own
## via _process now that is_locked_out() is false.
func _on_rush_ready() -> void:
	_vibrate(_tuning.rush_momentum_haptic_ready_ms)
	_ready_flash.color = Color(1, 1, 1, READY_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_ready_flash, "color:a", 0.0, READY_FLASH_FADE_SEC)


# ---------------------------------------------------------------------------
# Vent Windows: the approach telegraph and its resolutions
# (Plans/Overdrive_Vent_Windows.md, approach-bar rework Tim 2026-07-19)
# ---------------------------------------------------------------------------

## A vent event just SPAWNED at the bar's right edge (~approach_seconds from triggering). Record
## the divisor for the event bar's travel math, and fire the vent haptic HERE, at the spawn —
## not at window-open — because a warning pulse with the whole approach still ahead is what a
## telegraph haptic is FOR (it preserves the shipped meaning: "a check is coming, get ready",
## with time to act on it). At window-open a buzz would land at the exact instant the player
## should already be lifting — too late to help, and it would smear the physical beat players
## calibrate their gesture timing against. The visual "NOW" is the red bar reaching the target.
## The pulse also COUNTS the demand: one buzz per required lift (Tim 2026-07-20) — see
## _pulse_vent_telegraph.
func _on_vent_incoming(approach_seconds: float, required_lifts: int) -> void:
	_vent_approach_seconds = maxf(approach_seconds, 0.001)
	# Start the display clock exactly at the spawn value: the event is at the right edge NOW.
	# (_predict_clock's snap-on-increase rule would catch this anyway; setting it here makes the
	# first drawn frame exact rather than inferred.)
	_approach_display = _vent_approach_seconds
	_approach_core_seen = _vent_approach_seconds
	_pulse_vent_telegraph(required_lifts)


## The event reached the target: the window is open, the gesture clock is running. All the
## presentation is in-bar now (pips + countdown via the instrument overlay, driven per frame by
## _process) — no chip: the old held-open gold "VENT!" plate is retired, replaced by the
## approaching red bar the player has been watching for the whole approach.
func _on_vent_window_opened(_required_lifts: int, duration: float) -> void:
	_vent_window_duration = maxf(duration, 0.001)
	# The countdown starts full this instant — same reasoning as the approach clock above.
	_window_display = _vent_window_duration
	_window_core_seen = _vent_window_duration
	_window_lifts_done = 0


## A gesture lift landed: the in-bar pip display fills one more (the ×2/×3 vents need the
## player to KNOW each lift registered). _process feeds the tally to the instrument.
func _on_vent_lift_registered(lifts_done: int, _required_lifts: int) -> void:
	_window_lifts_done = lifts_done


## Vent completed in time: heat drops and the bonus ladder ratchets up a rung. A timed chip
## quotes the NEW excursion peak (the signal's value, so the number can never drift from the
## core's ladder), in celebratory money-green, plus the same full-meter white flash the READY
## moment uses — success should feel like a payoff, not mere survival.
func _on_vent_succeeded(new_tier: int, new_peak_bonus: float) -> void:
	# "UP TO", not "PEAK" (Tim, 2026-07-20). This number is current_peak_bonus() — the CEILING of
	# the ladder you have just unlocked, i.e. what you would earn riding at the hard backstop — not
	# what you are earning right now. The bar's own "+X%" and the spin-down chip both report the LIVE
	# lerped bonus, which is always lower unless heat is pinned at the ceiling. Tim read all three
	# on device and reasonably took them for the same quantity disagreeing.
	#
	# The ceiling stays on screen deliberately rather than being hidden to make the numbers match:
	# it is the whole reason riding deeper pays, so it earns its place — it just has to be LABELLED
	# as a ceiling. Naming the tier alongside it also gives the run its running score, which is what
	# Tim was looking for in this chip. The green plate and the chip's arrival remain the "you did
	# it" signal, so the words are free to carry the new information instead of repeating it.
	_show_tier_chip(
			"TIER %d — UP TO +%d%%" % [new_tier, int(round(new_peak_bonus * 100.0))],
			UiPalette.MONEY_GREEN, UiPalette.NAVY)
	_ready_flash.color = Color(1, 1, 1, READY_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_ready_flash, "color:a", 0.0, READY_FLASH_FADE_SEC)


## The window was blown (expired, or the gesture fumbled) — fired just before the overheat
## lands. The blown beat must stay VISIBLE (the plan's rule: miss-feedback is what makes the
## skill check learnable), and the bar itself can't show it — the overheat flips the bar into
## its drain display, wiping the in-bar pips — so the miss CHIP carries the pips: the demanded
## count with the landed ones solid and the unfinished ones strobing red, held for the chip's
## timed life while the OVERHEATED presentation plays underneath.
func _on_vent_missed(lifts_done: int, required_lifts: int) -> void:
	_vent_pips.show_miss(required_lifts, lifts_done)
	_show_tier_chip("VENT MISSED!", UiPalette.KETCHUP_RED, UiPalette.PALE_GOLD)


## Show the tier chip: set its text/colors, ease it in, hold, fade out. A new chip request while
## the old chip is still up simply restarts the sequence with the new text. The end-of-fade
## cleanup also retires the miss pips + strobe, so a miss chip tidies itself up and the next
## chip can never inherit stale pips.
func _show_tier_chip(text: String, plate_color: Color, text_color: Color) -> void:
	_style_tier_chip(text, plate_color, text_color)
	if _tier_chip_tween != null and _tier_chip_tween.is_valid():
		_tier_chip_tween.kill()
	_tier_chip.visible = true
	_tier_chip.modulate = Color(1, 1, 1, 0)
	_tier_chip_tween = create_tween()
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 1.0, TIER_CHIP_FADE_IN_SEC)
	_tier_chip_tween.tween_interval(TIER_CHIP_HOLD_SEC)
	_tier_chip_tween.tween_property(_tier_chip, "modulate:a", 0.0, TIER_CHIP_FADE_OUT_SEC)
	_tier_chip_tween.tween_callback(func() -> void:
		_tier_chip.visible = false
		_vent_pips.visible = false
		_vent_pips.stop_miss_flash())


## Apply text + plate/text colors to the chip.
func _style_tier_chip(text: String, plate_color: Color, text_color: Color) -> void:
	_tier_chip_label.text = text
	_tier_chip_label.add_theme_color_override("font_color", text_color)
	var plate := StyleBoxFlat.new()
	plate.bg_color = plate_color
	plate.border_color = UiPalette.NAVY
	plate.set_border_width_all(3)
	plate.set_corner_radius_all(8)
	plate.set_content_margin_all(14)
	_tier_chip.add_theme_stylebox_override("panel", plate)


## Haptic tap, mobile only — desktop must stay silent (Input.vibrate_handheld is a no-op on most
## desktops anyway, but the explicit guard documents the intent and costs nothing). Takes the
## tuning knob's float directly; a knob dialed to 0 (or below) disables that pulse.
func _vibrate(duration_ms: float) -> void:
	if duration_ms >= 1.0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration_ms))


## The vent telegraph's haptic: ONE PULSE PER REQUIRED LIFT (Tim 2026-07-20). A x2 window buzzes
## twice, a x3 three times, so the thumb already knows the demand before the eyes get to the pips
## — deliberate redundant encoding for the moment the mechanic is fastest.
##
## The pulses are played as a train rather than one long buzz: each pulse waits out its OWN length
## plus the gap knob before the next fires, so the player feels distinct counted beats. This is a
## coroutine (it awaits scene-tree timers), which is why it is fire-and-forget from the signal
## handler — the caller does not await it.
##
## Sized to fit inside the approach: at the shipped 80 ms pulse + 70 ms gap, three pulses take
## ~370 ms against a 1.2 s runway. The is_inside_tree() re-check after each wait covers the bar
## being torn down mid-train (screen change, First Contact reset).
func _pulse_vent_telegraph(required_lifts: int) -> void:
	var pulse_ms: float = _tuning.rush_momentum_haptic_vent_ms
	if pulse_ms < 1.0 or not OS.has_feature("mobile"):
		return  # knob disabled, or desktop — no train to play
	var pulses: int = maxi(required_lifts, 1)
	var gap_ms: float = maxf(_tuning.rush_momentum_haptic_vent_gap_ms, 0.0)
	for i in range(pulses):
		_vibrate(pulse_ms)
		if i == pulses - 1:
			return
		await get_tree().create_timer((pulse_ms + gap_ms) / 1000.0).timeout
		if not is_inside_tree():
			return


# ---------------------------------------------------------------------------
# The overdrive instrument overlay
# ---------------------------------------------------------------------------

## Custom-drawn overlay for the bar's OVERDRIVE minigame instrument (the same _draw approach
## MomentumStreaks uses), plus the OVERHEAT lockout's dead-bar gray — its one job outside
## overdrive. Draws NOTHING in cruise/build mode: the calm bar is deliberately unadorned now
## that its right edge IS the cruise point.
##
## In overdrive mode it draws, back to front:
##   • the APPROACH TRAIL: while the red event bar travels left, the region from the bar back
##     to the RIGHT edge fills with a dim gold wash — the event "fills in behind" its leading
##     edge (Tim 2026-07-18 night), so the approach reads as a REGION sweeping in, not a lone
##     thin bar. Dim MUSTARD_GOLD — the same act-now gold family as the target bar and the
##     open-window dressing — so the approach and the open event share one visual identity:
##     the trail IS the event backdrop, arriving.
##   • while a window is OPEN: the EVENT BACKDROP — the same gold wash, a step brighter, held
##     STEADY across the whole region right of the target. The trail grows to cover exactly
##     this region at the instant the event arrives, so opening reads as "the sweep completed
##     and lit up", never a cut to something new.
##   • while a window is OPEN: the TIMER STRIP — a thin, bright-gold horizontal bar hugging
##     the region's bottom edge, its right end draining left toward the target as time runs
##     out. It replaces the old full-region draining plate (which would now fight the steady
##     backdrop for the same pixels). Bottom placement keeps it clear of the centered pips;
##     spanning the full region means full strip = full window at a glance; and the leftward
##     drain continues the established motion language — everything about an event collapses
##     leftward into the target, so "the strip reaches the target = time's up" needs no
##     explanation.
##   • while a window is OPEN: the gesture pips, centered in the whole region right of the
##     target (VentPipRow's ring/disc drawing adapted to bar scale — ring = lift still owed,
##     solid disc = landed), brightened to be the most luminous marks on the bar (see the pip
##     color constants).
##   • the traveling EVENT BAR: bright red, entering at the right edge and moving left; its
##     reaching the target IS the window opening.
##   • the fixed TARGET BAR at TARGET_FRAC: the trigger point. Same wide-bar silhouette as the
##     retired teal cruise marker (a shape the player already reads as "a line that matters"),
##     but in MUSTARD_GOLD — the act-now family the old "VENT!" chip established — because
##     this line is where acting happens, not where safety ends. Drawn LAST so nothing tints it.
##
## In LOCKOUT (Tim 2026-07-18 night) it draws the whole bar — the draining red heat fill AND the
## dead-bar gray behind it (the host suppresses the ProgressBar's own fill while locked out, so
## this overlay is the SINGLE renderer of the drain edge; Tim 2026-07-20):
##   • drain phase: red heat fill on the left, dark gray filling the track it has vacated on the
##     right, meeting at one shared rounded pixel, so the bar visibly dies from the right as it
##     cools with no sliver of light track shimmering between the two;
##   • re-arm phase: the gray covers the whole bar, then its right edge recedes leftward in
##     proportion to the re-arm countdown, revealing the normal track gray behind it — the
##     gray's retreat IS the visual re-arm timer, and the READY flash lands on a bar that
##     already looks normal again.
##
## All x math uses the FILL's coordinate system (frac × size.x − inset): ProgressBar computes
## its fill rect across the bar's FULL width and the fill stylebox's −3px expand margin pulls
## the drawn edge back by the inset. Mapping fractions onto the inset track instead put markers
## ~1-2px off the true fill edge — the documented off-by-inset gotcha (Tim 2026-07-15).
class OverdriveInstrumentOverlay extends Control:
	## Match the framed fill's 3px inset (UiPalette.style_framed_progress).
	const EDGE_INSET := 3.0
	## The fixed target bar (the trigger point). Wide like the old cruise marker was — the one
	## landmark on the track must land at a glance (Tim 2026-07-16).
	const TARGET_BAR_WIDTH := 10.0
	const TARGET_BAR_COLOR := Color("#E3B23C")        # MUSTARD_GOLD — the act-now family
	## The traveling vent event: bright red, unmistakably "incoming trouble".
	const EVENT_BAR_WIDTH := 10.0
	const EVENT_BAR_COLOR := Color("#E8503A")         # KETCHUP_RED, brightened to read as LIVE
	## The approach trail and the open window's backdrop: ONE gold at two strengths. The
	## countdown plate's MUSTARD_GOLD family was kept on purpose (Tim 2026-07-18 night) so the
	## whole event lifecycle — trail, backdrop, timer strip, target bar — wears one identity;
	## the trail is the DIMMER of the two so the region lighting up a step at the arrival
	## instant reads as an escalation, not a repaint. Same hue, only alpha apart, so the trail
	## growing to full width IS the backdrop appearing — a seamless open.
	const APPROACH_TRAIL_COLOR := Color("#E3B23C", 0.25)   # dim translucent MUSTARD_GOLD
	const WINDOW_BACKDROP_COLOR := Color("#E3B23C", 0.40)  # the same gold, lit up
	## The open window's TIMER STRIP (replaces the full-region draining plate): thin, opaque,
	## and a notch brighter than MUSTARD_GOLD so it stays readable ON the translucent gold
	## backdrop it drains across. Geometry: hugs the region's bottom edge, below the centered
	## pips, with a small gap so it never welds visually onto the frame.
	## Device-pass contrast fix (Tim 2026-07-18: strip and pips were "too dim to see"): the
	## strip and pips sit on a GOLD backdrop over an amber fill wash, so gold-family marks
	## vanished into their own hue. Brightness alone can't fix same-hue stacking — each mark
	## now gets a DARK NAVY backing (a full-runway track under the strip, a halo behind each
	## pip) so the bright mark reads by contrast at any wash depth.
	const TIMER_STRIP_COLOR := Color("#FFF7E6")            # near-white warm, matches landed pips
	const TIMER_TRACK_COLOR := Color("#1D2D50", 0.85)      # UiPalette.NAVY backing track
	const TIMER_STRIP_HEIGHT := 8.0
	const TIMER_TRACK_PAD := 2.0                           # navy border visible around the strip
	const TIMER_STRIP_BOTTOM_GAP := 3.0
	## Everything the timer strip claims off the bar's bottom edge (gap + strip + the navy
	## backing track's padding). The pips are centered in the space ABOVE this band rather
	## than in the whole region, so the bigger pips (see PIP_RADIUS_MAX) can never overlap
	## the strip — two separate reads must never share pixels.
	const TIMER_STRIP_RESERVED := TIMER_STRIP_BOTTOM_GAP + TIMER_STRIP_HEIGHT + TIMER_TRACK_PAD
	## In-bar gesture pips, BRIGHTENED (Tim 2026-07-18 night — the old cream washed out against
	## the gold backdrop). A landed lift is a near-white disc — deliberately the most luminous
	## mark on the whole bar, because a registered beat is the confirmation the gesture lives
	## or dies on — and an owed lift is a bright-gold ring: luminous enough to pop off the
	## backdrop for contrast, while the solid-vs-outline SHAPE difference (not brightness
	## alone) is what keeps filled-vs-owed instantly distinguishable at a glance.
	const PIP_FILLED_COLOR := Color("#FFF7E6")             # near-white warm
	const PIP_RING_COLOR := Color("#FFF7E6")               # near-white too — the halo, not hue, separates it
	const PIP_HALO_COLOR := Color("#1D2D50", 0.85)         # navy halo behind every pip (contrast fix)
	const PIP_HALO_PAD := 5.0                              # halo radius beyond the pip silhouette
	const PIP_OUTLINE := 8.0
	## Pip radius as a fraction of the bar's inner height, with a hard cap so a desktop-resized
	## bar can't grow comedy pips. Three pips at this size fit the two-thirds-width region on
	## the narrowest supported phone with room to spare.
	## SIZE BUMP (Tim 2026-07-20: pips "readable but small"). BOTH numbers had to move: the
	## cap was the BINDING constraint at the shipped bar height, so raising the fraction
	## alone would have changed nothing on the phone. Radius 20 → 26 px (diameter 40 → 52).
	## The halo pad and the ring stroke went up with it (4 → 5, 6 → 8) so the proportions —
	## and so the filled-disc vs owed-ring read — stay as crisp as before, just larger.
	const PIP_HEIGHT_FRAC := 0.40
	const PIP_RADIUS_MAX := 26.0
	## Center-to-center pip spacing, in pip radii.
	const PIP_SPACING_RADII := 3.0

	## The lockout's dead-bar gray. Far darker than the normal PROGRESS_TRACK_GRAY (#B6BAC0)
	## so a locked bar is unmistakably DEAD at a glance, but a neutral slate rather than
	## near-black: the draining BRICK-red fill must still read against it, and red on a
	## neutral dark gray keeps its hue contrast where red on near-black would just be two
	## dark shapes.
	const LOCKOUT_GRAY := Color("#45464C")
	## The draining heat fill during lockout, drawn BY THIS OVERLAY (Tim 2026-07-20). The
	## host suppresses the ProgressBar's own fill while locked out and this overlay paints
	## both the red drain and the gray behind it, so the drain edge is ONE edge shared by
	## both rects — see _draw_lockout. Matches UiPalette.BRICK (the punishment color the
	## fill wore before), following this class's hex-literal-with-palette-name convention.
	const LOCKOUT_FILL_COLOR := Color("#8E2F1E")      # UiPalette.BRICK

	## Display state, fed every frame by the host's _process (derived fresh from the core each
	## frame — see the watchdog note there). _event_frac < 0 means no event bar. _active and
	## _lockout are mutually exclusive modes; both false = the invisible cruise/build idle.
	var _active := false
	var _target_frac := 0.33
	var _event_frac := -1.0
	var _window_open := false
	var _countdown_frac := 0.0
	var _required_lifts := 1
	var _lifts_done := 0
	var _lockout := false
	var _lockout_fill_frac := 0.0
	var _rearm_frac := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Overdrive mode: update the instrument's geometry; redraws only on actual change.
	func update_overdrive(target_frac: float, event_frac: float, window_open: bool,
			countdown_frac: float, required_lifts: int, lifts_done: int) -> void:
		if _active and not _lockout and is_equal_approx(target_frac, _target_frac) \
				and is_equal_approx(event_frac, _event_frac) \
				and window_open == _window_open \
				and is_equal_approx(countdown_frac, _countdown_frac) \
				and required_lifts == _required_lifts and lifts_done == _lifts_done:
			return
		_active = true
		_lockout = false
		_target_frac = target_frac
		_event_frac = event_frac
		_window_open = window_open
		_countdown_frac = countdown_frac
		_required_lifts = required_lifts
		_lifts_done = lifts_done
		queue_redraw()

	## Overheat lockout mode: the overlay paints the whole bar. `fill_frac` is the meter's SHOWN
	## (eased) fill; _draw_lockout draws the red heat fill left of that edge and the dead-bar gray
	## right of it, sharing one rounded pixel so there is no seam. `rearm_frac` is the core's
	## re-arm countdown remaining (0 while the drain phase still runs).
	func update_lockout(fill_frac: float, rearm_frac: float) -> void:
		if _lockout and is_equal_approx(fill_frac, _lockout_fill_frac) \
				and is_equal_approx(rearm_frac, _rearm_frac):
			return
		_lockout = true
		_active = false
		_lockout_fill_frac = fill_frac
		_rearm_frac = rearm_frac
		queue_redraw()

	## Cruise/build mode: the instrument draws nothing.
	func update_idle() -> void:
		if not _active and not _lockout:
			return
		_active = false
		_lockout = false
		queue_redraw()

	func _draw() -> void:
		var top := EDGE_INSET
		var bottom := size.y - EDGE_INSET
		if size.x <= EDGE_INSET * 2.0 or bottom <= top:
			return
		if _lockout:
			_draw_lockout(top, bottom)
			return
		if not _active:
			return
		# Fraction → x pixel in the fill's coordinate system (see the class comment).
		var target_x := maxf(_target_frac * size.x - EDGE_INSET, EDGE_INSET)
		var right_x := size.x - EDGE_INSET
		var runway := right_x - target_x
		if runway <= 0.0:
			return

		if _window_open:
			# The steady event backdrop across the whole region right of the target — the lit
			# stage the pips and the timer strip play on (the countdown no longer moves it).
			draw_rect(Rect2(target_x, top, runway, bottom - top), WINDOW_BACKDROP_COLOR)
			# The timer strip: anchored at the target, right end draining left as the window
			# runs out (placement + drain-direction rationale in the class comment).
			var strip_top := bottom - TIMER_STRIP_BOTTOM_GAP - TIMER_STRIP_HEIGHT
		# Navy backing track across the FULL runway first — the strip drains against it,
			# so both the remaining time and the elapsed gap read at a glance (contrast fix).
			draw_rect(Rect2(target_x - TIMER_TRACK_PAD, strip_top - TIMER_TRACK_PAD,
					runway + TIMER_TRACK_PAD * 2.0,
					TIMER_STRIP_HEIGHT + TIMER_TRACK_PAD * 2.0), TIMER_TRACK_COLOR)
			var strip_width := runway * clampf(_countdown_frac, 0.0, 1.0)
			if strip_width > 0.0:
				draw_rect(Rect2(target_x, strip_top, strip_width, TIMER_STRIP_HEIGHT),
						TIMER_STRIP_COLOR)
			_draw_pips(target_x, right_x, top, bottom)

		if _event_frac >= 0.0:
			# The traveling event: position interpolates target → right edge on the approach
			# fraction (1.0 just spawned, 0.0 = arrived = window opening). Clamped so the bar
			# never pokes past the frame at either end of its run.
			var event_x := target_x + runway * clampf(_event_frac, 0.0, 1.0)
			var half := EVENT_BAR_WIDTH * 0.5
			event_x = clampf(event_x, target_x, right_x - half)
			# The approach trail FIRST, from the event bar's center back to the right edge —
			# the region filling in behind the leading edge (the event bar draws over the
			# seam). Center, not the bar's left edge, so the trail can never peek out ahead
			# of the red bar and muddy which edge is leading.
			if right_x - event_x > 0.0:
				draw_rect(Rect2(event_x, top, right_x - event_x, bottom - top),
						APPROACH_TRAIL_COLOR)
			draw_rect(Rect2(event_x - half, top, EVENT_BAR_WIDTH, bottom - top),
					EVENT_BAR_COLOR)

		# The target bar, drawn LAST so neither the backdrop nor an arriving event tints it.
		draw_rect(Rect2(target_x - TARGET_BAR_WIDTH * 0.5, top, TARGET_BAR_WIDTH,
				bottom - top), TARGET_BAR_COLOR)

	## The lockout's dead-bar gray (see the class comment's LOCKOUT section). The re-arm
	## branch is checked FIRST: the eased fill can lag a hair above zero when the re-arm
	## begins, and the full-width gray must win that frame rather than leave a red sliver.
	func _draw_lockout(top: float, bottom: float) -> void:
		var left_x := EDGE_INSET
		var right_x := size.x - EDGE_INSET
		if _rearm_frac > 0.0:
			# Re-arm phase: the gray anchors at the LEFT and its right edge recedes leftward
			# with the countdown — the same rightward-reveal direction the READY moment then
			# confirms. Width rides the core's real fraction, so Rapid Restart and the
			# per-tier sting are automatically honest.
			var gray_width := (right_x - left_x) * clampf(_rearm_frac, 0.0, 1.0)
			if gray_width > 0.0:
				draw_rect(Rect2(left_x, top, gray_width, bottom - top), LOCKOUT_GRAY)
			return
		# Drain phase: THIS overlay paints the whole bar — red drain on the left, dead gray on
		# the right — so both share ONE leading edge and no third color (the light track gray)
		# can ever peek between them (Tim 2026-07-20: the drain had a thin, squiggly white sliver).
		#
		# The edge is rounded to a whole pixel with round(). Two renderers used to draw this drain:
		# Godot's ProgressBar fill (right edge at round(frac × width) − inset, integer-snapped) and
		# this overlay's gray (left edge at the UNROUNDED frac × width − inset). The two edges
		# disagreed by a sub-pixel that oscillated 0–1px as the eased fill slid, revealing a shimmering
		# strip of PROGRESS_TRACK_GRAY between them. Making one renderer draw both, at one rounded x,
		# removes the seam by construction. The eased fill (_lockout_fill_frac) is unchanged — the edge
		# still moves smoothly; it just lands on a whole pixel and stops shimmering.
		var fill_x := clampf(round(_lockout_fill_frac * size.x) - EDGE_INSET, left_x, right_x)
		if fill_x - left_x > 0.0:
			draw_rect(Rect2(left_x, top, fill_x - left_x, bottom - top), LOCKOUT_FILL_COLOR)
		if right_x - fill_x > 0.0:
			draw_rect(Rect2(fill_x, top, right_x - fill_x, bottom - top), LOCKOUT_GRAY)

	## The gesture pips at bar scale, centered in the region right of the target: one per
	## demanded lift, ring = still owed, solid disc = landed (VentPipRow's language, adapted).
	## They sit ON TOP of the steady backdrop and keep a fixed position — progress is the pips
	## filling, time is the strip draining; two separate reads, neither moving the other.
	func _draw_pips(region_left: float, region_right: float, top: float, bottom: float) -> void:
		# The band the pips live in: everything above the pixels the timer strip reserves.
		var pip_band_bottom := bottom - TIMER_STRIP_RESERVED
		var center_y := (top + pip_band_bottom) * 0.5
		# Largest pip (INCLUDING its navy halo) that still fits inside that band. This is a
		# safety net for short/resized bars — at the shipped bar height PIP_RADIUS_MAX binds
		# first, which is the intended size.
		var radius_fit := (pip_band_bottom - top) * 0.5 - PIP_HALO_PAD
		var pip_radius := minf(minf((bottom - top) * PIP_HEIGHT_FRAC, PIP_RADIUS_MAX), radius_fit)
		if pip_radius <= 0.0:
			return
		var spacing := pip_radius * PIP_SPACING_RADII
		var row_width := spacing * float(_required_lifts - 1)
		var first_x := (region_left + region_right) * 0.5 - row_width * 0.5
		for i in range(_required_lifts):
			var center := Vector2(first_x + spacing * float(i), center_y)
			# Navy halo behind every pip — the contrast plate the bright mark reads against
			# (see the contrast-fix note at the constants).
			draw_circle(center, pip_radius + PIP_HALO_PAD, PIP_HALO_COLOR)
			if i < _lifts_done:
				draw_circle(center, pip_radius, PIP_FILLED_COLOR)
			else:
				# Radius inset by half the stroke so the ring's OUTER edge matches a filled
				# pip's silhouette — filling a pip must read as "same pip, now solid".
				draw_arc(center, pip_radius - PIP_OUTLINE * 0.5, 0.0, TAU, 48, PIP_RING_COLOR,
						PIP_OUTLINE, true)


# ---------------------------------------------------------------------------
# The miss-feedback pips (chip)
# ---------------------------------------------------------------------------

## The miss chip's gesture post-mortem, drawn inside the tier chip beneath its text line: one
## LARGE pip per demanded lift, the landed ones solid, the unfinished ones strobing red — the
## player sees exactly which beat was blown (the plan's learnability rule). This row exists
## ALONGSIDE the in-bar pips because the overheat that follows a miss instantly flips the bar
## into its drain display, wiping the in-bar pips — the chip is where the evidence survives.
## Live-window duties (the countdown, progressive filling) moved into the bar; this row only
## ever shows the frozen final state. Custom-drawn like OverdriveInstrumentOverlay: two circle
## primitives are cheaper and crisper than textures at this size.
class VentPipRow extends Control:
	## Pip geometry — sized for at-a-glance legibility beside the FONT_HEADLINE chip text
	## (Tim's vision, §1b). Three pips draw 192px wide (2 × spacing + one diameter), narrower
	## than the "VENT MISSED!" headline above them, so the chip's plate is sized by the text
	## and the pips never crowd or overflow it.
	const PIP_RADIUS := 24.0
	const PIP_SPACING := 72.0    # center-to-center
	const PIP_OUTLINE := 5.0
	## Unfinished-pip blink rate — a hard, urgent strobe, clearly a failure.
	const MISS_FLASH_HZ := 6.0

	## Pips draw in the chip's NAVY (matching its border); missed pips strobe KETCHUP_RED (the
	## failure color). Hex literals with palette-name comments, matching the overlay's convention.
	const PIP_COLOR := Color("#1D2D50")         # NAVY
	const MISS_FLASH_COLOR := Color("#B5402A")  # KETCHUP_RED

	var _required := 1
	var _filled := 0
	var _miss_flashing := false
	## Miss-strobe clock in blink cycles (advanced by MISS_FLASH_HZ per second); the integer
	## part's parity picks red vs navy — a square wave, not a sine: an alarm, not a glow.
	var _miss_phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## A window was missed: show the post-mortem — `required` pips, `filled` of them solid,
	## the rest strobing. The host's chip fade calls stop_miss_flash when the chip retires.
	func show_miss(required: int, filled: int) -> void:
		_required = maxi(required, 1)
		_filled = clampi(filled, 0, _required)
		_miss_flashing = true
		_miss_phase = 0.0
		visible = true
		# Reserve the drawn footprint so the chip's containers size the plate around it.
		custom_minimum_size = Vector2(
				PIP_SPACING * float(_required - 1) + PIP_RADIUS * 2.0,
				PIP_RADIUS * 2.0)
		queue_redraw()

	func stop_miss_flash() -> void:
		_miss_flashing = false

	func _process(delta: float) -> void:
		# Only the strobe animates; the row is otherwise static once shown.
		if _miss_flashing and visible:
			_miss_phase += delta * MISS_FLASH_HZ
			queue_redraw()

	func _draw() -> void:
		# Pips, centered horizontally in whatever width the chip's column gave us.
		var row_width := PIP_SPACING * float(_required - 1)
		var first_x := size.x * 0.5 - row_width * 0.5
		for i in range(_required):
			var center := Vector2(first_x + PIP_SPACING * float(i), PIP_RADIUS)
			if i < _filled:
				draw_circle(center, PIP_RADIUS, PIP_COLOR)
			else:
				var ring := PIP_COLOR
				if _miss_flashing and fmod(_miss_phase, 1.0) < 0.5:
					ring = MISS_FLASH_COLOR
				# Radius inset by half the stroke so the ring's OUTER edge matches a filled
				# pip's silhouette — filling a pip must read as "same pip, now solid".
				draw_arc(center, PIP_RADIUS - PIP_OUTLINE * 0.5, 0.0, TAU, 48, ring,
						PIP_OUTLINE, true)
