#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Claudephobia"
SCHEME="Claudephobia"
ARCHIVE_PATH="dist/${APP_NAME}.xcarchive"
EXPORT_DIR="dist"
SIGNING_IDENTITY="Developer ID Application: Bruno Skendaj (53CZ5753ZD)"
TEAM_ID="53CZ5753ZD"

# Require xcodegen
if ! command -v xcodegen &>/dev/null; then
    echo "xcodegen not found. Install it with: brew install xcodegen"
    exit 1
fi

echo "Generating Xcode project from project.yml..."
xcodegen generate

echo "Cleaning previous build artifacts..."
rm -rf dist

echo "Archiving ${APP_NAME} (this includes the widget extension)..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -quiet

echo "Exporting app bundle..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -quiet

echo ""
echo "Verifying signature..."
codesign --verify --verbose "${EXPORT_DIR}/${APP_NAME}.app"
echo "Verifying widget extension signature..."
codesign --verify --verbose "${EXPORT_DIR}/${APP_NAME}.app/Contents/PlugIns/ClaudephobiaWidget.appex"
echo "Signatures verified."

echo ""
echo "Creating zip for notarization..."
cd "$EXPORT_DIR"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

echo "Submitting for notarization..."
xcrun notarytool submit "${APP_NAME}.zip" --keychain-profile "claudephobia-notary" --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_NAME}.app"

echo ""
echo "Done: dist/${APP_NAME}.app (signed + notarized)"
echo "Distribution zip: dist/${APP_NAME}.zip"
