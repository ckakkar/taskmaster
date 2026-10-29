#if DEBUG
    import AppKit

    /// `--debug-snapshots <folder>`: opens the welcome, the room (tall and short) and every Settings pane, saves
    /// each window as a PNG and quits. For reviewing layouts and refreshing README screenshots. Only Taskmaster's
    /// own windows are captured (by window number, so SpriteKit and sidebar materials appear as on screen); this
    /// needs Screen Recording permission for the launching terminal. Use with `TASKMASTER_STATE_DIR`.
    @MainActor
    enum DebugSnapshots {
        static var folder: URL? {
            let arguments = CommandLine.arguments
            guard let index = arguments.firstIndex(of: "--debug-snapshots"), index + 1 < arguments.count else {
                return nil
            }
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }

        static func run(into folder: URL, model: AppModel, showRoom: @escaping () -> Void) {
            Task { @MainActor in
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                func settle() async { try? await Task.sleep(for: .seconds(1.2)) }
                await settle()
                if !model.preferences.hasOnboarded { save(frontWindow, as: "welcome", in: folder) }
                frontWindow?.close()
                showRoom()
                let room = frontWindow
                room?.setContentSize(NSSize(width: 840, height: 860))
                await settle()
                save(room, as: "room", in: folder)
                room?.setContentSize(NSSize(width: 840, height: 520))
                await settle()
                save(room, as: "room-short", in: folder)
                room?.close()
                for pane in SettingsPane.allCases {
                    model.openSettings(pane)
                    await settle()
                    save(frontWindow, as: "settings-\(pane.rawValue)", in: folder)
                }
                NSApp.terminate(nil)
            }
        }

        /// The app's frontmost titled window; `keyWindow` is nil whenever another app has focus.
        private static var frontWindow: NSWindow? {
            NSApp.orderedWindows.first { $0.isVisible && $0.styleMask.contains(.titled) }
        }

        private static func save(_ window: NSWindow?, as name: String, in folder: URL) {
            guard let window else { return }
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = [
                "-x", "-o", "-l", "\(window.windowNumber)", folder.appendingPathComponent("\(name).png").path,
            ]
            try? capture.run()
            capture.waitUntilExit()
        }
    }
#endif
