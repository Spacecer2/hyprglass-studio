#!/bin/bash
# JaKooLitUpdateHook.sh — Restore HyprGlass config after JaKooLit's copy.sh
#
# This hook re-applies HyprGlass-specific configuration that JaKooLit's update
# script overwrites. It is safe to run multiple times.
#
# Usage: JaKooLitUpdateHook.sh

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
HYPR_DIR="${HOME}/.config/hypr"
USER_CONFIGS="${HYPR_DIR}/UserConfigs"
SCRIPTS_DIR="${HYPR_DIR}/scripts"

HYPRLAND_CONF="${HYPR_DIR}/hyprland.conf"
HYPGLASS_CONF="${USER_CONFIGS}/Hyprglass.conf"
USER_DECORATIONS="${USER_CONFIGS}/UserDecorations.conf"
FIX_SCRIPT="${SCRIPTS_DIR}/FixHyprglassValues.sh"

BACKUPS_DIR="${HYPR_DIR}/backups"
SNAPSHOT_DIR="${BACKUPS_DIR}/hyprglass-studio/hook-snapshot"

HYPGLASS_SRC_LINE='source= $UserConfigs/Hyprglass.conf'
HYPGLASS_EXEC_LINE='exec-once = $HOME/.config/hypr/scripts/FixHyprglassValues.sh'

# ── Logging ──────────────────────────────────────────────────────────────────
log_info() { printf '\033[0;36m[INFO]\033[0m  %s\n' "$*"; }
log_warn() { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERR ]\033[0m  %s\n' "$*" >&2; }
log_ok()   { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }

# ── Helpers ──────────────────────────────────────────────────────────────────
find_latest_backup_dir() {
    local latest=""
    if [[ -d "${BACKUPS_DIR}" ]]; then
        latest=$(find "${BACKUPS_DIR}" -maxdepth 1 -type d \
            \( -name 'hyprglass*' -o -name 'hyprglass-studio*' \) \
            -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    fi
    printf '%s\n' "${latest}"
}

find_latest_apply_conf() {
    local dir="$1"
    find "${dir}" -maxdepth 1 -name 'apply-*.conf' \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

file_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "${file}" ]] && grep -qE "${pattern}" "${file}"
}

# ── 1 & 2. Restore Hyprglass.conf if missing ─────────────────────────────────
ensure_hyprglass_conf() {
    if [[ -f "${HYPGLASS_CONF}" ]]; then
        log_ok "Hyprglass.conf is present"
        return 0
    fi

    log_warn "Hyprglass.conf is missing; searching backup..."

    local backup_dir
    backup_dir=$(find_latest_backup_dir)

    if [[ -z "${backup_dir}" ]]; then
        log_error "No HyprGlass backup directory found in ${BACKUPS_DIR}"
        return 1
    fi

    local src=""
    if [[ -f "${backup_dir}/UserConfigs/Hyprglass.conf" ]]; then
        src="${backup_dir}/UserConfigs/Hyprglass.conf"
    elif [[ -f "${backup_dir}/Hyprglass.conf" ]]; then
        src="${backup_dir}/Hyprglass.conf"
    elif [[ -d "${backup_dir}" ]]; then
        src=$(find_latest_apply_conf "${backup_dir}")
    fi

    if [[ -z "${src}" || ! -f "${src}" ]]; then
        log_error "No Hyprglass.conf backup found in ${backup_dir}"
        return 1
    fi

    mkdir -p "${USER_CONFIGS}"
    cp -f "${src}" "${HYPGLASS_CONF}"
    log_ok "Restored Hyprglass.conf from ${src}"
}

# ── 3. Re-add Hyprglass source line to hyprland.conf ─────────────────────────
ensure_source_line() {
    if [[ ! -f "${HYPRLAND_CONF}" ]]; then
        log_error "hyprland.conf not found at ${HYPRLAND_CONF}"
        return 1
    fi

    # Match "source = ...Hyprglass.conf" regardless of spacing or $UserConfigs path
    if file_contains "${HYPRLAND_CONF}" '^[[:space:]]*source[[:space:]]*=[[:space:]]*.*Hyprglass\.conf'; then
        log_ok "Hyprglass source line is present"
        return 0
    fi

    log_warn "Hyprglass source line missing; re-adding..."

    local tmp
    tmp=$(mktemp -p "${HYPR_DIR}")
    chmod 600 "$tmp"
    trap 'rm -f "${tmp}"' RETURN

    if file_contains "${HYPRLAND_CONF}" '^[[:space:]]*source[[:space:]]*='; then
        local last_source
        last_source=$(grep -nE '^[[:space:]]*source[[:space:]]*=' "${HYPRLAND_CONF}" | tail -1 | cut -d: -f1)
        {
            head -n "${last_source}" "${HYPRLAND_CONF}"
            printf '\n# HyprGlass — restored by JaKooLitUpdateHook.sh (must be sourced last)\n%s\n' "${HYPGLASS_SRC_LINE}"
            tail -n +$((last_source + 1)) "${HYPRLAND_CONF}"
        } > "${tmp}"
    else
        cat "${HYPRLAND_CONF}" > "${tmp}"
        printf '\n# HyprGlass — restored by JaKooLitUpdateHook.sh\n%s\n' "${HYPGLASS_SRC_LINE}" >> "${tmp}"
    fi

    mv -f "${tmp}" "${HYPRLAND_CONF}"
    log_ok "Added Hyprglass source line to ${HYPRLAND_CONF}"
}

# ── 4. Re-add exec-once for FixHyprglassValues.sh ────────────────────────────
ensure_exec_line() {
    if [[ ! -f "${HYPRLAND_CONF}" ]]; then
        log_error "hyprland.conf not found at ${HYPRLAND_CONF}"
        return 1
    fi

    if file_contains "${HYPRLAND_CONF}" 'FixHyprglassValues\.sh'; then
        log_ok "FixHyprglassValues.sh exec-once is present"
        return 0
    fi

    log_warn "FixHyprglassValues.sh exec-once missing; re-adding..."

    local tmp
    tmp=$(mktemp -p "${HYPR_DIR}")
    chmod 600 "$tmp"
    trap 'rm -f "${tmp}"' RETURN

    if file_contains "${HYPRLAND_CONF}" '^[[:space:]]*exec-once[[:space:]]*='; then
        local last_exec
        last_exec=$(grep -nE '^[[:space:]]*exec-once[[:space:]]*=' "${HYPRLAND_CONF}" | tail -1 | cut -d: -f1)
        {
            head -n "${last_exec}" "${HYPRLAND_CONF}"
            printf '\n# HyprGlass — restored by JaKooLitUpdateHook.sh\n%s\n' "${HYPGLASS_EXEC_LINE}"
            tail -n +$((last_exec + 1)) "${HYPRLAND_CONF}"
        } > "${tmp}"
    else
        cat "${HYPRLAND_CONF}" > "${tmp}"
        printf '\n# HyprGlass — restored by JaKooLitUpdateHook.sh\n%s\n' "${HYPGLASS_EXEC_LINE}" >> "${tmp}"
    fi

    mv -f "${tmp}" "${HYPRLAND_CONF}"
    log_ok "Added exec-once for FixHyprglassValues.sh to ${HYPRLAND_CONF}"
}

# ── 5. Restore UserDecorations.conf opacity/border settings ──────────────────
get_decoration_value() {
    local key="$1"
    grep -E "^[[:space:]]*${key}[[:space:]]*=" "${USER_DECORATIONS}" 2>/dev/null | head -1 | sed -E 's/^[^=]+=[[:space:]]*//;s/[[:space:]]*$//'
}

is_hyprglass_tuned() {
    local active_opacity dim_inactive active_border
    active_opacity=$(get_decoration_value 'active_opacity')
    dim_inactive=$(get_decoration_value 'dim_inactive')
    active_border=$(get_decoration_value 'col\.active_border')

    # HyprGlass tuning indicators:
    #   - active_opacity below 1.0 (transparency required for the effect)
    #   - dim_inactive disabled (avoids darkening glass layers)
    #   - transparent borders (rgba with all-zero alpha)
    [[ "${active_opacity}" != "1.0" && "${active_opacity}" != "1" ]] || return 1
    [[ "${dim_inactive}" == "false" ]] || return 1
    [[ "${active_border}" =~ ^rgba\(0+\)$ ]] || return 1

    return 0
}

ensure_user_decorations() {
    if [[ ! -f "${USER_DECORATIONS}" ]]; then
        log_error "UserDecorations.conf not found at ${USER_DECORATIONS}"
        return 1
    fi

    if is_hyprglass_tuned; then
        log_ok "UserDecorations.conf is HyprGlass-tuned"

        # Refresh the hook snapshot so it stays in sync with manual tweaks
        if [[ ! -f "${SNAPSHOT_DIR}/UserDecorations.conf" ]]; then
            mkdir -p "${SNAPSHOT_DIR}"
            cp -f "${USER_DECORATIONS}" "${SNAPSHOT_DIR}/UserDecorations.conf"
            log_ok "Created hook snapshot of UserDecorations.conf"
        fi
        return 0
    fi

    log_warn "UserDecorations.conf appears to have JaKooLit defaults; restoring HyprGlass settings..."

    local snapshot="${SNAPSHOT_DIR}/UserDecorations.conf"
    if [[ -f "${snapshot}" ]]; then
        cp -f "${snapshot}" "${USER_DECORATIONS}"
        log_ok "Restored UserDecorations.conf from hook snapshot"
        return 0
    fi

    log_warn "No hook snapshot exists; applying known-good HyprGlass defaults..."

    # Inline patch: keep the user's layout/colors but force the values
    # that JaKooLit's copy.sh resets to opaque/bordered defaults.
    sed -i -E \
        -e 's/^([[:space:]]*)col\.active_border[[:space:]]*=.*/\1col.active_border = rgba(00000000)/' \
        -e 's/^([[:space:]]*)col\.inactive_border[[:space:]]*=.*/\1col.inactive_border = rgba(00000000)/' \
        -e 's/^([[:space:]]*)active_opacity[[:space:]]*=.*/\1active_opacity = 0.75/' \
        -e 's/^([[:space:]]*)inactive_opacity[[:space:]]*=.*/\1inactive_opacity = 0.65/' \
        -e 's/^([[:space:]]*)fullscreen_opacity[[:space:]]*=.*/\1fullscreen_opacity = 1.0/' \
        -e 's/^([[:space:]]*)dim_inactive[[:space:]]*=.*/\1dim_inactive = false/' \
        -e 's/^([[:space:]]*)size[[:space:]]*=.*/\1size = 8/' \
        -e 's/^([[:space:]]*)passes[[:space:]]*=.*/\1passes = 4/' \
        -e 's/^([[:space:]]*)xray[[:space:]]*=.*/\1xray = false/' \
        -e 's/^([[:space:]]*)ignore_opacity[[:space:]]*=.*/\1ignore_opacity = false/' \
        "${USER_DECORATIONS}"

    # Create the snapshot from the patched file for next time
    mkdir -p "${SNAPSHOT_DIR}"
    cp -f "${USER_DECORATIONS}" "${SNAPSHOT_DIR}/UserDecorations.conf"

    log_ok "Patched UserDecorations.conf with HyprGlass defaults and created snapshot"
}

# ── 6. Run FixHyprglassValues.sh ─────────────────────────────────────────────
run_fix_script() {
    if [[ ! -f "${FIX_SCRIPT}" ]]; then
        log_error "FixHyprglassValues.sh not found at ${FIX_SCRIPT}"
        return 1
    fi

    chmod +x "${FIX_SCRIPT}"
    log_info "Running FixHyprglassValues.sh..."

    # The fix script sleeps and applies values with delays; run it asynchronously
    # so the update hook itself returns promptly.
    nohup "${FIX_SCRIPT}" >/dev/null 2>&1 &
    log_ok "FixHyprglassValues.sh started (PID $!)"
}

# ── 7. Send notification ─────────────────────────────────────────────────────
send_notification() {
    local icon="${1:-preferences-desktop}"
    local urgency="${2:-low}"
    local title="${3:-HyprGlass Update Hook}"
    local body="${4:-HyprGlass configuration restored after JaKooLit update}"

    if command -v notify-send &>/dev/null; then
        notify-send -i "${icon}" -u "${urgency}" "${title}" "${body}"
    else
        log_warn "notify-send not found; skipping desktop notification"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local had_error=false

    ensure_hyprglass_conf    || had_error=true
    ensure_source_line       || had_error=true
    ensure_exec_line         || had_error=true
    ensure_user_decorations  || had_error=true
    run_fix_script           || had_error=true

    if [[ "${had_error}" == "true" ]]; then
        log_error "JaKooLitUpdateHook finished with errors"
        send_notification "dialog-error" "normal" "HyprGlass Update Hook" \
            "Some restores failed. Check the terminal log."
        return 1
    fi

    log_ok "HyprGlass configuration restored successfully"
    send_notification "preferences-desktop" "low" "HyprGlass Update Hook" \
        "HyprGlass config restored after JaKooLit update"
}

main "$@"
