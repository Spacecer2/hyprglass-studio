# HyprGlass Studio

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Hyprland](https://img.shields.io/badge/Hyprland-0.55%2B-blueviolet.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)

> Apple-style Liquid Glass effects for your Hyprland desktop on Linux.

---

## What is HyprGlass Studio?

HyprGlass Studio brings the translucent, depth-aware glass aesthetic introduced in Apple's Liquid Glass design language to the Hyprland Wayland compositor. It applies real-time blur, tint, and transparency to windows and layer surfaces, syncs colors from your wallpaper, and gives you a browser-based Studio UI to tune every parameter live.

---

## Features

- **Glass Effect on Windows & Layer Surfaces** — Apply blur, opacity, and color tint to any window or layer-shell surface in real time.
- **Wallust Color Sync** — Automatically extract dominant colors from your wallpaper and use them to tint glass surfaces for a cohesive look.
- **Session Profiles** — Switch between presets like *Gaming*, *Coding*, and *Movies* with a single command or hotkey.
- **Web-based Studio UI** — A local dashboard for live-tuning glass parameters, previewing changes, and managing profiles.
- **Auto-Switching** — Automatically apply the right profile based on the active application (e.g. game detected → Gaming profile).
- **JaKooLit Dots Compatible** — Works out of the box with [JaKooLit's Hyprland dots](https://github.com/JaKooLit/Hyprland-Dots).

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

## Quick Start

**1. Clone the repository**

```bash
git clone https://github.com/youruser/hyprglass-studio.git ~/hyprglass-studio
cd ~/hyprglass-studio
```

**2. Install**

```bash
./install.sh
```

**3. Launch the Studio UI**

```bash
hyprglass-studio --studio
```

Then open `http://localhost:8420` in your browser to start tuning.

---

## Documentation

- [Configuration Reference](docs/configuration.md)
- [Profiles Guide](docs/profiles.md)
- [Auto-Switching Setup](docs/auto-switch.md)
- [Wallust Integration](docs/wallust.md)
- [Building from Source](docs/building.md)

---

## License

MIT — see [LICENSE](LICENSE) for details.
