#!/usr/bin/env bash
# HyprglassProfile.sh - Profile switching for Hyprglass plugin
# Profiles are .conf files using Hyprland-style $-prefixed variables.
# Usage: HyprglassProfile.sh {list|apply|current|menu|next}

set -euo pipefail

# Config
PROFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprglass-profiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CURRENT_PROFILE_CACHE="$CACHE_DIR/.hyprglass_profile"

# Fallback to script directory if no profiles dir
[[ -d "$PROFILES_DIR" ]] || PROFILES_DIR="$SCRIPT_DIR/profiles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

die() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
info() { echo -e "${BLUE}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }

check_deps() {
    command -v hyprctl &>/dev/null || die "hyprctl not found - is Hyprland running?"
}

ensure_dirs() {
    mkdir -p "$PROFILES_DIR" "$CACHE_DIR"
}

# Extract a $-prefixed variable value from a profile file.
# get_var <file> <name.with.dots>
get_var() {
    local file="$1" name="$2"
    grep -E "^\\\$${name}\s*=" "$file" 2>/dev/null | head -1 | sed -E 's/^[^=]+=\s*//' | sed -E 's/\s*$//'
}

# Get the base name of a profile file without extension.
profile_name_from_file() {
    basename "$1" .conf
}

# Get profile description from $metadata.description.
profile_desc_from_file() {
    local file="$1"
    local desc
    desc=$(get_var "$file" "metadata.description")
    [[ -n "$desc" ]] && echo "$desc" || echo "No description"
}

# Only allow simple profile names; reject paths and shell metacharacters.
validate_profile_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# Reject values that contain shell metacharacters or newlines. Even though
# values are passed directly to hyprctl, this guard protects against future
# refactoring mistakes and hostile config files.
validate_value() {
    local value="$1"
    if [[ "$value" =~ [$'\n\r`|;&$(){}[\\]<>!'] ]]; then
        warn "Skipping unsafe value: ${value:0:40}"
        return 1
    fi
    return 0
}

# Collect profile files into an array.
collect_profiles() {
    local profiles=()
    for f in "$PROFILES_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        profiles+=("$f")
    done
    printf '%s\n' "${profiles[@]}"
}

list_profiles() {
    ensure_dirs
    local profiles=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && profiles+=("$f")
    done < <(collect_profiles)

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No profiles found in $PROFILES_DIR"
        return 1
    fi

    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "none")

    info "Available profiles:"
    for f in "${profiles[@]}"; do
        local p desc
        p=$(profile_name_from_file "$f")
        desc=$(profile_desc_from_file "$f")
        if [[ "$p" == "$current" ]]; then
            echo -e "  ${GREEN}→ $p${NC} - $desc"
        else
            echo -e "  $p - $desc"
        fi
    done
}

apply_profile() {
    local profile_name="$1"

    validate_profile_name "$profile_name" || die "Invalid profile name: '$profile_name'"

    local profile_file="$PROFILES_DIR/${profile_name}.conf"

    [[ -f "$profile_file" ]] || die "Profile '$profile_name' not found"

    local name desc
    name=$(get_var "$profile_file" "name")
    [[ -n "$name" ]] || name="$profile_name"
    desc=$(profile_desc_from_file "$profile_file")

    info "Applying profile: $name"
    info "Description: $desc"

    # Apply glass settings: $glass.<key> -> plugin:hyprglass:<key>
    grep -E '^\$glass\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$glass\.([^=]+)=.*/\1/' | xargs)
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/\s*$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        if [[ "$key" == "enabled" ]]; then
            hyprctl keyword "plugin:hyprglass:enabled" "$value" >/dev/null 2>&1 || true
        else
            hyprctl keyword "plugin:hyprglass:$key" "$value" >/dev/null 2>&1 || true
        fi
        sleep 0.05
    done

    # Apply theme settings: $theme.<theme>.<key> -> <theme>:<key>
    grep -E '^\$theme\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$theme\.([^=]+)=.*/\1/' | xargs)
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/\s*$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        hyprctl keyword "$key" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done

    # Apply decoration settings: $decoration.<key> -> decoration:<key>
    grep -E '^\$decoration\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$decoration\.([^=]+)=.*/\1/' | xargs)
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/\s*$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        hyprctl keyword "decoration:$key" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done

    # Apply window rules: $window_rules.<name>.* -> windowrulev2
    # Build rules by collecting lines that share the same rule prefix.
    local rule_names=()
    while IFS= read -r line; do
        local rule_name
        rule_name=$(echo "$line" | sed -E 's/^\$window_rules\.([^.]+)\.[^=]+=.*/\1/')
        [[ -n "$rule_name" ]] || continue
        if [[ ! " ${rule_names[*]} " =~ " ${rule_name} " ]]; then
            rule_names+=("$rule_name")
        fi
    done < <(grep -E '^\$window_rules\.' "$profile_file" 2>/dev/null)

    local tag
    for rule_name in "${rule_names[@]}"; do
        local action match
        action=$(get_var "$profile_file" "window_rules.${rule_name}.action")
        match=$(get_var "$profile_file" "window_rules.${rule_name}.match")
        [[ -n "$action" ]] || continue
        validate_value "$action" || continue
        validate_value "$match" || continue

        case "$action" in
            disable) tag="hyprglass_disabled" ;;
            subtle|minimal) tag="hyprglass_preset_subtle" ;;
            full|default) tag="hyprglass_enabled" ;;
            ui) tag="hyprglass_preset_ui" ;;
            *) tag="hyprglass_enabled" ;;
        esac

        if [[ -n "$match" ]]; then
            # Replace commas with ', ' for Hyprland windowrulev2 syntax
            local match_formatted
            match_formatted=$(echo "$match" | sed 's/,/, /g')
            hyprctl keyword "windowrulev2" "tag +${tag}, ${match_formatted}" >/dev/null 2>&1 || true
            sleep 0.05
        fi
    done

    # Save current profile
    echo "$profile_name" > "$CURRENT_PROFILE_CACHE"

    if command -v notify-send &>/dev/null; then
        notify-send -i preferences-desktop -u low \
            "Hyprglass Profile" "Applied: $name" 2>/dev/null || true
    fi

    info "Profile applied successfully"
}

show_current() {
    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "none")

    if [[ "$current" == "none" ]]; then
        warn "No profile currently active"
        return 1
    fi

    local profile_file="$PROFILES_DIR/$current.conf"
    if [[ ! -f "$profile_file" ]]; then
        warn "Profile '$current' not found"
        return 1
    fi

    local name desc
    name=$(get_var "$profile_file" "name")
    [[ -n "$name" ]] || name="$current"
    desc=$(profile_desc_from_file "$profile_file")

    info "Current profile: $name"
    info "Description: $desc"
}

show_menu() {
    ensure_dirs
    local profiles=()
    local descriptions=()

    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        local name desc
        name=$(profile_name_from_file "$f")
        desc=$(profile_desc_from_file "$f")
        profiles+=("$name")
        descriptions+=("$desc")
    done < <(collect_profiles)

    [[ ${#profiles[@]} -gt 0 ]] || die "No profiles found"

    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "none")

    # Build menu entries
    local entries=()
    for i in "${!profiles[@]}"; do
        local marker=""
        [[ "${profiles[$i]}" == "$current" ]] && marker=" ✓"
        entries+=("${profiles[$i]} | ${descriptions[$i]}$marker")
    done

    # Show rofi menu
    local selected
    selected=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i -p "Select Profile" \
        -theme-str "window { width: 500px; }") || true

    if [[ -n "$selected" ]]; then
        local profile_name
        profile_name=$(echo "$selected" | cut -d'|' -f1 | xargs)
        validate_profile_name "$profile_name" || die "Invalid profile selected"
        apply_profile "$profile_name"
    fi
}

next_profile() {
    ensure_dirs
    local profiles=()
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        profiles+=("$(profile_name_from_file "$f")")
    done < <(collect_profiles)

    [[ ${#profiles[@]} -gt 0 ]] || die "No profiles found"

    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "${profiles[0]}")

    # Find current index
    local idx=0
    for i in "${!profiles[@]}"; do
        if [[ "${profiles[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Next index
    idx=$(( (idx + 1) % ${#profiles[@]} ))

    apply_profile "${profiles[$idx]}"
}

usage() {
    echo "Usage: $(basename "$0") {list|apply <profile>|current|menu|next}"
    echo ""
    echo "Commands:"
    echo "  list              List available profiles"
    echo "  apply <profile>   Apply a profile"
    echo "  current           Show current profile"
    echo "  menu              Show rofi menu"
    echo "  next              Cycle to next profile"
    echo ""
    echo "Profiles directory: $PROFILES_DIR"
}

main() {
    check_deps

    case "${1:-}" in
        list)
            list_profiles
            ;;
        apply)
            [[ -n "${2:-}" ]] || die "Profile name required"
            apply_profile "$2"
            ;;
        current)
            show_current
            ;;
        menu)
            show_menu
            ;;
        next)
            next_profile
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
