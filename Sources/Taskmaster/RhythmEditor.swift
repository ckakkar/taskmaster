import AppKit
import CompanionCore
import SwiftUI

struct RhythmEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            title(
                "Company that fits your day.",
                subtitle: "Give \(model.preferences.name) a rhythm that feels welcome on your desktop.")
            VStack(alignment: .leading, spacing: 12) {
                Text("Quiet focus").font(.system(size: 17, design: .serif))
                Text(
                    "\(model.preferences.name) settles nearby while you work. When time is up, you get a gentle stretch reminder."
                )
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                HStack {
                    Text("Session length").font(.system(size: 12))
                    Spacer()
                    TextField("Minutes", value: $model.preferences.focusMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 55).accessibilityLabel("Focus minutes")
                    Text("min").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                HStack {
                    ForEach([15, 25, 45], id: \.self) { minutes in
                        Button("\(minutes) min") { model.preferences.focusMinutes = minutes }.controlSize(.small)
                    }
                    Spacer()
                    Button(model.focusActive ? "End focus" : "Focus together") {
                        if model.focusActive { model.stopFocus() } else { model.startFocus() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if model.focusActive {
                    Text("\(model.focusLabel) left · quiet company").font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.green)
                }
                if model.preferences.completedFocusSessions > 0 {
                    Text("\(model.preferences.completedFocusSessions) little focus sessions, together.").font(
                        .system(size: 10)
                    ).foregroundStyle(Palette.secondary)
                }
            }
            Divider()
            Toggle("Occasionally bring me a meme", isOn: $model.preferences.autoMemes).font(
                .system(size: 13, weight: .medium))
            Text(
                "Only enabled cards in your stash are used. Deliveries pause during focus, naps and when \(model.preferences.name) is tucked away."
            )
            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            setting("Time between deliveries", value: "\(Int(model.preferences.memeInterval / 60)) min") {
                Slider(value: $model.preferences.memeInterval, in: 120...3_600, step: 60).accessibilityLabel(
                    "Meme delivery interval")
            }
            setting("Leave each card for", value: "\(Int(model.preferences.memeStaySeconds)) seconds") {
                Slider(value: $model.preferences.memeStaySeconds, in: 8...120, step: 1).accessibilityLabel(
                    "Meme display time")
            }
            Divider()
            Toggle("Nap when I’ve been away", isOn: $model.preferences.quietWhenIdle)
            Toggle("Show \(model.preferences.name) on every desktop Space", isOn: $model.preferences.allSpaces)
            Toggle("Little sound effects", isOn: $model.preferences.sound)
        }
    }
}
