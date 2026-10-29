import AppKit
import Combine
import CompanionCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            // Keep what Settings shows the same as what the companion uses.
            let bounded = preferences.bounded()
            if bounded != preferences { preferences = bounded }
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
    @Published var settingsPane = SettingsPane.general
    @Published var imageLink = ""
    @Published var isImporting = false
    @Published var libraryMessage: String?
    @Published private(set) var lastQuip = "Small paws. Big fan of you."
    @Published private(set) var deliveryPhase: DeliveryPhase?
    @Published private(set) var focusActive = false
    @Published private(set) var focusLabel = "A little company while you work."
    @Published private(set) var focusProgress: Double = 0
    /// A session finished and hasn't been acknowledged yet.
    @Published private(set) var focusFinished = false
    /// Why settings couldn't be read or saved, until a later save succeeds.
    @Published private(set) var preferencesProblem: String?
    @Published private(set) var importProgress: String?

    private(set) var atlas: PetAtlas
    private var atlasCache: [AvatarKind: PetAtlas] = [:]
    let library: MemeLibrary
    private(set) var desktop: DesktopController!
    weak var previewScene: PetScene?
    weak var appearanceScene: PetScene?
    var previews: [PetScene] { [previewScene, appearanceScene].compactMap { $0 } }
    @Published var chaosMessage: String?
    @Published private(set) var isStealingCursor = false
    let updater = Updater()
    /// The version of an update found by a background check, until it's installed or dismissed.
    @Published private(set) var availableUpdate: String?
    var openRoom: (() -> Void)?
    var openSettingsWindow: (() -> Void)?
    var openWelcome: (() -> Void)?
    private let preferencesURL: URL
    private var lastSound: Double = -10
    private var saveTask: Task<Void, Never>?
    private var schedule: CompanionSchedule?
    private var lastServiceSecond = 0
    private var importTask: Task<Void, Never>?
    private var libraryChanges: AnyCancellable?

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
        var unreadable: URL?
        if let data = try? Data(contentsOf: preferencesURL),
            let saved = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            preferences = saved.sanitized().resolvingAvatar(available: Set(AvatarKind.available))
        } else {
            preferences = Preferences()
            // Keep a file that can't be read at all, rather than overwriting it with defaults.
            if FileManager.default.fileExists(atPath: preferencesURL.path) {
                let backup = directory.appendingPathComponent(
                    "preferences-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: preferencesURL, to: backup)
                unreadable = backup
            }
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
        updater.onAvailable = { [weak self] version in self?.availableUpdate = version }
        // Views that watch the model also see the stash's problems and notices.
        libraryChanges = library.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        if let unreadable {
            preferencesProblem =
                "Your settings file couldn’t be read, so Taskmaster started fresh. The old file was kept as \(unreadable.lastPathComponent)."
        }
        resumeFocusIfNeeded()
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

    func openSettings(_ pane: SettingsPane) {
        settingsPane = pane
        openSettingsWindow?()
    }

    /// Every setting back to its default; the focus-session count and memes are kept.
    func resetAllSettings() {
        if preferences.avatar != .miso { selectAvatar(.miso) }
        preferences = preferences.resettingSettings()
        flushPreferences()
    }

    /// Where preferences and the meme stash live, shown in Finder.
    func revealDataFolder() {
        let folder = preferencesURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
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
            openSettings(.memes)
            return
        }
        stopFocus()
        if isPaused { isPaused = false }
        if !isVisible { isVisible = true }
        desktop.deliver(memeID: chosen.id)
        schedule?.didDeliver(at: Date().timeIntervalSince1970)
    }

    let memeViewer = MemeViewer()

    func handleCard(_ action: MemeCardNode.CardAction) {
        switch action {
        case .putAway: putMemeAway()
        case .keep: keepMemeLonger()
        case .open: openDeliveredMeme()
        }
    }

    func openDeliveredMeme() {
        guard let id = desktop.engine.delivery?.memeID, let item = library.items.first(where: { $0.id == id })
        else { return }
        openMeme(item)
    }

    func openMeme(_ item: MemeItem) { memeViewer.show(library.image(for: item), title: item.title) }

    // Asking for these should work straight away, even if the companion was settled down or tucked away.
    func putMemeAway() {
        if isPaused { isPaused = false }
        if !isVisible { isVisible = true }
        desktop.engine.recallDelivery()
        desktop.renderNow()
    }
    func keepMemeLonger() {
        if isPaused { isPaused = false }
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
            self.importFiles(panel.urls)
        }
    }

    /// Imports images one by one, with progress, a way to stop, and every failure named.
    func importFiles(_ urls: [URL], title: String? = nil, removeAfterwards: Bool = false) {
        guard !isImporting, !urls.isEmpty else { return }
        isImporting = true
        libraryMessage = nil
        importTask = Task { [weak self] in
            guard let self else { return }
            var added = 0
            var failures: [String] = []
            for (index, url) in urls.enumerated() {
                if Task.isCancelled { break }
                self.importProgress = urls.count == 1 ? "Adding…" : "Adding \(index + 1) of \(urls.count)…"
                do {
                    let item = try await self.library.importFile(url)
                    if let title { self.library.rename(item.id, to: title) }
                    added += 1
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
                if removeAfterwards { try? FileManager.default.removeItem(at: url) }
            }
            self.libraryMessage = Self.importSummary(
                added: added, total: urls.count, failures: failures, stopped: Task.isCancelled)
            self.importProgress = nil
            self.isImporting = false
            self.importTask = nil
        }
    }

    func cancelImport() { importTask?.cancel() }

    nonisolated static func importSummary(added: Int, total: Int, failures: [String], stopped: Bool) -> String {
        let images = "\(added) image\(added == 1 ? "" : "s")"
        if stopped { return "Stopped after adding \(images)." }
        if failures.isEmpty { return "Added \(images). Your originals stay where they are." }
        let shown = failures.prefix(3).joined(separator: "\n")
        let more = failures.count > 3 ? "\n…and \(failures.count - 3) more." : ""
        return "Added \(added) of \(total). Couldn’t add:\n\(shown)\(more)"
    }

    /// Adds an image from the clipboard: copied files, or picture data from another app.
    func pasteImage() {
        let pasteboard = NSPasteboard.general
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL], !files.isEmpty
        {
            importFiles(files)
            return
        }
        guard let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            libraryMessage = "There’s no image on the clipboard. Copy a picture or an image file, then try again."
            return
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try png.write(to: temporary)
            importFiles([temporary], title: "Pasted image", removeAfterwards: true)
        } catch {
            libraryMessage = "That image couldn’t be pasted (\(error.localizedDescription))."
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
        let now = Date().timeIntervalSince1970
        schedule?.startFocus(minutes: preferences.focusMinutes, now: now)
        // Remembered, so a relaunch picks the session back up.
        preferences.focusStartedAt = now
        preferences.focusEndsAt = schedule?.focus.deadline ?? 0
        focusFinished = false
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
        if preferences.focusEndsAt != 0 || preferences.focusStartedAt != 0 {
            preferences.focusStartedAt = 0
            preferences.focusEndsAt = 0
        }
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
                readyForDelivery: desktop.engine.isFreeForInterruption && !library.enabledItems.isEmpty))
        if update?.focusCompleted == true {
            stopFocus()
            preferences.completedFocusSessions += 1
            focusFinished = true
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

    func acknowledgeFocus() { focusFinished = false }

    /// Picks up a focus session that was running when Taskmaster quit, or counts one that ended meanwhile.
    private func resumeFocusIfNeeded() {
        guard preferences.focusEndsAt > 0 else { return }
        let now = Date().timeIntervalSince1970
        if preferences.focusEndsAt > now {
            schedule?.resumeFocus(startedAt: preferences.focusStartedAt, deadline: preferences.focusEndsAt)
            focusActive = true
            desktop.engine.isFocusing = true
            desktop.applyPreferences()
            lastServiceSecond = 0
            updateServices()
        } else {
            preferences.focusStartedAt = 0
            preferences.focusEndsAt = 0
            preferences.completedFocusSessions += 1
            focusFinished = true
        }
    }

    func flushPreferences() {
        saveTask?.cancel()
        savePreferences()
    }

    func retrySaving() {
        flushPreferences()
        library.retrySave()
    }

    func dismissProblem() {
        preferencesProblem = nil
        library.dismissProblem()
    }

    private func savePreferences() {
        do {
            try FileManager.default.createDirectory(
                at: preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences.sanitized()).write(to: preferencesURL, options: .atomic)
            if preferencesProblem?.hasPrefix("Settings couldn’t be saved") == true { preferencesProblem = nil }
        } catch {
            NSLog("Taskmaster could not save preferences: %@", error.localizedDescription)
            preferencesProblem = "Settings couldn’t be saved (\(error.localizedDescription))."
        }
    }
}
