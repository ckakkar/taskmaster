import Foundation

public enum CoatPalette {
    /// Recolors warm fur in premultiplied RGBA, preserving cream markings and alpha.
    public static func recolor(_ rgba: inout [UInt8], style: CoatStyle) {
        guard style != .cinnamon else { return }
        for i in stride(from: 0, to: rgba.count - 3, by: 4) {
            let alpha = Double(rgba[i + 3]) / 255
            guard alpha > 0 else { continue }
            let r = Double(rgba[i]) / 255 / alpha
            let g = Double(rgba[i + 1]) / 255 / alpha
            let b = Double(rgba[i + 2]) / 255 / alpha
            if g > 0.72 && b > 0.62 { continue }
            let warm =
                ((r - b - 0.045) / 0.22).clamped(to: 0...1)
                * ((r - 0.08) / 0.3).clamped(to: 0...1)
            guard warm > 0 else { continue }
            let light = r * 0.3 + g * 0.59 + b * 0.11
            let target: [Double] =
                switch style {
                case .cinnamon: [r, g, b]
                case .honey: [light * 1.5, light * 1.12, light * 0.48]
                case .dusk: [light * 0.95, light * 0.72, light * 1.22]
                case .moonlit: [light * 1.14, light * 1.20, light * 1.29]
                }
            for (channel, original) in [r, g, b].enumerated() {
                rgba[i + channel] = UInt8(
                    ((original + (target[channel] - original) * warm * 0.93)
                        .clamped(to: 0...1) * alpha * 255).rounded())
            }
        }
    }
}
