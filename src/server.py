#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hmac
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse
from datetime import datetime
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
CONFIG_PATH = HOME / ".config/hypr/UserConfigs/Hyprglass.conf"
BACKUP_DIR = HOME / ".config/hypr/backups/hyprglass-studio"
PREVIEW_DIR = Path("/tmp/hyprglass-studio")
VALIDATOR = ROOT.parent / "scripts" / "ValidateHyprglassConf.sh"
MAX_CONTENT_LENGTH = 2 * 1024 * 1024  # 2 MiB

# Studio API authentication. Set STUDIO_TOKEN to require the same value in the
# X-HyprGlass-Token header for state-changing endpoints. This prevents other
# local users from modifying the Hyprland config via the localhost-only API.
STUDIO_TOKEN = os.environ.get("STUDIO_TOKEN", "").strip()

lock = threading.Lock()
active_preview: dict[str, object] | None = None


def json_response(
    handler: SimpleHTTPRequestHandler, payload: dict, status: HTTPStatus = HTTPStatus.OK
) -> None:
    data = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(data)


def read_json(handler: SimpleHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length", "0"))
    if length < 0 or length > MAX_CONTENT_LENGTH:
        raise ValueError("request body too large")
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


def validate_config(content: str) -> tuple[bool, list[str]]:
    """Validate config content using the bundled shell validator.

    Writes the content to a temporary file and invokes ValidateHyprglassConf.sh
    so that validation logic stays in one place. Returns (ok, errors).
    """
    if not VALIDATOR.exists():
        return False, ["validator script not found"]

    with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False) as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        result = subprocess.run(
            ["bash", str(VALIDATOR), str(tmp_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return True, []
        errors = [line.strip() for line in result.stderr.splitlines() if line.strip()]
        if not errors:
            errors = ["validation failed"]
        return False, errors
    finally:
        tmp_path.unlink(missing_ok=True)


def reload_hyprland() -> None:
    subprocess.run(
        ["hyprctl", "reload"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _check_token(handler: SimpleHTTPRequestHandler) -> bool:
    """Return True if the request is authenticated (or auth is disabled).

    The token may be supplied either as the X-HyprGlass-Token header or as the
    `token` query parameter (useful for WebSocket upgrades and simple links).
    """
    if not STUDIO_TOKEN:
        return True
    header = handler.headers.get("X-HyprGlass-Token", "")
    if hmac.compare_digest(header, STUDIO_TOKEN):
        return True
    parsed = urllib.parse.urlparse(handler.path)
    token = urllib.parse.parse_qs(parsed.query).get("token", [None])[0] or ""
    # Use constant-time comparison to avoid timing side-channels.
    return hmac.compare_digest(token, STUDIO_TOKEN)


def launch_kitty_preview() -> subprocess.Popen:
    config_path_quoted = shlex.quote(str(CONFIG_PATH))
    message = (
        "printf 'Hyprglass preview\\n\\nThis window is temporary. Close it to restore the previous config.\\n'; "
        "printf '\\nCurrent config:\\n'; "
        f"sed -n '1,120p' {config_path_quoted}; "
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
        valid, errors = validate_config(content)
        if not valid:
            raise ValueError(f"invalid config: {'; '.join(errors)}")
        backup = backup_current("apply")
        write_config(content)
        reload_hyprland()
    return {"ok": True, "message": "applied", "backup": str(backup)}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    @staticmethod
    def _request_path(request_path: str) -> str:
        """Return the path component of a request, ignoring any query string."""
        return urllib.parse.urlparse(request_path).path

    def _serve_index(self) -> None:
        """Serve index.html with the current token injected for the frontend."""
        index = ROOT / "index.html"
        content = index.read_text(encoding="utf-8")
        if STUDIO_TOKEN and "</head>" in content:
            meta = (
                '<meta name="hyprglass-token" '
                f'content="{html.escape(STUDIO_TOKEN)}">\n'
            )
            content = content.replace("</head>", meta + "</head>", 1)
        data = content.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        path = self._request_path(self.path)
        if path in {"/", "/index.html"}:
            if STUDIO_TOKEN:
                return self._serve_index()
            return super().do_GET()
        if path == "/api/health":
            return json_response(self, {"ok": True, "version": "1.1.0"})
        if path == "/api/config":
            try:
                if CONFIG_PATH.exists():
                    content = CONFIG_PATH.read_text(encoding="utf-8")
                    return json_response(self, {"ok": True, "config": content})
                return json_response(self, {"ok": True, "config": ""})
            except Exception as exc:
                return json_response(
                    self,
                    {"ok": False, "error": str(exc)},
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                )
        return super().do_GET()

    def do_POST(self):  # noqa: N802
        path = self._request_path(self.path)
        if path not in {"/api/preview", "/api/apply"}:
            return json_response(
                self, {"ok": False, "error": "not found"}, HTTPStatus.NOT_FOUND
            )
        if not _check_token(self):
            return json_response(
                self,
                {
                    "ok": False,
                    "error": "missing or invalid X-HyprGlass-Token header/token",
                },
                HTTPStatus.UNAUTHORIZED,
            )
        try:
            data = read_json(self)
            content = data.get("config", "")
            if not isinstance(content, str) or not content.strip():
                raise ValueError("missing config")
            result = (
                preview_flow(content)
                if path == "/api/preview"
                else apply_flow(content)
            )
            return json_response(self, result)
        except ValueError as exc:
            return json_response(
                self, {"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST
            )
        except Exception as exc:  # noqa: BLE001
            return json_response(
                self, {"ok": False, "error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR
            )

    def log_message(self, fmt, *args):  # noqa: A003
        return


def main() -> None:
    global STUDIO_TOKEN
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--host", type=str, default=os.environ.get("STUDIO_HOST", "127.0.0.1")
    )
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("STUDIO_PORT", "8765"))
    )
    parser.add_argument(
        "--token",
        type=str,
        default=os.environ.get("STUDIO_TOKEN", ""),
        help="Shared secret required by state-changing API endpoints. "
        "Falls back to the STUDIO_TOKEN environment variable.",
    )
    args = parser.parse_args()

    STUDIO_TOKEN = (args.token or "").strip()

    if args.host not in {"127.0.0.1", "localhost", "::1"}:
        print(
            f"WARNING: Studio server binding to non-loopback address {args.host}. "
            "Other machines may be able to reach this endpoint.",
            file=sys.stderr,
        )
    if not STUDIO_TOKEN:
        print(
            "WARNING: Studio server running without --token / STUDIO_TOKEN. "
            "State-changing endpoints are unprotected. "
            "Pass --token or set STUDIO_TOKEN to protect /api/preview and /api/apply.",
            file=sys.stderr,
        )

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(PREVIEW_DIR, 0o700)
    os.chdir(ROOT)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
