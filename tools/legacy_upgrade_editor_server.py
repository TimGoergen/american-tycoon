#!/usr/bin/env python3
"""
Legacy Upgrade Editor Server for American Tycoon.
Serves the interactive Legacy Upgrades Studio & Editor web application,
handles real-time JSON read/write, GDScript code generation, and export management.
"""

import os
import sys
import json
import mimetypes
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8766
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(WORKSPACE_DIR, "tools")
HTML_FILE_PATH = os.path.join(TOOLS_DIR, "legacy_upgrade_editor.html")
JSON_DATA_PATH = os.path.join(TOOLS_DIR, "legacy_upgrades_data.json")
PLANS_DIR = os.path.join(WORKSPACE_DIR, "Plans")
CATALOG_GD_PATH = os.path.join(WORKSPACE_DIR, "game", "scripts", "core", "LegacyUpgradeCatalog.gd")

mimetypes.add_type("image/svg+xml", ".svg")
mimetypes.add_type("image/png", ".png")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("text/css", ".css")


def generate_gdscript(data):
    """Generate clean, commented GDScript for LegacyUpgradeCatalog.gd from database JSON."""
    upgrades = data.get("upgrades", [])
    
    lines = []
    lines.append("class_name LegacyUpgradeCatalog")
    lines.append("")
    lines.append("# The fixed catalog of Legacy upgrades — the permanent, dynasty-wide perks the")
    lines.append("# player buys with Legacy after a succession (GDD §13 / the M2 prestige reward).")
    lines.append("#")
    lines.append("# Auto-generated and exported from the American Tycoon Legacy Upgrade Studio.")
    lines.append("")
    lines.append("")
    lines.append("# ── Stable id constants ───────────────────────────────────────────────────────")
    
    for up in upgrades:
        uid = up.get("id", "")
        const_name = uid.upper()
        lines.append(f'const {const_name:<24} := "{uid}"')
    
    lines.append("")
    lines.append("")
    lines.append("# ── The catalog ───────────────────────────────────────────────────────────────")
    lines.append("const UPGRADES := [")
    
    for up in upgrades:
        lines.append("\t{")
        lines.append(f'\t\t"id": {up["id"].upper()},')
        lines.append(f'\t\t"name": "{up.get("name", "")}",')
        lines.append(f'\t\t"category": "{up.get("category", "")}",')
        desc_escaped = up.get("description", "").replace('"', '\\"')
        lines.append(f'\t\t"description": "{desc_escaped}",')
        if up.get("requires"):
            lines.append(f'\t\t"requires": {up["requires"].upper()},')
        lines.append(f'\t\t"max_level": {int(up.get("max_level", 1))},')
        
        base_cost = up.get("base_cost", 1.0)
        if isinstance(base_cost, float) and not base_cost.is_integer():
            lines.append(f'\t\t"base_cost": {base_cost:.10g},')
        else:
            lines.append(f'\t\t"base_cost": {int(base_cost)},')
            
        cost_growth = up.get("cost_growth", 1.0)
        lines.append(f'\t\t"cost_growth": {cost_growth},')
        
        eff = up.get("effect_per_level", 1.0)
        if isinstance(eff, float) and not eff.is_integer():
            lines.append(f'\t\t"effect_per_level": {eff},')
        else:
            lines.append(f'\t\t"effect_per_level": {eff:.1f},')
            
        lines.append("\t},")
    
    lines.append("]")
    lines.append("")
    lines.append("")
    lines.append("## Return every upgrade definition, in catalog (display) order.")
    lines.append("static func all() -> Array:")
    lines.append("\treturn UPGRADES")
    lines.append("")
    lines.append("")
    lines.append("## Look up one upgrade definition by id, or an empty Dictionary if unknown.")
    lines.append("static func get_definition(id: String) -> Dictionary:")
    lines.append("\tfor upgrade in UPGRADES:")
    lines.append('\t\tif upgrade["id"] == id:')
    lines.append("\t\t\treturn upgrade")
    lines.append('\tpush_error("LegacyUpgradeCatalog: unknown upgrade id \'%s\'" % id)')
    lines.append("\treturn {}")
    lines.append("")
    lines.append("")
    lines.append("static var cost_multiplier := 1.0")
    lines.append("static var cost_steepening := 1.0")
    lines.append("")
    lines.append("")
    lines.append("## Legacy cost to buy a specific level of an upgrade (levels are 1-based).")
    lines.append("static func cost_for_level(id: String, level: int) -> int:")
    lines.append("\tvar definition := get_definition(id)")
    lines.append('\tif definition.is_empty() or level < 1 or level > int(definition["max_level"]):')
    lines.append("\t\treturn 0")
    lines.append('\tvar base_cost := float(definition["base_cost"])')
    lines.append('\tvar growth := float(definition["cost_growth"])')
    lines.append("\tvar steps := float(level - 1)")
    lines.append("\tvar steepen := pow(cost_steepening, steps * (steps - 1.0) / 2.0)")
    lines.append("\treturn int(floor(base_cost * pow(growth, steps) * steepen * cost_multiplier))")
    lines.append("")
    
    return "\n".join(lines)


class LegacyEditorHandler(BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        # 1. Main UI
        if path in ("/", "/index.html", "/legacy_upgrade_editor.html"):
            if not os.path.exists(HTML_FILE_PATH):
                self.send_error(404, "legacy_upgrade_editor.html not found")
                return
            with open(HTML_FILE_PATH, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(content)
            return

        # 2. API Data
        elif path == "/api/data":
            if not os.path.exists(JSON_DATA_PATH):
                try:
                    import generate_legacy_database
                    generate_legacy_database.build_database()
                except Exception as e:
                    self.send_error(500, f"Failed to generate legacy database: {e}")
                    return

            with open(JSON_DATA_PATH, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(content)
            return

        # 3. Static Art / Icon Assets
        elif path.startswith("/art/") or path.startswith("/game/art/"):
            rel_path = path.lstrip("/")
            if rel_path.startswith("art/"):
                file_path = os.path.join(WORKSPACE_DIR, "game", rel_path)
            else:
                file_path = os.path.join(WORKSPACE_DIR, rel_path)

            if os.path.exists(file_path) and os.path.isfile(file_path):
                content_type, _ = mimetypes.guess_type(file_path)
                with open(file_path, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", content_type or "application/octet-stream")
                self.send_header("Content-Length", str(len(content)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(content)
                return
            else:
                self.send_error(404, f"Asset not found: {path}")
                return

        else:
            self.send_error(404, "Not Found")

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/api/save":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))

                # 1. Save to tools/legacy_upgrades_data.json
                with open(JSON_DATA_PATH, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)

                # 2. Save export snapshot to Plans/Legacy_Upgrades_Export.json
                os.makedirs(PLANS_DIR, exist_ok=True)
                export_path = os.path.join(PLANS_DIR, "Legacy_Upgrades_Export.json")
                with open(export_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)

                response_payload = {
                    "status": "success",
                    "saved_to": [JSON_DATA_PATH, export_path],
                    "upgrade_count": len(data.get("upgrades", [])),
                    "category_count": len(data.get("categories", []))
                }
                res_bytes = json.dumps(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(res_bytes)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(res_bytes)
            except Exception as e:
                self.send_error(500, f"Save failed: {e}")
            return

        elif path == "/api/export-gdscript":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))

                gdscript_code = generate_gdscript(data)
                
                # If requested, write directly to game/scripts/core/LegacyUpgradeCatalog.gd
                apply_to_file = self.headers.get("X-Apply-To-Project", "false").lower() == "true"
                if apply_to_file:
                    with open(CATALOG_GD_PATH, "w", encoding="utf-8") as f:
                        f.write(gdscript_code)

                response_payload = {
                    "status": "success",
                    "code": gdscript_code,
                    "applied_to_project": apply_to_file
                }
                res_bytes = json.dumps(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(res_bytes)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(res_bytes)
            except Exception as e:
                self.send_error(500, f"GDScript generation failed: {e}")
            return

        else:
            self.send_error(404, "Not Found")


def run_server():
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, LegacyEditorHandler)
    print("==================================================")
    print(f" American Tycoon Legacy Upgrades Studio")
    print(f" Running at: http://localhost:{PORT}")
    print(f" Data File:  {JSON_DATA_PATH}")
    print(f" Press Ctrl+C to stop.")
    print("==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")


if __name__ == "__main__":
    run_server()
