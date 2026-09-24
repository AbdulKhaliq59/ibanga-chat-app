#!/usr/bin/env bash
#
# Regenerates the app icon (light, dark and tinted) from IbangaLogoShape.
# Usage: ./scripts/generate-app-icon.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/IbangaChat/Assets.xcassets/AppIcon.appiconset"
BUILD_DIR="$ROOT/build/icon"
mkdir -p "$BUILD_DIR"

xcrun swiftc -O -parse-as-library \
    "$ROOT/scripts/icon/AppIconRenderer.swift" \
    "$ROOT/IbangaChat/Core/DesignSystem/IbangaLogo.swift" \
    -o "$BUILD_DIR/render-icon"

"$BUILD_DIR/render-icon" "$ICONSET"
