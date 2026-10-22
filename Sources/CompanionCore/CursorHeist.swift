import Foundation

/// A short, cancellable game. Moving the system pointer is the desktop adapter's job.
public struct CursorHeist: Equatable, Sendable {
    public enum Phase: Sendable { case sneaking, escaping }
    public internal(set) var phase: Phase = .sneaking
    public internal(set) var age: Double = 0
    public internal(set) var escapeX: Double = 0
    public var isHoldingCursor: Bool { phase == .escaping }
}
