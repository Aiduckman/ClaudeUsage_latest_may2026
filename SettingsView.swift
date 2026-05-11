import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var launchAtLogin = LaunchAtLogin.shared

    @State private var orgUUIDDraft: String = ""
    @State private var sessionKeyDraft: String = ""
    @State private var showSavedConfirmation = false

    var body: some View {
        Form {
            Section("Authentication") {
                TextField("Organization UUID", text: $orgUUIDDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                SecureField("sessionKey", text: $sessionKeyDraft)
                    .textFieldStyle(.roundedBorder)

                Text(authInstructions)
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Save") {
                        let orgTrimmed = orgUUIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        let keyTrimmed = sessionKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(orgTrimmed, forKey: ClaudeUsageClient.orgUUIDDefaultsKey)
                        viewModel.sessionStore.sessionKey = keyTrimmed.isEmpty ? nil : keyTrimmed
                        showSavedConfirmation = true
                        Task { await viewModel.refresh() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(orgUUIDDraft.isEmpty && sessionKeyDraft.isEmpty)

                    Button("Clear") {
                        orgUUIDDraft = ""
                        sessionKeyDraft = ""
                        UserDefaults.standard.removeObject(forKey: ClaudeUsageClient.orgUUIDDefaultsKey)
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
        .frame(minWidth: 540, minHeight: 600)
        .onAppear {
            orgUUIDDraft = UserDefaults.standard.string(forKey: ClaudeUsageClient.orgUUIDDefaultsKey) ?? ""
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
        Sign into claude.ai, open DevTools (⌥⌘I).

        • Organization UUID: Network tab → click Settings → Usage → find a request to \
        /api/organizations/<UUID>/usage → copy the UUID.

        • sessionKey: Application → Cookies → claude.ai → copy the Value of `sessionKey`.

        Both are stored locally (UUID in app preferences, sessionKey in macOS Keychain).
        """
    }
}
