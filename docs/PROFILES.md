# Session Profiles

Profiles are named collections of glass settings that let you switch between different visual configurations instantly. Each profile stores values for blur, opacity, saturation, and other glass parameters.

## Built-in Profiles

| Profile | Description |
|---------|-------------|
| `default` | Full glass, balanced settings. The standard configuration. |
| `gaming` | Disabled or subtle glass. Maximizes FPS by minimizing GPU compositing. |
| `coding` | Subtle glass with high readability. Reduced blur, higher contrast text. |
| `movies` | Minimal glass, cinema mode. Near-transparent overlays to avoid distraction. |

## Profile File Format

Profiles are stored as JSON or YAML in `~/.config/hyprglass/profiles/`.

### JSON Example

```json
{
  "name": "coding",
  "description": "Subtle glass for focused work",
  "blur": {
    "enabled": true,
    "size": 3,
    "passes": 1,
    "noise": 0.0,
    "contrast": 0.9,
    "brightness": 0.8,
    "vibrancy": 0.2,
    "vibrancy_darkness": 0.2
  },
  "opacity": {
    "active_opacity": 0.92,
    "inactive_opacity": 0.88,
    "fullscreen_opacity": 1.0
  },
  "decoration": {
    "rounding": 8,
    "shadow": {
      "enabled": false
    }
  },
  "animation": {
    "speed": 4,
    "style": "slide"
  },
  "saturation": 0.95
}
```

### YAML Example

```yaml
name: coding
description: Subtle glass for focused work
blur:
  enabled: true
  size: 3
  passes: 1
  noise: 0.0
  contrast: 0.9
  brightness: 0.8
  vibrancy: 0.2
  vibrancy_darkness: 0.2
opacity:
  active_opacity: 0.92
  inactive_opacity: 0.88
  fullscreen_opacity: 1.0
decoration:
  rounding: 8
  shadow:
    enabled: false
animation:
  speed: 4
  style: slide
saturation: 0.95
```

## Switching Profiles

### Keybind

```
SUPER + SHIFT + H     Cycle through profiles
SUPER + CTRL + H      Reset to default profile
```

### Rofi Menu

```bash
hyprglass-profile rofi
```

Displays an interactive menu of available profiles.

### Hyprglass Studio UI

Open Hyprglass Studio and select a profile from the Profiles panel. Changes apply immediately.

### Command Line

```bash
# Apply a profile
hyprglass-profile apply gaming

# Show current profile
hyprglass-profile current

# List all available profiles
hyprglass-profile list

# Create a new profile from current settings
hyprglass-profile save my-profile
```

## Auto-Switching Rules

Hyprglass can automatically switch profiles based on the active window. Rules are defined in `~/.config/hyprglass/auto-rules.json`:

```json
[
  {
    "match": {
      "class": "^(steam_app_.*)$"
    },
    "profile": "gaming",
    "priority": 100
  },
  {
    "match": {
      "class": "^(mpv|vlc|celluloid)$"
    },
    "profile": "movies",
    "priority": 90
  },
  {
    "match": {
      "class": "^(firefox|google-chrome|chromium|brave)$"
    },
    "profile": "default",
    "priority": 50
  },
  {
    "match": {
      "fullscreen": true
    },
    "profile": "gaming",
    "priority": 80
  },
  {
    "match": {
      "class": "^(kitty|alacritty|foot|wezterm)$"
    },
    "profile": "coding",
    "priority": 60
  }
]
```

### Priority Rules

Higher priority wins when multiple rules match. If no rule matches, the manual/default profile is used.

### Common Auto-Switch Patterns

| Condition | Recommended Profile | Reason |
|-----------|-------------------|--------|
| Fullscreen windows | `gaming` | Reduce compositing overhead |
| Steam games (`steam_app_*`) | `gaming` | Maximize performance |
| Video players (mpv, vlc) | `movies` | Avoid visual distraction |
| Browsers | `default` | Full glass aesthetic |
| Terminal emulators | `coding` | Readability first |

## Creating Custom Profiles

### Profile File Structure

Create a new file in `~/.config/hyprglass/profiles/` with a `.json` or `.yaml` extension. The filename becomes the profile name.

```
~/.config/hyprglass/profiles/
├── default.json
├── gaming.json
├── coding.json
├── movies.json
├── minimal.json          ← your custom profile
└── work-focus.yaml       ← another custom profile
```

### Available Settings

```json
{
  "name": "string",
  "description": "string",
  "blur": {
    "enabled": true,
    "size": 6,
    "passes": 2,
    "noise": 0.02,
    "contrast": 0.9,
    "brightness": 0.8,
    "vibrancy": 0.2,
    "vibrancy_darkness": 0.15
  },
  "opacity": {
    "active_opacity": 0.85,
    "inactive_opacity": 0.75,
    "fullscreen_opacity": 1.0
  },
  "decoration": {
    "rounding": 12,
    "shadow": {
      "enabled": true,
      "range": 15,
      "render_power": 3,
      "color": "rgba(0,0,0,0.4)"
    }
  },
  "animation": {
    "speed": 5,
    "style": "slide"
  },
  "saturation": 1.0,
  "tint_color": "auto",
  "tint_strength": 0.15
}
```

### Inheritance from Default

Profiles inherit missing values from `default.json`. You only need to specify values you want to override:

```json
{
  "name": "minimal",
  "description": "Almost invisible glass",
  "blur": {
    "size": 2,
    "passes": 1
  },
  "opacity": {
    "active_opacity": 0.95
  }
}
```

This inherits `blur.noise`, `blur.contrast`, `blur.brightness`, `blur.vibrancy`, and all `decoration`/`animation` settings from the default profile.

## Profile + Wallust Interaction

Profiles and wallust serve complementary roles:

- **Profiles** control the structural glass settings (blur, opacity, saturation, animation).
- **Wallust** controls the color scheme (window borders, tint colors, active/inactive highlights).

### How tint_color Auto-Updates

When `tint_color` is set to `"auto"` in a profile, Hyprglass queries wallust for the current background or accent color and uses it as the tint. This means:

1. When wallust updates your wallpaper, the tint color follows automatically.
2. You can change wallpapers without editing profile files.
3. The structural settings (blur, opacity) remain unchanged.

```json
{
  "name": "default",
  "tint_color": "auto",
  "tint_strength": 0.15
}
```

To pin a specific tint color instead of using wallust:

```json
{
  "name": "movies",
  "tint_color": "#1a1a2e",
  "tint_strength": 0.25
}
```

### Interaction Table

| Profile Setting | Wallust Setting | Behavior |
|----------------|-----------------|----------|
| `tint_color: "auto"` | `colors.wallust` | Wallust provides color, profile provides strength |
| `tint_color: "#hex"` | Any | Profile color is used, wallust ignored |
| `tint_strength` | `colors.alpha` | Profile strength takes precedence |
