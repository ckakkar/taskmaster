import Foundation
import Testing
@testable import CompanionCore

private let deliveryDesk = Habitat(left: 110, right: 1_330, floor: 20, ceiling: 700)

@Test func legacyPreferencesKeepTheExistingPetWhenNewSettingsAreAdded() throws {
    let legacy = Data(#"{"name":"Juniper","mischief":1,"size":1.4,"sound":true,"allSpaces":false,"quietWhenIdle":false,"showName":true}"#.utf8)
    let prefs = try JSONDecoder().decode(Preferences.self, from: legacy)
    #expect(prefs.name == "Juniper" && prefs.mischief == 1 && prefs.size == 1.4)
    #expect(prefs.sound && !prefs.allSpaces && prefs.showName)
    #expect(prefs.customQuips.isEmpty && prefs.includeBuiltInQuips && !prefs.autoMemes)
    #expect(prefs.focusMinutes == 25 && prefs.memeStaySeconds == 20)
    #expect(prefs.coat == .cinnamon && prefs.accessory == .none && !prefs.cursorHeists)
}

@Test func wardrobeAndMischiefSettingsSurviveSavingAndRejectUnknownStyles() throws {
    var prefs = Preferences()
    prefs.coat = .moonlit; prefs.accessory = .bandana; prefs.accessoryColor = .lavender
    prefs.cursorHeists = true; prefs.pawprintSeconds = .nan
    let saved = prefs.sanitized()
    #expect(saved.pawprintSeconds == 35)
    #expect(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(saved)) == saved)
    let future = try JSONDecoder().decode(Preferences.self, from: Data(#"{"coat":"future","accessory":"hat","accessoryColor":"unknown"}"#.utf8))
    #expect(future.coat == .cinnamon && future.accessory == .none && future.accessoryColor == .forest)
}

@Test func cursorHeistNeedsAnInvitationChaosAndAReachablePointer() {
    var pet = PetEngine(habitat: deliveryDesk, seed: 70)
    let pointer = Point(x: pet.position.x + 50, y: 130)
    let defaultAttempt = pet.beginCursorHeist(at: pointer)
    #expect(!defaultAttempt)
    pet.allowsCursorHeists = true
    let cozyAttempt = pet.beginCursorHeist(at: pointer)
    #expect(!cozyAttempt)
    pet.mischief = 1
    let tooHigh = pet.beginCursorHeist(at: Point(x: pointer.x, y: 600))
    #expect(!tooHigh)
    let allowed = pet.beginCursorHeist(at: pointer)
    #expect(allowed && pet.cursorHeist != nil)
    pet.tick(seconds: 1.0 / 60, cursor: pointer)
    #expect(pet.cursorHeist?.isHoldingCursor == true)
    let began = pet.elapsed
    while pet.cursorHeist != nil && pet.elapsed - began < 2 {
        pet.tick(seconds: 1.0 / 60, cursor: pet.cursorAnchor)
    }
    #expect(pet.cursorHeist == nil && pet.elapsed - began < 1.5)
    #expect((deliveryDesk.left...deliveryDesk.right).contains(pet.position.x))
}

@Test func cursorHeistsReleaseForPauseFocusDraggingAndDisabledSettings() {
    for interruption in 0..<5 {
        var pet = PetEngine(habitat: deliveryDesk, seed: 71)
        pet.mischief = 1; pet.allowsCursorHeists = true
        let pointer = Point(x: pet.position.x + 30, y: 130)
        let began = pet.beginCursorHeist(at: pointer)
        #expect(began)
        pet.tick(seconds: 0.02, cursor: pointer)
        #expect(pet.cursorHeist?.isHoldingCursor == true)
        switch interruption {
        case 0: pet.isPaused = true
        case 1: pet.isFocusing = true
        case 2: pet.beginDrag(at: pointer)
        case 3: pet.allowsCursorHeists = false
        default: pet.perform(.nap)
        }
        #expect(pet.cursorHeist == nil)
    }
}

@Test func aMissedHeistGivesUpAndDoesNotInterruptMemeDelivery() {
    var pet = PetEngine(habitat: deliveryDesk, seed: 72)
    pet.mischief = 1; pet.allowsCursorHeists = true
    let began = pet.beginCursorHeist(at: Point(x: pet.position.x - 300, y: 120))
    #expect(began)
    pet.tick(seconds: 0.1, cursor: Point(x: 600, y: 700))
    #expect(pet.cursorHeist == nil)
    pet.beginDelivery(memeID: "safe", screenLeft: 0, screenRight: 1_440, staySeconds: 8)
    let duringDelivery = pet.beginCursorHeist(at: Point(x: pet.position.x, y: 120))
    #expect(!duringDelivery && pet.delivery != nil)
}

@Test func muddyPawprintsFollowDistanceAndRespectTheOffSwitch() {
    for enabled in [true, false] {
        var pet = PetEngine(habitat: deliveryDesk, seed: 73)
        pet.muddyPaws = enabled
        pet.perform(.muddyZoomies)
        var prints: [Point] = []
        for _ in 0..<500 {
            pet.tick(seconds: 1.0 / 60)
            for event in pet.drainEvents() { if case .footprint(let point, _) = event { prints.append(point) } }
        }
        if enabled {
            #expect(prints.count > 8)
            for index in 1..<prints.count { #expect(abs(prints[index].x - prints[index - 1].x) >= 25) }
        } else { #expect(prints.isEmpty) }
    }
}

@Test func customQuipsAreCleanBoundedAndSurviveSaving() throws {
    var prefs = Preferences()
    prefs.customQuips = "  hello {name}  \n\nhello {name}\n" + String(repeating: "x", count: 300)
    prefs.focusMinutes = -5
    prefs.memeInterval = .infinity
    prefs.memeStaySeconds = -2
    let clean = prefs.sanitized()
    #expect(clean.quipLines.count == 2 && clean.quipLines[1].count == 160)
    #expect(clean.focusMinutes == 1 && clean.memeInterval == 600 && clean.memeStaySeconds == 8)
    let recovered = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(clean))
    #expect(recovered == clean)
}

@Test func customOnlyVoiceUsesThePetNameAndSilentModeReallyStaysSilent() {
    var pet = PetEngine(habitat: deliveryDesk, seed: 50)
    pet.customQuips = ["hello {name}", "snacks, please"]
    pet.companionName = "Juniper"
    pet.includeBuiltInQuips = false
    var heard = Set<String>()
    for _ in 0..<8 {
        pet.perform(.saySomething)
        for event in pet.drainEvents() { if case .speech(let text) = event { heard.insert(text) } }
    }
    #expect(heard == ["hello Juniper", "snacks, please"])
    pet.chatter = 0
    pet.perform(.treat)
    pet.perform(.saySomething)
    #expect(!pet.drainEvents().contains { if case .speech = $0 { true } else { false } })
}

@Test func memeDeliveryLeavesTheScreenBringsACardAndTakesItHome() {
    for startingLeft in [false, true] {
        var pet = PetEngine(habitat: deliveryDesk, seed: 51)
        if startingLeft {
            pet.perform(.comeHere(140))
            for _ in 0..<1_800 {
                pet.tick(seconds: 1.0 / 60)
                if pet.state == .sitting { break }
            }
        }
        pet.beginDelivery(memeID: "a-custom-meme", screenLeft: 0, screenRight: 1_440, staySeconds: 8)
        var phases = Set<String>()
        var wentOffscreen = false
        for _ in 0..<10_000 {
            pet.tick(seconds: 1.0 / 60)
            _ = pet.drainEvents()
            if let route = pet.delivery {
                phases.insert(route.phase.rawValue)
                wentOffscreen = wentOffscreen || pet.position.x < 0 || pet.position.x > 1_440
                #expect(route.memeID == "a-custom-meme")
                if route.phase == .fetching || route.phase == .comingHome { #expect(!route.showsCard) }
                if route.phase == .bringing && route.progress(petX: pet.position.x) < 0.01 {
                    #expect(route.cardPosition.x < -100 || route.cardPosition.x > 1_540)
                }
            } else { break }
        }
        #expect(wentOffscreen && pet.delivery == nil)
        #expect(phases == Set(["fetching", "bringing", "displaying", "collecting", "returning", "comingHome"]))
        #expect((deliveryDesk.left...deliveryDesk.right).contains(pet.position.x))
    }
}

@Test func deliveryCanBeKeptRecalledPausedAndCancelledSafely() {
    var pet = PetEngine(habitat: deliveryDesk, seed: 52)
    pet.beginDelivery(memeID: "test", screenLeft: 0, screenRight: 1_440, staySeconds: 8)
    for _ in 0..<4_000 {
        pet.tick(seconds: 1.0 / 60)
        if pet.delivery?.phase == .displaying { break }
    }
    let oldDeadline = pet.delivery!.leaveAt
    pet.keepDeliveryLonger()
    #expect(pet.delivery!.leaveAt == oldDeadline + 30)
    let before = pet.position
    pet.isPaused = true
    for _ in 0..<700 { pet.tick(seconds: 0.1) }
    #expect(pet.position == before && pet.delivery?.phase == .displaying)
    pet.isPaused = false
    pet.recallDelivery()
    #expect(pet.delivery?.phase == .collecting)
    for _ in 0..<5_000 {
        pet.tick(seconds: 1.0 / 60)
        if pet.delivery == nil { break }
    }
    #expect(pet.delivery == nil)
    pet.beginDelivery(memeID: "another", screenLeft: 0, screenRight: 1_440, staySeconds: 8)
    for _ in 0..<1_000 { pet.tick(seconds: 1.0 / 60) }
    pet.perform(.nap)
    #expect(pet.delivery == nil && pet.state == .sleeping)
    #expect((deliveryDesk.left...deliveryDesk.right).contains(pet.position.x))
}

@Test func focusUsesWallTimeAndFinishesOnlyOnce() {
    var focus = FocusSession()
    focus.start(minutes: 25, now: 1_000)
    #expect(focus.remaining(at: 1_060) == 1_440)
    #expect(abs(focus.progress(at: 1_750) - 0.5) < 0.00001)
    let beforeDeadline = focus.update(now: 2_499)
    let atDeadline = focus.update(now: 3_000)
    let afterDeadline = focus.update(now: 4_000)
    #expect(!beforeDeadline && atDeadline && !afterDeadline && !focus.isActive)
    focus.start(minutes: 1, now: 5_000)
    focus.cancel()
    let afterCancel = focus.update(now: 6_000)
    #expect(!afterCancel)
}

@Test func quietFocusSuppressesRoamingAndCursorGames() {
    var pet = PetEngine(habitat: deliveryDesk, seed: 53)
    pet.mischief = 1
    pet.isFocusing = true
    let start = pet.position
    for i in 0..<5_000 {
        pet.tick(seconds: 1.0 / 60, cursor: Point(x: start.x + sin(Double(i) * 0.2) * 200, y: 120))
        #expect(pet.position == start)
        #expect(pet.state == .sitting)
    }
    #expect(!pet.drainEvents().contains { if case .speech = $0 { true } else { false } })
}
