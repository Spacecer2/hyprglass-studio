# HyprGlass Studio — Web Interface

> Live editor for the HyprGlass configuration file.

---

## Table of Contents

- [Overview](#overview)
- [Launching the Studio](#launching-the-studio)
- [Interface Layout](#interface-layout)
- [Global Settings](#global-settings)
- [Theme Settings](#theme-settings)
- [Layer Surfaces](#layer-surfaces)
- [Decoration](#decoration)
- [Window Rules](#window-rules)
- [Export Panel](#export-panel)
- [Buttons & Actions](#buttons--actions)
- [How Configuration is Written](#how-configuration-is-written)
- [Preserving `default_preset`](#preserving-default_preset)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)

---

## Overview

HyprGlass Studio is a local web UI for editing `Hyprglass.conf`. It lets you adjust every HyprGlass parameter, preview changes in a temporary kitty window, and apply the result to your live Hyprland session. The editor runs as a lightweight Python HTTP server with no external Python dependencies.

The current UI is a single-page editor with a sidebar, a central editing area, and a live export preview panel.

---

## Launching the Studio

### From the repository

```bash
cd ~/hyprglass-studio
python3 -m src.server --port 8765
```

Any free port works:

```bash
python3 -m src.server --port 9000
```

### When installed system-wide

```bash
hyprglass-studio --port 8765
```

Once running, open the displayed URL in any browser:

```
http://localhost:8765
```

---

## Interface Layout

The page is split into three columns:

| Column | Contents |
|--------|----------|
| **Sidebar** | Navigation, state badges, and **Reset to defaults**. |
| **Content** | The active section's controls. |
| **Preview** | Live generated config, output-format toggle, and default theme/preset selectors. |

### Navigation Sections

| Section | Description |
|---------|-------------|
| **Global settings** | Plugin enable switch, default theme/preset, and global glass parameters. |
| **Theme settings** | Per-theme overrides for dark and light modes. |
| **Layer surfaces** | Layer namespace whitelist/blacklist and per-namespace presets. |
| **Decoration** | Window opacity for active, inactive, and fullscreen states. |
| **Window rules** | Per-window match/action rules. |
| **Export** | Summary cards and the generated config preview. |

---

### Global Settings

Top-level toggles and global glass parameters.

| Control | Type | Default | Description |
|---|---|---|---|
| `enabled` | checkbox | `true` | Master switch — disables all glass effects when unchecked. |
| `default_theme` | select | `dark` | Theme applied at startup (`dark` or `light`). |
| `default_preset` | select | `default` | Built-in preset loaded at startup (`glass`, `subtle`, `ui`, or `default`). |
| `blur_strength` | slider | `3.4` | Blur radius scale. |
| `blur_iterations` | slider | `2` | Gaussian blur passes. |
| `refraction_strength` | slider | `0.96` | Edge refraction intensity. |
| `chromatic_aberration` | slider | `0.7` | Spectral dispersion at edges. |
| `fresnel_strength` | slider | `0.96` | Edge glow intensity. |
| `specular_strength` | slider | `0.6` | Specular highlight brightness. |
| `glass_opacity` | slider | `1.0` | Overall glass opacity. |
| `edge_thickness` | slider | `0.14` | Bezel width as a fraction of the smallest dimension. |
| `lens_distortion` | slider | `0.56` | Center dome magnification. |
| `tint_color` | color | `0x8899aa22` | Glass tint in `0xAARRGGBB` format. |

---

### Theme Settings

Separate overrides for dark and light themes. The active set depends on the `default_theme` global setting.

| Control | Range | Description |
|---|---|---|
| `brightness` | 0.2 – 1.6 | Brightness multiplier. |
| `contrast` | 0.2 – 1.6 | Contrast around the midpoint. |
| `saturation` | 0 – 1.5 | Desaturation level. |
| `vibrancy` | 0 – 1 | Selective saturation boost. |
| `vibrancy_darkness` | 0 – 1 | How much dark areas influence vibrancy. |
| `adaptive_dim` | 0 – 1 | Dims bright areas behind the glass. |
| `adaptive_boost` | 0 – 1 | Boosts dark areas behind the glass. |

---

### Layer Surfaces

Configure which Hyprland layer-shell surfaces (bars, docks, widgets) receive glass effects.

| Control | Type | Description |
|---|---|---|
| `enabled` | checkbox | Enable glass on layer surfaces. |
| `namespaces` | textarea | Comma-separated whitelist (e.g. `waybar, swaync, notifications`). |
| `exclude_namespaces` | textarea | Comma-separated blacklist. |
| `preset` | text | Default preset used by layer surfaces. |
| `namespace_presets` | textarea | Comma-separated `namespace:preset` pairs. |
| `namespace_mask_thresholds` | textarea | Comma-separated `namespace=value` opacity thresholds. |

Click **Use sample layers** to populate typical values.

---

### Decoration

Override Hyprland's `decoration` opacity values.

| Control | Range | Default | Description |
|---|---|---|---|
| `active_opacity` | 0.0 – 1.0 | `0.86` | Opacity of focused windows. Must be `< 1.0` for glass to be visible. |
| `inactive_opacity` | 0.0 – 1.0 | `0.72` | Opacity of unfocused windows. |
| `fullscreen_opacity` | 0.0 – 1.0 | `1.0` | Opacity of fullscreen windows. Usually `1.0` for no glass. |

---

### Window Rules

A rule-based system for per-window glass behavior. Each rule has a match condition, an action, and an enable toggle.

**Match syntax** uses Hyprland-style conditions:

```
class ^(waterfox)$
class ^(kitty)$
tag:browser
```

**Action syntax** can be a tag or an opacity override:

```
tag +hyprglass_enabled
opacity 0.86 0.72
```

The generated config writes each enabled rule as:

```conf
windowrule = match:<condition>, <action>
```

Use **Add rule** and **Remove** to manage the list.

---

## Export Panel

The right-hand panel shows the generated config in real time and lets you:

- Toggle output format between **CONF** (Hyprland config) and **Lua**.
- Toggle preview theme between **dark** and **light**.
- Change the `default_theme` and `default_preset` selectors.
- **Copy config** to the clipboard.
- **Download** the generated file (`hyprglass.conf` or `hyprglass.lua`).

---

## Buttons & Actions

| Button | Behaviour |
|---|---|
| **Preview** | Sends a `POST /api/preview` with the current generated config. A kitty window opens with the new config applied. When the window closes, the previous config is restored. |
| **Apply** | Sends a `POST /api/apply`. The server validates the config, writes it to `~/.config/hypr/UserConfigs/Hyprglass.conf`, and triggers `hyprctl reload`. |
| **Copy config** | Copies the current export text to the clipboard. |
| **Download** | Downloads the current export as a file. |
| **Reset to defaults** | Clears `localStorage` and reloads the built-in default state. |

---

## How Configuration is Written

When **Apply** is clicked:

1. The editor serialises the in-memory state into Hyprland config text.
2. The browser sends the full text to `POST /api/apply`.
3. The server validates the config (required blocks, numeric ranges, etc.).
4. A timestamped backup is created in `~/.config/hypr/backups/hyprglass-studio/`.
5. The server writes the config to `~/.config/hypr/UserConfigs/Hyprglass.conf`.
6. `hyprctl reload` is executed so Hyprland picks up the new settings.

The default config path is:

```
~/.config/hypr/UserConfigs/Hyprglass.conf
```

---

## Preserving `default_preset`

`src/server.py` preserves the existing `default_preset` value when applying a new config:

```python
def _preserve_default_preset(new_content: str) -> str:
    ...
    match = re.search(r"^\s*default_preset\s*=\s*(.+)$", existing, re.MULTILINE)
    if match:
        ...
        new_content = re.sub(
            r"default_preset\s*=\s*\S+",
            f"default_preset = {preset_value}",
            new_content,
            count=1,
        )
    return new_content
```

This means:

- `default_preset` is read from the existing `Hyprglass.conf` before each write.
- The Studio UI can select a preset for the exported config, but the on-disk `default_preset` is preserved across applies.
- If `default_preset` is absent from the on-disk config (fresh install), it is set to `"default"` automatically.

---

## API Reference

The Studio server exposes a small REST API. All endpoints accept and return JSON (except `GET /api/config`, which returns the raw config text inside a JSON wrapper).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | `GET` | Server status and version. |
| `/api/config` | `GET` | Raw current `Hyprglass.conf` text. |
| `/api/preview` | `POST` | Preview a config in a temporary kitty window. |
| `/api/apply` | `POST` | Validate, write, and reload a config. |

See [API.md](API.md) for full request/response details and curl examples.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Server won't start — port in use | `python3 -m src.server --port <other>` or kill the process on the occupied port. |
| Preview doesn't open | Ensure `kitty` is installed and in your `PATH`. Close any existing preview window first. |
| Apply has no visual effect | Run `hyprctl reload` manually; check `~/.config/hypr/UserConfigs/Hyprglass.conf` for syntax errors. |
| Config path is wrong | The server hard-codes `~/.config/hypr/UserConfigs/Hyprglass.conf`. Edit `src/server.py` if your layout differs. |
| Changes lost after reload | Make sure you clicked **Apply**; **Preview** is temporary and restores the old config when the window closes. |
