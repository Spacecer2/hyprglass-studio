# Changelog

All notable changes to HyprGlass Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-12

### Added
- HyprGlass plugin integration
- Session profiles: default, gaming, coding, and movies
- Wallust color synchronization for dynamic theming
- Hyprglass Studio web UI for real-time configuration
- Auto-switching based on active application type
- FixHyprglassValues.sh workaround for value persistence
- FixHyprglassSource.sh recovery for corrupted configs
- JaKooLit Hyprland dots compatibility layer
- Command-line interface for headless configuration

### Changed
- Migrated config parser from shell to Python for reliability
- Improved glass parameter range validation

### Fixed
- Config values reverting after session reload (server guard)
- Preset application clobbering individual user values
- Border color conflicts with wallust color scheme
- Glass not visible on windows due to opacity requirement
- Edge case where rapid profile switches caused race conditions

### Known Issues
- .conf parser ignores namespaced values ([#34](https://github.com/Spacecer2/hyprglass-studio/issues))
- Glass effect is subtle by design for compositor stability
- Requires `opacity < 1.0` for windows to display glass effect

## [0.1.0] - 2026-07-11

### Added
- Initial project scaffolding and repository setup
- Basic HyprGlass configuration editor
- Prototype session profile support
- Initial documentation and README

---

## Contributors

- HyprGlass Studio maintainers and contributors

---

[1.0.0]: https://github.com/Spacecer2/hyprglass-studio
[0.1.0]: https://github.com/Spacecer2/hyprglass-studio/releases
