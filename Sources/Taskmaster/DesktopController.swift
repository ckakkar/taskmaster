import AppKit
import SpriteKit
import CompanionCore

@MainActor
final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DesktopController: NSObject {
    unowned let model: AppModel
    var engine: PetEngine
    let panel: CompanionPanel
    let scene: PetScene
    private let canvas: PetInteractionView
    private var screen: NSScreen
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var presentationTick = 0
    private var suspended = false
    var isDragging = false
    var contextMenu: (() -> NSMenu)?

    init(model: AppModel, atlas: PetAtlas) {
        self.model = model
        let screen = NSScreen.main ?? NSScreen.screens[0]
        self.screen = screen
        engine = PetEngine(habitat: Self.habitat(for: screen, scale: model.preferences.size))
        engine.mischief = model.preferences.mischief
        panel = CompanionPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        scene = PetScene(size: screen.frame.size, atlas: atlas)
        canvas = PetInteractionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        super.init()
        panel.title = "Miso · Taskmaster desktop companion"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.contentView = canvas
        canvas.driver = self
        canvas.allowsTransparency = true
        canvas.preferredFramesPerSecond = 60
        canvas.ignoresSiblingOrder = true
        canvas.shouldCullNonVisibleNodes = true
        canvas.presentScene(scene)
        applyPreferences()
        renderNow()
        panel.orderFrontRegardless()

        let timer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.002
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func applyPreferences() {
        engine.mischief = model.preferences.mischief
        engine.quietWhenIdle = model.preferences.quietWhenIdle
        engine.changeHabitat(Self.habitat(for: screen, scale: model.preferences.size))
        panel.collectionBehavior = model.preferences.allSpaces
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            : [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
    }

    func setVisible(_ visible: Bool) {
        engine.isPaused = !visible || model.isPaused
        canvas.isPaused = !visible
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        scene.removeAllActions()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func renderNow() {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        scene.render(engine: engine, preferences: model.preferences, origin: screen.frame.origin, reducedMotion: reduced)
        model.previewScene?.render(engine: engine, preferences: model.preferences, origin: .zero, reducedMotion: reduced)
        let events = engine.drainEvents()
        scene.handle(events)
        model.previewScene?.handle(events)
        model.syncPresentation()
    }

    func pointerDragged(to point: CGPoint, seconds: Double) {
        if let target = NSScreen.screens.first(where: { $0.frame.contains(point) }), target != screen {
            move(to: target)
        }
        engine.drag(to: Point(x: point.x, y: point.y), seconds: seconds)
        renderNow()
    }

    func callToPointer() {
        let pointer = NSEvent.mouseLocation
        if let target = NSScreen.screens.first(where: { $0.frame.contains(pointer) }), target != screen { move(to: target) }
        model.perform(.comeHere(pointer.x))
    }

    func showContextMenu(event: NSEvent, view: NSView) {
        guard let menu = contextMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.1, now - lastTick)
        lastTick = now
        guard !suspended else { return }
        let pointer = NSEvent.mouseLocation
        let localPoint = CGPoint(x: pointer.x - screen.frame.minX, y: pointer.y - screen.frame.minY)
        if model.isVisible {
            let anyInput = CGEventType(rawValue: UInt32.max)!
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
            engine.tick(seconds: dt, cursor: Point(x: pointer.x, y: pointer.y), userIdle: idle,
                        cursorContact: !isDragging && scene.hitPet(localPoint))
        }
        if model.isVisible {
            scene.render(
                engine: engine, preferences: model.preferences, origin: screen.frame.origin,
                reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        }
        if let preview = model.previewScene, preview.view?.window?.isVisible == true {
            preview.render(engine: engine, preferences: model.preferences, origin: .zero,
                           reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        }
        let events = engine.drainEvents()
        scene.handle(events)
        model.previewScene?.handle(events)
        let interactive = scene.hitPet(localPoint) || scene.hitPaw(localPoint) || scene.hitBall(localPoint) || scene.hitNote(localPoint)
        panel.ignoresMouseEvents = !(isDragging || interactive)
        presentationTick += 1
        if presentationTick % 12 == 0 { model.syncPresentation() }
    }

    private func move(to newScreen: NSScreen) {
        screen = newScreen
        panel.setFrame(newScreen.frame, display: true)
        canvas.frame = CGRect(origin: .zero, size: newScreen.frame.size)
        scene.size = newScreen.frame.size
        engine.changeHabitat(Self.habitat(for: newScreen, scale: model.preferences.size))
    }

    @objc private func displaysChanged() {
        let pointer = NSEvent.mouseLocation
        let target = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        if let target { move(to: target) }
    }

    @objc private func willSleep() { suspended = true; canvas.isPaused = true }
    @objc private func didWake() {
        suspended = false
        lastTick = CACurrentMediaTime()
        canvas.isPaused = !model.isVisible
        displaysChanged()
    }

    private static func habitat(for screen: NSScreen, scale: Double) -> Habitat {
        let frame = screen.visibleFrame
        let margin = min(110 * scale, frame.width / 3)
        return Habitat(
            left: frame.minX + margin, right: frame.maxX - margin,
            floor: frame.minY + 7, ceiling: max(frame.minY + 7, frame.maxY - 250 * scale)
        )
    }
}

@MainActor
final class PetInteractionView: SKView {
    weak var driver: DesktopController?
    private enum DragTarget { case pet, ball }
    private var target: DragTarget?
    private var start = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var lastTime: Double = 0
    private var wasDragged = false
    private var throwVelocity = Point.zero

    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let driver else { return }
        start = NSEvent.mouseLocation
        lastPoint = start
        lastTime = event.timestamp
        wasDragged = false
        throwVelocity = .zero
        let point = driver.scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))
        if driver.scene.hitNote(point) { driver.scene.dismissNote(); return }
        if driver.scene.hitBall(point) {
            target = .ball
            driver.engine.holdToy(at: Point(x: start.x, y: start.y))
            driver.isDragging = true
        } else if driver.scene.hitPet(point) || driver.scene.hitPaw(point) {
            target = .pet
            if event.clickCount == 2 { driver.model.openRoom?() }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let driver, let target else { return }
        let point = NSEvent.mouseLocation
        let dt = max(0.008, event.timestamp - lastTime)
        throwVelocity = Point(x: (point.x - lastPoint.x) / dt, y: (point.y - lastPoint.y) / dt)
        if !wasDragged && hypot(point.x - start.x, point.y - start.y) > 3 {
            if driver.model.isPaused { driver.model.isPaused = false }
            wasDragged = true
            driver.isDragging = true
            if target == .pet { driver.engine.beginDrag(at: Point(x: start.x, y: start.y)) }
            NSCursor.closedHand.set()
        }
        if wasDragged {
            if target == .pet {
                driver.pointerDragged(to: point, seconds: dt)
            } else {
                driver.engine.holdToy(at: Point(x: point.x, y: point.y))
            }
        }
        lastPoint = point
        lastTime = event.timestamp
    }

    override func mouseUp(with event: NSEvent) {
        guard let driver else { return }
        if target == .pet {
            if wasDragged { driver.engine.endDrag() }
            else if event.clickCount < 2 { driver.model.perform(.pet) }
        } else if target == .ball {
            driver.engine.releaseToy(velocity: throwVelocity)
        }
        driver.isDragging = false
        driver.renderNow()
        target = nil
        NSCursor.arrow.set()
    }

    override func rightMouseDown(with event: NSEvent) { driver?.showContextMenu(event: event, view: self) }
}
