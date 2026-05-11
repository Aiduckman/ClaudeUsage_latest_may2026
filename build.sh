#!/bin/bash
set -e
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "✗ xcodebuild not found. Install Xcode from the App Store."
    exit 1
fi

echo "→ Generating Xcode project…"
xcodegen generate --quiet

echo "→ Building ClaudeUsage (Release)…"
xcodebuild \
    -project ClaudeUsage.xcodeproj \
    -scheme ClaudeUsage \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    -quiet

APP_PATH=$(find build/Build/Products/Release -name "ClaudeUsage.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "✗ Build succeeded but couldn't locate .app — inspect build/ for issues."
    exit 1
fi

rm -rf ClaudeUsage.app
cp -R "$APP_PATH" .
xattr -dr com.apple.quarantine ClaudeUsage.app 2>/dev/null || true

echo ""
echo "✓ ClaudeUsage.app is ready in $(pwd)"
echo "  → open ClaudeUsage.app                    # launch now"
echo "  → mv ClaudeUsage.app /Applications/       # install (recommended)"
