# HyprGlass Studio — Architecture

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HyprGlass Studio                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────────────────┐ │
│  │  JS Frontend │◄─►│ Python Server│◄─►│  HyprGlass.conf (disk)  │ │
│  │  (Browser)   │   │  server.py   │   └───────────┬─────────────┘ │
│  └──────────────┘   └──────┬───────┘               │               │
│                            │                       ▼               │
│                     ┌──────▼───────┐   ┌─────────────────────────┐ │
│                     │   wallust    │   │  hyprctl reload         │ │
│                     │  (colors)    │   └───────────┬─────────────┘ │
│                     └──────┬───────┘               │               │
│                            │                       ▼               │
│                            │           ┌─────────────────────────┐ │
│                            └──────────►│  hyprglass plugin       │ │
│                                        │  (C++ render hooks)     │ │
│                                        └─────────────────────────┘ │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────────────────────────┐   │
│  │ Profile System   │   │ FixHyprglassValues.sh                │   │
│  │ (shell + config) │   │ (parser bug workaround)              │   │
│  └──────────────────┘   └──────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. Component Breakdown

### 2.1 HyprGlass Plugin (C++)

The core rendering engine. Compiled as a Hyprland plugin that registers render hooks on decoration layers and layer surfaces.

**Key responsibilities:**
- Registers `DECORATION_LAYER_BOTTOM` for window decorations — applies glass tint/blur behind window content
- Hooks `renderLayer` for layer surfaces (panels, bars, notifications) to apply consistent glass effects
- Reads tint color and opacity values from `HyprGlass.conf` at render time
- Uses FBO (Framebuffer Object) redirect to composite blur + tint in a single pass

**Dependencies:** Hyprland APIs, OpenGL ES / EGL, `hyprland-plugin-sdk`

### 2.2 HyprGlass Studio (Python Server + JS Frontend)

The configuration UI. Lets users visually adjust glass parameters and see changes live.

**server.py** — Lightweight Python HTTP/WebSocket server:
- Serves the JS frontend
- Exposes REST endpoints for reading/writing `HyprGlass.conf`
- Triggers `hyprctl reload` after config changes for instant feedback
- Optionally invokes wallust to regenerate color palettes from the current wallpaper
- Manages profile state (load/save/switch)

**JS Frontend** — Single-page UI:
- Color picker, opacity sliders, blur radius controls
- Live preview updates via WebSocket push
- Profile selector with one-click toggling
- Wallpaper-triggered color scheme preview

### 2.3 Wallust Integration (Template System)

Bridges wallpaper analysis to glass tinting.

**Flow:**
1. Detects or is told the current wallpaper path
2. Runs wallust to extract a color palette (dominant colors, ANSI set, terminal colors)
3. Applies Jinja-style templates (`templates/`) to map palette entries to HyprGlass.conf values
4. Writes the rendered output to `HyprGlass.conf`

**Template files** define mappings like:
```
glass_tint = {{ colors[0] }}
glass_opacity = {{ opacity | default(0.15) }}
```

### 2.4 Profile System (Shell Scripts + Config Files)

Manages named configurations that can be toggled at runtime.

**Structure:**
- `profiles/` — directories or files, one per profile (e.g., `profiles/dark.conf`, `profiles/light.conf`)
- Each profile is a complete or delta `HyprGlass.conf`
- Toggle scripts source the selected profile and apply it via `hyprctl keyword`

**Typical profile:**
```ini
plugin:hyprglass {
    enabled = true
    glass_opacity = 0.12
    glass_tint = rgb(1e1e2e)
    glass_blur = 5
    glass_rounding = 10
}
```

### 2.5 FixHyprglassValues.sh

Workaround script for known `.conf` parser bugs (see §5.1).

**Purpose:** Post-processes `HyprGlass.conf` to fix values that the Hyprland config parser incorrectly handles — such as misinterpreting certain color formats or clamping float ranges. Runs after every config write and before `hyprctl reload`.

**Mechanism:**
- Reads the raw conf file
- Applies sed/awk transformations to correct known problem patterns
- Overwrites the file in place
- Issues `hyprctl reload`

## 3. Data Flow

### 3.1 Wallpaper → Tint

```
Wallpaper set
     │
     ▼
wallust analyzes image
     │
     ▼
Color palette generated
     │
     ▼
Template rendering (templates/)
     │
     ▼
HyprGlass.conf written
     │
     ▼
hyprctl reload
     │
     ▼
Plugin picks up new tint values
     │
     ▼
Glass effect re-rendered with new colors
```

### 3.2 User → Studio UI → Config

```
User adjusts slider in browser
     │
     ▼
JS frontend sends new value via WebSocket/REST
     │
     ▼
server.py receives update
     │
     ▼
server.py writes HyprGlass.conf
     │
     ▼
FixHyprglassValues.sh runs (if enabled)
     │
     ▼
hyprctl reload
     │
     ▼
Plugin re-reads config, re-renders
```

### 3.3 Profile Toggle

```
User clicks profile in UI (or runs toggle script)
     │
     ▼
Profile script selected (profiles/)
     │
     ▼
hyprctl keyword plugin:hyprglass <key> <value>
     │
     ▼
Plugin receives keyword update in-memory
     │
     ▼
Immediate re-render (no full reload needed)
```

## 4. Plugin Rendering Pipeline

### 4.1 Window Decorations

```
┌─────────────────────────────────────┐
│           Window Content            │
├─────────────────────────────────────┤
│  ▲ DECORATION_LAYER_TOP            │
│  │  (border glow, shadows)         │
├─────────────────────────────────────┤
│  ▼ DECORATION_LAYER_BOTTOM         │
│     (glass tint + blur)            │  ◄── hyprglass renders here
│     Requires: window opacity < 1.0 │
└─────────────────────────────────────┘
```

- The plugin registers a render callback on `DECORATION_LAYER_BOTTOM`
- Before the window's own content draws, the plugin:
  1. Captures the scene behind the window into an FBO
  2. Applies Gaussian blur (configurable radius)
  3. Overlays the tint color at configured opacity
  4. Draws the composited result as the decoration background
- **Transparency requirement:** The window must have `opacity < 1.0` for the glass layer to be visible. Fully opaque windows hide the effect entirely.

### 4.2 Layer Surfaces (Panels, Bars)

```
┌─────────────────────────────────────┐
│         Layer Surface               │
│  ┌───────────────────────────────┐  │
│  │  renderLayer hook             │  │
│  │  ├─ FBO capture              │  │
│  │  ├─ Blur pass                │  │
│  │  ├─ Tint overlay             │  │
│  │  └─ Return composited FBO    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

- For layer-shell surfaces (ags/eww bars, hyprland notification popups), the plugin hooks `renderLayer`
- The hook redirects rendering to an off-screen FBO, applies the same blur+tint pipeline, then returns the result to the compositor
- This ensures layer surfaces get the same glass aesthetic as regular windows

## 5. Known Limitations

### 5.1 `.conf` Parser Bugs (Issue #34)

Hyprland's config parser has edge cases that corrupt hyprglass-specific values:

- **Color format parsing:** Some `rgb()` / `rgba()` formats may be misinterpreted when passed through the plugin keyword system
- **Float precision:** Values like `0.12` may be truncated or rounded unexpectedly
- **Quoting sensitivity:** String values with special characters may need escaping that the parser doesn't handle consistently

**Mitigation:** `FixHyprglassValues.sh` rewrites known problem patterns after each config save.

### 5.2 Preset Clobbering Individual Values

When applying a preset (e.g., via `hyprctl keyword plugin:hyprglass preset ...`), the plugin replaces the entire glass configuration block. Any individually tuned values (custom tint, specific opacity) are overwritten.

**Workaround:** Save your current settings as a named profile before applying presets. Restore after if needed.

### 5.3 Glass Requires Opacity < 1.0

The glass effect is only visible when the target surface has opacity below 1.0. This is a fundamental constraint of the rendering approach — the plugin renders *behind* the window content, and a fully opaque surface hides everything underneath.

**Implications:**
- Terminal emulators, file managers, and other apps must be configured with transparency for glass to show
- Some applications override window opacity (e.g., Electron apps with `--disable-transparent-visuals`)
- User must set both the window rule opacity *and* the glass opacity for the combined effect to look correct
