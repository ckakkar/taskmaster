import Foundation
import Testing

@testable import CompanionCore

private let desk = Habitat(left: 110, right: 1_330, floor: 20, ceiling: 700)
private let screen: ClosedRange<Double> = 0...1_440
private let farCursor = Point(x: -2_000, y: 900)

/// Runs a long, quiet session (nobody nearby, never away) and records what the companion chose to do.
private func session(seconds: Double, configure: (inout PetEngine) -> Void) -> (PetEngine, [PetState], [PetEvent]) {
    var pet = PetEngine(habitat: desk, seed: 160)
    pet.quietWhenIdle = false
    pet.stage = screen
    configure(&pet)
    var states: [PetState] = []
    var events: [PetEvent] = []
    for _ in 0..<Int(seconds * 30) {
        pet.tick(seconds: 1.0 / 30, cursor: farCursor)
        states.append(pet.state)
        events += pet.drainEvents()
    }
    return (pet, states, events)
}

private func notes(_ events: [PetEvent]) -> Int {
    events.filter { if case .note = $0 { true } else { false } }.count
}

@Test func turningWanderingOffKeepsTheCompanionWhereItIs() {
    let (pet, states, _) = session(seconds: 300) {
        $0.mischief = 0.5
        $0.wanders = false
        $0.peeksFromEdges = false
        $0.leavesNotes = false
    }
    #expect(!states.contains(.walking))
    #expect(pet.position.x == desk.right - 130)
    let (_, wandering, _) = session(seconds: 300) {
        $0.mischief = 0.5
        $0.peeksFromEdges = false
        $0.leavesNotes = false
    }
    #expect(wandering.contains(.walking))
}

@Test func napsAndNotesEachHaveTheirOwnSwitch() {
    let (_, napping, _) = session(seconds: 400) { $0.mischief = 0 }
    #expect(napping.contains(.sleeping))
    let (_, awake, _) = session(seconds: 400) {
        $0.mischief = 0
        $0.napsOnItsOwn = false
    }
    #expect(!awake.contains(.sleeping))

    let (_, _, scribbled) = session(seconds: 400) { $0.mischief = 1 }
    #expect(notes(scribbled) > 0)
    var noNotes = session(seconds: 400) {
        $0.mischief = 1
        $0.leavesNotes = false
    }
    #expect(notes(noNotes.2) == 0)
    // Asking for a surprise still works with the switch off.
    noNotes.0.perform(.surprise)
    #expect(notes(noNotes.0.drainEvents()) == 1)
}

@Test func cursorCuriosityAndFlightsCanBeTurnedOff() {
    for curious in [true, false] {
        var pet = PetEngine(habitat: desk, seed: 161)
        pet.mischief = 0.6
        pet.curiousAboutCursor = curious
        let start = pet.position.x
        var investigated = false
        for i in 0..<90 {
            pet.tick(seconds: 1.0 / 30, cursor: Point(x: start - 140 + sin(Double(i) * 0.3) * 30, y: 100))
            investigated = investigated || pet.state == .curious
        }
        #expect(investigated == curious)
    }
    for flies in [true, false] {
        let (_, states, _) = session(seconds: 900) {
            $0.avatar = .toothless
            $0.mischief = 0.6
            $0.takesFlights = flies
        }
        #expect(states.contains(.flying) == flies)
        // The signature flight is always available on request.
        var dragon = PetEngine(habitat: desk, seed: 162)
        dragon.avatar = .toothless
        dragon.takesFlights = flies
        dragon.perform(.signature)
        #expect(dragon.aerialRoute != nil)
    }
}
