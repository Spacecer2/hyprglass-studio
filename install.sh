#!/usr/bin/env bash
set -euo pipefail

# ── HyprGlass Studio Installer ────────────────────────────────────────────────
# Sets up HyprGlass Studio on a Hyprland system.
# Usage: ./install.sh [--yes] [--skip-plugin] [--skip-wallust]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/hyprnux/hyprglass"

HYPR_DIR="${HOME}/.config/hypr"
BACKUP_DIR="${HYPR_DIR}/backups/hyprglass-studio-$(date +%Y%m%d-%H%M%S)"

HYPRLAND_CONF="${HYPR_DIR}/hyprland.conf"
HYPGLASS_CONF="Hyprglass.conf"
HYPGLASS_SRC="source = ~/.config/hypr/UserConfigs/${HYPGLASS_CONF}"
HYPGLASS_EXEC="exec-once = ~/.config/hypr/scripts/FixHyprglassValues.sh"

AUTO_YES=false
SKIP_PLUGIN=false
SKIP_WALLUST=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
fatal()   { error "$*"; exit 1; }

confirm() {
    if $AUTO_YES; then
        return 0
    fi
    local prompt="${1:-Continue?}"
    echo -en "${BOLD}${prompt} [Y/n]${RESET} "
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y)       AUTO_YES=true ;;
            --skip-plugin)  SKIP_PLUGIN=true ;;
            --skip-wallust) SKIP_WALLUST=true ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --yes, -y        Skip all confirmation prompts (unattended install)"
                echo "  --skip-plugin    Skip hyprglass plugin installation"
                echo "  --skip-wallust   Skip wallust installation prompt"
                echo "  --help, -h       Show this help message"
                exit 0
                ;;
            *) fatal "Unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done
}

# ── Prerequisite checks ─────────────────────────────────────────────────────
check_prereqs() {
    info "Checking prerequisites..."

    local failures=0

    # Hyprland
    if command -v hyprctl &>/dev/null; then
        local ver
        ver=$(hyprctl version 2>/dev/null | head -1 || true)
        success "Hyprland found: ${ver}"
    else
        error "hyprctl not found — Hyprland is not installed"
        ((failures++))
    fi

    # hyprpm
    if command -v hyprpm &>/dev/null; then
        success "hyprpm found"
    else
        error "hyprpm not found — install the Hyprland plugin manager"
        ((failures++))
    fi

    # Python 3.10+
    if command -v python3 &>/dev/null; then
        local py_ver
        py_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        local py_major py_minor
        py_major=$(echo "$py_ver" | cut -d. -f1)
        py_minor=$(echo "$py_ver" | cut -d. -f2)
        if (( py_major > 3 || (py_major == 3 && py_minor >= 10) )); then
            success "Python ${py_ver} (>= 3.10)"
        else
            error "Python ${py_ver} found but >= 3.10 is required"
            ((failures++))
        fi
    else
        error "python3 not found"
        ((failures++))
    fi

    # curl or wget
    if command -v curl &>/dev/null; then
        success "curl found"
    elif command -v wget &>/dev/null; then
        success "wget found"
    else
        error "Neither curl nor wget found"
        ((failures++))
    fi

    if (( failures > 0 )); then
        fatal "Missing ${failures} required dependency(ies). Aborting."
    fi

    echo ""
}

# ── Backup ───────────────────────────────────────────────────────────────────
backup_configs() {
    info "Backing up existing configs to ${BACKUP_DIR}..."

    mkdir -p "${BACKUP_DIR}"

    local backed_up=0

    # hyprland.conf
    if [[ -f "${HYPRLAND_CONF}" ]]; then
        cp "${HYPRLAND_CONF}" "${BACKUP_DIR}/hyprland.conf"
        ((backed_up++))
    fi

    # UserConfigs directory
    if [[ -d "${HYPR_DIR}/UserConfigs" ]]; then
        cp -r "${HYPR_DIR}/UserConfigs" "${BACKUP_DIR}/UserConfigs" 2>/dev/null || true
        ((backed_up++))
    fi

    # Scripts directory
    if [[ -d "${HYPR_DIR}/scripts" ]]; then
        cp -r "${HYPR_DIR}/scripts" "${BACKUP_DIR}/scripts" 2>/dev/null || true
        ((backed_up++))
    fi

    # hyprglass-profiles directory
    if [[ -d "${HYPR_DIR}/hyprglass-profiles" ]]; then
        cp -r "${HYPR_DIR}/hyprglass-profiles" "${BACKUP_DIR}/hyprglass-profiles" 2>/dev/null || true
        ((backed_up++))
    fi

    # wallust templates
    if [[ -d "${HOME}/.config/wallust/templates" ]]; then
        mkdir -p "${BACKUP_DIR}/wallust-templates"
        cp -r "${HOME}/.config/wallust/templates"/* "${BACKUP_DIR}/wallust-templates/" 2>/dev/null || true
        ((backed_up++))
    fi

    if (( backed_up > 0 )); then
        success "Backed up ${backed_up} item(s) to ${BACKUP_DIR}"
    else
        info "No existing configs to back up"
    fi
    echo ""
}

# ── Plugin installation ──────────────────────────────────────────────────────
install_plugin() {
    if $SKIP_PLUGIN; then
        info "Skipping plugin installation (--skip-plugin)"
        return
    fi

    info "Installing HyprGlass plugin..."

    # Check if already installed
    if hyprpm list 2>/dev/null | grep -q hyprglass; then
        warn "HyprGlass plugin already installed"
        if confirm "Reinstall/更新 plugin?"; then
            hyprpm remove hyprglass 2>/dev/null || true
        else
            success "Skipping plugin reinstall"
            echo ""
            return
        fi
    fi

    hyprpm add "${REPO_URL}"
    hyprpm enable hyprglass

    # Verify
    if hyprctl plugins 2>/dev/null | grep -q hyprglass; then
        success "HyprGlass plugin loaded successfully"
    else
        warn "Plugin installed but not detected — you may need to reload Hyprland"
    fi
    echo ""
}

# ── Wallust installation ────────────────────────────────────────────────────
install_wallust() {
    if $SKIP_WALLUST; then
        info "Skipping wallust check (--skip-wallust)"
        return
    fi

    if command -v wallust &>/dev/null; then
        success "wallust already installed: $(wallust --version 2>/dev/null || echo 'unknown version')"
        return
    fi

    warn "wallust is not installed (optional — enables wallpaper color sync)"

    if ! confirm "Install wallust?"; then
        info "Skipping wallust installation"
        echo ""
        return
    fi

    # Try cargo first, fall back to AUR suggestion
    if command -v cargo &>/dev/null; then
        info "Installing wallust via cargo..."
        if cargo install wallust; then
            success "wallust installed via cargo"
            echo ""
            return
        else
            warn "cargo install failed"
        fi
    fi

    # Check for AUR helper
    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    if [[ -n "$aur_helper" ]]; then
        info "Installing wallust via ${aur_helper}..."
        if "${aur_helper}" -S wallust --noconfirm; then
            success "wallust installed via ${aur_helper}"
            echo ""
            return
        else
            warn "${aur_helper} install failed"
        fi
    fi

    warn "Could not install wallust automatically."
    warn "Install manually: yay -S wallust  OR  cargo install wallust"
    echo ""
}

# ── Copy config files ───────────────────────────────────────────────────────
copy_configs() {
    info "Installing configuration files..."

    # Create target directories
    mkdir -p "${HYPR_DIR}/UserConfigs"
    mkdir -p "${HYPR_DIR}/hyprglass-profiles"
    mkdir -p "${HYPR_DIR}/scripts"
    mkdir -p "${HOME}/.config/wallust/templates"

    # Copy Hyprglass.conf
    if [[ -f "${SCRIPT_DIR}/src/Hyprglass.conf" ]]; then
        cp "${SCRIPT_DIR}/src/Hyprglass.conf" "${HYPR_DIR}/UserConfigs/${HYPGLASS_CONF}"
        success "Copied Hyprglass.conf -> UserConfigs/"
    elif [[ -f "${SCRIPT_DIR}/Hyprglass.conf" ]]; then
        cp "${SCRIPT_DIR}/Hyprglass.conf" "${HYPR_DIR}/UserConfigs/${HYPGLASS_CONF}"
        success "Copied Hyprglass.conf -> UserConfigs/"
    else
        warn "Hyprglass.conf not found in repo — skipping (create manually if needed)"
    fi

    # Copy profiles
    if [[ -d "${SCRIPT_DIR}/profiles" ]]; then
        local profile_count
        profile_count=$(find "${SCRIPT_DIR}/profiles" -maxdepth 1 -name '*.conf' | wc -l)
        if (( profile_count > 0 )); then
            cp "${SCRIPT_DIR}/profiles/"*.conf "${HYPR_DIR}/hyprglass-profiles/"
            success "Copied ${profile_count} profile(s) -> hyprglass-profiles/"
        else
            warn "No profile .conf files found in profiles/"
        fi
    fi

    # Copy scripts
    if [[ -d "${SCRIPT_DIR}/scripts" ]]; then
        local script_count
        script_count=$(find "${SCRIPT_DIR}/scripts" -maxdepth 1 -name '*.sh' | wc -l)
        if (( script_count > 0 )); then
            cp "${SCRIPT_DIR}/scripts/"*.sh "${HYPR_DIR}/scripts/"
            success "Copied ${script_count} script(s) -> scripts/"
        fi
    fi

    # Copy wallust templates
    if [[ -d "${SCRIPT_DIR}/templates" ]]; then
        local template_count
        template_count=$(find "${SCRIPT_DIR}/templates" -maxdepth 1 -name '*.conf' | wc -l)
        if (( template_count > 0 )); then
            cp "${SCRIPT_DIR}/templates/"*.conf "${HOME}/.config/wallust/templates/"
            success "Copied ${template_count} template(s) -> wallust/templates/"
        fi
    fi

    echo ""
}

# ── Patch hyprland.conf ─────────────────────────────────────────────────────
patch_hyprland_conf() {
    info "Patching hyprland.conf..."

    if [[ ! -f "${HYPRLAND_CONF}" ]]; then
        warn "hyprland.conf not found at ${HYPRLAND_CONF}"
        warn "Add the following lines manually after Hyprland is configured:"
        echo "    source = ~/.config/hypr/UserConfigs/${HYPGLASS_CONF}"
        echo "    exec-once = ~/.config/hypr/scripts/FixHyprglassValues.sh"
        echo ""
        return
    fi

    local patched=false

    # Add source line if missing
    if grep -qF "${HYPGLASS_SRC}" "${HYPRLAND_CONF}"; then
        success "Source line already present"
    else
        # Append near other source lines if possible, otherwise at the end
        if grep -q '^source' "${HYPRLAND_CONF}"; then
            # Insert after the last existing source line
            local last_source_line
            last_source_line=$(grep -n '^source' "${HYPRLAND_CONF}" | tail -1 | cut -d: -f1)
            sed -i "${last_source_line}a\\${HYPGLASS_SRC}" "${HYPRLAND_CONF}"
        else
            echo -e "\n# HyprGlass Studio\n${HYPGLASS_SRC}" >> "${HYPRLAND_CONF}"
        fi
        success "Added source line for Hyprglass.conf"
        patched=true
    fi

    # Add exec-once if missing
    if grep -qF "${HYPGLASS_EXEC}" "${HYPRLAND_CONF}"; then
        success "exec-once already present"
    else
        if grep -q '^exec-once' "${HYPRLAND_CONF}"; then
            local last_exec_line
            last_exec_line=$(grep -n '^exec-once' "${HYPRLAND_CONF}" | tail -1 | cut -d: -f1)
            sed -i "${last_exec_line}a\\${HYPGLASS_EXEC}" "${HYPRLAND_CONF}"
        else
            echo -e "\n${HYPGLASS_EXEC}" >> "${HYPRLAND_CONF}"
        fi
        success "Added exec-once for FixHyprglassValues.sh"
        patched=true
    fi

    if $patched; then
        info "hyprland.conf has been updated — reload Hyprland to apply"
    fi
    echo ""
}

# ── Make scripts executable ─────────────────────────────────────────────────
make_executable() {
    info "Setting executable permissions..."

    local count=0

    # Scripts installed to hypr config
    for script in "${HYPR_DIR}/scripts/"*.sh; do
        [[ -f "$script" ]] || continue
        chmod +x "$script"
        ((count++))
    done

    if (( count > 0 )); then
        success "Made ${count} script(s) executable"
    fi
    echo ""
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}          ${BOLD}HyprGlass Studio installed successfully!${RESET}              ${GREEN}║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${RESET}"
    echo "    1. Reload Hyprland:  hyprctl reload"
    echo "    2. Toggle glass:     SUPER + G"
    echo "    3. Adjust opacity:   SUPER + Scroll"
    echo "    4. Switch profile:   HyprglassProfile.sh <profile>"
    echo ""
    echo -e "  ${BOLD}Profiles:${RESET}"
    for prof in "${HYPR_DIR}/hyprglass-profiles/"*.conf; do
        [[ -f "$prof" ]] || continue
        echo "    - $(basename "$prof" .conf)"
    done
    echo ""
    echo -e "  ${BOLD}Config locations:${RESET}"
    echo "    ${HYPR_DIR}/UserConfigs/${HYPGLASS_CONF}"
    echo "    ${HYPR_DIR}/hyprglass-profiles/"
    echo "    ${HYPR_DIR}/scripts/"
    echo "    ${HOME}/.config/wallust/templates/"
    echo ""
    echo -e "  ${BOLD}Backup:${RESET} ${BACKUP_DIR}"
    echo ""
    echo -e "  ${BOLD}Documentation:${RESET}"
    echo "    ${SCRIPT_DIR}/docs/"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    echo ""
    echo -e "${BOLD}HyprGlass Studio Installer${RESET}"
    echo "───────────────────────────────────────"
    echo ""

    check_prereqs
    backup_configs
    install_plugin
    install_wallust
    copy_configs
    patch_hyprland_conf
    make_executable
    print_summary
}

main "$@"
