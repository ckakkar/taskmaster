import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

@MainActor
extension CompanionRoom {
    var header: some View {
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
                Text(
                    model.isPaused
                        ? "Taking a little pause" : model.isVisible ? "At home on your desktop" : "Tucked away for now"
                )
                .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Palette.secondary)
            Button {
                model.customize(.look)
            } label: {
                Label("Make it yours", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .medium)).padding(.horizontal, 11).padding(.vertical, 8)
                    .background(.white.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(Palette.line.opacity(0.7), lineWidth: 0.7))
            }.buttonStyle(.plain)
            Button {
                model.showPreferences.toggle()
            } label: {
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
}
