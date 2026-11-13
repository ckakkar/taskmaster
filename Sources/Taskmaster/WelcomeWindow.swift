import AppKit
import CompanionCore
import SwiftUI

/// Shown once, on first launch: how to say hello, where the controls live, and opening at login.
@MainActor
final class WelcomeWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = Palette.paperBackground
            window.animationBehavior = .alertPanel
            window.contentViewController = NSHostingController(
                rootView: WelcomeView(
                    model: model,
                    onCustomize: { [weak self] in
                        self?.finish()
                        self?.model.openSettings(.companion)
                    },
                    onDone: { [weak self] in self?.finish() }))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // No focus ring on the login switch when the window opens; Tab still reaches every control.
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(nil) }
    }

    private func finish() {
        model.preferences.hasOnboarded = true
        model.flushPreferences()
        window?.close()
    }
}

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    let onCustomize: () -> Void
    let onDone: () -> Void
    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
    @ViewState private var appeared = false

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSImage(cgImage: model.atlas.frame(for: .highFive).image, size: .zero))
                .resizable().scaledToFit()
                .frame(height: 150)
                .shadow(color: Palette.orange.opacity(0.25), radius: 18, y: 10)
                .scaleEffect(appeared ? 1 : 0.88)
                .opacity(appeared ? 1 : 0)
                .padding(.top, 36)

            Text("Say hello to \(name).")
                .font(.system(size: 28, design: .serif))
                .padding(.top, 14)
                .entrance(appeared, delay: 0.12)
            Text("A little company. A little mischief.")
                .foregroundStyle(Palette.secondary)
                .padding(.top, 4)
                .entrance(appeared, delay: 0.18)

            VStack(spacing: 10) {
                step(
                    symbol: "hand.wave.fill", title: "Right there on your desktop",
                    detail: "Click to pet or boop the nose, drag to pick up, scroll to tickle, right-click for games."
                ) { EmptyView() }
                .entrance(appeared, delay: 0.26)
                step(
                    symbol: "pawprint.fill", title: "The paw in your menu bar",
                    detail: "Games, settings and a pause. Closing a window never sends \(name) away."
                ) { EmptyView() }
                .entrance(appeared, delay: 0.33)
                step(
                    symbol: "power", title: "Open at login",
                    detail: "So \(name) is there whenever you sign in."
                ) {
                    Toggle(
                        "Open at login",
                        isOn: Binding(
                            get: { launchAtLogin },
                            set: { on in
                                LaunchAtLogin.set(on)
                                launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
                            })
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .entrance(appeared, delay: 0.40)
            }
            .padding(.top, 26)
            .padding(.horizontal, 30)

            Spacer(minLength: 20)

            HStack(spacing: 12) {
                Button(action: onCustomize) {
                    Text("Make It Yours").frame(maxWidth: .infinity).frame(height: 28)
                }
                .controlSize(.large)
                Button(action: onDone) {
                    Text("Get Started").font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
            .entrance(appeared, delay: 0.48)
        }
        .frame(width: 480, height: 600)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
        .tint(Palette.tint)
        .onAppear {
            let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            withAnimation(reduced ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func step<Accessory: View>(
        symbol: String, title: String, detail: String, @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.orange.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line.opacity(0.7), lineWidth: 0.7))
    }
}

extension View {
    /// Rises gently into place after `delay` once `shown` turns true; with Reduce Motion it only fades.
    func entrance(_ shown: Bool, delay: Double) -> some View {
        modifier(Entrance(shown: shown, delay: delay))
    }
}

private struct Entrance: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2).delay(delay * 0.3)
                    : .spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: shown)
    }
}
