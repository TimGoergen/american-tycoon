# Audio System — Implementation Plan

**Status:** Planned, not started. Written 2026-08-06 from an interview with Tim.
**Graduates:** GDD §12 (Art & Audio Direction), §13 M3 milestone entry "audio implementation
(exotica/muzak per §12)", and GDD §11 open item "Sound & haptics design — remaining open:
haptics and per-event sound mapping."

**Code map basis:** all `file:line` references were verified against the working tree on
branch `feature/challenge-mode-gating` on 2026-08-06. Two branches carry work this plan
touches and are not merged yet — see §0.2.

---

## 0. Context

### 0.1 Starting position: nothing exists

Verified across the whole `game/` tree:

- No `[autoload]` section in `project.godot` — an audio singleton would be the **first
  autoload in the project**.
- No `[audio]` section, no `audio/buses/default_bus_layout` key, no
  `default_bus_layout.tres` anywhere.
- Zero occurrences of `AudioStream`, `AudioServer`, `AudioListener`, `.ogg`, `.wav`.

So this is greenfield. The one adjacent system that *does* exist is haptics, and it is the
pattern this plan deliberately mirrors (§2.1).

### 0.2 Branch dependency — read this before starting

The working tree is on `feature/challenge-mode-gating`. Two other branches carry
unmerged work that this plan's event map depends on:

| Branch | What it adds that matters here |
|---|---|
| `feature/auto-purchase-and-bulk-hire` | **Acquisitions Desk** (auto-buy) and **Head Hunters** (bulk hire). The interview decision "auto-buys are silent" (§4.4) is unimplementable until this merges — the code has no auto-buy at all today. |
| `feature/civs-12-26` | The 27-tier epoch ladder. §3.2's era-band → track mapping assumes 27 tiers. |

**Recommendation:** land audio *after* both merge, or accept that the auto-buy silencing
and the deep-band music mapping are follow-ups. Building the audio branch off `main`
today would produce an event map that goes stale on the next merge.

### 0.3 Decisions taken (Tim, 2026-08-06 interview)

Every row below is a decision, not a suggestion. Do not relitigate.

| # | Question | Decision |
|---|---|---|
| 1 | Background music presence | **Full looping soundtrack**, default on |
| 2 | High-frequency tap SFX | **Musical — taps play a scale** |
| 3 | Asset sourcing | **Licensed packs / free royalty-free libraries** |
| 4 | Priorities | **All four**: reward feedback, overdrive skill loop, ceremony beats, ambience/identity |
| 5 | Music variation across 27 epochs | **One track per era band (3–5 tracks)** |
| 6 | Tap scale keying | **Fixed pleasant scale always** (not keyed to the current track) |
| 7 | Player controls | **Music + SFX + haptics sliders**, one settings card |
| 8 | Focus loss | **Silence on focus loss, resume on return** |
| 9 | Overdrive audio | **Rising pitch + urgency layer** (continuous, heat-tracking) |
| 10 | Reward scaling | **Relative, not absolute** — keyed to % change, never raw magnitude |
| 11 | Bespoke ceremony audio | **Succession/obituary**, **First Contact / epoch arrival**, **Legacy upgrade purchase**. *Final Dollar deliberately excluded* (M4, not built) |
| 12 | Sequencing | **Vertical slice first**, then phased |
| 13 | Auto-purchase sound | **Silent — visual only** (the green count-chip wash already covers it) |
| 14 | First slice | **Tap → buy → collect** |
| 15 | UI sounds | **Tabs and major actions only** |
| 16 | Hard constraint | **Battery/CPU** — streaming vs in-memory, voice-count limits |
| 17 | Earth musical style | **Department-store muzak** |
| 18 | Alien musical style | **Alien instruments, American melody** |
| 19 | Long-session fatigue | **Fade out when idle, return on interaction** |

### 0.4 Design rules derived from those decisions

These are the invariants the implementation must hold. Each one is a decision above,
restated as something a code reviewer can check.

1. **Sound means the player did something.** Auto-purchase is silent (13). This
   generalizes: any unattended, repeating economic event stays visual-only. It is the
   single most important rule in this plan — an idle game that beeps unattended every
   1.5 seconds forever is a game people mute.
2. **No absolute magnitudes, ever.** (10) Nothing in the audio system may branch on a
   dollar amount. Branch on ratios, bands, or counts. A $250 purchase at generation 1 and
   a $4.2Sx purchase at generation 15 are the *same event* and must sound the same.
   This mirrors the existing project lesson that prestige constants must be tuned off
   ratios, not raw sim magnitudes.
3. **Audio never gates gameplay.** Every sound is fire-and-forget. No `await` on an audio
   call in an economy path. A dropped sound must never drop a purchase.
4. **Muted is a first-class state.** The whole system must be correct with volume at zero,
   on desktop, and in a headless sim run. Headless gates (`MoneyTest`, `EpochTest`,
   `AutoPurchaseTest`) must not need audio stubs.
5. **Every knob is a knob.** Volumes, fade times, cooldowns, and the tap-scale shape go
   into `TuningConfig` as `@export`s, matching how the haptic timings were promoted from
   consts (`MomentumBar.gd:207-208` records that promotion).

---

## 1. Architecture

### 1.1 The `Audio` autoload

**New file:** `game/scripts/audio/Audio.gd`, registered as the project's first autoload.

Rationale for an autoload rather than the project's existing static-class habit
(`TutorialProgress`, `SaveManager`, `Money.format_mode`): audio needs `AudioStreamPlayer`
**nodes** in the scene tree that survive `Main`'s teardown. `Main` is rebuilt on
succession and on tuning-apply (`Main.gd:451 _create_game()` is the funnel every boot path
passes through). A static class cannot own nodes; a scene-tree singleton can, and music
must not restart every time an heir takes over.

Public surface — deliberately small and verb-shaped:

```gdscript
# One-shots. Fire and forget; never awaited.
Audio.play(event: StringName, variant: int = 0) -> void
Audio.play_scaled(event: StringName, intensity: float) -> void   # intensity 0..1

# Music.
Audio.set_music_band(band: int) -> void      # crossfades; no-op if already on band
Audio.duck_music(amount_db: float, seconds: float) -> void
Audio.stop_music() -> void

# The continuous overdrive layer.
Audio.set_heat(normalized: float) -> void    # 0..1; drives pitch + urgency layer
Audio.set_heat_active(active: bool) -> void  # fades the layer in/out

# Volume, called from Settings.
Audio.set_bus_volume(bus: StringName, linear: float) -> void
```

**Everything routes through `Audio`.** No script anywhere else creates an
`AudioStreamPlayer`. This is the same containment discipline the project applies to
haptics — `MomentumBar.gd:876 _vibrate()` is the sole `Input.vibrate_handheld` call site
in the entire codebase, and that is why haptics were trivially made tunable later.

### 1.2 Bus layout

**New file:** `game/audio/default_bus_layout.tres`, referenced from `project.godot`.

```
Master
├── Music        — the looping soundtrack + the overdrive urgency layer
├── SFX          — economy feedback (tap, buy, collect, milestone, hire)
├── UI           — tabs, major buttons, denials
└── Ceremony     — succession, first contact, legacy purchase
```

Why four and not two: the settings card exposes three sliders (Music / SFX / Haptics per
decision 7), but **Ceremony must be separable from SFX at the mix level** even though the
player does not see it as its own slider. Ceremony sounds need to duck the music and sit
above the SFX floor; if they share a bus with the tap sound, tuning one wrecks the other.
`UI` is split from `SFX` for the same reason — a tab click and a purchase are different
loudness classes.

Player-facing slider → bus mapping:
- **Music slider** → `Music`
- **SFX slider** → `SFX`, `UI`, and `Ceremony` together
- **Haptics slider** → not a bus; scales the existing `MomentumBar` haptic ms knobs (§6.3)

### 1.3 Voice management — the CPU/battery constraint (decision 16)

The tap-scale decision (2) means the highest-frequency sound in the game is also the one
most likely to stack. Concrete limits:

- **Fixed pool of `AudioStreamPlayer` nodes**, allocated once in `Audio._ready()`. No
  runtime `new()` in a gameplay path. Proposed: 8 SFX voices, 4 UI, 2 Ceremony, 2 Music
  (for crossfade), 1 heat layer. Total 17 nodes, allocated at boot, never freed.
- **Steal-oldest** when the pool is exhausted. Never queue, never drop silently without a
  policy — an unbounded queue is how audio systems become the frame-time problem.
- **Per-event cooldown**, a `Dictionary[StringName, float]` of last-played timestamps.
  Default 40 ms. The tap scale gets its own shorter value; collect gets a much longer one
  (§4.3).
- **`.ogg` streaming vs in-memory:** music tracks stream from disk
  (`AudioStreamOggVorbis` with `loop = true`); every SFX loads fully into memory as
  `.wav` at import time. Streaming a 200 ms blip is strictly worse — disk seeks in the tap
  path is exactly the battery problem decision 16 asks about.
- **When all buses are at zero, `Audio.play()` returns immediately** without touching a
  voice. A muted player should cost approximately nothing.
- **Idle fade (decision 19) is also a CPU win** — after the fade completes, the music
  players are `stop()`ed, not left playing at zero volume. A stopped stream decodes
  nothing.

### 1.4 What plays where — the config resource

**New file:** `game/config/audio_events.tres` (a `Resource`, matching how `tuning.tres` and
the property `.tres` files work).

Maps `StringName` event → sample path(s), bus, base volume, cooldown ms, and pitch-variance
range. This keeps "which file plays for `buy_success`" out of GDScript, so swapping a
sourced asset is a resource edit rather than a code change — which matters a lot given
decision 3 (licensed packs; you will audition and replace samples repeatedly).

---

## 2. Patterns to mirror from the existing codebase

### 2.1 The haptics wrapper is the template

`MomentumBar.gd:876`:

```gdscript
func _vibrate(duration_ms: float) -> void:
    if duration_ms >= 1.0 and OS.has_feature("mobile"):
```

Three things to copy exactly:
1. **A knob at zero disables the effect** — no separate enabled flag to keep in sync.
2. **Platform guard inside the wrapper**, not at every call site.
3. **`is_inside_tree()` re-check after any `await`** — `MomentumBar.gd:904` does this
   inside the vent pulse train so a teardown mid-sequence doesn't error. Any audio
   sequence with a delay (ceremony stings, crossfades) needs the same guard.

The existing per-lift vent pulse train (`MomentumBar.gd:893 _pulse_vent_telegraph`) is
already the exact shape the vent audio cue wants. Audio should pulse **in lockstep with
it**, from the same function, not from a parallel timer — two timers drifting apart is
worse than no audio.

### 2.2 The settings card pattern

`Main.gd:1501-1539` builds the currency-format card. Copy its structure verbatim for the
audio card: `PanelContainer` + `UiPalette.make_panel_style()`, inner VBox separation 12,
heading Label at font size 45 with `UiPalette.make_bold_font()` and `UiPalette.NAVY`,
wrapped caption at `UiPalette.FONT_BODY`, then a rows VBox.

### 2.3 Dev tuning panel grouping

`DevTuningPanel.gd:270 const SECTIONS` auto-groups knobs by name prefix.
**An `audio_*` prefix needs a new SECTIONS entry**, or every audio knob silently lands in
the "Challenge Mode" catch-all (`CATCH_ALL_SECTION_TITLE` at `:307`). Also add entries to
`DESCRIPTIONS` (`:76`) and `DISPLAY_NAMES` (`:205`).

---

## 3. Music

### 3.1 Style direction (decisions 17, 18)

**Earth — department-store muzak.** Bland, cheerful, strings-and-organ elevator music.
The blandness is the joke: this is literally the hold music of prosperity, and the GDD's
line is that "the joke is sincerity." Sourcing note: this is a *harder* brief than tiki
exotica because most royalty-free "lounge" is written to be pleasant, not to be
funny-bland. Look for library music tagged *corporate*, *retail*, *supermarket*,
*hold music*, *1960s advertising*, and audition specifically for the ones that feel
slightly too content with themselves.

**Aliens — alien instruments, American melody.** The *same recognizable tune* played on
impossible instruments. This is the strongest single joke in the audio direction and it
has a real sourcing consequence: **you cannot assemble this from unrelated library
tracks.** Either
- (a) commission/generate one melody and have it re-arranged per band, or
- (b) pick one library track that has multiple instrumentation variants shipped together
  (some libraries do this), or
- (c) source a single melody and do the re-instrumentation yourself in a DAW.

Flag this as the plan's biggest open risk. §7.2 gives the fallback.

**Loop-transition rule:** band changes crossfade over ~2 s, and *never* mid-ceremony —
if an epoch arrival triggers a band change, the crossfade waits until the First Contact
overlay dismisses. Otherwise the new band's first note lands under the overlay's own
sting and both are ruined.

### 3.2 Era-band mapping (decision 5)

Five bands over 27 tiers, using the same banding logic the economy already uses in
`Plans/Progressive_Decay.md` (which bands tiers 3-11 / 12-19 / 20-27). Aligning the audio
bands to the *economy* bands is free coherence — the music changes when the game's math
changes character.

| Band | Tiers | Character |
|---|---|---|
| 0 — Blue Collar | 1 | Muzak, thin arrangement. Small speakers, small ambitions. |
| 1 — White Collar | 2 | Same tune, fuller. Strings arrive. The promotion is audible. |
| 2 — Early contact | 3–11 | The melody survives; instrumentation goes theremin/synth. |
| 3 — Mid | 12–19 | Fewer Earth instruments left. Odd intervals creep in. |
| 4 — Deep | 20–27 | The melody is recognizable but barely of this world. |

Band is derived from tier by one pure function — `Audio.band_for_tier(tier)`. Do not
scatter tier thresholds.

**Hook:** `EpochState.contact_made(new_tier)` (signal, declared `EpochState.gd:40`, already
connected at `Main.gd:688`). Also call `set_music_band()` at `Main.gd:451 _create_game()`
so a load lands on the right band without a transition.

### 3.3 Idle fade (decision 19)

After `audio_music_idle_fade_seconds` (proposed default: 180 s) with **no player
interaction**, fade music to silence over ~4 s and `stop()` the stream. Any interaction
fades it back in over ~1.5 s.

"Interaction" = any `SFX`- or `UI`-bus event fired. Not: passive cycle collections, not
auto-purchases, not the income/sec tick. This definition falls straight out of rule 0.4.1
— the same rule that keeps auto-buys silent decides what counts as presence.

Edge case to handle explicitly: **do not fade during an active overdrive session.** Heat
is a skill state; going quiet mid-rush because the player is holding rather than tapping
would be a bug that feels like a bug.

### 3.4 Focus handling (decision 8)

Godot delivers `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN` to the autoload's
`_notification()`. On focus out: fade the `Master` bus to silence over ~200 ms, then stop
music. On focus in: restore, and resume music from the top of the loop (not from position
— resuming mid-phrase after a long absence sounds broken).

Do **not** silence via `AudioServer.set_bus_mute` on `Master` and leave it — a crash or
missed `_IN` would leave the game permanently silent with no user-visible cause.
Fade the volume and keep a boolean; the boolean is recoverable, a muted bus is not
obviously diagnosable by a player.

---

## 4. SFX event map

Each row gives the hook point verified in the code. **"New hook"** means the code path has
no signal today and needs one added.

### 4.1 The core loop (first slice — decision 14)

| Event | Hook | Status |
|---|---|---|
| **Tap wage** | `WagePanel.wage_tapped` (`WagePanel.gd:15`) → `Main.gd:2073` | signal exists |
| Wage held auto-tap | `WagePanel.wage_hold_tapped` (`WagePanel.gd:16`) → `Main.gd:2077` | signal exists |
| **Tap property (start cycle)** | `GameState.gd:297` — `if prop.is_cycle_running:` is the branch | **new hook** |
| **Tap property (rush running cycle)** | same branch, other side | **new hook** |
| **Purchase succeeded** | `Main.gd:1845` (inside `if game.try_buy(...)`) | call site exists |
| **Cycle payout** | `PropertyState.gd:557 _collect()` — single chokepoint for *every* payout, passive and rushed | **new hook** |
| **Count milestone** | `Main.gd:1848` (`if prop.get_milestone_band() > band_before:`) — already computed for the tutorial tip | call site exists |

**The tap scale (decision 2, 6).** A fixed pentatonic set (C-D-E-G-A across ~1.5 octaves),
climbing one step per tap, decaying back to the root after
`audio_tap_scale_reset_seconds` (proposed 1.0 s) of no tapping, capped at the top of the
range. Fixed scale, not keyed to the current track (decision 6) — so it is one sample set
pitch-shifted, or a small bank of pre-pitched samples.

Implementation note: pitch-shift a single sample via `AudioStreamPlayer.pitch_scale` using
equal-temperament ratios (`2^(semitones/12)`). Pre-pitched samples sound better but are
five to eight files instead of one; start with pitch-shifting and only bank samples if
the artifacts are audible on device.

**Applies to which taps?** Tap wage and tap property (rush) both feed the scale, sharing
one climb counter. Purchases do **not** — they have their own sound and would break the
run. This is the "spam becomes music" payoff exactly where the spam is.

### 4.2 Purchase and hire feedback — relative scaling (decision 10)

`Audio.play_scaled("buy_success", intensity)` where intensity comes from the **percentage
change in income/sec**, not the price:

```
intensity = clampf(inverse_lerp(0.02, 0.50, delta_income_fraction), 0.0, 1.0)
```

A +2% buy sits at the floor; a +50% buy maxes out. Intensity drives volume and layer
count (a quiet base sample always, plus a brighter layer mixed in above ~0.5), never
pitch — pitch-scaling the purchase sound would collide with the tap scale.

`Main.gd:1845` already sits inside the successful-purchase branch and already knows the
property, so the pre/post income delta is available there.

Staff hire splits on `PropertyState.gd:247 add_staff_level()` — `staff_level == 1` is the
**first hire** (a distinct, more satisfying sound; it also starts the cycle at `:250`),
anything above is a level-up.

### 4.3 Collect — the fatigue trap

`_collect()` fires for **every property, every cycle**, and cycle lengths go down to
0.54 s at the fast end of the ladder. With a wide portfolio this is dozens of payouts per
second. A "cha-ching" per payout is unshippable.

Rules:
- Collect audio is **aggregated, not per-event**. Accumulate payouts over a window
  (proposed 250 ms) and play **one** sound whose intensity reflects the aggregate relative
  to current income/sec.
- **Hard cooldown** of `audio_collect_min_interval_ms` (proposed 250 ms) regardless.
- **Passive collections while the player is not interacting are silent** — rule 0.4.1
  again. A property finishing its cycle unattended is the game running, not the player
  acting. Only collections within ~2 s of a player interaction sound.

That last rule is the one that makes decision 1 (full soundtrack) survivable: the music
carries the idle state, and SFX are reserved for presence.

### 4.4 Auto-purchase — silent (decision 13)

Acquisitions Desk buys are **visual only**. The green count-chip wash already shipped on
`feature/auto-purchase-and-bulk-hire` is the entire feedback.

**Implementation blocker to resolve:** today `buy_requested` (`PropertyRow.gd:16`) cannot
distinguish an auto/repeat purchase from a player tap. Both the hold-to-buy repeat
(`PropertyRow.gd:837 _pump_held_buy`, emitting at `:850`) and — once merged — the
Acquisitions Desk arrive at the same handler (`Main.gd:1827`). The distinguishing state
exists only as `PropertyRow`'s private `_buy_hold_repeating` (`:848`).

**Required change:** add a source enum to the purchase path.

```gdscript
enum BuySource { PLAYER_TAP, HOLD_REPEAT, AUTO_PURCHASE }
signal buy_requested(prop_index: int, mode: int, source: BuySource)
```

The same treatment is needed for `hire_requested` (`_hire_hold_repeating`,
`PropertyRow.gd:859-864`) and the rush hold (`_rush_hold_pulsed`, `:829`).

Audio policy per source: `PLAYER_TAP` full, `HOLD_REPEAT` rate-limited (a hold is one
gesture, so it should sound like one thing, not sixty), `AUTO_PURCHASE` silent.

This refactor is worth doing on its own merits — "who initiated this" is information the
codebase currently discards, and the tutorial and stats systems will both want it later.

### 4.5 Denial sounds

Decision 15 selected "tabs and major actions only" for UI sound, and the negative-feedback
option was *not* selected. So denial sounds are **out of scope for v1** — but the hook
points are recorded here because they are the hardest to find later and the plan should not
lose them.

All are silent boolean returns with no signal:
- `Main.gd:1840-1841` — buy count resolved to 0 (best single "denied" anchor for buys)
- `EconomyState.gd:153-154` — insufficient cash; `:149-150` — property epoch-locked
- `EconomyState.gd:281-282` — staff at level cap; `:284-285` — insufficient cash
- `GameState.gd:295-296` and `:332-333` — refused rush on a frozen property
- `EpochState.gd:88-89` — refused epoch advance
- `GameState.gd:463-464` — frenzy pop refused

Note also that most denials never reach code at all: the buttons are pre-disabled
(`PropertyRow.gd:1610`, `:1459`, `Main.gd:1129`), and a disabled Godot button emits
nothing. A denial sound would need a `gui_input` hook on the disabled control. Combined
with the no-moving-UI principle (controls stay visible and gray), that is a real design
question, not just plumbing — which is a good reason it is deferred.

### 4.6 UI sounds (decision 15)

In scope: tab switches (`Main.gd:1759 _show_tab`), overlay open/close, buy-mode and
hire-mode toggles (`Main.gd:2576 _on_buy_mode_toggled`), the OVERDRIVE button
(`MomentumBar.gd:260`), MAKE CONTACT (`Main.gd:1116`), FRENZY pop
(`FrenzyBar.pop_requested`).

Out of scope: scrolling, coach-card dismissal, settings toggles, slider drags.

---

## 5. The overdrive layer (decision 9)

This is the most novel part of the system and the one place audio can change how well
someone plays.

### 5.1 Continuous heat tone

`RushMomentumState.gd:196 var heat` is the source. **There is no stored normalized form** —
the view computes it: `MomentumBar.gd:491` uses `heat / hard_ceiling` in overdrive and
`:504` uses `heat / cruise` in cruise. Heat 1.0 is the *band boundary*, not the ceiling.

`Audio.set_heat(normalized)` should be driven from `MomentumBar`'s existing per-frame
update, reusing the value it already computes — do not recompute normalization in the audio
layer, or the tone and the bar can disagree, and the project's stated invariant is that
what the bar shows *is* what the player gets.

Tone behavior:
- Base drone, `pitch_scale` mapped across ~a fifth from heat 0 → ceiling.
- An **urgency layer** (second stream) fading in over the top ~25% of the band, so the
  approach to overheat is audible before it is visible.
- Fades in on `engage_overdrive()` (`RushMomentumState.gd:814`) and out on
  `overheated` / `rush_ready`.
- **Cruise has no signal** — `is_cruising()` (`:835`) is polled per frame by the UI
  (`MomentumBar.gd:468`). The heat layer follows the same polling; a distinct, calmer
  timbre for cruise vs overdrive makes the choice between them audible, which supports the
  measured design intent that cruise is a genuine alternative (+24.9% vs +68.7%).

### 5.2 Vent cues

All signals already exist on `RushMomentumState`:

| Signal | Decl | Audio |
|---|---|---|
| `vent_incoming(approach_seconds, required_lifts)` | `:159` | Pulse train, **in lockstep with `MomentumBar.gd:893 _pulse_vent_telegraph`** — one audible tick per required lift, same timing as the haptic |
| `vent_window_opened(required_lifts, duration)` | `:163` | The "now" cue. This is the single most important sound in the game |
| `vent_lift_registered(lifts_done, required_lifts)` | `:166` | Ascending confirmation per lift — the player hears progress toward the requirement |
| `vent_succeeded(new_tier, new_peak_bonus)` | `:170` | Reward sting, intensity scaled by new tier |
| `vent_missed(lifts_done, required_lifts)` | `:175` | Fires just before overheat — the "you blew it" beat |
| `overheated(ended_vent_tier)` | `:185` | Failure thud; heat layer fades out |
| `rush_ready` | `:190` | Re-arm chime; system is live again |

The pulse-train lockstep is a hard requirement, not a nicety: `_pulse_vent_telegraph` fires
at **spawn**, not window-open (rationale documented at `MomentumBar.gd:768-776`), and
audio that fires at a different moment than the haptic would actively mislead.

### 5.3 Music interaction

Duck `Music` by ~4 dB while the heat layer is active. The urgency layer belongs to the
Music bus (not SFX) so the music slider controls it — a player who turned music off is
saying they want the game quiet, and a continuous drone would violate that.

---

## 6. Settings

### 6.1 The blocker: the settings tab overflows

`Main.gd:1543-1548` carries an explicit warning: the settings page is a plain
`VBoxContainer`, **not** a `ScrollContainer`, so content that does not fit is not clipped —
it is **unreachable**. The spacer's `EXPAND_FILL` collapses first, which hides the problem
until something is genuinely off-screen. Adding the currency-format card already forced
pairing CHALLENGES+STATS and ABOUT+HELP onto shared rows to recover 308 px.

**An audio card with three sliders will overflow it again.**

**Required first step:** wrap the settings page (`Main.gd:1438`, assigned at `:1612`) in a
`ScrollContainer`. This is the file's own recommended fix, recorded in its comments, and it
should land as its own small commit before the audio card — a layout change and an audio
feature failing together is two bugs wearing one trenchcoat.

### 6.2 The audio card

Copy `Main.gd:1501-1539` (currency-format card). Heading "SOUND", three labeled
`HSlider` rows: MUSIC, SOUND EFFECTS, HAPTICS.

Per the UI readability principle (large text, large tappable targets — Tim is 49 with
imperfect vision), sliders need generous grabber size and row height; a thin default
`HSlider` is not acceptable. Each row shows a percentage value so the setting is legible
without judging a knob position.

Each slider plays a short preview sound from its own bus on release — the only way to set
a volume is to hear it.

### 6.3 Haptics slider

Not a bus. It scales the existing `TuningConfig` haptic durations, all read by
`MomentumBar._vibrate()`:

- `TuningConfig.gd:460 rush_momentum_haptic_overheat_ms = 200.0`
- `:461 rush_momentum_haptic_ready_ms = 40.0`
- `:468 rush_momentum_haptic_vent_ms = 80.0`
- `:473 rush_momentum_haptic_vent_gap_ms = 70.0`

A multiplier at 0.0 drives durations below the `>= 1.0` guard in `_vibrate()`, so
**zero disables haptics for free** with no new branch — this is exactly the property §2.1
called out. Note `export_presets.cfg:82` documents the Android VIBRATE permission.

### 6.4 Persistence — the succession trap

**This is the one that will bite.** `DynastyState.gd:420 _carry_player_settings_to_heir`
carries exactly three settings today:

```gdscript
heir.ui_buy_mode = current.ui_buy_mode                    # :423
heir.ui_minigame_enabled = current.ui_minigame_enabled    # :424
heir.ui_currency_format = current.ui_currency_format      # :425
```

`DynastyState._new_generation()` builds a **brand-new `GameState`**, so anything parked
there as a player choice silently reverts to its default every prestige. It hides because
`Main` keeps its own UI mirrors — the controls keep showing the old value while `GameState`
has already reverted, and the loss only surfaces on the next launch. `ui_buy_mode` and
`ui_minigame_enabled` both dropped this way for months before it was caught on 2026-08-05.

**Therefore:** every audio setting added to `GameState` (`ui_music_volume`,
`ui_sfx_volume`, `ui_haptics_scale`) must be added to `_carry_player_settings_to_heir` at
`:425` **in the same commit**, serialized at `GameState.gd:523-524`, loaded at `:566-571`,
and applied at `Main.gd:493` alongside `Money.format_mode`.

Add an assertion to the test suite that the count of persisted UI settings equals the count
carried to the heir. That is the check that would have caught the original bug, and it will
catch the next one.

**No `SAVE_VERSION` bump** — new keys default sensibly when absent, same as the currency
format change.

---

## 7. Asset sourcing (decision 3)

### 7.1 SFX

Target ~25–30 samples for the full system, ~8 for the first slice.

Candidate sources, all with licenses compatible with a commercial release — **verify each
license at download time; do not trust this list as legal advice**:

| Source | Nature | Fit |
|---|---|---|
| **Kenney.nl** (CC0) | Clean UI/game SFX packs, public domain | Best starting point for UI + confirmation blips. CC0 = zero attribution burden |
| **Sonniss GDC bundles** (royalty-free) | Very large annual free bundles from pro libraries | Best source for foley/period material: cash registers, typewriters, adding machines |
| **freesound.org** | Mixed licenses | Excellent for specific period items; **must filter to CC0/CC-BY and track attribution per file** |
| **itch.io asset packs** | Mixed, often cheap | Good for cohesive small sets |
| **ZapSplat / Soundly free tier** | Royalty-free with attribution | Broad coverage |

Period-appropriate SFX shopping list — the mid-century vocabulary does the theming work:

- Mechanical cash register (purchase), adding-machine / typewriter clack (tap scale base),
  bell ding (milestone), telephone-switchboard click (tab), rubber stamp (confirmation),
  paper shuffle (auto-purchase — sourced but *unused* in v1, kept for the settings-toggle
  option if it ever returns), vacuum-tube hum (heat layer), theremin sweep (alien beats),
  slide-projector advance (epoch arrival).

**Maintain `game/audio/CREDITS.md`** from the first sourced file, listing every asset with
its source, license, and required attribution. Retrofitting attribution across 30 files
sourced over three months is miserable; doing it as you go is free.

### 7.2 Music — the risk

Decision 18 ("same melody, alien instruments") means the tracks **cannot be five unrelated
library pieces**. Options, in order of preference:

1. **One melody, five arrangements.** Commission or self-produce. Best result, most effort.
   A single ~60–90 s muzak melody re-instrumented five ways is a tractable brief for a
   freelance composer and is where the money in this project's audio budget should go.
2. **Library track with shipped variants.** Some production-music libraries ship the same
   cue in multiple instrumentations. Rare for this specific style, worth a search.
3. **Fallback: five related library tracks + a shared motif sting.** Give up the
   "same melody" joke in the loops, but preserve it in a short 3–5 note motif that appears
   in the epoch-arrival sting for every band, re-instrumented. Cheap, keeps the idea
   audible, and it is the option that most likely ships.

**Recommendation:** build the system against option 3 so the game is shippable, and treat
option 1 as an upgrade that requires no code changes (swap five files in
`audio_events.tres`). The architecture must not care which one you chose.

### 7.3 Format and footprint

- Music: **Ogg Vorbis**, mono or joint-stereo, ~96–112 kbps. A 90 s loop ≈ 1.2 MB.
  Five bands ≈ 6 MB.
- SFX: **WAV**, 44.1 kHz, mono, imported to the project. Individually tiny; ~30 samples
  ≈ 2–3 MB.
- **Target total ≈ 10 MB.** Decision 16 named CPU/battery rather than size as the
  constraint, so this is a sanity ceiling, not a hard budget.

---

## 8. Phasing (decisions 12, 14)

Each phase is independently mergeable, device-testable, and leaves the game in a shippable
state. Branch names follow the project's `feature/**` convention (every push builds and
ships a Firebase APK).

### Phase 0 — `feature/settings-scrollcontainer`
Wrap the settings page in a `ScrollContainer` (§6.1). No audio. Small, isolated, unblocks
everything downstream. Ship and device-check that nothing reflowed.

### Phase 1 — `feature/audio-core-slice` ← **the vertical slice (decision 14)**
The whole path, end to end, for exactly three events.

- `Audio` autoload + bus layout + voice pool + `audio_events.tres`
- Focus handling (§3.4) and the muted-costs-nothing path
- The settings card, all three sliders, persistence **including
  `_carry_player_settings_to_heir`** (§6.4)
- `TuningConfig` `audio_*` knobs + `DevTuningPanel` SECTIONS entry
- **Three sounds only:** the tap scale, purchase-succeeded (relative-scaled), and
  aggregated collect
- The `BuySource` enum refactor (§4.4) — needed now, because the collect and hold-repeat
  rules depend on it

**Exit criterion:** Tim plays 20 minutes on device and judges whether the core loop feels
better with sound than without. This is the decision point for everything after it. If the
tap scale is annoying at minute 15, that is a finding worth the whole phase.

### Phase 2 — `feature/audio-music`
Five band tracks, band mapping, crossfades, idle fade (§3.3), ceremony-safe transition
rule. Music slider becomes meaningful.

**Exit criterion:** a multi-epoch device session without music fatigue.

### Phase 3 — `feature/audio-overdrive`
Continuous heat tone, urgency layer, all vent cues in lockstep with the haptic pulse train,
cruise-vs-overdrive timbre split, music ducking.

**Exit criterion:** Tim can hit vent windows with the screen dimmed / not looking directly
at the bar. That is the test that proves the feature.

### Phase 4 — `feature/audio-ceremony`
Succession/obituary (`WillScreen.gd:285` `show_obituary`, `:317` `show_will`, `:341`
`show_heir_reveal`), First Contact / epoch arrival (`FirstContactOverlay.gd:248
show_contact`, reveal `:321`, typewriter `:418`), Legacy upgrade purchase
(`LegacyScreen.purchased` → `Main.gd:2382`). Music ducking per beat. Welcome-back overlay
(`WelcomeBackOverlay.gd:237 show_pile`) gets a return-spike cue.

**Exit criterion:** a full succession on device feels like an event.

### Phase 5 — `feature/audio-ui-polish`
Tabs and major actions (§4.6). Mix pass across all buses at once — the first time all
content exists together is the first time the mix can actually be judged.

**Deferred, explicitly:** denial sounds (§4.5), Final Dollar (M4, not built).

---

## 9. Testing

- **Headless gates must not regress.** `MoneyTest`, `EpochTest`, `AutoPurchaseTest` run
  without a display; the `Audio` autoload must no-op cleanly with no audio device. Guard
  on `OS.has_feature("mobile")` / audio-device availability inside `Audio`, exactly as
  `_vibrate()` does — not at call sites.
- **New: `sim/AudioSettingsTest.gd`** asserting that the set of UI settings persisted in
  `GameState` equals the set carried by `_carry_player_settings_to_heir`. This is the
  regression test for the bug class described in §6.4, and it protects the three existing
  settings too.
- **Device checklist additions** (`Plans/Device_Feel_Test_Checklist.md`):
  - 20-minute continuous session — is the tap scale still pleasant?
  - Background/foreground the app mid-rush — does audio recover?
  - Prestige — do volume settings survive succession? (the §6.4 trap, verified by hand)
  - Wide portfolio at deep tiers — does aggregated collect stay clean at dozens of
    payouts/sec?
  - Battery draw over 30 minutes, audio on vs off
  - All sliders at zero — is the game genuinely silent, and does it still run correctly?

---

## 10. Open questions for Tim

1. **Music sourcing route (§7.2)** — commission one melody with five arrangements, or ship
   the fallback (five related tracks + a shared re-instrumented motif sting)? This is the
   only decision with real money attached and it does not block Phase 1.
2. **Tap scale on the wage button specifically** — the wage tap has a hold-to-auto-tap
   mode (`wage_hold_tapped`). Should a *held* wage climb the scale, or hold at one note?
   Climbing rewards holding, which may be the opposite of the intent.
3. **Does the tap scale reset on tab change?** Leaning yes — a scale that resumes mid-climb
   after you did something else feels like a bug.
4. **Denial sounds** — deferred per decision 15, but the disabled-button problem (§4.5)
   interacts with the no-moving-UI principle. Worth revisiting once the rest ships and you
   can hear what is missing.
5. **Ceremony vs SFX slider grouping (§1.2)** — Ceremony currently rides the SFX slider.
   If someone turns SFX off, should the succession still have sound? Arguably yes; it is a
   story beat, not feedback.
