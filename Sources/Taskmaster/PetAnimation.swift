import CompanionCore
import SpriteKit

/// A light deformation rig preserves the painted fur while moving the head, ears and tail.
@MainActor
final class PetAnimation {
    private(set) var attention = PetAttention()
    private(set) var motion = PetMotion()
    private(set) var deltaTime: Double = 1.0 / 60
    private var lastUpdate = CACurrentMediaTime()
    private let eyes = EyeShader()

    func advance(target: Point?, engine: PetEngine, reducedMotion: Bool, strideLength: Double) {
        let now = CACurrentMediaTime()
        deltaTime = min(0.1, max(0, now - lastUpdate))
        attention.advance(
            seconds: deltaTime, target: target, asleep: engine.state == .sleeping, reducedMotion: reducedMotion)
        motion.advance(seconds: deltaTime, engine: engine, reducedMotion: reducedMotion, strideLength: strideLength)
        lastUpdate = now
    }

    func land(speed: Double) { motion.land(speed: speed) }

    func update(sprite: SKSpriteNode, frame: PetAtlas.Frame, engine: PetEngine, reducedMotion: Bool) {
        eyes.update(gaze: attention.gaze, blink: attention.blink, frame: frame, avatar: engine.avatar)
        sprite.shader = eyes.shader
        guard !reducedMotion else {
            sprite.warpGeometry = nil
            return
        }

        let head =
            frame.eyes.isEmpty
            ? SIMD2<Float>(0.64, 0.67)
            : frame.eyes.map(\.center).reduce(.zero, +) / Float(frame.eyes.count)
        let t = attention.time
        let asleep = engine.state == .sleeping
        let happy = engine.state == .happy
        let tailWave =
            (sin(t * (happy ? 5 : 1.8)) + sin(t * 0.73) * 0.28)
            * (asleep ? 0.003 : happy ? 0.026 + engine.affection * 0.008 : 0.017)
        let walking = engine.state == .walking ? Float(motion.movement.value) : 0
        let feet = engine.avatar.footPhases.map { WalkCycle.foot(phase: motion.stride, offset: $0) }
        let stretch = engine.state == .stretching ? sin(min(1, engine.stateAge / 3.2) * .pi) : 0
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
                let legBlend = min(1, max(0, (y - 0.08) / 0.35))
                let legs = 1 - legBlend * legBlend * (3 - 2 * legBlend)
                var gaitX: Float = 0
                var gaitY: Float = 0
                for index in feet.indices {
                    let distance = max(0, abs(x - Float(engine.avatar.feet[index])) - 0.045) / 0.075
                    let weight = exp(-distance * distance) * legs * walking
                    gaitX += Float(feet[index].x) * weight
                    gaitY += Float(feet[index].y - 0.012) * weight
                }
                let bodyRise = Float(sin(motion.stride * 2) * 0.004) * min(1, y * 3) * walking
                let wing =
                    engine.avatar == .toothless && engine.aerialRoute != nil
                    ? sin(t * 8) * 0.055 * Double(max(0, 1 - x * 1.7)) * Double(max(0, y - 0.2)) : 0
                let pawWeight: Float
                if engine.state == .highFive, let paw = frame.paw {
                    pawWeight = exp(-pow((x - paw.x) / 0.25, 2) - pow((y - paw.y) / 0.25, 2))
                } else {
                    pawWeight = 0
                }
                let dx =
                    Float(attention.gaze.x * 0.025) * headWeight
                    - (y - head.y) * Float(attention.headTilt) * headWeight
                    + Float(tailWave) * tailWeight
                    + Float(attention.earFlick * 0.022) * earWeight + gaitX
                    + Float(stretch * 0.025) * headWeight
                    + Float(sin(t * 4) * 0.012) * pawWeight
                let dy =
                    Float(attention.gaze.y * 0.018) * headWeight
                    + (x - head.x) * Float(attention.headTilt) * headWeight
                    + Float(tailWave * 0.6) * tailWeight
                    - Float(attention.earFlick * 0.014) * earWeight + gaitY
                    + Float(attention.engagement * 0.008) * earWeight
                    - Float(stretch * 0.025) * headWeight
                    + Float(cos(t * 4) * 0.008) * pawWeight
                    + bodyRise + Float(wing)
                destination.append(SIMD2(x + dx, y + dy))
            }
        }
        sprite.warpGeometry = SKWarpGeometryGrid(
            columns: 24, rows: 12, sourcePositions: source, destinationPositions: destination)
    }
}
