import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func hitPet(_ point: CGPoint) -> Bool {
        guard pet.size.width > 0, pet.size.height > 0 else { return false }
        let localPoint = pet.convert(point, from: self)
        let x = localPoint.x / pet.size.width + 0.5
        let y = localPoint.y / pet.size.height
        return atlas.frame(for: pose).contains(x: x, y: y)
    }

    func hitPaw(_ point: CGPoint) -> Bool {
        !pawRing.isHidden && hypot(point.x - pawRing.position.x, point.y - pawRing.position.y) < 24
    }

    func hitBall(_ point: CGPoint) -> Bool {
        !ball.isHidden && hypot(point.x - ball.position.x, point.y - ball.position.y) < 19
    }

    func hitNote(_ point: CGPoint) -> Bool {
        guard let note = childNode(withName: "note") else { return false }
        return note.contains(point)
    }

    func memeAction(at point: CGPoint) -> MemeCardNode.CardAction? {
        guard let card = memeCard, !card.isHidden else { return nil }
        return card.action(at: point)
    }
}
