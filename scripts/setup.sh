#!/usr/bin/env bash
#
# One-time setup for Ibanga Chat on a new Mac.
#
# Checks every prerequisite, fixes what it safely can (asking first), creates the
# two simulators used for the demo, and verifies that the project builds.
#
# Usage:
#   ./scripts/setup.sh          # interactive: asks before anything that needs sudo or a download
#   ./scripts/setup.sh --yes    # non-interactive: accepts every fix automatically
#
# Simulators can be changed with, for example:
#   IBANGA_SIMULATORS="iPhone 16,iPhone 16 Pro" ./scripts/setup.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/IbangaChat.xcodeproj"
SCHEME="IbangaChat"
DERIVED_DATA="$ROOT/build/DerivedData"
BUILD_LOG="$ROOT/build/setup-build.log"

MINIMUM_MACOS="15.6"
MINIMUM_XCODE="26.4"
IFS=',' read -r -a SIMULATORS <<< "${IBANGA_SIMULATORS:-iPhone 17,iPhone 17 Pro}"

AUTO_YES=false
[[ "${1:-}" == "--yes" ]] && AUTO_YES=true

# MARK: Output helpers

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'

step() { printf "\n%s▸ %s%s\n" "$bold" "$1" "$reset"; }
ok()   { printf "  %s✓%s %s\n" "$green" "$reset" "$1"; }
note() { printf "  %s!%s %s\n" "$yellow" "$reset" "$1"; }
fail() {
    printf "  %s✗ %s%s\n" "$red" "$1" "$reset" >&2
    shift
    for line in "$@"; do printf "    → %s\n" "$line" >&2; done
    exit 1
}

confirm() {
    $AUTO_YES && return 0
    local reply
    read -r -p "    $1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Returns success when $1 >= $2 (dotted versions such as 26.4 or 15.6.1).
version_at_least() {
    local IFS=.
    local -a have=($1) need=($2)
    for i in 0 1 2; do
        local h=${have[i]:-0} n=${need[i]:-0}
        ((h > n)) && return 0
        ((h < n)) && return 1
    done
    return 0
}

# MARK: 1. macOS

step "Checking macOS"
[[ "$(uname)" == "Darwin" ]] || fail "Ibanga Chat can only be built on macOS."
MACOS_VERSION="$(sw_vers -productVersion)"
version_at_least "$MACOS_VERSION" "$MINIMUM_MACOS" \
    || fail "macOS $MACOS_VERSION is too old." "Xcode $MINIMUM_XCODE requires macOS $MINIMUM_MACOS or later. Update via System Settings › General › Software Update."
ok "macOS $MACOS_VERSION"

# MARK: 2. Xcode

step "Checking Xcode"
if ! DEVELOPER_DIR_PATH="$(xcode-select -p 2>/dev/null)"; then
    fail "Xcode is not installed." \
        "Install Xcode $MINIMUM_XCODE or later from the Mac App Store or https://developer.apple.com/xcode/" \
        "Then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
fi
if [[ "$DEVELOPER_DIR_PATH" == *CommandLineTools* ]]; then
    fail "Only the Command Line Tools are selected, but the full Xcode app is required." \
        "Install Xcode from the Mac App Store, then run:" \
        "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
fi

XCODE_VERSION="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
version_at_least "$XCODE_VERSION" "$MINIMUM_XCODE" \
    || fail "Xcode $XCODE_VERSION is too old." "Install Xcode $MINIMUM_XCODE or later (Swift 6.2, iOS 26 SDK)."
ok "Xcode $XCODE_VERSION at $DEVELOPER_DIR_PATH"

if ! xcodebuild -license check >/dev/null 2>&1; then
    note "The Xcode license has not been accepted yet."
    confirm "Accept it now? (runs: sudo xcodebuild -license accept)" \
        && sudo xcodebuild -license accept \
        || fail "The Xcode license must be accepted." "Run: sudo xcodebuild -license accept"
fi
ok "Xcode license accepted"

if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    note "Xcode still needs to install its first-launch components."
    confirm "Install them now? (runs: sudo xcodebuild -runFirstLaunch)" \
        && sudo xcodebuild -runFirstLaunch \
        || fail "Xcode's first-launch components are required." "Run: sudo xcodebuild -runFirstLaunch"
fi
ok "Xcode components installed"

# MARK: 3. iOS Simulator runtime

step "Checking the iOS Simulator runtime"
latest_ios_runtime() {
    xcrun simctl list runtimes available | grep -E '^iOS ' | tail -n 1 | awk '{ print $NF }'
}
RUNTIME="$(latest_ios_runtime)"
if [[ -z "$RUNTIME" ]]; then
    note "No iOS Simulator runtime is installed (download is several GB)."
    confirm "Download it now? (runs: xcodebuild -downloadPlatform iOS)" \
        && xcodebuild -downloadPlatform iOS \
        || fail "An iOS Simulator runtime is required." "Run: xcodebuild -downloadPlatform iOS" "Or: Xcode › Settings › Components › iOS"
    RUNTIME="$(latest_ios_runtime)"
    [[ -n "$RUNTIME" ]] || fail "The iOS runtime still isn't available." "Open Xcode › Settings › Components and install iOS."
fi
ok "Runtime ${RUNTIME##*.}"

# MARK: 4. Simulators

step "Preparing simulators"
udid_for() {
    xcrun simctl list devices available \
        | grep -E "^[[:space:]]+$1 \(" \
        | head -n 1 \
        | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' || true
}

FIRST_UDID=""
for name in "${SIMULATORS[@]}"; do
    udid="$(udid_for "$name")"
    if [[ -z "$udid" ]]; then
        device_type="$(xcrun simctl list devicetypes | grep -E "^$name \(" | head -n 1 | sed -E 's/.*\((com\.apple[^)]*)\).*/\1/' || true)"
        [[ -n "$device_type" ]] || fail "This Xcode has no '$name' device type." \
            "Choose other simulators, e.g. IBANGA_SIMULATORS=\"iPhone 16,iPhone 16 Pro\" ./scripts/setup.sh"
        udid="$(xcrun simctl create "$name" "$device_type" "$RUNTIME")"
        ok "$name created ($udid)"
    else
        ok "$name ($udid)"
    fi
    [[ -n "$FIRST_UDID" ]] || FIRST_UDID="$udid"
done

# MARK: 5. Build

step "Building Ibanga Chat (first build takes a minute)"
mkdir -p "$ROOT/build"
if ! xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$FIRST_UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    build >"$BUILD_LOG" 2>&1; then
    grep -E "error:" "$BUILD_LOG" | sort -u >&2 || tail -n 30 "$BUILD_LOG" >&2
    fail "The build failed." "Full log: $BUILD_LOG"
fi
ok "Build succeeded"

printf "\n%s✓ Setup complete.%s Launch the app on both simulators with:\n\n" "$green$bold" "$reset"
if [[ -n "${IBANGA_SIMULATORS:-}" ]]; then
    printf "    IBANGA_SIMULATORS=\"%s\" ./scripts/run-simulators.sh\n\n" "$IBANGA_SIMULATORS"
else
    printf "    ./scripts/run-simulators.sh\n\n"
fi
