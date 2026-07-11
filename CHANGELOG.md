# Changelog

## [1.0.0] - 2026-07-23

### Added
- Initial release
- HyprGlass plugin integration
- Session profiles (default, gaming, coding, movies)
- Wallust color sync
- Hyprglass Studio web UI
- Auto-switching based on app type
- FixHyprglassValues.sh workaround
- FixHyprglassSource.sh recovery
- JaKooLit Hyprland dots compatibility

### Fixed
- Config values reverting (server guard)
- Preset clobbering individual values
- Border color conflicts with wallust
- Glass not visible on windows (opacity requirement)

### Known Issues
- .conf parser ignores namespaced values (issue #34)
- Glass effect is subtle by design
- Requires opacity < 1.0 for windows
