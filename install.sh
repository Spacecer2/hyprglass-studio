#!/usr/bin/env bash
#
# HyprGlass Studio Installer
# Production-ready setup for HyprGlass Studio on Hyprland.
#
# shellcheck disable=SC2317,SC2181

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/hyprnux/hyprglass"

HYPR_DIR="${HOME}/.config/hypr"
USER_CONFIGS_DIR="${HYPR_DIR}/UserConfigs"
SCRIPTS_DIR="${HYPR_DIR}/scripts"
PROFILES_DIR="${HYPR_DIR}/hyprglass-profiles"
WALLUST_DIR="${HOME}/.config/wallust"
WALLUST_TEMPLATES_DIR="${WALLUST_DIR}/templates"

HYPRLAND_CONF="${HYPR_DIR}/hyprland.conf"
STARTUP_CONF="${USER_CONFIGS_DIR}/Startup_Apps.conf"
KEYBINDS_CONF="${USER_CONFIGS_DIR}/Keybinds.conf"

HYPGLASS_CONF_NAME="Hyprglass.conf"
HYPGLASS_CONF_SRC="source = ~/.config/hypr/UserConfigs/${HYPGLASS_CONF_NAME}"
HYPGLASS_CONF_DEST="${USER_CONFIGS_DIR}/${HYPGLASS_CONF_NAME}"

FIX_SCRIPT_NAME="FixHyprglassValues.sh"
FIX_SCRIPT_DEST="${SCRIPTS_DIR}/${FIX_SCRIPT_NAME}"
HYPGLASS_EXEC="exec-once = ~/.config/hypr/scripts/${FIX_SCRIPT_NAME}"

BACKUP_DIR="${HYPR_DIR}/backups/hyprglass-studio-$(date +%Y%m%d-%H%M%S)"

# ── Options ──────────────────────────────────────────────────────────────────
AUTO_YES=false
SKIP_PLUGIN=false
SKIP_WALLUST=false
DRY_RUN=false
VERBOSE=false

# ── State ────────────────────────────────────────────────────────────────────
IS_JAKOOLIT=false
JAKOOLIT_DETECTED_BY=""
SPINNER_PID=""
TOTAL_STEPS=10
CURRENT_STEP=0

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────────────────────
log()   { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()   { echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
fatal() { err "$*"; exit 1; }
dry()   { echo -e "${MAGENTA}[DRY]${RESET}  $*"; }
verb()  { $VERBOSE && echo -e "${DIM}[DBG ]${RESET}  $*" || true; }

# ── Progress ─────────────────────────────────────────────────────────────────
progress_step() {
    local label="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local filled=$(( pct / 2 ))
    local empty=$(( 50 - filled ))
    printf "  ${BOLD}[${GREEN}%${filled}s${DIM}%${empty}s${RESET}${BOLD}]${RESET} %3d%% — %s\n" "" "" "${pct}" "${label}"
}

progress_reset() {
    CURRENT_STEP=0
}

# ── Spinner ──────────────────────────────────────────────────────────────────
spinner_start() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    (
        while true; do
            for frame in "${frames[@]}"; do
                echo -ne "\r${CYAN}${frame}${RESET} ${msg}  "
                sleep 0.08
            done
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        echo -ne "\r\033[K"
    fi
}

# ── User confirmation ────────────────────────────────────────────────────────
confirm() {
    if $AUTO_YES; then
        return 0
    fi
    local prompt="${1:-Continue?}"
    echo -en "${BOLD}${prompt} [Y/n]${RESET} "
    local answer
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# ── Help text ────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}HyprGlass Studio Installer${RESET}

${BOLD}USAGE${RESET}
    $0 [OPTIONS]

${BOLD}OPTIONS${RESET}
    ${BOLD}--yes, -y${RESET}        Skip all confirmation prompts (unattended install)
    ${BOLD}--dry-run${RESET}        Show what would be done without making changes
    ${BOLD}--skip-plugin${RESET}    Skip hyprglass plugin installation via hyprpm
    ${BOLD}--skip-wallust${RESET}   Skip wallust installation / integration check
    ${BOLD}--verbose, -v${RESET}    Print extra debug information
    ${BOLD}--help, -h${RESET}       Show this help message and exit

${BOLD}EXAMPLES${RESET}
    ${DIM}# Interactive install (prompts for each step)${RESET}
    $0

    ${DIM}# Fully automated install${RESET}
    $0 --yes

    ${DIM}# Preview changes without applying${RESET}
    $0 --dry-run

    ${DIM}# Install without the plugin or wallust${RESET}
    $0 --yes --skip-plugin --skip-wallust

${BOLD}DESCRIPTION${RESET}
    HyprGlass Studio adds a transparent glass overlay to Hyprland.
    This installer:

      • Detects JaKooLit Hyprland dots and preserves their structure
      • Verifies prerequisites (hyprctl, hyprpm, Python 3.10+)
      • Backs up existing configs with timestamps
      • Installs the hyprglass Hyprland plugin via hyprpm
      • Copies profiles, scripts, and templates
      • Generates Hyprglass.conf and a startup fix script if missing
      • Patches hyprland.conf safely (does not overwrite dotfiles)
      • Sets executable permissions
      • Verifies the installation

    Backups are saved to:
      ${BACKUP_DIR}

EOF
    exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y)        AUTO_YES=true ;;
            --skip-plugin)   SKIP_PLUGIN=true ;;
            --skip-wallust)  SKIP_WALLUST=true ;;
            --dry-run)       DRY_RUN=true ;;
            --verbose|-v)    VERBOSE=true ;;
            --help|-h)       show_help ;;
            *) fatal "Unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done
}

# ── Command wrapper ──────────────────────────────────────────────────────────
run_cmd() {
    if $DRY_RUN; then
        dry "Would run: $*"
        return 0
    fi
    "$@"
}

# ── File helpers ─────────────────────────────────────────────────────────────
file_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -qF -- "$pattern" "$file"
}

backup_if_exists() {
    local src="$1"
    local dest_dir="$2"
    if [[ -e "$src" ]]; then
        mkdir -p "$dest_dir"
        cp -a "$src" "${dest_dir}/$(basename "$src")" 2>/dev/null || true
        return 0
    fi
    return 1
}

# ── JaKooLit detection ───────────────────────────────────────────────────────
detect_jakoolit() {
    IS_JAKOOLIT=false
    JAKOOLIT_DETECTED_BY=""

    if [[ -d "$USER_CONFIGS_DIR" ]]; then
        # JaKooLit uses UserConfigs and sources them from hyprland.conf
        if [[ -f "$HYPRLAND_CONF" ]] && grep -qE 'source\s*=\s*.*/UserConfigs' "$HYPRLAND_CONF" 2>/dev/null; then
            IS_JAKOOLIT=true
            JAKOOLIT_DETECTED_BY="hyprland.conf sources UserConfigs"
        elif [[ -f "${USER_CONFIGS_DIR}/Keybinds.conf" && -f "${USER_CONFIGS_DIR}/Startup_Apps.conf" ]]; then
            IS_JAKOOLIT=true
            JAKOOLIT_DETECTED_BY="UserConfigs/Keybinds.conf + Startup_Apps.conf"
        elif [[ -f "${USER_CONFIGS_DIR}/ENVariables.conf" || -f "${USER_CONFIGS_DIR}/Monitors.conf" ]]; then
            IS_JAKOOLIT=true
            JAKOOLIT_DETECTED_BY="JaKooLit-style UserConfigs files"
        fi
    fi

    if $IS_JAKOOLIT; then
        ok "JaKooLit Hyprland dots detected (${JAKOOLIT_DETECTED_BY})"
        log "Will patch config files without breaking the dotfile structure."
    else
        log "Standard Hyprland configuration detected"
    fi
    echo ""
}

# ── Prerequisite checks ─────────────────────────────────────────────────────
check_prereqs() {
    log "Checking prerequisites..."
    local failures=0

    # Hyprland / hyprctl
    if command -v hyprctl &>/dev/null; then
        local ver
        ver=$(hyprctl version 2>/dev/null | head -1 || echo "unknown")
        ok "Hyprland found: ${ver}"
    else
        err "hyprctl not found — Hyprland is not installed or not in PATH"
        failures=$((failures + 1))
    fi

    # hyprpm
    if command -v hyprpm &>/dev/null; then
        ok "hyprpm found"
    else
        err "hyprpm not found — install the Hyprland plugin manager"
        failures=$((failures + 1))
    fi

    # Python 3.10+
    if command -v python3 &>/dev/null; then
        local py_major py_minor
        py_major=$(python3 -c "import sys; print(sys.version_info.major)" 2>/dev/null)
        py_minor=$(python3 -c "import sys; print(sys.version_info.minor)" 2>/dev/null)
        if (( py_major > 3 || (py_major == 3 && py_minor >= 10) )); then
            ok "Python ${py_major}.${py_minor} (>= 3.10)"
        else
            err "Python ${py_major}.${py_minor} found but >= 3.10 is required"
            failures=$((failures + 1))
        fi
    else
        err "python3 not found"
        failures=$((failures + 1))
    fi

    # jq (used by wallust color-sync hook and helper scripts)
    if command -v jq &>/dev/null; then
        ok "jq found"
    else
        warn "jq not found — wallust color sync and some helper scripts will not work until installed"
        if ! $AUTO_YES && confirm "Continue without jq?"; then
            true
        elif $AUTO_YES; then
            warn "Continuing without jq (--yes); install it later: sudo pacman -S jq"
        else
            err "jq is required by the bundled scripts"
            failures=$((failures + 1))
        fi
    fi

    # curl or wget (for plugin install / updates)
    if command -v curl &>/dev/null || command -v wget &>/dev/null; then
        ok "Network tool found (curl/wget)"
    else
        err "Neither curl nor wget found"
        failures=$((failures + 1))
    fi

    if (( failures > 0 )); then
        fatal "Missing ${failures} required dependency(ies). Aborting."
    fi

    echo ""
}

# ── Backup ───────────────────────────────────────────────────────────────────
backup_configs() {
    if $DRY_RUN; then
        dry "Would back up configs to ${BACKUP_DIR}"
        echo ""
        return
    fi

    log "Backing up existing configs..."
    spinner_start "Creating backup"

    mkdir -p "$BACKUP_DIR"
    local backed_up=0

    backup_if_exists "$HYPRLAND_CONF" "$BACKUP_DIR" && backed_up=$((backed_up + 1))
    backup_if_exists "$USER_CONFIGS_DIR" "$BACKUP_DIR" && backed_up=$((backed_up + 1))
    backup_if_exists "$SCRIPTS_DIR" "$BACKUP_DIR" && backed_up=$((backed_up + 1))
    backup_if_exists "$PROFILES_DIR" "$BACKUP_DIR" && backed_up=$((backed_up + 1))

    if [[ -d "$WALLUST_TEMPLATES_DIR" ]]; then
        mkdir -p "${BACKUP_DIR}/wallust-templates"
        cp -a "${WALLUST_TEMPLATES_DIR}/." "${BACKUP_DIR}/wallust-templates/" 2>/dev/null || true
        backed_up=$((backed_up + 1))
    fi

    spinner_stop

    if (( backed_up > 0 )); then
        ok "Backed up ${backed_up} item(s) to ${BACKUP_DIR}"
    else
        log "No existing configs to back up"
    fi
    echo ""
}

# ── Plugin installation ──────────────────────────────────────────────────────
install_plugin() {
    if $SKIP_PLUGIN; then
        log "Skipping plugin installation (--skip-plugin)"
        echo ""
        return
    fi

    log "Installing HyprGlass plugin via hyprpm..."

    if $DRY_RUN; then
        if hyprpm list 2>/dev/null | grep -q hyprglass; then
            dry "Plugin already installed; would offer reinstall"
        else
            dry "Would run: hyprpm add ${REPO_URL}"
            dry "Would run: hyprpm enable hyprglass"
            dry "Would run: hyprpm update hyprglass"
        fi
        echo ""
        return
    fi

    local plugin_installed=false
    if hyprpm list 2>/dev/null | grep -q hyprglass; then
        plugin_installed=true
        warn "HyprGlass plugin already installed"
        if confirm "Reinstall/update plugin?"; then
            spinner_start "Removing existing plugin"
            hyprpm remove hyprglass 2>/dev/null || true
            spinner_stop
            plugin_installed=false
        fi
    fi

    if ! $plugin_installed; then
        spinner_start "Adding hyprpm repository"
        if ! hyprpm add "$REPO_URL"; then
            spinner_stop
            warn "hyprpm add failed — trying with --verbose"
            spinner_start "Adding hyprpm repository (verbose)"
            hyprpm add "$REPO_URL" -v || true
            spinner_stop
        else
            spinner_stop
        fi

        spinner_start "Enabling hyprglass plugin"
        if ! hyprpm enable hyprglass; then
            spinner_stop
            fatal "Failed to enable hyprglass plugin. Check compiler/headers and run 'hyprpm update -v'."
        fi
        spinner_stop

        spinner_start "Updating hyprglass plugin"
        hyprpm update hyprglass 2>/dev/null || true
        spinner_stop
    fi

    # Verification happens later; just report status here
    if hyprctl plugins 2>/dev/null | grep -q hyprglass; then
        ok "HyprGlass plugin is loaded"
    else
        warn "Plugin installed but not currently loaded — reload Hyprland after install"
    fi
    echo ""
}

# ── Wallust integration ─────────────────────────────────────────────────────
install_wallust() {
    if $SKIP_WALLUST; then
        log "Skipping wallust check (--skip-wallust)"
        echo ""
        return
    fi

    if command -v wallust &>/dev/null; then
        ok "wallust already installed: $(wallust --version 2>/dev/null || echo 'unknown version')"
        echo ""
        return
    fi

    warn "wallust is not installed (optional — enables wallpaper color sync)"

    if $DRY_RUN; then
        dry "Would check for wallust and offer to install it"
        echo ""
        return
    fi

    if ! confirm "Install wallust?"; then
        log "Skipping wallust installation"
        echo ""
        return
    fi

    # Try cargo first
    if command -v cargo &>/dev/null; then
        log "Installing wallust via cargo..."
        spinner_start "Compiling wallust (this may take a while)"
        if cargo install wallust; then
            spinner_stop
            ok "wallust installed via cargo"
            echo ""
            return
        else
            spinner_stop
            warn "cargo install failed"
        fi
    fi

    # Try AUR helper
    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    if [[ -n "$aur_helper" ]]; then
        log "Installing wallust via ${aur_helper}..."
        spinner_start "Installing wallust via ${aur_helper}"
        if "${aur_helper}" -S wallust --noconfirm; then
            spinner_stop
            ok "wallust installed via ${aur_helper}"
            echo ""
            return
        else
            spinner_stop
            warn "${aur_helper} install failed"
        fi
    fi

    warn "Could not install wallust automatically."
    warn "Install manually: yay -S wallust  OR  cargo install wallust"
    echo ""
}

# ── Generate default Hyprglass.conf ──────────────────────────────────────────
generate_hyprglass_conf() {
    if [[ -f "$HYPGLASS_CONF_DEST" ]]; then
        if confirm "Hyprglass.conf already exists. Overwrite with defaults?"; then
            true
        else
            ok "Keeping existing Hyprglass.conf"
            return
        fi
    fi

    log "Generating default Hyprglass.conf..."

    if $DRY_RUN; then
        dry "Would generate ${HYPGLASS_CONF_DEST}"
        return
    fi

    mkdir -p "$USER_CONFIGS_DIR"

    cat > "$HYPGLASS_CONF_DEST" <<'EOF'
# ─── HyprGlass Studio Configuration ─────────────────────────────────────
# Auto-generated by install.sh. Edit freely, but keep the structure intact.

plugin:hyprglass {
    enabled = 1
    default_theme = dark
    default_preset = default
    blur_strength = 2.0
    blur_iterations = 3
    refraction_strength = 0.6
    chromatic_aberration = 0.5
    fresnel_strength = 0.6
    specular_strength = 0.8
    glass_opacity = 1.0
    edge_thickness = 0.06
    lens_distortion = 0.5
    tint_color = 0x8899aa22
}

# ─── Dark Theme ─────────────────────────────────────────────────────────
dark:brightness = 0.8192
dark:contrast = 0.8914
dark:saturation = 1.1911
dark:vibrancy = 0.369
dark:vibrancy_darkness = 0.6918
dark:adaptive_dim = 0.0
dark:adaptive_boost = 0.0

# ─── Light Theme ────────────────────────────────────────────────────────
light:brightness = 1.0
light:contrast = 1.0
light:saturation = 1.0
light:vibrancy = 0.2
light:vibrancy_darkness = 0.3
light:adaptive_dim = 0.0
light:adaptive_boost = 0.0

# ─── Layer Settings ─────────────────────────────────────────────────────
layers:enabled = 1
layers:namespaces = layer:surface
layers:exclude_namespaces = layer:notifications
layers:preset = default
layers:namespace_presets = layer:surface=glass
layers:namespace_mask_thresholds = layer:surface:0.3

# ─── Decoration Overrides ───────────────────────────────────────────────
decoration {
    active_opacity = 0.75
    inactive_opacity = 0.65
}

# ─── Window Rules ───────────────────────────────────────────────────────
windowrulev2 = tag +hyprglass_disabled, class:^(firefox)$
windowrulev2 = tag +hyprglass_preset_subtle, class:^(kitty)$
windowrulev2 = tag +hyprglass_enabled, class:^(thunar)$

# ─── Wallust Color Sync (optional) ──────────────────────────────────────
# If wallust is installed, these variables are updated by the wallust hook.
# $tint_color = rgb(aa88ff)
EOF

    ok "Generated ${HYPGLASS_CONF_DEST}"
}

# ── Generate startup fix script ──────────────────────────────────────────────
generate_fix_script() {
    if [[ -f "$FIX_SCRIPT_DEST" ]]; then
        if confirm "${FIX_SCRIPT_NAME} already exists. Overwrite?"; then
            true
        else
            ok "Keeping existing ${FIX_SCRIPT_NAME}"
            return
        fi
    fi

    log "Generating ${FIX_SCRIPT_NAME}..."

    if $DRY_RUN; then
        dry "Would generate ${FIX_SCRIPT_DEST}"
        return
    fi

    mkdir -p "$SCRIPTS_DIR"

    cat > "$FIX_SCRIPT_DEST" <<'EOF'
#!/usr/bin/env bash
# FixHyprglassValues.sh
# Applies the default HyprGlass profile at session startup.
# This script is executed once by Hyprland via exec-once.

set -euo pipefail

PROFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprglass-profiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SCRIPT="${SCRIPT_DIR}/HyprglassProfile.sh"

# Small delay to ensure plugin is loaded
sleep 0.5

# Apply default profile if the switcher exists
if [[ -x "$PROFILE_SCRIPT" ]] && [[ -f "${PROFILES_DIR}/default.conf" ]]; then
    "$PROFILE_SCRIPT" apply default >/dev/null 2>&1 || true
fi

# If wallust colors are present, apply them
WALLUST_CACHE="${HOME}/.cache/.hyprglass_wallust.json"
if [[ -f "$WALLUST_CACHE" ]] && command -v hyprctl &>/dev/null; then
    tint=$(jq -r '.tint_color // empty' "$WALLUST_CACHE" 2>/dev/null)
    brightness=$(jq -r '.brightness // empty' "$WALLUST_CACHE" 2>/dev/null)
    [[ -n "$tint" ]] && hyprctl keyword plugin:hyprglass:tint_color "$tint" >/dev/null 2>&1 || true
    [[ -n "$brightness" ]] && hyprctl keyword plugin:hyprglass:dark:brightness "$brightness" >/dev/null 2>&1 || true
fi
EOF

    chmod +x "$FIX_SCRIPT_DEST"
    ok "Generated ${FIX_SCRIPT_DEST}"
}

# ── Copy project files ───────────────────────────────────────────────────────
copy_configs() {
    log "Installing configuration files..."

    if $DRY_RUN; then
        progress_reset
        progress_step "Create directories"
        dry "Would create: ${USER_CONFIGS_DIR}"
        dry "Would create: ${PROFILES_DIR}"
        dry "Would create: ${SCRIPTS_DIR}"
        dry "Would create: ${WALLUST_TEMPLATES_DIR}"

        progress_step "Generate Hyprglass.conf"
        dry "Would generate ${HYPGLASS_CONF_DEST} (or keep existing)"

        progress_step "Generate startup script"
        dry "Would generate ${FIX_SCRIPT_DEST} (or keep existing)"

        progress_step "Copy profiles"
        if [[ -d "${SCRIPT_DIR}/profiles" ]]; then
            local n
            n=$(find "${SCRIPT_DIR}/profiles" -maxdepth 1 -type f -name '*.conf' | wc -l)
            dry "Would copy ${n} profile(s) -> ${PROFILES_DIR}/"
            if [[ -d "${SCRIPT_DIR}/profiles/themes" ]]; then
                n=$(find "${SCRIPT_DIR}/profiles/themes" -maxdepth 1 -type f -name '*.conf' | wc -l)
                dry "Would copy ${n} theme preset(s) -> ${PROFILES_DIR}/themes/"
            fi
        fi

        progress_step "Copy scripts"
        if [[ -d "${SCRIPT_DIR}/scripts" ]]; then
            local n
            n=$(find "${SCRIPT_DIR}/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | wc -l)
            dry "Would copy ${n} script(s) -> ${SCRIPTS_DIR}/"
        fi

        progress_step "Copy wallust templates"
        if [[ -d "${SCRIPT_DIR}/templates" ]]; then
            local n
            n=$(find "${SCRIPT_DIR}/templates" -maxdepth 1 -type f | wc -l)
            dry "Would copy ${n} template(s) -> ${WALLUST_TEMPLATES_DIR}/"
        fi

        progress_step "Done"
        echo ""
        return
    fi

    progress_reset

    # Create target directories
    progress_step "Create directories"
    mkdir -p "$USER_CONFIGS_DIR"
    mkdir -p "$PROFILES_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$WALLUST_TEMPLATES_DIR"

    # Generate main config
    progress_step "Hyprglass.conf"
    generate_hyprglass_conf

    # Generate startup fix script
    progress_step "Startup fix script"
    generate_fix_script

    # Copy profiles
    progress_step "Profiles"
    if [[ -d "${SCRIPT_DIR}/profiles" ]]; then
        local profile_count
        profile_count=$(find "${SCRIPT_DIR}/profiles" -maxdepth 1 -type f -name '*.conf' | wc -l)
        if (( profile_count > 0 )); then
            cp -a "${SCRIPT_DIR}/profiles/"*.conf "$PROFILES_DIR/" 2>/dev/null || true
            ok "Copied ${profile_count} profile(s) -> ${PROFILES_DIR}/"
        else
            warn "No .conf profile files found in profiles/"
        fi

        # Copy bundled theme presets if they exist.
        if [[ -d "${SCRIPT_DIR}/profiles/themes" ]]; then
            mkdir -p "$PROFILES_DIR/themes"
            local theme_count
            theme_count=$(find "${SCRIPT_DIR}/profiles/themes" -maxdepth 1 -type f -name '*.conf' | wc -l)
            if (( theme_count > 0 )); then
                cp -a "${SCRIPT_DIR}/profiles/themes/"*.conf "$PROFILES_DIR/themes/" 2>/dev/null || true
                ok "Copied ${theme_count} theme preset(s) -> ${PROFILES_DIR}/themes/"
            fi
        fi
    fi

    # Copy scripts
    progress_step "Scripts"
    if [[ -d "${SCRIPT_DIR}/scripts" ]]; then
        local script_count
        script_count=$(find "${SCRIPT_DIR}/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | wc -l)
        if (( script_count > 0 )); then
            cp -a "${SCRIPT_DIR}/scripts/"*.sh "$SCRIPTS_DIR/" 2>/dev/null || true
            cp -a "${SCRIPT_DIR}/scripts/"*.py "$SCRIPTS_DIR/" 2>/dev/null || true
            ok "Copied ${script_count} script(s) -> ${SCRIPTS_DIR}/"
        fi
    fi

    # Copy wallust templates
    progress_step "Wallust templates"
    if [[ -d "${SCRIPT_DIR}/templates" ]]; then
        local template_count
        template_count=$(find "${SCRIPT_DIR}/templates" -maxdepth 1 -type f | wc -l)
        if (( template_count > 0 )); then
            cp -a "${SCRIPT_DIR}/templates/"* "$WALLUST_TEMPLATES_DIR/" 2>/dev/null || true
            ok "Copied ${template_count} template(s) -> ${WALLUST_TEMPLATES_DIR}/"
        fi
    fi

    progress_step "Done"
    echo ""
}

# ── Patch hyprland.conf safely ──────────────────────────────────────────────
patch_hyprland_conf() {
    log "Patching Hyprland configuration..."

    if [[ ! -f "$HYPRLAND_CONF" ]]; then
        warn "hyprland.conf not found at ${HYPRLAND_CONF}"
        if $DRY_RUN; then
            dry "Would create ${HYPRLAND_CONF} with required source/exec lines"
        elif confirm "Create a minimal hyprland.conf?"; then
            mkdir -p "$HYPR_DIR"
            cat > "$HYPRLAND_CONF" <<EOF
# Minimal hyprland.conf generated by HyprGlass Studio installer
${HYPGLASS_CONF_SRC}
${HYPGLASS_EXEC}
EOF
            ok "Created minimal ${HYPRLAND_CONF}"
        else
            warn "Add the following lines manually:"
            echo "    ${HYPGLASS_CONF_SRC}"
            echo "    ${HYPGLASS_EXEC}"
        fi
        echo ""
        return
    fi

    if $DRY_RUN; then
        dry "Would patch ${HYPRLAND_CONF}"
        if $IS_JAKOOLIT; then
            dry "JaKooLit detected: source line goes into main hyprland.conf (keeps UserConfigs structure)"
            [[ -f "$STARTUP_CONF" ]] && dry "exec-once line would go into ${STARTUP_CONF}"
        fi
        echo ""
        return
    fi

    # 1. Ensure source line is present in hyprland.conf
    if file_contains "$HYPRLAND_CONF" "$HYPGLASS_CONF_SRC"; then
        ok "Source line already present in hyprland.conf"
    else
        # For JaKooLit, append after the last UserConfigs source line if possible
        local insert_after=""
        if $IS_JAKOOLIT; then
            insert_after=$(grep -nE '^source\s*=\s*.*/UserConfigs' "$HYPRLAND_CONF" 2>/dev/null | tail -1 | cut -d: -f1) || true
        fi
        if [[ -n "$insert_after" ]]; then
            sed -i "${insert_after}a\\${HYPGLASS_CONF_SRC}" "$HYPRLAND_CONF"
        elif grep -qE '^source\s*=' "$HYPRLAND_CONF"; then
            local last_source
            last_source=$(grep -nE '^source\s*=' "$HYPRLAND_CONF" | tail -1 | cut -d: -f1) || true
            sed -i "${last_source}a\\${HYPGLASS_CONF_SRC}" "$HYPRLAND_CONF"
        else
            echo -e "\n# HyprGlass Studio\n${HYPGLASS_CONF_SRC}" >> "$HYPRLAND_CONF"
        fi
        ok "Added source line: ${HYPGLASS_CONF_SRC}"
    fi

    # 2. Ensure exec-once line is present
    # For JaKooLit, prefer Startup_Apps.conf
    local exec_target="$HYPRLAND_CONF"
    if $IS_JAKOOLIT && [[ -f "$STARTUP_CONF" ]]; then
        exec_target="$STARTUP_CONF"
    fi

    if file_contains "$exec_target" "$HYPGLASS_EXEC"; then
        ok "exec-once line already present in $(basename "$exec_target")"
    else
        if grep -qE '^exec-once\s*=' "$exec_target"; then
            local last_exec
            last_exec=$(grep -nE '^exec-once\s*=' "$exec_target" | tail -1 | cut -d: -f1) || true
            sed -i "${last_exec}a\\${HYPGLASS_EXEC}" "$exec_target"
        else
            echo -e "\n# HyprGlass Studio startup fix\n${HYPGLASS_EXEC}" >> "$exec_target"
        fi
        ok "Added exec-once line to $(basename "$exec_target")"
    fi

    # 3. For JaKooLit, also add keybindings in Keybinds.conf if it exists
    if $IS_JAKOOLIT && [[ -f "$KEYBINDS_CONF" ]]; then
        local bind_toggle='bind = $mainMod, G, exec, ~/.config/hypr/scripts/HyprglassProfile.sh next'
        local bind_menu='bind = $mainMod SHIFT, G, exec, ~/.config/hypr/scripts/HyprglassProfile.sh menu'

        if ! file_contains "$KEYBINDS_CONF" "$bind_toggle"; then
            echo -e "\n# HyprGlass Studio keybindings\n${bind_toggle}" >> "$KEYBINDS_CONF"
            ok "Added keybinding: SUPER + G  (cycle profile)"
        fi
        if ! file_contains "$KEYBINDS_CONF" "$bind_menu"; then
            echo -e "${bind_menu}" >> "$KEYBINDS_CONF"
            ok "Added keybinding: SUPER + SHIFT + G  (profile menu)"
        fi
    fi

    log "Configuration patched safely. Existing structure preserved."
    echo ""
}

# ── Make scripts executable ─────────────────────────────────────────────────
make_executable() {
    log "Setting executable permissions..."

    local count=0

    if $DRY_RUN; then
        for script in "${SCRIPT_DIR}/scripts/"*.{sh,py}; do
            [[ -f "$script" ]] || continue
            count=$((count + 1))
        done
        dry "Would make ${count} script(s) executable"
        echo ""
        return
    fi

    for script in "$SCRIPTS_DIR"/*.{sh,py}; do
        [[ -f "$script" ]] || continue
        chmod +x "$script"
        count=$((count + 1))
    done

    if (( count > 0 )); then
        ok "Made ${count} script(s) executable"
    fi
    echo ""
}

# ── Verification ────────────────────────────────────────────────────────────
verify_installation() {
    log "Running verification..."
    local issues=0

    # Check Hyprglass.conf
    if [[ -f "$HYPGLASS_CONF_DEST" ]]; then
        ok "Hyprglass.conf installed"
    else
        err "Hyprglass.conf missing"
        issues=$((issues + 1))
    fi

    # Check Fix script
    if [[ -x "$FIX_SCRIPT_DEST" ]]; then
        ok "FixHyprglassValues.sh installed and executable"
    else
        err "FixHyprglassValues.sh missing or not executable"
        issues=$((issues + 1))
    fi

    # Check profile switcher
    if [[ -x "${SCRIPTS_DIR}/HyprglassProfile.sh" ]]; then
        ok "HyprglassProfile.sh installed and executable"
    else
        err "HyprglassProfile.sh missing or not executable"
        issues=$((issues + 1))
    fi

    # Check profiles
    local profile_count
    profile_count=$(find "$PROFILES_DIR" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | wc -l)
    if (( profile_count > 0 )); then
        ok "Profiles installed: ${profile_count}"
    else
        warn "No .conf profiles found in ${PROFILES_DIR}"
        issues=$((issues + 1))
    fi

    # Basic sanity check: .conf profiles should contain Hyprland-style assignment lines
    local conf_errors=0
    for prof in "$PROFILES_DIR"/*.conf; do
        [[ -f "$prof" ]] || continue
        if ! grep -qE '^\s*\$?[a-zA-Z0-9_:.@]+\s*=\s*' "$prof"; then
            warn "Profile does not appear to be valid Hyprland config: $(basename "$prof")"
            conf_errors=$((conf_errors + 1))
        fi
    done
    if (( conf_errors == 0 )); then
        ok "All profiles look like valid Hyprland .conf files"
    else
        issues=$((issues + conf_errors))
    fi

    # Check source line in hyprland.conf
    if file_contains "$HYPRLAND_CONF" "$HYPGLASS_CONF_SRC"; then
        ok "hyprland.conf sources Hyprglass.conf"
    else
        err "hyprland.conf does not source Hyprglass.conf"
        issues=$((issues + 1))
    fi

    # Check exec-once line
    local exec_target="$HYPRLAND_CONF"
    if $IS_JAKOOLIT && [[ -f "$STARTUP_CONF" ]]; then
        exec_target="$STARTUP_CONF"
    fi
    if file_contains "$exec_target" "$HYPGLASS_EXEC"; then
        ok "$(basename "$exec_target") runs FixHyprglassValues.sh"
    else
        err "$(basename "$exec_target") does not run FixHyprglassValues.sh"
        issues=$((issues + 1))
    fi

    # Check plugin loaded (only if we are inside a Hyprland session)
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        if hyprctl plugins 2>/dev/null | grep -q hyprglass; then
            ok "hyprglass plugin is loaded in the current session"
        else
            warn "hyprglass plugin is not loaded in the current session"
            warn "Run 'hyprctl reload' after install, or log out and back in"
            issues=$((issues + 1))
        fi
    else
        log "Not running inside a Hyprland session — skipping plugin runtime check"
    fi

    echo ""
    if (( issues == 0 )); then
        ok "Verification passed with no issues"
    else
        warn "Verification completed with ${issues} issue(s) — see above"
    fi
    echo ""
}

# ── Reload Hyprland ─────────────────────────────────────────────────────────
maybe_reload() {
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        return
    fi

    if $DRY_RUN; then
        dry "Would offer to reload Hyprland"
        return
    fi

    if confirm "Reload Hyprland now to apply changes?"; then
        spinner_start "Reloading Hyprland"
        hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed"
        spinner_stop
        ok "Hyprland reload requested"
    else
        log "Skipped Hyprland reload. Run 'hyprctl reload' when ready."
    fi
    echo ""
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    local box_width=66
    local title
    if $DRY_RUN; then
        title="Dry run complete — no changes were made"
    else
        title="HyprGlass Studio installed successfully!"
    fi

    echo ""
    echo -e "${GREEN}╔$(printf '═%.0s' $(seq 1 $box_width))╗${RESET}"
    printf "${GREEN}║${RESET}  %-${box_width}s${GREEN}║${RESET}\n" ""
    printf "${GREEN}║${RESET}  %-64s${GREEN}  ║${RESET}\n" "$title"
    printf "${GREEN}║${RESET}  %-${box_width}s${GREEN}║${RESET}\n" ""
    echo -e "${GREEN}╚$(printf '═%.0s' $(seq 1 $box_width))╝${RESET}"
    echo ""

    if ! $DRY_RUN; then
        echo -e "  ${BOLD}Quick Start:${RESET}"
        echo "    Reload Hyprland:  hyprctl reload"
        echo "    Cycle profile:    SUPER + G"
        echo "    Profile menu:     SUPER + SHIFT + G"
        echo "    Apply profile:    HyprglassProfile.sh apply <profile>"
        echo ""
        echo -e "  ${BOLD}Available profiles:${RESET}"
        for prof in "$PROFILES_DIR"/*.conf; do
            [[ -f "$prof" ]] || continue
            local name
            name=$(basename "$prof" .conf)
            printf "    • %s\n" "$name"
        done
        echo ""
        echo -e "  ${BOLD}Config locations:${RESET}"
        echo "    ${HYPGLASS_CONF_DEST}"
        echo "    ${PROFILES_DIR}/"
        echo "    ${SCRIPTS_DIR}/"
        echo "    ${WALLUST_TEMPLATES_DIR}/"
        echo ""
        echo -e "  ${BOLD}Backup:${RESET} ${BACKUP_DIR}"
        echo ""
        echo -e "  ${BOLD}Documentation:${RESET}"
        echo "    ${SCRIPT_DIR}/docs/"
        echo ""
    else
        echo -e "  ${DIM}Run without ${BOLD}--dry-run${RESET}${DIM} to apply these changes.${RESET}"
        echo ""
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    echo ""
    echo -e "${BOLD}HyprGlass Studio Installer${RESET}"
    if $DRY_RUN; then
        echo -e "${YELLOW}  ── DRY RUN MODE ──${RESET}"
    fi
    echo "────────────────────────────────────────────────────────────"
    echo ""

    detect_jakoolit
    check_prereqs
    backup_configs
    install_plugin
    install_wallust
    copy_configs
    patch_hyprland_conf
    make_executable
    verify_installation
    maybe_reload
    print_summary
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
}
trap cleanup EXIT
trap 'fatal "Interrupted"' INT TERM

main "$@"
