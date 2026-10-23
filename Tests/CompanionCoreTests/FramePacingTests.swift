import Foundation
import Testing

@testable import CompanionCore

private let desk = Habitat(left: 100, right: 1_200, floor: 30, ceiling: 800)
private let farAway = Point(x: 2_000, y: 700)

@Test func calmMomentsRedrawLessOftenUnlessThePointerIsNear() {
    var pet = PetEngine(habitat: desk, seed: 120)
    pet.mischief = 0
    #expect(pet.state == .sitting)
    #expect(pet.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.calm)
    #expect(pet.framesPerSecond(pointer: nil, isDragging: false) == FramePacing.calm)
    let nearHead = Point(x: pet.position.x + 40, y: pet.position.y + 120)
    #expect(pet.framesPerSecond(pointer: nearHead, isDragging: false) == FramePacing.active)
    pet.perform(.nap)
    #expect(pet.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.asleep)
    #expect(pet.framesPerSecond(pointer: nearHead, isDragging: false) == FramePacing.active)
}

@Test func movementTogglesAndDraggingAlwaysRenderSmoothly() {
    var pet = PetEngine(habitat: desk, seed: 121)
    pet.perform(.comeHere(pet.position.x - 300))
    pet.tick(seconds: 1.0 / 60)
    #expect(pet.state == .walking)
    #expect(pet.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.active)

    var player = PetEngine(habitat: desk, seed: 122)
    player.perform(.play)
    for _ in 0..<240 { player.tick(seconds: 1.0 / 60) }
    #expect(player.toy != nil)
    #expect(player.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.active)

    var held = PetEngine(habitat: desk, seed: 123)
    #expect(held.framesPerSecond(pointer: farAway, isDragging: true) == FramePacing.active)
    held.beginDrag(at: held.position)
    #expect(held.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.active)
}

@Test func aPausedPetStaysCalmEvenWithAToyOut() {
    var pet = PetEngine(habitat: desk, seed: 124)
    pet.perform(.play)
    pet.isPaused = true
    #expect(pet.framesPerSecond(pointer: farAway, isDragging: false) == FramePacing.calm)
    #expect(pet.framesPerSecond(pointer: farAway, isDragging: true) == FramePacing.active)
}
