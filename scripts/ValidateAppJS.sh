#!/usr/bin/env bash
#
# ValidateAppJS.sh — CI-friendly validator for src/app.js and src/bundle.js
# Usage: ./scripts/ValidateAppJS.sh
# Exit codes: 0 = valid, 1 = invalid
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_JS="${PROJECT_ROOT}/src/app.js"
BUNDLE_JS="${PROJECT_ROOT}/src/bundle.js"

ERRORS=0

log() {
    printf '%s\n' "$*"
}

error() {
    printf 'ERROR: %s\n' "$*" >&2
    ERRORS=$((ERRORS + 1))
}

run_node_check() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    log "Running node --check on $file"
    if ! node --check "$file"; then
        error "node --check failed for $file"
        return 1
    fi
    log "  OK: $file"
}

check_brace_balance() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local open_count close_count
    open_count=$(grep -oE '\{' "$file" | wc -l)
    close_count=$(grep -oE '\}' "$file" | wc -l)

    if [[ "$open_count" -ne "$close_count" ]]; then
        error "Brace mismatch in $file (open: $open_count, close: $close_count)"
        return 1
    fi

    log "  Brace balance OK: $file"
}

check_paren_balance() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local open_count close_count
    open_count=$(grep -oE '\(' "$file" | wc -l)
    close_count=$(grep -oE '\)' "$file" | wc -l)

    if [[ "$open_count" -ne "$close_count" ]]; then
        error "Parenthesis mismatch in $file (open: $open_count, close: $close_count)"
        return 1
    fi

    log "  Parenthesis balance OK: $file"
}

check_forbidden_patterns() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local found=0

    # Detect lines that look like accidental doubled closing braces: }};
    if grep -nE '\}\};' "$file" >/dev/null 2>&1; then
        error "Suspicious pattern '}};' found in $file"
        found=1
    fi

    # Detect trailing unmatched closing brace on its own without preceding open
    # This is intentionally a heuristic; node --check remains the source of truth.

    if [[ "$found" -eq 0 ]]; then
        log "  No suspicious patterns in $file"
    fi
}

main() {
    log "Validating JavaScript files in ${PROJECT_ROOT}/src"

    for target in "$APP_JS" "$BUNDLE_JS"; do
        run_node_check "$target"
        check_brace_balance "$target"
        check_paren_balance "$target"
        check_forbidden_patterns "$target"
        log ""
    done

    if [[ "$ERRORS" -gt 0 ]]; then
        log "Validation FAILED with $ERRORS error(s)."
        exit 1
    fi

    log "All JavaScript files are valid."
    exit 0
}

main "$@"
