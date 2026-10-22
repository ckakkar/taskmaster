import AppKit
import SpriteKit

@MainActor
final class MemeCardNode: SKNode {
    let memeID: String
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 28, height: 26), cornerRadius: 8)
    private let keepButton = SKShapeNode(rectOf: CGSize(width: 100, height: 25), cornerRadius: 9)
    let cardSize = CGSize(width: 266, height: 246)

    init(item: MemeItem, image: NSImage) {
        memeID = item.id
        super.init()
        zPosition = 2
        let rect = CGRect(x: -133, y: 0, width: 266, height: 246)
        let shadow = SKShapeNode(rect: rect.offsetBy(dx: 3, dy: -4), cornerRadius: 14)
        shadow.fillColor = NSColor.black.withAlphaComponent(0.10)
        shadow.strokeColor = .clear
        addChild(shadow)
        let paper = SKShapeNode(rect: rect, cornerRadius: 14)
        paper.fillColor = NSColor(calibratedRed: 1, green: 0.985, blue: 0.95, alpha: 1)
        paper.strokeColor = NSColor(calibratedRed: 0.71, green: 0.61, blue: 0.50, alpha: 0.32)
        paper.lineWidth = 1
        addChild(paper)
        let title = label("a little delivery", size: 10, weight: .semibold)
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -118, y: 225)
        title.fontColor = NSColor(calibratedRed: 0.53, green: 0.43, blue: 0.35, alpha: 1)
        addChild(title)
        closeButton.position = CGPoint(x: 111, y: 225)
        closeButton.fillColor = NSColor(calibratedWhite: 0, alpha: 0.045)
        closeButton.strokeColor = .clear
        let cross = label("×", size: 19, weight: .regular)
        cross.verticalAlignmentMode = .center
        closeButton.addChild(cross)
        addChild(closeButton)
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let texture = SKTexture(cgImage: cg)
            let picture = SKSpriteNode(texture: texture)
            let scale = min(242 / Double(cg.width), 168 / Double(cg.height))
            picture.size = CGSize(width: Double(cg.width) * scale, height: Double(cg.height) * scale)
            picture.position = CGPoint(x: 0, y: 125)
            addChild(picture)
        }
        keepButton.position = CGPoint(x: -62, y: 21)
        keepButton.fillColor = NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.86, alpha: 1)
        keepButton.strokeColor = .clear
        let keep = label("keep +30s", size: 10, weight: .medium)
        keep.verticalAlignmentMode = .center
        keepButton.addChild(keep)
        addChild(keepButton)
        let putAway = label("×  send back", size: 10, weight: .medium)
        putAway.position = CGPoint(x: 68, y: 18)
        putAway.fontColor = NSColor(calibratedRed: 0.56, green: 0.43, blue: 0.33, alpha: 1)
        addChild(putAway)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func action(at scenePoint: CGPoint) -> CardAction? {
        guard let scene else { return nil }
        let point = convert(scenePoint, from: scene)
        guard CGRect(x: -133, y: 0, width: 266, height: 246).contains(point) else { return nil }
        if closeButton.contains(point) || (point.y < 37 && point.x > 0) { return .putAway }
        return .keep
    }

    private func label(_ text: String, size: Double, weight: NSFont.Weight) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = NSFont.systemFont(ofSize: size, weight: weight).fontName
        label.fontSize = size
        label.fontColor = NSColor(calibratedRed: 0.32, green: 0.26, blue: 0.21, alpha: 1)
        return label
    }

    enum CardAction { case keep, putAway }
}
