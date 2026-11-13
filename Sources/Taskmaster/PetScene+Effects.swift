import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func dismissNote() { note?.removeFromParent() }

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
                    dust(strength: min(1, speed / 700))
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
            case .booped:
                // A startled blink and a little squash, with a puff of sparkle off the nose.
                animation.react(blink: true, squash: reducedMotion ? 0 : -1.4)
                particles(
                    kind: "spark", color: NSColor(calibratedRed: 1, green: 0.86, blue: 0.55, alpha: 0.9), count: 3,
                    from: headPoint)
            case .giggle:
                animation.react(blink: true, squash: reducedMotion ? 0 : 1.1)
                particles(
                    kind: "spark", color: NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.40, alpha: 1), count: 5)
            case .dizzy:
                particles(kind: "spark", color: .white.withAlphaComponent(0.85), count: 3, from: headPoint)
            case .noticed:
                animation.react(blink: false)
                particles(
                    kind: "heart", color: NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.39, alpha: 0.8), count: 1,
                    from: headPoint)
            }
        }
    }

    /// Just above the eyes of the drawing on screen (the top middle when it has none).
    var headPoint: CGPoint {
        let frame = atlas.frame(for: pose)
        guard !frame.eyes.isEmpty, pet.size.width > 0 else {
            return CGPoint(x: petLocation.x, y: petLocation.y + pet.size.height * 0.9)
        }
        let eyes = frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        return pet.convert(
            CGPoint(x: (Double(eyes.x) - 0.5) * pet.size.width, y: (Double(eyes.y) + 0.12) * pet.size.height), to: self)
    }

    /// Every transient effect (sparks, hearts, dust, Zs) shares one bound, oldest removed first.
    func makeRoomForMotes(_ count: Int) {
        let existing = children.filter { $0.name == "mote" }
        for node in existing.prefix(max(0, existing.count + count - 96)) { node.removeFromParent() }
    }

    func particles(kind: String, color: NSColor, count: Int, from origin: CGPoint? = nil) {
        guard !reducedMotion else { return }
        makeRoomForMotes(count)
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
            let start = origin ?? CGPoint(x: petLocation.x, y: petLocation.y + pet.size.height * 0.7)
            node.position = CGPoint(x: start.x + Double(index % 3 - 1) * (origin == nil ? 16 : 7), y: start.y)
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

    /// Soft puffs roll out from under the paws on a hard landing.
    func dust(strength: Double) {
        guard !reducedMotion else { return }
        let floor = CGPoint(x: petLocation.x, y: shadow.position.y + 2)
        let count = 4 + Int(strength * 4)
        makeRoomForMotes(count)
        for index in 0..<count {
            let side: Double = index % 2 == 0 ? -1 : 1
            let puff = SKShapeNode(circleOfRadius: 5 + Double(index % 3) * 2)
            puff.name = "mote"
            puff.fillColor = NSColor(calibratedRed: 0.58, green: 0.52, blue: 0.46, alpha: 0.38)
            puff.strokeColor = .clear
            puff.zPosition = 2.8
            puff.position = CGPoint(x: floor.x + side * (10 + Double(index) * 3), y: floor.y)
            puff.setScale(0.5)
            addChild(puff)
            let reach = (22 + Double(index) * 7) * (0.6 + strength * 0.6)
            let drift = SKAction.moveBy(x: side * reach, y: 5 + Double(index % 3) * 4, duration: 0.55)
            drift.timingMode = .easeOut
            puff.run(
                .sequence([
                    .group([drift, .scale(to: 1.5, duration: 0.55), .fadeOut(withDuration: 0.55)]),
                    .removeFromParent(),
                ]))
        }
    }

    /// One Z drifts up from a sleeping head, growing and fading as it goes.
    func sleepyZ(from point: CGPoint) {
        makeRoomForMotes(1)
        let z = SKLabelNode(text: "z")
        z.name = "mote"
        z.fontName = NSFont.systemFont(ofSize: 15, weight: .bold).fontName
        z.fontSize = 15
        z.fontColor = NSColor(calibratedRed: 0.49, green: 0.57, blue: 0.62, alpha: 0.85)
        z.position = point
        z.zPosition = 7
        z.setScale(0.55)
        z.alpha = 0
        addChild(z)
        let side: Double = pet.xScale < 0 ? -1 : 1
        let rise = SKAction.moveBy(x: side * 16, y: 38, duration: 2.4)
        rise.timingMode = .easeOut
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.18, duration: 0.8), .rotate(toAngle: -0.12, duration: 0.8),
            .rotate(toAngle: 0.08, duration: 0.8),
        ])
        z.run(
            .sequence([
                .group([
                    rise, sway, .scale(to: 1.15, duration: 2.4),
                    .sequence([.fadeIn(withDuration: 0.4), .wait(forDuration: 1.2), .fadeOut(withDuration: 0.8)]),
                ]),
                .removeFromParent(),
            ]))
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
        // Measured with the whole sentence, then anchored at its top-left so typing never reflows the card.
        let textHeight = label.frame.height
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        let height = max(87, textHeight + 51)
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
        label.position = CGPoint(x: -90, y: 7 + textHeight / 2)
        card.addChild(label)
        let characters = Array(text)
        if !reducedMotion, characters.count > 1 {
            // The note writes itself out, a letter at a time.
            label.text = ""
            let duration = min(1.8, Double(characters.count) * 0.035)
            label.run(
                .sequence([
                    .wait(forDuration: 0.3),
                    .customAction(withDuration: duration) { node, elapsed in
                        let typed = Int((Double(elapsed) / duration * Double(characters.count)).rounded(.up))
                        (node as? SKLabelNode)?.text = String(characters.prefix(min(characters.count, typed)))
                    },
                ]))
        }
        let signature = SKLabelNode(text: "a note from \(nameLabel.text ?? "your companion")  ·  click to tidy")
        signature.fontName = NSFont.systemFont(ofSize: 8).fontName
        signature.fontSize = 8
        signature.fontColor = label.fontColor?.withAlphaComponent(0.5)
        signature.position.y = -height / 2 + 14
        card.addChild(signature)
        addChild(card)
        note = card
        card.alpha = 0
        if reducedMotion {
            card.run(
                .sequence([
                    .fadeIn(withDuration: 0.3), .wait(forDuration: 12), .fadeOut(withDuration: 0.8),
                    .removeFromParent(),
                ]))
        } else {
            // The note drops onto the desk with a little settle, then drifts away when it is done.
            let resting = card.position
            card.position.y += 16
            card.zRotation = -0.16
            card.setScale(0.94)
            let drop = SKAction.move(to: resting, duration: 0.42)
            drop.timingMode = .easeOut
            let turn = SKAction.rotate(toAngle: -0.055, duration: 0.42)
            turn.timingMode = .easeOut
            let grow = SKAction.scale(to: 1, duration: 0.42)
            grow.timingMode = .easeOut
            let away = SKAction.moveBy(x: 0, y: -8, duration: 0.8)
            away.timingMode = .easeIn
            card.run(
                .sequence([
                    .group([drop, turn, grow, .fadeIn(withDuration: 0.25)]), .wait(forDuration: 12),
                    .group([away, .fadeOut(withDuration: 0.8)]), .removeFromParent(),
                ]))
        }
    }

    private func speech(_ text: String) {
        speechBubble?.removeFromParent()
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
        let bubble = CGSize(width: label.frame.width + 26, height: max(31, label.frame.height + 20))
        let pill = SKShapeNode(rectOf: bubble, cornerRadius: 15)
        pill.name = "speech"
        pill.fillColor = bubbleStyle.nsColor
        pill.strokeColor = NSColor(calibratedWhite: 0.3, alpha: 0.12)
        pill.position = speechPosition(width: bubble.width, height: bubble.height)
        pill.zPosition = 9
        // A small tail points down at the companion; it covers the outline where it joins the bubble.
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -7, y: 1))
        tailPath.addQuadCurve(to: CGPoint(x: -1, y: -8), control: CGPoint(x: -3, y: -3))
        tailPath.addQuadCurve(to: CGPoint(x: 7, y: 1), control: CGPoint(x: 2, y: -2))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        tail.fillColor = pill.fillColor
        tail.strokeColor = .clear
        tail.position = CGPoint(
            x: (petLocation.x - pill.position.x).clamped(to: -bubble.width / 2 + 18...bubble.width / 2 - 18),
            y: -bubble.height / 2 + 0.5)
        tail.zPosition = 0.1
        pill.addChild(tail)
        speechTail = tail
        pill.addChild(label)
        addChild(pill)
        speechBubble = pill
        if reducedMotion {
            pill.run(.sequence([.wait(forDuration: speechSeconds), .fadeOut(withDuration: 0.5), .removeFromParent()]))
            return
        }
        // Pops up from the companion with a small overshoot, and shrinks away as it fades.
        pill.alpha = 0
        pill.setScale(0.7)
        let grow = SKAction.scale(to: 1.06, duration: 0.16)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeInEaseOut
        let shrink = SKAction.scale(to: 0.9, duration: 0.35)
        shrink.timingMode = .easeIn
        pill.run(
            .sequence([
                .group([.fadeIn(withDuration: 0.12), .sequence([grow, settle])]),
                .wait(forDuration: max(0.5, speechSeconds - 0.28)),
                .group([.fadeOut(withDuration: 0.35), shrink]), .removeFromParent(),
            ]))
    }

    func speechPosition(width: CGFloat, height: CGFloat) -> CGPoint {
        let margin = min(size.width / 2, width / 2 + 8)
        return CGPoint(
            x: min(max(margin, size.width - margin), max(margin, petLocation.x)),
            y: min(size.height - height / 2 - 8, petLocation.y + pet.size.height + height / 2 + 12))
    }
}
