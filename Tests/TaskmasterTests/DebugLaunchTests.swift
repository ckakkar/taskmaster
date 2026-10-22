#if DEBUG
    import Testing

    @testable import Taskmaster

    @Test @MainActor func debugLaunchValidatesStatesAndKeepsPreferencesIsolated() throws {
        #expect(try DebugLaunch.parse(["Taskmaster"]) == nil)
        let parsed = try DebugLaunch.parse(["Taskmaster", "--debug-state", "flying", "--debug-avatar", "toothless"])
        let launch = try #require(parsed)
        #expect(launch.state.rawValue == "flying" && launch.avatar.rawValue == "toothless")
        #expect(launch.preferences.name == "Toothless" && launch.preferences.size == 1)
        #expect(!launch.stateDirectory.path.contains("Application Support"))
        for args in [
            ["--debug-state"], ["--debug-avatar", "toothless"], ["--debug-state", "unknown"],
            ["--debug-state", "flying", "--debug-avatar", "miso"],
        ] {
            #expect(throws: DebugLaunch.LaunchError.self) { try DebugLaunch.parse(args) }
        }
    }
#endif
