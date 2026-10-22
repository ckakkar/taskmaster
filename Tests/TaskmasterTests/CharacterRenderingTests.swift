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
        for pose in PetPose.allCases {
            let frame = atlas.frame(for: pose)
            #expect(frame.alpha.contains { $0 > 90 })
            #expect(frame.eyes.allSatisfy { (0...1).contains($0.center.x) && (0...1).contains($0.center.y) })
            #expect(frame.paw.map { (0...1).contains($0.x) && (0...1).contains($0.y) } ?? true)
        }
        if avatar != .miso {
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

@Test @MainActor func flightPreviewKeepsTheWholeBankingDragonVisible() throws {
    let atlas = try PetAtlas(avatar: .toothless)
    for size in [CGSize(width: 360, height: 250), CGSize(width: 436, height: 267)] {
        let scene = PetScene(size: size, atlas: atlas, preview: true)
        var pet = PetEngine(habitat: Habitat(left: 110, right: 1330, floor: 20, ceiling: 800), seed: 108)
        pet.avatar = .toothless
        pet.mischief = 0
        pet.perform(.signature)
        var prefs = Preferences()
        prefs.avatar = .toothless
        for tick in 0..<1800 {
            pet.tick(seconds: 1.0 / 60)
            if tick % 15 != 0 || pet.aerialRoute == nil { continue }
            scene.render(engine: pet, preferences: prefs, origin: .zero, reducedMotion: false)
            let character = try #require(scene.childNode(withName: "character") as? SKSpriteNode)
            #expect(character.frame.minX >= 0 && character.frame.maxX <= size.width)
            #expect(character.frame.minY >= 0 && character.frame.maxY <= size.height)
        }
    }
}
