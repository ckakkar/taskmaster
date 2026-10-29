import Foundation

public struct FocusSession: Sendable {
    public private(set) var deadline: Double?
    public private(set) var duration: Double = 1
    public var isActive: Bool { deadline != nil }
    public init() {}
    public mutating func start(minutes: Int, now: Double) {
        duration = Double(min(90, max(1, minutes))) * 60
        deadline = now + duration
    }
    public func remaining(at now: Double) -> Double { max(0, (deadline ?? now) - now) }
    public func progress(at now: Double) -> Double {
        isActive ? (1 - remaining(at: now) / duration).clamped(to: 0...1) : 0
    }
    /// Picks a session back up after a relaunch, from when it started and when it ends.
    public mutating func resume(startedAt: Double, deadline: Double) {
        guard startedAt.isFinite, deadline.isFinite, deadline > startedAt else { return }
        duration = deadline - startedAt
        self.deadline = deadline
    }
    public mutating func cancel() { deadline = nil }
    public mutating func update(now: Double) -> Bool {
        guard let deadline, now >= deadline else { return false }
        self.deadline = nil
        return true
    }
}
