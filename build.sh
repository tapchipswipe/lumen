#!/bin/bash
#
# macsync build script.
#
# Strategy:
#   1. If a full Xcode is installed (xcodebuild usable) -> generate project via
#      XcodeGen (if available) and build with xcodebuild.
#   2. Otherwise -> compile directly with swiftc from Command Line Tools,
#      assemble the .app bundle by hand. (Fully sufficient: the project is a
#      single pure-Swift target with no storyboards or asset catalogs.)
#
# Output:
#   build/macsync.app   (ad-hoc signed)
#   build/macsync.dmg   (compressed, mountable)
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Lumen"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
BUNDLE_ID="com.lumen.app"
MIN_MACOS="14.0"

echo "==> Lumen build"
echo "    Project: $PROJECT_DIR"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
touch "$BUILD_DIR/.metadata_never_index"

# ---------------------------------------------------------------------------
# Path 1: full Xcode via xcodebuild
# ---------------------------------------------------------------------------
if xcodebuild -version >/dev/null 2>&1; then
    echo "==> Full Xcode detected, using xcodebuild"
    XCODEPROJ="$PROJECT_DIR/$APP_NAME.xcodeproj"
    if [ ! -d "$XCODEPROJ" ]; then
        if command -v xcodegen >/dev/null 2>&1; then
            echo "==> Generating Xcode project with XcodeGen"
            (cd "$PROJECT_DIR" && xcodegen generate)
        else
            echo "!! xcodegen not installed (brew install xcodegen); falling back to swiftc"
        fi
    fi
    if [ -d "$XCODEPROJ" ]; then
        xcodebuild \
            -project "$XCODEPROJ" \
            -scheme "$APP_NAME" \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR/DerivedData" \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build
        cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app" "$APP_BUNDLE"
    fi
fi

# ---------------------------------------------------------------------------
# Path 2: direct swiftc compilation (Command Line Tools)
# ---------------------------------------------------------------------------
if [ ! -d "$APP_BUNDLE" ]; then
    echo "==> Compiling with swiftc (no full Xcode required)"
    SWIFT_SOURCES=$(find "$PROJECT_DIR/Sources" -name '*.swift' | sort)
    echo "$SWIFT_SOURCES" | sed 's/^/    /'

    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
    TARGET="arm64-apple-macosx$MIN_MACOS"

    mkdir -p "$BUILD_DIR/obj"
    # shellcheck disable=SC2086
    swiftc \
        -sdk "$SDK_PATH" \
        -target "$TARGET" \
        -O \
        -whole-module-optimization \
        -module-name "$APP_NAME" \
        -o "$BUILD_DIR/$APP_NAME" \
        $SWIFT_SOURCES

    echo "==> Assembling $APP_NAME.app bundle"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    cp "$PROJECT_DIR/Resources/macsync.entitlements" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Code sign. Prefer the stable self-signed "macsync-dev" identity so that
# macOS TCC permission grants (Accessibility, Screen Recording) survive
# rebuilds — ad-hoc signing produces a new cdhash each build and breaks them.
# ---------------------------------------------------------------------------
SIGN_IDENTITY="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "macsync-dev"; then
    SIGN_IDENTITY="macsync-dev"
    echo "==> Signing with stable identity: macsync-dev"
else
    echo "==> Signing ad-hoc (no macsync-dev identity found)"
fi
codesign --force --deep --sign "$SIGN_IDENTITY" \
    --entitlements "$PROJECT_DIR/Resources/macsync.entitlements" \
    --identifier "$BUNDLE_ID" \
    "$APP_BUNDLE"
codesign --verify --verbose=1 "$APP_BUNDLE" >/dev/null 2>&1 && echo "    signature OK"

# ---------------------------------------------------------------------------
# Package into .dmg
# ---------------------------------------------------------------------------
echo "==> Creating DMG"
DMG_STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
rm -rf "$DMG_STAGING"

echo ""
echo "==> Installing to /Applications/$APP_NAME.app"
rm -rf "/Applications/macsync.app" "/Applications/$APP_NAME.app" 2>/dev/null || true
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$APP_BUNDLE" 2>/dev/null || true
    "$LSREGISTER" -u "$PROJECT_DIR/build/dmg-staging/$APP_NAME.app" 2>/dev/null || true
    "$LSREGISTER" -f -R -trusted "/Applications/$APP_NAME.app" 2>/dev/null || true
fi
rm -rf "$APP_BUNDLE" "$DMG_STAGING" 2>/dev/null || true
touch "/Applications/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "==> BUILD COMPLETE"
echo "    Installed: /Applications/$APP_NAME.app"
echo "    DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1 | tr -d ' '))"

# Auto-sync MEMORY.md, AGENTS.md, GEMINI.md to iCloud agent_context
ICLOUD_AGENT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Lumen/agent_context"
if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
    mkdir -p "$ICLOUD_AGENT_DIR"
    cp "$PROJECT_DIR/MEMORY.md" "$ICLOUD_AGENT_DIR/MEMORY.md" 2>/dev/null || true
    cp "$PROJECT_DIR/README.md" "$ICLOUD_AGENT_DIR/README.md" 2>/dev/null || true
    cp /Users/lucasdespot/AGENTS.md "$ICLOUD_AGENT_DIR/AGENTS.md" 2>/dev/null || true
    echo "    iCloud Context: Synchronized ($ICLOUD_AGENT_DIR)"
fi
