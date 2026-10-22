import Foundation
import Testing

@testable import CompanionCore

private let habitat = Habitat(left: 100, right: 1_200, floor: 30, ceiling: 800)

@Test func pawsStayPlantedAsTheBodyMovesAcrossTheDesktop() {
    let width = 200.0
    let stride = width * WalkCycle.strideRatio
    for offset in WalkCycle.phaseOffsets {
        var first: Double?
        for sample in 0..<60 {
            let p = Double(sample) / 100
            let bodyX = (p - offset) * stride
            let foot = WalkCycle.foot(phase: (p - offset) * 2 * .pi, offset: offset)
            let worldX = bodyX + foot.x * width
            if let first { #expect(abs(worldX - first) < 0.000001) } else { first = worldX }
            #expect(foot.y == 0)
        }
    }
    let lifted = WalkCycle.foot(phase: 0.81 * .pi * 2, offset: 0)
    #expect(lifted.y > 0.05)
    let beforeLanding = WalkCycle.foot(phase: 0.99999 * .pi * 2, offset: 0)
    let afterLanding = WalkCycle.foot(phase: 0.00001 * .pi * 2, offset: 0)
    #expect(abs(beforeLanding.x - afterLanding.x) < 0.0001)
}

@Test func springsKeepTheSameTimingAtDifferentFrameRates() {
    var results: [Double] = []
    for fps in [30, 60, 120] {
        var spring = MotionSpring()
        for _ in 0..<fps {
            spring.advance(to: 1, seconds: 1 / Double(fps), response: 7)
            #expect(spring.value >= 0 && spring.value <= 1)
        }
        results.append(spring.value)
    }
    #expect(abs(results[0] - results[2]) < 0.000001)
    #expect(results[0] > 0.99)
}

@Test func walkingAcceleratesAndBrakesInsteadOfTeleportingOrOvershooting() {
    var pet = PetEngine(habitat: habitat, seed: 40)
    let destination = pet.position.x - 240
    pet.perform(.comeHere(destination))
    pet.tick(seconds: 1.0 / 60)
    #expect(abs(pet.velocity.x) > 0 && abs(pet.velocity.x) < 15)
    var maximumSpeed: Double = 0
    for _ in 0..<600 {
        pet.tick(seconds: 1.0 / 60)
        maximumSpeed = max(maximumSpeed, abs(pet.velocity.x))
        #expect(pet.position.x >= destination)
        if pet.state == .sitting { break }
    }
    #expect(maximumSpeed > 35)
    #expect(abs(pet.position.x - destination) < 4)
    #expect(pet.velocity == .zero)
}

@Test func highFiveCanBeAcceptedOrPolitelyTimeOut() {
    var pet = PetEngine(habitat: habitat, seed: 41)
    pet.perform(.offerHighFive)
    #expect(pet.state == .highFive)
    _ = pet.drainEvents()
    pet.perform(.pet)
    #expect(pet.state == .happy)
    #expect(pet.drainEvents().contains { if case .highFive = $0 { true } else { false } })
    pet.perform(.offerHighFive)
    for _ in 0..<610 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.state == .sitting)
}

@Test func snackHuntFindsTheTreatAndCleansUpAfterItself() {
    var pet = PetEngine(habitat: habitat, seed: 42)
    pet.perform(.findTreat)
    let snack = pet.snack!
    #expect(snack.position.x >= habitat.left && snack.position.x <= habitat.right)
    var sniffed = false
    for _ in 0..<900 {
        pet.tick(seconds: 1.0 / 60)
        sniffed = sniffed || pet.state == .sniffing
        if pet.snack == nil { break }
    }
    #expect(sniffed && pet.snack == nil && pet.state == .happy)
    #expect(pet.drainEvents().contains { if case .crumbs = $0 { true } else { false } })
    pet.perform(.findTreat)
    pet.perform(.nap)
    #expect(pet.snack == nil && pet.state == .sleeping)
}

@Test func followGameWorksInCozyModeAndStopsOnRequestOrAfterAMinute() {
    var pet = PetEngine(habitat: habitat, seed: 43)
    pet.mischief = 0
    let start = pet.position.x
    pet.perform(.followCursor)
    #expect(pet.isFollowingCursor)
    for _ in 0..<180 { pet.tick(seconds: 1.0 / 60, cursor: Point(x: 200, y: 300)) }
    #expect(pet.position.x < start)
    pet.perform(.stopFollowing)
    #expect(!pet.isFollowingCursor && pet.state == .sitting)
    pet.perform(.followCursor)
    for _ in 0..<3_610 { pet.tick(seconds: 1.0 / 60, cursor: Point(x: 600, y: 300)) }
    #expect(!pet.isFollowingCursor)
    pet.perform(.followCursor)
    pet.perform(.nap)
    #expect(!pet.isFollowingCursor && pet.state == .sleeping)
}

@Test func pauseFreezesSnackHuntAndFollowCountdown() {
    var pet = PetEngine(habitat: habitat, seed: 44)
    pet.perform(.findTreat)
    let saved = pet.snack
    pet.isPaused = true
    for _ in 0..<600 { pet.tick(seconds: 0.1) }
    #expect(pet.snack == saved)
    pet.isPaused = false
    pet.perform(.followCursor)
    pet.isPaused = true
    for _ in 0..<700 { pet.tick(seconds: 0.1) }
    #expect(pet.isFollowingCursor)
}
