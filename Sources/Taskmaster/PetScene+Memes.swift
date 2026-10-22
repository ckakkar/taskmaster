import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func previewPetX(_ route: MemeDelivery, petX: Double, petWidth: Double) -> Double {
        let middle = size.width / 2
        let outside = route.entryDirection > 0 ? -petWidth - 160 : size.width + petWidth + 160
        let drop = middle + route.entryDirection * 90
        let pickup = middle - route.entryDirection * 200
        let progress = route.progress(petX: petX)
        switch route.phase {
        case .fetching: return middle + (outside - middle) * progress
        case .bringing: return outside + (drop - outside) * progress
        case .displaying: return drop
        case .collecting: return drop + (pickup - drop) * progress
        case .returning: return pickup + (outside - pickup) * progress
        case .comingHome: return outside + (middle - outside) * progress
        }
    }

    func renderDelivery(engine: PetEngine, point: CGPoint) {
        guard let route = engine.delivery else {
            if let previous = memeCard {
                previous.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                memeCard = nil
            }
            ribbon.isHidden = true
            return
        }
        if memeCard?.memeID != route.memeID,
            let library, let item = library.items.first(where: { $0.id == route.memeID })
        {
            memeCard?.removeFromParent()
            let card = MemeCardNode(item: item, image: library.image(for: item))
            card.setScale(isPreview ? 0.62 : 1)
            memeCard = card
            addChild(card)
        }
        guard let card = memeCard else { return }
        card.isHidden = !route.showsCard
        if isPreview {
            card.position = CGPoint(
                x: route.isCarrying ? point.x - route.carryDirection * 145 : size.width / 2 - route.entryDirection * 55,
                y: 40)
        } else {
            card.position = local(route.cardPosition)
        }
        card.zRotation = reducedMotion ? 0 : route.isCarrying ? sin(animation.motion.stride) * 0.018 : -0.025
        ribbon.isHidden = !route.isCarrying
        if route.isCarrying {
            let start = CGPoint(
                x: point.x - route.carryDirection * pet.size.width * 0.27, y: point.y + pet.size.height * 0.5)
            let end = CGPoint(
                x: card.position.x + route.carryDirection * 133 * card.xScale, y: card.position.y + 120 * card.yScale)
            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 8))
            ribbon.path = path
        }
    }
}
