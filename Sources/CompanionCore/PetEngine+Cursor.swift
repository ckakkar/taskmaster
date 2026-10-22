import Foundation

extension PetEngine {
    @discardableResult
    public mutating func beginCursorHeist(at cursor: Point) -> Bool {
        guard allowsCursorHeists, mischief >= 0.75, !isPaused, !isFocusing,
              cursorHeist == nil, delivery == nil, toy == nil, snack == nil,
              state == .sitting || state == .idle || state == .walking,
              cursor.x.isFinite, cursor.y.isFinite,
              cursor.y > habitat.floor + 15, cursor.y < habitat.floor + 240 * visualScale,
              abs(cursor.x - position.x) < 400 * visualScale else { return false }
        manualFollowUntil = 0; followingCursorUntil = 0
        cursorHeist = CursorHeist()
        nextHeist = elapsed + random.value(in: 90...180)
        transition(to: .walking, for: 1)
        return true
    }

    public mutating func inviteCursorHeist() { nextHeist = elapsed }

    public mutating func cancelCursorHeist() {
        guard cursorHeist != nil else { return }
        cursorHeist = nil
        nextHeist = max(nextHeist, elapsed + 40)
        transition(to: .sitting, for: 4)
    }

    mutating func updateCursorHeist(_ dt: Double, cursor: Point?) -> Bool {
        guard var heist = cursorHeist else { return false }
        heist.age += dt
        if heist.phase == .sneaking {
            guard let cursor, heist.age < 3.5,
                  cursor.y > habitat.floor, cursor.y < habitat.floor + 250 * visualScale else {
                cancelCursorHeist(); return false
            }
            if abs(cursor.x - position.x) < 95 * visualScale {
                facingRight = cursor.x > position.x
                heist.phase = .escaping
                heist.age = 0
                let direction = position.x > (habitat.left + habitat.right) / 2 ? -1.0 : 1.0
                heist.escapeX = (position.x + direction * 260).clamped(to: habitat.left...habitat.right)
                muddyUntil = elapsed + 8
                events.append(.cursorCaught(position))
                speak("Your cursor has been briefly borrowed.")
            } else {
                walk(toward: cursor.x, dt: dt, speed: 155)
            }
        } else {
            guard heist.age < 1.35, abs(heist.escapeX - position.x) > 5 else {
                cancelCursorHeist(); speak("Fine. You may have it back."); return true
            }
            walk(toward: heist.escapeX, dt: dt, speed: 210)
        }
        cursorHeist = heist
        return true
    }

    mutating func observeCursor(_ cursor: Point?, contact: Bool, dt: Double) {
        defer { previousCursor = cursor }
        guard delivery == nil, cursorHeist == nil, !isFocusing else { return }
        guard let cursor, let previousCursor else { return }
        let distance = cursor.distance(to: previousCursor)
        if contact {
            stroke(distance: distance)
            cursorInterest = 0
            return
        }
        strokeDistance = max(0, strokeDistance - dt * 70)
        let nearby = abs(cursor.x - position.x) < 290
            && cursor.y > habitat.floor && cursor.y < habitat.floor + 270
        if nearby, (state == .sitting || state == .idle), abs(cursor.x - position.x) > 95 {
            facingRight = cursor.x > position.x
        }
        guard mischief > 0.3, toy == nil, snack == nil, !isFollowingCursor, nearby, distance > 1, distance < 65,
              state == .sitting || state == .idle || state == .walking,
              elapsed - lastCursorGame > 8 else {
            cursorInterest = max(0, cursorInterest - dt * 2)
            return
        }
        cursorInterest += dt
        if cursorInterest > 0.45 {
            cursorInterest = 0
            lastCursorGame = elapsed
            followingCursorUntil = elapsed + 3.5
            targetX = cursor.x.clamped(to: habitat.left...habitat.right)
            facingRight = targetX > position.x
            velocity = .zero
            transition(to: .curious, for: 0.5)
        }
    }

    /// Real movement over fur earns affection; a stationary hover or cursor jump does not.
    public mutating func stroke(distance: Double) {
        guard !isPaused, distance.isFinite, distance > 0, distance < 80,
              state != .carried, state != .falling else { return }
        strokeDistance += distance
        guard strokeDistance >= 120, elapsed - lastStroke > 1.3 else { return }
        strokeDistance = 0
        lastStroke = elapsed
        perform(.pet)
        if interactionCount % 4 == 0 { speak("That’s the spot.") }
    }
}
