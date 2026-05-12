import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item is created in AppKit (StatusBarController) so we
        // can colour the title reliably. Only the Settings scene lives here.
        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
    }
}
