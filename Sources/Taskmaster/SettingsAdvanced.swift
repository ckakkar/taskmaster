import AppKit
import CompanionCore
import SwiftUI

struct AdvancedPane: View {
    @ObservedObject var model: AppModel
    @ViewState private var confirmingReset = false

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        Form {
            Section {
                ExplainedToggle(
                    "Let \(name) borrow your cursor",
                    detail:
                        "Chaos only. A nearby pointer may get snatched for a getaway of at most 1½ seconds. Click, press Esc or pull away to take it back.",
                    isOn: $model.preferences.cursorHeists)
                HStack {
                    if let message = model.chaosMessage {
                        Text(message).foregroundStyle(Palette.orange)
                    }
                    Spacer()
                    Button("Invite a Cursor Heist") { model.inviteCursorHeist() }
                        .disabled(
                            !model.preferences.cursorHeists || model.preferences.mischief < 0.75 || model.focusActive)
                }
            } header: {
                Text("Cursor games")
            } footer: {
                Text(
                    "Off by default. Heists take a long breather between attempts and stay off during focus, naps, full-screen presentations and Reduce Motion."
                )
            }

            Section("Your data") {
                LabeledContent {
                    Button("Show in Finder") { model.revealDataFolder() }
                } label: {
                    Text("Settings and meme stash")
                    Text("Everything stays on this Mac.")
                }
            }

            Section {
                LabeledContent {
                    Button("Reset…", role: .destructive) { confirmingReset = true }
                } label: {
                    Text("Reset all settings")
                    Text("Everything in Settings goes back to how it started. Memes and focus sessions stay.")
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all settings?", isPresented: $confirmingReset) {
            Button("Reset All Settings", role: .destructive) { model.resetAllSettings() }
        } message: {
            Text("Your companion, mood, behaviours, sayings and schedules return to their defaults.")
        }
    }
}
