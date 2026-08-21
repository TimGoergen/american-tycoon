#!/usr/bin/env python3
"""
Developer Tuning Database Generator for American Tycoon.
Extracts all tuning knobs, sections, descriptions, display names, baked defaults,
and provenance records from:
  - game/scripts/resources/TuningConfig.gd
  - game/scripts/ui/DevTuningPanel.gd
  - game/config/tuning.tres
  - docs/Tuning_Record.md
and produces tools/dev_tuning_data.json.
"""

import os
import sys
import re
import json

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TUNING_CONFIG_PATH = os.path.join(WORKSPACE_DIR, "game", "scripts", "resources", "TuningConfig.gd")
DEV_PANEL_PATH = os.path.join(WORKSPACE_DIR, "game", "scripts", "ui", "DevTuningPanel.gd")
TUNING_TRES_PATH = os.path.join(WORKSPACE_DIR, "game", "config", "tuning.tres")
TUNING_RECORD_PATH = os.path.join(WORKSPACE_DIR, "docs", "Tuning_Record.md")
OUTPUT_JSON_PATH = os.path.join(WORKSPACE_DIR, "tools", "dev_tuning_data.json")

DEFAULT_SECTIONS = [
    {
        "id": "core_loop",
        "title": "Core Loop",
        "color": "#5E86B8",
        "prefixes": [
            "logic_hz", "m1_starting_cash", "band_step", "cycle_floor", "rush_pct",
            "hold_rush_per_second", "earth_economy_target", "autosave_cadence",
            "buy_hold_", "hire_hold_", "epoch_flagship_", "auto_purchase_",
            "offline_", "carb_"
        ],
        "description": "Base tick rate, economy targets, cycle speeds, hold-to-repeat timers, auto-purchase cadence, and carbonation bubble aesthetics."
    },
    {
        "id": "wage",
        "title": "Wage",
        "color": "#9FD8D4",
        "prefixes": ["wage_"],
        "description": "Active clock-in tap rates, executive pay floor fraction of passive income, and level-up bonuses."
    },
    {
        "id": "audio",
        "title": "Audio",
        "color": "#C77DFF",
        "prefixes": ["audio_"],
        "description": "Adaptive musical tap scales, rush harmony intervals, presence windows, volume dB scaling, and purchase feedback intensity."
    },
    {
        "id": "frenzy",
        "title": "Frenzy",
        "color": "#E3B23C",
        "prefixes": ["frenzy_"],
        "description": "TURBO multiplier ceiling, burn duration, charge fill per tap, idle decay rates, and activation floor threshold."
    },
    {
        "id": "rush_momentum",
        "title": "Rush Momentum",
        "color": "#B5402A",
        "prefixes": ["rush_momentum_"],
        "description": "Heat buildup/bleed rates, overdrive hard ceiling, safe cruise bonus, vent window timing, telegraph intervals, and haptic feedback."
    },
    {
        "id": "staff",
        "title": "Staff",
        "color": "#7DA87B",
        "prefixes": ["staff_", "retention_"],
        "description": "Alien staff recruitment scaling, cumulative ladder step bonuses, per-epoch levels, and Estate Office staff retention pricing."
    },
    {
        "id": "challenge_mode",
        "title": "Challenge Mode",
        "color": "#2B3F6C",
        "prefixes": [
            "challenge_", "basketball_tier_", "basketball_keepalive_",
            "memory_tier_", "memory_keepalive_", "match3_keepalive_",
            "timing_keepalive_", "catch_keepalive_", "balance_seconds_per_point",
            "balance_keepalive_", "balance_zone_"
        ],
        "description": "Challenge mode payout scaling, keep-alive timers, miss penalties, per-game tier cost escalation, and gold-zone tracking physics."
    },
    {
        "id": "minigames",
        "title": "Minigames",
        "color": "#508E89",
        "prefixes": [
            "minigame_", "match3_", "basketball_", "memory_", "balance_", "timing_", "catch_"
        ],
        "description": "Transition minigame timers, downside floor, neutral score thresholds, Match-3 scoring targets, and physics engines for all 6 minigames."
    },
    {
        "id": "legacy_bonus",
        "title": "Legacy Bonus",
        "color": "#F0D49A",
        "prefixes": ["legacy_bonus_", "legacy_gem_chance_"],
        "description": "Minigame bonus Legacy gem drop rates, lifetime-earned fraction rewards, and first-contact windfall multipliers."
    },
    {
        "id": "estate_legacy",
        "title": "Estate & Legacy",
        "color": "#A87C16",
        "prefixes": ["estate_", "loophole_", "k_legacy", "alpha_legacy", "legacy_knee_net", "legacy_cost_steepening", "legacy_upgrade_cost_multiplier", "alpha_legacy_deep"],
        "description": "Estate tax exemptions and baseline rates, Legacy mint power curve (k_legacy, alpha_legacy), deep piecewise knee, and shop cost steepening."
    },
    {
        "id": "events",
        "title": "Events",
        "color": "#8E2F1E",
        "prefixes": ["crash_", "audit_", "windfall_", "event_"],
        "description": "Market crash severity and duration, IRS audit settlement rates, windfall cash grants, and random event roll cadence."
    }
]

MINIGAME_SUBCATEGORIES = {
    "shared": {"id": "shared", "name": "Host & Transition Timing", "icon": "⏱️", "color": "#508E89"},
    "match3": {"id": "match3", "name": "Match Three", "icon": "💎", "color": "#9B5DE5"},
    "basketball": {"id": "basketball", "name": "Micro Basketball", "icon": "🏀", "color": "#E3B23C"},
    "balance": {"id": "balance", "name": "Balance the Books", "icon": "⚖️", "color": "#5E86B8"},
    "timing": {"id": "timing", "name": "Timing Bar", "icon": "🎯", "color": "#B5402A"},
    "catch": {"id": "catch", "name": "Catch the Money", "icon": "💰", "color": "#7DA87B"},
    "memory": {"id": "memory", "name": "Memory Match", "icon": "🧠", "color": "#9FD8D4"}
}

CATCH_ALL_TITLE = "Challenge Mode"


def parse_dev_panel_metadata(panel_text):
    """Extract DESCRIPTIONS and DISPLAY_NAMES from DevTuningPanel.gd."""
    descriptions = {}
    display_names = {}
    
    desc_match = re.search(r'const DESCRIPTIONS\s*:=\s*\{([^}]+)\}', panel_text, re.DOTALL)
    if desc_match:
        for line in desc_match.group(1).splitlines():
            m = re.search(r'^\s*"([^"]+)"\s*:\s*"([^"]+)"', line)
            if m:
                descriptions[m.group(1)] = m.group(2)
                
    disp_match = re.search(r'const DISPLAY_NAMES\s*:=\s*\{([^}]+)\}', panel_text, re.DOTALL)
    if disp_match:
        for line in disp_match.group(1).splitlines():
            m = re.search(r'^\s*"([^"]+)"\s*:\s*"([^"]+)"', line)
            if m:
                display_names[m.group(1)] = m.group(2)
                
    return descriptions, display_names


def parse_tuning_tres(tres_text):
    """Extract baked resource overrides from game/config/tuning.tres."""
    tres_values = {}
    for line in tres_text.splitlines():
        line = line.strip()
        if not line or line.startswith("[") or line.startswith(";"):
            continue
        if "=" in line:
            parts = line.split("=", 1)
            k = parts[0].strip()
            v_str = parts[1].strip()
            if k == "script":
                continue
            try:
                if "." in v_str or "e" in v_str.lower():
                    tres_values[k] = float(v_str)
                else:
                    tres_values[k] = int(v_str)
            except ValueError:
                tres_values[k] = v_str
    return tres_values


def parse_tuning_record(record_text):
    """Extract provenance and load-bearing notes from docs/Tuning_Record.md."""
    provenance_map = {
        "legacy_cost_steepening": {
            "kind": "Fitted",
            "deviation": True,
            "notes": "FITTED by DynastyArcStudy (1.10 vs Tim's seed 1.03). Critical brake on uncapped compounders."
        },
        "alpha_legacy_deep": {
            "kind": "Fitted",
            "deviation": True,
            "notes": "FITTED by DynastyArcStudy (0.05 vs Tim's seed 0.06). Keeps endgame frontier mints in billions."
        },
        "alpha_legacy": {
            "kind": "Device-tuned",
            "load_bearing": True,
            "notes": "Prestige retune (2026-07-23). Exponent on estate net worth for Legacy gem payout."
        },
        "k_legacy": {
            "kind": "Feel-tune",
            "load_bearing": True,
            "notes": "Prestige retune. Moves inversely with alpha_legacy to anchor first prestige at ~350 gems."
        },
        "legacy_knee_net": {
            "kind": "Feel-tune",
            "load_bearing": True,
            "notes": "Piecewise knee ($1e21) where mint curve switches to deep exponent."
        },
        "legacy_upgrade_cost_multiplier": {
            "kind": "Feel-tune",
            "load_bearing": True,
            "notes": "Prestige retune brake (3.0x on all Legacy upgrade costs)."
        },
        "frenzy_pop_floor": {
            "kind": "Solved",
            "notes": "SOLVED from frenzy_max_multiplier so that a new player's worst pop is exactly 2.0x."
        },
        "epoch_flagship_units_required": {
            "kind": "Device-tuned",
            "notes": "Device-tuned (35 in tuning.tres vs 1 fallback default). Requires owning flagship units before advance."
        }
    }
    return provenance_map


def parse_tuning_config():
    """Parse all exported variables from TuningConfig.gd with comments, docstrings, and inline tags."""
    if not os.path.exists(TUNING_CONFIG_PATH):
        raise FileNotFoundError(f"TuningConfig.gd not found at {TUNING_CONFIG_PATH}")
    with open(TUNING_CONFIG_PATH, "r", encoding="utf-8") as f:
        tc_text = f.read()

    panel_text = ""
    if os.path.exists(DEV_PANEL_PATH):
        with open(DEV_PANEL_PATH, "r", encoding="utf-8") as f:
            panel_text = f.read()

    tres_text = ""
    if os.path.exists(TUNING_TRES_PATH):
        with open(TUNING_TRES_PATH, "r", encoding="utf-8") as f:
            tres_text = f.read()

    record_text = ""
    if os.path.exists(TUNING_RECORD_PATH):
        with open(TUNING_RECORD_PATH, "r", encoding="utf-8") as f:
            record_text = f.read()

    descriptions, display_names = parse_dev_panel_metadata(panel_text)
    tres_baked = parse_tuning_tres(tres_text)
    record_provenance = parse_tuning_record(record_text)

    lines = tc_text.splitlines()
    knobs = []
    
    current_docstrings = []
    
    for i, line in enumerate(lines):
        doc_m = re.match(r'^\s*##\s?(.*)$', line)
        if doc_m:
            current_docstrings.append(doc_m.group(1))
            continue
            
        export_m = re.match(r'^\s*@export\s+var\s+(\w+):\s*(\w+)\s*=\s*([^#\n]+)(?:#\s*(.*))?$', line)
        if export_m:
            name = export_m.group(1)
            var_type = export_m.group(2)
            raw_val_str = export_m.group(3).strip().replace("_", "")
            inline_comment = (export_m.group(4) or "").strip()
            
            default_val = None
            try:
                if var_type == "int":
                    default_val = int(round(float(raw_val_str)))
                else:
                    default_val = float(raw_val_str)
            except ValueError:
                default_val = raw_val_str
                
            baked_val = default_val
            if name in tres_baked:
                baked_val = tres_baked[name]
                
            provenance_info = record_provenance.get(name, {})
            kind = provenance_info.get("kind", "")
            if not kind:
                if "device-tuned" in inline_comment.lower() or "device-tune" in inline_comment.lower():
                    kind = "Device-tuned"
                elif "feel-tune" in inline_comment.lower() or "feel-tuned" in inline_comment.lower():
                    kind = "Feel-tune"
                elif "tbd-sim" in inline_comment.lower():
                    kind = "TBD-SIM"
                elif "fit:" in inline_comment.lower() or "fitted" in inline_comment.lower():
                    kind = "Fitted"
                elif "solved" in inline_comment.lower():
                    kind = "Solved"
                else:
                    kind = "Authored"

            doc_text = " ".join(current_docstrings).strip()
            desc = descriptions.get(name, doc_text or inline_comment or "")
            disp_name = display_names.get(name, name.replace("_", " ").title())

            matched_section = CATCH_ALL_TITLE
            for sec in DEFAULT_SECTIONS:
                for prefix in sec["prefixes"]:
                    if name.startswith(prefix):
                        matched_section = sec["title"]
                        break
                if matched_section != CATCH_ALL_TITLE:
                    break

            step = 1 if var_type == "int" else 0.01
            if var_type == "float":
                if isinstance(baked_val, (int, float)):
                    if 0 < baked_val <= 0.01:
                        step = 0.001
                    elif baked_val >= 100:
                        step = 1.0
                    elif baked_val >= 10:
                        step = 0.1

            min_val = 0
            if isinstance(baked_val, (int, float)):
                if baked_val < 0:
                    min_val = baked_val * 2
                max_val = max(10.0, baked_val * 3.0) if baked_val > 0 else 100.0
            else:
                max_val = 100.0

            # Subcategory tagging (especially for Minigames)
            subcategory = None
            if matched_section == "Minigames":
                if name.startswith("match3_"):
                    subcategory = MINIGAME_SUBCATEGORIES["match3"]
                elif name.startswith("basketball_"):
                    subcategory = MINIGAME_SUBCATEGORIES["basketball"]
                elif name.startswith("balance_"):
                    subcategory = MINIGAME_SUBCATEGORIES["balance"]
                elif name.startswith("timing_"):
                    subcategory = MINIGAME_SUBCATEGORIES["timing"]
                elif name.startswith("catch_"):
                    subcategory = MINIGAME_SUBCATEGORIES["catch"]
                elif name.startswith("memory_"):
                    subcategory = MINIGAME_SUBCATEGORIES["memory"]
                else:
                    subcategory = MINIGAME_SUBCATEGORIES["shared"]

            # Mode identification (Base minigame vs Challenge mode)
            is_challenge = (
                matched_section == "Challenge Mode" or
                name.startswith("challenge_") or
                "_challenge_" in name or
                "_tier_" in name or
                "_keepalive_" in name or
                "_seconds_per_point" in name or
                "catch_premium_" in name or
                "timing_challenge_" in name or
                name == "match3_legacy_score_mult" or
                name == "balance_zone_reroll_seconds" or
                name == "balance_zone_ease"
            )

            knobs.append({
                "id": name,
                "name": disp_name,
                "type": var_type,
                "default_value": default_val,
                "baked_value": baked_val,
                "current_value": baked_val,
                "description": desc,
                "docstring": doc_text,
                "inline_comment": inline_comment,
                "section": matched_section,
                "subcategory": subcategory,
                "is_challenge_mode": is_challenge,
                "provenance": kind,
                "load_bearing": provenance_info.get("load_bearing", False),
                "is_deviation": provenance_info.get("deviation", False),
                "provenance_notes": provenance_info.get("notes", ""),
                "min": min_val,
                "max": max_val,
                "step": step
            })
            
            current_docstrings = []
        elif not line.strip().startswith("#"):
            current_docstrings = []

    return {
        "version": "1.0",
        "sections": DEFAULT_SECTIONS,
        "knobs": knobs
    }


def build_database():
    print("Building Developer Tuning database from Godot codebase...")
    data = parse_tuning_config()
    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"Successfully generated {OUTPUT_JSON_PATH}")
    print(f"Total knobs extracted: {len(data['knobs'])}")
    print(f"Total sections: {len(data['sections'])}")
    return data


if __name__ == "__main__":
    build_database()
