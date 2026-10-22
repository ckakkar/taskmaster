import AppKit
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let atlasURL = root.appendingPathComponent("Sources/Taskmaster/Resources/MisoAtlas.png")
guard let source = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
      let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let character = atlas.cropping(to: CGRect(x: 0, y: 0, width: atlas.width / 3, height: atlas.height / 3)) else {
    fatalError("Missing character atlas")
}
let output = root.appendingPathComponent("build/Taskmaster.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("No graphics context") }
    context.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
    let bounds = CGRect(x: 25, y: 25, width: 974, height: 974)
    let path = CGPath(roundedRect: bounds, cornerWidth: 218, cornerHeight: 218, transform: nil)
    context.addPath(path)
    context.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 1, green: 0.96, blue: 0.86, alpha: 1),
        CGColor(red: 0.94, green: 0.78, blue: 0.59, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
    context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.92, alpha: 0.5))
    context.fillEllipse(in: CGRect(x: 150, y: 170, width: 740, height: 740))
    context.interpolationQuality = .high
    context.draw(character, in: CGRect(x: 55, y: 65, width: 920, height: 920))
    guard let image = context.makeImage() else { fatalError("Could not render icon") }
    let names: [String]
    switch pixels {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names {
        guard let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil) else {
            fatalError("Could not write icon")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not encode icon") }
    }
}
