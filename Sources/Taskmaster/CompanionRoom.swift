import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct CompanionRoom: View {
    @ObservedObject var model: AppModel

    var body: some View {
        // Scrolls when the screen is shorter than the room, so every control stays reachable.
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 27) {
                header
                if let problem = model.preferencesProblem ?? model.library.problem {
                    StorageNotice(message: problem, retry: { model.retrySaving() }, dismiss: { model.dismissProblem() })
                }
                HStack(alignment: .top, spacing: 37) {
                    introduction.frame(maxWidth: .infinity)
                    controls.frame(width: 300)
                }
                footer
            }
            .padding(.horizontal, 34)
            .padding(.top, 47)
            .padding(.bottom, 25)
        }
        .frame(minWidth: 760)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.orange)
        .preferredColorScheme(.light)
    }
}

/// Says what couldn't be saved or read, with a way to try again.
struct StorageNotice: View {
    let message: String
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.orange)
            Text(message).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Try Again", action: retry)
            Button("Dismiss", action: dismiss).buttonStyle(.borderless)
        }
        .font(.system(size: 12))
        .padding(12)
        .background(Palette.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
