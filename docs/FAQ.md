# Frequently Asked Questions

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

---

## Performance

### Q: Does it affect performance?
**A:** Minimal on modern GPUs. Disable for gaming if needed.
