import Foundation

extension PetEngine {
    mutating func pickQuip(_ fallback: String) -> String? {
        guard chatter > 0 else { return nil }
        var lines = customQuips
        if includeBuiltInQuips { lines.append(fallback) }
        if lines.count > 1 {
            let fresh = lines.filter { $0 != previousQuip }
            if !fresh.isEmpty { lines = fresh }
        }
        guard !lines.isEmpty else { return nil }
        let index = Int(random.unit() * Double(lines.count)).clamped(to: 0...(lines.count - 1))
        previousQuip = lines[index]
        return lines[index].replacingOccurrences(of: "{name}", with: companionName)
    }

    /// Speech that does a job, such as a break reminder: always said, whatever the voice settings.
    mutating func announce(_ text: String) {
        events.append(.speech(text.replacingOccurrences(of: "{name}", with: companionName)))
    }

    mutating func speak(_ fallback: String) {
        if let text = pickQuip(fallback) { events.append(.speech(text)) }
    }

    mutating func makeMischief() {
        lastPrank = elapsed
        transition(to: .scheming, for: 4.5)
        let notes =
            mischief > 0.7
            ? ["this is my desk now.", "urgent: more snacks.", "i have a tiny complaint.", "nothing to see here."]
            : [
                "a little company for you.", "i brought you a good thought.", "small paws. big fan.",
                "a tiny high five, perhaps?",
            ]
        let index = Int(random.unit() * Double(notes.count)).clamped(to: 0...(notes.count - 1))
        if let text = pickQuip(notes[index]) { events.append(.note(position, text)) }
    }
}
