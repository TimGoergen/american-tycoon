#!/usr/bin/env python3
"""
High-Precision Audio Database & Recommendation Generator for American Tycoon.
Indexes 3,763 licensed audio assets across 15 packs in D:\\Downloads\\Game_Audio.
Applies semantic subfolder matching, category affinity, duration constraints,
negative noise filtering, and research-backed curated picks to deliver top-tier
recommendations for all 87 game audio cues.
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
        "keywords": ["card deliver", "contract", "stamp", "signature", "paper", "lock", "select button", "clothesequip"],
        "folder_affinities": ["SFX/Misc", "Books & Scrolls", "Select", "Bags"]
    },
    "milestone": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A property crosses a count milestone (25, 50, 100...). Fires on crossing.",
        "ideal_duration": [0.3, 1.8],
        "keywords": ["scoreboard ding", "ding", "bell", "levelup", "chime", "achievement", "triumph", "reward"],
        "folder_affinities": ["Buzzers and Boards", "Misc", "Events", "Buttons and Stingers"]
    },
    "cycle_started": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Tapping a STOPPED property to start one cycle by hand (machine turnover, not payout).",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["hammer", "lever", "crank", "gear", "switch", "turn", "start", "ratchet", "open lock"],
        "folder_affinities": ["FX", "Misc", "Click"]
    },
    "frenzy_pop": {
        "bus": "SFX", "db": -2.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Popping the FRENZY meter.",
        "ideal_duration": [0.4, 2.0],
        "keywords": ["fire", "ignite", "flame", "blast", "power", "siren sound", "frenzy", "burst"],
        "folder_affinities": ["Fire", "Buzzers and Boards", "FX", "Generic"]
    },
    "frenzy_end": {
        "bus": "SFX", "db": -10.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A frenzy burn runs out.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["steam", "cooldown", "hiss", "extinguish", "drain", "power down", "wind down", "fizzle", "exhaust"],
        "folder_affinities": ["FX", "Tech and Mech", "Update"]
    },

    # Rush and Overdrive
    "overdrive_engage": {
        "bus": "SFX", "db": -3.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The OVERDRIVE button engaged, ride begins.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["computer on", "engine rev", "thruster", "boost", "engage", "ignition", "power on"],
        "folder_affinities": ["FX", "Tech and Mech", "Start"]
    },
    "vent_tick": {
        "bus": "SFX", "db": -12.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "One per required lift, counted out the instant the vent window opens.",
        "ideal_duration": [0.03, 0.25],
        "keywords": ["pacer beeps", "pacer", "beep", "tick", "telegraph", "pip", "blip", "button 2", "timer"],
        "folder_affinities": ["Buzzers and Boards", "Buttons SFX Library", "FX"]
    },
    "vent_open": {
        "bus": "SFX", "db": -1.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "A vent window opens. Crucial gameplay telegraph to lift immediately.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["buzzer", "scoreboard buzzer", "communication receiving", "alert", "horn", "klaxon", "warning", "valve"],
        "folder_affinities": ["Buzzers and Boards", "FX", "Tech and Mech"]
    },
    "vent_lift": {
        "bus": "SFX", "db": -6.0, "cooldown": 10, "layered": False, "has_variants": False,
        "trigger": "Each lift registered inside the window. Pitched up one whole tone per lift.",
        "ideal_duration": [0.08, 0.5],
        "keywords": ["elevator", "whoosh", "lift", "valve", "pump", "generic spell end", "piston", "air release"],
        "folder_affinities": ["FX", "Generic", "Slide"]
    },
    "vent_success": {
        "bus": "SFX", "db": -2.0, "cooldown": 100, "layered": True, "has_variants": False,
        "trigger": "A vent completes in time. Intensity scales with vent tier reached.",
        "ideal_duration": [0.4, 2.8],
        "keywords": ["strong accept", "accept", "reward 2", "reward 1", "success", "chime", "complete"],
        "folder_affinities": ["Tech and Mech", "Misc", "Events"]
    },
    "vent_miss": {
        "bus": "SFX", "db": -4.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The vent window closes unmet — fires just before overheat.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["strong deny", "deny", "wrong 1", "wrong 3", "error", "buzz", "fault", "miss"],
        "folder_affinities": ["Tech and Mech", "Misc", "Cancel"]
    },
    "overheat": {
        "bus": "SFX", "db": -2.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "The ride ends in flames. Heat drains, rushing is locked out.",
        "ideal_duration": [0.8, 4.0],
        "keywords": ["decompression", "vent exhale", "exhaust", "steam", "explosion", "overheat", "sizzle"],
        "folder_affinities": ["FX", "Tech and Mech", "Fire"]
    },
    "rush_ready": {
        "bus": "SFX", "db": -8.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "The lockout ends and rushing is live again.",
        "ideal_duration": [0.2, 1.2],
        "keywords": ["computer on", "scoreboard ding", "ready", "boot", "chime", "power on", "recharge"],
        "folder_affinities": ["FX", "Buzzers and Boards", "Start"]
    },
    "heat_loop": {
        "bus": "SFX", "db": -16.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous mechanical drone held while momentum/heat is active.",
        "ideal_duration": [1.5, 30.0],
        "keywords": ["truck gear idle", "gear loop", "engine loop", "idle loop", "hum loop", "electric loop", "motor"],
        "folder_affinities": ["Update", "Electric", "FX"]
    },
    "urgency_loop": {
        "bus": "SFX", "db": -14.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Continuous rising tension sound held as heat approaches critical redline.",
        "ideal_duration": [1.5, 30.0],
        "keywords": ["saw loop", "pathetic alarm", "alarm loop", "tension loop", "siren loop", "urgency"],
        "folder_affinities": ["FX", "Tech and Mech", "Update"]
    },

    # Interface
    "tab_switch": {
        "bus": "UI", "db": -10.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "Changing tab, and only when the tab actually changes.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["slide button 13", "slide button", "slide", "switch", "tab", "swipe", "button 5"],
        "folder_affinities": ["Slide", "Buttons and Stingers", "Click"]
    },
    "screen_open": {
        "bus": "UI", "db": -9.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Opening a modal screen: About, Stats, Challenges, Help, Tuning.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["open drawer 2", "open drawer", "select button 1", "open", "popup", "expand", "drawer"],
        "folder_affinities": ["Misc", "Select", "Buttons SFX Library"]
    },
    "screen_close": {
        "bus": "UI", "db": -11.0, "cooldown": 100, "layered": False, "has_variants": False,
        "trigger": "Closing a modal screen.",
        "ideal_duration": [0.2, 0.9],
        "keywords": ["close drawer 3", "close drawer", "click button 6", "close", "cancel", "dismiss", "popdown"],
        "folder_affinities": ["Misc", "Cancel", "Click"]
    },
    "mode_toggle": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "The buy-mode or hire-mode toggle.",
        "ideal_duration": [0.08, 0.35],
        "keywords": ["click button 6", "click button 1", "click button", "toggle", "switch", "tick", "flick"],
        "folder_affinities": ["Click", "Select", "Buttons and Stingers"]
    },
    "epoch_page": {
        "bus": "UI", "db": -12.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "The epoch pager moves to another civilization.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["card deliver 1", "slide button 1", "page flip", "slide", "carousel", "flick"],
        "folder_affinities": ["Slide", "SFX/Misc", "Books & Scrolls"]
    },
    "make_contact": {
        "bus": "UI", "db": -1.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "The MAKE CONTACT button — the biggest action button in the game.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["teleportation", "beam me up", "select button 1", "warp", "contact", "portal", "light speed"],
        "folder_affinities": ["FX", "Tech and Mech", "Select"]
    },
    "tip_appear": {
        "bus": "UI", "db": -12.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "A tutorial coach card appears.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["bubble button", "bubble", "pop", "tip", "notification", "hint", "chime", "appear"],
        "folder_affinities": ["Bubble", "Misc", "Buttons SFX Library"]
    },
    "denied_cash": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "Reserved: an action refused for want of money.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["wrong 1", "cancel button", "deny", "dull", "empty", "no", "buzz", "refuse"],
        "folder_affinities": ["Cancel", "Misc", "Tech and Mech"]
    },
    "denied_locked": {
        "bus": "UI", "db": -10.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "Reserved: an action refused because something is locked.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["close lock", "padlock", "lock", "chain", "rattle", "metal rattle", "locked"],
        "folder_affinities": ["Misc", "FX", "Cancel"]
    },

    # Challenge Mode
    "challenge_start": {
        "bus": "UI", "db": -6.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Launching a game from the CHALLENGES screen.",
        "ideal_duration": [0.4, 1.8],
        "keywords": ["start gun", "whistle blow", "start button", "buzzer", "launch", "ready", "charge"],
        "folder_affinities": ["Buzzers and Boards", "Whistle", "Start", "Buttons and Stingers"]
    },
    "challenge_credit": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "A challenge run ends and its score is credited.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["coinbag", "coins pouring", "tally", "score count", "reward", "coins bag", "credit"],
        "folder_affinities": ["Coins", "Events", "Misc", "Buttons and Stingers"]
    },
    "challenge_tier": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "A challenge run climbs a tier of its ladder mid-run.",
        "ideal_duration": [0.6, 2.2],
        "keywords": ["stinger 15", "stinger 8", "levelup", "tier", "rank up", "fanfare", "chime"],
        "folder_affinities": ["Buttons and Stingers", "Misc", "Bravery", "Revive"]
    },

    # Shared Minigames
    "minigame_begin": {
        "bus": "UI", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "BEGIN on a minigame Get Ready gate — the round starts.",
        "ideal_duration": [0.3, 1.5],
        "keywords": ["whistle blow normal", "start gun", "buzzer", "ready", "start button", "stinger"],
        "folder_affinities": ["Whistle", "Buzzers and Boards", "Start", "Buttons and Stingers"]
    },
    "minigame_score": {
        "bus": "SFX", "db": -8.0, "cooldown": 40, "layered": False, "has_variants": False,
        "trigger": "The player scores in any minigame (shared layer across all 6 games).",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["scoreboard ding", "coin pickup", "ding", "score", "point", "hit", "ping", "reward"],
        "folder_affinities": ["Buzzers and Boards", "Coins", "Misc", "Events"]
    },
    "minigame_miss": {
        "bus": "SFX", "db": -7.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A miss that costs challenge time (shared miss channel).",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["wrong 1", "wrong 3", "buzzer", "miss", "error", "fail", "thud"],
        "folder_affinities": ["Misc", "Buzzers and Boards", "Cancel", "Tech and Mech"]
    },
    "minigame_countdown": {
        "bus": "UI", "db": -9.0, "cooldown": 250, "layered": False, "has_variants": False,
        "trigger": "One per second over the last few seconds of the minigame clock.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["scoreboard timer", "timer", "pacer beeps", "tick", "beep", "countdown", "clock"],
        "folder_affinities": ["Buzzers and Boards", "Buttons SFX Library", "FX"]
    },
    "minigame_best": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "The run passes the stored high score. Once per run.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["stinger 15", "stinger 8", "high score", "fanfare", "victory", "triumph", "record"],
        "folder_affinities": ["Buttons and Stingers", "Bravery", "Events", "Misc"]
    },
    "minigame_over": {
        "bus": "UI", "db": -4.0, "cooldown": 500, "layered": False, "has_variants": False,
        "trigger": "A minigame round or challenge run ends.",
        "ideal_duration": [0.5, 2.5],
        "keywords": ["whistle blow intense stop", "scoreboard buzzer", "soccer match end", "buzzer", "game over", "finish"],
        "folder_affinities": ["Whistle", "Buzzers and Boards", "Events"]
    },

    # Basketball
    "bball_grab": {
        "bus": "SFX", "db": -16.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A finger takes the ball and slingshot drag begins.",
        "ideal_duration": [0.08, 0.4],
        "keywords": ["court squeak generic", "court squeak", "court squeak sudden stop", "ball glove catch", "glove catch", "drag", "grab"],
        "folder_affinities": ["Tennis", "Basketball", "Pool", "Baseball - Cricket", "Misc"]
    },
    "bball_launch": {
        "bus": "SFX", "db": -6.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "The throw is released. Scaled by pull force.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["throw in normal", "throw in long", "generic swing normal", "generic swing powerful", "swoosh", "throw", "release"],
        "folder_affinities": ["Soccer", "Tennis", "Basketball", "Generic", "Wind"]
    },
    "bball_fizzle": {
        "bus": "SFX", "db": -14.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "Released under minimum pull — ball drops without throw.",
        "ideal_duration": [0.1, 0.4],
        "keywords": ["generic bounce distant", "ball sink distant", "ball roll", "drop", "plop", "soft bounce", "dull"],
        "folder_affinities": ["Basketball", "Pool", "Soccer", "Misc"]
    },
    "bball_wall": {
        "bus": "SFX", "db": -12.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "The ball bounces off a side wall or ceiling.",
        "ideal_duration": [0.08, 0.4],
        "keywords": ["wall hit normal", "wall hit intense", "wall hit powerful", "padding on glass", "ball contact pad", "backboard", "bounce"],
        "folder_affinities": ["Tennis", "Hockey", "Basketball", "Pool"]
    },
    "bball_floor": {
        "bus": "SFX", "db": -11.0, "cooldown": 40, "layered": False, "has_variants": True,
        "trigger": "The ball lands on the hardwood gym floor.",
        "ideal_duration": [0.08, 0.4],
        "keywords": ["generic bounce normal", "generic bounce intense", "generic bounce distant", "ball kick normal", "dribble", "floor bounce"],
        "folder_affinities": ["Basketball", "Soccer", "Tennis", "Pool"]
    },
    "bball_settle": {
        "bus": "SFX", "db": -18.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "The ball stops rolling and becomes throwable again.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["pitch movement ball rolling", "ball roll down bar", "generic bounce distant", "roll stop", "settle", "rest"],
        "folder_affinities": ["Soccer", "Pool", "Basketball", "Misc"]
    },
    "bball_rim": {
        "bus": "SFX", "db": -8.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "Clipping a rim post — the rim-out.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["generic net hit intense", "field goal kick goalpost", "generic net hit normal", "metal clang", "rim hit", "clank", "pole hit"],
        "folder_affinities": ["Basketball", "Football - Rugby", "Hockey", "FX"]
    },
    "bball_score": {
        "bus": "SFX", "db": -5.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "A made basket. Layers over shared minigame_score.",
        "ideal_duration": [0.2, 0.8],
        "keywords": ["in the net a", "in the net b", "generic net hit normal", "generic net swoosh", "basket", "net score"],
        "folder_affinities": ["Basketball", "Soccer", "Buzzers and Boards"]
    },
    "bball_swish": {
        "bus": "SFX", "db": -3.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "A clean centered drop — the gold SWISH! Layers over minigame_score.",
        "ideal_duration": [0.3, 1.2],
        "keywords": ["net swoosh intense", "net swoosh normal", "generic net swoosh", "in the net a", "clean net", "swish", "nylon"],
        "folder_affinities": ["Basketball", "Generic", "Wind"]
    },
    "bball_gem_through": {
        "bus": "SFX", "db": -8.0, "cooldown": 120, "layered": False, "has_variants": False,
        "trigger": "The ball passes through the Legacy gem. A promise, not yet a payout.",
        "ideal_duration": [0.2, 0.7],
        "keywords": ["crystal", "jewel", "gem", "glass touch", "shimmer", "sparkle", "ping"],
        "folder_affinities": ["Jewels & Runes", "Generic", "Misc"]
    },
    "bball_gem_earned": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 400, "layered": False, "has_variants": False,
        "trigger": "Shot passed through gem AND scored — rarest basketball outcome, pays Legacy.",
        "ideal_duration": [0.8, 3.0],
        "keywords": ["revive 3", "stinger 15", "gem", "magic reward", "crystal chime", "legacy fanfare"],
        "folder_affinities": ["Revive", "Buttons and Stingers", "Jewels & Runes", "Bravery"]
    },

    # Match Three
    "m3_select": {
        "bus": "SFX", "db": -16.0, "cooldown": 50, "layered": False, "has_variants": False,
        "trigger": "A gem is picked up — the drag begins.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["click button 6", "select button 4", "crystal tap", "gem click", "glass touch", "select", "bead"],
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
        "keywords": ["pathetic alarm", "alarm 1", "wrong 3", "dark magic", "curse", "poison", "hazard", "shock"],
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
        "keywords": ["coinpouring3", "coinbag3", "coins bag 2", "jackpot", "coin shower", "fortune", "legacy chime"],
        "folder_affinities": ["Coins", "SFX/Misc", "Generic"]
    },
    "catch_miss": {
        "bus": "SFX", "db": -12.0, "cooldown": 60, "layered": False, "has_variants": False,
        "trigger": "A coin reaches floor uncaught.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["coin drop", "ball sink", "floor bounce", "clatter", "miss", "lost coin"],
        "folder_affinities": ["Coins", "Pool", "Misc"]
    },
    "catch_spawn": {
        "bus": "SFX", "db": -22.0, "cooldown": 25, "layered": False, "has_variants": False,
        "trigger": "A coin appears at the top. Quiet, makes spawn rate audible.",
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
        "keywords": ["reward 1", "reward 2", "reward 3", "success tune", "arpeggio", "sequence clear", "correct"],
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
        "keywords": ["slide button 13", "hum on", "zone enter", "lock", "chime in", "activate", "resonance in"],
        "folder_affinities": ["Slide", "FX", "Electric", "Misc"]
    },
    "bal_leave": {
        "bus": "SFX", "db": -11.0, "cooldown": 150, "layered": False, "has_variants": False,
        "trigger": "The beam drifts back out of the scoring zone.",
        "ideal_duration": [0.1, 0.5],
        "keywords": ["click button 6", "hum off", "zone exit", "dissipate", "fade tone", "resonance out"],
        "folder_affinities": ["Click", "Cancel", "FX"]
    },
    "bal_lift": {
        "bus": "SFX", "db": -16.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "The lift button is pressed to pulse the beam.",
        "ideal_duration": [0.05, 0.25],
        "keywords": ["button 2", "thruster puff", "air pulse", "lift pulse", "short click", "blip"],
        "folder_affinities": ["FX", "Buttons SFX Library", "Misc"]
    },
    "bal_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A Legacy gem earned by holding the zone long enough.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "reward 1", "shimmer", "gem earned", "harmony", "legacy reward"],
        "folder_affinities": ["Revive", "Events", "Misc", "Jewels & Runes"]
    },

    # Timing Bar
    "time_lock_hit": {
        "bus": "SFX", "db": -5.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A lock inside the target zone on the oscillating timing bar.",
        "ideal_duration": [0.15, 0.6],
        "keywords": ["strong accept", "target hit", "bullseye", "heavy lock", "snap", "latch", "lock 2"],
        "folder_affinities": ["Tech and Mech", "Misc", "FX"]
    },
    "time_lock_miss": {
        "bus": "SFX", "db": -8.0, "cooldown": 80, "layered": False, "has_variants": False,
        "trigger": "A lock outside the target zone.",
        "ideal_duration": [0.1, 0.45],
        "keywords": ["strong deny", "wrong 1", "miss click", "metal glancing", "off target", "ricochet"],
        "folder_affinities": ["Tech and Mech", "Misc", "Cancel"]
    },
    "time_gem": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "A lock that also collected the pending Legacy gem.",
        "ideal_duration": [0.6, 2.5],
        "keywords": ["revive 3", "crystal target", "perfect lock", "gem reward", "magic bell"],
        "folder_affinities": ["Revive", "Jewels & Runes", "Events"]
    },

    # Ceremony
    "ceremony_obituary": {
        "bus": "Ceremony", "db": -3.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The succession obituary card appears.",
        "ideal_duration": [2.0, 8.0],
        "keywords": ["bell 1", "bell 2", "funeral bell", "deep toll", "gong", "church bell", "solemn chime"],
        "folder_affinities": ["SFX/Misc", "Misc", "Events"]
    },
    "ceremony_will": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The reading of the tycoon's will.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["card deliver 1", "card deliver 2", "paper unfold", "parchment", "wax seal", "legal tone", "bookopen"],
        "folder_affinities": ["SFX/Misc", "Books & Scrolls", "Bags"]
    },
    "ceremony_heir": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The heir reveal — the bloodline continues.",
        "ideal_duration": [2.0, 7.0],
        "keywords": ["revive 3", "stinger 15", "triumph", "majestic fanfare", "rebirth", "dynasty"],
        "folder_affinities": ["Revive", "Buttons and Stingers", "Bravery"]
    },
    "ceremony_contact": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "A First Contact alien card opens.",
        "ideal_duration": [2.0, 7.0],
        "keywords": ["generic spell summon", "teleportation", "light speed", "beam me up", "alien portal", "cosmic"],
        "folder_affinities": ["Generic", "FX", "Tech and Mech"]
    },
    "ceremony_contact_reveal": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The alien civilization's name lands on the card.",
        "ideal_duration": [1.5, 5.0],
        "keywords": ["communication receiving 2", "incoming transmission c", "stinger 15", "stinger 8", "synth swell"],
        "folder_affinities": ["FX", "Tech and Mech", "Buttons and Stingers"]
    },
    "ceremony_fanfare": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Major celebratory milestones and prestige fanfare.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["stinger 15", "stinger 8", "stinger 14", "brass fanfare", "victory", "triumph"],
        "folder_affinities": ["Buttons and Stingers", "Bravery", "Events"]
    },
    "ceremony_power_down": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "Transition into succession or reset sequence.",
        "ideal_duration": [1.0, 4.5],
        "keywords": ["decompression 1", "decompression 2", "power down", "shut down", "turbine fade", "system offline"],
        "folder_affinities": ["FX", "Tech and Mech"]
    },
    "legacy_purchase": {
        "bus": "Ceremony", "db": -6.0, "cooldown": 300, "layered": False, "has_variants": False,
        "trigger": "Buying a permanent Legacy upgrade in the Estate shop.",
        "ideal_duration": [1.0, 5.0],
        "keywords": ["generic spell summon", "coins bag 2", "strong accept", "magic upgrade", "divine blessing"],
        "folder_affinities": ["Generic", "SFX/Misc", "Tech and Mech", "Revive"]
    },
    "welcome_back": {
        "bus": "Ceremony", "db": -4.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "The welcome-back pile after time away.",
        "ideal_duration": [2.0, 8.5],
        "keywords": ["coinpouring3", "heal 9", "coinbag3", "cash flood", "wealth return", "tally"],
        "folder_affinities": ["Coins", "Heal", "Bags"]
    },
    "prestige_confirm": {
        "bus": "Ceremony", "db": -2.0, "cooldown": 800, "layered": False, "has_variants": False,
        "trigger": "PASS THE TORCH confirmed, just before succession screens take over.",
        "ideal_duration": [1.5, 6.0],
        "keywords": ["boxing bell fight start", "stinger 15", "bell 1", "gong", "torch ignite", "grand transition"],
        "folder_affinities": ["Buzzers and Boards", "Buttons and Stingers", "SFX/Misc"]
    },

    # Music Tracks
    "band_0_blue_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Earth, Blue Collar (Tier 1) — department-store muzak, thin arrangement.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["intensity 1", "coffee time", "corporate", "jazz velvet lounge", "acoustic", "muzak"],
        "folder_affinities": ["Corporate Music Pack Vol. 1", "Jazz Music Pack"]
    },
    "band_1_white_collar": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Earth, White Collar (Tier 2) — the same tune, fuller mix. Promotion audible.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["main", "coffee time", "corporate", "cheerful whistle", "full mix", "strings", "promotion"],
        "folder_affinities": ["Corporate Music Pack Vol. 1", "Jazz Music Pack"]
    },
    "band_2_early_contact": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Early contact (Tiers 3–11) — melody survives, synths and theremin creep in.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "air flows", "space", "synth", "cosmic", "ambient", "electronic loop"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3", "Space Audio Bundle"]
    },
    "band_3_mid": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Mid alien contact (Tiers 12–19) — fewer Earth instruments left.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "mystics", "eastern", "exotic", "hypnotic", "alien drone"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3", "Eastern Music Pack"]
    },
    "band_4_deep": {
        "bus": "Music", "db": -6.0, "cooldown": 0, "layered": False, "has_variants": False,
        "trigger": "Deep cosmos (Tiers 20–27) — recognizable, but barely of this world.",
        "ideal_duration": [60.0, 180.0],
        "keywords": ["ethereal", "direct sunlight", "winds of time", "deep space", "synthetic", "celestial"],
        "folder_affinities": ["Ethereal Music Pack Vol. 3"]
    },
    "music_preview": {
        "bus": "Music", "db": -4.0, "cooldown": 200, "layered": False, "has_variants": False,
        "trigger": "Releasing the MUSIC slider in Settings.",
        "ideal_duration": [0.5, 3.0],
        "keywords": ["stinger 15", "stinger 8", "preview", "music chord", "short chord"],
        "folder_affinities": ["Buttons and Stingers", "Corporate Music Pack Vol. 1"]
    }
}

# Curated High-Confidence Picks from Plans/Audio_Asset_Selection.md & Audio README
CURATED_PICKS = {
    # Core Loop
    "tap_note": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Counter A.wav", "role": "primary", "note": "Adding-machine mechanical tally tick under 200ms (0.142s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Counter B.wav", "role": "variant_1", "note": "Alternating tick variant to mask pitch-shift (0.181s)"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav", "role": "candidate", "note": "Electronic blip alternate (0.099s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "candidate", "note": "Crisp tactile button click"}
    ],
    "buy_success": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 1.wav", "role": "primary", "note": "Quiet metallic cash base texture (0.565s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 2.wav", "role": "layer", "note": "Bright celebratory layer for big income moves (1.144s)"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Coin 4.wav", "role": "candidate", "note": "Clean coin clink alternate (0.500s)"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Coins 2.wav", "role": "candidate", "note": "Multiple coin rattle alternate (0.950s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinBag2.mp3", "role": "candidate", "note": "Heavy purse buy alternate"}
    ],
    "hire_first": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Create Engineer.wav", "role": "primary", "note": "First staffer acquisition — craftsman sound (0.774s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "candidate", "note": "Americana brass/guitar stinger alternate (1.659s)"}
    ],
    "hire_levelled": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Create Human Female.wav", "role": "primary", "note": "Lighter weight upgrade in same sample family (0.304s)"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Create Human Male.wav", "role": "variant_1", "note": "Companion staff level-up variant"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Create Robot 1.wav", "role": "candidate", "note": "Tech/engineer staff upgrade alternate (0.485s)"}
    ],
    "retain_staff": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "primary", "note": "Contract signature / paper delivery (0.534s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Select/Select Button 1.wav", "role": "candidate", "note": "Major executive agreement select"}
    ],
    "milestone": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav", "role": "primary", "note": "Triumph scoreboard milestone bell (0.408s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Misc/LevelUp1.mp3", "role": "candidate", "note": "Bigger level-up stinger for late bands (1.776s)"}
    ],
    "cycle_started": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Hammer 1.wav", "role": "primary", "note": "Mechanical physical crank/turnover starting machine cycle"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Open Lock 2.wav", "role": "candidate", "note": "Latch click alternate"}
    ],
    "frenzy_pop": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Fire/Fire 1.mp3", "role": "primary", "note": "Massive fiery ignition burst"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Siren Sound.wav", "role": "candidate", "note": "Overdrive siren alarm pop"}
    ],
    "frenzy_end": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 2.wav", "role": "primary", "note": "Smooth cooldown steam exhaust"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Vent Exhale.wav", "role": "candidate", "note": "Long pneumatic gas exhaust"}
    ],

    # Rush & Overdrive
    "overdrive_engage": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Computer On.wav", "role": "primary", "note": "Overdrive console power engagement (1.110s)"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Saw (loop).wav", "role": "candidate", "note": "Mechanical machine acceleration"}
    ],
    "vent_tick": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Pacer Beeps Normal.wav", "role": "primary", "note": "Interval timer pulse rhythm (to slice single tick) (4.424s)"},
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Button 2.wav", "role": "candidate", "note": "Crisp electronic telegraph pip (0.250s)"}
    ],
    "vent_open": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Buzzer.wav", "role": "primary", "note": "Clear urgent game horn — signal to start lifting (0.337s)"},
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav", "role": "candidate", "note": "Sci-fi klaxon alternate (0.400s)"}
    ],
    "vent_lift": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Elevator.wav", "role": "primary", "note": "Pneumatic elevator lift pulse (2.500s)"},
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (end) 4.mp3", "role": "candidate", "note": "Ascending energy lift alternate (2.210s)"}
    ],
    "vent_success": [
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Strong Accept.wav", "role": "primary", "note": "Clean machine confirm / success stinger (2.701s)"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Reward 2.wav", "role": "candidate", "note": "Bright melodic chime alternate (0.540s)"}
    ],
    "vent_miss": [
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Strong Deny.wav", "role": "primary", "note": "Matched opposite to Strong Accept (2.701s)"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Wrong 1.wav", "role": "candidate", "note": "Snappy refusal buzzer (0.529s)"}
    ],
    "overheat": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 1.wav", "role": "primary", "note": "Violent steam release / machine burnout (3.740s)"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Vent Exhale.wav", "role": "candidate", "note": "Long pneumatic gas exhaust (8.811s)"}
    ],
    "rush_ready": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Computer On.wav", "role": "primary", "note": "System boot / ready confirmation (1.110s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Scoreboard Ding.wav", "role": "candidate", "note": "Pitched-up chime ready chime (0.408s)"}
    ],
    "heat_loop": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/Update/Truck Gear Idle (loop).wav", "role": "primary", "note": "Loop-tagged industrial engine idle (2.055s)"},
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Electric/Electric (loop).mp3", "role": "candidate", "note": "Continuous electric hum loop (6.440s)"}
    ],
    "urgency_loop": [
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Saw (loop).wav", "role": "primary", "note": "Loop-tagged rising saw motor friction (2.440s)"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Pathetic Alarm.wav", "role": "candidate", "note": "Sci-fi warning pulsation loop (2.928s)"}
    ],

    # Interface
    "tab_switch": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 13.wav", "role": "primary", "note": "Crisp tactile tab slide (0.263s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Button 5.wav", "role": "candidate", "note": "Americana period tactile button (0.311s)"}
    ],
    "screen_open": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Open Drawer 2.wav", "role": "primary", "note": "Physical cabinet / drawer opening (0.691s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Select/Select Button 1.wav", "role": "candidate", "note": "Major panel selection (0.489s)"}
    ],
    "screen_close": [
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Close Drawer 3.wav", "role": "primary", "note": "Matched cabinet drawer closing pair (0.888s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "candidate", "note": "Snappy dismiss click (0.221s)"}
    ],
    "mode_toggle": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 6.wav", "role": "primary", "note": "Mechanical toggle switch click (0.221s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Click/Click Button 1.wav", "role": "candidate", "note": "Firm push button click (0.190s)"}
    ],
    "epoch_page": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "primary", "note": "Tactile card flick / page slide (0.534s)"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Slide/Slide Button 1.wav", "role": "candidate", "note": "Smooth panel slide"}
    ],
    "make_contact": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Teleportation.wav", "role": "primary", "note": "Massive cosmic portal activation (2.650s)"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Beam Me Up A.wav", "role": "candidate", "note": "Sci-fi transporter ascension (9.202s)"}
    ],
    "tip_appear": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav", "role": "primary", "note": "Light, friendly popup bubble"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 5.wav", "role": "candidate", "note": "Subtle UI chime"}
    ],

    # Basketball (Direct Semantic Matches from Foley Sports / Basketball)
    "bball_grab": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Court Squeak Generic A.wav", "role": "primary", "note": "Authentic gym floor shoe squeak / drag friction (0.220s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Court Squeak Sudden Stop.wav", "role": "variant_1", "note": "Sharp shoe squeak variation"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Court Squeak Normal.wav", "role": "candidate", "note": "Court grip friction"}
    ],
    "bball_launch": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Soccer/Throw in Normal.wav", "role": "primary", "note": "Clean, dynamic athletic release whoosh"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Soccer/Throw in Long.wav", "role": "variant_1", "note": "Powerful athletic launch throw"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Generic Swing Normal.wav", "role": "candidate", "note": "Crisp air swing"}
    ],
    "bball_fizzle": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Distant.wav", "role": "primary", "note": "Soft weak ball drop without throw"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Pool/Ball Sink Distant.wav", "role": "candidate", "note": "Dull dropped ball flop"}
    ],
    "bball_wall": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Wall Hit Normal.wav", "role": "primary", "note": "Authentic gym wall / backboard rebound (0.240s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Tennis/Wall Hit Intense.wav", "role": "variant_1", "note": "High-velocity backboard impact"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Hockey/Padding on Glass Normal Hit.wav", "role": "variant_2", "note": "Padded glass bounce variation"}
    ],
    "bball_floor": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Normal.wav", "role": "primary", "note": "Classic basketball hardwood dribble bounce (0.190s)"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Intense.wav", "role": "variant_1", "note": "Hard direct basketball floor bounce"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Bounce Distant.wav", "role": "variant_2", "note": "Light ball bounce variation"}
    ],
    "bball_settle": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Soccer/Pitch Movement Ball Rolling.wav", "role": "primary", "note": "Ball rolling to a gentle halt"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Pool/Ball Roll Down Bar.wav", "role": "candidate", "note": "Ball deceleration roll"}
    ],
    "bball_rim": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Net Hit Intense.wav", "role": "primary", "note": "Sharp iron rim impact / hoop collision"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Football - Rugby/Field Goal Kick Goalpost.wav", "role": "candidate", "note": "Resonant metal post clang"}
    ],
    "bball_score": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/In The Net A.wav", "role": "primary", "note": "Direct made basket net hit"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/In The Net B.wav", "role": "variant_1", "note": "Basket made variation"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Net Hit Normal.wav", "role": "candidate", "note": "Hoop net strike"}
    ],
    "bball_swish": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Net Swoosh Intense.wav", "role": "primary", "note": "Flawless crisp nylon SWISH basket"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Net Swoosh Normal.wav", "role": "variant_1", "note": "Clean net swoosh variation"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Basketball/Generic Net Swoosh.wav", "role": "candidate", "note": "Nylon net flutter"}
    ],
    "bball_gem_through": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Jewels & Runes/Gem1.mp3", "role": "primary", "note": "Crystal chime contact through legacy gem"},
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (end) 1.mp3", "role": "candidate", "note": "Shimmer pass-through tone"}
    ],
    "bball_gem_earned": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Grand Legacy shot celebration fanfare (6.08s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "candidate", "note": "Victory celebration stinger (1.65s)"}
    ],

    # Catch Money
    "catch_coin": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp2.mp3", "role": "primary", "note": "Light, crisp falling coin catch (0.336s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp1.mp3", "role": "variant_1", "note": "Coin catch variant (0.384s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "variant_2", "note": "Paper dollar catch variation (0.534s)"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Coin 4.wav", "role": "candidate", "note": "Metallic coin alternate (0.500s)"}
    ],
    "catch_premium": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 1.wav", "role": "primary", "note": "Heavy purse premium coin catch (0.565s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinBag2.mp3", "role": "candidate", "note": "Rich coin bag catch"},
        {"path": "buildingandcraftingaudiobundle/Building and Crafting Audio Bundle/WAV/FX/Coins 2.wav", "role": "candidate", "note": "Multiple gold coins clink"}
    ],
    "catch_legacy": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPouring3.mp3", "role": "primary", "note": "Massive jackpot offline cascade (8.28s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinBag3.mp3", "role": "candidate", "note": "Grand fortune coin bag"}
    ],
    "catch_miss": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPickUp3.mp3", "role": "primary", "note": "Dropped coin impact on floor"},
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Pool/Ball Sink Distant.wav", "role": "candidate", "note": "Dull lost coin drop"}
    ],
    "catch_spawn": [
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Bubble/Bubble Button 5.wav", "role": "primary", "note": "Inaudible soft pop indicating spawn rate"},
        {"path": "puzzleaudiokit/Puzzle Audio Bundle/WAV/FX/Misc/Button 6.wav", "role": "candidate", "note": "Micro blip"}
    ],

    # Ceremony
    "ceremony_obituary": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Bell 1.wav", "role": "primary", "note": "Warm, dignified period bell toll (6.842s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Bell 2.wav", "role": "variant_1", "note": "Solemn bell chime toll"},
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "candidate", "note": "Solemn transition stinger (6.080s)"}
    ],
    "ceremony_will": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Card Deliver 1.wav", "role": "primary", "note": "Opening legal parchment & will (0.534s)"},
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Books & Scrolls/BookOpen1.mp3", "role": "candidate", "note": "Heavy leather book opened"},
        {"path": "buttonssfxlibrary/Buttons SFX Library/WAV/Select/Select Button 1.wav", "role": "candidate", "note": "Official document selection"}
    ],
    "ceremony_heir": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Revive/Revive 3.mp3", "role": "primary", "note": "Continuation of the dynasty reveal (6.080s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "candidate", "note": "Americana acoustic celebration (1.659s)"}
    ],
    "ceremony_contact": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (summon) 1.mp3", "role": "primary", "note": "Cosmic alien encounter stinger (6.130s)"},
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Light Speed.wav", "role": "candidate", "note": "Hyperspace arrival (1.670s)"}
    ],
    "ceremony_contact_reveal": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Communication Recieving 2.wav", "role": "primary", "note": "Incoming extraterrestrial transmission decode"},
        {"path": "Sci-Fi Horror Sound FX Pack Vol. 2/Sci-Fi Horror/Tech and Mech/Incoming Transmission C.wav", "role": "candidate", "note": "Alien radio broadcast decode"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 8.wav", "role": "candidate", "note": "Dramatic reveal chord"}
    ],
    "ceremony_fanfare": [
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "primary", "note": "Grand triumphant Americana fanfare (1.659s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 8.wav", "role": "candidate", "note": "Major milestone triumph stinger"}
    ],
    "ceremony_power_down": [
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 1.wav", "role": "primary", "note": "System offline power-down sound"},
        {"path": "spaceaudiobundle/Space Audio Bundle/WAV/FX/Decompression 2.wav", "role": "candidate", "note": "Turbine deceleration"}
    ],
    "legacy_purchase": [
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Generic/Generic Spell (summon) 1.mp3", "role": "primary", "note": "Legacy permanent power unlocked (6.130s)"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/SFX/Misc/Coins Bag 2.wav", "role": "candidate", "note": "Layered gold treasure purchase (1.144s)"}
    ],
    "welcome_back": [
        {"path": "inventorysfxbundle_audio/inventorysfxbundle/Assets/Coins/CoinPouring3.mp3", "role": "primary", "note": "Massive pile of idle offline cash cascade (8.280s)"},
        {"path": "magicspellssfxbundle_audio/magicspellssfxbundle/Mono/Heal/Heal 9.mp3", "role": "candidate", "note": "Warm restoration chime (4.570s)"}
    ],
    "prestige_confirm": [
        {"path": "Foley Sports Sound FX Pack/Foley Sports/Buzzers and Boards/Boxing Bell Fight Start.wav", "role": "primary", "note": "Resonant bell starting the next generation"},
        {"path": "westernaudiobundle/Western Audio Bundle/WAV/Buttons and Stingers/Stinger 15.wav", "role": "candidate", "note": "Triumphant succession confirmation"}
    ],

    # Music Bands
    "band_0_blue_collar": [
        {"path": "Corporate Music Pack Vol. 1/Corporate Coffee Time (RT 4.000)/Intensity 1.wav", "role": "primary", "note": "Thin arrangement department-store acoustic muzak (100.0s)"},
        {"path": "Jazz Music Pack/Jazz Velvet Lounge (RT 3.000)/Intensity 1.wav", "role": "candidate", "note": "Mellow retro lounge jazz bed"}
    ],
    "band_1_white_collar": [
        {"path": "Corporate Music Pack Vol. 1/Corporate Coffee Time (RT 4.000)/Main.wav", "role": "primary", "note": "Same tune, full arrangement with strings — promotion audible (100.0s)"},
        {"path": "Corporate Music Pack Vol. 1/Corporate Cheerful Whistle (RT 4.000)/Main.wav", "role": "candidate", "note": "Upbeat executive success groove"}
    ],
    "band_2_early_contact": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Air Flows (RT 4.000)/Main.wav", "role": "primary", "note": "Melody survives with synths and ethereal ambient texture (92.0s)"},
        {"path": "Space Audio Bundle/Space Audio Bundle/WAV/Music/Space 1.wav", "role": "candidate", "note": "Cosmic exploration synth soundtrack"}
    ],
    "band_3_mid": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Mystics (RT 4.000)/Main.wav", "role": "primary", "note": "Hypnotic alien intervals and exotic synth textures (88.0s)"},
        {"path": "Eastern Music Pack/Eastern Mysterious Land (RT 4.000)/Main.wav", "role": "candidate", "note": "Exotic non-Western alien harmonics"}
    ],
    "band_4_deep": [
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Direct Sunlight (RT 4.000)/Main.wav", "role": "primary", "note": "Recognizable, but deep cosmic space music (96.0s)"},
        {"path": "Ethereal Music Pack Vol. 3/Ethereal Vol3 Winds of Time (RT 4.000)/Main.wav", "role": "candidate", "note": "Deep void synth ambience"}
    ]
}

# Irrelevant negative keywords for audio noise filtering
NEGATIVE_KEYWORDS = [
    "horse", "bear", "animal", "creature", "monster", "zombie", "growl", "roar", "scream",
    "shotgun", "rifle", "firearm", "bullet", "bandit", "sword", "knife", "bow", "arrow",
    "footstep", "step", "walking", "running", "skate", "golf hit", "cricket"
]


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
        return round(max(0.1, size / 24000.0), 3)
    elif ext == '.ogg':
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
            if '__MACOSX' in root:
                continue
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in ('.wav', '.mp3', '.ogg') and not f.startswith('._'):
                    full_path = os.path.join(root, f)
                    rel_to_audio_root = os.path.relpath(full_path, GAME_AUDIO_DIR)
                    
                    size_bytes = os.path.getsize(full_path)
                    duration = get_audio_duration(full_path)
                    
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
    Compute high-precision match strength score (0 - 100) between an audio file and a game cue.
    """
    file_rel_norm = audio_file["rel_path"].lower()
    file_name_lower = audio_file["filename"].lower()
    file_subfolder_lower = audio_file["subfolder"].lower()
    
    # 1. Curated Priority Match
    if cue_id in CURATED_PICKS:
        for pick in CURATED_PICKS[cue_id]:
            pick_path_norm = pick["path"].lower()
            pick_fn = os.path.basename(pick["path"]).lower()
            
            # Exact path match
            if pick_path_norm in file_rel_norm or file_rel_norm.endswith(pick_path_norm):
                base_score = 98 if pick["role"] == "primary" else (95 if pick["role"].startswith("variant") else (93 if pick["role"] == "layer" else 88))
                return base_score, f"Curated Top Pick: {pick.get('note', 'Research match')}"
            
            # Filename match within same pack
            if pick_fn == file_name_lower and pick["path"].split('/')[0].lower() in file_rel_norm:
                base_score = 94 if pick["role"] == "primary" else 88
                return base_score, f"Curated: {pick.get('note', 'Pack match')}"

    # 2. Negative Noise Filtering
    is_weapon_or_animal = any(neg in file_name_lower or neg in file_subfolder_lower for neg in NEGATIVE_KEYWORDS)
    if is_weapon_or_animal and "frenzy" not in cue_id and "avoid" not in cue_id and "combat" not in cue_id:
        return 0, "Noise filtered (unrelated sound family)"

    score = 0.0
    reasons = []
    file_tokens = set(audio_file["tokens"])
    
    # 3. Subfolder Affinity Bonus
    folder_affinities = cue_meta.get("folder_affinities", [])
    for aff in folder_affinities:
        aff_lower = aff.lower()
        if aff_lower in file_subfolder_lower or aff_lower in audio_file["pack"].lower():
            score += 35
            reasons.append(f"Subfolder: {aff}")
            break

    # 4. Cue Specific Heuristics & Keywords
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

    # Basketball specific boost for Foley Sports / Basketball
    if cue_id.startswith("bball_"):
        if "basketball" in file_subfolder_lower or "basketball" in file_rel_norm:
            score += 45
            reasons.append("Basketball sound library")
        elif "tennis" in file_subfolder_lower and any(w in file_name_lower for w in ["squeak", "wall hit"]):
            score += 35
            reasons.append("Gym court acoustics")

    # Match Three specific boost
    if cue_id.startswith("m3_"):
        if "jewels" in file_subfolder_lower or "puzzle" in file_rel_norm:
            score += 30
            reasons.append("Puzzle & Gem library")

    # Catch Money specific boost
    if cue_id.startswith("catch_"):
        if "coins" in file_subfolder_lower or "coin" in file_name_lower:
            score += 40
            reasons.append("Coin sound category")

    # Interface specific boost
    if cue_meta.get("bus") == "UI":
        if "buttons sfx library" in file_rel_norm:
            score += 25
            reasons.append("Tactile UI library")

    # 5. Duration Adherence
    ideal_dur = cue_meta.get("ideal_duration", [0.1, 2.0])
    dur = audio_file["duration"]
    if ideal_dur[0] <= dur <= ideal_dur[1]:
        score += 15
        reasons.append(f"Duration {dur:.2f}s")
    elif dur < ideal_dur[0] * 0.7:
        score -= 20
    elif dur > ideal_dur[1] * 2.0:
        score -= 35

    # 6. Loop cues
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
                "trigger": "Audio event", "ideal_duration": [0.1, 2.0], "keywords": [], "folder_affinities": []
            })
            
            # Find and rank candidates
            candidates = []
            for item in catalog:
                score, reason = score_candidate_match(cue_id, meta, item)
                if score >= 25:
                    role = "candidate"
                    # Check curated role
                    if cue_id in CURATED_PICKS:
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
                        "selected": role in ("primary", "layer", "variant_1") or score >= 95
                    })
            
            # Sort candidates by score descending, then duration proximity
            candidates.sort(key=lambda x: (x["score"], -abs(x["duration"] - meta.get("ideal_duration", [0.5, 1.0])[0])), reverse=True)
            
            # Record assigned file ids
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
                "candidates": candidates[:30]  # Cap top 30 candidates per cue
            })
        
        sections_output.append({
            "section_id": group["id"],
            "name": group["name"],
            "description": group["description"],
            "cues": cues_list
        })
    
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
        "library_sample": catalog
    }
    
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Generated {OUTPUT_JSON_PATH} successfully.")
    print(f"Sections: {len(sections_output)}, Total cues: {total_cues_count}, Library files: {len(catalog)}")


if __name__ == "__main__":
    build_audio_database()
