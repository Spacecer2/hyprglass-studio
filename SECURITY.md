# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < Latest | :x:               |

Only the latest version receives security updates. Please ensure you are running the most recent release.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

- **Email:** Create a GitHub issue with the "security" label
- **Preferred:** Open an issue at [GitHub Issues](https://github.com/Spacecer2/hyprglass-studio/issues)

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Suggested fix (if applicable)

Do **not** disclose vulnerabilities publicly until a fix is available.

## Security Practices

### No Hardcoded Secrets

The codebase is scanned for hardcoded credentials, API keys, tokens, and other sensitive data. All secrets must be provided via environment variables or secure configuration files that are excluded from version control.

### Input Validation

All user inputs, plugin parameters, and external data are validated before processing. This includes:
- Type checking and sanitization
- Length and format validation
- Rejection of unexpected or malformed data

### Safe File Operations

File system operations follow security best practices:
- Path traversal prevention
- Atomic writes to prevent corruption
- Temporary file cleanup
- Restricted directory permissions where applicable

## Audit History

### 2026-07-12 — Full script and server audit

A security audit of `install.sh`, `uninstall.sh`, `src/server.py`, and all scripts under `scripts/` was performed. The following issues were identified and fixed:

#### Studio server (`src/server.py`)

- **Issue:** State-changing endpoints (`/api/apply`, `/api/preview`) had no authentication, so any local user connecting to the loopback interface could modify the Hyprland configuration.
- **Fix:** Added optional token authentication. Set the `STUDIO_TOKEN` environment variable and send the same value in the `X-HyprGlass-Token` request header. Without a token the server still starts for backward compatibility but prints a warning. The default bind address remains `127.0.0.1`; binding to a non-loopback address now emits a warning.

#### Temporary file handling

- **Issue:** Several scripts created temporary files with bare `mktemp`, placing them in `/tmp` (world-writable) where symlink attacks are possible.
- **Fix:** Updated the following scripts to create temporary files under the destination configuration directory with `mktemp -p` and restricted permissions (`chmod 600`):
  - `uninstall.sh`
  - `scripts/JaKooLitUpdateHook.sh`
  - `scripts/MigrateHyprglassConfig.sh`

#### Installer path validation

- **Issue:** `install.sh` only validated that `HYPR_DIR` and `WALLUST_DIR` were under `$HOME`.
- **Fix:** Extended `validate_target_paths` to also validate `USER_CONFIGS_DIR`, `SCRIPTS_DIR`, `PROFILES_DIR`, and `BACKUP_DIR`.

#### Uninstaller backup cleanup

- **Issue:** `uninstall.sh` offered to remove the entire `~/.config/hypr/backups` directory, which could delete unrelated backups.
- **Fix:** Cleanup now removes only `hyprglass-studio-*` directories inside the backups folder.

#### Wallust cache permissions

- **Issue:** `scripts/WallustHyprglassHook.sh` wrote the wallust color cache with default permissions.
- **Fix:** The cache file is now created with `chmod 600` so only the owner can read it.

#### Other verified security properties

- No `curl ... | bash` or equivalent remote auto-execution patterns exist.
- No `sudo`, `doas`, or `pkexec` privilege escalation is performed; `install.sh` explicitly refuses to run as root unless `--allow-root` is passed.
- No `eval` or dynamic code execution is used in shell scripts.
- No world-writable files are created.
- `server.py` uses `json.loads` for request bodies (no unsafe deserialization), validates `Content-Length`, writes only to fixed paths under `$HOME`, and invokes the validator with a list argument (no shell injection).

## Plugin Permissions

When using Hyprglass Studio plugins, be aware:

- Plugins run within a sandboxed context with limited system access
- Network requests are subject to content security policies
- File access is restricted to designated plugin directories
- User consent is required for any elevated permissions
- Plugin capabilities are declared and auditable

## Best Practices for Users

- Keep the application and plugins updated to the latest version
- Only install plugins from trusted sources
- Review plugin permission requests before granting access
- Report suspicious behavior immediately
- Use strong, unique credentials for any integrated services

### Securing the Studio server

When running `src/server.py` or `HyprglassTray.py`:

1. Start the server with a token:
   ```bash
   export STUDIO_TOKEN="$(openssl rand -hex 32)"
   python3 src/server.py
   ```
2. Do not bind to `0.0.0.0` unless you understand the network exposure.
3. The tray applet currently launches the server without a token. For a multi-user system, launch the server manually with `STUDIO_TOKEN` set and configure the tray to connect to the existing instance.
