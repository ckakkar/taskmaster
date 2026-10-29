import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct PersonalityCard: View {
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
                    Text(personality.description).font(.system(size: 11))
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
            .background(
                selected ? Color(red: 0.97, green: 0.91, blue: 0.86) : .white.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13).stroke(
                    selected ? Palette.orange.opacity(0.5) : Palette.line.opacity(0.55), lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(personality.title): \(personality.description)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
