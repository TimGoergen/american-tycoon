#!/usr/bin/env python3
"""
Deploy selected audio cue assets from licensed libraries in D:\\Downloads\\Game_Audio
into the American Tycoon Godot project (game/audio/cues and game/audio/loops).
"""

import os
import json
import soundfile as sf

WORKSPACE = r"c:\Claude\American Tycoon"
SRC_BASE = r"D:\Downloads\Game_Audio"
PLANS_DIR = os.path.join(WORKSPACE, "Plans")
CUES_DIR = os.path.join(WORKSPACE, "game", "audio", "cues")
LOOPS_DIR = os.path.join(WORKSPACE, "game", "audio", "loops")
MUSIC_DIR = os.path.join(WORKSPACE, "game", "audio", "music")

EXPORT_DATA = {
  "export_date": "2026-08-17T04:14:27.407Z",
  "app": "American Tycoon",
  "total_assigned_cues": 31,
  "selections": {
    "bball_grab": [],
    "tap_note": [
      {
        "file_id": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
        "rel_path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
        "filename": "Button 6.wav",
        "pack": "puzzleaudiokit",
        "role": "primary",
        "duration": 0.099
      }
    ],
    "buy_success": [
      {
        "file_id": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip6.mp3",
        "rel_path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip6.mp3",
        "filename": "CoinFlip6.mp3",
        "pack": "inventorysfxbundle_audio",
        "role": "primary",
        "duration": 0.867
      }
    ],
    "hire_first": [
      {
        "file_id": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Craft Button 2.wav",
        "rel_path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Craft Button 2.wav",
        "filename": "Craft Button 2.wav",
        "pack": "buildingandcraftingaudiobundle",
        "role": "primary",
        "duration": 1.3
      }
    ],
    "hire_levelled": [
      {
        "file_id": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Mining (diamond) 1.wav",
        "rel_path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Mining (diamond) 1.wav",
        "filename": "Mining (diamond) 1.wav",
        "pack": "buildingandcraftingaudiobundle",
        "role": "primary",
        "duration": 0.263
      }
    ],
    "retain_staff": [
      {
        "file_id": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip5.mp3",
        "rel_path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip5.mp3",
        "filename": "CoinFlip5.mp3",
        "pack": "inventorysfxbundle_audio",
        "role": "primary",
        "duration": 0.827
      }
    ],
    "cycle_started": [
      {
        "file_id": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Steps/Horse (sand) 1.wav",
        "rel_path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Steps/Horse (sand) 1.wav",
        "filename": "Horse (sand) 1.wav",
        "pack": "westernaudiobundle",
        "role": "primary",
        "duration": 0.254
      }
    ],
    "frenzy_pop": [
      {
        "file_id": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Lever 3 (Power On).wav",
        "rel_path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Lever 3 (Power On).wav",
        "filename": "Lever 3 (Power On).wav",
        "pack": "puzzleaudiokit",
        "role": "primary",
        "duration": 1.176
      }
    ],
    "overdrive_engage": [
      {
        "file_id": "puzzleaudiokit/Puzzle Audio Bundle/MP3/FX/Misc/Clock Alarm 1 (loop).mp3",
        "rel_path": "puzzleaudiokit/Puzzle Audio Bundle/MP3/FX/Misc/Clock Alarm 1 (loop).mp3",
        "filename": "Clock Alarm 1 (loop).mp3",
        "pack": "puzzleaudiokit",
        "role": "primary",
        "duration": 0.767
      }
    ],
    "vent_tick": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
        "filename": "Puntuation Sound.wav",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 0.05
      }
    ],
    "vent_open": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Button 2.wav",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Button 2.wav",
        "filename": "Button 2.wav",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 0.251
      }
    ],
    "vent_lift": [
      {
        "file_id": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Place Diamond.wav",
        "rel_path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Place Diamond.wav",
        "filename": "Place Diamond.wav",
        "pack": "buildingandcraftingaudiobundle",
        "role": "primary",
        "duration": 0.32
      }
    ],
    "vent_success": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav",
        "filename": "Communication Recieving 2.wav",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 0.403
      }
    ],
    "vent_miss": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Buzzer.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Buzzer.wav",
        "filename": "Buzzer.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.337
      }
    ],
    "overheat": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/MP3/FX/Decompression 2.mp3",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/MP3/FX/Decompression 2.mp3",
        "filename": "Decompression 2.mp3",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 2.43
      }
    ],
    "rush_ready": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
        "filename": "Scoreboard Ding.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.408
      }
    ],
    "heat_loop": [
      {
        "file_id": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Gear 3 (loop).wav",
        "rel_path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Gear 3 (loop).wav",
        "filename": "Gear 3 (loop).wav",
        "pack": "puzzleaudiokit",
        "role": "primary",
        "duration": 1.65
      }
    ],
    "tab_switch": [
      {
        "file_id": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Weapons/Bullet impact 6.wav",
        "rel_path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Weapons/Bullet impact 6.wav",
        "filename": "Bullet impact 6.wav",
        "pack": "westernaudiobundle",
        "role": "primary",
        "duration": 0.108
      }
    ],
    "mode_toggle": [
      {
        "file_id": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
        "rel_path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
        "filename": "Button 6.wav",
        "pack": "puzzleaudiokit",
        "role": "primary",
        "duration": 0.099
      }
    ],
    "epoch_page": [
      {
        "file_id": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 10.wav",
        "rel_path": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 10.wav",
        "filename": "Slide Button 10.wav",
        "pack": "buttonssfxlibrary",
        "role": "primary",
        "duration": 0.55
      }
    ],
    "make_contact": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Teleportation.wav",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Teleportation.wav",
        "filename": "Teleportation.wav",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 2.65
      }
    ],
    "tip_appear": [
      {
        "file_id": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav",
        "rel_path": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav",
        "filename": "Bubble Button 5.wav",
        "pack": "buttonssfxlibrary",
        "role": "primary",
        "duration": 0.533
      }
    ],
    "minigame_begin": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Whistle/Whistle Blow Normal.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Whistle/Whistle Blow Normal.wav",
        "filename": "Whistle Blow Normal.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.975
      }
    ],
    "minigame_score": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
        "filename": "Scoreboard Ding.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.408
      }
    ],
    "minigame_miss": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
        "filename": "Scoreboard Timer A.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.208
      }
    ],
    "minigame_countdown": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
        "filename": "Puntuation Sound.wav",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 0.05
      }
    ],
    "minigame_over": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Buzzer.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Buzzer.wav",
        "filename": "Scoreboard Buzzer.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.936
      }
    ],
    "bball_launch": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Baseball - Cricket/Ball Throw Fast.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Baseball - Cricket/Ball Throw Fast.wav",
        "filename": "Ball Throw Fast.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.452
      }
    ],
    "bball_fizzle": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
        "filename": "Scoreboard Timer A.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.208
      }
    ],
    "bball_wall": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Normal.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Normal.wav",
        "filename": "Generic Bounce Normal.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 0.655
      }
    ],
    "bball_swish": [
      {
        "file_id": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Net Swoosh Normal.wav",
        "rel_path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Net Swoosh Normal.wav",
        "filename": "Net Swoosh Normal.wav",
        "pack": "Foley Sports Sound FX Pack",
        "role": "primary",
        "duration": 1.125
      }
    ],
    "band_0_blue_collar": [
      {
        "file_id": "Jazz Music Pack/Jazz Music Pack/Harlem Nights (RT 3.003)/Jazz Harlem Nights Intensity 2.wav",
        "rel_path": "Jazz Music Pack/Jazz Music Pack/Harlem Nights (RT 3.003)/Jazz Harlem Nights Intensity 2.wav",
        "filename": "Jazz Harlem Nights Intensity 2.wav",
        "pack": "Jazz Music Pack",
        "role": "variant_1",
        "duration": 161.881
      }
    ],
    "band_1_white_collar": [
      {
        "file_id": "Corporate Music Pack Vol. 1/The Simulation (RT 2.182)/Corporate The Simulation Intensity 2.wav",
        "rel_path": "Corporate Music Pack Vol. 1/The Simulation (RT 2.182)/Corporate The Simulation Intensity 2.wav",
        "filename": "Corporate The Simulation Intensity 2.wav",
        "pack": "Corporate Music Pack Vol. 1",
        "role": "primary",
        "duration": 146.049
      },
      {
        "file_id": "Corporate Music Pack Vol. 1/The Simulation (RT 2.182)/Corporate The Simulation Main.wav",
        "rel_path": "Corporate Music Pack Vol. 1/The Simulation (RT 2.182)/Corporate The Simulation Main.wav",
        "filename": "Corporate The Simulation Main.wav",
        "pack": "Corporate Music Pack Vol. 1",
        "role": "layer",
        "duration": 146.049
      }
    ],
    "band_2_early_contact": [
      {
        "file_id": "spaceaudiobundle/Space Audio Bundle/MP3/Music/A Tale From Outer Space.mp3",
        "rel_path": "spaceaudiobundle/Space Audio Bundle/MP3/Music/A Tale From Outer Space.mp3",
        "filename": "A Tale From Outer Space.mp3",
        "pack": "spaceaudiobundle",
        "role": "primary",
        "duration": 59.294
      }
    ],
    "band_3_mid": [
      {
        "file_id": "Ethereal Music Pack Vol. 3/Ethereal Music Pack Vol. 3/Mystics (RT 13.197)/Ethereal Vol3 Mystics Intensity 2.wav",
        "rel_path": "Ethereal Music Pack Vol. 3/Ethereal Music Pack Vol. 3/Mystics (RT 13.197)/Ethereal Vol3 Mystics Intensity 2.wav",
        "filename": "Ethereal Vol3 Mystics Intensity 2.wav",
        "pack": "Ethereal Music Pack Vol. 3",
        "role": "variant_1",
        "duration": 166.919
      },
      {
        "file_id": "Ethereal Music Pack Vol. 3/Ethereal Music Pack Vol. 3/Mystics (RT 13.197)/Ethereal Vol3 Mystics Main.wav",
        "rel_path": "Ethereal Music Pack Vol. 3/Ethereal Music Pack Vol. 3/Mystics (RT 13.197)/Ethereal Vol3 Mystics Main.wav",
        "filename": "Ethereal Vol3 Mystics Main.wav",
        "pack": "Ethereal Music Pack Vol. 3",
        "role": "layer",
        "duration": 166.919
      }
    ],
    "band_4_deep": [
      {
        "file_id": "Corporate Music Pack Vol. 1/Space Intruder (RT 4)/Corporate Space Intruder Cut 30.wav",
        "rel_path": "Corporate Music Pack Vol. 1/Space Intruder (RT 4)/Corporate Space Intruder Cut 30.wav",
        "filename": "Corporate Space Intruder Cut 30.wav",
        "pack": "Corporate Music Pack Vol. 1",
        "role": "primary",
        "duration": 58.776
      }
    ]
  },
  "shortlisted_candidates": {
    "ceremony_contact": [
      "magicspellssfxbundle_audio/magicspellssfxbundle/Stereo/Misc/Spell Fail 5.mp3"
    ],
    "ceremony_fanfare": [
      "westernaudiobundle/Western Audio Bundle/WAV/SFX/Buttons and Stingers/Stinger 8.wav",
      "westernaudiobundle/Western Audio Bundle/MP3/FX/Buttons and Stingers/Stinger 15.mp3"
    ],
    "minigame_begin": [
      "buttonssfxlibrary/Buttons SFX Library/WAV/Start/Start Button 7.wav",
      "buttonssfxlibrary/Buttons SFX Library/WAV/Start/Start Button 5.wav"
    ]
  }
}


def main():
    export_json_path = os.path.join(PLANS_DIR, "Audio_Selection_Export.json")
    if os.path.exists(export_json_path):
        with open(export_json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"Loaded selections from {export_json_path}")
    else:
        data = EXPORT_DATA
        os.makedirs(PLANS_DIR, exist_ok=True)
        with open(export_json_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"Export JSON saved to {export_json_path}")

    # Deploy audio files
    deployed_count = 0
    deployed_credits = []
    deployed_music = []

    for cue_id, selections in data.get("selections", {}).items():
        if not selections:
            print(f"Skipping unassigned cue: {cue_id}")
            continue
        sel = selections[0]
        rel_path = sel["rel_path"].replace("/", os.sep)
        src_path = os.path.join(SRC_BASE, rel_path)
        
        if not os.path.exists(src_path):
            print(f"ERROR: Source file missing: {src_path}")
            continue

        if cue_id.startswith("band_"):
            target_dir = MUSIC_DIR
        elif cue_id in ("heat_loop", "urgency_loop"):
            target_dir = LOOPS_DIR
        else:
            target_dir = CUES_DIR
        os.makedirs(target_dir, exist_ok=True)

        try:
            samples, sr = sf.read(src_path)

            wav_path = os.path.join(target_dir, f"{cue_id}.wav")
            sf.write(wav_path, samples, sr, format="WAV", subtype="PCM_16")

            if cue_id.startswith("band_"):
                for ext in [".ogg", ".ogg.import"]:
                    old_f = os.path.join(target_dir, f"{cue_id}{ext}")
                    if os.path.exists(old_f):
                        os.remove(old_f)
                deployed_music.append((cue_id, sel["filename"], sel["pack"]))
            else:
                ogg_path = os.path.join(target_dir, f"{cue_id}.ogg")
                sf.write(ogg_path, samples, sr, format="OGG", subtype="VORBIS")
                deployed_credits.append((cue_id, sel["filename"], sel["pack"]))

            deployed_count += 1
            print(f"[{deployed_count:02d}] Deployed '{cue_id}' from '{sel['pack']}/{sel['filename']}' ({len(samples)/sr:.2f}s)")
        except Exception as e:
            print(f"ERROR deploying '{cue_id}' from '{src_path}': {e}")

    # Update CREDITS.md
    credits_path = os.path.join(WORKSPACE, "game", "audio", "CREDITS.md")
    with open(credits_path, "w", encoding="utf-8") as f:
        f.write("# Audio credits and licenses\n\n")
        f.write("Every audio file in `game/audio/` gets a line here, with its source, license, and any required\n")
        f.write("attribution — added **when the file is added**, not later.\n\n")
        f.write("If a file is here, it is cleared for a commercial release.\n\n")
        f.write("## Sourced SFX and Loops\n\n")
        f.write("Updated from the owned audio pack library (`D:\\Downloads\\Game_Audio\\`).\n\n")
        f.write("| Cue / Loop ID | Source File | Pack | License / Attribution |\n")
        f.write("|---|---|---|---|\n")
        for cue_id, fn, pk in deployed_credits:
            f.write(f"| `{cue_id}` | `{fn}` | {pk} | Commercial royalty-free |\n")
        f.write("\n## Music\n\n")
        f.write("Tracks live in `music/`, one per era band.\n\n")
        f.write("| Track / Band | Source File | Pack | License / Attribution |\n")
        f.write("|---|---|---|---|\n")
        for cue_id, fn, pk in deployed_music:
            f.write(f"| `{cue_id}` | `{fn}` | {pk} | Commercial royalty-free |\n")

    print(f"\nCompleted deployment of {deployed_count} cues and updated CREDITS.md.")


if __name__ == "__main__":
    main()

