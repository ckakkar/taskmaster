import Foundation

public enum Personality: String, CaseIterable, Codable, Sendable {
    case cozy, playful, chaos

    public var title: String { rawValue.capitalized }

    public var symbol: String {
        switch self {
        case .cozy: "moon.stars.fill"
        case .playful: "tennisball.fill"
        case .chaos: "bolt.heart.fill"
        }
    }

    public var mischief: Double {
        switch self {
        case .cozy: 0
        case .playful: 0.5
        case .chaos: 1
        }
    }

    public var description: String {
        switch self {
        case .cozy: "Small paws. Peaceful company."
        case .playful: "A curious little accomplice."
        case .chaos: "Excellent intentions. Questionable ideas."
        }
    }

    public static func closest(to mischief: Double) -> Personality {
        if mischief < 0.3 { return .cozy }
        if mischief < 0.75 { return .playful }
        return .chaos
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var name: String = "Miso"
    public var mischief: Double = 0.25
    public var size: Double = 1
    public var sound: Bool = false
    public var allSpaces: Bool = true
    public var quietWhenIdle: Bool = true
    public var showName: Bool = false

    public init() {}

    public var personality: Personality { .closest(to: mischief) }

    public func sanitized() -> Preferences {
        var copy = self
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = cleanName.isEmpty ? "Miso" : String(cleanName.prefix(24))
        copy.mischief = mischief.isFinite ? mischief.clamped(to: 0...1) : 0.25
        copy.size = size.isFinite ? size.clamped(to: 0.65...1.5) : 1
        return copy
    }
}
