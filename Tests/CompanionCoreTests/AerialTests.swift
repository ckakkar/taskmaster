import Testing

@testable import CompanionCore

private let sky = Habitat(left: 110, right: 1330, floor: 20, ceiling: 800)

@Test func dragonAndRobinTravelInTwoDimensionsAndLandWithinBounds() {
    for kind in [AvatarKind.toothless, .robin] {
        var pet = PetEngine(habitat: sky, seed: 95)
        pet.avatar = kind
        pet.mischief = 0
        pet.perform(.signature)
        #expect(pet.state == (kind == .toothless ? .flying : .grappling))
        var top = pet.position.y
        var left = pet.position.x
        var right = pet.position.x
        for _ in 0..<2400 {
            pet.tick(seconds: 1.0 / 60)
            top = max(top, pet.position.y)
            left = min(left, pet.position.x)
            right = max(right, pet.position.x)
            #expect(pet.position.x >= sky.left && pet.position.x <= sky.right)
            #expect(pet.position.y >= sky.floor && pet.position.y <= sky.ceiling)
        }
        #expect(top > 350 && right - left > 400)
        #expect(pet.aerialRoute == nil && pet.position.y == sky.floor)
    }
}

@Test func aerialPauseFocusAndGroundActivitiesRecoverSmoothly() {
    var pet = PetEngine(habitat: sky, seed: 96)
    pet.avatar = .toothless
    pet.perform(.signature)
    for _ in 0..<150 { pet.tick(seconds: 1.0 / 60) }
    let airborne = pet.position
    #expect(airborne.y > sky.floor)
    pet.isPaused = true
    for _ in 0..<100 { pet.tick(seconds: 0.1) }
    #expect(pet.position == airborne)
    pet.isPaused = false
    pet.perform(.nap)
    #expect(pet.position == airborne && pet.aerialRoute?.landing == true)
    for _ in 0..<100 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.position.y == sky.floor && pet.state == .sleeping)
    pet.perform(.wake)
    pet.perform(.signature)
    for _ in 0..<150 { pet.tick(seconds: 1.0 / 60) }
    pet.isFocusing = true
    for _ in 0..<150 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.aerialRoute == nil && pet.state == .sitting && pet.position.y == sky.floor)
}

@Test func airbornePettingKeepsFlightAndFollowCanUseCursorHeight() {
    var pet = PetEngine(habitat: sky, seed: 97)
    pet.avatar = .toothless
    pet.perform(.followCursor)
    for _ in 0..<120 { pet.tick(seconds: 1.0 / 60, cursor: Point(x: 500, y: 650)) }
    pet.perform(.pet)
    #expect(pet.aerialRoute != nil && pet.isFollowingCursor)
    for _ in 0..<400 { pet.tick(seconds: 1.0 / 60, cursor: Point(x: 500, y: 650)) }
    #expect(abs(pet.position.x - 500) < 100 && pet.position.y > 500)
    pet.perform(.stopFollowing)
    for _ in 0..<100 { pet.tick(seconds: 1.0 / 60) }
    #expect(!pet.isFollowingCursor && pet.aerialRoute == nil && pet.position.y == sky.floor)
}
