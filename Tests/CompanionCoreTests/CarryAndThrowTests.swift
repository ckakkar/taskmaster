import Foundation
import Testing

@testable import CompanionCore

private let room = Habitat(left: 100, right: 1_500, floor: 20, ceiling: 900)

@Test func focusEndingMidCarryLeavesTheCompanionInHandAndItLandsWhenDropped() {
    var engine = PetEngine(habitat: room, seed: 41)
    engine.isFocusing = true
    engine.beginDrag(at: Point(x: 600, y: 60))
    engine.drag(to: Point(x: 600, y: 540), seconds: 0.05)
    engine.isFocusing = false
    #expect(engine.state == .carried)
    engine.drag(to: Point(x: 650, y: 520), seconds: 0.05)
    #expect(engine.position.x > 600)
    engine.endDrag()
    for _ in 0..<240 { engine.tick(seconds: 1.0 / 60) }
    #expect(engine.position.y == room.floor)
    #expect(engine.state != .carried && engine.state != .falling)
}

@Test func focusEndingWhileAboveTheFloorDropsInsteadOfFloating() {
    var engine = PetEngine(habitat: room, seed: 42)
    engine.beginDrag(at: Point(x: 600, y: 60))
    engine.drag(to: Point(x: 600, y: 500), seconds: 0.05)
    engine.isFocusing = true
    engine.endDrag()
    engine.isFocusing = false
    for _ in 0..<240 { engine.tick(seconds: 1.0 / 60) }
    #expect(engine.position.y == room.floor)
}

@Test func holdingStillBeforeLettingGoIsAGentleDropNotAThrow() {
    var engine = PetEngine(habitat: room, seed: 43)
    engine.beginDrag(at: Point(x: 900, y: 60))
    engine.drag(to: Point(x: 400, y: 300), seconds: 0.016)
    #expect(engine.velocity.x < -600)
    // The pointer then rests for two seconds: the engine keeps ticking but hears no drags.
    for _ in 0..<120 { engine.tick(seconds: 1.0 / 60) }
    let heldAt = engine.position.x
    engine.endDrag()
    for _ in 0..<30 { engine.tick(seconds: 1.0 / 60) }
    #expect(abs(engine.position.x - heldAt) < 1)

    // A real flick still throws.
    var flung = PetEngine(habitat: room, seed: 44)
    flung.beginDrag(at: Point(x: 900, y: 60))
    flung.drag(to: Point(x: 400, y: 300), seconds: 0.016)
    let releasedAt = flung.position.x
    flung.endDrag()
    for _ in 0..<30 { flung.tick(seconds: 1.0 / 60) }
    #expect(flung.position.x < releasedAt - 100)
}

@Test func aBallHeldStillNeverExpiresAndALooseOneStillDoes() {
    var engine = PetEngine(habitat: room, seed: 45)
    engine.perform(.play)
    engine.holdToy(at: Point(x: 700, y: 300))
    for _ in 0..<(60 * 45) { engine.tick(seconds: 1.0 / 60) }
    #expect(engine.toy?.isHeld == true)
    engine.releaseToy(velocity: .zero)
    for _ in 0..<(60 * 31) { engine.tick(seconds: 1.0 / 60) }
    #expect(engine.toy == nil)
}

@Test func strokingOnTheDesktopEarnsHeartsDuringFocusToo() {
    for focusing in [false, true] {
        var engine = PetEngine(habitat: room, seed: 46)
        engine.isFocusing = focusing
        var hearts = 0
        for frame in 0..<120 {
            let x = engine.position.x - 20 + Double(frame % 20) * 2
            engine.tick(
                seconds: 1.0 / 60, cursor: Point(x: x, y: room.floor + 60), userIdle: 0, cursorContact: true)
            hearts += engine.drainEvents().filter { if case .hearts = $0 { true } else { false } }.count
        }
        #expect(hearts >= 1)
        if focusing {
            for _ in 0..<300 { engine.tick(seconds: 1.0 / 60) }
            #expect(engine.state == .sitting)
        }
    }
}
