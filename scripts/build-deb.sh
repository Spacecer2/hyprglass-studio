#!/usr/bin/env bash
#
# Build a .deb package for HyprGlass Studio.
# Run from the repository root.
#
# shellcheck disable=SC2317

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

PKG_NAME="hyprglass-studio"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' package.json)"
ARCH="all"
MAINTAINER="Spacecer2 <https://github.com/Spacecer2>"
DESCRIPTION="Apple-style Liquid Glass effects for Hyprland"

BUILD_DIR="/tmp/${PKG_NAME}-deb-build"
DEBIAN_DIR="${BUILD_DIR}/DEBIAN"

cleanup() {
    rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${DEBIAN_DIR}"

# Install project files into the staging area
make DESTDIR="${BUILD_DIR}" PREFIX=/usr install

# Write Debian control file
cat > "${DEBIAN_DIR}/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: x11
Priority: optional
Architecture: ${ARCH}
Depends: hyprland (>= 0.55), python3 (>= 3.10), python3-websockets, python3-aiohttp, python3-aiofiles, python3-yaml, jq
Recommends: wallust
Suggests: grim, slurp
Maintainer: ${MAINTAINER}
Description: ${DESCRIPTION}
 HyprGlass Studio brings translucent, depth-aware glass effects to
 the Hyprland Wayland compositor. It includes a web-based Studio UI
 for tuning blur, opacity, tint, and profiles in real time.
EOF

# Optional postinst script to run the local installer for the current user
# when the package is installed. Disabled by default to keep the package
# non-interactive; uncomment the block below to enable it.
#
# cat > "${DEBIAN_DIR}/postinst" <<'EOF'
# #!/bin/sh
# set -e
# if [ "$1" = "configure" ]; then
#     echo "Run 'hyprglass-studio' or '/usr/share/hyprglass-studio/install.sh' to finish setup."
# fi
# EOF
# chmod 755 "${DEBIAN_DIR}/postinst"

mkdir -p "${REPO_ROOT}/dist"
DEB_FILE="${REPO_ROOT}/dist/${PKG_NAME}_${VERSION}_${ARCH}.deb"

dpkg-deb --build "${BUILD_DIR}" "${DEB_FILE}"

echo "Built: ${DEB_FILE}"
