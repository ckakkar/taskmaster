import Foundation

public struct Point: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)

    public func distance(to other: Point) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

public struct Habitat: Equatable, Sendable {
    public var left: Double
    public var right: Double
    public var floor: Double
    public var ceiling: Double

    public init(left: Double, right: Double, floor: Double, ceiling: Double) {
        self.left = left
        self.right = max(left, right)
        self.floor = floor
        self.ceiling = max(floor, ceiling)
    }

    public func clamped(_ point: Point) -> Point {
        Point(x: point.x.clamped(to: left...right), y: point.y.clamped(to: floor...ceiling))
    }
}

extension Double {
    public func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}

/// A reproducible random stream makes long behaviour and recovery tests possible.
struct RandomStream: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xCAFE_F00D : seed
    }

    mutating func unit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}
