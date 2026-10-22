import AppKit
import SpriteKit
import CompanionCore

@MainActor
final class PetScene: SKScene {
    let atlas: PetAtlas
    weak var library: MemeLibrary?
    private let pet = SKSpriteNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 110, height: 15))
    private let ball = SKShapeNode(circleOfRadius: 12)
    private let ballStripe = SKShapeNode(circleOfRadius: 8)
    private let nameLabel = SKLabelNode()
    private let sleepLabel = SKLabelNode()
    private let snack = SKShapeNode(circleOfRadius: 8)
    private let pawRing = SKShapeNode(circleOfRadius: 19)
    private var contactShadows: [SKShapeNode] = []
    private var pose: PetPose = .sitting
    private var facingRight = true
    private var origin = CGPoint.zero
    private var isPreview = false
    private var petLocation = CGPoint.zero
    private var reducedMotion = false
    private let animation = PetAnimation()
    private var memeCard: MemeCardNode?
    private let ribbon = SKShapeNode()
    private let focusLabel = SKLabelNode()
    private let focusTrack = SKShapeNode(rectOf: CGSize(width: 58, height: 3), cornerRadius: 1.5)
    private let focusFill = SKShapeNode(rectOf: CGSize(width: 58, height: 3), cornerRadius: 1.5)
    private var speechSeconds: Double = 4
    private var bubbleStyle: BubbleStyle = .cream
    private let wardrobe = PetWardrobe()
    private var pawprintSeconds: Double = 35
    private var printScale: Double = 1

    init(size: CGSize, atlas: PetAtlas, preview: Bool = false) {
        self.atlas = atlas
        isPreview = preview
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        ribbon.strokeColor = NSColor(calibratedRed: 0.67, green: 0.48, blue: 0.32, alpha: 0.65)
        ribbon.lineWidth = 1.5
        ribbon.zPosition = 2.5
        ribbon.isHidden = true
        addChild(ribbon)
        focusLabel.fontName = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium).fontName
        focusLabel.fontSize = 11
        focusLabel.fontColor = NSColor(calibratedRed: 0.30, green: 0.46, blue: 0.36, alpha: 1)
        focusLabel.zPosition = 6
        focusLabel.isHidden = true
        addChild(focusLabel)
        focusTrack.fillColor = .black.withAlphaComponent(0.08)
        focusTrack.strokeColor = .clear
        focusTrack.isHidden = true
        focusTrack.zPosition = 6
        addChild(focusTrack)
        focusFill.fillColor = NSColor(calibratedRed: 0.47, green: 0.62, blue: 0.44, alpha: 1)
        focusFill.strokeColor = .clear
        focusTrack.addChild(focusFill)
        shadow.fillColor = NSColor(calibratedRed: 0.23, green: 0.13, blue: 0.08, alpha: 0.13)
        shadow.strokeColor = .clear
        shadow.zPosition = 0
        addChild(shadow)
        for _ in WalkCycle.footPositions {
            let contact = SKShapeNode(ellipseOf: CGSize(width: 17, height: 4))
            contact.fillColor = NSColor(calibratedRed: 0.28, green: 0.18, blue: 0.11, alpha: 0.18)
            contact.strokeColor = .clear
            contact.zPosition = 0.1
            addChild(contact)
            contactShadows.append(contact)
        }
        pet.anchorPoint = CGPoint(x: 0.5, y: 0)
        pet.zPosition = 3
        addChild(pet)
        wardrobe.zPosition = 0.5
        pet.addChild(wardrobe)

        ball.fillColor = NSColor(calibratedRed: 0.31, green: 0.59, blue: 0.52, alpha: 1)
        ball.strokeColor = NSColor(calibratedRed: 0.20, green: 0.43, blue: 0.38, alpha: 1)
        ball.lineWidth = 1.5
        ball.zPosition = 4
        ball.name = "ball"
        ballStripe.strokeColor = NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.71, alpha: 0.9)
        ballStripe.lineWidth = 2
        ballStripe.fillColor = .clear
        ball.addChild(ballStripe)
        let glint = SKShapeNode(ellipseOf: CGSize(width: 5, height: 3))
        glint.fillColor = .white.withAlphaComponent(0.65)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -4, y: 5)
        ball.addChild(glint)
        ball.isHidden = true
        addChild(ball)

        snack.fillColor = NSColor(calibratedRed: 0.83, green: 0.57, blue: 0.29, alpha: 1)
        snack.strokeColor = NSColor(calibratedRed: 0.57, green: 0.34, blue: 0.17, alpha: 1)
        snack.lineWidth = 1.5
        snack.zPosition = 4
        snack.isHidden = true
        for point in [CGPoint(x: -3, y: 2), CGPoint(x: 3, y: 3), CGPoint(x: 0, y: -3)] {
            let crumb = SKShapeNode(circleOfRadius: 1.4)
            crumb.fillColor = snack.strokeColor
            crumb.strokeColor = .clear
            crumb.position = point
            snack.addChild(crumb)
        }
        addChild(snack)
        pawRing.strokeColor = NSColor(calibratedRed: 0.79, green: 0.47, blue: 0.29, alpha: 0.7)
        pawRing.fillColor = .clear
        pawRing.lineWidth = 1.5
        pawRing.zPosition = 5
        pawRing.isHidden = true
        addChild(pawRing)

        for label in [nameLabel, sleepLabel] {
            label.fontName = NSFont.systemFont(ofSize: 11, weight: .semibold).fontName
            label.fontSize = 11
            label.fontColor = NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.27, alpha: 1)
            label.zPosition = 6
            addChild(label)
        }
        sleepLabel.text = "z  z  z"
        sleepLabel.fontColor = NSColor(calibratedRed: 0.49, green: 0.57, blue: 0.56, alpha: 0.8)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render(engine: PetEngine, preferences: Preferences, origin: CGPoint, reducedMotion: Bool) {
        self.origin = origin
        self.reducedMotion = reducedMotion
        speechSeconds = preferences.speechSeconds
        bubbleStyle = preferences.bubbleStyle
        pawprintSeconds = preferences.pawprintSeconds
        printScale = isPreview ? 0.8 : preferences.size
        if !preferences.muddyPaws { clearFootprints() }
        animation.setCoat(preferences.coat)
        let nextPose = atlas.pose(for: engine, reducedMotion: reducedMotion)
        let frame = atlas.frame(for: nextPose)
        if pet.texture == nil || pose != nextPose {
            if pet.texture != nil && !reducedMotion {
                crossfadePose()
            }
            pose = nextPose
            pet.texture = frame.texture
        }
        let scale = isPreview
            ? min(225 / atlas.standingHeight, max(80, size.height - 66) / atlas.maximumFrameHeight)
            : 155 / atlas.standingHeight * preferences.size
        pet.size = CGSize(width: Double(frame.width) * scale * frame.artworkScale,
                          height: Double(frame.height) * scale * frame.artworkScale)
        var ground = isPreview ? CGPoint(x: size.width * 0.5, y: 36) : local(engine.position)
        if isPreview, let route = engine.delivery { ground.x = previewPetX(route, petX: engine.position.x, petWidth: pet.size.width) }
        let attentionTarget = engine.state == .sniffing ? Point(x: 0.2, y: -0.65) : cursorTarget(at: ground)
        let standing = atlas.frame(for: .standing)
        let strideLength = Double(standing.width) * 155 / atlas.standingHeight * preferences.size * WalkCycle.strideRatio
        animation.advance(target: attentionTarget, engine: engine, reducedMotion: reducedMotion, strideLength: strideLength)
        facingRight = animation.motion.facingRight
        let time = animation.attention.time
        let movement = reducedMotion ? 0 : animation.motion.movement.value
        let gait = animation.motion.stride
        let breath = reducedMotion ? 0 : sin(time * (engine.state == .sleeping ? 1.3 : 2.1))
        let squash = reducedMotion ? 0 : animation.motion.squash.value
        pet.xScale = (facingRight || isPreview ? 1 : -1)
            * (1 - breath * 0.006 * (1 - movement) - squash * 0.55) * (isPreview ? 1 : animation.motion.turnWidth)
        pet.yScale = 1 + breath * (engine.state == .sleeping ? 0.025 : 0.012) + squash
        pet.zRotation = reducedMotion ? 0 : (engine.state == .carried
            ? sin(time * 5) * 0.025 + animation.motion.lean.value
            : (sin(time * 1.4) * 0.004 + animation.attention.headTilt * 0.35) * (1 - movement))
        var point = ground
        if engine.state == .happy && !reducedMotion {
            point.y += abs(sin(engine.stateAge * 7)) * exp(-engine.stateAge * 1.6) * 12
        }
        pet.position = point
        petLocation = point
        animation.update(sprite: pet, frame: frame, engine: engine, reducedMotion: reducedMotion)
        wardrobe.update(frame: frame, petSize: pet.size, preferences: preferences,
                        gaze: animation.attention.gaze, tilt: animation.attention.headTilt,
                        time: time, moving: movement, reducedMotion: reducedMotion)
        childNode(withName: "poseTransition")?.position = point
        if let speech = childNode(withName: "speech") {
            speech.position = speechPosition(width: speech.frame.width, height: speech.frame.height)
        }
        focusLabel.position = CGPoint(x: point.x, y: point.y + pet.size.height + 20)
        focusTrack.position = CGPoint(x: point.x, y: point.y + pet.size.height + 12)
        renderDelivery(engine: engine, point: point)
        shadow.position = CGPoint(x: point.x, y: isPreview ? 35 : engine.habitat.floor - origin.y)
        shadow.xScale = (engine.state == .sleeping ? 1.3 : 1) * (isPreview ? 1.65 : preferences.size)
        let height = max(0, engine.position.y - engine.habitat.floor)
        shadow.alpha = engine.state == .carried ? 0.2 : max(0.15, 1 - height / 400)
        shadow.yScale = 1 - movement * 0.15
        for (index, contact) in contactShadows.enumerated() {
            let step = WalkCycle.foot(phase: gait, offset: WalkCycle.phaseOffsets[index])
            let x = (WalkCycle.footPositions[index] - 0.5 + step.x * movement) * pet.size.width * pet.xScale
            contact.position = CGPoint(x: point.x + x, y: shadow.position.y + 1)
            contact.alpha = movement * max(0, 1 - step.y / 0.035)
            contact.xScale = isPreview ? 1.4 : preferences.size
            contact.isHidden = engine.state != .walking || reducedMotion
        }
        nameLabel.text = preferences.name
        nameLabel.position = CGPoint(x: point.x, y: point.y - 20)
        nameLabel.isHidden = isPreview || !preferences.showName
        sleepLabel.position = CGPoint(x: point.x + pet.size.width * 0.25, y: point.y + pet.size.height + 15 + breath * 3)
        sleepLabel.isHidden = engine.state != .sleeping
        if let toy = engine.toy {
            ball.isHidden = false
            if isPreview {
                ball.position = CGPoint(
                    x: point.x + (toy.position.x - engine.position.x).clamped(to: -150...150),
                    y: 48 + (toy.position.y - engine.habitat.floor).clamped(to: 0...150)
                )
            } else {
                ball.position = local(toy.position)
            }
            ball.zRotation = toy.position.x * 0.04
        } else {
            ball.isHidden = true
        }
        snack.isHidden = engine.snack == nil
        if let treat = engine.snack {
            snack.position = isPreview ? CGPoint(x: point.x + (treat.position.x - engine.position.x).clamped(to: -155...155), y: 43)
                : local(treat.position)
            snack.zRotation = sin(time * 2) * 0.06
        }
        pawRing.isHidden = engine.state != .highFive
        if let paw = frame.paw, !pawRing.isHidden {
            pawRing.position = pet.convert(CGPoint(x: (Double(paw.x) - 0.5) * pet.size.width,
                                                   y: Double(paw.y) * pet.size.height), to: self)
            pawRing.setScale(reducedMotion ? 1 : 1 + sin(time * 3) * 0.08)
            pawRing.alpha = reducedMotion ? 0.7 : 0.55 + sin(time * 3) * 0.2
        }
        if engine.isPaused { sleepLabel.isHidden = true }
    }

    func setFocus(text: String?, progress: Double) {
        focusLabel.text = text
        focusLabel.isHidden = text == nil
        focusTrack.isHidden = text == nil
        let width = progress.clamped(to: 0...1)
        focusFill.xScale = width
        focusFill.position.x = -29 * (1 - width)
    }

    private func previewPetX(_ route: MemeDelivery, petX: Double, petWidth: Double) -> Double {
        let middle = size.width / 2
        let outside = route.entryDirection > 0 ? -petWidth - 160 : size.width + petWidth + 160
        let drop = middle + route.entryDirection * 90
        let pickup = middle - route.entryDirection * 200
        let progress = route.progress(petX: petX)
        switch route.phase {
        case .fetching: return middle + (outside - middle) * progress
        case .bringing: return outside + (drop - outside) * progress
        case .displaying: return drop
        case .collecting: return drop + (pickup - drop) * progress
        case .returning: return pickup + (outside - pickup) * progress
        case .comingHome: return outside + (middle - outside) * progress
        }
    }

    private func renderDelivery(engine: PetEngine, point: CGPoint) {
        guard let route = engine.delivery else {
            if let previous = memeCard {
                previous.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                memeCard = nil
            }
            ribbon.isHidden = true
            return
        }
        if memeCard?.memeID != route.memeID,
           let library, let item = library.items.first(where: { $0.id == route.memeID }) {
            memeCard?.removeFromParent()
            let card = MemeCardNode(item: item, image: library.image(for: item))
            card.setScale(isPreview ? 0.62 : 1)
            memeCard = card
            addChild(card)
        }
        guard let card = memeCard else { return }
        card.isHidden = !route.showsCard
        if isPreview {
            card.position = CGPoint(x: route.isCarrying ? point.x - route.carryDirection * 145 : size.width / 2 - route.entryDirection * 55, y: 40)
        } else { card.position = local(route.cardPosition) }
        card.zRotation = reducedMotion ? 0 : route.isCarrying ? sin(animation.motion.stride) * 0.018 : -0.025
        ribbon.isHidden = !route.isCarrying
        if route.isCarrying {
            let start = CGPoint(x: point.x - route.carryDirection * pet.size.width * 0.27, y: point.y + pet.size.height * 0.5)
            let end = CGPoint(x: card.position.x + route.carryDirection * 133 * card.xScale, y: card.position.y + 120 * card.yScale)
            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 8))
            ribbon.path = path
        }
    }

    func memeAction(at point: CGPoint) -> MemeCardNode.CardAction? {
        guard let card = memeCard, !card.isHidden else { return nil }
        return card.action(at: point)
    }

    private func cursorTarget(at point: CGPoint) -> Point? {
        guard let view, let window = view.window else { return nil }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let inView = view.convert(inWindow, from: nil)
        guard view.bounds.contains(inView) else { return nil }
        let cursor = convertPoint(fromView: inView)
        let head = CGPoint(x: point.x + pet.size.width * (pet.xScale > 0 ? 0.15 : -0.15), y: point.y + pet.size.height * 0.68)
        guard hypot(cursor.x - head.x, cursor.y - head.y) < (isPreview ? 650 : 750) else { return nil }
        return Point(x: (cursor.x - head.x) / 145 * (pet.xScale > 0 ? 1 : -1), y: (cursor.y - head.y) / 145)
    }

    private func crossfadePose() {
        childNode(withName: "poseTransition")?.removeFromParent()
        let previous = SKSpriteNode(texture: pet.texture)
        previous.name = "poseTransition"
        previous.anchorPoint = pet.anchorPoint
        previous.position = pet.position
        previous.size = pet.size
        previous.xScale = pet.xScale
        previous.yScale = pet.yScale
        previous.zRotation = pet.zRotation
        previous.zPosition = 3.1
        addChild(previous)
        previous.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
        pet.alpha = 0
        pet.run(.fadeIn(withDuration: 0.18), withKey: "poseReveal")
    }

    private func speechPosition(width: Double, height: Double) -> CGPoint {
        let margin = min(size.width / 2, width / 2 + 8)
        return CGPoint(x: min(max(margin, size.width - margin), max(margin, petLocation.x)),
                       y: min(size.height - height / 2 - 8, petLocation.y + pet.size.height + height / 2 + 12))
    }

    func hitPet(_ point: CGPoint) -> Bool {
        guard pet.size.width > 0, pet.size.height > 0 else { return false }
        let localPoint = pet.convert(point, from: self)
        let x = localPoint.x / pet.size.width + 0.5
        let y = localPoint.y / pet.size.height
        return atlas.frame(for: pose).contains(x: x, y: y)
    }

    func hitPaw(_ point: CGPoint) -> Bool {
        !pawRing.isHidden && hypot(point.x - pawRing.position.x, point.y - pawRing.position.y) < 24
    }

    func hitBall(_ point: CGPoint) -> Bool {
        !ball.isHidden && hypot(point.x - ball.position.x, point.y - ball.position.y) < 19
    }

    func hitNote(_ point: CGPoint) -> Bool {
        guard let note = childNode(withName: "note") else { return false }
        return note.contains(point)
    }

    func dismissNote() { childNode(withName: "note")?.removeFromParent() }

    func clearFootprints() {
        for node in children where node.name == "footprint" { node.removeFromParent() }
    }

    func handle(_ events: [PetEvent]) {
        for event in events {
            switch event {
            case .hearts:
                particles(kind: "heart", color: NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.39, alpha: 1), count: 6)
            case .highFive:
                particles(kind: "spark", color: NSColor(calibratedRed: 0.93, green: 0.67, blue: 0.28, alpha: 1), count: 10)
                particles(kind: "heart", color: NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.39, alpha: 1), count: 4)
            case .crumbs:
                particles(kind: "crumb", color: NSColor(calibratedRed: 0.77, green: 0.54, blue: 0.23, alpha: 1), count: 9)
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
                particles(kind: "spark", color: NSColor(calibratedRed: 0.89, green: 0.68, blue: 0.34, alpha: 1), count: 3)
            case .cursorCaught:
                particles(kind: "spark", color: NSColor(calibratedRed: 0.93, green: 0.67, blue: 0.28, alpha: 1), count: 7)
            }
        }
    }

    private func local(_ point: Point) -> CGPoint { CGPoint(x: point.x - origin.x, y: point.y - origin.y) }

    private func particles(kind: String, color: NSColor, count: Int) {
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
            node.position = CGPoint(x: petLocation.x + Double(index % 3 - 1) * 16, y: petLocation.y + pet.size.height * 0.7)
            node.zPosition = 8
            node.setScale(0.3)
            addChild(node)
            let spread = Double(index) / Double(max(1, count - 1)) * 90 - 45
            node.run(.sequence([
                .wait(forDuration: Double(index) * 0.07),
                .group([
                    .moveBy(x: spread, y: 45 + Double(index % 3) * 15, duration: 1.2),
                    .sequence([.scale(to: 0.75, duration: 0.2), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.5)]),
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
            speck.fillColor = pad.fillColor.withAlphaComponent(0.23); speck.strokeColor = .clear
            mark.addChild(speck)
        }
        addChild(mark)
        mark.run(.sequence([.wait(forDuration: pawprintSeconds * 0.55), .fadeOut(withDuration: pawprintSeconds * 0.45), .removeFromParent()]))
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
        card.position = CGPoint(x: min(max(120, size.width - 120), max(120, candidateX)), y: petLocation.y + height / 2 + 18)
        card.zRotation = -0.055
        label.position.y = 7
        card.addChild(label)
        let signature = SKLabelNode(text: "a note from your panda  ·  click to tidy")
        signature.fontName = NSFont.systemFont(ofSize: 8).fontName
        signature.fontSize = 8
        signature.fontColor = label.fontColor?.withAlphaComponent(0.5)
        signature.position.y = -height / 2 + 14
        card.addChild(signature)
        addChild(card)
        card.alpha = 0
        card.run(.sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: 12), .fadeOut(withDuration: 0.8), .removeFromParent()]))
    }

    private func speech(_ text: String) {
        childNode(withName: "speech")?.removeFromParent()
        let label = SKLabelNode(text: text)
        label.fontName = NSFont.systemFont(ofSize: 12, weight: .semibold).fontName
        label.fontSize = 12
        label.fontColor = bubbleStyle == .midnight ? NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.87, alpha: 1) : NSColor(calibratedRed: 0.35, green: 0.27, blue: 0.23, alpha: 1)
        label.preferredMaxLayoutWidth = isPreview ? 250 : 290
        label.numberOfLines = 0
        label.verticalAlignmentMode = .center
        let pill = SKShapeNode(rectOf: CGSize(width: label.frame.width + 26, height: max(31, label.frame.height + 20)), cornerRadius: 15)
        pill.name = "speech"
        switch bubbleStyle {
        case .cream: pill.fillColor = NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 1)
        case .sage: pill.fillColor = NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.85, alpha: 1)
        case .peach: pill.fillColor = NSColor(calibratedRed: 1, green: 0.88, blue: 0.81, alpha: 1)
        case .midnight: pill.fillColor = NSColor(calibratedRed: 0.23, green: 0.27, blue: 0.30, alpha: 1)
        }
        pill.strokeColor = NSColor(calibratedWhite: 0.3, alpha: 0.12)
        pill.position = speechPosition(width: pill.frame.width, height: pill.frame.height)
        pill.zPosition = 9
        pill.addChild(label)
        addChild(pill)
        pill.run(.sequence([.wait(forDuration: speechSeconds), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }
}
