# Configuration Reference

HyprGlass is configured through Hyprland's config file using the `plugin:hyprglass` block, theme settings, layer rules, and window tags. All values have sensible defaults and can be overridden per-session or per-profile.

## Plugin Config Block

Add a `plugin:hyprglass` section to your `hyprland.conf`:

```conf
plugin:hyprglass {
    enabled = 1
    default_theme = dark
    default_preset = default
    blur_strength = 2.0
    blur_iterations = 3
    refraction_strength = 0.6
    chromatic_aberration = 0.5
    fresnel_strength = 0.6
    specular_strength = 0.8
    glass_opacity = 1.0
    edge_thickness = 0.06
    lens_distortion = 0.5
    tint_color = 0x8899aa22
}
```

### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `enabled` | int | `0`/`1` | `1` | Enable or disable the plugin entirely. |
| `default_theme` | string | `dark`/`light` | `dark` | Theme applied at startup. |
| `default_preset` | string | `default`/`glass`/`subtle`/`ui` | `default` | Preset applied at startup. The built-in presets are `default` (balanced), `glass` (strong), `subtle` (minimal), and `ui` (flat). |
| `blur_strength` | float | `0`–`10` | `2.0` | Intensity of the background blur. |
| `blur_iterations` | int | `1`–`5` | `3` | Number of blur passes (higher = smoother, costs more GPU). |
| `refraction_strength` | float | `0`–`2` | `0.6` | Strength of the light-bending effect through glass. |
| `chromatic_aberration` | float | `0`–`3` | `0.5` | Color fringing on high-contrast edges. |
| `fresnel_strength` | float | `0`–`2` | `0.6` | Edge-vs-center reflectivity (simulates glass angle). |
| `specular_strength` | float | `0`–`2` | `0.8` | Intensity of specular highlights. |
| `glass_opacity` | float | `0`–`1` | `1.0` | Global opacity multiplier for glass surfaces. |
| `edge_thickness` | float | `0`–`1` | `0.06` | Width of the bright edge line on glass borders. |
| `lens_distortion` | float | `0`–`1` | `0.5` | Subtle magnification warping through the glass. |
| `tint_color` | hex | `0xAARRGGBB` | `0x8899aa22` | ARGB color applied as a tint over glass. |

## Theme Settings

HyprGlass supports automatic dark/light switching. Theme values are applied as Hyprland decoration overrides at runtime.

### Dark Theme

```conf
dark:brightness = 0.8192
dark:contrast = 0.8914
dark:saturation = 1.1911
dark:vibrancy = 0.369
dark:vibrancy_darkness = 0.6918
dark:adaptive_dim = 0.0
dark:adaptive_boost = 0.0
```

### Light Theme

```conf
light:brightness = 1.0
light:contrast = 1.0
light:saturation = 1.0
light:vibrancy = 0.2
light:vibrancy_darkness = 0.3
light:adaptive_dim = 0.0
light:adaptive_boost = 0.0
```

### Theme Parameters

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| `brightness` | float | `0`–`2` | Adjusts overall brightness of glass surfaces. |
| `contrast` | float | `0`–`2` | Adjusts contrast to maintain readability. |
| `saturation` | float | `0`–`2` | Controls color saturation of background content. |
| `vibrancy` | float | `0`–`1` | Boosts vibrancy of colors behind glass. |
| `vibrancy_darkness` | float | `0`–`1` | Controls how much dark areas are affected by vibrancy. |
| `adaptive_dim` | float | `0`–`1` | Dims background proportionally to content contrast. |
| `adaptive_boost` | float | `0`–`1` | Brightens background when glass is over dark content. |

## Layer Settings

Control which Hyprland layers receive glass effects.

```conf
layers:enabled = 1
layers:namespaces = layer:surface, layer:wallpaper
layers:exclude_namespaces = layer:notifications
layers:preset = default
layers:namespace_presets = layer:surface=glass, layer:notifications=subtle
layers:namespace_mask_thresholds = layer:surface:0.3, layer:wallpaper:0.1
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | int | Enable glass on layer surfaces (`0`/`1`). |
| `namespaces` | list | Comma-separated layer namespaces to apply glass to. |
| `exclude_namespaces` | list | Comma-separated layer namespaces to skip. |
| `preset` | string | Default preset for all matched layers. |
| `namespace_presets` | map | Per-namespace preset overrides (`namespace=preset`). |
| `namespace_mask_thresholds` | map | Opacity thresholds per namespace below which glass is hidden. |

## Decoration Overrides

HyprGlass modifies Hyprland's decoration values. Set these in the `decoration` block for recommended glass behavior:

```conf
decoration {
    active_opacity = 0.75
    inactive_opacity = 0.65
}
```

These values ensure windows are transparent enough for the glass effect to show through while keeping content readable.

## Window Rules

HyprGlass uses Hyprland tags to control per-window glass behavior.

### Tags

| Tag | Effect |
|-----|--------|
| `+hyprglass_enabled` | Force glass on this window, even if excluded by default. |
| `+hyprglass_disabled` | Disable glass for this window entirely. |
| `+hyprglass_preset_glass` | Apply the `glass` preset to this window. |
| `+hyprglass_preset_subtle` | Apply the `subtle` preset to this window. |
| `+hyprglass_preset_ui` | Apply the `ui` preset to this window. |

### Example Rules

```conf
windowrulev2 = tag +hyprglass_disabled, class:^(firefox)$
windowrulev2 = tag +hyprglass_preset_subtle, class:^(kitty)$
windowrulev2 = tag +hyprglass_enabled, class:^(thunar)$
```

## Presets

Presets are named bundles of plugin parameters. The built-in presets are:

| Preset | Description |
|--------|-------------|
| `default` | Balanced glass. Full blur, standard refraction and tint. This is the startup default. |
| `glass` | Stronger glass effect. Higher refraction, more specular, thicker edges. |
| `subtle` | Minimal glass. Reduced blur, lower opacity, almost transparent. |
| `ui` | Flat UI style. Minimal blur, no refraction, clean surfaces. |

Presets can be applied globally via `default_preset`, per-layer via `namespace_presets`, or per-window via tags.

> **Note:** The Studio UI preset selector only lists `glass`, `subtle`, and `ui`. Selecting one of those changes the exported config; `default` is preserved as the on-disk startup value by the server guard.

## Complete Example Config

```conf
# ─── HyprGlass Configuration ───────────────────────────────────────

plugin:hyprglass {
    enabled = 1
    default_theme = dark
    default_preset = default
    blur_strength = 2.0
    blur_iterations = 3
    refraction_strength = 0.6
    chromatic_aberration = 0.5
    fresnel_strength = 0.6
    specular_strength = 0.8
    glass_opacity = 1.0
    edge_thickness = 0.06
    lens_distortion = 0.5
    tint_color = 0x8899aa22
}

# ─── Dark Theme ────────────────────────────────────────────────────

dark:brightness = 0.8192
dark:contrast = 0.8914
dark:saturation = 1.1911
dark:vibrancy = 0.369
dark:vibrancy_darkness = 0.6918
dark:adaptive_dim = 0.0
dark:adaptive_boost = 0.0

# ─── Light Theme ───────────────────────────────────────────────────

light:brightness = 1.0
light:contrast = 1.0
light:saturation = 1.0
light:vibrancy = 0.2
light:vibrancy_darkness = 0.3
light:adaptive_dim = 0.0
light:adaptive_boost = 0.0

# ─── Layer Settings ────────────────────────────────────────────────

layers:enabled = 1
layers:namespaces = layer:surface
layers:exclude_namespaces = layer:notifications
layers:preset = default
layers:namespace_presets = layer:surface=glass
layers:namespace_mask_thresholds = layer:surface:0.3

# ─── Decoration ────────────────────────────────────────────────────

decoration {
    active_opacity = 0.75
    inactive_opacity = 0.65
}

# ─── Window Rules ──────────────────────────────────────────────────

windowrulev2 = tag +hyprglass_disabled, class:^(firefox)$
windowrulev2 = tag +hyprglass_preset_subtle, class:^(kitty)$
windowrulev2 = tag +hyprglass_enabled, class:^(thunar)$
```
