import AppKit
import CompanionCore
import SwiftUI

struct GeneralPane: View {
    @ObservedObject var model: AppModel
    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { on in
                            LaunchAtLogin.set(on)
                            launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
                        })
                ) {
                    Text("Open Taskmaster at login")
                    Text("So \(name) is there as soon as you sign in.")
                }
                if LaunchAtLogin.needsApproval {
                    HStack {
                        Text("Allow Taskmaster under Login Items in System Settings.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    }
                }
                ExplainedToggle(
                    "Open the companion room when Taskmaster starts",
                    detail: "Otherwise \(name) just appears on your desktop, with the paw in your menu bar.",
                    isOn: $model.preferences.openRoomAtLaunch)
            }

            Section("On your desktop") {
                ExplainedToggle(
                    "Show on every desktop Space", detail: "Off, \(name) stays on the Space you’re using.",
                    isOn: $model.preferences.allSpaces)
                ExplainedToggle(
                    "Little sound effects", detail: "A soft pop when you pet, treat or play.",
                    isOn: $model.preferences.sound)
            }

            Section("Updates") {
                if model.updater.isAvailable {
                    // Sparkle keeps this setting; the model only announces the change to the view.
                    Toggle(
                        isOn: Binding(
                            get: { model.updater.automaticallyChecks },
                            set: {
                                model.objectWillChange.send()
                                model.updater.automaticallyChecks = $0
                            })
                    ) {
                        Text("Check for updates automatically")
                        Text("Soon after Taskmaster opens, then every hour. A dot on the paw means one is ready.")
                    }
                    LabeledContent("Taskmaster \(AppInfo.version)") {
                        Button("Check Now") { model.updater.checkForUpdates() }
                    }
                } else {
                    Text("This copy of Taskmaster was built locally and doesn’t update itself.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Help") {
                LabeledContent("New here?") {
                    Button("Show the Welcome Again") { model.openWelcome?() }
                }
                LabeledContent("Taskmaster on GitHub") {
                    Link("ckakkar/taskmaster", destination: AppInfo.repository)
                }
                LabeledContent("Something not right?") {
                    Link("Report a Problem", destination: AppInfo.issues)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval }
    }
}
