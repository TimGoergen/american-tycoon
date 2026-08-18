#!/usr/bin/env python3
"""
Audio Review Server for American Tycoon.
Serves the interactive audio refinement application, streams licensed audio packs
from D:\\Downloads\\Game_Audio with HTTP Range header support, and manages selection export.
"""

import os
import sys
import json
import mimetypes
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8765
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(WORKSPACE_DIR, "tools")
GAME_AUDIO_DIR = r"D:\Downloads\Game_Audio"
PROJECT_AUDIO_DIR = os.path.join(WORKSPACE_DIR, "game", "audio")
HTML_FILE_PATH = os.path.join(TOOLS_DIR, "audio_review.html")
JSON_DATA_PATH = os.path.join(TOOLS_DIR, "audio_review_data.json")

mimetypes.add_type("audio/wav", ".wav")
mimetypes.add_type("audio/mpeg", ".mp3")
mimetypes.add_type("audio/ogg", ".ogg")


class AudioReviewHandler(BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Range")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_HEAD(self):
        # Handle HEAD requests identically to GET for headers
        self.do_GET()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        # 1. Root / UI
        if path in ("/", "/index.html", "/audio_review.html"):
            if not os.path.exists(HTML_FILE_PATH):
                self.send_error(404, "audio_review.html not found")
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
                # Regenerate if missing
                try:
                    import generate_audio_database
                    generate_audio_database.build_audio_database()
                except Exception as e:
                    self.send_error(500, f"Failed to generate data: {e}")
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

        # 3. Stream Licensed Library Audio (D:\Downloads\Game_Audio\...)
        elif path.startswith("/audio/library/"):
            rel_audio_path = urllib.parse.unquote(path[len("/audio/library/"):])
            file_path = os.path.join(GAME_AUDIO_DIR, rel_audio_path)
            self.serve_audio_file(file_path)
            return

        # 4. Stream In-Game Audio (game/audio/...)
        elif path.startswith("/audio/game/") or path.startswith("/game/audio/") or path.startswith("/game/") or path.startswith("/audio/cues/") or path.startswith("/audio/loops/") or path.startswith("/audio/music/"):
            raw_path = urllib.parse.unquote(path).lstrip("/")
            file_path = os.path.join(WORKSPACE_DIR, raw_path)
            if not (os.path.exists(file_path) and os.path.isfile(file_path)):
                for prefix in ["audio/game/audio/", "audio/game/", "game/audio/", "audio/"]:
                    if raw_path.startswith(prefix):
                        sub = raw_path[len(prefix):]
                        candidate = os.path.join(PROJECT_AUDIO_DIR, sub)
                        if os.path.exists(candidate) and os.path.isfile(candidate):
                            file_path = candidate
                            break

            self.serve_audio_file(file_path)
            return

        else:
            self.send_error(404, "Not Found")

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path == "/api/export":
            try:
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode("utf-8"))

                # Save export to Plans/Audio_Selection_Export.json
                plans_dir = os.path.join(WORKSPACE_DIR, "Plans")
                os.makedirs(plans_dir, exist_ok=True)
                export_path = os.path.join(plans_dir, "Audio_Selection_Export.json")
                with open(export_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)

                response_payload = {
                    "status": "success",
                    "saved_to": export_path,
                    "count": len(data.get("selections", {}))
                }
                res_bytes = json.dumps(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(res_bytes)))
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(res_bytes)
            except Exception as e:
                self.send_error(500, f"Export save failed: {e}")
            return
        else:
            self.send_error(404, "Not Found")

    def serve_audio_file(self, file_path):
        if not os.path.exists(file_path) or not os.path.isfile(file_path):
            self.send_error(404, f"Audio file not found: {file_path}")
            return

        file_size = os.path.getsize(file_path)
        content_type, _ = mimetypes.guess_type(file_path)
        if not content_type:
            content_type = "application/octet-stream"

        range_header = self.headers.get("Range")

        if range_header:
            # Parse Range: bytes=start-end
            try:
                range_match = range_header.strip().lower()
                if range_match.startswith("bytes="):
                    range_val = range_match[6:]
                    parts = range_val.split("-")
                    start = int(parts[0]) if parts[0] else 0
                    end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1

                    if start >= file_size or end >= file_size or start > end:
                        self.send_error(416, "Requested Range Not Satisfiable")
                        return

                    length = end - start + 1
                    with open(file_path, "rb") as f:
                        f.seek(start)
                        chunk = f.read(length)

                    self.send_response(206)
                    self.send_header("Content-Type", content_type)
                    self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                    self.send_header("Content-Length", str(length))
                    self.send_header("Accept-Ranges", "bytes")
                    self.send_cors_headers()
                    self.end_headers()
                    self.wfile.write(chunk)
                    return
            except Exception:
                pass

        # Full file delivery
        with open(file_path, "rb") as f:
            chunk = f.read()

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(file_size))
        self.send_header("Accept-Ranges", "bytes")
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(chunk)


def run_server():
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, AudioReviewHandler)
    print(f"==================================================")
    print(f" American Tycoon Audio Review Server")
    print(f" Running at: http://localhost:{PORT}")
    print(f" Audio Root: {GAME_AUDIO_DIR}")
    print(f" Press Ctrl+C to stop.")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")


if __name__ == "__main__":
    run_server()
