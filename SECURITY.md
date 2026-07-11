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
- **Preferred:** Open an issue at [GitHub Issues](https://github.com/hyprglass-studio/hyprglass-studio/issues)

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