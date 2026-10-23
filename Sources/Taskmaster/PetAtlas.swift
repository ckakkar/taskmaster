import AppKit
import CompanionCore
import SpriteKit

enum PetPose: Int, CaseIterable {
    case standing, walkA, walkB, sitting, sleeping, carried, delighted, playBow, mischievous, highFive
}

@MainActor
final class PetAtlas {
    private struct Layout: Decodable {
        struct Neck: Decodable {
            let x: Double
            let y: Double
            let width: Double
            let angle: Double
        }
        struct Eye: Decodable {
            let x: Double
            let y: Double
            let radius: Double
            let aspect: Double?
        }
        struct Region: Decodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
            let eyes: [Eye]?
            let neck: Neck?
            let paw: Gesture.Landmark?
        }
        let sourceWidth: Double
        let sourceHeight: Double
        let frames: [Region]
        struct Gesture: Decodable {
            struct Landmark: Decodable {
                let x: Double
                let y: Double
            }
            let sourceWidth: Double
            let sourceHeight: Double
            let eyes: [Eye]
            let paw: Landmark
            let relativeScale: Double
            let neck: Neck
        }
        let highFive: Gesture?
    }
    struct Frame {
        struct Eye {
            /// Landmarks without an aspect describe Miso's slightly wide painted eyes.
            static let defaultAspect: Float = 1 / 0.88
            let center: SIMD2<Float>
            /// Vertical radius in texture pixels; the horizontal radius is `radius * aspect`.
            let radius: Float
            var aspect: Float = defaultAspect
        }
        let image: CGImage
        let texture: SKTexture
        let alpha: [UInt8]
        let width: Int
        let height: Int
        let eyes: [Eye]
        var artworkScale: Double = 1
        var paw: SIMD2<Float>? = nil
        struct Neck {
            let center: SIMD2<Float>
            let width: Float
            let angle: Double
        }
        var neck: Neck? = nil

        func contains(x: Double, y: Double) -> Bool {
            guard x >= 0, y >= 0, x < 1, y < 1 else { return false }
            let px = min(width - 1, Int(x * Double(width)))
            let py = min(height - 1, Int((1 - y) * Double(height)))
            return alpha[py * width + px] > 45
        }
    }

    let avatar: AvatarKind
    private(set) var frames: [PetPose: Frame] = [:]
    let standingHeight: Double
    let maximumFrameHeight: Double
    private var coatTextures: [String: SKTexture] = [:]

    init(avatar: AvatarKind = .miso) throws {
        self.avatar = avatar
        let resources: Bundle
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Taskmaster_Taskmaster.bundle"),
                let bundle = Bundle(url: bundleURL)
            else { throw ArtError.missingAtlas }
            resources = bundle
        } else {
            resources = Bundle.module
        }
        guard let url = resources.url(forResource: avatar.atlasName, withExtension: "png"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ArtError.missingAtlas }
        guard let layoutURL = resources.url(forResource: avatar.atlasName, withExtension: "json") else {
            throw ArtError.missingAtlas
        }
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: layoutURL))
        guard [9, 10].contains(layout.frames.count),
            layout.sourceWidth > 0, layout.sourceHeight > 0
        else { throw ArtError.invalidFrame }

        for pose in PetPose.allCases where pose.rawValue < layout.frames.count {
            let region = layout.frames[pose.rawValue]
            let sx = Double(sheet.width) / layout.sourceWidth
            let sy = Double(sheet.height) / layout.sourceHeight
            let rectangle = CGRect(
                x: region.x * sx, y: region.y * sy, width: region.width * sx, height: region.height * sy
            ).integral
            guard rectangle.minX >= 0, rectangle.minY >= 0,
                rectangle.maxX <= Double(sheet.width), rectangle.maxY <= Double(sheet.height),
                rectangle.width > 0, rectangle.height > 0,
                let cell = sheet.cropping(to: rectangle)
            else {
                throw ArtError.invalidFrame
            }
            let width = cell.width
            let height = cell.height
            let pixels = Self.rgba(cell)
            let bounds = Self.opaqueBounds(pixels, width: width, height: height)
            guard let trimmed = cell.cropping(to: bounds) else { throw ArtError.invalidFrame }
            let trimmedPixels = Self.rgba(trimmed)
            let alpha = stride(from: 3, to: trimmedPixels.count, by: 4).map { trimmedPixels[$0] }
            let texture = SKTexture(cgImage: trimmed)
            texture.filteringMode = .linear
            let originX = Double(rectangle.minX + bounds.minX)
            let originY = Double(rectangle.minY + bounds.minY)
            func landmark(_ x: Double, _ y: Double) -> SIMD2<Float> {
                let px = (x * sx - originX) / Double(trimmed.width)
                let py = 1 - (y * sy - originY) / Double(trimmed.height)
                return SIMD2(Float(px), Float(py))
            }
            let eyes: [Frame.Eye] = (region.eyes ?? []).map {
                Frame.Eye(
                    center: landmark($0.x, $0.y), radius: Float($0.radius * sx),
                    aspect: $0.aspect.map(Float.init) ?? Frame.Eye.defaultAspect)
            }
            let paw: SIMD2<Float>? = region.paw.map { landmark($0.x, $0.y) }
            let neck: Frame.Neck? = region.neck.map {
                Frame.Neck(
                    center: landmark($0.x, $0.y),
                    width: Float($0.width * sx / Double(trimmed.width)), angle: $0.angle)
            }
            frames[pose] = Frame(
                image: trimmed, texture: texture, alpha: alpha,
                width: trimmed.width, height: trimmed.height, eyes: eyes, paw: paw, neck: neck)
        }
        if layout.frames.count == 9 {
            // The new gesture has its own transparent image and scale reference.
            if let url = resources.url(forResource: "MisoHighFive", withExtension: "png"),
                let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            {
                let bounds = Self.opaqueBounds(Self.rgba(image), width: image.width, height: image.height)
                guard let trimmed = image.cropping(to: bounds) else { throw ArtError.invalidFrame }
                let data = Self.rgba(trimmed)
                let texture = SKTexture(cgImage: trimmed)
                texture.filteringMode = .linear
                guard let metadata = layout.highFive else { throw ArtError.invalidFrame }
                guard metadata.sourceWidth > 0, metadata.sourceHeight > 0,
                    metadata.relativeScale > 0, metadata.eyes.count == 2
                else { throw ArtError.invalidFrame }
                func landmark(_ x: Double, _ y: Double) -> SIMD2<Float> {
                    let px = x / metadata.sourceWidth * Double(image.width) - Double(bounds.minX)
                    let py = y / metadata.sourceHeight * Double(image.height) - Double(bounds.minY)
                    return SIMD2(Float(px / Double(trimmed.width)), Float(1 - py / Double(trimmed.height)))
                }
                let eyes = metadata.eyes.map {
                    Frame.Eye(
                        center: landmark($0.x, $0.y),
                        radius: Float($0.radius / metadata.sourceWidth * Double(image.width)),
                        aspect: $0.aspect.map(Float.init) ?? Frame.Eye.defaultAspect)
                }
                let artworkScale = Double(frames[.sitting]!.height) * metadata.relativeScale / Double(trimmed.height)
                frames[.highFive] = Frame(
                    image: trimmed, texture: texture,
                    alpha: stride(from: 3, to: data.count, by: 4).map { data[$0] },
                    width: trimmed.width, height: trimmed.height, eyes: eyes,
                    artworkScale: artworkScale, paw: landmark(metadata.paw.x, metadata.paw.y),
                    neck: Frame.Neck(
                        center: landmark(metadata.neck.x, metadata.neck.y),
                        width: Float(
                            metadata.neck.width / metadata.sourceWidth * Double(image.width) / Double(trimmed.width)),
                        angle: metadata.neck.angle))
            } else {
                throw ArtError.missingAtlas
            }
        }
        standingHeight = Double(frames[.standing]?.height ?? 300)
        maximumFrameHeight = frames.values.map { Double($0.height) * $0.artworkScale }.max() ?? 400
    }

    func frame(for pose: PetPose) -> Frame { frames[pose]! }

    func texture(for pose: PetPose, coat: CoatStyle) -> SKTexture {
        let frame = frame(for: pose)
        guard avatar == .miso, coat != .cinnamon else { return frame.texture }
        let key = "\(pose.rawValue)-\(coat.rawValue)"
        if let cached = coatTextures[key] { return cached }
        var pixels = Self.rgba(frame.image)
        CoatPalette.recolor(&pixels, style: coat)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
            let image = CGImage(
                width: frame.width, height: frame.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return frame.texture }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        coatTextures[key] = texture
        return texture
    }

    func pose(for engine: PetEngine, reducedMotion: Bool) -> PetPose {
        switch engine.state {
        case .idle: .standing
        case .walking: .standing
        case .sitting: .sitting
        case .sleeping: .sleeping
        case .carried, .falling, .flying: .carried
        case .happy: .delighted
        case .playing, .curious: .playBow
        case .scheming: .mischievous
        case .highFive: .highFive
        case .stretching, .sniffing: .playBow
        }
    }

    private static func rgba(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { bytes in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return }
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
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0
            while let index = stack.popLast() {
                count += 1
                let x = index % width
                let y = index / width
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                let neighbors = [
                    x > 0 ? index - 1 : -1, x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1, y + 1 < height ? index + width : -1,
                ]
                for next in neighbors where next >= 0 && !visited[next] && rgba[next * 4 + 3] > 90 {
                    visited[next] = true
                    stack.append(next)
                }
            }
            if count > largest {
                largest = count
                minX = max(0, minX - 4)
                minY = max(0, minY - 4)
                maxX = min(width - 1, maxX + 4)
                maxY = min(height - 1, maxY + 4)
                best = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            }
        }
        return best
    }

    enum ArtError: LocalizedError {
        case missingAtlas, invalidFrame
        var errorDescription: String? {
            "The companion’s artwork could not be loaded. Rebuild the application bundle."
        }
    }
}
