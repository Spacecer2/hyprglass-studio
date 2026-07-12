# Installation Guide

## Prerequisites

Before installing HyprGlass Studio, ensure you have the following:

| Requirement | Minimum Version | Required |
|-------------|----------------|----------|
| Hyprland | 0.55+ | Yes |
| hyprpm | latest | Yes |
| Python | 3.10+ | Yes |
| wallust | latest | Optional (color sync) |
| grim/slurp | latest | Optional (screenshots) |

### Installing Prerequisites

```bash
# Arch Linux (and derivatives)
sudo pacman -S hyprland hyprpm python wallust grim slurp

# For wallust from AUR
yay -S wallust
```

> **Note:** If you're using JaKooLit's Hyprland dots, most prerequisites are already installed.

---

## Step-by-Step Installation

### 1. Install the HyprGlass Plugin

First, install the HyprGlass Hyprland plugin via hyprpm:

```bash
hyprpm add https://github.com/Spacecer2/hyprglass-studio
hyprpm enable hyprglass
```

Verify the plugin is loaded:

```bash
hyprctl plugins
```

You should see `hyprglass` in the output.

### 2. Clone This Repository

```bash
cd ~
git clone https://github.com/Spacecer2/hyprglass-studio.git
cd hyprglass-studio
```

### 3. Run the Installer

```bash
chmod +x install.sh
./install.sh
```

The installer will:

- Detect your existing Hyprland configuration
- Create timestamped backups of all files it modifies
- Install the `hyprglass` plugin via `hyprpm`
- Copy profiles, scripts, and wallust templates
- Generate `Hyprglass.conf` and a startup fix script if missing
- Patch `hyprland.conf` safely without overwriting dotfiles
- Set executable permissions on helper scripts
- Verify the installation and optionally reload Hyprland

### 4. Import JaKooLit Decoration Defaults (Optional)

If you're using JaKooLit's Hyprland dots, you can import your current decoration settings into a HyprGlass profile:

```bash
chmod +x scripts/ImportJaKooLitDefaults.sh
./scripts/ImportJaKooLitDefaults.sh --apply
```

This will:

- Read your existing `~/.config/hypr/UserConfigs/UserDecorations.conf`
- Generate a HyprGlass profile that preserves the same opacity/blur/rounding feel
- Apply the generated profile immediately (omit `--apply` to review it first)

For full JaKooLit integration and recovery steps after dotfile updates, see [JAKOOLIT.md](JAKOOLIT.md).

---

## Post-Installation

### Verify Plugin Loaded

```bash
hyprctl plugins
```

Expected output should include:

```
Plugin hyprglass loaded successfully.
```

### Test Glass Effect

1. Open any window
2. Press the default glass toggle keybind: `SUPER + G`
3. The active window should gain a glass/blur effect
4. Adjust transparency in real-time with `SUPER + Scroll`

### Launch Studio UI

```bash
hyprglass-studio
```

Or use the desktop entry if installed:

```bash
# Application menu or launcher
HyprGlass Studio
```

The Studio UI provides a GUI for:

- Adjusting glass parameters (opacity, blur, color)
- Managing per-app glass rules
- Syncing colors with wallust
- Previewing effects in real-time

---

## System Tray Applet

HyprGlass Studio ships with a system tray applet that gives you quick access to profiles, the Studio UI, and a glass-effect toggle.

### Dependencies

- **GTK/AppIndicator mode** (default): `python-gobject`, plus one of:
  - `libappindicator-gtk3`
  - `ayatana-appindicator`
- **Rofi fallback mode**: `rofi`

On Arch Linux:

```bash
sudo pacman -S python-gobject libappindicator-gtk3 rofi
```

### Running the Tray Applet

From the repository:

```bash
~/hyprglass-studio/scripts/HyprglassTray.py
```

When installed system-wide, the script is copied to:

```bash
/usr/local/share/hyprglass-studio/scripts/HyprglassTray.py
```

If the GTK/AppIndicator dependencies are not available, the applet automatically falls back to a rofi menu. You can also force rofi mode explicitly:

```bash
~/hyprglass-studio/scripts/HyprglassTray.py --rofi
```

### Autostart

Add the tray applet to your Hyprland startup configuration so it runs on login:

```conf
exec-once = ~/hyprglass-studio/scripts/HyprglassTray.py
```

For JaKooLit dots, add it to `~/.config/hypr/UserConfigs/Startup_Apps.conf`.

### Tray Menu Items

| Item | Action |
|------|--------|
| **Profiles** | Switch between available HyprGlass profiles |
| **Open Studio** | Launch the HyprGlass Studio web UI |
| **Toggle Glass** | Enable or disable glass effects instantly |
| **Quit** | Close the tray applet |

---

## Updating

### How Dotfile Updates Affect Config

When you update your Hyprland dots (e.g., JaKooLit's repo), your config files may be overwritten. This can break HyprGlass integration.

**Affected files:**

- `~/.config/hypr/hyprland.conf`
- `~/.config/hypr/windowrules.conf`
- `~/.config/hypr/windowrulesv2.conf`
- `~/.config/hypr/keybindings.conf`

### JaKooLit Update Recovery

After a JaKooLit dotfile update, run the recovery hook to restore glass integration:

```bash
cd ~/hyprglass-studio
chmod +x scripts/JaKooLitUpdateHook.sh
./scripts/JaKooLitUpdateHook.sh
```

This hook will:

1. Detect which config files were overwritten
2. Restore the `Hyprglass.conf` source/include in `hyprland.conf`
3. Re-add the startup fix script (`FixHyprglassValues.sh`) if missing
4. Re-apply your saved glass presets

### Backup System

The installer automatically creates timestamped backups before any modification:

```
~/.config/hypr/backups/hyprglass-studio-YYYYMMDD-HHMMSS/
  ├── hyprland.conf
  ├── UserConfigs/Hyprglass.conf
  └── ...
```

**Restore from a backup:**

```bash
# Replace with the actual backup directory name
cp ~/.config/hypr/backups/hyprglass-studio-YYYYMMDD-HHMMSS/hyprland.conf ~/.config/hypr/hyprland.conf
cp ~/.config/hypr/backups/hyprglass-studio-YYYYMMDD-HHMMSS/UserConfigs/Hyprglass.conf ~/.config/hypr/UserConfigs/Hyprglass.conf
hyprctl reload
```

---

## Uninstalling

### Uninstall

To fully remove HyprGlass Studio and restore your original configuration:

```bash
cd ~/hyprglass-studio
chmod +x uninstall.sh
./uninstall.sh
```

This will:

1. Disable and remove the HyprGlass plugin
2. Remove glass rules from your Hyprland config
3. Restore files from the most recent backup
4. Remove Studio UI desktop entries

### Manual Cleanup

If you want to remove everything manually:

```bash
# Disable and remove the plugin
hyprpm disable hyprglass
hyprpm remove hyprglass

# Remove Studio UI
rm ~/.local/bin/hyprglass-studio
rm ~/.local/share/applications/hyprglass-studio.desktop

# Remove glass configs
rm ~/.config/hypr/UserConfigs/Hyprglass.conf

# Remove backups (optional)
rm -rf ~/.config/hypr/backups/

# Remove the repository
rm -rf ~/hyprglass-studio

# Reload Hyprland
hyprctl reload
```

---

## Troubleshooting

### Plugin not loading

```bash
# Reinstall the plugin
hyprpm remove hyprglass
hyprpm add https://github.com/Spacecer2/hyprglass-studio
hyprpm enable hyprglass
hyprctl reload
```

### Glass effect not visible

1. Verify blur is enabled in `hyprland.conf`:
   ```
   decoration {
       blur {
           enabled = true
       }
   }
   ```
2. Check that your GPU supports the required blur features
3. Try adjusting opacity with `SUPER + Scroll`

### Studio UI won't launch

```bash
# Check for missing dependencies
python3 --version  # Must be 3.10+
hyprctl plugins    # Verify hyprglass is loaded
```
