"""Tests for scripts/ValidateHyprglassConf.sh."""
from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
VALIDATOR = PROJECT_ROOT / "scripts" / "ValidateHyprglassConf.sh"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def run_validator(conf_path: Path) -> tuple[int, str, str]:
    """Run the validator on a config file and return (rc, stdout, stderr)."""
    result = subprocess.run(
        ["bash", str(VALIDATOR), str(conf_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, result.stdout, result.stderr


def test_validator_script_exists():
    assert VALIDATOR.exists(), "ValidateHyprglassConf.sh should exist"
    assert VALIDATOR.is_file(), "ValidateHyprglassConf.sh should be a file"


def test_validator_usage_without_args():
    result = subprocess.run(
        ["bash", str(VALIDATOR)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2
    assert "Usage" in result.stderr


def test_validator_rejects_missing_file():
    missing = FIXTURES / "does_not_exist.conf"
    rc, _, stderr = run_validator(missing)
    assert rc == 1
    assert "File not found" in stderr


@pytest.mark.parametrize(
    "fixture_name",
    ["valid.conf", "minimal_valid.conf"],
)
def test_validator_accepts_valid_configs(fixture_name):
    conf = FIXTURES / fixture_name
    rc, stdout, stderr = run_validator(conf)
    assert rc == 0, f"expected valid config to pass; stderr: {stderr}"
    assert stdout == ""
    assert stderr == ""


@pytest.mark.parametrize(
    "fixture_name, expected_error",
    [
        ("invalid_missing_plugin.conf", "missing plugin:hyprglass block"),
        ("invalid_unclosed_plugin.conf", "plugin:hyprglass block is not closed"),
        ("invalid_missing_required.conf", "missing required field: default_preset"),
        ("invalid_numeric.conf", "blur_strength must be between"),
        ("invalid_decoration.conf", "decoration.active_opacity must be between"),
    ],
)
def test_validator_rejects_invalid_configs(fixture_name, expected_error):
    conf = FIXTURES / fixture_name
    rc, _, stderr = run_validator(conf)
    assert rc == 1, f"expected invalid config to fail: {fixture_name}"
    assert expected_error in stderr


def test_validator_reports_all_missing_required_fields():
    conf = FIXTURES / "invalid_missing_required.conf"
    rc, _, stderr = run_validator(conf)
    assert rc == 1
    assert "missing required field: default_preset" in stderr


def test_validator_malformed_values():
    conf = FIXTURES / "invalid_malformed.conf"
    rc, _, stderr = run_validator(conf)
    assert rc == 1
    assert "blur_strength must be numeric" in stderr
    assert "decoration.active_opacity must be numeric" in stderr


def test_validator_plugins_numeric_range(tmp_path):
    conf = tmp_path / "edge_case.conf"
    conf.write_text(
        """
plugin:hyprglass {
    enabled = 1
    default_theme = dark
    default_preset = default
    blur_strength = 0
    blur_iterations = 1
    refraction_strength = 0
    chromatic_aberration = 0
    fresnel_strength = 0
    specular_strength = 0
    glass_opacity = 0
    edge_thickness = 0
    lens_distortion = 0
}

decoration {
    active_opacity = 0
    inactive_opacity = 0
    fullscreen_opacity = 0
}
""",
        encoding="utf-8",
    )
    rc, _, stderr = run_validator(conf)
    assert rc == 0, f"boundary values should be accepted; stderr: {stderr}"


def test_validator_plugins_numeric_upper_bound(tmp_path):
    conf = tmp_path / "upper_bound.conf"
    conf.write_text(
        """
plugin:hyprglass {
    enabled = 1
    default_theme = dark
    default_preset = default
    blur_strength = 8
    blur_iterations = 5
    refraction_strength = 1
    chromatic_aberration = 1
    fresnel_strength = 1
    specular_strength = 1
    glass_opacity = 1
    edge_thickness = 0.15
    lens_distortion = 1
}

decoration {
    active_opacity = 1
    inactive_opacity = 1
    fullscreen_opacity = 1
}
""",
        encoding="utf-8",
    )
    rc, _, stderr = run_validator(conf)
    assert rc == 0, f"upper boundary values should be accepted; stderr: {stderr}"
