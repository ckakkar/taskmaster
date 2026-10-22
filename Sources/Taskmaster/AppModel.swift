import AppKit
import CompanionCore
import SwiftUI
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
            schedule?.configure(preferences: preferences, now: Date().timeIntervalSince1970)
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

    private(set) var atlas: PetAtlas
    private var atlasCache: [AvatarKind: PetAtlas] = [:]
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
    private var schedule: CompanionSchedule?
    private var lastServiceSecond = 0

    init(atlas: PetAtlas) {
        self.atlas = atlas
        let environment = ProcessInfo.processInfo.environment
        let directory: URL
        if let override = environment["TASKMASTER_STATE_DIR"] {
            directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            #if DEBUG
                if let launch = DebugLaunch.current {
                    directory = launch.stateDirectory
                } else {
                    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Taskmaster", isDirectory: true)
                }
            #else
                directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Taskmaster", isDirectory: true)
            #endif
        }
        preferencesURL = directory.appendingPathComponent("preferences.json")
        library = MemeLibrary(directory: directory)
        if let data = try? Data(contentsOf: preferencesURL),
            let saved = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            preferences = saved.sanitized().resolvingAvatar(available: Set(AvatarKind.available))
        } else {
            preferences = Preferences()
        }
        #if DEBUG
            if let launch = DebugLaunch.current { preferences = launch.preferences }
        #endif
        atlasCache[atlas.avatar] = atlas
        if preferences.avatar != atlas.avatar {
            if let chosen = art(for: preferences.avatar) { self.atlas = chosen } else { preferences.avatar = .miso }
        }
        desktop = DesktopController(model: self, atlas: self.atlas)
        schedule = CompanionSchedule(preferences: preferences, now: Date().timeIntervalSince1970)
    }

    func select(_ personality: Personality) {
        preferences.mischief = personality.mischief
        if state == .sleeping { perform(.wake) }
    }

    func art(for avatar: AvatarKind) -> PetAtlas? {
        if let cached = atlasCache[avatar] { return cached }
        guard let loaded = try? PetAtlas(avatar: avatar) else { return nil }
        atlasCache[avatar] = loaded
        return loaded
    }

    func selectAvatar(_ avatar: AvatarKind) {
        guard avatar != preferences.avatar, let art = art(for: avatar) else { return }
        desktop.engine.cancelAerialTour()
        desktop.engine.cancelDelivery()
        desktop.engine.perform(.wake)
        desktop.engine.removeToy()
        atlas = art
        if preferences.name == preferences.avatar.title { preferences.name = avatar.title }
        preferences.avatar = avatar
        desktop.renderNow()
    }

    func perform(_ action: PetAction) {
        if focusActive && CompanionSchedule.endsFocus(action) { stopFocus() }
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
        let pack =
            chaotic
            ? [
                "this desk has been acquired by {name}.", "urgent: the snack situation is unacceptable.",
                "i have investigated. it is definitely a problem for tomorrow.", "i am the manager now.",
            ]
            : [
                "one little step is still a step.", "{name} believes in you.", "you don’t have to earn a tiny break.",
                "drink some water. i’ll keep your place.",
            ]
        var lines = preferences.quipLines
        for line in pack where !lines.contains(line) { lines.append(line) }
        preferences.customQuips = lines.joined(separator: "\n")
    }

    func bringMeme(_ item: MemeItem? = nil) {
        guard desktop.engine.delivery == nil else { return }
        guard let chosen = item ?? library.choose() else {
            libraryMessage = "Add an image or enable a card in \(preferences.name)’s meme stash first."
            customize(.memes)
            return
        }
        stopFocus()
        if isPaused { isPaused = false }
        if !isVisible { isVisible = true }
        desktop.deliver(memeID: chosen.id)
        schedule?.didDeliver(at: Date().timeIntervalSince1970)
    }

    func putMemeAway() {
        desktop.engine.recallDelivery()
        desktop.renderNow()
    }
    func keepMemeLonger() {
        desktop.engine.keepDeliveryLonger()
        desktop.renderNow()
    }

    func wipePawprints() {
        desktop.scene.clearFootprints()
        for preview in previews { preview.clearFootprints() }
    }

    func inviteCursorHeist() {
        desktop.engine.inviteCursorHeist()
        chaosMessage =
            "Move your pointer near \(preferences.name) at the bottom of the screen. Click or press Esc to take it back."
    }

    func importMemes() {
        let panel = NSOpenPanel()
        panel.title = "Add to \(preferences.name)’s meme stash"
        panel.prompt = "Add images"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            let urls = panel.urls
            self.isImporting = true
            Task {
                defer { self.isImporting = false }
                var count = 0
                var failure: String?
                for url in urls {
                    do {
                        _ = try await self.library.importFile(url)
                        count += 1
                    } catch { failure = error.localizedDescription }
                }
                self.libraryMessage =
                    "Added \(count) image\(count == 1 ? "" : "s")."
                    + (failure.map { " " + $0 } ?? " Your originals stay where they are.")
            }
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
                self.libraryMessage = "Added that image to \(self.preferences.name)’s stash."
            } catch { self.libraryMessage = error.localizedDescription }
        }
    }

    func startFocus() {
        desktop.engine.cancelDelivery()
        desktop.engine.perform(.stopFollowing)
        desktop.engine.removeToy()
        schedule?.startFocus(minutes: preferences.focusMinutes, now: Date().timeIntervalSince1970)
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
        schedule?.endFocus()
        focusActive = false
        focusProgress = 0
        focusLabel = "A little company while you work."
        desktop?.engine.isFocusing = false
        desktop?.applyPreferences()
        desktop?.scene.setFocus(text: nil, progress: 0)
        for preview in previews { preview.setFocus(text: nil, progress: 0) }
    }

    func updateServices() {
        let now = Date().timeIntervalSince1970
        guard Int(now) != lastServiceSecond else { return }
        lastServiceSecond = Int(now)
        let update = schedule?.update(
            now: now,
            availability: .init(
                visible: isVisible, paused: isPaused,
                readyForDelivery: desktop.engine.delivery == nil && desktop.engine.cursorHeist == nil
                    && desktop.engine.aerialRoute == nil
                    && desktop.engine.state != .sleeping && desktop.engine.state != .carried
                    && desktop.engine.state != .falling && !library.enabledItems.isEmpty))
        if update?.focusCompleted == true {
            stopFocus()
            preferences.completedFocusSessions += 1
            desktop.engine.perform(.breakReminder)
            desktop.renderNow()
        }
        if let focus = schedule?.focus, focus.isActive {
            let remaining = Int(ceil(focus.remaining(at: now)))
            focusLabel = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            focusProgress = focus.progress(at: now)
            desktop.scene.setFocus(text: focusLabel, progress: focusProgress)
            for preview in previews { preview.setFocus(text: focusLabel, progress: focusProgress) }
        }
        if update?.deliverMeme == true { bringMeme() }
    }

    func flushPreferences() {
        saveTask?.cancel()
        savePreferences()
    }

    private func savePreferences() {
        do {
            try FileManager.default.createDirectory(
                at: preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences.sanitized()).write(to: preferencesURL, options: .atomic)
        } catch {
            NSLog("Taskmaster could not save preferences: %@", error.localizedDescription)
        }
    }
}
