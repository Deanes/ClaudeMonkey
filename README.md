# 🐵 ClaudeMonkey

Auto-approve permission prompts in the [Claude desktop app](https://claude.ai/download) on macOS.

When Claude Code (agent mode) asks to run a command, edit a file, or use a tool, ClaudeMonkey detects the permission buttons and clicks them automatically — so you can let Claude work uninterrupted.

## How It Works

ClaudeMonkey uses the **macOS Accessibility API** (AXUIElement) to:

1. Find the Claude desktop app by its bundle ID
2. Activate Chromium/Electron's accessibility tree (it's lazy-loaded)
3. Poll the UI every 1.5 seconds for "Always allow" / "Allow once" buttons
4. Click the appropriate button via `AXUIElementPerformAction`

No screen recording. No OCR. No image matching. Pure accessibility API.

## Features

- **Menubar app** — lives in your menubar as 🐵, no dock icon
- **On/Off toggle** — only watches when you want it to
- **Mode selection** — prefer "Always allow" or "Allow once"
- **Smart fallback** — if only one button type exists, clicks it regardless of mode
- **Activity log** — see what was approved and when
- **Context capture** — reads nearby text to show what command/action was permitted

## Requirements

- macOS 13.0+
- Claude desktop app
- **Accessibility permission** — ClaudeMonkey needs to be granted access in System Settings → Privacy & Security → Accessibility

## Building

```bash
cd ClaudeMonkey

mkdir -p build/ClaudeMonkey.app/Contents/MacOS
cp ClaudeMonkey/Info.plist build/ClaudeMonkey.app/Contents/

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

open build/ClaudeMonkey.app
```

## Accessibility Permission

After launching, macOS will prompt you to grant accessibility access. If the prompt doesn't appear:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click **+** and add `ClaudeMonkey.app` from the `build/` folder
3. Toggle it **on**

> **Note:** Rebuilding the binary changes its hash, which invalidates the accessibility permission. After rebuilding, toggle ClaudeMonkey off and back on in System Settings, or remove and re-add it.

## How Claude's Permission UI Works

Claude desktop is an Electron app. Its permission buttons are rendered in web content inside Chromium. The accessibility tree is lazy — it only materializes when an accessibility client queries the focused element. ClaudeMonkey triggers this on first poll by reading `AXFocusedUIElement`, which causes Chromium to expose all 500+ UI elements including the permission buttons.

The buttons appear as:
- `AXButton` with title **"Always allow"**
- `AXButton` with title **"Allow once ⌘⏎"**
- `AXButton` with title **"Deny"**

ClaudeMonkey matches on the title text and performs `kAXPressAction` to click.

## License

MIT
