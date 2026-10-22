import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct RitualButton: View {
    let title: String
    let symbol: String
    var hint: String? = nil
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
        .help(hint ?? title)
        .onHover { if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }
}
