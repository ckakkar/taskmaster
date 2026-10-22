import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct PetPreview: NSViewRepresentable {
    let model: AppModel
    var wardrobe = false

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.model = model
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        let scene = PetScene(size: CGSize(width: 360, height: 260), atlas: model.atlas, preview: true)
        scene.library = model.library
        view.presentScene(scene)
        if wardrobe { model.appearanceScene = scene } else { model.previewScene = scene }
        model.desktop.renderNow()
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        guard let scene = view.scene as? PetScene else { return }
        if wardrobe { model.appearanceScene = scene } else { model.previewScene = scene }
        scene.changeAtlas(model.atlas)
        view.isPaused = false
    }

    static func dismantleNSView(_ view: PreviewView, coordinator: ()) {
        view.isPaused = true
        view.presentScene(nil)
    }

    @MainActor final class PreviewView: SKView {
        weak var model: AppModel?
        private var tracking: NSTrackingArea?
        private var lastPointer: CGPoint?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self)
            addTrackingArea(area)
            tracking = area
        }

        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            defer { lastPointer = point }
            guard let previous = lastPointer, let scene = scene as? PetScene,
                scene.hitPet(scene.convertPoint(fromView: point)), let model
            else { return }
            model.desktop.engine.stroke(distance: hypot(point.x - previous.x, point.y - previous.y))
        }

        override func mouseExited(with event: NSEvent) {
            lastPointer = nil
            NSCursor.arrow.set()
        }
        override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseDown(with event: NSEvent) {
            if let scene = scene as? PetScene, model?.deliveryPhase == .displaying {
                let point = scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))
                if !scene.hitPet(point), let action = scene.memeAction(at: point) {
                    if action == .putAway { model?.putMemeAway() } else { model?.keepMemeLonger() }
                    return
                }
            }
            guard let scene = scene as? PetScene,
                scene.hitPet(scene.convertPoint(fromView: convert(event.locationInWindow, from: nil)))
                    || scene.hitPaw(scene.convertPoint(fromView: convert(event.locationInWindow, from: nil)))
            else { return }
            lastPointer = convert(event.locationInWindow, from: nil)
            model?.perform(.pet)
        }
        override func rightMouseDown(with event: NSEvent) { model?.perform(.surprise) }
        override var acceptsFirstResponder: Bool { false }
    }
}
