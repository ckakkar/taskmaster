#if DEBUG
    import AppKit
    import CompanionCore

    @MainActor
    struct DebugLaunch {
        static var current: DebugLaunch?
        let state: DebugPetState
        let avatar: AvatarKind

        static func parse(_ arguments: [String]) throws -> DebugLaunch? {
            guard arguments.contains("--debug-state") || arguments.contains("--debug-avatar") else { return nil }
            func value(_ flag: String) throws -> String {
                guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
                    !arguments[index + 1].hasPrefix("--")
                else { throw LaunchError("Missing value for \(flag).") }
                return arguments[index + 1]
            }
            guard let state = DebugPetState(rawValue: try value("--debug-state")) else {
                throw LaunchError("Choose sitting, walking, sleeping or flying.")
            }
            let name = arguments.contains("--debug-avatar") ? try value("--debug-avatar") : "miso"
            guard let avatar = AvatarKind(rawValue: name), AvatarKind.available.contains(avatar) else {
                throw LaunchError("Choose miso or toothless.")
            }
            guard state != .flying || avatar == .toothless else {
                throw LaunchError("Miso cannot fly; use Toothless for flying measurements.")
            }
            return DebugLaunch(state: state, avatar: avatar)
        }

        var stateDirectory: URL {
            FileManager.default.temporaryDirectory.appendingPathComponent("taskmaster-debug-\(getpid())")
        }

        var preferences: Preferences {
            var result = Preferences()
            result.avatar = avatar
            result.name = avatar.title
            result.quietWhenIdle = false
            return result
        }

        func writeReady(model: AppModel, roomOpen: Bool) throws {
            guard let path = ProcessInfo.processInfo.environment["TASKMASTER_DEBUG_READY_FILE"] else { return }
            let screen = NSScreen.main
            let data: [String: Any] = [
                "pid": getpid(), "avatar": avatar.rawValue, "requestedState": state.rawValue,
                "actualState": model.desktop.engine.state.rawValue, "roomOpen": roomOpen,
                "size": model.preferences.size, "mischief": model.preferences.mischief,
                "reducedMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                "screenWidth": screen?.frame.width ?? 0, "screenHeight": screen?.frame.height ?? 0,
                "backingScale": screen?.backingScaleFactor ?? 0,
            ]
            try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        struct LaunchError: LocalizedError {
            let message: String
            init(_ message: String) { self.message = message }
            var errorDescription: String? { message }
        }
    }
#endif
