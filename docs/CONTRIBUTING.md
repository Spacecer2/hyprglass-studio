# Contributing to Hyprglass Studio

Thank you for your interest in contributing! This guide will help you get started.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/hyprglass-studio.git
   cd hyprglass-studio
   ```

2. Install dependencies:
   - Python 3
   - hyprpm (Hyprland Package Manager)

3. Run in development mode:
   ```bash
   ./scripts/dev.sh
   ```

## Project Structure

```
src/         - Plugin source (C++)
scripts/     - Shell scripts
templates/   - Wallust templates
profiles/    - Session profiles
docs/        - Documentation
```

## Coding Standards

- **Shell scripts**: Use bash, ensure shellcheck clean
- **Python**: Follow PEP 8, use type hints
- **JavaScript**: ES6+, no comments unless complex

## Testing

1. Test on a fresh Hyprland install
2. Verify all profiles work correctly
3. Check wallust integration

## Pull Request Process

1. Fork and branch from main
2. Test your changes thoroughly
3. Update documentation if needed
4. Submit with a clear description of changes

## Issue Reporting

When reporting issues, please include:

1. Output of `hyprctl plugins`
2. Contents of `Hyprglass.conf`
3. Steps to reproduce the issue

## Questions?

Open an issue with the "question" label or reach out on Discord.
