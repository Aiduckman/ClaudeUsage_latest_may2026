import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let onboardingCompleteKey = "claudeusage.onboardingComplete"

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let done = UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey)
        let hasOrgUUID = !((UserDefaults.standard.string(forKey: ClaudeUsageClient.orgUUIDDefaultsKey) ?? "").isEmpty)
        // Auto-show on first launch (unless an org UUID is already configured,
        // which suggests the user upgraded from an older version).
        if !done && !hasOrgUUID {
            showOnboarding()
        }
    }

    @MainActor
    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to ClaudeUsage"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 760, height: 580))

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.onboardingWindow = window
    }
}
