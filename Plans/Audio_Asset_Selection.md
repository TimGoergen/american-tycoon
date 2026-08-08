# Audio Asset Selection — sourcing `Plans/Audio_System.md` from the owned packs

**Status:** Recommendation, nothing implemented. Written 2026-08-07.
**Feeds:** `Plans/Audio_System.md` §4 (SFX event map), §5 (overdrive), §7 (asset sourcing).
**Library audited:** 14 packs extracted to `D:\Downloads\Game_Audio` — 3,763 audio files,
~2,200 unique sounds, 9.8 GB. Every path below was verified to exist on disk.

**Method and its limits.** Selection was made from filename semantics, folder semantics, and
**measured durations** (WAV `fmt`/`data` chunks parsed directly; the pack folder names are
unreliable, see §5.1). Nothing here has been *listened to*. Duration is decisive for the
high-frequency events — a tap blip that is 300 ms instead of 140 ms is simply wrong no
matter how it sounds — but every pick below is an audition candidate, not a final call.

---

## 1. The headline findings

1. **The `tap_scale` blip has exactly one good candidate in 2,200 sounds.**
   `Scoreboard Counter A.wav` (0.142 s) from the Foley Sports pack is the only file that
   is both under the 200 ms ceiling and mechanically percussive rather than electronic.
   It is a tally-counter tick — which is functionally an adding-machine key, the exact
   sound §7.1 of the audio plan asks for. This is a lucky hit; the pack it came from is
   otherwise nearly useless.

2. **The music packs ship three distinct full-length mixes per track**, not one.
   Every track folder contains `Main.wav`, `Intensity 1.wav`, and `Intensity 2.wav` —
   same length to the sample, different audio (verified by MD5). These are adaptive-music
   layer stems. **This solves the Band 0 → Band 1 requirement outright**: "same tune,
   fuller, the promotion is audible" is literally `Intensity 1` → `Main` of one
   composition. See §5.

3. **The plan's biggest stated risk (§7.2, "same melody, alien instruments") is
   partially solved, not fully.** The Intensity stems give a genuine same-melody
   re-arrangement across Bands 0→1. Bands 2→4 still fall back to related-but-different
   library tracks. Honest verdict in §5.4.

4. **Four of the fourteen packs should be set aside entirely** — Hip Hop, Eastern, Horror,
   and most of Foley Sports. Details and reasoning in §7.

5. **Nothing in the library covers three named items** from the plan's shopping list:
   a mechanical cash register, a typewriter, and a theremin. Substitutes are proposed;
   the gaps are listed honestly in §6.

---

## 2. Phase 1 vertical slice — the eight files to start with

`Plans/Audio_System.md` §8 Phase 1 needs the tap scale, purchase-succeeded, and aggregated
collect. This is the minimum set to audition first.

| Event | File (under `D:\Downloads\Game_Audio\`) | Length |
|---|---|---|
| `tap_scale` | `Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Counter A.wav` | 0.142 s |
| `tap_scale` alt | `Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Counter B.wav` | 0.181 s |
| `buy_success` (quiet base) | `westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Coins Bag 1.wav` | 0.565 s |
| `buy_success` (bright layer) | `westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Coins Bag 2.wav` | 1.144 s |
| `collect` | `westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Card Deliver 1.wav` | 0.534 s |
| `collect` alt | `inventorysfxbundle_audio\inventorysfxbundle\Assets\Coins\CoinPickUp2.mp3` | 0.336 s |
| `milestone` | `Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Ding.wav` | 0.408 s |
| `hire_first` | `buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Create Engineer.wav` | 0.774 s |

**Why `collect` is paper and `buy_success` is coins — a deliberate split.** Both events fire
within a second of each other constantly. If both are coin sounds the player cannot tell
them apart, and the plan's §4.2 relative-intensity scaling on purchases becomes inaudible.
Giving collect a paper texture (`Card Deliver`) and purchase a metal texture (`Coins Bag`)
separates them by timbre rather than by volume, which survives being mixed under music.
The coin alternate is listed in case paper reads as too thin on a phone speaker.

**Two `tap_scale` variants are listed on purpose.** The plan pitch-shifts one sample up a
pentatonic scale. Having a second near-identical tick lets alternating taps use different
source samples, which masks the artificial quality of heavy pitch-shifting on the high notes.

---

## 3. Full SFX event map

Paths are relative to `D:\Downloads\Game_Audio\`. Durations measured.

### 3.1 Core loop

| Event | First choice | Alternate |
|---|---|---|
| `tap_scale` | `Foley Sports\...\Buzzers and Boards\Scoreboard Counter A.wav` (0.142 s) | `puzzleaudiokit\...\WAV\FX\Misc\Button 6.wav` (0.099 s) — shorter but electronic, not mechanical |
| `buy_success` quiet | `westernaudiobundle\...\SFX\Misc\Coins Bag 1.wav` (0.565 s) | `buildingandcrafting...\WAV\FX\Coin 4.wav` (0.500 s) |
| `buy_success` bright | `westernaudiobundle\...\SFX\Misc\Coins Bag 2.wav` (1.144 s) | `buildingandcrafting...\WAV\FX\Coins 2.wav` (0.950 s) |
| `collect` | `westernaudiobundle\...\SFX\Misc\Card Deliver 1.wav` (0.534 s) | `inventorysfxbundle...\Assets\Coins\CoinPickUp2.mp3` (0.336 s) |
| `collect` variation | `westernaudiobundle\...\SFX\Misc\Card Deliver 2.wav` (0.590 s) | `inventorysfxbundle...\Assets\Coins\CoinPickUp1.mp3` (0.384 s) |
| `milestone` | `Foley Sports\...\Buzzers and Boards\Scoreboard Ding.wav` (0.408 s) | `inventorysfxbundle...\Assets\Misc\LevelUp1.mp3` (1.776 s) — bigger, for high bands |
| `hire_first` | `buildingandcrafting...\WAV\FX\Create Engineer.wav` (0.774 s) | `westernaudiobundle\...\Buttons and Stingers\Stinger 15.wav` (1.659 s) |
| `hire_levelup` | `buildingandcrafting...\WAV\FX\Create Human Female.wav` (0.304 s) | `buildingandcrafting...\WAV\FX\Create Robot 1.wav` (0.485 s) |

The `Create Engineer` / `Create Human Female` pairing is deliberate — same sample family,
different weight, so first-hire and level-up read as the same *kind* of event at two scales.
That is what §4.2 of the audio plan asks for.

### 3.2 Overdrive / heat system (Phase 3)

This is where the library is unexpectedly strong.

| Event | First choice | Alternate |
|---|---|---|
| `heat_drone` | `buildingandcrafting...\WAV\Update\Truck Gear Idle (loop).wav` (2.055 s, loop-tagged) | `magicspells...\Mono\Electric\Electric (loop).mp3` (6.44 s) |
| `heat_urgency` | `buildingandcrafting...\WAV\FX\Saw (loop).wav` (2.440 s, loop-tagged) | `Sci-Fi Horror...\Tech and Mech\Pathetic Alarm.wav` (2.928 s) |
| `vent_tick` | `Foley Sports\...\Buzzers and Boards\Pacer Beeps Normal.wav` (4.424 s — **slice one beep out**) | `spaceaudiobundle\...\WAV\FX\Button 2.wav` (0.250 s) |
| `vent_window_open` | `Foley Sports\...\Buzzers and Boards\Buzzer.wav` (0.337 s) | `spaceaudiobundle\...\WAV\FX\Communication Recieving 2.wav` (0.400 s) |
| `vent_lift` | `spaceaudiobundle\...\WAV\FX\Elevator.wav` (2.500 s — trim) | `magicspells...\Mono\Generic\Generic Spell (end) 4.mp3` (2.21 s) |
| `vent_success` | `Sci-Fi Horror...\Tech and Mech\Strong Accept.wav` (2.701 s) | `puzzleaudiokit\...\FX\Misc\Reward 2.wav` (0.540 s) |
| `vent_missed` | `Sci-Fi Horror...\Tech and Mech\Strong Deny.wav` (2.701 s) | `puzzleaudiokit\...\FX\Misc\Wrong 1.wav` (0.529 s) |
| `overheat` | `spaceaudiobundle\...\WAV\FX\Decompression 1.wav` (3.740 s) | `Sci-Fi Horror...\Tech and Mech\Vent Exhale.wav` (8.811 s — trim to onset) |
| `rush_ready` | `spaceaudiobundle\...\WAV\FX\Computer On.wav` (1.110 s) | `Foley Sports\...\Scoreboard Ding.wav` pitched up (0.408 s) |

**Three notes on this block.**

- **`Truck Gear Idle` over `Electric (loop)` for the drone is a theme call, not a quality
  call.** A mechanical engine idle says *business, industry, machinery*. An electrical hum
  says *sci-fi*. The heat system is the player working a machine hard; the mechanical
  timbre matches, and it stays coherent when the alien epochs arrive because the joke is
  that the player's operation is always recognizably American.
- **`Strong Accept` / `Strong Deny` are a matched pair** — identical length, same sample
  family, clean opposites. Success and failure in the same skill loop should be obviously
  related sounds. Both live in a horror pack but are abstract machine confirms with no
  creature content.
- **`Pacer Beeps Normal` must be cut down to a single tick** before use. It is an interval
  timer's whole beep train; the plan (§5.2) requires the pulse fire in lockstep with
  `MomentumBar._pulse_vent_telegraph`, which means the game drives the timing, not the file.
  Shipping the train as-is would guarantee drift against the haptic.

### 3.3 Ceremony (Phase 4)

| Event | First choice | Alternate |
|---|---|---|
| `succession` | `westernaudiobundle\...\SFX\Misc\Bell 1.wav` (6.842 s) | `magicspells...\Mono\Revive\Revive 3.mp3` (6.08 s) |
| `first_contact` | `spaceaudiobundle\...\WAV\FX\Teleportation.wav` (2.650 s) | `Sci-Fi Horror...\Tech and Mech\Beam Me Up A.wav` (9.202 s) |
| `first_contact` bed | `magicspells...\Mono\Generic\Generic Spell (summon) 1.mp3` (6.13 s) | `spaceaudiobundle\...\WAV\FX\Light Speed.wav` (1.67 s) |
| `legacy_purchase` | `magicspells...\Mono\Generic\Generic Spell (summon) 1.mp3` (6.13 s) | layer `Coins Bag 2.wav` under `Strong Accept.wav` |
| `welcome_back` | `inventorysfxbundle...\Assets\Coins\CoinPouring3.mp3` (8.280 s — trim/fade) | `magicspells...\Mono\Heal\Heal 9.mp3` (4.57 s) |

A long warm bell for succession is the right instinct — dignified, period, and it does not
read as horror or as sadness. `Revive 3` is the better pick if the beat needs to feel like
*continuation* rather than *ending*; the heir reveal (`WillScreen.gd:341`) may want that.

`CoinPouring3` is nearly 8.3 seconds of coin cascade. That is far too long as-is, but it is
the only genuine "pile of money" gesture in the library and it trims well.

### 3.4 UI (Phase 5)

| Event | First choice | Length |
|---|---|---|
| `tab_switch` | `buttonssfxlibrary\...\WAV\Slide\Slide Button 13.wav` | 0.263 s |
| `button_major` | `buttonssfxlibrary\...\WAV\Select\Select Button 1.wav` | 0.489 s |
| `toggle` | `buttonssfxlibrary\...\WAV\Click\Click Button 6.wav` | 0.221 s |
| `overlay_open` | `puzzleaudiokit\...\WAV\FX\Misc\Open Drawer 2.wav` | 0.691 s |
| `overlay_close` | `puzzleaudiokit\...\WAV\FX\Misc\Close Drawer 3.wav` | 0.888 s |

The drawer pair is a matched open/close from one source object, which is worth more than
either sound is individually — the ear notices when an overlay closes with an unrelated
sound. `Western\...\Buttons and Stingers\Button 5.wav` (0.311 s) is the period-flavored
alternative to the whole UI set if the Buttons library reads as too generic/modern.

---

## 4. Consolidated pick list — 26 files

Everything above, deduplicated, as the shopping list for `game/audio/`.

```
Foley Sports\...\Buzzers and Boards\Scoreboard Counter A.wav    tap_scale
Foley Sports\...\Buzzers and Boards\Scoreboard Counter B.wav    tap_scale variant
Foley Sports\...\Buzzers and Boards\Scoreboard Ding.wav         milestone / rush_ready alt
Foley Sports\...\Buzzers and Boards\Buzzer.wav                  vent_window_open
Foley Sports\...\Buzzers and Boards\Pacer Beeps Normal.wav      vent_tick (slice)
Western\...\SFX\Misc\Coins Bag 1.wav                            buy_success quiet
Western\...\SFX\Misc\Coins Bag 2.wav                            buy_success bright
Western\...\SFX\Misc\Card Deliver 1.wav                         collect
Western\...\SFX\Misc\Card Deliver 2.wav                         collect variant
Western\...\SFX\Misc\Bell 1.wav                                 succession
Building\...\WAV\FX\Create Engineer.wav                         hire_first
Building\...\WAV\FX\Create Human Female.wav                     hire_levelup
Building\...\WAV\FX\Coin 4.wav                                  buy_success alt
Building\...\WAV\Update\Truck Gear Idle (loop).wav              heat_drone
Building\...\WAV\FX\Saw (loop).wav                              heat_urgency
Space\...\WAV\FX\Decompression 1.wav                            overheat
Space\...\WAV\FX\Computer On.wav                                rush_ready
Space\...\WAV\FX\Teleportation.wav                              first_contact
Space\...\WAV\FX\Elevator.wav                                   vent_lift
Sci-Fi Horror\...\Tech and Mech\Strong Accept.wav               vent_success
Sci-Fi Horror\...\Tech and Mech\Strong Deny.wav                 vent_missed
Magic\Mono\Generic\Generic Spell (summon) 1.mp3                 legacy_purchase
Inventory\Assets\Coins\CoinPouring3.mp3                         welcome_back
Buttons\WAV\Slide\Slide Button 13.wav                           tab_switch
Buttons\WAV\Select\Select Button 1.wav                          button_major
Puzzle\WAV\FX\Misc\Open Drawer 2.wav + Close Drawer 3.wav       overlay open/close
```

That is 26 files against the plan's §7.1 target of 25–30. It fits.

---

## 5. Music — the five era bands

### 5.1 Correction: the folder names lie about length

Track folders are named like `Coffee Time (RT 4.000)`. **`RT` is not runtime.** Measured
against the actual RIFF headers, every `Main.wav` across all five music packs runs
**85–108 seconds** regardless of its RT tag (which ranges 1.16–14.03). `Coffee Time
(RT 4.000)` is 100.00 s; `Timelapse (RT 12.000)` is 108.02 s. RT appears to be a leftover
store catalog code. **Trust measured duration only.**

This is good news: every track is already a ~1.5-minute unit, which is the right shape for
a loop bed.

### 5.2 The Intensity stems — the important discovery

Each track folder holds five files:

- `Main.wav` — full mix, ~85–108 s
- `Intensity 1.wav`, `Intensity 2.wav` — **same length to the sample, different audio**
  (MD5-verified distinct), i.e. sparser and fuller mixes of the same composition
- `Cut 30.wav`, `Cut 60.wav` — trailer edits with fade tails, **not loop-safe, do not use**

10/10 Corporate tracks and 9/10 Ethereal tracks ship the Intensity pair.

**This directly delivers the Band 0 → Band 1 spec.** The audio plan §3.2 asks Band 1 to be
"same tune, fuller. Strings arrive. The promotion is audible." That is exactly what a
sparse-mix → full-mix stem pair of one composition *is*. No DAW work, no commission.

Secondary use worth noting for Phase 3: these stems are built for adaptive layering, so the
overdrive system could crossfade `Main` → `Intensity 2` while heat is high instead of just
ducking the music. That is a Phase 3 idea, not a Phase 2 requirement.

### 5.3 Recommended ladder

| Band | Tiers | File (under `D:\Downloads\Game_Audio\`) | Length |
|---|---|---|---|
| 0 Blue Collar | 1 | `Corporate Music Pack Vol. 1\Coffee Time (RT 4.000)\Corporate Coffee Time Intensity 1.wav` | 100.00 s |
| 1 White Collar | 2 | `Corporate Music Pack Vol. 1\Coffee Time (RT 4.000)\Corporate Coffee Time Main.wav` | 100.00 s |
| 2 Early contact | 3–11 | `Corporate Music Pack Vol. 1\Space Intruder (RT 4)\Corporate Space Intruder Main.wav` | 100.00 s |
| 3 Mid | 12–19 | `Ethereal Music Pack Vol. 3\...\Time Warps (RT 8.092)\Ethereal Vol3 Time Warps Main.wav` | 97.70 s |
| 4 Deep | 20–27 | `Ethereal Music Pack Vol. 3\...\Winds of Time (RT 8.092)\Ethereal Vol3 Winds of Time Main.wav` | 97.70 s |

**Why this shape.**

- **Bands 0→1 are one composition at two densities.** The promotion beat is audible and
  genuinely the same tune, which is the joke the plan wants. Verify by ear that
  `Intensity 1` is the *sparser* of the pair — the naming does not guarantee direction.
- **Band 2 stays inside the Corporate pack.** `Space Intruder` is a corporate-library cue
  with a synthetic/quirky-sci-fi character — "the melody survives, instrumentation goes
  theremin/synth" without leaving the composer, session, or production chain that Bands
  0–1 came from. The first alien epoch should still sound like *your company*, just
  somewhere strange. It is also 100.00 s, matching Bands 0–1 exactly.
- **Bands 3→4 are a matched pair.** `Time Warps` and `Winds of Time` measure 97.70 s
  each and carry the identical `RT 8.092` tag but are different audio (MD5-verified) —
  almost certainly the same underlying composition in two arrangements. That is a second
  free "same melody, different dress" moment at the deep end.

**The one real seam is Band 2 → Band 3** (tier 12), where Corporate hands off to Ethereal:
different composer, different session, bright-and-pulsed giving way to slow-attack pads.
A naive linear crossfade there will sound like two songs overlapping. Two mitigations,
both cheap:

1. Every band change in this game already coincides with an epoch arrival, and
   `Plans/Audio_System.md` §3.1 already requires the crossfade to wait until the First
   Contact overlay dismisses. Duck to near-silence under the arrival sting and hard-cut.
   A scripted transition at a story beat is not a cheat — it is the correct treatment.
2. If it still jars, substitute Band 3 with `Ethereal ...\Direct Sunlight` or
   `Glowing`, whichever auditions closer to Corporate's brightness.

### 5.4 Honest verdict on the plan's §7.2 risk

`Plans/Audio_System.md` §7.2 warns that "same melody, alien instruments" cannot be
assembled from unrelated library tracks, and ranks the options. Against this library:

- **Option 1 (one melody, five arrangements) is not achievable here** — these are five
  separate stock packs from different composers. It remains a commission.
- **Option 2 (library track with shipped variants) is *partially* achievable, and better
  than the plan assumed.** The Intensity stems are exactly the shipped-variants case, and
  they cover Bands 0→1 completely plus a bonus same-piece pair at 3→4.
- **Option 3 (the fallback) is comfortably achievable** and is what §5.3 above is.

So: ship §5.3 now, and the plan's advice holds unchanged — treat the commission as a later
upgrade that swaps files in `audio_events.tres` with no code change.

---

## 6. Gaps — what the library does not have

| Wanted (plan §7.1) | Status | Substitute used |
|---|---|---|
| Mechanical cash register | **absent** | `Coins Bag 1/2` (coin-bag clunk) |
| Adding machine / typewriter clack | **absent as such** | `Scoreboard Counter A` (tally-counter tick) — a genuinely good stand-in |
| Theremin sweep | **absent** | `Teleportation` shimmer |
| Slide-projector advance | **absent** | `Open Drawer 2` / `Elevator` |
| Telephone-switchboard click | **absent** | `Slide Button 13` |
| Rubber stamp | **absent** | `Click Button 6` |
| Vacuum-tube hum | **absent** | `Truck Gear Idle (loop)` (engine idle) |
| Department-store muzak | **present** | Corporate pack — the best single fit in the whole library |

The three that matter are the register, the typewriter, and the theremin, because they are
named in the plan as the period vocabulary that does the theming. The tally-counter tick
covers the typewriter well. The register and theremin are worth a targeted free-source
search later (Sonniss GDC bundles and freesound.org both carry both) — but nothing blocks
Phase 1 on them.

---

## 7. Pack-by-pack verdict

| Pack | Verdict |
|---|---|
| **Corporate Music Pack Vol. 1** | **Keep — most valuable pack in the library.** Bands 0–2 plus the Intensity-stem solve. |
| **Ethereal Music Pack Vol. 3** | **Keep.** Bands 3–4; cosmic-wonder, never dark. |
| **Western Audio Bundle** | **Keep** — `Buttons and Stingers` + `SFX\Misc` only. Period-mechanical foley reads as generic mid-century Americana. Drop Animals, Weapons, Voice, Ambience, Music. |
| **Foley Sports Sound FX Pack** | **Keep `Buzzers and Boards` only** — but it is essential: the only sub-200 ms mechanical transient, plus the vent buzzer and the milestone ding. Drop all 11 other subfolders (ball and impact foley). |
| **Building & Crafting Audio Bundle** | **Keep** — coins, `Create *` hire cues, and the two loop-tagged drone beds. |
| **Space Audio Bundle** | **Keep** — `Decompression`, `Computer On`, `Teleportation`, `Elevator` are semantic bullseyes for the vent/ceremony beats. |
| **Sci-Fi Horror Vol. 2** | **Keep `Tech and Mech` only.** `Strong Accept`/`Strong Deny` and the machine beds are abstract and clean. **Never touch `Creatures` or `Stingers`** — screams and jump-scares, wrong game. |
| **Inventory SFX Bundle** | **Keep narrowly** — `Coins` folder (`CoinPickUp`, `CoinPouring`) and `Misc\LevelUp`. |
| **Magic Spells SFX Bundle** | **Keep narrowly** — `Generic\Spell (summon)` and `Revive` as abstract weight/ceremony. Use **Mono** variants. Avoid Fear/Madness/Venom/Fire folders entirely. |
| **Puzzle Audio Kit** | **Keep narrowly** — the drawer open/close pair, `Gear (loop)`, and a few reward/wrong stings as alternates. Its music is a mystery/puzzle family, wrong for the ladder. |
| **Buttons SFX Library** | **Keep for Phase 5 UI only.** Contributes nothing outside clicks. |
| **Jazz Music Pack** | **Set aside** for the ladder — 1940s–50s nightclub noir, not department-store muzak. Possible one-off flavor sting later. |
| **Hip Hop Music Pack Vol. 3** | **Drop.** Modern trap/808; shares nothing with the game's period. |
| **Eastern Music Pack** | **Drop.** Wrong instrument family for the Corporate ladder — and using real-world Eastern instrumentation as shorthand for "alien" would cut directly against the game's own rule that aliens are business partners, not exotic Others. |
| **Horror Audio Bundle** | **Drop.** Its only non-horror material (12 button clicks, a bell) is duplicated better by Western and Buttons. Everything else is tonally wrong. |

---

## 8. Before any of this ships

1. **Format conversion is required, not optional.** The music `Main.wav` files are ~27.5 MB
   each — five bands as WAV would be 138 MB against a ~10 MB target (plan §7.3). Convert to
   Ogg Vorbis ~96–112 kbps (≈1.2 MB per 90 s, ≈6 MB for five bands). SFX convert to mono
   44.1 kHz WAV; the MP3-sourced picks (Inventory, Magic) need decoding to WAV so they load
   in memory rather than streaming — plan §1.3 is explicit that streaming a short blip is
   the battery problem.
2. **Loop points need hand-checking.** No music track in any pack is marked `(loop)`. Every
   band track needs its splice trimmed and verified by ear in Godot before it loops for
   hours in front of a player.
3. **Trim the long files.** `CoinPouring3` (8.3 s), `Vent Exhale` (8.8 s), `Pacer Beeps`
   (4.4 s), and `Elevator` (2.5 s) are all sources to cut from, not files to ship.
4. **Licensing — reviewed 2026-08-07, see §9.** All three licensors permit commercial
   mobile release; nothing in the selection is blocked. **One live obligation:** Tao & Sound
   requires **attribution**, and it covers 18 of the 26 SFX. `game/audio/CREDITS.md`
   (plan §7.1) should be started with the first file copied in, not retrofitted, and the
   ABOUT screen needs a credits line. Audio files stay in the public repo (§9.5, decided).
5. **Audition before committing.** Every pick here is reasoned from filename and duration.
   The `tap_scale` choice in particular carries the most risk per the plan's own Phase 1
   exit criterion ("is the tap scale still pleasant at minute 15?") and deserves listening
   to first, before any code is written.

---

## 9. Licensing review

**Reviewed 2026-08-07. This is a reading of the license documents, not legal advice.**

Despite 14 packs there are only **three licensors** and **four distinct documents** (the
`EULA.txt` is byte-identical across six packs; the `Royalty-Free License (Link).pdf` is
byte-identical across seven — verified by MD5).

### 9.1 Who licenses what

| Licensor | Packs | Commercial mobile release | Attribution |
|---|---|---|---|
| **Tao & Sound** (`EULA.txt` → taoandsound.com/ASEULA.htm) | Building & Crafting, Buttons, Horror, Puzzle, Space, Western | **Permitted** | **REQUIRED** |
| **Ovani Sound** (`Royalty-Free License (Link).pdf` → ovanisound.com terms) | Corporate, Eastern, Ethereal, Foley Sports, Hip Hop, Jazz, Sci-Fi Horror Vol. 2 | **Permitted** | Not required |
| **GameDev Market** (Humble Bundle; `Important - Read Me.pdf`) | Inventory SFX, Magic Spells SFX | **Permitted** | Not required |

**Bottom line: nothing in the recommended selection is blocked from commercial release.**
All three licensors explicitly allow paid/monetized distribution with no revenue cap, no
team-size limit, and no per-title cap (with the GDM caveat in §9.4).

### 9.2 Tao & Sound requires credit — and it covers most of the SFX

The shipped `EULA.txt` points to the full agreement, which states:

> "The END USER shall credit the authorship of the Asset within the electronic application
> or digital medium where the Asset is used, whenever reasonably possible."

**18 of the 26 recommended SFX come from Tao & Sound packs** (Western, Building, Space,
Puzzle, Buttons). A mobile game with an existing Settings → ABOUT screen has no argument
that crediting is not "reasonably possible", so this is a real obligation, not a courtesy.

Practically: the ABOUT screen needs a credits line, and `game/audio/CREDITS.md` needs to
exist from the first file copied in.

Also from that agreement, worth knowing:
- Use must be **integrated into an application with purpose beyond playing the audio** —
  trivially satisfied by a game.
- **No AI/ML training** on the assets without consent.
- No use in a **logo, trademark, or service mark**.
- The `EULA.txt` ties the licence to the purchase invoice: *"By retaining this invoice,
  you have a perpetual, non-transferable license."* **Keep the store invoices.** They are
  the proof of licence, and support is conditioned on producing them.

### 9.3 Ovani Sound — cleanest of the three

Covers all five recommended music-band tracks plus the Foley Sports and Sci-Fi Horror SFX.

> "This license grants all commercial or personal use" … "We welcome and encourage the use
> of our music in your games, films, or products for sale."
> "Credits for the use of Sound FX and Music packs are not required but are highly appreciated."

The mandatory-credit exception applies only to their *Voices* series, which is not used here.
Prohibited: redistributing/selling the content on its own, standalone soundboard/player
apps, AI training, and falsely claiming authorship.

### 9.4 GameDev Market — the only one with residual ambiguity

Their terms page blocks automated retrieval (HTTP 403), so this rests on the bundle's own
read-me plus secondary sources. The read-me is explicit:

> "At the moment our license states that each asset can only be used in one project, however
> we are in the process of removing this clause, so for the purpose of any Humble Bundle
> purchases, all assets can be used in multiple projects."

Current GDM terms reportedly carry "no restriction on the number of projects," but older
purchases may sit under the one-project version.

**Why this does not actually matter here:** American Tycoon is one project, so even the
most restrictive reading is satisfied. The only live constraint is that these two packs'
files must **not** be reused in Critter Quitters or Blob Chain without re-checking.

Only **two** files in the §4 list come from GDM — `CoinPouring3.mp3` (`welcome_back`) and
`Generic Spell (summon) 1.mp3` (`legacy_purchase`). Both have non-GDM substitutes already
listed in §3.3 (layer `Coins Bag 2.wav` under `Strong Accept.wav`), so the dependency can
be dropped entirely if the ambiguity is unwelcome.

### 9.5 The public-repo problem — the one genuine conflict

`TimGoergen/american-tycoon` is a **public** GitHub repository (verified 2026-08-07).

Both licensors that cover the bulk of the selection restrict distributing the audio
on its own:

- **Ovani:** *"You agree not to distribute, sell, or sublicense the Content on its own or
  separated from Attached Media."*
- **Tao & Sound:** prohibits allowing any user *"to extract the Asset or derivative works
  for use outside of that context."*

Committing raw `.wav`/`.ogg` files to a public repo lets anyone download the individual
sound files without the game — which is a plausible reading of exactly what both clauses
forbid. Shipping them compiled inside an APK is unambiguously fine; the exposure is the
**source tree**, not the build.

This is genuinely ambiguous rather than a clear breach — the files sit in a game project,
not a sample-pack listing — but it is the one place the licences and the current repo setup
actually pull against each other, and it is worth resolving deliberately.

Options, cheapest first:

1. **Accept it.** Defensible; many public game repos ship licensed audio. Lowest effort,
   non-zero risk, and the risk is the vendor's to raise.
2. **Keep audio out of git; fetch at build time.** The existing GitHub Actions pipeline
   pulls the files from a private location before export. Preserves the public repo, keeps
   raw assets off it. Most work.
3. **Make the repo private.** Removes the question entirely. Affects nothing else in the
   pipeline — releases and Firebase distribution work the same.
4. **Ask the vendors.** Both have support channels; a written yes is worth more than this
   analysis.

### DECIDED (Tim, 2026-08-07): option 1 — keep the audio in the public repo.

Tim stated for the record that **he is not currently committed to ever publishing this game
commercially**. That materially lowers the stakes: every clause reviewed above is concerned
with commercial redistribution of the assets, and an unpublished hobby project sits well
inside all three licences. The four options above are kept for the record, not as open
questions. **Do not re-litigate this.**

Two things remain true regardless of that decision, and are NOT covered by it:

1. **The Tao & Sound attribution requirement (§9.2) still applies.** It is conditioned on
   using the asset in an application, not on selling one. 18 of the 26 recommended SFX are
   Tao & Sound. The ABOUT screen credits line and `game/audio/CREDITS.md` are still needed.
2. **If the game ever does head toward commercial release, this decision should be
   revisited before that happens** — not because the licences change, but because unwinding
   audio out of git history after the fact is far more work than the choice would have been.
   A pointer here is cheaper than rediscovering the question later.

### 9.6 Packs recommended for dropping — no licence issue either way

Hip Hop, Eastern, and Jazz (Ovani) and Horror (Tao & Sound) were set aside in §7 on
creative grounds. Nothing in their licences prevents use; they are simply the wrong music.
