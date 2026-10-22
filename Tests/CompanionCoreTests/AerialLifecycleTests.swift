import Foundation
import Testing

@testable import CompanionCore

private let sky = Habitat(left: 110, right: 1330, floor: 20, ceiling: 800)

@Test func resizingDoesNotRestartFlightOrRepeatItsGreeting() {
    var pet = PetEngine(habitat: sky, seed: 103)
    pet.avatar = .toothless
    pet.mischief = 0
    pet.perform(.signature)
    _ = pet.drainEvents()
    let deadline = pet.aerialUntil
    for index in 0..<120 {
        pet.tick(seconds: 1.0 / 60)
        pet.changeHabitat(
            Habitat(
                left: 110 + Double(index) * 0.3, right: 1330 - Double(index) * 0.3,
                floor: 20, ceiling: 800 - Double(index)))
    }
    #expect(pet.aerialUntil == deadline && pet.aerialRoute != nil)
    #expect(!pet.drainEvents().contains { if case .speech = $0 { true } else { false } })
    for _ in 0..<2200 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.aerialRoute == nil && pet.position.y == pet.habitat.floor)
}

@Test func anAirborneDeliveryLandsBeforeFetchingWithoutTeleporting() {
    var pet = PetEngine(habitat: sky, seed: 104)
    pet.avatar = .toothless
    pet.mischief = 0
    pet.perform(.signature)
    for _ in 0..<150 { pet.tick(seconds: 1.0 / 60) }
    let before = pet.position
    pet.beginDelivery(memeID: "flight-delivery", screenLeft: 0, screenRight: 1440, staySeconds: 8)
    #expect(pet.position == before && pet.aerialRoute?.landing == true)
    for _ in 0..<100 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.aerialRoute == nil && pet.position.y == sky.floor && pet.delivery != nil)
    for _ in 0..<12000 {
        pet.tick(seconds: 1.0 / 60)
        if pet.delivery == nil { break }
    }
    #expect(pet.delivery == nil)
}

@Test func changingDisplaysPreservesFlightAndDraggingTakesOverSafely() {
    var pet = PetEngine(habitat: sky, seed: 105)
    pet.avatar = .toothless
    pet.mischief = 0
    pet.perform(.signature)
    for _ in 0..<130 { pet.tick(seconds: 1.0 / 60) }
    let deadline = pet.aerialUntil
    let other = Habitat(left: 2100, right: 3100, floor: 40, ceiling: 640)
    pet.rehome(to: other, changedDisplay: true)
    #expect(pet.aerialRoute != nil && pet.aerialUntil == deadline)
    for _ in 0..<120 {
        pet.tick(seconds: 1.0 / 60)
        #expect((other.left...other.right).contains(pet.position.x))
        #expect((other.floor...other.ceiling).contains(pet.position.y))
    }
    let pointer = pet.position
    pet.beginDrag(at: pointer)
    #expect(pet.aerialRoute == nil && pet.state == .carried && pet.position == pointer)
    pet.endDrag()
    for _ in 0..<300 { pet.tick(seconds: 1.0 / 60) }
    #expect(pet.position.y == other.floor)
}

@Test func automaticFlightsHaveLongBreathersBetweenThem() {
    var pet = PetEngine(habitat: sky, seed: 106)
    pet.avatar = .toothless
    pet.mischief = 1
    var lastStart = -1000.0
    var previousFlying = false
    var starts = 0
    for _ in 0..<36000 {
        pet.tick(seconds: 1.0 / 60)
        let flying = pet.aerialRoute != nil
        if flying && !previousFlying {
            #expect(pet.elapsed - lastStart >= 180)
            lastStart = pet.elapsed
            starts += 1
        }
        previousFlying = flying
        _ = pet.drainEvents()
    }
    #expect(starts > 0 && starts <= 3)
}

@Test func unavailableAvatarsFallBackWithoutLosingTheCustomName() throws {
    var prefs = Preferences()
    prefs.avatar = .toothless
    prefs.name = "Desk guardian"
    let recovered = prefs.resolvingAvatar(available: [.miso])
    #expect(recovered.avatar == .miso && recovered.name == prefs.name)
    #expect(prefs.resolvingAvatar(available: [.miso, .toothless]).avatar == .toothless)
    let legacy = Data(#"{"avatar":"removed-avatar","name":"Desk guardian","size":1.2}"#.utf8)
    let decoded = try JSONDecoder().decode(Preferences.self, from: legacy)
    #expect(decoded.avatar == .miso && decoded.name == prefs.name && decoded.size == 1.2)
}

@Test func sameDisplayWakePreservesACardButMovingDisplaysCancelsIt() {
    var pet = PetEngine(habitat: sky, seed: 107)
    pet.beginDelivery(memeID: "wake-card", screenLeft: 0, screenRight: 1440, staySeconds: 20)
    for _ in 0..<4000 {
        pet.tick(seconds: 1.0 / 60)
        if pet.delivery?.phase == .displaying { break }
    }
    let before = pet.delivery
    pet.rehome(to: sky, changedDisplay: false)
    #expect(pet.delivery == before)
    pet.rehome(to: Habitat(left: 2100, right: 3100, floor: 40, ceiling: 640), changedDisplay: true)
    #expect(pet.delivery == nil && (2100...3100).contains(pet.position.x))
}
