#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import threading
from datetime import datetime
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
CONFIG_PATH = HOME / ".config/hypr/UserConfigs/Hyprglass.conf"
BACKUP_DIR = HOME / ".config/hypr/backups/hyprglass-studio"
PREVIEW_DIR = Path("/tmp/hyprglass-studio")

lock = threading.Lock()
active_preview: dict[str, Path] | None = None


def json_response(handler: SimpleHTTPRequestHandler, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
    data = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(data)


def read_json(handler: SimpleHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length) if length else b"{}"
    return json.loads(raw.decode("utf-8"))


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def backup_current(prefix: str) -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = BACKUP_DIR / f"{prefix}-{stamp}.conf"
    if CONFIG_PATH.exists():
        shutil.copy2(CONFIG_PATH, backup)
    return backup


def _preserve_default_preset(new_content: str) -> str:
    if not CONFIG_PATH.exists():
        return new_content
    try:
        existing = CONFIG_PATH.read_text(encoding="utf-8")
    except Exception:
        return new_content
    match = re.search(r"^\s*default_preset\s*=\s*(.+)$", existing, re.MULTILINE)
    if match:
        preset_value = match.group(1).strip()
        new_content = re.sub(
            r"default_preset\s*=\s*\S+",
            f"default_preset = {preset_value}",
            new_content,
            count=1,
        )
    return new_content


def write_config(content: str) -> None:
    ensure_parent(CONFIG_PATH)
    CONFIG_PATH.write_text(_preserve_default_preset(content), encoding="utf-8")


def reload_hyprland() -> None:
    subprocess.run(["hyprctl", "reload"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def launch_kitty_preview() -> subprocess.Popen[str]:
    message = (
        "printf 'Hyprglass preview\\n\\nThis window is temporary. Close it to restore the previous config.\\n'; "
        "printf '\\nCurrent config:\\n'; "
        f"sed -n '1,120p' {CONFIG_PATH}; "
        "printf '\\n\\nPress any key to close...'; "
        "read -rn1"
    )
    return subprocess.Popen(
        [
            "kitty",
            "--class",
            "hyprglass-preview",
            "--title",
            "Hyprglass Preview",
            "sh",
            "-lc",
            message,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def preview_flow(content: str) -> dict:
    global active_preview
    with lock:
        if active_preview is not None:
            return {"ok": False, "error": "preview already active"}
        backup = backup_current("preview")
        write_config(content)
        reload_hyprland()
        try:
            proc = launch_kitty_preview()
        except Exception as exc:
            shutil.copy2(backup, CONFIG_PATH)
            reload_hyprland()
            return {"ok": False, "error": f"failed to launch preview: {exc}"}
        active_preview = {"backup": backup, "proc": proc.pid}

    def restore_when_closed() -> None:
        global active_preview
        try:
            proc.wait()
        finally:
            with lock:
                if backup.exists():
                    shutil.copy2(backup, CONFIG_PATH)
                    reload_hyprland()
                active_preview = None

    threading.Thread(target=restore_when_closed, daemon=True).start()
    return {"ok": True, "message": "preview opened", "pid": proc.pid}


def apply_flow(content: str) -> dict:
    with lock:
        if active_preview is not None:
            return {"ok": False, "error": "close the preview window before applying"}
        backup = backup_current("apply")
        write_config(content)
        reload_hyprland()
    return {"ok": True, "message": "applied", "backup": str(backup)}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):  # noqa: N802
        if self.path == "/api/health":
            return json_response(self, {"ok": True, "version": "1.1.0"})
        if self.path == "/api/config":
            try:
                if CONFIG_PATH.exists():
                    content = CONFIG_PATH.read_text(encoding="utf-8")
                    return json_response(self, {"ok": True, "config": content})
                return json_response(self, {"ok": True, "config": ""})
            except Exception as exc:
                return json_response(self, {"ok": False, "error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)
        return super().do_GET()

    def do_POST(self):  # noqa: N802
        if self.path not in {"/api/preview", "/api/apply"}:
            return json_response(self, {"ok": False, "error": "not found"}, HTTPStatus.NOT_FOUND)
        try:
            data = read_json(self)
            content = data.get("config", "")
            if not isinstance(content, str) or not content.strip():
                raise ValueError("missing config")
            result = preview_flow(content) if self.path == "/api/preview" else apply_flow(content)
            return json_response(self, result)
        except Exception as exc:  # noqa: BLE001
            return json_response(self, {"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)

    def log_message(self, fmt, *args):  # noqa: A003
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", type=str, default=os.environ.get("STUDIO_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("STUDIO_PORT", "8765")))
    args = parser.parse_args()
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(ROOT)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
