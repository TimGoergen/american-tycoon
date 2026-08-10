# Audio credits and licenses

Every audio file in `game/audio/` gets a line here, with its source, license, and any required
attribution — added **when the file is added**, not later. Retrofitting attribution across thirty
files sourced over three months is miserable; doing it as you go is free
(`Plans/Audio_System.md` §7.1).

If a file is here, it is cleared for a commercial release. If you cannot write its line, do not
commit it.

## Current files

**Everything in `cues/`, `loops/` and `music/` today is a generated placeholder** — synthesized sine
tones written directly as PCM by `tools/generate_placeholder_audio.py`. No sampled or third-party
material of any kind, so there is nothing to license and nothing to attribute.

They exist so the whole audio design could be built and heard before a note was sourced. See
`README.md` for the full cue list and what to name a replacement.

| Source | Licence | Attribution |
|---|---|---|
| `tools/generate_placeholder_audio.py` | Original work, no third-party content | No |

## Music

Tracks live in `music/`, one per era band — see `music/README.md` for names, format and what the
game does with them. The five files there now are generated placeholders, not music.

## When sourcing real samples

Verify the license **at download time** and write the row immediately. Do not trust a summary
elsewhere in the plan docs, including this project's own — those are notes, not legal advice.

Watch for the two that are easy to get wrong:

- **CC-BY requires attribution in the shipped game**, not just in this file. The About screen is
  where that lands.
- **"Free" on an asset site frequently means free for non-commercial use.** This game is intended
  for release, so non-commercial licenses are unusable no matter how good the sample is.
