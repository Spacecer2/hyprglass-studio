#!/usr/bin/env bash
# HyprglassNotify.sh - Desktop notifications for HyprGlass events
# Usage: HyprglassNotify.sh <event-type> [message]
#
# Supported events:
#   profile-switch   - Profile applied successfully
#   config-restored  - Hyprglass.conf restored from known-good backup
#   gpu-throttle     - GPU utilization high; glass effects throttled
#   wallust-update   - Colors updated from wallpaper

set -euo pipefail

EVENT="${1:-}"
MESSAGE="${2:-}"

if [[ -z "$EVENT" ]]; then
    echo "Usage: $(basename "$0") <event-type> [message]" >&2
    echo "Supported events: profile-switch, config-restored, gpu-throttle, wallust-update" >&2
    exit 1
fi

# Defaults
TITLE="HyprGlass"
ICON="dialog-information"
URGENCY="normal"

# Per-event icon and urgency mapping
case "$EVENT" in
    profile-switch)
        TITLE="HyprGlass Profile"
        ICON="preferences-desktop-display"
        URGENCY="low"
        ;;
    config-restored)
        TITLE="HyprGlass Config Restored"
        ICON="document-revert"
        URGENCY="critical"
        ;;
    gpu-throttle)
        TITLE="HyprGlass GPU Throttle"
        ICON="preferences-system-power"
        URGENCY="critical"
        ;;
    wallust-update)
        TITLE="HyprGlass Wallust"
        ICON="preferences-desktop-wallpaper"
        URGENCY="low"
        ;;
    *)
        TITLE="HyprGlass"
        ICON="dialog-information"
        URGENCY="normal"
        ;;
esac

[[ -n "$MESSAGE" ]] || MESSAGE="$TITLE"

if command -v notify-send &>/dev/null; then
    notify-send -i "$ICON" -u "$URGENCY" "$TITLE" "$MESSAGE" 2>/dev/null || true
fi
