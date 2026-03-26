#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Claudephobia"
BUILD_DIR=".build/release"
APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
SIGNING_IDENTITY="Developer ID Application: Bruno Skendaj (53CZ5753ZD)"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf dist
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"

# Copy Info.plist
cp Resources/Info.plist "${CONTENTS}/Info.plist"

# Copy app icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
    echo "App icon included."
else
    echo "Warning: Resources/AppIcon.icns not found. App will have no icon."
fi

# Code sign with Developer ID + hardened runtime (required for notarization)
echo "Signing with: ${SIGNING_IDENTITY}"
codesign --force --options runtime --entitlements Resources/Claudephobia.entitlements --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
echo "Signed."

# Verify signature
codesign --verify --verbose "${APP_BUNDLE}"
echo "Signature verified."

# Notarize
echo ""
echo "Creating zip for notarization..."
cd dist
zip -r "${APP_NAME}.zip" "${APP_NAME}.app"

echo "Submitting for notarization..."
xcrun notarytool submit "${APP_NAME}.zip" --keychain-profile "claudephobia-notary" --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_NAME}.app"

echo ""
echo "Done: dist/${APP_NAME}.app (signed + notarized)"
echo "Distribution zip: dist/${APP_NAME}.zip"
