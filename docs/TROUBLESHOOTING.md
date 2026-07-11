# Troubleshooting

Common issues and their solutions for Hyprglass Studio.

---

## Glass not visible on windows

**Symptom:** The glass effect appears on Waybar and panels but not on application windows.

**Cause:** Windows have `active_opacity = 1.0` by default, which makes them fully opaque. The glass effect renders behind windows because it sits on `DECORATION_LAYER_BOTTOM`.

**Fix:**

```ini
decoration {
    active_opacity = 0.75
}
```

**Why this works:** Reducing opacity makes the window semi-transparent, allowing the glass layer beneath it to show through.

---

## Glass only works on waybar, not windows

**Symptom:** Glass effect works on Waybar and some panels but not on application windows.

**Cause:** `blur:xray = true` conflicts with how Hyprglass renders. When `xray` is enabled, blur passes through transparent regions, which can interfere with glass visibility on windows.

**Fix:**

```ini
blur {
    xray = false
    ignore_opacity = false
}
```

**Why this works:** Disabling `xray` and `ignore_opacity` ensures Hyprglass can properly composite the glass effect over all layers without conflicts.

---

## Config values keep reverting

**Symptom:** You change settings in `Hyprglass.conf` but they revert after a while or after restarting the server.

**Cause:** The Studio `server.py` overwrites `Hyprglass.conf` when applying presets, clobbering your manual changes.

**Fix:** The server guard preserves the `default_preset` value across overwrites. Set `default_preset` to your preferred preset to avoid losing it.

**Workaround:** If you need to apply custom values at startup, use `FixHyprglassValues.sh` as a startup script. It restores your desired configuration after the server initializes.

```bash
~/.config/hypr/FixHyprglassValues.sh
```

---

## Plugin shows wrong values

**Symptom:** The Hyprglass plugin displays incorrect colors or values that don't match what's in your config file.

**Cause:** The `.conf` parser ignores namespaced values (e.g., `glass:color`) and only reads top-level keys. This causes the plugin to fall back to defaults or stale values.

**Fix:** Use `hyprctl keyword` with delays to set values correctly:

```bash
hyprctl keyword decoration:glass:color "rgba(1a1a1a80)"
sleep 0.1
hyprctl keyword decoration:glass:opacity 0.5
```

The delay ensures each keyword is applied before the next one is read by the plugin.

---

## Glass preset overrides my settings

**Symptom:** You customize individual glass values, but after applying a preset or restarting, they get replaced.

**Cause:** `default_preset = glass` is set in the config, which applies the full glass preset and overwrites all individual settings.

**Fix:**

```ini
default_preset = default
```

**Why this works:** Setting `default_preset = default` prevents any preset from being applied automatically, preserving your individual customizations.

---

## Border colors keep changing

**Symptom:** You set border colors manually, but they change whenever you switch wallpapers.

**Cause:** `wallust` regenerates colors on every wallpaper change, overwriting your custom border colors with generated values.

**Fix:** Set transparent borders in `UserDecorations.conf` so they persist regardless of wallust changes:

```ini
decoration {
    border_size = 0
    col.active_border = "rgba(00000000)"
    col.inactive_border = "rgba(00000000)"
}
```

This file is not overwritten by wallust, so your settings stay intact.

---

## JaKooLit copy.sh breaks my config

**Symptom:** After running JaKooLit's `copy.sh` to update Hyprland, your Hyprglass configuration is gone or broken.

**Cause:** `copy.sh` replaces the entire `~/.config/hypr/` directory with a fresh default, wiping out Hyprglass files and configurations.

**Fix:** After running `copy.sh`, run the recovery script to restore Hyprglass:

```bash
~/.config/hypr/FixHyprglassSource.sh
```

This re-links and restores your Hyprglass configuration on top of the fresh Hyprland install.

---

## Studio gives "operation not permitted"

**Symptom:** The Studio server fails with an "operation not permitted" error when trying to write to `Hyprglass.conf` or related files.

**Cause:** The file has been marked immutable with `chattr +i`, which prevents any modification including by root.

**Fix:**

```bash
sudo chattr -i ~/.config/hypr/Hyprglass.conf
```

After removing the immutable flag, the Studio server can write to the file normally.
