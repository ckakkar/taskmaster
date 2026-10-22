import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func dismissNote() { childNode(withName: "note")?.removeFromParent() }

    func clearFootprints() {
        for node in children where node.name == "footprint" { node.removeFromParent() }
    }

    func handle(_ events: [PetEvent]) {
        for event in events {
            switch event {
            case .hearts:
                particles(
                    kind: "heart", color: NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.39, alpha: 1), count: 6)
            case .highFive:
                particles(
                    kind: "spark", color: NSColor(calibratedRed: 0.93, green: 0.67, blue: 0.28, alpha: 1), count: 10)
                particles(
                    kind: "heart", color: NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.39, alpha: 1), count: 4)
            case .crumbs:
                particles(
                    kind: "crumb", color: NSColor(calibratedRed: 0.77, green: 0.54, blue: 0.23, alpha: 1), count: 9)
            case .landing(_, let speed):
                if !reducedMotion && speed > 80 {
                    animation.land(speed: speed)
                    particles(kind: "crumb", color: .white.withAlphaComponent(0.65), count: 4)
                }
            case .footprint(let position, let right):
                let point = isPreview ? CGPoint(x: petLocation.x + (right ? -18 : 18), y: 35) : local(position)
                footprint(at: point, right: right)
            case .note(_, let text):
                if !isPreview { makeNote(text) }
            case .speech(let text):
                speech(text)
            case .toyHit:
                particles(
                    kind: "spark", color: NSColor(calibratedRed: 0.89, green: 0.68, blue: 0.34, alpha: 1), count: 3)
            case .cursorCaught:
                particles(
                    kind: "spark", color: NSColor(calibratedRed: 0.93, green: 0.67, blue: 0.28, alpha: 1), count: 7)
            }
        }
    }

    func particles(kind: String, color: NSColor, count: Int) {
        guard !reducedMotion else { return }
        let existing = children.filter { $0.name == "mote" }
        for node in existing.prefix(max(0, existing.count + count - 96)) { node.removeFromParent() }
        for index in 0..<count {
            let node: SKShapeNode
            if kind == "heart" {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: -5))
                path.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: -15, y: 4), control2: CGPoint(x: -6, y: 14))
                path.addCurve(to: CGPoint(x: 0, y: -5), control1: CGPoint(x: 6, y: 14), control2: CGPoint(x: 15, y: 4))
                node = SKShapeNode(path: path)
            } else {
                node = SKShapeNode(circleOfRadius: kind == "crumb" ? 2.5 : 3.5)
            }
            node.fillColor = color
            node.name = "mote"
            node.strokeColor = .clear
            node.position = CGPoint(
                x: petLocation.x + Double(index % 3 - 1) * 16, y: petLocation.y + pet.size.height * 0.7)
            node.zPosition = 8
            node.setScale(0.3)
            addChild(node)
            let spread = Double(index) / Double(max(1, count - 1)) * 90 - 45
            node.run(
                .sequence([
                    .wait(forDuration: Double(index) * 0.07),
                    .group([
                        .moveBy(x: spread, y: 45 + Double(index % 3) * 15, duration: 1.2),
                        .sequence([
                            .scale(to: 0.75, duration: 0.2), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.5),
                        ]),
                    ]),
                    .removeFromParent(),
                ]))
        }
    }

    private func footprint(at point: CGPoint, right: Bool) {
        // Bound the number of transient props even after a long session.
        let prints = children.filter { $0.name == "footprint" }
        if prints.count >= 60 { prints.first?.removeFromParent() }
        let mark = SKNode()
        mark.name = "footprint"
        mark.position = CGPoint(x: point.x, y: point.y + (right ? 5 : 14) * printScale)
        mark.setScale(printScale)
        mark.zRotation = right ? -0.28 : 0.28
        mark.zPosition = 0.2
        let pad = SKShapeNode(ellipseOf: CGSize(width: 10, height: 7))
        pad.fillColor = NSColor(calibratedRed: 0.32, green: 0.23, blue: 0.15, alpha: 0.43)
        if atlas.avatar == .toothless {
            pad.fillColor = NSColor(calibratedRed: 0.36, green: 0.61, blue: 0.85, alpha: 0.4)
        }
        pad.strokeColor = .clear
        mark.addChild(pad)
        for (index, x) in [-5.0, -1.7, 1.7, 5.0].enumerated() {
            let toe = SKShapeNode(ellipseOf: CGSize(width: 3.5, height: 4))
            toe.position = CGPoint(x: x, y: index == 0 || index == 3 ? 5 : 7)
            toe.fillColor = pad.fillColor
            toe.strokeColor = .clear
            mark.addChild(toe)
        }
        for index in 0..<3 {
            let speck = SKShapeNode(circleOfRadius: index == 0 ? 1.1 : 0.6)
            speck.position = CGPoint(x: Double(index * 7 - 8), y: Double(index * 3 - 4))
            speck.fillColor = pad.fillColor.withAlphaComponent(0.23)
            speck.strokeColor = .clear
            mark.addChild(speck)
        }
        addChild(mark)
        mark.run(
            .sequence([
                .wait(forDuration: pawprintSeconds * 0.55), .fadeOut(withDuration: pawprintSeconds * 0.45),
                .removeFromParent(),
            ]))
    }

    private func makeNote(_ text: String) {
        dismissNote()
        let label = SKLabelNode(text: text)
        label.fontName = NSFont.systemFont(ofSize: 14, weight: .medium).fontName
        label.fontSize = 14
        label.fontColor = NSColor(calibratedRed: 0.39, green: 0.30, blue: 0.20, alpha: 1)
        label.preferredMaxLayoutWidth = 180
        label.numberOfLines = 0
        label.verticalAlignmentMode = .center
        let height = max(87, label.frame.height + 51)
        let card = SKShapeNode(rectOf: CGSize(width: 216, height: height), cornerRadius: 10)
        card.name = "note"
        card.fillColor = NSColor(calibratedRed: 1, green: 0.95, blue: 0.77, alpha: 1)
        card.strokeColor = NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.35, alpha: 0.3)
        card.lineWidth = 1
        card.zPosition = 5
        let candidateX = petLocation.x > size.width / 2 ? petLocation.x - 150 : petLocation.x + 150
        card.position = CGPoint(
            x: min(max(120, size.width - 120), max(120, candidateX)), y: petLocation.y + height / 2 + 18)
        card.zRotation = -0.055
        label.position.y = 7
        card.addChild(label)
        let signature = SKLabelNode(text: "a note from \(nameLabel.text ?? "your companion")  ·  click to tidy")
        signature.fontName = NSFont.systemFont(ofSize: 8).fontName
        signature.fontSize = 8
        signature.fontColor = label.fontColor?.withAlphaComponent(0.5)
        signature.position.y = -height / 2 + 14
        card.addChild(signature)
        addChild(card)
        card.alpha = 0
        card.run(
            .sequence([
                .fadeIn(withDuration: 0.3), .wait(forDuration: 12), .fadeOut(withDuration: 0.8), .removeFromParent(),
            ]))
    }

    private func speech(_ text: String) {
        childNode(withName: "speech")?.removeFromParent()
        let label = SKLabelNode(text: text)
        label.fontName = NSFont.systemFont(ofSize: 12, weight: .semibold).fontName
        label.fontSize = 12
        label.fontColor =
            bubbleStyle == .midnight
            ? NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.87, alpha: 1)
            : NSColor(calibratedRed: 0.35, green: 0.27, blue: 0.23, alpha: 1)
        label.preferredMaxLayoutWidth = isPreview ? 250 : 290
        label.numberOfLines = 0
        label.verticalAlignmentMode = .center
        let pill = SKShapeNode(
            rectOf: CGSize(width: label.frame.width + 26, height: max(31, label.frame.height + 20)), cornerRadius: 15)
        pill.name = "speech"
        pill.fillColor = bubbleStyle.nsColor
        pill.strokeColor = NSColor(calibratedWhite: 0.3, alpha: 0.12)
        pill.position = speechPosition(width: pill.frame.width, height: pill.frame.height)
        pill.zPosition = 9
        pill.addChild(label)
        addChild(pill)
        pill.run(.sequence([.wait(forDuration: speechSeconds), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    func speechPosition(width: CGFloat, height: CGFloat) -> CGPoint {
        let margin = min(size.width / 2, width / 2 + 8)
        return CGPoint(
            x: min(max(margin, size.width - margin), max(margin, petLocation.x)),
            y: min(size.height - height / 2 - 8, petLocation.y + pet.size.height + height / 2 + 12))
    }
}
