import json
import pytest
from pathlib import Path


PROFILES_DIR = Path(__file__).resolve().parent.parent / "profiles"
REQUIRED_KEYS = {"name", "glass", "theme", "decoration"}


def test_profiles_directory_exists():
    assert PROFILES_DIR.exists(), "profiles directory should exist"
    assert PROFILES_DIR.is_dir(), "profiles should be a directory"


def test_default_profile_exists():
    default = PROFILES_DIR / "default.conf"
    assert default.exists(), "default.conf should exist"


@pytest.mark.parametrize("profile_path", list(PROFILES_DIR.glob("*.conf")))
def test_profile_is_valid_json(profile_path):
    with profile_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    assert isinstance(data, dict), f"{profile_path.name} should contain a JSON object"


@pytest.mark.parametrize("profile_path", list(PROFILES_DIR.glob("*.conf")))
def test_profile_has_required_keys(profile_path):
    with profile_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    missing = REQUIRED_KEYS - data.keys()
    assert not missing, f"{profile_path.name} is missing keys: {missing}"


@pytest.mark.parametrize("profile_path", list(PROFILES_DIR.glob("*.conf")))
def test_profile_name_matches_filename(profile_path):
    with profile_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    expected_name = profile_path.stem
    assert data.get("name") == expected_name, (
        f"{profile_path.name} name should match filename"
    )
