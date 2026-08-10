extends SceneTree

# Writes game/audio/README.md — the list of every sound the game can make, what triggers it, and
# exactly what to name a file so the game picks it up.
#
# Usage: godot --headless --path . --script res://sim/AudioCueDoc.gd
#
# GENERATED, NOT WRITTEN. The table in Audio.gd is the only definition of a cue; a hand-maintained
# document beside it would be a second one, and the two would part company the first time someone
# added a sound in a hurry. Re-run this after touching CUES and the document is correct by
# construction.
#
# The prose that cannot be derived — what fires each cue, and the design notes — lives in TRIGGERS
# below, keyed by cue id. A cue with no entry there still appears in the document, marked as needing
# one, so the gap is visible rather than silent.

const OUTPUT_PATH := "res://audio/README.md"

## What fires each cue, in the player's terms. Keep these short: the document is a reference someone
## reads while holding an audio file, not an explanation of the game.
const TRIGGERS := {
	&"tap_note": "Tapping CLOCK IN, or tapping a property whose cycle is already running (a rush). Pitched by the game across a pentatonic figure — see the note below.",
	&"buy_success": "A property purchase completes. Volume scales with how much the buy moved your income; a `_layer` sample is mixed in on top for a big jump.",
	&"hire_first": "The FIRST staffer on a property — the moment it starts running itself.",
	&"hire_levelled": "Any later staff level on a property that is already staffed.",
	&"retain_staff": "Buying staff retention in the Estate screen.",
	&"milestone": "A property crosses a count milestone (25, 50, 100 …). Fires on the crossing.",
	&"cycle_started": "Tapping a STOPPED property to start one cycle by hand. Deliberately not part of the tap scale — it is the machine turning over, not a payout.",
	&"frenzy_pop": "Popping the FRENZY meter.",
	&"frenzy_end": "A frenzy burn runs out. NO HOOK YET — the core has no signal for it; see the note below.",
	&"overdrive_engage": "The OVERDRIVE button, but only when the ride actually starts (the core refuses while auto-buy is on, or during a lockout).",
	&"vent_tick": "One per required lift, counted out the instant the vent WINDOW opens.",
	&"vent_open": "A vent window opens. The most important sound in the game — it is what makes the gesture playable without watching the bar.",
	&"vent_lift": "Each lift registered inside the window. Pitched up one whole tone per lift, so progress is audible.",
	&"vent_success": "A vent completes in time. Intensity scales with the vent tier reached.",
	&"vent_miss": "The window closes unmet — fires just before the overheat.",
	&"overheat": "The ride ends in flames. Heat drains, rushing is locked out.",
	&"rush_ready": "The lockout ends and rushing is live again.",
	&"tab_switch": "Changing tab, and only when the tab actually changes.",
	&"screen_open": "Opening a modal screen: ABOUT, STATS, CHALLENGES, HELP, or either tuning panel.",
	&"screen_close": "Closing one of those screens.",
	&"mode_toggle": "The buy-mode or hire-mode toggle.",
	&"epoch_page": "The epoch pager moves to another civilization, and only on an actual page change.",
	&"make_contact": "The MAKE CONTACT button — the biggest button in the game.",
	&"tip_appear": "A tutorial coach card appears. Only when one is actually shown.",
	&"denied_cash": "Reserved: an action refused for want of money. NO HOOK YET — deferred by decision 15.",
	&"denied_locked": "Reserved: an action refused because something is locked. NO HOOK YET — deferred by decision 15.",
	&"challenge_start": "Launching a game from the CHALLENGES screen.",
	&"challenge_credit": "A challenge run ends and its score is credited.",
	&"challenge_tier": "A challenge run climbs a tier of its ladder, mid-run.",
	&"ceremony_obituary": "The succession's obituary card.",
	&"ceremony_will": "The reading of the will.",
	&"ceremony_heir": "The heir reveal — the bloodline continues.",
	&"ceremony_contact": "A First Contact card opens.",
	&"ceremony_contact_reveal": "The civilization's name lands on that card. Fired from the reveal timeline, so it cannot drift.",
	&"legacy_purchase": "Buying a Legacy upgrade in the Estate shop.",
	&"welcome_back": "The welcome-back pile after time away.",
	&"prestige_confirm": "PASS THE TORCH is confirmed, just before the succession screens take over.",
	&"minigame_begin": "BEGIN on a minigame's Get Ready gate — the round starts.",
	&"minigame_score": "The player scores in any minigame. Fired from the shared score tracker, so it covers all six games without any of them knowing about it.",
	&"minigame_miss": "A miss that costs challenge time — the one miss every game already reports through a shared channel.",
	&"minigame_countdown": "One per second over the last few seconds of the clock, on the same tick the timer pops.",
	&"minigame_best": "The run passes the stored high score. Once per run.",
	&"minigame_over": "A round or challenge run ends.",
	&"bball_grab": "A finger takes the ball and the slingshot drag begins.",
	&"bball_launch": "The throw is released. Scaled by the SAME pull force the aim wedge shows, so a lob and a cannon shot sound as different as they look.",
	&"bball_fizzle": "Released under the minimum pull — not a throw; the ball just drops.",
	&"bball_wall": "The ball bounces off a side wall or the ceiling. Scaled by impact speed.",
	&"bball_floor": "The ball lands on the floor. Scaled by impact speed.",
	&"bball_settle": "The ball stops rolling and becomes throwable again.",
	&"bball_rim": "Clipping a rim post — the rim-out.",
	&"bball_score": "A made basket. LAYERS over the shared `minigame_score`.",
	&"bball_swish": "A clean centred drop — the gold SWISH! Also layers over `minigame_score`.",
	&"bball_gem_through": "The ball passes through the Legacy gem. A promise, not yet a payout.",
	&"bball_gem_earned": "The shot that passed through the gem also scored — the game's rarest outcome, and the only one that pays Legacy.",
	&"m3_select": "A gem is picked up — the drag begins.",
	&"m3_swap": "Two gems trade places.",
	&"m3_invalid": "A swap that matched nothing; the gems slide back. Sounded as they START back, so the refusal lands when the player learns it.",
	&"m3_match": "A match clears. PITCHED UP a whole tone per cascade step (capped), so a chain is audibly a run rather than the same sound four times.",
	&"m3_fall": "The refill drops into the gaps. Once per step, not once per gem.",
	&"m3_avoid": "A match that hit the AVOID gem — this game's one real mistake, and a large score penalty.",
	&"m3_legacy": "A Legacy gem is collected — the only thing in this game that pays the dynasty.",
	&"catch_coin": "An ordinary coin caught. The most-repeated sound in the game — four variants, and the smallest thing in the build.",
	&"catch_premium": "A premium coin caught, worth several ordinary ones. Scaled by its value.",
	&"catch_legacy": "The JACKPOT coin — the only one that pays the dynasty.",
	&"catch_miss": "A coin reaches the floor uncaught.",
	&"catch_spawn": "A coin appears. Almost inaudible on purpose: its job is to make the late-round spawn RATE audible, not to announce a coin.",
	&"music_preview": "Releasing the MUSIC slider in Settings.",
}

## Cues whose hook does not exist yet, so the document can say so plainly rather than implying the
## sound is wired and merely silent.
const NOT_YET_HOOKED := [&"frenzy_end", &"denied_cash", &"denied_locked"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var audio := load("res://scripts/audio/" + "Audio.gd") as GDScript
	if audio == null:
		print("FAILED to load Audio.gd")
		quit(1)
		return
	var constants := audio.get_script_constant_map()
	var cues: Dictionary = constants["CUES"]

	var missing_triggers: Array[String] = []
	for id in cues:
		if not TRIGGERS.has(id):
			missing_triggers.append(String(id))

	var text := _header(constants)
	text += _cue_tables(cues, constants)
	text += _music_section(constants)
	text += _footer(constants)

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		print("FAILED to write %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(text)
	file.close()

	print("Wrote %s — %d cues" % [OUTPUT_PATH, cues.size()])
	if not missing_triggers.is_empty():
		print("MISSING a trigger description: %s" % ", ".join(missing_triggers))
		quit(1)
	quit(0)


func _header(constants: Dictionary) -> String:
	return """# Audio cues — the complete list

**This file is generated.** Edit `CUES` in `scripts/audio/Audio.gd` (and `TRIGGERS` in
`sim/AudioCueDoc.gd` for the descriptions), then re-run:

    godot --headless --path . --script res://sim/AudioCueDoc.gd

## How a sound gets into the game

Name the file after the cue and put it in the right folder. That is the whole process — there is no
manifest to edit, and nothing else to change.

| Kind | Folder | Named |
|---|---|---|
| One-shot cues | `%s` | `<cue id>.ogg` |
| Continuous layers | `%s` | `heat_loop.ogg`, `urgency_loop.ogg` |
| Music tracks | `%s` | one per era band — see below |

**`.ogg` or `.wav`.** `.ogg` is tried first, so a sourced track always beats a placeholder of the
same name; you do not have to delete the old file, though you may.

**Variants.** Add `<cue id>_1`, `_2`, up to `_%d` and the game picks one at random per play. Use it
on anything heard constantly — the tap and the purchase are the obvious candidates. A single
unnumbered file is perfectly fine and is what everything ships with today.

**Layers.** A cue marked *layered* below also looks for `<cue id>_layer`, mixed in ON TOP of the base
sample when the moment is a big one. It never replaces it.

**A missing file is not an error.** The cue simply makes no sound, and the game logs one line at
startup listing everything still unrecorded. That is what lets the whole design exist before any of
it has been recorded — every cue in this document already has a hook and a generated placeholder.

""" % [constants["CUES_DIR"], constants["LOOPS_DIR"], constants["MUSIC_DIR"], constants["MAX_VARIANTS"]]


func _cue_tables(cues: Dictionary, constants: Dictionary) -> String:
	var groups := {
		"The core loop": [&"tap_note", &"buy_success", &"hire_first", &"hire_levelled",
			&"retain_staff", &"milestone", &"cycle_started", &"frenzy_pop", &"frenzy_end"],
		"Rush and overdrive": [&"overdrive_engage", &"vent_tick", &"vent_open", &"vent_lift",
			&"vent_success", &"vent_miss", &"overheat", &"rush_ready"],
		"Interface": [&"tab_switch", &"screen_open", &"screen_close", &"mode_toggle",
			&"epoch_page", &"make_contact", &"tip_appear"],
		"Denials (reserved)": [&"denied_cash", &"denied_locked"],
		"Challenge Mode": [&"challenge_start", &"challenge_credit", &"challenge_tier"],
		"Minigames — the shared beats": [&"minigame_begin", &"minigame_score", &"minigame_miss",
			&"minigame_countdown", &"minigame_best", &"minigame_over"],
		"Catch Money": [&"catch_coin", &"catch_premium", &"catch_legacy", &"catch_miss",
			&"catch_spawn"],
		"Match Three": [&"m3_select", &"m3_swap", &"m3_invalid", &"m3_match", &"m3_fall",
			&"m3_avoid", &"m3_legacy"],
		"Basketball": [&"bball_grab", &"bball_launch", &"bball_fizzle", &"bball_wall",
			&"bball_floor", &"bball_settle", &"bball_rim", &"bball_score", &"bball_swish",
			&"bball_gem_through", &"bball_gem_earned"],
		"Ceremony — the story beats": [&"ceremony_obituary", &"ceremony_will", &"ceremony_heir",
			&"ceremony_contact", &"ceremony_contact_reveal", &"legacy_purchase", &"welcome_back",
			&"prestige_confirm"],
		"Settings": [&"music_preview"],
	}
	var order := ["The core loop", "Rush and overdrive", "Interface", "Denials (reserved)",
		"Challenge Mode", "Minigames — the shared beats", "Basketball", "Match Three", "Catch Money", "Ceremony — the story beats", "Settings"]

	var text := "## The cues\n\nBus decides which slider governs a sound, and whether it counts as"
	text += " the player being *present* (SFX and UI do; Ceremony and Music do not).\n"
	for group in order:
		text += "\n### %s\n\n| Cue / filename | Bus | dB | Cooldown | Fires when |\n" % group
		text += "|---|---|---|---|---|\n"
		for id in groups[group]:
			var row: Dictionary = cues.get(id, {})
			if row.is_empty():
				continue
			var name := "`%s`" % id
			if row.get("layered", false):
				name += " + `%s_layer`" % id
			if id in NOT_YET_HOOKED:
				name += " ⚠"
			text += "| %s | %s | %.0f | %.0f ms | %s |\n" % [
				name, row["bus"], row["db"], row["cooldown"], TRIGGERS.get(id, "**(undescribed)**")]
	text += "\n⚠ = the sound and the file slot exist, but nothing calls it yet.\n"
	return text


func _music_section(constants: Dictionary) -> String:
	var text := "\n## Music\n\nOne track per era band, in `%s`:\n\n" % constants["MUSIC_DIR"]
	text += "| File | Tiers | Character |\n|---|---|---|\n"
	var characters := [
		"Earth, Blue Collar — department-store muzak, thin arrangement.",
		"Earth, White Collar — the **same tune**, fuller. The promotion should be audible.",
		"Early contact — the melody survives; instrumentation goes theremin/synth.",
		"Mid — fewer Earth instruments left. Odd intervals creep in.",
		"Deep — recognizable, but barely of this world.",
	]
	var tiers := ["1", "2", "3–11", "12–19", "20–27"]
	var files: Array = constants["MUSIC_BAND_FILES"]
	for i in range(files.size()):
		text += "| `%s.ogg` | %s | %s |\n" % [files[i], tiers[i], characters[i]]
	text += """
Ogg Vorbis, 96–112 kbps, mono or joint stereo. **It must loop seamlessly** — the game sets the loop
flag, so the file has to end where it begins.

The game crossfades between bands over 2 seconds, and never during a ceremony: the change waits until
the First Contact card is dismissed. It fades the music out after a long idle and brings it back when
you next act, and ducks it 4 dB while a rush is on. A band with no file keeps the current track
playing rather than cutting to silence, so tracks can arrive one at a time.
"""
	return text


func _footer(constants: Dictionary) -> String:
	var silent: Array = constants["DELIBERATELY_SILENT"]
	return """
## Deliberately silent

| Event | Why |
|---|---|
| `%s` | The Acquisitions Desk buys without the player, and unattended events stay silent. It cannot even reach a hook — the desk buys inside the core, which never touches the audio layer. |
| `%s` | A cycle completing was built, heard, and removed: *"only when the user taps to purchase"*. |

## Three sounds the game pitches itself

Do not add pitch variance to either, and do not record them with vibrato — the game is doing the
tuning, and a wobble on top is simply out of tune.

- **`tap_note`** is played across a two-octave pentatonic figure that rises and falls, with the
  window drifting up the scale as a run continues. Record it as ONE note; C5 is what the placeholder
  uses. It is pitched from there in both directions.
- **`vent_lift`** steps up a whole tone per lift within a window, so the count is audible.
- **`m3_match`** climbs a whole tone per cascade step, so a chain reads as a run. Record it as one
  clean tone with no vibrato and no movement of its own — anything already going somewhere fights
  the climb the game puts on top.

## The minigames

**Basketball, Match Three and Catch Money are done; the other three are not.** The six games share the beats above — begin, score, miss, countdown, new best, over — and each
game's own vocabulary (a swish, a match, a caught coin, a flipped pad) is a LATER PASS, deliberately.
Getting the shared layer right first means every game already sounds like it belongs to this game
before any of them sounds like itself.

**The soundtrack stops entirely while a minigame is up**, rather than ducking. A minigame owns the
whole screen, sets its own pace, and its own sounds are fast and small; an era track underneath would
fight all three. The band is remembered, so returning restores the same track.

## Credits

Every sourced file needs a row in `CREDITS.md` **when it is added**, with its licence. If you cannot
write the row, do not commit the file.
""" % [silent[0], silent[1]]
