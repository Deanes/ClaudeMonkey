import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine: MonkeyEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("🐵 ClaudeMonkey")
                    .font(.headline)
                Spacer()
                StatusPill(
                    text: engine.isEnabled ? (engine.promptVisible ? "Clicking!" : "Watching") : "Off",
                    color: engine.isEnabled ? (engine.promptVisible ? .orange : .green) : .secondary
                )
            }

            Divider()

            // Main toggle
            Toggle(isOn: $engine.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Approve")
                        .font(.system(.body, weight: .medium))
                    Text("Watch Claude for permission prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // Mode picker
            HStack {
                Text("Click:")
                    .foregroundColor(.secondary)
                Picker("", selection: $engine.approvalMode) {
                    ForEach(ApprovalMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Delay toggle
            Toggle(isOn: $engine.delayEnabled) {
                HStack {
                    Text("Delay")
                        .font(.system(.body, weight: .medium))
                    Text("\(Int(engine.delaySeconds))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // Countdown indicator
            if engine.countdown > 0 {
                HStack(spacing: 8) {
                    ProgressView(value: 1.0 - (engine.countdown / engine.delaySeconds))
                        .progressViewStyle(.linear)
                        .tint(.orange)
                    Text(String(format: "%.0fs", engine.countdown))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // Status
            VStack(alignment: .leading, spacing: 4) {
                StatusRow(
                    label: "Claude",
                    value: engine.claudeRunning ? "Running" : "Not found",
                    color: engine.claudeRunning ? .green : .red
                )
                StatusRow(
                    label: "Accessibility",
                    value: engine.hasAccessibility ? "Granted" : "Not granted",
                    color: engine.hasAccessibility ? .green : .orange
                )
                if engine.isEnabled, let lastPoll = engine.lastPollTime {
                    StatusRow(
                        label: "Last poll",
                        value: lastPoll.formatted(.dateTime.hour().minute().second()),
                        color: .secondary
                    )
                }
            }

            if !engine.hasAccessibility {
                Button("Grant Accessibility Access") {
                    _ = engine.checkAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            // Log
            HStack {
                Text("Activity Log")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !engine.log.isEmpty {
                    Text("\(engine.log.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                    Button("Clear") {
                        engine.clearLog()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }

            if engine.log.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("🙈")
                            .font(.title2)
                        Text("No approvals yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(engine.log) { entry in
                            LogEntryView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Divider()

            // Footer
            HStack {
                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.body)
                .foregroundColor(.red)
            }
        }
        .padding(16)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(value)
                .font(.caption)
        }
    }
}

struct LogEntryView: View {
    let entry: ApprovalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("✅")
                    .font(.caption2)
                Text(entry.buttonTitle)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !entry.context.isEmpty && entry.context != "permission prompt" {
                Text(entry.context)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.05)))
    }
}
