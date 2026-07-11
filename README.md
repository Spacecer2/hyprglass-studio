```
╔════════════════════════════════════════════════════════════╗
║     HyprGlass Studio — Liquid Glass for Hyprland          ║
╚════════════════════════════════════════════════════════════╝
```

> Real-time Liquid Glass effects for the Hyprland Wayland compositor.

# HyprGlass Studio

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status: Production Ready](https://img.shields.io/badge/status-production--ready-brightgreen.svg)](#security-features)
[![GitHub stars](https://img.shields.io/github/stars/Spacecer2/hyprglass-studio?style=social)](https://github.com/Spacecer2/hyprglass-studio)
[![GitHub issues](https://img.shields.io/github/issues/Spacecer2/hyprglass-studio)](https://github.com/Spacecer2/hyprglass-studio/issues)
[![Last commit](https://img.shields.io/github/last-commit/Spacecer2/hyprglass-studio)](https://github.com/Spacecer2/hyprglass-studio/commits/master)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.55%2B-blueviolet.svg)](https://hyprland.org)
[![Python](https://img.shields.io/badge/Python-%E2%89%A5%203.10-3776AB.svg?logo=python&logoColor=white)](https://www.python.org)

> Apple-style Liquid Glass effects for your Hyprland desktop on Linux.

---

## What is HyprGlass Studio?

HyprGlass Studio brings the translucent, depth-aware glass aesthetic introduced in Apple's Liquid Glass design language to the Hyprland Wayland compositor. It applies real-time blur, tint, and transparency to windows and layer surfaces, syncs colors from your wallpaper, and gives you a browser-based Studio UI to tune every parameter live.

---

## Vision

HyprGlass Studio is more than a blur plugin — it's a step toward a future where your desktop feels alive, adaptive, and unmistakably yours.

- **Short-term (v1.x):** Rock-solid stability, polished profiles, and seamless [wallust](https://codeberg.org/explosion-mental/wallust) color syncing that makes every wallpaper feel like a fresh theme.
- **Mid-term (v2.x):** A ground-up plugin rewrite for better performance, lower latency, and deeper Wayland-native integration — starting with Hyprland and growing from there.
- **Long-term (v3.x+):** AI-powered adaptive glass that reads context and mood, a community marketplace for one-click profiles, and first-class support for the broader Wayland compositor ecosystem.

The goal is simple: **glass that knows you.**

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features, milestones, and current status.

---

## Version Planning

Release goals and version targets are tracked in [ROADMAP.md](ROADMAP.md#version-planning).

---

## Demo

<!-- Replace with an actual screen recording GIF -->
![HyprGlass Studio Demo](screenshots/demo.gif)

---

## Features

- 🪟 **Glass Effect on Windows & Layer Surfaces** — Apply blur, opacity, and color tint to any window or layer-shell surface in real time.
- 🎨 **Wallust Color Sync** — Automatically extract dominant colors from your wallpaper and use them to tint glass surfaces for a cohesive look.
- 🔀 **Session Profiles** — Switch between presets like *Gaming*, *Coding*, and *Movies* with a single command or hotkey.
- 🖥️ **Web-based Studio UI** — A local dashboard for live-tuning glass parameters, previewing changes, and exporting configs.
- 🔄 **Auto-Switching** — Automatically apply the right profile based on the active application (e.g. game detected → Gaming profile).
- 🤝 **JaKooLit Dots Compatible** — Works out of the box with [JaKooLit's Hyprland dots](https://github.com/JaKooLit/Hyprland-Dots).

---

## Security Features

HyprGlass Studio is designed with security in mind. See [SECURITY.md](SECURITY.md) for the full security policy and vulnerability reporting process.

- **Non-root installer** — The installer refuses to run as root or via `sudo` unless explicitly allowed with `--allow-root`, preventing accidental system-wide modifications.
- **Path validation** — All target paths are verified to live under `$HOME` before any file operation.
- **Input validation** — User inputs, plugin parameters, and external data are type-checked, sanitized, and validated.
- **Atomic backups** — Existing configs are backed up with timestamps before modification so you can roll back safely.
- **No hardcoded secrets** — The codebase is scanned for credentials, API keys, and tokens; secrets are provided via environment variables or secure config files.
- **Sandboxed plugins** — Plugins run with limited system access, declared capabilities, and user-consent gating.
- **Safe file operations** — Path-traversal prevention, atomic writes, temporary file cleanup, and restricted permissions where applicable.

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
| **Python** | ≥ 3.10 | Core runtime |
| **wallust** | latest | Optional — for wallpaper color sync |

---

## Installation

### Quick install

For security, review the install script before running it. You can download it first, inspect it, and then execute it locally:

```bash
# Download the installer
curl -fsSL -o /tmp/hyprglass-install.sh \
    https://raw.githubusercontent.com/Spacecer2/hyprglass-studio/master/install.sh

# Inspect the script (recommended)
less /tmp/hyprglass-install.sh

# Run it interactively
bash /tmp/hyprglass-install.sh

# Or run it unattended
bash /tmp/hyprglass-install.sh --yes
```

### Manual install

```bash
git clone https://github.com/Spacecer2/hyprglass-studio.git ~/hyprglass-studio
cd ~/hyprglass-studio
./install.sh
```

### Installer options

The fixed installer supports several options:

| Option | Description |
|--------|-------------|
| `--yes`, `-y` | Skip all confirmation prompts (unattended install) |
| `--dry-run` | Show what would be done without making changes |
| `--skip-plugin` | Skip the `hyprglass` plugin installation via `hyprpm` |
| `--skip-wallust` | Skip wallust integration checks |
| `--verbose`, `-v` | Print extra debug information |
| `--allow-root` | Allow running as root (not recommended; for containers only) |
| `--help`, `-h` | Show usage information |

### What the installer does

The install script will:

- Detect JaKooLit Hyprland dots and preserve their structure
- Verify prerequisites (`hyprctl`, `hyprpm`, Python 3.10+, `jq`, curl/wget)
- Create timestamped backups of existing configs
- Install the `hyprglass` Hyprland plugin via `hyprpm`
- Copy profiles, scripts, and wallust templates
- Generate `Hyprglass.conf` and a startup fix script if missing
- Patch `hyprland.conf` safely without overwriting dotfiles
- Set executable permissions on helper scripts
- Verify the installation and optionally reload Hyprland

### JaKooLit Hyprland dots

If you use [JaKooLit's Hyprland dots](https://github.com/JaKooLit/Hyprland-Dots), HyprGlass Studio is compatible out of the box. The installer detects the JaKooLit layout and patches the appropriate config files. See [docs/JAKOOLIT.md](docs/JAKOOLIT.md) for detailed integration steps.

### Verification

After installation, confirm everything is in place:

```bash
# Confirm the Hyprland plugin is loaded
hyprpm list | grep -i hyprglass

# Confirm the profile switcher is installed
~/.config/hypr/scripts/HyprglassProfile.sh list

# Check the installation health
~/.config/hypr/scripts/CheckHyprglassStatus.sh

# Validate the generated Hyprglass.conf
~/.config/hypr/scripts/ValidateHyprglassConf.sh
```

---

## Quick Start

**1. Launch the Studio UI**

After running the installer:

```bash
hyprglass-studio
```

From the repository directly:

```bash
cd ~/hyprglass-studio
python3 -m src.server --port 8765
```

**2. Open your browser**

Navigate to `http://localhost:8765` to tune blur, opacity, tint, layer surfaces, and window rules in real time.

**3. Try a profile**

```bash
~/.config/hypr/scripts/HyprglassProfile.sh apply gaming
```

---

## Documentation

- [Configuration Reference](docs/CONFIGURATION.md)
- [Installation Guide](docs/INSTALLATION.md)
- [Profiles Guide](docs/PROFILES.md)
- [Auto-Switching Setup](docs/PROFILES.md#auto-switching)
- [Profile Sharing](docs/PROFILE-SHARING.md)
- [Wallust Integration](docs/WALLUST-INTEGRATION.md)
- [Studio UI Guide](docs/STUDIO-UI.md)
- [API Reference](docs/API.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Themes Guide](docs/THEMES.md)
- [Rofi Theme](docs/ROFI-THEME.md)
- [GPU Monitoring](docs/GPU-MONITOR.md)
- [Performance Tuning](docs/PERFORMANCE.md)
- [Migration Guide](docs/MIGRATION.md)
- [Marketplace](docs/MARKETPLACE.md)
- [JaKooLit Integration](docs/JAKOOLIT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [FAQ](docs/FAQ.md)
- [Demo Setup](docs/DEMO.md)
- [Version Planning](docs/VERSION-PLANNING.md)
- [Roadmap](ROADMAP.md)
- [Contributing](docs/CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

---

## Contributing

Contributions are welcome! Please read [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on how to report issues, propose features, and submit changes.

> **Branch protection:** The `master` branch is protected. All changes must be submitted through a pull request and reviewed before merging. Direct pushes to `master` are not allowed. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md#pull-request-process) for the full PR process.

---

## Star History

View the [star history](https://star-history.com/#Spacecer2/hyprglass-studio&Date) for this project.

---

## License

MIT — see [LICENSE](LICENSE) for details.
