import Foundation

public struct AerialRoute: Equatable, Sendable {
    public let start: Point
    public let end: Point
    public let anchor: Point
    public let duration: Double
    public internal(set) var age: Double = 0
    public let landing: Bool
    public var progress: Double { (age / duration).clamped(to: 0...1) }
    public var point: Point {
        let t = progress
        let eased = t * t * (3 - 2 * t)
        return Point(
            x: start.x + (end.x - start.x) * eased,
            y: start.y + (end.y - start.y) * eased + sin(t * .pi) * (landing ? 0 : 65))
    }
}
