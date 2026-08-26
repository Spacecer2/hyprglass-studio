#!/usr/bin/env bash
# StartHyprglassStudio.sh
# Starts the HyprGlass Studio web UI server (localhost:8765).
# A random token is generated once and reused for API auth.

set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
TOKEN_FILE="${CONF_DIR}/.hyprglass_token"
LOG_DIR="${CONF_DIR}/logs"
STUDIO_SERVER="${CONF_DIR}/hyprglass-studio/src/server.py"
PORT="${PORT:-8765}"

mkdir -p "${LOG_DIR}"

if [[ ! -f "${TOKEN_FILE}" ]]; then
    umask 077
    openssl rand -hex 32 > "${TOKEN_FILE}"
fi

STUDIO_TOKEN="$(cat "${TOKEN_FILE}")"
export STUDIO_TOKEN

# Guard against duplicate instances
if pgrep -f "src/server.py --port ${PORT}" >/dev/null 2>&1; then
    exit 0
fi

nohup python3 "${STUDIO_SERVER}" --port "${PORT}" \
    >> "${LOG_DIR}/hyprglass-studio.log" 2>&1 &
disown