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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "game", "audio", "cues")
LOOPS_DIR = os.path.join(ROOT, "game", "audio", "loops")
MUSIC_DIR = os.path.join(ROOT, "game", "audio", "music")

# Equal-temperament note frequencies used below, so the tones sit in a real scale rather than on
# arbitrary numbers. A4 = 440.
NOTES = {
    "F2": 87.31,
    "A2": 110.00,
    "E3": 164.81,
    "A3": 220.00,
    "F3": 174.61,
    "C4": 261.63,
    "F4": 349.23,
    "G4": 392.00,
    "E4": 329.63,
    "A4": 440.00,
    "A5": 880.00,
    "C5": 523.25,
    "D5": 587.33,
    "F5": 698.46,
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


def glide(start_hz, end_hz, seconds, harmonics=(1.0,), curve=2.0, attack=0.05):
    """A tone that SLIDES from one pitch to another — the theremin gesture the alien beats want.

    Integrating the frequency over time rather than plugging it into sin(2*pi*f*t) is the whole
    point: the naive version restarts the phase every sample as the frequency moves, which warbles.
    Accumulating phase keeps the waveform continuous through the slide.
    """
    total = int(seconds * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(total):
        progress = i / max(1, total - 1)
        frequency = start_hz + (end_hz - start_hz) * progress
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE
        value = 0.0
        for index, level in enumerate(harmonics):
            value += level * math.sin(phase * (index + 1))
        samples.append(value * envelope(i, total, attack, curve))
    return samples


def write_wav(name, samples, directory=None):
    """Normalize to PEAK and write 16-bit mono PCM."""
    loudest = max(abs(value) for value in samples) or 1.0
    scale = PEAK / loudest
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767)) for value in samples)

    path = os.path.join(directory or OUT_DIR, name)
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
    write_wav("buy_success_layer.wav", sequence([
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
    write_ceremony()
    write_remaining_cues()
    write_minigame_cues()
    write_basketball_cues()
    write_music()


def write_rush_layer():
    """The two continuous OVERDRIVE layers (Plans/Audio_System.md §5.1).

    Both loop forever while a ride is on; the game pitches the base drone with heat and fades the
    urgency layer in over the top of the band. They are quiet and harmonically simple on purpose —
    this is the one sound in the game that is held rather than struck, so anything with character
    becomes something to endure.
    """
    write_wav("heat_loop.wav", seamless_loop(
        NOTES["A2"], 1.0, harmonics=(1.0, 0.45, 0.18, 0.07)), LOOPS_DIR)
    # Faster, brighter, and pulsing: the approach to overheat should be audible before it is visible.
    write_wav("urgency_loop.wav", seamless_loop(
        NOTES["E3"], 1.0, harmonics=(1.0, 0.6, 0.35, 0.2, 0.1),
        tremolo_hz=9.0, tremolo_depth=0.55), LOOPS_DIR)


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

    # The success LAYER, mixed in above the base at a deep vent tier: the same resolution an octave
    # up, so a hard-won vent reads as more of the same sound rather than a different one.
    write_wav("vent_success_layer.wav", sequence([
        (0.000, tone(NOTES["C5"] * 2.0, 0.10, harmonics=(1.0, 0.5, 0.25), curve=5.0)),
        (0.070, tone(NOTES["E5"] * 2.0, 0.10, harmonics=(1.0, 0.45, 0.2), curve=5.0)),
        (0.140, tone(NOTES["A5"] * 2.0, 0.34, harmonics=(1.0, 0.5, 0.25, 0.12), curve=3.0)),
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


def write_ceremony():
    """The story beats (Plans/Audio_System.md §4, Phase 4). These are the only sounds in the game
    that are ALLOWED to be slow: every other cue answers a press and must be out of the way, while
    these accompany a screen the player is reading. They ride their own Ceremony bus so they can sit
    above the feedback floor without the tap sound having to move."""
    # SUCCESSION, in three beats. A death, a reading, and an heir -- the arc has to be audible in the
    # shape: down, level, up.
    write_wav("ceremony_obituary.wav", sequence([
        (0.000, tone(NOTES["F3"], 1.10, harmonics=(1.0, 0.3, 0.12), curve=1.6, attack=0.05)),
        (0.220, tone(NOTES["C4"], 0.95, harmonics=(1.0, 0.25), curve=1.6, attack=0.05)),
        (0.440, tone(NOTES["F2"], 1.40, harmonics=(1.0, 0.2), curve=1.4, attack=0.06)),
    ]))
    # The will: level and procedural, a chord that neither mourns nor celebrates. It is paperwork.
    write_wav("ceremony_will.wav", sequence([
        (0.000, tone(NOTES["C4"], 0.85, harmonics=(1.0, 0.35, 0.15), curve=2.2, attack=0.03)),
        (0.000, tone(NOTES["G4"], 0.80, harmonics=(1.0, 0.3), curve=2.2, attack=0.03)),
    ]))
    # The heir: the one beat in the set that resolves upward and lands. The bloodline continues.
    write_wav("ceremony_heir.wav", sequence([
        (0.000, tone(NOTES["F4"], 0.30, harmonics=(1.0, 0.4, 0.2), curve=3.0)),
        (0.180, tone(NOTES["C5"], 0.30, harmonics=(1.0, 0.4, 0.2), curve=3.0)),
        (0.360, tone(NOTES["F5"], 1.20, harmonics=(1.0, 0.5, 0.25, 0.12), curve=1.8)),
    ]))

    # FIRST CONTACT. A theremin slide is the one instrument that says "alien" without a word of
    # explanation, and the GDD's audio direction asks for exactly that vocabulary.
    write_wav("ceremony_contact.wav", sequence([
        (0.000, glide(NOTES["A3"], NOTES["E5"], 1.30, harmonics=(1.0, 0.22, 0.08), curve=1.5)),
        (0.500, glide(NOTES["E4"], NOTES["A4"], 0.95, harmonics=(1.0, 0.18), curve=1.8, attack=0.12)),
    ]))
    # The civilization is named: a bright, wide chord landing under the reveal.
    write_wav("ceremony_contact_reveal.wav", sequence([
        (0.000, tone(NOTES["A4"], 1.00, harmonics=(1.0, 0.45, 0.2, 0.1), curve=2.0, attack=0.02)),
        (0.050, tone(NOTES["D5"], 0.95, harmonics=(1.0, 0.4, 0.18), curve=2.0, attack=0.02)),
        (0.100, tone(NOTES["F5"], 0.90, harmonics=(1.0, 0.35, 0.15), curve=2.0, attack=0.02)),
    ]))

    # A LEGACY PURCHASE. Short and bright -- this one fires far more often than the others, so it is
    # the ceremony sound most able to wear out its welcome, and it is deliberately the smallest.
    write_wav("legacy_purchase.wav", sequence([
        (0.000, tone(NOTES["A5"], 0.14, harmonics=(1.0, 0.5, 0.25), curve=4.5)),
        (0.080, tone(NOTES["E5"] * 2.0, 0.34, harmonics=(1.0, 0.4, 0.2), curve=3.0)),
    ]))

    # COMING BACK to a pile of offline earnings: warm, and pleased to see you.
    write_wav("welcome_back.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.28, harmonics=(1.0, 0.45, 0.2), curve=3.2, attack=0.02)),
        (0.150, tone(NOTES["E5"], 0.28, harmonics=(1.0, 0.4, 0.18), curve=3.2, attack=0.02)),
        (0.300, tone(NOTES["G5"], 0.75, harmonics=(1.0, 0.5, 0.25, 0.1), curve=2.2, attack=0.02)),
    ]))


# The five era bands (Plans/Audio_System.md §3.2). These are PLACEHOLDERS in the most literal sense:
# they hold the slot so the band mapping, the crossfade, the idle fade and the duck can all be heard
# and judged before a note of real music exists. Nobody should mistake them for the soundtrack.
#
# Each is a slow chord loop, and they differ the way the real tracks are meant to: the Earth bands
# are plain triads (department-store muzak, per decision 17), and the alien bands bend the same shape
# further out of true as the tiers deepen (decision 18 -- the same melody on impossible instruments).
MUSIC_BANDS = [
    # name, root, chord (semitones over the root), harmonics, tremolo Hz, tremolo depth
    ("band_0_blue_collar",  "C4", (0, 4, 7),      (1.0, 0.35, 0.12),            0.0,  0.0),
    ("band_1_white_collar", "C4", (0, 4, 7, 11),  (1.0, 0.5, 0.25, 0.12),       0.0,  0.0),
    ("band_2_early_contact","C4", (0, 4, 7, 10),  (1.0, 0.4, 0.2, 0.1, 0.05),   3.0,  0.25),
    ("band_3_mid",          "C4", (0, 3, 6, 10),  (1.0, 0.55, 0.3, 0.18, 0.1),  5.0,  0.35),
    ("band_4_deep",         "C4", (0, 1, 6, 11),  (1.0, 0.6, 0.4, 0.25, 0.15),  7.0,  0.45),
]

## Seconds per music loop. Short for a soundtrack, which is fine for a placeholder and keeps the
## repository from carrying megabytes of tone.
MUSIC_SECONDS = 8.0


def write_music():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, root, chord, harmonics, tremolo_hz, tremolo_depth in MUSIC_BANDS:
        base = NOTES[root]
        voices = []
        for semitones in chord:
            frequency = base * (2.0 ** (semitones / 12.0))
            voices.append(seamless_loop(frequency, MUSIC_SECONDS, harmonics=harmonics,
                                        tremolo_hz=tremolo_hz, tremolo_depth=tremolo_depth))
        # Every voice was rounded to its OWN whole-cycle length, so they differ by a few samples.
        # Mix over the shortest, which is still a whole number of cycles for that voice.
        length = min(len(v) for v in voices)
        mixed = [sum(v[i] for v in voices) / len(voices) for i in range(length)]
        write_wav(name + ".wav", mixed, MUSIC_DIR)


def write_remaining_cues():
    """Defaults for the cues that had no sound yet (Tim, 2026-08-09: every cue gets a hook AND a
    default, so the whole design can be heard before a single sample is sourced).

    Each is built from the same handful of shapes as the rest -- a rise means progress, a fall means
    loss, a bare thud means a wall -- so a placeholder still tells the player what happened even
    though none of them is the sound the game will ship with."""
    # STAFF. First hire is an arrival and lands; a level-up is the same gesture, smaller and higher.
    write_wav("hire_first.wav", sequence([
        (0.000, tone(NOTES["G4"], 0.14, harmonics=(1.0, 0.4, 0.15), curve=4.0)),
        (0.090, tone(NOTES["C5"], 0.30, harmonics=(1.0, 0.35, 0.15), curve=3.0)),
    ]))
    write_wav("hire_levelled.wav", tone(NOTES["E5"], 0.16, harmonics=(1.0, 0.3), curve=5.0))
    write_wav("retain_staff.wav", tone(NOTES["A4"], 0.20, harmonics=(1.0, 0.35, 0.12), curve=4.0))

    # A MILESTONE is an automatic reward, so it announces itself: a bell-like third.
    write_wav("milestone.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.18, harmonics=(1.0, 0.5, 0.3, 0.15), curve=3.5)),
        (0.000, tone(NOTES["E5"], 0.45, harmonics=(1.0, 0.45, 0.25, 0.12), curve=2.6)),
    ]))
    # Starting an idle cycle by hand: quiet, mechanical, and NOT a payout -- it is the machine
    # turning over, and it must not be mistaken for money arriving.
    write_wav("cycle_started.wav", tone(NOTES["A3"], 0.07, harmonics=(1.0, 0.6, 0.3), curve=7.0))

    # FRENZY: a bright rush up on the pop, a soft settle when it lapses.
    write_wav("frenzy_pop.wav", sequence([
        (0.000, glide(NOTES["C5"], NOTES["C6"], 0.30, harmonics=(1.0, 0.4, 0.2), curve=2.5)),
        (0.120, tone(NOTES["E6"], 0.34, harmonics=(1.0, 0.35), curve=3.0)),
    ]))
    write_wav("frenzy_end.wav", glide(NOTES["C5"], NOTES["G4"], 0.40,
                                      harmonics=(1.0, 0.25), curve=2.2))
    # ENGAGING OVERDRIVE: a rising swell, the counterpart to the overheat thud.
    write_wav("overdrive_engage.wav", sequence([
        (0.000, glide(NOTES["A3"], NOTES["A4"], 0.45, harmonics=(1.0, 0.4, 0.2, 0.1), curve=2.0)),
        (0.150, tone(NOTES["E5"], 0.30, harmonics=(1.0, 0.3), curve=3.0)),
    ]))

    # UI. All small, all dry: these fire constantly and must never draw attention to themselves.
    write_wav("tab_switch.wav", tone(NOTES["A4"], 0.045, harmonics=(1.0, 0.7, 0.4), curve=9.0))
    write_wav("screen_open.wav", sequence([
        (0.000, tone(NOTES["E4"], 0.06, harmonics=(1.0, 0.4), curve=7.0)),
        (0.040, tone(NOTES["A4"], 0.14, harmonics=(1.0, 0.3), curve=5.0)),
    ]))
    write_wav("screen_close.wav", sequence([
        (0.000, tone(NOTES["A4"], 0.06, harmonics=(1.0, 0.4), curve=7.0)),
        (0.040, tone(NOTES["E4"], 0.14, harmonics=(1.0, 0.3), curve=5.0)),
    ]))
    write_wav("mode_toggle.wav", tone(NOTES["C5"], 0.04, harmonics=(1.0, 0.8, 0.5), curve=10.0))
    write_wav("epoch_page.wav", tone(NOTES["G4"], 0.05, harmonics=(1.0, 0.5), curve=8.0))
    write_wav("tip_appear.wav", tone(NOTES["F5"], 0.12, harmonics=(1.0, 0.3), curve=5.0))
    # MAKE CONTACT is the biggest button in the game: a wide, opening chord.
    write_wav("make_contact.wav", sequence([
        (0.000, tone(NOTES["C4"], 0.55, harmonics=(1.0, 0.45, 0.2), curve=2.4, attack=0.02)),
        (0.060, tone(NOTES["G4"], 0.50, harmonics=(1.0, 0.4, 0.18), curve=2.4, attack=0.02)),
        (0.120, tone(NOTES["E5"], 0.60, harmonics=(1.0, 0.5, 0.25, 0.1), curve=2.2, attack=0.02)),
    ]))

    # DENIALS. A wall, not a punishment: low, short, unresolved, and quiet enough to ignore.
    write_wav("denied_cash.wav", tone(NOTES["F3"], 0.10, harmonics=(1.0, 0.3), curve=6.0))
    write_wav("denied_locked.wav", sequence([
        (0.000, tone(NOTES["F3"], 0.07, harmonics=(1.0, 0.3), curve=7.0)),
        (0.070, tone(NOTES["F3"], 0.12, harmonics=(1.0, 0.3), curve=6.0)),
    ]))

    # CHALLENGE MODE.
    write_wav("challenge_start.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.10, harmonics=(1.0, 0.4), curve=5.0)),
        (0.070, tone(NOTES["G5"], 0.26, harmonics=(1.0, 0.35), curve=3.5)),
    ]))
    write_wav("challenge_credit.wav", sequence([
        (0.000, tone(NOTES["E5"], 0.12, harmonics=(1.0, 0.4, 0.2), curve=4.0)),
        (0.080, tone(NOTES["A5"], 0.36, harmonics=(1.0, 0.45, 0.2), curve=2.8)),
    ]))
    # Climbing a tier of the ladder: the same figure, one rung higher and wider.
    write_wav("challenge_tier.wav", sequence([
        (0.000, tone(NOTES["A4"], 0.12, harmonics=(1.0, 0.4), curve=4.0)),
        (0.080, tone(NOTES["E5"], 0.12, harmonics=(1.0, 0.4), curve=4.0)),
        (0.160, tone(NOTES["A5"], 0.45, harmonics=(1.0, 0.5, 0.25), curve=2.4)),
    ]))

    # PRESTIGE CONFIRMED: the deep, deliberate beat before the succession screens take over.
    write_wav("prestige_confirm.wav", sequence([
        (0.000, tone(NOTES["F2"], 0.90, harmonics=(1.0, 0.3, 0.12), curve=1.8, attack=0.04)),
        (0.180, tone(NOTES["C4"], 0.70, harmonics=(1.0, 0.35), curve=2.2, attack=0.04)),
    ]))


def write_minigame_cues():
    """The SHARED minigame beats — the layer every game has in common (Tim, 2026-08-09: shared beats
    first). Each game's own vocabulary — a swish, a match, a caught coin — is a later pass.

    These are the fastest, most repeated sounds in the game, so they are the smallest: a minigame can
    fire `minigame_score` several times a second for a minute straight."""
    # BEGIN: the round starts. A short rising pair, so the run opens on an upbeat.
    write_wav("minigame_begin.wav", sequence([
        (0.000, tone(NOTES["G4"], 0.09, harmonics=(1.0, 0.4), curve=5.5)),
        (0.070, tone(NOTES["C5"], 0.22, harmonics=(1.0, 0.35), curve=4.0)),
    ]))
    # SCORE: tiny and bright. Carries a little pitch variance in the table so a fast run does not
    # turn into a machine gun on one note.
    write_wav("minigame_score.wav", tone(NOTES["E5"], 0.07, harmonics=(1.0, 0.35), curve=7.0))
    # MISS: low and short. It must read as "no" without punishing — in challenge mode a miss only
    # costs time, and play continues.
    write_wav("minigame_miss.wav", tone(NOTES["C4"], 0.10, harmonics=(1.0, 0.3), curve=6.0))
    # COUNTDOWN: one per second over the last few. Dry, so five in a row do not blur together.
    write_wav("minigame_countdown.wav", tone(NOTES["A4"], 0.055, harmonics=(1.0, 0.5), curve=8.0))
    # NEW BEST: the moment the run stops being practice. The only one of these allowed to be big.
    write_wav("minigame_best.wav", sequence([
        (0.000, tone(NOTES["C5"], 0.10, harmonics=(1.0, 0.45, 0.2), curve=4.5)),
        (0.070, tone(NOTES["E5"], 0.10, harmonics=(1.0, 0.45, 0.2), curve=4.5)),
        (0.140, tone(NOTES["G5"], 0.12, harmonics=(1.0, 0.45, 0.2), curve=4.5)),
        (0.210, tone(NOTES["C5"] * 2.0, 0.40, harmonics=(1.0, 0.5, 0.25, 0.12), curve=2.6)),
    ]))
    # OVER: the run ends. Falling and settled — an ending, not a failure.
    write_wav("minigame_over.wav", sequence([
        (0.000, tone(NOTES["G4"], 0.14, harmonics=(1.0, 0.35), curve=4.5)),
        (0.100, tone(NOTES["E4"], 0.16, harmonics=(1.0, 0.3), curve=4.0)),
        (0.200, tone(NOTES["C4"], 0.45, harmonics=(1.0, 0.3, 0.12), curve=2.8)),
    ]))


def write_basketball_cues():
    """Basketball's own vocabulary (Tim, 2026-08-09), layered OVER the shared beats.

    The impacts get VARIANTS because one shot can bounce a dozen times and a single sample would be
    the most fatiguing thing in the build. They are deliberately noise-based rather than tonal: a
    bounce is a thud, and a pitched thud starts sounding like a melody nobody wrote."""
    # THE BALL. Grab is barely there; the launch is a short whoosh that the game scales by pull force.
    write_wav("bball_grab.wav", noise_burst(0.045, curve=9.0))
    write_wav("bball_launch.wav", sequence([
        (0.000, noise_burst(0.10, curve=5.0)),
        (0.000, glide(NOTES["A3"], NOTES["E4"], 0.16, harmonics=(1.0, 0.3), curve=4.0)),
    ]))
    # A tap that never became a throw: the ball simply drops. Small and slightly deflating.
    write_wav("bball_fizzle.wav", glide(NOTES["E4"], NOTES["A3"], 0.14,
                                        harmonics=(1.0, 0.25), curve=5.0))

    # IMPACTS, four variants each. The game picks one at random per bounce and scales it by speed.
    for index in range(1, 5):
        # Wall/ceiling: a harder, brighter knock than the floor.
        write_wav("bball_wall_%d.wav" % index, sequence([
            (0.000, noise_burst(0.05 + 0.004 * index, curve=8.0)),
            (0.000, tone(NOTES["A3"] * (1.0 + 0.05 * index), 0.06, harmonics=(1.0, 0.5), curve=9.0)),
        ]))
        # Floor: lower and rounder — the ball meeting the boards.
        write_wav("bball_floor_%d.wav" % index, sequence([
            (0.000, noise_burst(0.06 + 0.005 * index, curve=7.0)),
            (0.000, tone(NOTES["F2"] * (1.0 + 0.04 * index), 0.10, harmonics=(1.0, 0.4, 0.15), curve=6.0)),
        ]))
    # Settling to rest: the last, smallest contact.
    write_wav("bball_settle.wav", noise_burst(0.05, curve=10.0))

    # THE RIM: metal. A short bright ring over the knock, which is what makes a rim-out unmistakable.
    write_wav("bball_rim.wav", sequence([
        (0.000, noise_burst(0.04, curve=9.0)),
        (0.000, tone(NOTES["E5"] * 2.0, 0.22, harmonics=(1.0, 0.6, 0.35, 0.2), curve=4.0)),
    ]))

    # THE BASKET. Score is the net; swish is the net with nothing else touched, and is the payoff
    # sound of the whole game — the one thing here allowed to sound expensive.
    write_wav("bball_score.wav", sequence([
        (0.000, noise_burst(0.09, curve=6.0)),
        (0.030, tone(NOTES["C5"], 0.20, harmonics=(1.0, 0.4, 0.18), curve=4.0)),
    ]))
    write_wav("bball_swish.wav", sequence([
        (0.000, noise_burst(0.13, curve=4.5)),
        (0.040, tone(NOTES["E5"], 0.22, harmonics=(1.0, 0.45, 0.2), curve=3.5)),
        (0.120, tone(NOTES["A5"], 0.45, harmonics=(1.0, 0.5, 0.28, 0.14), curve=2.6)),
    ]))

    # THE GEM: passing through it is a promise; earning it is the game's rarest outcome.
    write_wav("bball_gem_through.wav", tone(NOTES["E5"] * 2.0, 0.12, harmonics=(1.0, 0.4), curve=5.0))
    write_wav("bball_gem_earned.wav", sequence([
        (0.000, tone(NOTES["A4"], 0.12, harmonics=(1.0, 0.45, 0.2), curve=4.0)),
        (0.080, tone(NOTES["E5"], 0.12, harmonics=(1.0, 0.45, 0.2), curve=4.0)),
        (0.160, tone(NOTES["A5"], 0.50, harmonics=(1.0, 0.5, 0.3, 0.15), curve=2.4)),
    ]))


def verify_loops():
    """Assert every loop actually loops. A seam click is inaudible as a defect in isolation and
    obvious as a crackle once the sound is held for seconds, so it gets checked rather than trusted."""
    for name in ["heat_loop", "urgency_loop"]:
        path = os.path.join(LOOPS_DIR, name + ".wav")
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
