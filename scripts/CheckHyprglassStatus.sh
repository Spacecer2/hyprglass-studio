#!/usr/bin/env bash
#
# CheckHyprglassStatus.sh
# Health check for the HyprGlass installation.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
HYPRGLASS_PLUGIN_NAME="hyprglass"
HYPRGLASS_CONFIG_DIR="${HOME}/.config/hyprglass"
HYPRGLASS_SOCKET_DIR="/tmp/hyprglass"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ok()   { printf '%bOK%b    - %s\n' "$GREEN" "$NC" "$1"; }
warn() { printf '%bWARN%b  - %s\n' "$YELLOW" "$NC" "$1"; }
fail() { printf '%bFAIL%b  - %s\n' "$RED" "$NC" "$1"; }
info() { printf '%bINFO%b  - %s\n' "$BLUE" "$NC" "$1"; }

header() {
    printf '\n%b==>%b %s\n' "$BLUE" "$NC" "$1"
}

# ---------------------------------------------------------------------------
# Runtime checks
# ---------------------------------------------------------------------------

# 1. Check if hyprglass plugin is loaded
check_plugin_loaded() {
    header "Plugin Status"

    if ! command -v hyprctl &>/dev/null; then
        fail "hyprctl not found in PATH. Is Hyprland running?"
        return 1
    fi

    local plugin_info
    if plugin_info=$(hyprctl plugin list 2>/dev/null | grep -i "${HYPRGLASS_PLUGIN_NAME}"); then
        ok "HyprGlass plugin is loaded"
        info "Plugin: ${plugin_info}"
    else
        fail "HyprGlass plugin is NOT loaded"
        return 1
    fi
}

# 2. Check if enabled
check_enabled() {
    header "Enabled Status"

    local enabled
    enabled=$(hyprctl getoption "plugin:hyprglass:enabled" 2>/dev/null | awk -F': ' '/int:/ {print $2}' | tr -d ' ')

    if [[ "${enabled}" == "1" ]]; then
        ok "HyprGlass is enabled"
    elif [[ "${enabled}" == "0" ]]; then
        warn "HyprGlass is disabled"
    else
        warn "Could not determine enabled status (got: '${enabled}')"
    fi
}

# 3. Check current preset
check_preset() {
    header "Current Preset"

    local preset
    preset=$(hyprctl getoption "plugin:hyprglass:preset" 2>/dev/null | awk -F': ' '/str:/ {print $2}' | sed 's/^ *//;s/ *$//')

    if [[ -n "${preset}" ]]; then
        ok "Current preset: ${preset}"
    else
        warn "No preset configured or option not found"
    fi
}

# 4. Check current profile
check_profile() {
    header "Current Profile"

    local profile
    profile=$(hyprctl getoption "plugin:hyprglass:profile" 2>/dev/null | awk -F': ' '/str:/ {print $2}' | sed 's/^ *//;s/ *$//')

    if [[ -n "${profile}" ]]; then
        ok "Current profile: ${profile}"
    else
        warn "No profile configured or option not found"
    fi
}

# 5. Check opacity settings
check_opacity() {
    header "Opacity Settings"

    local active_opacity inactive_opacity
    active_opacity=$(hyprctl getoption "decoration:active_opacity" 2>/dev/null | awk -F': ' '/float:/ {print $2}' | tr -d ' ')
    inactive_opacity=$(hyprctl getoption "decoration:inactive_opacity" 2>/dev/null | awk -F': ' '/float:/ {print $2}' | tr -d ' ')

    if [[ -n "${active_opacity}" ]]; then
        info "Active window opacity: ${active_opacity}"
    else
        warn "Could not read active opacity"
    fi

    if [[ -n "${inactive_opacity}" ]]; then
        info "Inactive window opacity: ${inactive_opacity}"
    else
        warn "Could not read inactive opacity"
    fi

    # Try HyprGlass-specific opacity option if available
    local hg_opacity
    hg_opacity=$(hyprctl getoption "plugin:hyprglass:opacity" 2>/dev/null | awk -F': ' '/float:/ {print $2}' | tr -d ' ')
    if [[ -n "${hg_opacity}" ]]; then
        info "HyprGlass opacity: ${hg_opacity}"
    fi
}

# 6. Check if config files exist
check_config_files() {
    header "Config Files"

    local files=(
        "${HYPRGLASS_CONFIG_DIR}/hyprglass.conf"
        "${HYPRGLASS_CONFIG_DIR}/presets.conf"
        "${HYPRGLASS_CONFIG_DIR}/profiles.conf"
    )

    local found_any=false
    for file in "${files[@]}"; do
        if [[ -f "${file}" ]]; then
            ok "Found ${file}"
            found_any=true
        else
            warn "Missing ${file}"
        fi
    done

    if [[ "${found_any}" == "false" ]]; then
        warn "No HyprGlass config files found in ${HYPRGLASS_CONFIG_DIR}"
    fi
}

# 7. Check if server is running
check_server() {
    header "Server Status"

    local pid_file="${HYPRGLASS_SOCKET_DIR}/hyprglass.pid"
    local socket="${HYPRGLASS_SOCKET_DIR}/hyprglass.sock"

    if [[ -S "${socket}" ]]; then
        ok "HyprGlass socket exists: ${socket}"
    else
        warn "HyprGlass socket not found: ${socket}"
    fi

    if [[ -f "${pid_file}" ]]; then
        local pid
        pid=$(cat "${pid_file}")
        if kill -0 "${pid}" 2>/dev/null; then
            ok "HyprGlass server is running (PID: ${pid})"
        else
            warn "Stale PID file found (PID: ${pid}), server not running"
        fi
    else
        warn "HyprGlass PID file not found: ${pid_file}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    printf '%b========================================%b\n' "$BLUE" "$NC"
    printf '%b     HyprGlass Health Check Report%b\n' "$BLUE" "$NC"
    printf '%b========================================%b\n' "$BLUE" "$NC"
    printf "Generated: %s\n" "$(date)"

    check_plugin_loaded
    check_enabled
    check_preset
    check_profile
    check_opacity
    check_config_files
    check_server

    printf '\n%b========================================%b\n' "$BLUE" "$NC"
    printf '%b     HyprGlass check complete.%b\n' "$BLUE" "$NC"
    printf '%b========================================%b\n' "$BLUE" "$NC"
}

main "$@"
