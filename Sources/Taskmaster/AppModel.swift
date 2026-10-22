import AppKit
import SwiftUI
import CompanionCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            saveTask?.cancel()
            saveTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self?.savePreferences()
            }
            desktop?.applyPreferences()
            nextAutoMeme = Date().timeIntervalSince1970 + preferences.memeInterval
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
    @Published var customizationSection = CustomizationSection.look
    @Published var imageLink = ""
    @Published var isImporting = false
    @Published var libraryMessage: String?
    @Published private(set) var lastQuip = "Small paws. Big fan of you."
    @Published private(set) var deliveryPhase: DeliveryPhase?
    @Published private(set) var focusActive = false
    @Published private(set) var focusLabel = "A little company while you work."
    @Published private(set) var focusProgress: Double = 0

    let atlas: PetAtlas
    let library: MemeLibrary
    private(set) var desktop: DesktopController!
    weak var previewScene: PetScene?
    weak var appearanceScene: PetScene?
    var previews: [PetScene] { [previewScene, appearanceScene].compactMap { $0 } }
    @Published var chaosMessage: String?
    @Published private(set) var isStealingCursor = false
    var openRoom: (() -> Void)?
    var openCustomization: (() -> Void)?
    var closeCustomization: (() -> Void)?
    private let preferencesURL: URL
    private var lastSound: Double = -10
    private var saveTask: Task<Void, Never>?
    private var focus = FocusSession()
    private var lastServiceSecond = 0
    private var nextAutoMeme = Date().timeIntervalSince1970 + 600

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
        library = MemeLibrary(directory: directory)
        if let data = try? Data(contentsOf: preferencesURL),
           let saved = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = saved.sanitized()
        } else {
            preferences = Preferences()
        }
        desktop = DesktopController(model: self, atlas: atlas)
        nextAutoMeme = Date().timeIntervalSince1970 + preferences.memeInterval
    }

    func select(_ personality: Personality) {
        preferences.mischief = personality.mischief
        if state == .sleeping { perform(.wake) }
    }

    func perform(_ action: PetAction) {
        if focusActive {
            switch action {
            case .pet, .treat, .saySomething: break
            default: stopFocus()
            }
        }
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
        if deliveryPhase != engine.delivery?.phase { deliveryPhase = engine.delivery?.phase }
        if isStealingCursor != (engine.cursorHeist != nil) { isStealingCursor = engine.cursorHeist != nil }
    }

    func playSound() {
        guard preferences.sound, desktop.engine.elapsed - lastSound > 0.4 else { return }
        lastSound = desktop.engine.elapsed
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    func toggleNap() { perform(state == .sleeping ? .wake : .nap) }

    func observe(_ events: [PetEvent]) {
        for event in events { if case .speech(let text) = event { lastQuip = text } }
    }

    func customize(_ section: CustomizationSection) {
        customizationSection = section
        showPreferences = false
        openCustomization?()
    }

    func addQuipPack(chaotic: Bool) {
        let pack = chaotic ? ["this desk has been acquired by {name}.", "urgent: the snack situation is unacceptable.", "i have investigated. it is definitely a problem for tomorrow.", "i am the manager now."]
            : ["one little step is still a step.", "{name} believes in you.", "you don’t have to earn a tiny break.", "drink some water. i’ll keep your place."]
        var lines = preferences.quipLines
        for line in pack where !lines.contains(line) { lines.append(line) }
        preferences.customQuips = lines.joined(separator: "\n")
    }

    func bringMeme(_ item: MemeItem? = nil) {
        guard desktop.engine.delivery == nil else { return }
        guard let chosen = item ?? library.choose() else {
            libraryMessage = "Add an image or enable a card in Miso’s meme stash first."
            customize(.memes)
            return
        }
        stopFocus()
        if isPaused { isPaused = false }
        if !isVisible { isVisible = true }
        desktop.deliver(memeID: chosen.id)
        nextAutoMeme = Date().timeIntervalSince1970 + preferences.memeInterval
    }

    func putMemeAway() { desktop.engine.recallDelivery(); desktop.renderNow() }
    func keepMemeLonger() { desktop.engine.keepDeliveryLonger(); desktop.renderNow() }

    func wipePawprints() { desktop.scene.clearFootprints(); previews.forEach { $0.clearFootprints() } }

    func inviteCursorHeist() {
        desktop.engine.inviteCursorHeist()
        chaosMessage = "Move your pointer near Miso at the bottom of the screen. Click or pull away to take it back."
    }

    func importMemes() {
        let panel = NSOpenPanel()
        panel.title = "Add to Miso’s meme stash"
        panel.prompt = "Add images"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            var count = 0
            for url in panel.urls {
                do { _ = try self.library.importFile(url); count += 1 }
                catch { self.libraryMessage = error.localizedDescription }
            }
            if count > 0 { self.libraryMessage = "Added \(count) image\(count == 1 ? "" : "s"). Your originals stay where they are." }
        }
    }

    func importImageLink() {
        guard !isImporting else { return }
        isImporting = true
        let link = imageLink
        Task { [weak self] in
            guard let self else { return }
            defer { self.isImporting = false }
            do {
                _ = try await self.library.importLink(link)
                self.imageLink = ""
                self.libraryMessage = "Added that image to Miso’s stash."
            } catch { self.libraryMessage = error.localizedDescription }
        }
    }

    func startFocus() {
        desktop.engine.cancelDelivery()
        desktop.engine.perform(.stopFollowing)
        desktop.engine.removeToy()
        focus.start(minutes: preferences.focusMinutes, now: Date().timeIntervalSince1970)
        focusActive = true
        desktop.engine.isFocusing = true
        desktop.applyPreferences()
        if !isVisible { isVisible = true }
        if isPaused { isPaused = false }
        lastServiceSecond = 0
        updateServices()
        desktop.renderNow()
    }

    func stopFocus() {
        focus.cancel()
        focusActive = false
        focusProgress = 0
        focusLabel = "A little company while you work."
        desktop?.engine.isFocusing = false
        desktop?.applyPreferences()
        desktop?.scene.setFocus(text: nil, progress: 0)
        previews.forEach { $0.setFocus(text: nil, progress: 0) }
    }

    func updateServices() {
        let now = Date().timeIntervalSince1970
        guard Int(now) != lastServiceSecond else { return }
        lastServiceSecond = Int(now)
        if focus.update(now: now) {
            stopFocus()
            preferences.completedFocusSessions += 1
            desktop.engine.perform(.breakReminder)
            desktop.renderNow()
        }
        if focus.isActive {
            let remaining = Int(ceil(focus.remaining(at: now)))
            focusLabel = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            focusProgress = focus.progress(at: now)
            desktop.scene.setFocus(text: focusLabel, progress: focusProgress)
            previews.forEach { $0.setFocus(text: focusLabel, progress: focusProgress) }
        }
        if preferences.autoMemes, now >= nextAutoMeme, !focusActive, isVisible, !isPaused,
           desktop.engine.delivery == nil, state != .sleeping, state != .carried, state != .falling {
            nextAutoMeme = now + preferences.memeInterval
            if !library.enabledItems.isEmpty { bringMeme() }
        }
    }

    func flushPreferences() { saveTask?.cancel(); savePreferences() }

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
