import Foundation

public enum WalkCycle {
    /// One full stride covers this fraction of the standing drawing's width. Small animals take quick, short
    /// steps; a short stride also changes drawing often enough to read as motion rather than stop-motion.
    public static let strideRatio: Double = 0.2
    public static let footPositions = [0.28, 0.53, 0.77]
    public static let phaseOffsets = [0.0, 0.5, 0.25]

    /// During stance, local foot velocity exactly cancels the moving body.
    /// The lifted return uses a Hermite curve with matching touchdown velocity.
    public static func foot(phase: Double, offset: Double) -> Point {
        let wrapped = (phase / (.pi * 2) + offset).truncatingRemainder(dividingBy: 1)
        let p = wrapped < 0 ? wrapped + 1 : wrapped
        let stance = 0.62
        if p < stance { return Point(x: strideRatio * (stance / 2 - p), y: 0) }
        let t = (p - stance) / (1 - stance)
        let t2 = t * t
        let t3 = t2 * t
        let halfStep = strideRatio * stance / 2
        let tangent = -strideRatio * (1 - stance)
        let x =
            (2 * t3 - 3 * t2 + 1) * -halfStep + (t3 - 2 * t2 + t) * tangent
            + (-2 * t3 + 3 * t2) * halfStep + (t3 - t2) * tangent
        return Point(x: x, y: pow(sin(t * .pi), 1.2) * 0.055)
    }

    /// The painted keys of one stride, in order: contact A, passing, contact B, passing.
    public static let keyCount = 4

    /// Which painted key shows at a stride phase and how far the following key has dissolved in.
    /// Each key holds for most of its quarter and eases into the next over the last `blend` of it,
    /// so the drawing reads as steps rather than a constant double exposure.
    public static func paintedKey(phase: Double, count: Int = keyCount, blend: Double = 0.35) -> (
        key: Int, next: Int, mix: Double, within: Double
    ) {
        let count = max(1, count)
        guard phase.isFinite else { return (0, 1 % count, 0, 0) }
        let turns = (phase / (.pi * 2)).truncatingRemainder(dividingBy: 1)
        let position = (turns < 0 ? turns + 1 : turns) * Double(count)
        let key = min(count - 1, Int(position))
        let within = position - Double(key)
        let width = blend.clamped(to: 0.01...1)
        let t = ((within - (1 - width)) / width).clamped(to: 0...1)
        return (key, (key + 1) % count, t * t * (3 - 2 * t), within)
    }

    /// How far (as a fraction of one key's travel) painted paws shift back against the body while a key is
    /// held, so feet on the floor stay put instead of skating: ahead of centre as the key starts, behind as it
    /// ends. One key's travel is a quarter of a stride.
    public static func footHold(within: Double) -> Double { 0.5 - within.clamped(to: -1...1) }

    /// Body height through a stride: lowest as a paw lands (contact keys), highest while passing.
    public static func bob(phase: Double) -> Double { -cos(phase * 2) }
}

/// An analytic, critically damped spring stays stable at different display rates.
public struct MotionSpring: Sendable {
    public private(set) var value: Double
    public private(set) var velocity: Double = 0

    public init(_ value: Double = 0) { self.value = value }

    public mutating func advance(to target: Double, seconds: Double, response: Double = 12) {
        guard target.isFinite, seconds.isFinite, seconds > 0 else { return }
        let dt = min(seconds, 0.1)
        let frequency = max(1, response)
        let offset = value - target
        let step = (velocity + frequency * offset) * dt
        let decay = exp(-frequency * dt)
        value = target + (offset + step) * decay
        velocity = (velocity - frequency * step) * decay
    }

    public mutating func kick(_ amount: Double) { if amount.isFinite { velocity += amount } }
}

/// Continuous gait and secondary motion; texture changes never drive the clock.
public struct PetMotion: Sendable {
    public private(set) var stride: Double = 0
    public private(set) var movement = MotionSpring()
    public private(set) var lean = MotionSpring()
    public private(set) var squash = MotionSpring()
    public private(set) var facingRight = true
    public private(set) var turnWidth: Double = 1
    /// A small hop while turning around: 0 when settled, 1 at the middle of the turn.
    public private(set) var turnLift: Double = 0
    private var turnProgress: Double = 1
    private var turnDestination = true
    private var lastPositionX: Double?

    public init() {}

    public mutating func advance(seconds: Double, engine: PetEngine, reducedMotion: Bool, strideLength: Double = 64) {
        let dt = min(0.1, max(0, seconds))
        // A paused companion holds still, mid-stride included, and carries on from there when resumed.
        if engine.isPaused {
            lastPositionX = engine.position.x
            return
        }
        let walking = engine.state == .walking
        movement.advance(to: walking ? 1 : 0, seconds: dt, response: 15)
        lean.advance(
            to: engine.state == .carried
                ? (-engine.velocity.x * 0.00015).clamped(to: -0.12...0.12)
                : walking ? engine.velocity.x * -0.00010 : 0, seconds: dt, response: 9)
        squash.advance(to: 0, seconds: dt, response: 17)
        let distance = lastPositionX.map { engine.position.x - $0 } ?? 0
        if walking && abs(distance) < 80 {
            stride += distance * (engine.facingRight ? 1 : -1) / max(10, strideLength) * .pi * 2
        }
        lastPositionX = engine.position.x
        stride.formTruncatingRemainder(dividingBy: .pi * 2)
        if engine.facingRight != turnDestination {
            turnDestination = engine.facingRight
            turnProgress = 0
        }
        turnProgress = min(1, turnProgress + dt * 5.5)
        if turnProgress >= 0.5 || reducedMotion { facingRight = turnDestination }
        turnWidth = reducedMotion ? 1 : 1 - sin(turnProgress * .pi) * 0.24
        turnLift = reducedMotion ? 0 : sin(turnProgress * .pi)
    }

    public mutating func land(speed: Double) {
        squash.kick(-min(3.5, max(0, speed) / 200))
    }

    /// Squash (negative) or stretch (positive) as the body settles into a new pose.
    public mutating func settle(_ amount: Double) {
        squash.kick(amount.clamped(to: -3...3))
    }
}
