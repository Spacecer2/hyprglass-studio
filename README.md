# HyprGlass Studio

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/youruser/hyprglass-studio?style=social)](https://github.com/youruser/hyprglass-studio/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/youruser/hyprglass-studio)](https://github.com/youruser/hyprglass-studio/issues)
[![Last commit](https://img.shields.io/github/last-commit/youruser/hyprglass-studio)](https://github.com/youruser/hyprglass-studio/commits/main)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.55%2B-blueviolet.svg)](https://hyprland.org)
[![Python](https://img.shields.io/badge/Python-%E2%89%A5%203.8-3776AB.svg?logo=python&logoColor=white)](https://www.python.org)

> Apple-style Liquid Glass effects for your Hyprland desktop on Linux.

---

## What is HyprGlass Studio?

HyprGlass Studio brings the translucent, depth-aware glass aesthetic introduced in Apple's Liquid Glass design language to the Hyprland Wayland compositor. It applies real-time blur, tint, and transparency to windows and layer surfaces, syncs colors from your wallpaper, and gives you a browser-based Studio UI to tune every parameter live.

---

## Demo

<!-- Replace with an actual screen recording GIF -->
![HyprGlass Studio Demo](screenshots/demo.gif)

---

## Features

- 🪟 **Glass Effect on Windows & Layer Surfaces** — Apply blur, opacity, and color tint to any window or layer-shell surface in real time.
- 🎨 **Wallust Color Sync** — Automatically extract dominant colors from your wallpaper and use them to tint glass surfaces for a cohesive look.
- 🔀 **Session Profiles** — Switch between presets like *Gaming*, *Coding*, and *Movies* with a single command or hotkey.
- 🖥️ **Web-based Studio UI** — A local dashboard for live-tuning glass parameters, previewing changes, and managing profiles.
- 🔄 **Auto-Switching** — Automatically apply the right profile based on the active application (e.g. game detected → Gaming profile).
- 🤝 **JaKooLit Dots Compatible** — Works out of the box with [JaKooLit's Hyprland dots](https://github.com/JaKooLit/Hyprland-Dots).

---

## Screenshots

<!-- Replace the paths below with actual screenshots -->

| Glass Effect | Studio UI | Profile Switch |
|:---:|:---:|:---:|
| ![Glass](screenshots/glass.png) | ![Studio](screenshots/studio.png) | ![Profiles](screenshots/profiles.png) |

---

## Requirements

| Dependency | Version | Notes |
|---|---|---|
| **Hyprland** | ≥ 0.55 | Required |
| **hyprpm** | latest | Hyprland plugin manager |
| **Python** | ≥ 3.8 | Core runtime |
| **wallust** | latest | Optional — for wallpaper color sync |

---

## Installation

### One-liner install

```bash
bash <(curl -s https://raw.githubusercontent.com/youruser/hyprglass-studio/main/install.sh)
```

### Manual install

```bash
git clone https://github.com/youruser/hyprglass-studio.git ~/hyprglass-studio
cd ~/hyprglass-studio
./install.sh
```

The install script will:

- Check for Hyprland, `hyprpm`, and Python
- Build and install the Hyprland glass plugin via `hyprpm`
- Install the Python package and CLI entry point
- Optionally enable the user service for auto-start

### JaKooLit Hyprland dots

If you use [JaKooLit's Hyprland dots](https://github.com/JaKooLit/Hyprland-Dots), HyprGlass Studio is compatible out of the box. The installer detects the JaKooLit layout and adds the default keybindings and startup hook to `~/.config/hypr/UserConfigs/Startup_Apps.conf`. If you prefer to manage startup manually, skip the service option during install.

### Verification

After installation, confirm everything is in place:

```bash
# Check the CLI is available
hyprglass-studio --version

# Confirm the Hyprland plugin is loaded
hyprpm list | grep -i hyprglass

# Check the user service status (if you enabled auto-start)
systemctl --user status hyprglass-studio
```

---

## Quick Start

**1. Launch the Studio UI**

```bash
hyprglass-studio --studio
```

**2. Open your browser**

Navigate to `http://localhost:8420` to tune blur, opacity, tint, and profiles in real time.

**3. Try a profile**

```bash
hyprglass-studio --profile Gaming
```

---

## Documentation

- [Configuration Reference](docs/configuration.md)
- [Profiles Guide](docs/profiles.md)
- [Auto-Switching Setup](docs/auto-switch.md)
- [Wallust Integration](docs/wallust.md)
- [Building from Source](docs/building.md)

---

## Star History

<!-- Replace with actual Star History chart or link -->
[![Star History Chart](https://api.star-history.com/svg?repos=youruser/hyprglass-studio&type=Date)](https://star-history.com/#youruser/hyprglass-studio&Date)

---

## License

MIT — see [LICENSE](LICENSE) for details.
