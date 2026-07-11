# Hyprglass Studio Logo Placeholder & Usage Guide

## 1. Logo Concept

The Hyprglass Studio logo blends **liquid glass** aesthetics with the compositor-native spirit of the project.

- **Liquid glass** — soft refractions, translucent layers, and smooth gradients that evoke glassmorphism and modern desktop effects.
- **Wayland** — the form suggests a stylized "W" or wave, nodding to the protocol the studio tooling is built for.
- **Hyprland colors** — the palette pulls from Hyprland's signature cyan/magenta accents, grounding the brand in its ecosystem while keeping it distinct.

The overall mark should feel lightweight, dynamic, and at home on a tiling Wayland desktop.

## 2. SVG Placeholder Description

Until the final logo is produced, use a placeholder SVG that contains:

- A rounded rectangle or soft organic blob as the base shape.
- A semi-transparent white fill with a subtle gradient overlay.
- A thin, glowing stroke in the primary accent color.
- Optional: a small monogram letter "H" or "Hy" in the center, using the secondary accent color.

Keep the SVG flat, vector-only, and scalable without raster effects. The file should be saved as:

```
assets/logo.svg
```

## 3. Color Palette

| Token           | Hex       | Usage                              |
|-----------------|-----------|------------------------------------|
| `--hglass-bg`   | `#1E1E2E` | Dark backgrounds, app chrome       |
| `--hglass-glass`| `rgba(255,255,255,0.08)` | Glass panel fills        |
| `--hglass-cyan` | `#00E5FF` | Primary accent, glow, links        |
| `--hglass-magenta` | `#FF00AA` | Secondary accent, highlights  |
| `--hglass-white`| `#EAEAEA` | Primary text on dark backgrounds   |

Use cyan and magenta sparingly as accents; the majority of each asset should remain dark/glass.

## 4. Icon Sizes Needed

Generate rasterized icons from the final SVG in the following square sizes:

- 16 × 16 px
- 32 × 32 px
- 48 × 48 px
- 128 × 128 px
- 256 × 256 px
- 512 × 512 px

Store PNG exports under:

```
assets/icons/
```

Name them consistently, e.g. `icon-16x16.png`, `icon-256x256.png`.

## 5. Favicon Instructions

Create a favicon package from the 32 × 32 px and 16 × 16 px icons.

Recommended output:

- `favicon.ico` — multi-resolution ICO containing 16 × 16 and 32 × 32 px.
- `favicon-16x16.png`
- `favicon-32x32.png`
- `apple-touch-icon.png` — 180 × 180 px export from the 512 × 512 source.

Place favicon files in the project web root or public directory:

```
public/
├── favicon.ico
├── favicon-16x16.png
├── favicon-32x32.png
└── apple-touch-icon.png
```

Link them in HTML `<head>`:

```html
<link rel="icon" type="image/x-icon" href="/favicon.ico">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
```
