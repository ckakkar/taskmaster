import AppKit
import CompanionCore
import SpriteKit

extension PetScene {
    func hitPet(_ point: CGPoint) -> Bool {
        guard pet.size.width > 0, pet.size.height > 0 else { return false }
        let localPoint = pet.convert(point, from: self)
        let x = localPoint.x / pet.size.width + 0.5
        let y = localPoint.y / pet.size.height
        let frame = atlas.frame(for: pose)
        // Sheared legs get a point and a half of slack either side for their anti-aliased outline.
        let slack = footShift == 0 ? 0 : 1.5 / pet.size.width
        let unsheared = Self.unshear(x, y, footShift)
        if [0, -slack, slack].contains(where: { frame.contains(x: unsheared + $0, y: y) }) { return true }
        // Mid-stride, the next drawing is already partly visible: its paws count as fur too.
        guard let blendPose, !strideBlend.isHidden, strideBlend.alpha > 0.2, strideBlend.size.width > 0 else {
            return false
        }
        let blendPoint = strideBlend.convert(point, from: self)
        let blendY = blendPoint.y / strideBlend.size.height
        let blendX = Self.unshear(blendPoint.x / strideBlend.size.width + 0.5, blendY, incomingFootShift)
        let blendSlack = incomingFootShift == 0 ? 0 : 1.5 / strideBlend.size.width
        return [0, -blendSlack, blendSlack].contains {
            atlas.frame(for: blendPose).contains(x: blendX + $0, y: blendY)
        }
    }

    /// Undoes the walking rig's leg shear (see `PetAnimation`), mapping a point on screen back into the drawing.
    /// The warp grid has 12 rows and the drawing interpolates linearly between them, so the inverse does too.
    static func unshear(_ x: Double, _ y: Double, _ shift: Double) -> Double {
        func legs(_ height: Double) -> Double { 1 - min(1, max(0, (height - 0.1) / 0.3)) }
        let row = min(11.999, max(0, y * 12)).rounded(.down)
        let fraction = min(1, max(0, y * 12 - row))
        let weight = legs(row / 12) + (legs((row + 1) / 12) - legs(row / 12)) * fraction
        return x - shift * weight
    }

    /// Whether a point on the fur is on the head (eyes to snout), where a click is a boop rather than a pat.
    func hitHead(_ point: CGPoint) -> Bool {
        let frame = atlas.frame(for: pose)
        guard frame.eyes.count == 2, hitPet(point) else { return false }
        let localPoint = pet.convert(point, from: self)
        let x = localPoint.x / pet.size.width + 0.5
        let y = localPoint.y / pet.size.height
        let a = frame.eyes[0].center
        let b = frame.eyes[1].center
        let span = max(0.06, Double(abs(a.x - b.x)))
        // Drawings face right: the snout runs past the far eye, so the oval leans that way.
        let centerX = Double(a.x + b.x) / 2 + span * 0.25
        let centerY = Double(a.y + b.y) / 2 - 0.03
        let radiusX = span * 1.45
        let radiusY = span * 1.45 * Double(frame.width) / Double(frame.height)
        let dx = (x - centerX) / radiusX
        let dy = (y - centerY) / radiusY
        return dx * dx + dy * dy < 1
    }

    func hitPaw(_ point: CGPoint) -> Bool {
        !pawRing.isHidden && hypot(point.x - pawRing.position.x, point.y - pawRing.position.y) < 24
    }

    func hitBall(_ point: CGPoint) -> Bool {
        !ball.isHidden && hypot(point.x - ball.position.x, point.y - ball.position.y) < 19
    }

    func hitNote(_ point: CGPoint) -> Bool {
        guard let note, note.parent != nil else { return false }
        return note.contains(point)
    }

    func memeAction(at point: CGPoint) -> MemeCardNode.CardAction? {
        guard let card = memeCard, !card.isHidden else { return nil }
        return card.action(at: point)
    }
}
