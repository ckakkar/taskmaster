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
        // Walking steps through the painted stride keys, timed by distance travelled (one frame behind the
        // motion model, which is advanced below once the pose is known).
        var nextPose = atlas.pose(for: engine, reducedMotion: reducedMotion)
        var stride: (key: Int, next: Int, mix: Double, within: Double)?
        // Pausing mid-walk holds the current stride drawing rather than snapping back to standing.
        if engine.state == .walking, engine.isPaused || reducedMotion || animation.motion.movement.value > 0.3 {
            let shown = WalkCycle.paintedKey(phase: animation.motion.stride, count: atlas.strideKeys.count)
            stride = (shown.key, shown.next, reducedMotion ? 0 : shown.mix, shown.within)
            nextPose = atlas.strideKeys[shown.key]
        }
        let frame = atlas.frame(for: nextPose)
        if pet.texture == nil || pose != nextPose || coat != preferences.coat {
            let withinStride =
                stride != nil && atlas.strideKeys.contains(pose) && atlas.strideKeys.contains(nextPose)
            if pet.texture != nil && pose != nextPose && !reducedMotion && !withinStride {
                crossfadePose()
                animation.settle(from: pose, to: nextPose)
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
            // Reserve the whole silhouette, including its gentle banking rotation and a wingtip at the top of
            // its upstroke.
            let inset = pet.size.width * 0.53 + pet.size.height * 0.18 + 12
            let top = pet.size.height * 1.1 + pet.size.width * 0.1 + 12
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
            // Each downstroke lifts the body a little; the recovery lets it sink back. The room's preview
            // already fits the banking dragon edge to edge, so it skips the bob.
            if engine.avatar == .toothless, !isPreview {
                point.y += Double(animation.wingAngle(engine: engine)) * 7 * preferences.size
            }
        }
        if !reducedMotion, !engine.isPaused {
            // A tickle is a quick wriggle that fades out; dizziness a slow, woozy sway. Pause holds both still.
            let tickle = max(0, engine.tickledUntil - engine.elapsed) / 1.6
            pet.zRotation += sin(time * 31) * 0.045 * tickle
            if engine.isDizzy, engine.state != .carried {
                pet.zRotation += sin(time * 4.2) * 0.05 * min(1, (engine.dizzyUntil - engine.elapsed) / 1.5)
            }
        }
        if engine.state == .happy && !reducedMotion {
            point.y += abs(sin(engine.stateAge * 7)) * exp(-engine.stateAge * 1.6) * 12
        }
        // Turning around mid-walk is a little hop; stride keys shift so the head stays where it was.
        let hop = engine.state == .walking ? animation.motion.turnLift * 5 * (isPreview ? 1 : preferences.size) : 0
        let strideShift = stride == nil ? 0 : atlas.strideShift(nextPose, scale: scale)
        pet.position = CGPoint(x: point.x + strideShift * (pet.xScale < 0 ? -1 : 1), y: point.y + hop)
        petLocation = point
        if engine.avatar == .toothless, engine.aerialRoute != nil, time >= flightSparkAt, !engine.isPaused {
            flightSparkAt = time + 0.3
            particles(kind: "spark", color: NSColor(calibratedRed: 0.49, green: 0.72, blue: 1, alpha: 0.7), count: 1)
        }
        // A stride dissolve fades the next drawing in over the first half and the current one out over the
        // second, so neither drawing's own paws linger as a ghost and the overlap never turns see-through.
        let dissolving = stride.map { $0.mix > 0.001 && atlas.strideKeys[$0.next] != nextPose } ?? false
        let outgoing = dissolving ? min(1, 2 - 2 * (stride?.mix ?? 0)) : 1
        var wardrobeFrame = frame
        // Painted paws on the floor hold their place while a drawing is shown (the legs shear back as the body
        // travels), so feet don't skate between drawings. The room's preview walks on the spot, so it skips this.
        let petWidth = Double(pet.size.width)
        let travel: Double =
            isPreview || stride == nil
            ? 0 : strideLength / Double(atlas.strideKeys.count) * movement / max(1, petWidth)
        var feet = 0.0
        var incomingFeet = 0.0
        if let stride {
            let keys = atlas.strideKeys
            var start = stride.key
            while start > 0, keys[start - 1] == keys[stride.key] { start -= 1 }
            var length = 1
            while start + length < keys.count, keys[start + length] == keys[stride.key] { length += 1 }
            let progress = (Double(stride.key - start) + stride.within) / Double(length)
            feet = WalkCycle.footHold(within: progress) * travel * Double(length)
            // The incoming drawing starts a run of its own, its paws placed where they will land.
            var nextLength = 1
            while stride.next + nextLength < keys.count, keys[stride.next + nextLength] == keys[stride.next] {
                nextLength += 1
            }
            incomingFeet =
                WalkCycle.footHold(within: (stride.within - 1) / Double(nextLength)) * travel * Double(nextLength)
        }
        footShift = reducedMotion ? 0 : feet
        incomingFootShift = 0
        animation.update(
            sprite: pet, frame: frame, engine: engine, reducedMotion: reducedMotion, opacity: outgoing, footShift: feet)
        if let stride, dissolving {
            let nextPose = atlas.strideKeys[stride.next]
            let next = atlas.frame(for: nextPose)
            if strideBlend.texture == nil || strideBlend.name != "\(nextPose.rawValue)-\(coat.rawValue)" {
                strideBlend.texture = atlas.texture(for: nextPose, coat: coat)
                strideBlend.name = "\(nextPose.rawValue)-\(coat.rawValue)"
            }
            strideBlend.size = CGSize(
                width: Double(next.width) * scale * next.artworkScale,
                height: Double(next.height) * scale * next.artworkScale)
            // The incoming drawing's own width, so its shear matches the same distance on screen.
            incomingFootShift =
                reducedMotion ? 0 : incomingFeet * petWidth / max(1, Double(next.width) * scale * next.artworkScale)
            let offset = atlas.strideShift(nextPose, scale: scale) - strideShift
            strideBlend.position = CGPoint(x: offset, y: 0)
            strideBlend.alpha = min(1, stride.mix * 2)
            strideBlend.isHidden = false
            blendPose = nextPose
            animation.update(
                sprite: strideBlend, frame: next, engine: engine, reducedMotion: reducedMotion, blending: true,
                footShift: incomingFootShift)
            wardrobeFrame = PetScene.neckBlend(
                from: frame, to: next, offset: offset / (scale * frame.artworkScale), mix: stride.mix)
        } else {
            strideBlend.isHidden = true
        }
        wardrobe.update(
            frame: wardrobeFrame, petSize: pet.size, preferences: preferences,
            gaze: animation.attention.gaze, tilt: animation.attention.headTilt,
            time: time, moving: movement, reducedMotion: reducedMotion)
        wardrobe.isHidden = preferences.avatar != .miso || wardrobe.isHidden
        if let transition = poseTransition, transition.parent != nil { transition.position = point }
        if let speech = speechBubble as? SKShapeNode, speech.parent != nil, let body = speech.path?.boundingBox {
            speech.position = speechPosition(width: body.width, height: body.height)
            speechTail?.position.x = (point.x - speech.position.x).clamped(
                to: -body.width / 2 + 18...body.width / 2 - 18)
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
        // Below the paws when there's room; above the head when the floor is the screen's bottom edge
        // (a hidden Dock), so the name never falls off the screen.
        let below = point.y - 20
        nameLabel.position = CGPoint(x: point.x, y: below >= 4 ? below : point.y + pet.size.height + 30)
        nameLabel.isHidden = isPreview || !preferences.showName
        let headSide: Double = pet.xScale < 0 ? -1 : 1
        sleepLabel.position = CGPoint(
            x: point.x + pet.size.width * 0.25 * headSide, y: point.y + pet.size.height + 15 + breath * 3)
        // With motion, sleep is a slow drift of Zs; Reduce Motion keeps the still label.
        sleepLabel.isHidden = engine.state != .sleeping || !reducedMotion
        if engine.state == .sleeping, !reducedMotion, !engine.isPaused, time >= nextSleepZ {
            nextSleepZ = time + 1.5
            let headX: Double = Double(point.x) + Double(pet.size.width) * 0.22 * headSide
            sleepyZ(from: CGPoint(x: headX, y: Double(point.y) + Double(pet.size.height) * 0.8))
        }
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
        updateDizzyStars(engine: engine, time: time)
    }

    /// A frame whose neck landmark sits between two stride keys' necks, in the first key's coordinates,
    /// so an accessory glides with the dissolve instead of jumping when the key changes.
    static func neckBlend(from frame: PetAtlas.Frame, to next: PetAtlas.Frame, offset: Double, mix: Double)
        -> PetAtlas.Frame
    {
        guard let a = frame.neck, let b = next.neck else { return mix < 0.5 ? frame : next }
        let width = Double(frame.width)
        let height = Double(frame.height)
        let bx = ((Double(b.center.x) - 0.5) * Double(next.width) + offset) / width + 0.5
        let by = Double(b.center.y) * Double(next.height) / height
        let bw = Double(b.width) * Double(next.width) / width
        func mixed(_ p: Double, _ q: Double) -> Float { Float(p + (q - p) * mix) }
        var result = frame
        result.neck = PetAtlas.Frame.Neck(
            center: SIMD2(mixed(Double(a.center.x), bx), mixed(Double(a.center.y), by)),
            width: mixed(Double(a.width), bw), angle: a.angle + (b.angle - a.angle) * mix)
        return result
    }

    /// Three little stars circle the head while the companion is dizzy; with Reduce Motion they stay put.
    private func updateDizzyStars(engine: PetEngine, time: Double) {
        guard engine.isDizzy, !engine.isPaused else {
            dizzyStars.isHidden = true
            return
        }
        if dizzyStars.children.isEmpty {
            for _ in 0..<3 {
                let path = CGMutablePath()
                for corner in 0..<10 {
                    let radius = corner % 2 == 0 ? 5.5 : 2.4
                    let angle = Double(corner) * .pi / 5 + .pi / 2
                    let vertex = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                    if corner == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
                }
                path.closeSubpath()
                let star = SKShapeNode(path: path)
                star.fillColor = NSColor(calibratedRed: 1, green: 0.82, blue: 0.35, alpha: 1)
                star.strokeColor = NSColor(calibratedRed: 0.85, green: 0.58, blue: 0.2, alpha: 0.8)
                star.lineWidth = 0.8
                dizzyStars.addChild(star)
            }
        }
        dizzyStars.isHidden = false
        let fade = min(1, (engine.dizzyUntil - engine.elapsed) / 0.6)
        dizzyStars.alpha = fade
        // Circling the crown, above the eyes.
        dizzyStars.position = CGPoint(x: headPoint.x, y: headPoint.y + Double(pet.size.height) * 0.14)
        let radius: Double = max(18, Double(pet.size.width) * 0.16)
        for (index, star) in dizzyStars.children.enumerated() {
            let angle = (reducedMotion ? 0 : time * 4.5) + Double(index) * .pi * 2 / 3
            star.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.32)
            // Stars behind the head are smaller and dimmer.
            star.setScale(0.8 + sin(angle) * -0.2)
            star.zPosition = sin(angle) > 0 ? -0.1 : 0.1
        }
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

    /// The old drawing (with its warp) sits over the new one and fades away, so a pose change dissolves
    /// instead of popping; the motion model adds the squash or stretch.
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
        previous.warpGeometry = pet.warpGeometry
        previous.zPosition = 3.1
        addChild(previous)
        poseTransition = previous
        let fade = SKAction.fadeOut(withDuration: 0.15)
        fade.timingMode = .easeIn
        previous.run(.sequence([fade, .removeFromParent()]))
        pet.alpha = 1
    }
}
