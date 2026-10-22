import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct CompanionRoom: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            header
            HStack(alignment: .top, spacing: 37) {
                introduction.frame(maxWidth: .infinity)
                controls.frame(width: 300)
            }
            footer
        }
        .padding(.horizontal, 34)
        .padding(.top, 47)
        .padding(.bottom, 25)
        .frame(minWidth: 790, minHeight: 710)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.orange)
        .preferredColorScheme(.light)
    }
}
