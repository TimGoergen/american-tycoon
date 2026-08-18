#!/usr/bin/env python3
"""
High-Precision Audio Database & Recommendation Generator for American Tycoon.
Indexes 3,763 licensed audio assets across 15 packs in D:\\Downloads\\Game_Audio.
Applies semantic subfolder matching, category affinity, duration constraints,
negative noise filtering, and research-backed curated picks to deliver top-tier
recommendations for all 87 game audio cues.

Updated to accurately reflect current audio files used in Godot code (Audio.gd),
including deployed licensed assets from CREDITS.md, active format resolution (.ogg > .wav),
variants, layers, and synthesized placeholders.
"""

import os
import sys
import json
import re
import struct
from pathlib import Path

GAME_AUDIO_DIR = r"D:\Downloads\Game_Audio"
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_AUDIO_DIR = os.path.join(WORKSPACE_DIR, "game", "audio")
CREDITS_PATH = os.path.join(PROJECT_AUDIO_DIR, "CREDITS.md")
AUDIO_GD_PATH = os.path.join(WORKSPACE_DIR, "game", "scripts", "audio", "Audio.gd")
EXPORT_PATH = os.path.join(WORKSPACE_DIR, "Plans", "Audio_Selection_Export.json")
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

# Comprehensive CUE METADATA & Keyword Taxonomies
CUE_METADATA = {
    # Core Loop
    "tap_note": {
        "bus": "SFX", "db": -6.0, "cooldown": 45, "layered": False, "has_variants": True,
        "trigger": "Tapping CLOCK IN or a running property (a rush). Pitched across a pentatonic scale.",
        "ideal_duration": [0.05, 0.20],
        "keywords": ["scoreboard counter", "counter", "tick", "tally", "typewriter", "adding machine", "button 6", "tap", "blip"],
        "folder_affinities": ["Buzzers and Boards", "Buttons SFX Library", "Misc", "FX"]
    },
    "buy_success": {
        "bus": "SFX", "db": -3.0, "cooldown": 60, "layered": True, "has_variants": True,
        "trigger": "A property purchase completes. Volume scales with income boost. Uses _layer on big jumps.",
        "ideal_duration": [0.3, 1.3],
        "keywords": ["coins bag", "coins", "coin", "money", "cash", "register", "purchase", "gold"],
        "folder_affinities": ["Coins", "SFX/Misc", "Misc", "FX"]
    },
    "hire_first": {
        "bus": "SFX", "db": -3.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "The FIRST staffer on a property — the moment it starts running itself.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["create engineer", "create", "hire", "worker", "contract", "stinger 15", "whistle", "staff"],
        "folder_affinities": ["FX", "Buttons and Stingers", "Select"]
    },
    "hire_levelled": {
        "bus": "SFX", "db": -7.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Any later staff level on an already-staffed property.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["create human female", "create human male", "create robot", "create", "level", "upgrade", "worker"],
        "folder_affinities": ["FX", "Misc", "Select"]
    },
    "retain_staff": {
        "bus": "SFX", "db": -6.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Buying staff retention in the Estate screen.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["card deliver 1", "paper", "contract", "seal", "stamp", "signature", "retain", "hire"],
        "folder_affinities": ["SFX/Misc", "Select", "Coins"]
    },
    "milestone": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A property crosses a count milestone (25, 50, 100 …). Fires on the crossing.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["scoreboard ding", "ding", "bell", "chime", "levelup", "milestone", "triumph"],
        "folder_affinities": ["Buzzers and Boards", "Buttons and Stingers", "Events", "Misc"]
    },
    "cycle_started": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Tapping a STOPPED property to start one cycle by hand (crank/turnover).",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["hammer 1", "open lock 2", "ratchet", "crank", "click", "turnover", "start", "gear"],
        "folder_affinities": ["FX", "Misc", "Steps"]
    },
    "frenzy_pop": {
        "bus": "SFX", "db": -2.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Popping the FRENZY meter.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["fire 1", "siren sound", "pop", "burst", "ignition", "spark", "explosion", "frenzy", "power on"],
        "folder_affinities": ["Fire", "Buzzers and Boards", "FX/Misc", "Misc"]
    },
    "frenzy_end": {
        "bus": "SFX", "db": -10.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A frenzy burn runs out. Smooth steam/gas dissipation.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["decompression 2", "vent exhale", "steam", "hiss", "cooldown", "drain", "exhaust"],
        "folder_affinities": ["FX", "Tech and Mech", "Misc"]
    },

    # Rush and Overdrive
    "overdrive_engage": {
        "bus": "SFX", "db": -3.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The OVERDRIVE button starts the high-speed ride.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["computer on", "saw loop", "engine start", "turbine", "whine", "power up", "alarm"],
        "folder_affinities": ["FX", "Tech and Mech", "Misc"]
    },
    "vent_tick": {
        "bus": "SFX", "db": -12.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "One per required lift, counted out the instant the vent window opens.",
        "ideal_duration": [0.03, 0.12],
        "keywords": ["pacer beeps", "button 2", "pip", "blip", "tick", "beep", "telegraph", "punctuation"],
        "folder_affinities": ["Buzzers and Boards", "Buttons SFX Library", "FX"]
    },
    "vent_open": {
        "bus": "SFX", "db": -1.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "A vent window opens — the most critical audio cue in the game.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["buzzer", "communication recieving", "horn", "klaxon", "alarm", "open", "vent"],
        "folder_affinities": ["Buzzers and Boards", "FX", "Tech and Mech"]
    },
    "vent_lift": {
        "bus": "SFX", "db": -6.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "Each lift registered inside the window. Pitched up one whole tone per lift.",
        "ideal_duration": [0.08, 0.45],
        "keywords": ["elevator", "generic spell end", "lift", "whoosh", "pneumatic", "rise", "place diamond"],
        "folder_affinities": ["FX", "Generic", "Building and Crafting Audio Bundle"]
    },
    "vent_success": {
        "bus": "SFX", "db": -2.0, "cooldown": 100, "layered": True, "has_variants": False,
        "trigger": "A vent completes in time. Intensity scales with vent tier reached.",
        "ideal_duration": [0.3, 1.6],
        "keywords": ["strong accept", "reward 2", "chime", "vent clear", "success", "lock"],
        "folder_affinities": ["Tech and Mech", "Misc", "FX"]
    },
    "vent_miss": {
        "bus": "SFX", "db": -4.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The window closes unmet — fires just before overheat.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["strong deny", "wrong 1", "buzzer", "refusal", "miss", "fail"],
        "folder_affinities": ["Tech and Mech", "Buzzers and Boards", "Misc"]
    },
    "overheat": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The ride ends in flames. Heat drains, rushing is locked out.",
        "ideal_duration": [0.8, 3.5],
        "keywords": ["decompression 1", "vent exhale", "overheat", "steam blast", "burnout", "alarm", "explosion"],
        "folder_affinities": ["FX", "Tech and Mech", "Fire"]
    },
    "rush_ready": {
        "bus": "SFX", "db": -8.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The lockout ends and rushing is live again.",
        "ideal_duration": [0.2, 1.2],
        "keywords": ["computer on", "scoreboard ding", "ready", "charge", "recharge", "boot"],
        "folder_affinities": ["FX", "Buzzers and Boards", "Misc"]
    },
    "heat_loop": {
        "bus": "Music", "db": -14.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous bass drone held throughout rush mode, pitch-shifted with heat.",
        "ideal_duration": [1.5, 10.0],
        "keywords": ["truck gear idle", "gear 3", "electric loop", "motor", "hum", "drone", "idle"],
        "folder_affinities": ["Update", "FX", "Electric", "Misc"]
    },
    "urgency_loop": {
        "bus": "Music", "db": -16.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous warning pulsation rising in top 25% of heat gauge.",
        "ideal_duration": [1.5, 10.0],
        "keywords": ["saw loop", "pathetic alarm", "urgency", "pulse", "pulsation", "friction", "hazard"],
        "folder_affinities": ["FX", "Tech and Mech", "Madness"]
    },

    # UI / Interface
    "tab_switch": {
        "bus": "UI", "db": -10.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Changing navigation tab in the bottom bar.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["slide button 13", "bullet impact 6", "button 5", "click", "slide", "tab", "switch"],
        "folder_affinities": ["Slide", "Buttons and Stingers", "Click", "Weapons"]
    },
    "screen_open": {
        "bus": "UI", "db": -9.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Opening a modal screen (Stats, Challenges, Help, About, Tuning).",
        "ideal_duration": [0.15, 0.8],
        "keywords": ["open drawer 2", "select button 1", "screen open", "whoosh", "panel open", "sheet"],
        "folder_affinities": ["Misc", "Select", "Slide"]
    },
    "screen_close": {
        "bus": "UI", "db": -11.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Closing a modal screen.",
        "ideal_duration": [0.12, 0.6],
        "keywords": ["close drawer 2", "cancel button 1", "screen close", "slide back", "dismiss"],
        "folder_affinities": ["Misc", "Cancel", "Slide"]
    },
    "mode_toggle": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "The buy-mode (x1, x10, Next, Max) or hire-mode toggle.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["toggle button 6", "button 6", "switch", "toggle", "notch", "tick"],
        "folder_affinities": ["Buttons SFX Library", "Misc", "Click"]
    },
    "epoch_page": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "Paging through epochs/civilizations in the Era carousel.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["slide button 10", "slide button", "page flip", "card swipe", "glide"],
        "folder_affinities": ["Slide", "Buttons SFX Library", "Select"]
    },
    "make_contact": {
        "bus": "UI", "db": -1.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "The MAKE CONTACT button — the largest milestone action in the game.",
        "ideal_duration": [0.6, 3.0],
        "keywords": ["teleportation", "light speed", "contact", "cosmic", "hyperspace", "warp", "transmission"],
        "folder_affinities": ["FX", "Space Audio Bundle", "Revive"]
    },
    "tip_appear": {
        "bus": "UI", "db": -12.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A tutorial coach card or system tip appears on screen.",
        "ideal_duration": [0.1, 0.6],
        "keywords": ["bubble button 5", "bubble button", "pop", "tip", "notification", "blip"],
        "folder_affinities": ["Bubble", "Buttons SFX Library", "Misc"]
    },
    "denied_cash": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "An action refused due to insufficient cash.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["wrong 1", "cancel button 1", "deny", "buzz", "refusal", "no funds"],
        "folder_affinities": ["Cancel", "Misc", "Tech and Mech"]
    },
    "denied_locked": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "An action refused because an item is locked.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["wrong 3", "locked", "refusal", "padlock", "deny", "rattle"],
        "folder_affinities": ["Cancel", "Misc", "Tech and Mech"]
    },

    # Challenge Mode
    "challenge_start": {
        "bus": "UI", "db": -6.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Launching a time-attack session from the Challenges screen.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["boxing bell fight start", "stinger 15", "gong", "challenge", "start gong", "whistle"],
        "folder_affinities": ["Buzzers and Boards", "Buttons and Stingers", "Whistle"]
    },
    "challenge_credit": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "A challenge run ends and points/currency are credited.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["reward 1", "coins pouring", "tally", "score", "credit", "victory"],
        "folder_affinities": ["Coins", "Events", "Misc"]
    },
    "challenge_tier": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "Climbing a tier in the challenge ladder mid-run.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["scoreboard ding", "levelup", "tier", "stinger", "fanfare", "climb"],
        "folder_affinities": ["Buzzers and Boards", "Buttons and Stingers", "Events"]
    },

    # Minigames Shared
    "minigame_begin": {
        "bus": "UI", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "BEGIN on a minigame's Get Ready gate — round start.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["whistle blow normal", "referee whistle", "game whistle", "start whistle", "go"],
        "folder_affinities": ["Whistle", "Buzzers and Boards"]
    },
    "minigame_score": {
        "bus": "SFX", "db": -8.0, "cooldown": 40, "layered": False, "has_variants": False,
        "trigger": "The player scores in any minigame (shared layer across all 6 games).",
        "ideal_duration": [0.15, 0.7],
        "keywords": ["scoreboard ding", "point chime", "ding", "bell", "score", "swish hit"],
        "folder_affinities": ["Buzzers and Boards", "Events", "Misc"]
    },
    "minigame_miss": {
        "bus": "SFX", "db": -7.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A miss that costs challenge time in any minigame.",
        "ideal_duration": [0.15, 0.7],
        "keywords": ["scoreboard timer a", "timer tick", "buzzer", "miss", "dull clank"],
        "folder_affinities": ["Buzzers and Boards", "Tech and Mech", "Misc"]
    },
    "minigame_countdown": {
        "bus": "UI", "db": -9.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "One per second over the last 5 seconds of the minigame clock.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["punctuation sound", "pacer beeps normal", "tick", "beep", "countdown", "blip"],
        "folder_affinities": ["Buzzers and Boards", "Space Audio Bundle", "Buttons SFX Library"]
    },
    "minigame_best": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "The run passes the stored all-time high score.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["stinger 15", "revive 3", "high score fanfare", "best", "triumph", "fanfare"],
        "folder_affinities": ["Buttons and Stingers", "Revive", "Events"]
    },
    "minigame_over": {
        "bus": "UI", "db": -4.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "A round or challenge run timer hits 0:00.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["scoreboard buzzer", "game buzzer", "round over", "horn", "final buzzer"],
        "folder_affinities": ["Buzzers and Boards", "Whistle"]
    },

    # Basketball
    "bball_grab": {
        "bus": "SFX", "db": -16.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A finger touches the ball and the slingshot drag begins.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["basketball grab", "leather squeak", "grip", "shoe squeak", "leather catch", "court squeak"],
        "folder_affinities": ["Basketball", "Tennis", "Misc"]
    },
    "bball_launch": {
        "bus": "SFX", "db": -6.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Throw released, scaled by pull force.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["ball throw fast", "throw", "whoosh", "launch", "release", "whip"],
        "folder_affinities": ["Basketball", "Foley Sports", "FX"]
    },
    "bball_fizzle": {
        "bus": "SFX", "db": -14.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "Released under minimum pull — ball drops feebly.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["scoreboard timer a", "fizzle", "drop", "plop", "fail", "soft bounce"],
        "folder_affinities": ["Buzzers and Boards", "Pool", "Basketball"]
    },
    "bball_wall": {
        "bus": "SFX", "db": -12.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "Ball rebounds from side walls or ceiling.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["generic bounce normal", "bounce", "backboard", "wall rebound", "ball hit", "rebound"],
        "folder_affinities": ["Basketball", "Foley Sports", "Tennis"]
    },
    "bball_floor": {
        "bus": "SFX", "db": -11.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "Ball hits hardwood court floor.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["generic bounce normal", "dribble", "floor bounce", "hardwood", "ball floor"],
        "folder_affinities": ["Basketball", "Foley Sports"]
    },
    "bball_settle": {
        "bus": "SFX", "db": -18.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "Ball rolls to a stop and becomes throwable again.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["basketball settle", "ball roll", "settle", "soft stop", "roll"],
        "folder_affinities": ["Basketball", "Pool", "Misc"]
    },
    "bball_rim": {
        "bus": "SFX", "db": -8.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "Ball clips the metal hoop rim.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["generic net hit intense", "field goal kick goalpost", "rim", "iron", "clang", "hoop strike"],
        "folder_affinities": ["Basketball", "Football - Rugby", "Foley Sports"]
    },
    "bball_score": {
        "bus": "SFX", "db": -5.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "Basket made (hits rim and net). Layers over minigame_score.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["in the net a", "in the net b", "generic net hit normal", "basket", "made shot", "net"],
        "folder_affinities": ["Basketball", "Foley Sports"]
    },
    "bball_swish": {
        "bus": "SFX", "db": -3.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "Clean center drop with no rim contact — golden SWISH!",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["net swoosh intense", "net swoosh normal", "generic net swoosh", "swish", "nylon", "swoosh"],
        "folder_affinities": ["Basketball", "Foley Sports"]
    },
    "bball_gem_through": {
        "bus": "SFX", "db": -8.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "The ball passes through the Legacy gem. A promise, not yet a payout.",
        "ideal_duration": [0.2, 0.7],
        "keywords": ["gem1", "crystal", "jewel", "gem", "glass touch", "shimmer", "sparkle", "ping"],
        "folder_affinities": ["Jewels & Runes", "Generic", "Misc"]
    },
    "bball_gem_earned": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "Shot passed through gem AND scored — pays Legacy.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["revive 3", "stinger 15", "gem", "magic reward", "crystal chime", "legacy fanfare"],
        "folder_affinities": ["Revive", "Buttons and Stingers", "Jewels & Runes"]
    },

    # Match Three
    "m3_select": {
        "bus": "SFX", "db": -16.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "A gem is picked up — the drag begins.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["click button 6", "select button 4", "crystal tap", "gem click", "glass touch", "select"],
        "folder_affinities": ["Click", "Select", "Jewels & Runes", "Misc"]
    },
    "m3_swap": {
        "bus": "SFX", "db": -11.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Two gems trade places.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["slide button 13", "glass slide", "gem swap", "switch", "glide", "marble slide"],
        "folder_affinities": ["Slide", "Jewels & Runes", "Misc"]
    },
    "m3_invalid": {
        "bus": "SFX", "db": -10.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A swap matched nothing; gems slide back.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["wrong 1", "wrong 2", "cancel button", "invalid", "refusal", "deny"],
        "folder_affinities": ["Misc", "Cancel", "Tech and Mech"]
    },
    "m3_match": {
        "bus": "SFX", "db": -6.0, "cooldown": 30, "layered": False, "has_variants": False,
        "trigger": "A match clears. Pitched up a whole tone per cascade step.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["reward 2", "crystal shatter", "gem match", "chime", "sparkle", "burst", "glass break"],
        "folder_affinities": ["Misc", "Jewels & Runes", "Generic", "Events"]
    },
    "m3_fall": {
        "bus": "SFX", "db": -15.0, "cooldown": 40, "layered": False, "has_variants": False,
        "trigger": "Refill gems drop into empty grid spaces.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["marbles falling", "gem drops", "rattle", "beads", "trickle", "card deliver"],
        "folder_affinities": ["Misc", "Jewels & Runes", "SFX/Misc"]
    },
    "m3_avoid": {
        "bus": "SFX", "db": -5.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "A match that hit the AVOID gem — the main hazard penalty.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["pathetic alarm", "alarm 1", "wrong 3", "dark magic", "curse", "hazard", "shock"],
        "folder_affinities": ["Tech and Mech", "Misc", "Madness", "Venom"]
    },
    "m3_legacy": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem is collected in Match Three.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "generic spell summon", "reward 1", "grand chime", "legacy", "gem collect"],
        "folder_affinities": ["Revive", "Generic", "Jewels & Runes", "Events"]
    },

    # Catch Money
    "catch_coin": {
        "bus": "SFX", "db": -10.0, "cooldown": 25, "layered": False, "has_variants": True,
        "trigger": "An ordinary falling coin caught (most repeated sound in game).",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["coinpickup2", "coinpickup1", "coin 4", "card deliver 1", "small coin", "coin clink"],
        "folder_affinities": ["Coins", "SFX/Misc", "FX"]
    },
    "catch_premium": {
        "bus": "SFX", "db": -5.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A premium gold coin caught, worth multiple coins.",
        "ideal_duration": [0.2, 0.7],
        "keywords": ["coins bag 1", "coinbag2", "coins 2", "heavy coin", "rich clink", "gold coin"],
        "folder_affinities": ["Coins", "SFX/Misc", "FX"]
    },
    "catch_legacy": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "The JACKPOT Legacy coin caught — pays dynasty points.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["coinpouring3", "coinbag3", "coins bag 2", "jackpot", "coin shower", "fortune"],
        "folder_affinities": ["Coins", "SFX/Misc", "Generic"]
    },
    "catch_miss": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A coin reaches floor uncaught.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["coinpickup3", "ball sink", "floor bounce", "clatter", "miss", "lost coin"],
        "folder_affinities": ["Coins", "Pool", "Misc"]
    },
    "catch_spawn": {
        "bus": "SFX", "db": -22.0, "cooldown": 25, "layered": False, "has_variants": False,
        "trigger": "A coin appears at top. Quiet, makes spawn rate audible.",
        "ideal_duration": [0.04, 0.18],
        "keywords": ["bubble button 5", "bubble button", "button 6", "soft pop", "blip", "spawn", "light tick"],
        "folder_affinities": ["Bubble", "Buttons SFX Library", "Misc"]
    },

    # Memory
    "mem_pad": {
        "bus": "SFX", "db": -7.0, "cooldown": 20, "layered": False, "has_variants": False,
        "trigger": "A pad lights during playback or player tap. Pitched per pad.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["button 2", "click button 1", "synthesizer tone", "pure tone", "pad tone", "electronic note"],
        "folder_affinities": ["Buttons SFX Library", "FX", "Misc"]
    },
    "mem_round": {
        "bus": "SFX", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The whole sequence recalled correctly.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["reward 1", "reward 2", "reward 3", "success tune", "arpeggio", "sequence clear"],
        "folder_affinities": ["Misc", "Events", "Buttons and Stingers"]
    },
    "mem_wrong": {
        "bus": "SFX", "db": -3.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The wrong pad tapped. Game ends on this sound.",
        "ideal_duration": [0.4, 1.6],
        "keywords": ["wrong 1", "wrong 3", "strong deny", "error buzz", "dissonant", "fail", "game over buzz"],
        "folder_affinities": ["Misc", "Tech and Mech", "Cancel"]
    },
    "mem_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem earned in the bonus round.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "generic spell summon", "gem chime", "sparkle", "crystal reward"],
        "folder_affinities": ["Revive", "Generic", "Jewels & Runes"]
    },

    # Balance
    "bal_enter": {
        "bus": "SFX", "db": -9.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "The beam crosses INTO the scoring zone.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["slide button 13", "hum on", "zone enter", "lock", "chime in", "activate"],
        "folder_affinities": ["Slide", "FX", "Electric", "Misc"]
    },
    "bal_leave": {
        "bus": "SFX", "db": -11.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "The beam drifts back out of the scoring zone.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["click button 6", "hum off", "zone exit", "dissipate", "fade tone"],
        "folder_affinities": ["Click", "Cancel", "FX"]
    },
    "bal_lift": {
        "bus": "SFX", "db": -16.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "The lift impulse button is pressed.",
        "ideal_duration": [0.08, 0.4],
        "keywords": ["elevator", "pneumatic pulse", "lift", "thrust", "puff"],
        "folder_affinities": ["FX", "Tech and Mech"]
    },
    "bal_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem earned by maintaining the zone balance.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "generic spell summon", "crystal chime", "sparkle", "gem reward"],
        "folder_affinities": ["Revive", "Generic", "Jewels & Runes"]
    },

    # Timing Bar
    "time_lock_hit": {
        "bus": "SFX", "db": -5.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "Locking the moving needle inside the target zone.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["strong accept", "reward 2", "chime", "lock hit", "target hit", "bullseye"],
        "folder_affinities": ["Tech and Mech", "Misc", "Events"]
    },
    "time_lock_miss": {
        "bus": "SFX", "db": -8.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "Locking outside the target zone.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["wrong 1", "strong deny", "buzzer", "lock miss", "off target"],
        "folder_affinities": ["Misc", "Tech and Mech", "Cancel"]
    },
    "time_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A lock that collects the pending Legacy gem.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "generic spell summon", "crystal stinger", "gem fanfare"],
        "folder_affinities": ["Revive", "Generic", "Jewels & Runes"]
    },

    # Ceremony
    "ceremony_obituary": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The succession's obituary card reveals the departed patriarch.",
        "ideal_duration": [1.5, 8.0],
        "keywords": ["bell 1", "bell 2", "bell toll", "solemn stinger", "church bell", "death stinger"],
        "folder_affinities": ["Misc", "Buttons and Stingers", "Revive"]
    },
    "ceremony_will": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The reading and opening of the last will and testament.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["card deliver 1", "bookopen1", "parchment", "document", "will open", "legal"],
        "folder_affinities": ["SFX/Misc", "Books & Scrolls", "Select"]
    },
    "ceremony_heir": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The heir reveal — the dynasty continues into the next generation.",
        "ideal_duration": [1.2, 7.0],
        "keywords": ["revive 3", "stinger 15", "heir fanfare", "triumph", "continuation", "dynasty stinger"],
        "folder_affinities": ["Revive", "Buttons and Stingers", "Events"]
    },
    "ceremony_contact": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "First Contact ceremony card opens for an alien civilization.",
        "ideal_duration": [1.5, 7.0],
        "keywords": ["generic spell summon 1", "light speed", "alien contact", "cosmic arrival", "warp tone"],
        "folder_affinities": ["Generic", "Space Audio Bundle", "Revive"]
    },
    "ceremony_contact_reveal": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The civilization's name and portrait land on the card.",
        "ideal_duration": [0.5, 2.5],
        "keywords": ["communication recieving 2", "incoming transmission c", "stinger 8", "decode", "reveal"],
        "folder_affinities": ["Space Audio Bundle", "Tech and Mech", "Buttons and Stingers"]
    },
    "ceremony_fanfare": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Major generational milestone achievement fanfare.",
        "ideal_duration": [1.0, 4.0],
        "keywords": ["stinger 15", "stinger 8", "triumph fanfare", "victory brass", "americana celebration"],
        "folder_affinities": ["Buttons and Stingers", "Events"]
    },
    "ceremony_power_down": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Machine and city systems shutting down for succession handover.",
        "ideal_duration": [0.8, 3.5],
        "keywords": ["decompression 1", "decompression 2", "power down", "turbine off", "dissipate"],
        "folder_affinities": ["Space Audio Bundle", "Tech and Mech"]
    },
    "legacy_purchase": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Buying a permanent Legacy / Dynasty upgrade in the Estate shop.",
        "ideal_duration": [0.8, 4.0],
        "keywords": ["generic spell summon 1", "coins bag 2", "legacy unlock", "dynasty purchase", "power"],
        "folder_affinities": ["Generic", "SFX/Misc", "Coins"]
    },
    "welcome_back": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The welcome-back overlay celebrating offline earnings collected.",
        "ideal_duration": [1.5, 8.0],
        "keywords": ["coinpouring3", "heal 9", "offline cash cascade", "fortune", "wealth shower"],
        "folder_affinities": ["Coins", "Heal", "Generic"]
    },
    "prestige_confirm": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "PASS THE TORCH is confirmed, handing over the empire.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["boxing bell fight start", "stinger 15", "pass the torch", "transition bell", "confirm"],
        "folder_affinities": ["Buzzers and Boards", "Buttons and Stingers"]
    },

    # Music Bands
    "band_0_blue_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Epochs 1-2 (Tiers 0-1): Blue collar acoustic department-store muzak.",
        "ideal_duration": [40.0, 180.0],
        "keywords": ["corporate coffee time intensity 1", "jazz velvet lounge intensity 1", "blue collar muzak"],
        "folder_affinities": ["Corporate Music Pack Vol. 1", "Jazz Music Pack"]
    },
    "band_1_white_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Epoch 3 (Tier 2): White collar promotion — full orchestra strings arrangement of the theme.",
        "ideal_duration": [40.0, 180.0],
        "keywords": ["corporate coffee time main", "corporate cheerful whistle main", "executive muzak"],
        "folder_affinities": ["Corporate Music Pack Vol. 1"]
    },
    "band_2_early_contact": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Tiers 3-11: First alien civilizations — melody carries over with ethereal synth pads.",
        "ideal_duration": [40.0, 180.0],
        "keywords": ["ethereal vol3 air flows", "space 1", "early contact ambience", "space synth"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3", "Space Audio Bundle"]
    },
    "band_3_mid": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Tiers 12-19: Galactic federation — exotic scales and non-Western harmonic textures.",
        "ideal_duration": [40.0, 180.0],
        "keywords": ["ethereal vol3 mystics", "eastern mysterious land main", "galactic synth"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3", "Eastern Music Pack"]
    },
    "band_4_deep": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Tiers 20+: Deep cosmos void — ethereal, transcendent cosmic soundscapes.",
        "ideal_duration": [40.0, 180.0],
        "keywords": ["ethereal vol3 direct sunlight", "ethereal vol3 winds of time", "deep space void"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3"]
    },

    # Settings
    "music_preview": {
        "bus": "Music", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Releasing the MUSIC slider in Settings screen.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["stinger 15", "reward 1", "music stinger", "chime"],
        "folder_affinities": ["Buttons and Stingers", "Misc"]
    }
}

# Deployed / Sourced Cues from CREDITS.md & deploy_audio_selections.py
DEPLOYED_LIBRARY_PATHS = {
    "tap_note": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
    "buy_success": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip6.mp3",
    "hire_first": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Craft Button 2.wav",
    "hire_levelled": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Mining (diamond) 1.wav",
    "retain_staff": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip5.mp3",
    "cycle_started": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Steps/Horse (sand) 1.wav",
    "frenzy_pop": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Lever 3 (Power On).wav",
    "overdrive_engage": "puzzleaudiokit/Puzzle Audio Bundle/MP3/FX/Misc/Clock Alarm 1 (loop).mp3",
    "vent_tick": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
    "vent_open": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Button 2.wav",
    "vent_lift": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Place Diamond.wav",
    "vent_success": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav",
    "vent_miss": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Buzzer.wav",
    "overheat": "spaceaudiobundle/Space Audio Bundle/MP3/FX/Decompression 2.mp3",
    "rush_ready": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
    "heat_loop": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Gear 3 (loop).wav",
    "tab_switch": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Weapons/Bullet impact 6.wav",
    "mode_toggle": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav",
    "epoch_page": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 10.wav",
    "make_contact": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Teleportation.wav",
    "tip_appear": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav",
    "minigame_begin": "Foley Sports Sound FX Pack/Foley Sports/Whistle/Whistle Blow Normal.wav",
    "minigame_score": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav",
    "minigame_miss": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
    "minigame_countdown": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Puntuation Sound.wav",
    "minigame_over": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Buzzer.wav",
    "bball_launch": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Ball Throw Fast.wav",
    "bball_fizzle": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Timer A.wav",
    "bball_wall": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Normal.wav",
    "bball_swish": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Net Swoosh Normal.wav"
}

# Curated recommendations for unassigned cues or alternative options
CURATED_PICKS = {
    # Core Loop alternatives
    "tap_note": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav", "role": "primary", "note": "Active in Godot code (0.099s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Counter A.wav", "role": "candidate", "note": "Mechanical tally tick (0.142s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "candidate", "note": "Tactile click alternate"}
    ],
    "buy_success": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinFlip6.mp3", "role": "primary", "note": "Active in Godot code (0.867s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 1.wav", "role": "candidate", "note": "Heavy coins bag texture (0.565s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 2.wav", "role": "layer", "note": "Celebratory gold layer for big jumps"}
    ],
    "milestone": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav", "role": "primary", "note": "Triumph scoreboard milestone bell (0.408s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Misc/LevelUp1.mp3", "role": "candidate", "note": "Level up fanfare (1.776s)"}
    ],
    "frenzy_end": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 2.wav", "role": "primary", "note": "Steam cooldown exhaust (2.43s)"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Vent Exhale.wav", "role": "candidate", "note": "Pneumatic exhaust (8.81s)"}
    ],
    "urgency_loop": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Saw (loop).wav", "role": "primary", "note": "Urgency engine friction loop (2.44s)"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Pathetic Alarm.wav", "role": "candidate", "note": "Warning pulsation loop (2.93s)"}
    ],
    "screen_open": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Open Drawer 2.wav", "role": "primary", "note": "Physical cabinet / drawer open (0.691s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Select/Select Button 1.wav", "role": "candidate", "note": "Panel select (0.489s)"}
    ],
    "screen_close": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Close Drawer 2.wav", "role": "primary", "note": "Panel dismiss (0.505s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Cancel/Cancel Button 1.wav", "role": "candidate", "note": "Cancel dismiss"}
    ],
    "denied_cash": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 1.wav", "role": "primary", "note": "Refusal buzz for insufficient cash (0.529s)"}
    ],
    "denied_locked": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 3.wav", "role": "primary", "note": "Locked state denial (0.540s)"}
    ],
    "challenge_start": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Boxing Bell Fight Start.wav", "role": "primary", "note": "Match starting fight bell (0.760s)"}
    ],
    "challenge_credit": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Reward 1.wav", "role": "primary", "note": "Challenge victory score credit (1.20s)"}
    ],
    "challenge_tier": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav", "role": "primary", "note": "Ladder climb chime (0.408s)"}
    ],
    "bball_grab": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Basketball Squeak Single A.wav", "role": "primary", "note": "Tactile gym court shoe/ball squeak (0.134s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Shoe Squeak A.wav", "role": "candidate", "note": "Shoe grip alternate"}
    ],
    "bball_floor": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Normal.wav", "role": "primary", "note": "Hardwood basketball bounce (0.334s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Dribble A.wav", "role": "variant_1", "note": "Dribble bounce alternate"}
    ],
    "bball_settle": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Soft.wav", "role": "primary", "note": "Ball settling roll (0.240s)"}
    ],
    "bball_rim": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Net Hit Intense.wav", "role": "primary", "note": "Hoop rim hit (0.405s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Football - Rugby/Field Goal Kick Goalpost.wav", "role": "candidate", "note": "Metal post clang"}
    ],
    "bball_score": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/In The Net A.wav", "role": "primary", "note": "Clean made basket (0.420s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/In The Net B.wav", "role": "variant_1", "note": "Basket made variation"}
    ],
    "bball_gem_through": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Jewels & Runes/Gem1.mp3", "role": "primary", "note": "Crystal chime pass-through (0.450s)"}
    ],
    "bball_gem_earned": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Legacy basket celebration stinger (6.08s)"}
    ],
    "m3_select": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "primary", "note": "Tactile gem pick up click (0.150s)"}
    ],
    "m3_swap": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 13.wav", "role": "primary", "note": "Smooth gem tile slide (0.263s)"}
    ],
    "m3_invalid": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 1.wav", "role": "primary", "note": "Invalid match refusal (0.529s)"}
    ],
    "m3_match": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Reward 2.wav", "role": "primary", "note": "Clear match chime (0.540s)"}
    ],
    "m3_fall": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "primary", "note": "Gem grid drop refill (0.534s)"}
    ],
    "m3_avoid": [
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Pathetic Alarm.wav", "role": "primary", "note": "Avoid gem hazard strike (2.93s)"}
    ],
    "m3_legacy": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Match-3 Legacy collect fanfare (6.08s)"}
    ],
    "catch_coin": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp2.mp3", "role": "primary", "note": "Crisp falling coin catch (0.336s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp1.mp3", "role": "variant_1", "note": "Coin catch variant (0.384s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "variant_2", "note": "Paper dollar catch variation (0.534s)"}
    ],
    "catch_premium": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 1.wav", "role": "primary", "note": "Heavy gold coin catch (0.565s)"}
    ],
    "catch_legacy": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPouring3.mp3", "role": "primary", "note": "Jackpot fortune cascade (8.28s)"}
    ],
    "catch_miss": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp3.mp3", "role": "primary", "note": "Dropped coin floor impact (0.350s)"}
    ],
    "catch_spawn": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav", "role": "primary", "note": "Soft bubble spawn pop (0.533s)"}
    ],
    "mem_pad": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Button 2.wav", "role": "primary", "note": "Pad synthesizer note (0.251s)"}
    ],
    "mem_round": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Reward 1.wav", "role": "primary", "note": "Round clear arpeggio (1.20s)"}
    ],
    "mem_wrong": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 1.wav", "role": "primary", "note": "Memory error buzzer (0.529s)"}
    ],
    "mem_gem": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Memory bonus gem (6.08s)"}
    ],
    "bal_enter": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 13.wav", "role": "primary", "note": "Balance zone entry lock (0.263s)"}
    ],
    "bal_leave": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "primary", "note": "Balance zone leave tone (0.150s)"}
    ],
    "bal_lift": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Place Diamond.wav", "role": "primary", "note": "Lift impulse sound (0.320s)"}
    ],
    "bal_gem": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Balance reward gem (6.08s)"}
    ],
    "time_lock_hit": [
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Strong Accept.wav", "role": "primary", "note": "Target lock success (2.70s)"}
    ],
    "time_lock_miss": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 1.wav", "role": "primary", "note": "Target lock miss (0.529s)"}
    ],
    "time_gem": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Timing lock gem (6.08s)"}
    ],
    "ceremony_obituary": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Bell 1.wav", "role": "primary", "note": "Solemn succession bell toll (6.84s)"}
    ],
    "ceremony_will": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "primary", "note": "Opening last will parchment (0.534s)"}
    ],
    "ceremony_heir": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Heir continuation fanfare (6.08s)"}
    ],
    "ceremony_contact": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (summon) 1.mp3", "role": "primary", "note": "Alien contact stinger (6.13s)"}
    ],
    "ceremony_contact_reveal": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav", "role": "primary", "note": "Civilization transmission decode (0.403s)"}
    ],
    "ceremony_fanfare": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "primary", "note": "Dynasty triumph fanfare (1.659s)"}
    ],
    "ceremony_power_down": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 1.wav", "role": "primary", "note": "System power down (3.74s)"}
    ],
    "legacy_purchase": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (summon) 1.mp3", "role": "primary", "note": "Permanent legacy purchase (6.13s)"}
    ],
    "welcome_back": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPouring3.mp3", "role": "primary", "note": "Offline cash shower (8.28s)"}
    ],
    "prestige_confirm": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Boxing Bell Fight Start.wav", "role": "primary", "note": "Succession bell handover (0.760s)"}
    ],
    "band_0_blue_collar": [
        {"path": "Corporate Music Pack Vol. 1/Corporate Coffee Time (RT 4.000)/Intensity 1.wav", "role": "primary", "note": "Department-store acoustic muzak (100.0s)"}
    ],
    "band_1_white_collar": [
        {"path": "Corporate Music Pack Vol. 1/Corporate Coffee Time (RT 4.000)/Main.wav", "role": "primary", "note": "Executive strings arrangement (100.0s)"}
    ],
    "band_2_early_contact": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Air Flows (RT 4.000)/Main.wav", "role": "primary", "note": "Ethereal synth texture (92.0s)"}
    ],
    "band_3_mid": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Mystics (RT 4.000)/Main.wav", "role": "primary", "note": "Alien harmonics (88.0s)"}
    ],
    "band_4_deep": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Direct Sunlight (RT 4.000)/Main.wav", "role": "primary", "note": "Deep space void soundtrack (96.0s)"}
    ]
}

# Irrelevant negative keywords for audio noise filtering
NEGATIVE_KEYWORDS = [
    "horse", "bear", "animal", "creature", "monster", "zombie", "growl", "roar", "scream",
    "shotgun", "rifle", "firearm", "bullet", "bandit", "sword", "knife", "bow", "arrow",
    "footstep", "step", "walking", "running", "skate", "golf hit", "cricket"
]


def parse_credits_md():
    """Parse CREDITS.md to get exact licensor, pack, and file for sourced cues."""
    credits_map = {}
    if not os.path.exists(CREDITS_PATH):
        return credits_map
    with open(CREDITS_PATH, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("| `"):
                parts = [p.strip() for p in line.split("|")[1:-1]]
                if len(parts) >= 5:
                    cue_id = parts[0].strip("`")
                    src_file = parts[1].strip("`")
                    pack = parts[2]
                    licensor = parts[3]
                    license_info = parts[4]
                    credits_map[cue_id] = {
                        "source_file": src_file,
                        "pack": pack,
                        "licensor": licensor,
                        "license": license_info,
                        "library_rel_path": DEPLOYED_LIBRARY_PATHS.get(cue_id, "")
                    }
    return credits_map


def get_audio_duration(file_path, ext, size):
    """Accurately extract duration from WAV RIFF header or estimate MP3/OGG."""
    if ext == '.wav':
        if size < 44:
            return 0.1
        try:
            with open(file_path, 'rb') as f:
                header = f.read(64)
                if header[:4] == b'RIFF' and header[8:12] == b'WAVE':
                    fmt_idx = header.find(b'fmt ')
                    if fmt_idx != -1 and len(header) >= fmt_idx + 20:
                        byte_rate = struct.unpack('<I', header[fmt_idx+16:fmt_idx+20])[0]
                        if byte_rate > 0:
                            return round((size - 44) / byte_rate, 3)
        except Exception:
            pass
        return round(max(0.05, size / 176400.0), 3)
    elif ext == '.mp3':
        return round(max(0.1, size / 24000.0), 3)
    elif ext == '.ogg':
        return round(max(0.1, size / 16000.0), 3)
    return 1.0


def scan_all_library_files():
    """Scan all 15 audio packs and build indexed file catalog with fast parsing."""
    print("Scanning audio packs in:", GAME_AUDIO_DIR)
    catalog = []
    if not os.path.exists(GAME_AUDIO_DIR):
        print(f"Warning: {GAME_AUDIO_DIR} not found!")
        return catalog
    
    pack_dirs = [d for d in os.listdir(GAME_AUDIO_DIR) if os.path.isdir(os.path.join(GAME_AUDIO_DIR, d)) and not d.startswith('__')]
    
    for pack in sorted(pack_dirs):
        pack_path = os.path.join(GAME_AUDIO_DIR, pack)
        for root, dirs, files in os.walk(pack_path):
            if '__MACOSX' in root:
                continue
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in ('.wav', '.mp3', '.ogg') and not f.startswith('._'):
                    full_path = os.path.join(root, f)
                    rel_to_audio_root = os.path.relpath(full_path, GAME_AUDIO_DIR)
                    
                    size_bytes = os.path.getsize(full_path)
                    duration = get_audio_duration(full_path, ext, size_bytes)
                    
                    name_clean = os.path.splitext(f)[0]
                    subfolder_rel = os.path.relpath(root, pack_path).replace('\\', '/')
                    
                    tokens = set(re.findall(r'[a-zA-Z0-9]+', f.lower() + " " + subfolder_rel.lower().replace('/', ' ')))
                    
                    catalog.append({
                        "id": rel_to_audio_root.replace('\\', '/'),
                        "filename": f,
                        "name_clean": name_clean,
                        "pack": pack,
                        "rel_path": rel_to_audio_root.replace('\\', '/'),
                        "subfolder": subfolder_rel,
                        "format": ext.replace('.', '').upper(),
                        "size_bytes": size_bytes,
                        "duration": duration,
                        "is_loop": "loop" in f.lower() or "loop" in root.lower(),
                        "tokens": list(tokens)
                    })
    
    print(f"Indexed {len(catalog)} audio files across {len(pack_dirs)} packs.")
    return catalog


def inspect_game_audio_for_cue(cue_id, category, credits_map):
    """
    Inspect what audio files exist in game/audio/ for a specific cue,
    following Godot's Audio.gd runtime resolution order (.ogg then .wav).
    """
    cues_dir = os.path.join(PROJECT_AUDIO_DIR, "cues")
    loops_dir = os.path.join(PROJECT_AUDIO_DIR, "loops")
    music_dir = os.path.join(PROJECT_AUDIO_DIR, "music")
    
    target_dir = cues_dir if category == "cue" else (loops_dir if category == "loop" else music_dir)
    is_sourced = cue_id in credits_map
    
    # 1. Resolve active base file (.ogg then .wav)
    active_file = None
    all_files = []
    
    if os.path.exists(target_dir):
        # Look for direct matches
        for ext in [".ogg", ".wav", ".mp3"]:
            fn = cue_id + ext
            fp = os.path.join(target_dir, fn)
            if os.path.exists(fp):
                sz = os.path.getsize(fp)
                dur = get_audio_duration(fp, ext, sz)
                file_obj = {
                    "filename": fn,
                    "path": f"game/audio/{os.path.basename(target_dir)}/{fn}",
                    "format": ext.replace('.', '').upper(),
                    "size": sz,
                    "duration": dur,
                    "is_active": active_file is None
                }
                all_files.append(file_obj)
                if active_file is None:
                    active_file = file_obj
    
    # 2. Resolve variants (_1 to _4)
    variants = []
    if category == "cue":
        for i in range(1, 5):
            var_id = f"{cue_id}_{i}"
            for ext in [".ogg", ".wav", ".mp3"]:
                fn = var_id + ext
                fp = os.path.join(cues_dir, fn)
                if os.path.exists(fp):
                    sz = os.path.getsize(fp)
                    dur = get_audio_duration(fp, ext, sz)
                    variants.append({
                        "variant_index": i,
                        "filename": fn,
                        "path": f"game/audio/cues/{fn}",
                        "format": ext.replace('.', '').upper(),
                        "size": sz,
                        "duration": dur
                    })
                    break
    
    # 3. Resolve layer (_layer)
    layer = None
    if category == "cue":
        layer_id = f"{cue_id}_layer"
        for ext in [".ogg", ".wav", ".mp3"]:
            fn = layer_id + ext
            fp = os.path.join(cues_dir, fn)
            if os.path.exists(fp):
                sz = os.path.getsize(fp)
                dur = get_audio_duration(fp, ext, sz)
                layer = {
                    "filename": fn,
                    "path": f"game/audio/cues/{fn}",
                    "format": ext.replace('.', '').upper(),
                    "size": sz,
                    "duration": dur
                }
                break
    
    # Status determination
    if active_file:
        status = "sourced" if is_sourced else "placeholder"
    elif variants:
        status = "sourced" if is_sourced else "placeholder"
        active_file = variants[0] # e.g. bball_floor uses variants directly
    else:
        status = "missing"
    
    return {
        "status": status,
        "is_sourced": is_sourced,
        "active_file": active_file,
        "source_info": credits_map.get(cue_id),
        "variants": variants,
        "layer": layer,
        "all_files": all_files
    }


def score_candidate_match(cue_id, cue_meta, audio_file, credits_map):
    """
    Compute high-precision match strength score (0 - 100) between an audio file and a game cue.
    """
    file_rel_norm = audio_file["rel_path"].lower()
    file_name_lower = audio_file["filename"].lower()
    file_subfolder_lower = audio_file["subfolder"].lower()
    
    # 1. Exact Deployed In-Game Match
    if cue_id in DEPLOYED_LIBRARY_PATHS:
        dep_path = DEPLOYED_LIBRARY_PATHS[cue_id].lower()
        if dep_path in file_rel_norm or file_rel_norm.endswith(dep_path) or (os.path.basename(dep_path) == file_name_lower and dep_path.split('/')[0] in file_rel_norm):
            return 100, f"Active In-Game Sound (Sourced from {audio_file['pack']})"
    
    # 2. Curated Priority Match
    if cue_id in CURATED_PICKS:
        for pick in CURATED_PICKS[cue_id]:
            pick_path_norm = pick["path"].lower()
            pick_fn = os.path.basename(pick["path"]).lower()
            
            if pick_path_norm in file_rel_norm or file_rel_norm.endswith(pick_path_norm):
                base_score = 98 if pick["role"] == "primary" else (95 if pick["role"].startswith("variant") else (93 if pick["role"] == "layer" else 88))
                return base_score, f"Curated: {pick.get('note', 'Research match')}"
            
            if pick_fn == file_name_lower and pick["path"].split('/')[0].lower() in file_rel_norm:
                base_score = 94 if pick["role"] == "primary" else 88
                return base_score, f"Curated: {pick.get('note', 'Pack match')}"

    # 3. Negative Noise Filtering
    is_weapon_or_animal = any(neg in file_name_lower or neg in file_subfolder_lower for neg in NEGATIVE_KEYWORDS)
    if is_weapon_or_animal and "frenzy" not in cue_id and "avoid" not in cue_id and "tab_switch" not in cue_id:
        return 0, "Noise filtered (unrelated sound family)"

    score = 0.0
    reasons = []
    file_tokens = set(audio_file["tokens"])
    
    # 4. Subfolder Affinity Bonus
    folder_affinities = cue_meta.get("folder_affinities", [])
    for aff in folder_affinities:
        aff_lower = aff.lower()
        if aff_lower in file_subfolder_lower or aff_lower in audio_file["pack"].lower():
            score += 35
            reasons.append(f"Subfolder: {aff}")
            break

    # 5. Cue Specific Keywords
    keywords = cue_meta.get("keywords", [])
    matched_kws = []
    for kw in keywords:
        kw_lower = kw.lower()
        kw_parts = kw_lower.split()
        if all(part in file_tokens or part in file_name_lower for part in kw_parts):
            matched_kws.append(kw)
            score += 25
        elif any(part in file_tokens for part in kw_parts):
            score += 10
            
    if matched_kws:
        reasons.append(f"Keywords: {', '.join(matched_kws[:3])}")

    # Specific boosts
    if cue_id.startswith("bball_"):
        if "basketball" in file_subfolder_lower or "basketball" in file_rel_norm:
            score += 45
            reasons.append("Basketball sound library")
        elif "tennis" in file_subfolder_lower and any(w in file_name_lower for w in ["squeak", "wall hit"]):
            score += 35
            reasons.append("Gym court acoustics")

    if cue_id.startswith("m3_"):
        if "jewels" in file_subfolder_lower or "puzzle" in file_rel_norm:
            score += 30
            reasons.append("Puzzle & Gem library")

    if cue_id.startswith("catch_"):
        if "coins" in file_subfolder_lower or "coin" in file_name_lower:
            score += 40
            reasons.append("Coin sound category")

    if cue_meta.get("bus") == "UI":
        if "buttons sfx library" in file_rel_norm:
            score += 25
            reasons.append("Tactile UI library")

    # Duration Adherence
    ideal_dur = cue_meta.get("ideal_duration", [0.1, 2.0])
    dur = audio_file["duration"]
    if ideal_dur[0] <= dur <= ideal_dur[1]:
        score += 15
        reasons.append(f"Duration {dur:.2f}s")
    elif dur < ideal_dur[0] * 0.7:
        score -= 20
    elif dur > ideal_dur[1] * 2.0:
        score -= 35

    # Loop cues
    if "loop" in cue_id or cue_meta.get("bus") == "Music":
        if audio_file["is_loop"] or "loop" in file_name_lower:
            score += 25
            reasons.append("Seamless loop tagged")
        if cue_meta.get("bus") == "Music" and dur >= 50.0:
            score += 20
    else:
        if audio_file["is_loop"] and dur > 5.0:
            score -= 30

    final_score = int(max(0, min(87, score)))
    reason_str = " | ".join(reasons) if reasons else "Keyword match"
    return final_score, reason_str


def build_audio_database():
    credits_map = parse_credits_md()
    print(f"Loaded {len(credits_map)} sourced cue entries from CREDITS.md")
    
    catalog = scan_all_library_files()
    
    all_assigned_file_ids = set()
    sections_output = []
    total_cues_count = 0
    total_sourced_count = 0
    total_placeholder_count = 0
    
    for group in CUE_GROUPS:
        cues_list = []
        for cue_id in group["cues"]:
            total_cues_count += 1
            meta = CUE_METADATA.get(cue_id, {
                "bus": "SFX", "db": -6.0, "cooldown": 50, "layered": False, "has_variants": False,
                "trigger": "Audio event", "ideal_duration": [0.1, 2.0], "keywords": [], "folder_affinities": []
            })
            
            category = "loop" if "loop" in cue_id else ("music" if group["id"] == "music_tracks" else "cue")
            in_game_info = inspect_game_audio_for_cue(cue_id, category, credits_map)
            
            if in_game_info["is_sourced"]:
                total_sourced_count += 1
            else:
                total_placeholder_count += 1
            
            # Find and rank candidates
            candidates = []
            for item in catalog:
                score, reason = score_candidate_match(cue_id, meta, item, credits_map)
                if score >= 25 or (cue_id in DEPLOYED_LIBRARY_PATHS and os.path.basename(DEPLOYED_LIBRARY_PATHS[cue_id]).lower() == item["filename"].lower()):
                    role = "candidate"
                    is_active_deployed = False
                    
                    # Check if this candidate is the deployed in-game sound
                    if cue_id in DEPLOYED_LIBRARY_PATHS:
                        dep_p = DEPLOYED_LIBRARY_PATHS[cue_id].lower()
                        if dep_p in item["rel_path"].lower() or item["rel_path"].lower().endswith(dep_p) or (os.path.basename(dep_p) == item["filename"].lower() and dep_p.split('/')[0] in item["rel_path"].lower()):
                            role = "primary"
                            is_active_deployed = True
                            score = 100
                            reason = f"Active in Godot code (Sourced from {item['pack']})"
                    
                    if not is_active_deployed and cue_id in CURATED_PICKS:
                        for p in CURATED_PICKS[cue_id]:
                            if os.path.basename(p["path"]).lower() == item["filename"].lower() and (p["path"].split('/')[0].lower() in item["rel_path"].lower()):
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
                        "is_current_deployed": is_active_deployed,
                        "selected": is_active_deployed or role in ("primary", "layer", "variant_1") or score >= 95
                    })
            
            # Sort: active deployed always at top, then score, then duration match
            candidates.sort(key=lambda x: (1 if x["is_current_deployed"] else 0, x["score"], -abs(x["duration"] - meta.get("ideal_duration", [0.5, 1.0])[0])), reverse=True)
            
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
                "existing_in_game": in_game_info,
                "candidates": candidates[:30]
            })
        
        sections_output.append({
            "section_id": group["id"],
            "name": group["name"],
            "description": group["description"],
            "cues": cues_list
        })
    
    # Packs Summary
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
        "generated_at": "2026-08-17",
        "total_library_files": len(catalog),
        "total_cues": total_cues_count,
        "total_sourced": total_sourced_count,
        "total_placeholders": total_placeholder_count,
        "packs": list(packs_summary.values()),
        "sections": sections_output,
        "library_sample": catalog
    }
    
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Generated {OUTPUT_JSON_PATH} successfully.")
    print(f"Sections: {len(sections_output)}, Total cues: {total_cues_count} (Sourced: {total_sourced_count}, Placeholders: {total_placeholder_count}), Library files: {len(catalog)}")


if __name__ == "__main__":
    build_audio_database()
