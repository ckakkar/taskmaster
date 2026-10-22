import Foundation

public struct CompanionSchedule: Sendable {
    public struct Availability: Sendable {
        public var visible: Bool
        public var paused: Bool
        public var readyForDelivery: Bool
        public init(visible: Bool, paused: Bool, readyForDelivery: Bool) {
            self.visible = visible
            self.paused = paused
            self.readyForDelivery = readyForDelivery
        }
    }
    public struct Update: Sendable {
        public let focusCompleted: Bool
        public let deliverMeme: Bool
    }
    public private(set) var focus = FocusSession()
    public private(set) var nextMeme: Double = 0
    private var automatic = false
    private var interval: Double = 600

    public init(preferences: Preferences, now: Double) { configure(preferences: preferences, now: now) }

    public mutating func configure(preferences: Preferences, now: Double) {
        let clean = preferences.sanitized()
        if nextMeme == 0 || automatic != clean.autoMemes || interval != clean.memeInterval {
            nextMeme = now + clean.memeInterval
        }
        automatic = clean.autoMemes
        interval = clean.memeInterval
    }
    public mutating func startFocus(minutes: Int, now: Double) { focus.start(minutes: minutes, now: now) }
    public mutating func endFocus() { focus.cancel() }
    public mutating func didDeliver(at now: Double) { nextMeme = now + interval }

    public static func endsFocus(_ action: PetAction) -> Bool {
        switch action {
        case .pet, .treat, .saySomething: false
        default: true
        }
    }

    public mutating func update(now: Double, availability: Availability) -> Update {
        if focus.update(now: now) {
            nextMeme = now + interval
            return Update(focusCompleted: true, deliverMeme: false)
        }
        let deliver =
            automatic && now >= nextMeme && !focus.isActive
            && availability.visible && !availability.paused && availability.readyForDelivery
        if deliver { didDeliver(at: now) }
        return Update(focusCompleted: false, deliverMeme: deliver)
    }
}
