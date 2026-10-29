import AppKit
import CompanionCore
import SwiftUI

struct CompanionPane: View {
    @ObservedObject var model: AppModel

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        Form {
            Section("Who keeps you company") {
                HStack(spacing: 12) {
                    ForEach(AvatarKind.available, id: \.self) { avatar in
                        CharacterCard(model: model, avatar: avatar)
                    }
                }
                .padding(.vertical, 4)
                PetPreview(model: model, wardrobe: true)
                    .frame(height: 210)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Palette.paper], startPoint: .top,
                            endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .accessibilityLabel("Live preview of \(name)")
            }

            Section("Name and size") {
                TextField("Name", text: $model.preferences.name, prompt: Text(model.preferences.avatar.title))
                ValueSlider(
                    title: "Size on the desktop", value: "\(Int((model.preferences.size * 100).rounded()))%",
                    amount: $model.preferences.size, range: 0.65...1.5, step: 0.05)
                ExplainedToggle(
                    "Show their name on the desktop", detail: "A small label under \(name).",
                    isOn: $model.preferences.showName)
            }

            Section("Wardrobe") {
                if model.preferences.avatar == .miso {
                    Picker("Coat", selection: $model.preferences.coat) {
                        ForEach(CoatStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Accessory", selection: $model.preferences.accessory) {
                        ForEach(AccessoryStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Accessory colour") {
                        HStack(spacing: 10) {
                            ForEach(AccessoryColor.allCases, id: \.self) { color in
                                Swatch(
                                    color: Color(nsColor: color.nsColor),
                                    selected: model.preferences.accessoryColor == color
                                ) { model.preferences.accessoryColor = color }
                                .help(color.title)
                                .accessibilityLabel("\(color.title) accessory")
                            }
                        }
                    }
                    .disabled(model.preferences.accessory == .none)
                } else {
                    Text("\(model.preferences.avatar.title) keeps their own look: coats and accessories are Miso’s.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CharacterCard: View {
    @ObservedObject var model: AppModel
    let avatar: AvatarKind

    private var selected: Bool { model.preferences.avatar == avatar }

    var body: some View {
        Button {
            model.selectAvatar(avatar)
        } label: {
            VStack(spacing: 6) {
                if let frame = model.art(for: avatar)?.frame(for: .sitting) {
                    Image(nsImage: NSImage(cgImage: frame.image, size: .zero)).resizable().scaledToFit()
                        .frame(height: 72)
                }
                Text(avatar.title).font(.system(size: 13, weight: .semibold))
                Text(avatar.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Palette.orange.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Palette.orange : Color.primary.opacity(0.1), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose \(avatar.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A round colour choice with a ring around the selected one.
struct Swatch: View {
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle().fill(color).frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                .padding(3)
                .overlay(Circle().stroke(selected ? Color.primary : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
