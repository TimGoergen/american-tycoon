# Concurrent Multi-Touch on the Property Panel

**Status:** BUILT 2026-07-02 (branch `feature/ui-tap-targets`); device-tested 2026-07-06 — works,
but Tim expects secondary fingers on ALL Property-tab controls, not just the rows.
**EXPANDED 2026-07-07 (branch `feature/multitouch-all-controls`):** new reusable
`SecondaryTapButton` node (child of any Button; secondary press emits the Button's own `pressed`
signal, `is_secondary_held()` for hold pumps) attached to the buy-mode toggle, the TURBO meter, and
the clock-in button (whose auto-tap pump and sweep glow treat a secondary hold as held). The
app-wide gate moved from `PropertyRow.multitouch_enabled` to `SecondaryTapButton.enabled`; the rows'
bespoke three-target handler is otherwise unchanged.

## The problem

Tim wants concurrent inputs: e.g. **hold the rush portrait with one finger while tapping or holding
Buy/Hire with another.** Out of the box this is impossible in Godot.

**Root cause.** The project uses the default `input_devices/pointing/emulate_mouse_from_touch = true`.
Godot converts **only the first finger** of a gesture into a mouse event, and every `Button` (rush
portrait, buy, hire) acts on that single emulated mouse. While finger 1 holds the portrait, finger 2
produces **no** mouse event at all, so buy/hire can't fire. Godot's GUI focus machinery is
single-pointer, so `_gui_input` can't cleanly receive concurrent touches on different controls
either. The only reliable fix is to read **raw** `InputEventScreenTouch` events and hit-test them
ourselves.

## The design (chosen for LOW regression risk)

Split fingers into **primary** and **secondary**:

- **Primary finger** = the first finger of a gesture (the one Godot emulates the mouse from). It is
  left **entirely** to the existing Button path. Single-touch behaviour is therefore **byte-for-byte
  unchanged** — no risk to the well-tested common case.
- **Secondary fingers** = any additional finger down while the primary is still held. These are
  handled in `PropertyRow._input` directly: hit-test the finger's global position against the row's
  three controls and drive the action. Because the emulated mouse ignores these fingers, there is
  **never a double-fire**.

A finger is "first of a gesture" when no other finger is currently down (`_active_fingers` empty at
press). The primary index is locked until it releases; while any finger remains down we never adopt a
new primary, matching Godot's own "emulate from the first touch only" rule.

### Where the state lives (all in `PropertyRow.gd`)
- `static var multitouch_enabled` — set by `Main._process` each frame; true only when the Property
  tab is showing and no full-screen overlay (minigame / succession / settings / welcome / dev /
  first-contact) is up. Gates secondary-finger actions so a stray finger can't buy on a row hidden
  behind a modal.
- `_active_fingers` / `_primary_finger` — the primary/secondary bookkeeping.
- `_secondary_targets` — finger index → which control ("rush"/"buy"/"hire") it's currently over.
- `_portrait_interactive` — cached from `_refresh` so a secondary rush obeys the same "rush allowed"
  rule the ManagerCircle uses.

### How each control reacts
- **Press** on a control by a secondary finger fires the one-shot action (`tap_requested` /
  `buy_requested` / `_on_hire_pressed`), exactly what a primary tap does.
- **Hold** is picked up by the existing `_pump_held_*` functions, which now OR the primary Button
  state with `_secondary_held(id)` — so either finger can drive the hold-to-repeat.
- **Slide off** a control (drag) cancels its hold, matching lifting a finger off a button.

Eligibility is respected: a disabled Buy/Hire or a non-interactive portrait is not a hit target, so a
secondary finger can only ever trigger what a primary finger could.

## Known first-pass limitations (device-test, then decide)
- No visual "pressed" depress on a button driven by a secondary finger (the rush portrait's infinity
  icon DOES show). Actions/holds work; only the transient tactile depress is missing on finger 2.
- Hit-testing uses each control's global rect and visibility but does NOT additionally clip to the
  ScrollContainer's viewport. A row scrolled off-screen has an off-screen rect so this is unlikely to
  matter, but if a partially-clipped row ever mis-registers a touch near the tab bar, add a viewport
  clip check.
- The portrait is drawn as a circle but hit-tested as its square rect (same as the old Button).
