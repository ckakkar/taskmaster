import AppKit
import Sparkle

/// Updates, like Luna's: Taskmaster checks GitHub soon after it opens and then every hour, shows what
/// changed, and installs and relaunches. Only builds that carry an update key (releases) check; local
/// builds don't.
///
/// A desktop companion shouldn't throw a window in front of whatever you're doing, so an update found by a
/// background check is announced gently (a dot on the menu bar paw and a note in the companion room) and
/// Sparkle's window opens when you click it. One found right after launch shows Sparkle's window at once.
@MainActor
final class Updater: NSObject {
    private var controller: SPUStandardUpdaterController?
    /// Called with the new version when one is waiting, and nil once it's dealt with.
    var onAvailable: (String?) -> Void = { _ in }
    private var announcedAt: Date?

    override init() {
        super.init()
        let info = Bundle.main.infoDictionary ?? [:]
        let key = (info["SUPublicEDKey"] as? String) ?? ""
        let feed = (info["SUFeedURL"] as? String) ?? ""
        guard !key.isEmpty, !feed.isEmpty else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

        // Sparkle's own schedule waits a full interval after the last check; check soon after launch too.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let updater = self?.controller?.updater, updater.automaticallyChecksForUpdates,
                updater.canCheckForUpdates
            else { return }
            updater.checkForUpdatesInBackground()
        }
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var isAvailable: Bool { controller != nil }

    /// Opens Sparkle's window: the waiting update with its notes, or a fresh check.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}

// Sparkle calls its user driver delegate on the main thread.
extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Right after launch, or if the dot has been ignored for a day, show the window itself.
        immediateFocus || (announcedAt.map { Date().timeIntervalSince($0) > 86400 } ?? false)
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        if handleShowingUpdate {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            if announcedAt == nil { announcedAt = Date() }
            onAvailable(update.displayVersionString)
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        announcedAt = nil
        onAvailable(nil)
    }

    func standardUserDriverWillFinishUpdateSession() {
        announcedAt = nil
        onAvailable(nil)
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static let repository = URL(string: "https://github.com/ckakkar/taskmaster")!
    static let issues = URL(string: "https://github.com/ckakkar/taskmaster/issues/new")!
}

/// The paw in the menu bar, with a dot when an update is waiting.
enum MenuBarGlyph {
    static func image(badge: Bool) -> NSImage? {
        let description = badge ? "Taskmaster companion controls, update available" : "Taskmaster companion controls"
        guard let paw = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: description) else {
            return nil
        }
        guard badge else { return paw }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let scale = min(15 / paw.size.width, 15 / paw.size.height)
            let pawSize = NSSize(width: paw.size.width * scale, height: paw.size.height * scale)
            paw.draw(
                in: NSRect(
                    x: rect.midX - pawSize.width / 2, y: rect.midY - pawSize.height / 2,
                    width: pawSize.width, height: pawSize.height))
            // Clear a ring around the dot so it reads against the paw.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: 11, y: 11, width: 7, height: 7)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 12.5, y: 12.5, width: 4.5, height: 4.5)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }
}
