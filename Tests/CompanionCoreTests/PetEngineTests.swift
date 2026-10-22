import Foundation
import Testing
@testable import CompanionCore

private let desk = Habitat(left: 100, right: 1_200, floor: 50, ceiling: 800)

@Test func roamingAndToysStayOnTheDesktopDuringLongSessions() {
    for personality in Personality.allCases {
        var pet = PetEngine(habitat: desk, seed: 42)
        pet.mischief = personality.mischief
        for step in 0..<18_000 {
            if step % 2_000 == 0 { pet.perform(.play) }
            pet.tick(seconds: 1.0 / 30, cursor: Point(x: -1_000, y: 200))
            #expect(pet.position.x >= desk.left && pet.position.x <= desk.right)
            #expect(pet.position.y >= desk.floor)
            if let ball = pet.toy {
                #expect(ball.position.x >= desk.left && ball.position.x <= desk.right)
                #expect(ball.position.y >= desk.floor + 12)
            }
            _ = pet.drainEvents()
        }
    }
}

@Test func pickedUpPetLandsAfterBeingReleased() {
    var pet = PetEngine(habitat: desk, seed: 2)
    let start = pet.position
    pet.beginDrag(at: start)
    pet.drag(to: Point(x: start.x - 200, y: 700), seconds: 0.02)
    #expect(pet.state == .carried)
    #expect(pet.position.y == 700)
    pet.endDrag()
    for _ in 0..<180 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.position.y == desk.floor)
    #expect(pet.state != .falling && pet.state != .carried)
    #expect(pet.drainEvents().contains { if case .landing = $0 { true } else { false } })
}

@Test func manualNapPersistsUntilAnInteraction() {
    var pet = PetEngine(habitat: desk, seed: 3)
    pet.perform(.nap)
    for _ in 0..<10_000 { pet.tick(seconds: 0.1, userIdle: 0) }
    #expect(pet.state == .sleeping)
    pet.perform(.pet)
    #expect(pet.state == .happy)
    #expect(pet.interactionCount == 2)
}

@Test func pauseFreezesBothPetAndToy() {
    var pet = PetEngine(habitat: desk, seed: 4)
    pet.perform(.play)
    let position = pet.position
    let toy = pet.toy
    let elapsed = pet.elapsed
    pet.isPaused = true
    for _ in 0..<100 { pet.tick(seconds: 0.1) }
    #expect(pet.position == position)
    #expect(pet.toy == toy)
    #expect(pet.elapsed == elapsed)
}

@Test func monitorRemovalRecoversPetAndToyToRemainingScreen() {
    var pet = PetEngine(habitat: desk, seed: 5)
    pet.perform(.play)
    let smaller = Habitat(left: -900, right: -200, floor: 0, ceiling: 600)
    pet.changeHabitat(smaller)
    #expect(pet.position.x >= smaller.left && pet.position.x <= smaller.right)
    #expect(pet.position.y == smaller.floor)
    #expect(pet.toy!.position.x >= smaller.left && pet.toy!.position.x <= smaller.right)
}

@Test func thrownBallBouncesAndEventuallyGoesAway() {
    var pet = PetEngine(habitat: desk, seed: 6)
    pet.perform(.play)
    pet.holdToy(at: Point(x: 700, y: 500))
    pet.releaseToy(velocity: Point(x: 4_000, y: -4_000))
    #expect(pet.toy!.velocity.x == 850)
    #expect(pet.toy!.velocity.y == -650)
    var sawBounce = false
    for _ in 0..<1_000 {
        pet.tick(seconds: 1.0 / 30)
        if let toy = pet.toy, toy.velocity.y > 0 { sawBounce = true }
        _ = pet.drainEvents()
    }
    #expect(sawBounce)
    #expect(pet.toy == nil)
}

@Test func awayTimeOnlyCausesNapsWhenEnabled() {
    var pet = PetEngine(habitat: desk, seed: 7)
    pet.tick(seconds: 0.1, userIdle: 400)
    #expect(pet.state == .sleeping)
    pet.perform(.wake)
    pet.quietWhenIdle = false
    pet.tick(seconds: 0.1, userIdle: 400)
    #expect(pet.state == .sitting)
}

@Test func preferencesSurviveRoundTripAndRejectInvalidValues() throws {
    var preferences = Preferences()
    preferences.name = "  Juniper  "
    preferences.mischief = 100
    preferences.size = -10
    let recovered = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences)).sanitized()
    #expect(recovered.name == "Juniper")
    #expect(recovered.mischief == 1)
    #expect(recovered.size == 0.65)
    preferences.name = "   "
    preferences.mischief = .nan
    preferences.size = .infinity
    #expect(preferences.sanitized().name == "Miso")
    #expect(preferences.sanitized().mischief == 0.25)
    #expect(preferences.sanitized().size == 1)
}
