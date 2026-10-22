import AppKit
import CompanionCore
import SwiftUI

@MainActor func title(_ text: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
        Text(text).font(.system(size: 23, design: .serif))
        Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(
            horizontal: false, vertical: true)
    }
}

@MainActor func setting<Content: View>(_ title: String, value: String, @ViewBuilder content: () -> Content)
    -> some View
{
    VStack(alignment: .leading, spacing: 7) {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
        }
        content()
    }
}

extension BubbleStyle {
    var color: Color { Color(nsColor: nsColor) }
}
