import json
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src import server as app_module  # noqa: E402

TEST_TOKEN = "test-studio-token"


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
    # Enable token auth for state-changing endpoints.
    monkeypatch.setattr(app_module, "STUDIO_TOKEN", TEST_TOKEN)

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


def _api_request(url: str, data: bytes, token: str | None = TEST_TOKEN) -> urllib.request.Request:
    """Build a POST request with the optional auth token."""
    headers = {"Content-Type": "application/json"}
    if token is not None:
        headers["X-HyprGlass-Token"] = token
    return urllib.request.Request(
        url,
        data=data,
        headers=headers,
        method="POST",
    )


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


VALID_CONFIG = (
    Path(__file__).resolve().parent / "fixtures" / "valid.conf"
).read_text(encoding="utf-8")


class FakePreviewProcess:
    """Minimal stand-in for the kitty preview process."""

    pid = 12345

    def wait(self) -> None:
        pass


def test_apply_valid_config(server_url, tmp_path, monkeypatch):
    config_path = tmp_path / "Hyprglass.conf"
    monkeypatch.setattr(app_module, "CONFIG_PATH", config_path)

    request = _api_request(
        f"{server_url}/api/apply",
        data=json.dumps({"config": VALID_CONFIG}).encode("utf-8"),
    )
    response = urllib.request.urlopen(request, timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True
    assert data.get("message") == "applied"
    assert config_path.exists()


def test_apply_invalid_config(server_url):
    request = _api_request(
        f"{server_url}/api/apply",
        data=json.dumps({"config": "not a valid config"}).encode("utf-8"),
    )
    with pytest.raises(urllib.error.HTTPError) as exc_info:
        urllib.request.urlopen(request, timeout=5)
    assert exc_info.value.code == 400
    body = json.loads(exc_info.value.read().decode("utf-8"))
    assert body.get("ok") is False
    assert "invalid config" in body.get("error", "")


def test_apply_without_token_is_rejected(server_url):
    request = _api_request(
        f"{server_url}/api/apply",
        data=json.dumps({"config": VALID_CONFIG}).encode("utf-8"),
        token=None,
    )
    with pytest.raises(urllib.error.HTTPError) as exc_info:
        urllib.request.urlopen(request, timeout=5)
    assert exc_info.value.code == 401
    body = json.loads(exc_info.value.read().decode("utf-8"))
    assert body.get("ok") is False
    assert "X-HyprGlass-Token" in body.get("error", "")


def test_preview_endpoint(server_url, tmp_path, monkeypatch):
    config_path = tmp_path / "Hyprglass.conf"
    monkeypatch.setattr(app_module, "CONFIG_PATH", config_path)
    monkeypatch.setattr(app_module, "launch_kitty_preview", FakePreviewProcess)

    request = _api_request(
        f"{server_url}/api/preview",
        data=json.dumps({"config": VALID_CONFIG}).encode("utf-8"),
    )
    response = urllib.request.urlopen(request, timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True
    assert data.get("message") == "preview opened"
    assert data.get("pid") == 12345
