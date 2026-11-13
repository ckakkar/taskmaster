import CompanionCore
import SpriteKit

/// A light deformation rig preserves the painted fur while moving the head, ears and tail.
/// Walking alternates the painted stride keys; the rig only adds the body's bob and follow-through.
@MainActor
final class PetAnimation {
    private(set) var attention = PetAttention()
    private(set) var motion = PetMotion()
    private(set) var deltaTime: Double = 1.0 / 60
    /// Debug filmstrips substitute a simulated clock so every frame is reproducible.
    var clock: () -> Double = { CACurrentMediaTime() } {
        didSet { lastUpdate = clock() }
    }
    private lazy var lastUpdate = clock()
    private let eyes = EyeShader()
    private let blendEyes = EyeShader()

    func advance(target: Point?, engine: PetEngine, reducedMotion: Bool, strideLength: Double) {
        let now = clock()
        deltaTime = min(0.1, max(0, now - lastUpdate))
        attention.advance(
            seconds: deltaTime, target: target, asleep: engine.state == .sleeping, reducedMotion: reducedMotion)
        motion.advance(seconds: deltaTime, engine: engine, reducedMotion: reducedMotion, strideLength: strideLength)
        lastUpdate = now
    }

    func land(speed: Double) { motion.land(speed: speed) }

    func react(blink: Bool, squash: Double = 0) {
        attention.react(blink: blink)
        if squash != 0 { motion.settle(squash) }
    }

    /// Lower poses squash in; rising ones stretch up. Both spring back to rest.
    func settle(from old: PetPose, to new: PetPose) {
        let low: Set<PetPose> = [.sitting, .sleeping, .playBow, .mischievous]
        switch (low.contains(old), low.contains(new)) {
        case (false, true): motion.settle(new == .sleeping ? -1.2 : -1.9)
        case (true, false): motion.settle(1.5)
        case (true, true): motion.settle(-0.9)
        case (false, false): motion.settle(0.6)
        }
    }

    /// The drawing that is fading in over `sprite` during a stride uses its own eye landmarks.
    func update(
        sprite: SKSpriteNode, frame: PetAtlas.Frame, engine: PetEngine, reducedMotion: Bool, blending: Bool = false
    ) {
        let shader = blending ? blendEyes : eyes
        shader.update(gaze: attention.gaze, blink: attention.blink, frame: frame, avatar: engine.avatar)
        sprite.shader = shader.shader
        sprite.warpGeometry = reducedMotion ? nil : warp(for: frame, engine: engine)
    }

    private func warp(for frame: PetAtlas.Frame, engine: PetEngine) -> SKWarpGeometryGrid {
        let head =
            frame.eyes.isEmpty
            ? SIMD2<Float>(0.64, 0.67)
            : frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        let t = attention.time
        let asleep = engine.state == .sleeping
        let happy = engine.state == .happy
        let walking = engine.state == .walking ? Float(motion.movement.value) : 0
        let stride = motion.stride
        let tailWave =
            (sin(t * (happy ? 5 : 1.8)) + sin(t * 0.73) * 0.28)
            * (asleep ? 0.003 : happy ? 0.026 + engine.affection * 0.008 : 0.017) * Double(1 - walking * 0.6)
        // The tail swings once per stride, a quarter cycle behind the hips; the head dips just after each step.
        let tailStride = Float(sin(stride - 0.8)) * 0.022 * walking
        let bodyBob = Float(WalkCycle.bob(phase: stride)) * 0.011 * walking
        let headBob = Float(-WalkCycle.bob(phase: stride - 0.7)) * 0.006 * walking
        let stretch = engine.state == .stretching ? sin(min(1, engine.stateAge / 3.2) * .pi) : 0
        let flying = engine.avatar == .toothless && engine.aerialRoute != nil
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        source.reserveCapacity(325)
        destination.reserveCapacity(325)
        for row in 0...12 {
            for column in 0...24 {
                let x = Float(column) / 24
                let y = Float(row) / 12
                source.append(SIMD2(x, y))
                let headWeight = exp(-pow((x - head.x) / 0.44, 2) - pow((y - head.y) / 0.4, 2)) * min(1, y * 4)
                let tailWeight = max(0, 1 - x * 2.4) * min(1, y * 3)
                let earWeight = max(0, (y - head.y - 0.12) * 5) * headWeight
                // Paws stay planted; everything above them rides the stride.
                let body = min(1, max(0, (y - 0.1) / 0.3))
                let wing = flying ? sin(t * 8) * 0.055 * Double(max(0, 1 - x * 1.7)) * Double(max(0, y - 0.2)) : 0
                let pawWeight: Float
                if engine.state == .highFive, let paw = frame.paw {
                    pawWeight = exp(-pow((x - paw.x) / 0.25, 2) - pow((y - paw.y) / 0.25, 2))
                } else {
                    pawWeight = 0
                }
                let dx =
                    Float(attention.gaze.x * 0.025) * headWeight
                    - (y - head.y) * Float(attention.headTilt) * headWeight
                    + Float(tailWave + attention.tailFlick * 0.03) * tailWeight
                    + Float(attention.earFlick * 0.022) * earWeight
                    + Float(stretch * 0.025) * headWeight
                    + Float(sin(t * 4) * 0.012) * pawWeight
                let dy =
                    Float(attention.gaze.y * 0.018) * headWeight
                    + (x - head.x) * Float(attention.headTilt) * headWeight
                    + Float(tailWave * 0.6 + attention.tailFlick * 0.022) * tailWeight + tailStride * tailWeight
                    - Float(attention.earFlick * 0.014) * earWeight
                    + Float(attention.engagement * 0.008) * earWeight
                    - Float(stretch * 0.025) * headWeight
                    + Float(cos(t * 4) * 0.008) * pawWeight
                    + bodyBob * body + headBob * headWeight + Float(wing)
                destination.append(SIMD2(x + dx, y + dy))
            }
        }
        return SKWarpGeometryGrid(columns: 24, rows: 12, sourcePositions: source, destinationPositions: destination)
    }
}
