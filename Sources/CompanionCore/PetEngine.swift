import Foundation

public enum PetState: String, CaseIterable, Sendable {
    case idle, walking, sitting, sleeping, carried, falling, happy, playing, scheming, curious, highFive, stretching,
        sniffing, flying

    public var description: String {
        switch self {
        case .idle: "Taking it all in"
        case .walking: "On a tiny adventure"
        case .sitting: "Keeping you company"
        case .sleeping: "Dreaming of snacks"
        case .carried: "A little airborne"
        case .falling: "Coming in for a landing"
        case .happy: "Very pleased about this"
        case .playing: "Important ball business"
        case .scheming: "Probably up to something"
        case .curious: "What’s that little thing?"
        case .highFive: "A tiny high five?"
        case .stretching: "A biiig little stretch"
        case .sniffing: "Sniffing out a snack"
        case .flying: "A little dragon. A big sky."
        }
    }
}

public enum PetAction: Sendable {
    case pet, treat, play, nap, wake
    case comeHere(Double)
    case surprise
    case offerHighFive, followCursor, stopFollowing, findTreat, stretch, saySomething, breakReminder
    case muddyZoomies, signature
}

public enum PetEvent: Sendable {
    case hearts(Point)
    case crumbs(Point)
    case landing(Point, Double)
    case footprint(Point, Bool)
    case note(Point, String)
    case speech(String)
    case toyHit(Point)
    case highFive(Point)
    case cursorCaught(Point)
}

public struct Toy: Equatable, Sendable {
    public var position: Point
    public var velocity: Point
    public var age: Double = 0
    public var isHeld: Bool = false
}

public struct Snack: Equatable, Sendable {
    public var position: Point
    public var age: Double = 0
}

public struct PetEngine: Sendable {
    public internal(set) var habitat: Habitat
    public internal(set) var position: Point
    public internal(set) var velocity: Point = .zero
    public internal(set) var state: PetState = .sitting
    public internal(set) var stateAge: Double = 0
    public internal(set) var elapsed: Double = 0
    public internal(set) var facingRight = false
    public internal(set) var toy: Toy?
    public internal(set) var snack: Snack?
    public internal(set) var delivery: MemeDelivery?
    public internal(set) var cursorHeist: CursorHeist?
    public internal(set) var aerialRoute: AerialRoute?
    public var avatar: AvatarKind = .miso
    public var allowsCursorHeists = false { didSet { if !allowsCursorHeists { cancelCursorHeist() } } }
    public var muddyPaws = true
    public var visualScale: Double = 1
    public var cursorAnchor: Point {
        Point(
            x: position.x + (facingRight ? 52 : -52) * visualScale,
            y: position.y + 105 * visualScale)
    }
    public var isFollowingCursor: Bool { elapsed < manualFollowUntil }
    public internal(set) var interactionCount = 0
    public internal(set) var affection: Double = 0.25
    public var mischief: Double = 0.25
    public var isPaused = false { didSet { if isPaused { cancelCursorHeist() } } }
    public var quietWhenIdle = true
    public var isFocusing = false {
        didSet {
            if isFocusing { cancelCursorHeist() } else if oldValue { transition(to: .sitting, for: 4) }
        }
    }
    public var customQuips: [String] = []
    public var includeBuiltInQuips = true
    public var chatter: Double = 0.35
    public var companionName = "Miso"

    var random: RandomStream
    var targetX: Double
    var decisionAt: Double = 7
    var releaseAt: Double = 0
    var dragOffset: Point = .zero
    var events: [PetEvent] = []
    var lastPrank: Double = -18
    var lastToyHit: Double = -2
    var isUserNap = false
    var previousCursor: Point?
    var cursorInterest: Double = 0
    var followingCursorUntil: Double = 0
    var lastCursorGame: Double = -10
    var strokeDistance: Double = 0
    var lastStroke: Double = -2
    var manualFollowUntil: Double = 0
    var nextChatter: Double = 75
    var previousQuip = ""
    var nextHeist: Double = 40
    var muddyUntil: Double = 0
    var footprintX: Double?
    var rightFoot = false
    var aerialUntil: Double = 0
    var afterLanding: PetAction?
    var nextAerialAt: Double = 90
    #if DEBUG
        var debugState: DebugPetState?
    #endif

    public init(habitat: Habitat, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.habitat = habitat
        let startX = max(habitat.left, habitat.right - 130)
        position = Point(x: startX, y: habitat.floor)
        targetX = startX
        random = RandomStream(seed: seed)
    }

    public mutating func changeHabitat(_ newHabitat: Habitat) {
        let oldHabitat = habitat
        cancelCursorHeist()
        footprintX = nil
        habitat = newHabitat
        if var route = aerialRoute {
            func map(_ point: Point) -> Point {
                let x = (point.x - oldHabitat.left) / max(1, oldHabitat.right - oldHabitat.left)
                let y = (point.y - oldHabitat.floor) / max(1, oldHabitat.ceiling - oldHabitat.floor)
                return newHabitat.clamped(
                    Point(
                        x: newHabitat.left + x * (newHabitat.right - newHabitat.left),
                        y: newHabitat.floor + y * (newHabitat.ceiling - newHabitat.floor)))
            }
            route.start = map(route.start)
            route.end = map(route.end)
            position = map(position)
            aerialRoute = route
            return
        }
        if delivery != nil {
            let shift = newHabitat.floor - position.y
            position.y = newHabitat.floor
            delivery!.cardPosition.y += shift
            return
        }
        targetX = targetX.clamped(to: habitat.left...habitat.right)
        if state != .carried {
            position = habitat.clamped(position)
            if state != .falling { position.y = habitat.floor }
        }
        if var ball = toy {
            ball.position = habitat.clamped(ball.position)
            ball.position.y = max(habitat.floor + 12, ball.position.y)
            toy = ball
        }
        if var snack {
            snack.position = Point(x: snack.position.x.clamped(to: habitat.left...habitat.right), y: habitat.floor + 7)
            self.snack = snack
        }
    }

    public mutating func tick(seconds: Double, cursor: Point? = nil, userIdle: Double = 0, cursorContact: Bool = false)
    {
        guard !isPaused, seconds.isFinite, seconds > 0 else { return }
        let dt = min(seconds, 0.1)
        elapsed += dt
        stateAge += dt
        mischief = mischief.isFinite ? mischief.clamped(to: 0...1) : 0.25
        #if DEBUG
            if let debugState {
                updateDebugState(debugState, dt: dt)
                return
            }
        #endif
        updateToy(dt)
        if snack != nil {
            snack!.age += dt
            if snack!.age > 45 { snack = nil }
        }
        observeCursor(cursor, contact: cursorContact, dt: dt)

        if !isFocusing, delivery == nil, chatter > 0, elapsed > nextChatter,
            state == .sitting || state == .idle
        {
            nextChatter = elapsed + random.value(in: 70...180) / max(0.2, chatter)
            speak(
                [
                    "Just checking on my favorite human.", "Small steps count, too.",
                    "I am supervising. Very professionally.", "A tiny pause is allowed.",
                ][Int(random.unit() * 4).clamped(to: 0...3)])
        }

        if state == .carried { return }
        if updateAerial(dt) { return }
        if state == .falling {
            velocity.y -= 1_350 * dt
            position.x = (position.x + velocity.x * dt).clamped(to: habitat.left...habitat.right)
            position.y += velocity.y * dt
            velocity.x *= pow(0.13, dt)
            if position.y <= habitat.floor {
                position.y = habitat.floor
                events.append(.landing(position, abs(velocity.y)))
                velocity = .zero
                transition(to: .sitting, for: 3)
            }
            return
        }
        if state == .sleeping {
            if !isUserNap && userIdle < 30 && stateAge > 25 && elapsed >= releaseAt {
                transition(to: .sitting, for: 5)
            }
            return
        }
        if isFocusing {
            cancelCursorHeist()
            if state == .happy && elapsed < releaseAt { return }
            if state != .sitting { transition(to: .sitting, for: .infinity) }
            return
        }
        if updateDelivery(dt) { return }
        if !allowsCursorHeists || mischief < 0.75 { cancelCursorHeist() }
        if updateCursorHeist(dt, cursor: cursor) { return }
        if allowsCursorHeists, mischief >= 0.75, elapsed >= nextHeist, userIdle < 20, let cursor {
            if beginCursorHeist(at: cursor) { return }
        }
        if state == .highFive || state == .stretching {
            if elapsed >= releaseAt { transition(to: .sitting, for: 5) }
            return
        }
        if quietWhenIdle && userIdle > 300 && toy == nil {
            transition(to: .sleeping, for: 30)
            return
        }
        if state == .happy || state == .scheming {
            if elapsed >= releaseAt { transition(to: .sitting, for: random.value(in: 3...7)) }
            return
        }
        if state == .curious {
            if elapsed >= releaseAt { transition(to: .walking, for: 1) }
            return
        }
        if let snack {
            let distance = snack.position.x - position.x
            if abs(distance) > 30 {
                walk(toward: snack.position.x, dt: dt, speed: 80 + 30 * mischief)
            } else if state != .sniffing {
                velocity = .zero
                transition(to: .sniffing, for: 1.2)
            } else if elapsed >= releaseAt {
                self.snack = nil
                affection = min(1, affection + 0.07)
                transition(to: .happy, for: 3.2)
                events.append(.crumbs(position))
                speak("Found it. Mine now.")
            }
            return
        }
        if state == .sniffing { transition(to: .sitting, for: 4) }
        if let ball = toy, !ball.isHeld, ball.age < 24 {
            targetX = ball.position.x.clamped(to: habitat.left...habitat.right)
            let distance = targetX - position.x
            if abs(distance) > 26 {
                walk(toward: targetX, dt: dt, speed: 95 + 55 * mischief)
            } else {
                if state != .playing { transition(to: .playing, for: 1.3) }
                if ball.position.y < habitat.floor + 95, elapsed - lastToyHit > 1.2 {
                    lastToyHit = elapsed
                    var knocked = ball
                    let direction = position.x > (habitat.left + habitat.right) / 2 ? -1.0 : 1.0
                    knocked.velocity = Point(x: direction * random.value(in: 115...240), y: 240)
                    toy = knocked
                    facingRight = direction > 0
                    events.append(.toyHit(ball.position))
                }
            }
            return
        }
        if state == .playing { transition(to: .sitting, for: 4) }
        if elapsed < followingCursorUntil || isFollowingCursor, let cursor {
            let direction = cursor.x >= position.x ? 1.0 : -1.0
            targetX = (cursor.x - direction * 38).clamped(to: habitat.left...habitat.right)
            if abs(targetX - position.x) > 45 {
                walk(toward: targetX, dt: dt, speed: 95 + mischief * 45)
            } else if state == .walking {
                velocity = .zero
                transition(to: .sitting, for: 3)
            }
            return
        }
        if state == .walking {
            if abs(targetX - position.x) < 4 {
                position.x = targetX
                velocity = .zero
                transition(to: .sitting, for: random.value(in: 3...9))
            } else {
                walk(toward: targetX, dt: dt, speed: elapsed < muddyUntil ? 155 : 36 + 60 * mischief)
            }
        } else if elapsed >= decisionAt {
            decide(cursor: cursor)
        }
    }

    public mutating func perform(_ action: PetAction) {
        if aerialRoute != nil {
            switch action {
            case .pet, .treat:
                interactionCount += 1
                events.append(.hearts(position))
                return
            case .saySomething:
                speak("The view is pretty good up here.")
                return
            case .signature:
                aerialUntil = elapsed + 25
                return
            case .followCursor:
                manualFollowUntil = elapsed + 60
                aerialUntil = elapsed + 60
                return
            default:
                afterLanding = action
                landAerialTour()
                return
            }
        }
        interactionCount += 1
        let speaking: Bool = if case .saySomething = action { true } else { false }
        if !speaking {
            let canKeepCard: Bool =
                switch action {
                case .pet, .treat, .offerHighFive, .stretch, .saySomething: true
                default: false
                }
            cancelCursorHeist()
            if delivery?.phase != .displaying || !canKeepCard { cancelDelivery() }
            affection = min(1, affection + 0.055)
            isUserNap = false
            followingCursorUntil = 0
            manualFollowUntil = 0
            snack = nil
            cursorInterest = 0
            if state == .carried { return }
            if state == .falling { position.y = habitat.floor }
            velocity = .zero
        }
        switch action {
        case .pet:
            let wasHighFive = state == .highFive
            transition(to: .happy, for: 2.8)
            events.append(wasHighFive ? .highFive(position) : .hearts(position))
            if wasHighFive { speak("We make a good team.") }
        case .treat:
            transition(to: .happy, for: 4)
            events.append(.crumbs(position))
            speak(["For me?", "A very good day.", "Excellent snack."][interactionCount % 3])
        case .play:
            let direction = position.x > (habitat.left + habitat.right) / 2 ? -1.0 : 1.0
            toy = Toy(
                position: Point(
                    x: (position.x + direction * 100).clamped(to: habitat.left...habitat.right), y: habitat.floor + 75),
                velocity: Point(x: direction * 95, y: 170)
            )
            transition(to: .playing, for: 2)
        case .nap:
            toy = nil
            isUserNap = true
            transition(to: .sleeping, for: .infinity)
        case .wake:
            transition(to: .sitting, for: 5)
        case .comeHere(let x):
            toy = nil
            targetX = x.clamped(to: habitat.left...habitat.right)
            transition(to: .walking, for: 1)
        case .surprise:
            makeMischief()
        case .offerHighFive:
            toy = nil
            transition(to: .highFive, for: 10)
            speak("Your turn!")
        case .followCursor:
            toy = nil
            if avatar != .miso {
                startAerialTour()
                manualFollowUntil = elapsed + 60
                aerialUntil = elapsed + 60
                break
            }
            manualFollowUntil = elapsed + 60
            transition(to: .sitting, for: 1)
            speak("Lead the way.")
        case .stopFollowing:
            transition(to: .sitting, for: 6)
        case .findTreat:
            toy = nil
            let direction = position.x > (habitat.left + habitat.right) / 2 ? -1.0 : 1.0
            let x = (position.x + direction * random.value(in: 160...330)).clamped(to: habitat.left...habitat.right)
            snack = Snack(position: Point(x: x, y: habitat.floor + 7))
            transition(to: .curious, for: 0.6)
            speak("I smell something good.")
        case .stretch:
            toy = nil
            transition(to: .stretching, for: 3.2)
        case .saySomething:
            speak("Small paws. Big fan of you.")
        case .breakReminder:
            transition(to: .stretching, for: 3.2)
            speak("A little break? Uncurl your shoulders. I’ll keep your place.")
        case .muddyZoomies:
            toy = nil
            muddyUntil = elapsed + 12
            lastPrank = elapsed
            let middle = (habitat.left + habitat.right) / 2
            targetX = position.x > middle ? habitat.left + 30 : habitat.right - 30
            transition(to: .walking, for: 1)
            speak("I have made several artistic decisions.")
        case .signature:
            if avatar == .miso { perform(.muddyZoomies) } else { startAerialTour() }
        }
    }

    public mutating func beginDrag(at pointer: Point) {
        cancelAerialTour()
        cancelCursorHeist()
        cancelDelivery()
        isUserNap = false
        manualFollowUntil = 0
        followingCursorUntil = 0
        snack = nil
        dragOffset = Point(x: position.x - pointer.x, y: position.y - pointer.y)
        velocity = .zero
        transition(to: .carried, for: .infinity)
    }

    public mutating func drag(to pointer: Point, seconds: Double) {
        guard state == .carried else { return }
        let next = habitat.clamped(Point(x: pointer.x + dragOffset.x, y: pointer.y + dragOffset.y))
        let dt = max(0.008, min(0.1, seconds))
        velocity = Point(
            x: ((next.x - position.x) / dt).clamped(to: -650...650),
            y: ((next.y - position.y) / dt).clamped(to: -500...500)
        )
        position = next
    }

    public mutating func endDrag() {
        guard state == .carried else { return }
        transition(to: .falling, for: .infinity)
        velocity.y = min(velocity.y, 80)
    }

    public mutating func drainEvents() -> [PetEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    mutating func transition(to next: PetState, for duration: Double) {
        state = next
        if next != .walking && next != .carried && next != .falling { velocity = .zero }
        stateAge = 0
        releaseAt = elapsed + duration
        decisionAt = releaseAt
    }

    mutating func walk(toward x: Double, dt: Double, speed: Double, bounds: ClosedRange<Double>? = nil) {
        if state != .walking { transition(to: .walking, for: 1) }
        let direction = x > position.x ? 1.0 : -1.0
        let distance = abs(x - position.x)
        let desired = direction * min(speed, sqrt(2 * 380 * distance))
        let acceleration = 400 + mischief * 220
        velocity.x += (desired - velocity.x).clamped(to: -acceleration * dt...acceleration * dt)
        if abs(velocity.x) > 8 { facingRight = velocity.x > 0 }
        let step = velocity.x * dt
        if step * direction > 0 && abs(step) >= distance {
            position.x = x
            velocity.x = 0
        } else {
            position.x += step
        }
        position.x = position.x.clamped(to: bounds ?? habitat.left...habitat.right)
        position.y = habitat.floor
        if muddyPaws, mischief > 0.72 || elapsed < muddyUntil,
            abs(position.x - (footprintX ?? position.x - 28)) >= 25, abs(velocity.x) > 12
        {
            footprintX = position.x
            rightFoot.toggle()
            events.append(.footprint(Point(x: position.x, y: habitat.floor), rightFoot))
        }
    }

    mutating func decide(cursor: Point?) {
        let roll = random.unit()
        if avatar != .miso, mischief > 0.3, elapsed >= nextAerialAt, roll < 0.06 {
            startAerialTour()
            return
        }
        if mischief > 0.45, elapsed - lastPrank > 28, roll < 0.16 + mischief * 0.12 {
            makeMischief()
        } else if roll < 0.22 && mischief < 0.35 {
            isUserNap = false
            transition(to: .sleeping, for: random.value(in: 25...45))
        } else if roll < 0.7 + mischief * 0.2 {
            if mischief > 0.3, let cursor, random.unit() < 0.4 {
                targetX = cursor.x.clamped(to: habitat.left...habitat.right)
            } else {
                targetX = random.value(in: habitat.left...habitat.right)
            }
            transition(to: .walking, for: 1)
        } else {
            transition(to: roll > 0.91 ? .stretching : .idle, for: roll > 0.91 ? 3.2 : random.value(in: 4...9))
        }
    }

}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(range.upperBound, Swift.max(range.lowerBound, self)) }
}
