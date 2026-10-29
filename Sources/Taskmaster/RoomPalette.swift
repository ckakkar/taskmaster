import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

enum Palette {
    static let paper = Color(red: 0.985, green: 0.973, blue: 0.95)
    static let ink = Color(red: 0.23, green: 0.20, blue: 0.17)
    // About 5.4:1 against paper, comfortably readable at small sizes.
    static let secondary = Color(red: 0.45, green: 0.39, blue: 0.34)
    static let orange = Color(red: 0.76, green: 0.35, blue: 0.21)
    static let line = Color(red: 0.86, green: 0.82, blue: 0.77)
    static let green = Color(red: 0.34, green: 0.48, blue: 0.39)
}

/// SwiftUI's `State`. In the macOS 27 SDK `@State` is a macro whose plugin ships only with Xcode, so with just
/// the Command Line Tools the attribute doesn't compile; naming the property wrapper directly works with any
/// toolchain and behaves identically (as in Luna).
typealias ViewState<Value> = SwiftUI.State<Value>
