# Demo GIF Script

This document describes the content and timing for the demo GIF (60 seconds target).

---

## Scene Breakdown

### 0:00–0:05 — Terminal Opens with Glass Effect

- Desktop with wallpaper visible
- User launches a terminal (e.g., `kitty` or `alacritty`)
- Window appears with frosted glass transparency
- Background wallpaper subtly visible through the terminal
- Tint color matches the current wallpaper palette

### 0:05–0:12 — Switch Profiles via Rofi Menu

- Rofi menu invoked (e.g., `Super+P`)
- Menu displays available profiles: `daylight`, `midnight`, `gaming`, `focus`
- User selects a different profile (e.g., `midnight`)
- All open windows transition tint color smoothly
- Terminal glass opacity updates in real-time

### 0:12–0:20 — Wallpaper Change and Tint Update

- User changes wallpaper (e.g., via `swww img` or hyprpaper config)
- HyprGlass detects the new wallpaper
- Extracts dominant color from the new image
- Glass tint automatically shifts to match new wallpaper palette
- No manual intervention required — transition is automatic

### 0:20–0:30 — Game Detected, Glass Disables

- User launches a game (e.g., via Steam or from terminal)
- HyprGlass identifies the window as a game (by class or title)
- Glass effect disabled for that specific window
- Game renders with full opacity — no performance overhead
- Other windows retain glass effect if still open

### 0:30–0:40 — Game Exits, Glass Restores

- User closes the game
- HyprGlass detects window close event
- Glass effect automatically re-enabled for new windows
- Return to normal desktop workflow

### 0:40–0:55 — Studio UI Parameter Adjustment

- User opens HyprGlass Studio (native or web UI)
- UI displays current profile and live preview
- User adjusts:
  - Opacity slider (0.3 → 0.7)
  - Blur radius slider (5 → 15)
  - Saturation slider (1.0 → 1.3)
- Changes apply in real-time to open windows
- User clicks "Save Profile" to persist changes

### 0:55–1:00 — Final State / Logo

- All windows showing updated glass parameters
- Clean desktop shot
- HyprGlass logo overlay (optional)

---

## Notes

- Total target duration: **60 seconds**
- Music: ambient lo-fi or minimal electronic (optional)
- Resolution: 1920×1080 minimum, record at native monitor res
- Frame rate: 60fps for smooth transitions
- Export format: GIF via `ffmpeg` or `gifski`, or MP4 fallback
- Keep cursor visible throughout to guide viewer's eye
