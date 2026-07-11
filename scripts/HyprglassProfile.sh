#!/usr/bin/env bash
# HyprglassProfile.sh - Profile switching for Hyprglass plugin
# Profiles are .conf files using Hyprland-style $-prefixed variables.
# Usage: HyprglassProfile.sh {list|apply|current|menu|next|export|import|import-from-url|marketplace|theme|theme-list|theme-current}

set -euo pipefail
shopt -s nullglob

# Config
PROFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprglass-profiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CURRENT_PROFILE_CACHE="$CACHE_DIR/.hyprglass_profile"
CURRENT_THEME_CACHE="$CACHE_DIR/.hyprglass_theme"
VALIDATOR="$SCRIPT_DIR/ValidateHyprglassConf.sh"
NOTIFIER="$SCRIPT_DIR/HyprglassNotify.sh"
HYPERGLASS_CONF="${HYPERGLASS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/Hyprglass.conf}"
ROFI_THEME="${ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes/rofi-hyprglass.rasi}"

# Fallback to script directory if no profiles dir
[[ -d "$PROFILES_DIR" ]] || PROFILES_DIR="$SCRIPT_DIR/profiles"

# Theme presets live inside the profiles directory
THEMES_DIR="$PROFILES_DIR/themes"
# Fallback to script directory if no themes dir
[[ -d "$THEMES_DIR" ]] || THEMES_DIR="$SCRIPT_DIR/profiles/themes"

# Marketplace registry and bundled community profiles
COMMUNITY_DIR="$PROFILES_DIR/community"
REGISTRY_FILE="$PROFILES_DIR/registry.json"
# Fallback to the source tree when running from the repository
[[ -d "$COMMUNITY_DIR" ]] || COMMUNITY_DIR="$SCRIPT_DIR/../profiles/community"
[[ -f "$REGISTRY_FILE" ]] || REGISTRY_FILE="$SCRIPT_DIR/../profiles/registry.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

die() { printf '%bError: %s%b\n' "$RED" "$1" "$NC" >&2; exit 1; }
info() { printf '%b%s%b\n' "$BLUE" "$1" "$NC"; }
warn() { printf '%b%s%b\n' "$YELLOW" "$1" "$NC"; }

check_deps() {
    command -v hyprctl &>/dev/null || die "hyprctl not found - is Hyprland running?"
}

ensure_dirs() {
    mkdir -p "$PROFILES_DIR" "$THEMES_DIR" "$CACHE_DIR"
}

# Extract a $-prefixed variable value from a profile file.
# get_var <file> <name.with.dots>
get_var() {
    local file="$1" name="$2"
    # Escape regex metacharacters in the variable name (e.g. dots).
    local escaped_name
    escaped_name=$(printf '%s' "$name" | sed 's/[.\\[*^$+?{|]/\\&/g')
    grep -E "^\\\$${escaped_name}\s*=" "$file" 2>/dev/null | head -1 | sed -E 's/^[^=]+=\s*//' | sed -E 's/\s*$//'
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

# Reject values that contain shell/control characters. Values are passed as
# quoted arguments to hyprctl, so Hyprland regex metacharacters ($, (), [],
# {}, ^, +, ?) are intentionally allowed.
validate_value() {
    local value="$1"
    if [[ "$value" =~ [$'\n\r`\\|;&<>'] ]]; then
        warn "Skipping unsafe value: ${value:0:40}"
        return 1
    fi
    return 0
}

# Validate a profile file for correct Hyprglass profile syntax.
validate_profile_file() {
    local file="$1"
    local line_no=0 errors=0

    info "Validating profile file..."

    # Required identity fields.
    local name
    name=$(get_var "$file" "name")
    if [[ -z "$name" ]]; then
        warn "Missing required field: \$name"
        errors=$((errors + 1))
    fi

    # Known numeric fields and ranges.
    declare -A ranges=(
        [glass.blur_strength]="0 10"
        [glass.blur_iterations]="1 5"
        [glass.refraction_strength]="0 2"
        [glass.chromatic_aberration]="0 3"
        [glass.fresnel_strength]="0 2"
        [glass.specular_strength]="0 2"
        [glass.glass_opacity]="0 1"
        [glass.edge_thickness]="0 1"
        [glass.lens_distortion]="0 1"
        [decoration.active_opacity]="0 1"
        [decoration.inactive_opacity]="0 1"
        [decoration.fullscreen_opacity]="0 1"
    )

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_no=$((line_no + 1))
        # Skip blanks and comments.
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Every active line must be a $-prefixed assignment.
        if [[ ! "$line" =~ ^\$[a-zA-Z0-9_.-]+[[:space:]]*= ]]; then
            warn "Invalid syntax on line $line_no: $line"
            errors=$((errors + 1))
            continue
        fi

        # Reject unsafe values.
        local value
        value=$(echo "$line" | sed -E 's/^[^=]+=[[:space:]]*//;s/[[:space:]]*$//')
        if ! validate_value "$value"; then
            errors=$((errors + 1))
        fi

        # Validate known numeric ranges.
        local key
        key=$(echo "$line" | sed -E 's/^\$([a-zA-Z0-9_.-]+)[[:space:]]*=.*/\1/')
        if [[ -n "${ranges[$key]:-}" ]]; then
            local lo hi
            read -r lo hi <<< "${ranges[$key]}"
            if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                warn "$key must be numeric, got '$value'"
                errors=$((errors + 1))
            elif ! awk -v v="$value" -v lo="$lo" -v hi="$hi" 'BEGIN { exit !(v+0 >= lo && v+0 <= hi) }'; then
                warn "$key must be between $lo and $hi, got $value"
                errors=$((errors + 1))
            fi
        fi
    done < "$file"

    if (( errors > 0 )); then
        die "Profile validation failed: $(basename "$file") ($errors error(s))"
    fi
}

# Convert a theme key like "dark.brightness" to Hyprland's "dark:brightness".
theme_key_to_hyprctl() {
    local key="$1"
    # Replace only the first dot with a colon (namespace:key).
    echo "${key/./:}"
}

# Apply per-rule overrides defined as $window_rules.<name>.overrides.*.
apply_rule_overrides() {
    local file="$1"

    grep -E '^\$window_rules\.([^.]+)\.overrides\.' "$file" 2>/dev/null | while IFS= read -r line; do
        local rule_name key value
        rule_name=$(echo "$line" | sed -E 's/^\$window_rules\.([^.]+)\.overrides\.[^=]+=.*/\1/')
        key=$(echo "$line" | sed -E 's/^\$window_rules\.([^.]+)\.overrides\.([^=]+)=.*/\2/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=[[:space:]]*//;s/[[:space:]]*$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue

        local hypr_key=""
        case "$key" in
            enabled|default_theme|default_preset|blur_strength|blur_iterations|refraction_strength|chromatic_aberration|fresnel_strength|specular_strength|glass_opacity|edge_thickness|lens_distortion|tint_color)
                hypr_key="plugin:hyprglass:$key"
                ;;
            active_opacity|inactive_opacity|fullscreen_opacity|rounding|shadow|drop_shadow|shadow_range|shadow_render_power)
                hypr_key="decoration:$key"
                ;;
            brightness|contrast|saturation|vibrancy|vibrancy_darkness|adaptive_dim|adaptive_boost)
                # Theme overrides without a namespace default to the dark theme.
                hypr_key="dark:$key"
                ;;
            dark.*|light.*)
                hypr_key=$(theme_key_to_hyprctl "$key")
                ;;
            *)
                warn "Unknown override key '$key' for rule '$rule_name'; skipping"
                continue
                ;;
        esac

        hyprctl keyword "$hypr_key" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done
}

# Validate the written Hyprglass.conf if it exists.
validate_written_conf() {
    [[ -f "$HYPERGLASS_CONF" ]] || return 0
    [[ -x "$VALIDATOR" ]] || die "Validator not found or not executable: $VALIDATOR"
    info "Validating Hyprglass.conf..."
    if ! "$VALIDATOR" "$HYPERGLASS_CONF"; then
        die "Hyprglass.conf validation failed: $HYPERGLASS_CONF"
    fi
}

# Collect profile files into an array.
collect_profiles() {
    local profiles=()
    for f in "$PROFILES_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        profiles+=("$f")
    done
    if ((${#profiles[@]} > 0)); then
        printf '%s\n' "${profiles[@]}" | sort
    fi
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
            printf '  %b→ %s%b - %s\n' "$GREEN" "$p" "$NC" "$desc"
        else
            printf '  %s - %s\n' "$p" "$desc"
        fi
    done
}

apply_profile() {
    local profile_name="$1"

    validate_profile_name "$profile_name" || die "Invalid profile name: '$profile_name'"

    local profile_file="$PROFILES_DIR/${profile_name}.conf"

    [[ -f "$profile_file" ]] || die "Profile '$profile_name' not found"
    validate_profile_file "$profile_file"

    local name desc
    name=$(get_var "$profile_file" "name")
    [[ -n "$name" ]] || name="$profile_name"
    desc=$(profile_desc_from_file "$profile_file")

    info "Applying profile: $name"
    info "Description: $desc"

    # Apply glass settings: $glass.<key> -> plugin:hyprglass:<key>
    grep -E '^\$glass\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$glass\.([^=]+)=.*/\1/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/[[:space:]]+$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        if [[ "$key" == "enabled" ]]; then
            hyprctl keyword "plugin:hyprglass:enabled" "$value" >/dev/null 2>&1 || true
        else
            hyprctl keyword "plugin:hyprglass:$key" "$value" >/dev/null 2>&1 || true
        fi
        sleep 0.05
    done

    grep -E '^\$theme\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$theme\.([^=]+)=.*/\1/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/[[:space:]]+$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        hyprctl keyword "$(theme_key_to_hyprctl "$key")" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done

    # Apply decoration settings: $decoration.<key> -> decoration:<key>
    grep -E '^\$decoration\.' "$profile_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$decoration\.([^=]+)=.*/\1/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/[[:space:]]+$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        hyprctl keyword "decoration:$key" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done

    # Apply window rules: $window_rules.<name>.* -> windowrulev2
    # Build rules by collecting lines that share the same rule prefix.
    local rule_names=()
    declare -A rule_names_seen
    while IFS= read -r line; do
        local rule_name
        rule_name=$(printf '%s\n' "$line" | sed -E 's/^\$window_rules\.([^.]+)\.[^=]+=.*/\1/')
        [[ -n "$rule_name" ]] || continue
        if [[ -z "${rule_names_seen[$rule_name]:-}" ]]; then
            rule_names_seen[$rule_name]=1
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

    # Apply per-rule overrides after the base profile.
    apply_rule_overrides "$profile_file"

    # Save current profile
    echo "$profile_name" > "$CURRENT_PROFILE_CACHE"

    if [[ -x "$NOTIFIER" ]]; then
        "$NOTIFIER" profile-switch "Applied: $name" 2>/dev/null || true
    fi

    validate_written_conf

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
    local rofi_args=(-dmenu -i -p "Select Profile" -theme-str "window { width: 500px; }")
    [[ -f "$ROFI_THEME" ]] && rofi_args+=(-theme "$ROFI_THEME")

    selected=$(printf '%s\n' "${entries[@]}" | rofi "${rofi_args[@]}") || true

    if [[ -n "$selected" ]]; then
        local profile_name
        profile_name=$(echo "$selected" | cut -d'|' -f1 | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
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

export_profile() {
    local profile_name="$1"
    local output_file="${2:-}"

    validate_profile_name "$profile_name" || die "Invalid profile name: '$profile_name'"

    local profile_file="$PROFILES_DIR/${profile_name}.conf"
    [[ -f "$profile_file" ]] || die "Profile '$profile_name' not found"

    if [[ -n "$output_file" ]]; then
        cp "$profile_file" "$output_file" || die "Failed to export profile to '$output_file'"
        info "Exported profile '$profile_name' to '$output_file'"
    else
        cat "$profile_file"
    fi
}

import_profile() {
    local source_file="$1"

    [[ -f "$source_file" ]] || die "File not found: '$source_file'"

    local profile_name
    profile_name=$(get_var "$source_file" "name")
    [[ -n "$profile_name" ]] || profile_name=$(basename "$source_file" .conf)

    validate_profile_name "$profile_name" || die "Invalid profile name in file: '$profile_name'"

    local target_file="$PROFILES_DIR/${profile_name}.conf"
    if [[ -f "$target_file" ]]; then
        warn "Profile '$profile_name' already exists and will be overwritten"
    fi

    validate_profile_file "$source_file"

    ensure_dirs
    cp "$source_file" "$target_file" || die "Failed to import profile to '$target_file'"
    info "Imported profile '$profile_name' to '$target_file'"
}

import_from_url() {
    local url="$1"

    [[ -n "$url" ]] || die "URL required"

    # Only allow HTTPS URLs to prevent file:// or other local fetches.
    if [[ ! "$url" =~ ^https:// ]]; then
        die "Only HTTPS URLs are allowed for profile imports"
    fi

    local tmp_file
    tmp_file=$(mktemp --suffix=.conf) || die "Failed to create temporary file"
    trap 'rm -f "${tmp_file:-}"' EXIT

    info "Downloading profile from $url..."
    if command -v curl &>/dev/null; then
        if ! curl -fsSL -- "$url" > "$tmp_file"; then
            die "Failed to download profile from '$url'"
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -qO - -- "$url" > "$tmp_file"; then
            die "Failed to download profile from '$url'"
        fi
    else
        die "curl or wget is required for URL imports"
    fi

    import_profile "$tmp_file"
}

# Locate the marketplace registry, preferring the installed copy.
find_registry() {
    if [[ -f "$REGISTRY_FILE" ]]; then
        echo "$REGISTRY_FILE"
        return 0
    fi
    die "Marketplace registry not found: $REGISTRY_FILE"
}

# Locate the bundled community profiles directory.
find_community_dir() {
    if [[ -d "$COMMUNITY_DIR" ]]; then
        echo "$COMMUNITY_DIR"
        return 0
    fi
    die "Community profiles directory not found: $COMMUNITY_DIR"
}

marketplace_list() {
    local registry
    registry=$(find_registry)

    info "Available marketplace profiles:"
    if command -v jq &>/dev/null; then
        jq -r '.profiles[] | "  \(.name) - \(.description)"' "$registry"
    elif command -v python3 &>/dev/null; then
        python3 - "$registry" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
for p in d.get("profiles", []):
    print(f"  {p.get('name', '')} - {p.get('description', '')}")
PY
    else
        die "jq or python3 is required to read the marketplace registry"
    fi
}

marketplace_install() {
    local profile_name="$1"

    validate_profile_name "$profile_name" || die "Invalid profile name: '$profile_name'"

    local registry community_dir
    registry=$(find_registry)
    community_dir=$(find_community_dir)

    local source_file="$community_dir/${profile_name}.conf"
    [[ -f "$source_file" ]] || die "Marketplace profile '$profile_name' not found in $community_dir"

    ensure_dirs

    local target_file="$PROFILES_DIR/${profile_name}.conf"
    cp "$source_file" "$target_file" || die "Failed to install profile to '$target_file'"
    info "Installed marketplace profile: $profile_name"
    info "Apply it with: $(basename "$0") apply $profile_name"
}

# Collect theme files into an array.
collect_themes() {
    local themes=()
    for f in "$THEMES_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        themes+=("$f")
    done
    if ((${#themes[@]} > 0)); then
        printf '%s\n' "${themes[@]}" | sort
    fi
}

list_themes() {
    ensure_dirs
    local themes=()
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        themes+=("$f")
    done < <(collect_themes)

    if [[ ${#themes[@]} -eq 0 ]]; then
        warn "No themes found in $THEMES_DIR"
        return 1
    fi

    local current
    current=$(cat "$CURRENT_THEME_CACHE" 2>/dev/null || echo "none")

    info "Available themes:"
    for f in "${themes[@]}"; do
        local t desc
        t=$(profile_name_from_file "$f")
        desc=$(profile_desc_from_file "$f")
        if [[ "$t" == "$current" ]]; then
            printf '  %b→ %s%b - %s\n' "$GREEN" "$t" "$NC" "$desc"
        else
            printf '  %s - %s\n' "$t" "$desc"
        fi
    done
}

show_current_theme() {
    local current
    current=$(cat "$CURRENT_THEME_CACHE" 2>/dev/null || echo "none")

    if [[ "$current" == "none" ]]; then
        warn "No theme currently active"
        return 1
    fi

    local theme_file="$THEMES_DIR/$current.conf"
    if [[ ! -f "$theme_file" ]]; then
        warn "Theme '$current' not found"
        return 1
    fi

    local name desc
    name=$(get_var "$theme_file" "name")
    [[ -n "$name" ]] || name="$current"
    desc=$(profile_desc_from_file "$theme_file")

    info "Current theme: $name"
    info "Description: $desc"
}

apply_theme() {
    local theme_name="$1"

    validate_profile_name "$theme_name" || die "Invalid theme name: '$theme_name'"

    local theme_file="$THEMES_DIR/${theme_name}.conf"

    [[ -f "$theme_file" ]] || die "Theme '$theme_name' not found"
    validate_profile_file "$theme_file"

    local name desc
    name=$(get_var "$theme_file" "name")
    [[ -n "$name" ]] || name="$theme_name"
    desc=$(profile_desc_from_file "$theme_file")

    info "Applying theme: $name"
    info "Description: $desc"

    # Set the active theme in the plugin
    hyprctl keyword "plugin:hyprglass:default_theme" "$name" >/dev/null 2>&1 || true
    sleep 0.05

    # Apply theme settings: $theme.<namespace>.* -> <namespace>:<key>
    grep -E '^\$theme\.' "$theme_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$theme\.([^=]+)=.*/\1/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/[[:space:]]+$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        hyprctl keyword "$(theme_key_to_hyprctl "$key")" "$value" >/dev/null 2>&1 || true
        sleep 0.05
    done

    # Apply glass settings from the theme (e.g. tint_color)
    grep -E '^\$glass\.' "$theme_file" 2>/dev/null | while IFS= read -r line; do
        local key value
        key=$(echo "$line" | sed -E 's/^\$glass\.([^=]+)=.*/\1/' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
        value=$(echo "$line" | sed -E 's/^[^=]+=\s*//' | sed -E 's/[[:space:]]+$//')
        [[ -n "$key" ]] || continue
        validate_value "$value" || continue
        if [[ "$key" == "enabled" ]]; then
            hyprctl keyword "plugin:hyprglass:enabled" "$value" >/dev/null 2>&1 || true
        else
            hyprctl keyword "plugin:hyprglass:$key" "$value" >/dev/null 2>&1 || true
        fi
        sleep 0.05
    done

    # Save current theme
    echo "$theme_name" > "$CURRENT_THEME_CACHE"

    if [[ -x "$NOTIFIER" ]]; then
        "$NOTIFIER" profile-switch "Theme applied: $name" 2>/dev/null || true
    fi

    info "Theme applied successfully"
}

usage() {
    echo "Usage: $(basename "$0") {list|apply <profile>|current|menu|next|export <profile> [file]|import <file>|import-from-url <url>|marketplace list|marketplace install <name>|theme <name>|theme-list|theme-current}"
    echo ""
    echo "Commands:"
    echo "  list                          List available profiles"
    echo "  apply <profile>               Apply a profile"
    echo "  current                       Show current profile"
    echo "  menu                          Show rofi menu"
    echo "  next                          Cycle to next profile"
    echo "  export <profile> [file]       Export a profile to stdout or file"
    echo "  import <file>                 Import a profile into $PROFILES_DIR"
    echo "  import-from-url <url>         Download and import a profile"
    echo "  marketplace list              List bundled community marketplace profiles"
    echo "  marketplace install <name>    Install a community profile into $PROFILES_DIR"
    echo "  theme <name>                  Apply a theme preset"
    echo "  theme-list                    List available theme presets"
    echo "  theme-current                 Show current theme preset"
    echo ""
    echo "Profiles directory: $PROFILES_DIR"
    echo "Themes directory:   $THEMES_DIR"
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
        export)
            [[ -n "${2:-}" ]] || die "Profile name required"
            export_profile "$2" "${3:-}"
            ;;
        import)
            [[ -n "${2:-}" ]] || die "File path required"
            import_profile "$2"
            ;;
        import-from-url)
            [[ -n "${2:-}" ]] || die "URL required"
            import_from_url "$2"
            ;;
        marketplace)
            case "${2:-}" in
                list)
                    marketplace_list
                    ;;
                install)
                    [[ -n "${3:-}" ]] || die "Profile name required"
                    marketplace_install "$3"
                    ;;
                *)
                    echo "Usage: $(basename "$0") marketplace {list|install <name>}"
                    exit 1
                    ;;
            esac
            ;;
        theme)
            [[ -n "${2:-}" ]] || die "Theme name required"
            apply_theme "$2"
            ;;
        theme-list)
            list_themes
            ;;
        theme-current)
            show_current_theme
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
