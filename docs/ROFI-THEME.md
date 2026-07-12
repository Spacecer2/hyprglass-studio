# Rofi Theme

HyprGlass Studio ships a custom rofi theme that matches the glass aesthetic used by the profile switcher.

## What It Does

The `HyprglassProfile.sh menu` command uses rofi to display the list of HyprGlass profiles. When the bundled theme is installed, the menu renders with:

- A dark, translucent background
- Rounded corners and subtle cyan border
- Accent highlighting for the selected item
- A prompt that matches the HyprGlass Studio color palette

## Installation Location

The installer copies the theme from the repository to:

```
~/.config/rofi/themes/rofi-hyprglass.rasi
```

The profile menu script uses this path by default. If the theme file is missing, rofi falls back to its default appearance.

## Usage

Open the profile menu with the configured keybinding (default: `SUPER + SHIFT + G`) or run:

```bash
~/.config/hypr/scripts/HyprglassProfile.sh menu
```

To preview the theme directly without changing profiles:

```bash
rofi -show drun -theme ~/.config/rofi/themes/rofi-hyprglass.rasi
```

## Customization

Edit `~/.config/rofi/themes/rofi-hyprglass.rasi` to change colors, fonts, border radius, or window size. The palette variables are defined at the top of the file:

| Variable | Default | Purpose |
|---|---|---|
| `bg` | `rgba(16, 20, 28, 0.92)` | Window background |
| `bg-alt` | `rgba(28, 36, 50, 0.85)` | Input bar and message background |
| `fg` | `#e8edf5` | Primary text |
| `fg-dim` | `#8b95a7` | Placeholder and secondary text |
| `accent` | `#00bcd4` | Prompt and selected item |
| `border` | `rgba(0, 188, 212, 0.45)` | Window and selection border |

Changes take effect the next time the menu is opened. No Hyprland reload is required.

## Disabling the Custom Theme

To use your own rofi theme instead, set the `ROFI_THEME` environment variable before running the menu:

```bash
export ROFI_THEME="~/.config/rofi/themes/my-theme.rasi"
~/.config/hypr/scripts/HyprglassProfile.sh menu
```

Or modify the `ROFI_THEME` line near the top of `HyprglassProfile.sh`.

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Menu uses default rofi theme | Theme file not installed | Re-run `install.sh` or copy `templates/rofi-hyprglass.rasi` to `~/.config/rofi/themes/` |
| Rofi fails to start | Invalid rasi syntax | Validate with `rofi -theme ~/.config/rofi/themes/rofi-hyprglass.rasi -show drun` and check the error output |
| Font looks wrong | Font not installed | Install [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) or change the `font` line in the theme |
| No blur behind menu | Compositor settings | Enable background blur for rofi in your compositor or Hyprland window rules |
