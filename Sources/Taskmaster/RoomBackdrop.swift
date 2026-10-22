import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct RoomBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for x in stride(from: 18.0, to: size.width, by: 22) {
                    for y in stride(from: 18.0, to: size.height, by: 22) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                            with: .color(Palette.secondary.opacity(0.13)))
                    }
                }
            }
            Circle()
                .fill(Color(red: 0.96, green: 0.82, blue: 0.60).opacity(0.45))
                .frame(width: 180, height: 180)
                .position(x: proxy.size.width * 0.57, y: 135)
            Ellipse()
                .fill(Color.white.opacity(0.32))
                .frame(width: proxy.size.width * 0.8, height: 80)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height - 40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .allowsHitTesting(false)
    }
}
