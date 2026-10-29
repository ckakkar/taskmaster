import Foundation

/// Calm moments redraw less often to save energy; anything moving, held or near the pointer stays smooth.
public enum FramePacing {
    public static let active = 60
    public static let calm = 30
    public static let asleep = 20
    /// Tucked away with no room open: only timers (focus, deliveries) need the loop.
    public static let hidden = 4
    /// Lower rates wait this long after the last active moment, so landings and pose blends settle smoothly.
    public static let settleSeconds = 1.0
}

extension PetEngine {
    /// The rendering rate this moment needs. Cursor petting and curiosity measure pointer movement per
    /// frame and were tuned at the active rate, so a pointer near the pet always keeps it.
    public func framesPerSecond(pointer: Point?, isDragging: Bool) -> Int {
        if isDragging { return FramePacing.active }
        if isPaused { return FramePacing.calm }
        if toy != nil || cursorHeist != nil || aerialRoute != nil { return FramePacing.active }
        switch state {
        case .walking, .carried, .falling, .happy, .playing, .curious, .flying: return FramePacing.active
        default: break
        }
        if let pointer, abs(pointer.x - position.x) < 340 * visualScale,
            pointer.y > habitat.floor - 40, pointer.y < position.y + 320 * visualScale
        {
            return FramePacing.active
        }
        return state == .sleeping ? FramePacing.asleep : FramePacing.calm
    }
}
