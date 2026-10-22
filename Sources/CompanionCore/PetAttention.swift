import Foundation

/// Small, continuous movements live independently of the pet's larger activities.
public struct PetAttention: Sendable {
    public private(set) var gaze = Point.zero
    public private(set) var blink: Double = 0
    public private(set) var headTilt: Double = 0
    public private(set) var earFlick: Double = 0
    public private(set) var time: Double = 0
    public private(set) var isWatching = false
    public private(set) var engagement: Double = 0
    private var headX = MotionSpring()
    private var headY = MotionSpring()
    private var interest = MotionSpring()
    private var random: RandomStream
    private var nextBlink: Double
    private var blinkStarted: Double = -100
    private var nextEarFlick: Double = 4
    private var earStarted: Double = -100
    private var doubleBlink = false

    public init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        random = RandomStream(seed: seed)
        nextBlink = random.value(in: 2.5...5.5)
    }

    public mutating func advance(seconds: Double, target: Point?, asleep: Bool, reducedMotion: Bool) {
        guard seconds.isFinite, seconds > 0 else { return }
        let dt = min(0.1, seconds)
        time += dt
        isWatching = target != nil && !asleep
        let destination =
            asleep
            ? .zero
            : Point(
                x: (target?.x ?? 0).clamped(to: -1...1),
                y: (target?.y ?? 0).clamped(to: -1...1)
            )
        // Fast enough to acknowledge a person, soft enough to avoid a mechanical snap.
        let follow = 1 - exp(-dt * (isWatching ? 12 : 3.5))
        gaze.x += (destination.x - gaze.x) * follow
        gaze.y += (destination.y - gaze.y) * follow
        headX.advance(to: destination.x, seconds: dt, response: 7)
        headY.advance(to: destination.y, seconds: dt, response: 6)
        interest.advance(to: isWatching ? 1 : 0, seconds: dt, response: 6)
        engagement = interest.value
        headTilt = reducedMotion || asleep ? 0 : headX.value * 0.065 + headY.value * 0.03

        if time >= nextBlink && !asleep {
            blinkStarted = time
            if doubleBlink {
                doubleBlink = false
                nextBlink = time + random.value(in: 3.2...7)
            } else if random.unit() < 0.18 {
                doubleBlink = true
                nextBlink = time + 0.34
            } else {
                nextBlink = time + random.value(in: 3.2...7)
            }
        }
        let phase = (time - blinkStarted) / 0.22
        blink = asleep ? 1 : (phase >= 0 && phase < 1 ? pow(sin(phase * .pi), 0.7) : 0)
        if time >= nextEarFlick {
            earStarted = time
            nextEarFlick = time + random.value(in: 4.5...11)
        }
        let earAge = time - earStarted
        earFlick = reducedMotion || asleep || earAge > 0.48 ? 0 : sin(earAge * 30) * exp(-earAge * 7)
    }
}
