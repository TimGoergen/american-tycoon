#!/usr/bin/env python3
"""
Audio Database & Recommendation Generator for American Tycoon.
Scans D:\\Downloads\\Game_Audio and game/audio, parses durations,
maps game cues to candidate audio files, ranks matches by recommendation strength,
and writes tools/audio_review_data.json.
"""

import os
import sys
import json
import re
import struct
import wave
from pathlib import Path

GAME_AUDIO_DIR = r"D:\Downloads\Game_Audio"
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_AUDIO_DIR = os.path.join(WORKSPACE_DIR, "game", "audio")
OUTPUT_JSON_PATH = os.path.join(WORKSPACE_DIR, "tools", "audio_review_data.json")

# Structure of Sections and Cues from game/sim/AudioCueDoc.gd & Audio.gd
CUE_GROUPS = [
    {
        "id": "core_loop",
        "name": "The Core Loop",
        "description": "Primary economic engine interactions: tapping, purchasing, hiring, milestones, and frenzy.",
        "cues": ["tap_note", "buy_success", "hire_first", "hire_levelled", "retain_staff", "milestone", "cycle_started", "frenzy_pop", "frenzy_end"]
    },
    {
        "id": "rush_overdrive",
        "name": "Rush and Overdrive",
        "description": "High-risk momentum mechanics: heat build-up, vent window timing, successes, misses, overheat and loops.",
        "cues": ["overdrive_engage", "vent_tick", "vent_open", "vent_lift", "vent_success", "vent_miss", "overheat", "rush_ready", "heat_loop", "urgency_loop"]
    },
    {
        "id": "interface",
        "name": "Interface",
        "description": "UI transitions and core navigational feedback.",
        "cues": ["tab_switch", "screen_open", "screen_close", "mode_toggle", "epoch_page", "make_contact", "tip_appear"]
    },
    {
        "id": "denials",
        "name": "Denials (Reserved)",
        "description": "Feedback when an action cannot be performed (e.g. insufficient cash or locked state).",
        "cues": ["denied_cash", "denied_locked"]
    },
    {
        "id": "challenge_mode",
        "name": "Challenge Mode",
        "description": "Time-attack and score ladder cues for challenge sessions.",
        "cues": ["challenge_start", "challenge_credit", "challenge_tier"]
    },
    {
        "id": "minigames_shared",
        "name": "Minigames — Shared Beats",
        "description": "Universal sound framework across all six arcade minigames.",
        "cues": ["minigame_begin", "minigame_score", "minigame_miss", "minigame_countdown", "minigame_best", "minigame_over"]
    },
    {
        "id": "basketball",
        "name": "Basketball",
        "description": "Slingshot mechanics, wall/floor bounces, net swish, rim-outs, and legacy shots.",
        "cues": ["bball_grab", "bball_launch", "bball_fizzle", "bball_wall", "bball_floor", "bball_settle", "bball_rim", "bball_score", "bball_swish", "bball_gem_through", "bball_gem_earned"]
    },
    {
        "id": "match_three",
        "name": "Match Three",
        "description": "Gem swapping, cascade chains, falling refills, avoid gem penalties, and legacy collection.",
        "cues": ["m3_select", "m3_swap", "m3_invalid", "m3_match", "m3_fall", "m3_avoid", "m3_legacy"]
    },
    {
        "id": "catch_money",
        "name": "Catch Money",
        "description": "Fast-paced falling coin catches, coin varieties, misses, and spawn rhythms.",
        "cues": ["catch_coin", "catch_premium", "catch_legacy", "catch_miss", "catch_spawn"]
    },
    {
        "id": "memory",
        "name": "Memory (Simon)",
        "description": "Pitched sequence pads, correct recall, error buzzers, and legacy bonuses.",
        "cues": ["mem_pad", "mem_round", "mem_wrong", "mem_gem"]
    },
    {
        "id": "balance",
        "name": "Balance",
        "description": "Continuous beam positioning, zone boundaries, lift impulses, and legacy rewards.",
        "cues": ["bal_enter", "bal_leave", "bal_lift", "bal_gem"]
    },
    {
        "id": "timing_bar",
        "name": "Timing Bar",
        "description": "Oscillating needle lock-in timing, target hits, misses, and legacy bonuses.",
        "cues": ["time_lock_hit", "time_lock_miss", "time_gem"]
    },
    {
        "id": "ceremony",
        "name": "Ceremony — Story Beats",
        "description": "Generational succession, heir reveals, first alien contacts, and dynasty legacies.",
        "cues": ["ceremony_obituary", "ceremony_will", "ceremony_heir", "ceremony_contact", "ceremony_contact_reveal", "ceremony_fanfare", "ceremony_power_down", "legacy_purchase", "welcome_back", "prestige_confirm"]
    },
    {
        "id": "music_tracks",
        "name": "Music & Era Ambience",
        "description": "Adaptive soundtrack evolving from Earth 1950s department-store muzak into alien space soundscapes.",
        "cues": ["band_0_blue_collar", "band_1_white_collar", "band_2_early_contact", "band_3_mid", "band_4_deep"]
    },
    {
        "id": "settings",
        "name": "Settings",
        "description": "Configuration and preview audio.",
        "cues": ["music_preview"]
    }
]

CUE_METADATA = {
    "tap_note": {
        "bus": "SFX", "db": -6.0, "cooldown": 45, "layered": False, "has_variants": True,
        "trigger": "Tapping CLOCK IN or a running property (a rush). Pitched across a pentatonic scale.",
        "ideal_duration": [0.05, 0.20],
        "keywords": ["counter", "tick", "button", "blip", "click", "tap", "typewriter", "scoreboard", "wood", "knock"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "buttonssfxlibrary", "puzzleaudiokit", "buildingandcraftingaudiobundle"]
    },
    "buy_success": {
        "bus": "SFX", "db": -3.0, "cooldown": 60, "layered": True, "has_variants": True,
        "trigger": "A property purchase completes. Volume scales with income boost. Uses _layer on big jumps.",
        "ideal_duration": [0.3, 1.3],
        "keywords": ["coins bag", "coin", "cash", "money", "register", "purchase", "buy", "pay", "gold"],
        "pack_affinities": ["westernaudiobundle", "buildingandcraftingaudiobundle", "inventorysfxbundle_audio"]
    },
    "hire_first": {
        "bus": "SFX", "db": -3.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "The FIRST staffer on a property — the moment it starts running itself.",
        "ideal_duration": [0.5, 1.8],
        "keywords": ["create engineer", "create", "hire", "worker", "contract", "stinger", "whistle", "fanfare", "craft"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "westernaudiobundle", "buttonssfxlibrary"]
    },
    "hire_levelled": {
        "bus": "SFX", "db": -7.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Any later staff level on an already-staffed property.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["create human", "create robot", "create", "promote", "upgrade", "worker", "level"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "inventorysfxbundle_audio"]
    },
    "retain_staff": {
        "bus": "SFX", "db": -6.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Buying staff retention in the Estate screen.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["contract", "stamp", "signature", "paper", "lock", "select", "equip", "coin"],
        "pack_affinities": ["westernaudiobundle", "inventorysfxbundle_audio", "buttonssfxlibrary"]
    },
    "milestone": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A property crosses a count milestone (25, 50, 100...). Fires on crossing.",
        "ideal_duration": [0.3, 1.8],
        "keywords": ["scoreboard ding", "ding", "bell", "levelup", "chime", "achievement", "triumph", "reward", "fanfare"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "inventorysfxbundle_audio", "puzzleaudiokit", "westernaudiobundle"]
    },
    "cycle_started": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Tapping a STOPPED property to start one cycle by hand (machine turnover, not payout).",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["lever", "crank", "gear", "switch", "turn", "start", "ratchet", "clunk", "pull"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "puzzleaudiokit", "westernaudiobundle"]
    },
    "frenzy_pop": {
        "bus": "SFX", "db": -2.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Popping the FRENZY meter.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["fire", "flame", "blast", "ignite", "burst", "power", "siren", "horn", "frenzy", "explode"],
        "pack_affinities": ["magicspellssfxbundle_audio", "spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "frenzy_end": {
        "bus": "SFX", "db": -10.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A frenzy burn runs out.",
        "ideal_duration": [0.4, 1.5],
        "keywords": ["steam", "cooldown", "hiss", "extinguish", "drain", "power down", "wind down", "fizzle"],
        "pack_affinities": ["spaceaudiobundle", "buildingandcraftingaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "overdrive_engage": {
        "bus": "SFX", "db": -3.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The OVERDRIVE button engaged, ride begins.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["engine rev", "thruster", "turbo", "boost", "engage", "ignition", "start", "alarm", "computer on"],
        "pack_affinities": ["spaceaudiobundle", "buildingandcraftingaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "vent_tick": {
        "bus": "SFX", "db": -12.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "One per required lift, counted out the instant the vent window opens.",
        "ideal_duration": [0.03, 0.25],
        "keywords": ["pacer beep", "beep", "tick", "telegraph", "metronome", "pip", "blip", "button 2"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "spaceaudiobundle", "buttonssfxlibrary"]
    },
    "vent_open": {
        "bus": "SFX", "db": -1.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "A vent window opens. Crucial gameplay telegraph to lift immediately.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["buzzer", "communication receiving", "alert", "horn", "klaxon", "warning", "open valve", "steam burst"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "vent_lift": {
        "bus": "SFX", "db": -6.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "Each lift registered inside the window. Pitched up one whole tone per lift.",
        "ideal_duration": [0.08, 0.4],
        "keywords": ["elevator", "whoosh", "lift", "valve", "pump", "piston", "generic spell end", "air release"],
        "pack_affinities": ["spaceaudiobundle", "magicspellssfxbundle_audio", "buildingandcraftingaudiobundle"]
    },
    "vent_success": {
        "bus": "SFX", "db": -2.0, "cooldown": 100, "layered": True, "has_variants": False,
        "trigger": "A vent completes in time. Intensity scales with vent tier reached.",
        "ideal_duration": [0.4, 2.8],
        "keywords": ["strong accept", "reward", "accept", "success", "chime", "vent release", "cooling", "complete"],
        "pack_affinities": ["Sci-Fi Horror Sound FX Pack Vol. 2", "puzzleaudiokit", "spaceaudiobundle"]
    },
    "vent_miss": {
        "bus": "SFX", "db": -4.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The vent window closes unmet — fires just before overheat.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["strong deny", "wrong", "deny", "error", "buzz", "fault", "miss", "fail"],
        "pack_affinities": ["Sci-Fi Horror Sound FX Pack Vol. 2", "puzzleaudiokit", "buttonssfxlibrary"]
    },
    "overheat": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The ride ends in flames. Heat drains, rushing is locked out.",
        "ideal_duration": [0.8, 4.0],
        "keywords": ["decompression", "vent exhale", "steam burst", "explosion", "breakdown", "overheat", "exhaust", "sizzle"],
        "pack_affinities": ["spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2", "buildingandcraftingaudiobundle"]
    },
    "rush_ready": {
        "bus": "SFX", "db": -8.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The lockout ends and rushing is live again.",
        "ideal_duration": [0.2, 1.2],
        "keywords": ["computer on", "scoreboard ding", "ready", "recharge", "boot", "chime", "power on"],
        "pack_affinities": ["spaceaudiobundle", "Foley Sports Sound FX Pack", "buttonssfxlibrary"]
    },
    "heat_loop": {
        "bus": "SFX", "db": -16.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous mechanical drone held while momentum/heat is active.",
        "ideal_duration": [1.5, 30.0],
        "keywords": ["truck gear idle", "gear loop", "engine loop", "idle loop", "hum loop", "electric loop", "drone", "motor"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "puzzleaudiokit", "magicspellssfxbundle_audio"]
    },
    "urgency_loop": {
        "bus": "SFX", "db": -14.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous rising tension sound held as heat approaches critical redline.",
        "ideal_duration": [1.5, 30.0],
        "keywords": ["saw loop", "pathetic alarm", "alarm loop", "tension loop", "pulsing", "siren loop", "urgency", "warning"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2", "spaceaudiobundle"]
    },
    "tab_switch": {
        "bus": "UI", "db": -10.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Changing tab, and only when the tab actually changes.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["slide button", "slide", "whoosh", "switch", "swipe", "page flip", "paper"],
        "pack_affinities": ["buttonssfxlibrary", "westernaudiobundle", "puzzleaudiokit"]
    },
    "screen_open": {
        "bus": "UI", "db": -9.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Opening a modal screen: About, Stats, Challenges, Help, Tuning.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["open drawer", "open", "popup", "select button", "drawer", "whoosh in", "expand"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "westernaudiobundle"]
    },
    "screen_close": {
        "bus": "UI", "db": -11.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Closing a modal screen.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["close drawer", "close", "popdown", "cancel", "dismiss", "whoosh out", "drawer"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "westernaudiobundle"]
    },
    "mode_toggle": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "The buy-mode or hire-mode toggle.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["click button", "toggle", "switch", "click", "tick", "button", "flick"],
        "pack_affinities": ["buttonssfxlibrary", "westernaudiobundle", "puzzleaudiokit"]
    },
    "epoch_page": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "The epoch pager moves to another civilization.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["slide button", "paper turn", "page flip", "slide", "carousel", "flick"],
        "pack_affinities": ["buttonssfxlibrary", "westernaudiobundle", "puzzleaudiokit"]
    },
    "make_contact": {
        "bus": "UI", "db": -1.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "The MAKE CONTACT button — the biggest action button in the game.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["teleportation", "beam me up", "portal", "warp", "contact", "power surge", "stinger", "select button 1"],
        "pack_affinities": ["spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2", "buttonssfxlibrary"]
    },
    "tip_appear": {
        "bus": "UI", "db": -12.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A tutorial coach card appears.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["bubble", "pop", "tip", "notification", "chime", "hint", "bell", "appear"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "inventorysfxbundle_audio"]
    },
    "denied_cash": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "Reserved: an action refused for want of money.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["wrong", "deny", "dull thud", "empty", "no", "buzz", "lock", "refuse"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "westernaudiobundle"]
    },
    "denied_locked": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "Reserved: an action refused because something is locked.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["lock", "padlock", "chain", "rattle", "deny", "metal rattle", "locked"],
        "pack_affinities": ["westernaudiobundle", "buildingandcraftingaudiobundle", "puzzleaudiokit"]
    },
    "challenge_start": {
        "bus": "UI", "db": -6.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Launching a game from the CHALLENGES screen.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["start", "ready go", "whistle", "buzzer", "launch", "gong", "alarm", "charge"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle", "buttonssfxlibrary"]
    },
    "challenge_credit": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "A challenge run ends and its score is credited.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["coins pouring", "tally", "score count", "reward", "stinger", "coins bag", "credit"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "puzzleaudiokit"]
    },
    "challenge_tier": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "A challenge run climbs a tier of its ladder mid-run.",
        "ideal_duration": [0.6, 2.2],
        "keywords": ["levelup", "ladder", "rank up", "fanfare", "tier", "stinger", "chime"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "minigame_begin": {
        "bus": "UI", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "BEGIN on a minigame Get Ready gate — the round starts.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["whistle", "buzzer", "go", "start", "ready", "stinger", "ding"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle", "buttonssfxlibrary"]
    },
    "minigame_score": {
        "bus": "SFX", "db": -8.0, "cooldown": 40, "layered": False, "has_variants": False,
        "trigger": "The player scores in any minigame (shared layer across all 6 games).",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["coin", "ding", "point", "score", "hit", "pickup", "ping", "reward"],
        "pack_affinities": ["inventorysfxbundle_audio", "Foley Sports Sound FX Pack", "puzzleaudiokit"]
    },
    "minigame_miss": {
        "bus": "SFX", "db": -7.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A miss that costs challenge time (shared miss channel).",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["wrong", "buzz", "miss", "fail", "error", "thud", "bonk"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "Foley Sports Sound FX Pack"]
    },
    "minigame_countdown": {
        "bus": "UI", "db": -9.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "One per second over the last few seconds of the minigame clock.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["tick", "beep", "clock", "countdown", "timer", "pacer beep", "woodblock"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "buttonssfxlibrary", "spaceaudiobundle"]
    },
    "minigame_best": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "The run passes the stored high score. Once per run.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["fanfare", "high score", "record", "victory", "triumph", "stinger", "applause", "cheer"],
        "pack_affinities": ["westernaudiobundle", "inventorysfxbundle_audio", "Foley Sports Sound FX Pack"]
    },
    "minigame_over": {
        "bus": "UI", "db": -4.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "A minigame round or challenge run ends.",
        "ideal_duration": [0.5, 2.5],
        "keywords": ["buzzer", "whistle", "game over", "time out", "gong", "horn", "finish"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "bball_grab": {
        "bus": "SFX", "db": -16.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A finger takes the ball and slingshot drag begins.",
        "ideal_duration": [0.08, 0.3],
        "keywords": ["leather", "grab", "shoe squeak", "friction", "ball catch", "drag", "grip"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle", "puzzleaudiokit"]
    },
    "bball_launch": {
        "bus": "SFX", "db": -6.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "The throw is released. Scaled by pull force.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["whoosh", "swoosh", "throw", "release", "slingshot", "launch", "whip"],
        "pack_affinities": ["magicspellssfxbundle_audio", "Foley Sports Sound FX Pack", "westernaudiobundle"]
    },
    "bball_fizzle": {
        "bus": "SFX", "db": -14.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "Released under minimum pull — ball drops without throw.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["drop", "dull", "plop", "thud", "fizzle", "weak", "soft bounce"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "puzzleaudiokit"]
    },
    "bball_wall": {
        "bus": "SFX", "db": -12.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "The ball bounces off a side wall or ceiling.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["basketball bounce", "wall impact", "thud", "backboard", "rebound", "wood thud"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "buildingandcraftingaudiobundle"]
    },
    "bball_floor": {
        "bus": "SFX", "db": -11.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "The ball lands on the hardwood gym floor.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["basketball bounce", "hardwood bounce", "floor bounce", "ball drop", "dribble"],
        "pack_affinities": ["Foley Sports Sound FX Pack"]
    },
    "bball_settle": {
        "bus": "SFX", "db": -18.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "The ball stops rolling and becomes throwable again.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["roll stop", "settle", "soft tap", "ball roll", "rest"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "puzzleaudiokit"]
    },
    "bball_rim": {
        "bus": "SFX", "db": -8.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "Clipping a rim post — the rim-out.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["rim hit", "metal clang", "iron", "pole hit", "clank", "hoop"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "buildingandcraftingaudiobundle", "westernaudiobundle"]
    },
    "bball_score": {
        "bus": "SFX", "db": -5.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "A made basket. Layers over shared minigame_score.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["basket", "swish", "net", "score", "cheer", "hoop score"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle"]
    },
    "bball_swish": {
        "bus": "SFX", "db": -3.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "A clean centered drop — the gold SWISH! Layers over minigame_score.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["swish", "clean net", "cloth swoosh", "perfect basket", "flutter", "nylon"],
        "pack_affinities": ["Foley Sports Sound FX Pack", "westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "bball_gem_through": {
        "bus": "SFX", "db": -8.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "The ball passes through the Legacy gem. A promise, not yet a payout.",
        "ideal_duration": [0.2, 0.7],
        "keywords": ["crystal chime", "gem touch", "shimmer", "glass pass", "sparkle", "ping"],
        "pack_affinities": ["magicspellssfxbundle_audio", "puzzleaudiokit", "inventorysfxbundle_audio"]
    },
    "bball_gem_earned": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "Shot passed through gem AND scored — rarest basketball outcome, pays Legacy.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["gem fanfare", "revive", "stinger", "jackpot", "magic reward", "crystal chime", "legacy"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "m3_select": {
        "bus": "SFX", "db": -16.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "A gem is picked up — the drag begins.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["crystal tap", "gem click", "glass touch", "bead", "select", "tick"],
        "pack_affinities": ["puzzleaudiokit", "magicspellssfxbundle_audio", "buttonssfxlibrary"]
    },
    "m3_swap": {
        "bus": "SFX", "db": -11.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Two gems trade places.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["glass slide", "gem swap", "marble slide", "switch", "friction", "glide"],
        "pack_affinities": ["puzzleaudiokit", "westernaudiobundle", "buttonssfxlibrary"]
    },
    "m3_invalid": {
        "bus": "SFX", "db": -10.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A swap matched nothing; gems slide back.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["wrong", "dull click", "slide back", "invalid", "refusal", "wood block", "deny"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary"]
    },
    "m3_match": {
        "bus": "SFX", "db": -6.0, "cooldown": 30, "layered": False, "has_variants": False,
        "trigger": "A match clears. Pitched up a whole tone per cascade step.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["crystal shatter", "gem match", "chime", "sparkle", "burst", "glass break", "spell hit"],
        "pack_affinities": ["magicspellssfxbundle_audio", "puzzleaudiokit", "inventorysfxbundle_audio"]
    },
    "m3_fall": {
        "bus": "SFX", "db": -15.0, "cooldown": 40, "layered": False, "has_variants": False,
        "trigger": "Refill gems drop into empty grid spaces.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["marbles falling", "gem drops", "cascade rattle", "rattle", "beads", "trickle"],
        "pack_affinities": ["puzzleaudiokit", "westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "m3_avoid": {
        "bus": "SFX", "db": -5.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "A match that hit the AVOID gem — the main hazard penalty.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["skull", "dark magic", "curse", "poison", "alarm", "wrong", "hazard", "shock"],
        "pack_affinities": ["magicspellssfxbundle_audio", "Sci-Fi Horror Sound FX Pack Vol. 2", "puzzleaudiokit"]
    },
    "m3_legacy": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem is collected in Match Three.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["crystal summon", "magic reward", "grand chime", "legacy", "gem collect", "sparkle stinger"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "catch_coin": {
        "bus": "SFX", "db": -10.0, "cooldown": 25, "layered": False, "has_variants": True,
        "trigger": "An ordinary falling coin caught (most repeated sound in game).",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["coin pickup", "coin 1", "coin 2", "coin clink", "small coin", "card deliver"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "buildingandcraftingaudiobundle"]
    },
    "catch_premium": {
        "bus": "SFX", "db": -5.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A premium gold coin caught, worth multiple coins.",
        "ideal_duration": [0.2, 0.7],
        "keywords": ["gold coin", "coin bag", "heavy coin", "coins 2", "premium coin", "rich clink"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "buildingandcraftingaudiobundle"]
    },
    "catch_legacy": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "The JACKPOT Legacy coin caught — pays dynasty points.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["jackpot", "coins pouring", "coin shower", "fortune", "magic coin", "legacy chime"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "catch_miss": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A coin reaches floor uncaught.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["coin drop floor", "coin roll", "floor bounce", "clatter", "miss", "lost coin"],
        "pack_affinities": ["westernaudiobundle", "inventorysfxbundle_audio", "puzzleaudiokit"]
    },
    "catch_spawn": {
        "bus": "SFX", "db": -22.0, "cooldown": 25, "layered": False, "has_variants": False,
        "trigger": "A coin appears at the top. Quiet, makes spawn rate audible.",
        "ideal_duration": [0.04, 0.18],
        "keywords": ["soft pop", "blip", "drop", "spawn", "light tick", "droplet"],
        "pack_affinities": ["puzzleaudiokit", "buttonssfxlibrary", "inventorysfxbundle_audio"]
    },
    "mem_pad": {
        "bus": "SFX", "db": -7.0, "cooldown": 20, "layered": False, "has_variants": False,
        "trigger": "A pad lights during playback or player tap. Pitched per pad.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["synthesizer tone", "pure tone", "chime", "bell", "pad tone", "marimba", "electronic note", "button"],
        "pack_affinities": ["buttonssfxlibrary", "spaceaudiobundle", "puzzleaudiokit", "westernaudiobundle"]
    },
    "mem_round": {
        "bus": "SFX", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The whole sequence recalled correctly.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["success tune", "arpeggio", "sequence clear", "reward", "correct", "chime flourish"],
        "pack_affinities": ["puzzleaudiokit", "westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "mem_wrong": {
        "bus": "SFX", "db": -3.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The wrong pad tapped. Game ends on this sound.",
        "ideal_duration": [0.4, 1.6],
        "keywords": ["wrong sequence", "error buzz", "dissonant", "fail", "strong deny", "game over buzz"],
        "pack_affinities": ["puzzleaudiokit", "Sci-Fi Horror Sound FX Pack Vol. 2", "buttonssfxlibrary"]
    },
    "mem_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem earned in the bonus round.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["gem chime", "sparkle", "revive", "magic flourish", "legacy", "crystal reward"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "bal_enter": {
        "bus": "SFX", "db": -9.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "The beam crosses INTO the scoring zone.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["hum on", "zone enter", "lock", "chime in", "activate", "resonance in", "gentle tone"],
        "pack_affinities": ["spaceaudiobundle", "puzzleaudiokit", "magicspellssfxbundle_audio"]
    },
    "bal_leave": {
        "bus": "SFX", "db": -11.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "The beam drifts back out of the scoring zone.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["hum off", "zone exit", "dissipate", "fade tone", "resonance out", "click"],
        "pack_affinities": ["spaceaudiobundle", "puzzleaudiokit", "magicspellssfxbundle_audio"]
    },
    "bal_lift": {
        "bus": "SFX", "db": -16.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "The lift button is pressed to pulse the beam.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["thruster puff", "air pulse", "valve click", "lift pulse", "short click", "blip"],
        "pack_affinities": ["spaceaudiobundle", "buttonssfxlibrary", "puzzleaudiokit"]
    },
    "bal_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem earned by holding the zone long enough.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["shimmer", "gem earned", "harmony", "magic bell", "legacy", "reward"],
        "pack_affinities": ["magicspellssfxbundle_audio", "inventorysfxbundle_audio", "westernaudiobundle"]
    },
    "time_lock_hit": {
        "bus": "SFX", "db": -5.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A lock inside the target zone on the oscillating timing bar.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["heavy lock", "dead center", "target hit", "bullseye", "strong accept", "snap", "latch"],
        "pack_affinities": ["buildingandcraftingaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2", "westernaudiobundle"]
    },
    "time_lock_miss": {
        "bus": "SFX", "db": -8.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A lock outside the target zone.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["miss click", "metal glancing", "off target", "error", "ricochet", "dull tap"],
        "pack_affinities": ["westernaudiobundle", "puzzleaudiokit", "buildingandcraftingaudiobundle"]
    },
    "time_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A lock that also collected the pending Legacy gem.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["crystal target", "perfect lock", "gem reward", "magic bell", "legacy"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "ceremony_obituary": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The succession obituary card appears.",
        "ideal_duration": [2.0, 8.0],
        "keywords": ["bell 1", "funeral bell", "deep toll", "gong", "solemn chime", "church bell", "legacy"],
        "pack_affinities": ["westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "ceremony_will": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The reading of the tycoon's will.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["paper unfold", "parchment", "wax seal", "legal tone", "solemn strings", "reading"],
        "pack_affinities": ["westernaudiobundle", "magicspellssfxbundle_audio", "inventorysfxbundle_audio"]
    },
    "ceremony_heir": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The heir reveal — the bloodline continues.",
        "ideal_duration": [2.0, 7.0],
        "keywords": ["revive 3", "revive", "triumph", "majestic fanfare", "rebirth", "stinger 15", "dynasty"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle"]
    },
    "ceremony_contact": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "A First Contact alien card opens.",
        "ideal_duration": [2.0, 7.0],
        "keywords": ["teleportation", "beam me up", "generic spell summon", "light speed", "alien portal", "cosmic"],
        "pack_affinities": ["spaceaudiobundle", "magicspellssfxbundle_audio", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "ceremony_contact_reveal": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The alien civilization's name lands on the card.",
        "ideal_duration": [1.5, 5.0],
        "keywords": ["alien voice", "transmission", "cosmic reveal", "stinger", "synth swell", "teleport finish"],
        "pack_affinities": ["spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2", "magicspellssfxbundle_audio"]
    },
    "ceremony_fanfare": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Major celebratory milestones and prestige fanfare.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["brass fanfare", "stinger", "victory", "triumph", "royal fanfare", "grand stinger"],
        "pack_affinities": ["westernaudiobundle", "inventorysfxbundle_audio"]
    },
    "ceremony_power_down": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Transition into succession or reset sequence.",
        "ideal_duration": [1.0, 4.5],
        "keywords": ["power down", "shut down", "turbine fade", "decompression", "system offline"],
        "pack_affinities": ["spaceaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "legacy_purchase": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Buying a permanent Legacy upgrade in the Estate shop.",
        "ideal_duration": [1.0, 5.0],
        "keywords": ["generic spell summon", "strong accept", "coins bag 2", "magic upgrade", "divine blessing", "shimmer"],
        "pack_affinities": ["magicspellssfxbundle_audio", "westernaudiobundle", "Sci-Fi Horror Sound FX Pack Vol. 2"]
    },
    "welcome_back": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The welcome-back pile after time away.",
        "ideal_duration": [2.0, 8.5],
        "keywords": ["coin pouring", "coin shower", "cash flood", "heal 9", "wealth return", "tally"],
        "pack_affinities": ["inventorysfxbundle_audio", "westernaudiobundle", "magicspellssfxbundle_audio"]
    },
    "prestige_confirm": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "PASS THE TORCH confirmed, just before succession screens take over.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["gong", "torch ignite", "heavy seal", "bell", "stinger 15", "grand transition"],
        "pack_affinities": ["westernaudiobundle", "magicspellssfxbundle_audio", "spaceaudiobundle"]
    },
    "band_0_blue_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Earth, Blue Collar (Tier 1) — department-store muzak, thin arrangement.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["intensity 1", "corporate", "coffee time", "jazz", "acoustic", "elevator", "commercial"],
        "pack_affinities": ["Corporate Music Pack Vol. 1", "Jazz Music Pack"]
    },
    "band_1_white_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Earth, White Collar (Tier 2) — the same tune, fuller mix. Promotion audible.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["main", "corporate", "coffee time", "full mix", "strings", "success", "motivational"],
        "pack_affinities": ["Corporate Music Pack Vol. 1", "Jazz Music Pack"]
    },
    "band_2_early_contact": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Early contact (Tiers 3–11) — melody survives, synths and theremin creep in.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "space", "synth", "ambient", "cosmic", "mystery", "pulsing"],
        "pack_affinities": ["Ethereal Music Pack Vol. 3", "Corporate Music Pack Vol. 1"]
    },
    "band_3_mid": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Mid alien contact (Tiers 12–19) — fewer Earth instruments left.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "eastern", "exotic", "hypnotic", "alien", "drone", "space"],
        "pack_affinities": ["Ethereal Music Pack Vol. 3", "Eastern Music Pack"]
    },
    "band_4_deep": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Deep cosmos (Tiers 20–27) — recognizable, but barely of this world.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "cosmic", "deep space", "synthetic", "astral", "celestial", "dimension"],
        "pack_affinities": ["Ethereal Music Pack Vol. 3"]
    },
    "music_preview": {
        "bus": "Music", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Releasing the MUSIC slider in Settings.",
        "ideal_duration": [0.5, 3.0],
        "keywords": ["chime", "short chord", "stinger", "preview", "music chord", "sample"],
        "pack_affinities": ["westernaudiobundle", "Corporate Music Pack Vol. 1", "buttonssfxlibrary"]
    }
}

# Curated Top Selections from Plans/Audio_Asset_Selection.md & Audio README
CURATED_PICKS = {
    "tap_note": [
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Counter A.wav", "role": "primary", "note": "Exact tally-counter / adding-machine mechanical tick under 200ms (0.142s)"},
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Counter B.wav", "role": "variant_1", "note": "Alternating tick variant to avoid repetition fatigue (0.181s)"},
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Button 6.wav", "role": "candidate", "note": "Electronic blip alternate (0.099s)"}
    ],
    "buy_success": [
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Coins Bag 1.wav", "role": "primary", "note": "Quiet metallic cash base texture (0.565s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Coins Bag 2.wav", "role": "layer", "note": "Bright celebratory layer for high-delta purchases (1.144s)"},
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Coin 4.wav", "role": "candidate", "note": "Clean coin clink alternate (0.500s)"},
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Coins 2.wav", "role": "candidate", "note": "Multiple coin rattle alternate (0.950s)"}
    ],
    "hire_first": [
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Create Engineer.wav", "role": "primary", "note": "First staffer acquisition — craftsman sound (0.774s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\Buttons and Stingers\Stinger 15.wav", "role": "candidate", "note": "Americana brass/guitar stinger alternate (1.659s)"}
    ],
    "hire_levelled": [
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Create Human Female.wav", "role": "primary", "note": "Lighter weight upgrade in same sample family (0.304s)"},
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Create Robot 1.wav", "role": "candidate", "note": "Tech/engineer staff upgrade alternate (0.485s)"}
    ],
    "milestone": [
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Ding.wav", "role": "primary", "note": "Triumph scoreboard milestone bell (0.408s)"},
        {"path": r"inventorysfxbundle_audio\inventorysfxbundle\Assets\Misc\LevelUp1.mp3", "role": "candidate", "note": "Bigger level-up stinger for late bands (1.776s)"}
    ],
    "cycle_started": [
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Hammer 1.wav", "role": "primary", "note": "Mechanical physical crank/hammer starting machine cycle"},
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Open Lock 2.wav", "role": "candidate", "note": "Latch click alternate"}
    ],
    "overdrive_engage": [
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Computer On.wav", "role": "primary", "note": "Overdrive console power engagement (1.110s)"},
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Saw (loop).wav", "role": "candidate", "note": "Mechanical machine acceleration"}
    ],
    "vent_tick": [
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Pacer Beeps Normal.wav", "role": "primary", "note": "Interval timer pulse rhythm (to slice single tick) (4.424s)"},
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Button 2.wav", "role": "candidate", "note": "Crisp electronic telegraph pip (0.250s)"}
    ],
    "vent_open": [
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Buzzer.wav", "role": "primary", "note": "Clear urgent game horn — signal to start lifting (0.337s)"},
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Communication Recieving 2.wav", "role": "candidate", "note": "Sci-fi klaxon alternate (0.400s)"}
    ],
    "vent_lift": [
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Elevator.wav", "role": "primary", "note": "Pneumatic elevator lift pulse (2.500s)"},
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Generic\Generic Spell (end) 4.mp3", "role": "candidate", "note": "Ascending energy lift alternate (2.210s)"}
    ],
    "vent_success": [
        {"path": r"Sci-Fi Horror Sound FX Pack Vol. 2\Sci-Fi Horror\Tech and Mech\Strong Accept.wav", "role": "primary", "note": "Clean machine confirm / success stinger (2.701s)"},
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Reward 2.wav", "role": "candidate", "note": "Bright melodic chime alternate (0.540s)"}
    ],
    "vent_miss": [
        {"path": r"Sci-Fi Horror Sound FX Pack Vol. 2\Sci-Fi Horror\Tech and Mech\Strong Deny.wav", "role": "primary", "note": "Matched opposite to Strong Accept (2.701s)"},
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Wrong 1.wav", "role": "candidate", "note": "Snappy refusal buzzer (0.529s)"}
    ],
    "overheat": [
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Decompression 1.wav", "role": "primary", "note": "Violent steam release / machine burnout (3.740s)"},
        {"path": r"Sci-Fi Horror Sound FX Pack Vol. 2\Sci-Fi Horror\Tech and Mech\Vent Exhale.wav", "role": "candidate", "note": "Long pneumatic gas exhaust (8.811s)"}
    ],
    "rush_ready": [
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Computer On.wav", "role": "primary", "note": "System boot / ready confirmation (1.110s)"},
        {"path": r"Foley Sports Sound FX Pack\Foley Sports\Buzzers and Boards\Scoreboard Ding.wav", "role": "candidate", "note": "Pitched-up chime ready chime (0.408s)"}
    ],
    "heat_loop": [
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\Update\Truck Gear Idle (loop).wav", "role": "primary", "note": "Loop-tagged industrial engine idle (2.055s)"},
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Electric\Electric (loop).mp3", "role": "candidate", "note": "Continuous electric hum loop (6.440s)"}
    ],
    "urgency_loop": [
        {"path": r"buildingandcraftingaudiobundle\Building and Crafting Audio Bundle\WAV\FX\Saw (loop).wav", "role": "primary", "note": "Loop-tagged rising saw motor friction (2.440s)"},
        {"path": r"Sci-Fi Horror Sound FX Pack Vol. 2\Sci-Fi Horror\Tech and Mech\Pathetic Alarm.wav", "role": "candidate", "note": "Sci-fi warning pulsation loop (2.928s)"}
    ],
    "tab_switch": [
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Slide\Slide Button 13.wav", "role": "primary", "note": "Crisp tactile tab slide (0.263s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\Buttons and Stingers\Button 5.wav", "role": "candidate", "note": "Americana period tactile button (0.311s)"}
    ],
    "screen_open": [
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Open Drawer 2.wav", "role": "primary", "note": "Physical cabinet / drawer opening (0.691s)"},
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Select\Select Button 1.wav", "role": "candidate", "note": "Major panel selection (0.489s)"}
    ],
    "screen_close": [
        {"path": r"puzzleaudiokit\puzzleaudiokit\WAV\FX\Misc\Close Drawer 3.wav", "role": "primary", "note": "Matched cabinet drawer closing pair (0.888s)"},
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Click\Click Button 6.wav", "role": "candidate", "note": "Snappy dismiss click (0.221s)"}
    ],
    "mode_toggle": [
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Click\Click Button 6.wav", "role": "primary", "note": "Mechanical toggle switch click (0.221s)"},
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Click\Click Button 1.wav", "role": "candidate", "note": "Firm push button click (0.190s)"}
    ],
    "epoch_page": [
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Card Deliver 1.wav", "role": "primary", "note": "Tactile card flick / page slide (0.534s)"},
        {"path": r"buttonssfxlibrary\buttonssfxlibrary\WAV\Slide\Slide Button 1.wav", "role": "candidate", "note": "Smooth panel slide"}
    ],
    "make_contact": [
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Teleportation.wav", "role": "primary", "note": "Massive cosmic portal activation (2.650s)"},
        {"path": r"Sci-Fi Horror Sound FX Pack Vol. 2\Sci-Fi Horror\Tech and Mech\Beam Me Up A.wav", "role": "candidate", "note": "Sci-fi transporter ascension (9.202s)"}
    ],
    "ceremony_obituary": [
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Bell 1.wav", "role": "primary", "note": "Warm, dignified period bell toll (6.842s)"},
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Revive\Revive 3.mp3", "role": "candidate", "note": "Solemn transition stinger (6.080s)"}
    ],
    "ceremony_heir": [
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Revive\Revive 3.mp3", "role": "primary", "note": "Continuation of the dynasty reveal (6.080s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\Buttons and Stingers\Stinger 15.wav", "role": "candidate", "note": "Americana acoustic celebration (1.659s)"}
    ],
    "ceremony_contact": [
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Generic\Generic Spell (summon) 1.mp3", "role": "primary", "note": "Cosmic alien encounter stinger (6.130s)"},
        {"path": r"spaceaudiobundle\spaceaudiobundle\WAV\FX\Light Speed.wav", "role": "candidate", "note": "Hyperspace arrival (1.670s)"}
    ],
    "legacy_purchase": [
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Generic\Generic Spell (summon) 1.mp3", "role": "primary", "note": "Legacy permanent power unlocked (6.130s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Coins Bag 2.wav", "role": "candidate", "note": "Layered gold treasure purchase (1.144s)"}
    ],
    "welcome_back": [
        {"path": r"inventorysfxbundle_audio\inventorysfxbundle\Assets\Coins\CoinPouring3.mp3", "role": "primary", "note": "Massive pile of idle offline cash cascade (8.280s)"},
        {"path": r"magicspellssfxbundle_audio\magicspellssfxbundle\Mono\Heal\Heal 9.mp3", "role": "candidate", "note": "Warm restoration chime (4.570s)"}
    ],
    "catch_coin": [
        {"path": r"inventorysfxbundle_audio\inventorysfxbundle\Assets\Coins\CoinPickUp2.mp3", "role": "primary", "note": "Light, crisp falling coin catch (0.336s)"},
        {"path": r"inventorysfxbundle_audio\inventorysfxbundle\Assets\Coins\CoinPickUp1.mp3", "role": "variant_1", "note": "Coin catch variant (0.384s)"},
        {"path": r"westernaudiobundle\Western Audio Bundle\WAV\SFX\Misc\Card Deliver 1.wav", "role": "variant_2", "note": "Paper dollar catch variation (0.534s)"}
    ]
}


def get_audio_duration(file_path):
    """Accurately extract duration from WAV RIFF header or estimate MP3/OGG."""
    ext = os.path.splitext(file_path)[1].lower()
    size = os.path.getsize(file_path)
    if ext == '.wav':
        try:
            with open(file_path, 'rb') as f:
                header = f.read(128)
                if header[:4] == b'RIFF' and header[8:12] == b'WAVE':
                    fmt_idx = header.find(b'fmt ')
                    if fmt_idx != -1 and len(header) >= fmt_idx + 24:
                        fmt, channels, rate, byte_rate = struct.unpack('<HHII', header[fmt_idx+8:fmt_idx+20])
                        if byte_rate > 0:
                            data_idx = header.find(b'data')
                            if data_idx != -1 and len(header) >= data_idx + 8:
                                data_sz = struct.unpack('<I', header[data_idx+4:data_idx+8])[0]
                                if 0 < data_sz <= size:
                                    return round(data_sz / byte_rate, 3)
                            return round((size - 44) / byte_rate, 3)
        except Exception:
            pass
        return round(max(0.05, size / 176400.0), 3)
    elif ext == '.mp3':
        # Average 192kbps = 24,000 bytes/sec
        return round(max(0.1, size / 24000.0), 3)
    elif ext == '.ogg':
        # Average 128kbps = 16,000 bytes/sec
        return round(max(0.1, size / 16000.0), 3)
    return 1.0


def scan_all_library_files():
    """Scan all 15 audio packs and build indexed file catalog."""
    print("Scanning audio packs in:", GAME_AUDIO_DIR)
    catalog = []
    if not os.path.exists(GAME_AUDIO_DIR):
        print(f"Warning: {GAME_AUDIO_DIR} not found!")
        return catalog
    
    pack_dirs = [d for d in os.listdir(GAME_AUDIO_DIR) if os.path.isdir(os.path.join(GAME_AUDIO_DIR, d)) and not d.startswith('__')]
    
    for pack in sorted(pack_dirs):
        pack_path = os.path.join(GAME_AUDIO_DIR, pack)
        for root, dirs, files in os.walk(pack_path):
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in ('.wav', '.mp3', '.ogg') and not f.startswith('._'):
                    full_path = os.path.join(root, f)
                    rel_to_audio_root = os.path.relpath(full_path, GAME_AUDIO_DIR)
                    rel_to_pack = os.path.relpath(full_path, pack_path)
                    
                    size_bytes = os.path.getsize(full_path)
                    duration = get_audio_duration(full_path)
                    
                    name_clean = os.path.splitext(f)[0]
                    # Tokenize name and subfolders for search and keywords
                    subfolders = os.path.relpath(root, pack_path).replace('\\', '/').split('/')
                    tokens = set(re.findall(r'[a-zA-Z0-9]+', f.lower() + " " + " ".join(subfolders).lower()))
                    
                    catalog.append({
                        "id": rel_to_audio_root.replace('\\', '/'),
                        "filename": f,
                        "name_clean": name_clean,
                        "pack": pack,
                        "rel_path": rel_to_audio_root.replace('\\', '/'),
                        "subfolder": os.path.relpath(root, pack_path).replace('\\', '/'),
                        "format": ext.replace('.', '').upper(),
                        "size_bytes": size_bytes,
                        "duration": duration,
                        "is_loop": "loop" in f.lower() or "loop" in root.lower(),
                        "tokens": list(tokens)
                    })
    
    print(f"Indexed {len(catalog)} audio files across {len(pack_dirs)} packs.")
    return catalog


def check_existing_game_cues():
    """Scan what audio files currently exist in the game/audio folder."""
    existing = {}
    if not os.path.exists(PROJECT_AUDIO_DIR):
        return existing
    
    cues_dir = os.path.join(PROJECT_AUDIO_DIR, "cues")
    loops_dir = os.path.join(PROJECT_AUDIO_DIR, "loops")
    music_dir = os.path.join(PROJECT_AUDIO_DIR, "music")
    
    for d, category in [(cues_dir, "cue"), (loops_dir, "loop"), (music_dir, "music")]:
        if os.path.exists(d):
            for f in os.listdir(d):
                if f.endswith(('.ogg', '.wav', '.mp3')):
                    base_id = os.path.splitext(f)[0]
                    existing[base_id] = {
                        "filename": f,
                        "category": category,
                        "path": f"game/audio/{os.path.basename(d)}/{f}",
                        "size": os.path.getsize(os.path.join(d, f))
                    }
    return existing


def score_candidate_match(cue_id, cue_meta, audio_file):
    """
    Compute match strength score (0 - 100) between an audio file and a game cue.
    """
    # Check if curated pick
    if cue_id in CURATED_PICKS:
        for pick in CURATED_PICKS[cue_id]:
            pick_norm = pick["path"].replace('/', '\\').lower()
            file_norm = audio_file["rel_path"].replace('/', '\\').lower()
            if pick_norm in file_norm or file_norm.endswith(pick_norm) or os.path.basename(pick_norm) == audio_file["filename"].lower():
                base_score = 98 if pick["role"] == "primary" else (94 if pick["role"] == "layer" else 90)
                return base_score, f"Curated: {pick.get('note', 'Recommended in Audio_Asset_Selection.md')}"
    
    score = 0.0
    reasons = []
    file_tokens = set(audio_file["tokens"])
    file_name_lower = audio_file["filename"].lower()
    
    # 1. Cue ID exact/sub-match
    cue_tokens = set(re.findall(r'[a-zA-Z0-9]+', cue_id.lower()))
    cue_overlap = cue_tokens.intersection(file_tokens)
    if cue_overlap:
        score += len(cue_overlap) * 22
        reasons.append(f"Matches cue name keywords: {', '.join(cue_overlap)}")
    
    # 2. Cue metadata keyword matching
    keywords = cue_meta.get("keywords", [])
    matched_kw = []
    for kw in keywords:
        kw_parts = kw.lower().split()
        if all(part in file_tokens or part in file_name_lower for part in kw_parts):
            matched_kw.append(kw)
    
    if matched_kw:
        score += min(45, len(matched_kw) * 16)
        reasons.append(f"Keywords: {', '.join(matched_kw[:3])}")
    
    # 3. Pack affinity bonus
    pack_affinities = cue_meta.get("pack_affinities", [])
    if audio_file["pack"] in pack_affinities:
        score += 15
        reasons.append(f"Affinitive pack: {audio_file['pack']}")
    
    # 4. Duration compatibility
    ideal_dur = cue_meta.get("ideal_duration", [0.1, 2.0])
    dur = audio_file["duration"]
    if ideal_dur[0] <= dur <= ideal_dur[1]:
        score += 18
        reasons.append(f"Ideal duration ({dur:.2f}s)")
    elif dur < ideal_dur[0]:
        diff_ratio = (ideal_dur[0] - dur) / max(0.01, ideal_dur[0])
        score -= min(20, diff_ratio * 15)
    elif dur > ideal_dur[1]:
        diff_ratio = (dur - ideal_dur[1]) / max(0.1, ideal_dur[1])
        score -= min(45, diff_ratio * 25)
    
    # 5. Loop bonus/penalty
    is_loop_cue = "loop" in cue_id or cue_meta.get("bus") == "Music"
    if is_loop_cue:
        if audio_file["is_loop"] or "loop" in file_name_lower:
            score += 25
            reasons.append("Loop-tagged asset")
        if cue_meta.get("bus") == "Music" and dur >= 50.0:
            score += 20
    else:
        if audio_file["is_loop"] and dur > 5.0:
            score -= 30
    
    final_score = int(max(0, min(89, score)))
    reason_str = " | ".join(reasons) if reasons else "Catalog match"
    return final_score, reason_str


def build_audio_database():
    catalog = scan_all_library_files()
    existing_cues = check_existing_game_cues()
    
    all_assigned_file_ids = set()
    
    sections_output = []
    total_cues_count = 0
    
    for group in CUE_GROUPS:
        cues_list = []
        for cue_id in group["cues"]:
            total_cues_count += 1
            meta = CUE_METADATA.get(cue_id, {
                "bus": "SFX", "db": -6.0, "cooldown": 50, "layered": False, "has_variants": False,
                "trigger": "Audio event", "ideal_duration": [0.1, 2.0], "keywords": [], "pack_affinities": []
            })
            
            # Find and rank candidates
            candidates = []
            for item in catalog:
                score, reason = score_candidate_match(cue_id, meta, item)
                if score >= 20 or (cue_id in CURATED_PICKS and any(os.path.basename(p["path"]).lower() in item["filename"].lower() for p in CURATED_PICKS[cue_id])):
                    role = "candidate"
                    # Check curated role
                    if cue_id in CURATED_PICKS:
                        for p in CURATED_PICKS[cue_id]:
                            if os.path.basename(p["path"]).lower() == item["filename"].lower():
                                role = p.get("role", "primary")
                                break
                    
                    candidates.append({
                        "file_id": item["id"],
                        "filename": item["filename"],
                        "name_clean": item["name_clean"],
                        "pack": item["pack"],
                        "rel_path": item["rel_path"],
                        "subfolder": item["subfolder"],
                        "format": item["format"],
                        "duration": item["duration"],
                        "score": score,
                        "role": role,
                        "reason": reason,
                        "selected": role in ("primary", "layer") or score >= 95
                    })
            
            # Sort candidates by score descending, then duration
            candidates.sort(key=lambda x: (x["score"], -abs(x["duration"] - meta.get("ideal_duration", [0.5, 1.0])[0])), reverse=True)
            
            # Top candidate selections
            for c in candidates[:15]:
                all_assigned_file_ids.add(c["file_id"])
            
            cues_list.append({
                "cue_id": cue_id,
                "bus": meta["bus"],
                "db": meta["db"],
                "cooldown": meta["cooldown"],
                "layered": meta.get("layered", False),
                "has_variants": meta.get("has_variants", False),
                "trigger": meta.get("trigger", ""),
                "existing_in_game": existing_cues.get(cue_id),
                "candidates": candidates[:25]  # Cap top 25 candidates per cue
            })
        
        sections_output.append({
            "section_id": group["id"],
            "name": group["name"],
            "description": group["description"],
            "cues": cues_list
        })
    
    # Organize 'Other / Unassigned Library' section
    other_files = [f for f in catalog if f["id"] not in all_assigned_file_ids]
    
    # Categorize 'Other' by pack
    packs_summary = {}
    for item in catalog:
        p = item["pack"]
        if p not in packs_summary:
            packs_summary[p] = {"name": p, "count": 0, "formats": set()}
        packs_summary[p]["count"] += 1
        packs_summary[p]["formats"].add(item["format"])
    
    for p in packs_summary:
        packs_summary[p]["formats"] = list(packs_summary[p]["formats"])
    
    output_data = {
        "generated_at": "2026-08-16",
        "total_library_files": len(catalog),
        "total_cues": total_cues_count,
        "packs": list(packs_summary.values()),
        "sections": sections_output,
        "library_sample": catalog  # Complete catalog for in-browser search & assignment
    }
    
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Generated {OUTPUT_JSON_PATH} successfully.")
    print(f"Sections: {len(sections_output)}, Total cues: {total_cues_count}, Library files: {len(catalog)}")


if __name__ == "__main__":
    build_audio_database()
