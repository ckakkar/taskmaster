import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func render(engine: PetEngine, preferences: Preferences, origin: CGPoint, reducedMotion: Bool) {
        self.origin = origin
        self.reducedMotion = reducedMotion
        speechSeconds = preferences.speechSeconds
        bubbleStyle = preferences.bubbleStyle
        pawprintSeconds = preferences.pawprintSeconds
        printScale = isPreview ? 0.8 : preferences.size
        if !preferences.muddyPaws { clearFootprints() }
        let nextPose = atlas.pose(for: engine, reducedMotion: reducedMotion)
        let frame = atlas.frame(for: nextPose)
        if pet.texture == nil || pose != nextPose || coat != preferences.coat {
            if pet.texture != nil && pose != nextPose && !reducedMotion {
                crossfadePose()
            }
            pose = nextPose
            coat = preferences.coat
            pet.texture = atlas.texture(for: nextPose, coat: coat)
        }
        let scale =
            isPreview
            ? min(
                (engine.avatar == .toothless ? 150 : 225) / atlas.standingHeight,
                max(80, size.height - 66) / atlas.maximumFrameHeight)
            : 155 / atlas.standingHeight * preferences.size
        pet.size = CGSize(
            width: Double(frame.width) * scale * frame.artworkScale,
            height: Double(frame.height) * scale * frame.artworkScale)
        var ground = isPreview ? CGPoint(x: size.width * 0.5, y: 36) : local(engine.position)
        if isPreview, engine.aerialRoute != nil {
            let x = (engine.position.x - engine.habitat.left) / max(1, engine.habitat.right - engine.habitat.left)
            let y = (engine.position.y - engine.habitat.floor) / max(1, engine.habitat.ceiling - engine.habitat.floor)
            // Reserve the whole silhouette, including its gentle banking rotation.
            let inset = pet.size.width * 0.53 + pet.size.height * 0.18 + 12
            let top = pet.size.height * 1.03 + pet.size.width * 0.1 + 12
            ground = CGPoint(
                x: inset + x * max(0, size.width - 2 * inset),
                y: 36 + y * max(0, size.height - top - 36))
        }
        if isPreview, let route = engine.delivery {
            ground.x = previewPetX(route, petX: engine.position.x, petWidth: pet.size.width)
        }
        let attentionTarget = engine.state == .sniffing ? Point(x: 0.2, y: -0.65) : cursorTarget(at: ground)
        let standing = atlas.frame(for: .standing)
        let strideLength =
            Double(standing.width) * 155 / atlas.standingHeight * preferences.size * WalkCycle.strideRatio
        animation.advance(
            target: attentionTarget, engine: engine, reducedMotion: reducedMotion, strideLength: strideLength)
        facingRight = animation.motion.facingRight
        let time = animation.attention.time
        let movement = reducedMotion ? 0 : animation.motion.movement.value
        let gait = animation.motion.stride
        let breath = reducedMotion ? 0 : sin(time * (engine.state == .sleeping ? 1.3 : 2.1))
        let squash = reducedMotion ? 0 : animation.motion.squash.value
        pet.xScale =
            (facingRight || isPreview ? 1 : -1)
            * (1 - breath * 0.006 * (1 - movement) - squash * 0.55) * (isPreview ? 1 : animation.motion.turnWidth)
        pet.yScale = 1 + breath * (engine.state == .sleeping ? 0.025 : 0.012) + squash
        pet.zRotation =
            reducedMotion
            ? 0
            : (engine.state == .carried
                ? sin(time * 5) * 0.025 + animation.motion.lean.value
                : (sin(time * 1.4) * 0.004 + animation.attention.headTilt * 0.35) * (1 - movement))
        var point = ground
        if engine.aerialRoute != nil, !reducedMotion {
            pet.zRotation = (engine.velocity.y * (facingRight ? 1 : -1) * 0.0007).clamped(to: -0.16...0.16)
        }
        if engine.state == .happy && !reducedMotion {
            point.y += abs(sin(engine.stateAge * 7)) * exp(-engine.stateAge * 1.6) * 12
        }
        pet.position = point
        petLocation = point
        if engine.avatar == .toothless, engine.aerialRoute != nil, time >= flightSparkAt, !engine.isPaused {
            flightSparkAt = time + 0.3
            particles(kind: "spark", color: NSColor(calibratedRed: 0.49, green: 0.72, blue: 1, alpha: 0.7), count: 1)
        }
        animation.update(sprite: pet, frame: frame, engine: engine, reducedMotion: reducedMotion)
        wardrobe.update(
            frame: frame, petSize: pet.size, preferences: preferences,
            gaze: animation.attention.gaze, tilt: animation.attention.headTilt,
            time: time, moving: movement, reducedMotion: reducedMotion)
        wardrobe.isHidden = preferences.avatar != .miso || wardrobe.isHidden
        if let transition = poseTransition, transition.parent != nil { transition.position = point }
        if let speech = speechBubble, speech.parent != nil {
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
            guard index < engine.avatar.feet.count else {
                contact.isHidden = true
                continue
            }
            let step = WalkCycle.foot(phase: gait, offset: engine.avatar.footPhases[index])
            let x = (engine.avatar.feet[index] - 0.5 + step.x * movement) * pet.size.width * pet.xScale
            contact.position = CGPoint(x: point.x + x, y: shadow.position.y + 1)
            contact.alpha = movement * max(0, 1 - step.y / 0.035)
            contact.xScale = isPreview ? 1.4 : preferences.size
            contact.isHidden = engine.state != .walking || reducedMotion
        }
        nameLabel.text = preferences.name
        nameLabel.position = CGPoint(x: point.x, y: point.y - 20)
        nameLabel.isHidden = isPreview || !preferences.showName
        sleepLabel.position = CGPoint(
            x: point.x + pet.size.width * 0.25, y: point.y + pet.size.height + 15 + breath * 3)
        sleepLabel.isHidden = engine.state != .sleeping
        if let toy = engine.toy {
            let plasma = engine.avatar == .toothless
            ball.fillColor =
                plasma
                ? NSColor(calibratedRed: 0.48, green: 0.72, blue: 1, alpha: 1)
                : NSColor(calibratedRed: 0.31, green: 0.59, blue: 0.52, alpha: 1)
            ball.strokeColor = plasma ? .systemPurple : NSColor(calibratedRed: 0.20, green: 0.43, blue: 0.38, alpha: 1)
            ball.glowWidth = plasma ? 8 : 0
            ballStripe.strokeColor =
                plasma
                ? .white.withAlphaComponent(0.8) : NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.71, alpha: 0.9)
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
            snack.position =
                isPreview
                ? CGPoint(x: point.x + (treat.position.x - engine.position.x).clamped(to: -155...155), y: 43)
                : local(treat.position)
            snack.zRotation = sin(time * 2) * 0.06
        }
        pawRing.isHidden = engine.state != .highFive
        if let paw = frame.paw, !pawRing.isHidden {
            pawRing.position = pet.convert(
                CGPoint(
                    x: (Double(paw.x) - 0.5) * pet.size.width,
                    y: Double(paw.y) * pet.size.height), to: self)
            pawRing.setScale(reducedMotion ? 1 : 1 + sin(time * 3) * 0.08)
            pawRing.alpha = reducedMotion ? 0.7 : 0.55 + sin(time * 3) * 0.2
        }
        if engine.isPaused { sleepLabel.isHidden = true }
    }

    private func cursorTarget(at point: CGPoint) -> Point? {
        guard let view, let window = view.window else { return nil }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let inView = view.convert(inWindow, from: nil)
        guard view.bounds.contains(inView) else { return nil }
        let cursor = convertPoint(fromView: inView)
        let head = CGPoint(
            x: point.x + pet.size.width * (pet.xScale > 0 ? 0.15 : -0.15), y: point.y + pet.size.height * 0.68)
        guard hypot(cursor.x - head.x, cursor.y - head.y) < (isPreview ? 650 : 750) else { return nil }
        return Point(x: (cursor.x - head.x) / 145 * (pet.xScale > 0 ? 1 : -1), y: (cursor.y - head.y) / 145)
    }

    private func crossfadePose() {
        poseTransition?.removeFromParent()
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
        poseTransition = previous
        previous.alpha = 0.14
        previous.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
        pet.alpha = 1
    }
}
