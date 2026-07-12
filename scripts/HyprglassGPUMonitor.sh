#!/usr/bin/env bash
# HyprglassGPUMonitor.sh - GPU-driven automatic profile switching for HyprGlass
#
# Monitors GPU utilization and switches to the configured gaming profile when
# load crosses the high threshold. Once GPU utilization drops below the low
# threshold for a sustained period, the previously active profile is restored.
#
# Supported GPU tools (auto-detected in this order):
#   - nvidia-smi (NVIDIA)
#   - intel_gpu_top (Intel)
#   - radeontop (AMD)
#
# Usage:
#   HyprglassGPUMonitor.sh [--daemon|--one-shot|--status|--help]
#
# Environment variables:
#   HG_GPU_POLL_INTERVAL  Seconds between checks (default: 5)
#   HG_GPU_HIGH           High-usage threshold % (default: 80)
#   HG_GPU_LOW            Low-usage threshold % (default: 40)
#   HG_GPU_LOW_DURATION   Seconds below low threshold before restore (default: 60)
#   HG_GPU_GAMING_PROFILE Profile to apply on high load (default: gaming)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SCRIPT="${SCRIPT_DIR}/HyprglassProfile.sh"

LOG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/logs"
LOG_FILE="${LOG_DIR}/hyprglass-gpu.log"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_FILE="${CACHE_DIR}/.hyprglass_gpu_monitor_state"
PID_FILE="${CACHE_DIR}/.hyprglass_gpu_monitor.pid"
CURRENT_PROFILE_CACHE="${CACHE_DIR}/.hyprglass_profile"

POLL_INTERVAL="${HG_GPU_POLL_INTERVAL:-5}"
HIGH_THRESHOLD="${HG_GPU_HIGH:-80}"
LOW_THRESHOLD="${HG_GPU_LOW:-40}"
LOW_DURATION="${HG_GPU_LOW_DURATION:-60}"
GAMING_PROFILE="${HG_GPU_GAMING_PROFILE:-gaming}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    mkdir -p "${LOG_DIR}"
    printf '%s\n' "$msg" >> "${LOG_FILE}"
}

# Safe wrapper for reading GPU usage that never aborts the monitor loop.
get_gpu_usage_safe() {
    local tool="$1"
    local usage
    usage=$(get_gpu_usage "$tool" 2>/dev/null) || true
    printf '%s' "$usage"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [--daemon|--one-shot|--status|--help]

Modes:
  --daemon    Run continuously in the background (default)
  --one-shot  Check GPU usage once, switch if needed, then exit
  --status    Print current profile, GPU usage, and monitor state
  --help      Show this help message

Environment variables:
  HG_GPU_POLL_INTERVAL  Seconds between checks (default: ${POLL_INTERVAL})
  HG_GPU_HIGH           High-usage threshold % (default: ${HIGH_THRESHOLD})
  HG_GPU_LOW            Low-usage threshold % (default: ${LOW_THRESHOLD})
  HG_GPU_LOW_DURATION   Seconds below low threshold before restore (default: ${LOW_DURATION})
  HG_GPU_GAMING_PROFILE Profile to apply on high load (default: ${GAMING_PROFILE})

Log file: ${LOG_FILE}
EOF
}

current_profile() {
    cat "${CURRENT_PROFILE_CACHE}" 2>/dev/null || echo "default"
}

apply_profile() {
    local profile="$1"
    if [[ ! -x "${PROFILE_SCRIPT}" ]]; then
        log "Profile script not found or not executable: ${PROFILE_SCRIPT}"
        return 1
    fi
    if "${PROFILE_SCRIPT}" apply "${profile}" >/dev/null 2>&1; then
        log "Applied profile: ${profile}"
        return 0
    else
        log "Failed to apply profile: ${profile}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# GPU detection and usage reading
# ---------------------------------------------------------------------------
detect_gpu_tool() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "nvidia"
    elif command -v intel_gpu_top >/dev/null 2>&1; then
        echo "intel"
    elif command -v radeontop >/dev/null 2>&1; then
        echo "amd"
    else
        echo "none"
    fi
}

get_nvidia_usage() {
    local val
    val=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | awk '{print int($1)}')
    [[ -n "$val" ]] && printf '%d' "$val"
}

get_intel_usage() {
    local output val

    # Prefer JSON output when available; sample once with a 1s window.
    if output=$(intel_gpu_top -J -s 1000 -l 1 2>/dev/null); then
        # Expected format: {"engines":{"Render/3D/0":{"busy":12.34,...}}}
        val=$(printf '%s' "$output" | grep -oP '"Render/3D/0"\s*:\s*\{\s*"busy"\s*:\s*\K[0-9]+(\.[0-9]+)?' | head -n1)
        if [[ -n "$val" ]]; then
            printf '%d' "${val%.*}"
            return
        fi
    fi

    # Fallback to text output.
    output=$(timeout 2 intel_gpu_top -s 1000 2>/dev/null | head -n 20)
    val=$(printf '%s' "$output" | grep -oiE 'render/3d[^0-9]*[0-9]+(\.[0-9]+)?%' | head -n1 | grep -oP '[0-9]+(\.[0-9]+)?' | head -n1)
    [[ -n "$val" ]] && printf '%d' "${val%.*}"
}

get_amd_usage() {
    local output val
    output=$(radeontop -d - -l 1 2>/dev/null)
    val=$(printf '%s' "$output" | grep -oP 'gpu\s+\K[0-9]+(\.[0-9]+)?' | head -n1)
    [[ -n "$val" ]] && printf '%d' "${val%.*}"
}

get_gpu_usage() {
    local tool="$1" usage
    case "$tool" in
        nvidia) usage=$(get_nvidia_usage) ;;
        intel)  usage=$(get_intel_usage)  ;;
        amd)    usage=$(get_amd_usage)    ;;
        *)      usage=""                 ;;
    esac
    if [[ "$usage" =~ ^[0-9]+$ ]]; then
        printf '%d' "$usage"
    fi
}

# ---------------------------------------------------------------------------
# Monitoring logic
# ---------------------------------------------------------------------------
run_monitor_loop() {
    local tool
    tool=$(detect_gpu_tool)

    mkdir -p "${LOG_DIR}"
    log "GPU monitor started (tool: ${tool}, high: ${HIGH_THRESHOLD}%, low: ${LOW_THRESHOLD}%, duration: ${LOW_DURATION}s)."

    if [[ "$tool" == "none" ]]; then
        log "No supported GPU monitoring tool found (nvidia-smi, intel_gpu_top, or radeontop). Exiting."
        return 1
    fi

    local low_counter=0
    local usage previous_profile

    while true; do
        usage=$(get_gpu_usage_safe "$tool")

        if [[ -z "$usage" ]]; then
            log "Could not read GPU usage (tool: ${tool}). Skipping this cycle."
            sleep "${POLL_INTERVAL}"
            continue
        fi

        local active_profile
        active_profile=$(current_profile)

        if (( usage > HIGH_THRESHOLD )); then
            if [[ "$active_profile" != "$GAMING_PROFILE" ]]; then
                # Remember the profile we are switching away from, but only if
                # we are not already in an auto-switched state.
                if [[ ! -f "$STATE_FILE" ]]; then
                    printf '%s\n' "$active_profile" > "$STATE_FILE"
                fi
                apply_profile "$GAMING_PROFILE"
                log "High GPU load detected (${usage}% > ${HIGH_THRESHOLD}%). Switched to '${GAMING_PROFILE}' (previous: $(cat "$STATE_FILE" 2>/dev/null || echo default))."
            fi
            low_counter=0
        elif (( usage < LOW_THRESHOLD )); then
            if [[ "$active_profile" == "$GAMING_PROFILE" && -f "$STATE_FILE" ]]; then
                low_counter=$((low_counter + POLL_INTERVAL))
                if (( low_counter >= LOW_DURATION )); then
                    previous_profile=$(cat "$STATE_FILE" 2>/dev/null || echo "default")
                    [[ -z "$previous_profile" ]] && previous_profile="default"
                    apply_profile "$previous_profile"
                    log "GPU load stayed below ${LOW_THRESHOLD}% for ${LOW_DURATION}s (current: ${usage}%). Restored previous profile '${previous_profile}'."
                    rm -f "$STATE_FILE"
                    low_counter=0
                fi
            else
                low_counter=0
            fi
        else
            low_counter=0
        fi

        sleep "${POLL_INTERVAL}"
    done
}

run_one_shot() {
    local tool usage active_profile previous_profile
    tool=$(detect_gpu_tool)

    if [[ "$tool" == "none" ]]; then
        log "No supported GPU monitoring tool found."
        return 1
    fi

    usage=$(get_gpu_usage_safe "$tool")
    active_profile=$(current_profile)

    if [[ -z "$usage" ]]; then
        log "Could not read GPU usage (tool: ${tool})."
        return 1
    fi

    log "One-shot check: GPU ${usage}%, active profile '${active_profile}'."

    if (( usage > HIGH_THRESHOLD )) && [[ "$active_profile" != "$GAMING_PROFILE" ]]; then
        [[ ! -f "$STATE_FILE" ]] && printf '%s\n' "$active_profile" > "$STATE_FILE"
        apply_profile "$GAMING_PROFILE"
    elif (( usage < LOW_THRESHOLD )) && [[ "$active_profile" == "$GAMING_PROFILE" && -f "$STATE_FILE" ]]; then
        previous_profile=$(cat "$STATE_FILE" 2>/dev/null || echo "default")
        [[ -z "$previous_profile" ]] && previous_profile="default"
        apply_profile "$previous_profile"
        rm -f "$STATE_FILE"
    fi
}

show_status() {
    local tool usage active_profile saved_profile
    tool=$(detect_gpu_tool)
    usage=$(get_gpu_usage_safe "$tool")
    active_profile=$(current_profile)
    saved_profile=$(cat "$STATE_FILE" 2>/dev/null || echo "(none)")

    cat <<EOF
GPU tool:       ${tool}
GPU usage:      ${usage:-unknown}%
Active profile: ${active_profile}
Saved profile:  ${saved_profile}
High threshold: ${HIGH_THRESHOLD}
Low threshold:  ${LOW_THRESHOLD}
Low duration:   ${LOW_DURATION}
PID file:       ${PID_FILE}
Log file:       ${LOG_FILE}
EOF
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main() {
    local mode="${1:---daemon}"

    case "$mode" in
        --help|-h)
            usage
            exit 0
            ;;
        --status|-s)
            show_status
            exit 0
            ;;
    esac

    # Ensure only one daemon/one-shot instance is running.
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log "GPU monitor already running (PID: ${old_pid}). Exiting."
            exit 0
        fi
    fi

    # Clean up PID file on exit.
    cleanup() {
        rm -f "$PID_FILE"
        log "GPU monitor stopped."
    }
    trap cleanup EXIT INT TERM

    mkdir -p "${LOG_DIR}" "${CACHE_DIR}"
    echo $$ > "$PID_FILE"

    case "$mode" in
        --daemon|-d)
            run_monitor_loop
            ;;
        --one-shot|-1)
            run_one_shot
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
