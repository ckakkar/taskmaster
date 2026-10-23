import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

struct PreferencesPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("Make yourself at home.").font(.system(size: 21, design: .serif))
            VStack(alignment: .leading, spacing: 7) {
                Text("Companion’s name").font(.system(size: 11, weight: .medium))
                TextField(model.preferences.avatar.title, text: $model.preferences.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.preferences = model.preferences.sanitized() }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("A little smaller, a little bigger").font(.system(size: 11))
                    Spacer()
                    Text("\(Int(model.preferences.size * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                }
                Slider(value: $model.preferences.size, in: 0.65...1.5)
                    .accessibilityLabel("Companion size")
            }
            Divider()
            Toggle("Show name below the panda", isOn: $model.preferences.showName)
            Toggle("Wander across desktop Spaces", isOn: $model.preferences.allSpaces)
            Toggle("Nap when I’ve been away a while", isOn: $model.preferences.quietWhenIdle)
            Toggle("Little sound effects", isOn: $model.preferences.sound)
            Text(
                "Drag to pick up. Click to pet. Right-click for little rituals. The paw in your menu bar is always there."
            )
            .font(.system(size: 11))
            .foregroundStyle(Palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            if model.updater.isAvailable {
                // Sparkle keeps this setting; the model only announces the change to the view.
                Toggle(
                    "Check for updates automatically",
                    isOn: Binding(
                        get: { model.updater.automaticallyChecks },
                        set: {
                            model.objectWillChange.send()
                            model.updater.automaticallyChecks = $0
                        }))
                HStack {
                    Text("Taskmaster \(AppInfo.version)").foregroundStyle(Palette.secondary)
                    Spacer()
                    Button("Check Now") { model.updater.checkForUpdates() }.controlSize(.small)
                }
            } else {
                Text("This copy of Taskmaster was built locally and doesn’t update itself.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
        .padding(25)
        .frame(width: 340)
        .background(Palette.paper)
        .tint(Palette.orange)
    }
}
