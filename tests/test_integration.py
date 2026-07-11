"""End-to-end integration tests for Hyprglass Studio components."""
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

VALIDATOR = PROJECT_ROOT / "scripts" / "ValidateHyprglassConf.sh"
GUARD_SCRIPT = PROJECT_ROOT / "scripts" / "HyprglassGuard.sh"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
VALID_CONFIG = FIXTURES.joinpath("valid.conf").read_text(encoding="utf-8")


def find_free_port() -> int:
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
def server_url(tmp_path, monkeypatch):
    """Start the Studio server on a random port and return its base URL."""
    port = find_free_port()
    host = "127.0.0.1"

    monkeypatch.setattr(app_module, "CONFIG_PATH", tmp_path / "Hyprglass.conf")
    monkeypatch.setattr(app_module, "BACKUP_DIR", tmp_path / "backups")
    monkeypatch.setattr(app_module, "PREVIEW_DIR", tmp_path / "preview")
    monkeypatch.setattr(app_module, "reload_hyprland", lambda: None)
    monkeypatch.setattr(app_module, "launch_kitty_preview", lambda: None)

    server = ThreadingHTTPServer((host, port), app_module.Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://{host}:{port}"
    time.sleep(0.05)
    yield url
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)


def test_python_and_shell_validators_agree(tmp_path):
    """A config accepted by src.server.validate_config must also pass the shell validator."""
    conf = tmp_path / "Hyprglass.conf"
    conf.write_text(VALID_CONFIG, encoding="utf-8")

    py_valid, py_errors = app_module.validate_config(VALID_CONFIG)
    assert py_valid is True, f"Python validator rejected valid config: {py_errors}"

    result = subprocess.run(
        ["bash", str(VALIDATOR), str(conf)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Shell validator rejected config: {result.stderr}"


def test_server_apply_and_shell_validator_agree(server_url, tmp_path):
    """POST a valid config through the server, then validate the written file with the shell script."""
    monkeypatch = pytest.MonkeyPatch()
    monkeypatch.setattr(app_module, "CONFIG_PATH", tmp_path / "Hyprglass.conf")

    request = urllib.request.Request(
        f"{server_url}/api/apply",
        data=json.dumps({"config": VALID_CONFIG}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    response = urllib.request.urlopen(request, timeout=5)
    assert response.status == 200
    data = json.loads(response.read().decode("utf-8"))
    assert data.get("ok") is True

    conf = tmp_path / "Hyprglass.conf"
    assert conf.exists()

    result = subprocess.run(
        ["bash", str(VALIDATOR), str(conf)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Shell validator rejected server-written config: {result.stderr}"

    monkeypatch.undo()


def test_guard_restores_config_after_server_writes_invalid_state(tmp_path):
    """The server writes a valid config; we corrupt it; the guard restores it."""
    conf = tmp_path / "Hyprglass.conf"
    known_good_dir = tmp_path / "backups" / "hyprglass-known-good"
    known_good_dir.mkdir(parents=True)

    # Seed known-good backup.
    conf.write_text(VALID_CONFIG, encoding="utf-8")
    subprocess.run(["cp", "-a", str(conf), str(known_good_dir / "Hyprglass.conf")], check=True)

    # Corrupt the live config.
    conf.write_text("this is not valid", encoding="utf-8")

    script = f"""
set -euo pipefail
export XDG_CONFIG_HOME="{tmp_path}"
source "{GUARD_SCRIPT}"
NOTIFIER="/bin/true"
check_config
"""
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Guard check_config failed: {result.stderr}"
    assert "plugin:hyprglass" in conf.read_text(encoding="utf-8")


def test_installer_dry_run_completes():
    """The installer dry-run should reach the end without crashing."""
    result = subprocess.run(
        ["bash", str(PROJECT_ROOT / "install.sh"), "--dry-run", "--yes", "--skip-plugin", "--skip-wallust"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"install.sh --dry-run failed: {result.stderr}"
    assert "Dry run complete" in result.stdout or "Dry run complete" in result.stderr


def test_guard_blocks_on_missing_config(tmp_path):
    """If Hyprglass.conf is missing, the guard should attempt a restore."""
    known_good_dir = tmp_path / "backups" / "hyprglass-known-good"
    known_good_dir.mkdir(parents=True)
    (known_good_dir / "Hyprglass.conf").write_text(VALID_CONFIG, encoding="utf-8")

    script = f"""
set -euo pipefail
export XDG_CONFIG_HOME="{tmp_path}"
source "{GUARD_SCRIPT}"
NOTIFIER="/bin/true"
validate_conf || restore_conf
"""
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Guard restore failed: {result.stderr}"
    restored = (tmp_path / "Hyprglass.conf").read_text(encoding="utf-8")
    assert "plugin:hyprglass" in restored
