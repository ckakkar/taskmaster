import AppKit
import CompanionCore
import SwiftUI

struct WardrobeEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(
                "A familiar little face. Your way.",
                subtitle: "A softer coat, a favorite color, a tiny finishing touch. Changes appear as you choose.")
            HStack(spacing: 12) {
                ForEach(AvatarKind.available, id: \.self) { avatar in
                    Button {
                        model.selectAvatar(avatar)
                    } label: {
                        VStack(spacing: 4) {
                            if let frame = model.art(for: avatar)?.frame(for: .sitting) {
                                Image(nsImage: NSImage(cgImage: frame.image, size: .zero)).resizable().scaledToFit()
                                    .frame(height: 68)
                            }
                            Text(avatar.title).font(.system(size: 12, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(10)
                            .background(
                                model.preferences.avatar == avatar ? Palette.orange.opacity(0.1) : .white.opacity(0.65),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    model.preferences.avatar == avatar ? Palette.orange : Palette.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("Choose \(avatar.title)")
                }
            }
            PetPreview(model: model, wardrobe: true)
                .frame(height: 250)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Palette.paper], startPoint: .top,
                        endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18)
                )
                .overlay(alignment: .topLeading) {
                    Text("\(model.preferences.name.uppercased())’S WARDROBE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(Palette.secondary).padding(17)
                }
                .accessibilityLabel("Live preview of your companion’s outfit")
            HStack {
                Text("A name of their own").font(.system(size: 12))
                Spacer()
                TextField(model.preferences.avatar.title, text: $model.preferences.name).textFieldStyle(.roundedBorder)
                    .frame(width: 155)
                    .accessibilityLabel("Companion name")
            }
            if model.preferences.avatar == .miso {
                Picker("Coat tone", selection: $model.preferences.coat) {
                    ForEach(CoatStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Little accessory", selection: $model.preferences.accessory) {
                    ForEach(AccessoryStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                HStack(spacing: 12) {
                    Text("Favorite color").font(.system(size: 12))
                    Spacer()
                    ForEach(AccessoryColor.allCases, id: \.self) { color in
                        Button {
                            model.preferences.accessoryColor = color
                        } label: {
                            Circle().fill(Color(nsColor: color.nsColor)).frame(width: 25, height: 25)
                                .overlay(Circle().stroke(.white, lineWidth: 3).padding(3))
                                .overlay(
                                    Circle().stroke(
                                        model.preferences.accessoryColor == color ? Palette.ink : .clear, lineWidth: 1.3
                                    ).padding(-3))
                        }.buttonStyle(.plain).help(color.title).accessibilityLabel("\(color.title) accessory")
                    }
                }.padding(.vertical, 4)
            }
            Button(model.preferences.avatar.signature) { model.perform(.signature) }.buttonStyle(.borderedProminent)
            setting("Desktop size", value: "\(Int(model.preferences.size * 100))%") {
                Slider(value: $model.preferences.size, in: 0.65...1.5, step: 0.05).accessibilityLabel("Companion size")
            }
            Toggle("Show their name on the desktop", isOn: $model.preferences.showName).font(.system(size: 12))
        }
    }
}
