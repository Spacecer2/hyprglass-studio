#!/usr/bin/env python3
"""
HyprglassTray.py - System tray applet and rofi launcher for HyprGlass.

Usage:
    HyprglassTray.py              Run the GTK/AppIndicator system tray applet.
    HyprglassTray.py --rofi       Show a rofi-based menu instead.
    HyprglassTray.py --help       Show this help message.

Dependencies:
    - GTK/AppIndicator mode: python-gobject, libappindicator-gtk3 (or ayatana)
    - Rofi mode: rofi, bash, hyprctl

The tray applet shows the current HyprGlass profile and lets you:
    - Switch between profiles
    - Open HyprGlass Studio in a browser
    - Toggle glass effects on/off
    - Quit the applet
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path


_ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

# ---------------------------------------------------------------------------
# Paths and constants
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROFILE_SCRIPT = SCRIPT_DIR / "HyprglassProfile.sh"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
CURRENT_PROFILE_CACHE = CACHE_DIR / ".hyprglass_profile"
HYPR_DIR = Path.home() / ".config" / "hypr"
PROFILES_DIR = HYPR_DIR / "hyprglass-profiles"

STUDIO_CMDS = [
    "hyprglass-studio",
    str(SCRIPT_DIR / "hyprglass-studio-launcher"),
]

DEFAULT_ICON_NAME = "preferences-system-windows"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def run(cmd: list[str], capture: bool = True, check: bool = False) -> subprocess.CompletedProcess:
    """Run a command, suppressing stderr unless in debug mode."""
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True, check=check)
    return subprocess.run(cmd, text=True, check=check)


def current_profile() -> str:
    """Return the currently active profile name, or 'default'."""
    # Prefer the explicit cache written by HyprglassProfile.sh.
    if CURRENT_PROFILE_CACHE.exists():
        cached = CURRENT_PROFILE_CACHE.read_text().strip()
        if cached:
            return cached

    # Fall back to running the profile script.
    if PROFILE_SCRIPT.exists():
        result = run(["bash", str(PROFILE_SCRIPT), "current"])
        for line in result.stdout.splitlines():
            if line.startswith("Current profile:"):
                return line.split(":", 1)[1].strip()

    return "default"


def list_profiles() -> list[str]:
    """Return a sorted list of available profile names."""
    profiles: list[str] = []

    # Use HyprglassProfile.sh when available.
    if PROFILE_SCRIPT.exists():
        result = run(["bash", str(PROFILE_SCRIPT), "list"])
        for line in result.stdout.splitlines():
            # Strip ANSI color codes before parsing.
            stripped = _ANSI_RE.sub("", line.strip())
            if not stripped or stripped.startswith("Available") or stripped.startswith("No profiles"):
                continue
            # Lines look like: "  profile - description" or "  -> profile - description"
            name = stripped.lstrip("→ ").split(" - ", 1)[0].strip()
            if name and name not in profiles:
                profiles.append(name)
        if profiles:
            return sorted(profiles)

    # Direct directory scan.
    directory = PROFILES_DIR if PROFILES_DIR.exists() else SCRIPT_DIR.parent / "profiles"
    if directory.exists():
        for conf in sorted(directory.glob("*.conf")):
            profiles.append(conf.stem)

    return profiles


def apply_profile(name: str) -> None:
    """Apply a HyprGlass profile by name."""
    if PROFILE_SCRIPT.exists():
        run(["bash", str(PROFILE_SCRIPT), "apply", name], check=False)
    else:
        # Direct fallback through hyprctl (best-effort).
        profile_file = PROFILES_DIR / f"{name}.conf"
        if not profile_file.exists():
            return
        for line in profile_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if not line.startswith("$"):
                continue
            key, _, value = line[1:].partition("=")
            key = key.strip()
            value = value.strip()
            if key.startswith("glass."):
                sub = key.split(".", 1)[1]
                if sub == "enabled":
                    run(["hyprctl", "keyword", "plugin:hyprglass:enabled", value])
                else:
                    run(["hyprctl", "keyword", f"plugin:hyprglass:{sub}", value])


def glass_enabled() -> bool:
    """Return whether HyprGlass is currently enabled."""
    result = run(["hyprctl", "getoption", "plugin:hyprglass:enabled"])
    if not result.stdout:
        return False
    return "int: 1" in result.stdout or "set: true" in result.stdout


def toggle_glass() -> None:
    """Toggle the HyprGlass enabled state."""
    new_state = "0" if glass_enabled() else "1"
    run(["hyprctl", "keyword", "plugin:hyprglass:enabled", new_state])


def open_studio() -> None:
    """Launch the HyprGlass Studio web UI."""
    # Try installed launcher first.
    for cmd in STUDIO_CMDS:
        if shutil.which(cmd) or Path(cmd).exists():
            # Start in the background so the tray stays responsive.
            subprocess.Popen(
                [cmd, "--port", "8765"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return

    # Repository fallback: run src/server.py directly.
    server_py = SCRIPT_DIR.parent / "src" / "server.py"
    if server_py.exists():
        subprocess.Popen(
            ["python3", str(server_py), "--port", "8765"],
            cwd=str(SCRIPT_DIR.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return

    notify("HyprGlass Studio launcher not found")


def notify(message: str) -> None:
    """Show a transient desktop notification if notify-send is available."""
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "HyprGlass", message], check=False)


# ---------------------------------------------------------------------------
# Icon generation
# ---------------------------------------------------------------------------
def build_icon_path() -> str | None:
    """Generate a simple 64x64 tray icon and return its PNG path."""
    try:
        from PIL import Image, ImageDraw
    except Exception:
        return None

    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Glass-like rounded square background.
    draw.rounded_rectangle(
        (4, 4, size - 4, size - 4),
        radius=14,
        fill=(120, 160, 200, 220),
        outline=(200, 220, 255, 255),
        width=3,
    )
    # A subtle highlight.
    draw.rounded_rectangle(
        (10, 10, size - 10, 26),
        radius=8,
        fill=(255, 255, 255, 80),
    )

    fd, path = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    img.save(path, "PNG")
    return path


# ---------------------------------------------------------------------------
# System tray (AppIndicator3 + GTK3)
# ---------------------------------------------------------------------------
def run_tray() -> int:
    """Run the GTK/AppIndicator system tray applet."""
    try:
        import gi

        gi.require_version("Gtk", "3.0")
        from gi.repository import Gtk

        # Prefer Ayatana's maintained indicator; fall back to the older name.
        indicator_module = None
        for name in ("AyatanaAppIndicator3", "AppIndicator3"):
            try:
                gi.require_version(name, "0.1")
                indicator_module = __import__("gi.repository", fromlist=[name])
                indicator_module = getattr(indicator_module, name)
                break
            except Exception:
                continue

        if indicator_module is None:
            raise ImportError("No AppIndicator implementation found")
    except Exception as exc:
        print(f"Tray dependencies not available: {exc}", file=sys.stderr)
        print("Falling back to rofi mode.", file=sys.stderr)
        return run_rofi()

    icon_path = build_icon_path()
    indicator = indicator_module.Indicator.new(
        "hyprglass-tray",
        icon_path or DEFAULT_ICON_NAME,
        indicator_module.IndicatorCategory.APPLICATION_STATUS,
    )
    indicator.set_status(indicator_module.IndicatorStatus.ACTIVE)
    indicator.set_title("HyprGlass")
    indicator.set_label(f"Profile: {current_profile()}", "Profile: default")

    def rebuild_menu(_=None):
        menu = Gtk.Menu()

        # Header label (non-clickable).
        header = Gtk.MenuItem(label=f"Current profile: {current_profile()}")
        header.set_sensitive(False)
        menu.append(header)

        sep = Gtk.SeparatorMenuItem()
        menu.append(sep)

        # Profile submenu.
        profiles = list_profiles()
        if profiles:
            profile_menu = Gtk.Menu()
            profile_item = Gtk.MenuItem(label="Profiles")
            profile_item.set_submenu(profile_menu)
            active = current_profile()
            for profile in profiles:
                label = f"{'✓ ' if profile == active else ''}{profile}"
                item = Gtk.MenuItem(label=label)
                item.connect("activate", lambda _, p=profile: (apply_profile(p), rebuild_menu()))
                profile_menu.append(item)
            menu.append(profile_item)

        # Open Studio.
        studio_item = Gtk.MenuItem(label="Open Studio")
        studio_item.connect("activate", lambda _: open_studio())
        menu.append(studio_item)

        # Toggle glass.
        state = "On" if glass_enabled() else "Off"
        toggle_item = Gtk.MenuItem(label=f"Toggle Glass ({state})")
        toggle_item.connect("activate", lambda _: (toggle_glass(), rebuild_menu()))
        menu.append(toggle_item)

        sep2 = Gtk.SeparatorMenuItem()
        menu.append(sep2)

        # Quit.
        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect("activate", lambda _: Gtk.main_quit())
        menu.append(quit_item)

        menu.show_all()
        indicator.set_menu(menu)

    rebuild_menu()
    # Refresh the label/menu periodically in case the profile changed externally.
    def refresh():
        indicator.set_label(f"Profile: {current_profile()}", "Profile: default")
        rebuild_menu()
        return True

    Gtk.timeout_add_seconds(5, refresh)
    Gtk.main()

    if icon_path:
        try:
            os.unlink(icon_path)
        except OSError:
            pass
    return 0


# ---------------------------------------------------------------------------
# Rofi fallback
# ---------------------------------------------------------------------------
def run_rofi() -> int:
    """Show a rofi menu with the same actions as the tray applet."""
    if not shutil.which("rofi"):
        print("Error: rofi is not installed.", file=sys.stderr)
        print("Install rofi or run this on a system with GTK/AppIndicator support.", file=sys.stderr)
        return 1

    rofi_theme = os.environ.get("ROFI_THEME", "")
    active = current_profile()
    profiles = list_profiles()

    entries = ["Open Studio", f"Toggle Glass (currently {'On' if glass_enabled() else 'Off'})"]
    if profiles:
        entries.append("Profiles ▶")
    entries.append("Quit")

    args = ["rofi", "-dmenu", "-i", "-p", "HyprGlass"]
    if rofi_theme and Path(rofi_theme).exists():
        args.extend(["-theme", rofi_theme])
    args.extend(["-theme-str", "window { width: 400px; }"])

    result = subprocess.run(args, input="\n".join(entries), text=True, capture_output=True)
    if result.returncode != 0 or not result.stdout.strip():
        return 0

    choice = result.stdout.strip()

    if choice == "Open Studio":
        open_studio()
    elif choice.startswith("Toggle Glass"):
        toggle_glass()
    elif choice == "Profiles ▶":
        return _rofi_profiles(active, profiles)
    elif choice == "Quit":
        return 0

    return 0


def _rofi_profiles(active: str, profiles: list[str]) -> int:
    """Show a rofi submenu for selecting a profile."""
    rofi_theme = os.environ.get("ROFI_THEME", "")
    entries = [f"{'✓ ' if p == active else ''}{p}" for p in profiles]

    args = ["rofi", "-dmenu", "-i", "-p", "Select Profile"]
    if rofi_theme and Path(rofi_theme).exists():
        args.extend(["-theme", rofi_theme])
    args.extend(["-theme-str", "window { width: 400px; }"])

    result = subprocess.run(args, input="\n".join(entries), text=True, capture_output=True)
    if result.returncode != 0 or not result.stdout.strip():
        return 0

    selected = result.stdout.strip().lstrip("✓ ").strip()
    if selected in profiles:
        apply_profile(selected)
        notify(f"Applied profile: {selected}")
    return 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="HyprGlass system tray applet and rofi launcher.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--rofi",
        action="store_true",
        help="Use rofi instead of the system tray applet.",
    )
    args = parser.parse_args()

    if args.rofi:
        return run_rofi()
    return run_tray()


if __name__ == "__main__":
    sys.exit(main())
