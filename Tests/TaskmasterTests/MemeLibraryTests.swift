import AppKit
import Foundation
import ImageIO
import Testing

@testable import Taskmaster

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("TaskmasterTests-\(UUID())")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func imageFixture(in directory: URL) throws -> URL {
    let context = try #require(
        CGContext(
            data: nil, width: 2048, height: 2048, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2048, height: 2048))
    let image = try #require(context.makeImage())
    let url = directory.appendingPathComponent("original.png")
    let writer = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(writer, image, nil)
    #expect(CGImageDestinationFinalize(writer))
    return url
}

@Test @MainActor func corruptMemeIndexRecoversOwnedImagesAndKeepsTheDamagedIndex() async throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let fixture = try imageFixture(in: root)
    let library = MemeLibrary(directory: root)
    let item = try await library.importFile(fixture)
    let directory = root.appendingPathComponent("Memes")
    let index = directory.appendingPathComponent("library.json")
    try Data("damaged json".utf8).write(to: index)
    let recovered = MemeLibrary(directory: root)
    #expect(recovered.items.contains { $0.id == item.id && $0.fileName == item.fileName })
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path).contains {
            $0.hasPrefix("library-corrupt-")
        })
    recovered.setEnabled(item.id, false)
    let reopened = MemeLibrary(directory: root)
    #expect(reopened.items.first { $0.id == item.id }?.enabled == false)
    #expect(FileManager.default.fileExists(atPath: fixture.path))
}

@Test @MainActor func imageImportYieldsTheMainActorAndNormalizesACopy() async throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let fixture = try imageFixture(in: root)
    let original = try Data(contentsOf: fixture)
    let library = MemeLibrary(directory: root)
    var mainActorRan = false
    let heartbeat = Task { @MainActor in mainActorRan = true }
    let item = try await library.importFile(fixture)
    #expect(mainActorRan)
    await heartbeat.value
    let copy = root.appendingPathComponent("Memes").appendingPathComponent(try #require(item.fileName))
    let source = try #require(CGImageSourceCreateWithURL(copy as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(max(image.width, image.height) <= 1600)
    #expect(try Data(contentsOf: fixture) == original)
}

@Test @MainActor func oversizedAndInvalidImagesDoNotChangeTheStash() async throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = MemeLibrary(directory: root)
    let url = root.appendingPathComponent("invalid.png")
    try Data("not an image".utf8).write(to: url)
    let count = library.items.count
    await #expect(throws: (any Error).self) { _ = try await library.importFile(url) }
    try Data(repeating: 0, count: MemeImageImport.maximumBytes + 1).write(to: url)
    await #expect(throws: (any Error).self) { _ = try await library.importFile(url) }
    #expect(library.items.count == count)
}

private final class ImageDownloadProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let declared = request.url!.lastPathComponent == "declared"
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: declared ? ["Content-Length": "25000001"] : [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !declared {
            let chunk = Data(repeating: 1, count: 65536)
            for _ in 0..<383 { client?.urlProtocol(self, didLoad: chunk) }
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func imageDownloadsRejectBothDeclaredAndStreamedOversizeBodies() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ImageDownloadProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    for path in ["declared", "streamed"] {
        do {
            let result = try await MemeImageImport.download(
                URL(string: "https://test.invalid/\(path)")!, session: session)
            try? FileManager.default.removeItem(at: result)
            Issue.record("Accepted an oversized image")
        } catch MemeLibrary.ImportError.tooLarge {
            // Expected: reject both oversized response types.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
