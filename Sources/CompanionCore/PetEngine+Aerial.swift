import Foundation

extension PetEngine {
    public mutating func startAerialTour() {
        guard avatar == .toothless, !isFocusing, !isPaused else { return }
        cancelCursorHeist()
        cancelDelivery()
        toy = nil
        snack = nil
        manualFollowUntil = 0
        followingCursorUntil = 0
        isUserNap = false
        aerialUntil = elapsed + 25
        nextAerialAt = elapsed + 180
        afterLanding = nil
        nextAerialRoute()
        speak("Mrrp. Watch this.")
    }

    public mutating func landAerialTour() {
        guard aerialRoute != nil else { return }
        aerialUntil = elapsed
        aerialRoute = AerialRoute(
            start: position, end: Point(x: position.x, y: habitat.floor),
            duration: 1.4, landing: true)
    }

    public mutating func cancelAerialTour() {
        guard aerialRoute != nil else { return }
        aerialRoute = nil
        afterLanding = nil
        velocity = .zero
        if position.y > habitat.floor {
            transition(to: .falling, for: .infinity)
        } else {
            transition(to: .sitting, for: 4)
        }
    }

    public mutating func rehome(to habitat: Habitat, changedDisplay: Bool) {
        if changedDisplay { cancelDelivery() }
        changeHabitat(habitat)
    }

    mutating func nextAerialRoute() {
        var end = Point(
            x: random.value(in: habitat.left...habitat.right),
            y: random.value(in: habitat.floor...max(habitat.floor, habitat.ceiling - 65)))
        if isFollowingCursor, let cursor = previousCursor {
            end = habitat.clamped(Point(x: cursor.x, y: cursor.y - 55))
        }
        let duration = (position.distance(to: end) / 210).clamped(to: 1.8...5)
        aerialRoute = AerialRoute(
            start: position, end: end,
            duration: duration, landing: false)
        transition(to: .flying, for: .infinity)
    }

    mutating func updateAerial(_ dt: Double) -> Bool {
        guard var route = aerialRoute else { return false }
        if isFocusing && !route.landing {
            landAerialTour()
            route = aerialRoute!
        }
        route.age += dt
        let previous = position
        position = habitat.clamped(route.point)
        velocity = Point(x: (position.x - previous.x) / dt, y: (position.y - previous.y) / dt)
        if abs(velocity.x) > 8 { facingRight = velocity.x > 0 }
        aerialRoute = route
        guard route.progress >= 1 else { return true }
        if route.landing {
            aerialRoute = nil
            position.y = habitat.floor
            velocity = .zero
            transition(to: .sitting, for: 5)
            events.append(.landing(position, 100))
            if let action = afterLanding {
                afterLanding = nil
                perform(action)
            }
        } else if elapsed >= aerialUntil {
            landAerialTour()
        } else {
            nextAerialRoute()
        }
        return true
    }
}
