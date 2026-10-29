import AppKit

/// Shows a meme at a readable size: a delivered card's picture, or one from the stash.
@MainActor
final class MemeViewer {
    private var window: NSWindow?

    func show(_ image: NSImage, title: String) {
        let visible =
            (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let limit = CGSize(width: visible.width * 0.7, height: visible.height * 0.7)
        let natural = image.size.width > 0 && image.size.height > 0 ? image.size : CGSize(width: 640, height: 460)
        // Fit within 70% of the screen; small images are enlarged (up to 2×) so their text is easy to read.
        let scale = min(limit.width / natural.width, limit.height / natural.height, 2)
        let size = CGSize(width: max(320, natural.width * scale), height: max(220, natural.height * scale))

        let window = self.window ?? makeWindow()
        window.title = title
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setAccessibilityLabel(title)
        window.contentView = view
        window.setContentSize(size)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 240, height: 180)
        self.window = window
        return window
    }
}
