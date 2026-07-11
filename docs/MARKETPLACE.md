# Profile Marketplace

The Hyprglass profile marketplace is a small built-in collection of community-curated profiles. These profiles ship with the project in `profiles/community/` and can be installed into your local profiles directory with `HyprglassProfile.sh`.

## Available Profiles

| Profile | Description |
|---------|-------------|
| `cyberpunk` | Neon cyberpunk glass with high blur and magenta/cyan tint |
| `solarized` | Solarized Dark glass with blue-green tint and calm contrast |
| `gruvbox` | Warm Gruvbox Dark glass with earthy amber/brown tint |
| `catppuccin` | Soft Catppuccin Mocha glass with pastel pink/lavender tint |
| `everforest` | Muted Everforest Dark glass with soft sage green tint |

## Listing Marketplace Profiles

```bash
HyprglassProfile.sh marketplace list
```

This prints the names and descriptions of every bundled community profile. The command requires either `jq` or `python3` to read `profiles/registry.json`.

## Installing a Marketplace Profile

```bash
HyprglassProfile.sh marketplace install catppuccin
```

The profile is copied from `profiles/community/` into your local profiles directory (`~/.config/hypr/hyprglass-profiles/`) and validated. If a profile with the same name already exists, it is overwritten. After installing, apply it with:

```bash
HyprglassProfile.sh apply catppuccin
```

## Registry Format

Marketplace metadata lives in `profiles/registry.json`:

```json
{
  "version": "1.0.0",
  "updated": "2026-07-12",
  "source": "https://github.com/neo/hyprglass-studio/tree/main/profiles/community",
  "profiles": [
    {
      "name": "catppuccin",
      "file": "community/catppuccin.conf",
      "version": "1.0.0",
      "author": "HyprGlass Community",
      "description": "Soft Catppuccin Mocha glass with pastel pink/lavender tint",
      "tags": ["dark", "pastel", "soft"]
    }
  ]
}
```

Each entry points to a `.conf` file relative to `profiles/`. The `name` must match the filename without the `.conf` extension.

## Adding a Community Profile

1. Create a new `.conf` file in `profiles/community/` following the standard profile format documented in [PROFILES.md](PROFILES.md).
2. Add an entry to `profiles/registry.json`.
3. Run `HyprglassProfile.sh marketplace list` to verify it appears.

## Sharing Profiles

For sharing profiles outside the built-in marketplace, use the existing `export`, `import`, and `import-from-url` commands. See [PROFILE-SHARING.md](PROFILE-SHARING.md) for details.
