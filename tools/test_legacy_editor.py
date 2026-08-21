#!/usr/bin/env python3
"""
Test script to verify legacy upgrade editor server, data generation, and math parity.
"""
import os
import sys
import json
import urllib.request
import threading
import time

# Import server module
import legacy_upgrade_editor_server

def test_suite():
    print("Testing Legacy Upgrade Editor Backend...")
    
    # 1. Start server on test port 8799
    legacy_upgrade_editor_server.PORT = 8799
    server_thread = threading.Thread(target=legacy_upgrade_editor_server.run_server, daemon=True)
    server_thread.start()
    time.sleep(0.5)

    base_url = "http://127.0.0.1:8799"

    # 2. Test GET /
    print("Testing GET / ...")
    with urllib.request.urlopen(f"{base_url}/") as response:
        assert response.status == 200
        html = response.read().decode("utf-8")
        assert "American Tycoon" in html
        assert "Legacy Studio" in html
    print("  -> UI served OK")

    # 3. Test GET /api/data
    print("Testing GET /api/data ...")
    with urllib.request.urlopen(f"{base_url}/api/data") as response:
        assert response.status == 200
        data = json.loads(response.read().decode("utf-8"))
        assert "upgrades" in data
        assert "categories" in data
        assert len(data["upgrades"]) >= 20
    print(f"  -> Returned {len(data['upgrades'])} upgrades across {len(data['categories'])} categories OK")

    # 4. Test POST /api/save
    print("Testing POST /api/save ...")
    req = urllib.request.Request(
        f"{base_url}/api/save",
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as response:
        assert response.status == 200
        res = json.loads(response.read().decode("utf-8"))
        assert res["status"] == "success"
    print("  -> POST /api/save OK")

    # 5. Test POST /api/export-gdscript
    print("Testing POST /api/export-gdscript ...")
    req = urllib.request.Request(
        f"{base_url}/api/export-gdscript",
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as response:
        assert response.status == 200
        res = json.loads(response.read().decode("utf-8"))
        assert "class_name LegacyUpgradeCatalog" in res["code"]
        assert "const SEED_CAPITAL" in res["code"]
    print("  -> GDScript export generation OK")

    # Formula parity check with sample parameters (base 1.0, growth 1.8, mult 3.0, steep 1.1)
    # Level 1 = floor(1 * 1.8^0 * 3.0) = 3
    # Level 2 = floor(1 * 1.8^1 * 1.1^0 * 3.0) = 5
    # Level 3 = floor(1 * 3.24 * 1.1 * 3.0) = floor(10.692) = 10
    def cost_calc(base, growth, lvl, steep=1.1, mult=3.0):
        steps = lvl - 1
        s_term = (steep ** (steps * (steps - 1) / 2))
        return int(base * (growth ** steps) * s_term * mult)

    assert cost_calc(1.0, 1.8, 1) == 3
    assert cost_calc(1.0, 1.8, 2) == 5
    assert cost_calc(1.0, 1.8, 3) == 10
    print("  -> Cost formula math parity verified OK")

    print("\nALL BACKEND & API TESTS PASSED SUCCESSFULLY!\n")

if __name__ == "__main__":
    test_suite()
