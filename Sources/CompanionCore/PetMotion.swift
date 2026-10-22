import Foundation

public enum WalkCycle {
    public static let strideRatio: Double = 0.32
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
    private var turnProgress: Double = 1
    private var turnDestination = true
    private var lastPositionX: Double?

    public init() {}

    public mutating func advance(seconds: Double, engine: PetEngine, reducedMotion: Bool, strideLength: Double = 64) {
        let dt = min(0.1, max(0, seconds))
        let walking = engine.state == .walking && !engine.isPaused
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
    }

    public mutating func land(speed: Double) {
        squash.kick(-min(3.5, max(0, speed) / 200))
    }
}
