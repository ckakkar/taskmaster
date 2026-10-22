import AppKit
import SpriteKit
import SwiftUI
import CompanionCore

private enum Palette {
    static let paper = Color(red: 0.985, green: 0.973, blue: 0.95)
    static let ink = Color(red: 0.23, green: 0.20, blue: 0.17)
    static let secondary = Color(red: 0.55, green: 0.49, blue: 0.43)
    static let orange = Color(red: 0.76, green: 0.35, blue: 0.21)
    static let line = Color(red: 0.86, green: 0.82, blue: 0.77)
    static let green = Color(red: 0.34, green: 0.48, blue: 0.39)
}

struct CompanionRoom: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            header
            HStack(alignment: .top, spacing: 37) {
                introduction.frame(maxWidth: .infinity)
                controls.frame(width: 300)
            }
            footer
        }
        .padding(.horizontal, 34)
        .padding(.top, 47)
        .padding(.bottom, 25)
        .frame(minWidth: 790, minHeight: 610)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.orange)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.orange)
                Text("taskmaster").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(model.isPaused ? Palette.secondary : Palette.green).frame(width: 5, height: 5)
                Text(model.isPaused ? "Taking a little pause" : model.isVisible ? "At home on your desktop" : "Tucked away for now")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Palette.secondary)
            Button { model.showPreferences.toggle() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .frame(width: 34, height: 32)
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line.opacity(0.7), lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .help("Companion preferences")
            .accessibilityLabel("Companion preferences")
            .popover(isPresented: $model.showPreferences, arrowEdge: .bottom) {
                PreferencesPanel(model: model)
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("A little company.")
                Text("A little mischief.").foregroundStyle(Palette.orange)
            }
            .font(.system(size: 36, weight: .regular, design: .serif))
            .tracking(-1)
            .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.91, blue: 0.83), Color(red: 0.97, green: 0.94, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoomBackdrop()
                VStack {
                    HStack {
                        Text("MEET \(model.preferences.name.uppercased())")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Image(systemName: "sparkle").foregroundStyle(Palette.orange.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(22)
                PetPreview(model: model)
                    .padding(.top, 35)
                    .accessibilityLabel("\(model.preferences.name), your red panda. Click to pet.")
                HStack(spacing: 5) {
                    Image(systemName: model.state == .sleeping ? "moon.zzz.fill" : "heart.fill")
                        .font(.system(size: 9))
                    Text(model.isPaused ? "Just being here" : model.state.description)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Palette.paper.opacity(0.9), in: Capsule())
                .padding(.bottom, 15)
            }
            .frame(height: 302)
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.8), lineWidth: 1))

            HStack(spacing: 7) {
                Image(systemName: "hand.draw").font(.system(size: 13))
                Text("Move your cursor close. Stroke gently.").font(.system(size: 11))
            }
            .foregroundStyle(Palette.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("GOOD COMPANY, YOUR WAY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Palette.secondary)
                Text("What’s the mood?").font(.system(size: 23, weight: .regular, design: .serif))
            }
            VStack(spacing: 8) {
                ForEach(Personality.allCases, id: \.self) { personality in
                    PersonalityCard(
                        personality: personality,
                        selected: model.preferences.personality == personality
                    ) { model.select(personality) }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("A touch of mischief").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(Int(model.preferences.mischief * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                }
                Slider(value: $model.preferences.mischief, in: 0...1)
                    .accessibilityLabel("Mischief level")
                HStack {
                    Text("little angel")
                    Spacer()
                    Text("lovable menace")
                }
                .font(.system(size: 9))
                .foregroundStyle(Palette.secondary)
            }
            Rectangle().fill(Palette.line.opacity(0.75)).frame(height: 0.7)
            HStack {
                Text("LITTLE RITUALS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(Palette.secondary)
                Spacer()
                if model.interactions > 0 {
                    Text("\(model.interactions) happy moments")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.secondary)
                }
            }
            HStack(spacing: 9) {
                RitualButton(title: "Treat", symbol: "carrot.fill") { model.perform(.treat) }
                RitualButton(title: "Play", symbol: "tennisball.fill") { model.perform(.play) }
                RitualButton(title: model.state == .sleeping ? "Wake" : "Nap", symbol: model.state == .sleeping ? "sun.max.fill" : "moon.zzz.fill") { model.toggleNap() }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 17) {
            Rectangle().fill(Palette.line.opacity(0.65)).frame(height: 0.7)
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "leaf").font(.system(size: 11))
                    Text("Small paws. Big personality.").font(.system(size: 11))
                }
                .foregroundStyle(Palette.secondary)
                Spacer()
                Button { model.isVisible.toggle() } label: {
                    Label(model.isVisible ? "Tuck away" : "Bring back", systemImage: model.isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
                Button { model.isPaused.toggle() } label: {
                    Label(model.isPaused ? "Let’s wander" : "Settle down", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Palette.ink, in: Capsule())
                        .foregroundStyle(Palette.paper)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
        }
    }
}

private struct PersonalityCard: View {
    let personality: Personality
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: personality.symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(selected ? Palette.orange : Palette.secondary)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(personality.title).font(.system(size: 13, weight: .semibold))
                    Text(personality.description).font(.system(size: 9))
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(selected ? Palette.orange : Palette.line, lineWidth: 1).frame(width: 14, height: 14)
                    if selected { Circle().fill(Palette.orange).frame(width: 6, height: 6) }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(selected ? Color(red: 0.97, green: 0.91, blue: 0.86) : .white.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Palette.orange.opacity(0.5) : Palette.line.opacity(0.55), lineWidth: 0.8))
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(personality.title): \(personality.description)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct RitualButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Palette.orange)
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 67)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line.opacity(0.6), lineWidth: 0.7))
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .onHover { if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }
}

private struct RoomBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for x in stride(from: 18.0, to: size.width, by: 22) {
                    for y in stride(from: 18.0, to: size.height, by: 22) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(Palette.secondary.opacity(0.13)))
                    }
                }
            }
            Circle()
                .fill(Color(red: 0.96, green: 0.82, blue: 0.60).opacity(0.45))
                .frame(width: 180, height: 180)
                .position(x: proxy.size.width * 0.57, y: 135)
            Ellipse()
                .fill(Color.white.opacity(0.32))
                .frame(width: proxy.size.width * 0.8, height: 80)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height - 40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .allowsHitTesting(false)
    }
}

private struct PreferencesPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("Make yourself at home.").font(.system(size: 21, design: .serif))
            VStack(alignment: .leading, spacing: 7) {
                Text("Companion’s name").font(.system(size: 11, weight: .medium))
                TextField("Miso", text: $model.preferences.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.preferences = model.preferences.sanitized() }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("A little smaller, a little bigger").font(.system(size: 11))
                    Spacer()
                    Text("\(Int(model.preferences.size * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                }
                Slider(value: $model.preferences.size, in: 0.65...1.5)
                    .accessibilityLabel("Companion size")
            }
            Divider()
            Toggle("Show name below the panda", isOn: $model.preferences.showName)
            Toggle("Wander across desktop Spaces", isOn: $model.preferences.allSpaces)
            Toggle("Nap when I’ve been away a while", isOn: $model.preferences.quietWhenIdle)
            Toggle("Little sound effects", isOn: $model.preferences.sound)
            Text("Drag to pick up. Click to pet. Right-click for little rituals. The paw in your menu bar is always there.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .padding(25)
        .frame(width: 340)
        .background(Palette.paper)
        .tint(Palette.orange)
    }
}

private struct PetPreview: NSViewRepresentable {
    let model: AppModel

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.model = model
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 30
        view.ignoresSiblingOrder = true
        let scene = PetScene(size: CGSize(width: 360, height: 260), atlas: model.atlas, preview: true)
        view.presentScene(scene)
        model.previewScene = scene
        model.desktop.renderNow()
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

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
            let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
            addTrackingArea(area)
            tracking = area
        }

        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            defer { lastPointer = point }
            guard let previous = lastPointer, let scene = scene as? PetScene,
                  scene.hitPet(scene.convertPoint(fromView: point)), let model else { return }
            model.desktop.engine.stroke(distance: hypot(point.x - previous.x, point.y - previous.y))
        }

        override func mouseExited(with event: NSEvent) { lastPointer = nil; NSCursor.arrow.set() }
        override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseDown(with event: NSEvent) {
            guard let scene = scene as? PetScene,
                  scene.hitPet(scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))) else { return }
            lastPointer = convert(event.locationInWindow, from: nil)
            model?.perform(.pet)
        }
        override func rightMouseDown(with event: NSEvent) { model?.perform(.surprise) }
        override var acceptsFirstResponder: Bool { false }
    }
}
