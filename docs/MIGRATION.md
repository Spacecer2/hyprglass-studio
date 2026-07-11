# Migration Guide

HyprGlass Studio ships with a built-in migration tool that detects outdated config formats, backs them up, and rewrites them in the current format.

## When to migrate

Run the migration tool after every major update, or whenever Hyprland reports unknown config keys. You should also migrate if you created configs with an early preview/beta release of HyprGlass Studio.

## Running the migration tool

The migration tool is installed to `~/.config/hypr/scripts/MigrateHyprglassConfig.sh` by `install.sh`. It runs automatically during installation when an outdated config is detected.

### Interactive mode

```bash
~/.config/hypr/scripts/MigrateHyprglassConfig.sh
```

The tool will:

1. Scan `~/.config/hypr/UserConfigs/Hyprglass.conf`
2. Scan every `*.conf` profile in `~/.config/hypr/hyprglass-profiles/`
3. Back up originals to `~/.config/hypr/backups/hyprglass-migrate-YYYYMMDD-HHMMSS/`
4. Rewrite files in the current format
5. Print a report of what changed

### Dry run

Preview changes without modifying anything:

```bash
~/.config/hypr/scripts/MigrateHyprglassConfig.sh --dry-run
```

### Unattended mode

For scripts or CI:

```bash
~/.config/hypr/scripts/MigrateHyprglassConfig.sh --yes
```

### Custom config directory

If your Hyprland config is not in `~/.config/hypr`:

```bash
~/.config/hypr/scripts/MigrateHyprglassConfig.sh --config-dir /path/to/hypr/config
```

## Detected legacy formats

The migration tool recognizes the following legacy patterns.

### Main config (`Hyprglass.conf`)

| Legacy pattern | Current format |
|---|---|
| No `plugin:hyprglass { ... }` block | Add block with all current keys |
| Theme overrides inside `plugin:hyprglass` block | Move `dark:*` and `light:*` to top level |
| Missing `layers:*` settings | Add default layer namespace rules |
| `windowrule = match:..., action` | Convert to `windowrulev2 = tag +hyprglass_*, ...` or `windowrulev2 = opacity ...` |

### Profile configs

| Legacy pattern | Current format |
|---|---|
| Missing `$version` or `$metadata` fields | Add them with sensible defaults |
| Flat keys like `blur_strength = ...` | Convert to `$glass.blur_strength = ...` |
| Flat theme keys like `brightness = ...` | Convert to `$theme.dark.brightness = ...` |
| Old `$rules.*` namespace | Rename to `$window_rules.*` |

## Backup and recovery

Every migrated file is copied to a timestamped backup directory before it is changed:

```text
~/.config/hypr/backups/hyprglass-migrate-YYYYMMDD-HHMMSS/
```

If something goes wrong, restore the original file manually:

```bash
cp ~/.config/hypr/backups/hyprglass-migrate-YYYYMMDD-HHMMSS/Hyprglass.conf \
   ~/.config/hypr/UserConfigs/Hyprglass.conf
```

Then reload Hyprland:

```bash
hyprctl reload
```

## Migration report

After running, the tool prints a report like this:

```text
Migration report:
  Backups saved to: /home/user/.config/hypr/backups/hyprglass-migrate-20260712-143052

  • /home/user/.config/hypr/UserConfigs/Hyprglass.conf: theme overrides inside plugin block (should be top-level)
  • /home/user/.config/hypr/hyprglass-profiles/default.conf: missing $version field

Migration complete.
```

A report that says `No migration needed` means your configs are already current.

## Updating `install.sh`

The installer calls the migration tool automatically after copying scripts. If you are installing for the first time, no migration is performed because no legacy configs exist. If you are reinstalling or upgrading, the migration tool runs before the final verification step.

To skip automatic migration during install, pass `--yes` (migration still runs, but prompts are skipped) or remove the `MigrateHyprglassConfig.sh` exec line from your installer.
