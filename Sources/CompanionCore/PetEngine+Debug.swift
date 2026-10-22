#if DEBUG
    import Foundation

    public enum DebugPetState: String, CaseIterable, Sendable {
        case sitting, walking, sleeping, flying
    }

    extension PetEngine {
        /// Hold a repeatable workload while using the normal walking/flight physics.
        /// This API and its tick hook do not exist in release builds.
        @discardableResult public mutating func startDebugState(_ selected: DebugPetState) -> Bool {
            guard selected != .flying || avatar == .toothless else { return false }
            debugState = selected
            cancelDelivery()
            cancelCursorHeist()
            toy = nil
            snack = nil
            aerialRoute = nil
            position.y = habitat.floor
            velocity = .zero
            random = RandomStream(seed: 108)
            targetX = habitat.left
            switch selected {
            case .sitting: transition(to: .sitting, for: .infinity)
            case .walking: transition(to: .walking, for: .infinity)
            case .sleeping:
                isUserNap = true
                transition(to: .sleeping, for: .infinity)
            case .flying:
                startAerialTour()
                aerialUntil = .infinity
            }
            events.removeAll()
            return true
        }

        mutating func updateDebugState(_ selected: DebugPetState, dt: Double) {
            switch selected {
            case .sitting, .sleeping:
                let expected: PetState = selected == .sitting ? .sitting : .sleeping
                if state != expected { transition(to: expected, for: .infinity) }
            case .walking:
                if abs(targetX - position.x) < 4 {
                    targetX = targetX == habitat.left ? habitat.right : habitat.left
                }
                walk(toward: targetX, dt: dt, speed: 36 + 60 * mischief)
            case .flying:
                _ = updateAerial(dt)
            }
        }
    }
#endif
