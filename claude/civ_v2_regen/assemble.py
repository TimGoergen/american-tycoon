# Civilizations v2 draft regeneration for the ESCALATING 52-property ladder (2026-07-16).
#
# The v2 draft (docs/civilizations_v2_draft.json, 2026-07-14) was built for the old flat
# 5-properties-per-alien-epoch pattern. The live game shipped the escalating ladder on
# 2026-07-15 (epoch cohorts 6,7,8,9,10 for tiers 2-6), so the draft is regenerated here:
#   - tiers 1-6 are synced to the LIVE 52 properties (.tres) and LIVE rosters (EpochCatalog);
#   - tiers 7-26 continue the escalation: cohort size = min(tier + 4, 14). The 14 cap comes
#     from the 2026-07-15 scaling analysis: per-rung ratio = 16807^(1/N), and below ~x2 per
#     rung a new property stops feeling like a new magnitude; N=14 keeps it at exactly ~x2.
#   - each tier-7+ cohort keeps its draft flagship cost anchor (10% of the previous epoch's
#     clear threshold) and re-spaces rungs: cost(k) = flagship * (16807^(1/N))^k, income =
#     cost * 0.01824, both rounded to 4 significant figures, cycles 60s (the live pattern,
#     verified against the shipped tiers 2-6 .tres values).
#
# Stages (each a subcommand):
#   master  - build master_properties.json: the full 326-property ladder in roster order
#             (Earth's 12, then each tier's cohort cheapest-first), with computed numbers.
#             Needs the stage1_T*.json naming files (20 parallel agents, one per new civ).
#   stage2  - write per-civ input files for the 26 roster-authoring agents: identity, the
#             civ's existing roster entries (voice reference), and the exact list of
#             property names it still needs to title.
#   final   - assemble docs/civilizations_v2_draft.json from all parts + validate.

import json
import math
import sys
from pathlib import Path

REGEN_DIR = Path(r"C:\Claude\American Tycoon\claude\civ_v2_regen")
SCRATCH = Path(r"C:\Users\chefq\AppData\Local\Temp\claude\C--Users-chefq"
               r"\26e4d961-d6d6-40f2-98ea-e60746bd0c0b\scratchpad")
DRAFT_PATH = Path(r"C:\Claude\American Tycoon\docs\civilizations_v2_draft.json")

INCOME_RATIO = 0.01824
EPOCH_SPAN = 16807.0        # 7^5 — one epoch's total cost span AND threshold step
COHORT_CAP = 14             # scaling analysis: keeps per-rung ratio at ~x2

def cohort_size(tier: int) -> int:
    if tier == 1:
        return 12           # Earth's fixed dozen
    return min(tier + 4, COHORT_CAP)

def round_4sf(x: float) -> float:
    if x == 0:
        return 0.0
    magnitude = math.floor(math.log10(abs(x)))
    return round(x, -(magnitude - 3))

def load(path: Path):
    # utf-8-sig: PowerShell's Out-File -Encoding utf8 writes a BOM.
    return json.loads(path.read_text(encoding="utf-8-sig"))

def build_master():
    live_props = load(SCRATCH / "live_properties.json")
    draft = load(DRAFT_PATH)
    civs = draft["civilizations"]

    master = []  # entries: {tier, rung, property, staffer_home, unit_cost, income, cycle, source}

    # Tiers 1-6: the live 52, grouped by tier, cheapest first (unlock_tier 0 in the .tres = Earth).
    for tier in range(1, 7):
        tres_tier = 0 if tier == 1 else tier
        cohort = sorted((p for p in live_props if p["tier"] == tres_tier),
                        key=lambda p: p["cost"])
        assert len(cohort) == cohort_size(tier), \
            f"tier {tier}: live cohort {len(cohort)} != expected {cohort_size(tier)}"
        for rung, p in enumerate(cohort):
            master.append({
                "tier": tier, "rung": rung, "property": p["name"],
                "staffer_home": p["staffer"], "unit_cost": p["cost"],
                "income_per_unit": p["income"], "cycle_seconds": p["cycle"],
                "source": "live",
            })

    # Tiers 7-26: draft's 5 (flagship, 3 siblings, capstone — ascending cost) + stage1 names
    # slotted between siblings and capstone, re-spaced onto the escalating grid.
    for tier in range(7, 27):
        civ = civs[tier - 1]
        old = sorted(civ["introduces_property_types"], key=lambda p: p["unit_cost"])
        assert len(old) == 5, f"tier {tier}: draft cohort {len(old)} != 5"
        stage1 = load(REGEN_DIR / f"stage1_T{tier:02d}.json")
        new_props = stage1["new_properties"]
        n = cohort_size(tier)
        assert len(new_props) == n - 5, \
            f"tier {tier}: stage1 has {len(new_props)} names, expected {n - 5}"

        # Identity order (the live convention): flagship, siblings, NEW, capstone.
        names = ([{"property": p["property"], "staffer": p["staffer_name"]} for p in old[:4]]
                 + [{"property": p["property"], "staffer": p["staffer"]} for p in new_props]
                 + [{"property": old[4]["property"], "staffer": old[4]["staffer_name"]}])

        flagship_cost = old[0]["unit_cost"]
        ratio = EPOCH_SPAN ** (1.0 / n)
        for rung, entry in enumerate(names):
            cost = round_4sf(flagship_cost * (ratio ** rung))
            master.append({
                "tier": tier, "rung": rung, "property": entry["property"],
                "staffer_home": entry["staffer"], "unit_cost": cost,
                "income_per_unit": round_4sf(cost * INCOME_RATIO), "cycle_seconds": 60.0,
                "source": "draft" if rung < 4 or rung == n - 1 else "stage1",
            })

    all_names = [e["property"] for e in master]
    dupes = {x for x in all_names if all_names.count(x) > 1}
    assert not dupes, f"duplicate property names across the ladder: {dupes}"
    expected_total = 12 + sum(cohort_size(t) for t in range(2, 27))
    assert len(master) == expected_total, f"{len(master)} != {expected_total}"

    out = REGEN_DIR / "master_properties.json"
    out.write_text(json.dumps(master, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"master: {len(master)} properties -> {out}")

def build_stage2_inputs():
    master = load(REGEN_DIR / "master_properties.json")
    draft = load(DRAFT_PATH)
    live_rosters = load(SCRATCH / "live_rosters.json")

    live_by_civ = {r["civilization"]: r["staffer_names"] for r in live_rosters}
    live_props = load(SCRATCH / "live_properties.json")  # PROPERTY_PATHS (id) order

    for tier, civ in enumerate(draft["civilizations"], start=1):
        name = civ["civilization"]
        known = {}  # property name -> this civ's staffer title
        if tier <= 6:
            # The SHIPPED roster is authoritative for the live 52 (EpochCatalog order = id order).
            for prop, staffer in zip(live_props, live_by_civ[name]):
                known[prop["name"]] = staffer
        # Draft roster entries (the old 137). For live civs these only add tiers 7-26 (their
        # live-52 titles above win); for new civs they are the whole existing roster.
        for entry in civ["staffer_roster_all_properties"]:
            known.setdefault(entry["property"], entry["staffer"])
        if tier >= 7:
            # Its own stage1 inventions title themselves.
            for p in load(REGEN_DIR / f"stage1_T{tier:02d}.json")["new_properties"]:
                known[p["property"]] = p["staffer"]

        needed = [{"tier": e["tier"], "property": e["property"]}
                  for e in master if e["property"] not in known]
        payload = {
            "tier": tier,
            "civilization": name,
            "hail": civ.get("hail", ""),
            "currency": civ.get("currency", ""),
            "home_planet": civ.get("home_planet", ""),
            "voice_reference_existing_roster": [
                {"property": p, "staffer" : s} for p, s in list(known.items())],
            "properties_needing_titles": needed,
        }
        out = REGEN_DIR / f"stage2_input_T{tier:02d}.json"
        out.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"stage2 input T{tier:02d} {name}: {len(needed)} titles needed, "
              f"{len(known)} known")

def _format_number(x) -> str:
    # Match the draft's number style: whole-valued floats print as full decimals with a
    # trailing .0 (never scientific notation, even at 1e116); fractional floats print their
    # shortest repr (0.01824, 78.45). Python's json module can't hook float formatting,
    # which is why this file writes JSON itself.
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, int):
        return str(x)
    if x == int(x):
        return f"{x:.1f}"
    return repr(x)

def _write_json(value, indent: int) -> str:
    pad = "  " * indent
    child_pad = "  " * (indent + 1)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float, bool)):
        return _format_number(value)
    if isinstance(value, list):
        if not value:
            return "[]"
        items = [child_pad + _write_json(v, indent + 1) for v in value]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = [child_pad + json.dumps(k, ensure_ascii=False) + ": " + _write_json(v, indent + 1)
                 for k, v in sorted(value.items())]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    raise TypeError(f"unhandled type {type(value)}")

def build_final():
    master = load(REGEN_DIR / "master_properties.json")
    draft = load(DRAFT_PATH)
    live_rosters = load(SCRATCH / "live_rosters.json")
    live_props = load(SCRATCH / "live_properties.json")
    live_by_civ = {r["civilization"]: r["staffer_names"] for r in live_rosters}

    master_names = [e["property"] for e in master]
    by_tier = {}
    for e in master:
        by_tier.setdefault(e["tier"], []).append(e)

    out_civs = []
    for tier, civ in enumerate(draft["civilizations"], start=1):
        name = civ["civilization"]

        # This civ's staffer title for every property, from the same precedence the stage2
        # inputs used (shipped EpochCatalog first for live civs, then draft, then stage1),
        # topped off with the stage2 agent's new titles.
        known = {}
        if tier <= 6:
            for prop, staffer in zip(live_props, live_by_civ[name]):
                known[prop["name"]] = staffer
        for entry in civ["staffer_roster_all_properties"]:
            known.setdefault(entry["property"], entry["staffer"])
        if tier >= 7:
            for p in load(REGEN_DIR / f"stage1_T{tier:02d}.json")["new_properties"]:
                known[p["property"]] = p["staffer"]
        stage2 = load(REGEN_DIR / f"stage2_T{tier:02d}.json")
        assert stage2["civilization"] == name, f"T{tier}: stage2 civ mismatch"
        for entry in stage2["new_roster_entries"]:
            assert entry["property"] in master_names, \
                f"T{tier}: stage2 invented unknown property {entry['property']!r}"
            assert entry["property"] not in known, \
                f"T{tier}: stage2 re-titled already-known {entry['property']!r}"
            known[entry["property"]] = entry["staffer"]
        missing = [n for n in master_names if n not in known]
        assert not missing, f"T{tier} {name}: roster missing {len(missing)}: {missing[:5]}"

        cohort = by_tier[tier]
        rebuilt = dict(civ.__dict__) if hasattr(civ, "__dict__") else dict(civ)
        rebuilt["introduces_property_types"] = [
            {
                "cycle_seconds": e["cycle_seconds"],
                "income_per_unit": e["income_per_unit"],
                "property": e["property"],
                "staffer_name": e["staffer_home"],
                "unit_cost": e["unit_cost"],
            }
            for e in cohort
        ]
        rebuilt["staffer_roster_all_properties"] = [
            {"property": n, "staffer": known[n]} for n in master_names]
        out_civs.append(rebuilt)

    doc = {
        "_about": ("American Tycoon civilization content, v2 DRAFT (regenerated 2026-07-16 "
                   "for the escalating 52-property live ladder): the original 6 civilizations "
                   "(tiers 1-6, synced verbatim to the live game) plus 20 NEW alien "
                   "civilizations (tiers 7-26) for review. American Tycoon is an idle/tycoon "
                   "game: you build a property empire in Earth dollars, and 'consume' each "
                   "epoch's economy to make First Contact with the next civilization (a "
                   "bigger market). The single currency stays dollars; each civ's currency "
                   "is FLAVOR only."),
        "civilizations": out_civs,
        "design_pattern": {
            "alien_income_to_cost_ratio": 0.01824,
            "alien_property_cycle_seconds": 60,
            "earth_economy_target_dollars": 103600000000000.0,
            "economy": ("A continuous cost/income ladder across all 326 properties. Earth "
                        "(tier 1) has 12 property types; alien epochs ESCALATE (Tim's "
                        "2026-07-15 unlock-cadence decision): tier T introduces min(T+4, 14) "
                        "property types - 6 at tier 2, one more each tier, capped at 14 from "
                        "tier 10 on (below ~x2 per rung a new property stops reading as a "
                        "new magnitude; 16807^(1/14) ~= x2.0)."),
            "economy_scale": ("Each epoch's clear threshold = earth_economy_target x "
                              "7^(5*(tier-1)) = x16807 per epoch. A new epoch's cheapest "
                              "property (the flagship) costs ~10% of the previous epoch's "
                              "threshold (a real save-up)."),
            "per_civilization": ("A distinct VOICE (the 'hail' = its own first words, "
                                 "in-character), a home planet, a flavor currency name, an "
                                 "accent color, a deadpan narrator 'contact_line', and a "
                                 "re-theming of EVERY property's staffer title into its "
                                 "theme."),
            "tone": ("Wry, satirical late-capitalism humor; alien civilizations are "
                     "money-obsessed in their own strange way (light beings, machines, "
                     "fungal hive-minds, crystals, time-eaters)."),
            "v2_notes": ("Regenerated 2026-07-16 for the escalating ladder. Tiers 1-6 "
                         "properties/rosters are the LIVE game's (52 properties, .tres + "
                         "EpochCatalog). Tiers 7-26 keep each draft flagship's cost anchor "
                         "and re-space the cohort onto the grid: cost(rung k) = flagship x "
                         "(16807^(1/N))^k, income = cost x 0.01824, both rounded to 4 "
                         "significant figures; all alien cycles 60s. Cohort identity order: "
                         "flagship, the 3 original siblings, the new upper-mid ventures, "
                         "then the original capstone as the top rung. Roster order is "
                         "Earth's 12 then each tier's cohort cheapest-first. Some civs use "
                         "non-Latin scripts in their hails (runes tier 10, Greek tier 16, "
                         "mirrored text tier 20, Cyrillic tier 23, math notation tier 25) - "
                         "file must stay UTF-8."),
        },
    }

    # ---- validation before writing ----
    ratio_errors = []
    for tier, cohort in by_tier.items():
        n = len(cohort)
        assert n == cohort_size(tier)
        costs = [e["unit_cost"] for e in cohort]
        assert costs == sorted(costs), f"tier {tier}: cohort not ascending"
        if tier >= 2:
            expected_ratio = EPOCH_SPAN ** (1.0 / n)
            for a, b in zip(costs, costs[1:]):
                if abs(b / a / expected_ratio - 1.0) > 0.002:  # 4sf rounding tolerance
                    ratio_errors.append((tier, a, b))
            for e in cohort:
                assert abs(e["income_per_unit"] / e["unit_cost"] / INCOME_RATIO - 1.0) < 0.002, \
                    f"tier {tier}: income ratio off at {e['property']}"
    assert not ratio_errors, f"rung ratio drift: {ratio_errors[:3]}"
    for civ in out_civs:
        roster_names = [e["property"] for e in civ["staffer_roster_all_properties"]]
        assert roster_names == master_names, f"{civ['civilization']}: roster order/coverage"
        own = {p["property"]: p["staffer_name"] for p in civ["introduces_property_types"]}
        for e in civ["staffer_roster_all_properties"]:
            if e["property"] in own:
                assert e["staffer"] == own[e["property"]], \
                    f"{civ['civilization']}: own-roster mismatch at {e['property']}"

    DRAFT_PATH.write_text(_write_json(doc, 0) + "\n", encoding="utf-8")
    reparsed = json.loads(DRAFT_PATH.read_text(encoding="utf-8"))
    assert len(reparsed["civilizations"]) == 26
    print(f"final: {len(master_names)} properties x 26 civilizations -> {DRAFT_PATH}")
    print("validation: cohort sizes, rung ratios, income ratio, roster coverage/order, "
          "own-staffer consistency, reparse - ALL PASS")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "master":
        build_master()
    elif cmd == "stage2":
        build_stage2_inputs()
    elif cmd == "final":
        build_final()
    else:
        print("usage: assemble.py master|stage2|final")
        sys.exit(1)
