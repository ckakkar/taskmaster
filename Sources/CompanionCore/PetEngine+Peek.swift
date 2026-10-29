import Foundation

extension PetEngine {
    /// Starts an edge peek from the nearer side of the screen. Needs `stage` and a free moment.
    @discardableResult
    mutating func beginPeek() -> Bool {
        guard let stage, peek == nil, delivery == nil, aerialRoute == nil, cursorHeist == nil, toy == nil,
            snack == nil, !isFocusing, !isPaused
        else { return false }
        let side: Double = position.x < (stage.lowerBound + stage.upperBound) / 2 ? -1 : 1
        let edge = side < 0 ? stage.lowerBound : stage.upperBound
        // The standing pose is about 191 points wide at 100% size; its head is on the side it faces.
        let width = 191 * visualScale
        peek = EdgePeek(
            side: side,
            hiddenX: edge + side * width * 0.75,
            peekX: edge + side * width * 0.12,
            returnX: side < 0 ? habitat.left + 60 : habitat.right - 60)
        nextPeekAt = elapsed + random.value(in: 150...300)
        manualFollowUntil = 0
        followingCursorUntil = 0
        isUserNap = false
        transition(to: .walking, for: .infinity)
        return true
    }

    /// Ends a peek at once, bringing the companion back onto the desktop.
    public mutating func cancelPeek() {
        guard peek != nil else { return }
        peek = nil
        position = habitat.clamped(position)
        position.y = habitat.floor
        velocity = .zero
        transition(to: .sitting, for: 4)
    }

    /// A peek that gets noticed turns into a "found you": pets and treats land, and the companion comes back in.
    /// Speaking doesn't disturb it; any other action ends the peek first. Returns true when the action is handled.
    mutating func handleDuringPeek(_ action: PetAction) -> Bool {
        guard var route = peek else { return false }
        switch action {
        case .saySomething:
            return false
        case .pet, .treat:
            guard route.isVisible else { break }
            interactionCount += 1
            affection = min(1, affection + 0.055)
            if case .treat = action { events.append(.crumbs(position)) } else { events.append(.hearts(position)) }
            speak("You found me!")
            route.phase = .returning
            peek = route
            transition(to: .walking, for: .infinity)
            return true
        default:
            break
        }
        cancelPeek()
        return false
    }

    mutating func updatePeek(_ dt: Double) -> Bool {
        guard var route = peek else { return false }
        let bounds = min(habitat.left, route.hiddenX)...max(habitat.right, route.hiddenX)
        switch route.phase {
        case .leaving:
            if arrive(at: route.hiddenX, dt: dt, speed: 105 + 45 * mischief, bounds: bounds) {
                route.phase = .hiding
                route.until = elapsed + random.value(in: 2.5...5)
                transition(to: .idle, for: .infinity)
            }
        case .hiding:
            if elapsed >= route.until { route.phase = .peekingIn }
        case .peekingIn:
            if arrive(at: route.peekX, dt: dt, speed: 40, bounds: bounds) {
                route.phase = .peeking
                route.until = elapsed + random.value(in: 3...5)
                facingRight = route.side < 0
                transition(to: .peeking, for: .infinity)
                speak("…did you notice me?")
            }
        case .peeking:
            if elapsed >= route.until { route.phase = .returning }
        case .returning:
            if arrive(at: route.returnX, dt: dt, speed: 70 + 40 * mischief, bounds: bounds) {
                peek = nil
                transition(to: .sitting, for: random.value(in: 4...8))
                return true
            }
        }
        peek = route
        return true
    }

    /// Walks toward `x` and reports arrival, stopping exactly there.
    private mutating func arrive(at x: Double, dt: Double, speed: Double, bounds: ClosedRange<Double>) -> Bool {
        if abs(position.x - x) > 3 {
            walk(toward: x, dt: dt, speed: speed, bounds: bounds)
            return false
        }
        position.x = x
        velocity = .zero
        return true
    }
}
