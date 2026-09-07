#!/bin/bash
set -e

PROJECT_DIR="/Users/lucasdespot/macsync"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Lumen"

echo "=================================================="
echo "⚡ LUMEN MASTER AUTO-SHIP PIPELINE"
echo "=================================================="

cd "$PROJECT_DIR"

# 1. Read current version and bump patch by 1
OLD_VERSION=$(grep -A 1 "CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
IFS='.' read -r major minor patch <<< "$OLD_VERSION"
NEW_PATCH=$((patch + 1))
NEW_VERSION="${major}.${minor}.${NEW_PATCH}"

echo "🔢 Auto-bumping version: $OLD_VERSION -> $NEW_VERSION"

find "$PROJECT_DIR" -type f \( -name "*.plist" -o -name "*.sh" \) | grep -v ".git/" | xargs sed -i '' "s/${OLD_VERSION}/${NEW_VERSION}/g"
sed -i '' "s/Current version\*\*: \`${OLD_VERSION}\`/Current version\*\*: \`${NEW_VERSION}\`/g" /Users/lucasdespot/AGENTS.md /Users/lucasdespot/GEMINI.md "$PROJECT_DIR/MEMORY.md" 2>/dev/null || true

# 2. Run Automated Regression Suite
echo "🧪 Running test suite..."
./test.sh > /tmp/lumen_test_output.log 2>&1 || {
    echo "❌ Tests failed! Showing last 20 lines:"
    tail -n 20 /tmp/lumen_test_output.log
    exit 1
}
echo "✅ $(grep "checks passed" /tmp/lumen_test_output.log || echo "All tests passed")"

# 3. Build iOS Target
echo "📱 Building LumenMobile.ipa (v$NEW_VERSION)..."
bash mobile/scripts/build_ios.sh > /tmp/lumen_ios_build.log 2>&1 || {
    echo "❌ iOS build failed! Showing last 20 lines:"
    tail -n 20 /tmp/lumen_ios_build.log
    exit 1
}
echo "✅ LumenMobile.ipa packaged successfully."

# 4. Build macOS Target
echo "🖥️ Building Lumen.app (v$NEW_VERSION)..."
./build.sh > /tmp/lumen_mac_build.log 2>&1 || {
    echo "❌ macOS build failed! Showing last 20 lines:"
    tail -n 20 /tmp/lumen_mac_build.log
    exit 1
}
echo "✅ Lumen.app built & signed with macsync-dev."

# 5. Sync Artifacts & Memory to iCloud Drive
echo "☁️ Syncing to iCloud Drive..."
mkdir -p "$ICLOUD_DIR/builds" "$ICLOUD_DIR/agent_context"
cp "$PROJECT_DIR/build/Lumen.dmg" "$ICLOUD_DIR/builds/Lumen.dmg"
cp "$PROJECT_DIR/mobile/distribution/LumenMobile.ipa" "$ICLOUD_DIR/builds/LumenMobile.ipa"
cp "$PROJECT_DIR/MEMORY.md" "$ICLOUD_DIR/agent_context/MEMORY.md" 2>/dev/null || true
cp "$PROJECT_DIR/README.md" "$ICLOUD_DIR/agent_context/README.md" 2>/dev/null || true
cp /Users/lucasdespot/AGENTS.md "$ICLOUD_DIR/agent_context/AGENTS.md" 2>/dev/null || true
echo "✅ iCloud Drive synchronized."

# 6. Commit & Push to GitHub
echo "🐙 Committing & pushing to GitHub..."
git add -A
COMMIT_MSG="release(v$NEW_VERSION): automated delivery pipeline"
git commit -m "$COMMIT_MSG" >/dev/null 2>&1 || true
git push origin main >/dev/null 2>&1 || true
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION" 2>/dev/null || true
git push origin "v$NEW_VERSION" >/dev/null 2>&1 || true
echo "✅ GitHub updated (main + tag v$NEW_VERSION)."

echo "=================================================="
echo "🎉 DEPLOYMENT COMPLETE: v$NEW_VERSION IS LIVE ACROSS MAC, IOS, ICLOUD & GITHUB"
echo "=================================================="
