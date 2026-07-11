# Theme Presets

Theme presets are reusable color tunings for Hyprglass. Each preset changes the
tint color, brightness, contrast, saturation, and vibrancy settings to give
your desktop a distinct look while keeping the same underlying glass profile.

## Built-in Themes

| Theme | Description |
|-------|-------------|
| `midnight` | Deep blue glass effect for late-night sessions. |
| `amber` | Warm orange glass effect for a cozy glow. |
| `forest` | Green tinted glass effect inspired by nature. |
| `nord` | Cool blue-gray glass using the Nord color palette. |
| `dracula` | Purple-tinted glass using the Dracula color palette. |

## Applying a Theme

### Command Line

```bash
# Apply a theme preset
hyprglass-profile theme midnight

# List available themes
hyprglass-profile theme-list

# Show the current theme
hyprglass-profile theme-current
```

### Hyprglass Studio UI

Open Hyprglass Studio and select a theme from the Themes panel. The active
theme is applied immediately and remembered across sessions.

## Theme File Format

Themes are stored as plain `.conf` files in `profiles/themes/` using
Hyprland-style `$`-prefixed variables.

```conf
# HyprGlass theme preset: midnight
# Deep blue glass effect

# Theme identity
$name = midnight
$metadata.author = HyprGlass Studio
$metadata.description = Deep blue glass effect for late-night sessions

# Theme parameters
$theme.midnight.brightness = 0.78
$theme.midnight.contrast = 1.15
$theme.midnight.saturation = 1.25
$theme.midnight.vibrancy = 0.50
$theme.midnight.vibrancy_darkness = 0.68
$theme.midnight.adaptive_dim = 0.60
$theme.midnight.adaptive_boost = 0.20

# Glass tint color (0xAARRGGBB)
$glass.tint_color = 0x881a2f55
```

### Required Fields

| Variable | Purpose |
|----------|---------|
| `$name` | Theme identifier. Must match the filename without `.conf`. |
| `$metadata.author` | Author of the theme. |
| `$metadata.description` | Short description shown in listings. |
| `$theme.<name>.<key>` | Color tuning parameters applied as `<key> <value>` to Hyprland. |
| `$glass.tint_color` | Glass tint in `0xAARRGGBB` format. |

## Creating Custom Themes

1. Copy an existing theme file from `profiles/themes/`.
2. Rename it to your theme name, e.g. `sunset.conf`.
3. Update `$name` to match the filename.
4. Adjust the `$theme.<name>.*` and `$glass.tint_color` values.
5. Run `hyprglass-profile theme sunset` to preview it.

### Tint Color Format

Tint colors use Hyprland's `0xAARRGGBB` format:

- `AA` — alpha/transparency (00 = fully transparent, FF = fully opaque)
- `RR` — red channel
- `GG` — green channel
- `BB` — blue channel

For example, `0x88bd93f9` is a semi-transparent purple from the Dracula palette.

## Theme + Profile Interaction

Themes and profiles work together:

- **Profiles** control structural glass settings such as blur strength, opacity,
  and window rules.
- **Themes** control color tuning and tint.

When you apply a theme, the active profile stays in place and only the color
settings change. To switch both structure and color, apply a profile first and
then apply a theme.

## Theme Storage Locations

Themes are looked up in the following order:

1. `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprglass-profiles/themes/`
2. `<script-dir>/profiles/themes/` (bundled presets)

Custom themes should be placed in your config directory so they are not
overwritten on update.
