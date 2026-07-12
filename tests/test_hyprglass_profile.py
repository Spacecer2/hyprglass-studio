"""Tests for scripts/HyprglassProfile.sh profile import/export and errors."""

from __future__ import annotations

import subprocess
import tarfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROFILE_SCRIPT = PROJECT_ROOT / "scripts" / "HyprglassProfile.sh"
DEFAULT_PROFILE = PROJECT_ROOT / "profiles" / "default.conf"


def _run_bash_function(
    tmp_path: Path, setup: str, func_call: str
) -> subprocess.CompletedProcess[str]:
    """Source HyprglassProfile.sh in an isolated env and call a function."""
    script = f"""
set -euo pipefail
export XDG_CONFIG_HOME="{tmp_path}"
export XDG_CACHE_HOME="{tmp_path}/cache"
source "{PROFILE_SCRIPT}"
PROFILES_DIR="{tmp_path / 'profiles'}"
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


def _install_profile(tmp_path: Path, name: str) -> Path:
    """Copy the bundled default profile into the isolated profiles dir."""
    profiles_dir = tmp_path / "profiles"
    profiles_dir.mkdir(parents=True, exist_ok=True)
    target = profiles_dir / f"{name}.conf"
    target.write_text(DEFAULT_PROFILE.read_text(encoding="utf-8"), encoding="utf-8")
    # Rename the $name line so the profile identity matches the file name.
    target.write_text(
        target.read_text(encoding="utf-8").replace(
            "$name = default", f"$name = {name}"
        ),
        encoding="utf-8",
    )
    return target


def test_export_profile_to_stdout(tmp_path: Path):
    _install_profile(tmp_path, "test")
    result = _run_bash_function(tmp_path, "", "export_profile test")
    assert result.returncode == 0, f"export_profile failed: {result.stderr}"
    assert "$name = test" in result.stdout


def test_export_profile_to_file(tmp_path: Path):
    _install_profile(tmp_path, "test")
    out = tmp_path / "exported.conf"
    result = _run_bash_function(tmp_path, "", f'export_profile test "{out}"')
    assert result.returncode == 0, f"export_profile failed: {result.stderr}"
    assert out.exists()
    assert "$name = test" in out.read_text(encoding="utf-8")


def test_export_profile_missing(tmp_path: Path):
    result = _run_bash_function(
        tmp_path, "", 'export_profile nonexistent "{tmp_path / "out.conf"}"'
    )
    assert result.returncode != 0
    assert "not found" in result.stderr
    assert "list" in result.stderr


def test_import_profile_raw(tmp_path: Path):
    source = tmp_path / "custom.conf"
    source.write_text(DEFAULT_PROFILE.read_text(encoding="utf-8"), encoding="utf-8")
    source.write_text(
        source.read_text(encoding="utf-8").replace("$name = default", "$name = custom"),
        encoding="utf-8",
    )
    result = _run_bash_function(tmp_path, "", f'import_profile "{source}"')
    assert result.returncode == 0, f"import_profile failed: {result.stderr}"
    imported = tmp_path / "profiles" / "custom.conf"
    assert imported.exists()
    assert "$name = custom" in imported.read_text(encoding="utf-8")


def test_import_profile_missing_file(tmp_path: Path):
    missing = tmp_path / "does-not-exist.conf"
    result = _run_bash_function(tmp_path, "", f'import_profile "{missing}"')
    assert result.returncode != 0
    assert "File not found" in result.stderr


def test_export_and_import_archive(tmp_path: Path):
    _install_profile(tmp_path, "archived")
    archive = tmp_path / "archived.hyprglass"
    export_result = _run_bash_function(
        tmp_path, "", f'export_profile archived "{archive}"'
    )
    assert export_result.returncode == 0, f"export failed: {export_result.stderr}"
    assert archive.exists()

    with tarfile.open(archive, "r:gz") as tar:
        names = tar.getnames()
    assert any(name.endswith("archived.conf") for name in names)
    assert any(name.endswith("metadata.json") for name in names)

    # Clear profiles and re-import from archive.
    for conf in (tmp_path / "profiles").glob("*.conf"):
        conf.unlink()
    import_result = _run_bash_function(
        tmp_path, "", f'import_profile "{archive}"'
    )
    assert import_result.returncode == 0, f"import failed: {import_result.stderr}"
    imported = tmp_path / "profiles" / "archived.conf"
    assert imported.exists()
    assert "$name = archived" in imported.read_text(encoding="utf-8")


def test_import_archive_without_conf_fails(tmp_path: Path):
    archive = tmp_path / "bad.hyprglass"
    archive.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive, "w:gz") as tar:
        import io

        data = b"not a profile"
        info = tarfile.TarInfo(name="readme.txt")
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data))

    result = _run_bash_function(tmp_path, "", f'import_profile "{archive}"')
    assert result.returncode != 0
    assert "No .conf profile found" in result.stderr


def test_apply_profile_missing_has_helpful_message(tmp_path: Path):
    result = _run_bash_function(tmp_path, "", "apply_profile missing")
    assert result.returncode != 0
    stderr = result.stderr
    assert "not found" in stderr
    assert "list" in stderr
    assert "import" in stderr


def test_apply_profile_warns_on_hyprctl_failure(tmp_path: Path):
    _install_profile(tmp_path, "test")
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    fake_hyprctl = fake_bin / "hyprctl"
    fake_hyprctl.write_text("#!/bin/sh\necho 'mock hyprctl failure' >&2\nexit 1\n", encoding="utf-8")
    fake_hyprctl.chmod(0o755)
    setup = f'export PATH="{fake_bin}:$PATH"'
    result = _run_bash_function(tmp_path, setup, "apply_profile test")
    assert result.returncode == 0, f"apply_profile failed: {result.stderr}"
    output = result.stdout
    assert "hyprctl keyword failed" in output
    assert "Make sure Hyprland is running" in output


def test_apply_theme_missing_has_helpful_message(tmp_path: Path):
    result = _run_bash_function(tmp_path, "", "apply_theme missing")
    assert result.returncode != 0
    stderr = result.stderr
    assert "not found" in stderr
    assert "theme-list" in stderr


def test_import_and_export_aliases(tmp_path: Path):
    _install_profile(tmp_path, "aliased")
    out = tmp_path / "aliased.hyprglass"
    export_result = _run_bash_function(tmp_path, "", f'export_profile aliased "{out}"')
    assert export_result.returncode == 0

    for conf in (tmp_path / "profiles").glob("*.conf"):
        conf.unlink()

    import_result = _run_bash_function(tmp_path, "", f'import_profile "{out}"')
    assert import_result.returncode == 0
    assert (tmp_path / "profiles" / "aliased.conf").exists()
