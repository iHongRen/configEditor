#!/usr/bin/env zsh
# Automatic DMG packager for Configs macOS app
# Usage:
#   ./scripts/build_dmg.sh [project_path] [scheme] [configuration] [app_name] [output_dir]
# Examples:
#   ./scripts/build_dmg.sh Configs/Configs.xcodeproj Configs Release Configs

set -euo pipefail

PROJECT_PATH=${1:-"Configs/Configs.xcodeproj"}
SCHEME=${2:-"Configs"}
CONFIGURATION=${3:-"Release"}
APP_NAME=${4:-"Configs"}
OUTPUT_DIR=${5:-"$(pwd)/build/output"}

BUILD_DIR="$(pwd)/build"
STAGING_DIR="$BUILD_DIR/staging"

DMG_NAME="${APP_NAME}-${CONFIGURATION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

echo "Project: $PROJECT_PATH"
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "App Name: $APP_NAME"
echo "Build dir: $BUILD_DIR"
echo "Output DMG: $DMG_PATH"

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Cleaning previous build artifacts..."
rm -rf "$STAGING_DIR"
rm -rf "$BUILD_DIR/DerivedData"

echo "Building app with xcodebuild..."
# Try to build the app. We set a local DerivedData to avoid polluting global Xcode state.
xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" clean build | sed -e 's/^/  /'

echo "Locating .app bundle..."
APP_BUNDLE_NAME="$APP_NAME.app"
APP_PATH=$(find "$BUILD_DIR" -type d -name "$APP_BUNDLE_NAME" | head -n 1 || true)

if [ -z "$APP_PATH" ]; then
    # Try the common legacy path
    if [ -d "${BUILD_DIR}/${CONFIGURATION}/${APP_BUNDLE_NAME}" ]; then
        APP_PATH="${BUILD_DIR}/${CONFIGURATION}/${APP_BUNDLE_NAME}"
    fi
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Cannot find built .app bundle. Searched under $BUILD_DIR"
    exit 1
fi

echo "Found app at: $APP_PATH"

echo "Preparing staging directory: $STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Copying app to staging..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create an Applications symlink so users can drag the app there from the DMG
ln -s /Applications "$STAGING_DIR/Applications" || true

echo "Creating compressed DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "DMG created at: $DMG_PATH"

echo "Cleaning staging..."
rm -rf "$STAGING_DIR"

echo "Done."

exit 0
