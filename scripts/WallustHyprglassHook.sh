#!/bin/bash
# shellcheck disable=SC2016

# Wallust hook for HyprGlass Studio
# Updates hyprglass tint color based on wallpaper colors

set -euo pipefail

# Read wallust-hyprland.conf
WALLUST_CONF="$HOME/.config/hypr/wallust/wallust-hyprland.conf"

if [ ! -f "$WALLUST_CONF" ]; then
    echo "Error: wallust-hyprland.conf not found"
    exit 1
fi

# Extract $color12 (accent) and $background
color12=$(grep -E '^\$color12' "$WALLUST_CONF" | cut -d'=' -f2 | tr -d ' ' || true)
background=$(grep -E '^\$background' "$WALLUST_CONF" | cut -d'=' -f2 | tr -d ' ' || true)

if [ -z "$color12" ] || [ -z "$background" ]; then
    echo "Error: Could not extract colors from wallust config"
    exit 1
fi

# Normalize supported color formats to a 6-digit lowercase hex string.
# Accepted inputs: #RRGGBB, rgb(RRGGBB), 0xAARRGGBB, 0xRRGGBB, RRGGBB.
# Returns 1 for malformed or unsupported values.
normalize_hex() {
    local color="$1"
    local hex

    # Strip surrounding whitespace.
    color=$(printf '%s' "$color" | tr -d '[:space:]')

    case "$color" in
        \#*)
            hex=${color#"#"}
            ;;
        [Rr][Gg][Bb]\(*\))
            hex=${color#*\(}
            hex=${hex%)}
            ;;
        0[xX]*)
            hex=${color#0x}
            hex=${hex#0X}
            # 0xAARRGGBB -> drop alpha channel.
            if [ "${#hex}" -eq 8 ]; then
                hex=${hex:2:6}
            fi
            ;;
        *)
            # Raw hex; treat 8-char values as AARRGGBB.
            hex=$color
            if [ "${#hex}" -eq 8 ]; then
                hex=${hex:2:6}
            fi
            ;;
    esac

    # Validate: exactly six hexadecimal characters.
    if ! [[ "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
        return 1
    fi

    printf '%s' "$hex" | tr '[:upper:]' '[:lower:]'
}

color12_hex=$(normalize_hex "$color12") || {
    echo "Error: Invalid color12 value: $color12"
    exit 1
}
background_hex=$(normalize_hex "$background") || {
    echo "Error: Invalid background value: $background"
    exit 1
}

# Generate tint_color: 0x99 + color12_hex
tint_color="0x99${color12_hex}"

# Calculate brightness from background color (0-1 scale)
bg_r=$((16#${background_hex:0:2}))
bg_g=$((16#${background_hex:2:2}))
bg_b=$((16#${background_hex:4:2}))

# Calculate perceived brightness (0-255 scale, then normalize)
brightness=$(( (bg_r * 299 + bg_g * 587 + bg_b * 114) / 1000 ))
brightness_pct=$((brightness * 100 / 255))

# Determine brightness setting based on wallpaper brightness
if [ "$brightness_pct" -lt 20 ]; then
    brightness_setting="1.2"
elif [ "$brightness_pct" -lt 50 ]; then
    brightness_setting="1.0"
else
    brightness_setting="0.8"
fi

# Apply hyprglass settings
hyprctl keyword plugin:hyprglass:tint_color "$tint_color" 2>/dev/null
hyprctl keyword plugin:hyprglass:dark:brightness "$brightness_setting" 2>/dev/null

# Save values to cache
CACHE_DIR="$HOME/.cache"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/.hyprglass_wallust.json"
cat > "$CACHE_FILE" << EOF
{
  "tint_color": "$tint_color",
  "brightness": "$brightness_setting",
  "wallpaper_brightness_pct": $brightness_pct,
  "color12": "$color12",
  "background": "$background"
}
EOF
chmod 600 "$CACHE_FILE"

# Send notification
notify-send "HyprGlass colors updated from wallpaper"

echo "HyprGlass updated: tint=$tint_color, brightness=$brightness_setting (wallpaper: ${brightness_pct}%)"
