class_name PropertyRow
extends PanelContainer

# One rung of the property ladder on the Main screen (M1 brief §4): name,
# owned count, live cycle progress, milestone slider, and the buy/hire
# buttons. Pure view: it reads game state every frame and emits a signal
# for every action — all mutations happen in Main → GameState.
#
# Each row has a single buy button; what it buys is set by the global
# buy-mode toggle on the Main screen (×1 / ×10 / ×100 / MAX).

# NEXT_TIER buys exactly enough units to reach the next milestone threshold (replaced
# ×100, Tim 2026-07-07). It keeps ×100's ordinal slot so saved ui_buy_mode ints stay valid.
enum BuyMode { ONE, TEN, NEXT_TIER, MAX }

# The staff-hire equivalent of BuyMode (Plans/Auto_Purchase_And_Bulk_Hire.md §B2). BLOCK buys
# up to the next 20-level staffer-block boundary, which is the meaningful unit on the staff
# ladder: level 1 of a block is the expensive staffer HIRE and levels 2-20 are the cheap steps
# after it, so "finish this block" is what a player actually wants to buy. It is the staff-side
# analogue of BuyMode.NEXT_TIER.
#
# If this enum ever changes, follow the BuyMode lesson above: a retired mode KEEPS its ordinal
# slot, because the player's chosen mode is persisted as a plain int in the save.
# BLOCK (buy to the next 20-level staffer boundary) was REMOVED 2026-08-01 (Tim). Unlike the
# BuyMode case above, this mode was deleted rather than replaced, so there is no successor to
# inherit its ordinal — MAX moves down from 3 to 2 and the enum simply gets shorter. Saves
# written while BLOCK existed are clamped into range on load (GameState.load_save_dict), which
# lands an old BLOCK or MAX on the new MAX. Head Hunters dropped to 2 levels to match, since
# each of its levels unlocks exactly one bulk mode and there are now only two.
## Bulk-hire ladder. All three are free to everyone since the Head Hunters track was deleted
## (2026-08-07). If a mode is ever added here, raise LegacyUpgrades.ALL_HIRE_MODES_UNLOCKED to
## match — core cannot name this enum (it would create a class-resolution cycle), so that constant
## mirrors this one's top ordinal by hand.
enum HireMode { ONE, TEN, MAX }

## WHO asked for this action. Audio is the reason it exists (Plans/Audio_System.md §4.4): a HOLD is
## ONE gesture and must sound like one thing, not like sixty purchases — but until now the codebase
## simply discarded "who initiated this", and the distinguishing state lived only in this file's
## private _buy_hold_repeating.
##
## There is deliberately no AUTO_PURCHASE value: the Acquisitions Desk buys inside AutoPurchaseState,
## in core, and never reaches these signals at all. Auto-buys are silent by construction rather than
## by a check, which is the stronger guarantee.
enum ActionSource {
	PLAYER_TAP,   ## A discrete press.
	HOLD_REPEAT,  ## A repeat pumped out while the button stays held.
}

signal buy_requested(prop_index: int, mode: BuyMode, source: ActionSource)
signal tap_requested(prop_index: int)
signal hold_rush_requested(prop_index: int)
## Fired the moment a rush HOLD that actually auto-rushed ends, so Rush Momentum can stop
## building immediately instead of riding out the pulse-bridging grace window (Tim 2026-07-15:
## the momentum bar kept growing ~a second after release). Quick taps never fire this.
signal rush_hold_released(prop_index: int)
## RAW physical press/release edges on the rush control — the finger itself touching down and
## lifting off, with no engage threshold, no pulse pacing, no tap-vs-hold interpretation.
## These exist for the Overdrive Vent Window gesture reader (Plans/Overdrive_Vent_Windows.md):
## the vent gesture is a precisely timed sequence of lifts and re-presses, so the core needs
## the bare edges. They are ADDITIONAL, lower-level events — hold_rush_requested /
## rush_hold_released above keep their exact shipped behaviour. Main routes these to
## GameState.notify_rush_pressed/notify_rush_released; outside a vent window the core
## ignores them, so they are inert in ordinary play. See _pump_rush_edges.
signal rush_pressed(prop_index: int)
signal rush_released(prop_index: int)
## The staff button was pressed. There is only ONE staff action now — buy the next rung of
## the property's sequential staff ladder (hiring a staffer IS level 1 of each 20-level
## block, GDD §6.1 epoch-depth redesign) — so the button needs no state dispatch.
## Carries the HireMode the row is currently set to, exactly as buy_requested carries the
## BuyMode: the row emits the MODE and Main resolves it to a level count (via this row's
## resolve_hire_count) before spending. The mode sent is the EFFECTIVE one — already clamped
## to what the player's Head Hunters level allows (see _effective_hire_mode).
signal hire_requested(prop_index: int, mode: HireMode, source: ActionSource)

var prop_index: int = -1

var _prop: PropertyState
var _economy: EconomyState
var _frenzy: FrenzyState
## The shared Rush Momentum / heat state (Rush Overheat, Tim 2026-07-15). Read-only here, and now
## only for is_vent_window_open(), which holds the rush presentation up through the vent gesture's
## finger lifts (see _vent_presentation_hold). The "rushing is shut down" LOOK is no longer taken
## from this shared state: an overheat downs only the properties that were being rushed, so the
## row keys that dim off its OWN is_overheat_frozen flag instead (Tim 2026-07-19).
var _rush_momentum: RushMomentumState
## Auto-Purchase Mode, read-only, for one job: while it is RUNNING the core refuses every rush
## (GameState.hold_rush_property), so this row must not present one. Held live rather than pushed
## so the presentation can never lag the refusal by a frame.
var _auto_purchase: AutoPurchaseState
## The generation's reached epoch — the highest staffer tier any property may be hired
## or upgraded to right now. Read live so the hire button unlocks the moment a new
## civilization is contacted (EpochState.current_tier).
var _epoch: EpochState
var _buy_mode: BuyMode = BuyMode.ONE
## The global staff-hire mode, pushed in by Main's hire-mode toggle (set_hire_mode).
var _hire_mode: HireMode = HireMode.ONE
## The highest HireMode the player has unlocked, pushed in by Main (set_max_hire_mode) so the
## row never has to read the dynasty itself. Defaults to ONE — bulk hiring is off until the
## Head Hunters legacy track is bought.
var _max_hire_mode: HireMode = HireMode.ONE

## Accumulates held-down time on the tap button to pace auto-rush pulses.
var _hold_accumulator := 0.0

## Hold-to-repeat pacing (Tim, 2026-06-22), mirroring the Estate shop: a quick tap acts once; holding
## auto-repeats after a short initial delay so the player can watch the cost climb and release when
## they want to stop. The Buy button and the staff (hire/upgrade/level-up) button now have SEPARATE,
## live-tunable pacing (Tim, 2026-07-03): the initial delay and repeat interval for each are read from
## TuningConfig (buy_hold_* / hire_hold_*) so they can be felt out on device via the balance screen.
var _buy_hold_accumulator := 0.0
var _buy_hold_repeating := false
## Whether THIS press-and-hold gesture has already produced a purchase. It decides which purchase
## reports itself as the gesture's first — see _next_buy_source.
var _buy_gesture_acted := false

## Hold-to-repeat state for the STAFF button (Tim, 2026-07-01): holding it keeps hiring/upgrading —
## and then leveling up the staffer — until the player releases, on its own hire_hold_* pacing
## (separate from the buy button's, Tim 2026-07-03).
var _hire_hold_accumulator := 0.0
var _hire_hold_repeating := false
## The hire equivalent of _buy_gesture_acted.
var _hire_gesture_acted := false

# --- Concurrent multi-touch (Tim, 2026-07-02) ------------------------------------------------------
# Godot converts only the FIRST finger of a touch gesture into a mouse event (project setting
# input_devices/pointing/emulate_mouse_from_touch, on by default), and Buttons act on that single
# emulated mouse. So while one finger holds the rush portrait, a second finger on Buy or Hire produces
# NOTHING. To allow concurrent inputs — hold rush while tapping or holding buy/hire — this row also
# reads RAW touch events in _input and drives its three controls from SECONDARY fingers directly.
#
# The FIRST finger of a gesture (the "primary") is left ENTIRELY to the existing Button path, so
# single-touch behaviour is unchanged; only extra fingers are handled here, so there is never a
# double-fire against the emulated mouse. See _input and the _pump_held_* functions.

# The app-wide "secondary fingers allowed" gate lives on SecondaryTapButton.enabled
# (Main sets it every frame) — shared with the buy-mode / TURBO / clock-in buttons so
# every secondary-finger input obeys one rule (Tim, 2026-07-07; was a static here).

## Every finger currently on the screen (by index), primary and secondary alike. Used only to tell
## whether a new touch is the FIRST of a gesture (→ primary, left to the Button path) or an extra
## finger (→ secondary, handled here).
var _active_fingers := {}
## The primary finger's index — the one Godot emulates the mouse from. Tracked so its release is
## recognised, but never acted on here. -1 when no gesture is in progress.
var _primary_finger := -1
## Active SECONDARY fingers → which control each is currently over ("rush" / "buy" / "hire"). A finger
## over none of the three controls is simply absent. The hold pumps read this to tell when a second
## finger is holding a control down.
var _secondary_targets := {}
## The portrait's interactivity as last computed in _refresh, so a secondary tap on it obeys the
## same "rush allowed" rule the ManagerCircle uses (any owned property, staffed or not).
var _portrait_interactive := false

# The cycle progress bar is driven by our own smooth, per-frame prediction rather
# than the raw logic value. Logic ticks at LOGIC_HZ (10 Hz) while rendering runs
# every frame (~60 Hz), so reading cycle_progress directly makes the bar lurch in
# ~10 steps/sec — jumpy and staccato. Instead we advance a displayed fraction at
# real time (delta / cycle_length each frame, the true fill rate) and only re-sync
# to the logic state on the events that prediction can't see: a rush jumping the
# cycle forward, or the cycle completing and restarting. The result is constant-
# velocity motion at the full frame rate.
var _displayed_cycle_fraction := 0.0

## Last frame's true cycle fraction. Cycle progress only ever decreases when a
## cycle completes and restarts, so a drop tells us the cycle wrapped.
var _last_true_cycle_fraction := 0.0

## True while the displayed bar still owes a trip to the right edge for a cycle that
## already completed. The displayed fraction lags the true one (rush catch-up easing,
## 10 Hz logic ticks), so snapping to the new cycle's progress the moment the true value
## wraps reset the bar from mid-fill without ever reaching the right edge — worst under a
## held rush, where the lag is largest and wraps are constant (Tim, 2026-07-06). Instead
## the bar keeps filling to 1.0 first, then wraps and chases the new cycle.
var _finish_lap_pending := false

## While the player holds the rush button, the cycle bar fills in a deeper, more vivid
## green to signal the active push (Tim, 2026-06-23 — was a lighter tint, now darker and
## more saturated so the push reads as "leaning in" rather than washing out).
## HELD_RUSH_DARKEN pulls the green toward black; HELD_RUSH_SATURATE scales its HSV
## saturation (1.0 = unchanged) so the deeper green still reads as green, not gray.
const HELD_RUSH_DARKEN := 0.18
const HELD_RUSH_SATURATE := 1.4

## Time constant (seconds) for the cycle bar to ease up to a rush-jumped target.
## A rush jumps the true progress forward in a discrete step (and held rushes fire
## several times a second); easing toward that target instead of snapping to it
## makes a held rush read as smooth acceleration rather than a stutter of jumps.
const RUSH_CATCHUP_TAU := 0.12

## Once a property's EFFECTIVE cycle is shorter than this (seconds), the cycle bar stops
## animating and is pinned solid-full. Past this speed the bar would refill several times a
## second — a meaningless strobe at 60fps — so we instead show the property as a continuously-
## paying business (genre-standard, Tim 2026-06-25). This is a pure presentation / legibility
## threshold, NOT an economy value, so it lives here in the UI rather than in tuning.tres.
const SOLID_BAR_THRESHOLD_SEC := 0.25

## The same "faster than the eye" rule for a HELD RUSH (Tim, 2026-07-06 — replaced a
## measured completion-cadence rule that stuck and unstuck unpredictably): while rushing,
## the bar counts as solid if the COMPUTED cycle-under-rush time (natural fill plus the
## held-rush pulses) is at or under this. Deliberately more lenient than
## SOLID_BAR_THRESHOLD_SEC — a rushed sub-second lap is a strobe of back-to-back
## finishing-lap sprints, so it pins earlier than a natural cycle would.
## 0.6 → 0.4 (Tim, 2026-07-07): pin less often, keeping visible motion the norm under
## rush; solid is reserved for genuinely strobe-fast laps.
const RUSHED_SOLID_THRESHOLD_SEC := 0.4

## THE COMPLETION PULSE, for cycles too short to animate honestly (Tim, 2026-08-09: "if a property
## has a cycle that is too short, then it never looks like it fills up... you see an instantaneous
## flash of the income bar about a third full, and then nothing").
##
## Photon Exchange with Efficiency Experts at level 10 runs a 0.139 s cycle. Pinned, the bar sprints
## at PIN_FILL_PER_SEC = 3.0 bars/sec, so in 0.139 s it reaches 0.42 — a third of the way — and then
## the cycle ENDS, the pin releases, and the bar snapped back to empty. Every payout looked like a
## failed fill.
##
## So a completed cycle now owns a fixed-length flourish on ITS OWN clock rather than the economy's:
## fill the rest of the way, hold a beat at full, then drop. It runs only where a real payout
## happened, so the bar still never shows a cycle the player did not earn — it just takes long enough
## to be seen. Roughly a quarter of a second all told.
const COMPLETION_FILL_PER_SEC := 5.0
const COMPLETION_HOLD_SEC := 0.12

## How fast the bar fills the rest of the way when it BECOMES pinned (fractions of the
## full bar per second): a quick sprint to the right edge, then hold — snapping straight
## to solid read as sudden (Tim, 2026-07-07). 3.0 = the remaining lap in ⅓s at most.
const PIN_FILL_PER_SEC := 3.0

## ALL rush presentation (color, boosted income readout, excitement, solid pin, sweep
## rate) engages only after the rush has been HELD this long — a mere START/rush tap
## presses the same button for a few frames, which flashed the whole rush look on
## every tap (Tim, 2026-07-08). A real hold reaches this within its first pulse; a
## tap never does. The pump itself is NOT gated: pulses land from the first interval.
const RUSH_ENGAGE_SEC := 0.3

## The displayed bar's sweep rate eases toward its target (natural or rushed) with
## this time constant, so engaging/releasing a rush ACCELERATES the sweep instead of
## snapping it — a fill-speed snap stretches the bubble field and reads as a frenzy
## sprint at the hold's edges (Tim, 2026-07-08: the frenzy must be constant).
const SWEEP_EASE_TAU := 0.3

## The catch-up may move the bar at most this multiple of the CURRENT sweep rate.
## 1.0 — NO headroom (autopilot data, 2026-07-08: even 1.15 made the engage window
## run measurably 15% hotter than the sustained sweep for its first two seconds).
## Phase re-syncs at the wraps instead, where the metronome wrap below absorbs any
## displayed-vs-true drift for free.
const CATCHUP_RATE_HEADROOM := 1.0

## A pinned-solid bar's commanded liquid flow (px/s), fed to its GoldBubbles overlay.
## Deliberately brisk: solid means "cycling faster than the eye", so the MOST active
## property should carry the most active fizz — not sink to the idle drift a motionless
## fill edge would otherwise measure (Tim, 2026-07-06). Holding rush multiplies it, so
## rushing a solid bar has a visible effect beyond the color swap. These two are the
## TOP rungs of the carbonation speed ladder: every measured (non-solid) bar is capped
## below them by GoldBubbles.MEASURED_FLOW_CAP_PX.
const SOLID_FLOW_PX := 110.0
const SOLID_FLOW_RUSH_MULT := 1.6

## The cycle bar's fill while the property is OVERHEAT-FROZEN (Plans/Overdrive_Vent_Windows.md,
## Tim 2026-07-19): the same dark "dead machine" slate the momentum bar's lockout drain reveals,
## so the two instruments tell one story — this bar going dead-slate and the momentum bar's
## dead-slate re-arm countdown are the same shutdown. MUST match MomentumBar's LOCKOUT_GRAY
## (#45464C); that const lives inside MomentumBar's private instrument class, so the value is
## duplicated here rather than reached into.
const FROZEN_SLATE := Color("#45464C")

## The frozen row's explanatory banner (Tim, 2026-07-20 device verdict): a dark row stated the
## fact without explaining it, so an "OVERHEATED" plate plus a countdown now sits over the cycle
## band. The COUNTDOWN is the point — a wait you can see the end of is a bounded wait; an
## unexplained dark row is an open-ended one. Its plate is the same dead slate the frozen bar
## wears, so the row's look is unchanged apart from finally carrying words.
const FROZEN_BANNER_TEXT := "OVERHEATED"
## Cream on slate is the project's highest-contrast pairing and matches the row's other
## light-on-dark text; the countdown rides the same line so there is one thing to read.
const FROZEN_BANNER_FONT_SIZE := UiPalette.FONT_SUBHEAD

## Whether the bar was pinned solid last frame — unpinning restarts the visible lap.
var _was_pinned := false

## Seconds the rush has been continuously held (0 when not held) — gates the whole
## rush presentation past RUSH_ENGAGE_SEC so taps don't flash it. FROZEN (not reset) while a
## vent window holds the presentation through the gesture's finger lifts — see _refresh.
var _rush_hold_seconds := 0.0
## The rush control's raw held state last frame (primary Button OR secondary finger), so
## _pump_rush_edges can emit rush_pressed/rush_released exactly on the transitions.
var _rush_button_was_down := false
## True once the current rush hold has fired at least one auto-rush pulse; drives the
## rush_hold_released signal on release (see _pump_held_rush).
var _rush_hold_pulsed := false

## Whether the property's cycle was running LAST frame. The running → stopped edge is what starts
## the completion pulse: it fires exactly when an unstaffed cycle has paid out and halted.
var _was_cycle_running := false
## Seconds left of the pulse's hold-at-full, once the fill has arrived there.
var _completion_hold_remaining := 0.0

## The displayed bar's eased sweep rate (bars/sec) — see SWEEP_EASE_TAU.
var _sweep_rate := 0.0

## The per-second rate this row's income label currently shows (rush-boosted while rush
## is held; 0 for an unowned row's buy-in preview). Cached each _refresh; Main sums it
## across rows for the hero panel's income headline (Tim, 2026-07-07).
var _displayed_income_per_sec := 0.0


## The per-second income rate currently displayed on this row (see above).
func get_displayed_income_per_sec() -> float:
	return _displayed_income_per_sec

## The portrait/rush button is a square sized to a fraction of the panel's full height, centered
## vertically (Tim, 2026-07-02): at 1.0 it filled the whole row; 0.9 trims it 10% so it no longer
## dominates the panel while staying a comfortably large tap target.
const PORTRAIT_HEIGHT_FRACTION := 0.9

## Once the EFFECTIVE cycle is shorter than this (seconds), the income readout over the bar switches
## from a per-cycle figure tagged with its length ("$X/4.3m" = $X every 4.3 minutes; see
## _format_cycle_duration) to a per-second rate ("$X/s") — a sub-second cycle reads more naturally as
## a rate than as "per 0.4 seconds" (Tim, 2026-07-01/02).
const PER_SECOND_READOUT_THRESHOLD_SEC := 1.0
## Which cycle-bar fill look is currently applied, so we only rebuild the stylebox on a
## change, not every frame (the same approach FrenzyBar uses for its burn-color swap):
##   0 = normal green (idle/running, rush available)
##   1 = brighter green (rush button held)
##   2 = calm blue (staffed and running itself — rush is no longer an option)
##   3 = dead slate (overheat-frozen — the machine is down; see FROZEN_SLATE)
## -1 = not yet applied.
var _cycle_color_applied := -1

# Both action buttons lay their two pieces of text out the same way: a left-aligned
# label and a right-aligned label sharing one vertically-centered row (Tim 2026-06-17).
# The buy button shows "BUY ×N" on the left and the cost on the right; the hire button
# shows the verb/staffer on the left and the cost/tier on the right. The font is sized
# to fill this fixed row height — see _add_split_button_labels.
## Raised 80 → 92 in the taller-panel pass (Tim, 2026-07-05) — the panel's height follows
## its rows, so growing the two row constants grows the whole panel (and the portrait
## disc with it, via PORTRAIT_HEIGHT_FRACTION).
const BUTTON_ROW_HEIGHT := 92
## Buy/hire button label size. 30 → 38 in the all-panel-text pass, +20% to 46, then
## −20% back down to 37 after the on-device look (Tim, 2026-07-05).
const BUTTON_LABEL_FONT_SIZE := 37

## The hire button's COUNT caption ("×10") — see _refresh_hire_button. One tier below the cost
## beside it (FONT_BUTTON = 34 vs 37): the price is the number the player is deciding on and the
## count is its qualifier, and the hire button is the narrower of the two action buttons, so the
## smaller of two legible sizes is what buys the count room to be spelled out in full rather than
## ellipsized. Still well above UiPalette.FONT_SMALL, the readability floor.
const HIRE_COUNT_FONT_SIZE := UiPalette.FONT_BUTTON

## Property-row readability pass (Tim, 2026-07-01): the row is taller and its labels bigger.
## The property NAME reads in bold on the top line at this size — FONT_SUBHEAD (41) + 25%
## from the all-panel-text-larger pass (Tim, 2026-07-05).
const NAME_FONT_SIZE := 51
## Shared height of the second row's two elements — the cycle progress bar and the outlined
## "owned / next-threshold" count chip — kept equal so they read as one aligned band.
## Raised 52 → 60 (2026-07-05 taller-panel pass), then +50% → 90 (Tim, same day), then
## trimmed 90 → 70 (Tim, 2026-07-23) to condense each property panel: at the unchanged
## 41px band font (~49px line height) the old 90 left ~40px of dead vertical air, so the
## band shortens without crowding the text or squashing the progress bar. Shrinking this
## also shrinks the whole panel and the portrait disc with it (see the row-constants note
## above), which is the point — a more compact rung.
const SECOND_ROW_HEIGHT := 70
## Font for the count-panel text and the per-cycle income readout above the bar.
## FONT_BODY (32) → 41 with the 50%-taller band, +25% to 51 in the all-panel-text pass,
## then −20% back to 41 for this band specifically (Tim, 2026-07-05).
const SECOND_ROW_FONT_SIZE := 41

## --- The auto-purchase marker (Tim, 2026-08-01) ------------------------------------------------
## Auto-Purchase Mode buys silently on a cadence — as fast as about once a second — and Tim's
## question was simply "where did my money go?". A flash on a hero stat was rejected as a strobe,
## so the answer is marked on the ROWS the desk actually bought into: the count chip (the readout
## of the very number that just went up) washes green for a moment.
##
## Deliberately QUIETER than anything a manual purchase does. A manual buy flashes the hero stat
## at the top of the screen; this stays inside one chip on one row, tops out well below opaque,
## sits BEHIND the count text so it never touches its legibility, and is gone in half a second.
## At the desk's fastest cadence it reads as a slow blink on whichever rows are being fed.
const AUTO_PURCHASE_MARKER_SECONDS := 0.5
## Peak alpha of that wash. Low on purpose: enough to catch the eye in peripheral vision, not
## enough to repaint the chip.
const AUTO_PURCHASE_MARKER_PEAK_ALPHA := 0.32

## Small inline icons that replace the leading "$" on money figures and mark the buy count
## (Tim, 2026-07-09). A dollar-bill sits just before every amount; a property-tab icon sits
## before the buy button's "+N" count. Each is sized to roughly its neighboring text's cap
## height and mouse-ignored so taps still reach the control underneath.
## Each loads the IMPORTED texture (see _crisp_icon_texture) — the raw .svg source is NOT in
## the export, so it must not be read at runtime.
const DOLLAR_ICON_SVG := "res://art/icons/dollar_bill.svg"
const PROPERTY_ICON_SVG := "res://art/icons/tab_property_inactive.svg"
## The Family Ledger book, reused here as the FLAGSHIP badge (see _flagship_icon). It is the same
## art the Family Ledger tab uses, and it is already imported at svg/scale=4 (≈324px native), so
## it downscales into the badge cleanly instead of blocking up the way a scale-1 import would.
const LEDGER_ICON_SVG := "res://art/icons/tab_ledger_inactive.svg"

## The hire button's headshot icon and the buy button's factory (property-tab) icon are sized
## so their VISIBLE (opaque) art is the SAME height: 50.6px, the average of their former
## on-screen heights — the headshot showed ~55.5px, the factory ~45.6px (Tim, 2026-07-10).
## Each icon's art sits in a square canvas with its own transparent padding, so the BOX needed
## to reach this visible height differs per icon and is derived from that icon's opaque
## fraction at each use (headshot: art fills 86/96 of its box; factory: 279/324).
const MATCHED_ICON_VISIBLE_HEIGHT := 50.6

## The flagship badge's box, in pixels. The ledger art fills only the middle ~33/48 of its square
## canvas, so a 76px box draws a ~52px-tall book — about the height of the NAME line it sits
## beside, which is what makes it readable at arm's length.
const FLAGSHIP_ICON_BOX := 76
## How far the badge is INSET from the name line's top-right corner. It used to be NUDGED OUT
## instead (8px right, 4px up), which pushed it into the panel's 12px content margin and left the
## book only ~4px shy of the heavy border — Tim, 2026-07-31: "give the badge a little more space
## from the edge."
##
## The RIGHT edge is where the crowding actually was, so that is where the correction goes: the
## badge now sits 6px INSIDE the content edge instead of 8px outside it, an 18px move inward.
## Vertically it is merely un-nudged to flush (0) rather than pushed down: the ledger art already
## carries ~12px of transparent padding above it inside the box, and the box is taller than the
## name line, so driving it further down would run the book into the cycle-bar band below — which
## would be a crowding problem traded for a worse one.
##
## These only move PAINT: the badge is anchored, not laid out, so nothing on the row shifts.
const FLAGSHIP_ICON_INSET_RIGHT := 6
const FLAGSHIP_ICON_INSET_TOP := 0
## Air between the end of a clipped property name and the badge's box, so text never touches art.
const FLAGSHIP_NAME_CLEARANCE := 8

## Imported icon textures, loaded once and keyed by source path. Shared across every row
## (all rows draw the same two icons), loaded lazily on first use.
static var _crisp_icon_cache := {}

## True when this rung is its epoch cohort's FLAGSHIP — the property whose 35th unit advances the
## epoch, and the one auto-purchase never buys. Fixed for the life of the row (flagship-ness is a
## property of the config: the cohort's highest base_cost), so Main sets it once at row setup.
var _is_flagship := false
## The Family Ledger badge in the row's top-right corner, shown only on the flagship. An overlay
## anchored inside the name label — see the note where it is built.
var _flagship_icon: TextureRect

var _manager_circle: ManagerCircle
var _name_label: Label
## The "owned / next-milestone-threshold" readout, inside its own gray-outlined chip (Tim, 2026-07-01).
var _count_label: Label
## The green wash inside that chip, shown for half a second after Auto-Purchase Mode buys into THIS
## property (see flash_auto_purchased). An overlay inside the chip, drawn under the count text.
var _auto_purchase_marker: ColorRect
## Seconds of that wash still owed. Driven by a plain countdown in _refresh — NOT a Tween and NOT a
## Timer, precisely because this fires forever at up to ~1/sec (see flash_auto_purchased).
var _auto_purchase_marker_seconds := 0.0
var _income_label: Label
## Dollar-bill icon drawn just left of the income readout, in place of its leading "$".
var _income_icon: TextureRect
var _cycle_bar: ProgressBar
var _cycle_bubbles: GoldBubbles
## Fast PURPLE streaks shown ONLY while THIS property is being rushed at max Rush Momentum —
## tiny dots flying in a straight line, contrasting the swaying gold carbonation (Tim, 2026-07-14;
## recolored purple 2026-07-26 to read distinct from the red frenzy-burn fill).
var _cycle_momentum_streaks: MomentumStreaks
## Diagnosis readout over the bar, shown when tuning.carb_debug_overlay = 1.
var _carb_debug_label: Label
## The "OVERHEATED + countdown" plate shown only while THIS property is overheat-frozen. It is an
## OVERLAY on the cycle band the row already occupies — nothing is resized or re-laid-out when it
## appears, so a finger resting on the row (or a scroll in progress) is never disturbed.
var _frozen_banner: PanelContainer
var _frozen_banner_label: Label
## The whole-seconds figure the banner last showed, kept so the countdown can only ever go DOWN
## within one freeze. The two halves of the lockout are measured differently (see
## _overheat_seconds_remaining), and a readout that ticked back UP at the handoff would look broken.
## INT_MAX-ish sentinel = "no freeze in progress"; reset every time the row thaws.
var _frozen_seconds_shown: int = 1 << 30
var _buy_button: Button
var _buy_caption_label: Label
## Property-tab icon before the buy button's "+N" count.
var _buy_count_icon: TextureRect
var _buy_cost_label: Label
## Dollar-bill icon before the buy button's cost (hidden when there is no cost to show).
var _buy_cost_icon: TextureRect
var _hire_button: Button
## The hire button's count caption — "×10", the staff levels THIS press will buy (see
## _refresh_hire_button). It is the left half of the button's split labels, the same slot the
## buy button spells "+10" in.
var _hire_count_label: Label
var _hire_cost_label: Label
## Dollar-bill icon before the hire button's cost (hidden while the button shows "MAX").
var _hire_cost_icon: TextureRect
## The hire button's hand-drawn "add staff" symbol: headshot + "+" (see StaffHireGlyph).
var _hire_glyph: StaffHireGlyph

## Which hire-button look is currently applied, so the stylebox is only rebuilt when
## the state flips, not every frame. -1 = not yet applied, 0 = action (HIRE/UPGRADE,
## normal mustard), 1 = fully-staffed-for-now (faint green, disabled).
var _hire_style_applied := -1

## Tracks which ownership look is currently applied so the panel/start-button
## styleboxes are only rebuilt when ownership flips, not every frame.
## -1 = not yet applied, 0 = owned (normal), 1 = unowned (gray).
var _ownership_style_applied := -1


## Call before adding to the tree.
func setup(p_index: int, prop: PropertyState, economy: EconomyState, frenzy: FrenzyState,
		epoch: EpochState, rush_momentum: RushMomentumState,
		auto_purchase: AutoPurchaseState) -> void:
	prop_index = p_index
	_prop = prop
	_economy = economy
	_frenzy = frenzy
	_epoch = epoch
	_rush_momentum = rush_momentum
	# Held read-only, exactly like rush_momentum: the row reads the live flag each frame rather
	# than having a copy pushed at it, so it can never present a rush the core is refusing.
	_auto_purchase = auto_purchase


## Accessors so a tutorial coach card can anchor to a SPECIFIC control on this row (its buy button,
## its hire button, or the portrait/rush control) instead of the whole row — so the pointer arrow
## and highlight land on the exact thing the tip is directing the player to press.
func get_buy_button() -> Button:
	return _buy_button


func get_hire_button() -> Button:
	return _hire_button


func get_rush_control() -> Control:
	return _manager_circle


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPalette.make_panel_style())

	# The portrait/rush control sits on the LEFT as a single tall square spanning the WHOLE
	# panel height (Tim, 2026-07-01): on device the old section-height circle was a hard tap
	# target, so it now runs the full height of the row for a big, easy-to-hit button. To its
	# right, a column holds the stacked rows — the bold NAME, then the "owned / threshold" count
	# chip beside the income-over-progress-bar band, then the buy/hire buttons. The circle's
	# square size is set in _refresh to match its own height.
	var outer_row := HBoxContainer.new()
	outer_row.add_theme_constant_override("separation", 12)
	add_child(outer_row)

	_manager_circle = ManagerCircle.new()
	_manager_circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # sized in _refresh, centered
	# The portrait IS the start/rush control now (the old START button is gone): a single tap
	# starts an idle cycle (or rushes a running one); holding it auto-rushes (see _pump_held_rush).
	_manager_circle.pressed.connect(func() -> void: tap_requested.emit(prop_index))
	outer_row.add_child(_manager_circle)

	# The stacked rows to the right of the tall portrait.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_row.add_child(column)

	# Row 1 — the property name, in bold.
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip a long name rather than letting it force the whole row wider than the panel — otherwise a
	# long name sets the row's MINIMUM width and, paired with the tall (so wide) portrait, pushes the
	# panel off the right edge of the screen (Tim, 2026-07-01). Clipping lets the row shrink to fit.
	_name_label.clip_text = true
	column.add_child(_name_label)

	# Row 2 — the live cycle progress bar on the LEFT (with the per-cycle income drawn ON
	# TOP of it, bold black), and the outlined "owned / next-threshold" count chip on the
	# RIGHT — sitting directly above the buy button, since the count is exactly what that
	# button grows (Tim, 2026-07-05; mirrors the staff column, where the portrait's level
	# sits above the hire button). The chip and the bar share a height so they read as
	# one line.
	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 10)
	column.add_child(second_row)

	# The bar cell fills the row's leftover width and holds the progress bar with the income drawn
	# over it. A plain Control host (rather than parenting the income to the bar) keeps the income
	# overlay visible even on an unowned "peek" row, where the bar itself is hidden — no cycle to
	# run — but the single-unit income preview should still show.
	var bar_cell := Control.new()
	bar_cell.custom_minimum_size = Vector2(0, SECOND_ROW_HEIGHT)
	bar_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_cell.size_flags_vertical = Control.SIZE_SHRINK_END
	second_row.add_child(bar_cell)

	# The count chip: a gray-outlined plate wrapping the "owned / threshold" readout. Transparent
	# fill so only the outline shows, whatever the row's ownership background is. It takes only its
	# own width (SHRINK_END pins it right) and bottom-aligns so it sits level with the progress bar.
	var count_chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color.TRANSPARENT
	chip_style.border_color = UiPalette.MID_GRAY
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(4)
	# Side padding widened 16 → 26 so the chip reads a little roomier (Tim, 2026-07-05).
	chip_style.set_content_margin(SIDE_LEFT, 26)
	chip_style.set_content_margin(SIDE_RIGHT, 26)
	count_chip.add_theme_stylebox_override("panel", chip_style)
	count_chip.custom_minimum_size = Vector2(0, SECOND_ROW_HEIGHT)
	count_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_chip.size_flags_vertical = Control.SIZE_SHRINK_END
	second_row.add_child(count_chip)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", UiPalette.NAVY)
	_count_label.add_theme_font_size_override("font_size", SECOND_ROW_FONT_SIZE)
	# Every text on the panel reads bold (Tim, 2026-07-05).
	_count_label.add_theme_font_override("font", UiPalette.make_bold_font())
	count_chip.add_child(_count_label)

	# The auto-purchase marker: a flat green wash filling the chip's inner area. Like the OVERHEATED
	# plate and the flagship badge, it costs the layout NOTHING — a ColorRect's minimum size is zero,
	# so the chip (and therefore the row) is exactly the same size whether it is showing or not.
	# Moved to index 0 so it draws over the chip's plate but UNDER the count text, which keeps the
	# numbers at full contrast while the wash is up.
	_auto_purchase_marker = ColorRect.new()
	_auto_purchase_marker.color = Color(UiPalette.MONEY_GREEN, 0.0)
	_auto_purchase_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_purchase_marker.visible = false
	count_chip.add_child(_auto_purchase_marker)
	count_chip.move_child(_auto_purchase_marker, 0)

	# Cycle progress bar (Style Guide §9: the "spin" is the real cycle progress), filling the cell.
	_cycle_bar = ProgressBar.new()
	_cycle_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cycle_bar.min_value = 0.0
	_cycle_bar.max_value = 1.0
	_cycle_bar.show_percentage = false
	UiPalette.style_progress_bar(_cycle_bar, UiPalette.MONEY_GREEN)
	# Gold bubbles drifting through the fill — every progress bar carries them (Tim, 2026-07-03).
	# Kept as a member: the refresh commands their flow speed while the bar is pinned solid.
	_cycle_bubbles = GoldBubbles.new()
	_cycle_bar.add_child(_cycle_bubbles)

	# Fast PURPLE streaks over the gold, hidden until this property is rushed at max Rush Momentum
	# (see _process). They fly straight and fast to contrast the swaying gold carbonation — purple
	# so the cruise-control rush reads distinct from the RED frenzy-burn fill (Tim, 2026-07-26).
	_cycle_momentum_streaks = MomentumStreaks.new()
	_cycle_momentum_streaks.color = UiPalette.BRIGHT_PURPLE
	_cycle_momentum_streaks.visible = false
	_cycle_bar.add_child(_cycle_momentum_streaks)

	# Tiny diagnosis readout over the bar (tuning.carb_debug_overlay = 1 in Balance
	# Tuning): the live numbers driving the carbonation, so an on-device eye report can
	# be matched to WHICH parameter actually moved (Tim, 2026-07-08 — the frenzy edge
	# burst survived several model-based fixes; this ends the guessing).
	_carb_debug_label = Label.new()
	_carb_debug_label.add_theme_font_size_override("font_size", 22)
	# White with a navy outline so it reads on ANY fill color — the first pass was
	# plain black at the bar's top-left, exactly where the income label already draws.
	_carb_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_carb_debug_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	_carb_debug_label.add_theme_constant_override("outline_size", 6)
	_carb_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Pinned along the bar's TOP-RIGHT, clear of the left-aligned income readout.
	_carb_debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_carb_debug_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_carb_debug_label.position.y = 2
	_carb_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carb_debug_label.visible = false
	_cycle_bar.add_child(_carb_debug_label)
	bar_cell.add_child(_cycle_bar)

	# Per-cycle income: bold BLACK, LEFT-aligned, drawn ON TOP of the bar and vertically centered
	# in it (Tim, 2026-07-01; flipped left 2026-07-05 when the count chip moved to the row's right
	# — right-aligned it would butt against the chip and the two number groups would read as one
	# jumble). A cream outline (the project's faux-weight trick) keeps it legible over both the
	# green fill and the gray track. Inset a little from the cell's edges; ignores the mouse so a
	# tap on the bar area is never eaten by the label.
	# A small dollar-bill icon stands in for the leading "$" on the amount (Tim, 2026-07-09),
	# pinned to the bar's left edge and vertically centered like the income text. The label
	# starts just to its right (offset_left below leaves room for the icon box + a small gap).
	_income_icon = _make_inline_icon(DOLLAR_ICON_SVG, SECOND_ROW_FONT_SIZE)
	_income_icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)  # left edge, full height, vertically centered
	_income_icon.offset_left = 12
	# LEFT_WIDE stretches to the cell's full height; keep it icon-sized so the aspect fit centers it.
	_income_icon.offset_right = 12 + _income_icon.custom_minimum_size.x
	bar_cell.add_child(_income_icon)

	_income_label = Label.new()
	_income_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Start the text just past the dollar-bill icon (its left inset + width + a 4px gap).
	_income_label.offset_left = _income_icon.offset_right + 4
	_income_label.offset_right = -12
	_income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_income_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income_label.add_theme_font_size_override("font_size", SECOND_ROW_FONT_SIZE)
	_income_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_income_label.add_theme_color_override("font_color", Color.BLACK)
	_income_label.add_theme_color_override("font_outline_color", UiPalette.CREAM)
	_income_label.add_theme_constant_override("outline_size", 4)
	bar_cell.add_child(_income_label)

	# The overheat-freeze banner, added LAST inside the bar cell so it draws OVER the cycle bar
	# and the income readout (see FROZEN_BANNER_TEXT). It is anchored to the cell's full rect, so
	# it borrows space the row already occupies rather than adding any of its own — the row's
	# height and every control's position are identical frozen or not (no-moving-UI rule). It also
	# ignores the mouse, so the swipe-to-scroll pass-through and any finger already on the row keep
	# working exactly as before.
	_frozen_banner = PanelContainer.new()
	_frozen_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frozen_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frozen_banner.visible = false
	var frozen_plate := StyleBoxFlat.new()
	frozen_plate.bg_color = FROZEN_SLATE
	frozen_plate.set_corner_radius_all(4)
	_frozen_banner.add_theme_stylebox_override("panel", frozen_plate)
	bar_cell.add_child(_frozen_banner)

	_frozen_banner_label = Label.new()
	_frozen_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frozen_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frozen_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frozen_banner_label.add_theme_font_size_override("font_size", FROZEN_BANNER_FONT_SIZE)
	_frozen_banner_label.add_theme_font_override("font", UiPalette.make_bold_font())
	_frozen_banner_label.add_theme_color_override("font_color", UiPalette.CREAM)
	# A navy outline keeps the word legible even where the plate is overdrawn by the streaks or a
	# future effect — the same faux-weight trick the income readout uses in reverse.
	_frozen_banner_label.add_theme_color_override("font_outline_color", UiPalette.INK_NAVY)
	_frozen_banner_label.add_theme_constant_override("outline_size", 4)
	_frozen_banner.add_child(_frozen_banner_label)

	# Buy / hire buttons (bulk-buy is mandatory — GDD §3.1). The buy button's
	# count follows the global buy-mode toggle.
	var button_line := HBoxContainer.new()
	button_line.add_theme_constant_override("separation", 8)
	column.add_child(button_line)

	# The HIRE button sits FIRST — next to the staff portrait — so everything staff-related
	# groups on the row's left side (Tim, 2026-07-05: portrait shows who + their level, the
	# button beside it grows them). It reads as a pure action: the headshot icon, a plus
	# sign, and the next rung's price — the level readout itself lives in the portrait now.
	_hire_button = Button.new()
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# EQUAL width with the buy button (Tim, 2026-08-01). It used to be 0.85 : 1.0 — a 46/54 split
	# in BUY's favour, "whose 'BUY ×N' + cost labels are the longer text" (2026-07-05). That reason
	# has since expired twice over: BUY's caption was shortened to a bare "+N", and HIRE now carries
	# a count caption of its own, so the two buttons hold the same three things (icon, count, cost).
	# The measured effect at the shipped 1080-wide layout: HIRE 328 → ~358px, BUY 387 → ~358px,
	# which is what gives the new count room to print in full beside the price on ordinary rows.
	_hire_button.size_flags_stretch_ratio = 1.0
	_hire_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_hire_button, false)
	# Connected ONCE here (a per-refresh reconnect would stack handlers and double-fire).
	_hire_button.pressed.connect(_on_hire_pressed)
	var hire_labels := _add_split_button_labels(_hire_button)
	# The LEFT caption is back (Tim, 2026-08-01). From 2026-07-05 it was queue_free'd, because the
	# headshot+plus glyph below was the button's whole caption and the hire count was implied by the
	# global HIRE toggle at the top of the screen. It now carries that count per row — "×10" — so a
	# row states what ITS button will buy. Reusing this label (rather than adding another) keeps the
	# hire button laid out exactly like the buy button: same slot, same clip_text yield rule.
	_hire_count_label = hire_labels[0]
	_hire_count_label.add_theme_font_size_override("font_size", HIRE_COUNT_FONT_SIZE)
	_hire_cost_label = hire_labels[1]

	# The "add staff" glyph — headshot + "+" — is DRAWN, not composed from nodes: a
	# Label's line box carries dead ascent above the "+" glyph and the headshot SVG
	# carries transparent padding, so container layout could neither top-align the pair
	# nor pull them close (Tim, 2026-07-05). See StaffHireGlyph at the end of this file.
	_hire_glyph = StaffHireGlyph.new()
	# The glyph takes only its own drawn width now; the count caption beside it is the piece that
	# expands and pushes the cost to the right edge (it did that job while it was the only thing on
	# the button's left). Keeping the glyph at its natural width is what puts the "×10" directly
	# against it, so the pair reads as one caption: "+[staffer] ×10".
	_hire_glyph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hire_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hire_row := _hire_cost_label.get_parent() as HBoxContainer
	hire_row.add_child(_hire_glyph)
	hire_row.move_child(_hire_glyph, 0)  # glyph, then the count caption, then the cost label
	# A dollar-bill icon just before the hire cost, standing in for its "$" (Tim, 2026-07-09).
	# Hidden in _refresh_hire_button while the button shows "MAX" (no cost).
	_hire_cost_icon = _make_inline_icon(DOLLAR_ICON_SVG, BUTTON_LABEL_FONT_SIZE)
	hire_row.add_child(_hire_cost_icon)
	hire_row.move_child(_hire_cost_icon, hire_row.get_child_count() - 2)  # icon, then cost label last
	button_line.add_child(_hire_button)

	_buy_button = Button.new()
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.custom_minimum_size = Vector2(0, BUTTON_ROW_HEIGHT)
	UiPalette.style_button(_buy_button, true)  # red: buying is a spend action (§8)
	_buy_button.pressed.connect(func() -> void:
		buy_requested.emit(prop_index, _buy_mode, _next_buy_source()))
	var buy_labels := _add_split_button_labels(_buy_button)
	_buy_caption_label = buy_labels[0]
	_buy_cost_label = buy_labels[1]
	# Inline icons on the buy button (Tim, 2026-07-09): a property-tab icon before the "+N"
	# count on the left, and a dollar-bill icon before the cost on the right (its "$").
	var buy_row := _buy_caption_label.get_parent() as HBoxContainer
	# The property-tab count icon is sized to match the hire button's headshot icon: both show
	# the same visible art height (Tim, 2026-07-10). The factory art fills 279/324 of its square
	# canvas, so scale the target height up by that inverse to get the box it needs.
	var factory_box := roundi(MATCHED_ICON_VISIBLE_HEIGHT * 324.0 / 279.0)
	_buy_count_icon = _make_inline_icon(PROPERTY_ICON_SVG, factory_box, true)
	buy_row.add_child(_buy_count_icon)
	buy_row.move_child(_buy_count_icon, 0)  # the tab icon leads, then the "+N" caption
	_buy_cost_icon = _make_inline_icon(DOLLAR_ICON_SVG, BUTTON_LABEL_FONT_SIZE)
	buy_row.add_child(_buy_cost_icon)
	buy_row.move_child(_buy_cost_icon, buy_row.get_child_count() - 2)  # dollar icon, then cost label last
	button_line.add_child(_buy_button)

	# Let a swipe that lands anywhere on the row (the panel, labels, or progress
	# bars — anything that isn't one of the buttons above) scroll the ladder,
	# rather than being swallowed by the row. See UiPalette.allow_scroll_drag_through.
	UiPalette.allow_scroll_drag_through(self)

	# The FLAGSHIP badge — the Family Ledger book in the row's top-right corner, shown only on the
	# rung that advances the epoch. Like the OVERHEATED plate above, it is an OVERLAY: it borrows
	# space the row already occupies and costs the layout nothing, so a flagship row is EXACTLY the
	# same size, with every control in exactly the same place, as any other row (no-moving-UI rule).
	#
	# It is parented to the NAME LABEL rather than to this PanelContainer on purpose. A
	# PanelContainer is a Container: it re-lays-out its direct children and would stretch the badge
	# across the whole panel, ignoring its anchors. A Label is not a container, so a Control child
	# of it keeps its own anchors — and the name label already spans the row's full content width on
	# the top line, which makes its top-right corner the panel's top-right corner.
	#
	# Added LAST so it draws over everything, and mouse-ignored (re-asserted AFTER
	# allow_scroll_drag_through, which would otherwise flip it to PASS) so it can never intercept a
	# tap or a scroll drag.
	_flagship_icon = _make_inline_icon(LEDGER_ICON_SVG, FLAGSHIP_ICON_BOX, true)
	_flagship_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_flagship_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Offsets are measured from the TOP_RIGHT anchor, so a positive inset pulls the box left/down —
	# i.e. inward from the label's corner, which is the panel's content corner.
	_flagship_icon.offset_right = -FLAGSHIP_ICON_INSET_RIGHT
	_flagship_icon.offset_left = _flagship_icon.offset_right - FLAGSHIP_ICON_BOX
	_flagship_icon.offset_top = FLAGSHIP_ICON_INSET_TOP
	_flagship_icon.offset_bottom = _flagship_icon.offset_top + FLAGSHIP_ICON_BOX
	# The source art is already solid NAVY (#1D2D50) — the same navy as the flagship plate's heavy
	# border — so it is drawn untinted (modulate stays white). Tinting it gold was the alternative,
	# but gold-on-gold-warmed-cream is a low-contrast pairing, and this badge has to be legible for
	# a low-vision player; navy on the warm plate is the strongest reading of the two.
	_flagship_icon.modulate = Color.WHITE
	_flagship_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flagship_icon.visible = _is_flagship
	_name_label.add_child(_flagship_icon)
	# Main sets flagship-ness BEFORE _ready, when there was no label to inset yet — so apply it
	# here too, now that both exist. (set_flagship handles the after-_ready case.)
	_apply_flagship_name_inset(_is_flagship)


## Mark this rung as its epoch cohort's FLAGSHIP (or not). Main calls this ONCE per row at setup:
## which property is the flagship is fixed by config (the cohort's highest base_cost), so this is
## never re-evaluated per frame.
##
## Safe to call before OR after _ready: the badge is only touched once it exists, and the plate is
## rebuilt on the next refresh.
func set_flagship(value: bool) -> void:
	if _is_flagship == value:
		return
	_is_flagship = value
	if _flagship_icon != null:
		_flagship_icon.visible = value
	if _name_label != null:
		_apply_flagship_name_inset(value)
	# CACHE INVALIDATION: _apply_ownership_styling early-returns when the look it wants is already
	# the one applied, and it keys only off owned/frozen — it has no idea flagship-ness changed. A
	# row told it is the flagship AFTER its plain plate was applied would therefore keep that plate
	# forever. Clearing the sentinel forces the next refresh to rebuild the stylebox.
	_ownership_style_applied = -1
	# Re-apply right away when the row is already built (is_node_ready() is false while Main is
	# still configuring a freshly constructed row — its labels don't exist yet, and _ready will
	# pick the right plate on the first refresh anyway).
	if is_node_ready() and _prop != null:
		_apply_ownership_styling(_prop.units_owned > 0, _prop.is_overheat_frozen)


## Keep a long property name from running underneath the flagship badge.
##
## The name Label spans the full content width and clips at the PANEL edge, not at the badge,
## so on a flagship row the longest names (28 characters, e.g. "Pheromone Broadcasting Guild")
## would slide under the ledger icon and become unreadable — unacceptable for a low-vision
## player, and the badge is on the marquee property precisely so it gets read.
##
## The fix is a right-side CONTENT margin on the Label itself, not a layout change. A Label's
## "normal" stylebox insets where its text is drawn INSIDE its own rect; the Label's size, the
## column's layout, and every sibling control stay exactly where they were. So the text simply
## clips earlier on flagship rows and nothing moves — the no-moving-UI rule is preserved.
func _apply_flagship_name_inset(flagship: bool) -> void:
	if not flagship:
		_name_label.remove_theme_stylebox_override("normal")
		return
	var inset := StyleBoxEmpty.new()
	# Reserve exactly the width the badge actually occupies over the label, plus a little air.
	# The badge's left edge sits at (label width − FLAGSHIP_ICON_INSET_RIGHT − FLAGSHIP_ICON_BOX),
	# so the strip it covers is INSET_RIGHT + BOX wide — the inset ADDS to the reservation now that
	# the badge sits inside the label's corner (it SUBTRACTED while the badge hung outside it).
	inset.content_margin_right = (
			FLAGSHIP_ICON_BOX + FLAGSHIP_ICON_INSET_RIGHT + FLAGSHIP_NAME_CLEARANCE
	)
	_name_label.add_theme_stylebox_override("normal", inset)


## Called by Main when the player cycles the global buy-mode toggle.
func set_buy_mode(mode: BuyMode) -> void:
	_buy_mode = mode


## Called by Main when the player cycles the global hire-mode toggle.
func set_hire_mode(mode: HireMode) -> void:
	_hire_mode = mode


## Called by Main to say how far the player's Head Hunters legacy track has unlocked bulk
## hiring: level 0 → ×1 only, 1 → ×10, 2 → BLOCK, 3 → MAX. Those levels line up exactly with
## the HireMode ordinals, which is why the clamp below is a plain mini(). Main pushes this in
## rather than the row reading LegacyUpgrades itself — the row stays free of dynasty coupling,
## exactly as it is today.
func set_max_hire_mode(level: int) -> void:
	_max_hire_mode = clampi(level, HireMode.ONE, HireMode.MAX) as HireMode


## The mode this row will actually act on: the global choice, clamped to what the player has
## unlocked. Clamping here (rather than refusing) means a save carrying a mode from a previous
## generation's upgrades degrades gracefully to the best allowed one instead of doing nothing.
func _effective_hire_mode() -> HireMode:
	return mini(_hire_mode, _max_hire_mode) as HireMode


## How many staff levels a hire press in `mode` would buy RIGHT NOW — the single source of
## truth for that count. The hire button prices its quote with it and Main must resolve the
## mode with it too; if either side computed its own count they would drift and the button
## would advertise a purchase the core doesn't make.
##
## Static, and taking everything it needs as arguments, so Main can call it straight off the
## class (PropertyRow.resolve_hire_count(...)) without having to find the row that emitted.
##
## PARTIAL FILL IS DELIBERATE: the returned count is the mode's desired count clamped to what
## the player can actually afford (and to the reached-epoch level cap, which
## get_max_affordable_staff_levels already respects). So a ×10 press with cash for 7 levels
## returns 7 and buys 7 — a bulk button that went dead because the 10th level was a dollar
## short would read as broken. EconomyState.try_buy_staff_levels is partial-fill for the same
## reason, so the quote and the purchase agree even if cash changes between them.
static func resolve_hire_count(mode: HireMode, economy: EconomyState, prop_index: int, reached_tier: int) -> int:
	var desired := 0
	match mode:
		HireMode.ONE:
			desired = 1
		HireMode.TEN:
			desired = 10
		HireMode.MAX:
			desired = economy.get_max_affordable_staff_levels(prop_index, reached_tier)
	if desired <= 0:
		return 0
	return economy.get_max_affordable_staff_levels(prop_index, reached_tier, desired)


## When false, this row belongs to an epoch/tab the pager is NOT currently showing: the row
## hides and skips ALL per-frame work (refresh + carbonation draw), so only the active tab's
## ~6 rows ever cost anything. Set by Main via set_tab_active(). Default true so the row still
## works if the pager never touches it.
var _tab_active: bool = true


## Main's pager calls this when the player swipes to another epoch/tab: only the active tab's
## rows stay live. Hiding stops the Control (and its GoldBubbles) from drawing.
func set_tab_active(active: bool) -> void:
	_tab_active = active
	if not active:
		visible = false
		# A hidden row stops running _process, so a marker still fading when the tab was swiped away
		# would be frozen mid-fade and reappear, stuck, the next time this tab is opened. Clear it
		# here — the same reason the held-action latches are dropped below.
		_clear_auto_purchase_marker()
		# Drop any held action NOW. A deactivated row stops running _process, so the
		# _pump_held_* functions can never clear a hold that was engaged at the moment the
		# tab switched — e.g. holding a rush when First Contact auto-jumps the pager to the
		# new epoch's tab (the overlay swallows the finger release). The stale latch made
		# is_hold_active() report true forever, which killed epoch swiping until the player
		# paged back to this tab by button (Tim's report, 2026-07-27).
		_release_all_holds()


## Reset every held-action latch to "not held", mirroring what the _pump_held_* functions do
## when they see the button released — including notifying Main that an engaged rush ended,
## so the rush-momentum state doesn't stay stuck on a hidden row.
func _release_all_holds() -> void:
	if _rush_hold_pulsed:
		_rush_hold_pulsed = false
		rush_hold_released.emit(prop_index)
	# Close the raw press/release edge stream too (the vent-gesture reader tracks it), exactly
	# as _pump_rush_edges would on the finger lifting.
	if _rush_button_was_down:
		_rush_button_was_down = false
		rush_released.emit(prop_index)
	_hold_accumulator = 0.0
	_rush_hold_seconds = 0.0
	_buy_hold_accumulator = 0.0
	_buy_hold_repeating = false
	_buy_gesture_acted = false
	_hire_hold_accumulator = 0.0
	_hire_hold_repeating = false
	_hire_gesture_acted = false


## Mark this row as one Auto-Purchase Mode just bought into. Main calls it immediately after the
## Acquisitions Desk spends into THIS property; nothing else calls it, so a manual purchase never
## produces the marker and a row the desk skipped stays completely inert.
##
## RE-ENTRANCY (this fires forever, up to about once a second): the effect is ONE pre-built
## ColorRect plus ONE float countdown, so re-triggering simply refills the countdown and repaints
## the alpha. There is no Tween and no Timer to stack, kill, or leak — calling this every frame for
## an hour allocates nothing and leaves nothing behind. A re-trigger mid-fade restarts cleanly at
## full strength rather than fighting a previous animation, so the wash can only ever brighten on a
## buy and dim in between — it never flickers dark first.
func flash_auto_purchased() -> void:
	# Before _ready (Main configures a freshly constructed row) there is nothing to paint yet, and a
	# row on a tab the player isn't looking at must not bank a marker for the next time it is shown.
	if _auto_purchase_marker == null or not _tab_active:
		return
	_auto_purchase_marker_seconds = AUTO_PURCHASE_MARKER_SECONDS
	_auto_purchase_marker.color = Color(UiPalette.MONEY_GREEN, AUTO_PURCHASE_MARKER_PEAK_ALPHA)
	_auto_purchase_marker.visible = true


## Fade the auto-purchase marker out over AUTO_PURCHASE_MARKER_SECONDS. Called once per frame from
## _refresh; a no-op (and free) on the overwhelming majority of frames, when nothing is showing.
func _fade_auto_purchase_marker(delta: float) -> void:
	if _auto_purchase_marker_seconds <= 0.0:
		return
	_auto_purchase_marker_seconds = maxf(0.0, _auto_purchase_marker_seconds - delta)
	if _auto_purchase_marker_seconds <= 0.0:
		_clear_auto_purchase_marker()
		return
	# Squared falloff: full strength on the buy itself, then away quickly — the marker should be
	# noticed, not watched. Linear read as a lingering highlight at this duration.
	var remaining := _auto_purchase_marker_seconds / AUTO_PURCHASE_MARKER_SECONDS
	_auto_purchase_marker.color = Color(
			UiPalette.MONEY_GREEN, AUTO_PURCHASE_MARKER_PEAK_ALPHA * remaining * remaining)


## Take the marker down immediately, wherever it was in its fade.
func _clear_auto_purchase_marker() -> void:
	_auto_purchase_marker_seconds = 0.0
	if _auto_purchase_marker != null:
		_auto_purchase_marker.color = Color(UiPalette.MONEY_GREEN, 0.0)
		_auto_purchase_marker.visible = false


func _process(delta: float) -> void:
	if not _tab_active:
		return  # a hidden tab: no refresh, no bar/bubble draw — the whole point of the pager
	_refresh(delta)
	_pump_rush_edges()
	_pump_held_rush(delta)
	_pump_held_buy(delta)
	_pump_held_hire(delta)


## Raw touch handling for CONCURRENT inputs (see the multi-touch note in the fields above). Only
## SECONDARY fingers are acted on here; the primary finger is left to the normal Button / emulated-
## mouse path, so single-touch behaviour is untouched and nothing ever double-fires.
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
		return
	# A held secondary finger sliding: re-check which control it is over now, so sliding OFF a control
	# cancels its hold (matching how lifting off a button stops the repeat).
	var drag := event as InputEventScreenDrag
	if drag != null and _secondary_targets.has(drag.index):
		var target := _control_under_point(drag.position)
		if target == "":
			_secondary_targets.erase(drag.index)
		else:
			_secondary_targets[drag.index] = target


func _on_touch_pressed(index: int, global_pos: Vector2) -> void:
	# The first finger of a gesture is the one Godot emulates the mouse from — leave it entirely to the
	# Button path. We still record it so its release is recognised, but we never act on it here.
	var is_first_finger := _active_fingers.is_empty()
	_active_fingers[index] = true
	if is_first_finger:
		_primary_finger = index
		return
	# A secondary finger: act only when the Property tab is live and this row is actually on screen,
	# so a stray finger can't trigger a purchase on a row hidden behind a modal overlay.
	if not SecondaryTapButton.enabled or not is_visible_in_tree():
		return
	var control_id := _control_under_point(global_pos)
	if control_id == "":
		return
	_secondary_targets[index] = control_id
	_fire_secondary_action(control_id)


func _on_touch_released(index: int) -> void:
	_active_fingers.erase(index)
	_secondary_targets.erase(index)
	if index == _primary_finger:
		_primary_finger = -1


## Advance the completion pulse by one frame: fill to the right edge, hold there a beat, then let go.
##
## Deliberately its own clock. The bar's normal motion is derived from the economy — cycle_progress
## over the effective length — and that is right for any cycle long enough to watch. Below roughly a
## fifth of a second the arithmetic is still correct and the RESULT is useless: too few frames pass
## for the fill to arrive, so the player sees a stub of a bar and then nothing. A payout the player
## cannot see is, to them, a payout that did not happen.
##
## Releasing the flag is what ends it: the next frame mirrors the true (zero) progress, so the bar
## drops to empty and the row is ready for the next tap.
func _advance_completion_pulse(delta: float) -> void:
	if _displayed_cycle_fraction < 1.0:
		_displayed_cycle_fraction = minf(
			_displayed_cycle_fraction + delta * COMPLETION_FILL_PER_SEC, 1.0)
		return
	_completion_hold_remaining -= delta
	if _completion_hold_remaining <= 0.0:
		_finish_lap_pending = false


## The income readout over the cycle bar, as text. Pure: same inputs, same string, no node access —
## which is what lets the rule below be tested directly instead of by squinting at a screenshot.
##
## THREE CASES, and the distinction that matters is WHO RESTARTS THE CYCLE.
##
##   • Being RUSHED — the held finger restarts it, so the boosted rate is genuinely delivered for as
##     long as the hold lasts, and the readout quotes it (sub-second) or the rush-shortened lump.
##   • Owned but UNSTAFFED, with a sub-second cycle — nothing restarts it. One tap buys exactly one
##     cycle and then it stops, so the figure is shown BARE: no unit, because there is no rate. This
##     replaces the per-SECOND form only; a longer unstaffed cycle already reads as its lump plus its
##     wait, which is honest about the tap AND tells the player how long the payout takes.
##   • STAFFED — the staffer restarts it forever, so a per-second rate is a real throughput. Sub-
##     second cycles read as a rate; longer ones read as their lump plus the wait, because money
##     arriving every 4 minutes is not a per-second trickle.
##
## The unstaffed case was added 2026-08-09. It used to fall through to the sub-second rate, which
## advertised a throughput the row could not reach without a staffer — and the gap grew with every
## Efficiency upgrade, since those shorten the cycle without changing what one tap pays. Tim, with an
## 0.18 s cycle: "the income display on that property says 11.4T/s, but tapping the staff portrait
## only gains around 2T... the disconnect between an income label specific to seconds but the actual
## income for a single cycle is much less." The two figures were both correct; the label was simply
## answering a question the player was not asking.
##
## Note the hero-panel headline already drew this distinction — an idle unstaffed row contributes
## ZERO to it (Tim, 2026-07-13) — so this brings the row's own label in line with what the header
## had been saying about it all along.
func _format_income_readout(
		per_cycle: float, effective_length: float, rushed_fractions_per_second: float,
		is_owned: bool, is_staffed: bool
) -> String:
	# The leading "$" is shown as the dollar-bill icon just left of the label (see _income_icon),
	# so strip it off every amount before it goes into the text (Tim, 2026-07-09).
	if rushed_fractions_per_second > 0.0:
		var rushed_cycle_time := 1.0 / rushed_fractions_per_second
		if rushed_cycle_time <= PER_SECOND_READOUT_THRESHOLD_SEC:
			return Money.of(per_cycle * rushed_fractions_per_second).display().trim_prefix("$") + " / s"
		return "%s / %s" % [
			Money.of(per_cycle).display().trim_prefix("$"), _format_cycle_duration(rushed_cycle_time)]

	if effective_length > 0.0 and effective_length <= PER_SECOND_READOUT_THRESHOLD_SEC:
		# The per-tap form replaces the per-SECOND form ONLY. A long cycle already reads as its lump
		# plus its wait ("2T / 4.3m"), which is both honest about what a tap pays and useful about
		# how long the payout takes — replacing that with "/ tap" would throw the wait away to fix a
		# problem it never had.
		if is_owned and not is_staffed:
			# BARE, with no unit at all (Tim, 2026-08-09). "/ tap" was accurate but still framed the
			# figure as a rate-of-something, and the row already says how the money arrives — the
			# portrait is the only way to run this property. A naked amount is the payout, full stop.
			return Money.of(per_cycle).display().trim_prefix("$")
		return Money.of(per_cycle / effective_length).display().trim_prefix("$") + " / s"
	return "%s / %s" % [
		Money.of(per_cycle).display().trim_prefix("$"), _format_cycle_duration(effective_length)]


## Which of this row's three interactive controls, if any, sits under a global point — "" if none.
## Respects each control's current eligibility (a disabled Buy/Hire, or a non-interactive portrait, is
## not a target), so a secondary finger can only ever trigger what a primary finger could.
func _control_under_point(global_pos: Vector2) -> String:
	if _portrait_interactive and _manager_circle.is_visible_in_tree() \
			and _manager_circle.get_global_rect().has_point(global_pos):
		return "rush"
	if not _buy_button.disabled and _buy_button.is_visible_in_tree() \
			and _buy_button.get_global_rect().has_point(global_pos):
		return "buy"
	if not _hire_button.disabled and _hire_button.is_visible_in_tree() \
			and _hire_button.get_global_rect().has_point(global_pos):
		return "hire"
	return ""


## Fire the one-shot action for a secondary-finger PRESS on a control (the hold pumps add the repeats
## afterward, exactly as they do for the primary finger's Button).
func _fire_secondary_action(control_id: String) -> void:
	match control_id:
		"rush":
			tap_requested.emit(prop_index)  # start an idle cycle, or land one rush
		"buy":
			buy_requested.emit(prop_index, _buy_mode, _next_buy_source())
		"hire":
			_on_hire_pressed()


## True while any SECONDARY finger is currently holding the named control ("rush" / "buy" / "hire") —
## the hold pumps OR this with the primary finger's Button state so either finger can drive a hold.
func _secondary_held(control_id: String) -> bool:
	return _secondary_targets.values().has(control_id)


## Emit the raw rush_pressed/rush_released edge signals (the vent gesture's input — see the
## signal comments). "Down" is the SAME truth the hold pump reads — the primary finger's
## Button OR any secondary finger on the portrait — so the edges can never disagree with the
## hold behaviour; polling it per frame costs at most one frame of latency (~16 ms), far
## inside the gesture's 0.25–0.40 s tolerances. Deliberately NOT gated on is_cycle_running:
## an unstaffed property's cycle stops for a few frames at every payout (the same flicker
## documented in _refresh), and a vent re-press landing in that gap must still count as a
## press. Owning zero units means the control can't rush at all, so those rows stay silent;
## edges are otherwise always forwarded (even during lockout) — the core, not the view,
## decides what a press means.
func _pump_rush_edges() -> void:
	var down: bool = _prop.units_owned > 0 \
			and (_manager_circle.is_held() or _secondary_held("rush"))
	if down == _rush_button_was_down:
		return
	_rush_button_was_down = down
	if down:
		rush_pressed.emit(prop_index)
	else:
		rush_released.emit(prop_index)


## Holding the start/rush button continually drives the property at the tuning
## hold rate (UI notes §2): an idle cycle is STARTED on the first held pulse,
## then a running cycle is RUSHED on every pulse after. Both are gated behind the
## same accumulator, so a quick tap accrues no pulse and stays a plain single
## action (which still fires on release via the button's pressed signal).
func _pump_held_rush(delta: float) -> void:
	# is_held() is false whenever the portrait button is disabled (a locked rung, or an
	# automated property that is not the player's top one), so those simply never auto-rush.
	# A secondary finger on the portrait (multi-touch) counts as held too.
	if (not _manager_circle.is_held() and not _secondary_held("rush")) or _prop.units_owned == 0:
		_hold_accumulator = 0.0
		# The hold just ended (or lapsed): if it actually auto-rushed, say so NOW, so momentum
		# stops building at the release instead of riding out the grace window. Gated on a real
		# pulse having fired — a quick tap fires no pulse, and its momentum credit (granted via
		# the button's own pressed -> tap_requested on release) must survive this pump seeing
		# "not held" on the very same frame.
		if _rush_hold_pulsed:
			_rush_hold_pulsed = false
			rush_hold_released.emit(prop_index)
		return
	_hold_accumulator += delta
	var pulse_interval := 1.0 / _prop.tuning.hold_rush_per_second
	while _hold_accumulator >= pulse_interval:
		_hold_accumulator -= pulse_interval
		# Every held pulse is the RUSH verb — the core starts an idle cycle itself before
		# rushing it (GameState.hold_rush_property). Routing idle pulses to a plain tap here
		# (the old behavior) broke on very short cycles: an unstaffed sub-pulse-interval
		# cycle was ALWAYS stopped when the pulse landed, so every pulse became a start-tap
		# and no rush ever fired — rush mode could not engage on that property (Tim's
		# Photon Exchange report, 2026-07-27).
		_rush_hold_pulsed = true
		hold_rush_requested.emit(prop_index)


## Holding the BUY button keeps purchasing on a calm cadence (hold-to-buy). A quick tap is
## handled by the button's own `pressed` signal (one purchase); this only adds the repeats
## while it stays held. Unaffordable pulses are skipped (the buy button disables itself), so
## a held button simply idles once the player runs out of cash rather than spamming failures.
func _pump_held_buy(delta: float) -> void:
	# Held via the primary finger's Button, or a secondary finger resting on it (multi-touch).
	if not _buy_button.button_pressed and not _secondary_held("buy"):
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = false
		# The gesture is over, so the next press starts a fresh one and gets its feedback. Safe to
		# do here rather than on button_down: this runs in _process, and the release-fired `pressed`
		# has already been emitted by the time the next frame sees the button unheld.
		_buy_gesture_acted = false
		return
	_buy_hold_accumulator += delta
	var threshold := _prop.tuning.buy_hold_repeat_interval if _buy_hold_repeating \
		else _prop.tuning.buy_hold_initial_delay
	if _buy_hold_accumulator >= threshold:
		_buy_hold_accumulator = 0.0
		_buy_hold_repeating = true
		if not _buy_button.disabled:
			buy_requested.emit(prop_index, _buy_mode, _next_buy_source())


## Holding the STAFF button keeps performing its current action on a calm cadence (Tim, 2026-07-01):
## a quick tap is handled by the button's own `pressed` (one hire/upgrade/level-up); this only adds
## the repeats while it stays held. It routes through _on_hire_pressed, so a held button naturally
## flows from hiring to upgrading to leveling up as the state changes. Unaffordable pulses are
## skipped (the button disables itself), so a held button simply idles once the player runs out of
## cash rather than spamming failures — exactly like the buy button.
func _pump_held_hire(delta: float) -> void:
	# Held via the primary finger's Button, or a secondary finger resting on it (multi-touch).
	if not _hire_button.button_pressed and not _secondary_held("hire"):
		_hire_hold_accumulator = 0.0
		_hire_hold_repeating = false
		_hire_gesture_acted = false   # gesture over — see the note in _pump_held_buy
		return
	_hire_hold_accumulator += delta
	var threshold := _prop.tuning.hire_hold_repeat_interval if _hire_hold_repeating \
		else _prop.tuning.hire_hold_initial_delay
	if _hire_hold_accumulator >= threshold:
		_hire_hold_accumulator = 0.0
		_hire_hold_repeating = true
		if not _hire_button.disabled:
			_on_hire_pressed()


## True while a HELD action is engaged on this row: auto-rush (held past RUSH_ENGAGE_SEC), or
## hold-to-buy / hold-to-hire once they start repeating. Main checks this so a press that's held
## long enough to trigger a hold and then drifts sideways does NOT also flip the epoch tab
## (Tim 2026-07-11 — a hold owns the finger).
func is_hold_active() -> bool:
	return _buy_hold_repeating or _hire_hold_repeating or _rush_hold_seconds >= RUSH_ENGAGE_SEC


## True while the game's open vent window should hold THIS row's rush presentation up through
## the gesture's finger lifts (Plans/Overdrive_Vent_Windows.md). Two conditions:
##   • a vent window is open — read from the SHARED RushMomentumState the row already holds
##     for the overheat-lockout look (the cleanest existing seam to the global rush state;
##     no new setup parameter needed), and
##   • this row was already presenting an ENGAGED rush (_rush_hold_seconds past
##     RUSH_ENGAGE_SEC — the frozen counter, see _refresh).
## The second condition is how the row knows the vent is ABOUT it without being told which
## property overdrive rode in on: only the row whose hold built the heat can have an engaged
## counter when a window opens; every other row's counter sits at 0. (Rushing two rows at once
## can leave both engaged — both fingers are then mid-gesture, so holding both presentations
## through the window is the honest read.)
func _vent_presentation_hold() -> bool:
	# Never while overheat-frozen. Overheating CLOSES the vent window, so is_vent_window_open()
	# is already false the moment a freeze begins — the explicit gate just makes the row's
	# contract self-evident: the vent hold exists to keep a LIVE rush looking alive through the
	# gesture's finger lifts, and it must never keep a frozen (dead) row looking alive instead.
	if _prop != null and _prop.is_overheat_frozen:
		return false
	return _rush_momentum != null and _rush_momentum.is_vent_window_open() \
			and _rush_hold_seconds >= RUSH_ENGAGE_SEC


func _refresh(delta: float) -> void:
	# Ladder visibility (Phase 3 tabs, Tim 2026-07-11): the pager (Main) groups properties into
	# epoch tabs and shows one tab at a time, so within the ACTIVE tab every unlocked property is
	# shown — the old single-cheapest "peek" rule is replaced by the tab grouping. This func only
	# runs at all when _tab_active is true (see _process), so a row is visible iff its property is
	# unlocked. A property locked behind a later epoch still never shows (its tab isn't reachable).
	var current_tier := _epoch.current_tier
	visible = _economy.is_property_unlocked(prop_index, current_tier)

	var config := _prop.config as PropertyConfig
	# Row 1 is just the property name (bold). The owned-count and next-milestone threshold now live
	# in their own outlined chip on row 2 (Tim, 2026-07-01), no longer folded into the title.
	_name_label.text = config.display_name

	# The count chip: "<owned> / <next milestone threshold>", or "<owned> / MAX" past the last tier.
	var next_milestone := _prop.get_next_milestone_count()
	if next_milestone <= 0:
		_count_label.text = "%d / MAX" % _prop.units_owned
	else:
		_count_label.text = "%d / %d" % [_prop.units_owned, next_milestone]

	# A rung the player owns no units of yet gets a drab gray "locked" look; once a
	# unit is bought it switches to the normal cream styling (applied on change).
	var owned := _prop.units_owned > 0

	# Overheat property FREEZE (Plans/Overdrive_Vent_Windows.md, Tim 2026-07-19): this property
	# was actively being rushed at the moment the heat bar overheated, so the core has shut it
	# DOWN for the whole lockout — cycle paused, collections refused, idle starts refused; it
	# comes back the instant rushing re-arms. The row presents it as a dead machine: LOCKED-style
	# portrait disc, the cycle bar dead-slate and frozen where it stopped, carbonation off, and
	# the income readout dimmed and counted as 0. PRESENTATION ONLY, same principle as the
	# rush-lockout dim below — nothing is disabled or hidden (no-moving-UI rule), because the
	# player's finger may still be resting on the portrait when the freeze lands mid-hold: the
	# hold pump and raw rush edges keep flowing to the core, which refuses them until rush_ready.
	# (is_overheat_frozen is only ever true during a lockout, so rush_locked below is always
	# true on a frozen row too — the freeze look layers ON TOP of the lockout look.)
	var frozen := _prop.is_overheat_frozen

	_apply_ownership_styling(owned, frozen)

	# An unowned rung has no cycle to run, so the cycle bar is hidden until the player
	# owns at least one unit (Tim, 2026-06-28).
	_cycle_bar.visible = owned

	# Keep the portrait circle square, sized to PORTRAIT_HEIGHT_FRACTION of the panel's full height
	# and centered vertically. The row's height is driven by the column of rows to the right, so we
	# read it back from the portrait's parent (the outer HBox) and shrink the square to fit.
	var outer_row := _manager_circle.get_parent() as Control
	var portrait_size: float = outer_row.size.y * PORTRAIT_HEIGHT_FRACTION
	_manager_circle.custom_minimum_size = Vector2(portrait_size, portrait_size)

	# The portrait is the start/rush control (ManagerCircle). Decide its look and whether it
	# accepts input this frame:
	#   • LOCKED   — no units owned yet (drab, inert).
	#   • STAFFED  — automated; shows the property accent + staffer headshot. Still rushable:
	#                the staffer runs it, but the boss can always lean on it (Tim, 2026-07-03 —
	#                was "only the single highest property"; opened to every owned row because
	#                rush is self-limiting economically: 5% of a short cycle is worth nothing,
	#                so only the long-cycle rows reward the attention, and a same-looking disc
	#                that ignored touches read as broken rather than automated).
	#   • UNSTAFFED — owned but not automated; silver restart plate.
	# The infinity icon shows whenever an interactive portrait is actively held (being rushed).
	var staffed := _prop.is_staffed
	var interactive := owned
	# Remembered for _control_under_point, so a secondary-finger rush obeys this same rule.
	_portrait_interactive = interactive
	var portrait_mode := ManagerCircle.PortraitMode.LOCKED
	if owned:
		portrait_mode = ManagerCircle.PortraitMode.STAFFED if staffed else ManagerCircle.PortraitMode.UNSTAFFED
	# While overheat-frozen the disc wears the SAME drab-gray LOCKED look an unowned rung uses —
	# the row's existing "not available" vocabulary, reused rather than inventing a new state —
	# while staying interactive underneath so a finger already holding it keeps its raw
	# edge/hold signals (the core refuses them; see the freeze note above). LOCKED also draws
	# no staff level, which is honest here: the staffer is down with the machine.
	if frozen:
		portrait_mode = ManagerCircle.PortraitMode.LOCKED
	# Rush Overheat lockout (Tim 2026-07-15): while rushing is shut down the portrait must LOOK
	# disabled — the core ignores the rush verb, so a live-looking button that does nothing would
	# read as a bug. PRESENTATION ONLY: the portrait stays interactive (a tap can still start an
	# idle cycle, which is not a rush), and buy/hire are untouched. A gray, dimmed modulate mutes
	# the whole disc; the rush-held look below is suppressed for the duration.
	#
	# This is PER-PROPERTY, keyed on the freeze — NOT on the global meter (Tim 2026-07-19: during
	# an overheat, unrelated properties, including unstaffed ones he had never rushed, also looked
	# locked; the whole tab read as dead). Only the properties that were actually being rushed go
	# down; everyone else keeps rushing through the lockout for income and frenzy (see
	# GameState.tap_property), so their portraits must keep looking alive.
	var rush_locked := frozen
	# AUTO-BUY ALSO REFUSES EVERY RUSH (Tim, 2026-08-07: "when auto buy is enabled and you hold down
	# a staffer portrait, the rush visualization occurs even though the property isn't actually
	# cycling that fast or generating income at that rate").
	#
	# The core has always refused the verb here — GameState.hold_rush_property returns immediately —
	# but this row derived its rush LOOK from the local press alone, so the finger produced a vivid
	# fill, a boosted income readout and frenzy fizz while nothing was landing. That is precisely the
	# desync the system's binding invariant forbids: whatever the row shows IS what the player earns.
	#
	# Deliberately kept OUT of `rush_locked` above, which drives the gray portrait dim. That dim is
	# per-property and keyed on an overheat freeze, because a GLOBAL dim made the whole tab read dead
	# (Tim 2026-07-19) — and auto-buy's lockout is global, so folding it in would resurrect exactly
	# that. The lie is the thing being fixed; the dim is a separate call.
	var rush_refused_by_auto_buy := _auto_purchase != null and _auto_purchase.is_running()
	_manager_circle.modulate = Color(0.55, 0.55, 0.55) if rush_locked else Color.WHITE
	# The infinity "rushing" icon shows whether the primary Button or a secondary finger holds it
	# — hidden during lockout, when holding produces no rushes. The vent presentation hold (see
	# _vent_presentation_hold below) keeps it up through the vent gesture's finger lifts too:
	# this reads LAST frame's _rush_hold_seconds (the current-frame update happens further down),
	# which is exactly the frozen value the hold maintains, so the icon never flickers mid-vent.
	var show_rush_icon := interactive and not rush_locked and not rush_refused_by_auto_buy \
			and (_manager_circle.is_held() or _secondary_held("rush")
					or _vent_presentation_hold())
	_manager_circle.set_state(
		portrait_mode, config.accent_color, config.manager_portrait, show_rush_icon,
		interactive, _prop.staff_level,
		# The staffer's role — property rung + the epoch tier currently running it — seeds a
		# procedural face when no portrait is authored (StafferFace).
		prop_index, _prop.staff_tier
	)
	# Income readout. For an OWNED rung: the cash paid each time the bar fills (per cycle),
	# lit by the live frenzy multiplier so it matches what the player actually receives.
	# For an UNOWNED rung: the per-cycle value of a SINGLE unit, drawn dark gray (see
	# _apply_ownership_styling), so the player can see what the next tier is worth before
	# buying in (Tim 2026-06-17).
	# Effective (sped-up) cycle length drives both the readout below and the bar fill
	# further down. Once it drops below SOLID_BAR_THRESHOLD_SEC the property is paying so
	# fast that the bar can't meaningfully animate, so we treat it as "humming": pin the
	# bar solid (see further down) and quote a steady per-second rate instead of per-cycle.
	var effective_length := _prop.get_effective_cycle_length()
	var bar_is_solid := owned and _prop.is_cycle_running \
		and effective_length > 0.0 and effective_length < SOLID_BAR_THRESHOLD_SEC
	# The amount paid per completed cycle. For an OWNED rung get_income_per_cycle() already folds in
	# the staffer and Family Fortune (Legacy) multipliers AND this property's own Rush Momentum factor
	# (>1 only while it is being actively rushed — Tim 2026-07-13), with frenzy applied live on top so
	# it matches what the player receives; for an UNOWNED rung it's the per-cycle value of a single
	# unit (a buy-in preview).
	var per_cycle := _prop.get_income_per_cycle() * _frenzy.get_multiplier() if owned \
		else _prop.get_single_unit_income_per_cycle()
	# Rate context on the payout (Tim, 2026-07-02): a cycle of a second or more shows the per-cycle
	# payout WITH its cycle length, scaled to a sensible unit — "$X/4.3m" is $X every 4.3 minutes —
	# so the figure is never an unlabeled amount. A sub-second cycle instead reads as a per-second
	# rate ("$X/s"), the same per-cycle figure divided by the (tiny) cycle length.
	# The income amount shows a single decimal place only when it isn't zero (display()'s default —
	# _trim drops a trailing ".0"), with a space on either side of the slash (Tim, 2026-07-02/03):
	# "$14M / 4.3m" when whole, "$14.3M / 4.3m" when not.
	# "<=" so a cycle of EXACTLY one second also reads as the per-second rate " / s" —
	# per-cycle and per-second are the same number at 1s, and "$X / 1s" read as a defect
	# (Tim, 2026-07-03: a per-second rate says "/ s", never "/ 1s").
	#
	# While rush is HELD the readout instead quotes the effective rate the rush is
	# actually producing (Tim, 2026-07-07 — rushing changed no number on screen):
	# per-cycle income × the computed cycle-under-rush completion rate. The same rate
	# feeds the solid-bar rule below, so the number and the bar always agree.
	# Held by EITHER path: the primary finger on the portrait Button, or a secondary
	# finger via the raw-touch handler (Tim, 2026-07-07 — rushing two properties at once
	# left the secondary one with the calm color/rate: it pumped, but this flag only
	# looked at the Button, so a rushed row didn't always present as rushing).
	# Also forced OFF while rush is locked out (Rush Overheat): the finger may still be down, but
	# no rushes are landing, so the boosted readout / vivid green / frenzy fizz would all be lies.
	# `rush_refused_by_auto_buy` is the second suppressor: same reasoning as the overheat lockout —
	# the finger may be down, but no rushes are landing, so the boosted readout, vivid green and
	# frenzy fizz would all be lies.
	var rush_held := (_manager_circle.is_held() or _secondary_held("rush")) \
			and _prop.units_owned > 0 and not rush_locked and not rush_refused_by_auto_buy
	# The ENGAGED flag: held long enough to count as a real hold (see RUSH_ENGAGE_SEC).
	# Every rush-presentation element below keys off THIS, never the raw press, so a
	# single tap changes nothing on screen (Tim, 2026-07-08).
	#
	# Vent-window presentation hold (Plans/Overdrive_Vent_Windows.md — "the hold must not
	# flicker"): the vent gesture demands lifting the finger mid-rush, and the game must never
	# LOOK like it dropped the hold during those lifts. So while _vent_presentation_hold() is
	# true the counter FREEZES at its held value instead of resetting — rush_engaged stays true,
	# and with it every downstream rush visual (vivid fill color, boosted income readout, frenzy
	# bubbles, the rushed sweep rate). Normal release behaviour resumes the instant the window
	# resolves (success, miss, or overheat all close it).
	if rush_held:
		_rush_hold_seconds += delta
	elif not _vent_presentation_hold():
		_rush_hold_seconds = 0.0
	var rush_engaged := _rush_hold_seconds >= RUSH_ENGAGE_SEC
	# Deliberately NOT gated on is_cycle_running: an UNSTAFFED property's cycle stops the
	# instant it pays out and only restarts on the next held-rush pulse, so gating on it
	# made the readout (and the solid pin) flicker back to the calm display for a few
	# frames at the end of every cycle (Tim, 2026-07-08). While rush is held the restart
	# is guaranteed, so the rushed rate stays honest across that momentary gap.
	var rushed_fractions_per_second := 0.0
	if rush_engaged and effective_length > 0.0:
		rushed_fractions_per_second = 1.0 / effective_length \
				+ _prop.tuning.hold_rush_per_second * _prop.tuning.rush_pct * _prop.rush_power_multiplier
	_income_label.text = _format_income_readout(
		per_cycle, effective_length, rushed_fractions_per_second, owned, staffed)
	# Cache the per-second equivalent of whatever the label just showed (rush-boosted
	# while held) — Main sums these across rows for the hero panel's income headline
	# (Tim, 2026-07-07), so the headline always equals the sum of the visible rows.
	# Unowned rows show a buy-in PREVIEW, which is not income — they contribute 0.
	# An overheat-FROZEN row likewise contributes 0: the machine is down and pays nothing for
	# the whole lockout (same reasoning as the owned-but-unstaffed rule below — a row that is
	# not actually earning must not inflate the income headline).
	if not owned or effective_length <= 0.0 or frozen:
		_displayed_income_per_sec = 0.0
	elif rushed_fractions_per_second > 0.0:
		# Being rushed: it really earns at this rate right now (even an unstaffed rung, while held).
		_displayed_income_per_sec = per_cycle * rushed_fractions_per_second
	elif _prop.is_cycle_running:
		# Its cycle is RUNNING, so it genuinely produces per_cycle when that cycle completes — earn
		# this passive rate. Two ways to be here: STAFFED (auto-runs hands-off), or an unstaffed
		# cycle still IN FLIGHT — e.g. finishing the last cycle after a rush is released, while the
		# release-tail bonus is still draining. That in-flight cycle WILL pay per_cycle × the decaying
		# rush_momentum_factor, so the headline must track the drain here, not snap straight to base
		# the instant the finger lifts (Tim 2026-07-20: the header dropped to base while the cycle was
		# still running and the momentum bar was still draining).
		_displayed_income_per_sec = per_cycle / effective_length
	else:
		# Owned but UNSTAFFED and its cycle has STOPPED (idle): an unstaffed rung halts after each
		# payout and needs a manual tap or a rush to run again, so a stopped one earns nothing
		# passively and must NOT inflate the income headline (Tim 2026-07-13: two staffed properties
		# made ~70 B/s, but the headline read ~80 B/s, the extra coming from idle unstaffed rungs'
		# theoretical rates being summed in). is_cycle_running is exactly what separates "about to
		# pay this cycle" from "stopped, earning nothing" — the earlier is_staffed gate missed a
		# running unstaffed cycle and read it as idle.
		_displayed_income_per_sec = 0.0

	# Smooth, constant-velocity cycle bar (see _displayed_cycle_fraction above). Measured
	# against the EFFECTIVE (sped-up) cycle length so the bar still fills all the way to the
	# right once the Legacy "Efficiency Experts" upgrade shortens the real cycle — it just
	# fills faster (Tim 2026-06-17). Measuring against the raw length capped the fill at
	# 1 / cycle_speed_multiplier, so it stopped short of the right edge.
	var true_fraction := _prop.cycle_progress / effective_length if effective_length > 0.0 else 0.0
	var wrapped := true_fraction < _last_true_cycle_fraction

	# Deterministic solid rule (Tim, 2026-07-06 — replaced a measured completion-cadence
	# rule that could stick and unstick unpredictably): the bar is solid exactly when the
	# CURRENT completion time is too short to watch. Not rushing, that's the effective
	# cycle length (bar_is_solid). While rush is HELD, it's the computed cycle-under-rush
	# time (rushed_fractions_per_second, computed with the income readout above). In any
	# other circumstance the bar animates normally.
	var rushed_solid := rushed_fractions_per_second > 0.0 \
			and 1.0 / rushed_fractions_per_second <= RUSHED_SOLID_THRESHOLD_SEC
	# A frozen row is never pinned "humming at full" — the machine is down, so the frozen
	# branch below holds the bar exactly where the core stopped it instead.
	var pinned := (bar_is_solid or rushed_solid) and not frozen

	# A cycle just PAID OUT AND STOPPED — the unstaffed case, since a staffed property restarts
	# itself and never takes this edge. Owe the bar a visible finish (see COMPLETION_FILL_PER_SEC).
	if _was_cycle_running and not _prop.is_cycle_running and owned and not frozen:
		_finish_lap_pending = true
		_completion_hold_remaining = COMPLETION_HOLD_SEC
	_was_cycle_running = _prop.is_cycle_running

	if _was_pinned and not pinned and not _finish_lap_pending:
		# Unpinning (rush released, usually): restart the visible lap from empty and let
		# the easing below chase the real progress — holding at full would freeze the
		# bar until the next natural completion.
		#
		# Skipped when a finish is owed: that is the completion pulse, and zeroing the bar here is
		# precisely the snap-back that made a short cycle look like it never filled.
		_displayed_cycle_fraction = 0.0
		_finish_lap_pending = false
	_was_pinned = pinned

	if frozen:
		# Overheat freeze: the core is holding cycle_progress still, so the displayed bar must
		# hold too — mirror the true (stopped) value exactly and clear the animation machinery.
		# Left to the running branch below, the displayed fraction would keep sweeping on its
		# own (it advances at _sweep_rate every frame and only re-syncs phase at the wraps),
		# animating a machine that is DOWN.
		_displayed_cycle_fraction = true_fraction
		_finish_lap_pending = false
		# Park the eased sweep at the natural rate so the restart at rush_ready resumes at calm
		# speed instead of inheriting the stale rushed rate from just before the overheat.
		if effective_length > 0.0:
			_sweep_rate = 1.0 / effective_length
	elif pinned:
		# Cycles complete faster than the eye/bar can follow — fill the rest of the way
		# in a quick sprint (see PIN_FILL_PER_SEC; snapping straight to full read as
		# sudden), then hold there. The income readout carries the information now; the
		# bar just reads as "maxed and humming".
		_displayed_cycle_fraction = minf(_displayed_cycle_fraction + delta * PIN_FILL_PER_SEC, 1.0)
		_finish_lap_pending = false
	elif (not _prop.is_cycle_running and not rush_engaged) or _prop.units_owned == 0:
		# Idle or empty: nothing is advancing, so just mirror the true value exactly.
		# An ENGAGED rush is never idle: an unstaffed cycle stops for a few frames at
		# every payout until the next pulse restarts it, and routing those frames here
		# hard-reset the eased sweep to natural — so the "constant" rushed sweep was
		# actually a sawtooth re-accelerating from scratch every lap (caught red-handed
		# by Tim's debug-overlay data, 2026-07-08: swp cycled 17→283 within each lap).
		if _finish_lap_pending and _prop.units_owned > 0:
			# THE COMPLETION PULSE. The cycle is over and the core has already paid; this is the
			# flourish that lets the player SEE it happened, on a clock slow enough to register.
			_advance_completion_pulse(delta)
		else:
			_displayed_cycle_fraction = true_fraction
			_finish_lap_pending = false
		# Park the eased sweep at the natural rate so a later start doesn't inherit
		# a stale rushed rate (or a zero) from long ago.
		if effective_length > 0.0:
			_sweep_rate = 1.0 / effective_length
	else:
		# A completed cycle (detected above) means the displayed bar usually hasn't
		# reached the right edge yet (it lags — see _finish_lap_pending), so it owes a
		# finishing lap rather than a snap-back.
		if wrapped:
			_finish_lap_pending = true
		# While a lap is owed, the chase target sits one full bar ahead of the true
		# progress: the bar fills through 1.0, then wraps onto the new cycle below.
		var target := true_fraction + (1.0 if _finish_lap_pending else 0.0)
		# Running: advance at the real fill rate — the DETERMINISTIC rushed rate while
		# an engaged rush is held (the same number the income readout shows). The rate
		# is EASED between natural and rushed (SWEEP_EASE_TAU) so engaging/releasing
		# accelerates the sweep instead of snapping it: a fill-speed snap stretches the
		# bubble field and reads as a frenzy sprint at the hold's edges. One smooth,
		# constant sweep = one constant frenzy (Tim, 2026-07-08).
		var target_rate := 1.0 / effective_length
		if rushed_fractions_per_second > 0.0:
			target_rate = rushed_fractions_per_second
		_sweep_rate = lerpf(_sweep_rate, target_rate, 1.0 - exp(-delta / SWEEP_EASE_TAU))
		var advanced := _displayed_cycle_fraction + delta * _sweep_rate
		if target > advanced:
			# Catch-up (single rush taps, the engage moment, the owed lap after a
			# release): capped at a small headroom over the CURRENT sweep rate, so
			# closing the gap never moves the fill visibly faster than the sweep
			# itself — the gap absorbs as a phase drift over seconds, not a sprint.
			var catchup := 1.0 - exp(-delta / RUSH_CATCHUP_TAU)
			var candidate := lerpf(advanced, target, catchup)
			var max_step := _sweep_rate * CATCHUP_RATE_HEADROOM * delta
			_displayed_cycle_fraction = minf(candidate, _displayed_cycle_fraction + max_step)
		else:
			_displayed_cycle_fraction = advanced
		if _finish_lap_pending and _displayed_cycle_fraction >= 1.0:
			# The bar visibly touched the right edge — wrap onto the new cycle, carrying
			# any overshoot so the motion stays continuous.
			_finish_lap_pending = false
			_displayed_cycle_fraction -= 1.0
		elif rush_engaged and _displayed_cycle_fraction >= 1.0:
			# METRONOME wrap while an engaged rush sweeps: never wait at full for the
			# pulse-stepped true progress to catch up — that wait was a ~quarter-second
			# stall (fill speed dipping 280 → 120) every single lap, the last rhythm
			# blip in the frenzy (autopilot data, 2026-07-08). Rate is what matters
			# during a hold; phase re-syncs on release via the normal machinery.
			_displayed_cycle_fraction -= 1.0
		_displayed_cycle_fraction = clampf(_displayed_cycle_fraction, 0.0, 1.0)
	_last_true_cycle_fraction = true_fraction
	_cycle_bar.value = _displayed_cycle_fraction

	# Cycle-bar fill color. Once a property is staffed and running itself hands-off, rush
	# is no longer an option (only the player's single highest-owned property stays
	# rushable — see `interactive` above), so the bar drops its active green for a calm
	# blue. Otherwise it stays green, brightening while the rush button is actively held.
	var rush_no_longer_option := staffed and not interactive
	_set_cycle_color(rush_no_longer_option, rush_engaged, frozen)

	# Carbonation TIER (Tim, 2026-07-10): the bar's actual fill speed no longer drives the
	# bubbles — each state just picks a tier with a STATIC speed and agitation. Holding rush
	# whips the liquid up (FRENZY); a normally cycling owned bar FLOWS; a static or unowned
	# bar only fizzes (IDLE). The ease inside GoldBubbles smooths transitions between tiers.
	# A dead machine doesn't fizz: the carbonation hides entirely while frozen (an effect
	# overlay inside the bar, not a control, so the no-moving-UI rule doesn't apply) and is
	# parked at IDLE so the rush_ready restart ramps up from still liquid rather than resuming
	# mid-froth. Without this, a core that reports is_cycle_running during the pause would keep
	# gold FLOWING fizz drifting across the dead-slate fill.
	_cycle_bubbles.visible = not frozen
	if not owned or frozen:
		_cycle_bubbles.tier = GoldBubbles.Tier.IDLE
	elif rush_engaged:
		_cycle_bubbles.tier = GoldBubbles.Tier.FRENZY
	elif _prop.is_cycle_running:
		_cycle_bubbles.tier = GoldBubbles.Tier.FLOWING
	else:
		_cycle_bubbles.tier = GoldBubbles.Tier.IDLE
	_cycle_bubbles.tier_ease_tau = _prop.tuning.carb_tier_ease

	# Fast neon-salmon streaks over the gold ONLY on a property that is ITSELF being rushed in
	# OVERDRIVE — its own momentum factor at/past the Hot-band bonus, i.e. heat past the old cap
	# (Rush Overheat, Tim 2026-07-15; was "at max bonus" when the meter still had a hard cap).
	# Momentum applies only to the rushed property, so no other row may show any change
	# (Tim 2026-07-13) — so this keys off THIS property's own momentum factor, not the global meter.
	# (rush_momentum_factor is 1 + bonus while the property is within its rush grace.)
	var rushed_in_overdrive := _prop.rush_momentum_factor \
			>= 1.0 + _prop.tuning.rush_momentum_bonus_at_hot - 0.001
	# ... and never on a frozen row (overheat zeroes the momentum grace anyway; the explicit
	# gate just guarantees no overdrive streak can outlive the machine it decorated).
	_cycle_momentum_streaks.visible = owned and rushed_in_overdrive and not frozen

	# The diagnosis overlay: live values driving this row's carbonation (reading the
	# bubbles' internals directly is fine here — this label exists only to expose them).
	var debug_on := _prop.tuning.carb_debug_overlay > 0.5 and owned
	_carb_debug_label.visible = debug_on
	if debug_on:
		_carb_debug_label.text = "tier %d  agit %.2f  spd %d px/s" % [
			_cycle_bubbles.tier, _cycle_bubbles._agitation, int(_cycle_bubbles._base_speed_px),
		]

	_refresh_frozen_banner(frozen)
	_fade_auto_purchase_marker(delta)

	_refresh_buy_button()
	_refresh_hire_button()


## Show / hide the "OVERHEATED + countdown" plate and keep its number current. Called every frame
## from _refresh; the plate itself never moves or resizes the row (see _ready).
func _refresh_frozen_banner(frozen: bool) -> void:
	if not frozen:
		_frozen_banner.visible = false
		_frozen_seconds_shown = 1 << 30  # sentinel: the next freeze starts its countdown fresh
		return
	# Whole seconds, rounded UP: the freeze is not over until the figure would reach zero, so
	# "1" must stay on screen through the last partial second rather than flashing a "0" the
	# player would read as "it should have thawed by now".
	var seconds := int(ceil(_overheat_seconds_remaining()))
	seconds = maxi(seconds, 1)
	# Monotone: never let the readout tick back up mid-freeze (see _frozen_seconds_shown).
	seconds = mini(seconds, _frozen_seconds_shown)
	_frozen_seconds_shown = seconds
	_frozen_banner_label.text = "%s  %ds" % [FROZEN_BANNER_TEXT, seconds]
	_frozen_banner.visible = true


## Seconds until this row THAWS — i.e. until RushMomentumState fires rush_ready, which is the exact
## moment GameState brings the frozen properties back up. The lockout has two halves and the core
## exposes each of them differently, so the two are added here rather than read from one getter:
##
##   • the locked DRAIN, still running: heat is public and drains at a known constant rate, so the
##     remaining drain time is heat / rate exactly.
##   • the post-drain RE-ARM: the core publishes only rearm_remaining_fraction() (the momentum
##     bar's dead-gray timer needs a fraction, not seconds), so the fraction is multiplied back out
##     by the delay's full length, rebuilt here from the same knobs the core uses.
##
## Rebuilding that length needs the per-tier failure sting, which the core captures privately at the
## overheat moment and never exposes. We substitute its CAP knob — the largest it can ever be — so
## the estimate errs HIGH. That direction is deliberate: over-estimating ends the countdown a beat
## early (the row simply lights back up), while under-estimating would park it at "1s" while the
## property was still dark, which is precisely the open-ended wait this banner exists to remove.
## Both sting knobs ship at 0.0 today ("the freeze is the penalty"), so today the figure is exact.
##
## NOT read from a UI-side timer of our own: the core owns this clock, it advances on tick time
## (so pauses and scene reloads stay honest), and a parallel timer would drift away from the thaw.
func _overheat_seconds_remaining() -> float:
	if _rush_momentum == null:
		return 0.0
	var tuning := _prop.tuning
	# The "Rapid Restart" Legacy upgrade shrinks BOTH halves of the lockout. The core clamps the
	# scale before using it, so clamp identically here or the two clocks disagree.
	var lockout_scale := clampf(_rush_momentum.lockout_time_scale, 0.05, 1.0)
	var rearm_total := (tuning.rush_momentum_rearm_seconds
			+ tuning.rush_momentum_vent_fail_rearm_cap) * lockout_scale
	if _rush_momentum.is_rearming():
		# The drain is done; only the re-arm tail is left.
		return _rush_momentum.rearm_remaining_fraction() * rearm_total
	# Still draining: the drain left, plus the whole re-arm that follows it.
	var drain_rate := tuning.rush_momentum_locked_drain_per_second / lockout_scale
	if drain_rate <= 0.0:
		return rearm_total
	return _rush_momentum.heat / drain_rate + rearm_total


## Pick the cycle bar's fill: dead slate while the property is overheat-frozen (the machine
## is down — highest priority, overriding every live look), calm blue once the property is
## automated and rush is no longer an option, otherwise the active green (brightened while
## the rush button is held). Only rebuilds the stylebox on a change — doing it every frame
## would be wasteful (same pattern as FrenzyBar's burn-color swap).
func _set_cycle_color(rush_no_longer_option: bool, rush_held: bool, frozen: bool) -> void:
	var want := 0
	if frozen:
		want = 3
	elif rush_no_longer_option:
		want = 2
	elif rush_held:
		want = 1
	if want == _cycle_color_applied:
		return
	_cycle_color_applied = want
	var fill := UiPalette.MONEY_GREEN
	if want == 3:
		fill = FROZEN_SLATE
	elif want == 2:
		fill = UiPalette.CYCLE_BLUE
	elif want == 1:
		# Deeper, more saturated green for the active push. Color has no "saturate"
		# helper, so we nudge the HSV saturation by hand after darkening.
		fill = UiPalette.MONEY_GREEN.darkened(HELD_RUSH_DARKEN)
		fill.s = minf(fill.s * HELD_RUSH_SATURATE, 1.0)
	UiPalette.style_progress_bar(_cycle_bar, fill)


## Format a cycle length (seconds) as a compact duration with a unit scaled to size —
## seconds (s), minutes (m), hours (h), or days (d) — for the "$X/<duration>" income readout (Tim,
## 2026-07-02). Units are lowercase, matching the "/s" per-second rate. At most one decimal,
## and only when it is non-zero (Money.trim): "4.3m" but "2m", never "2.0m" (Tim, 2026-07-03).
func _format_cycle_duration(seconds: float) -> String:
	if seconds >= 86400.0:
		return Money.trim(seconds / 86400.0, 1) + "d"
	elif seconds >= 3600.0:
		return Money.trim(seconds / 3600.0, 1) + "h"
	elif seconds >= 60.0:
		return Money.trim(seconds / 60.0, 1) + "m"
	return Money.trim(seconds, 1) + "s"


## Swap the row's panel background and income readout between three looks:
##   0 owned (normal)   — cream panel, per-cycle payout in bold black.
##   1 unowned          — drab gray "locked" panel, dark-gray single-unit preview.
##   2 overheat-frozen  — the panel KEEPS its owned cream (the player still owns it; only the
##     machine is down). The income readout is NOT restyled: the full-cell OVERHEATED countdown
##     plate is drawn over the bar and covers it, so the plate + timer carries the "down right now"
##     message on its own (Tim, 2026-07-22 — chose the plate over also revealing a dimmed $0).
## Only rebuilds the styleboxes when the state actually flips, not every frame. (The portrait
## button's own look is set live by ManagerCircle.)
func _apply_ownership_styling(owned: bool, frozen: bool) -> void:
	var want := 0
	if not owned:
		want = 1
	elif frozen:
		want = 2
	if want == _ownership_style_applied:
		return
	_ownership_style_applied = want
	# The FLAGSHIP rung takes the warmed, heavy-bordered, softly glowing plate in every one of the
	# three states below — owning it, not owning it yet, and being overheat-frozen don't change
	# WHICH property advances the epoch, so the marker must never blink off. (Both flagship plates
	# keep the standard plate's content margin, so swapping them in never moves anything: see
	# UiPalette._apply_flagship_frame.)
	var owned_plate := (
			UiPalette.make_flagship_panel_style() if _is_flagship else UiPalette.make_panel_style()
	)
	if want == 0:
		add_theme_stylebox_override("panel", owned_plate)
		# Owned: the per-cycle payout in bold black (Tim, 2026-07-01).
		_income_label.add_theme_color_override("font_color", Color.BLACK)
		# The dollar-bill icon is FULL-COLOR art (green note, gold seal), so it shows at its
		# own colors — modulate stays white. Tinting it to the text color turned the whole
		# icon into a solid black silhouette (Tim, 2026-07-09).
		_income_icon.modulate = Color.WHITE
	elif want == 1:
		add_theme_stylebox_override("panel",
				UiPalette.make_unowned_flagship_panel_style() if _is_flagship
				else UiPalette.make_unowned_panel_style())
		# Unowned: a drab dark-gray single-unit preview, matching the locked row look. Fade the
		# color icon back with alpha (rather than recolor it) so it still reads as a dollar bill.
		_income_label.add_theme_color_override("font_color", UiPalette.DARK_GRAY)
		_income_icon.modulate = Color(1, 1, 1, 0.5)
	else:
		# Frozen: still the owned cream panel (it shows through the plate's rounded corners). The
		# income readout and icon are left as-is on purpose — the OVERHEATED countdown plate is drawn
		# full over the bar cell and fully occludes them, so dimming them here was dead work that only
		# made the code look like a $0 readout stays visible during a freeze; it does not. When the row
		# thaws, want==0 restores the black readout (see the function comment above; Tim, 2026-07-22).
		add_theme_stylebox_override("panel", owned_plate)


## Which source the NEXT buy of this gesture should report.
##
## THE FIRST purchase of a gesture is the one that gets the feedback, whether it came from a quick
## tap or from the first pump of a hold — everything after it is a repeat.
##
## This was originally written the other way round (repeats silent, the release-fired purchase
## audible), and that put the ONLY sound at the END of the gesture: press, hold half a second, and
## the confirmation arrived when the finger lifted. Feedback belongs at the start of an action, not
## its finish (Tim, 2026-08-08: "a noticeable delay between clicking the buy button and the sound").
func _next_buy_source() -> ActionSource:
	if _buy_gesture_acted:
		return ActionSource.HOLD_REPEAT
	_buy_gesture_acted = true
	return ActionSource.PLAYER_TAP


## The hire equivalent of _next_buy_source.
func _next_hire_source() -> ActionSource:
	if _hire_gesture_acted:
		return ActionSource.HOLD_REPEAT
	_hire_gesture_acted = true
	return ActionSource.PLAYER_TAP


## The staff button's `pressed` handler. One action only — buy up the ladder — so no state
## dispatch (the pre-redesign HIRE/UPGRADE/LEVEL-UP state machine is gone). HOW MANY rungs is
## the current hire mode's business, and Main resolves that from the mode we send.
func _on_hire_pressed() -> void:
	hire_requested.emit(prop_index, _effective_hire_mode(), _next_hire_source())


## Update the staff button for the property's sequential ladder (GDD §6.1, epoch-depth
## redesign). The button is a pure BUY action — headshot + "+" and the COUNT this press buys
## ("×10") on the left, the price of those levels on the right (the current level shows in the
## portrait disc instead, Tim 2026-07-05) — plus a faint-green MAX park when every level the reached epoch
## allows has been bought. Because each block's price is fixed by its own epoch, the
## number here can never silently jump at a first contact; a new block's bigger price
## only appears once the player has actually climbed to it (the 2026-07-03 bug fix).
func _refresh_hire_button() -> void:
	# Cap reached: every level the reached epoch allows is bought. The next block unlocks
	# at the next first contact, so the button parks on the faint-green "staffed" plate
	# with the icon + plus grayed and "MAX" where the price was.
	if _economy.is_staff_level_maxed(prop_index, _epoch.current_tier):
		_apply_hire_styling(true)
		_hire_cost_label.text = "MAX"
		# "MAX" is not a price, so hide the dollar-bill icon (Tim, 2026-07-09).
		_hire_cost_icon.visible = false
		# No count either: this button buys NOTHING until the next first contact raises the cap, and
		# "×0" beside the word MAX would read as a broken quote rather than as a parked button. The
		# label stays in place (empty), so nothing about the button's layout changes here.
		_hire_count_label.text = ""
		_hire_button.disabled = true
		_hire_cost_label.add_theme_color_override("font_color", UiPalette.NAVY)
		_hire_count_label.add_theme_color_override("font_color", UiPalette.NAVY)
		_hire_glyph.tint = UiPalette.NAVY
		return

	_apply_hire_styling(false)
	# Price what this press will ACTUALLY buy under the current hire mode, not one level. The
	# count comes from resolve_hire_count — the same function Main uses to resolve the mode it
	# receives — so the quote on the button and the levels actually bought can never disagree.
	# The count is already clamped to what's affordable, so a ×10 press with cash for 7 quotes
	# the 7 and stays live rather than going dead a dollar short of the tenth level.
	var count := resolve_hire_count(_effective_hire_mode(), _economy, prop_index, _epoch.current_tier)
	var cost := 0.0
	if count > 0:
		cost = _economy.get_bulk_staff_level_cost(prop_index, count, _epoch.current_tier)
	else:
		# Nothing affordable yet: show the next single level's price so the player can see how
		# close they are, rather than a blank or a "$0" — the same fallback the buy button uses.
		cost = _economy.get_next_staff_level_cost(prop_index)
	# Drop the leading "$" — the dollar-bill icon before the label carries it (Tim, 2026-07-09).
	_hire_cost_label.text = Money.of(cost).display().trim_prefix("$")
	_hire_cost_icon.visible = true
	# The count caption states what THIS press buys, in the same "count on the left, price on the
	# right" shape the buy button uses ("+10"). It is the RESOLVED count, not the mode's name, so:
	#   • it is already clamped to the EFFECTIVE mode (_effective_hire_mode), and a player without
	#     the Head Hunters level can never be shown a ×10 the button would not honour;
	#   • BLOCK and MAX — which have no fixed number — state their actual number here;
	#   • partial fills tell the truth: a ×10 press with cash for 7 levels reads "×7", matching the
	#     price beside it (see resolve_hire_count).
	# When nothing is affordable yet (count 0) the price beside it is the NEXT SINGLE LEVEL's — the
	# fallback quote above — so the caption says "×1" to match that quote rather than "×0". The
	# button is disabled and dimmed in that state anyway, which is what says "not yet"; a row of
	# "×0"s across the whole early game would just be noise beside a price the player IS saving for.
	_hire_count_label.text = "×%d" % maxi(count, 1)
	# A property with no units can't be staffed — a staffer needs something to run.
	_hire_button.disabled = count <= 0 or _prop.units_owned == 0
	# Navy on the live mustard plate, dimmed to match the disabled cream plate — applied to
	# the cost text and the headshot+plus glyph (both monochrome, so they take a flat tint).
	var hire_color := Color(UiPalette.NAVY, 0.45) if _hire_button.disabled else UiPalette.NAVY
	_hire_cost_label.add_theme_color_override("font_color", hire_color)
	_hire_count_label.add_theme_color_override("font_color", hire_color)
	_hire_glyph.tint = hire_color
	# The dollar-bill icon is FULL-COLOR art, so it keeps its own colors (tinting it navy
	# turned it into a solid dark box — Tim, 2026-07-09); only fade it with alpha when the
	# button is disabled, matching the dimmed cost text beside it.
	_hire_cost_icon.modulate = Color(1, 1, 1, 0.45) if _hire_button.disabled else Color.WHITE


## Swap the hire button between the normal action look (HIRE/UPGRADE) and the faint-
## green "staffed for now" look. Only rebuilds the stylebox when the state flips.
func _apply_hire_styling(staffed: bool) -> void:
	var want := 1 if staffed else 0
	if want == _hire_style_applied:
		return
	_hire_style_applied = want
	if staffed:
		var staffed_style := UiPalette.make_staffed_style()
		_hire_button.add_theme_stylebox_override("disabled", staffed_style)
		_hire_button.add_theme_stylebox_override("normal", staffed_style)
		_hire_button.add_theme_color_override("font_disabled_color", UiPalette.NAVY)
	else:
		UiPalette.style_button(_hire_button, false)


## Overlay an action button with two labels — one left-aligned, one right-aligned —
## sharing a single vertically-centered row that fills the button's fixed height. A
## Button only draws one centered string, so to put the count on the left and the cost
## on the right we add our own labels on top of it. The overlay ignores the mouse so
## taps still reach the button underneath. Returns [left_label, right_label].
##
## NO-MOVING-UI GUARANTEE (why the captions can say anything without the row shifting):
##   • a Button is NOT a Container, so its minimum size comes only from its own text/icon and
##     custom_minimum_size — nothing added to this overlay can ever widen or heighten it, and the
##     button line's widths are fixed by the two stretch ratios regardless;
##   • inside the overlay the LEFT label is expanding AND clip_text, and a clipped Label reports a
##     minimum width of 1, so its string length has no say in the layout either. The cost stays
##     pinned to the right edge whatever the caption reads.
## Together those two are why the buy count ("+1" … "+1240") and the hire count ("×1" … "×137")
## can change every frame without a single pixel of reflow.
func _add_split_button_labels(button: Button) -> Array:
	# Fill the button, inset by the plate's content margin so the text clears the border.
	var overlay := MarginContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 12)
	overlay.add_theme_constant_override("margin_right", 12)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(overlay)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)

	var left := Label.new()
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_FILL
	left.clip_text = true  # if the two strings ever collide, the caption yields, never the cost
	left.add_theme_font_size_override("font_size", BUTTON_LABEL_FONT_SIZE)
	# Every text on the panel reads bold (Tim, 2026-07-05).
	left.add_theme_font_override("font", UiPalette.make_bold_font())
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var right := Label.new()
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.size_flags_vertical = Control.SIZE_FILL
	right.add_theme_font_size_override("font_size", BUTTON_LABEL_FONT_SIZE)
	right.add_theme_font_override("font", UiPalette.make_bold_font())
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	return [left, right]


## Build a small inline icon that sits just left of a text label, standing in for the
## symbol the label used to spell out (the "$" on money figures, or a tab icon on the buy
## count). Sized to a square a little taller than the font's cap height so it reads at the
## same weight as the digits beside it, aspect-preserved, and mouse-ignored so a tap on it
## still reaches the control underneath. (Tim, 2026-07-09.)
##
## The texture is the imported SVG (see _crisp_icon_texture), drawn with LINEAR filtering as
## it shrinks into the small inline box.
## When size_is_box is false (the default), size_px is a neighboring font size and the box is
## set ~1.1x it so the icon reads a touch taller than the glyphs. When true, size_px IS the box
## side in pixels directly (used to hit an exact visible height — see the buy count icon).
func _make_inline_icon(svg_path: String, size_px: int, size_is_box := false) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _crisp_icon_texture(svg_path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var box := size_px if size_is_box else roundi(size_px * 1.1)
	icon.custom_minimum_size = Vector2(box, box)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Return the imported texture for an icon SVG, cached so the load happens once per icon for
## the whole ladder (all rows share the same two icons).
##
## IMPORTANT: this loads the IMPORTED texture (which ships inside the export PCK). The earlier
## version read the raw .svg SOURCE at runtime and rasterized it — but the export filter is
## "all_resources", which strips source files, so on device that read returned nothing and the
## app crashed on load (Tim, 2026-07-10). The imported SVG rasterizes at its native size, which
## is ample for these small inline icons — the same way ManagerCircle.HEADSHOT_TEX is used.
static func _crisp_icon_texture(svg_path: String) -> Texture2D:
	if _crisp_icon_cache.has(svg_path):
		return _crisp_icon_cache[svg_path]
	var texture := load(svg_path) as Texture2D
	_crisp_icon_cache[svg_path] = texture
	return texture


## Tint both of a split button's labels the one color. The overlay labels aren't the
## button's own text, so they don't follow its font_color/disabled theme overrides —
## we set their color to match the button's current state by hand.
func _set_split_label_color(left: Label, right: Label, color: Color) -> void:
	left.add_theme_color_override("font_color", color)
	right.add_theme_color_override("font_color", color)


## Update the buy button's caption, cost, and enabled state for the
## current global buy mode.
func _refresh_buy_button() -> void:
	# How many units this press would buy under the current mode. The left label just shows that
	# count as "+N" (Tim, 2026-07-01) — no "BUY"/"MAX" wording, since the count alone reads as the
	# purchase; the cost sits on the right.
	var count := 0
	match _buy_mode:
		BuyMode.ONE:
			count = 1
		BuyMode.TEN:
			count = 10
		BuyMode.NEXT_TIER:
			# Exactly enough to reach the next milestone threshold; 0 past the last tier
			# (get_next_milestone_count returns <= 0 there).
			count = maxi(0, _prop.get_next_milestone_count() - _prop.units_owned)
		BuyMode.MAX:
			count = _prop.get_max_affordable(_economy.cash)

	if count <= 0:
		# MAX mode with nothing affordable yet (or NEXT TIER past the last tier): "+0", and
		# show the next single unit's cost so the player can see how close they are,
		# instead of a blank "—".
		_buy_caption_label.text = "+0"
		# Drop the "$" — the dollar-bill icon before the label carries it (Tim, 2026-07-09).
		_buy_cost_label.text = Money.of(_prop.get_bulk_cost(1)).display().trim_prefix("$")
		_buy_button.disabled = true
		_set_buy_label_colors()
		return

	var cost := _prop.get_bulk_cost(count)
	_buy_caption_label.text = "+%d" % count
	_buy_cost_label.text = Money.of(cost).display().trim_prefix("$")
	_buy_button.disabled = _economy.cash < cost
	_set_buy_label_colors()


## Color the buy button's labels to match its state: the action pale-gold when live,
## or the dimmed navy of style_button's disabled plate when it can't be afforded.
func _set_buy_label_colors() -> void:
	var color := Color(UiPalette.NAVY, 0.45) if _buy_button.disabled else UiPalette.PALE_GOLD
	_set_split_label_color(_buy_caption_label, _buy_cost_label, color)
	# The property-tab icon is a MONOCHROME navy glyph, so it takes the same flat tint as the
	# count text beside it. The dollar-bill icon is FULL-COLOR art, so it keeps its own colors
	# (tinting it turned it into a solid box — Tim, 2026-07-09) and only fades with alpha when
	# the button is disabled.
	_buy_count_icon.modulate = color
	_buy_cost_icon.modulate = Color(1, 1, 1, 0.45) if _buy_button.disabled else Color.WHITE


# ---------------------------------------------------------------------------
# The hire button's "add staff" glyph
# ---------------------------------------------------------------------------

## The headshot icon with a large "+" tucked tight against its top-right, drawn as ONE
## control. Hand-drawn because node layout could not deliver "top-aligned and close"
## (Tim, 2026-07-05): a Label's line box carries dead ascent above the "+" glyph, and
## the headshot SVG carries transparent padding in its canvas — so container-aligned
## boxes left the plus visually low and far from the face. Drawing lets the plus hug
## the icon's VISIBLE bounds (get_used_rect — see the texture-sizing memory note).
class StaffHireGlyph extends Control:
	## Side of the square box the headshot canvas is fitted into. Sized so the VISIBLE headshot
	## art (which fills 86/96 of this box) is MATCHED_ICON_VISIBLE_HEIGHT tall, matching the buy
	## button's factory icon (Tim, 2026-07-10). Was a flat 62.0 (visible ~55.5px).
	const ICON_SIZE := PropertyRow.MATCHED_ICON_VISIBLE_HEIGHT * 96.0 / 86.0
	## The plus is bigger than the button's cost text so it carries as a symbol.
	## +25% in the all-panel-text-larger pass (42 → 52, Tim 2026-07-05).
	const PLUS_FONT_SIZE := 52
	## Gap between the face's visible right edge and the plus.
	const PAIR_GAP := 3.0
	## Distance from the "+" glyph's VISUAL top down to its text baseline, as a fraction
	## of the font size ("+" spans roughly the x-height band in most fonts). Art knob:
	## raise to push the plus down, lower to lift it.
	const PLUS_TOP_TO_BASELINE := 0.60

	## Tint for the whole glyph (navy live, dimmed navy when the button is disabled).
	var tint := Color.WHITE:
		set(value):
			if value != tint:
				tint = value
				queue_redraw()

	## The imported headshot SVG, shared across all rows (see PropertyRow._crisp_icon_texture).
	static var _headshot_tex: Texture2D
	## The headshot art's opaque bounds inside its canvas, computed ONCE for all rows
	## (get_used_rect is a CPU pixel scan; the canvas carries transparent padding). Measured
	## against the crisp texture above so it scales in step with tex.get_size() in _draw.
	static var _icon_used_rect := Rect2()
	## The bold face the "+" draws in (all panel text is bold, Tim 2026-07-05) —
	## cached: building a FontVariation per frame in _draw would be wasteful.
	static var _plus_font: FontVariation

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# LINEAR filtering as the headshot is drawn down into its small box.
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if _headshot_tex == null:
			_headshot_tex = PropertyRow._crisp_icon_texture("res://art/icons/headshot.svg")
		if _icon_used_rect.size == Vector2.ZERO:
			_icon_used_rect = Rect2(_headshot_tex.get_image().get_used_rect())
		if _plus_font == null:
			_plus_font = UiPalette.make_bold_font()
		var plus_width := _plus_font.get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, PLUS_FONT_SIZE).x
		custom_minimum_size = Vector2(ICON_SIZE + PAIR_GAP + plus_width, ICON_SIZE)

	func _draw() -> void:
		# Fit the icon canvas into its square box preserving aspect (what the old
		# TextureRect's KEEP_ASPECT did), pinned LEFT and vertically centered.
		var tex := _headshot_tex
		var tex_size := Vector2(tex.get_size())
		var fit := minf(ICON_SIZE / tex_size.x, ICON_SIZE / tex_size.y)
		var canvas_size := tex_size * fit
		var canvas_pos := Vector2(0.0, (size.y - canvas_size.y) / 2.0)
		draw_texture_rect(tex, Rect2(canvas_pos, canvas_size), false, tint)

		# The face's VISIBLE bounds within that canvas — what the plus aligns against.
		var face_top := canvas_pos.y + _icon_used_rect.position.y * fit
		var face_right := canvas_pos.x + _icon_used_rect.end.x * fit

		var baseline_y := face_top + PLUS_FONT_SIZE * PLUS_TOP_TO_BASELINE
		draw_string(_plus_font, Vector2(face_right + PAIR_GAP, baseline_y), "+",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, PLUS_FONT_SIZE, tint)
