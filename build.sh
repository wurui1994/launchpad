#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LaunchPad"
BUNDLE_ID="program.LaunchPad"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building Swift package..."
swift build -c release

# Ensure build output exists
EXECUTABLE_PATH="${BUILD_DIR}/${APP_NAME}"
if [ ! -f "${EXECUTABLE_PATH}" ]; then
    # For some SwiftPM versions, executable will be under .build/release/<targetName>
    # Try alternative path
    EXECUTABLE_PATH=".build/release/${APP_NAME}"
fi

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    echo "Error: built executable not found at ${EXECUTABLE_PATH}"
    # exit 1
fi

# Remove previous bundle
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp Info.plist.in "${CONTENTS_DIR}/Info.plist"

# Optional: copy icon (icns) into Resources and reference in Info.plist if you have one
cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

echo "Created app bundle at ${APP_DIR}"

# Optional: set quarantine removal so double-click works without Gatekeeper prompt (not altering signatures)
# xattr -d com.apple.quarantine "${APP_DIR}" 2>/dev/null || true

# Launch the app using open to ensure it's run as a GUI app
echo "Opening app..."
echo "${APP_DIR}"
# open "${APP_DIR}"