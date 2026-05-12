import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let onboardingCompleteKey = "claudeusage.onboardingComplete"

    /// Shared view model. Owned by the delegate so both the AppKit status bar
    /// controller and the SwiftUI Settings scene can observe the same instance.
    let viewModel = UsageViewModel(useMock: false)

    private var statusBarController: StatusBarController?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Internal capture mode: render each onboarding page to PNG and exit.
        // Used to generate README screenshots without needing Screen Recording.
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--capture-onboarding=") }) {
            let dir = String(arg.dropFirst("--capture-onboarding=".count))
            Task { @MainActor in
                self.captureOnboarding(to: dir)
            }
            return
        }

        // Bring up the menu bar item (AppKit, not MenuBarExtra).
        Task { @MainActor in
            self.statusBarController = StatusBarController(viewModel: self.viewModel)
        }

        let done = UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey)
        let hasOrgUUID = !((UserDefaults.standard.string(forKey: ClaudeUsageClient.orgUUIDDefaultsKey) ?? "").isEmpty)
        if !done && !hasOrgUUID {
            showOnboarding()
        }
    }

    @MainActor
    private func captureOnboarding(to dirPath: String) {
        let dir = URL(fileURLWithPath: dirPath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for page in 0..<4 {
            let view = OnboardingView(initialPage: page, onComplete: {})
                .preferredColorScheme(.dark)
                .background(Color(NSColor.windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            guard let nsImage = renderer.nsImage,
                  let tiff = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:])
            else {
                print("X failed to render page \(page)")
                continue
            }
            let out = dir.appendingPathComponent("page\(page).png")
            do {
                try png.write(to: out)
                print("OK \(out.lastPathComponent)")
            } catch {
                print("X write failed: \(error)")
            }
        }
        NSApp.terminate(nil)
    }

    @MainActor
    func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Optional debug/QA hook: launch directly to a specific page by
        // setting the key, e.g. `defaults write com.example.claudeusage \
        // claudeusage.onboardingStartPage -int 2`.
        let startPage = UserDefaults.standard.integer(forKey: "claudeusage.onboardingStartPage")
        UserDefaults.standard.removeObject(forKey: "claudeusage.onboardingStartPage")

        let view = OnboardingView(initialPage: startPage) { [weak self] in
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
