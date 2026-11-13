import AppKit
import CompanionCore
import SpriteKit
import Testing

@testable import Taskmaster

/// While walking, the rig shears the painted legs to keep planted paws still. A click on a paw where it is drawn
/// must still land on the companion (found by Codex QA: the hit mask used the unsheared drawing).
@Test @MainActor func clicksOnShearedWalkingPawsLandOnTheCompanion() throws {
    for avatar in AvatarKind.available {
        let atlas = try PetAtlas(avatar: avatar)
        let scene = PetScene(size: CGSize(width: 1400, height: 600), atlas: atlas)
        var clock = 0.0
        scene.animation.clock = { clock }
        var engine = PetEngine(habitat: Habitat(left: 100, right: 1300, floor: 40, ceiling: 500), seed: 9)
        engine.avatar = avatar
        engine.startDebugState(.walking)
        var preferences = Preferences()
        preferences.avatar = avatar
        var checked = 0
        for _ in 0..<240 {
            clock += 1.0 / 60
            engine.tick(seconds: 1.0 / 60)
            scene.render(engine: engine, preferences: preferences, origin: .zero, reducedMotion: false)
            // With many drawings per stride each holds only briefly, so the shear is small.
            guard abs(scene.footShift) > 0.004 else { continue }
            let frame = atlas.frame(for: scene.pose)
            // An opaque paw pixel in the bottom tenth of the drawing, moved to where the shear draws it.
            for py in stride(from: 0.02, to: 0.1, by: 0.02) {
                // Well inside the paw, so rounding at its outline can't decide the result.
                for px in stride(from: 0.05, to: 0.95, by: 0.01)
                where [-0.006, 0, 0.006].allSatisfy({ frame.contains(x: px + $0, y: py) }) {
                    let body = min(1, max(0, (py - 0.1) / 0.3))
                    let shown = px + scene.footShift * (1 - body)
                    guard !frame.contains(x: shown, y: py) else { continue }
                    let point = scene.pet.convert(
                        CGPoint(x: (shown - 0.5) * scene.pet.size.width, y: py * scene.pet.size.height),
                        to: scene)
                    #expect(scene.hitPet(point), "\(avatar) paw at \(px), \(py) drawn at \(shown)")
                    checked += 1
                }
            }
        }
        #expect(checked > 0)
    }
}
