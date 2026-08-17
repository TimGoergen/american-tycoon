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
    ]
  }
}


def main():
    # 1. Save export json to Plans/
    os.makedirs(PLANS_DIR, exist_ok=True)
    export_json_path = os.path.join(PLANS_DIR, "Audio_Selection_Export.json")
    with open(export_json_path, "w", encoding="utf-8") as f:
        json.dump(EXPORT_DATA, f, indent=2)
    print(f"Export JSON saved to {export_json_path}")

    # 2. Deploy audio files
    deployed_count = 0
    for cue_id, selections in EXPORT_DATA["selections"].items():
        if not selections:
            print(f"Skipping unassigned cue: {cue_id}")
            continue
        sel = selections[0]
        rel_path = sel["rel_path"].replace("/", os.sep)
        src_path = os.path.join(SRC_BASE, rel_path)
        
        if not os.path.exists(src_path):
            print(f"ERROR: Source file missing: {src_path}")
            continue

        target_dir = LOOPS_DIR if cue_id == "heat_loop" else CUES_DIR
        os.makedirs(target_dir, exist_ok=True)

        samples, sr = sf.read(src_path)

        ogg_path = os.path.join(target_dir, f"{cue_id}.ogg")
        wav_path = os.path.join(target_dir, f"{cue_id}.wav")

        sf.write(ogg_path, samples, sr, format="OGG", subtype="VORBIS")
        sf.write(wav_path, samples, sr, format="WAV", subtype="PCM_16")

        deployed_count += 1
        print(f"[{deployed_count:02d}] Deployed '{cue_id}' from '{sel['pack']}/{sel['filename']}' ({len(samples)/sr:.2f}s)")

    print(f"\nCompleted deployment of {deployed_count} cues.")


if __name__ == "__main__":
    main()
