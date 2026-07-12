#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# MigrateHyprglassConfig.sh
# Detects outdated HyprGlass Studio config formats and migrates them to the
# current format. Backs up the originals and reports every change.
#
# Usage:
#   MigrateHyprglassConfig.sh [--dry-run] [--config-dir DIR] [--yes]
#
# Defaults:
#   Config dir: ~/.config/hypr
#   Profiles dir: ~/.config/hypr/hyprglass-profiles
#

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
HYPR_DIR="${HOME}/.config/hypr"
USER_CONFIGS_DIR="${HYPR_DIR}/UserConfigs"
PROFILES_DIR="${HYPR_DIR}/hyprglass-profiles"

HYPGLASS_CONF_NAME="Hyprglass.conf"
HYPGLASS_CONF_DEST="${USER_CONFIGS_DIR}/${HYPGLASS_CONF_NAME}"

BACKUP_DIR="${HYPR_DIR}/backups/hyprglass-migrate-$(date +%Y%m%d-%H%M%S)"

# ── Options ──────────────────────────────────────────────────────────────────
DRY_RUN=false
AUTO_YES=false
VERBOSE=false

# ── State ────────────────────────────────────────────────────────────────────
CHANGED_FILES=()
REPORT_LINES=()
MIGRATION_NEEDED=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────────────────────
log()   { printf '%b[INFO]%b  %s\n' "$CYAN" "$RESET" "$*"; }
ok()    { printf '%b[ OK ]%b  %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%b[WARN]%b  %s\n' "$YELLOW" "$RESET" "$*"; }
err()   { printf '%b[ERR ]%b  %s\n' "$RED" "$RESET" "$*" >&2; }
fatal() { err "$*"; exit 1; }
dry()   { printf '%b[DRY]%b  %s\n' "$MAGENTA" "$RESET" "$*"; }
verb()  { $VERBOSE && printf '%b[DBG ]%b  %s\n' "$DIM" "$RESET" "$*" || true; }

# ── Help text ────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}HyprGlass Studio Config Migration Tool${RESET}

${BOLD}USAGE${RESET}
    $0 [OPTIONS]

${BOLD}OPTIONS${RESET}
    ${BOLD}--dry-run${RESET}        Preview changes without writing files
    ${BOLD}--config-dir DIR${RESET} Use DIR instead of ~/.config/hypr
    ${BOLD}--yes, -y${RESET}        Skip confirmation prompts
    ${BOLD}--verbose, -v${RESET}    Print extra debug information
    ${BOLD}--help, -h${RESET}       Show this help message and exit

${BOLD}DESCRIPTION${RESET}
    Scans Hyprglass.conf and profile .conf files for legacy syntax, backs
    them up, rewrites them in the current format, and prints a report.

    Legacy signs this tool detects:
      • Main config without a plugin:hyprglass { ... } block
      • Theme overrides inside the plugin block instead of top-level
      • Flat glass keys (blur_strength = ...) instead of \$glass.blur_strength
      • Profiles missing \$version or \$metadata fields
      • Window rules using old opacity syntax instead of tags

EOF
    exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)      DRY_RUN=true ;;
            --config-dir)   HYPR_DIR="$2"; shift ;;
            --yes|-y)       AUTO_YES=true ;;
            --verbose|-v)   VERBOSE=true ;;
            --help|-h)      show_help ;;
            *) fatal "Unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done

    # Re-derive dependent paths after possible --config-dir
    USER_CONFIGS_DIR="${HYPR_DIR}/UserConfigs"
    PROFILES_DIR="${HYPR_DIR}/hyprglass-profiles"
    HYPGLASS_CONF_DEST="${USER_CONFIGS_DIR}/${HYPGLASS_CONF_NAME}"

    # Prevent path traversal: the migration tool must only touch paths under HOME.
    local home_trailing
    home_trailing="$HOME"
    [[ "$home_trailing" != / ]] && home_trailing="${home_trailing%/}/"
    if [[ "$HYPR_DIR" != "$HOME" && "$HYPR_DIR" != "$home_trailing"* ]]; then
        fatal "--config-dir must be under \$HOME (refusing to migrate: $HYPR_DIR)"
    fi
}

# ── Backup helpers ───────────────────────────────────────────────────────────
backup_file() {
    local src="$1"
    if [[ ! -e "$src" ]]; then
        return 0
    fi

    if $DRY_RUN; then
        dry "Would back up: ${src} -> ${BACKUP_DIR}/$(basename "$src")"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    cp -a "$src" "${BACKUP_DIR}/$(basename "$src")" 2>/dev/null || true
}

# ── Reporting ────────────────────────────────────────────────────────────────
report_change() {
    local file="$1"
    local change="$2"
    MIGRATION_NEEDED=true
    REPORT_LINES+=("${file}: ${change}")
}

print_report() {
    echo ""
    if ! $MIGRATION_NEEDED; then
        ok "No migration needed — all configs are already in the current format."
        return
    fi

    printf '%bMigration report:%b\n' "$BOLD" "$RESET"
    echo "  Backups saved to: ${BACKUP_DIR}"
    echo ""
    for line in "${REPORT_LINES[@]}"; do
        echo "  • ${line}"
    done
    echo ""

    if $DRY_RUN; then
        warn "Dry run complete — no files were modified."
    else
        ok "Migration complete."
    fi
}

# ── Confirmation ─────────────────────────────────────────────────────────────
confirm() {
    if $AUTO_YES; then
        return 0
    fi
    local prompt="${1:-Continue?}"
    printf '%b%s [Y/n]%b ' "$BOLD" "$prompt" "$RESET"
    local answer
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# ── Main config migration ────────────────────────────────────────────────────
# Reads the existing Hyprglass.conf, normalizes it to the current documented
# format, and writes it back. Returns 0 if changes were made.
migrate_main_config() {
    local src="$1"
    local tmp
    tmp=$(mktemp -p "$(dirname "$src")")
    chmod 600 "$tmp"
    local changed=false

    verb "Analyzing ${src}"

    # Detection: does the file contain a plugin:hyprglass block?
    if ! grep -qE '^\s*plugin:hyprglass\s*\{' "$src" 2>/dev/null; then
        report_change "$src" "missing plugin:hyprglass block"
        changed=true
    fi

    # Detection: theme overrides inside the plugin block (old UI export format)
    if awk '/plugin:hyprglass *\{/,/^\s*\}/' "$src" 2>/dev/null | grep -qE '^\s*(dark|light):[a-z_]+\s*='; then
        report_change "$src" "theme overrides inside plugin block (should be top-level)"
        changed=true
    fi

    # Detection: missing layer settings
    if ! grep -qE '^\s*layers:enabled\s*=' "$src" 2>/dev/null; then
        report_change "$src" "missing layers:* settings"
        changed=true
    fi

    # Detection: legacy windowrulev2 syntax (current format uses windowrule = match:)
    if grep -qE '^\s*windowrulev2\s*=' "$src" 2>/dev/null; then
        report_change "$src" "windowrulev2 syntax (use match: instead)"
        changed=true
    fi

    if ! $changed; then
        verb "${src} is already in current format"
        rm -f "$tmp"
        return 1
    fi

    if $DRY_RUN; then
        dry "Would migrate: ${src}"
        rm -f "$tmp"
        return 0
    fi

    backup_file "$src"

    # Extract values using a best-effort parser. We support both old inline
    # format and current block format.
    python3 - "$src" "$tmp" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

# Defaults for the current documented format
plugin_defaults = {
    "enabled": "1",
    "default_theme": "dark",
    "default_preset": "default",
    "blur_strength": "2.0",
    "blur_iterations": "3",
    "refraction_strength": "0.6",
    "chromatic_aberration": "0.5",
    "fresnel_strength": "0.6",
    "specular_strength": "0.8",
    "glass_opacity": "1.0",
    "edge_thickness": "0.06",
    "lens_distortion": "0.5",
    "tint_color": "0x8899aa22",
}

theme_defaults = {
    "dark": {
        "brightness": "0.8192",
        "contrast": "0.8914",
        "saturation": "1.1911",
        "vibrancy": "0.369",
        "vibrancy_darkness": "0.6918",
        "adaptive_dim": "0.0",
        "adaptive_boost": "0.0",
    },
    "light": {
        "brightness": "1.0",
        "contrast": "1.0",
        "saturation": "1.0",
        "vibrancy": "0.2",
        "vibrancy_darkness": "0.3",
        "adaptive_dim": "0.0",
        "adaptive_boost": "0.0",
    },
}

layers_defaults = {
    "enabled": "1",
    "namespaces": "layer:surface",
    "exclude_namespaces": "layer:notifications",
    "preset": "default",
    "namespace_presets": "layer:surface=glass",
    "namespace_mask_thresholds": "layer:surface:0.3",
}

decoration_defaults = {
    "active_opacity": "0.75",
    "inactive_opacity": "0.65",
}

if not src.exists():
    text = ""
else:
    text = src.read_text(encoding="utf-8", errors="replace")

# Remove comments and blank lines for parsing, but keep originals for value extraction
def parse_block(name, text):
    """Extract key = value pairs from a block like 'name { ... }'."""
    pattern = re.compile(rf"^\s*{re.escape(name)}\s*\{{.*?^\s*\}}", re.MULTILINE | re.DOTALL)
    match = pattern.search(text)
    if not match:
        return {}
    block = match.group(0)
    values = {}
    for line in block.splitlines():
        m = re.match(r"^\s*([a-zA-Z0-9_:.]+)\s*=\s*(.+?)\s*$", line)
        if m:
            key, value = m.group(1), m.group(2)
            # strip inline comments
            value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
            values[key] = value
    return values

def parse_toplevel(text):
    """Extract top-level key = value assignments outside any block."""
    values = {}
    for line in text.splitlines():
        if re.search(r"\{|\}", line):
            continue
        m = re.match(r"^\s*([a-zA-Z0-9_:.]+)\s*=\s*(.+?)\s*$", line)
        if m:
            key, value = m.group(1), m.group(2)
            value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
            values[key] = value
    return values

# Parse existing values
plugin_values = parse_block("plugin:hyprglass", text)
toplevel_values = parse_toplevel(text)
decoration_values = parse_block("decoration", text)

# Theme values may be inside plugin block (old format) or top-level (current)
theme_values = {"dark": {}, "light": {}}
for theme in ("dark", "light"):
    for key in theme_defaults[theme]:
        # Current documented location: top-level dark:key / light:key
        if f"{theme}:{key}" in toplevel_values:
            theme_values[theme][key] = toplevel_values[f"{theme}:{key}"]
        # Old UI-export location: inside plugin block
        elif f"{theme}:{key}" in plugin_values:
            theme_values[theme][key] = plugin_values[f"{theme}:{key}"]

# Layer values may be inside plugin block or top-level
layers_values = {}
for key in layers_defaults:
    if f"layers:{key}" in toplevel_values:
        layers_values[key] = toplevel_values[f"layers:{key}"]
    elif f"layers:{key}" in plugin_values:
        layers_values[key] = plugin_values[f"layers:{key}"]

# Merge defaults with extracted values
def merge(defaults, extracted):
    result = dict(defaults)
    result.update({k: v for k, v in extracted.items() if k in defaults})
    return result

plugin_final = merge(plugin_defaults, plugin_values)
theme_final = {t: merge(theme_defaults[t], theme_values[t]) for t in theme_defaults}
layers_final = merge(layers_defaults, layers_values)
decoration_final = merge(decoration_defaults, decoration_values)

# Window rules: keep current 'windowrule = match:..., action' syntax and migrate
# legacy 'windowrulev2 = action, condition' lines to it.
window_rules = []
for line in text.splitlines():
    if re.match(r"^\s*windowrule\s*=\s*match:", line):
        # Already in current format; preserve as-is.
        window_rules.append(line.strip())
    else:
        m = re.match(r"^\s*windowrulev2\s*=\s*(.+?)\s*,\s*(.+?)\s*$", line)
        if m:
            action, match_expr = m.group(1), m.group(2)
            # Normalize Hyprland v2 condition syntax to project match syntax:
            # class:^(foo)$ -> class ^(foo)$ ; tag:foo -> tag foo
            match_expr = re.sub(r'\bclass:\s*', 'class ', match_expr)
            match_expr = re.sub(r'\btag:\s*', 'tag ', match_expr)
            window_rules.append(f"windowrule = match:{match_expr}, {action}")

# Build output in current documented format
out = []
out.append("# ─── HyprGlass Studio Configuration ─────────────────────────────────────")
out.append("# Migrated by MigrateHyprglassConfig.sh")
out.append("")
out.append("plugin:hyprglass {")
for key, value in plugin_final.items():
    out.append(f"    {key} = {value}")
out.append("}")
out.append("")
out.append("# ─── Dark Theme ─────────────────────────────────────────────────────────")
for key, value in theme_final["dark"].items():
    out.append(f"dark:{key} = {value}")
out.append("")
out.append("# ─── Light Theme ────────────────────────────────────────────────────────")
for key, value in theme_final["light"].items():
    out.append(f"light:{key} = {value}")
out.append("")
out.append("# ─── Layer Settings ─────────────────────────────────────────────────────")
for key, value in layers_final.items():
    out.append(f"layers:{key} = {value}")
out.append("")
out.append("# ─── Decoration Overrides ───────────────────────────────────────────────")
out.append("decoration {")
for key, value in decoration_final.items():
    out.append(f"    {key} = {value}")
out.append("}")
out.append("")
out.append("# ─── Window Rules ───────────────────────────────────────────────────────")
if window_rules:
    out.extend(window_rules)
else:
    out.append("windowrule = match:class ^(firefox)$, tag +hyprglass_disabled")
    out.append("windowrule = match:class ^(kitty)$, tag +hyprglass_preset_subtle")
    out.append("windowrule = match:class ^(thunar)$, tag +hyprglass_enabled")
out.append("")
out.append("# ─── Wallust Color Sync (optional) ──────────────────────────────────────")
out.append("# If wallust is installed, these variables are updated by the wallust hook.")
out.append("# $tint_color = rgb(aa88ff)")
out.append("")

dst.write_text("\n".join(out), encoding="utf-8")
PY

    mv "$tmp" "$src"
    ok "Migrated ${src}"
    return 0
}

# ── Profile migration ────────────────────────────────────────────────────────
# Profiles use Hyprland-style variable assignments with namespaced keys:
#   $name, $version, $inherits
#   $metadata.author, $metadata.description
#   $glass.blur_strength, $theme.dark.brightness, etc.
migrate_profile() {
    local src="$1"
    local name
    name=$(basename "$src" .conf)
    local tmp
    tmp=$(mktemp -p "$(dirname "$src")")
    chmod 600 "$tmp"
    local changed=false

    verb "Analyzing profile ${src}"

    # Detection 1: missing $version
    if ! grep -qE '^\s*\$version\s*=' "$src" 2>/dev/null; then
        report_change "$src" "missing \$version field"
        changed=true
    fi

    # Detection 2: missing $metadata fields
    if ! grep -qE '^\s*\$metadata\.author\s*=' "$src" 2>/dev/null; then
        report_change "$src" "missing \$metadata fields"
        changed=true
    fi

    # Detection 3: flat glass/theme/decoration/window_rules keys (old v0.x format)
    if grep -qE '^\s*(blur_strength|refraction_strength|brightness|active_opacity)\s*=' "$src" 2>/dev/null; then
        report_change "$src" "flat parameter keys (not namespaced)"
        changed=true
    fi

    # Detection 4: old-style window rule block instead of namespaced rules
    if grep -qE '^\s*\$rules\.' "$src" 2>/dev/null; then
        report_change "$src" "old \$rules.* namespace (renamed to \$window_rules.*)"
        changed=true
    fi

    if ! $changed; then
        verb "Profile ${src} is already in current format"
        rm -f "$tmp"
        return 1
    fi

    if $DRY_RUN; then
        dry "Would migrate profile: ${src}"
        rm -f "$tmp"
        return 0
    fi

    backup_file "$src"

    python3 - "$src" "$tmp" "$name" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
profile_name = sys.argv[3]

text = src.read_text(encoding="utf-8", errors="replace") if src.exists() else ""

# Extract simple $key = value assignments
def parse_vars(text, prefix=None):
    values = {}
    for line in text.splitlines():
        m = re.match(r"^\s*\$([a-zA-Z0-9_.:]+)\s*=\s*(.*?)\s*$", line)
        if not m:
            continue
        key, value = m.group(1), m.group(2)
        value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
        if prefix is None or key.startswith(prefix):
            values[key] = value
    return values

all_vars = parse_vars(text)

# Profile identity defaults
identity = {
    "name": all_vars.get("name", profile_name),
    "version": all_vars.get("version", "1.0.0"),
    "inherits": all_vars.get("inherits", ""),
}

metadata = {
    "author": all_vars.get("metadata.author", "HyprGlass Studio"),
    "description": all_vars.get("metadata.description", f"Migrated {profile_name} profile"),
}

# Glass settings: prefer $glass.*, fall back to flat keys
glass_keys = [
    "blur_strength", "blur_iterations", "refraction_strength",
    "chromatic_aberration", "fresnel_strength", "specular_strength",
    "glass_opacity", "edge_thickness", "lens_distortion",
]
glass_defaults = {
    "blur_strength": "3.4",
    "blur_iterations": "2",
    "refraction_strength": "0.96",
    "chromatic_aberration": "0.7",
    "fresnel_strength": "0.96",
    "specular_strength": "0.6",
    "glass_opacity": "1.0",
    "edge_thickness": "0.14",
    "lens_distortion": "0.42",
}
glass = {}
for key in glass_keys:
    if f"glass.{key}" in all_vars:
        glass[key] = all_vars[f"glass.{key}"]
    elif key in all_vars:
        glass[key] = all_vars[key]
    else:
        glass[key] = glass_defaults[key]

# Theme settings: prefer $theme.dark.*, fall back to flat dark:* or dark_ keys
theme_keys = ["brightness", "contrast", "saturation", "vibrancy", "vibrancy_darkness", "adaptive_dim", "adaptive_boost"]
theme_defaults = {
    "brightness": "1.1",
    "contrast": "1.2",
    "saturation": "1.15",
    "vibrancy": "0.7",
    "vibrancy_darkness": "0.52",
    "adaptive_dim": "0.65",
    "adaptive_boost": "0.34",
}
theme = {"dark": {}}
for key in theme_keys:
    if f"theme.dark.{key}" in all_vars:
        theme["dark"][key] = all_vars[f"theme.dark.{key}"]
    elif f"dark.{key}" in all_vars:
        theme["dark"][key] = all_vars[f"dark.{key}"]
    elif f"dark_{key}" in all_vars:
        theme["dark"][key] = all_vars[f"dark_{key}"]
    elif key in all_vars:
        theme["dark"][key] = all_vars[key]
    else:
        theme["dark"][key] = theme_defaults[key]

# Decoration settings
decoration_defaults = {
    "active_opacity": "0.75",
    "inactive_opacity": "0.65",
}
decoration = {}
for key in decoration_defaults:
    if f"decoration.{key}" in all_vars:
        decoration[key] = all_vars[f"decoration.{key}"]
    elif key in all_vars:
        decoration[key] = all_vars[key]
    else:
        decoration[key] = decoration_defaults[key]

# Window rules: gather all $window_rules.* / $rules.* entries. We preserve the
# existing structure as much as possible and only rename the namespace.
rule_vars = {}
for key, value in all_vars.items():
    if key.startswith("window_rules."):
        rule_vars[key] = value
    elif key.startswith("rules."):
        new_key = "window_rules." + key[len("rules."):]
        rule_vars[new_key] = value

# Fallback window rules if none exist
if not rule_vars:
    rule_vars = {
        "fullscreen.match": "class:^(.*)$,fullscreen:1",
        "fullscreen.action": "disable",
        "fullscreen.reason": "Fullscreen windows - glass disabled for unobstructed view",
        "games.match": "class:^steam_app_.+$",
        "games.action": "disable",
        "games.reason": "Games - glass disabled for performance and compatibility",
        "video_players.match": "class:^(mpv|vlc|celluloid)$",
        "video_players.action": "minimal",
        "video_players.reason": "Video players - minimal glass to preserve video clarity",
        "fallback.action": "default",
        "fallback.reason": "All other windows use the profile defaults",
    }

# Build output
out = []
out.append(f"# HyprGlass Studio profile")
out.append(f"# Migrated by MigrateHyprglassConfig.sh")
out.append("")
out.append("# Profile identity")
out.append(f"$name = {identity['name']}")
out.append(f"$version = {identity['version']}")
out.append(f"$inherits = {identity['inherits']}")
out.append("")
out.append("# Metadata")
out.append(f"$metadata.author = {metadata['author']}")
out.append(f"$metadata.description = {metadata['description']}")
out.append("")
out.append("# Glass effect settings")
for key in glass_keys:
    out.append(f"$glass.{key} = {glass[key]}")
out.append("")
out.append("# Theme settings")
for key in theme_keys:
    out.append(f"$theme.dark.{key} = {theme['dark'][key]}")
out.append("")
out.append("# Decoration settings")
for key in decoration_defaults:
    out.append(f"$decoration.{key} = {decoration[key]}")
out.append("")
out.append("# Window rules")
# Group rules by prefix
rules_by_name = {}
for key, value in rule_vars.items():
    if "." not in key:
        continue
    name, field = key.split(".", 1)
    rules_by_name.setdefault(name, {})[field] = value

# Print known rule groups first, then any extras
order = ["fullscreen", "games", "video_players", "browsers", "terminals", "ides", "fallback"]
printed = set()
for name in order:
    if name in rules_by_name:
        for field in ("match", "action", "reason"):
            if field in rules_by_name[name]:
                out.append(f"$window_rules.{name}.{field} = {rules_by_name[name][field]}")
        for field in sorted(rules_by_name[name]):
            if field.startswith("overrides."):
                out.append(f"$window_rules.{name}.{field} = {rules_by_name[name][field]}")
        printed.add(name)

for name in sorted(rules_by_name):
    if name in printed:
        continue
    for field in sorted(rules_by_name[name]):
        out.append(f"$window_rules.{name}.{field} = {rules_by_name[name][field]}")

out.append("")
dst.write_text("\n".join(out), encoding="utf-8")
PY

    mv "$tmp" "$src"
    ok "Migrated profile ${src}"
    return 0
}

# ── Scan all configs ─────────────────────────────────────────────────────────
scan_and_migrate() {
    # Main config
    if [[ -f "$HYPGLASS_CONF_DEST" ]]; then
        if migrate_main_config "$HYPGLASS_CONF_DEST"; then
            CHANGED_FILES+=("$HYPGLASS_CONF_DEST")
        fi
    else
        warn "Main config not found: ${HYPGLASS_CONF_DEST}"
    fi

    # Profiles
    if [[ -d "$PROFILES_DIR" ]]; then
        local profile
        for profile in "$PROFILES_DIR"/*.conf; do
            [[ -f "$profile" ]] || continue
            if migrate_profile "$profile"; then
                CHANGED_FILES+=("$profile")
            fi
        done
    else
        warn "Profile directory not found: ${PROFILES_DIR}"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    echo ""
    printf '%bHyprGlass Studio Config Migration Tool%b\n' "$BOLD" "$RESET"
    if $DRY_RUN; then
        printf '%b  ── DRY RUN MODE ──%b\n' "$YELLOW" "$RESET"
    fi
    echo "────────────────────────────────────────────────────────────"
    echo ""

    if ! command -v python3 &>/dev/null; then
        fatal "python3 is required for config migration"
    fi

    log "Config directory: ${HYPR_DIR}"
    log "Profiles directory: ${PROFILES_DIR}"
    echo ""

    scan_and_migrate

    print_report

    if $MIGRATION_NEEDED && ! $DRY_RUN && ! $AUTO_YES; then
        echo ""
        if confirm "Reload Hyprland to apply migrated config?"; then
            if command -v hyprctl &>/dev/null; then
                hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed"
            else
                warn "hyprctl not found; reload Hyprland manually"
            fi
        fi
    fi
}

main "$@"
