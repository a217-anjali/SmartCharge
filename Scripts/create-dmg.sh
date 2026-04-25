#!/bin/bash
set -euo pipefail

APP_NAME="SmartCharge"
DMG_NAME="${APP_NAME}.dmg"
BUILD_DIR="build/Release"
STAGING_DIR="build/dmg-staging"

echo "Building ${APP_NAME} for release..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath build \
    clean build

APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} not found"
    exit 1
fi

echo "Creating DMG..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "build/${DMG_NAME}"

rm -rf "${STAGING_DIR}"
echo "Done: build/${DMG_NAME}"
