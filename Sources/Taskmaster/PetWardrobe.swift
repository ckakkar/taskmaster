import AppKit
import SpriteKit
import CompanionCore

extension BubbleStyle {
    var nsColor: NSColor {
        switch self {
        case .cream: NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 1)
        case .sage: NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.85, alpha: 1)
        case .peach: NSColor(calibratedRed: 1, green: 0.88, blue: 0.81, alpha: 1)
        case .midnight: NSColor(calibratedRed: 0.23, green: 0.27, blue: 0.30, alpha: 1)
        }
    }
}

extension AccessoryColor {
    var nsColor: NSColor {
        switch self {
        case .forest: NSColor(calibratedRed: 0.28, green: 0.49, blue: 0.38, alpha: 1)
        case .rust: NSColor(calibratedRed: 0.76, green: 0.29, blue: 0.22, alpha: 1)
        case .lavender: NSColor(calibratedRed: 0.59, green: 0.48, blue: 0.73, alpha: 1)
        case .ocean: NSColor(calibratedRed: 0.27, green: 0.49, blue: 0.65, alpha: 1)
        case .rose: NSColor(calibratedRed: 0.80, green: 0.48, blue: 0.54, alpha: 1)
        }
    }
}

/// A small fabric accessory follows the neck rather than covering the painted face.
@MainActor
final class PetWardrobe: SKNode {
    private var currentStyle: AccessoryStyle?
    private var currentColor: AccessoryColor?

    func update(frame: PetAtlas.Frame, petSize: CGSize, preferences: Preferences, gaze: Point,
                tilt: Double, time: Double, moving: Double, reducedMotion: Bool) {
        if currentStyle != preferences.accessory || currentColor != preferences.accessoryColor {
            currentStyle = preferences.accessory
            currentColor = preferences.accessoryColor
            rebuild(style: preferences.accessory, color: preferences.accessoryColor.nsColor)
        }
        isHidden = preferences.accessory == .none
        let head = frame.eyes.isEmpty ? SIMD2<Float>(0.64, 0.65)
            : frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        position = CGPoint(x: (Double(head.x) - 0.5 - 0.065 + gaze.x * 0.012) * petSize.width,
                           y: (Double(head.y) - 0.18 + gaze.y * 0.008) * petSize.height)
        let scale = petSize.height / 230
        setScale(scale)
        zRotation = reducedMotion ? 0 : tilt * 0.3 + sin(time * 5) * moving * 0.035
    }

    private func rebuild(style: AccessoryStyle, color: NSColor) {
        removeAllChildren()
        guard style != .none else { return }
        func shape(_ path: CGPath, fill: NSColor) -> SKShapeNode {
            let node = SKShapeNode(path: path)
            node.fillColor = fill
            node.strokeColor = fill.blended(withFraction: 0.28, of: .black) ?? fill
            node.lineWidth = 0.8
            node.isAntialiased = true
            addChild(node)
            return node
        }
        let path = CGMutablePath()
        switch style {
        case .bandana:
            path.move(to: CGPoint(x: -25, y: 4))
            path.addQuadCurve(to: CGPoint(x: 23, y: 7), control: CGPoint(x: 0, y: -3))
            path.addLine(to: CGPoint(x: 8, y: -26))
            path.addQuadCurve(to: CGPoint(x: -25, y: 4), control: CGPoint(x: -9, y: -19))
            _ = shape(path, fill: color)
            let seam = SKShapeNode()
            let seamPath = CGMutablePath()
            seamPath.move(to: CGPoint(x: -17, y: 0)); seamPath.addLine(to: CGPoint(x: 7, y: -20)); seamPath.addLine(to: CGPoint(x: 17, y: 1))
            seam.path = seamPath; seam.strokeColor = .white.withAlphaComponent(0.4); seam.lineWidth = 0.7
            addChild(seam)
            let star = SKLabelNode(text: "✦")
            star.fontSize = 9; star.fontColor = .white.withAlphaComponent(0.85)
            star.position = CGPoint(x: 5, y: -13); addChild(star)
        case .bow:
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: -25, y: 11), control1: CGPoint(x: -8, y: 8), control2: CGPoint(x: -20, y: 15))
            path.addQuadCurve(to: CGPoint(x: -23, y: -13), control: CGPoint(x: -29, y: -5))
            path.addQuadCurve(to: .zero, control: CGPoint(x: -13, y: -10))
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: 24, y: 12), control1: CGPoint(x: 8, y: 8), control2: CGPoint(x: 19, y: 16))
            path.addQuadCurve(to: CGPoint(x: 24, y: -12), control: CGPoint(x: 29, y: -5))
            path.addQuadCurve(to: .zero, control: CGPoint(x: 13, y: -9))
            _ = shape(path, fill: color)
            let knot = SKShapeNode(rectOf: CGSize(width: 9, height: 14), cornerRadius: 3)
            knot.fillColor = color.blended(withFraction: 0.15, of: .white) ?? color
            knot.strokeColor = color; addChild(knot)
        case .bell:
            let collar = SKShapeNode(rectOf: CGSize(width: 45, height: 7), cornerRadius: 3)
            collar.fillColor = color; collar.strokeColor = .clear; addChild(collar)
            let bell = SKShapeNode(circleOfRadius: 9)
            bell.fillColor = NSColor(calibratedRed: 0.94, green: 0.73, blue: 0.34, alpha: 1)
            bell.strokeColor = NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.17, alpha: 1)
            bell.position = CGPoint(x: 3, y: -11); addChild(bell)
            let hole = SKShapeNode(circleOfRadius: 2)
            hole.fillColor = bell.strokeColor; hole.strokeColor = .clear; hole.position.y = -3; bell.addChild(hole)
            let glint = SKShapeNode(ellipseOf: CGSize(width: 4, height: 2))
            glint.fillColor = .white.withAlphaComponent(0.6); glint.strokeColor = .clear
            glint.position = CGPoint(x: -2, y: 4); bell.addChild(glint)
        case .none: break
        }
    }
}
