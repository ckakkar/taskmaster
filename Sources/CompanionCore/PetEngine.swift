import Foundation

public enum PetState: String, CaseIterable, Sendable {
    case idle, walking, sitting, sleeping, carried, falling, happy, playing, scheming, curious

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
        }
    }
}

public enum PetAction: Sendable {
    case pet, treat, play, nap, wake, comeHere(Double), surprise
}

public enum PetEvent: Sendable {
    case hearts(Point)
    case crumbs(Point)
    case landing(Point, Double)
    case footprint(Point, Bool)
    case note(Point, String)
    case speech(String)
    case toyHit(Point)
}

public struct Toy: Equatable, Sendable {
    public var position: Point
    public var velocity: Point
    public var age: Double = 0
    public var isHeld: Bool = false
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
    public private(set) var interactionCount = 0
    public private(set) var affection: Double = 0.25
    public var mischief: Double = 0.25
    public var isPaused = false
    public var quietWhenIdle = true

    private var random: RandomStream
    private var targetX: Double
    private var decisionAt: Double = 7
    private var releaseAt: Double = 0
    private var dragOffset: Point = .zero
    private var events: [PetEvent] = []
    private var nextFootprint: Double = 0
    private var lastPrank: Double = -18
    private var lastToyHit: Double = -2
    private var isUserNap = false
    private var previousCursor: Point?
    private var cursorInterest: Double = 0
    private var followingCursorUntil: Double = 0
    private var lastCursorGame: Double = -10
    private var strokeDistance: Double = 0
    private var lastStroke: Double = -2

    public init(habitat: Habitat, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.habitat = habitat
        let startX = max(habitat.left, habitat.right - 130)
        position = Point(x: startX, y: habitat.floor)
        targetX = startX
        random = RandomStream(seed: seed)
    }

    public mutating func changeHabitat(_ newHabitat: Habitat) {
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
    }

    public mutating func tick(seconds: Double, cursor: Point? = nil, userIdle: Double = 0, cursorContact: Bool = false) {
        guard !isPaused, seconds.isFinite, seconds > 0 else { return }
        let dt = min(seconds, 0.1)
        elapsed += dt
        stateAge += dt
        mischief = mischief.isFinite ? mischief.clamped(to: 0...1) : 0.25
        updateToy(dt)
        observeCursor(cursor, contact: cursorContact, dt: dt)

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
        if elapsed < followingCursorUntil, let cursor {
            targetX = cursor.x.clamped(to: habitat.left...habitat.right)
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
                walk(toward: targetX, dt: dt, speed: 36 + 60 * mischief)
            }
        } else if elapsed >= decisionAt {
            decide(cursor: cursor)
        }
    }

    public mutating func perform(_ action: PetAction) {
        interactionCount += 1
        affection = min(1, affection + 0.055)
        isUserNap = false
        followingCursorUntil = 0
        cursorInterest = 0
        if state == .carried { return }
        if state == .falling { position.y = habitat.floor }
        velocity = .zero
        switch action {
        case .pet:
            transition(to: .happy, for: 2.8)
            events.append(.hearts(position))
        case .treat:
            transition(to: .happy, for: 4)
            events.append(.crumbs(position))
            events.append(.speech(["For me?", "A very good day.", "Excellent snack."][interactionCount % 3]))
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
        if interactionCount % 4 == 0 { events.append(.speech("That’s the spot.")) }
    }

    public mutating func beginDrag(at pointer: Point) {
        isUserNap = false
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

    public mutating func drainEvents() -> [PetEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    private mutating func transition(to next: PetState, for duration: Double) {
        state = next
        stateAge = 0
        releaseAt = elapsed + duration
        decisionAt = releaseAt
    }

    private mutating func observeCursor(_ cursor: Point?, contact: Bool, dt: Double) {
        defer { previousCursor = cursor }
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
        guard mischief > 0.3, toy == nil, nearby, distance > 1, distance < 65,
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

    private mutating func walk(toward x: Double, dt: Double, speed: Double) {
        if state != .walking { transition(to: .walking, for: 1) }
        let direction = x > position.x ? 1.0 : -1.0
        facingRight = direction > 0
        velocity.x = direction * speed
        position.x += direction * min(abs(x - position.x), speed * dt)
        position.x = position.x.clamped(to: habitat.left...habitat.right)
        position.y = habitat.floor
        if mischief > 0.72, elapsed - lastPrank < 8, elapsed > nextFootprint {
            nextFootprint = elapsed + 0.48
            events.append(.footprint(position, facingRight))
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
            transition(to: .idle, for: random.value(in: 4...9))
        }
    }

    private mutating func makeMischief() {
        lastPrank = elapsed
        transition(to: .scheming, for: 4.5)
        let notes = mischief > 0.7
            ? ["this is my desk now.", "urgent: more snacks.", "i have a tiny complaint.", "nothing to see here."]
            : ["a little company for you.", "i brought you a good thought.", "small paws. big fan.", "you can pet the panda."]
        let index = Int(random.unit() * Double(notes.count)).clamped(to: 0...(notes.count - 1))
        events.append(.note(position, notes[index]))
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
