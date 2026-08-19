#!/usr/bin/env python3
"""
Legacy Upgrade Database Generator for American Tycoon.
Extracts all upgrades, categories, tuning values, designer notes, and effect formulas
from game/scripts/core/LegacyUpgradeCatalog.gd into a rich structured JSON database.
"""

import os
import sys
import json

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG_GD_PATH = os.path.join(WORKSPACE_DIR, "game", "scripts", "core", "LegacyUpgradeCatalog.gd")
TUNING_TRES_PATH = os.path.join(WORKSPACE_DIR, "game", "config", "tuning.tres")
OUTPUT_JSON_PATH = os.path.join(WORKSPACE_DIR, "tools", "legacy_upgrades_data.json")

# Category definitions and design metadata
CATEGORIES = [
    {
        "id": "wealth",
        "name": "Wealth",
        "color": "#10b981", # Emerald
        "accent": "emerald",
        "icon": "banknote",
        "description": "Direct financial multipliers, starting capital endowments, and market crash hedging strategies.",
        "design_role": "Core cashflow scaling and defensive financial cushions."
    },
    {
        "id": "operations",
        "name": "Operations",
        "color": "#38bdf8", # Cyan / Sky
        "accent": "cyan",
        "icon": "cog",
        "description": "Cycle speed, staff recruitment discounts, automated purchasing, shift supervisors, and extended offline earnings.",
        "design_role": "Automation, cadence acceleration, and operational efficiency."
    },
    {
        "id": "career",
        "name": "Career",
        "color": "#fbbf24", # Amber
        "accent": "amber",
        "icon": "briefcase",
        "description": "Active tapping wage multipliers and executive career networking.",
        "design_role": "Active manual play income scaling."
    },
    {
        "id": "legacy",
        "name": "Legacy",
        "color": "#c084fc", # Purple
        "accent": "purple",
        "icon": "gem",
        "description": "Prestige yield scaling, succession paperwork optimizations, and inheritance minigame cap expansions.",
        "design_role": "Prestige loop acceleration and gem minting efficiency."
    },
    {
        "id": "labor",
        "name": "Labor",
        "color": "#818cf8", # Indigo
        "accent": "indigo",
        "icon": "hand",
        "description": "Auto-tapping and auto-rushing cadence enhancements for held interaction.",
        "design_role": "Quality of life and manual rush speed amplification."
    },
    {
        "id": "frenzy",
        "name": "Frenzy",
        "color": "#f97316", # Orange
        "accent": "orange",
        "icon": "flame",
        "description": "Market frenzy TURBO intensity, burn duration, cycle charge generation, decay resistance, and afterburn tails.",
        "design_role": "Burst multiplier phases and frenzy engine sustain."
    },
    {
        "id": "rush",
        "name": "Rush",
        "color": "#f43f5e", # Rose
        "accent": "rose",
        "icon": "gauge",
        "description": "Rush heat sink enhancements, safe cruise bonuses, and overheat lockout mitigation.",
        "design_role": "Risk-reward momentum pacing and overheat recovery."
    }
]

DEFAULT_UPGRADES = [
    {
        "id": "seed_capital",
        "name": "Trust Fund",
        "category": "Wealth",
        "description": "Every heir is born into more money.",
        "max_level": 20,
        "base_cost": 1.0,
        "cost_growth": 1.8,
        "effect_per_level": 2500.0,
        "effect_type": "additive_dollars",
        "effect_formula_desc": "+$2,500 starting cash per level",
        "getter_symbol": "starting_cash_bonus()",
        "compounding": False,
        "requires": "",
        "notes": "Additive starting cash endowment. Capped at 20 levels (+$50,000 max) to keep early generations exciting without blowing out early progression balance.",
        "custom_metadata": {
            "tier": "Early Game",
            "stat_target": "starting_cash",
            "ui_badge": "Cash"
        }
    },
    {
        "id": "family_fortune",
        "name": "Family Fortune",
        "category": "Wealth",
        "description": "The family name itself earns. All property income rises.",
        "max_level": 9999,
        "base_cost": 6.0,
        "cost_growth": 2.8,
        "effect_per_level": 0.20,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.20 property income per level (compounding)",
        "getter_symbol": "property_income_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Dynasty's main macro income accelerator. Compounding ×1.20 per level. Uncapped: the steepening cost curve (1.1^n) serves as the infinite economic brake.",
        "custom_metadata": {
            "tier": "Core Accelerator",
            "stat_target": "property_revenue",
            "ui_badge": "Income"
        }
    },
    {
        "id": "efficiency",
        "name": "Efficiency Experts",
        "category": "Operations",
        "description": "Sharper management. Every property cycles faster.",
        "max_level": 9999,
        "base_cost": 6.0,
        "cost_growth": 2.8,
        "effect_per_level": 0.12,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.12 cycle speed per level (compounding)",
        "getter_symbol": "cycle_speed_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding cycle speed multiplier (×1.12 per level). Scales property throughput across all owned holdings without cycle floor clamp.",
        "custom_metadata": {
            "tier": "Core Accelerator",
            "stat_target": "cycle_speed",
            "ui_badge": "Speed"
        }
    },
    {
        "id": "loyal_staff",
        "name": "Loyal Staff",
        "category": "Operations",
        "description": "Hardened family retainers work for less. Hiring costs drop.",
        "max_level": 16,
        "base_cost": 5.0,
        "cost_growth": 2.6,
        "effect_per_level": 0.04,
        "effect_type": "reduction_percent",
        "effect_formula_desc": "−4% staff hiring cost per level (capped at −64%, floored at 0.20×)",
        "getter_symbol": "staff_cost_multiplier()",
        "compounding": False,
        "requires": "",
        "notes": "Additive staff hiring discount. Capped at 16 levels (−64% cost) and code-floored at 20% cost so staff can never become completely free.",
        "custom_metadata": {
            "tier": "Mid Game",
            "stat_target": "staff_hire_cost",
            "ui_badge": "Discount"
        }
    },
    {
        "id": "connections",
        "name": "Old-Money Connections",
        "category": "Career",
        "description": "Doors open faster for old money. Your wage per tap rises.",
        "max_level": 9999,
        "base_cost": 4.0,
        "cost_growth": 2.7,
        "effect_per_level": 0.40,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.40 wage per tap per level (compounding)",
        "getter_symbol": "wage_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding wage per tap accelerator (×1.40/level). Keeps active clicking competitive and rewarding well into late-game runs.",
        "custom_metadata": {
            "tier": "Active Play",
            "stat_target": "tap_wage",
            "ui_badge": "Wage"
        }
    },
    {
        "id": "estate_lawyers",
        "name": "Estate Lawyers",
        "category": "Legacy",
        "description": "Clever paperwork. Each succession yields more Legacy.",
        "max_level": 12,
        "base_cost": 10.0,
        "cost_growth": 3.8,
        "effect_per_level": 0.075,
        "effect_type": "additive_percent",
        "effect_formula_desc": "+7.5% Legacy gained at succession per level (capped at +90%)",
        "getter_symbol": "legacy_yield_multiplier()",
        "compounding": False,
        "requires": "",
        "notes": "Additive prestige yield booster (+7.5%/level up to +90%). Has the steepest cost growth (3.8) to prevent runaway prestige feedback loops.",
        "custom_metadata": {
            "tier": "Prestige Booster",
            "stat_target": "legacy_gain",
            "ui_badge": "Gems"
        }
    },
    {
        "id": "minigame_bonus",
        "name": "Family Reputation",
        "category": "Legacy",
        "description": "A name worth showing off. A great inheritance minigame pays a bigger bonus.",
        "max_level": 20,
        "base_cost": 8.0,
        "cost_growth": 2.0,
        "effect_per_level": 0.025,
        "effect_type": "additive_percent",
        "effect_formula_desc": "+2.5% max inheritance bonus cap per level (25% base -> up to 75%)",
        "getter_symbol": "minigame_bonus_max()",
        "compounding": False,
        "requires": "",
        "notes": "Additive inheritance minigame cap expander (+2.5%/level over 25% base). Rewarding skillful prestige minigame performance.",
        "custom_metadata": {
            "tier": "Minigame",
            "stat_target": "minigame_cap",
            "ui_badge": "Skill"
        }
    },
    {
        "id": "auto_click_speed",
        "name": "Restless Hands",
        "category": "Labor",
        "description": "Hold to work faster. Auto-tapping and auto-rushing speed up.",
        "max_level": 9999,
        "base_cost": 5.0,
        "cost_growth": 2.7,
        "effect_per_level": 0.15,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.15 held auto-tap / auto-rush speed per level (compounding)",
        "getter_symbol": "auto_click_speed_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding rate increase (×1.15/level) for continuous held taps and held rush charging.",
        "custom_metadata": {
            "tier": "QoL / Active",
            "stat_target": "hold_speed",
            "ui_badge": "Speed"
        }
    },
    {
        "id": "rush_power",
        "name": "Strong-Arm Tactics",
        "category": "Operations",
        "description": "Lean on it. Each rush-tap drives a property's cycle further.",
        "max_level": 9999,
        "base_cost": 6.0,
        "cost_growth": 2.8,
        "effect_per_level": 0.20,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.20 rush advance per level (compounding)",
        "getter_symbol": "rush_power_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding rush efficiency (×1.20/level). Each manual rush tap shaves a larger slice of the remaining cycle duration.",
        "custom_metadata": {
            "tier": "Rush Mechanics",
            "stat_target": "rush_progress",
            "ui_badge": "Power"
        }
    },
    {
        "id": "frenzy_intensity",
        "name": "Killer Instinct",
        "category": "Frenzy",
        "description": "In a market frenzy you go for the throat. TURBO's multiplier climbs higher.",
        "max_level": 9999,
        "base_cost": 6.0,
        "cost_growth": 2.8,
        "effect_per_level": 0.15,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.15 TURBO bonus power per level (compounding)",
        "getter_symbol": "frenzy_intensity_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding boost to TURBO's multiplier bonus above 1× (×1.15/level). Turns market frenzies into explosive wealth events.",
        "custom_metadata": {
            "tier": "Frenzy",
            "stat_target": "turbo_multiplier",
            "ui_badge": "Burst"
        }
    },
    {
        "id": "frenzy_duration",
        "name": "Second Wind",
        "category": "Frenzy",
        "description": "The frenzy just won't quit. Every TURBO burn lasts longer.",
        "max_level": 9999,
        "base_cost": 6.0,
        "cost_growth": 2.8,
        "effect_per_level": 0.15,
        "effect_type": "compounding_multiplier",
        "effect_formula_desc": "×1.15 TURBO duration per level (compounding)",
        "getter_symbol": "frenzy_duration_multiplier()",
        "compounding": True,
        "requires": "",
        "notes": "Compounding duration extension (×1.15/level) by reducing frenzy burn-drain rate.",
        "custom_metadata": {
            "tier": "Frenzy",
            "stat_target": "turbo_duration",
            "ui_badge": "Duration"
        }
    },
    {
        "id": "cooling_systems",
        "name": "Cooling Systems",
        "category": "Rush",
        "description": "Better heat sinks. The safe cruise rush bonus climbs with every level.",
        "max_level": 10,
        "base_cost": 6.0,
        "cost_growth": 2.0,
        "effect_per_level": 0.005,
        "effect_type": "additive_percent",
        "effect_formula_desc": "+0.5% safe cruise rush bonus per level (up to +5%)",
        "getter_symbol": "cruise_bonus_points()",
        "compounding": False,
        "requires": "",
        "notes": "Additive bonus to cruise rush heat points (+0.5%/level, max +5% at level 10). Lifts cruise ceiling safely.",
        "custom_metadata": {
            "tier": "Rush Safety",
            "stat_target": "cruise_bonus",
            "ui_badge": "Heat"
        }
    },
    {
        "id": "rapid_restart",
        "name": "Rapid Restart",
        "category": "Rush",
        "description": "Seasoned cool-down crews. Overheat lockouts pass faster.",
        "max_level": 10,
        "base_cost": 6.0,
        "cost_growth": 2.0,
        "effect_per_level": 0.05,
        "effect_type": "reduction_percent",
        "effect_formula_desc": "−5% overheat lockout time per level (max −50% at level 10)",
        "getter_symbol": "overheat_lockout_scale()",
        "compounding": False,
        "requires": "",
        "notes": "Additive lockout reduction (−5%/level up to −50%). Halves punishment for redlining while preserving the risk factor.",
        "custom_metadata": {
            "tier": "Rush Safety",
            "stat_target": "lockout_time",
            "ui_badge": "Recovery"
        }
    },
    {
        "id": "auto_purchase_unlock",
        "name": "Acquisitions Desk",
        "category": "Operations",
        "description": "Buyers work your current era, taking its cheapest holdings first. Rushing is closed while the desk is open.",
        "max_level": 1,
        "base_cost": 1666.6666666667,
        "cost_growth": 1.0,
        "effect_per_level": 1.0,
        "effect_type": "unlock",
        "effect_formula_desc": "Unlocks Auto-Purchase mode (1 holding every 3.0s)",
        "getter_symbol": "auto_purchase_unlocked()",
        "compounding": False,
        "requires": "",
        "notes": "Master gateway unlock for automated property purchases (priced at exactly 5,000 gems with 3.0 cost multiplier). High prestige milestone.",
        "custom_metadata": {
            "tier": "Premium Automation",
            "stat_target": "auto_buy_unlocked",
            "ui_badge": "Unlock"
        }
    },
    {
        "id": "auto_purchase_quantity",
        "name": "Buying Power",
        "category": "Operations",
        "description": "More buyers on the floor. Each level buys one more holding every round.",
        "max_level": 30,
        "base_cost": 1666.6666666667,
        "cost_growth": 1.6,
        "effect_per_level": 1.0,
        "effect_type": "additive_count",
        "effect_formula_desc": "+1 purchase per round per level (total: Level + 1 holdings)",
        "getter_symbol": "auto_purchase_quantity()",
        "compounding": False,
        "requires": "auto_purchase_unlock",
        "notes": "Increases volume of holdings bought per auto-buy round. Requires Acquisitions Desk.",
        "custom_metadata": {
            "tier": "Automation Scaling",
            "stat_target": "auto_buy_count",
            "ui_badge": "Volume"
        }
    },
    {
        "id": "auto_purchase_cadence",
        "name": "Standing Orders",
        "category": "Operations",
        "description": "Faster paperwork. Each level shortens the wait between buying rounds.",
        "max_level": 11,
        "base_cost": 1666.6666666667,
        "cost_growth": 3.5,
        "effect_per_level": 0.25,
        "effect_type": "additive_seconds",
        "effect_formula_desc": "−0.25s interval between buying rounds per level (3.0s down to 0.25s floor)",
        "getter_symbol": "auto_purchase_cadence_scale()",
        "compounding": False,
        "requires": "auto_purchase_unlock",
        "notes": "Reduces interval between auto-purchase rounds in 0.25s steps down to 0.25s floor. Steep growth 3.5. Requires Acquisitions Desk.",
        "custom_metadata": {
            "tier": "Automation Scaling",
            "stat_target": "auto_buy_cadence",
            "ui_badge": "Cadence"
        }
    },
    {
        "id": "extended_offline",
        "name": "Night Shift",
        "category": "Operations",
        "description": "Operations run longer while you are away. Extends the offline earnings window.",
        "max_level": 5,
        "base_cost": 2666.6666666667,
        "cost_growth": 2.5,
        "effect_per_level": 14400.0,
        "effect_type": "additive_seconds",
        "effect_formula_desc": "+4 hours offline earnings cap per level (4h base -> up to 24h at level 5)",
        "getter_symbol": "offline_cap_seconds()",
        "compounding": False,
        "requires": "",
        "notes": "Extends idle offline progression window (+4h/level, 8,000 gem base price with multiplier). Max level 5 gives full 24h window.",
        "custom_metadata": {
            "tier": "Offline QoL",
            "stat_target": "offline_window",
            "ui_badge": "Offline"
        }
    },
    {
        "id": "auto_restart_cycles",
        "name": "Shift Supervisors",
        "category": "Operations",
        "description": "Supervisors keep machines running. Automatically restarts cycles on your top unstaffed properties.",
        "max_level": 12,
        "base_cost": 10.0,
        "cost_growth": 2.2,
        "effect_per_level": 1.0,
        "effect_type": "additive_count",
        "effect_formula_desc": "Auto-restarts top N unstaffed properties (1 property per level)",
        "getter_symbol": "auto_restart_count()",
        "compounding": False,
        "requires": "",
        "notes": "Automates manual properties from highest tier downwards. Bridges the gap before staff hiring.",
        "custom_metadata": {
            "tier": "Automation",
            "stat_target": "auto_restart_count",
            "ui_badge": "Auto"
        }
    },
    {
        "id": "auto_pop_turbo",
        "name": "Hair Trigger",
        "category": "Frenzy",
        "description": "The instant the market peaks, you strike. Automatically triggers TURBO when the frenzy meter is full.",
        "max_level": 1,
        "base_cost": 15.0,
        "cost_growth": 1.0,
        "effect_per_level": 1.0,
        "effect_type": "unlock",
        "effect_formula_desc": "Auto-triggers TURBO frenzy pop immediately upon reaching 100% meter",
        "getter_symbol": "auto_pop_turbo_unlocked()",
        "compounding": False,
        "requires": "",
        "notes": "Single-level QoL unlock. Eliminates manual button press timing for market frenzy bursts.",
        "custom_metadata": {
            "tier": "Frenzy Automation",
            "stat_target": "auto_turbo",
            "ui_badge": "Trigger"
        }
    },
    {
        "id": "frenzy_cycle_charge",
        "name": "Market Buzz",
        "category": "Frenzy",
        "description": "Market volume feeds excitement. Completed property cycles generate frenzy meter charge.",
        "max_level": 10,
        "base_cost": 8.0,
        "cost_growth": 2.2,
        "effect_per_level": 0.0005,
        "effect_type": "additive_percent",
        "effect_formula_desc": "+0.05% frenzy meter per completed property cycle per level (max +0.5%)",
        "getter_symbol": "frenzy_cycle_charge_per_completion()",
        "compounding": False,
        "requires": "",
        "notes": "Passive frenzy meter generation from ongoing property completions. Synergizes with high cycle speed properties.",
        "custom_metadata": {
            "tier": "Frenzy Synergy",
            "stat_target": "frenzy_passive_charge",
            "ui_badge": "Charge"
        }
    },
    {
        "id": "frenzy_decay_resist",
        "name": "Market Momentum",
        "category": "Frenzy",
        "description": "Hype holds its value. Extends grace before frenzy decays and reduces decay speed.",
        "max_level": 10,
        "base_cost": 6.0,
        "cost_growth": 2.0,
        "effect_per_level": 6.0,
        "effect_type": "special",
        "effect_formula_desc": "+6s idle grace & −8% meter decay speed per level",
        "getter_symbol": "frenzy_idle_grace_bonus() / frenzy_decay_rate_multiplier()",
        "compounding": False,
        "requires": "",
        "notes": "Dual-effect frenzy stabilizer: adds 6s grace before decay starts and cuts decay speed by 8% per level (down to 20% floor).",
        "custom_metadata": {
            "tier": "Frenzy Sustain",
            "stat_target": "decay_resistance",
            "ui_badge": "Grace"
        }
    },
    {
        "id": "frenzy_afterburn",
        "name": "Residual Momentum",
        "category": "Frenzy",
        "description": "The buzz lingers after the peak. Frenzy multiplier fades gradually over a tail instead of ending abruptly.",
        "max_level": 8,
        "base_cost": 10.0,
        "cost_growth": 2.4,
        "effect_per_level": 1.5,
        "effect_type": "additive_seconds",
        "effect_formula_desc": "+1.5s post-frenzy decay tail per level (up to +12.0s)",
        "getter_symbol": "frenzy_afterburn_duration()",
        "compounding": False,
        "requires": "",
        "notes": "Creates a smooth exponential decay tail when TURBO expires instead of an instant drop to 1×.",
        "custom_metadata": {
            "tier": "Frenzy Sustain",
            "stat_target": "afterburn_tail",
            "ui_badge": "Tail"
        }
    },
    {
        "id": "crisis_hedging",
        "name": "Hedging Strategies",
        "category": "Wealth",
        "description": "Smart short positions soften market shocks. Property income stays higher during a Market Crash.",
        "max_level": 8,
        "base_cost": 8.0,
        "cost_growth": 2.2,
        "effect_per_level": 0.05,
        "effect_type": "additive_percent",
        "effect_formula_desc": "+5% retained property income during crash per level (50% base -> up to 90%)",
        "getter_symbol": "crash_income_retention_bonus()",
        "compounding": False,
        "requires": "",
        "notes": "Mitigates market crash penalties from 50% loss down to only 10% loss at level 8.",
        "custom_metadata": {
            "tier": "Defensive Wealth",
            "stat_target": "crash_retention",
            "ui_badge": "Hedge"
        }
    },
    {
        "id": "crisis_liquidity",
        "name": "Emergency Liquidity",
        "category": "Operations",
        "description": "Credit facilities and cash reserves stabilize operations quickly. Market Crashes end sooner.",
        "max_level": 6,
        "base_cost": 10.0,
        "cost_growth": 2.4,
        "effect_per_level": 0.08,
        "effect_type": "reduction_percent",
        "effect_formula_desc": "−8% crash duration per level (up to −48% duration)",
        "getter_symbol": "crash_duration_reduction_pct()",
        "compounding": False,
        "requires": "",
        "notes": "Shortens the active duration of random Market Crash events by up to 48%.",
        "custom_metadata": {
            "tier": "Defensive Ops",
            "stat_target": "crash_duration",
            "ui_badge": "Liquidity"
        }
    }
]

GLOBAL_TUNING = {
    "legacy_upgrade_cost_multiplier": 3.0,
    "legacy_cost_steepening": 1.1,
    "k_legacy": 0.16,
    "alpha_legacy": 0.35,
    "legacy_knee_net": 1e21,
    "alpha_legacy_deep": 0.05,
    "minigame_keep_floor": 0.9,
    "minigame_full_performance": 0.5
}

def build_database():
    print(f"Building Legacy Upgrade Database...")
    db = {
        "version": "1.0.0",
        "metadata": {
            "title": "American Tycoon Legacy Upgrades",
            "source_file": "game/scripts/core/LegacyUpgradeCatalog.gd",
            "last_updated": "2026-08-18",
            "author": "Antigravity Studio"
        },
        "global_tuning": GLOBAL_TUNING,
        "categories": CATEGORIES,
        "upgrades": DEFAULT_UPGRADES
    }

    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)
    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)

    print(f"Successfully generated database with {len(DEFAULT_UPGRADES)} upgrades across {len(CATEGORIES)} categories at:")
    print(f" -> {OUTPUT_JSON_PATH}")
    return db

if __name__ == "__main__":
    build_database()
