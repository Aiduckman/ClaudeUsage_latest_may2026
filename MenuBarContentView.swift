import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
            Text("ClaudeUsage").font(.headline)
            Spacer()
            if viewModel.isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let usage = viewModel.usage {
            windowRow(title: "Session (5h)", window: usage.session)
            windowRow(title: "Week", window: usage.week)
            if let opus = usage.opus {
                windowRow(title: "Opus (week)", window: opus)
            }
            HStack {
                Spacer()
                Text("Updated \(usage.lastUpdated, style: .time)")
                    .font(.caption2).foregroundColor(.secondary)
            }
        } else if let error = viewModel.lastError {
            VStack(alignment: .leading, spacing: 6) {
                Label("Error", systemImage: "exclamationmark.triangle")
                    .font(.caption.bold()).foregroundColor(.red)
                Text(error).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func windowRow(title: String, window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(window.displayPercent)%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(tint(for: window.utilization))
            }
            ProgressView(value: window.safeValue)
                .tint(tint(for: window.utilization))
            Text("Resets \(window.resetsAt, style: .relative)")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private func tint(for pct: Double) -> Color {
        if pct >= 0.9 { return .red }
        if pct >= 0.7 { return .orange }
        return .blue
    }

    private var footer: some View {
        HStack {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")

            Spacer()

            SettingsLink {
                Text("Settings…")
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
