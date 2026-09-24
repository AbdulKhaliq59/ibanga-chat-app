#!/usr/bin/env bash
#
# Builds Ibanga once and launches it side by side on iPhone 17 and iPhone 17 Pro.
#
# Usage:
#   ./scripts/run-simulators.sh            # build + launch on both
#   ./scripts/run-simulators.sh --reset    # uninstall first (fresh onboarding + new identity)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/IbangaChat.xcodeproj"
SCHEME="IbangaChat"
DERIVED_DATA="$ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/IbangaChat.app"
DEVICES=("iPhone 17" "iPhone 17 Pro")

RESET=false
[[ "${1:-}" == "--reset" ]] && RESET=true

udid_for() {
    xcrun simctl list devices available \
        | grep -E "^[[:space:]]+$1 \(" \
        | head -n 1 \
        | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true
}

UDIDS=()
for name in "${DEVICES[@]}"; do
    udid="$(udid_for "$name")"
    if [[ -z "$udid" ]]; then
        echo "✗ No available simulator named '$name'. Create it in Xcode › Window › Devices and Simulators." >&2
        exit 1
    fi
    UDIDS+=("$udid")
done

echo "▸ Building ${SCHEME}..."
mkdir -p "$ROOT/build"
BUILD_LOG="$ROOT/build/xcodebuild.log"
if ! xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=${UDIDS[0]}" \
    -derivedDataPath "$DERIVED_DATA" \
    build >"$BUILD_LOG" 2>&1; then
    grep -E "error:" "$BUILD_LOG" | sort -u >&2 || tail -n 30 "$BUILD_LOG" >&2
    echo "✗ Build failed. Full log: $BUILD_LOG" >&2
    exit 1
fi
grep -E "warning:" "$BUILD_LOG" | grep -v appintents | sort -u || true

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")"

open -a Simulator

for i in "${!DEVICES[@]}"; do
    name="${DEVICES[$i]}"
    udid="${UDIDS[$i]}"

    echo "▸ $name ($udid)"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null

    if $RESET; then
        xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
    fi

    xcrun simctl install "$udid" "$APP_PATH"
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
    echo "  ✓ launched"
done

echo "✓ Ibanga is running on: ${DEVICES[*]}"
