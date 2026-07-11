#!/bin/bash
# HyprglassProfile.sh - Profile switching for Hyprglass plugin
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
    command -v jq &>/dev/null || die "jq not found"
}

ensure_dirs() {
    mkdir -p "$PROFILES_DIR" "$CACHE_DIR"
}

list_profiles() {
    ensure_dirs
    local profiles=()
    for f in "$PROFILES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        profiles+=("$(basename "$f" .json)")
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No profiles found in $PROFILES_DIR"
        return 1
    fi

    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "none")

    info "Available profiles:"
    for p in "${profiles[@]}"; do
        local desc
        desc=$(jq -r '.description // "No description"' "$PROFILES_DIR/$p.json")
        if [[ "$p" == "$current" ]]; then
            echo -e "  ${GREEN}→ $p${NC} - $desc"
        else
            echo -e "  $p - $desc"
        fi
    done
}

apply_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/$profile_name.json"

    [[ -f "$profile_file" ]] || die "Profile '$profile_name' not found"

    local json
    json=$(cat "$profile_file") || die "Failed to read profile"

    # Validate JSON
    echo "$json" | jq empty 2>/dev/null || die "Invalid JSON in profile"

    local name desc
    name=$(echo "$json" | jq -r '.name // empty')
    desc=$(echo "$json" | jq -r '.description // "No description"')

    [[ -n "$name" ]] || die "Profile missing 'name' field"

    info "Applying profile: $name"
    info "Description: $desc"

    # Apply glass settings
    if echo "$json" | jq -e '.glass' &>/dev/null; then
        local enabled
        enabled=$(echo "$json" | jq -r '.glass.enabled // empty')

        if [[ "$enabled" == "false" ]]; then
            hyprctl keyword plugin:hyprglass:enabled 0
            sleep 0.2
        elif [[ "$enabled" == "true" ]]; then
            hyprctl keyword plugin:hyprglass:enabled 1
            sleep 0.2
        fi

        # Apply other glass settings
        echo "$json" | jq -r '.glass | to_entries[] | select(.key != "enabled") | "\(.key) \(.value)"' | \
        while read -r key value; do
            hyprctl keyword "plugin:hyprglass:$key" "$value"
            sleep 0.2
        done
    fi

    # Apply decoration settings
    if echo "$json" | jq -e '.decoration' &>/dev/null; then
        echo "$json" | jq -r '.decoration | to_entries[] | "\(.key) \(.value)"' | \
        while read -r key value; do
            hyprctl keyword "decoration:$key" "$value"
            sleep 0.2
        done
    fi

    # Save current profile
    echo "$profile_name" > "$CURRENT_PROFILE_CACHE"

    notify-send -i preferences-desktop -u low \
        "Hyprglass Profile" "Applied: $name"

    info "Profile applied successfully"
}

show_current() {
    local current
    current=$(cat "$CURRENT_PROFILE_CACHE" 2>/dev/null || echo "none")

    if [[ "$current" == "none" ]]; then
        warn "No profile currently active"
        return 1
    fi

    local profile_file="$PROFILES_DIR/$current.json"
    if [[ ! -f "$profile_file" ]]; then
        warn "Profile '$current' not found"
        return 1
    fi

    local name desc
    name=$(jq -r '.name // empty' "$profile_file")
    desc=$(jq -r '.description // "No description"' "$profile_file")

    info "Current profile: $name"
    info "Description: $desc"
}

show_menu() {
    ensure_dirs
    local profiles=()
    local descriptions=()

    for f in "$PROFILES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name desc
        name=$(jq -r '.name // "unknown"' "$f")
        desc=$(jq -r '.description // "No description"' "$f")
        profiles+=("$name")
        descriptions+=("$desc")
    done

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
        -theme-str "window { width: 500px; }")

    if [[ -n "$selected" ]]; then
        local profile_name
        profile_name=$(echo "$selected" | cut -d'|' -f1 | xargs)
        apply_profile "$profile_name"
    fi
}

next_profile() {
    ensure_dirs
    local profiles=()
    for f in "$PROFILES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        profiles+=("$(basename "$f" .json)")
    done

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
