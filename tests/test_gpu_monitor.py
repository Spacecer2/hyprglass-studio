"""Tests for scripts/HyprglassGPUMonitor.sh and the /api/gpu endpoint."""
from __future__ import annotations

import json
import subprocess
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

MONITOR = PROJECT_ROOT / "scripts" / "HyprglassGPUMonitor.sh"


def find_free_port() -> int:
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
def server_url(tmp_path, monkeypatch):
    port = find_free_port()
    host = "127.0.0.1"

    monkeypatch.setattr(app_module, "CONFIG_PATH", tmp_path / "Hyprglass.conf")
    monkeypatch.setattr(app_module, "BACKUP_DIR", tmp_path / "backups")
    monkeypatch.setattr(app_module, "PREVIEW_DIR", tmp_path / "preview")

    server = ThreadingHTTPServer((host, port), app_module.Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://{host}:{port}"
    time.sleep(0.05)
    yield url
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)


def test_gpu_monitor_script_exists():
    assert MONITOR.exists(), "HyprglassGPUMonitor.sh should exist"
    assert MONITOR.is_file(), "HyprglassGPUMonitor.sh should be a file"


def test_gpu_monitor_status_runs_without_crash():
    result = subprocess.run(
        ["bash", str(MONITOR), "--status"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"status failed: {result.stderr}"
    assert "GPU tool:" in result.stdout
    assert "GPU usage:" in result.stdout


def test_gpu_monitor_status_reports_tool_and_usage():
    result = subprocess.run(
        ["bash", str(MONITOR), "--status"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
    lines = result.stdout.splitlines()
    data = {}
    for line in lines:
        if ":" in line:
            key, value = line.split(":", 1)
            data[key.strip()] = value.strip()
    assert "GPU tool" in data
    assert "GPU usage" in data
    assert data["GPU tool"] in {"nvidia", "intel", "amd", "none"}


def test_gpu_monitor_rejects_invalid_mode():
    result = subprocess.run(
        ["bash", str(MONITOR), "--invalid"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
    assert "Usage" in result.stderr


def test_server_gpu_endpoint_returns_status(server_url):
    response = urllib.request.urlopen(f"{server_url}/api/gpu", timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True
    assert "gpu_tool" in data
    assert "gpu_usage" in data
