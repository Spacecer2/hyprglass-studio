#!/usr/bin/env bash
# HyprglassScheduler.sh - Time-based profile scheduler for HyprGlass
#
# Reads a simple schedule from ~/.config/hypr/hyprglass-schedule.conf and
# switches HyprGlass profiles based on the time of day.
#
# Usage: HyprglassScheduler.sh [--daemon|--one-shot|--status|--stop|--help]
#
# Schedule format:
#   HH:MM profile_name
#   # comment
#
# Example:
#   08:00 coding
#   18:00 default
#   22:00 movies
#
# Environment variables:
#   HG_SCHEDULE_FILE    Path to schedule config
#                       (default: ~/.config/hypr/hyprglass-schedule.conf)
#   HG_SCHEDULER_LOG    Path to log file
#                       (default: ~/.config/hypr/logs/hyprglass-scheduler.log)
#   HG_SCHEDULER_PID    Path to PID file
#                       (default: ~/.cache/.hyprglass_scheduler.pid)

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SCRIPT="${SCRIPT_DIR}/HyprglassProfile.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

SCHEDULE_FILE="${HG_SCHEDULE_FILE:-${CONFIG_HOME}/hypr/hyprglass-schedule.conf}"
LOG_FILE="${HG_SCHEDULER_LOG:-${CONFIG_HOME}/hypr/logs/hyprglass-scheduler.log}"
PID_FILE="${HG_SCHEDULER_PID:-${CACHE_HOME}/.hyprglass_scheduler.pid}"
LAST_PROFILE_FILE="${CACHE_HOME}/.hyprglass_scheduler_profile"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    mkdir -p "$(dirname "${LOG_FILE}")"
    printf '%s\n' "$msg" >> "${LOG_FILE}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [--daemon|--one-shot|--status|--stop|--help]

Modes:
  --daemon    Run continuously in the background (default)
  --one-shot  Apply the profile for the current time, then exit
  --status    Print scheduler status and next scheduled switch
  --stop      Stop a running scheduler daemon
  --help      Show this help message

Environment variables:
  HG_SCHEDULE_FILE    Path to schedule config
                      (default: ${SCHEDULE_FILE})
  HG_SCHEDULER_LOG    Path to log file
                      (default: ${LOG_FILE})
  HG_SCHEDULER_PID    Path to PID file
                      (default: ${PID_FILE})

Schedule file format:
  HH:MM profile_name

Example:
  08:00 coding
  18:00 default
  22:00 movies

Log file: ${LOG_FILE}
EOF
}

# ---------------------------------------------------------------------------
# Schedule parsing
# ---------------------------------------------------------------------------
parse_schedule() {
    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        echo "Schedule file not found: $SCHEDULE_FILE" >&2
        return 1
    fi

    local line time_part profile min h m

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip trailing comments.
        line="${line%%#*}"
        # Trim leading/trailing whitespace.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue

        time_part="${line%%[[:space:]]*}"
        profile="${line#*[[:space:]]}"
        profile="${profile#"${profile%%[![:space:]]*}"}"
        profile="${profile%"${profile##*[![:space:]]}"}"

        if [[ ! "$time_part" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
            echo "Invalid time entry: '$time_part'" >&2
            return 1
        fi

        h="${BASH_REMATCH[1]}"
        m="${BASH_REMATCH[2]}"

        if (( 10#$h > 23 || 10#$m > 59 )); then
            echo "Time out of range: '$time_part'" >&2
            return 1
        fi

        if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Invalid profile name: '$profile'" >&2
            return 1
        fi

        min=$((10#$h * 60 + 10#$m))
        printf '%d\t%s\n' "$min" "$profile"
    done < "$SCHEDULE_FILE" | sort -n -k1,1
}

schedule_count() {
    parse_schedule 2>/dev/null | wc -l
}

current_minutes() {
    local h m
    h=$(date +%H)
    m=$(date +%M)
    echo $((10#$h * 60 + 10#$m))
}

# Return the profile that should be active for the given minute-of-day.
profile_for_minute() {
    local now="$1"
    local entry_time entry_profile selected=""

    while IFS=$'\t' read -r entry_time entry_profile; do
        if (( entry_time <= now )); then
            selected="$entry_profile"
        else
            break
        fi
    done < <(parse_schedule)

    if [[ -z "$selected" ]]; then
        # Before the first entry of the day: wrap around to the last entry.
        selected=$(parse_schedule | tail -n1 | cut -f2)
    fi

    echo "$selected"
}

# Return the next scheduled switch after the given minute-of-day.
next_switch() {
    local now="$1"
    local entry_time entry_profile

    while IFS=$'\t' read -r entry_time entry_profile; do
        if (( entry_time > now )); then
            printf '%02d:%02d -> %s' $((entry_time / 60)) $((entry_time % 60)) "$entry_profile"
            return 0
        fi
    done < <(parse_schedule)

    # Wrap around to the first entry tomorrow.
    local first
    first=$(parse_schedule | head -n1)
    IFS=$'\t' read -r entry_time entry_profile <<< "$first"
    printf '%02d:%02d -> %s (tomorrow)' $((entry_time / 60)) $((entry_time % 60)) "$entry_profile"
}

# ---------------------------------------------------------------------------
# Profile application
# ---------------------------------------------------------------------------
apply_profile() {
    local profile="$1"

    if [[ ! -x "$PROFILE_SCRIPT" ]]; then
        log "Profile script not found or not executable: $PROFILE_SCRIPT"
        return 1
    fi

    if "$PROFILE_SCRIPT" apply "$profile" >/dev/null 2>&1; then
        log "Applied scheduled profile: $profile"
        printf '%s\n' "$profile" > "$LAST_PROFILE_FILE"
        return 0
    else
        log "Failed to apply scheduled profile: $profile"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
run_one_shot() {
    local now target

    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        log "Schedule file not found: $SCHEDULE_FILE"
        return 1
    fi

    if [[ "$(schedule_count)" -eq 0 ]]; then
        log "No schedule entries found in: $SCHEDULE_FILE"
        return 1
    fi

    now=$(current_minutes)
    target=$(profile_for_minute "$now")

    if [[ -z "$target" ]]; then
        log "Could not determine scheduled profile"
        return 1
    fi

    apply_profile "$target"
}

run_daemon() {
    log "Scheduler started. Schedule: $SCHEDULE_FILE"

    while true; do
        if [[ ! -f "$SCHEDULE_FILE" ]]; then
            log "Schedule file missing: $SCHEDULE_FILE. Retrying in 60s..."
            sleep 60
            continue
        fi

        if [[ "$(schedule_count)" -eq 0 ]]; then
            log "No schedule entries found in: $SCHEDULE_FILE. Retrying in 60s..."
            sleep 60
            continue
        fi

        local now target last=""
        now=$(current_minutes)
        target=$(profile_for_minute "$now")
        last=$(cat "$LAST_PROFILE_FILE" 2>/dev/null || true)

        if [[ -n "$target" && "$target" != "$last" ]]; then
            apply_profile "$target"
        fi

        # Sleep until the next minute boundary (plus a small safety margin).
        local sec sleep_secs
        sec=$(date +%S)
        sec="${sec#0}"
        sleep_secs=$((61 - sec))
        sleep "$sleep_secs"
    done
}

show_status() {
    local pid active target next

    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "unknown")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            pid="$pid (running)"
        else
            pid="$pid (stale)"
        fi
    else
        pid="not running"
    fi

    active=$(cat "$LAST_PROFILE_FILE" 2>/dev/null || echo "unknown")

    if [[ -f "$SCHEDULE_FILE" && "$(schedule_count)" -gt 0 ]]; then
        local now
        now=$(current_minutes)
        target=$(profile_for_minute "$now")
        next=$(next_switch "$now")
    else
        target="(schedule not available)"
        next="(schedule not available)"
    fi

    cat <<EOF
Scheduler PID: $pid
Schedule file: $SCHEDULE_FILE
Active profile (last applied): $active
Current scheduled profile: $target
Next switch: $next
Log file: $LOG_FILE
EOF
}

stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            rm -f "$PID_FILE"
            echo "Scheduler stopped (PID $pid)."
        else
            rm -f "$PID_FILE"
            echo "Scheduler not running (stale PID removed)."
        fi
    else
        echo "Scheduler not running."
    fi
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
        --stop)
            stop_daemon
            exit 0
            ;;
    esac

    mkdir -p "$(dirname "${LOG_FILE}")" "$CACHE_HOME"

    case "$mode" in
        --daemon|-d)
            if [[ -f "$PID_FILE" ]]; then
                local old_pid
                old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
                if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
                    log "Scheduler already running (PID: $old_pid). Exiting."
                    exit 0
                fi
            fi

            cleanup() {
                rm -f "$PID_FILE"
                log "Scheduler stopped."
            }
            trap cleanup EXIT INT TERM

            echo $$ > "$PID_FILE"
            run_daemon
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
