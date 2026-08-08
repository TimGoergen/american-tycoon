# Audio credits and licenses

Every audio file in `game/audio/` gets a line here, with its source, license, and any required
attribution — added **when the file is added**, not later. Retrofitting attribution across thirty
files sourced over three months is miserable; doing it as you go is free
(`Plans/Audio_System.md` §7.1).

If a file is here, it is cleared for a commercial release. If you cannot write its line, do not
commit it.

## Current files

| File | Source | License | Attribution required |
|---|---|---|---|
| `sfx/tap_note.wav` | Generated — `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |
| `sfx/buy_success.wav` | Generated — `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |
| `sfx/buy_success_bright.wav` | Generated — `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |
| `sfx/collect.wav` | Generated — `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |
| `sfx/music_preview.wav` | Generated — `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |

**These are placeholders.** They are synthesized sine tones with amplitude envelopes, written
directly as PCM by the script above — no sampled or third-party material of any kind, so there is
nothing to license and nothing to attribute. They exist so Phase 1 can be judged on a device; the
timing and pitch relationships are real even though the tone quality is plain.

## When sourcing real samples

Verify the license **at download time** and write the row immediately. Do not trust a summary
elsewhere in the plan docs, including this project's own — those are notes, not legal advice.

Watch for the two that are easy to get wrong:

- **CC-BY requires attribution in the shipped game**, not just in this file. The About screen is
  where that lands.
- **"Free" on an asset site frequently means free for non-commercial use.** This game is intended
  for release, so non-commercial licenses are unusable no matter how good the sample is.
