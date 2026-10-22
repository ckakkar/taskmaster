import Foundation
import Testing

@testable import CompanionCore

@Test func gazeEasesTowardCursorAndReturnsToRest() {
    var attention = PetAttention(seed: 20)
    attention.advance(seconds: 1.0 / 30, target: Point(x: 5, y: -4), asleep: false, reducedMotion: false)
    #expect(attention.gaze.x > 0 && attention.gaze.x < 0.5)
    for _ in 0..<90 {
        attention.advance(seconds: 1.0 / 30, target: Point(x: 5, y: -4), asleep: false, reducedMotion: false)
    }
    #expect(attention.gaze.x > 0.99 && attention.gaze.x <= 1)
    #expect(attention.gaze.y < -0.99 && attention.gaze.y >= -1)
    for _ in 0..<90 { attention.advance(seconds: 1.0 / 30, target: nil, asleep: false, reducedMotion: false) }
    #expect(abs(attention.gaze.x) < 0.001)
    #expect(!attention.isWatching)
}

@Test func naturalBlinksAreBriefAndSleepHasClosedEyes() {
    var attention = PetAttention(seed: 21)
    var closedFrames = 0
    for _ in 0..<1_800 {
        attention.advance(seconds: 1.0 / 30, target: nil, asleep: false, reducedMotion: false)
        #expect((0...1).contains(attention.blink))
        if attention.blink > 0.2 { closedFrames += 1 }
    }
    #expect(closedFrames > 30 && closedFrames < 180)
    attention.advance(seconds: 0.1, target: Point(x: 1, y: 1), asleep: true, reducedMotion: false)
    #expect(attention.blink == 1 && !attention.isWatching)
    attention.advance(seconds: 0.1, target: Point(x: 1, y: 1), asleep: false, reducedMotion: true)
    #expect(attention.earFlick == 0)
}

@Test func strokingRequiresRealGentleMovementAndHasACooldown() {
    var pet = PetEngine(habitat: Habitat(left: 0, right: 1_000, floor: 0, ceiling: 800), seed: 22)
    pet.stroke(distance: 1_000)
    for _ in 0..<10 { pet.stroke(distance: 0) }
    #expect(pet.interactionCount == 0)
    for _ in 0..<8 { pet.stroke(distance: 16) }
    #expect(pet.state == .happy && pet.interactionCount == 1)
    for _ in 0..<20 { pet.stroke(distance: 16) }
    #expect(pet.interactionCount == 1)
    for _ in 0..<45 { pet.tick(seconds: 1.0 / 30) }
    pet.stroke(distance: 10)
    #expect(pet.interactionCount == 2)
}

@Test func playfulPetInvestigatesNearbyMotionWhileCozyPetStaysPut() {
    let desk = Habitat(left: 0, right: 1_200, floor: 0, ceiling: 800)
    for mischief in [0.0, 0.6] {
        var pet = PetEngine(habitat: desk, seed: 23)
        pet.mischief = mischief
        let start = pet.position.x
        var curious = false
        for i in 0..<60 {
            let cursor = Point(x: start - 140 + sin(Double(i) * 0.3) * 30, y: 100)
            pet.tick(seconds: 1.0 / 30, cursor: cursor)
            if pet.state == .curious { curious = true }
        }
        #expect(curious == (mischief > 0.3))
        #expect(mischief > 0.3 ? pet.position.x < start : pet.position.x == start)
    }
}

@Test func cursorTeleportsDoNotStartAChaseOrWakeAManualNap() {
    var pet = PetEngine(habitat: Habitat(left: 0, right: 1_200, floor: 0, ceiling: 800), seed: 24)
    pet.mischief = 1
    for i in 0..<60 {
        pet.tick(seconds: 1.0 / 30, cursor: Point(x: i % 2 == 0 ? 900 : 1_100, y: 100))
    }
    #expect(pet.state == .sitting)
    pet.perform(.nap)
    for i in 0..<150 {
        pet.tick(seconds: 1.0 / 30, cursor: Point(x: 1_000 + sin(Double(i)) * 20, y: 100))
    }
    #expect(pet.state == .sleeping)
}
