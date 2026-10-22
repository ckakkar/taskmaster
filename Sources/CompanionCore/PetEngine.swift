import Foundation

public enum PetState: String, CaseIterable, Sendable {
    case idle, walking, sitting, sleeping, carried, falling, happy, playing, scheming, curious, highFive, stretching, sniffing

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
        }
    }
}

public enum PetAction: Sendable {
    case pet, treat, play, nap, wake, comeHere(Double), surprise
    case offerHighFive, followCursor, stopFollowing, findTreat, stretch, saySomething, breakReminder
    case muddyZoomies
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
    public private(set) var habitat: Habitat
    public private(set) var position: Point
    public private(set) var velocity: Point = .zero
    public private(set) var state: PetState = .sitting
    public private(set) var stateAge: Double = 0
    public private(set) var elapsed: Double = 0
    public private(set) var facingRight = false
    public private(set) var toy: Toy?
    public private(set) var snack: Snack?
    public private(set) var delivery: MemeDelivery?
    public private(set) var cursorHeist: CursorHeist?
    public var allowsCursorHeists = false { didSet { if !allowsCursorHeists { cancelCursorHeist() } } }
    public var muddyPaws = true
    public var visualScale: Double = 1
    public var cursorAnchor: Point {
        Point(x: position.x + (facingRight ? 52 : -52) * visualScale,
              y: position.y + 105 * visualScale)
    }
    public var isFollowingCursor: Bool { elapsed < manualFollowUntil }
    public private(set) var interactionCount = 0
    public private(set) var affection: Double = 0.25
    public var mischief: Double = 0.25
    public var isPaused = false { didSet { if isPaused { cancelCursorHeist() } } }
    public var quietWhenIdle = true
    public var isFocusing = false { didSet { if isFocusing { cancelCursorHeist() } } }
    public var customQuips: [String] = []
    public var includeBuiltInQuips = true
    public var chatter: Double = 0.35
    public var companionName = "Miso"

    private var random: RandomStream
    private var targetX: Double
    private var decisionAt: Double = 7
    private var releaseAt: Double = 0
    private var dragOffset: Point = .zero
    private var events: [PetEvent] = []
    private var lastPrank: Double = -18
    private var lastToyHit: Double = -2
    private var isUserNap = false
    private var previousCursor: Point?
    private var cursorInterest: Double = 0
    private var followingCursorUntil: Double = 0
    private var lastCursorGame: Double = -10
    private var strokeDistance: Double = 0
    private var lastStroke: Double = -2
    private var manualFollowUntil: Double = 0
    private var nextChatter: Double = 75
    private var previousQuip = ""
    private var nextHeist: Double = 40
    private var muddyUntil: Double = 0
    private var footprintX: Double?
    private var rightFoot = false

    public init(habitat: Habitat, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.habitat = habitat
        let startX = max(habitat.left, habitat.right - 130)
        position = Point(x: startX, y: habitat.floor)
        targetX = startX
        random = RandomStream(seed: seed)
    }

    public mutating func changeHabitat(_ newHabitat: Habitat) {
        cancelCursorHeist()
        footprintX = nil
        delivery = nil
        habitat = newHabitat
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

    public mutating func tick(seconds: Double, cursor: Point? = nil, userIdle: Double = 0, cursorContact: Bool = false) {
        guard !isPaused, seconds.isFinite, seconds > 0 else { return }
        let dt = min(seconds, 0.1)
        elapsed += dt
        stateAge += dt
        mischief = mischief.isFinite ? mischief.clamped(to: 0...1) : 0.25
        updateToy(dt)
        if snack != nil {
            snack!.age += dt
            if snack!.age > 45 { snack = nil }
        }
        observeCursor(cursor, contact: cursorContact, dt: dt)

        if !isFocusing, delivery == nil, chatter > 0, elapsed > nextChatter,
           state == .sitting || state == .idle {
            nextChatter = elapsed + random.value(in: 70...180) / max(0.2, chatter)
            speak(["Just checking on my favorite human.", "Small steps count, too.", "I am supervising. Very professionally.", "A tiny pause is allowed."][Int(random.unit() * 4).clamped(to: 0...3)])
        }

        if state == .carried { return }
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
        if (elapsed < followingCursorUntil || isFollowingCursor), let cursor {
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
        if case .saySomething = action {
            interactionCount += 1
            speak("Small paws. Big fan of you.")
            return
        }
        let canKeepCard: Bool = switch action {
        case .pet, .treat, .offerHighFive, .stretch, .saySomething: true
        default: false
        }
        cancelCursorHeist()
        if delivery?.phase != .displaying || !canKeepCard { cancelDelivery() }
        interactionCount += 1
        affection = min(1, affection + 0.055)
        isUserNap = false
        followingCursorUntil = 0
        manualFollowUntil = 0
        snack = nil
        cursorInterest = 0
        if state == .carried { return }
        if state == .falling { position.y = habitat.floor }
        velocity = .zero
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
                position: Point(x: (position.x + direction * 100).clamped(to: habitat.left...habitat.right), y: habitat.floor + 75),
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

    public mutating func beginDrag(at pointer: Point) {
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

    public mutating func holdToy(at pointer: Point) {
        guard var ball = toy else { return }
        ball.isHeld = true
        ball.position = habitat.clamped(pointer)
        ball.position.y = max(habitat.floor + 12, ball.position.y)
        ball.velocity = .zero
        ball.age = 0
        toy = ball
    }

    public mutating func releaseToy(velocity: Point) {
        guard var ball = toy else { return }
        ball.isHeld = false
        ball.velocity = Point(x: velocity.x.clamped(to: -850...850), y: velocity.y.clamped(to: -650...850))
        toy = ball
    }

    public mutating func removeToy() { toy = nil }

    public mutating func beginDelivery(memeID: String, screenLeft: Double, screenRight: Double, staySeconds: Double) {
        guard delivery == nil, screenLeft.isFinite, screenRight.isFinite, screenRight > screenLeft else { return }
        cancelCursorHeist()
        toy = nil; snack = nil; isUserNap = false
        manualFollowUntil = 0; followingCursorUntil = 0
        let left = position.x < (screenLeft + screenRight) / 2
        let direction = left ? 1.0 : -1.0
        let exit = left ? screenLeft - 460 : screenRight + 460
        let drop = ((screenLeft + screenRight) / 2 + direction * 200).clamped(to: habitat.left...habitat.right)
        delivery = MemeDelivery(memeID: memeID, entryDirection: direction, exitX: exit,
            dropPetX: drop, cardPosition: Point(x: drop - direction * 200, y: habitat.floor + 12),
            legStartX: position.x, targetX: exit, staySeconds: staySeconds.isFinite ? staySeconds.clamped(to: 8...120) : 20)
        transition(to: .walking, for: .infinity)
    }

    public mutating func recallDelivery() {
        guard var route = delivery else { return }
        if route.phase == .fetching {
            route.phase = .comingHome
            route.legStartX = position.x
            route.targetX = position.x.clamped(to: habitat.left...habitat.right)
        } else if route.phase == .displaying || route.phase == .bringing {
            route.phase = .collecting
            route.legStartX = position.x
            route.targetX = route.cardPosition.x - route.entryDirection * 200
        } else { return }
        delivery = route
        transition(to: .walking, for: .infinity)
    }

    public mutating func keepDeliveryLonger() {
        guard delivery?.phase == .displaying else { return }
        delivery!.leaveAt = min(elapsed + 180, delivery!.leaveAt + 30)
    }

    public mutating func cancelDelivery() {
        guard delivery != nil else { return }
        delivery = nil
        position = habitat.clamped(position)
        position.y = habitat.floor
        velocity = .zero
        transition(to: .sitting, for: 4)
    }

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

    private mutating func updateCursorHeist(_ dt: Double, cursor: Point?) -> Bool {
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

    private mutating func updateDelivery(_ dt: Double) -> Bool {
        guard var route = delivery else { return false }
        if route.phase == .displaying {
            guard elapsed >= route.leaveAt else { return false }
            route.phase = .collecting
            route.legStartX = position.x
            route.targetX = route.cardPosition.x - route.entryDirection * 200
        }
        let range = min(habitat.left, min(route.exitX, route.targetX))...max(habitat.right, max(route.exitX, route.targetX))
        if abs(position.x - route.targetX) > 3 {
            walk(toward: route.targetX, dt: dt, speed: 145 + 35 * mischief, bounds: range)
            if route.isCarrying {
                facingRight = route.carryDirection < 0
                route.cardPosition = Point(x: position.x - route.carryDirection * 200, y: habitat.floor + 12)
            }
            delivery = route
            return true
        }
        position.x = route.targetX
        velocity = .zero
        route.legStartX = position.x
        switch route.phase {
        case .fetching:
            route.phase = .bringing
            route.targetX = route.dropPetX
            route.cardPosition = Point(x: position.x - route.entryDirection * 200, y: habitat.floor + 12)
        case .bringing:
            route.cardPosition = Point(x: position.x - route.entryDirection * 200, y: habitat.floor + 12)
            route.phase = .displaying
            route.leaveAt = elapsed + route.staySeconds
            transition(to: .sitting, for: route.staySeconds + 1)
            speak("I brought you a little something.")
        case .collecting:
            route.phase = .returning
            route.targetX = route.exitX
        case .returning:
            route.phase = .comingHome
            route.targetX = route.exitX < habitat.left ? habitat.left + 70 : habitat.right - 70
            route.targetX = route.targetX.clamped(to: habitat.left...habitat.right)
        case .comingHome:
            delivery = nil
            transition(to: .sitting, for: 7)
            return true
        case .displaying: break
        }
        delivery = route
        return true
    }

    private mutating func pickQuip(_ fallback: String) -> String? {
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

    private mutating func speak(_ fallback: String) {
        if let text = pickQuip(fallback) { events.append(.speech(text)) }
    }

    public mutating func drainEvents() -> [PetEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    private mutating func transition(to next: PetState, for duration: Double) {
        state = next
        if next != .walking && next != .carried && next != .falling { velocity = .zero }
        stateAge = 0
        releaseAt = elapsed + duration
        decisionAt = releaseAt
    }

    private mutating func observeCursor(_ cursor: Point?, contact: Bool, dt: Double) {
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

    private mutating func walk(toward x: Double, dt: Double, speed: Double, bounds: ClosedRange<Double>? = nil) {
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
           abs(position.x - (footprintX ?? position.x - 28)) >= 25, abs(velocity.x) > 12 {
            footprintX = position.x
            rightFoot.toggle()
            events.append(.footprint(Point(x: position.x, y: habitat.floor), rightFoot))
        }
    }

    private mutating func decide(cursor: Point?) {
        let roll = random.unit()
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

    private mutating func makeMischief() {
        lastPrank = elapsed
        transition(to: .scheming, for: 4.5)
        let notes = mischief > 0.7
            ? ["this is my desk now.", "urgent: more snacks.", "i have a tiny complaint.", "nothing to see here."]
            : ["a little company for you.", "i brought you a good thought.", "small paws. big fan.", "you can pet the panda."]
        let index = Int(random.unit() * Double(notes.count)).clamped(to: 0...(notes.count - 1))
        if let text = pickQuip(notes[index]) { events.append(.note(position, text)) }
    }

    private mutating func updateToy(_ dt: Double) {
        guard var ball = toy else { return }
        ball.age += dt
        if ball.age > 30 {
            toy = nil
            return
        }
        if !ball.isHeld {
            ball.velocity.y -= 850 * dt
            ball.position.x += ball.velocity.x * dt
            ball.position.y += ball.velocity.y * dt
            if ball.position.y < habitat.floor + 12 {
                ball.position.y = habitat.floor + 12
                ball.velocity.y = abs(ball.velocity.y) > 24 ? abs(ball.velocity.y) * 0.66 : 0
                ball.velocity.x *= pow(0.35, dt)
            }
            if ball.position.x < habitat.left {
                ball.position.x = habitat.left
                ball.velocity.x = abs(ball.velocity.x) * 0.8
            } else if ball.position.x > habitat.right {
                ball.position.x = habitat.right
                ball.velocity.x = -abs(ball.velocity.x) * 0.8
            }
            ball.position.y = min(ball.position.y, habitat.ceiling + 100)
        }
        toy = ball
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(range.upperBound, Swift.max(range.lowerBound, self)) }
}
