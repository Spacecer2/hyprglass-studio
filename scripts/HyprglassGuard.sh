#!/usr/bin/env bash
# HyprglassGuard.sh - Watches Hyprglass.conf and restores it from a known-good backup if corruption is detected.
# Also monitors GPU utilization and warns when glass effects should be throttled.
# Intended to be launched once by Hyprland via exec-once.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFIER="$SCRIPT_DIR/HyprglassNotify.sh"

HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
HYPGLASS_CONF="${HYPR_DIR}/UserConfigs/Hyprglass.conf"
KNOWN_GOOD_DIR="${HYPR_DIR}/backups/hyprglass-known-good"
VALIDATOR="$SCRIPT_DIR/ValidateHyprglassConf.sh"

# Check interval in seconds
CHECK_INTERVAL=5
# GPU throttle check interval in seconds (GPU utilization changes slowly)
GPU_CHECK_INTERVAL=30
# GPU throttle threshold (% utilization)
GPU_THROTTLE_PCT=90
# Minimum seconds between GPU throttle notifications
GPU_THROTTLE_COOLDOWN=120

last_gpu_notify=0
last_gpu_check=0
last_conf_mtime=0
cached_known_good=""

notify() {
    local event="$1" msg="$2"
    [[ -x "$NOTIFIER" ]] && "$NOTIFIER" "$event" "$msg" || true
}

validate_conf() {
    [[ -f "$HYPGLASS_CONF" ]] || return 1
    [[ -x "$VALIDATOR" ]] || return 0
    "$VALIDATOR" "$HYPGLASS_CONF" >/dev/null 2>&1
}

find_known_good() {
    if [[ -n "$cached_known_good" && -f "$cached_known_good" ]]; then
        printf '%s\n' "$cached_known_good"
        return 0
    fi

    [[ -d "$KNOWN_GOOD_DIR" ]] || return 1
    cached_known_good=$(find "$KNOWN_GOOD_DIR" -maxdepth 1 -type f -name 'Hyprglass.conf*' -print -quit 2>/dev/null)
    [[ -n "$cached_known_good" && -f "$cached_known_good" ]] || return 1
    printf '%s\n' "$cached_known_good"
}

restore_conf() {
    local backup
    backup=$(find_known_good)
    [[ -n "$backup" && -f "$backup" ]] || return 1

    mkdir -p "$(dirname "$HYPGLASS_CONF")"
    cp -f "$backup" "$HYPGLASS_CONF"
    if command -v hyprctl &>/dev/null; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
    notify config-restored "Restored Hyprglass.conf from known-good backup"

    # Refresh mtime cache so we do not immediately re-validate the restored file
    last_conf_mtime=$(stat -c %Y "$HYPGLASS_CONF" 2>/dev/null || echo 0)
}

# Check whether Hyprglass.conf is corrupt and restore if needed.
# Skips validation when the file has not changed since the last check.
check_config() {
    if [[ ! -f "$HYPGLASS_CONF" ]]; then
        restore_conf
        return 0
    fi

    local mtime
    mtime=$(stat -c %Y "$HYPGLASS_CONF" 2>/dev/null || echo 0)
    if (( mtime == last_conf_mtime )); then
        return 0
    fi
    last_conf_mtime=$mtime

    if ! validate_conf; then
        restore_conf
    fi
}

# Best-effort GPU utilization check. Supports nvidia-smi; other vendors fall back to /sys usage.
check_gpu_throttle() {
    local now
    now=$(date +%s)
    (( now - last_gpu_check >= GPU_CHECK_INTERVAL )) || return 0
    last_gpu_check=$now

    local pct=""

    if command -v nvidia-smi &>/dev/null; then
        # Capture all output first to avoid SIGPIPE from head closing the pipe.
        local nvidia_out
        nvidia_out=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true)
        pct=$(echo "$nvidia_out" | head -1 | tr -d '[:space:]')
    fi

    # Fallback: try to find a GPU hwmon load attribute
    if [[ -z "$pct" ]]; then
        local hwmon
        for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*; do
            if [[ -r "${hwmon}/in0_input" ]]; then
                continue
            fi
            if [[ -r "${hwmon}/fan1_input" ]]; then
                # amdgpu often exposes pwm1 / freq1 / power1 instead of a simple load percentage
                if [[ -r "${hwmon}/power1_average" ]]; then
                    # Cannot easily derive utilization; skip
                    continue
                fi
            fi
        done
    fi

    if [[ "$pct" =~ ^[0-9]+$ ]]; then
        if (( pct > GPU_THROTTLE_PCT )); then
            if (( now - last_gpu_notify > GPU_THROTTLE_COOLDOWN )); then
                notify gpu-throttle "GPU utilization ${pct}% — consider reducing glass effects"
                last_gpu_notify=$now
            fi
        fi
    fi
}

# Use inotify-based watching when available to avoid periodic validation.
# Falls back to the legacy polling loop if inotifywait is unavailable.
run_event_loop() {
    if command -v inotifywait &>/dev/null; then
        # Validate once at startup, then wait for file changes
        check_config
        while true; do
            check_gpu_throttle
            # Block until the config changes or the GPU interval elapses
            inotifywait -q -q -t "$GPU_CHECK_INTERVAL" -e modify,move_self,delete_self "$HYPGLASS_CONF" 2>/dev/null || true
            check_config
        done
    else
        while true; do
            check_config
            check_gpu_throttle
            sleep "$CHECK_INTERVAL"
        done
    fi
}

main() {
    [[ -d "$KNOWN_GOOD_DIR" ]] || mkdir -p "$KNOWN_GOOD_DIR"

    run_event_loop
}

# Only run the daemon when this script is executed directly; do not auto-run
# when it is sourced by tests or other scripts.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    :  # executed directly; run the daemon loop below
    main "$@"
fi
