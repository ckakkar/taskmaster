import Foundation
import Testing

@testable import CompanionCore

private let desk = Habitat(left: 100, right: 1_200, floor: 30, ceiling: 800)
private let stripTop = desk.floor + OverlayExtent.stripHeight(size: 1)

@Test func groundedActivitiesFitInTheFloorStrip() {
    var pet = PetEngine(habitat: desk, seed: 130)
    pet.mischief = 1
    #expect(!pet.reachesAbove(stripTop, isDragging: false))
    pet.perform(.comeHere(300))
    for _ in 0..<120 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.state == .walking && !pet.reachesAbove(stripTop, isDragging: false))
    pet.beginDelivery(memeID: "card", screenLeft: 0, screenRight: 1_300, staySeconds: 8)
    for _ in 0..<2_000 {
        pet.tick(seconds: 1.0 / 60)
        #expect(!pet.reachesAbove(stripTop, isDragging: false))
        if let card = pet.delivery?.cardPosition { #expect(card.y + 246 < stripTop) }
    }
}

@Test func aBallPlayedOnTheFloorStaysInTheStripUntilItIsThrownHigh() {
    var pet = PetEngine(habitat: desk, seed: 131)
    pet.perform(.play)
    for _ in 0..<900 {
        pet.tick(seconds: 1.0 / 60)
        #expect(!pet.reachesAbove(stripTop, isDragging: false))
    }
    pet.perform(.play)
    pet.holdToy(at: Point(x: 600, y: 100))
    #expect(pet.reachesAbove(stripTop, isDragging: true))
    pet.releaseToy(velocity: Point(x: 0, y: 850))
    #expect(pet.reachesAbove(stripTop, isDragging: false))
}

@Test func carriedFallingAndFlyingPetsNeedTheWholeScreen() {
    var pet = PetEngine(habitat: desk, seed: 132)
    pet.beginDrag(at: pet.position)
    #expect(pet.reachesAbove(stripTop, isDragging: false))
    pet.drag(to: Point(x: 500, y: 600), seconds: 0.02)
    pet.endDrag()
    pet.tick(seconds: 1.0 / 60)
    #expect(pet.state == .falling && pet.reachesAbove(stripTop, isDragging: false))

    var dragon = PetEngine(habitat: desk, seed: 133)
    dragon.avatar = .toothless
    dragon.perform(.signature)
    dragon.tick(seconds: 1.0 / 60)
    #expect(dragon.aerialRoute != nil && dragon.reachesAbove(stripTop, isDragging: false))
}
