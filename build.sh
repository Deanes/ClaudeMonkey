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
codesign --force --sign - \
    --identifier com.cyberstewart.claudemonkey \
    --entitlements ClaudeMonkey/ClaudeMonkey.entitlements \
    build/ClaudeMonkey.app

echo "✅ Build complete: build/ClaudeMonkey.app"
