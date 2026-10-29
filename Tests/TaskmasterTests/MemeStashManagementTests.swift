import AppKit
import Foundation
import ImageIO
import Testing

@testable import Taskmaster

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("TaskmasterStash-\(UUID())")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func tinyPNG(at url: URL) throws {
    let context = try #require(
        CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    let writer = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(writer, try #require(context.makeImage()), nil)
    #expect(CGImageDestinationFinalize(writer))
}

@Test @MainActor func cardsCanBeRenamedAndADeletionUndone() async throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("cat.png")
    try tinyPNG(at: source)
    let library = MemeLibrary(directory: root)
    let item = try await library.importFile(source)

    library.rename(item.id, to: "   Very serious cat   ")
    library.rename(item.id, to: "   ")
    #expect(library.items.first { $0.id == item.id }?.title == "Very serious cat")
    #expect(MemeLibrary(directory: root).items.first { $0.id == item.id }?.title == "Very serious cat")

    let file = root.appendingPathComponent("Memes").appendingPathComponent(try #require(item.fileName))
    let position = try #require(library.items.firstIndex { $0.id == item.id })
    library.remove(library.items[position])
    #expect(!library.items.contains { $0.id == item.id })
    #expect(!FileManager.default.fileExists(atPath: file.path))
    library.undoRemove()
    #expect(library.items.firstIndex { $0.id == item.id } == position)
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(library.lastRemoved == nil)
}

@Test @MainActor func saveFailuresAreReportedAndClearedByASuccessfulRetry() throws {
    let root = try temporaryFolder()
    let memes = root.appendingPathComponent("Memes")
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: memes.path)
        try? FileManager.default.removeItem(at: root)
    }
    let library = MemeLibrary(directory: root)
    #expect(library.problem == nil)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: memes.path)
    library.setEnabled("starter-snacks", false)
    #expect(library.problem != nil)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: memes.path)
    library.retrySave()
    #expect(library.problem == nil)
    #expect(MemeLibrary(directory: root).items.first { $0.id == "starter-snacks" }?.enabled == false)
}

@Test @MainActor func loadingDropsDuplicatesAndRestoringStartersRespectsTheLimit() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let memes = root.appendingPathComponent("Memes")
    try FileManager.default.createDirectory(at: memes, withIntermediateDirectories: true)
    var entries: [MemeItem] = []
    for _ in 0..<(MemeLibrary.capacity - 1) {
        let id = UUID().uuidString
        try tinyPNG(at: memes.appendingPathComponent("\(id).png"))
        entries.append(MemeItem(id: id, title: "Card", fileName: "\(id).png"))
    }
    entries.append(entries[0])
    try JSONEncoder().encode(entries).write(to: memes.appendingPathComponent("library.json"))

    let library = MemeLibrary(directory: root)
    #expect(library.items.count == MemeLibrary.capacity - 1)
    #expect(Set(library.items.map(\.id)).count == library.items.count)
    library.restoreStarters()
    #expect(library.items.count == MemeLibrary.capacity)
}

@Test func importSummariesNameEveryProblem() {
    #expect(AppModel.importSummary(added: 1, total: 1, failures: [], stopped: false).hasPrefix("Added 1 image."))
    let mixed = AppModel.importSummary(
        added: 2, total: 7, failures: ["a.png: bad", "b.png: bad", "c.png: bad", "d.png: bad", "e.png: bad"],
        stopped: false)
    #expect(mixed.contains("Added 2 of 7") && mixed.contains("a.png") && mixed.contains("…and 2 more."))
    #expect(AppModel.importSummary(added: 3, total: 9, failures: [], stopped: true) == "Stopped after adding 3 images.")
}
