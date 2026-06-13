#!/bin/bash
# Build and sign ClaudeMonkey
set -e

cd "$(dirname "$0")"

mkdir -p build/ClaudeMonkey.app/Contents/MacOS
cp ClaudeMonkey/Info.plist build/ClaudeMonkey.app/Contents/

echo "Building..."
swiftc \
    ClaudeMonkey/ClaudeMonkeyApp.swift \
    ClaudeMonkey/MonkeyEngine.swift \
    ClaudeMonkey/MenuBarView.swift \
    -o build/ClaudeMonkey.app/Contents/MacOS/ClaudeMonkey \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework SwiftUI \
    -target arm64-apple-macosx13.0 \
    -parse-as-library

echo "Signing..."
# Sign with the stable Apple Development team identity (not ad-hoc) so the macOS
# Accessibility (TCC) grant survives rebuilds. Ad-hoc signing (--sign -) changes
# the code hash every build and silently resets the Accessibility permission,
# which makes the app's poll loop short-circuit and show "Not found".
# Override the identity with SIGN_ID=... ./build.sh if the cert ever changes.
SIGN_ID="${SIGN_ID:-Apple Development: Deane Stewart (2HVVX24CN3)}"
codesign --force --sign "$SIGN_ID" \
    --identifier com.cyberstewart.claudemonkey \
    --entitlements ClaudeMonkey/ClaudeMonkey.entitlements \
    build/ClaudeMonkey.app

echo "✅ Build complete: build/ClaudeMonkey.app"
