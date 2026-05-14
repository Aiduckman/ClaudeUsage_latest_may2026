import AppKit
import SwiftUI
import Combine

/// AppKit-based menu bar item.
///
/// macOS 14+ applies the menu bar text style to NSStatusBarButton's title
/// (attributed or otherwise) and strips custom foreground colors. To get
/// reliable color we render the icon + percentage to a single NSImage and
/// assign it to button.image. For the default (.ok / .neutral) levels the
/// image is marked as a template so macOS auto-tints it for light/dark mode.
/// For warning / danger the orange / red color is baked in.
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
            // Keep the button purely image-based; no system text rendering.
            button.imagePosition = .imageOnly
            button.title = ""
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 380)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: viewModel)
        )

        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refresh() }
            }
            .store(in: &cancellables)

        // Re-render when the system switches between light and dark mode.
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        refresh()
    }

    @objc private func appearanceChanged() {
        DispatchQueue.main.async { self.refresh() }
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let level = viewModel.menuBarLevel

        // Pick the color and whether to bake it in.
        let color: NSColor
        let bake: Bool
        switch level {
        case .ok:       color = .labelColor;          bake = false   // system handles tint
        case .warning:  color = .systemOrange;        bake = true
        case .danger:   color = .systemRed;           bake = true
        case .neutral:  color = .secondaryLabelColor; bake = false
        }

        button.image = renderImage(symbol: level.symbolName,
                                   text: viewModel.menuBarLabel,
                                   color: color,
                                   bakedColor: bake)
        button.title = ""
    }

    /// Draws the SF Symbol + percentage into a single NSImage.
    /// - `bakedColor == false`: the resulting image is marked template;
    ///   macOS auto-tints it to match the menu bar (white/black depending
    ///   on the menu bar background).
    /// - `bakedColor == true`: the color is drawn into the image; the
    ///   image is non-template so macOS leaves it alone.
    private func renderImage(symbol: String,
                             text: String,
                             color: NSColor,
                             bakedColor: Bool) -> NSImage {
        let font = NSFont.menuBarFont(ofSize: 0)

        // Build the symbol with palette color if we're baking it in.
        var symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if bakedColor {
            symbolConfig = symbolConfig.applying(.init(paletteColors: [color]))
        }
        let symbolImage = NSImage(systemSymbolName: symbol,
                                  accessibilityDescription: "ClaudeUsage")?
            .withSymbolConfiguration(symbolConfig)
            ?? NSImage()
        let symbolSize = symbolImage.size

        // For template mode, draw text with any opaque color (alpha is what
        // becomes the tint mask). For baked mode, use the explicit color.
        let textColor: NSColor = bakedColor ? color : .black
        let textAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font
        ]
        let textNS = (" " + text) as NSString
        let textSize = textNS.size(withAttributes: textAttrs)

        let spacing: CGFloat = 1
        let totalWidth = symbolSize.width + spacing + textSize.width
        let totalHeight = max(symbolSize.height, textSize.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        image.lockFocus()

        let symbolY = (totalHeight - symbolSize.height) / 2
        symbolImage.draw(at: NSPoint(x: 0, y: symbolY),
                         from: .zero,
                         operation: .sourceOver,
                         fraction: 1.0)

        let textY = (totalHeight - textSize.height) / 2
        textNS.draw(at: NSPoint(x: symbolSize.width + spacing, y: textY),
                    withAttributes: textAttrs)

        image.unlockFocus()
        image.isTemplate = !bakedColor
        return image
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
