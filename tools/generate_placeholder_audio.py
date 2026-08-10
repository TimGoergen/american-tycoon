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
# these get mixed together (a tap run can land on top of a purchase) and per-event
# volumes in audio_events.tres trim further. Headroom now is cheaper than clipping later.
PEAK = 0.5

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio", "sfx")

# Equal-temperament note frequencies used below, so the tones sit in a real scale rather than on
# arbitrary numbers. A4 = 440.
NOTES = {
    "A2": 110.00,
    "E3": 164.81,
    "A3": 220.00,
    "C4": 261.63,
    "E4": 329.63,
    "A4": 440.00,
    "A5": 880.00,
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


def seamless_loop(frequency, seconds, harmonics=(1.0,), tremolo_hz=0.0, tremolo_depth=0.0):
    """A LOOPING tone with no click at the seam.

    A loop clicks unless the waveform arrives back at its exact starting phase. So the buffer length
    is fixed first, and then the FREQUENCY is nudged to whichever nearby value fits a whole number of
    cycles into that buffer. Every harmonic is an integer multiple of it, so they all land on the
    seam too, and the tremolo gets a whole number of its own cycles for the same reason.

    THE WRONG WAY, which shipped on 2026-08-09 and clicked once a second: round the PERIOD to whole
    samples and multiply up. A period of 400.909 samples rounded to 401 puts the buffer 0.02 cycles
    past the seam, and at 110 Hz that is a jump of thirty times a normal sample-to-sample step —
    inaudible as a pitch error, obvious as a crackle (Tim: "there are crackles in it"). The seam is
    now asserted numerically at the bottom of this file rather than assumed.
    """
    total = int(round(seconds * SAMPLE_RATE))
    cycles = max(1, round(frequency * total / SAMPLE_RATE))
    frequency = cycles * SAMPLE_RATE / total       # the nearest exactly-loopable frequency
    tremolo_cycles = max(1, round(tremolo_hz * total / SAMPLE_RATE)) if tremolo_hz > 0 else 0

    samples = []
    for i in range(total):
        t = i / SAMPLE_RATE
        value = 0.0
        for index, level in enumerate(harmonics):
            value += level * math.sin(2.0 * math.pi * frequency * (index + 1) * t)
        if tremolo_cycles:
            phase = 2.0 * math.pi * tremolo_cycles * i / total
            value *= 1.0 - tremolo_depth + tremolo_depth * (0.5 + 0.5 * math.sin(phase))
        samples.append(value)
    return samples


def noise_burst(seconds, curve=6.0):
    """A short pseudo-random burst, for the percussive cues. Deterministic: the same file every run,
    so a regenerate never silently changes what the game sounds like."""
    total = int(seconds * SAMPLE_RATE)
    state = 12345
    samples = []
    for i in range(total):
        state = (1103515245 * state + 12345) % 2147483648
        value = (state / 1073741824.0) - 1.0
        samples.append(value * envelope(i, total, 0.002, curve))
    return samples


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

    # PURCHASE -- a rising two-note confirmation. Rising because a purchase is a step forward, and
    # distinct from the tap note, which is a single pitched blip.
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

    # MUSIC SLIDER PREVIEW -- a small arpeggiated major chord standing in for the muzak of Phase 2.
    # The music slider needs something on the Music bus to audition, or it is a knob with no feedback.
    write_wav("music_preview.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.55, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
        (0.090, tone(NOTES["E5"], 0.50, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
        (0.180, tone(NOTES["G5"], 0.48, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.5, attack=0.01)),
    ]))

    write_rush_layer()
    write_vent_cues()


def write_rush_layer():
    """The two continuous OVERDRIVE layers (Plans/Audio_System.md §5.1).

    Both loop forever while a ride is on; the game pitches the base drone with heat and fades the
    urgency layer in over the top of the band. They are quiet and harmonically simple on purpose —
    this is the one sound in the game that is held rather than struck, so anything with character
    becomes something to endure.
    """
    write_wav("heat_loop.wav", seamless_loop(
        NOTES["A2"], 1.0, harmonics=(1.0, 0.45, 0.18, 0.07)))
    # Faster, brighter, and pulsing: the approach to overheat should be audible before it is visible.
    write_wav("urgency_loop.wav", seamless_loop(
        NOTES["E3"], 1.0, harmonics=(1.0, 0.6, 0.35, 0.2, 0.1),
        tremolo_hz=9.0, tremolo_depth=0.55))


def write_vent_cues():
    """The vent gesture's seven beats (§5.2)."""
    # TELEGRAPH TICK — one per required lift, in lockstep with the haptic pulse train. Dry and
    # short: it is counting, not announcing.
    write_wav("vent_tick.wav", tone(NOTES["A4"], 0.05, harmonics=(1.0, 0.5), curve=8.0))

    # THE WINDOW OPENS — "the single most important sound in the game" (§5.2). A rising two-note
    # call, bright enough to cut through the drone that is playing underneath it.
    write_wav("vent_open.wav", sequence([
        (0.000, tone(NOTES["E5"], 0.10, harmonics=(1.0, 0.5, 0.25), curve=5.0)),
        (0.060, tone(NOTES["C6"], 0.26, harmonics=(1.0, 0.45, 0.22), curve=3.5)),
    ]))

    # EACH LIFT REGISTERED — the game pitches this up per lift, so the player HEARS progress toward
    # the requirement without looking at the pips.
    write_wav("vent_lift.wav", tone(NOTES["A4"], 0.09, harmonics=(1.0, 0.35), curve=6.0))

    # SUCCESS — a three-note flourish, the only sound in the set that resolves upward and lands.
    write_wav("vent_success.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.12, harmonics=(1.0, 0.4, 0.2), curve=5.0)),
        (0.070, tone(NOTES["E5"], 0.12, harmonics=(1.0, 0.4, 0.2), curve=5.0)),
        (0.140, tone(NOTES["A5"], 0.40,
                     harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.8)),
    ]))

    # MISSED — falling, and unresolved. It fires just before the overheat, so it is the "you blew
    # it" beat rather than the punishment itself.
    write_wav("vent_miss.wav", sequence([
        (0.000, tone(NOTES["E4"], 0.10, harmonics=(1.0, 0.4), curve=5.0)),
        (0.070, tone(NOTES["C4"], 0.28, harmonics=(1.0, 0.3), curve=3.5)),
    ]))

    # OVERHEAT — the punishment: a low thud with a noise transient on it, the only percussive sound
    # in the game. Nothing musical, because nothing about it is a reward.
    write_wav("overheat.wav", sequence([
        (0.000, noise_burst(0.09, curve=7.0)),
        (0.000, tone(NOTES["A2"], 0.45, harmonics=(1.0, 0.25, 0.1), curve=3.0)),
    ]))

    # RE-ARM — the system is live again. Deliberately small: it is permission to play, not applause.
    write_wav("rush_ready.wav", sequence([
        (0.000, tone(NOTES["A4"], 0.08, harmonics=(1.0, 0.3), curve=6.0)),
        (0.055, tone(NOTES["E5"], 0.20, harmonics=(1.0, 0.35), curve=4.0)),
    ]))


def verify_loops():
    """Assert every loop actually loops. A seam click is inaudible as a defect in isolation and
    obvious as a crackle once the sound is held for seconds, so it gets checked rather than trusted."""
    for name in ["heat_loop", "urgency_loop"]:
        path = os.path.join(OUT_DIR, name + ".wav")
        with wave.open(path, "rb") as handle:
            count = handle.getnframes()
            data = struct.unpack("<%dh" % count, handle.readframes(count))
        # The seam is just one more sample-to-sample transition, so the honest comparator is the
        # LARGEST step the waveform already makes on its own — not the average, which a bright
        # harmonic exceeds constantly. Against the average, a perfectly good loop looks broken.
        steps = [abs(data[i + 1] - data[i]) for i in range(count - 1)]
        jump = abs(data[0] - data[-1])
        biggest = max(steps)
        status = "clean" if jump <= biggest else "CLICKS"
        print("  loop seam %-14s jump=%d vs largest normal step %d -> %s" % (name, jump, biggest, status))
        if status != "clean":
            raise SystemExit("%s does not loop cleanly" % name)


if __name__ == "__main__":
    main()
    verify_loops()
