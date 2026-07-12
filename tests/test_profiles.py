import os
import re
import subprocess
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROFILES_DIR = PROJECT_ROOT / "profiles"
PROFILE_SCRIPT = PROJECT_ROOT / "scripts" / "HyprglassProfile.sh"
REQUIRED_SECTIONS = {"glass", "theme", "decoration"}


def test_profiles_directory_exists():
    assert PROFILES_DIR.exists(), "profiles directory should exist"
    assert PROFILES_DIR.is_dir(), "profiles should be a directory"


def test_default_profile_exists():
    default = PROFILES_DIR / "default.conf"
    assert default.exists(), "default.conf should exist"


@pytest.mark.parametrize("profile_path", list(PROFILES_DIR.glob("*.conf")))
def test_profile_sets_name(profile_path):
    content = profile_path.read_text(encoding="utf-8")
    expected = f"$name = {profile_path.stem}"
    assert expected in content, f"{profile_path.name} should set $name to {profile_path.stem}"


@pytest.mark.parametrize("profile_path", list(PROFILES_DIR.glob("*.conf")))
def test_profile_has_required_sections(profile_path):
    content = profile_path.read_text(encoding="utf-8")
    found = {section for section in REQUIRED_SECTIONS if re.search(rf"\${section}\.", content)}
    missing = REQUIRED_SECTIONS - found
    assert not missing, f"{profile_path.name} is missing sections: {missing}"


def run_profile(args: list[str], tmp_path: Path) -> subprocess.CompletedProcess:
    env = {"XDG_CONFIG_HOME": str(tmp_path), "XDG_CACHE_HOME": str(tmp_path / "cache")}
    return subprocess.run(
        ["bash", str(PROFILE_SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )


def test_export_profile_prints_to_stdout():
    result = run_profile(["export", "default"], Path("/tmp"))
    assert result.returncode == 0, f"export failed: {result.stderr}"
    assert "$name = default" in result.stdout


def test_export_profile_writes_file(tmp_path: Path):
    output = tmp_path / "exported.conf"
    result = run_profile(["export", "default", str(output)], tmp_path)
    assert result.returncode == 0, f"export failed: {result.stderr}"
    assert output.exists()
    assert "$name = default" in output.read_text(encoding="utf-8")


def test_import_profile_creates_user_profile(tmp_path: Path):
    source = tmp_path / "custom.conf"
    source.write_text(
        PROFILES_DIR.joinpath("default.conf").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    result = run_profile(["import", str(source)], tmp_path)
    assert result.returncode == 0, f"import failed: {result.stderr}"
    imported = tmp_path / "hypr" / "hyprglass-profiles" / "default.conf"
    assert imported.exists()
    assert "$name = default" in imported.read_text(encoding="utf-8")


def test_import_profile_rejects_invalid_file(tmp_path: Path):
    bad = tmp_path / "bad.conf"
    bad.write_text("$name = bad\n$glass.blur_strength = 99\n", encoding="utf-8")
    result = run_profile(["import", str(bad)], tmp_path)
    assert result.returncode != 0
    assert "Profile validation failed" in result.stderr


def test_import_profile_rejects_unsafe_values(tmp_path: Path):
    bad = tmp_path / "evil.conf"
    bad.write_text("$name = evil\n$glass.blur_strength = 3.4; rm -rf /\n", encoding="utf-8")
    result = run_profile(["import", str(bad)], tmp_path)
    assert result.returncode != 0
    assert "Profile validation failed" in result.stderr


def test_import_from_url_rejects_http(tmp_path: Path):
    result = run_profile(["import-from-url", "http://example.com/test.conf"], tmp_path)
    assert result.returncode != 0
    assert "Only HTTPS URLs are allowed" in result.stderr


def test_theme_directory_exists():
    themes_dir = PROFILES_DIR / "themes"
    assert themes_dir.exists(), "themes directory should exist"


def test_tokyonight_theme_exists():
    theme = PROFILES_DIR / "themes" / "tokyonight.conf"
    assert theme.exists()
    content = theme.read_text(encoding="utf-8")
    assert "$name = tokyonight" in content
    assert "$default_theme = dark" in content


def test_theme_list_includes_tokyonight():
    result = run_profile(["theme-list"], Path("/tmp"))
    assert result.returncode == 0, f"theme-list failed: {result.stderr}"
    assert "tokyonight" in result.stdout


def test_theme_current_after_apply(tmp_path: Path):
    # Create a fake hyprctl on PATH so apply_theme does not fail.
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    fake_hyprctl = fake_bin / "hyprctl"
    fake_hyprctl.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    fake_hyprctl.chmod(0o755)

    env = {
        "XDG_CONFIG_HOME": str(tmp_path),
        "XDG_CACHE_HOME": str(tmp_path / "cache"),
        "PATH": f"{fake_bin}:{os.environ.get('PATH', '')}",
    }
    result = subprocess.run(
        ["bash", str(PROFILE_SCRIPT), "theme", "tokyonight"],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert result.returncode == 0, f"theme apply failed: {result.stderr}"

    result2 = subprocess.run(
        ["bash", str(PROFILE_SCRIPT), "theme-current"],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert result2.returncode == 0, f"theme-current failed: {result2.stderr}"
    assert "tokyonight" in result2.stdout
