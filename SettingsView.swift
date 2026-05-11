import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var launchAtLogin = LaunchAtLogin.shared

    @State private var sessionKeyDraft: String = ""
    @State private var showSavedConfirmation = false

    var body: some View {
        Form {
            Section("Authentication") {
                SecureField("sessionKey", text: $sessionKeyDraft)
                    .textFieldStyle(.roundedBorder)

                Text(authInstructions)
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Save") {
                        let trimmed = sessionKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.sessionStore.sessionKey = trimmed.isEmpty ? nil : trimmed
                        showSavedConfirmation = true
                        Task { await viewModel.refresh() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(sessionKeyDraft.isEmpty)

                    Button("Clear") {
                        sessionKeyDraft = ""
                        viewModel.sessionStore.sessionKey = nil
                    }

                    if showSavedConfirmation {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green).font(.caption)
                            .transition(.opacity)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Notify at 80% and 95%", isOn: $viewModel.notificationsEnabled)

                switch notificationManager.authorizationStatus {
                case .notDetermined:
                    Button("Grant notification permission") {
                        Task { await notificationManager.requestAuthorization() }
                    }
                case .denied:
                    Label("Notifications blocked in System Settings", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundColor(.orange)
                case .authorized, .provisional, .ephemeral:
                    Label("Permission granted", systemImage: "checkmark.circle")
                        .font(.caption).foregroundColor(.green)
                @unknown default:
                    EmptyView()
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin.isEnabled)
                Text(launchAtLogin.statusDescription)
                    .font(.caption).foregroundColor(.secondary)
            }

            Section("Status") {
                if let usage = viewModel.usage {
                    LabeledContent("Last updated") {
                        Text(usage.lastUpdated, style: .time)
                    }
                    LabeledContent("Session") { Text("\(usage.session.displayPercent)%") }
                    LabeledContent("Week")    { Text("\(usage.week.displayPercent)%") }
                    if let opus = usage.opus {
                        LabeledContent("Opus") { Text("\(opus.displayPercent)%") }
                    }
                } else {
                    Text("No data yet.").font(.caption).foregroundColor(.secondary)
                }
                if let error = viewModel.lastError {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 540, minHeight: 560)
        .onAppear {
            sessionKeyDraft = viewModel.sessionStore.sessionKey ?? ""
            Task { await notificationManager.refreshAuthorizationStatus() }
        }
        .onChange(of: showSavedConfirmation) { newValue in
            guard newValue else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { showSavedConfirmation = false }
            }
        }
    }

    private var authInstructions: String {
        """
        Paste your claude.ai sessionKey cookie. \
        To grab it: claude.ai signed in → DevTools (⌥⌘I) → \
        Application → Cookies → claude.ai → copy the Value of `sessionKey`. \
        Stored in macOS Keychain.
        """
    }
}
