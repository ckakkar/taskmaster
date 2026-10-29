import AppKit
import CompanionCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, companion, behaviour, sayings, memes, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .companion: "Companion"
        case .behaviour: "Behaviour"
        case .sayings: "Sayings"
        case .memes: "Memes"
        case .advanced: "Advanced"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .companion: "pawprint.fill"
        case .behaviour: "sparkles"
        case .sayings: "text.bubble.fill"
        case .memes: "photo.on.rectangle.angled"
        case .advanced: "slider.horizontal.3"
        }
    }
    var color: Color {
        switch self {
        case .general: .gray
        case .companion: Palette.orange
        case .behaviour: .purple
        case .sayings: .teal
        case .memes: .pink
        case .advanced: .indigo
        }
    }
}

/// Taskmaster's Settings, in an ordinary window with a sidebar like System Settings (and Luna).
@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered,
            defer: false)
        window.title = "Taskmaster Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 700, height: 500)
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = [.minSize]
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 800, height: 620))
        window.setFrameAutosaveName("TaskmasterSettings")
        self.window = window
        return window
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(
                selection: Binding(
                    get: { Optional(model.settingsPane) }, set: { if let pane = $0 { model.settingsPane = pane } })
            ) {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarRow(pane: pane).tag(pane)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 196, max: 240)
        } detail: {
            VStack(spacing: 0) {
                if let problem = model.preferencesProblem ?? model.library.problem {
                    StorageNotice(message: problem, retry: { model.retrySaving() }, dismiss: { model.dismissProblem() })
                        .padding([.horizontal, .top], 20)
                }
                pane
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(model.settingsPane.title)
        }
        .tint(Palette.orange)
    }

    @ViewBuilder private var pane: some View {
        Group {
            switch model.settingsPane {
            case .general: GeneralPane(model: model)
            case .companion: CompanionPane(model: model)
            case .behaviour: BehaviourPane(model: model)
            case .sayings: SayingsPane(model: model)
            case .memes: MemesPane(model: model, library: model.library)
            case .advanced: AdvancedPane(model: model)
            }
        }
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane

    var body: some View {
        Label {
            Text(pane.title)
        } icon: {
            Image(systemName: pane.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(pane.color.gradient))
        }
    }
}

/// A switch with a one-line explanation underneath, the way every behaviour is described.
struct ExplainedToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    init(_ title: String, detail: String, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
            Text(detail)
        }
    }
}

/// A slider row with its current value shown on the right.
struct ValueSlider: View {
    let title: String
    let value: String
    @Binding var amount: Double
    let range: ClosedRange<Double>
    var step: Double? = nil

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                if let step {
                    Slider(value: $amount, in: range, step: step).labelsHidden()
                } else {
                    Slider(value: $amount, in: range).labelsHidden()
                }
                Text(value).monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 64, alignment: .trailing)
            }
            .frame(maxWidth: 280)
        } label: {
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
