import Foundation
import Testing

@testable import CompanionCore

private let available = CompanionSchedule.Availability(visible: true, paused: false, readyForDelivery: true)

@Test func endingFocusAfterPettingResumesDecisionsInsteadOfSittingForever() {
    for petDuringFocus in [true, false] {
        var pet = PetEngine(habitat: Habitat(left: 100, right: 1300, floor: 20, ceiling: 700), seed: 85)
        pet.mischief = 0
        pet.isFocusing = true
        pet.tick(seconds: 0.1)
        if petDuringFocus { pet.perform(.pet) }
        for _ in 0..<50 { pet.tick(seconds: 0.1) }
        pet.isFocusing = false
        var madeADecision = false
        for _ in 0..<300 {
            pet.tick(seconds: 0.1)
            if pet.state != .sitting {
                madeADecision = true
                break
            }
        }
        #expect(madeADecision)
    }
}

@Test func unrelatedPreferenceEditsDoNotPostponeAutomaticMemes() {
    var preferences = Preferences()
    preferences.autoMemes = true
    preferences.memeInterval = 120
    var schedule = CompanionSchedule(preferences: preferences, now: 1000)
    preferences.size = 1.3
    preferences.name = "Juniper"
    preferences.completedFocusSessions = 8
    schedule.configure(preferences: preferences, now: 1100)
    #expect(schedule.nextMeme == 1120)
    let update = schedule.update(now: 1120, availability: available)
    #expect(update.deliverMeme && !update.focusCompleted && schedule.nextMeme == 1240)
    let duplicate = schedule.update(now: 1120, availability: available)
    #expect(!duplicate.deliverMeme)
    preferences.memeInterval = 300
    schedule.configure(preferences: preferences, now: 1150)
    #expect(schedule.nextMeme == 1450)
}

@Test func automaticDeliveriesWaitForAWelcomeMoment() {
    var prefs = Preferences()
    prefs.autoMemes = true
    prefs.memeInterval = 120
    var schedule = CompanionSchedule(preferences: prefs, now: 100)
    for state in [
        CompanionSchedule.Availability(visible: false, paused: false, readyForDelivery: true),
        .init(visible: true, paused: true, readyForDelivery: true),
        .init(visible: true, paused: false, readyForDelivery: false),
    ] {
        let update = schedule.update(now: 300, availability: state)
        #expect(!update.deliverMeme)
    }
    schedule.startFocus(minutes: 1, now: 300)
    let focused = schedule.update(now: 340, availability: available)
    #expect(!focused.deliverMeme && !focused.focusCompleted)
    let completed = schedule.update(now: 360, availability: available)
    #expect(completed.focusCompleted && !completed.deliverMeme)
    let duplicate = schedule.update(now: 361, availability: available)
    #expect(!duplicate.focusCompleted && !duplicate.deliverMeme)
}

@Test func onlyQuietInteractionsKeepFocusAndCancelledFocusHasNoReminder() {
    for action in [PetAction.pet, .treat, .saySomething] { #expect(!CompanionSchedule.endsFocus(action)) }
    for action in [
        PetAction.play, .nap, .wake, .comeHere(200), .surprise, .offerHighFive,
        .followCursor, .stopFollowing, .findTreat, .stretch, .muddyZoomies, .breakReminder,
    ] {
        #expect(CompanionSchedule.endsFocus(action))
    }
    var schedule = CompanionSchedule(preferences: Preferences(), now: 100)
    schedule.startFocus(minutes: 1, now: 100)
    schedule.endFocus()
    let update = schedule.update(now: 500, availability: available)
    #expect(!update.focusCompleted)
}

@Test func resizingDuringADeliveryPreservesItsRouteAndPosition() {
    var pet = PetEngine(habitat: Habitat(left: 110, right: 1330, floor: 20, ceiling: 700), seed: 87)
    pet.beginDelivery(memeID: "resize", screenLeft: 0, screenRight: 1440, staySeconds: 8)
    for _ in 0..<700 { pet.tick(seconds: 1.0 / 60) }
    let before = pet.position
    let route = pet.delivery
    pet.changeHabitat(Habitat(left: 160, right: 1280, floor: 20, ceiling: 600))
    #expect(pet.position == before && pet.delivery == route)
    pet.perform(.saySomething)
    #expect(pet.position == before && pet.delivery == route)
    for _ in 0..<12000 {
        pet.tick(seconds: 1.0 / 60)
        if pet.delivery == nil { break }
    }
    #expect(pet.delivery == nil)
    #expect((160...1280).contains(pet.position.x))
}

@Test func everyPreferenceIsEncodedAndAllNonDefaultValuesReload() throws {
    var p = Preferences()
    p.name = "Juniper"
    p.mischief = 0.9
    p.size = 1.4
    p.sound = true
    p.allSpaces = false
    p.quietWhenIdle = false
    p.showName = true
    p.customQuips = "Hello {name}"
    p.includeBuiltInQuips = false
    p.chatter = 0.8
    p.bubbleStyle = .midnight
    p.speechSeconds = 9
    p.autoMemes = true
    p.memeInterval = 900
    p.memeStaySeconds = 45
    p.focusMinutes = 40
    p.completedFocusSessions = 3
    p.coat = .dusk
    p.accessory = .bow
    p.accessoryColor = .rose
    p.muddyPaws = false
    p.pawprintSeconds = 70
    p.cursorHeists = true
    let data = try JSONEncoder().encode(p)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(Mirror(reflecting: p).children.compactMap(\.label)) == Set(object.keys))
    #expect(try JSONDecoder().decode(Preferences.self, from: data) == p)
}
