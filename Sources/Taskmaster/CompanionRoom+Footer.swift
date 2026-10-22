import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

@MainActor
extension CompanionRoom {
    var footer: some View {
        VStack(spacing: 17) {
            Rectangle().fill(Palette.line.opacity(0.65)).frame(height: 0.7)
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "leaf").font(.system(size: 11))
                    Text(model.preferences.avatar.subtitle).font(.system(size: 11))
                }
                .foregroundStyle(Palette.secondary)
                Spacer()
                Button {
                    model.isVisible.toggle()
                } label: {
                    Label(
                        model.isVisible ? "Tuck away" : "Bring back", systemImage: model.isVisible ? "eye.slash" : "eye"
                    )
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
                Button {
                    model.isPaused.toggle()
                } label: {
                    Label(
                        model.isPaused ? "Let’s wander" : "Settle down",
                        systemImage: model.isPaused ? "play.fill" : "pause.fill"
                    )
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
