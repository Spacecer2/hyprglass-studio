#!/usr/bin/env bash
# OpenHyprglassStudio.sh
# Ensures the Studio server is running and opens the web UI in a browser.
# Used by the rofi/app-launcher desktop entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8765}"

"${SCRIPT_DIR}/StartHyprglassStudio.sh"

# Wait until the server accepts connections before opening the browser.
for _ in $(seq 1 25); do
    if command -v curl >/dev/null 2>&1 && curl -sf -o /dev/null "http://localhost:${PORT}"; then
        break
    fi
    sleep 0.2
done

xdg-open "http://localhost:${PORT}"