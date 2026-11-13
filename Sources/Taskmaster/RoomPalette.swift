import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

/// The room's warm paper palette, with a lamplit evening version for Dark Mode.
enum Palette {
    static let paper = adaptive(light: (0.985, 0.973, 0.95), dark: (0.125, 0.11, 0.098))
    static let ink = adaptive(light: (0.23, 0.20, 0.17), dark: (0.95, 0.92, 0.88))
    // About 5.4:1 against paper in both appearances, comfortably readable at small sizes.
    static let secondary = adaptive(light: (0.45, 0.39, 0.34), dark: (0.72, 0.67, 0.62))
    static let orange = adaptive(light: (0.76, 0.35, 0.21), dark: (0.95, 0.55, 0.38))
    /// The control tint: filled buttons and selected segments carry white labels, so the fill stays deep in both
    /// appearances (about 4.4:1 against white) even though accent text brightens in the dark.
    static let tint = Color(red: 0.76, green: 0.35, blue: 0.21)
    static let line = adaptive(light: (0.86, 0.82, 0.77), dark: (0.32, 0.29, 0.26))
    static let green = adaptive(light: (0.34, 0.48, 0.39), dark: (0.55, 0.74, 0.60))
    /// Raised surfaces: buttons, cards and rows sitting on the paper.
    static let card = adaptive(light: (1, 1, 1), dark: (1, 1, 1), lightAlpha: 0.72, darkAlpha: 0.06)
    static let cardHover = adaptive(light: (1, 1, 1), dark: (1, 1, 1), lightAlpha: 0.95, darkAlpha: 0.11)
    static let selected = adaptive(light: (0.97, 0.91, 0.86), dark: (0.36, 0.21, 0.15))
    /// The little stage the companion stands on in the room and in Settings.
    static let stageTop = adaptive(light: (0.96, 0.91, 0.83), dark: (0.27, 0.22, 0.18))
    static let stageBottom = adaptive(light: (0.97, 0.94, 0.88), dark: (0.20, 0.17, 0.14))
    static let sun = adaptive(light: (0.96, 0.82, 0.60), dark: (0.95, 0.66, 0.38), lightAlpha: 0.45, darkAlpha: 0.22)
    static let floorGlow = adaptive(light: (1, 1, 1), dark: (1, 0.92, 0.82), lightAlpha: 0.32, darkAlpha: 0.07)
    static let rim = adaptive(light: (1, 1, 1), dark: (1, 1, 1), lightAlpha: 0.8, darkAlpha: 0.08)
    /// The paper as an AppKit colour, for window backgrounds behind the SwiftUI content.
    static let paperBackground = adaptiveNS(light: (0.985, 0.973, 0.95), dark: (0.125, 0.11, 0.098))

    private static func adaptive(
        light: (Double, Double, Double), dark: (Double, Double, Double), lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(nsColor: adaptiveNS(light: light, dark: dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    private static func adaptiveNS(
        light: (Double, Double, Double), dark: (Double, Double, Double), lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let (red, green, blue) = isDark ? dark : light
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

/// Presses sink with a spring and hovering lifts a little; with Reduce Motion only the colours change.
struct SoftPressStyle: ButtonStyle {
    var cornerRadius: CGFloat = 13
    var lift = true

    func makeBody(configuration: Configuration) -> some View {
        SoftPressBody(configuration: configuration, cornerRadius: cornerRadius, lift: lift)
    }

    private struct SoftPressBody: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        let lift: Bool
        @ViewState private var hovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.965 : hovering && lift ? 1.015 : 1)
                .shadow(
                    color: .black.opacity(hovering && lift && !configuration.isPressed ? 0.08 : 0),
                    radius: 8, y: 3
                )
                .opacity(isEnabled ? 1 : 0.5)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.62),
                    value: configuration.isPressed
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
                .onHover { hovering = $0 && isEnabled }
        }
    }
}

/// SwiftUI's `State`. In the macOS 27 SDK `@State` is a macro whose plugin ships only with Xcode, so with just
/// the Command Line Tools the attribute doesn't compile; naming the property wrapper directly works with any
/// toolchain and behaves identically (as in Luna).
typealias ViewState<Value> = SwiftUI.State<Value>
