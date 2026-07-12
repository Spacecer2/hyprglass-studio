#!/usr/bin/env bash
# ImportJaKooLitDefaults.sh — Import JaKooLit decoration settings into a HyprGlass profile
#
# Reads the user's existing JaKooLit UserDecorations.conf, extracts current
# opacity/blur/rounding values, and generates a HyprGlass Studio profile that
# preserves the same visual feel while enabling HyprGlass glass effects.
#
# Usage: ImportJaKooLitDefaults.sh [options]
#   -i, --input <path>     Path to UserDecorations.conf (default: ~/.config/hypr/UserConfigs/UserDecorations.conf)
#   -o, --output <path>    Output profile path (default: ~/.config/hypr/hyprglass-profiles/jakoolit-imported.conf)
#   -n, --name <name>      Profile name inside the generated file (default: jakoolit-imported)
#   -a, --apply            Apply the generated profile immediately after import
#   -f, --force            Overwrite existing profile without prompting
#   -d, --dry-run          Print the generated profile to stdout instead of writing it
#   -h, --help             Show this help message

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprglass-profiles"
PROFILE_SWITCHER="${SCRIPT_DIR}/HyprglassProfile.sh"

DEFAULT_INPUT="${HOME}/.config/hypr/UserConfigs/UserDecorations.conf"
FALLBACK_INPUTS=(
    "$DEFAULT_INPUT"
    "${HOME}/.config/hyprland/UserConfigs/UserDecorations.conf"
    "${HOME}/.config/hypr/UserDecorations.conf"
)

# ── Defaults ─────────────────────────────────────────────────────────────────
PROFILE_NAME="jakoolit-imported"
OUTPUT_FILE=""
APPLY=false
FORCE=false
DRY_RUN=false

# ── Logging ──────────────────────────────────────────────────────────────────
log_info()  { printf '\033[0;36m[INFO]\033[0m  %s\n' "$*"; }
log_warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERR ]\033[0m  %s\n' "$*" >&2; }
log_ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }

# ── Helpers ──────────────────────────────────────────────────────────────────
usage() {
    sed -n '/^# Usage:/,/^#   -h/p' "$0" | sed 's/^# //'
}

find_input_file() {
    local path="${1:-}"
    if [[ -n "$path" ]]; then
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
        log_error "Specified input file not found: $path"
        return 1
    fi

    for candidate in "${FALLBACK_INPUTS[@]}"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    log_error "JaKooLit UserDecorations.conf not found. Searched:"
    printf '  %s\n' "${FALLBACK_INPUTS[@]}" >&2
    log_error "Specify the path with -i / --input"
    return 1
}

# Extract a top-level or nested key from a Hyprland config block.
# get_conf_value <file> <key>
get_conf_value() {
    local file="$1"
    local key="$2"
    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1 | sed -E 's/^[^=]+=[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]*#.*$//'
}

# Extract a value from inside a named block (one level deep).
# get_block_value <file> <block> <key>
get_block_value() {
    local file="$1"
    local block="$2"
    local key="$3"
    awk -v block="$block" -v key="$key" '
        /^[[:space:]]*\w+[[:space:]]*\{/ { in_block = ($1 == block) }
        /^[[:space:]]*\}/ { in_block = 0 }
        in_block && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            sub(/^[^=]+=[[:space:]]*/, "")
            sub(/[[:space:]]*$/, "")
            sub(/[[:space:]]*#.*$/, "")
            print
            exit
        }
    ' "$file"
}

# Clamp a numeric value between min and max.
clamp() {
    local value="$1"
    local min="$2"
    local max="$3"
    awk -v v="$value" -v min="$min" -v max="$max" 'BEGIN {
        if (v < min) v = min
        if (v > max) v = max
        printf "%.4g", v
    }'
}

# Map JaKooLit blur size (Hyprland decoration:blur:size) to HyprGlass blur_strength.
# Hyprland size is roughly pixels/radius; HyprGlass strength is an effect intensity.
map_blur_strength() {
    local size="${1:-8}"
    awk -v s="$size" 'BEGIN {
        # Linear scaling tuned so size 8 → ~3.4 and size 0 → 0.0
        v = s * 0.425
        if (v > 10) v = 10
        printf "%.2f", v
    }'
}

# Derive glass_opacity from active_opacity so the profile feels consistent.
map_glass_opacity() {
    local active="${1:-0.75}"
    awk -v a="$active" 'BEGIN {
        # Lower window opacity → higher glass opacity (more visible glass layer)
        v = 1.0 - ((1.0 - a) * 0.75)
        if (v < 0.1) v = 0.1
        if (v > 1.0) v = 1.0
        printf "%.2f", v
    }'
}

# Derive theme vibrancy from active opacity.
map_vibrancy() {
    local active="${1:-0.75}"
    awk -v a="$active" 'BEGIN {
        # More transparent windows benefit from higher vibrancy
        v = (1.0 - a) * 1.5
        if (v > 1.0) v = 1.0
        printf "%.2f", v
    }'
}

# Convert a string-ish boolean to lowercase true/false.
normalize_bool() {
    local val="${1:-true}"
    case "${val,,}" in
        true|yes|1|on)  echo "true" ;;
        *)              echo "false" ;;
    esac
}

# Check whether borders are transparent (required for glass edges).
is_border_transparent() {
    local color="$1"
    [[ "$color" =~ rgba\(.*0+\)$ ]] || [[ "$color" == "rgba(00000000)" ]]
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    local input_arg=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                input_arg="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -n|--name)
                PROFILE_NAME="$2"
                shift 2
                ;;
            -a|--apply)
                APPLY=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage >&2
                exit 1
                ;;
        esac
    done

    INPUT_FILE=$(find_input_file "$input_arg") || exit 1

    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="${PROFILES_DIR}/${PROFILE_NAME}.conf"
    fi
}

# ── Main import logic ────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    log_info "Reading JaKooLit settings from: ${INPUT_FILE}"

    # ── Extract JaKooLit values ──────────────────────────────────────────────
    local active_opacity inactive_opacity fullscreen_opacity
    local blur_size blur_passes blur_enabled
    local dim_inactive rounding active_border inactive_border

    active_opacity=$(get_block_value "$INPUT_FILE" "decoration" "active_opacity")
    inactive_opacity=$(get_block_value "$INPUT_FILE" "decoration" "inactive_opacity")
    fullscreen_opacity=$(get_block_value "$INPUT_FILE" "decoration" "fullscreen_opacity")
    dim_inactive=$(get_block_value "$INPUT_FILE" "decoration" "dim_inactive")
    rounding=$(get_block_value "$INPUT_FILE" "decoration" "rounding")

    blur_size=$(get_block_value "$INPUT_FILE" "blur" "size")
    blur_passes=$(get_block_value "$INPUT_FILE" "blur" "passes")
    blur_enabled=$(get_block_value "$INPUT_FILE" "blur" "enabled")

    active_border=$(get_block_value "$INPUT_FILE" "general" "col.active_border")
    inactive_border=$(get_block_value "$INPUT_FILE" "general" "col.inactive_border")

    # ── Apply sensible defaults when values are missing ──────────────────────
    active_opacity="${active_opacity:-0.75}"
    inactive_opacity="${inactive_opacity:-0.65}"
    fullscreen_opacity="${fullscreen_opacity:-1.0}"
    blur_size="${blur_size:-8}"
    blur_passes="${blur_passes:-4}"
    blur_enabled="${blur_enabled:-true}"
    dim_inactive="${dim_inactive:-false}"
    rounding="${rounding:-10}"

    # ── Map to HyprGlass profile values ──────────────────────────────────────
    local blur_strength blur_iterations glass_opacity vibrancy
    blur_strength=$(map_blur_strength "$blur_size")
    blur_iterations=$(clamp "$blur_passes" 1 5)
    glass_opacity=$(map_glass_opacity "$active_opacity")
    vibrancy=$(map_vibrancy "$active_opacity")

    # When JaKooLit blur is disabled, generate a minimal/non-glassy profile.
    if [[ "$(normalize_bool "$blur_enabled")" == "false" ]]; then
        blur_strength="0.0"
        blur_iterations="1"
        glass_opacity="0.0"
        vibrancy="0.0"
    fi

    # ── Warnings about settings that break glass ─────────────────────────────
    if [[ "$(normalize_bool "$dim_inactive")" == "true" ]]; then
        log_warn "dim_inactive is enabled in UserDecorations.conf; this darkens glass layers."
        log_warn "  Consider setting dim_inactive = false for the best HyprGlass experience."
    fi

    if ! is_border_transparent "$active_border" || ! is_border_transparent "$inactive_border"; then
        log_warn "Non-transparent borders detected (active: ${active_border:-none}, inactive: ${inactive_border:-none})."
        log_warn "  HyprGlass works best with transparent borders, e.g. rgba(00000000)."
    fi

    # ── Build profile content ────────────────────────────────────────────────
    local profile_content
    profile_content=$(cat <<EOF
# HyprGlass Studio profile
# Auto-generated from JaKooLit UserDecorations.conf
# Source: ${INPUT_FILE}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Profile identity
\$name = ${PROFILE_NAME}
\$version = 1.0.0
\$inherits = default

# Metadata
\$metadata.author = JaKooLit Import
\$metadata.description = Imported from JaKooLit UserDecorations.conf (blur size ${blur_size}, passes ${blur_passes}, active opacity ${active_opacity})

# Glass effect settings — derived from decoration:blur
\$glass.blur_strength = ${blur_strength}
\$glass.blur_iterations = ${blur_iterations}
\$glass.refraction_strength = 0.96
\$glass.chromatic_aberration = 0.7
\$glass.fresnel_strength = 0.96
\$glass.specular_strength = 0.6
\$glass.glass_opacity = ${glass_opacity}
\$glass.edge_thickness = 0.14
\$glass.lens_distortion = 0.42

# Theme settings
\$theme.dark.brightness = 1.1
\$theme.dark.contrast = 1.2
\$theme.dark.saturation = 1.15
\$theme.dark.vibrancy = ${vibrancy}
\$theme.dark.vibrancy_darkness = 0.52
\$theme.dark.adaptive_dim = 0.65
\$theme.dark.adaptive_boost = 0.34

# Decoration settings — imported from UserDecorations.conf
\$decoration.active_opacity = ${active_opacity}
\$decoration.inactive_opacity = ${inactive_opacity}
\$decoration.fullscreen_opacity = ${fullscreen_opacity}
\$decoration.rounding = ${rounding}

# Window rules
\$window_rules.fullscreen.match = fullscreen 1
\$window_rules.fullscreen.action = disable
\$window_rules.fullscreen.reason = Fullscreen windows - glass disabled for unobstructed view
\$window_rules.games.match = class ^(steam_app_.+|gamescope)$
\$window_rules.games.action = disable
\$window_rules.games.reason = Games - glass disabled for performance and compatibility
\$window_rules.video_players.match = class ^(mpv|vlc|celluloid)$
\$window_rules.video_players.action = minimal
\$window_rules.video_players.reason = Video players - minimal glass to preserve video clarity
\$window_rules.video_players.overrides.blur_strength = 1.0
\$window_rules.video_players.overrides.glass_opacity = 0.3
\$window_rules.video_players.overrides.active_opacity = 0.95
\$window_rules.browsers.match = class ^(firefox|chrome|chromium|brave|vivaldi|zen)$
\$window_rules.browsers.action = full
\$window_rules.browsers.reason = Browsers - full glass effect for immersive experience
\$window_rules.browsers.overrides.blur_strength = 4.0
\$window_rules.browsers.overrides.refraction_strength = 1.0
\$window_rules.browsers.overrides.fresnel_strength = 1.0
\$window_rules.terminals.match = class ^(kitty|Alacritty|wezterm|foot|ghostty|com.mitchellh.ghostty)$
\$window_rules.terminals.action = subtle
\$window_rules.terminals.reason = Terminals - subtle glass for readability
\$window_rules.terminals.overrides.blur_strength = 2.0
\$window_rules.terminals.overrides.glass_opacity = 0.7
\$window_rules.terminals.overrides.active_opacity = 0.85
\$window_rules.terminals.overrides.inactive_opacity = 0.75
\$window_rules.fallback.action = default
\$window_rules.fallback.reason = All other windows use the profile defaults
EOF
)

    # ── Output ───────────────────────────────────────────────────────────────
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '%s\n' "$profile_content"
        log_ok "Dry run complete. Profile was not written."
        exit 0
    fi

    if [[ -f "$OUTPUT_FILE" && "$FORCE" != "true" ]]; then
        log_warn "Profile already exists: ${OUTPUT_FILE}"
        read -rp "Overwrite? [y/N] " answer
        if [[ "${answer,,}" != "y" && "${answer,,}" != "yes" ]]; then
            log_info "Import cancelled."
            exit 0
        fi
    fi

    mkdir -p "$(dirname "$OUTPUT_FILE")"
    printf '%s\n' "$profile_content" > "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"

    log_ok "Imported JaKooLit settings to: ${OUTPUT_FILE}"
    log_info "  active_opacity:    ${active_opacity}"
    log_info "  inactive_opacity:  ${inactive_opacity}"
    log_info "  fullscreen_opacity: ${fullscreen_opacity}"
    log_info "  blur size → blur_strength: ${blur_size} → ${blur_strength}"
    log_info "  blur passes → blur_iterations: ${blur_passes} → ${blur_iterations}"
    log_info "  rounding:          ${rounding}"

    # ── Apply if requested ───────────────────────────────────────────────────
    if [[ "$APPLY" == "true" ]]; then
        if [[ -x "$PROFILE_SWITCHER" ]]; then
            log_info "Applying profile: ${PROFILE_NAME}"
            "$PROFILE_SWITCHER" apply "$PROFILE_NAME"
        else
            log_error "Profile switcher not found or not executable: ${PROFILE_SWITCHER}"
            log_info "Apply manually with: HyprglassProfile.sh apply ${PROFILE_NAME}"
            exit 1
        fi
    else
        log_info "Apply with: HyprglassProfile.sh apply ${PROFILE_NAME}"
    fi
}

main "$@"
