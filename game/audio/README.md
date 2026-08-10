# Audio cues — the complete list

**This file is generated.** Edit `CUES` in `scripts/audio/Audio.gd` (and `TRIGGERS` in
`sim/AudioCueDoc.gd` for the descriptions), then re-run:

    godot --headless --path . --script res://sim/AudioCueDoc.gd

## How a sound gets into the game

Name the file after the cue and put it in the right folder. That is the whole process — there is no
manifest to edit, and nothing else to change.

| Kind | Folder | Named |
|---|---|---|
| One-shot cues | `res://audio/cues/` | `<cue id>.ogg` |
| Continuous layers | `res://audio/loops/` | `heat_loop.ogg`, `urgency_loop.ogg` |
| Music tracks | `res://audio/music/` | one per era band — see below |

**`.ogg` or `.wav`.** `.ogg` is tried first, so a sourced track always beats a placeholder of the
same name; you do not have to delete the old file, though you may.

**Variants.** Add `<cue id>_1`, `_2`, up to `_4` and the game picks one at random per play. Use it
on anything heard constantly — the tap and the purchase are the obvious candidates. A single
unnumbered file is perfectly fine and is what everything ships with today.

**Layers.** A cue marked *layered* below also looks for `<cue id>_layer`, mixed in ON TOP of the base
sample when the moment is a big one. It never replaces it.

**A missing file is not an error.** The cue simply makes no sound, and the game logs one line at
startup listing everything still unrecorded. That is what lets the whole design exist before any of
it has been recorded — every cue in this document already has a hook and a generated placeholder.

## The cues

Bus decides which slider governs a sound, and whether it counts as the player being *present* (SFX and UI do; Ceremony and Music do not).

### The core loop

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `tap_note` | SFX | -6 | 45 ms | Tapping CLOCK IN, or tapping a property whose cycle is already running (a rush). Pitched by the game across a pentatonic figure — see the note below. |
| `buy_success` + `buy_success_layer` | SFX | -3 | 60 ms | A property purchase completes. Volume scales with how much the buy moved your income; a `_layer` sample is mixed in on top for a big jump. |
| `hire_first` | SFX | -3 | 60 ms | The FIRST staffer on a property — the moment it starts running itself. |
| `hire_levelled` | SFX | -7 | 60 ms | Any later staff level on a property that is already staffed. |
| `retain_staff` | SFX | -6 | 60 ms | Buying staff retention in the Estate screen. |
| `milestone` | SFX | -2 | 200 ms | A property crosses a count milestone (25, 50, 100 …). Fires on the crossing. |
| `cycle_started` | SFX | -12 | 60 ms | Tapping a STOPPED property to start one cycle by hand. Deliberately not part of the tap scale — it is the machine turning over, not a payout. |
| `frenzy_pop` | SFX | -2 | 300 ms | Popping the FRENZY meter. |
| `frenzy_end` ⚠ | SFX | -10 | 300 ms | A frenzy burn runs out. NO HOOK YET — the core has no signal for it; see the note below. |

### Rush and overdrive

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `overdrive_engage` | SFX | -3 | 200 ms | The OVERDRIVE button, but only when the ride actually starts (the core refuses while auto-buy is on, or during a lockout). |
| `vent_tick` | SFX | -12 | 10 ms | One per required lift, counted out the instant the vent WINDOW opens. |
| `vent_open` | SFX | -1 | 100 ms | A vent window opens. The most important sound in the game — it is what makes the gesture playable without watching the bar. |
| `vent_lift` | SFX | -6 | 10 ms | Each lift registered inside the window. Pitched up one whole tone per lift, so progress is audible. |
| `vent_success` + `vent_success_layer` | SFX | -2 | 100 ms | A vent completes in time. Intensity scales with the vent tier reached. |
| `vent_miss` | SFX | -4 | 100 ms | The window closes unmet — fires just before the overheat. |
| `overheat` | SFX | -2 | 200 ms | The ride ends in flames. Heat drains, rushing is locked out. |
| `rush_ready` | SFX | -8 | 100 ms | The lockout ends and rushing is live again. |

### Interface

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `tab_switch` | UI | -10 | 60 ms | Changing tab, and only when the tab actually changes. |
| `screen_open` | UI | -9 | 100 ms | Opening a modal screen: ABOUT, STATS, CHALLENGES, HELP, or either tuning panel. |
| `screen_close` | UI | -11 | 100 ms | Closing one of those screens. |
| `mode_toggle` | UI | -12 | 50 ms | The buy-mode or hire-mode toggle. |
| `epoch_page` | UI | -12 | 50 ms | The epoch pager moves to another civilization, and only on an actual page change. |
| `make_contact` | UI | -1 | 400 ms | The MAKE CONTACT button — the biggest button in the game. |
| `tip_appear` | UI | -12 | 200 ms | A tutorial coach card appears. Only when one is actually shown. |

### Denials (reserved)

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `denied_cash` ⚠ | UI | -10 | 250 ms | Reserved: an action refused for want of money. NO HOOK YET — deferred by decision 15. |
| `denied_locked` ⚠ | UI | -10 | 250 ms | Reserved: an action refused because something is locked. NO HOOK YET — deferred by decision 15. |

### Challenge Mode

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `challenge_start` | UI | -6 | 200 ms | Launching a game from the CHALLENGES screen. |
| `challenge_credit` | Ceremony | -4 | 400 ms | A challenge run ends and its score is credited. |
| `challenge_tier` | Ceremony | -3 | 400 ms | A challenge run climbs a tier of its ladder, mid-run. |

### Minigames — the shared beats

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `minigame_begin` | UI | -4 | 200 ms | BEGIN on a minigame's Get Ready gate — the round starts. |
| `minigame_score` | SFX | -8 | 40 ms | The player scores in any minigame. Fired from the shared score tracker, so it covers all six games without any of them knowing about it. |
| `minigame_miss` | SFX | -7 | 80 ms | A miss that costs challenge time — the one miss every game already reports through a shared channel. |
| `minigame_countdown` | UI | -9 | 250 ms | One per second over the last few seconds of the clock, on the same tick the timer pops. |
| `minigame_best` | Ceremony | -3 | 500 ms | The run passes the stored high score. Once per run. |
| `minigame_over` | UI | -4 | 500 ms | A round or challenge run ends. |

### Basketball

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `bball_grab` | SFX | -16 | 60 ms | A finger takes the ball and the slingshot drag begins. |
| `bball_launch` | SFX | -6 | 60 ms | The throw is released. Scaled by the SAME pull force the aim wedge shows, so a lob and a cannon shot sound as different as they look. |
| `bball_fizzle` | SFX | -14 | 80 ms | Released under the minimum pull — not a throw; the ball just drops. |
| `bball_wall` | SFX | -12 | 40 ms | The ball bounces off a side wall or the ceiling. Scaled by impact speed. |
| `bball_floor` | SFX | -11 | 40 ms | The ball lands on the floor. Scaled by impact speed. |
| `bball_settle` | SFX | -18 | 120 ms | The ball stops rolling and becomes throwable again. |
| `bball_rim` | SFX | -8 | 50 ms | Clipping a rim post — the rim-out. |
| `bball_score` | SFX | -5 | 120 ms | A made basket. LAYERS over the shared `minigame_score`. |
| `bball_swish` | SFX | -3 | 120 ms | A clean centred drop — the gold SWISH! Also layers over `minigame_score`. |
| `bball_gem_through` | SFX | -8 | 120 ms | The ball passes through the Legacy gem. A promise, not yet a payout. |
| `bball_gem_earned` | Ceremony | -4 | 400 ms | The shot that passed through the gem also scored — the game's rarest outcome, and the only one that pays Legacy. |

### Ceremony — the story beats

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `ceremony_obituary` | Ceremony | -3 | 800 ms | The succession's obituary card. |
| `ceremony_will` | Ceremony | -6 | 800 ms | The reading of the will. |
| `ceremony_heir` | Ceremony | -2 | 800 ms | The heir reveal — the bloodline continues. |
| `ceremony_contact` | Ceremony | -4 | 800 ms | A First Contact card opens. |
| `ceremony_contact_reveal` | Ceremony | -2 | 800 ms | The civilization's name lands on that card. Fired from the reveal timeline, so it cannot drift. |
| `legacy_purchase` | Ceremony | -6 | 300 ms | Buying a Legacy upgrade in the Estate shop. |
| `welcome_back` | Ceremony | -4 | 800 ms | The welcome-back pile after time away. |
| `prestige_confirm` | Ceremony | -2 | 800 ms | PASS THE TORCH is confirmed, just before the succession screens take over. |

### Settings

| Cue / filename | Bus | dB | Cooldown | Fires when |
|---|---|---|---|---|
| `music_preview` | Music | -4 | 200 ms | Releasing the MUSIC slider in Settings. |

⚠ = the sound and the file slot exist, but nothing calls it yet.

## Music

One track per era band, in `res://audio/music/`:

| File | Tiers | Character |
|---|---|---|
| `band_0_blue_collar.ogg` | 1 | Earth, Blue Collar — department-store muzak, thin arrangement. |
| `band_1_white_collar.ogg` | 2 | Earth, White Collar — the **same tune**, fuller. The promotion should be audible. |
| `band_2_early_contact.ogg` | 3–11 | Early contact — the melody survives; instrumentation goes theremin/synth. |
| `band_3_mid.ogg` | 12–19 | Mid — fewer Earth instruments left. Odd intervals creep in. |
| `band_4_deep.ogg` | 20–27 | Deep — recognizable, but barely of this world. |

Ogg Vorbis, 96–112 kbps, mono or joint stereo. **It must loop seamlessly** — the game sets the loop
flag, so the file has to end where it begins.

The game crossfades between bands over 2 seconds, and never during a ceremony: the change waits until
the First Contact card is dismissed. It fades the music out after a long idle and brings it back when
you next act, and ducks it 4 dB while a rush is on. A band with no file keeps the current track
playing rather than cutting to silence, so tracks can arrive one at a time.

## Deliberately silent

| Event | Why |
|---|---|
| `auto_purchase` | The Acquisitions Desk buys without the player, and unattended events stay silent. It cannot even reach a hook — the desk buys inside the core, which never touches the audio layer. |
| `cycle_payout` | A cycle completing was built, heard, and removed: *"only when the user taps to purchase"*. |

## Two sounds the game pitches itself

Do not add pitch variance to either, and do not record them with vibrato — the game is doing the
tuning, and a wobble on top is simply out of tune.

- **`tap_note`** is played across a two-octave pentatonic figure that rises and falls, with the
  window drifting up the scale as a run continues. Record it as ONE note; C5 is what the placeholder
  uses. It is pitched from there in both directions.
- **`vent_lift`** steps up a whole tone per lift within a window, so the count is audible.

## The minigames

**Basketball is done; the other five are not.** The six games share the beats above — begin, score, miss, countdown, new best, over — and each
game's own vocabulary (a swish, a match, a caught coin, a flipped pad) is a LATER PASS, deliberately.
Getting the shared layer right first means every game already sounds like it belongs to this game
before any of them sounds like itself.

**The soundtrack stops entirely while a minigame is up**, rather than ducking. A minigame owns the
whole screen, sets its own pace, and its own sounds are fast and small; an era track underneath would
fight all three. The band is remembered, so returning restores the same track.

## Credits

Every sourced file needs a row in `CREDITS.md` **when it is added**, with its licence. If you cannot
write the row, do not commit the file.
