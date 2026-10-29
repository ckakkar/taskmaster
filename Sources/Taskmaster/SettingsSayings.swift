import AppKit
import CompanionCore
import SwiftUI

struct SayingsPane: View {
    @ObservedObject var model: AppModel

    private var name: String { model.preferences.sanitized().name }
    private var chatterLabel: String {
        model.preferences.chatter == 0 ? "Silent" : model.preferences.chatter < 0.5 ? "Occasional" : "Chatty"
    }
    private var canSpeak: Bool {
        !model.focusActive && model.preferences.chatter > 0
            && (model.preferences.includeBuiltInQuips || !model.preferences.quipLines.isEmpty)
    }

    var body: some View {
        Form {
            Section("How chatty") {
                ValueSlider(
                    title: "Talkativeness", value: chatterLabel, amount: $model.preferences.chatter, range: 0...1)
                ValueSlider(
                    title: "Time to read a saying", value: "\(Int(model.preferences.speechSeconds)) s",
                    amount: $model.preferences.speechSeconds, range: 2...12, step: 1)
            }

            Section("Speech bubble") {
                LabeledContent("Colour") {
                    HStack(spacing: 10) {
                        ForEach(BubbleStyle.allCases, id: \.self) { style in
                            Swatch(color: style.color, selected: model.preferences.bubbleStyle == style) {
                                model.preferences.bubbleStyle = style
                            }
                            .help(style.title)
                            .accessibilityLabel("\(style.title) bubble")
                        }
                    }
                }
                HStack(spacing: 12) {
                    Text(model.preferences.chatter == 0 ? "\(name) is enjoying some quiet." : model.lastQuip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            model.preferences.bubbleStyle == .midnight
                                ? Color(red: 0.98, green: 0.95, blue: 0.87) : Color(red: 0.35, green: 0.27, blue: 0.23)
                        )
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(model.preferences.bubbleStyle.color, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                    Spacer()
                    Button("Say Something") { model.perform(.saySomething) }.disabled(!canSpeak)
                }
            }

            Section {
                TextEditor(text: $model.preferences.customQuips)
                    .font(.system(size: 13))
                    .frame(minHeight: 130)
                    .accessibilityLabel("Your sayings, one per line")
                    .overlay(alignment: .topLeading) {
                        if model.preferences.customQuips.isEmpty {
                            Text("One saying per line, like “Water break? I’ll hold your spot.”")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    Button("Add Cozy Lines") { model.addQuipPack(chaotic: false) }
                    Button("Add Chaotic Lines") { model.addQuipPack(chaotic: true) }
                    Spacer()
                    Text("\(model.preferences.quipLines.count) sayings").foregroundStyle(.secondary)
                }
                ExplainedToggle(
                    "Mix in \(name)’s own sayings", detail: "Off, only your lines are used.",
                    isOn: $model.preferences.includeBuiltInQuips)
            } header: {
                Text("Your sayings")
            } footer: {
                Text("One per line. Use {name} for your companion’s name. Up to 100 sayings, 160 characters each.")
            }
        }
        .formStyle(.grouped)
    }
}

extension BubbleStyle {
    var color: Color { Color(nsColor: nsColor) }
}
