# Session Profiles

Profiles are named collections of glass settings that let you switch between different visual configurations instantly. Each profile is a Hyprland-style `.conf` file using `$`-prefixed variables. Profiles are applied at runtime with the `HyprglassProfile.sh` helper.

## Built-in Profiles

| Profile | Description |
|---------|-------------|
| `default` | Full glass, balanced settings. The standard configuration. |
| `gaming` | Disabled or subtle glass. Maximizes FPS by minimizing GPU compositing. |
| `coding` | Subtle glass with high readability. Reduced blur, higher contrast text. |
| `movies` | Minimal glass, cinema mode. Near-transparent overlays to avoid distraction. |

## Profile Storage

Installed profiles live in:

```
~/.config/hypr/hyprglass-profiles/
```

The installer copies the bundled profiles there. You can add your own `.conf` files to the same directory.

## Profile File Format

Profiles use Hyprland configuration syntax with `$`-prefixed namespaced variables.

### Minimal Example

```conf
# HyprGlass Studio profile

# Profile identity
$name = coding
$version = 1.0.0
$inherits = default

# Metadata
$metadata.author = Your Name
$metadata.description = Subtle glass for focused work

# Glass effect settings
$glass.blur_strength = 1.5
$glass.blur_iterations = 1
$glass.refraction_strength = 0.4
$glass.chromatic_aberration = 0.1
$glass.fresnel_strength = 0.3
$glass.specular_strength = 0.2
$glass.glass_opacity = 0.8
$glass.edge_thickness = 0.05
$glass.lens_distortion = 0.1

# Theme settings
$theme.dark.brightness = 1.05
$theme.dark.contrast = 1.3
$theme.dark.saturation = 1.0
$theme.dark.vibrancy = 0.5
$theme.dark.vibrancy_darkness = 0.3
$theme.dark.adaptive_dim = 0.4
$theme.dark.adaptive_boost = 0.2

# Decoration settings
$decoration.active_opacity = 0.88
$decoration.inactive_opacity = 0.78

# Window rules
$window_rules.fullscreen.match = fullscreen:1
$window_rules.fullscreen.action = disable
$window_rules.fullscreen.reason = Fullscreen windows - glass disabled for unobstructed view

$window_rules.fallback.action = default
$window_rules.fallback.reason = All other windows use the profile defaults
```

### Namespaces

| Namespace | Maps to | Example |
|-----------|---------|---------|
| `$glass.*` | `plugin:hyprglass:*` | `$glass.blur_strength` → `plugin:hyprglass:blur_strength` |
| `$theme.dark.*` / `$theme.light.*` | `dark:*` / `light:*` | `$theme.dark.brightness` → `dark:brightness` |
| `$decoration.*` | `decoration:*` | `$decoration.active_opacity` → `decoration:active_opacity` |
| `$window_rules.<name>.*` | `windowrulev2` tags | See [Window Rules](#window-rules) below |

## Switching Profiles

### Keybinds

The installer adds these keybindings (JaKooLit layout uses `Keybinds.conf`):

```
SUPER + G             Cycle to next profile
SUPER + SHIFT + G     Open rofi profile menu
```

### Rofi Menu

```bash
~/.config/hypr/scripts/HyprglassProfile.sh menu
```

Displays an interactive menu of available profiles using the bundled rofi theme.

### Command Line

```bash
# List profiles
~/.config/hypr/scripts/HyprglassProfile.sh list

# Apply a profile
~/.config/hypr/scripts/HyprglassProfile.sh apply gaming

# Show the currently active profile
~/.config/hypr/scripts/HyprglassProfile.sh current

# Cycle to the next profile
~/.config/hypr/scripts/HyprglassProfile.sh next
```

### Hyprglass Studio UI

The Studio UI exports full configuration snapshots, but it does not save or load named `.conf` profiles directly. Use `HyprglassProfile.sh` for profile switching, or copy an exported `.conf` into `~/.config/hypr/hyprglass-profiles/`.

## Auto-Switching

Automatic profile switching is provided by `HyprglassGPUMonitor.sh` (GPU-load based) and by the per-window rules inside each profile. There is no separate `auto-rules.json` file.

### GPU-Driven Auto-Switch

`HyprglassGPUMonitor.sh` polls GPU utilization and switches to the `gaming` profile when load is high, then restores the previous profile when load drops. See [GPU-MONITOR.md](GPU-MONITOR.md) for setup and environment variables.

### Window-Rule-Driven Auto-Switch

Each profile can contain `$window_rules` entries that tag windows for the plugin. The action determines which tag is applied:

| Action | Tag applied | Effect |
|--------|-------------|--------|
| `disable` | `+hyprglass_disabled` | No glass on matching windows |
| `subtle` / `minimal` | `+hyprglass_preset_subtle` | Reduced glass |
| `full` / `default` | `+hyprglass_enabled` | Full profile glass |
| `ui` | `+hyprglass_preset_ui` | Flat UI preset |

Example rules from a profile:

```conf
$window_rules.games.match = class:^steam_app_.+$,class:^gamescope$
$window_rules.games.action = disable
$window_rules.games.reason = Games - glass disabled for performance

$window_rules.video_players.match = class:^(mpv|vlc|celluloid)$
$window_rules.video_players.action = minimal
$window_rules.video_players.reason = Video players - minimal glass
$window_rules.video_players.overrides.blur_strength = 1.0
$window_rules.video_players.overrides.glass_opacity = 0.3
$window_rules.video_players.overrides.active_opacity = 0.95
```

### Common Auto-Switch Patterns

| Condition | Recommended Profile / Rule | Reason |
|-----------|---------------------------|--------|
| Fullscreen windows | `$window_rules.fullscreen.action = disable` | Reduce compositing overhead |
| Steam games (`steam_app_*`) | `$window_rules.games.action = disable` | Maximize performance |
| Video players (mpv, vlc) | `$window_rules.video_players.action = minimal` | Avoid visual distraction |
| Browsers | `$window_rules.browsers.action = full` | Full glass aesthetic |
| Terminal emulators | `$window_rules.terminals.action = subtle` | Readability first |

## Creating Custom Profiles

### Profile File Structure

Create a new file in `~/.config/hypr/hyprglass-profiles/` with a `.conf` extension. The filename (without `.conf`) becomes the profile name.

```
~/.config/hypr/hyprglass-profiles/
├── default.conf
├── gaming.conf
├── coding.conf
├── movies.conf
├── minimal.conf          ← your custom profile
└── work-focus.conf       ← another custom profile
```

### Required Identity Fields

```conf
$name = minimal
$version = 1.0.0
$inherits = default
```

`$inherits` is reserved for future inheritance support; currently each profile should define the values it needs.

### Available Settings

```conf
# Glass effect settings
$glass.blur_strength = 3.4
$glass.blur_iterations = 2
$glass.refraction_strength = 0.96
$glass.chromatic_aberration = 0.7
$glass.fresnel_strength = 0.96
$glass.specular_strength = 0.6
$glass.glass_opacity = 1.0
$glass.edge_thickness = 0.14
$glass.lens_distortion = 0.42

# Theme settings (dark theme shown; light is analogous)
$theme.dark.brightness = 1.1
$theme.dark.contrast = 1.2
$theme.dark.saturation = 1.15
$theme.dark.vibrancy = 0.7
$theme.dark.vibrancy_darkness = 0.52
$theme.dark.adaptive_dim = 0.65
$theme.dark.adaptive_boost = 0.34

# Decoration settings
$decoration.active_opacity = 0.75
$decoration.inactive_opacity = 0.65
```

### Window Rules

Rules are grouped under `$window_rules.<name>` and support these fields:

| Field | Description |
|-------|-------------|
| `match` | Comma-separated Hyprland windowrulev2 conditions |
| `action` | `disable`, `subtle`, `minimal`, `full`, `default`, or `ui` |
| `reason` | Human-readable description |
| `overrides.<key>` | Optional per-rule overrides applied after the profile |

```conf
$window_rules.terminals.match = class:^(kitty|Alacritty|wezterm|foot|ghostty)$
$window_rules.terminals.action = subtle
$window_rules.terminals.reason = Terminals - subtle glass for readability
$window_rules.terminals.overrides.blur_strength = 2.0
$window_rules.terminals.overrides.glass_opacity = 0.7
$window_rules.terminals.overrides.active_opacity = 0.85
$window_rules.terminals.overrides.inactive_opacity = 0.75
```

## Profile + Wallust Interaction

Profiles and wallust serve complementary roles:

- **Profiles** control the structural glass settings (blur, opacity, saturation, theme overrides).
- **Wallust** controls the color scheme (tint color, brightness calibration).

### How Tint Auto-Updates

Wallust writes `~/.cache/.hyprglass_wallust.json` with extracted colors. The startup fix script (`FixHyprglassValues.sh`) applies `tint_color` and `dark:brightness` from that cache. To disable auto-tint, remove or comment out the wallust cache handling in `FixHyprglassValues.sh`.

### Pinning a Tint Color

Set `$glass.tint_color` in the profile (or in `Hyprglass.conf`) to a fixed `0xAARRGGBB` value. If a static tint is present, the wallust cache will not override it unless the startup script is configured to do so.

```conf
$glass.tint_color = 0x881a1a2e
```

### Interaction Table

| Profile Setting | Wallust Setting | Behavior |
|----------------|-----------------|----------|
| No `$glass.tint_color` in profile | Wallust cache present | Startup script applies wallust tint |
| `$glass.tint_color = 0xAARRGGBB` | Wallust cache present | Profile tint is applied by `HyprglassProfile.sh`; wallust cache handled separately at startup |
| `$theme.dark.brightness` set | Wallust brightness present | Profile brightness takes precedence when profile is applied |
