# Contributing to Hyprglass Studio

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold its principles.

## Development Setup

### Prerequisites

Ensure you have the following installed:

- **Hyprland** (latest stable release)
- **Python 3.10+**
- **hyprpm** (Hyprland Package Manager)
- **CMake 3.20+**
- **g++** or **clang++** with C++20 support
- **Node.js 18+** and **npm** (for build tooling)

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/hyprglass-studio.git
cd hyprglass-studio

# 2. Create a virtual environment and install Python dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Install npm packages (for build scripts)
npm install

# 4. Build the plugin
make build

# 5. Run in development mode (hot-reload enabled)
./scripts/dev.sh --watch
```

### Manual Build

```bash
# Build only the C++ plugin
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build

# Install plugin manually for testing
hyprpm install build/libhyprglass.so
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `HYPGLASS_LOG_LEVEL` | Logging verbosity (`debug`, `info`, `warn`) | `info` |
| `HYPGLASS_CONFIG_DIR` | Override config directory | `~/.config/hyprglass` |
| `HYPGLASS_THEME` | Default theme on startup | `auto` |

## Project Structure

```
src/           - Plugin source (C++)
scripts/       - Shell scripts
templates/     - Wallust templates
profiles/      - Session profiles
docs/          - Documentation
tests/         - Test suites
```

## Coding Standards

- **Shell scripts**: Use bash, ensure shellcheck clean
- **Python**: Follow PEP 8, use type hints
- **JavaScript**: ES6+, no comments unless complex
- **C++**: Follow `.clang-format` defaults, use smart pointers

## Testing Checklist

Before submitting a PR, verify:

- [ ] All existing tests pass (`make test`)
- [ ] New tests are written for added features
- [ ] Plugin loads without errors (`hyprctl plugins`)
- [ ] Profiles load and switch correctly
- [ ] Wallust integration generates valid colorschemes
- [ ] No memory leaks (run with `valgrind` if applicable)
- [ ] Documentation is updated (if applicable)
- [ ] Changelog entry is added (if applicable)
- [ ] Tested on a fresh Hyprland session

## Pull Request Process

1. Fork and branch from `main`
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make changes following the coding standards
4. Run the test suite and verify locally
5. Update documentation if needed
6. Submit with a clear description of changes

### PR Description Template

```markdown
## Description
Brief summary of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe how you tested your changes.

## Checklist
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] Changelog entry added
```

## Commit Style Guide

We follow [Conventional Commits](https://www.conventionalcommits.org/) for clear, structured history.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code restructuring, no feature/fix |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |
| `ci` | CI/CD changes |

### Examples

```bash
feat(profiles): add dark mode auto-switching
fix(wallust): resolve color cache invalidation
docs(readme): update installation instructions
refactor(core): simplify theme loading logic
test(profiles): add unit tests for profile switcher
chore(deps): update Python dependencies
```

### Breaking Changes

Indicate with `!` before the colon and include a `BREAKING CHANGE` footer:

```
feat(api)!: remove deprecated profile endpoint

BREAKING CHANGE: The /api/profiles/legacy endpoint has been removed.
Migrate to /api/profiles/v2.
```

## Release Process

Releases are automated via GitHub Actions and follow [Semantic Versioning](https://semver.org/).

### Versioning

- **MAJOR** (`X.0.0`): Breaking changes
- **MINOR** (`x.Y.0`): New features (backward compatible)
- **PATCH** (`x.y.Z`): Bug fixes (backward compatible)

### Release Steps

1. Ensure all tests pass on `main`
2. Update `CHANGELOG.md` with release notes (or use auto-generation)
3. Create a release tag:
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0: Add dark mode support"
   git push origin v1.2.0
   ```
4. GitHub Actions will:
   - Build binaries for supported platforms
   - Publish to hyprpm registry
   - Create a GitHub Release with artifacts

### Pre-release Tags

For pre-releases, use suffixes:

```bash
git tag -a v1.2.0-beta.1 -m "Pre-release v1.2.0-beta.1"
```

### Hotfixes

For urgent fixes on a released version:

```bash
git checkout v1.2.0
git checkout -b hotfix/v1.2.1
# Make fix, commit, push
git tag -a v1.2.1 -m "Hotfix: fix critical crash in profile loader"
```

## Issue Reporting

When reporting issues, please include:

1. Output of `hyprctl plugins`
2. Contents of `Hyprglass.conf`
3. Steps to reproduce the issue
4. Expected vs actual behavior
5. Log output (`~/.config/hyprglass/logs/`)

## Questions?

Open an issue with the "question" label or reach out on Discord.
