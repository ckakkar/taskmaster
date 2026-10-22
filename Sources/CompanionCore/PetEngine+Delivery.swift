import Foundation

extension PetEngine {
    public mutating func beginDelivery(memeID: String, screenLeft: Double, screenRight: Double, staySeconds: Double) {
        guard delivery == nil, screenLeft.isFinite, screenRight.isFinite, screenRight > screenLeft else { return }
        cancelCursorHeist()
        if aerialRoute != nil { landAerialTour() }
        toy = nil
        snack = nil
        isUserNap = false
        manualFollowUntil = 0
        followingCursorUntil = 0
        let left = position.x < (screenLeft + screenRight) / 2
        let direction = left ? 1.0 : -1.0
        let exit = left ? screenLeft - 460 : screenRight + 460
        let drop = ((screenLeft + screenRight) / 2 + direction * 200).clamped(to: habitat.left...habitat.right)
        delivery = MemeDelivery(
            memeID: memeID, entryDirection: direction, exitX: exit,
            dropPetX: drop, cardPosition: Point(x: drop - direction * 200, y: habitat.floor + 12),
            legStartX: position.x, targetX: exit,
            staySeconds: staySeconds.isFinite ? staySeconds.clamped(to: 8...120) : 20)
        transition(to: aerialRoute == nil ? .walking : avatar == .toothless ? .flying : .grappling, for: .infinity)
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
        } else {
            return
        }
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

    mutating func updateDelivery(_ dt: Double) -> Bool {
        guard var route = delivery else { return false }
        if route.phase == .displaying {
            guard elapsed >= route.leaveAt else { return false }
            route.phase = .collecting
            route.legStartX = position.x
            route.targetX = route.cardPosition.x - route.entryDirection * 200
        }
        let range =
            min(habitat.left, min(route.exitX, route.targetX))...max(habitat.right, max(route.exitX, route.targetX))
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
}
