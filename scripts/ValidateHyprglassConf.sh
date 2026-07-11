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

warn() {
    ERRORS+=("$1")
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
        warn "missing plugin:hyprglass block"
        return
    fi

    if ! grep -qE '^\s*plugin:hyprglass\s*\{' "$file" 2>/dev/null; then
        warn "missing plugin:hyprglass block"
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
        warn "plugin:hyprglass block is not closed"
        return
    fi

    local assignments
    assignments=$(echo "$body" | grep -E '^\s*[a-zA-Z0-9_:]+\s*=' || true)

    for key in enabled default_theme default_preset; do
        if ! echo "$assignments" | grep -qE "^\\s*${key}\\s*="; then
            warn "missing required field: $key"
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
            warn "missing numeric field: $field"
            continue
        fi
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            warn "$field must be numeric, got '$value'"
            continue
        fi
        local lo hi
        read -r lo hi <<< "${ranges[$field]}"
        if ! awk -v v="$value" -v lo="$lo" -v hi="$hi" 'BEGIN { exit !(v+0 >= lo && v+0 <= hi) }'; then
            warn "$field must be between $lo and $hi, got $value"
        fi
    done
}

validate_decoration_block() {
    local file="$1"
    local body
    body=$(extract_block "decoration" "$file" 2>/dev/null || true)

    if [[ -z "${body// }" ]]; then
        warn "missing decoration block"
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
        warn "decoration block is not closed"
        return
    fi

    local assignments
    assignments=$(echo "$body" | grep -E '^\s*[a-zA-Z0-9_:]+\s*=' || true)

    for field in active_opacity inactive_opacity fullscreen_opacity; do
        local value
        value=$(echo "$assignments" | grep -E "^\\s*${field}\\s*=" | head -1 | sed -E 's/^[^=]+=[[:space:]]*//' | sed -E 's/[[:space:]]*$//' || true)
        if [[ -z "$value" ]]; then
            warn "missing decoration field: $field"
            continue
        fi
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            warn "decoration.$field must be numeric, got '$value'"
            continue
        fi
        if ! awk -v v="$value" 'BEGIN { exit !(v+0 >= 0 && v+0 <= 1) }'; then
            warn "decoration.$field must be between 0 and 1, got $value"
        fi
    done
}

validate_plugin_block "$CONF_FILE"
validate_decoration_block "$CONF_FILE"

if (( ${#ERRORS[@]} > 0 )); then
    for msg in "${ERRORS[@]}"; do
        echo "$msg" >&2
    done
    exit 1
fi

exit 0
