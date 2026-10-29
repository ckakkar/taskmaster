import AppKit
import ImageIO
import UniformTypeIdentifiers

struct MemeItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    let fileName: String?
    var enabled: Bool = true
    var isStarter: Bool { fileName == nil }
}

/// A card removed a moment ago, kept so the removal can be undone.
struct RemovedMeme {
    let item: MemeItem
    let index: Int
    let trashedFile: URL?
}

@MainActor
final class MemeLibrary: ObservableObject {
    static let capacity = 100
    @Published private(set) var items: [MemeItem] = []
    /// Why the stash couldn't be saved, until a later save succeeds.
    @Published private(set) var problem: String?
    /// Something worth knowing about the stash, such as a recovered list, until dismissed.
    @Published var notice: String?
    @Published private(set) var lastRemoved: RemovedMeme?
    private let directory: URL
    private let indexURL: URL
    private let images = NSCache<NSString, NSImage>()
    private var previousID: String?
    private static let starters = [
        MemeItem(id: "starter-snacks", title: "The snack committee", fileName: nil),
        MemeItem(id: "starter-break", title: "A very serious reminder", fileName: nil),
        MemeItem(id: "starter-paws", title: "Desktop ownership", fileName: nil),
    ]

    init(directory: URL) {
        self.directory = directory.appendingPathComponent("Memes", isDirectory: true)
        indexURL = self.directory.appendingPathComponent("library.json")
        images.countLimit = 12
        images.totalCostLimit = 32_000_000
        if let data = try? Data(contentsOf: indexURL),
            let saved = try? JSONDecoder().decode([MemeItem].self, from: data)
        {
            var seen = Set<String>()
            items = saved.filter { item in
                guard seen.insert(item.id).inserted else { return false }
                guard let name = item.fileName else { return true }
                return Self.isOwnedFile(name)
                    && FileManager.default.fileExists(atPath: self.directory.appendingPathComponent(name).path)
            }
        } else {
            let files =
                (try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: nil))
                ?? []
            items =
                Self.starters
                + files.filter { Self.isOwnedFile($0.lastPathComponent) }.sorted { $0.path < $1.path }.map {
                    MemeItem(
                        id: $0.deletingPathExtension().lastPathComponent, title: "Recovered image",
                        fileName: $0.lastPathComponent)
                }
            // Preserve the damaged index for recovery; never silently overwrite it.
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let backup = self.directory.appendingPathComponent("library-corrupt-\(UUID().uuidString).json")
                try? FileManager.default.copyItem(at: indexURL, to: backup)
                notice =
                    "The meme list was damaged, so it was rebuilt from the images in the stash. Their titles and rotation choices were reset; the old list was kept as \(backup.lastPathComponent)."
            }
            save()
        }
    }

    var enabledItems: [MemeItem] { items.filter(\.enabled) }

    func choose() -> MemeItem? {
        let candidates = enabledItems.filter { $0.id != previousID }
        let item = (candidates.isEmpty ? enabledItems : candidates).randomElement()
        previousID = item?.id
        return item
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].enabled = enabled
        save()
    }

    func rename(_ id: String, to title: String) {
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty, let index = items.firstIndex(where: { $0.id == id }), items[index].title != clean
        else { return }
        items[index].title = clean
        save()
    }

    /// Removes a card and moves its image to the Trash; `undoRemove()` brings both back.
    func remove(_ item: MemeItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items.remove(at: index)
        images.removeObject(forKey: item.id as NSString)
        save()
        var trashed: NSURL?
        if let name = item.fileName, Self.isOwnedFile(name) {
            try? FileManager.default.trashItem(at: directory.appendingPathComponent(name), resultingItemURL: &trashed)
        }
        lastRemoved = RemovedMeme(item: item, index: index, trashedFile: trashed as URL?)
    }

    func undoRemove() {
        guard let removed = lastRemoved, items.count < Self.capacity else { return }
        lastRemoved = nil
        if let name = removed.item.fileName {
            guard let trashed = removed.trashedFile,
                (try? FileManager.default.moveItem(at: trashed, to: directory.appendingPathComponent(name))) != nil
            else {
                notice = "“\(removed.item.title)” couldn’t be brought back from the Trash."
                return
            }
        }
        items.insert(removed.item, at: min(removed.index, items.count))
        save()
    }

    func forgetRemoval() { lastRemoved = nil }

    func importFile(_ url: URL) async throws -> MemeItem {
        guard items.count < Self.capacity else { throw ImportError.stashFull }
        let directory = directory
        let item = try await Task.detached(priority: .userInitiated) { try MemeImageImport.copy(url, into: directory) }
            .value
        guard items.count < Self.capacity else {
            if let name = item.fileName {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
            throw ImportError.stashFull
        }
        items.append(item)
        save()
        return item
    }

    func restoreStarters() {
        for item in Self.starters where items.count < Self.capacity && !items.contains(where: { $0.id == item.id }) {
            items.append(item)
        }
        save()
    }

    func importLink(_ text: String) async throws -> MemeItem {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme?.lowercased() == "https", url.host != nil
        else { throw ImportError.invalidLink }
        let temporary = try await Task.detached(priority: .userInitiated) { try await MemeImageImport.download(url) }
            .value
        defer { try? FileManager.default.removeItem(at: temporary) }
        let imported = try await importFile(temporary)
        if let index = items.firstIndex(where: { $0.id == imported.id }) {
            items[index].title = String(url.deletingPathExtension().lastPathComponent.prefix(60))
            save()
            return items[index]
        }
        return imported
    }

    func image(for item: MemeItem) -> NSImage {
        if let cached = images.object(forKey: item.id as NSString) { return cached }
        let image: NSImage
        if let fileName = item.fileName {
            image = NSImage(contentsOf: directory.appendingPathComponent(fileName)) ?? Self.unreadableImage()
        } else {
            image = Self.starterImage(id: item.id)
        }
        cache(image, id: item.id)
        return image
    }

    private func cache(_ image: NSImage, id: String) {
        let cost = Int(max(1, image.size.width) * max(1, image.size.height) * 4)
        images.setObject(image, forKey: id as NSString, cost: cost)
    }

    private static func isOwnedFile(_ name: String) -> Bool {
        guard name.hasSuffix(".png"), !name.contains("/") else { return false }
        return UUID(uuidString: String(name.dropLast(4))) != nil
    }

    func retrySave() { save() }

    func dismissProblem() { problem = nil }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(items).write(to: indexURL, options: .atomic)
            problem = nil
        } catch {
            NSLog("Could not save the companion’s meme stash: %@", error.localizedDescription)
            problem = "The meme stash couldn’t be saved (\(error.localizedDescription))."
        }
    }

    private static func unreadableImage() -> NSImage {
        NSImage(size: CGSize(width: 640, height: 460), flipped: false) { rect in
            NSColor(calibratedWhite: 0.9, alpha: 1).setFill()
            rect.fill()
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            ("This image couldn’t be read." as NSString).draw(
                in: CGRect(x: 40, y: 200, width: 560, height: 60),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 30, weight: .medium),
                    .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 1), .paragraphStyle: centered,
                ])
            return true
        }
    }

    private static func starterImage(id: String) -> NSImage {
        let size = CGSize(width: 640, height: 460)
        return NSImage(size: size, flipped: false) { rect in
            let green = id == "starter-break"
            NSColor(calibratedRed: green ? 0.87 : 0.98, green: green ? 0.92 : 0.90, blue: green ? 0.85 : 0.78, alpha: 1)
                .setFill()
            rect.fill()
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            let title =
                id == "starter-snacks"
                ? "THE SNACK COMMITTEE" : green ? "A VERY SERIOUS REMINDER" : "OFFICIAL DESKTOP NOTICE"
            let message =
                id == "starter-snacks"
                ? "has reviewed your work.\nmore snacks are recommended."
                : green
                    ? "unclench your jaw.\ndrop your shoulders.\nyou’re doing okay."
                    : "this is my desk now.\nyou may continue using it."
            let ink = NSColor(calibratedRed: 0.27, green: 0.25, blue: 0.20, alpha: 1)
            (title as NSString).draw(
                in: CGRect(x: 35, y: 335, width: 570, height: 36),
                withAttributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold), .foregroundColor: ink,
                    .paragraphStyle: centered,
                ])
            (message as NSString).draw(
                in: CGRect(x: 40, y: 100, width: 560, height: 205),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 36, weight: .medium), .foregroundColor: ink,
                    .paragraphStyle: centered,
                ])
            ("small paws. big opinions." as NSString).draw(
                in: CGRect(x: 40, y: 40, width: 560, height: 30),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 15), .foregroundColor: ink.withAlphaComponent(0.6),
                    .paragraphStyle: centered,
                ])
            return true
        }
    }

    enum ImportError: LocalizedError {
        case tooLarge, notImage, cannotSave, invalidLink, downloadFailed, stashFull
        var errorDescription: String? {
            switch self {
            case .tooLarge: "Choose an image smaller than 25 MB."
            case .notImage: "That file isn’t a supported image. Try PNG, JPEG, GIF or HEIC."
            case .cannotSave: "Couldn’t save a copy of that image."
            case .invalidLink: "Paste a direct HTTPS link to an image."
            case .downloadFailed: "That image link didn’t load. Try another link or add the image from your Mac."
            case .stashFull: "The stash holds 100 images. Remove a card before adding another."
            }
        }
    }
}
