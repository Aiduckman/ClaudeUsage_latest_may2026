import AppKit
import SwiftUI
import Combine

/// AppKit-based menu bar item. SwiftUI's MenuBarExtra applies the system
/// template-image tint to its label and silently strips colors, so the
/// percentage in the menu bar always rendered white. NSStatusItem +
/// attributedTitle gives us reliable color (orange 70–89%, red 90%+).
/// The dropdown content stays SwiftUI via NSHostingController.
@MainActor
final class StatusBarController: NSObject {
    private let viewModel: UsageViewModel
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 380)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: viewModel)
        )

        // Re-render every time any @Published field on the view model changes.
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // willChange fires BEFORE the new value lands; defer one runloop.
                DispatchQueue.main.async { self?.refresh() }
            }
            .store(in: &cancellables)

        refresh()
    }

    private func refresh() {
        guard let button = statusItem.button else { return }

        let level = viewModel.menuBarLevel
        let (textColor, useTint): (NSColor, Bool)
        switch level {
        case .ok:       textColor = .labelColor;          useTint = false  // default menu bar text
        case .warning:  textColor = .systemOrange;        useTint = true
        case .danger:   textColor = .systemRed;           useTint = true
        case .neutral:  textColor = .secondaryLabelColor; useTint = false
        }

        // Icon
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let image = NSImage(systemSymbolName: level.symbolName,
                            accessibilityDescription: "ClaudeUsage")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true

        // Title — attributedTitle bypasses the system menu bar text style.
        let title = " " + viewModel.menuBarLabel
        let attr = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.menuBarFont(ofSize: 0)
            ]
        )
        button.attributedTitle = attr

        // contentTintColor recolors the template image to match.
        button.contentTintColor = useTint ? textColor : nil
    }

    @objc private func togglePopover(_ sender: AnyObject) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
