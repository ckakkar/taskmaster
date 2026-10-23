// Renders the background of Taskmaster.dmg's window (run by scripts/make-dmg.sh).
//
//   swift scripts/dmg-background.swift <background.png> <scale>
//
// 660×400 points: a warm cream wall and a wooden desk the two icons sit on, with a trail of Miso's muddy
// pawprints walking from the app (left) to Applications (right). Finder draws the icon labels in white in
// dark mode and black in light mode, so the desk behind them (y ≈ 240–292) is a mid-tone that reads with
// both. Keep the icon positions in sync with scripts/dmg-settings.py.
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3, let scale = Double(args[2]) else {
    FileHandle.standardError.write(Data("usage: swift scripts/dmg-background.swift <out.png> <scale>\n".utf8))
    exit(2)
}

let width: CGFloat = 660
let height: CGFloat = 400
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Top-left origin in points, like Finder's icon positions.
ctx.scaleBy(x: scale, y: scale)
ctx.translateBy(x: 0, y: height)
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, alpha,
        ])!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

let deskTop: CGFloat = 240
let deskBottom: CGFloat = 292

// The wall, warming towards the desk, with afternoon light from the upper left.
ctx.drawLinearGradient(
    gradient([color(0xFCF6EC), color(0xF6E6CF), color(0xEFD5B6)], [0, 0.7, 1]),
    start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: deskTop), options: [])
let light = CGPoint(x: 140, y: 30)
ctx.drawRadialGradient(
    gradient([color(0xFFFDF7, 0.9), color(0xFFF6E6, 0.35), color(0xFFF6E6, 0)], [0, 0.45, 1]),
    startCenter: light, startRadius: 0, endCenter: light, endRadius: 300, options: [])

// A few faint floating hearts, like the ones Miso gives off when petted.
func heart(at point: CGPoint, size: CGFloat, alpha: CGFloat) {
    let path = CGMutablePath()
    let s = size / 14
    path.move(to: CGPoint(x: point.x, y: point.y + 5 * s))
    path.addCurve(
        to: CGPoint(x: point.x, y: point.y - 4 * s), control1: CGPoint(x: point.x - 15 * s, y: point.y - 4 * s),
        control2: CGPoint(x: point.x - 6 * s, y: point.y - 14 * s))
    path.addCurve(
        to: CGPoint(x: point.x, y: point.y + 5 * s), control1: CGPoint(x: point.x + 6 * s, y: point.y - 14 * s),
        control2: CGPoint(x: point.x + 15 * s, y: point.y - 4 * s))
    ctx.addPath(path)
    ctx.setFillColor(color(0xD9786A, alpha))
    ctx.fillPath()
}
for (x, y, size, alpha) in [
    (58.0, 46.0, 11.0, 0.22), (602, 38, 13, 0.26), (548, 92, 8, 0.18), (96, 112, 7, 0.16), (330, 30, 9, 0.18),
] {
    heart(at: CGPoint(x: x, y: y), size: size, alpha: alpha)
}

// The desk: a mid-tone wooden top (relative luminance about 0.18 behind the labels), a lit front edge
// and a soft shadow on the floor below.
ctx.drawLinearGradient(
    gradient([color(0xC0835B), color(0xAE6A45), color(0xA4603D)], [0, 0.25, 1]),
    start: CGPoint(x: 0, y: deskTop), end: CGPoint(x: 0, y: deskBottom), options: [])
ctx.setStrokeColor(color(0x8E4F31, 0.18))
ctx.setLineWidth(1)
for (y, start, end) in [(254.0, 30.0, 300.0), (262, 380, 640), (276, 60, 250), (283, 420, 600), (270, 280, 420)] {
    ctx.move(to: CGPoint(x: start, y: y))
    ctx.addQuadCurve(to: CGPoint(x: end, y: y + 1.5), control: CGPoint(x: (start + end) / 2, y: y - 1.5))
    ctx.strokePath()
}
ctx.setFillColor(color(0xE2A57C, 0.8))
ctx.fill(CGRect(x: 0, y: deskTop, width: width, height: 1.5))
ctx.drawLinearGradient(
    gradient([color(0x6E3A22, 0.55), color(0xF3E2CC)], [0, 1]),
    start: CGPoint(x: 0, y: deskBottom), end: CGPoint(x: 0, y: deskBottom + 14), options: [])
ctx.drawLinearGradient(
    gradient([color(0xF3E2CC), color(0xF8EBDA)], [0, 1]),
    start: CGPoint(x: 0, y: deskBottom + 14), end: CGPoint(x: 0, y: height), options: [])

// Muddy pawprints from the app to Applications along a gentle arc, each pointing the way it walks and
// stepping a little left or right of the path, darker as they near Applications.
let start = CGPoint(x: 246, y: 196)
let control = CGPoint(x: 330, y: 138)
let end = CGPoint(x: 414, y: 190)
// Small typed steps keep older Swift compilers from timing out on the curve arithmetic.
func point(_ t: CGFloat) -> CGPoint {
    let u: CGFloat = 1 - t
    let a: CGFloat = u * u
    let b: CGFloat = 2 * u * t
    let c: CGFloat = t * t
    let x: CGFloat = a * start.x + b * control.x + c * end.x
    let y: CGFloat = a * start.y + b * control.y + c * end.y
    return CGPoint(x: x, y: y)
}
func direction(_ t: CGFloat) -> CGFloat {
    let before: CGFloat = 2 * (1 - t)
    let after: CGFloat = 2 * t
    let dx: CGFloat = before * (control.x - start.x) + after * (end.x - control.x)
    let dy: CGFloat = before * (control.y - start.y) + after * (end.y - control.y)
    return atan2(dy, dx)
}
func pawprint(at center: CGPoint, angle: CGFloat, alpha: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    // Toes point along the direction of travel.
    ctx.rotate(by: angle + .pi / 2)
    ctx.setFillColor(color(0x8A4A2C, alpha))
    ctx.fillEllipse(in: CGRect(x: -5.2, y: -1.5, width: 10.4, height: 8.4))
    for (x, y, w, h) in [
        (-7.2, -6.8, 3.6, 4.6), (-3.2, -10.2, 3.6, 4.8), (0.6, -10.2, 3.6, 4.8), (4.4, -6.8, 3.6, 4.6),
    ] {
        ctx.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
    }
    ctx.restoreGState()
}
let steps = 7
for index in 0..<steps {
    let t = 0.06 + CGFloat(index) / CGFloat(steps - 1) * 0.86
    let p = point(t)
    let angle = direction(t)
    let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
    let offset = CGPoint(x: -sin(angle) * 6 * side, y: cos(angle) * 6 * side)
    pawprint(at: CGPoint(x: p.x + offset.x, y: p.y + offset.y), angle: angle, alpha: 0.42 + 0.45 * CGFloat(index) / 6)
}

// Words, on the floor below the desk.
func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat) {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    let attributed = NSAttributedString(
        string: string,
        attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(0x3B2A22, alpha))!])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.saveGState()
    // Core Text draws upright in a bottom-left coordinate space.
    ctx.translateBy(x: (width - bounds.width) / 2, y: y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}
text("Drag Taskmaster into Applications", size: 17, weight: .semibold, alpha: 0.9, y: 338)
text("First launch: System Settings › Privacy & Security › Open Anyway", size: 11, weight: .medium, alpha: 0.7, y: 364)

let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: args[1]))
