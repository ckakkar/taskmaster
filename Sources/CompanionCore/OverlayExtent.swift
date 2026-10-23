import Foundation

/// The desktop overlay covers only a strip along the floor, because drawing and compositing a
/// full-screen transparent layer costs GPU time on every frame. It grows to the whole screen
/// while something can be above that strip.
public enum OverlayExtent {
    /// The strip's height above the floor: the tallest grounded pose plus room for speech, notes and cards.
    public static func stripHeight(size: Double) -> Double { 260 + 230 * size }
    /// The whole screen stays in use this long after the last reason for it, so bounces and landings finish.
    public static let holdSeconds = 1.5
}

extension PetEngine {
    /// Whether anything can be drawn above `stripTop` (in the same coordinates as the habitat):
    /// a held, falling or flying pet, or a ball that is held or will rise near the strip's top.
    public func reachesAbove(_ stripTop: Double, isDragging: Bool) -> Bool {
        if isDragging || state == .carried || state == .falling || aerialRoute != nil { return true }
        if position.y > habitat.floor + 1 { return true }
        guard let toy else { return false }
        // Top of the ball's current arc under its 850 points/s² gravity.
        let apex = toy.position.y + max(0, toy.velocity.y) * max(0, toy.velocity.y) / 1_700
        return toy.isHeld || apex > stripTop - 60
    }
}
