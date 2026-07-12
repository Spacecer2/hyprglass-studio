# Sharing Hyprglass Profiles

Profiles can be shared with other Hyprglass users as plain `.conf` files. Each profile is self-contained and uses Hyprland-style variable syntax, so it can be imported, exported, and distributed easily.

## Export a Profile

Export an existing profile to stdout or to a file.

```bash
# Print a profile to stdout
HyprglassProfile.sh export default

# Save a profile to a file
HyprglassProfile.sh export default ~/my-default.conf
```

Exported files contain the full profile definition and are ready to share.

## Import a Profile

Import a profile from a local `.conf` file into your profiles directory.

```bash
HyprglassProfile.sh import ~/Downloads/cool-glass.conf
```

The profile name is read from the `$name` variable inside the file. If `$name` is missing, the filename (without `.conf`) is used. Existing profiles with the same name are overwritten after a warning.

## Import from a URL

Download and import a profile directly from a URL.

```bash
HyprglassProfile.sh import-from-url https://example.com/hyprglass-profiles/cool-glass.conf
```

This requires `curl` or `wget` to be installed. The downloaded file is validated and then copied into your profiles directory.

## Sharing Best Practices

1. **Use a descriptive `$name` and `$metadata.description`.** This helps recipients understand what the profile does before applying it.
2. **Set `$metadata.author`.** Include your name or username so others know who created the profile.
3. **Keep overrides minimal.** Only override settings that matter for the profile's purpose. Leave unrelated values at sensible defaults.
4. **Test before sharing.** Apply the profile locally and verify it looks correct on your setup.
5. **Avoid machine-specific paths.** Do not include paths, usernames, or host-specific window class names unless they are broadly useful.

## Profile File Format

Shared profiles use the same format as local profiles:

```conf
# HyprGlass Studio profile

# Profile identity
$name = community-example
$version = 1.0.0
$inherits = default

# Metadata
$metadata.author = Your Name
$metadata.description = Brief description of what this profile does

# Glass effect settings
$glass.blur_strength = 3.4
$glass.blur_iterations = 2
$glass.refraction_strength = 0.96
$glass.chromatic_aberration = 0.7
$glass.fresnel_strength = 0.96
$glass.specular_strength = 0.6
$glass.glass_opacity = 1.0
$glass.edge_thickness = 0.14
$glass.lens_distortion = 0.42

# Theme settings
$theme.dark.brightness = 1.1
$theme.dark.contrast = 1.2
$theme.dark.saturation = 1.15
$theme.dark.vibrancy = 0.7
$theme.dark.vibrancy_darkness = 0.52
$theme.dark.adaptive_dim = 0.65
$theme.dark.adaptive_boost = 0.34

# Decoration settings
$decoration.active_opacity = 0.75
$decoration.inactive_opacity = 0.65

# Window rules
$window_rules.fallback.action = default
$window_rules.fallback.reason = All other windows use the profile defaults
```

## Example Workflow

1. Create and tune a profile on your machine.
2. Export it:
   ```bash
   HyprglassProfile.sh export my-profile ~/my-profile.conf
   ```
3. Share `~/my-profile.conf` via GitHub, email, a gist, or a chat message.
4. The recipient imports it:
   ```bash
   HyprglassProfile.sh import ~/Downloads/my-profile.conf
   HyprglassProfile.sh apply my-profile
   ```

## Security Notes

- Profiles are plain text. Review any profile you import from the internet before applying it.
- The import command validates the file format before copying it into your profiles directory.
- Do not apply profiles from untrusted sources without inspection.
