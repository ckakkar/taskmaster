import AppKit
import CompanionCore
import SwiftUI

enum CustomizationSection: String, CaseIterable {
    case look, voice, mischief, memes, habits
    var title: String {
        switch self {
        case .look: "Look & feel"
        case .voice: "Voice & quips"
        case .mischief: "Little crimes"
        case .memes: "Meme stash"
        case .habits: "Daily rhythm"
        }
    }
    var symbol: String {
        switch self {
        case .look: "tshirt"
        case .voice: "text.bubble"
        case .mischief: "pawprint"
        case .memes: "photo.on.rectangle.angled"
        case .habits: "leaf"
        }
    }
}

struct CustomizationView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make \(model.preferences.name) yours.").font(.system(size: 29, design: .serif))
                    Text("A little more you. A little more personality.").font(.system(size: 12)).foregroundStyle(
                        Palette.secondary)
                }
                Spacer()
                Button("Done") { model.closeCustomization?() }.buttonStyle(.borderedProminent)
            }
            HStack(alignment: .top, spacing: 27) {
                VStack(spacing: 7) {
                    ForEach(CustomizationSection.allCases, id: \.self) { section in
                        Button {
                            model.customizationSection = section
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    model.customizationSection == section ? Palette.orange.opacity(0.1) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(model.customizationSection == section ? Palette.orange : Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "pawprint.fill").font(.system(size: 24)).foregroundStyle(
                        Palette.orange.opacity(0.25))
                    Text("small paws.\nyour kind of company.")
                        .font(.system(size: 10)).multilineTextAlignment(.center).foregroundStyle(Palette.secondary)
                }.frame(width: 151)
                Divider()
                ScrollView {
                    Group {
                        switch model.customizationSection {
                        case .look: WardrobeEditor(model: model)
                        case .voice: VoiceEditor(model: model)
                        case .mischief: MischiefEditor(model: model)
                        case .memes: MemeStash(model: model, library: model.library)
                        case .habits: RhythmEditor(model: model)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(30)
        .padding(.top, 22)
        .frame(minWidth: 820, minHeight: 650)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.orange)
        .preferredColorScheme(.light)
    }
}
