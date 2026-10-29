import Foundation

/// A short game of hide-and-seek: walk off the side of the screen, wait out of sight, then peek back in.
public struct EdgePeek: Equatable, Sendable {
    public enum Phase: Sendable {
        case leaving, hiding, peekingIn, peeking, returning
    }
    public internal(set) var phase: Phase = .leaving
    /// -1 for the left edge of the screen, 1 for the right.
    public let side: Double
    /// Fully past the edge, out of sight.
    public let hiddenX: Double
    /// Just inside the edge, so the head and shoulders show.
    public let peekX: Double
    /// Back on the desktop afterwards.
    public let returnX: Double
    public internal(set) var until: Double = 0
    /// Whether any of the companion can be seen right now.
    public var isVisible: Bool { phase != .hiding }
}
