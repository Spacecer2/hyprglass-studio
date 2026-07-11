# JaKooLit Hyprland Dots Integration

This guide explains how to use HyprGlass Studio with [JaKooLit's Hyprland dotfiles](https://github.com/JaKooLit/Hyprland-Dots). JaKooLit's setup works well out of the box, but its update mechanism can overwrite the extra configuration that HyprGlass needs. The workflow below keeps glass effects intact across dotfile updates.

---

## 1. Why special handling is needed

JaKooLit's dots ship a complete, ready-to-use `~/.config/hypr/` directory. HyprGlass, on the other hand, adds its own pieces on top of a normal Hyprland config:

- A `plugin:hyprglass { ... }` block in `hyprland.conf`
- Extra window rules in `windowrules.conf` / `windowrulesv2.conf`
- Keybindings for toggling and adjusting glass effects
- A `source` line that loads `~/.config/hypr/Hyprglass.conf` or similar
- Optional wallust hooks and profile rules

Because JaKooLit manages the whole `~/.config/hypr/` tree as one unit, a normal dotfile update will replace these additions and silently remove HyprGlass integration. The scripts below re-apply the missing pieces after each update.

---

## 2. How `copy.sh` affects the setup

JaKooLit's `copy.sh` copies a fresh copy of the dotfiles into `~/.config/hypr/`. It does not merge changes; it replaces files.

**Files that are typically overwritten or reset:**

| File | What HyprGlass loses |
|------|----------------------|
| `~/.config/hypr/hyprland.conf` | `plugin:hyprglass` block, `source` includes |
| `~/.config/hypr/windowrules.conf` | Glass window rules |
| `~/.config/hypr/windowrulesv2.conf` | Per-app glass tags/presets |
| `~/.config/hypr/keybindings.conf` | Glass toggle/adjust keybinds |
| `~/.config/hypr/Hyprglass.conf` | Saved glass settings |

After running `copy.sh` you will usually find that:

- `hyprctl plugins` still shows `hyprglass` loaded, but the plugin has no active config.
- `SUPER + G` and scroll bindings no longer work.
- Windows no longer get the glass effect.

This is expected. Run the recovery script described in the next section.

---

## 3. `FixHyprglassSource.sh` usage

`FixHyprglassSource.sh` is the recovery script that repairs HyprGlass integration after JaKooLit has overwritten your config.

**What it does:**

1. Detects which HyprGlass-related entries are missing from the current config.
2. Re-injects the `plugin:hyprglass` source/include into `hyprland.conf`.
3. Restores glass window rules in `windowrules.conf` / `windowrulesv2.conf`.
4. Re-adds keybindings for toggling glass and adjusting opacity/blur.
5. Re-applies your saved presets from `~/.config/hypr/Hyprglass.conf` or `~/.config/hyprglass/`.

**Run it manually:**

```bash
cd ~/hyprglass-studio
chmod +x FixHyprglassSource.sh
./FixHyprglassSource.sh
```

If the script was installed into your Hyprland config directory, you can also run:

```bash
~/.config/hypr/FixHyprglassSource.sh
```

After it finishes, reload Hyprland:

```bash
hyprctl reload
```

Then test the effect with `SUPER + G` and verify the plugin is still loaded:

```bash
hyprctl plugins
```

---

## 4. `JaKooLitUpdateHook.sh` usage

`JaKooLitUpdateHook.sh` is a convenience wrapper that combines a dotfile update with the HyprGlass recovery step. Instead of running `copy.sh` directly, run this hook so recovery happens automatically.

**Typical workflow:**

```bash
cd ~/hyprglass-studio
chmod +x JaKooLitUpdateHook.sh
./JaKooLitUpdateHook.sh
```

**What the hook usually does:**

1. Backs up your current `~/.config/hypr/` directory.
2. Runs JaKooLit's `copy.sh` from its known location.
3. Runs `FixHyprglassSource.sh` immediately after `copy.sh` finishes.
4. Reloads Hyprland.

If your JaKooLit repo is in a different location, edit the hook and set the correct path:

```bash
JAKOOLit_DOTS_DIR="$HOME/Hyprland-Dots"
```

You can also call the hook from your own update alias:

```bash
alias update-dots='~/hyprglass-studio/JaKooLitUpdateHook.sh'
```

---

## 5. How to run after a dotfile update

If you prefer to update JaKooLit manually, use this order:

1. **Back up first.**

   ```bash
   cd ~/hyprglass-studio
   chmod +x BackupConfig.sh
   ./BackupConfig.sh
   ```

2. **Run JaKooLit's update.**

   ```bash
   cd ~/Hyprland-Dots
   ./copy.sh
   ```

3. **Restore HyprGlass integration.**

   ```bash
   cd ~/hyprglass-studio
   ./FixHyprglassSource.sh
   ```

4. **Reload Hyprland.**

   ```bash
   hyprctl reload
   ```

5. **Verify.**

   ```bash
   hyprctl plugins
   ```

   Open a window and press `SUPER + G`. The glass effect should return.

---

## 6. Troubleshooting when JaKooLit overwrites configs

### Glass effect disappears after `copy.sh`

**Symptom:** Windows are no longer transparent/blurry and `SUPER + G` does nothing.

**Cause:** `copy.sh` replaced the HyprGlass entries in your Hyprland config.

**Fix:** Run the recovery script and reload:

```bash
~/hyprglass-studio/FixHyprglassSource.sh
hyprctl reload
```

### `plugin:hyprglass` block is missing

Check whether `hyprland.conf` still sources your glass config:

```bash
grep -i hyprglass ~/.config/hypr/hyprland.conf
```

If nothing is returned, run `FixHyprglassSource.sh`.

### Keybindings no longer work

Check whether the glass keybindings are still present:

```bash
grep -i "hyprglass\|glass" ~/.config/hypr/keybindings.conf
```

If they are gone, run `FixHyprglassSource.sh`.

### Plugin is no longer loaded

```bash
hyprctl plugins
```

If `hyprglass` is not listed, re-enable it:

```bash
hyprpm enable hyprglass
hyprctl reload
```

### Studio says "operation not permitted"

If a file was marked immutable (`chattr +i`), remove the flag:

```bash
sudo chattr -i ~/.config/hypr/Hyprglass.conf
```

Then run the recovery script again.

### Restore from a backup

If recovery fails, restore the backup created by `BackupConfig.sh`:

```bash
cp ~/.config/hypr/backups/hyprland.conf.bak ~/.config/hypr/hyprland.conf
# Repeat for other overwritten files as needed
hyprctl reload
```

Then re-run `FixHyprglassSource.sh` to ensure the latest HyprGlass entries are present.

---

## 7. Recommended way to keep settings persistent

The cleanest way to survive JaKooLit updates is to keep HyprGlass changes out of the files that `copy.sh` owns.

### Use separate, sourced files

Place HyprGlass-specific settings in files that are **sourced** by `hyprland.conf`, not embedded inside it:

- `~/.config/hypr/Hyprglass.conf` — plugin settings and presets
- `~/.config/hypr/UserDecorations.conf` — decoration tweaks that survive wallust
- `~/.config/hypr/hyprglass-rules.conf` — glass window rules

`FixHyprglassSource.sh` only needs to re-add a single `source = ...` line after `copy.sh`, rather than patch many inline values.

### Always update through the hook

Use `JaKooLitUpdateHook.sh` (or your own wrapper) instead of running `copy.sh` directly. This guarantees the recovery step runs every time.

### Back up before updates

Run `BackupConfig.sh` before any dotfile update. Keep several backups so you can roll back if something goes wrong.

### Save presets and profiles

Use HyprGlass profiles to export your tuned effects:

```bash
hyprglass-profile save my-daily
hyprglass-profile export my-daily
```

Store exported profiles outside `~/.config/hypr/` (for example, in `~/hyprglass-studio/profiles/`) so `copy.sh` cannot delete them.

### Avoid editing JaKooLit's core files directly

Instead of editing `windowrules.conf` or `keybindings.conf` directly, add glass overrides in a separate file and source it. This makes `FixHyprglassSource.sh` simpler and less likely to conflict with future JaKooLit changes.

### Summary checklist

- [ ] `FixHyprglassSource.sh` is executable and tested.
- [ ] `JaKooLitUpdateHook.sh` is used for every dotfile update.
- [ ] `BackupConfig.sh` is run before `copy.sh`.
- [ ] HyprGlass settings live in sourced files outside JaKooLit's main files.
- [ ] Presets/profiles are exported and stored outside `~/.config/hypr/`.

---

For general HyprGlass configuration options, see [`CONFIGURATION.md`](CONFIGURATION.md). For installation steps, see [`INSTALLATION.md`](INSTALLATION.md).
