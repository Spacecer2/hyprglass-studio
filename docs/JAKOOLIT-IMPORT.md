# Importing JaKooLit Decoration Defaults into HyprGlass

If you are coming from [JaKooLit's Hyprland dotfiles](https://github.com/JaKooLit/Hyprland-Dots), you probably already tuned `~/.config/hypr/UserConfigs/UserDecorations.conf` to your taste. The **ImportJaKooLitDefaults.sh** tool reads those existing opacity and blur settings and turns them into a HyprGlass Studio profile, so you do not have to start from scratch.

---

## What it does

1. Locates your JaKooLit `UserDecorations.conf`.
2. Extracts current values for:
   - `decoration:active_opacity`
   - `decoration:inactive_opacity`
   - `decoration:fullscreen_opacity`
   - `decoration:rounding`
   - `decoration:blur:size` and `decoration:blur:passes`
   - `decoration:dim_inactive`
   - `general:col.active_border` / `col.inactive_border`
3. Maps them to the HyprGlass profile format (`$glass.*`, `$decoration.*`, `$theme.dark.*`).
4. Writes a new `.conf` profile into your HyprGlass profiles directory.
5. Optionally applies the profile immediately.

---

## Requirements

- HyprGlass Studio must be installed (so `HyprglassProfile.sh` and the profiles directory exist).
- A JaKooLit `UserDecorations.conf` file must be present.

The tool is safe to run repeatedly; it will ask before overwriting an existing imported profile unless `--force` is used.

---

## Basic usage

Run the import from the repository or from your installed HyprGlass scripts directory:

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh
```

This creates:

```text
~/.config/hypr/hyprglass-profiles/jakoolit-imported.conf
```

Then apply it:

```bash
~/.config/hypr/scripts/HyprglassProfile.sh apply jakoolit-imported
```

---

## Command-line options

| Option | Description |
|--------|-------------|
| `-i, --input <path>` | Path to `UserDecorations.conf` (default: `~/.config/hypr/UserConfigs/UserDecorations.conf`) |
| `-o, --output <path>` | Output profile path (default: `~/.config/hypr/hyprglass-profiles/jakoolit-imported.conf`) |
| `-n, --name <name>` | Profile name inside the generated file (default: `jakoolit-imported`) |
| `-a, --apply` | Apply the generated profile immediately after import |
| `-f, --force` | Overwrite an existing profile without prompting |
| `-d, --dry-run` | Print the generated profile to stdout instead of writing it |
| `-h, --help` | Show help |

### Examples

**Import and apply in one step:**

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh --apply
```

**Use a custom JaKooLit config path:**

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh \
    --input ~/.config/hypr-backup/UserConfigs/UserDecorations.conf \
    --name jakoolit-backup
```

**Preview before writing:**

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh --dry-run
```

**Force overwrite and apply:**

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh --force --apply
```

---

## How values are mapped

| JaKooLit setting | HyprGlass profile field | Notes |
|------------------|-------------------------|-------|
| `decoration.active_opacity` | `$decoration.active_opacity` | Imported as-is |
| `decoration.inactive_opacity` | `$decoration.inactive_opacity` | Imported as-is |
| `decoration.fullscreen_opacity` | `$decoration.fullscreen_opacity` | Imported as-is |
| `decoration.rounding` | `$decoration.rounding` | Imported as-is |
| `decoration.blur.size` | `$glass.blur_strength` | Scaled (`size × 0.425`, max `10.0`) |
| `decoration.blur.passes` | `$glass.blur_iterations` | Clamped to `1–5` |
| `decoration.blur.enabled` | disables glass when `false` | Sets blur and glass opacity to `0.0` |
| `decoration.dim_inactive` | warning only | `true` darkens glass layers; the tool warns you |
| `general.col.*_border` | warning only | Non-transparent borders reduce the glass edge effect |

Other `$glass.*` values (refraction, fresnel, specular, edge thickness, lens distortion) are set to sensible defaults inherited from the bundled `default` profile. You can edit them afterward in the generated file or in the Studio UI.

---

## After importing

1. **Apply the profile** to see the result:

   ```bash
   ~/.config/hypr/scripts/HyprglassProfile.sh apply jakoolit-imported
   ```

2. **Fine-tune** the generated profile. Open it in a text editor or use the Studio UI to adjust glass strength, theme vibrancy, and per-app window rules.

3. **Reload Hyprland** if you edit the file manually:

   ```bash
   hyprctl reload
   ```

---

## Tips for the best result

- Set `dim_inactive = false` in `UserDecorations.conf` before importing. Dimming darkens the glass layer and makes the effect less visible.
- Use transparent borders for the glass edge to look correct:

  ```conf
  col.active_border = rgba(00000000)
  col.inactive_border = rgba(00000000)
  ```

- Import after every major JaKooLit update if you changed opacity/blur settings, then re-apply the generated profile.
- Store the generated profile outside `~/.config/hypr/` if you want it to survive JaKooLit's `copy.sh`:

  ```bash
  cp ~/.config/hypr/hyprglass-profiles/jakoolit-imported.conf \
     ~/hyprglass-studio/profiles/
  ```

---

## Troubleshooting

### "JaKooLit UserDecorations.conf not found"

Specify the file explicitly:

```bash
~/hyprglass-studio/scripts/ImportJaKooLitDefaults.sh -i /path/to/UserDecorations.conf
```

### Imported profile looks too strong or too weak

Edit the generated file and adjust `$glass.blur_strength` and `$glass.glass_opacity`. The import is a starting point, not a perfect one-to-one mapping.

### Glass effect does not appear

- Make sure HyprGlass plugin is loaded: `hyprctl plugins`
- Check that `active_opacity` is below `1.0`.
- Ensure borders are transparent.
- Disable `dim_inactive`.
- Run `hyprctl reload`.

---

For general JaKooLit integration, see [`JAKOOLIT.md`](JAKOOLIT.md). For profile format details, see [`PROFILES.md`](PROFILES.md).
