import SwiftUI

@main
struct ClaudeUsageApp: App {
    // Defaults to mock data so the menu bar populates immediately on first launch.
    // After you fill in your org UUID (UsageClient.swift) and your sessionKey
    // (Settings → Authentication), flip this to `false` and rebuild.
    @StateObject private var viewModel = UsageViewModel(useMock: true)

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
