import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct RitualButton: View {
    let title: String
    let symbol: String
    var hint: String? = nil
    let action: () -> Void
    @ViewState private var taps = 0
    @ViewState private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Palette.orange)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : taps)
                    .contentTransition(.symbolEffect(.replace))
                Text(title).font(.system(size: 12, weight: .medium))
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 67)
            .background(hovering ? Palette.cardHover : Palette.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13).stroke(
                    hovering ? Palette.orange.opacity(0.35) : Palette.line.opacity(0.6), lineWidth: 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13))
            .animation(.easeOut(duration: 0.15), value: hovering)
            .animation(.easeInOut(duration: 0.2), value: title)
        }
        .buttonStyle(SoftPressStyle())
        .help(hint ?? title)
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
}
