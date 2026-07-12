#!/usr/bin/env bash
set -euo pipefail

# ── HyprGlass Studio Uninstaller ──────────────────────────────────────────────
# Removes HyprGlass Studio and restores the previous Hyprland configuration.
# Usage: ./uninstall.sh [--yes] [--keep-plugin] [--keep-backups]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HYPR_DIR="${HOME}/.config/hypr"
WALLUST_DIR="${HOME}/.config/wallust"

HYPRLAND_CONF="${HYPR_DIR}/hyprland.conf"
HYPGLASS_CONF="Hyprglass.conf"
HYPGLASS_SRC="source = ~/.config/hypr/UserConfigs/${HYPGLASS_CONF}"
HYPGLASS_EXEC="exec-once = ~/.config/hypr/scripts/FixHyprglassValues.sh"

AUTO_YES=false
KEEP_PLUGIN=false
KEEP_BACKUPS=false
DRY_RUN=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
fatal()   { error "$*"; exit 1; }
dry()     { echo -e "${MAGENTA}[DRY]${RESET}  $*"; }

# ── Spinner ──────────────────────────────────────────────────────────────────
SPINNER_PID=""

spinner_start() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    (
        while true; do
            for frame in "${frames[@]}"; do
                echo -ne "\r${CYAN}${frame}${RESET} ${msg}  "
                sleep 0.1
            done
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID"
}

spinner_stop() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        echo -ne "\r\033[K"
    fi
}

# ── Confirm prompt ───────────────────────────────────────────────────────────
confirm() {
    if $AUTO_YES; then
        return 0
    fi
    local prompt="${1:-Continue?}"
    echo -en "${BOLD}${prompt} [Y/n]${RESET} "
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# ── Help text ────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}HyprGlass Studio Uninstaller${RESET}

${BOLD}USAGE${RESET}
    $0 [OPTIONS]

${BOLD}OPTIONS${RESET}
    ${BOLD}--yes${RESET}, ${BOLD}-y${RESET}        Skip all confirmation prompts (unattended uninstall)
    ${BOLD}--keep-plugin${RESET}  Leave the hyprglass Hyprland plugin installed
    ${BOLD}--keep-backups${RESET} Do not remove old installer backups
    ${BOLD}--dry-run${RESET}      Show what would be done without making changes
    ${BOLD}--help${RESET}, ${BOLD}-h${RESET}        Show this help message and exit

${BOLD}EXAMPLES${RESET}
    ${DIM}# Interactive uninstall${RESET}
    $0

    ${DIM}# Fully automated uninstall${RESET}
    $0 --yes

    ${DIM}# Preview changes without applying${RESET}
    $0 --dry-run

${BOLD}DESCRIPTION${RESET}
    This script removes HyprGlass Studio by:

      - Creating a restore point of the current config
      - Removing the hyprglass plugin (unless --keep-plugin is used)
      - Cleaning Hyprglass entries from hyprland.conf
      - Removing Hyprglass.conf, profiles, scripts, and wallust templates
      - Offering to restore JaKooLit defaults if a JaKooLit layout is detected

    A restore point is saved to:
      ${HYPR_DIR}/backups/hyprglass-uninstall-<timestamp>/

EOF
    exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y)       AUTO_YES=true ;;
            --keep-plugin)  KEEP_PLUGIN=true ;;
            --keep-backups) KEEP_BACKUPS=true ;;
            --dry-run)      DRY_RUN=true ;;
            --help|-h)      show_help ;;
            *) fatal "Unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done
}

# ── Dry-run wrapper ──────────────────────────────────────────────────────────
run_cmd() {
    if $DRY_RUN; then
        dry "Would run: $*"
        return 0
    fi
    "$@"
}

# ── Run with optional spinner ────────────────────────────────────────────────
run_with_spinner() {
    local msg="$1"
    shift
    if $DRY_RUN; then
        dry "Would run: $*"
        return 0
    fi
    spinner_start "$msg"
    if "$@"; then
        spinner_stop
        return 0
    else
        spinner_stop
        return 1
    fi
}

# ── Create restore point ─────────────────────────────────────────────────────
create_restore_point() {
    local restore_dir
    restore_dir="${HYPR_DIR}/backups/hyprglass-uninstall-$(date +%Y%m%d-%H%M%S)"
    RESTORE_DIR="$restore_dir"

    if $DRY_RUN; then
        dry "Would create restore point at ${restore_dir}"
        return
    fi

    info "Creating restore point at ${restore_dir}..."
    mkdir -p "${restore_dir}"
    local saved=0

    if [[ -f "${HYPRLAND_CONF}" ]]; then
        cp "${HYPRLAND_CONF}" "${restore_dir}/hyprland.conf"
        ((saved++)) || true
    fi

    if [[ -d "${HYPR_DIR}/UserConfigs" ]]; then
        mkdir -p "${restore_dir}/UserConfigs"
        cp -r "${HYPR_DIR}/UserConfigs/"*.conf "${restore_dir}/UserConfigs/" 2>/dev/null || true
        ((saved++)) || true
    fi

    if [[ -d "${HYPR_DIR}/scripts" ]]; then
        mkdir -p "${restore_dir}/scripts"
        cp -r "${HYPR_DIR}/scripts/"*.sh "${restore_dir}/scripts/" 2>/dev/null || true
        ((saved++)) || true
    fi

    if [[ -d "${WALLUST_DIR}/templates" ]]; then
        mkdir -p "${restore_dir}/wallust-templates"
        cp -r "${WALLUST_DIR}/templates/"* "${restore_dir}/wallust-templates/" 2>/dev/null || true
        ((saved++)) || true
    fi

    if [[ -f "${HYPR_DIR}/UserConfigs/Startup_Apps.conf" ]]; then
        cp "${HYPR_DIR}/UserConfigs/Startup_Apps.conf" "${restore_dir}/Startup_Apps.conf" 2>/dev/null || true
        ((saved++)) || true
    fi

    if (( saved > 0 )); then
        success "Restore point created (${saved} item(s))"
    else
        warn "No config files found to include in restore point"
    fi
    echo ""
}

# ── Remove Hyprland plugin ───────────────────────────────────────────────────
remove_plugin() {
    if $KEEP_PLUGIN; then
        info "Skipping plugin removal (--keep-plugin)"
        echo ""
        return
    fi

    if ! command -v hyprpm &>/dev/null; then
        warn "hyprpm not found — cannot remove plugin"
        echo ""
        return
    fi

    info "Removing hyprglass plugin..."

    if hyprpm list 2>/dev/null | grep -q hyprglass; then
        run_with_spinner "Disabling hyprglass plugin" hyprpm disable hyprglass 2>/dev/null || true
        run_with_spinner "Removing hyprglass plugin" hyprpm remove hyprglass 2>/dev/null || true
        success "Hyprglass plugin removed"
    else
        info "Hyprglass plugin not installed — nothing to remove"
    fi
    echo ""
}

# ── Better cleanup of hyprland.conf ──────────────────────────────────────────
cleanup_hyprland_conf() {
    if [[ ! -f "${HYPRLAND_CONF}" ]]; then
        warn "hyprland.conf not found at ${HYPRLAND_CONF}"
        echo ""
        return
    fi

    info "Cleaning hyprland.conf..."

    if $DRY_RUN; then
        dry "Would remove HyprGlass source/exec lines and comment block from ${HYPRLAND_CONF}"
        echo ""
        return
    fi

    local tmp
    tmp=$(mktemp -p "${HYPR_DIR}")
    chmod 600 "$tmp"

    awk -v src="${HYPGLASS_SRC}" -v exec="${HYPGLASS_EXEC}" '
        BEGIN { skip = 0 }
        # Remove the "# HyprGlass Studio" header and the following source/exec lines
        /# HyprGlass Studio/ { skip = 1; next }
        skip && /^[[:space:]]*$/ { skip = 0; next }
        skip && ($0 == src || $0 == exec) { next }
        skip && $0 !~ /^#/ { skip = 0 }

        # Remove exact source/exec lines anywhere else
        $0 == src { next }
        $0 == exec { next }

        # Trim trailing whitespace on remaining lines
        { sub(/[[:space:]]+$/, ""); print }
    ' "${HYPRLAND_CONF}" > "$tmp"

    # Remove any leftover blank runs at the end of the file
    sed -i -e :a -e '/^[[:space:]]*$/ { $d; N; ba }' "$tmp"

    mv "$tmp" "${HYPRLAND_CONF}"
    success "hyprland.conf cleaned"
    echo ""
}

# ── Remove generated files ───────────────────────────────────────────────────
remove_generated_files() {
    info "Removing generated HyprGlass files..."

    # Hyprglass.conf
    if [[ -f "${HYPR_DIR}/UserConfigs/${HYPGLASS_CONF}" ]]; then
        run_cmd rm "${HYPR_DIR}/UserConfigs/${HYPGLASS_CONF}"
        success "Removed UserConfigs/${HYPGLASS_CONF}"
    fi

    # Profiles
    if [[ -d "${HYPR_DIR}/hyprglass-profiles" ]]; then
        run_cmd rm -rf "${HYPR_DIR}/hyprglass-profiles"
        success "Removed hyprglass-profiles/"
    fi

    # Scripts installed by HyprGlass Studio
    local hyprglass_scripts=(
        "FixHyprglassValues.sh"
        "HyprglassProfile.sh"
        "WallustHyprglassHook.sh"
        "generate-hyprglass-from-wallust.sh"
    )
    for script in "${hyprglass_scripts[@]}"; do
        local target="${HYPR_DIR}/scripts/${script}"
        if [[ -f "$target" ]]; then
            run_cmd rm "$target"
            success "Removed scripts/${script}"
        fi
    done

    # Generated wallust template
    local wallust_template="${WALLUST_DIR}/templates/colors-hyprglass.conf"
    if [[ -f "$wallust_template" ]]; then
        run_cmd rm "$wallust_template"
        success "Removed wallust template colors-hyprglass.conf"
    fi

    echo ""
}

# ── JaKooLit detection and default restoration ───────────────────────────────
is_jakoolit_layout() {
    [[ -d "${HYPR_DIR}/UserConfigs" ]] && \
    [[ -f "${HYPR_DIR}/UserConfigs/Startup_Apps.conf" ]] && \
    [[ -f "${HYPR_DIR}/UserConfigs/UserSettings.conf" ]]
}

find_latest_installer_backup() {
    local backup_root="${HYPR_DIR}/backups"
    if [[ ! -d "$backup_root" ]]; then
        return
    fi
    find "$backup_root" -maxdepth 1 -type d -name 'hyprglass-studio-*' -printf '%T@ %p\n' 2>/dev/null | \
        sort -n | tail -1 | cut -d' ' -f2-
}

restore_jakoolit_file_from_backup() {
    local file_name="$1"
    local current_path="$2"
    local backup_dir="$3"
    local backup_path="${backup_dir}/${file_name}"

    if [[ -f "$backup_path" ]]; then
        run_cmd cp "$backup_path" "$current_path"
        success "Restored ${file_name} from installer backup"
        return 0
    fi
    return 1
}

cleanup_jakoolit_startup() {
    local startup_conf="${HYPR_DIR}/UserConfigs/Startup_Apps.conf"
    if [[ ! -f "$startup_conf" ]]; then
        return
    fi

    info "Removing HyprGlass startup hook from JaKooLit Startup_Apps.conf..."

    if $DRY_RUN; then
        dry "Would remove HyprGlass exec lines from ${startup_conf}"
        return
    fi

    local tmp
    tmp=$(mktemp -p "${HYPR_DIR}")
    chmod 600 "$tmp"
    grep -vF "FixHyprglassValues.sh" "$startup_conf" | \
    grep -vF "WallustHyprglassHook.sh" | \
    grep -vF "# HyprGlass Studio" > "$tmp" || true
    mv "$tmp" "$startup_conf"
    success "Cleaned Startup_Apps.conf"
}

offer_restore_jakoolit_defaults() {
    if ! is_jakoolit_layout; then
        return
    fi

    info "JaKooLit Hyprland dots layout detected"

    local latest_backup
    latest_backup=$(find_latest_installer_backup)

    if [[ -n "$latest_backup" ]]; then
        info "Found installer backup: ${latest_backup}"
    fi

    if $AUTO_YES; then
        warn "--yes set: skipping JaKooLit default restoration prompt"
        cleanup_jakoolit_startup
        echo ""
        return
    fi

    if [[ -n "$latest_backup" ]] && \
       confirm "Restore JaKooLit defaults from the installer backup (recommended)?"; then
        if restore_jakoolit_file_from_backup "Startup_Apps.conf" \
            "${HYPR_DIR}/UserConfigs/Startup_Apps.conf" "$latest_backup"; then
            true
        else
            warn "Startup_Apps.conf not found in backup — cleaning instead"
            cleanup_jakoolit_startup
        fi
    elif confirm "Clean HyprGlass hooks from Startup_Apps.conf instead?"; then
        cleanup_jakoolit_startup
    else
        info "Skipping JaKooLit default restoration"
    fi
    echo ""
}

# ── Remove desktop entries / CLI if present ──────────────────────────────────
remove_desktop_entries() {
    local bin_file="${HOME}/.local/bin/hyprglass-studio"
    local desktop_file="${HOME}/.local/share/applications/hyprglass-studio.desktop"

    if [[ -f "$bin_file" ]]; then
        run_cmd rm "$bin_file"
        success "Removed ${bin_file}"
    fi

    if [[ -f "$desktop_file" ]]; then
        run_cmd rm "$desktop_file"
        success "Removed ${desktop_file}"
    fi
}

# ── Optional cleanup of old backups ──────────────────────────────────────────
cleanup_old_backups() {
    if $KEEP_BACKUPS; then
        info "Keeping all backups (--keep-backups)"
        echo ""
        return
    fi

    if $AUTO_YES; then
        info "--yes set: leaving backup directory intact"
        echo ""
        return
    fi

    local backup_dir="${HYPR_DIR}/backups"
    if [[ -d "$backup_dir" ]] && confirm "Remove old HyprGlass installer backups in ${backup_dir}?"; then
        run_cmd rm -rf "${backup_dir}"/hyprglass-studio-*
        success "Removed HyprGlass installer backups from ${backup_dir}"
    else
        info "Keeping backup directory"
    fi
    echo ""
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${YELLOW}║${RESET}        ${BOLD}Dry run complete — no changes were made${RESET}           ${YELLOW}║${RESET}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${RESET}"
    else
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${RESET}         ${BOLD}HyprGlass Studio uninstalled successfully!${RESET}         ${GREEN}║${RESET}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "  ${BOLD}Restore point:${RESET} ${RESTORE_DIR:-none}"
        echo ""
        echo -e "  ${BOLD}Next steps:${RESET}"
        echo "    1. Review hyprland.conf if you still see glass effects"
        echo "    2. Reload Hyprland:  hyprctl reload"
        echo "    3. Remove this repo when satisfied:  rm -rf ${SCRIPT_DIR}"
    fi
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    echo ""
    echo -e "${BOLD}HyprGlass Studio Uninstaller${RESET}"
    if $DRY_RUN; then
        echo -e "${YELLOW}  ── DRY RUN MODE ──${RESET}"
    fi
    echo "───────────────────────────────────────"
    echo ""

    if ! $AUTO_YES; then
        if ! confirm "This will remove HyprGlass Studio. Continue?"; then
            info "Uninstall cancelled"
            exit 0
        fi
        echo ""
    fi

    create_restore_point
    remove_plugin
    cleanup_hyprland_conf
    remove_generated_files
    offer_restore_jakoolit_defaults
    remove_desktop_entries
    cleanup_old_backups
    print_summary
}

# ── Cleanup on exit ──────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
}
trap cleanup EXIT

main "$@"
