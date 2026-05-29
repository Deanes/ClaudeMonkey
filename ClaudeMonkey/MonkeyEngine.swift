import Foundation
import Cocoa
import ApplicationServices

struct ApprovalEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let buttonTitle: String
    let context: String
}

enum ApprovalMode: String, CaseIterable {
    case alwaysAllow = "Always allow"
    case allowOnce = "Allow once"
}

@MainActor
class MonkeyEngine: ObservableObject {
    @Published var isEnabled = true {
        didSet {
            if isEnabled {
                startPolling()
            } else {
                stopPolling()
            }
        }
    }
    @Published var approvalMode: ApprovalMode = .alwaysAllow
    @Published var log: [ApprovalEntry] = []
    @Published var claudeRunning = false
    @Published var lastPollTime: Date? = nil
    @Published var hasAccessibility = false
    @Published var promptVisible = false
    @Published var delayEnabled = true
    @Published var delaySeconds: Double = 4.0
    @Published var countdown: Double = 0

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 3.0
    private var axActivated = false
    private var promptFirstSeen: Date? = nil

    // MARK: - Accessibility Check

    @discardableResult
    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibility = trusted
        return trusted
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        axActivated = false
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        axActivated = false
    }

    private func poll() {
        lastPollTime = Date()
        hasAccessibility = AXIsProcessTrusted()
        guard hasAccessibility else { return }

        guard let claudePID = findClaudePID() else {
            claudeRunning = false
            promptVisible = false
            return
        }
        claudeRunning = true

        let appRef = AXUIElementCreateApplication(claudePID)

        // Tell Electron/Chromium to expose its full accessibility tree.
        // AXEnhancedUserInterface is the standard signal — works in Parsec/remote sessions.
        AXUIElementSetAttributeValue(appRef, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        // Trigger lazy AX tree materialization
        var focusedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedRef)

        // Try standard windows attribute first
        var windowsRef: CFTypeRef?
        var windows: [AXUIElement] = []
        if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let w = windowsRef as? [AXUIElement], !w.isEmpty {
            windows = w
        } else {
            // Fallback: main window, focused window, or children
            var mainRef: CFTypeRef?
            var focusWinRef: CFTypeRef?
            AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &mainRef)
            AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusWinRef)
            if let r = mainRef, CFGetTypeID(r) == AXUIElementGetTypeID() {
                windows.append(r as! AXUIElement)
            }
            if let r = focusWinRef, CFGetTypeID(r) == AXUIElementGetTypeID() {
                let w = r as! AXUIElement
                if !windows.contains(where: { CFEqual($0, w) }) { windows.append(w) }
            }
            if windows.isEmpty {
                var childRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appRef, kAXChildrenAttribute as CFString, &childRef) == .success,
                   let children = childRef as? [AXUIElement] {
                    windows = children
                }
            }
        }

        guard !windows.isEmpty else { return }

        var allButtons: [(element: AXUIElement, title: String, kind: ApprovalKind)] = []
        for window in windows {
            collectApprovalButtons(element: window, depth: 0, buttons: &allButtons)
        }

        if allButtons.isEmpty {
            promptVisible = false
            promptFirstSeen = nil
            countdown = 0
            return
        }

        promptVisible = true

        let preferred = allButtons.first { $0.kind == .alwaysAllow }
        let fallback  = allButtons.first { $0.kind == .allowOnce }
        let target: (element: AXUIElement, title: String, kind: ApprovalKind)?
        switch approvalMode {
        case .alwaysAllow: target = preferred ?? fallback
        case .allowOnce:   target = fallback  ?? preferred
        }
        guard let btn = target else { return }

        if delayEnabled {
            if promptFirstSeen == nil { promptFirstSeen = Date() }
            let remaining = delaySeconds - Date().timeIntervalSince(promptFirstSeen!)
            if remaining > 0 { countdown = remaining; return }
        }

        countdown = 0
        promptFirstSeen = nil
        clickButton(btn.element, title: btn.title)
    }

    // MARK: - Process Discovery

    private func findClaudePID() -> pid_t? {
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == "com.anthropic.claudefordesktop" {
                return app.processIdentifier
            }
        }
        return nil
    }

    // MARK: - AX Tree Search

    private enum ApprovalKind {
        case alwaysAllow
        case allowOnce
    }

    private func collectApprovalButtons(element: AXUIElement, depth: Int, buttons: inout [(element: AXUIElement, title: String, kind: ApprovalKind)]) {
        guard depth < 35 else { return }

        let role  = axString(element, kAXRoleAttribute)
        let title = axString(element, kAXTitleAttribute) ?? ""
        let desc  = axString(element, kAXDescriptionAttribute) ?? ""

        if role == "AXButton" {
            let text = (title.isEmpty ? desc : title).lowercased()
            if text == "always allow" || text.hasPrefix("always allow") {
                buttons.append((element, title.isEmpty ? desc : title, .alwaysAllow))
            } else if text.hasPrefix("allow once") || text == "allow once" {
                buttons.append((element, title.isEmpty ? desc : title, .allowOnce))
            }
        }

        var childrenRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard err == .success, let children = childrenRef as? [AXUIElement] else { return }
        for child in children {
            collectApprovalButtons(element: child, depth: depth + 1, buttons: &buttons)
        }
    }

    private func clickButton(_ element: AXUIElement, title: String) {
        let err = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if err == .success {
            let context = gatherContext(element)
            let entry = ApprovalEntry(timestamp: Date(), buttonTitle: title, context: context)
            log.insert(entry, at: 0)
            if log.count > 100 { log = Array(log.prefix(100)) }
            NSLog("🐵 ClaudeMonkey: Clicked '\(title)' — \(context)")
            axActivated = false
        } else {
            NSLog("🐵 ClaudeMonkey: Failed to click '\(title)' — AX error \(err.rawValue)")
        }
    }

    // MARK: - Context Gathering

    private func gatherContext(_ button: AXUIElement) -> String {
        guard let parent = axElement(button, kAXParentAttribute) else { return "permission prompt" }
        var texts: [String] = []
        collectTexts(element: parent, depth: 0, maxDepth: 3, texts: &texts)
        let filtered = texts.filter { t in
            !t.isEmpty && t.count > 3 && t.count < 300
            && !t.lowercased().hasPrefix("allow")
            && t.lowercased() != "deny"
        }
        if filtered.isEmpty { return "permission prompt" }
        return filtered.prefix(2).joined(separator: " | ")
    }

    private func collectTexts(element: AXUIElement, depth: Int, maxDepth: Int, texts: inout [String]) {
        guard depth < maxDepth else { return }
        let role = axString(element, kAXRoleAttribute) ?? ""
        if role == "AXStaticText" || role == "AXTextField" || role == "AXTextArea" {
            if let val = axString(element, kAXValueAttribute), !val.isEmpty {
                texts.append(val)
            } else if let t = axString(element, kAXTitleAttribute), !t.isEmpty {
                texts.append(t)
            }
        }
        var childrenRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard err == .success, let children = childrenRef as? [AXUIElement] else { return }
        for child in children { collectTexts(element: child, depth: depth + 1, maxDepth: maxDepth, texts: &texts) }
    }

    // MARK: - AX Helpers

    private func axString(_ elem: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elem, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private func axElement(_ elem: AXUIElement, _ attr: String) -> AXUIElement? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(elem, attr as CFString, &ref)
        guard err == .success, let r = ref else { return nil }
        guard CFGetTypeID(r) == AXUIElementGetTypeID() else { return nil }
        return (r as! AXUIElement)
    }

    // MARK: - Cleanup

    func clearLog() { log.removeAll() }
}
