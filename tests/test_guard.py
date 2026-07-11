"""Tests for scripts/HyprglassGuard.sh logic.

The guard is designed to run as a long-lived daemon, so these tests source the
script in isolated bash processes and exercise individual functions with mocked
paths.  To avoid executing the daemon loop, the helper strips the trailing
`main "$@"` call from the sourced script.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GUARD_SCRIPT = PROJECT_ROOT / "scripts" / "HyprglassGuard.sh"
VALIDATOR = PROJECT_ROOT / "scripts" / "ValidateHyprglassConf.sh"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _source_with_main_removed(tmp_path: Path) -> Path:
    """Return a temp copy of the guard script with the main call removed."""
    content = GUARD_SCRIPT.read_text(encoding="utf-8")
    # Comment out the final "main \"$@\"" line so sourcing only loads functions.
    content = content.replace('main "$@"', '# main "$@"')
    dest = tmp_path / "HyprglassGuard_sourced.sh"
    dest.write_text(content, encoding="utf-8")
    return dest


def run_guard_function(tmp_path: Path, setup: str, func_call: str) -> subprocess.CompletedProcess:
    """Source HyprglassGuard.sh (without running main), run setup, then call a function.

    Paths are overridden so the guard never touches the user's real ~/.config.
    """
    sourced = _source_with_main_removed(tmp_path)
    script = f"""
set -euo pipefail

# Override guard paths before sourcing.
export XDG_CONFIG_HOME="{tmp_path}"

# Source the guard script but do not run main().
source "{sourced}"

# Disable real notifications.
NOTIFIER="/bin/true"

{setup}

{func_call}
"""
    return subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_guard_script_exists():
    assert GUARD_SCRIPT.exists(), "HyprglassGuard.sh should exist"
    assert GUARD_SCRIPT.is_file(), "HyprglassGuard.sh should be a file"


def test_validate_conf_succeeds(tmp_path):
    conf = tmp_path / "hypr" / "UserConfigs" / "Hyprglass.conf"
    conf.parent.mkdir(parents=True)
    conf.write_text(FIXTURES.joinpath("valid.conf").read_text(encoding="utf-8"), encoding="utf-8")
    result = run_guard_function(tmp_path, "", "validate_conf")
    assert result.returncode == 0, f"validate_conf should succeed: {result.stderr}"


def test_validate_conf_fails_for_missing_file(tmp_path):
    result = run_guard_function(tmp_path, "", "validate_conf")
    assert result.returncode == 1


def test_validate_conf_passes_when_validator_missing(tmp_path):
    """If the validator is missing the guard should not trigger a restore."""
    conf = tmp_path / "hypr" / "UserConfigs" / "Hyprglass.conf"
    conf.parent.mkdir(parents=True)
    conf.write_text("invalid", encoding="utf-8")
    sourced = _source_with_main_removed(tmp_path)
    script = f"""
set -euo pipefail
export XDG_CONFIG_HOME="{tmp_path}"
source "{sourced}"
VALIDATOR="/nonexistent/ValidateHyprglassConf.sh"
validate_conf
"""
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"should pass when validator missing: {result.stderr}"


def test_find_known_good_returns_backup(tmp_path):
    backup_dir = tmp_path / "hypr" / "backups" / "hyprglass-known-good"
    backup_dir.mkdir(parents=True)
    backup = backup_dir / "Hyprglass.conf.backup"
    backup.write_text("backup", encoding="utf-8")

    result = run_guard_function(tmp_path, "", "find_known_good")
    assert result.returncode == 0
    assert "Hyprglass.conf" in result.stdout


def test_find_known_good_fails_when_no_backup(tmp_path):
    result = run_guard_function(tmp_path, "", "find_known_good")
    assert result.returncode == 1


def test_restore_conf_from_known_good(tmp_path):
    conf = tmp_path / "hypr" / "UserConfigs" / "Hyprglass.conf"
    conf.parent.mkdir(parents=True)
    conf.write_text("corrupt", encoding="utf-8")

    backup_dir = tmp_path / "hypr" / "backups" / "hyprglass-known-good"
    backup_dir.mkdir(parents=True)
    backup = backup_dir / "Hyprglass.conf.good"
    good_content = FIXTURES.joinpath("valid.conf").read_text(encoding="utf-8")
    backup.write_text(good_content, encoding="utf-8")

    result = run_guard_function(tmp_path, "", "restore_conf")
    assert result.returncode == 0, f"restore_conf failed: {result.stderr}"
    restored = conf.read_text(encoding="utf-8")
    assert "plugin:hyprglass" in restored


def test_check_config_restores_corrupt_config(tmp_path):
    conf = tmp_path / "hypr" / "UserConfigs" / "Hyprglass.conf"
    conf.parent.mkdir(parents=True)
    conf.write_text("not a valid config", encoding="utf-8")

    backup_dir = tmp_path / "hypr" / "backups" / "hyprglass-known-good"
    backup_dir.mkdir(parents=True)
    backup = backup_dir / "Hyprglass.conf.good"
    backup.write_text(
        FIXTURES.joinpath("valid.conf").read_text(encoding="utf-8"),
        encoding="utf-8",
    )

    result = run_guard_function(tmp_path, "", "check_config")
    assert result.returncode == 0, f"check_config failed: {result.stderr}"
    assert "plugin:hyprglass" in conf.read_text(encoding="utf-8")


def test_check_config_leaves_valid_config_intact(tmp_path):
    conf = tmp_path / "hypr" / "UserConfigs" / "Hyprglass.conf"
    conf.parent.mkdir(parents=True)
    original = FIXTURES.joinpath("valid.conf").read_text(encoding="utf-8")
    conf.write_text(original, encoding="utf-8")

    result = run_guard_function(tmp_path, "", "check_config")
    assert result.returncode == 0
    assert conf.read_text(encoding="utf-8") == original


def test_notify_runs_notifier_when_available(tmp_path):
    notifier = tmp_path / "notifier.sh"
    notifier.write_text("#!/bin/sh\necho notified $@\n", encoding="utf-8")
    notifier.chmod(0o755)
    sourced = _source_with_main_removed(tmp_path)

    script = f"""
set -euo pipefail
export XDG_CONFIG_HOME="{tmp_path}"
source "{sourced}"
NOTIFIER="{notifier}"
notify test-event "test message"
"""
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"notify failed: {result.stderr}"
    assert "notified" in result.stdout


def test_notify_is_silent_when_notifier_missing(tmp_path):
    result = run_guard_function(
        tmp_path,
        "NOTIFIER='/nonexistent/HyprglassNotify.sh'",
        "notify test-event 'test message'",
    )
    assert result.returncode == 0, f"notify should be silent: {result.stderr}"


def test_check_gpu_throttle_does_not_fail(tmp_path):
    """GPU throttle logic is best-effort; ensure it does not crash."""
    result = run_guard_function(tmp_path, "", "check_gpu_throttle")
    assert result.returncode == 0, f"check_gpu_throttle failed: {result.stderr}"
