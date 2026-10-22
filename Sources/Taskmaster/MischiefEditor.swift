import AppKit
import CompanionCore
import SwiftUI

struct MischiefEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            title(
                "Small paws. Petty crimes.",
                subtitle: "Choose which kinds of trouble are welcome. Focus time stays peaceful.")
            HStack(spacing: 9) {
                ForEach(Personality.allCases, id: \.self) { mood in
                    Button {
                        model.select(mood)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mood.symbol).font(.system(size: 20))
                            Text(mood.title).font(.system(size: 12, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(
                                model.preferences.personality == mood
                                    ? Palette.orange.opacity(0.1) : .white.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13).stroke(
                                    model.preferences.personality == mood ? Palette.orange : Palette.line,
                                    lineWidth: 0.8))
                    }.buttonStyle(.plain)
                }
            }
            setting("Mischief", value: "\(Int(model.preferences.mischief * 100))%") {
                Slider(value: $model.preferences.mischief, in: 0...1).accessibilityLabel("Mischief intensity")
            }
            Divider()
            Toggle("Muddy little paws", isOn: $model.preferences.muddyPaws).font(.system(size: 14, weight: .medium))
            Text(
                "In Chaos, \(model.preferences.name) leaves a trail wherever they walk. Pawprints fade on their own and never catch your clicks."
            )
            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            setting("How long the evidence stays", value: "\(Int(model.preferences.pawprintSeconds)) seconds") {
                Slider(value: $model.preferences.pawprintSeconds, in: 8...90, step: 1).accessibilityLabel(
                    "Pawprint lifetime")
            }
            HStack {
                Button("Muddy zoomies") { model.perform(.muddyZoomies) }.disabled(!model.preferences.muddyPaws)
                Button("Wipe pawprints") { model.wipePawprints() }
            }.controlSize(.small)
            Divider()
            Toggle("Let \(model.preferences.name) borrow my cursor", isOn: $model.preferences.cursorHeists).font(
                .system(size: 14, weight: .medium))
            Text(
                "Chaos only. A nearby pointer may get snatched for a tiny getaway, lasting at most 1½ seconds. Click or press Esc to end the game immediately."
            )
            .font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            Text(
                "Heists take a long breather between attempts. They stay off during focus, naps, full-screen presentations and Reduce Motion."
            )
            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Button("Invite a cursor heist") { model.inviteCursorHeist() }
                .disabled(!model.preferences.cursorHeists || model.preferences.mischief < 0.75 || model.focusActive)
            if let message = model.chaosMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(Palette.orange)
            }
        }
    }
}
