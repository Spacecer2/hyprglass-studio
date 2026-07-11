# Frequently Asked Questions

## Table of Contents

- [General](#general)
- [Configuration](#configuration)
- [Profile System](#profile-system)
- [Wallust Integration](#wallust-integration)
- [Performance](#performance)

---

## General

### Q: What is HyprGlass?
**A:** Apple-style Liquid Glass effect for Hyprland Linux desktop

---

### Q: Does it work on all windows?
**A:** Yes, but windows need opacity < 1.0 to see the effect

---

### Q: Why does glass work on waybar but not kitty?
**A:** Layer surfaces use a different rendering path. Windows need transparency.

---

### Q: Can I use it with JaKooLit dots?
**A:** Yes, but copy.sh will overwrite configs. Run FixHyprglassSource.sh after.

---

### Q: Can I use it with other Wayland compositors?
**A:** No, Hyprland only (uses Hyprland-specific APIs)

---

## Configuration

### Q: How do I make glass more visible?
**A:** Lower active_opacity to 0.65-0.75, increase blur_strength

---

### Q: Can I have different glass for different apps?
**A:** Yes, use window rules with tags

---

### Q: How does wallust integration work?
**A:** Tint color auto-updates from wallpaper accent color

---

### Q: What are the available presets?
**A:** default, glass, subtle, ui (built-in)

---

### Q: How do I create custom presets?
**A:** Define in config with `inherits = "base_preset"`

---

### Q: Why do my settings keep reverting?
**A:** Studio server or .conf parser bug. Check FixHyprglassValues.sh.

See [Configuration Guide](CONFIGURATION.md) for detailed configuration documentation.

---

## Profile System

### Q: What is the profile system?
**A:** Profiles let you save and switch between complete glass configurations. Each profile stores opacity, blur, tint, and window rules as a named snapshot.

---

### Q: How do I switch profiles?
**A:** Use `hyprglassctl --profile <name>` or switch via the Studio UI dropdown. Profiles are stored in `~/.config/hypr/profiles/`.

---

### Q: Can profiles override window rules per-app?
**A:** Yes. Each profile can define its own window rule overrides. See [Profile Documentation](PROFILES.md).

---

### Q: What happens to unsaved changes when I switch profiles?
**A:** Unsaved tweaks are discarded. Use `hyprglassctl --save` before switching to preserve your current state.

---

### Q: Can I import/export profiles for sharing?
**A:** Yes. Use `hyprglassctl --export <name>` to create a portable JSON file, and `--import <file>` to load it.

---

## Wallust Integration

### Q: How do I enable wallust color sync?
**A:** Set `wallust.enabled = true` in your config. Requires `wallust` installed and a wallpaper loaded.

---

### Q: Can I pick a specific color from my wallpaper instead of the default accent?
**A:** Yes. Set `wallust.color_index` to select which extracted palette entry to use (0 = dominant, 1 = vibrant, etc.).

---

### Q: Wallust colors aren't updating. What's wrong?
**A:** Ensure wallust is running (`wallust run`), Hyprland signals are enabled in your `hyprland.conf`, and `wallust.hooks = true` is set.

See [Wallust Integration Guide](WALLUST-INTEGRATION.md) for full setup instructions.

---

## Performance

### Q: Does it affect performance?
**A:** Minimal on modern GPUs. Disable for gaming if needed.

---

### Q: How many windows can the glass effect handle?
**A:** Tested up to ~50 windows without frame drops. Performance depends on blur_strength and GPU capability.

See [Performance Tuning](PERFORMANCE.md) for optimization tips.

---

### Q: Why is my glass laggy on fractional scaling?
**A:** Fractional scaling forces buffer resampling. Set `render_dpi = 1` in config or use integer scaling for better results.

---

### Q: Does glass work with Hyprland's screen sharing?
**A:** Partially. Screen share captures the composited frame including glass, but may show visual artifacts on the sharer's side.

---

### Q: Can I disable glass globally without removing it?
**A:** Yes. Run `hyprglassctl --disable` to toggle off without uninstalling. Re-enable with `--enable`.
