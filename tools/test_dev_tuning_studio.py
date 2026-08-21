#!/usr/bin/env python3
"""
Test Suite for Developer Tuning Studio.
Tests database generation, .tres serialization, override extraction,
and HTTP server API endpoints.
"""

import os
import sys
import json
import unittest
import threading
import urllib.request
import urllib.error
from http.server import HTTPServer

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(WORKSPACE_DIR, "tools"))

import generate_dev_tuning_database
import dev_tuning_studio_server


class TestDevTuningStudio(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Generate fresh database
        cls.db = generate_dev_tuning_database.build_database()
        
        # Start test HTTP server on port 8799
        cls.test_port = 8799
        dev_tuning_studio_server.PORT = cls.test_port
        cls.server = HTTPServer(("", cls.test_port), dev_tuning_studio_server.DevTuningHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever)
        cls.server_thread.daemon = True
        cls.server_thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def test_database_knobs_count(self):
        """Verify all tuning knobs (including 41 new minigame knobs) are extracted."""
        self.assertGreaterEqual(len(self.db["knobs"]), 180, "Should have at least 180 knobs extracted")
        self.assertEqual(len(self.db["sections"]), 11, "Should have 11 distinct sections")

    def test_minigame_subcategories(self):
        """Verify minigame knobs are correctly mapped to subcategories."""
        knobs = self.db["knobs"]
        subcats = set()
        for k in knobs:
            if k.get("subcategory"):
                subcats.add(k["subcategory"]["id"])
        
        expected_subcats = {"shared", "match3", "basketball", "balance", "timing", "catch", "memory"}
        self.assertTrue(expected_subcats.issubset(subcats), f"Missing subcategories: {expected_subcats - subcats}")

    def test_challenge_mode_distinction(self):
        """Verify that knobs are correctly tagged as Base game vs Challenge mode."""
        knobs_by_id = {k["id"]: k for k in self.db["knobs"]}
        
        # Base knobs should have is_challenge_mode = False
        self.assertFalse(knobs_by_id["match3_points_per_gem"]["is_challenge_mode"])
        self.assertFalse(knobs_by_id["basketball_gravity"]["is_challenge_mode"])
        self.assertFalse(knobs_by_id["balance_zone_half"]["is_challenge_mode"])
        self.assertFalse(knobs_by_id["timing_target_locks"]["is_challenge_mode"])
        self.assertFalse(knobs_by_id["catch_target_coins"]["is_challenge_mode"])
        self.assertFalse(knobs_by_id["memory_target_rounds"]["is_challenge_mode"])

        # Challenge knobs should have is_challenge_mode = True
        self.assertTrue(knobs_by_id["match3_legacy_score_mult"]["is_challenge_mode"])
        self.assertTrue(knobs_by_id["catch_challenge_spawn_interval"]["is_challenge_mode"])
        self.assertTrue(knobs_by_id["catch_premium_coin_chance"]["is_challenge_mode"])
        self.assertTrue(knobs_by_id["timing_challenge_speed_period"]["is_challenge_mode"])
        self.assertTrue(knobs_by_id["balance_zone_reroll_seconds"]["is_challenge_mode"])

    def test_key_knobs_presence(self):
        """Verify key balance, prestige, and hazard knobs are present with correct metadata."""
        knobs_by_id = {k["id"]: k for k in self.db["knobs"]}
        
        # Check Core Loop
        self.assertIn("logic_hz", knobs_by_id)
        self.assertIn("cycle_floor", knobs_by_id)
        self.assertIn("earth_economy_target", knobs_by_id)
        
        # Check Minigame Knobs
        self.assertIn("catch_target_coins", knobs_by_id)
        self.assertIn("basketball_gravity", knobs_by_id)
        self.assertIn("balance_zone_half", knobs_by_id)
        self.assertIn("timing_target_locks", knobs_by_id)
        self.assertIn("match3_points_per_gem", knobs_by_id)
        self.assertIn("memory_target_rounds", knobs_by_id)
        
        # Check Rush Momentum & Vent
        self.assertIn("rush_momentum_hard_ceiling", knobs_by_id)
        self.assertIn("rush_momentum_cruise_bonus", knobs_by_id)
        self.assertIn("rush_momentum_vent_approach_seconds", knobs_by_id)
        
        # Check Prestige & Deviations
        self.assertIn("legacy_cost_steepening", knobs_by_id)
        self.assertTrue(knobs_by_id["legacy_cost_steepening"]["is_deviation"])
        self.assertEqual(knobs_by_id["legacy_cost_steepening"]["baked_value"], 1.1)

        self.assertIn("alpha_legacy_deep", knobs_by_id)
        self.assertTrue(knobs_by_id["alpha_legacy_deep"]["is_deviation"])
        self.assertEqual(knobs_by_id["alpha_legacy_deep"]["baked_value"], 0.05)

    def test_generate_tres_content(self):
        """Verify Godot 4 Resource syntax generation."""
        tres_content = dev_tuning_studio_server.generate_tres_content(self.db)
        self.assertIn('[gd_resource type="Resource" script_class="TuningConfig"', tres_content)
        self.assertIn('[ext_resource type="Script" path="res://scripts/resources/TuningConfig.gd"', tres_content)
        self.assertIn('[resource]', tres_content)
        self.assertIn('logic_hz = 10', tres_content)
        self.assertIn('rush_momentum_hard_ceiling = 1.6', tres_content)

    def test_generate_overrides_dict(self):
        """Verify overrides extraction detects modified values."""
        modified_data = json.loads(json.dumps(self.db))
        # Modify two knobs
        for k in modified_data["knobs"]:
            if k["id"] == "logic_hz":
                k["current_value"] = 20
            elif k["id"] == "cycle_floor":
                k["current_value"] = 0.5
                
        overrides = dev_tuning_studio_server.generate_overrides_dict(modified_data)
        self.assertEqual(len(overrides), 2)
        self.assertEqual(overrides["logic_hz"], 20)
        self.assertEqual(overrides["cycle_floor"], 0.5)

    def test_api_get_data(self):
        """Verify GET /api/data endpoint."""
        url = f"http://localhost:{self.test_port}/api/data"
        req = urllib.request.urlopen(url)
        self.assertEqual(req.status, 200)
        payload = json.loads(req.read().decode("utf-8"))
        self.assertIn("knobs", payload)
        self.assertGreaterEqual(len(payload["knobs"]), 140)

    def test_api_post_export_tres(self):
        """Verify POST /api/export-tres endpoint."""
        url = f"http://localhost:{self.test_port}/api/export-tres"
        req = urllib.request.Request(
            url,
            data=json.dumps(self.db).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        resp = urllib.request.urlopen(req)
        self.assertEqual(resp.status, 200)
        payload = json.loads(resp.read().decode("utf-8"))
        self.assertEqual(payload["status"], "success")
        self.assertIn('[gd_resource type="Resource"', payload["code"])

    def test_api_post_export_overrides(self):
        """Verify POST /api/export-overrides endpoint."""
        url = f"http://localhost:{self.test_port}/api/export-overrides"
        modified_data = json.loads(json.dumps(self.db))
        for k in modified_data["knobs"]:
            if k["id"] == "rush_pct":
                k["current_value"] = 0.25
                
        req = urllib.request.Request(
            url,
            data=json.dumps(modified_data).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        resp = urllib.request.urlopen(req)
        self.assertEqual(resp.status, 200)
        payload = json.loads(resp.read().decode("utf-8"))
        self.assertEqual(payload["status"], "success")
        self.assertEqual(payload["overrides"]["rush_pct"], 0.25)


if __name__ == "__main__":
    unittest.main()
