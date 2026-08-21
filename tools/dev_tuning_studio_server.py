#!/usr/bin/env python3
"""
Developer Tuning Studio Server for American Tycoon.
Serves the interactive Dev Tuning Studio web application,
handles real-time JSON read/write, Godot tuning.tres generation,
and on-device tuning_overrides.json export.
"""

import os
import sys
import json
import mimetypes
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8767
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(WORKSPACE_DIR, "tools")
HTML_FILE_PATH = os.path.join(TOOLS_DIR, "dev_tuning_studio.html")
JSON_DATA_PATH = os.path.join(TOOLS_DIR, "dev_tuning_data.json")
PLANS_DIR = os.path.join(WORKSPACE_DIR, "Plans")
TUNING_TRES_PATH = os.path.join(WORKSPACE_DIR, "game", "config", "tuning.tres")

mimetypes.add_type("image/svg+xml", ".svg")
mimetypes.add_type("image/png", ".png")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("text/css", ".css")


def generate_tres_content(data):
    """Generate a clean, valid Godot 4 Resource (.tres) for game/config/tuning.tres."""
    knobs = data.get("knobs", [])
    
    lines = []
    lines.append('[gd_resource type="Resource" script_class="TuningConfig" load_steps=2 format=3]')
    lines.append("")
    lines.append('[ext_resource type="Script" path="res://scripts/resources/TuningConfig.gd" id="1"]')
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1")')
    
    for k in knobs:
        kid = k.get("id")
        val = k.get("current_value", k.get("baked_value"))
        val_type = k.get("type", "float")
        
        if kid == "script" or kid is None:
            continue
            
        if val_type == "int":
            try:
                lines.append(f"{kid} = {int(round(float(val)))}")
            except (ValueError, TypeError):
                lines.append(f"{kid} = {val}")
        else:
            try:
                fval = float(val)
                # If cleanly formatted float or scientific notation
                if abs(fval) >= 1e12:
                    lines.append(f"{kid} = {fval}")
                elif fval.is_integer():
                    lines.append(f"{kid} = {fval:.1f}")
                else:
                    lines.append(f"{kid} = {fval}")
            except (ValueError, TypeError):
                lines.append(f"{kid} = {val}")
                
    lines.append("")
    return "\n".join(lines)


def generate_overrides_dict(data):
    """Generate dictionary of overrides where current_value != baked_value."""
    knobs = data.get("knobs", [])
    overrides = {}
    
    for k in knobs:
        kid = k.get("id")
        val = k.get("current_value")
        baked = k.get("baked_value")
        val_type = k.get("type", "float")
        
        if val is None or baked is None:
            continue
            
        is_diff = False
        if val_type == "int":
            try:
                c_int = int(round(float(val)))
                b_int = int(round(float(baked)))
                if c_int != b_int:
                    overrides[kid] = c_int
            except (ValueError, TypeError):
                pass
        else:
            try:
                c_flt = float(val)
                b_flt = float(baked)
                if abs(c_flt - b_flt) > 1e-9:
                    overrides[kid] = c_flt
            except (ValueError, TypeError):
                pass
                
    return overrides


class DevTuningHandler(BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Apply-To-Project")

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
        if path in ("/", "/index.html", "/dev_tuning_studio.html"):
            if not os.path.exists(HTML_FILE_PATH):
                self.send_error(404, "dev_tuning_studio.html not found")
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
                    import generate_dev_tuning_database
                    generate_dev_tuning_database.build_database()
                except Exception as e:
                    self.send_error(500, f"Failed to generate dev tuning database: {e}")
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

                # 1. Save to tools/dev_tuning_data.json
                with open(JSON_DATA_PATH, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)

                # 2. Save export snapshot to Plans/Dev_Tuning_Export.json
                os.makedirs(PLANS_DIR, exist_ok=True)
                export_path = os.path.join(PLANS_DIR, "Dev_Tuning_Export.json")
                with open(export_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)

                overrides = generate_overrides_dict(data)

                response_payload = {
                    "status": "success",
                    "saved_to": [JSON_DATA_PATH, export_path],
                    "knob_count": len(data.get("knobs", [])),
                    "override_count": len(overrides)
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

        elif path == "/api/export-tres":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))

                tres_content = generate_tres_content(data)
                
                apply_to_file = self.headers.get("X-Apply-To-Project", "false").lower() == "true"
                if apply_to_file:
                    with open(TUNING_TRES_PATH, "w", encoding="utf-8") as f:
                        f.write(tres_content)

                response_payload = {
                    "status": "success",
                    "code": tres_content,
                    "applied_to_project": apply_to_file,
                    "tres_path": TUNING_TRES_PATH
                }
                res_bytes = json.dumps(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(res_bytes)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(res_bytes)
            except Exception as e:
                self.send_error(500, f"TRES export failed: {e}")
            return

        elif path == "/api/export-overrides":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))

                overrides = generate_overrides_dict(data)

                response_payload = {
                    "status": "success",
                    "overrides": overrides,
                    "count": len(overrides)
                }
                res_bytes = json.dumps(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(res_bytes)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(res_bytes)
            except Exception as e:
                self.send_error(500, f"Overrides export failed: {e}")
            return

        else:
            self.send_error(404, "Not Found")


def run_server():
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, DevTuningHandler)
    print("==================================================")
    print(f" American Tycoon Developer Tuning Studio")
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
