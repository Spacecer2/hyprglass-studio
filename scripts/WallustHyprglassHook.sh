#!/bin/bash

# Wallust hook for HyprGlass Studio
# Updates hyprglass tint color based on wallpaper colors

# Read wallust-hyprland.conf
WALLUST_CONF="$HOME/.config/hypr/wallust/wallust-hyprland.conf"

if [ ! -f "$WALLUST_CONF" ]; then
    echo "Error: wallust-hyprland.conf not found"
    exit 1
fi

# Extract $color12 (accent) and $background
color12=$(grep -E '^\$color12' "$WALLUST_CONF" | cut -d'=' -f2 | tr -d ' ')
background=$(grep -E '^\$background' "$WALLUST_CONF" | cut -d'=' -f2 | tr -d ' ')

if [ -z "$color12" ] || [ -z "$background" ]; then
    echo "Error: Could not extract colors from wallust config"
    exit 1
fi

# Remove alpha channel from color12 for tint_color (take first 6 chars after 0x)
color12_hex=$(echo "$color12" | sed 's/^0x//' | cut -c1-6)

# Generate tint_color: 0x99 + color12_hex
tint_color="0x99${color12_hex}"

# Calculate brightness from background color (0-1 scale)
# Extract RGB components (assuming 0xAARRGGBB format)
bg_hex=$(echo "$background" | sed 's/^0x//')
bg_r=$((16#${bg_hex:2:2}))
bg_g=$((16#${bg_hex:4:2}))
bg_b=$((16#${bg_hex:6:2}))

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
cat > "$CACHE_DIR/.hyprglass_wallust.json" << EOF
{
  "tint_color": "$tint_color",
  "brightness": "$brightness_setting",
  "wallpaper_brightness_pct": $brightness_pct,
  "color12": "$color12",
  "background": "$background"
}
EOF

# Send notification
notify-send "HyprGlass colors updated from wallpaper"

echo "HyprGlass updated: tint=$tint_color, brightness=$brightness_setting (wallpaper: ${brightness_pct}%)"
