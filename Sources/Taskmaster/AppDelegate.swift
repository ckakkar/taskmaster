import AppKit
import Combine
import CompanionCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var room: NSWindow?
    private var settings: SettingsWindowController?
    private var welcome: WelcomeWindowController?
    private var updateBadge: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let atlas = try PetAtlas()
            let model = AppModel(atlas: atlas)
            self.model = model
            let settings = SettingsWindowController(model: model)
            let welcome = WelcomeWindowController(model: model)
            self.settings = settings
            self.welcome = welcome
            model.openRoom = { [weak self] in self?.showRoom() }
            model.openSettingsWindow = { settings.show() }
            model.openWelcome = { welcome.show() }
            model.desktop.contextMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
            installApplicationMenu()
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                button.image = MenuBarGlyph.image(badge: false)
                button.toolTip = "Taskmaster · a little company"
            }
            item.menu = makeMenu()
            item.menu?.delegate = self
            statusItem = item
            updateBadge = model.$availableUpdate.sink { [weak self] version in
                self?.statusItem?.button?.image = MenuBarGlyph.image(badge: version != nil)
            }
            // A companion starts quietly: the welcome the first time, and the room only if you asked for it.
            if !CommandLine.arguments.contains("--quiet") {
                if !model.preferences.hasOnboarded {
                    welcome.show()
                } else if model.preferences.openRoomAtLaunch {
                    showRoom()
                }
            }
            #if DEBUG
                try DebugLaunch.current?.writeReady(
                    model: model, roomOpen: room?.isVisible == true)
                if let folder = DebugSnapshots.folder {
                    DebugSnapshots.run(into: folder, model: model) { [weak self] in self?.showRoom() }
                }
            #endif
        } catch {
            let alert = NSAlert()
            alert.messageText = "Your companion couldn’t find its way home."
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.flushPreferences()
        model?.desktop.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Opening Taskmaster again (from Finder, Spotlight or Launchpad) shows the room.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showRoom()
        return true
    }

    @objc func showRoom() {
        guard let model else { return }
        if room == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 790),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "Taskmaster · A little company"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(calibratedRed: 0.985, green: 0.973, blue: 0.95, alpha: 1)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CompanionRoom(model: model))
            // The room scrolls, so it can open smaller than its content on short or scaled displays.
            window.contentMinSize = NSSize(width: 760, height: 460)
            let visible =
                (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? NSSize(width: 840, height: 790)
            window.setContentSize(NSSize(width: min(840, visible.width - 40), height: min(860, visible.height - 40)))
            window.center()
            window.setFrameAutosaveName("CompanionRoom")
            room = window
        }
        NSApp.activate(ignoringOtherApps: true)
        room?.makeKeyAndOrderFront(nil)
        // No control starts focused, so the room opens without a focus ring; Tab still moves through it.
        room?.makeFirstResponder(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let updated = makeMenu()
        menu.removeAllItems()
        for item in updated.items {
            updated.removeItem(item)
            menu.addItem(item)
        }
    }

    /// The menu bar paw's menu, also shown when you right-click the companion.
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        guard let model else { return menu }
        let name = model.preferences.sanitized().name
        let heading = NSMenuItem(
            title: "\(name) · \(model.isPaused ? "Paused" : model.preferences.personality.title)",
            action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        if let version = model.availableUpdate {
            add(
                "Update to Taskmaster \(version)…", action: #selector(checkForUpdates), to: menu,
                symbol: "arrow.down.circle")
        }
        menu.addItem(.separator())

        add(
            model.state == .highFive ? "Return the high five" : "Pet \(name)", action: #selector(pet), to: menu,
            symbol: "heart")
        add("Give a treat", action: #selector(treat), to: menu, symbol: "carrot")
        add(
            model.preferences.avatar == .toothless ? "Play with plasma" : "Play with a ball", action: #selector(play),
            to: menu, symbol: "tennisball")
        add(
            model.state == .sleeping ? "Wake up gently" : "Time for a nap", action: #selector(nap), to: menu,
            symbol: "moon.zzz")
        let games = NSMenu()
        add("A tiny high five", action: #selector(highFive), to: games, symbol: "hand.raised.fill")
        add(
            model.isFollowingCursor ? "Stop following the cursor" : "Follow my cursor for a minute",
            action: #selector(follow), to: games, symbol: "cursorarrow.motionlines")
        add("Hide and seek", action: #selector(hideAndSeek), to: games, symbol: "eye.slash")
        add("Find a hidden snack", action: #selector(findTreat), to: games, symbol: "sparkle.magnifyingglass")
        // While flying, the signature item lands instead of extending the flight.
        add(
            model.state == .flying ? "Land gently" : model.preferences.avatar.signature,
            action: model.state == .flying ? #selector(land) : #selector(signature), to: games,
            symbol: model.preferences.avatar.symbol)
        add("Have a stretch", action: #selector(stretch), to: games, symbol: "figure.flexibility")
        add("A little surprise", action: #selector(surprise), to: games, symbol: "sparkles")
        submenu("Games", games, to: menu, symbol: "gamecontroller")
        add(
            model.deliveryPhase == nil ? "Bring me a meme" : "Put the meme away", action: #selector(deliverMeme),
            to: menu, symbol: "photo.on.rectangle")
        if model.deliveryPhase == .displaying {
            add("Keep it 30 seconds longer", action: #selector(keepMeme), to: menu, symbol: "clock.badge.plus")
            add("See it bigger", action: #selector(openMeme), to: menu, symbol: "arrow.up.left.and.arrow.down.right")
        }
        add(
            model.focusActive ? "End quiet focus" : "Focus together · \(model.preferences.focusMinutes) min",
            action: #selector(toggleFocus), to: menu, symbol: "leaf")
        menu.addItem(.separator())

        let moods = NSMenu()
        for (index, personality) in Personality.allCases.enumerated() {
            let item = NSMenuItem(title: personality.title, action: #selector(selectMood(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = personality == model.preferences.personality ? .on : .off
            item.image = NSImage(systemSymbolName: personality.symbol, accessibilityDescription: nil)
            moods.addItem(item)
        }
        submenu("Mood", moods, to: menu, symbol: model.preferences.personality.symbol)
        add("Come to my pointer", action: #selector(comeHere), to: menu, symbol: "arrow.down.to.line")
        if NSScreen.screens.count > 1 {
            let displays = NSMenu()
            for (index, screen) in NSScreen.screens.enumerated() {
                let item = NSMenuItem(
                    title: screen.localizedName, action: #selector(moveToDisplay(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.state = DesktopController.displayID(screen) == model.desktop.currentDisplayID ? .on : .off
                displays.addItem(item)
            }
            submenu("Move to display", displays, to: menu, symbol: "display.2")
        }
        add("Wipe pawprints", action: #selector(wipe), to: menu, symbol: "pawprint")
        add(
            model.isPaused ? "Let’s wander · Resume" : "Settle down · Pause", action: #selector(pause), to: menu,
            symbol: model.isPaused ? "play" : "pause")
        add(
            model.isVisible ? "Tuck away · Hide" : "Bring back · Show", action: #selector(toggleVisible), to: menu,
            symbol: model.isVisible ? "eye.slash" : "eye")
        menu.addItem(.separator())

        add("Companion Room", action: #selector(showRoom), to: menu, symbol: "house")
        add("Settings…", action: #selector(openSettings), to: menu, symbol: "gearshape", key: ",")
        if model.updater.isAvailable, model.availableUpdate == nil {
            add("Check for Updates…", action: #selector(checkForUpdates), to: menu)
        }
        add("Quit Taskmaster", action: #selector(quit), to: menu, key: "q")
        return menu
    }

    private func add(_ title: String, action: Selector, to menu: NSMenu, symbol: String? = nil, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
    }

    private func submenu(_ title: String, _ submenu: NSMenu, to menu: NSMenu, symbol: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.submenu = submenu
        menu.addItem(item)
    }

    /// The menus shown while one of Taskmaster's windows is in front, so the usual shortcuts work.
    private func installApplicationMenu() {
        let main = NSMenu()
        let appMenu = NSMenu(title: "Taskmaster")
        add("About Taskmaster", action: #selector(showAbout), to: appMenu)
        if model?.updater.isAvailable == true {
            add("Check for Updates…", action: #selector(checkForUpdates), to: appMenu)
        }
        appMenu.addItem(.separator())
        add("Settings…", action: #selector(openSettings), to: appMenu, key: ",")
        add("Companion Room", action: #selector(showRoom), to: appMenu, key: "0")
        appMenu.addItem(.separator())
        add("Quit Taskmaster", action: #selector(quit), to: appMenu, key: "q")
        submenu("Taskmaster", appMenu, to: main, symbol: "pawprint")

        let edit = NSMenu(title: "Edit")
        for (name, selector, key) in [
            ("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
        ] {
            edit.addItem(withTitle: name, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        let editRoot = NSMenuItem()
        editRoot.submenu = edit
        main.addItem(editRoot)

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowRoot = NSMenuItem()
        windowRoot.submenu = window
        main.addItem(windowRoot)
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "A little company. A little mischief.",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        ])
    }

    @objc private func selectMood(_ item: NSMenuItem) { model?.select(Personality.allCases[item.tag]) }
    @objc private func openSettings() { model?.openSettings(model?.settingsPane ?? .general) }
    @objc private func toggleFocus() {
        if model?.focusActive == true { model?.stopFocus() } else { model?.startFocus() }
    }
    @objc private func deliverMeme() {
        if model?.deliveryPhase == nil { model?.bringMeme() } else { model?.putMemeAway() }
    }
    @objc private func treat() { model?.perform(.treat) }
    @objc private func pet() { model?.perform(.pet) }
    @objc private func play() { model?.perform(.play) }
    @objc private func nap() { model?.toggleNap() }
    @objc private func surprise() { model?.perform(.surprise) }
    @objc private func highFive() { model?.perform(.offerHighFive) }
    @objc private func follow() {
        guard let model else { return }
        model.perform(model.isFollowingCursor ? .stopFollowing : .followCursor)
    }
    @objc private func hideAndSeek() { model?.perform(.hideAndSeek) }
    @objc private func findTreat() { model?.perform(.findTreat) }
    @objc private func comeHere() { model?.desktop.callToPointer() }
    @objc private func signature() { model?.perform(.signature) }
    @objc private func land() { model?.perform(.stopFollowing) }
    @objc private func keepMeme() { model?.keepMemeLonger() }
    @objc private func openMeme() { model?.openDeliveredMeme() }
    @objc private func moveToDisplay(_ item: NSMenuItem) {
        guard NSScreen.screens.indices.contains(item.tag) else { return }
        model?.isVisible = true
        model?.desktop.moveCompanion(to: NSScreen.screens[item.tag])
    }
    @objc private func stretch() { model?.perform(.stretch) }
    @objc private func wipe() { model?.wipePawprints() }
    @objc private func pause() { model?.isPaused.toggle() }
    @objc private func toggleVisible() { model?.isVisible.toggle() }
    @objc private func checkForUpdates() { model?.updater.checkForUpdates() }
    @objc private func quit() { NSApp.terminate(nil) }
}
