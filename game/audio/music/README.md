# Music tracks — what to name them and where they go

One file per era band. Drop it in **this folder** with the exact name below and the game picks it up
on the next run; nothing else needs changing.

| File | Band | Epoch tiers | What it is |
|---|---|---|---|
| `band_0_blue_collar.ogg` | 0 | tier 1 | Earth, Blue Collar. Department-store muzak, thin arrangement — small speakers, small ambitions. |
| `band_1_white_collar.ogg` | 1 | tier 2 | Earth, White Collar. The **same tune**, fuller. Strings arrive. The promotion should be audible. |
| `band_2_early_contact.ogg` | 2 | tiers 3–11 | The melody survives; the instrumentation goes theremin/synth. |
| `band_3_mid.ogg` | 3 | tiers 12–19 | Fewer Earth instruments left. Odd intervals creep in. |
| `band_4_deep.ogg` | 4 | tiers 20–27 | The melody is still recognizable, but barely of this world. |

## Format

- **Ogg Vorbis**, mono or joint stereo, **96–112 kbps**. A 90-second loop lands around 1.2 MB, so all
  five come to roughly 6 MB — the plan's whole audio budget is ~10 MB.
- **Make it loop seamlessly.** The game sets the loop flag itself, so the file just has to end where
  it begins — no gap of silence at either end, and ideally a musical phrase that closes onto its own
  first beat.
- Length is up to you. 60–90 seconds is the usual range for this kind of loop; shorter starts to
  announce itself.

## `.wav` also works

The loader tries `.ogg` first and falls back to `.wav` of the same name. That is how the generated
placeholders currently in this folder work — they are 8-second chord loops, and they exist only so
the band changes, crossfades, idle fade and ducking could be built and heard before real music
existed. **Delete a placeholder once its real track lands**, or leave it: the `.ogg` wins either way.

## A missing track is not an error

If a band has no file, the game keeps playing whatever was already on rather than cutting to silence,
and logs a warning. So the tracks can arrive one at a time.

## What the game does with them

- **Crossfades over 2 seconds** on a band change, and never mid-ceremony — the change waits until the
  First Contact overlay is dismissed, so a new track's first bar cannot land under that beat's sting.
- **Fades out after a long idle** and returns when the player next acts. An active overdrive ride
  counts as being present, so the music never drops out mid-rush.
- **Ducks by 4 dB** while a rush is on, so the overdrive layer sits on top of it.
- Rides the **Music bus**, so the player's Music slider governs it (and the overdrive drone with it).

## The one open decision

`Plans/Audio_System.md` §7.2: five *related* library tracks plus a shared motif sting is the cheap
route and what this is built against. One melody re-arranged five ways is the better joke — the same
tune on impossible instruments — and costs money. The architecture does not care; it is a file swap.

Record every sourced file in `../CREDITS.md` **when you add it**, with its licence.
