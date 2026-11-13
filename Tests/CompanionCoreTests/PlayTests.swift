import Foundation
import Testing

@testable import CompanionCore

private let room = Habitat(left: 100, right: 1_500, floor: 20, ceiling: 900)

private func count(_ events: [PetEvent], _ match: (PetEvent) -> Bool) -> Int { events.filter(match).count }

@Test func boopsAreNoticedEveryTimeAndAThirdInARowDelights() {
    var engine = PetEngine(habitat: room, seed: 60)
    engine.perform(.boop)
    #expect(count(engine.drainEvents()) { if case .booped = $0 { true } else { false } } == 1)
    #expect(engine.state == .sitting)
    engine.tick(seconds: 0.5)
    engine.perform(.boop)
    engine.tick(seconds: 0.5)
    engine.perform(.boop)
    #expect(engine.state == .happy)
    // After a pause the count starts again.
    for _ in 0..<(60 * 5) { engine.tick(seconds: 1.0 / 60) }
    engine.perform(.boop)
    #expect(engine.state != .happy)
}

@Test func boopingASleeperWakesItAndBoopingAWalkerStopsIt() {
    var sleeper = PetEngine(habitat: room, seed: 61)
    sleeper.perform(.nap)
    sleeper.perform(.boop)
    #expect(sleeper.state == .sitting)

    var walker = PetEngine(habitat: room, seed: 62)
    walker.perform(.comeHere(300))
    for _ in 0..<30 { walker.tick(seconds: 1.0 / 60) }
    walker.perform(.boop)
    #expect(walker.state == .idle && walker.velocity == .zero)
}

@Test func scrollingTicklesOnceEnoughHasBuiltUpAndThenNeedsAMoment() {
    var engine = PetEngine(habitat: room, seed: 63)
    engine.scroll(distance: 30)
    #expect(!engine.isTickled)
    engine.scroll(distance: 45)
    #expect(engine.isTickled && engine.state == .happy)
    #expect(count(engine.drainEvents()) { if case .giggle = $0 { true } else { false } } == 1)
    // Scrolling straight on does not giggle again until the cooldown has passed.
    for _ in 0..<5 { engine.scroll(distance: 60) }
    #expect(count(engine.drainEvents()) { if case .giggle = $0 { true } else { false } } == 0)
    for _ in 0..<72 { engine.tick(seconds: 1.0 / 60) }
    engine.scroll(distance: 80)
    #expect(count(engine.drainEvents()) { if case .giggle = $0 { true } else { false } } == 1)
    // Nonsense input and a companion in hand are ignored.
    var held = PetEngine(habitat: room, seed: 64)
    held.beginDrag(at: Point(x: 600, y: 60))
    held.scroll(distance: .infinity)
    held.scroll(distance: 500)
    #expect(!held.isTickled)
}

@Test func shakingWhileCarriedMakesTheCompanionDizzyButCarryingDoesNot() {
    var gentle = PetEngine(habitat: room, seed: 65)
    gentle.beginDrag(at: Point(x: 600, y: 60))
    for step in 0..<40 { gentle.drag(to: Point(x: 600 + Double(step) * 3, y: 200), seconds: 1.0 / 60) }
    #expect(!gentle.isDizzy)

    var shaken = PetEngine(habitat: room, seed: 66)
    shaken.beginDrag(at: Point(x: 600, y: 60))
    var x = 600.0
    for step in 0..<48 {
        x += step / 8 % 2 == 0 ? 12 : -12
        shaken.drag(to: Point(x: x, y: 250), seconds: 1.0 / 60)
        shaken.tick(seconds: 1.0 / 60)
    }
    #expect(shaken.isDizzy)
    #expect(count(shaken.drainEvents()) { if case .dizzy = $0 { true } else { false } } == 1)
    shaken.endDrag()
    for _ in 0..<60 { shaken.tick(seconds: 1.0 / 60) }
    #expect(shaken.position.y == room.floor && shaken.isDizzy)
    for _ in 0..<(60 * 6) { shaken.tick(seconds: 1.0 / 60) }
    #expect(!shaken.isDizzy)
}

@Test func aRestingPointerIsNoticedOncePerVisit() {
    var engine = PetEngine(habitat: room, seed: 67)
    let spot = Point(x: engine.position.x, y: room.floor + 60)
    var noticed = 0
    func visit(frames: Int, contact: Bool) {
        for _ in 0..<frames {
            engine.tick(seconds: 1.0 / 60, cursor: spot, userIdle: 0, cursorContact: contact)
            noticed += count(engine.drainEvents()) { if case .noticed = $0 { true } else { false } }
        }
    }
    visit(frames: 30, contact: true)
    #expect(noticed == 0)
    visit(frames: 120, contact: true)
    #expect(noticed == 1)
    visit(frames: 10, contact: false)
    visit(frames: 120, contact: true)
    #expect(noticed == 2)
}

@Test func boopsAndTicklesNeverEndFocus() {
    #expect(!CompanionSchedule.endsFocus(.boop))
    #expect(!CompanionSchedule.endsFocus(.tickle))
}
