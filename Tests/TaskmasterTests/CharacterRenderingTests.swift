import AppKit
import CompanionCore
import SpriteKit
import Testing

@testable import Taskmaster

@Test @MainActor func coatChangesReachTheCharacterTextureAndAreCached() throws {
    let atlas = try PetAtlas()
    let scene = PetScene(size: CGSize(width: 1200, height: 900), atlas: atlas)
    let engine = PetEngine(habitat: Habitat(left: 110, right: 1100, floor: 20, ceiling: 600), seed: 100)
    var preferences = Preferences()
    scene.render(engine: engine, preferences: preferences, origin: .zero, reducedMotion: true)
    let character = try #require(scene.childNode(withName: "character") as? SKSpriteNode)
    let original = character.texture
    preferences.coat = .moonlit
    scene.render(engine: engine, preferences: preferences, origin: .zero, reducedMotion: true)
    #expect(character.texture !== original)
    #expect(character.texture === atlas.texture(for: .sitting, coat: .moonlit))
}

@Test @MainActor func everyShippedAvatarHasAllPosesAndFlightUsesTheAirborneArt() throws {
    for avatar in AvatarKind.available {
        let atlas = try PetAtlas(avatar: avatar)
        for pose in PetPose.allCases { #expect(atlas.frame(for: pose).alpha.contains { $0 > 90 }) }
        if avatar == .toothless {
            let scene = PetScene(size: CGSize(width: 1200, height: 900), atlas: atlas)
            var pet = PetEngine(habitat: Habitat(left: 110, right: 1100, floor: 20, ceiling: 700), seed: 101)
            pet.avatar = avatar
            pet.perform(.signature)
            for _ in 0..<120 { pet.tick(seconds: 1.0 / 60) }
            var prefs = Preferences()
            prefs.avatar = avatar
            scene.render(engine: pet, preferences: prefs, origin: .zero, reducedMotion: true)
            let character = try #require(scene.childNode(withName: "character") as? SKSpriteNode)
            #expect(character.texture === atlas.frame(for: .carried).texture)
            #expect(character.position.y > 20)
        }
    }
}
