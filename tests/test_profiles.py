import re
from pathlib import Path

import pytest


PROFILES_DIR = Path(__file__).resolve().parent.parent / "profiles"
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
