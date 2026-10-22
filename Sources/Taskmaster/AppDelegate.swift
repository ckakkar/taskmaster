import AppKit
import SwiftUI
import CompanionCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var room: NSWindow?
    private var customization: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let atlas = try PetAtlas()
            if CommandLine.arguments.contains("--self-check") {
                let sizes = PetPose.allCases.map { pose in
                    let frame = atlas.frame(for: pose)
                    precondition(frame.width > 0 && frame.height > 0)
                    precondition(frame.eyes.allSatisfy { eye in
                        (0...1).contains(eye.center.x) && (0...1).contains(eye.center.y) && eye.radius > 0
                    }, "Eye landmarks must remain inside their trimmed character frame.")
                    return "\(pose): \(frame.width)×\(frame.height), \(frame.eyes.count) animated eyes"
                }
                print("Taskmaster self-check passed: all \(PetPose.allCases.count) transparent character frames loaded.")
                sizes.forEach { print($0) }
                NSApp.terminate(nil)
                return
            }
            let model = AppModel(atlas: atlas)
            self.model = model
            model.openRoom = { [weak self] in self?.showRoom() }
            model.openCustomization = { [weak self] in self?.showCustomization() }
            model.closeCustomization = { [weak self] in self?.model?.flushPreferences(); self?.customization?.close() }
            model.desktop.contextMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
            installApplicationMenu()
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Taskmaster companion controls")
                button.toolTip = "Taskmaster · a little company"
            }
            item.menu = makeMenu()
            item.menu?.delegate = self
            statusItem = item
            if !CommandLine.arguments.contains("--quiet") { showRoom() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Miso couldn’t find its way home."
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) { model?.flushPreferences(); model?.desktop.stop() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showRoom()
        return true
    }

    @objc func showRoom() {
        guard let model else { return }
        if room == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 745),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "Taskmaster · A little company"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(calibratedRed: 0.985, green: 0.973, blue: 0.95, alpha: 1)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CompanionRoom(model: model))
            window.center()
            window.setFrameAutosaveName("CompanionRoom")
            window.contentMinSize = NSSize(width: 790, height: 720)
            if window.contentLayoutRect.height < 720 { window.setContentSize(NSSize(width: 840, height: 745)) }
            room = window
        }
        NSApp.activate(ignoringOtherApps: true)
        room?.makeKeyAndOrderFront(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let updated = makeMenu()
        menu.removeAllItems()
        for item in updated.items {
            updated.removeItem(item)
            menu.addItem(item)
        }
    }

    @objc private func showCustomization() {
        guard let model else { return }
        if customization == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 730),
                                  styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Make Miso yours"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 820, height: 650)
            window.contentView = NSHostingView(rootView: CustomizationView(model: model))
            window.center()
            customization = window
        }
        NSApp.activate(ignoringOtherApps: true)
        customization?.makeKeyAndOrderFront(nil)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        guard let model else { return menu }
        let heading = NSMenuItem(title: "\(model.preferences.sanitized().name) · \(model.isPaused ? "Paused" : model.preferences.personality.title)", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        add("Open companion room…", action: #selector(showRoom), to: menu, symbol: "house")
        add("Make Miso yours…", action: #selector(customizeVoice), to: menu, symbol: "slider.horizontal.3")
        add(model.focusActive ? "End quiet focus" : "Focus together · \(model.preferences.focusMinutes) min", action: #selector(toggleFocus), to: menu, symbol: "leaf")
        add(model.deliveryPhase == nil ? "Bring me a meme" : "Put the meme away", action: #selector(deliverMeme), to: menu, symbol: "photo.on.rectangle")
        menu.addItem(.separator())
        let mood = NSMenuItem(title: "Personality", action: nil, keyEquivalent: "")
        let moods = NSMenu()
        for (index, personality) in Personality.allCases.enumerated() {
            let item = NSMenuItem(title: personality.title, action: #selector(selectMood(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = personality == model.preferences.personality ? .on : .off
            item.image = NSImage(systemSymbolName: personality.symbol, accessibilityDescription: nil)
            moods.addItem(item)
        }
        mood.submenu = moods
        menu.addItem(mood)
        add(model.state == .highFive ? "Return the high five" : "Pet \(model.preferences.sanitized().name)", action: #selector(pet), to: menu, symbol: "heart")
        add("Give a treat", action: #selector(treat), to: menu, symbol: "carrot")
        add("Play with a ball", action: #selector(play), to: menu, symbol: "tennisball")
        add(model.state == .sleeping ? "Wake up gently" : "Time for a nap", action: #selector(nap), to: menu, symbol: "moon.zzz")
        add("A little surprise", action: #selector(surprise), to: menu, symbol: "sparkles")
        add("A tiny high five", action: #selector(highFive), to: menu, symbol: "hand.raised.fill")
        add(model.isFollowingCursor ? "Stop following the cursor" : "Follow my cursor for a minute", action: #selector(follow), to: menu, symbol: "cursorarrow.motionlines")
        add("Find a hidden snack", action: #selector(findTreat), to: menu, symbol: "sparkle.magnifyingglass")
        add("Come to this screen", action: #selector(comeHere), to: menu, symbol: "arrow.down.to.line")
        add("Have a stretch", action: #selector(stretch), to: menu, symbol: "figure.flexibility")
        add("Muddy zoomies", action: #selector(zoomies), to: menu, symbol: "hare")
        add("Wipe pawprints", action: #selector(wipe), to: menu, symbol: "sparkles")
        menu.addItem(.separator())
        add(model.isPaused ? "Let’s wander" : "Settle down", action: #selector(pause), to: menu, symbol: model.isPaused ? "play" : "pause")
        add(model.isVisible ? "Tuck away" : "Bring back", action: #selector(toggleVisible), to: menu, symbol: model.isVisible ? "eye.slash" : "eye")
        menu.addItem(.separator())
        add("Quit Taskmaster", action: #selector(quit), to: menu, key: "q")
        return menu
    }

    private func add(_ title: String, action: Selector, to menu: NSMenu, symbol: String? = nil, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let root = NSMenuItem()
        let appMenu = NSMenu(title: "Taskmaster")
        add("Companion room…", action: #selector(showRoom), to: appMenu, key: ",")
        add("Make Miso yours…", action: #selector(customizeVoice), to: appMenu, key: ";")
        appMenu.addItem(.separator())
        add("Quit Taskmaster", action: #selector(quit), to: appMenu, key: "q")
        root.submenu = appMenu
        main.addItem(root)
        let editRoot = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (name, selector, key) in [
            ("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
        ] {
            edit.addItem(withTitle: name, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editRoot.submenu = edit
        main.addItem(editRoot)
        NSApp.mainMenu = main
    }

    @objc private func selectMood(_ item: NSMenuItem) { model?.select(Personality.allCases[item.tag]) }
    @objc private func customizeVoice() { model?.customize(.look) }
    @objc private func toggleFocus() { if model?.focusActive == true { model?.stopFocus() } else { model?.startFocus() } }
    @objc private func deliverMeme() { if model?.deliveryPhase == nil { model?.bringMeme() } else { model?.putMemeAway() } }
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
    @objc private func findTreat() { model?.perform(.findTreat) }
    @objc private func comeHere() { model?.desktop.callToPointer() }
    @objc private func stretch() { model?.perform(.stretch) }
    @objc private func zoomies() { model?.perform(.muddyZoomies) }
    @objc private func wipe() { model?.wipePawprints() }
    @objc private func pause() { model?.isPaused.toggle() }
    @objc private func toggleVisible() { model?.isVisible.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
