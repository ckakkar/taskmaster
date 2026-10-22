import AppKit
import SwiftUI
import CompanionCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var room: NSWindow?

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
                print("Taskmaster self-check passed: all nine transparent character frames loaded.")
                sizes.forEach { print($0) }
                NSApp.terminate(nil)
                return
            }
            let model = AppModel(atlas: atlas)
            self.model = model
            model.openRoom = { [weak self] in self?.showRoom() }
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

    func applicationWillTerminate(_ notification: Notification) { model?.desktop.stop() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showRoom()
        return true
    }

    @objc func showRoom() {
        guard let model else { return }
        if room == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 650),
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

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        guard let model else { return menu }
        let heading = NSMenuItem(title: "\(model.preferences.sanitized().name) · \(model.isPaused ? "Paused" : model.preferences.personality.title)", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        add("Open companion room…", action: #selector(showRoom), to: menu, symbol: "house")
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
        add("Give a treat", action: #selector(treat), to: menu, symbol: "carrot")
        add("Play with a ball", action: #selector(play), to: menu, symbol: "tennisball")
        add(model.state == .sleeping ? "Wake up gently" : "Time for a nap", action: #selector(nap), to: menu, symbol: "moon.zzz")
        add("A little surprise", action: #selector(surprise), to: menu, symbol: "sparkles")
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
    @objc private func treat() { model?.perform(.treat) }
    @objc private func play() { model?.perform(.play) }
    @objc private func nap() { model?.toggleNap() }
    @objc private func surprise() { model?.perform(.surprise) }
    @objc private func pause() { model?.isPaused.toggle() }
    @objc private func toggleVisible() { model?.isVisible.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
