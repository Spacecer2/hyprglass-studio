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
hyprpm add https://github.com/hyprnux/hyprglass
hyprpm enable hyprglass
```

Verify the plugin is loaded:

```bash
hyprctl plugins
```

You should see `hyprglass` in the output.

### 2. Clone This Repository

```bash
cd ~/SSD
git clone https://github.com/your-username/hyprglass-studio.git
cd hyprglass-studio
```

### 3. Run the Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:

- Detect your existing Hyprland configuration
- Create backups of all files it modifies
- Install the Studio UI launcher
- Configure glass effect defaults
- Set up wallust integration (if wallust is installed)

### 4. Configure for JaKooLit Dots (If Using)

If you're using JaKooLit's Hyprland dots, run the JaKooLit-specific configuration:

```bash
chmod +x configure-jakoolit.sh
./configure-jakoolit.sh
```

This will:

- Merge glass effects into your existing `hyprland.conf`
- Patch window rules for glass transparency
- Preserve your existing keybinds and styling

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

## Updating

### How Dotfile Updates Affect Config

When you update your Hyprland dots (e.g., JaKooLit's repo), your config files may be overwritten. This can break HyprGlass integration.

**Affected files:**

- `~/.config/hypr/hyprland.conf`
- `~/.config/hypr/windowrules.conf`
- `~/.config/hypr/windowrulesv2.conf`
- `~/.config/hypr/keybindings.conf`

### FixHyprglassSource.sh Recovery

After a dotfile update, run the recovery script to restore glass integration:

```bash
cd ~/SSD/hyprglass-studio
chmod +x FixHyprglassSource.sh
./FixHyprglassSource.sh
```

This script will:

1. Detect which config files were overwritten
2. Re-inject glass-related window rules
3. Restore keybindings for glass controls
4. Re-apply your saved glass presets

### Backup System

The installer automatically creates backups before any modification:

```
~/.config/hypr/backups/
  ├── hyprland.conf.bak
  ├── windowrules.conf.bak
  └── ...
```

**Manual backup before updates:**

```bash
cd ~/SSD/hyprglass-studio
chmod +x BackupConfig.sh
./BackupConfig.sh
```

**Restore from backup:**

```bash
cp ~/.config/hypr/backups/hyprland.conf.bak ~/.config/hypr/hyprland.conf
hyprctl reload
```

---

## Uninstalling

### RevertHyprglass.sh

To fully remove HyprGlass and restore your original configuration:

```bash
cd ~/SSD/hyprglass-studio
chmod +x RevertHyprglass.sh
./RevertHyprglass.sh
```

This will:

1. Disable the HyprGlass plugin
2. Remove glass rules from your Hyprland config
3. Restore all files from the most recent backup
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
rm ~/.config/hypr/glass-rules.conf

# Remove backups (optional)
rm -rf ~/.config/hypr/backups/

# Remove the repository
rm -rf ~/SSD/hyprglass-studio

# Reload Hyprland
hyprctl reload
```

---

## Troubleshooting

### Plugin not loading

```bash
# Reinstall the plugin
hyprpm remove hyprglass
hyprpm add https://github.com/hyprnux/hyprglass
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
