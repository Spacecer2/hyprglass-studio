import json
import sys
import threading
import time
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src import server as app_module  # noqa: E402


def find_free_port() -> int:
    """Return a free TCP port on localhost."""
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
def server_url(tmp_path, monkeypatch):
    """Start the Studio server on a random port and return its base URL."""
    port = find_free_port()
    host = "127.0.0.1"

    # Point the server at a temp config directory so tests don't touch ~/.config.
    monkeypatch.setattr(app_module, "CONFIG_PATH", tmp_path / "Hyprglass.conf")
    monkeypatch.setattr(app_module, "BACKUP_DIR", tmp_path / "backups")
    monkeypatch.setattr(app_module, "PREVIEW_DIR", tmp_path / "preview")

    # Avoid calling out to Hyprland/kitty during tests.
    monkeypatch.setattr(app_module, "reload_hyprland", lambda: None)
    monkeypatch.setattr(app_module, "launch_kitty_preview", lambda: None)

    server = ThreadingHTTPServer((host, port), app_module.Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://{host}:{port}"
    time.sleep(0.05)  # Give the server a moment to start listening.
    yield url
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)


def test_root_endpoint(server_url):
    response = urllib.request.urlopen(f"{server_url}/", timeout=5)
    assert response.status == 200
    body = response.read().decode("utf-8")
    assert "Hyprglass Studio" in body


def test_health_endpoint(server_url):
    response = urllib.request.urlopen(f"{server_url}/api/health", timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True


def test_config_endpoint_empty(server_url):
    response = urllib.request.urlopen(f"{server_url}/api/config", timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True
    assert data.get("config") == ""


def test_config_endpoint_returns_content(server_url, tmp_path, monkeypatch):
    config = tmp_path / "Hyprglass.conf"
    config.write_text("default_preset = default\n", encoding="utf-8")
    monkeypatch.setattr(app_module, "CONFIG_PATH", config)

    response = urllib.request.urlopen(f"{server_url}/api/config", timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True
    assert "default_preset" in data.get("config", "")
