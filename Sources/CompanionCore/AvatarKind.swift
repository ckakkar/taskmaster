import Foundation

public enum AvatarKind: String, CaseIterable, Codable, Sendable {
    case miso, toothless, robin
    public static let available: [AvatarKind] = [.miso, .toothless]
    public var footPhases: [Double] {
        switch self {
        case .miso: WalkCycle.phaseOffsets
        case .toothless: [0, 0.5, 0.25, 0.75]
        case .robin: [0, 0.5]
        }
    }
    public var title: String {
        switch self {
        case .miso: "Miso"
        case .toothless: "Toothless"
        case .robin: "Robin"
        }
    }
    public var subtitle: String {
        switch self {
        case .miso: "Small paws. Big opinions."
        case .toothless: "A sky full of tiny adventures."
        case .robin: "Your desktop’s little guardian."
        }
    }
    public var symbol: String {
        switch self {
        case .miso: "pawprint.fill"
        case .toothless: "sparkles"
        case .robin: "bolt.shield.fill"
        }
    }
    public var signature: String {
        switch self {
        case .miso: "Muddy zoomies"
        case .toothless: "Take flight"
        case .robin: "Grapple patrol"
        }
    }
    public var atlasName: String {
        switch self {
        case .miso: "MisoAtlas"
        case .toothless: "ToothlessAtlas"
        case .robin: "RobinAtlas"
        }
    }
    public var feet: [Double] {
        switch self {
        case .miso: WalkCycle.footPositions
        case .toothless: [0.40, 0.50, 0.66, 0.76]
        case .robin: [0.49, 0.70]
        }
    }
}
