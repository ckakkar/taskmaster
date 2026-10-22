import Foundation

public enum DeliveryPhase: String, Sendable {
    case fetching, bringing, displaying, collecting, returning, comingHome
    public var description: String {
        switch self {
        case .fetching: "Off to find you something"
        case .bringing: "A very important delivery"
        case .displaying: "I thought you’d like this"
        case .collecting: "Tidying up my little delivery"
        case .returning: "Taking this one home"
        case .comingHome: "Back in a moment"
        }
    }
}

public struct MemeDelivery: Equatable, Sendable {
    public let memeID: String
    public internal(set) var phase: DeliveryPhase = .fetching
    public let entryDirection: Double
    public let exitX: Double
    public let dropPetX: Double
    public internal(set) var cardPosition: Point
    public internal(set) var legStartX: Double
    public internal(set) var targetX: Double
    public internal(set) var leaveAt: Double = .infinity
    public let staySeconds: Double
    public var showsCard: Bool { phase != .fetching && phase != .comingHome }
    public var isCarrying: Bool { phase == .bringing || phase == .returning }
    public var carryDirection: Double { phase == .returning ? -entryDirection : entryDirection }
    public func progress(petX: Double) -> Double {
        guard abs(targetX - legStartX) > 0.01 else { return 1 }
        return ((petX - legStartX) / (targetX - legStartX)).clamped(to: 0...1)
    }
}
