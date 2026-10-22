import Foundation

public enum BubbleStyle: String, CaseIterable, Codable, Sendable {
    case cream, sage, peach, midnight
    public var title: String { rawValue.capitalized }
}

public enum CoatStyle: String, CaseIterable, Codable, Sendable {
    case cinnamon, honey, dusk, moonlit
    public var title: String { rawValue.capitalized }
}

public enum AccessoryStyle: String, CaseIterable, Codable, Sendable {
    case none, bandana, bow, bell
    public var title: String { rawValue.capitalized }
}

public enum AccessoryColor: String, CaseIterable, Codable, Sendable {
    case forest, rust, lavender, ocean, rose
    public var title: String { rawValue.capitalized }
}

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
    public var avatar: AvatarKind = .miso
    public var mischief: Double = 0.25
    public var size: Double = 1
    public var sound: Bool = false
    public var allSpaces: Bool = true
    public var quietWhenIdle: Bool = true
    public var showName: Bool = false
    public var customQuips: String = ""
    public var includeBuiltInQuips: Bool = true
    public var chatter: Double = 0.35
    public var bubbleStyle: BubbleStyle = .cream
    public var speechSeconds: Double = 4
    public var autoMemes: Bool = false
    public var memeInterval: Double = 600
    public var memeStaySeconds: Double = 20
    public var focusMinutes: Int = 25
    public var completedFocusSessions: Int = 0
    public var coat: CoatStyle = .cinnamon
    public var accessory: AccessoryStyle = .none
    public var accessoryColor: AccessoryColor = .forest
    public var muddyPaws = true
    public var pawprintSeconds: Double = 35
    public var cursorHeists = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case name, avatar, mischief, size, sound, allSpaces, quietWhenIdle, showName
        case customQuips, includeBuiltInQuips, chatter, bubbleStyle, speechSeconds
        case autoMemes, memeInterval, memeStaySeconds, focusMinutes, completedFocusSessions
        case coat, accessory, accessoryColor, muddyPaws, pawprintSeconds, cursorHeists
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? name
        avatar = (try? values.decode(AvatarKind.self, forKey: .avatar)) ?? avatar
        mischief = try values.decodeIfPresent(Double.self, forKey: .mischief) ?? mischief
        size = try values.decodeIfPresent(Double.self, forKey: .size) ?? size
        sound = try values.decodeIfPresent(Bool.self, forKey: .sound) ?? sound
        allSpaces = try values.decodeIfPresent(Bool.self, forKey: .allSpaces) ?? allSpaces
        quietWhenIdle = try values.decodeIfPresent(Bool.self, forKey: .quietWhenIdle) ?? quietWhenIdle
        showName = try values.decodeIfPresent(Bool.self, forKey: .showName) ?? showName
        customQuips = try values.decodeIfPresent(String.self, forKey: .customQuips) ?? customQuips
        includeBuiltInQuips = try values.decodeIfPresent(Bool.self, forKey: .includeBuiltInQuips) ?? includeBuiltInQuips
        chatter = try values.decodeIfPresent(Double.self, forKey: .chatter) ?? chatter
        bubbleStyle = (try? values.decode(BubbleStyle.self, forKey: .bubbleStyle)) ?? bubbleStyle
        speechSeconds = try values.decodeIfPresent(Double.self, forKey: .speechSeconds) ?? speechSeconds
        autoMemes = try values.decodeIfPresent(Bool.self, forKey: .autoMemes) ?? autoMemes
        memeInterval = try values.decodeIfPresent(Double.self, forKey: .memeInterval) ?? memeInterval
        memeStaySeconds = try values.decodeIfPresent(Double.self, forKey: .memeStaySeconds) ?? memeStaySeconds
        focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? focusMinutes
        completedFocusSessions =
            try values.decodeIfPresent(Int.self, forKey: .completedFocusSessions) ?? completedFocusSessions
        coat = (try? values.decode(CoatStyle.self, forKey: .coat)) ?? coat
        accessory = (try? values.decode(AccessoryStyle.self, forKey: .accessory)) ?? accessory
        accessoryColor = (try? values.decode(AccessoryColor.self, forKey: .accessoryColor)) ?? accessoryColor
        muddyPaws = try values.decodeIfPresent(Bool.self, forKey: .muddyPaws) ?? muddyPaws
        pawprintSeconds = try values.decodeIfPresent(Double.self, forKey: .pawprintSeconds) ?? pawprintSeconds
        cursorHeists = try values.decodeIfPresent(Bool.self, forKey: .cursorHeists) ?? cursorHeists
    }

    public var quipLines: [String] {
        var seen = Set<String>()
        return customQuips.components(separatedBy: .newlines).compactMap { line in
            let clean = String(line.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            return clean.isEmpty || !seen.insert(clean).inserted ? nil : clean
        }.prefix(100).map { $0 }
    }

    public var personality: Personality { .closest(to: mischief) }

    public func sanitized() -> Preferences {
        var copy = self
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = cleanName.isEmpty ? "Miso" : String(cleanName.prefix(24))
        copy.mischief = mischief.isFinite ? mischief.clamped(to: 0...1) : 0.25
        copy.size = size.isFinite ? size.clamped(to: 0.65...1.5) : 1
        copy.customQuips = quipLines.joined(separator: "\n")
        copy.chatter = chatter.isFinite ? chatter.clamped(to: 0...1) : 0.35
        copy.speechSeconds = speechSeconds.isFinite ? speechSeconds.clamped(to: 2...12) : 4
        copy.memeInterval = memeInterval.isFinite ? memeInterval.clamped(to: 120...3_600) : 600
        copy.memeStaySeconds = memeStaySeconds.isFinite ? memeStaySeconds.clamped(to: 8...120) : 20
        copy.focusMinutes = min(90, max(1, focusMinutes))
        copy.completedFocusSessions = max(0, completedFocusSessions)
        copy.pawprintSeconds = pawprintSeconds.isFinite ? pawprintSeconds.clamped(to: 8...90) : 35
        return copy
    }
}
