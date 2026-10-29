import Foundation
import Testing

@testable import CompanionCore

private let desk = Habitat(left: 110, right: 1_330, floor: 20, ceiling: 700)
private let screen: ClosedRange<Double> = 0...1_440
/// Half the standing pose's width at 100% size, in points.
private let halfWidth = 191.0 / 2

private func speech(_ events: [PetEvent]) -> [String] {
    events.compactMap { if case .speech(let text) = $0 { text } else { nil } }
}

@Test func hideAndSeekLeavesThenPeeksInFromTheNearerEdgeAndComesBack() {
    var pet = PetEngine(habitat: desk, seed: 170)
    pet.stage = screen
    pet.perform(.hideAndSeek)
    let route = try! #require(pet.peek)
    #expect(route.side == 1)
    var hidden = false
    var peeked = false
    var said: [String] = []
    for _ in 0..<(60 * 40) {
        pet.tick(seconds: 1.0 / 60)
        said += speech(pet.drainEvents())
        if pet.peek?.phase == .hiding {
            hidden = true
            #expect(pet.position.x - halfWidth > screen.upperBound)
        }
        if pet.state == .peeking {
            peeked = true
            // The head shows just inside the right edge, facing back into the screen.
            #expect(pet.position.x - halfWidth < screen.upperBound)
            #expect(pet.position.x > screen.upperBound)
            #expect(!pet.facingRight)
        }
        if pet.peek == nil { break }
    }
    #expect(hidden && peeked)
    #expect(said.contains("…did you notice me?"))
    #expect(pet.peek == nil && pet.state == .sitting)
    #expect((desk.left...desk.right).contains(pet.position.x))
}

@Test func findingAPeekingCompanionCountsAsFoundAndBringsItBack() {
    var pet = PetEngine(habitat: desk, seed: 171)
    pet.stage = screen
    pet.perform(.hideAndSeek)
    while pet.state != .peeking { pet.tick(seconds: 1.0 / 60) }
    _ = pet.drainEvents()
    pet.perform(.pet)
    let events = pet.drainEvents()
    #expect(events.contains { if case .hearts = $0 { true } else { false } })
    #expect(speech(events).contains("You found me!"))
    #expect(pet.peek?.phase == .returning)
    for _ in 0..<(60 * 20) where pet.peek != nil { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.peek == nil && (desk.left...desk.right).contains(pet.position.x))
}

@Test func otherActionsDragsAndNewDisplaysEndAPeekOnTheDesktop() {
    func hiding() -> PetEngine {
        var pet = PetEngine(habitat: desk, seed: 172)
        pet.stage = screen
        pet.perform(.hideAndSeek)
        while pet.peek?.phase != .hiding { pet.tick(seconds: 1.0 / 60) }
        return pet
    }
    var napper = hiding()
    napper.perform(.nap)
    #expect(napper.peek == nil && napper.state == .sleeping)
    #expect((desk.left...desk.right).contains(napper.position.x))

    var moved = hiding()
    moved.rehome(to: Habitat(left: -1_800, right: -300, floor: 0, ceiling: 600), changedDisplay: true)
    #expect(moved.peek == nil && (-1_800 ... -300).contains(moved.position.x))

    var resized = hiding()
    let before = resized.position.x
    resized.changeHabitat(Habitat(left: 130, right: 1_310, floor: 24, ceiling: 680))
    #expect(resized.peek?.phase == .hiding && resized.position.x == before && resized.position.y == 24)
}

@Test func peeksHappenOnTheirOwnOnlyWhenAllowedAndOnlyWithAKnownScreen() {
    for (allowed, stage) in [(true, Optional(screen)), (false, Optional(screen)), (true, nil)] {
        var pet = PetEngine(habitat: desk, seed: 173)
        pet.quietWhenIdle = false
        pet.mischief = 0.3
        pet.peeksFromEdges = allowed
        pet.stage = stage
        var peeked = false
        for _ in 0..<(30 * 900) {
            pet.tick(seconds: 1.0 / 30, cursor: Point(x: -2_000, y: 900))
            _ = pet.drainEvents()
            peeked = peeked || pet.peek != nil
        }
        #expect(peeked == (allowed && stage != nil))
    }
    var noStage = PetEngine(habitat: desk, seed: 174)
    noStage.perform(.hideAndSeek)
    #expect(noStage.peek == nil && noStage.state == .sitting)
}
