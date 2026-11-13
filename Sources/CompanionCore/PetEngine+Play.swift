import Foundation

/// Small physical games a person starts: booping the nose, tickling with the scroll wheel, shaking the
/// companion about while carrying it, and resting the pointer on its fur.
extension PetEngine {
    public var isDizzy: Bool { elapsed < dizzyUntil }
    public var isTickled: Bool { elapsed < tickledUntil }

    /// Scrolling over the fur tickles once enough of it has built up; it then needs a moment to recover.
    public mutating func scroll(distance: Double) {
        guard !isPaused, distance.isFinite, distance > 0, state != .carried, state != .falling,
            aerialRoute == nil
        else { return }
        scrollDistance += min(distance, 60)
        guard scrollDistance >= 70, elapsed - lastTickle > 1.1 else { return }
        scrollDistance = 0
        lastTickle = elapsed
        perform(.tickle)
    }

    /// A new companion starts fresh, with no dizziness, giggles or half-finished boop combo inherited.
    public mutating func clearReactions() {
        dizzyUntil = -1
        tickledUntil = -1
        boopCount = 0
        shakeTurns.removeAll()
        shakeSign = 0
    }

    mutating func reactToBoop() {
        // Three boops count as a combo only when all of them land within 2.5 seconds.
        if elapsed - boopComboStart > 2.5 {
            boopCount = 0
        }
        if boopCount == 0 { boopComboStart = elapsed }
        boopCount += 1
        events.append(.booped(position))
        if state == .sleeping {
            transition(to: .sitting, for: 4)
            speak("Mm? Oh. Hello.")
        } else if boopCount >= 3 {
            boopCount = 0
            affection = min(1, affection + 0.03)
            transition(to: .happy, for: 2.4)
            speak("Okay, okay. Boop received.")
        } else if state == .walking {
            velocity = .zero
            transition(to: .idle, for: 1.2)
        }
    }

    mutating func reactToTickle() {
        tickledUntil = elapsed + 1.6
        transition(to: .happy, for: 1.8)
        events.append(.giggle(position))
        if interactionCount % 3 == 1 {
            speak(["Stop, that tickles!", "Hee. Hee hee.", "Not the belly!"][interactionCount / 3 % 3])
        }
    }

    /// Four quick changes of direction while carried leave the companion dizzy for a few seconds.
    mutating func noticeShake() {
        let sign = velocity.x > 260 ? 1 : velocity.x < -260 ? -1 : 0
        if sign != 0 {
            if shakeSign != 0, sign != shakeSign { shakeTurns.append(elapsed) }
            shakeSign = sign
        }
        shakeTurns.removeAll { elapsed - $0 > 1.4 }
        guard shakeTurns.count >= 4, !isDizzy else { return }
        shakeTurns.removeAll()
        dizzyUntil = elapsed + 3.5
        events.append(.dizzy(position))
        speak("Wheeeee—")
    }

    /// A pointer resting on the fur for a moment gets a look and a flick of the tail, once per visit.
    mutating func noticeHover(still: Bool, dt: Double) {
        hoverStill = still ? hoverStill + dt : 0
        guard hoverStill > 0.8, !noticedHover, state != .sleeping, state != .carried, state != .falling else {
            return
        }
        noticedHover = true
        events.append(.noticed(position))
    }
}
