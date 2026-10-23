import CompanionCore
import Metal
import SpriteKit
import Testing

@testable import Taskmaster

/// SpriteKit draws the plain sprite when a custom shader fails to compile, so a broken
/// shader shows up here as eyes that never change.
@Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "Needs a Metal device to compile the shader"))
@MainActor func eyesBlinkWithFurLidsAndLookAroundWithoutTouchingTheRestOfTheFace() throws {
    for avatar in AvatarKind.available {
        let frame = try PetAtlas(avatar: avatar).frame(for: .sitting)
        try #require(frame.eyes.count == 2)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        let sprite = SKSpriteNode(texture: frame.texture)
        let eyes = EyeShader()
        sprite.shader = eyes.shader

        func render(gaze: Point, blink: Double) throws -> RenderedPixels {
            eyes.update(gaze: gaze, blink: blink, frame: frame, avatar: avatar)
            let texture = try #require(view.texture(from: sprite))
            return RenderedPixels(texture.cgImage())
        }
        let open = try render(gaze: .zero, blink: 0)
        let closed = try render(gaze: .zero, blink: 1)
        let lookingRight = try render(gaze: Point(x: 1, y: 0), blink: 0)

        for eye in frame.eyes {
            let center = (x: Double(eye.center.x), y: Double(eye.center.y))
            let radius = Double(eye.radius) / Double(frame.width)
            #expect(open.difference(from: closed, around: center, radius: radius * 0.6) > 6)
            #expect(open.difference(from: lookingRight, around: center, radius: radius * 0.6) > 1)
        }
        // The near eye's closed upper lid takes its colour from the fur just above it.
        let near = try #require(frame.eyes.max { $0.radius * $0.aspect < $1.radius * $1.aspect })
        let height = Double(near.radius) / Double(frame.height)
        let lid = (x: Double(near.center.x), y: Double(near.center.y) + height * 0.45)
        let brow = (x: Double(near.center.x), y: Double(near.center.y) + height * 1.4)
        let patch = Double(near.radius) / Double(frame.width) * 0.25
        let furColor = open.mean(around: brow, radius: patch)
        #expect(closed.mean(around: lid, radius: patch).distance(to: furColor) < 40)
        #expect(open.mean(around: lid, radius: patch).distance(to: furColor) > 40)

        let chin = (x: 0.5, y: 0.25)
        #expect(open.difference(from: closed, around: chin, radius: 0.08) == 0)
        #expect(open.difference(from: lookingRight, around: chin, radius: 0.08) == 0)
    }
}

private struct RenderedPixels {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    init(_ image: CGImage) {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { bytes in
            let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.width = width
        self.height = height
        rgba = data
    }

    /// Pixel offsets inside a circle given in texture coordinates (y up),
    /// with the radius measured as a fraction of the image width.
    private func indices(around center: (x: Double, y: Double), radius: Double) -> [Int] {
        let cx = center.x * Double(width)
        let cy = (1 - center.y) * Double(height)
        let r = radius * Double(width)
        var result: [Int] = []
        for y in max(0, Int(cy - r))...min(height - 1, Int(cy + r)) {
            for x in max(0, Int(cx - r))...min(width - 1, Int(cx + r)) where hypot(Double(x) - cx, Double(y) - cy) <= r
            {
                result.append((y * width + x) * 4)
            }
        }
        return result
    }

    /// Mean per-channel difference between two renders inside a circle.
    func difference(from other: RenderedPixels, around center: (x: Double, y: Double), radius: Double) -> Double {
        let pixels = indices(around: center, radius: radius)
        guard !pixels.isEmpty else { return 0 }
        let total = pixels.reduce(0) { sum, index in
            sum + (0..<3).reduce(0) { $0 + abs(Int(rgba[index + $1]) - Int(other.rgba[index + $1])) }
        }
        return Double(total) / Double(pixels.count * 3)
    }

    func mean(around center: (x: Double, y: Double), radius: Double) -> SIMD3<Double> {
        let pixels = indices(around: center, radius: radius)
        let sum = pixels.reduce(SIMD3<Double>.zero) { total, index in
            total + SIMD3(Double(rgba[index]), Double(rgba[index + 1]), Double(rgba[index + 2]))
        }
        return sum / Double(max(1, pixels.count))
    }
}

extension SIMD3<Double> {
    fileprivate func distance(to other: SIMD3<Double>) -> Double {
        let delta = self - other
        return (delta * delta).sum().squareRoot()
    }
}
