import SwiftUI

@main
struct ClaudeUsageApp: App {
    // Live data by default. The menu bar will show an error until you paste your
    // Organization UUID and sessionKey in Settings (⌘,). Flip to `true` for a
    // mock-data demo mode.
    @StateObject private var viewModel = UsageViewModel(useMock: false)

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
