#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Claudephobia"
SCHEME="Claudephobia"
ARCHIVE_PATH="dist/${APP_NAME}.xcarchive"
EXPORT_DIR="dist"
SIGNING_IDENTITY="Developer ID Application: Bruno Skendaj (53CZ5753ZD)"
TEAM_ID="53CZ5753ZD"

# Provisioning profile names (must match names on developer.apple.com exactly)
PROFILE_APP="Claudephobia Developer ID"
PROFILE_WIDGET="Claudephobia Widget Developer ID"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------

if ! command -v xcodegen &>/dev/null; then
    echo "❌  xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

# Verify profiles are installed locally before wasting time on a build
check_profile() {
    local name="$1"
    local found
    found=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.provisionprofile" -o -name "*.mobileprovision" 2>/dev/null \
        | xargs -I{} security cms -D -i {} 2>/dev/null \
        | grep -A1 "<key>Name</key>" \
        | grep "<string>${name}</string>" | head -1)
    if [ -z "$found" ]; then
        echo "❌  Provisioning profile not found: \"${name}\""
        echo "    → In Xcode: Settings → Accounts → Download Manual Profiles"
        echo "    → Or create it at developer.apple.com → Profiles"
        return 1
    fi
    echo "✅  Profile found: ${name}"
}

echo "Checking provisioning profiles..."
check_profile "$PROFILE_APP"
check_profile "$PROFILE_WIDGET"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

echo ""
echo "Generating Xcode project from project.yml..."
xcodegen generate

echo ""
echo "Cleaning previous build artifacts..."
rm -rf dist

echo ""
echo "Archiving ${APP_NAME} + ClaudephobiaWidget extension..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_APP" \
    "ClaudephobiaWidget:PROVISIONING_PROFILE_SPECIFIER=$PROFILE_WIDGET" \
    -quiet

echo ""
echo "Exporting signed app bundle..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -quiet

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

echo ""
echo "Verifying signatures..."
codesign --verify --verbose "${EXPORT_DIR}/${APP_NAME}.app"
codesign --verify --verbose "${EXPORT_DIR}/${APP_NAME}.app/Contents/PlugIns/ClaudephobiaWidget.appex"
echo "✅  Signatures verified."

# ---------------------------------------------------------------------------
# Notarize
# ---------------------------------------------------------------------------

echo ""
echo "Creating zip for notarization..."
cd "$EXPORT_DIR"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

echo "Submitting for notarization..."
xcrun notarytool submit "${APP_NAME}.zip" --keychain-profile "claudephobia-notary" --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_NAME}.app"

echo ""
echo "✅  Done: dist/${APP_NAME}.app (signed + notarized, widget embedded)"
echo "    Distribution zip: dist/${APP_NAME}.zip"
