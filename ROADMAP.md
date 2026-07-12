# Hyprglass Studio Roadmap

## Project Vision Statement

Hyprglass Studio aims to be the definitive open-source environment for designing, sharing, and deploying glass-themed desktop customizations for Hyprland and beyond. We believe everyone should be able to craft a beautiful, cohesive, and performant desktop experience through an intuitive studio interface—without writing a single line of configuration. Our vision is to bridge the gap between artistic expression and system configuration, empowering users to create, preview, and distribute polished "glass" setups with ease, while fostering a community-driven ecosystem of profiles, presets, and plugins.

---

## Version Milestones

### v1.0 (current) — Initial Release

**Theme:** Establish the foundation.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Core Hyprland profile editor with live preview | ✅ Done |
| 2 | Glass color, blur, border, and shadow customization | ✅ Done |
| 3 | Save and load local profiles | ✅ Done |
| 4 | Basic CLI for applying profiles | ✅ Done |
| 5 | Initial test suite and packaging (PKGBUILD, install script) | ✅ Done |

### v1.1 — Profile Sharing, Import/Export, and GPU Monitor

**Theme:** Make profiles portable and the system observable.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Export profiles to a portable `.hyprglass` archive format | 🚧 In progress |
| 2 | Import profiles from local archives or remote URLs | 🚧 In progress |
| 3 | One-click profile sharing via generated shareable links | 📋 Planned |
| 4 | GPU usage and temperature monitor widget | 📋 Planned |
| 5 | Resource-aware profile suggestions (e.g., reduce blur on weak GPUs) | 📋 Planned |

### v1.2 — Wallpaper Brightness Auto-Switch and Day/Night Themes

**Theme:** Adapt the desktop to time and environment.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Time-based automatic wallpaper switching | 📋 Planned |
| 2 | Ambient-light-aware brightness/contrast adjustment | 📋 Planned |
| 3 | Day and night glass theme presets | 📋 Planned |
| 4 | Scheduled transitions with smooth crossfades | 📋 Planned |
| 5 | Location-based sunrise/sunset detection for automation | 📋 Planned |

### v1.3 — Better Studio UI and Presets Marketplace

**Theme:** Improve usability and grow the ecosystem.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Redesigned studio interface with drag-and-drop panels | 📋 Planned |
| 2 | In-app searchable marketplace for community presets | 📋 Planned |
| 3 | Rating, review, and versioning for marketplace items | 📋 Planned |
| 4 | Improved accessibility and keyboard navigation | 📋 Planned |
| 5 | Undo/redo history and non-destructive editing | 📋 Planned |

### v2.0 — Plugin Architecture Improvements and Performance

**Theme:** Scale the platform for advanced users and developers.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | Stable plugin API with documentation and examples | 📋 Planned |
| 2 | Hot-reloadable plugins for custom effects and widgets | 📋 Planned |
| 3 | Rendering performance improvements and reduced memory usage | 📋 Planned |
| 4 | Async profile application and background tasks | 📋 Planned |
| 5 | Plugin registry and distribution system | 📋 Planned |

### v3.0 — AI Adaptive Glass and Multi-Compositor Support

**Theme:** Intelligence and portability.

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | AI-assisted profile generation from screenshots or color palettes | 📋 Planned |
| 2 | Adaptive glass themes that respond to workload and mood | 📋 Planned |
| 3 | Support for additional Wayland compositors beyond Hyprland | 📋 Planned |
| 4 | Cross-compositor profile compatibility layer | 📋 Planned |
| 5 | On-device learning for personalized recommendations | 📋 Planned |

---

## How to Contribute to the Roadmap

We welcome community input on where Hyprglass Studio should go next. Here's how you can contribute:

1. **Propose new ideas:** Open a [GitHub Discussion](https://github.com/Spacecer2/hyprglass-studio/discussions) with the `roadmap` tag and describe the feature, the problem it solves, and who would benefit.
2. **Vote on existing items:** React to roadmap issues and discussions to help us prioritize what the community cares about most.
3. **Pick up planned work:** Check issues labeled `roadmap` and `help wanted`. Comment on the issue to let maintainers know you're working on it.
4. **Report blockers:** If an in-progress item is stuck due to a technical or dependency issue, open an issue with the `roadmap-blocker` label.
5. **Update this file:** If you're a maintainer and a deliverable changes status, submit a PR editing this `ROADMAP.md` file and reference the relevant milestone issue.

Please keep proposals focused, include concrete use cases, and be respectful of maintainers' time. The roadmap is a living document and will be reviewed quarterly.
