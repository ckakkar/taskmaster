import AppKit
import CompanionCore
import SwiftUI

struct VoiceEditor: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            title("A voice you recognize.", subtitle: "Write the things you’d like your little companion to say.")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("YOUR QUIPS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5)
                    Spacer()
                    Text("\(model.preferences.quipLines.count) sayings").font(.system(size: 10)).foregroundStyle(
                        Palette.secondary)
                }
                TextEditor(text: $model.preferences.customQuips)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .frame(height: 165)
                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 0.7))
                    .accessibilityLabel("Custom quips, one saying per line")
                Text("One saying per line. Use {name} for your pet’s name. Up to 100 sayings, 160 characters each.")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                HStack(spacing: 8) {
                    Button("Add cozy lines") { model.addQuipPack(chaotic: false) }
                    Button("Add chaotic lines") { model.addQuipPack(chaotic: true) }
                }.controlSize(.small)
                Toggle(
                    "Mix in \(model.preferences.name)’s original sayings", isOn: $model.preferences.includeBuiltInQuips
                ).font(.system(size: 12))
            }
            setting(
                "How talkative?",
                value: model.preferences.chatter == 0
                    ? "Silent" : model.preferences.chatter < 0.5 ? "Occasional" : "Chatty"
            ) {
                Slider(value: $model.preferences.chatter, in: 0...1).accessibilityLabel("Chatter level")
            }
            setting("Time to read a saying", value: "\(Int(model.preferences.speechSeconds)) seconds") {
                Slider(value: $model.preferences.speechSeconds, in: 2...12, step: 1).accessibilityLabel(
                    "Speech duration")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Bubble color").font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    ForEach(BubbleStyle.allCases, id: \.self) { style in
                        Button {
                            model.preferences.bubbleStyle = style
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(style.color).frame(width: 13, height: 13).overlay(
                                    Circle().stroke(Palette.line, lineWidth: 0.6))
                                Text(style.title).font(.system(size: 10))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 8)
                            .background(.white.opacity(0.6), in: Capsule())
                            .overlay(
                                Capsule().stroke(
                                    model.preferences.bubbleStyle == style ? Palette.orange : Palette.line, lineWidth: 1
                                ))
                        }.buttonStyle(.plain)
                    }
                }
                Text(
                    model.preferences.chatter == 0
                        ? "\(model.preferences.name) is enjoying some quiet." : model.lastQuip
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.preferences.bubbleStyle == .midnight ? Color.white : Palette.ink)
                .padding(16).frame(maxWidth: .infinity, minHeight: 65)
                .background(model.preferences.bubbleStyle.color, in: RoundedRectangle(cornerRadius: 16))
                Button("Say something") { model.perform(.saySomething) }
                    .disabled(
                        model.focusActive || model.preferences.chatter == 0
                            || (!model.preferences.includeBuiltInQuips && model.preferences.quipLines.isEmpty))
            }
        }
    }
}
