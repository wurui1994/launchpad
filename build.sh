#!/usr/bin/env bash
# set -euo pipefail

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
echo "${APP_DIR}"
if [ "$1" = "--run" ] || [ "$1" = "-r" ]; then
    echo "Opening app..."
    open "${APP_DIR}"
fi

# Optional: Create a zip archive with date
if [ "$1" = "--zip" ] || [ "$1" = "-z" ]; then
    # Get current date in YYYYMMDD format
    CURRENT_DATE=$(date +"%Y%m%d")
    ZIP_NAME="${APP_NAME}_${CURRENT_DATE}.zip"
    ZIP_PATH="build/${ZIP_NAME}"
    
    echo "Creating zip archive: ${ZIP_NAME}..."
    # Remove previous zip if exists
    rm -f "${ZIP_PATH}"
    
    # Create zip archive from the app bundle
    cd build && zip -r "${ZIP_NAME}" "${APP_NAME}.app" && cd ..
    
    echo "Zip archive created at: ${ZIP_PATH}"
    
    # Optional: Remove quarantine attribute from the zip file
    xattr -d com.apple.quarantine "${ZIP_PATH}" 2>/dev/null || true
    
    echo "Download link: file://${PWD}/${ZIP_PATH}"
fi