import AppKit
import SpriteKit
import CompanionCore

enum PetPose: Int, CaseIterable {
    case standing, walkA, walkB, sitting, sleeping, carried, delighted, playBow, mischievous
}

@MainActor
final class PetAtlas {
    private struct Layout: Decodable {
        struct Eye: Decodable { let x: Double; let y: Double; let radius: Double }
        struct Region: Decodable {
            let x: Double; let y: Double; let width: Double; let height: Double
            let eyes: [Eye]?
        }
        let sourceWidth: Double
        let sourceHeight: Double
        let frames: [Region]
    }
    struct Frame {
        struct Eye {
            let center: SIMD2<Float>
            let radius: Float
        }
        let image: CGImage
        let texture: SKTexture
        let alpha: [UInt8]
        let width: Int
        let height: Int
        let eyes: [Eye]

        func contains(x: Double, y: Double) -> Bool {
            guard x >= 0, y >= 0, x < 1, y < 1 else { return false }
            let px = min(width - 1, Int(x * Double(width)))
            let py = min(height - 1, Int((1 - y) * Double(height)))
            return alpha[py * width + px] > 45
        }
    }

    private(set) var frames: [PetPose: Frame] = [:]
    let standingHeight: Double
    let maximumFrameHeight: Double

    init() throws {
        let resources: Bundle
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Taskmaster_Taskmaster.bundle"),
                  let bundle = Bundle(url: bundleURL) else { throw ArtError.missingAtlas }
            resources = bundle
        } else {
            resources = Bundle.module
        }
        guard let url = resources.url(forResource: "MisoAtlas", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ArtError.missingAtlas }
        guard let layoutURL = resources.url(forResource: "MisoAtlas", withExtension: "json") else { throw ArtError.missingAtlas }
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: layoutURL))
        guard layout.frames.count == PetPose.allCases.count,
              layout.sourceWidth > 0, layout.sourceHeight > 0 else { throw ArtError.invalidFrame }

        for pose in PetPose.allCases {
            let region = layout.frames[pose.rawValue]
            let sx = Double(sheet.width) / layout.sourceWidth, sy = Double(sheet.height) / layout.sourceHeight
            let rectangle = CGRect(x: region.x * sx, y: region.y * sy, width: region.width * sx, height: region.height * sy).integral
            guard rectangle.minX >= 0, rectangle.minY >= 0,
                  rectangle.maxX <= Double(sheet.width), rectangle.maxY <= Double(sheet.height),
                  rectangle.width > 0, rectangle.height > 0,
                  let cell = sheet.cropping(to: rectangle) else {
                throw ArtError.invalidFrame
            }
            let width = cell.width, height = cell.height
            let pixels = Self.rgba(cell)
            let bounds = Self.opaqueBounds(pixels, width: width, height: height)
            guard let trimmed = cell.cropping(to: bounds) else { throw ArtError.invalidFrame }
            let trimmedPixels = Self.rgba(trimmed)
            let alpha = stride(from: 3, to: trimmedPixels.count, by: 4).map { trimmedPixels[$0] }
            let texture = SKTexture(cgImage: trimmed)
            texture.filteringMode = .linear
            frames[pose] = Frame(
                image: trimmed, texture: texture, alpha: alpha,
                width: trimmed.width, height: trimmed.height,
                eyes: (region.eyes ?? []).map { eye in
                    Frame.Eye(center: SIMD2(
                        Float((eye.x * sx - rectangle.minX - bounds.minX) / Double(trimmed.width)),
                        Float(1 - (eye.y * sy - rectangle.minY - bounds.minY) / Double(trimmed.height))
                    ), radius: Float(eye.radius * sx))
                }
            )
        }
        standingHeight = Double(frames[.standing]?.height ?? 300)
        maximumFrameHeight = Double(frames.values.map(\.height).max() ?? 400)
    }

    func frame(for pose: PetPose) -> Frame { frames[pose]! }

    func pose(for engine: PetEngine, reducedMotion: Bool) -> PetPose {
        switch engine.state {
        case .idle: .standing
        case .walking:
            reducedMotion ? .standing : (Int(engine.elapsed * 5) % 2 == 0 ? .walkA : .walkB)
        case .sitting: .sitting
        case .sleeping: .sleeping
        case .carried, .falling: .carried
        case .happy: .delighted
        case .playing, .curious: .playBow
        case .scheming: .mischievous
        }
    }

    private static func rgba(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    private static func opaqueBounds(_ rgba: [UInt8], width: Int, height: Int) -> CGRect {
        // Measure the principal connected silhouette, excluding loose wisps
        // and fragments of neighboring poses at an atlas cell's edges.
        var visited = [Bool](repeating: false, count: width * height)
        var largest = 0
        var best = CGRect(x: 0, y: 0, width: width, height: height)
        var stack: [Int] = []
        stack.reserveCapacity(width * height / 2)
        for seed in 0..<(width * height) where !visited[seed] && rgba[seed * 4 + 3] > 90 {
            stack.removeAll(keepingCapacity: true)
            stack.append(seed)
            visited[seed] = true
            var count = 0
            var minX = width, minY = height, maxX = 0, maxY = 0
            while let index = stack.popLast() {
                count += 1
                let x = index % width, y = index / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                let neighbors = [x > 0 ? index - 1 : -1, x + 1 < width ? index + 1 : -1,
                                 y > 0 ? index - width : -1, y + 1 < height ? index + width : -1]
                for next in neighbors where next >= 0 && !visited[next] && rgba[next * 4 + 3] > 90 {
                    visited[next] = true
                    stack.append(next)
                }
            }
            if count > largest {
                largest = count
                minX = max(0, minX - 4); minY = max(0, minY - 4)
                maxX = min(width - 1, maxX + 4); maxY = min(height - 1, maxY + 4)
                best = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            }
        }
        return best
    }

    enum ArtError: LocalizedError {
        case missingAtlas, invalidFrame
        var errorDescription: String? { "Miso’s character artwork could not be loaded. Rebuild the application bundle." }
    }
}
