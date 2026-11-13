// Paints walk-cycle in-betweens from existing stride drawings, so a companion steps through more drawings.
//
//   swift scripts/make-inbetweens.swift <atlas.png> <atlas.json> <out.png> <out.json> <keys> <steps>
//   e.g. … ToothlessAtlas.png ToothlessAtlas.json ToothlessWalk.png ToothlessWalk.json 1,0,2,0 2
//
// The key drawings (atlas region indices, in stride order) are aligned at the eyes and the ground line, as
// the app aligns them. Vision estimates optical flow both ways between neighbours; each in-between warps both
// neighbours toward time t and mixes them, weighted toward the nearer key (Super SloMo's linear flow
// approximation). Writes a four-column sheet and a layout with interpolated eye landmarks, which the app
// loads as `<Name>Walk`. See docs/CHARACTER-ART.md.
import AppKit
import CoreImage
import Vision

struct Eye: Codable {
    var x: Double
    var y: Double
    var radius: Double
    var aspect: Double?
}
struct Neck: Codable {
    var x: Double
    var y: Double
    var width: Double
    var angle: Double
}
struct Region: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var eyes: [Eye]?
    var neck: Neck?
}
struct Layout: Codable {
    var sourceWidth: Double
    var sourceHeight: Double
    var frames: [Region]
}

let args = CommandLine.arguments
let sheetURL = URL(fileURLWithPath: args[1])
let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let outImage = URL(fileURLWithPath: args[3])
let outLayout = URL(fileURLWithPath: args[4])
let keys = args[5].split(separator: ",").map { Int($0)! }
let steps = Int(args[6])!

let source = CGImageSourceCreateWithURL(sheetURL as CFURL, nil)!
let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let sx = Double(sheet.width) / layout.sourceWidth

struct Bitmap {
    var width: Int, height: Int
    var data: [Float]  // premultiplied RGBA, 0...1
    func pixel(_ x: Int, _ y: Int) -> SIMD4<Float> {
        guard x >= 0, y >= 0, x < width, y < height else { return .zero }
        let i = (y * width + x) * 4
        return SIMD4(data[i], data[i + 1], data[i + 2], data[i + 3])
    }
    func sample(_ x: Float, _ y: Float) -> SIMD4<Float> {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let fx = x - Float(x0)
        let fy = y - Float(y0)
        let a = pixel(x0, y0)
        let b = pixel(x0 + 1, y0)
        let c = pixel(x0, y0 + 1)
        let d = pixel(x0 + 1, y0 + 1)
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    }
}

func rgba(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let context = CGContext(
        data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return bytes
}

/// Bounds of the largest connected silhouette (alpha > 90), as PetAtlas trims.
func silhouette(_ bytes: [UInt8], _ w: Int, _ h: Int) -> CGRect {
    var seen = [Bool](repeating: false, count: w * h)
    var best = CGRect(x: 0, y: 0, width: w, height: h)
    var largest = 0
    for seed in 0..<(w * h) where !seen[seed] && bytes[seed * 4 + 3] > 90 {
        var stack = [seed]
        seen[seed] = true
        var n = 0
        var minX = w
        var minY = h
        var maxX = 0
        var maxY = 0
        while let i = stack.popLast() {
            n += 1
            let x = i % w
            let y = i / w
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
            for j in [x > 0 ? i - 1 : -1, x + 1 < w ? i + 1 : -1, y > 0 ? i - w : -1, y + 1 < h ? i + w : -1]
            where j >= 0 && !seen[j] && bytes[j * 4 + 3] > 90 {
                seen[j] = true
                stack.append(j)
            }
        }
        if n > largest {
            largest = n
            best = CGRect(
                x: max(0, minX - 4), y: max(0, minY - 4), width: min(w - 1, maxX + 4) - max(0, minX - 4) + 1,
                height: min(h - 1, maxY + 4) - max(0, minY - 4) + 1)
        }
    }
    return best
}

/// A drawing with its landmarks in pixels (top-left origin) of whatever image it currently sits in.
struct Drawn {
    var eyes: [Eye]
    var neck: Neck?
    func moved(_ dx: Double, _ dy: Double) -> Drawn {
        Drawn(
            eyes: eyes.map { Eye(x: $0.x + dx, y: $0.y + dy, radius: $0.radius, aspect: $0.aspect) },
            neck: neck.map { Neck(x: $0.x + dx, y: $0.y + dy, width: $0.width, angle: $0.angle) })
    }
    func mixed(_ other: Drawn, _ t: Double) -> Drawn {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return Drawn(
            eyes: zip(eyes, other.eyes).map {
                Eye(x: mix($0.x, $1.x), y: mix($0.y, $1.y), radius: mix($0.radius, $1.radius), aspect: $0.aspect)
            },
            neck: neck.flatMap { a in
                other.neck.map { b in
                    Neck(x: mix(a.x, b.x), y: mix(a.y, b.y), width: mix(a.width, b.width), angle: mix(a.angle, b.angle))
                }
            })
    }
}
struct Key {
    var image: CGImage
    var marks: Drawn
}
var cut: [Key] = []
for index in keys {
    let r = layout.frames[index]
    let rect = CGRect(x: r.x * sx, y: r.y * sx, width: r.width * sx, height: r.height * sx).integral
    let cell = sheet.cropping(to: rect)!
    let bounds = silhouette(rgba(cell), cell.width, cell.height)
    let trimmed = cell.cropping(to: bounds)!
    let scaled = Drawn(
        eyes: (r.eyes ?? []).map { Eye(x: $0.x * sx, y: $0.y * sx, radius: $0.radius * sx, aspect: $0.aspect) },
        neck: r.neck.map { Neck(x: $0.x * sx, y: $0.y * sx, width: $0.width * sx, angle: $0.angle) })
    cut.append(Key(image: trimmed, marks: scaled.moved(-rect.minX - bounds.minX, -rect.minY - bounds.minY)))
}

// A shared canvas: eyes centred at the same x, ground line (bottom of the drawing) at the same y.
let eyeX = cut.map { k in k.marks.eyes.map(\.x).reduce(0, +) / Double(k.marks.eyes.count) }
let leftReach = zip(cut, eyeX).map { $1 }.max()!
let rightReach = zip(cut, eyeX).map { Double($0.image.width) - $1 }.max()!
let tallest = cut.map(\.image.height).max()!
let canvasW = Int(leftReach + rightReach) + 24
let canvasH = tallest + 24
let anchorX = leftReach + 12
func placed(_ k: Key, _ ex: Double) -> (Bitmap, Drawn) {
    let dx = anchorX - ex
    let dy = Double(canvasH - 12 - k.image.height)  // top-left origin
    var bytes = [UInt8](repeating: 0, count: canvasW * canvasH * 4)
    let context = CGContext(
        data: &bytes, width: canvasW, height: canvasH, bitsPerComponent: 8, bytesPerRow: canvasW * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // CGContext's origin is bottom-left; the ground line sits 12 px above the bottom.
    context.draw(k.image, in: CGRect(x: dx, y: 12, width: Double(k.image.width), height: Double(k.image.height)))
    return (
        Bitmap(width: canvasW, height: canvasH, data: bytes.map { Float($0) / 255 }),
        k.marks.moved(dx, dy)
    )
}
let placedKeys = zip(cut, eyeX).map { placed($0, $1) }

func cgImage(_ b: Bitmap) -> CGImage {
    let bytes = b.data.map { UInt8(max(0, min(255, ($0 * 255).rounded()))) }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: b.width, height: b.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: b.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
}

/// Flow on the drawing composited over mid grey (Vision ignores alpha), in canvas pixels, top-left origin.
func flow(from a: Bitmap, to b: Bitmap) throws -> [SIMD2<Float>] {
    func opaque(_ m: Bitmap) -> CIImage {
        var flat = m
        for i in stride(from: 0, to: flat.data.count, by: 4) {
            let alpha = flat.data[i + 3]
            for c in 0..<3 { flat.data[i + c] = flat.data[i + c] + 0.5 * (1 - alpha) }
            flat.data[i + 3] = 1
        }
        return CIImage(cgImage: cgImage(flat))
    }
    let request = VNGenerateOpticalFlowRequest(targetedCIImage: opaque(b), options: [:])
    request.computationAccuracy = .veryHigh
    request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
    try VNImageRequestHandler(ciImage: opaque(a), options: [:]).perform([request])
    let buffer = (request.results!.first! as VNPixelBufferObservation).pixelBuffer
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let fw = CVPixelBufferGetWidth(buffer)
    let fh = CVPixelBufferGetHeight(buffer)
    let row = CVPixelBufferGetBytesPerRow(buffer)
    let base = CVPixelBufferGetBaseAddress(buffer)!
    var result = [SIMD2<Float>](repeating: .zero, count: a.width * a.height)
    let scaleX = Float(a.width) / Float(fw)
    let scaleY = Float(a.height) / Float(fh)
    for y in 0..<a.height {
        for x in 0..<a.width {
            let px = min(fw - 1, Int(Float(x) / scaleX))
            let py = min(fh - 1, Int(Float(y) / scaleY))
            let p = base.advanced(by: py * row + px * 8).assumingMemoryBound(to: Float.self)
            result[y * a.width + x] = SIMD2(p[0] * scaleX, p[1] * scaleY)
        }
    }
    return result
}

/// The drawing halfway between a and b, from flows a→b and b→a (Super SloMo's linear approximation at t = ½).
func between(_ a: Bitmap, _ b: Bitmap, _ ab: [SIMD2<Float>], _ ba: [SIMD2<Float>], t: Float) -> Bitmap {
    var out = Bitmap(width: a.width, height: a.height, data: [Float](repeating: 0, count: a.data.count))
    for y in 0..<a.height {
        for x in 0..<a.width {
            let i = y * a.width + x
            let f01 = ab[i]
            let f10 = ba[i]
            let toA = f01 * (-(1 - t) * t) + f10 * (t * t)
            let toB = f01 * ((1 - t) * (1 - t)) - f10 * (t * (1 - t))
            let pa = a.sample(Float(x) + toA.x, Float(y) + toA.y)
            let pb = b.sample(Float(x) + toB.x, Float(y) + toB.y)
            // Where one neighbour has fur and the other doesn't (a paw lifting away, say), blending would
            // leave a translucent ghost; take the nearer drawing there instead.
            let gap = min(1, max(0, (abs(pa.w - pb.w) - 0.12) / 0.3))
            let occlusion = gap * gap * (3 - 2 * gap)
            let mixed = (pa * (1 - t) + pb * t) * (1 - occlusion) + (t < 0.5 ? pa : pb) * occlusion
            for c in 0..<4 { out.data[i * 4 + c] = mixed[c] }
        }
    }
    return out
}

var frames: [(Bitmap, Drawn)] = []
for index in placedKeys.indices {
    let (a, eyesA) = placedKeys[index]
    let (b, eyesB) = placedKeys[(index + 1) % placedKeys.count]
    frames.append((a, eyesA))
    let ab = try flow(from: a, to: b)
    let ba = try flow(from: b, to: a)
    for step in 1...max(1, steps) {
        let t = Float(step) / Float(steps + 1)
        let mid = between(a, b, ab, ba, t: t)
        frames.append((mid, eyesA.mixed(eyesB, Double(t))))
    }
}

// 4 × 2 sheet, row-major in stride order.
let columns = 4
let rows = (frames.count + 3) / 4
var sheetBytes = [Float](repeating: 0, count: canvasW * columns * canvasH * rows * 4)
var regions: [Region] = []
for (n, frame) in frames.enumerated() {
    let ox = (n % columns) * canvasW
    let oy = (n / columns) * canvasH
    for y in 0..<canvasH {
        for x in 0..<canvasW {
            let s = (y * canvasW + x) * 4
            let d = ((oy + y) * canvasW * columns + ox + x) * 4
            for c in 0..<4 { sheetBytes[d + c] = frame.0.data[s + c] }
        }
    }
    let marks = frame.1.moved(Double(ox), Double(oy))
    regions.append(
        Region(
            x: Double(ox), y: Double(oy), width: Double(canvasW), height: Double(canvasH), eyes: marks.eyes,
            neck: marks.neck))
}
let whole = Bitmap(width: canvasW * columns, height: canvasH * rows, data: sheetBytes)
let dest = CGImageDestinationCreateWithURL(outImage as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cgImage(whole), nil)
CGImageDestinationFinalize(dest)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(Layout(sourceWidth: Double(whole.width), sourceHeight: Double(whole.height), frames: regions))
    .write(to: outLayout)
print("canvas \(canvasW)×\(canvasH), \(frames.count) frames")
