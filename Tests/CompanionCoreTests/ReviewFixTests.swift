import Foundation
import Testing

@testable import CompanionCore

private let wide = Habitat(left: 110, right: 2_450, floor: 20, ceiling: 1_200)

private func speech(_ events: [PetEvent]) -> [String] {
    events.compactMap { if case .speech(let text) = $0 { text } else { nil } }
}

@Test func shrinkingTheScreenDuringADeliveryOrPeekBringsTheCompanionHome() {
    let small = Habitat(left: 110, right: 914, floor: 20, ceiling: 600)
    var courier = PetEngine(habitat: wide, seed: 180)
    courier.beginDelivery(memeID: "card", screenLeft: 0, screenRight: 2_560, staySeconds: 20)
    while courier.delivery?.phase != .displaying { courier.tick(seconds: 1.0 / 60) }
    courier.changeHabitat(small)
    #expect(courier.delivery == nil)
    #expect((small.left...small.right).contains(courier.position.x))

    var hider = PetEngine(habitat: wide, seed: 181)
    hider.stage = 0...2_560
    hider.perform(.hideAndSeek)
    while hider.peek?.phase != .hiding { hider.tick(seconds: 1.0 / 60) }
    hider.changeHabitat(small)
    #expect(hider.peek == nil && (small.left...small.right).contains(hider.position.x))
}

@Test func breakRemindersAreSaidWhateverTheVoiceSettings() {
    for (custom, chatter) in [(["SNACKS ONLY"], 0.35), ([], 0.0)] {
        var pet = PetEngine(habitat: wide, seed: 182)
        pet.customQuips = custom
        pet.includeBuiltInQuips = custom.isEmpty
        pet.chatter = chatter
        pet.perform(.breakReminder)
        #expect(speech(pet.drainEvents()) == ["A little break? Uncurl your shoulders. I’ll keep your place."])
        #expect(pet.state == .stretching)
    }
}

@Test func misosSignatureCountsAsOneInteraction() {
    var pet = PetEngine(habitat: wide, seed: 183)
    pet.perform(.signature)
    #expect(pet.interactionCount == 1)
    #expect(pet.state == .walking)
}

@Test func aMalformedPreferenceOnlyLosesThatOneSetting() throws {
    let damaged = Data(#"{"name":"Juniper","size":"big","sound":true,"mischief":"lots","focusMinutes":40}"#.utf8)
    let prefs = try JSONDecoder().decode(Preferences.self, from: damaged)
    #expect(prefs.name == "Juniper" && prefs.sound && prefs.focusMinutes == 40)
    #expect(prefs.size == Preferences().size && prefs.mischief == Preferences().mischief)
}

@Test func liveLimitsMatchWhatTheCompanionUsesWithoutFightingTyping() {
    var prefs = Preferences()
    prefs.name = "Trash Panda "
    prefs.size = 9
    prefs.focusMinutes = 500
    prefs.speechSeconds = -3
    let bounded = prefs.bounded()
    #expect(bounded.name == "Trash Panda ")
    #expect(bounded.size == 1.5 && bounded.focusMinutes == 90 && bounded.speechSeconds == 2)
    prefs.name = String(repeating: "m", count: 30)
    #expect(prefs.bounded().name.count == 24)
    #expect(Preferences().bounded() == Preferences())
}

@Test func automaticActivitiesWaitForAFreeMoment() {
    var pet = PetEngine(habitat: wide, seed: 184)
    pet.stage = 0...2_560
    #expect(pet.isFreeForInterruption)
    for action in [PetAction.play, .findTreat, .offerHighFive, .followCursor, .hideAndSeek, .nap] {
        var busy = pet
        busy.perform(action)
        busy.tick(seconds: 1.0 / 60)
        #expect(!busy.isFreeForInterruption)
    }
    var paused = pet
    paused.isPaused = true
    #expect(!paused.isFreeForInterruption)
}

@Test func deliveriesCrossAWideScreenQuickly() {
    var pet = PetEngine(habitat: wide, seed: 185)
    pet.beginDelivery(memeID: "card", screenLeft: 0, screenRight: 2_560, staySeconds: 8)
    var seconds = 0.0
    while pet.delivery != nil, seconds < 120 {
        pet.tick(seconds: 1.0 / 60)
        seconds += 1.0 / 60
    }
    #expect(pet.delivery == nil)
    #expect(seconds < 45)
}

@Test func aFocusSessionPicksUpWhereItLeftOffAfterARelaunch() {
    var focus = FocusSession()
    focus.resume(startedAt: 1_000, deadline: 2_500)
    #expect(focus.isActive)
    #expect(focus.remaining(at: 2_000) == 500)
    #expect(abs(focus.progress(at: 1_750) - 0.5) < 0.00001)
    let finished = focus.update(now: 2_500)
    #expect(finished)
    var nonsense = FocusSession()
    nonsense.resume(startedAt: 2_000, deadline: 1_000)
    #expect(!nonsense.isActive)
}
