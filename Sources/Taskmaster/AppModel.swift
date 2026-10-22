import AppKit
import SwiftUI
import CompanionCore

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            savePreferences()
            desktop?.applyPreferences()
        }
    }
    @Published var isPaused = false {
        didSet { desktop?.engine.isPaused = isPaused || !isVisible }
    }
    @Published var isVisible = true {
        didSet { desktop?.setVisible(isVisible) }
    }
    @Published private(set) var state: PetState = .sitting
    @Published private(set) var interactions = 0
    @Published private(set) var isFollowingCursor = false
    @Published var showPreferences = false

    let atlas: PetAtlas
    private(set) var desktop: DesktopController!
    weak var previewScene: PetScene?
    var openRoom: (() -> Void)?
    private let preferencesURL: URL
    private var lastSound: Double = -10

    init(atlas: PetAtlas) {
        self.atlas = atlas
        let environment = ProcessInfo.processInfo.environment
        let directory: URL
        if let override = environment["TASKMASTER_STATE_DIR"] {
            directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Taskmaster", isDirectory: true)
        }
        preferencesURL = directory.appendingPathComponent("preferences.json")
        if let data = try? Data(contentsOf: preferencesURL),
           let saved = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = saved.sanitized()
        } else {
            preferences = Preferences()
        }
        desktop = DesktopController(model: self, atlas: atlas)
    }

    func select(_ personality: Personality) {
        preferences.mischief = personality.mischief
        if state == .sleeping { perform(.wake) }
    }

    func perform(_ action: PetAction) {
        if isPaused { isPaused = false }
        if !isVisible { isVisible = true }
        desktop.engine.perform(action)
        desktop.renderNow()
        playSound()
    }

    func syncPresentation() {
        guard let desktop else { return }
        let engine = desktop.engine
        if state != engine.state { state = engine.state }
        if interactions != engine.interactionCount { interactions = engine.interactionCount }
        if isFollowingCursor != engine.isFollowingCursor { isFollowingCursor = engine.isFollowingCursor }
    }

    func playSound() {
        guard preferences.sound, desktop.engine.elapsed - lastSound > 0.4 else { return }
        lastSound = desktop.engine.elapsed
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    func toggleNap() { perform(state == .sleeping ? .wake : .nap) }

    private func savePreferences() {
        do {
            try FileManager.default.createDirectory(at: preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences.sanitized()).write(to: preferencesURL, options: .atomic)
        } catch {
            NSLog("Taskmaster could not save preferences: %@", error.localizedDescription)
        }
    }
}
