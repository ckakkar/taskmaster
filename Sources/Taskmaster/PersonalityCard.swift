import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct PersonalityCard: View {
    let personality: Personality
    let selected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: personality.symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(selected ? Palette.orange : Palette.secondary)
                    .symbolEffect(.bounce, value: selected && !reduceMotion)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(personality.title).font(.system(size: 13, weight: .semibold))
                    Text(personality.description).font(.system(size: 11))
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(selected ? Palette.orange : Palette.line, lineWidth: 1).frame(width: 14, height: 14)
                    Circle().fill(Palette.orange).frame(width: 6, height: 6)
                        .scaleEffect(selected ? 1 : 0.01)
                        .opacity(selected ? 1 : 0)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(selected ? Palette.selected : Palette.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13).stroke(
                    selected ? Palette.orange.opacity(0.5) : Palette.line.opacity(0.55), lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(SoftPressStyle(lift: false))
        .animation(
            reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.7), value: selected
        )
        .accessibilityLabel("\(personality.title): \(personality.description)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
