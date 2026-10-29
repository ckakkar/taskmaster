import AppKit
import CompanionCore
import SpriteKit

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
    private var lastWarp: CGPoint?
    private var cursorHoldStarted: Double = 0
    private var cursorPullDistance: Double = 0
    private(set) var framesPerSecond = FramePacing.active
    private var settleUntil: Double = 0
    private var coversWholeScreen = true
    /// Sits for the Settings preview, so outfits can be chosen while the real companion is off on an errand.
    private var posed = PetEngine(habitat: Habitat(left: 0, right: 1, floor: 0, ceiling: 1), seed: 1)
    private var wholeScreenUntil: Double = 0
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
        scene.library = model.library
        canvas = PetInteractionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        super.init()
        panel.title = "\(model.preferences.name) · Taskmaster desktop companion"
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
        canvas.preferredFramesPerSecond = framesPerSecond
        canvas.ignoresSiblingOrder = true
        canvas.shouldCullNonVisibleNodes = true
        canvas.presentScene(scene)
        applyPreferences()
        #if DEBUG
            if let launch = DebugLaunch.current { engine.startDebugState(launch.state) }
        #endif
        renderNow()
        panel.orderFrontRegardless()

        startTimer()
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func applyPreferences() {
        scene.changeAtlas(model.atlas)
        for preview in model.previews { preview.changeAtlas(model.atlas) }
        engine.avatar = model.preferences.avatar
        posed.avatar = model.preferences.avatar
        engine.mischief = model.preferences.mischief
        engine.quietWhenIdle = model.preferences.quietWhenIdle
        engine.customQuips = model.preferences.quipLines
        engine.includeBuiltInQuips = model.preferences.includeBuiltInQuips
        engine.chatter = model.focusActive ? 0 : model.preferences.chatter
        engine.companionName = model.preferences.name
        engine.allowsCursorHeists =
            model.preferences.cursorHeists
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        engine.muddyPaws = model.preferences.muddyPaws
        engine.wanders = model.preferences.wanders
        engine.napsOnItsOwn = model.preferences.napsOnItsOwn
        engine.curiousAboutCursor = model.preferences.curiousAboutCursor
        engine.leavesNotes = model.preferences.leavesNotes
        engine.peeksFromEdges = model.preferences.peeksFromEdges
        engine.takesFlights = model.preferences.takesFlights
        engine.stage = screen.frame.minX...screen.frame.maxX
        engine.visualScale = model.preferences.sanitized().size
        if !engine.allowsCursorHeists || engine.mischief < 0.75 { engine.cancelCursorHeist() }
        let habitat = Self.habitat(for: screen, scale: model.preferences.size)
        if engine.habitat != habitat {
            engine.changeHabitat(habitat)
        }
        layoutPanel()
        panel.collectionBehavior =
            model.preferences.allSpaces
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
        scene.render(
            engine: engine, preferences: model.preferences, origin: screen.frame.origin, reducedMotion: reduced)
        for preview in model.previews {
            preview.render(
                engine: engine(for: preview), preferences: model.preferences, origin: .zero, reducedMotion: reduced)
        }
        let events = engine.drainEvents()
        model.observe(events)
        scene.handle(events)
        for preview in model.previews { preview.handle(events) }
        model.syncPresentation()
    }

    func pointerDragged(to point: CGPoint, seconds: Double) {
        if let target = NSScreen.screens.first(where: { $0.frame.contains(point) }), target != screen {
            move(to: target)
        }
        engine.drag(to: Point(x: point.x, y: point.y), seconds: seconds)
        updateExtent(now: CACurrentMediaTime())
        renderNow()
    }

    func callToPointer() {
        let pointer = NSEvent.mouseLocation
        if let target = NSScreen.screens.first(where: { $0.frame.contains(pointer) }), target != screen {
            move(to: target)
        }
        model.perform(.comeHere(pointer.x))
    }

    func deliver(memeID: String) {
        scene.dismissNote()
        engine.beginDelivery(
            memeID: memeID, screenLeft: screen.frame.minX, screenRight: screen.frame.maxX,
            staySeconds: model.preferences.memeStaySeconds)
        renderNow()
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
        if presentationTick % 12 == 0 || framesPerSecond <= FramePacing.hidden { model.updateServices() }
        let pointer = NSEvent.mouseLocation
        let localPoint = CGPoint(x: pointer.x - screen.frame.minX, y: pointer.y - screen.frame.minY)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { engine.cancelCursorHeist() }
        updateCursorHold(pointer: pointer, now: now)
        if model.isVisible {
            let anyInput = CGEventType(rawValue: UInt32.max)!
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
            engine.tick(
                seconds: dt, cursor: Point(x: pointer.x, y: pointer.y), userIdle: idle,
                cursorContact: !isDragging && scene.hitPet(localPoint))
        }
        updateExtent(now: now)
        if model.isVisible {
            scene.render(
                engine: engine, preferences: model.preferences, origin: screen.frame.origin,
                reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        }
        for preview in model.previews where preview.view?.window?.isVisible == true {
            preview.render(
                engine: engine(for: preview), preferences: model.preferences, origin: .zero,
                reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        }
        let events = engine.drainEvents()
        model.observe(events)
        scene.handle(events)
        for preview in model.previews { preview.handle(events) }
        if model.isVisible {
            let cardHit = engine.delivery?.phase == .displaying && scene.memeAction(at: localPoint) != nil
            let interactive =
                engine.aerialRoute == nil
                && (cardHit || scene.hitPet(localPoint) || scene.hitPaw(localPoint) || scene.hitBall(localPoint)
                    || scene.hitNote(localPoint))
            // Every assignment is a window-server round trip, even when the value is unchanged.
            let ignoresMouse = !(isDragging || interactive)
            if panel.ignoresMouseEvents != ignoresMouse { panel.ignoresMouseEvents = ignoresMouse }
        }
        pace(pointer: pointer, now: now)
        presentationTick += 1
        if presentationTick % 12 == 0 { model.syncPresentation() }
    }

    private func engine(for preview: PetScene) -> PetEngine {
        preview === model.appearanceScene ? posed : engine
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = 1.0 / Double(framesPerSecond)
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = interval * 0.1
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Speeds up at once for movement or a nearby pointer; slows down only after things settle.
    private func pace(pointer: CGPoint, now: Double) {
        let roomUnderPointer = model.previews.contains {
            $0.view?.window?.isVisible == true && $0.view?.window?.frame.contains(pointer) == true
        }
        let previewShowing = model.previews.contains { $0.view?.window?.isVisible == true }
        let wanted =
            roomUnderPointer
            ? FramePacing.active
            : !model.isVisible && !previewShowing
                ? FramePacing.hidden
                : engine.framesPerSecond(pointer: Point(x: pointer.x, y: pointer.y), isDragging: isDragging)
        if wanted >= FramePacing.active { settleUntil = now + FramePacing.settleSeconds }
        if wanted != framesPerSecond, wanted > framesPerSecond || now >= settleUntil {
            framesPerSecond = wanted
            canvas.preferredFramesPerSecond = wanted
            startTimer()
        }
        for preview in model.previews where preview.view?.preferredFramesPerSecond != framesPerSecond {
            preview.view?.preferredFramesPerSecond = framesPerSecond
        }
    }

    private func updateCursorHold(pointer: CGPoint, now: Double) {
        guard engine.cursorHeist?.isHoldingCursor == true, model.isVisible, !model.isPaused,
            !engine.isFocusing, !suspended, !isDragging,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            if lastWarp != nil { engine.cancelCursorHeist() }
            lastWarp = nil
            cursorPullDistance = 0
            return
        }
        if lastWarp == nil { cursorHoldStarted = now }
        if let lastWarp {
            cursorPullDistance += max(0, hypot(pointer.x - lastWarp.x, pointer.y - lastWarp.y) - 1.5)
        }
        let clicked =
            CGEventSource.buttonState(.combinedSessionState, button: .left)
            || CGEventSource.buttonState(.combinedSessionState, button: .right)
            || CGEventSource.buttonState(.combinedSessionState, button: .center)
        let escaped = CGEventSource.keyState(.combinedSessionState, key: 53)
        guard !clicked, !escaped, cursorPullDistance < 22, now - cursorHoldStarted < 1.5,
            NSApp.currentSystemPresentationOptions.isDisjoint(with: [.hideMenuBar, .hideDock])
        else {
            engine.cancelCursorHeist()
            lastWarp = nil
            cursorPullDistance = 0
            return
        }
        let anchor = engine.cursorAnchor
        let point = CGPoint(x: anchor.x, y: anchor.y)
        let quartzPoint = CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY) - point.y)
        if CGWarpMouseCursorPosition(quartzPoint) == .success {
            lastWarp = point
        } else {
            engine.cancelCursorHeist()
            lastWarp = nil
            model.chaosMessage =
                "This Mac didn’t allow the cursor game. \(model.preferences.name) will stick to muddy paws."
        }
    }

    /// Takes the companion to another display and has them walk to its middle.
    func moveCompanion(to target: NSScreen) {
        if Self.displayID(target) != Self.displayID(screen) { move(to: target) }
        model.perform(.comeHere(target.visibleFrame.midX))
    }

    var currentDisplayID: UInt32 { Self.displayID(screen) }

    private func move(to newScreen: NSScreen) {
        // A different display, or the same one at a new size: either way old routes no longer fit.
        let changedDisplay =
            Self.displayID(screen) != Self.displayID(newScreen) || screen.frame.size != newScreen.frame.size
        let habitat = Self.habitat(for: newScreen, scale: model.preferences.size)
        screen = newScreen
        engine.stage = newScreen.frame.minX...newScreen.frame.maxX
        if changedDisplay || engine.habitat != habitat {
            engine.rehome(to: habitat, changedDisplay: changedDisplay)
        }
        layoutPanel()
    }

    private var stripTop: Double {
        engine.habitat.floor + OverlayExtent.stripHeight(size: model.preferences.sanitized().size)
    }

    /// Grows the panel to the whole screen while something can be above the floor strip.
    private func updateExtent(now: Double) {
        if engine.reachesAbove(stripTop, isDragging: isDragging) {
            wholeScreenUntil = now + OverlayExtent.holdSeconds
        }
        let whole = now < wholeScreenUntil
        guard whole != coversWholeScreen else { return }
        coversWholeScreen = whole
        layoutPanel()
    }

    /// The panel's bottom-left corner stays at the screen's, so scene coordinates never change.
    private func layoutPanel() {
        var frame = screen.frame
        if !coversWholeScreen { frame.size.height = min(frame.height, max(1, CGFloat(stripTop) - frame.minY)) }
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
        canvas.frame = CGRect(origin: .zero, size: frame.size)
        scene.size = frame.size
    }

    @objc private func displaysChanged() {
        let pointer = NSEvent.mouseLocation
        let target =
            NSScreen.screens.first { Self.displayID($0) == Self.displayID(screen) }
            ?? NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        if let target { move(to: target) }
    }

    @objc private func willSleep() {
        suspended = true
        canvas.isPaused = true
        // Nothing to draw or time while the display sleeps; focus catches up from the wall clock on wake.
        timer?.invalidate()
        timer = nil
    }
    @objc private func didWake() {
        suspended = false
        startTimer()
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

    static func displayID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
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
        if driver.engine.delivery?.phase == .displaying, !driver.scene.hitPet(point),
            let action = driver.scene.memeAction(at: point)
        {
            driver.model.handleCard(action)
            return
        }
        if driver.scene.hitNote(point) {
            driver.scene.dismissNote()
            return
        }
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
            if wasDragged { driver.engine.endDrag() } else if event.clickCount < 2 { driver.model.perform(.pet) }
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
