#!/usr/bin/env bash
# ValidateHyprglassConf.sh - Validates a Hyprglass.conf file.
# Exit 0 if valid, non-zero if invalid. Prints errors to stderr.

set -euo pipefail

CONF_FILE="${1:-}"

if [[ -z "$CONF_FILE" ]]; then
    echo "Usage: $0 <path-to-Hyprglass.conf>" >&2
    exit 2
fi

if [[ ! -f "$CONF_FILE" ]]; then
    echo "File not found: $CONF_FILE" >&2
    exit 1
fi

ERRORS=()
WARNINGS=()

add_error() {
    ERRORS+=("$1")
}

add_warning() {
    WARNINGS+=("$1")
}

# Extract the body of a block named BLOCK { ... }.
# Outputs lines between the opening and matching close brace.
extract_block() {
    local name="$1" file="$2"
    awk -v block="$name" '
        BEGIN { in_block=0; depth=0 }
        $0 ~ "^\\s*" block "\\s*\\{" { in_block=1; depth=1; next }
        in_block {
            for (i=1; i<=NF; i++) {
                if ($i ~ /\{/) depth++
                if ($i ~ /\}/) depth--
            }
            if (depth <= 0) { exit }
            print
        }
    ' "$file"
}

# Validate that required keys are present inside the plugin block.
validate_plugin_block() {
    local file="$1"
    local body
    body=$(extract_block "plugin:hyprglass" "$file" 2>/dev/null || true)

    if [[ -z "${body// }" ]]; then
        add_error "missing plugin:hyprglass block"
        return
    fi

    if ! grep -qE '^\s*plugin:hyprglass\s*\{' "$file" 2>/dev/null; then
        add_error "missing plugin:hyprglass block"
        return
    fi

    # Check for a matching closing brace on its own line.
    local start_line end_line
    start_line=$(grep -nE '^\s*plugin:hyprglass\s*\{' "$file" | head -1 | cut -d: -f1)
    end_line=$(awk -v start="$start_line" '
        NR == start { depth = 1; next }
        NR > start {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /\{/) depth++
                if ($i ~ /\}/) depth--
            }
            if (depth == 0 && /^\s*\}\s*$/) { print NR; exit }
        }
    ' "$file")
    if [[ -z "$end_line" ]]; then
        add_error "plugin:hyprglass block is not closed"
        return
    fi

    local assignments
    assignments=$(echo "$body" | grep -E '^\s*[a-zA-Z0-9_:]+\s*=' || true)

    for key in enabled default_theme default_preset; do
        if ! echo "$assignments" | grep -qE "^\\s*${key}\\s*="; then
            add_error "missing required field: $key"
        fi
    done

    declare -A ranges=(
        [blur_strength]="0 8"
        [blur_iterations]="1 5"
        [refraction_strength]="0 1"
        [chromatic_aberration]="0 1"
        [fresnel_strength]="0 1"
        [specular_strength]="0 1"
        [glass_opacity]="0 1"
        [edge_thickness]="0 0.15"
        [lens_distortion]="0 1"
    )

    for field in "${!ranges[@]}"; do
        local value
        value=$(echo "$assignments" | grep -E "^\\s*${field}\\s*=" | head -1 | sed -E 's/^[^=]+=[[:space:]]*//' | sed -E 's/[[:space:]]*$//' || true)
        if [[ -z "$value" ]]; then
            add_error "missing numeric field: $field"
            continue
        fi
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            add_error "$field must be numeric, got '$value'"
            continue
        fi
        local lo hi
        read -r lo hi <<< "${ranges[$field]}"
        if ! awk -v v="$value" -v lo="$lo" -v hi="$hi" 'BEGIN { exit !(v+0 >= lo && v+0 <= hi) }'; then
            add_error "$field must be between $lo and $hi, got $value"
        fi
    done
}

validate_decoration_block() {
    local file="$1"
    local body
    body=$(extract_block "decoration" "$file" 2>/dev/null || true)

    if [[ -z "${body// }" ]]; then
        add_error "missing decoration block"
        return
    fi

    local start_line end_line
    start_line=$(grep -nE '^\s*decoration\s*\{' "$file" | head -1 | cut -d: -f1)
    end_line=$(awk -v start="$start_line" '
        NR == start { depth = 1; next }
        NR > start {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /\{/) depth++
                if ($i ~ /\}/) depth--
            }
            if (depth == 0 && /^\s*\}\s*$/) { print NR; exit }
        }
    ' "$file")
    if [[ -z "$end_line" ]]; then
        add_error "decoration block is not closed"
        return
    fi

    local assignments
    assignments=$(echo "$body" | grep -E '^\s*[a-zA-Z0-9_:]+\s*=' || true)

    for field in active_opacity inactive_opacity fullscreen_opacity; do
        local value
        value=$(echo "$assignments" | grep -E "^\\s*${field}\\s*=" | head -1 | sed -E 's/^[^=]+=[[:space:]]*//' | sed -E 's/[[:space:]]*$//' || true)
        if [[ -z "$value" ]]; then
            add_error "missing decoration field: $field"
            continue
        fi
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            add_error "decoration.$field must be numeric, got '$value'"
            continue
        fi
        if ! awk -v v="$value" 'BEGIN { exit !(v+0 >= 0 && v+0 <= 1) }'; then
            add_error "decoration.$field must be between 0 and 1, got $value"
        fi
    done
}

# Known windowrule rule/action keywords (Hyprland / JaKooLit dots).
# Keep this list conservative; add more as needed.
KNOWN_WINDOWRULE_RULES=(
    animation bordercolor bordersize center dimaround float forceinput fullscreen
    idleinhibit keepaspectratio maximize monitor move nearestres noanim noblur
    noborder nodim nofocus nomaxsize noshadow opaque opacity pin pseudo
    renderunfocused rounding size suppressevent syncfullscreen tag tile unset
    windowdance workspace xray
)

is_known_windowrule_rule() {
    local rule="$1"
    local first_word
    first_word="${rule%% *}"
    local known
    for known in "${KNOWN_WINDOWRULE_RULES[@]}"; do
        [[ "$first_word" == "$known" ]] && return 0
    done
    return 1
}

validate_window_rules() {
    local file="$1"
    local line keyword rest

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(windowrule(v2)?)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            keyword="${BASH_REMATCH[1]}"
            rest="${BASH_REMATCH[3]}"

            # A window rule must contain a comma separating the matcher/rule halves.
            if [[ "$rest" != *,* ]]; then
                add_error "window rule is missing comma: $line"
                continue
            fi

            if [[ "$keyword" == "windowrule" ]]; then
                # JaKooLit/Hyprland 0.55+ syntax: windowrule = match:<matcher>, <rule>
                if [[ ! "$rest" =~ ^match: ]]; then
                    add_error "window rule missing 'match:' prefix: $line"
                    continue
                fi

                # Split at the first comma after the matcher.
                local matchers rule
                matchers="${rest%%,*}"
                rule="${rest#*,}"
                matchers="${matchers#"${matchers%%[![:space:]]*}"}"
                matchers="${matchers%"${matchers##*[![:space:]]}"}"
                rule="${rule#"${rule%%[![:space:]]*}"}"
                rule="${rule%"${rule##*[![:space:]]}"}"

                # Matcher must be non-empty and start with match:<field> <value>
                if [[ ! "$matchers" =~ ^match:[a-zA-Z_]+[[:space:]]+.+$ ]]; then
                    add_error "window rule has invalid matcher: $line"
                    continue
                fi

                if ! is_known_windowrule_rule "$rule"; then
                    add_error "window rule has unknown rule keyword after comma: $line"
                    continue
                fi
            else
                # windowrulev2 (legacy): windowrulev2 = RULE, MATCH
                local rule matchers
                rule="${rest%%,*}"
                matchers="${rest#*,}"
                rule="${rule#"${rule%%[![:space:]]*}"}"
                rule="${rule%"${rule##*[![:space:]]}"}"
                matchers="${matchers#"${matchers%%[![:space:]]*}"}"
                matchers="${matchers%"${matchers##*[![:space:]]}"}"

                if ! is_known_windowrule_rule "$rule"; then
                    add_error "windowrulev2 has no rule before comma: $line"
                    continue
                fi

                if [[ ! "$matchers" =~ ^(class|title|tag|initialTitle|initialClass|fullscreen|floating|pseudo|monitor|workspace|initialWorkspace|xwayland|initialClass): ]]; then
                    add_error "windowrulev2 has invalid matcher after comma: $line"
                    continue
                fi

                add_warning "windowrulev2 is deprecated; use windowrule = match:..., ...: $line"
            fi
        fi
    done < <(grep -E '^[[:space:]]*windowrule(v2)?[[:space:]]*=' "$file" || true)
}

# Find lines matching dark:*, light:*, or layers:* that are outside plugin:hyprglass block.
find_theme_keys_outside_plugin() {
    local file="$1"
    awk '
        /^[[:space:]]*plugin:hyprglass[[:space:]]*\{/ { in_block=1; depth=1; next }
        in_block {
            for (i=1; i<=NF; i++) {
                if ($i ~ /\{/) depth++
                if ($i ~ /\}/) depth--
            }
            if (depth <= 0) { in_block=0 }
            next
        }
        /^[[:space:]]*(dark|light|layers):/ { print }
    ' "$file"
}

validate_theme_key_location() {
    local file="$1"
    local outside
    outside=$(find_theme_keys_outside_plugin "$file")
    if [[ -n "$outside" ]]; then
        add_error "theme key found outside plugin:hyprglass block: $outside"
    fi
}

validate_plugin_block "$CONF_FILE"
validate_decoration_block "$CONF_FILE"
validate_window_rules "$CONF_FILE"
validate_theme_key_location "$CONF_FILE"

if (( ${#WARNINGS[@]} > 0 )); then
    for msg in "${WARNINGS[@]}"; do
        echo "warning: $msg" >&2
    done
fi

if (( ${#ERRORS[@]} > 0 )); then
    for msg in "${ERRORS[@]}"; do
        echo "$msg" >&2
    done
    exit 1
fi

exit 0
