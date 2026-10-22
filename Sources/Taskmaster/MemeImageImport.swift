import Foundation
import ImageIO
import UniformTypeIdentifiers

/// All decompression, conversion and streamed downloads run outside the main actor.
enum MemeImageImport {
    static let maximumBytes = 25_000_000

    static func validateSize(_ count: Int) throws {
        guard count <= maximumBytes else { throw MemeLibrary.ImportError.tooLarge }
    }

    static func copy(_ url: URL, into directory: URL) throws -> MemeItem {
        try validateSize(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1600,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary)
        else { throw MemeLibrary.ImportError.notImage }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let fileName = id + ".png"
        let destination = directory.appendingPathComponent(fileName)
        guard
            let writer = CGImageDestinationCreateWithURL(
                destination as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw MemeLibrary.ImportError.cannotSave
        }
        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else {
            try? FileManager.default.removeItem(at: destination)
            throw MemeLibrary.ImportError.cannotSave
        }
        let title = String(url.deletingPathExtension().lastPathComponent.prefix(60))
        return MemeItem(id: id, title: title.isEmpty ? "A little delivery" : title, fileName: fileName)
    }

    static func download(_ url: URL, session: URLSession = .shared) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (stream, response) = try await session.bytes(for: request)
        defer { stream.task.cancel() }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MemeLibrary.ImportError.downloadFailed
        }
        if response.expectedContentLength > 0 { try validateSize(Int(response.expectedContentLength)) }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        let writer = try FileHandle(forWritingTo: temporary)
        var succeeded = false
        defer {
            try? writer.close()
            if !succeeded { try? FileManager.default.removeItem(at: temporary) }
        }
        var buffer = Data()
        buffer.reserveCapacity(65_536)
        var count = 0
        for try await byte in stream {
            count += 1
            try validateSize(count)
            buffer.append(byte)
            if buffer.count == 65_536 {
                try writer.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty { try writer.write(contentsOf: buffer) }
        succeeded = true
        return temporary
    }
}
