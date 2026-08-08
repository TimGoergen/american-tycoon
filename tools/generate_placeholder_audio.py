"""Generate the placeholder SFX for American Tycoon's audio system.

WHY THIS EXISTS
---------------
The audio plan (Plans/Audio_System.md) sources its real samples from licensed/CC0 libraries, but
Phase 1's whole point is a device test: does the core loop FEEL better with sound? That question
cannot be answered by a silent build, and it does not need finished art to answer -- it needs the
timing, the pitch relationships, and the mix to be real.

So these are synthesized: simple decaying tones written straight to 16-bit PCM. They are deliberately
plain. When sourced samples arrive they replace these by editing game/config/audio_events.tres --
no code changes, which is exactly the property the plan's architecture was built for.

The tap sound in particular is worth understanding: the game pitch-shifts ONE sample across a
pentatonic scale at runtime, so a pure-ish tone is not a compromise here, it is the right shape. A
recorded typewriter clack would be pitch-shifted the same way.

USAGE
-----
    python tools/generate_placeholder_audio.py

Writes .wav files into game/audio/sfx/. Safe to re-run; it overwrites.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
# Peak amplitude for a generated sample, as a fraction of full scale. Deliberately well below 1.0:
# these get mixed together (a tap can land on top of a purchase on top of a collect) and per-event
# volumes in audio_events.tres trim further. Headroom now is cheaper than clipping later.
PEAK = 0.5

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio", "sfx")

# Equal-temperament note frequencies used below, so the tones sit in a real scale rather than on
# arbitrary numbers. A4 = 440.
NOTES = {
    "G4": 392.00,
    "C5": 523.25,
    "E5": 659.25,
    "G5": 783.99,
    "C6": 1046.50,
    "E6": 1318.51,
}


def envelope(position, total, attack_seconds=0.004, curve=4.0):
    """Amplitude multiplier at `position` of `total` samples.

    A short attack ramp avoids the click a hard start produces (a waveform jumping from silence to
    full amplitude in one sample is a broadband transient -- audible, and unpleasant on small phone
    speakers). The tail is an exponential-ish decay to exactly zero, so the end does not click either.
    """
    attack_samples = max(1, int(attack_seconds * SAMPLE_RATE))
    if position < attack_samples:
        return position / attack_samples
    remaining = 1.0 - (position - attack_samples) / max(1, total - attack_samples)
    return max(0.0, remaining) ** curve


def tone(frequency, seconds, harmonics=(1.0,), curve=4.0, attack=0.004):
    """One decaying tone. `harmonics` gives the relative level of each partial (1st, 2nd, 3rd...)."""
    total = int(seconds * SAMPLE_RATE)
    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        value = 0.0
        for index, level in enumerate(harmonics):
            value += level * math.sin(2.0 * math.pi * frequency * (index + 1) * t)
        samples.append(value * envelope(i, total, attack, curve))
    return samples


def sequence(parts):
    """Lay tones onto one timeline at given offsets: [(offset_seconds, samples), ...]."""
    length = max(int(offset * SAMPLE_RATE) + len(chunk) for offset, chunk in parts)
    out = [0.0] * length
    for offset, chunk in parts:
        start = int(offset * SAMPLE_RATE)
        for i, value in enumerate(chunk):
            out[start + i] += value
    return out


def write_wav(name, samples):
    """Normalize to PEAK and write 16-bit mono PCM."""
    loudest = max(abs(value) for value in samples) or 1.0
    scale = PEAK / loudest
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767)) for value in samples)

    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)
    print("wrote %s (%.0f ms)" % (name, 1000.0 * len(samples) / SAMPLE_RATE))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # TAP -- the note the pentatonic scale plays. Authored at C5, the ROOT of the scale, because the
    # game pitch-shifts up from here; shifting mostly upward keeps the artifacts on the bright side
    # where they are less obvious than the muddy ones you get shifting down a long way.
    write_wav("tap_note.wav", tone(NOTES["C5"], 0.14, harmonics=(1.0, 0.28, 0.08), curve=5.0))

    # PURCHASE -- a rising two-note confirmation. Rising because a purchase is a step forward; the
    # collect blip below deliberately does not rise, so the two never sound like the same event.
    write_wav("buy_success.wav", sequence([
        (0.000, tone(NOTES["G5"], 0.16, harmonics=(1.0, 0.35, 0.12), curve=4.0)),
        (0.085, tone(NOTES["C6"], 0.34, harmonics=(1.0, 0.30, 0.10), curve=3.0)),
    ]))

    # PURCHASE, BRIGHT LAYER -- mixed in ABOVE the base sample for a big relative gain, never
    # replacing it. Same two notes an octave up plus a third, so it reads as "more of that", not as a
    # different sound. (Intensity drives volume and layering, never pitch -- pitch belongs to the tap
    # scale and the two must not collide.)
    write_wav("buy_success_bright.wav", sequence([
        (0.000, tone(NOTES["E6"], 0.14, harmonics=(1.0, 0.4, 0.2, 0.1), curve=4.0)),
        (0.085, tone(NOTES["C6"] * 2.0, 0.30, harmonics=(1.0, 0.35, 0.15), curve=3.0)),
    ]))

    # COLLECT -- soft, low, short. This one plays most often, so it is the one most able to become
    # irritating: no rise, few harmonics, and short enough to sit under everything else.
    write_wav("collect.wav", tone(NOTES["G4"], 0.09, harmonics=(1.0, 0.15), curve=6.0))

    # MUSIC SLIDER PREVIEW -- a small arpeggiated major chord standing in for the muzak of Phase 2.
    # The music slider needs something on the Music bus to audition, or it is a knob with no feedback.
    write_wav("music_preview.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.55, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
        (0.090, tone(NOTES["E5"], 0.50, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
        (0.180, tone(NOTES["G5"], 0.48, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
    ]))


if __name__ == "__main__":
    main()
