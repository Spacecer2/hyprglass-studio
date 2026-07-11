# Version Planning

This document outlines the planned release roadmap for HyprGlass Studio. Versions are ordered chronologically and reflect the intended evolution of the project.

---

## v1.0.1 - Bug fixes, CI stability

### Goals

- Stabilize the initial release.
- Resolve critical and high-priority bugs reported after v1.0.0 launch.
- Improve CI/CD pipeline reliability and test coverage.

### Features

- Fix reported crashes and UI glitches.
- Add automated regression tests for core workflows.
- Improve error reporting and logging.
- Stabilize build artifacts across supported platforms.

### Breaking changes

- None.

### Deprecations

- None.

### Migration notes

- Upgrade directly from v1.0.0. No configuration changes required.

---

## v1.1.0 - Profile system enhancements

### Goals

- Expand the profile system to support more flexible configuration and sharing.
- Improve profile import/export and versioning.

### Features

- Profile templates and presets.
- Nested profile inheritance.
- Profile diff and merge utilities.
- Enhanced import/export with validation.
- CLI commands for profile management.

### Breaking changes

- Profile schema updated with new required fields; older profiles are auto-migrated on first load.

### Deprecations

- Legacy flat profile format is deprecated in favor of the new structured format.

### Migration notes

- Existing profiles will be automatically migrated on first use.
- Back up your `~/.config/hyprglass/profiles` directory before upgrading.

---

## v1.2.0 - Wallust and auto-switching

### Goals

- Integrate with Wallust for dynamic color scheme generation.
- Add automatic profile and theme switching based on context.

### Features

- Wallust integration for extracting color palettes from wallpapers.
- Auto-switch profiles based on time of day, active application, or display configuration.
- Rules engine for conditional theme application.
- Live preview of generated color schemes.

### Breaking changes

- None.

### Deprecations

- Manual palette override fields may be deprecated in favor of generated palettes.

### Migration notes

- Enable Wallust integration from the settings panel.
- Existing manual themes remain functional; migration to generated palettes is optional.

---

## v1.3.0 - Studio UI improvements

### Goals

- Refine and modernize the Studio user interface.
- Improve usability, accessibility, and responsiveness.

### Features

- Redesigned main dashboard with better visual hierarchy.
- Improved settings and profile editors.
- Keyboard navigation and accessibility enhancements.
- Responsive layouts for different screen sizes.
- Dark/light mode refinements.

### Breaking changes

- None.

### Deprecations

- Old widget IDs and legacy UI plugin hooks may be deprecated.

### Migration notes

- Custom UI themes may require minor updates to match new selectors.
- Review custom CSS overrides after upgrading.

---

## v2.0.0 - Breaking changes, plugin rewrite

### Goals

- Deliver a robust, future-proof plugin system.
- Clean up technical debt and remove legacy APIs.

### Features

- New plugin API with improved lifecycle management.
- TypeScript-first plugin development.
- Sandboxed plugin execution.
- Better error isolation and debugging tools.
- Migration assistant for plugin authors.

### Breaking changes

- Old plugin API removed; plugins must be rewritten for the new API.
- Configuration file format changes.
- Some internal modules reorganized.

### Deprecations

- All v1.x plugin APIs deprecated and removed in v2.0.0.
- Legacy configuration keys deprecated in prior versions are removed.

### Migration notes

- Use the provided migration assistant to convert configurations.
- Plugin authors should consult the v2.0 plugin authoring guide.
- Breaking changes are clearly listed in the v2.0 changelog.

---

## v3.0.0 - Future architecture

### Goals

- Evolve the platform architecture for long-term scalability and modularity.
- Enable distributed and headless deployment scenarios.

### Features

- Modular core with optional components.
- Headless/server mode for remote management.
- New rendering backend options.
- Enhanced multi-device synchronization.
- Improved performance and resource efficiency.

### Breaking changes

- Core architecture changes may require adjustments to advanced custom setups.
- Some internal extension points may change.

### Deprecations

- Monolithic application mode deprecated in favor of modular deployment.

### Migration notes

- Standard desktop installations continue to work with the default modular configuration.
- Advanced users and integrators should review the v3.0 architecture guide.

---
